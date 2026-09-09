extends "res://studies/fidelity.gd"
## Visual lab only: compare relative scale; no gameplay or persistent edits.
const NAMES := ["1 · Compact", "2 · Taller peaks", "3 · Smaller inhabitants"]
var variant := 0
var baseline: Dictionary
var actor: CreatureActor
var lab_ui: CanvasLayer
var stats: Label
var actor_point := Vector2(-3.6,7.4)
var peak := 0.0
var avatar_height := 0.0
var ready_for_compare := false

func _ready() -> void:
	super._ready()
	_ui.hide()
	_ambient_audio.muted = true
	_thunder_audio.muted = true
	_paused = true
	_celestial.cycling = false
	_celestial.set_phase(0.42)
	_celestial.cloud = 0.06
	_atmosphere.fog_amount = 0.02
	_atmosphere.haze_amount = 0.03
	_atmosphere.shroud = 0.0
	_growth.terrain = 1.0
	_growth.foliage = 1.0
	_growth.water = 1.0
	_growth.replaying = false
	_growth.publish()
	_chunk_editor.form_landscape("horn","alpine",false,37,"quiet",false)
	var data = _chunk_editor.data
	# A readable scale reference in the foreground, with a familiar conifer nearby.
	data.objects = data.objects.filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(actor_point)>2.4)
	data.place("tree",Vector2(-6.2,7.4),0.3,1.65)
	data.objects_revision += 1
	baseline = data._snapshot()
	actor = CreatureActor.new()
	actor.name = "ScaleReferenceBigfoot"
	add_child(actor)
	actor.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	actor.set_process(false)
	actor.player.advance(0.0)
	actor.player.pause()
	var coat := ShaderMaterial.new()
	coat.shader = preload("res://shaders/reference_surface.gdshader")
	for mesh: MeshInstance3D in actor.actor.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
	actor.rotation.y = 0.5
	avatar_height = _visual_height(actor)
	_make_lab_ui()
	ready_for_compare = true
	set_scale_variant(0)
	reset_lab_camera()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 0
	get_window().title = "ZenScape visual lab · Mountain scale"

func _visual_height(node: Node3D) -> float:
	var minimum := INF
	var maximum := -INF
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		var box := mesh.get_aabb()
		for corner in range(8):
			var point: Vector3 = node.to_local(mesh.to_global(box.get_endpoint(corner)))
			minimum = minf(minimum,point.y)
			maximum = maxf(maximum,point.y)
	return maximum-minimum

func set_scale_variant(index: int) -> void:
	variant = posmod(index,3)
	var data = _chunk_editor.data
	data._restore(baseline)
	var living_scale := 0.55 if variant == 2 else 1.0
	if variant == 1:
		# Preserve the low ground and tarn; stretch only the upper mountain.
		for i in range(data.heights.size()):
			var height: float = data.heights[i]
			data.heights[i] = height + maxf(height-3.0,0.0)
	if variant == 2:
		for item in data.objects: item.scale *= living_scale
		data.objects_revision += 1
	_chunk_editor.refresh()
	if variant == 2:
		for batch in _chunk_editor.content._batches:
			if batch.get_meta("part","") != "grass": continue
			for i in range(batch.multimesh.instance_count):
				var pose: Transform3D = batch.multimesh.get_instance_transform(i)
				pose.basis = pose.basis.scaled(Vector3.ONE*living_scale)
				batch.multimesh.set_instance_transform(i,pose)
	actor.scale = Vector3.ONE*living_scale
	actor.position = Vector3(actor_point.x,float(data.ground_height(actor_point)),actor_point.y)
	peak = 0.0
	for height in data.heights: peak = maxf(peak,height)
	stats.text = "%s   |   peak %.1f units · Bigfoot visual %.1f · ratio %.1f:1" % [NAMES[variant],peak,avatar_height*living_scale,peak/(avatar_height*living_scale)]
	if _display_fog != null: _display_fog.forget()
	print("SCALE ",stats.text)

func reset_lab_camera() -> void:
	target = Vector3(0,7.5,0)
	distance = 62.0
	yaw = 0.35
	polar = 1.08
	_auto_orbit = false
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_update_camera()

func focus_scale_reference() -> void:
	target = actor.position+Vector3(0,1.8,0)
	distance = 23.0
	yaw = 0.35
	polar = 1.3
	_auto_orbit = false
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_update_camera()

func _make_lab_ui() -> void:
	lab_ui = CanvasLayer.new()
	lab_ui.layer = 30
	add_child(lab_ui)
	var host := Control.new()
	lab_ui.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	host.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -450
	panel.offset_right = 450
	panel.offset_top = -122
	panel.offset_bottom = -20
	var column := VBoxContainer.new()
	panel.add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for i in range(NAMES.size()):
		var button := Button.new()
		button.text = NAMES[i]
		button.pressed.connect(func() -> void: set_scale_variant(i))
		row.add_child(button)
	stats = Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(stats)
	var hint := Label.new()
	hint.text = "Same camera across variants · C overview · F Bigfoot view · drag orbit · wheel zoom · Space drift"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",13)
	column.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if not ready_for_compare: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			set_scale_variant(event.keycode-KEY_1)
			return
		if event.keycode == KEY_C:
			reset_lab_camera()
			return
		if event.keycode == KEY_F:
			focus_scale_reference()
			return
		if event.keycode in [KEY_TAB,KEY_H,KEY_B,KEY_Y,KEY_ESCAPE,KEY_R,KEY_K]: return
	super._unhandled_input(event)
