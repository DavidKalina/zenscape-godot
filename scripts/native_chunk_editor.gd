class_name NativeChunkEditor
extends Node
## Build tools attached to the live fidelity scene. Entering Build never swaps
## the chunk, camera, environment or shader; only the controls become active.
var scene: Node3D
var terrain: MeshInstance3D
var data := NativeTerrainData.new()
var content: GardenView
var pond_level := -0.15
var object_angle := 0.0
var object_scale := 1.0
var save_path := "user://native-garden.json"
var active := false
var mode := "raise"
var radius := 2.2
var strength := 2.0
var grass_amount := 0.85
var mountain_radius := 6.0
var mountain_peak := 9.0
var _tool_settings := {}
var _sky_controls := {}
var controls := VBoxContainer.new()
var _tools := VBoxContainer.new()
var _toggle := Button.new()
var _status := Label.new()
var _painting := false
var _elapsed := 0.0
var _level := 0.0
var _material: ShaderMaterial
var _previous_override: Material
var _anchors: Array[Dictionary] = []
var _original_ground_map: Image
var _original_stream_map: Image
var _original_bird_ground: RefCounted
var _original_precip_top := 0.0
var _source_visibility := {}
var _skirt: MeshInstance3D
var _skirt_mesh: ArrayMesh
var _boulder_anchors: Array[Transform3D] = []
var _landmark_pose: Transform3D
var _last_point: Variant = null

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	terrain = scene.get_node("Reference/terrain")
	data.setup(terrain.mesh)
	_original_ground_map = scene._precipitation.ground_texture.get_image()
	_original_stream_map = scene._precipitation.stream_texture.get_image()
	_original_bird_ground = scene._bird_flight.ground
	_original_precip_top = scene._precipitation._materials[0].get_shader_parameter("top")
	_skirt = scene.get_node("Reference/skirt")
	_skirt_mesh = _skirt.mesh
	_landmark_pose = scene._growth._landmark.transform
	for boulder: Dictionary in scene._growth._boulders:
		_boulder_anchors.append(boulder.rest)
	for node in scene.get_node("Reference").get_children():
		if node is VisualInstance3D and node not in [terrain, _skirt]:
			_source_visibility[node] = node.visible
		if not node is MultiMeshInstance3D:
			continue
		var material := node.multimesh.mesh.surface_get_material(0) as ShaderMaterial
		if material == null or material.get_shader_parameter("plant_growth") != true:
			continue
		var transforms: Array[Transform3D] = []
		for i in range(node.multimesh.instance_count):
			transforms.append(node.multimesh.get_instance_transform(i))
		_anchors.append({"node":node,"transforms":transforms,"source":node.multimesh})
	content = GardenView.new()
	content.name = "AuthoredGarden"
	content.data = data
	scene.add_child(content)
	_build_controls()

