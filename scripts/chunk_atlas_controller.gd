extends Node
## `--atlas`: Genesis chunks stitched into one world (docs/chunk-atlas/DESIGN.md).
## The live chunk is the editor's own at the origin; its stored neighbours are
## drawn around it by scripts/chunk_atlas_view.gd. A plain arrow key
## steps to the chunk that way, relative to the camera, growing a fresh plain
## pinned to its neighbours if the square is empty.

const Atlas = preload("res://scripts/chunk_atlas.gd")
const AtlasView = preload("res://scripts/chunk_atlas_view.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const Genes = preload("res://scripts/chunk_atlas_genes.gd")
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

## Accepts `--atlas` before or after Godot's `--` separator; launchers pass
## their extra arguments straight through without one.
static func enabled() -> bool:
	return "--atlas" in OS.get_cmdline_user_args() or "--atlas" in OS.get_cmdline_args()

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
		# The first plain sits at (0, 0), where the world field and the
		# plain's own field coincide, so later plains already continue it.
		_attach_live()
	await _build_views()
	_build_pad()
	if views.size() > 0: scene.distance = maxf(scene.distance,62.0)
	scene._update_camera()
	busy = false
	_hint()

func _hint() -> void:
	scene._notice.text = "Chunk %s · the arrow keys walk to the next chunk, or grows one there." % [atlas.live]

func _attach_live() -> void:
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.data.set_world_offset(Atlas.world_origin(atlas.live))
	editor.border_pin = atlas.pin_for(atlas.live,editor.data.points)
	editor.open_sides = atlas.shared_sides(atlas.live)
	editor._rebuild_skirt()
	# Shared borders hold their height while the live chunk folds and grows.
	var sides: Dictionary = editor.open_sides
	var hold := Vector4(float(sides.has("n")),float(sides.has("e")),float(sides.has("s")),float(sides.has("w")))
	for material in [editor.terrain.material_override,editor._previous_override,editor._material,editor.terrain.get_active_material(0)]:
		if material is ShaderMaterial: material.set_shader_parameter("atlas_hold",hold)

## Chunks in the world, the live one included even before it is first stored.
func chunk_count() -> int:
	return atlas.slots.size()+(0 if atlas.slots.has(atlas.live) else 1)

func live_origin() -> Vector2:
	return Atlas.world_origin(atlas.live)

## Regenerate: a world whose terrain continues the stored neighbours
## (scripts/chunk_atlas_genes.gd).
func sample_world(seed_value: int) -> Dictionary:
	return await Genes.sample_near_async(seed_value,Genes.neighbours(atlas,atlas.live),{},get_tree())

## After the live chunk is formed afresh: carry the neighbours' relief and
## cover in, then redraw.
func carry_in_live() -> void:
	var editor: NativeChunkEditor = scene._chunk_editor
	last_carry = atlas.carry_in(atlas.live,editor.data)
	await editor.refresh(get_tree())

var last_carry := 0.0

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
		var stale: bool = not wanted.has(slot) or views[slot].revision != atlas.slots[slot].get("revision",0)
		if stale:
			views[slot].queue_free()
			views.erase(slot)
	for slot: Vector2i in wanted:
		var sides: Dictionary = atlas.shared_sides(slot)
		if not views.has(slot):
			var view := AtlasView.new()
			view.name = "Chunk_%d_%d" % [slot.x,slot.y]
			view.slot = slot
			view.revision = atlas.slots[slot].get("revision",0)
			root.add_child(view)
			if not await view.build(atlas.slots[slot].document,editor.data.source_mesh,_terrain_material(),editor._skirt_mesh,editor._skirt.position,sides):
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
	last_carry = 0.0
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
	if grown: last_carry = atlas.carry_in(target,editor.data)
	editor.border_pin.apply(editor.data)
	# The world slides under the camera: keep the view where it was, then
	# glide onto the new chunk.
	scene.target -= shift
	_glide_from = scene.target
	_glide_time = 0.0
	await _build_views()
	await editor.refresh(get_tree())
	scene._refresh_habitat()
	atlas.save(path)
	busy = false
	_hint()
	if grown: scene._notice.text = "A new plain at %s, joined to its neighbours. Drag to raise land." % [target]
	return true

## On-screen pad: four arrows round the chunk's name, each marked "new" or
## "visit" for the square it points at from the current camera.
var _pad: PanelContainer
var _pad_buttons := {}
var _pad_label: Label
const PAD_ARROWS := {Vector2(0,-1):"▲",Vector2(-1,0):"◀",Vector2(1,0):"▶",Vector2(0,1):"▼"}

func _build_pad() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_pad = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06,0.07,0.08,0.62)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(10)
	_pad.add_theme_stylebox_override("panel",style)
	_pad.anchor_left = 1.0
	_pad.anchor_right = 1.0
	_pad.anchor_top = 1.0
	_pad.anchor_bottom = 1.0
	_pad.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pad.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pad.offset_right = -24.0
	_pad.offset_bottom = -110.0
	layer.add_child(_pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	_pad.add_child(column)
	var title := Label.new()
	title.text = "WORLD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",11)
	title.modulate = Color(1,1,1,0.6)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	column.add_child(grid)
	for cell in [Vector2(-1,-1),Vector2(0,-1),Vector2(1,-1),Vector2(-1,0),Vector2.ZERO,Vector2(1,0),Vector2(-1,1),Vector2(0,1),Vector2(1,1)]:
		if PAD_ARROWS.has(cell):
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(64,44)
			button.add_theme_font_size_override("font_size",13)
			button.pressed.connect(func(): if can_move(): move(camera_direction(cell)))
			grid.add_child(button)
			_pad_buttons[cell] = button
		elif cell == Vector2.ZERO:
			_pad_label = Label.new()
			_pad_label.custom_minimum_size = Vector2(64,44)
			_pad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_pad_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_pad_label.add_theme_font_size_override("font_size",12)
			grid.add_child(_pad_label)
		else:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(64,44)
			grid.add_child(gap)
	var legend := Label.new()
	legend.text = "or the arrow keys"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size",11)
	legend.modulate = Color(1,1,1,0.5)
	column.add_child(legend)
	_refresh_pad()

func _refresh_pad() -> void:
	if _pad == null: return
	var count := chunk_count()
	_pad_label.text = "%d, %d\n%d chunk%s" % [atlas.live.x,atlas.live.y,count,"" if count == 1 else "s"]
	var ready := can_move()
	for cell in _pad_buttons:
		var button: Button = _pad_buttons[cell]
		var target: Vector2i = atlas.live+camera_direction(cell)
		button.text = "%s\n%s" % [PAD_ARROWS[cell],"visit" if atlas.has(target) else "+ new"]
		button.disabled = not ready

func contains_pointer(point: Vector2) -> bool:
	return _pad != null and _pad.is_visible_in_tree() and _pad.get_global_rect().has_point(point)

func _process(delta: float) -> void:
	_refresh_pad()
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
