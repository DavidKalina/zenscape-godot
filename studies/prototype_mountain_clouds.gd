extends "res://studies/fidelity.gd"
## Visual lab only: mountain silhouettes, height, and drifting summit clouds.
const NAMES := ["1 · Alpine massif", "2 · Broken ridge", "3 · Volcanic crown"]
var variant := 0
var baseline: Dictionary
var actor: CreatureActor
var lab_ui: CanvasLayer
var stats: Label
var actor_point := Vector2(-3.6,7.4)
var peak := 0.0
var avatar_height := 0.0
var ready_for_compare := false
var mountain_height := 24.0
var cloud_altitude := 11.0
var clouds_enabled := true
var cloud_clock := 0.0
var cloud_drift := true
var cloud_volume: FogVolume
var cloud_material: ShaderMaterial
var cloud_button: Button
var mountain_material: ShaderMaterial


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
	mountain_material = _chunk_editor.terrain.mesh.surface_get_material(0).duplicate()
	mountain_material.shader = preload("res://shaders/prototype_mountain_surface.gdshader")
	_chunk_editor.terrain.material_override = mountain_material
	_make_clouds()
	_make_lab_ui()
	ready_for_compare = true
	set_scale_variant(0)
	reset_lab_camera()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 0
	get_window().title = "ZenScape visual lab · Mountains through clouds"

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

func _profile(point: Vector2) -> float:
	var q := Vector2(point.x,(point.y+3.2)*1.15)
	if variant == 0:
		var main := pow(maxf(0.0,1.0-Vector2(q.x/8.8,q.y/8.1).length()),1.15)
		var left := 0.72*pow(maxf(0.0,1.0-Vector2((q.x+4.6)/6.5,(q.y+0.7)/6.8).length()),1.1)
		var right := 0.63*pow(maxf(0.0,1.0-Vector2((q.x-4.8)/6.0,(q.y-0.7)/6.0).length()),1.2)
		return maxf(main,maxf(left,right))+0.13*exp(-q.length_squared()/85.0)
	if variant == 1:
		var ridge := 0.0
		for summit in [Vector3(-6.0,-0.8,0.78),Vector3(0.0,-1.2,1.0),Vector3(5.7,0.8,0.83)]:
			var r := Vector2((q.x-summit.x)/6.4,(q.y-summit.y)/7.8).length()
			ridge = maxf(ridge,summit.z*pow(maxf(0.0,1.0-r),1.1))
		return ridge+0.14*exp(-q.length_squared()/100.0)
	var radius := Vector2(q.x/9.5,q.y/8.5).length()
	var cone := pow(maxf(0.0,1.0-radius),1.05)
	var crater := 0.34*exp(-radius*radius/0.024)
	return maxf(cone-crater,0.0)*(1.0+0.035*sin(atan2(q.y,q.x)*9.0))

func set_scale_variant(index: int) -> void:
	variant = posmod(index,3)
	var data = _chunk_editor.data
	data._restore(baseline)
	var values := PackedFloat32Array()
	var maximum := 0.001
	for point in data.points:
		var value := _profile(point)
		values.append(value)
		maximum = maxf(maximum,value)
	for i in range(data.heights.size()):
		var point: Vector2 = data.points[i]
		var preserve := smoothstep(2.8,6.2,point.y)
		var height := 1.1+values[i]/maximum*(mountain_height-1.1)
		data.heights[i] = lerpf(height,baseline.heights[i],preserve)
	# Keep forest at the foothills; avoid lifting old trees onto new cliffs.
	data.objects = data.objects.filter(func(item: Dictionary) -> bool:
		var height: float = data.ground_height(Vector2(item.x,item.z))
		return height<5.0 or item.z>6.2)
	data.objects_revision += 1
	_chunk_editor.refresh()
	actor.scale = Vector3.ONE
	actor.position = Vector3(actor_point.x,float(data.ground_height(actor_point)),actor_point.y)
	peak = 0.0
	for height in data.heights: peak = maxf(peak,height)
	mountain_material.set_shader_parameter("study_snowline",maxf(7.0,mountain_height*0.64))
	_update_stats()
	if _display_fog != null: _display_fog.forget()
	print("MOUNTAIN ",NAMES[variant]," height=",peak," clouds=",cloud_altitude)