func _build_controls() -> void:
	_toggle.text = "Build this chunk"
	_toggle.toggle_mode = true
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.toggled.connect(set_active)
	controls.add_child(_toggle)
	controls.add_child(_tools)
	_tools.visible = false
	var flat := Button.new()
	flat.text = "Start flat · clear this chunk"
	flat.focus_mode = Control.FOCUS_NONE
	flat.pressed.connect(start_flat)
	_tools.add_child(flat)
	var row := GridContainer.new()
	row.columns = 4
	var group := ButtonGroup.new()
	for tool in ["raise","lower","smooth","flatten","mountain","grass","meadow","erase","tree","rock","flower","pond"]:
		var button := Button.new()
		button.text = tool.capitalize()
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = tool == mode
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			finish_stroke()
			mode = tool
			_update_tool_settings()
		)
		row.add_child(button)
	_tools.add_child(row)
	_setting("radius","Brush size",0.4,5.0,0.1,["raise","lower","smooth","flatten","grass","meadow","erase","pond"])
	_setting("strength","Strength",0.4,5.0,0.1,["raise","lower","smooth","flatten","meadow","erase"])
	_setting("grass_amount","Grass density",0.0,1.0,0.05,["grass"])
	var cover := Button.new()
	cover.text = "Cover chunk in grass"
	cover.focus_mode = Control.FOCUS_NONE
	cover.pressed.connect(cover_grass)
	_tools.add_child(cover)
	_tool_settings[cover] = ["grass"]
	_setting("mountain_radius","Mountain base radius",1.0,12.0,0.5,["mountain"])
	_setting("mountain_peak","Peak height",0.5,24.0,0.5,["mountain"])
	_setting("pond_level","Pond surface height",-1.4,12.0,0.05,["pond"])
	_update_tool_settings()
	var history := HBoxContainer.new()
	for entry: Array in [["Undo",undo],["Redo",redo],["Save",save_garden],["Open",open_garden]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		history.add_child(button)
	_tools.add_child(history)
	_build_sky_controls()
	_status.text = "Left drag paints · Click places · Right drag orbits\nSave keeps this garden · Open restores it"
	_status.add_theme_font_size_override("font_size",12)
	_tools.add_child(_status)

func _setting(property: String, title: String, low: float, high: float, step: float, modes: Array) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := SpinBox.new()
	value.min_value = low
	value.max_value = high
	value.step = step
	value.value = get(property)
	value.value_changed.connect(func(number: float) -> void: set(property,number))
	row.add_child(value)
	_tools.add_child(row)
	_tool_settings[row] = modes

func _update_tool_settings() -> void:
	for control: Control in _tool_settings:
		control.visible = mode in _tool_settings[control]

func cover_grass() -> void:
	finish_stroke()
	data.begin_stroke()
	data.grass.fill(grass_amount)
	data.end_stroke()
	refresh()

func _build_sky_controls() -> void:
	var toggle := CheckButton.new()
	toggle.text = "Sky & weather"
	toggle.focus_mode = Control.FOCUS_NONE
	_tools.add_child(toggle)
	var sky := VBoxContainer.new()
	sky.visible = false
	toggle.toggled.connect(func(value: bool) -> void: sky.visible = value)
	_tools.add_child(sky)
	var moods := HBoxContainer.new()
	for i in range(3):
		var button := Button.new()
		button.text = ["Golden hour","Misty dawn","Night"][i]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: scene._apply_mood(i); _sync_sky_controls())
		moods.add_child(button)
	sky.add_child(moods)
	var weather := OptionButton.new()
	for preset: String in scene._precipitation.PRESET_NAMES:
		weather.add_item(preset.capitalize())
	weather.focus_mode = Control.FOCUS_NONE
	weather.item_selected.connect(func(index: int) -> void: scene._precipitation.set_weather(index))
	sky.add_child(weather)
	_sky_controls.weather = weather
	for setting: String in ["time","clouds","fog"]:
		var label := Label.new()
		label.text = {"time":"Time of day","clouds":"Cloud cover","fog":"Mist"}[setting]
		sky.add_child(label)
		var slider := HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.01
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(func(value: float) -> void:
			match setting:
				"time": scene._celestial.set_phase(value)
				"clouds": scene._precipitation.cloud_override = value
				"fog": scene._atmosphere.set_fog(value)
		)
		sky.add_child(slider)
		_sky_controls[setting] = slider
	_sync_sky_controls()

func _sync_sky_controls() -> void:
	if _sky_controls.is_empty():
		return
	_sky_controls.weather.select(scene._precipitation.preset_index)
	_sky_controls.time.set_value_no_signal(scene._celestial.phase)
	_sky_controls.clouds.set_value_no_signal(scene._precipitation.cloud_override if scene._precipitation.cloud_override >= 0.0 else scene._celestial.cloud)
	_sky_controls.fog.set_value_no_signal(scene._atmosphere._fog_target)

func set_active(enabled: bool) -> void:
	if active == enabled:
		return
	finish_stroke()
	if enabled and scene._growth.terrain < 0.995:
		_toggle.set_pressed_no_signal(false)
		return
	active = enabled
	_toggle.set_pressed_no_signal(active)
	_toggle.text = "Inspect this chunk" if active else "Build this chunk"
	_tools.visible = active
	scene._orbiting = false
	if active:
		_previous_override = terrain.material_override
		_material = terrain.get_active_material(0).duplicate() as ShaderMaterial
		terrain.material_override = _material
	else:
		terrain.material_override = _previous_override
		_material = null

