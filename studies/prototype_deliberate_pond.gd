extends "res://studies/fidelity.gd"
## THROWAWAY: Does one quiet pond feel more tactile with localized wetness,
## stone/moss separation, cooler canopy interiors and afternoon light?
## Same editable fixture in all three variants. No saved world is read or written.
const TITLES := ["1 · Original materials", "2 · Tactile materials", "3 · Deliberate afternoon"]
var variant := 2
var study_materials: Array[ShaderMaterial] = []
var study_label: Label
var study_ui: CanvasLayer
var original_look: Dictionary
var layered_tree: Node3D
var original_tree_parts: Array[Node3D] = []
var layered_canopy := true
var canopy_button: Button

func _ready() -> void:
	super._ready()
	_ui.hide()
	_ambient_audio.muted = true
	_thunder_audio.muted = true
	_celestial.cycling = false
	_celestial.set_phase(0.60)
	_atmosphere.fog_amount = 0.02
	_atmosphere.haze_amount = 0.03
	_atmosphere.shroud = 0.0
	_atmosphere.strength = 0.24
	_celestial.cloud = 0.03
	_growth.terrain = 1.0
	_growth.foliage = 1.0
	_growth.water = 1.0
	_growth.replaying = false
	_growth.publish()
	var data = _chunk_editor.data
	data.reset_flat()
	data.brush(Vector2(-4,-4), 8.0, 1.8, "raise", 0.0)
	data.brush(Vector2(5,-5), 7.0, 0.8, "raise", 0.0)
	data.brush(Vector2(1,0), 5.4, 1.4, "lower", 0.0)
	data.brush(Vector2(2,0), 4.5, 0.35, "lower", 0.0)
	assert(data.add_pond(Vector2(1,0), -0.25))
	data.paint_grass(Vector2.ZERO, 18.0, 0.9)
	data.place("broadleaf", Vector2(-3.2,-1.8), 0.6, 2.6, {}, NativeObjectPose.encode_tint(Color("527e45").srgb_to_linear()))
	data.place("boulder_1", Vector2(-2.1,0.8), 0.7, 1.15)
	data.place("boulder_2", Vector2(-1.0,2.2), 2.4, 0.85)
	data.place("boulder_3", Vector2(3.6,-1.5), 1.1, 0.7)
	for entry in [[-4.0,-1.1,0.9],[-3.4,0.0,0.7],[-3.7,-3.5,1.0]]:
		data.place("fern", Vector2(entry[0],entry[1]), entry[0], entry[2])
	for entry in [[3.6,1.6], [3.9,1.1], [3.7,0.7],[-1.7,-2.0]]:
		data.place("reeds", Vector2(entry[0],entry[1]), entry[0], 0.75)
	data.paint_blades(Vector2(-4,0), 2.0, 0.65)
	data.paint_blades(Vector2(4,2), 1.5, 0.5)
	_chunk_editor.refresh()
	# Patch only the prototype's live resources before planar copies are built.
	_collect_materials(self)
	for batch in _chunk_editor.content._batches:
		if str(batch.get_meta("part","")).begins_with("broadleaf:"):
			original_tree_parts.append(batch)
	layered_tree = preload("res://studies/prototype_pond_canopy.gd").new()
	layered_tree.position = Vector3(-3.2,float(data.ground_height(Vector2(-3.2,-1.8))),-1.8)
	layered_tree.scale = Vector3.ONE * 0.9
	add_child(layered_tree)
	study_materials.append(layered_tree.leaf_material)
	original_look = _celestial.look.document()
	_make_study_ui()
	reset_study_camera()
	set_variant(variant)
	set_canopy(layered_canopy)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 0
	get_window().title = "ZenScape · Deliberate pond prototype"

