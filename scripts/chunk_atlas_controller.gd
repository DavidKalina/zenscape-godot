extends Node
## `--atlas`: Genesis chunks stitched into one world (docs/chunk-atlas/DESIGN.md).
## The live chunk is the editor's own at the origin; its stored neighbours are
## drawn around it by scripts/chunk_atlas_view.gd. A plain arrow key
## steps to the chunk that way, relative to the camera, growing a fresh plain
## pinned to its neighbours if the square is empty.

const Atlas = preload("res://scripts/chunk_atlas.gd")
const AtlasView = preload("res://scripts/chunk_atlas_view.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
## Chebyshev rings drawn around the live chunk (main.js NEAR_RINGS).
const NEAR_RINGS := 1
## Seconds the camera takes to glide onto the new live chunk (visit.js GLIDE_S).
const GLIDE_S := 1.15

var scene: Node3D
var atlas = Atlas.new()
var path := Atlas.PATH
var busy := false
var root: Node3D
var views := {}
var last_build_usec := 0
var _glide_from := Vector3.ZERO
var _glide_time := -1.0

static func enabled() -> bool:
	return "--atlas" in OS.get_cmdline_user_args()

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	busy = true
	root = Node3D.new()
	root.name = "ChunkAtlas"
	scene.add_child(root)
	var editor: NativeChunkEditor = scene._chunk_editor
	if atlas.load(path) and atlas.slots.has(atlas.live) and editor.data.load_document(atlas.slots[atlas.live].document):
		editor.data._undo.clear()
		editor.data._redo.clear()
		_attach_live()
		await editor.refresh(get_tree())
		scene._refresh_habitat()
	else:
		# A new atlas starts from the plain the regrowth controller just formed;
		# its seed becomes the seed of every later plain.
		atlas = Atlas.new()
		atlas.seed_value = int(scene.places.world_seed)
		atlas.live = Vector2i.ZERO
		_attach_live()
	_build_views()
	if views.size() > 0: scene.distance = maxf(scene.distance,62.0)
	scene._update_camera()
	busy = false
	_hint()

func _hint() -> void:
	scene._notice.text = "Chunk %s · the arrow keys walk to the next chunk, or grows one there." % [atlas.live]

func _attach_live() -> void:
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.border_pin = atlas.pin_for(atlas.live,editor.data.points)
	editor.open_sides = atlas.shared_sides(atlas.live)
	editor._rebuild_skirt()

func _terrain_material() -> Material:
	var editor: NativeChunkEditor = scene._chunk_editor
	return editor._previous_override if editor.active else editor.terrain.material_override

## Draw every stored chunk within NEAR_RINGS of the live one, reusing views
## whose document is unchanged.
func _build_views() -> void:
	var began := Time.get_ticks_usec()
	var editor: NativeChunkEditor = scene._chunk_editor
	var wanted := {}
	for slot: Vector2i in atlas.slots:
		if slot == atlas.live: continue
		if maxi(absi(slot.x-atlas.live.x),absi(slot.y-atlas.live.y)) > NEAR_RINGS: continue
		wanted[slot] = true
	for slot: Vector2i in views.keys():
		var stale: bool = not wanted.has(slot) or views[slot].document_hash != hash(atlas.slots[slot].document.get("heights"))
		if stale:
			views[slot].queue_free()
			views.erase(slot)
	for slot: Vector2i in wanted:
		var sides: Dictionary = atlas.shared_sides(slot)
		if not views.has(slot):
			var view := AtlasView.new()
			view.name = "Chunk_%d_%d" % [slot.x,slot.y]
			view.slot = slot
			root.add_child(view)
			if not view.build(atlas.slots[slot].document,editor.data.source_mesh,_terrain_material(),editor._skirt_mesh,editor._skirt.position,sides):
				push_warning("Chunk atlas: could not draw %s" % slot)
				view.queue_free()
				continue
			views[slot] = view
		else:
			views[slot].set_open_sides(editor._skirt_mesh,editor._skirt.position,sides)
		views[slot].position = Atlas.offset(slot,atlas.live)
	last_build_usec = Time.get_ticks_usec()-began

func _store_live() -> void:
	var editor: NativeChunkEditor = scene._chunk_editor
	if editor.border_pin != null: editor.border_pin.apply(editor.data)
	Atlas.quantize_edges(editor.data)
	atlas.store(atlas.live,editor.data.to_document())

func save() -> bool:
	if busy: return false
	_store_live()
	return atlas.save(path)

func can_move() -> bool:
	var editor: NativeChunkEditor = scene._chunk_editor
	return not busy and not editor.forming and editor.refresh_pending == 0 and not editor.water_settling and not scene.places.busy

## Step the live chunk one square. An empty square grows a fresh plain pinned
## to every stored neighbour.
func move(direction: Vector2i) -> bool:
	if not can_move(): return false
	busy = true
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.finish_stroke()
	_store_live()
	var target: Vector2i = atlas.live+direction
	var shift := Atlas.offset(target,atlas.live)
	var grown := not atlas.has(target)
	atlas.live = target
	if grown:
		Genesis.shape(editor.data,atlas.seed_value,Atlas.world_origin(target))
	else:
		editor.data.load_document(atlas.slots[target].document)
	editor.data._undo.clear()
	editor.data._redo.clear()
	_attach_live()
	editor.border_pin.apply(editor.data)
	# The world slides under the camera: keep the view where it was, then
	# glide onto the new chunk.
	scene.target -= shift
	_glide_from = scene.target
	_glide_time = 0.0
	_build_views()
	await editor.refresh(get_tree())
	scene._refresh_habitat()
	atlas.save(path)
	busy = false
	_hint()
	if grown: scene._notice.text = "A new plain at %s, joined to its neighbours. Drag to raise land." % [target]
	return true

func _process(delta: float) -> void:
	if _glide_time < 0.0: return
	_glide_time += delta
	var t := smoothstep(0.0,1.0,minf(_glide_time/GLIDE_S,1.0))
	scene.target = _glide_from.lerp(Vector3.ZERO,t)
	scene._update_camera()
	if _glide_time >= GLIDE_S: _glide_time = -1.0

## Plain arrows: macOS takes Ctrl+arrows for Spaces, and focused UI would
## eat them as focus moves, so this reads them before the GUI does.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if event.ctrl_pressed or event.meta_pressed or event.alt_pressed or event.shift_pressed: return
	if scene.photo != null and scene.photo.active: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	var screen := {KEY_UP:Vector2(0,-1),KEY_DOWN:Vector2(0,1),KEY_LEFT:Vector2(-1,0),KEY_RIGHT:Vector2(1,0)}
	if not screen.has(event.keycode): return
	get_viewport().set_input_as_handled()
	move(camera_direction(screen[event.keycode]))

## A screen direction (x right, y down) to the slot step nearest it on the
## ground, as seen from the current camera.
func camera_direction(screen: Vector2) -> Vector2i:
	var basis: Basis = scene.camera.global_basis
	var right := Vector2(basis.x.x,basis.x.z).normalized()
	var ahead := Vector2(-basis.z.x,-basis.z.z).normalized()
	var ground := right*screen.x-ahead*screen.y
	if absf(ground.x) >= absf(ground.y): return Vector2i(1 if ground.x > 0.0 else -1,0)
	# World -z is +v (north).
	return Vector2i(0,1 if ground.y < 0.0 else -1)