func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventKey and event.pressed and not event.echo and (event.ctrl_pressed or event.meta_pressed):
		if event.keycode == KEY_Z:
			if event.shift_pressed: redo()
			else: undo()
			return true
		if event.keycode == KEY_Y:
			redo()
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			finish_stroke()
			return true
		var hit: Variant = pick(event.position)
		if hit != null:
			data.begin_stroke()
			_level = hit.y
			_last_point = Vector2(hit.x,hit.z)
			if mode in ["tree","rock","flower","pond","mountain"]:
				if mode == "mountain":
					data.mountain(_last_point,mountain_radius,mountain_peak)
				elif mode == "pond":
					if not data.add_pond(_last_point,pond_level):
						_status.text = "Dig a hollow, then set water below its banks."
				else:
					if data.place(mode,_last_point,object_angle,object_scale) < 0:
						_status.text = "This garden has reached its object limit."
				if data.end_stroke():
					refresh()
			else:
				_painting = true
				dab(_last_point,strength/30.0)
				refresh()
		return true
	return false

func pick(mouse: Vector2) -> Variant:
	if scene._growth.terrain < 0.995:
		return null
	if not scene.get_viewport().get_visible_rect().has_point(mouse):
		return null
	for child in scene._ui.get_children():
		if child is Control and scene._ui.visible and child.is_visible_in_tree() and child.get_global_rect().has_point(mouse):
			return null
	var camera: Camera3D = scene.camera
	var origin := terrain.to_local(camera.project_ray_origin(mouse))
	var direction := terrain.global_basis.inverse()*camera.project_ray_normal(mouse)
	return data.ray_hit(origin,direction.normalized())

func _process(delta: float) -> void:
	if active:
		_sync_sky_controls()
	if not active:
		return
	if _painting and (not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or scene._growth.terrain < 0.995):
		finish_stroke()
	var hit: Variant = pick(scene.get_viewport().get_mouse_position()) if not scene._orbiting and not scene._panning else null
	_material.set_shader_parameter("brush_visible",hit != null)
	if hit != null:
		var center := Vector2(hit.x,hit.z)
		_material.set_shader_parameter("brush_center",center)
		_material.set_shader_parameter("brush_radius",mountain_radius if mode == "mountain" else radius)
		if _painting:
			_elapsed += minf(delta,0.05)
			if _elapsed >= 1.0/30.0:
				var previous: Vector2 = _last_point if _last_point != null else center
				var dabs := maxi(1,ceili(previous.distance_to(center)/(radius*0.15)))
				for i in range(1,dabs+1):
					dab(previous.lerp(center,float(i)/dabs),strength*_elapsed/dabs)
				refresh()
				_elapsed = 0.0
				_last_point = center
	else:
		_last_point = null
		_elapsed = 0.0

func finish_stroke() -> void:
	if not _painting:
		return
	_painting = false
	_elapsed = 0.0
	_last_point = null
	data.end_stroke()

func undo() -> void:
	finish_stroke()
	if data.undo():
		refresh()

func redo() -> void:
	finish_stroke()
	if data.redo():
		refresh()

