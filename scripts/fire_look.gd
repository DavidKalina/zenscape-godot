class_name FireLook
extends RefCounted
## Paints what `FireField` simulates.
##
## Two jobs, and nothing else. Per record it pushes `(char, burn)` into
## `GardenView.set_object_fire`, which lands in `INSTANCE_CUSTOM.rg` and drives
## `shaders/reference_char.gdshaderinc`: leaves brown and curl, then thin to a
## charcoal skeleton, with an ember glow while the thing is actually alight.
## Per burnt cell the field has already written the scorch into the cover and
## tint arrays, but those writes bump no revision, so somebody has to ask the
## terrain and the flora batches to look again; this does it on a timer.
##
## The look owns no state the field does not, except one thing: the char of
## records that have finished burning. The field forgets a snag the moment it
## swaps the record, and without that memory the snag would rebuild looking
## freshly cut.

var field: FireField = null
var view: GardenView = null

## Ask the terrain mesh and the flora batches to pick up the field's ground
## writes. Integration can turn this off and drive `refresh_ground()` itself.
var ground_refresh := true
## While anything is alight. Fast enough that the front leaves black behind it.
var ground_interval := 0.5
## While only ash is fading back to grass over `FireField.regrow_seconds`.
var regrow_interval := 4.0

var _state := {} ## id -> Vector2(char, burn), including settled snags.
var _clock := 0.0
var _dirty := false

func setup(field_: FireField, view_: GardenView) -> void:
	field = field_
	view = view_
	_state.clear()
	_clock = 0.0
	_dirty = false
	if field == null:
		return
	for pair in [["object_ignited",_on_ignited],["object_charring",_on_charring],
			["object_burned_out",_on_burned_out],["cell_ignited",_on_cell_ignited],
			["cell_burned_out",_on_cell_burned_out],["fire_extinguished",_on_extinguished]]:
		if not field.is_connected(pair[0],pair[1]):
			field.connect(pair[0],pair[1])

func advance(delta: float, paused := false) -> void:
	if field == null or view == null or not is_instance_valid(view):
		return
	if not paused:
		var burning: Dictionary = field.burning_objects()
		for id: int in burning:
			var entry: Dictionary = burning[id]
			_state[id] = Vector2(float(entry["char"]),float(entry.burn))
	# Push every frame, paused included. `set_object_fire` early-outs when the
	# value has not moved, so a still world costs one comparison per burnt thing
	# and a rebuild mid-burn comes back charred on the next call regardless.
	for id: int in _state:
		var value: Vector2 = _state[id]
		view.set_object_fire(id,value.x,value.y)
	if paused:
		return
	_advance_ground(delta)

## Records the look is still painting: burning objects plus settled snags.
func charred() -> Dictionary:
	return _state.duplicate()

# -------------------------------------------------------------------- ground

func _advance_ground(delta: float) -> void:
	if not ground_refresh:
		return
	var alight: bool = field.active()
	_clock += delta
	if _clock < (ground_interval if alight else regrow_interval):
		return
	_clock = 0.0
	# Regrowth keeps rewriting cover and tint long after the last flame, so the
	# ground stays dirty until the field has restored every remembered cell.
	if not _dirty and not alight and field.ash_center().is_zero_approx():
		return
	_dirty = false
	refresh_ground()

## Rebuild the flora batches and the terrain mesh from the arrays the field
## wrote. `GardenView.rebuild` re-applies every record's fire state, so the
## burnt trees survive the pass.
func refresh_ground() -> void:
	if view == null or not is_instance_valid(view):
		return
	view.rebuild()
	var editor: Object = _editor()
	if editor == null:
		return
	var terrain: Variant = editor.get("terrain")
	var data: Variant = editor.get("data")
	if terrain is MeshInstance3D and data != null:
		# The narrow half of `NativeChunkEditor.refresh`: `build_mesh` is
		# incremental over the repainted region, so this is far cheaper than a
		# full refresh and skips the status line and the surface-map rebuild.
		terrain.mesh = data.play_mesh(data.build_mesh(false))

## The chunk editor that owns this view, if there is one. `GardenView` is added
## as a child of the scene by `NativeChunkEditor`, so the scene is the only hop.
func _editor() -> Object:
	var parent: Node = view.get_parent()
	if parent == null:
		return null
	var editor: Variant = parent.get("_chunk_editor")
	if not (editor is Object) or editor.get("content") != view:
		return null
	return editor

# ------------------------------------------------------------------- signals

func _on_ignited(id: int, _kind: String, _position: Vector3) -> void:
	_state[id] = Vector2(0.0,1.0)

func _on_charring(id: int, char: float) -> void:
	var burn: float = _state.get(id,Vector2.ZERO).y
	_state[id] = Vector2(char,burn)

func _on_burned_out(id: int, kind: String, _position: Vector3) -> void:
	var group := FireField.group_of(kind)
	if group == "tree" or group == "deadwood":
		# The tree became a snag (same id, charcoal tint) or the deadwood simply
		# stopped burning. Either way it stays black and stops glowing.
		_state[id] = Vector2(1.0,0.0)
		view.set_object_fire(id,1.0,0.0)
	else:
		_state.erase(id)
		if view != null and is_instance_valid(view):
			view.set_object_fire(id,0.0,0.0)
	_dirty = true

func _on_cell_ignited(_index: int, _center: Vector3) -> void:
	_dirty = true

func _on_cell_burned_out(_index: int) -> void:
	_dirty = true

func _on_extinguished() -> void:
	_dirty = true
	_clock = ground_interval