func _collect_materials(node: Node) -> void:
	var mesh: Mesh
	if node is MeshInstance3D: mesh = node.mesh
	if node is MultiMeshInstance3D and node.multimesh != null: mesh = node.multimesh.mesh
	if mesh != null:
		for surface in range(mesh.get_surface_count()):
			var material = node.material_override if node.material_override != null else mesh.surface_get_material(surface)
			if material is ShaderMaterial and material.shader != null and material.shader.resource_path.ends_with("reference_surface.gdshader"):
				material.shader = preload("res://shaders/prototype_pond_surface.gdshader")
				study_materials.append(material)
	for child in node.get_children(): _collect_materials(child)

func set_variant(index: int) -> void:
	variant = posmod(index,3)
	for material in study_materials:
		material.set_shader_parameter("tactile", 0.0 if variant == 0 else 1.0)
		material.set_shader_parameter("foliage_transmission", 0.22 if variant > 0 and material.get_shader_parameter("palette_role") == 2 else 0.0)
	layered_tree.leaf_material.set_shader_parameter("foliage_transmission",0.65 if variant > 0 else 0.0)
	_celestial.look.restore(original_look)
	if variant == 2:
		_celestial.look.set_value("ambient_energy", 0.72)
		_celestial.look.set_color("ambient", Color("91abc6"))
		_celestial.look.set_color("bounce", Color("535840"))
		_celestial.look.set_color("sun", Color("ffdaac"))
		_celestial.look.set_color("grass", Color("589453"))
		_celestial.look.set_color("foliage", Color("567749"))
		_celestial.look.set_color("rock", Color("81908d"))
	_environment.ssao_enabled = variant > 0
	_environment.ssao_radius = 0.8
	_environment.ssao_intensity = 1.3
	_environment.ssao_light_affect = 0.06 if variant > 0 else 0.0
	_environment.ssil_enabled = false
	_environment.glow_enabled = false
	_celestial.update_rig()
	if _display_fog != null: _display_fog.forget()
	study_label.text = TITLES[variant]
	print("POND VARIANT ", TITLES[variant], " materials=", study_materials.size())

func set_canopy(enabled: bool) -> void:
	layered_canopy = enabled
	layered_tree.visible = enabled
	for part in original_tree_parts: part.visible = not enabled
	if canopy_button != null: canopy_button.text = "Canopy: layered" if enabled else "Canopy: original"
	if _display_fog != null: _display_fog.forget()
	print("CANOPY ", "layered" if enabled else "original")

func reset_study_camera() -> void:
	target = Vector3(0,1.0,0)
	distance = 16.5
	yaw = 0.55
	polar = 1.15
	_auto_orbit = false
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_update_camera()

func _make_study_ui() -> void:
	study_ui = CanvasLayer.new()
	study_ui.layer = 30
	add_child(study_ui)
	var host := Control.new()
	study_ui.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	host.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -390
	panel.offset_right = 390
	panel.offset_top = -94
	panel.offset_bottom = -24
	panel.custom_minimum_size = Vector2(780,70)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	var previous := Button.new()
	previous.text = "  ‹  "
	previous.pressed.connect(func() -> void: set_variant(variant-1))
	row.add_child(previous)
	study_label = Label.new()
	study_label.custom_minimum_size.x = 360
	study_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(study_label)
	var next := Button.new()
	next.text = "  ›  "
	next.pressed.connect(func() -> void: set_variant(variant+1))
	row.add_child(next)
	canopy_button = Button.new()
	canopy_button.pressed.connect(func() -> void: set_canopy(not layered_canopy))
	row.add_child(canopy_button)
	var hint := Label.new()
	hint.text = "K canopy · 1 / 2 / 3 materials · drag orbit · wheel zoom · Space drift · P pause · C reset"
	hint.add_theme_font_size_override("font_size",13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			set_variant(event.keycode-KEY_1)
			return
		if event.keycode == KEY_K:
			set_canopy(not layered_canopy)
			return
		if event.keycode == KEY_C:
			reset_study_camera()
			return
		# The original reference overlay/editor are irrelevant to this fixture.
		if event.keycode in [KEY_TAB,KEY_H,KEY_B,KEY_Y,KEY_ESCAPE]: return
	super._unhandled_input(event)