func refresh() -> void:
	_status.text = "Garden changed · Save to keep your work."
	terrain.mesh = data.build_mesh()
	var original := data.heights == data.original_heights
	for entry in _anchors:
		if data.blank:
			continue
		var node: MultiMeshInstance3D = entry.node
		if original:
			node.multimesh = entry.source
			continue
		if node.multimesh == entry.source:
			node.multimesh = entry.source.duplicate()
		for i in range(entry.transforms.size()):
			var transform: Transform3D = entry.transforms[i]
			var world := node.to_global(transform.origin)
			var local := terrain.to_local(world)
			world.y += data.delta_at(Vector2(local.x,local.z))
			transform.origin = node.to_local(world)
			node.multimesh.set_instance_transform(i,transform)
	for node: VisualInstance3D in _source_visibility:
		node.visible = _source_visibility[node]
	for i in range(_boulder_anchors.size()):
		var rest := _boulder_anchors[i]
		rest.origin.y += data.delta_at(Vector2(rest.origin.x, rest.origin.z))
		scene._growth._boulders[i].rest = rest
	var landmark := _landmark_pose
	landmark.origin.y += data.delta_at(Vector2(landmark.origin.x, landmark.origin.z))
	scene._growth._landmark.transform = landmark
	scene._growth.publish()
	sync_visibility()
	_rebuild_skirt()
	content.rebuild()
	# Existing habitat/rain/fog consumers keep the same texture object.
	var image: Image = _original_ground_map.duplicate()
	for z in range(image.get_height()):
		for x in range(image.get_width()):
			if original and not data.blank:
				continue
			var point := (Vector2(x,z)+Vector2.ONE*0.5)/image.get_width()*32.0-Vector2.ONE*16.0
			var height: Variant = data.height_at(point.x,point.y)
			var value := Color(-1000,-1000,-1000,-1000) if data.blank else image.get_pixel(x,z)
			value.g = float(height) if height != null else -1000.0
			value.r = maxf(value.g,value.a)
			image.set_pixel(x,z,value)
	GardenSurfaceMap.paint_water(image,content.pond_vertices)
	scene._precipitation.ground_texture.update(image)
	var streams: Image = _original_stream_map.duplicate()
	if data.blank:
		streams.fill(Color(0,0,0,0))
	scene._precipitation.stream_texture.update(streams)
	scene._bigfoot.ground.setup(terrain)
	scene._bird_flight.ground = _original_bird_ground if original else data
	scene._atmosphere.update_ground_bounds(terrain,original)
	scene._precipitation.set_ceiling(_original_precip_top if original else scene._atmosphere._summit.y+5.0)
	if scene._display_fog != null:
		scene._display_fog.update_view()

func start_flat() -> void:
	finish_stroke()
	data.begin_stroke()
	data.reset_flat()
	data.end_stroke()
	refresh()

func _rebuild_skirt() -> void:
	if data.heights == data.original_heights:
		_skirt.mesh = _skirt_mesh
		return
	# Deform the original faceted earth sides, keeping their base and material.
	# The captured rim extends 0.2 units beyond the terrain's outer edge.
	var arrays := _skirt_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var low := _skirt_mesh.get_aabb().position.y
	var high := _skirt_mesh.get_aabb().end.y
	for i in range(vertices.size()):
		var world := _skirt.to_global(vertices[i])
		var local := terrain.to_local(world)
		var point := Vector2(local.x,local.z).clamp(Vector2(-14,-14),Vector2(14,14))
		vertices[i].y += data.delta_at(point) * clampf((vertices[i].y-low)/(high-low),0.0,1.0)
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3):
			normals[i+j] = normal
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,_skirt_mesh.surface_get_material(0))
	_skirt.mesh = mesh

func dab(point: Vector2, amount: float) -> void:
	match mode:
		"grass": data.paint_grass(point,radius,grass_amount)
		"meadow": data.paint_meadow(point,radius,amount)
		"erase":
			data.paint_grass(point,radius,0.0)
			data.paint_meadow(point,radius,-amount)
			data.erase_objects(point,radius)
		_: data.brush(point,radius,amount,mode,_level)

func save_garden() -> bool:
	finish_stroke()
	var document := data.to_document()
	document.scene_state = NativeGardenStore.capture(scene)
	var temporary := save_path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		_status.text = "Could not save. Your garden is still open."
		return false
	file.store_string(JSON.stringify(document,"",true,true))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or DirAccess.rename_absolute(temporary,save_path) != OK:
		_status.text = "Could not finish saving. Please try again."
		return false
	_status.text = "Garden saved."
	return true

func open_garden() -> bool:
	var file := FileAccess.open(save_path,FileAccess.READ)
	if file == null:
		_status.text = "No saved garden to open yet."
		return false
	if file.get_length() > 16000000:
		_status.text = "This garden file is too large to open."
		return false
	var document: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not document is Dictionary or not NativeGardenStore.valid(scene,document.get("scene_state")):
		_status.text = "Could not read this garden. Your open garden is unchanged."
		return false
	finish_stroke()
	if not data.load_document(document):
		_status.text = "This garden does not match the chunk. Your open garden is unchanged."
		return false
	refresh()
	NativeGardenStore.restore(scene,document.scene_state)
	_status.text = "Garden opened."
	return true

func sync_visibility() -> void:
	if data.blank:
		for node: VisualInstance3D in _source_visibility:
			node.visible = false