func set_height(value: float) -> void:
	mountain_height = clampf(value,8.0,32.0)
	set_scale_variant(variant)

func _make_clouds() -> void:
	var existing := _atmosphere.get_node_or_null("ValleyFog")
	if existing != null: existing.hide()
	cloud_material = ShaderMaterial.new()
	cloud_material.shader = preload("res://shaders/prototype_peak_clouds.gdshader")
	cloud_volume = FogVolume.new()
	cloud_volume.name = "MountainCloudBand"
	cloud_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	cloud_volume.size = Vector3(35,9,29)
	cloud_volume.position = Vector3(0,cloud_altitude,-2.5)
	cloud_volume.material = cloud_material
	add_child(cloud_volume)
	_environment.volumetric_fog_density = 0.0
	_environment.volumetric_fog_length = 125.0
	_environment.volumetric_fog_detail_spread = 0.8
	_environment.volumetric_fog_anisotropy = 0.3
	_environment.volumetric_fog_temporal_reprojection_enabled = true
	_environment.volumetric_fog_temporal_reprojection_amount = 0.75
	_environment.volumetric_fog_ambient_inject = 0.8
	_environment.volumetric_fog_sky_affect = 1.0
	_sync_clouds()

func _sync_clouds() -> void:
	_environment.volumetric_fog_enabled = clouds_enabled
	cloud_volume.visible = clouds_enabled
	cloud_volume.position.y = cloud_altitude
	cloud_material.set_shader_parameter("cloud_time",cloud_clock)
	if cloud_button != null: cloud_button.text = "Clouds: on" if clouds_enabled else "Clouds: off"

func toggle_clouds() -> void:
	clouds_enabled = not clouds_enabled
	_sync_clouds()

func _process(delta: float) -> void:
	super._process(delta)
	if cloud_volume != null:
		if cloud_drift: cloud_clock += delta
		_sync_clouds()

func _update_stats() -> void:
	if stats != null:
		stats.text = "%s · Peak %.0f · Clouds %.1f · Bigfoot stays the same size" % [NAMES[variant],peak,cloud_altitude]

func reset_lab_camera() -> void:
	target = Vector3(0,10.0,0)
	distance = 66.0
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
	panel.offset_top = -155
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
	var options := HBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(options)
	for entry in [["Short",12.0],["Tall",24.0],["Extreme",32.0]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(func() -> void: set_height(entry[1]))
		options.add_child(button)
	cloud_button = Button.new()
	cloud_button.text = "Clouds: on"
	cloud_button.pressed.connect(toggle_clouds)
	options.add_child(cloud_button)
	var altitude_label := Label.new()
	altitude_label.text = "  Cloud altitude  "
	options.add_child(altitude_label)
	var altitude := HSlider.new()
	altitude.min_value = 5.0
	altitude.max_value = 23.0
	altitude.step = 0.5
	altitude.value = cloud_altitude
	altitude.custom_minimum_size.x = 150
	altitude.value_changed.connect(func(value: float) -> void:
		cloud_altitude = value
		_sync_clouds()
		_update_stats())
	options.add_child(altitude)
	stats = Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(stats)
	var hint := Label.new()
	hint.text = "1/2/3 shape · [ / ] height · K clouds · P freeze clouds · C overview · F Bigfoot · Space orbit"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",13)
	column.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if not ready_for_compare: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			set_scale_variant(event.keycode-KEY_1)
			return
		if event.keycode == KEY_K:
			toggle_clouds()
			return
		if event.keycode == KEY_P:
			cloud_drift = not cloud_drift
			return
		if event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
			set_height(mountain_height + (-4.0 if event.keycode == KEY_BRACKETLEFT else 4.0))
			return
		if event.keycode == KEY_C:
			reset_lab_camera()
			return
		if event.keycode == KEY_F:
			focus_scale_reference()
			return
		if event.keycode in [KEY_TAB,KEY_H,KEY_B,KEY_Y,KEY_ESCAPE,KEY_R,KEY_K]: return
	super._unhandled_input(event)
