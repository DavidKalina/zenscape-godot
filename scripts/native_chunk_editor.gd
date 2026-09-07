class_name NativeChunkEditor
extends Node
## Build tools attached to the live fidelity scene. Entering Build never swaps
## the chunk, camera, environment or shader; only the controls become active.
const GROUPS := [
	["Sculpt",["raise","lower","smooth","flatten"]],
	["Landscape",["ground","range","mountain"]],
	["Cover",["grass","blades","meadow","erase"]],
	["Place",["tree","rock","flower","arch","bigfoot_tree","assets"]],
	["Water",["pond","waterfall"]],
]
const TOOL_TEXT := {
	"raise":"Build hills with slow, gentle strokes.",
	"lower":"Press valleys and hollows into the land.",
	"smooth":"Soften slopes and blend your brushwork.",
	"flatten":"Level toward the height where you click.",
	"ground":"Set a resting height, then form the whole floor.",
	"range":"Shape a ridge across the chunk, then fill its water and flora.",
	"mountain":"Click to raise a peak. Variation reshuffles its ridges.",
	"grass":"Paint ground cover, or green the whole chunk at once.",
	"blades":"Paint standing blades over the grass.",
	"meadow":"Paint grass and wildflowers together.",
	"erase":"Brush away cover and placed objects. Undo restores them.",
	"tree":"Click to plant a tree. It settles onto the ground.",
	"rock":"Click to set a stone.",
	"flower":"Click to plant one flower. Zoom in for the detail.",
	"arch":"Click to raise a stone arch.",
	"bigfoot_tree":"Click to plant the tree Bigfoot visits.",
	"assets":"Pick a piece below, then click to place it.",
	"pond":"Dig a hollow, then click inside to fill it.",
	"waterfall":"Click the waterfall lip, then a lower landing point.",
}
var scene: Node3D
var terrain: MeshInstance3D
var data := NativeTerrainData.new()
var content: GardenView
var landmarks: NativeGardenLandmarks
var falls: NativeGardenFalls
var _fall_start: Variant = null
var catalog_asset := "broadleaf"
var object_heading := 0.0
var pond_level := -0.15
var object_angle := 0.0
var custom_tint := false
var object_tint := Color("7fb069")
var object_scale := 1.0
var object_width := 1.0
var object_height := 1.0
var object_depth := 1.0
var object_pitch := 0.0
var object_roll := 0.0
var object_elevation := 0.0
var save_path := "user://native-garden.json"
var active := false
var mode := "raise"
var radius := 2.2
var strength := 2.0
var ground_elevation := 0.0
var ground_relief := 1.0
var grass_amount := 1.0
var blade_amount := 0.35
var range_height := 1.0
var range_width := 1.0
var range_heading := 0.0
var range_variation := 0
var mountain_radius := 9.0
var mountain_variation := 7
var mountain_heading := 0.0
var mountain_peak := 9.0
var _tool_settings := {}
var _tool_buttons := {}
var _settings := {}
var _sky_panel: VBoxContainer
var _sky_toggle: CheckButton
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
	landmarks = NativeGardenLandmarks.new()
	landmarks.name = "AuthoredLandmarks"
	scene.add_child(landmarks)
	falls = NativeGardenFalls.new()
	falls.name = "AuthoredFalls"
	scene.add_child(falls)
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
	var group := ButtonGroup.new()
	for entry: Array in GROUPS:
		var row := _section(entry[0])
		for tool: String in entry[1]:
			var button := Button.new()
			button.text = "Bigfoot tree" if tool == "bigfoot_tree" else tool.capitalize()
			button.toggle_mode = true
			button.button_group = group
			button.button_pressed = tool == mode
			button.focus_mode = Control.FOCUS_NONE
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(select_tool.bind(tool))
			row.add_child(button)
			_tool_buttons[tool] = button
	var asset_picker := OptionButton.new()
	asset_picker.name = "AssetPicker"
	asset_picker.focus_mode = Control.FOCUS_NONE
	for kind in preload("res://scripts/native_asset_catalog.gd").PARTS:
		asset_picker.add_item(kind.replace("_"," ").capitalize())
		asset_picker.set_item_metadata(asset_picker.item_count-1,kind)
	asset_picker.item_selected.connect(func(index: int): catalog_asset = asset_picker.get_item_metadata(index))
	_tools.add_child(asset_picker)
	_tool_settings[asset_picker] = ["assets"]
	_setting("ground_elevation","Ground elevation",-1.0,8.0,0.1,["ground"])
	_setting("ground_relief","Ground relief",0.0,3.0,0.05,["ground"])
	var foundation := Button.new()
	foundation.text = "Form ground foundation"
	foundation.focus_mode = Control.FOCUS_NONE
	foundation.pressed.connect(form_foundation)
	_tools.add_child(foundation)
	_tool_settings[foundation] = ["ground"]
	_setting("radius","Brush size",0.4,5.0,0.05,["raise","lower","smooth","flatten","grass","blades","meadow","erase","pond"])
	_setting("strength","Strength",0.4,5.0,0.05,["raise","lower","smooth","flatten","meadow","erase"])
	_setting("grass_amount","Ground coverage",0.0,1.0,0.05,["grass"])
	_setting("blade_amount","Blade density",0.0,1.0,0.05,["blades"])
	var cover := Button.new()
	cover.text = "Cover chunk in grass"
	cover.focus_mode = Control.FOCUS_NONE
	cover.pressed.connect(cover_grass)
	_tools.add_child(cover)
	_tool_settings[cover] = ["grass"]
	var clear_blades := Button.new()
	clear_blades.text = "Remove Blades-tool patches"
	clear_blades.focus_mode = Control.FOCUS_NONE
	clear_blades.pressed.connect(func() -> void:
		finish_stroke()
		data.begin_stroke()
		data.blades.fill(0.0)
		data.end_stroke()
		refresh()
	)
	_tools.add_child(clear_blades)
	_tool_settings[clear_blades] = ["blades"]
	_setting("range_height","Range height",0.1,1.8,0.05,["range"])
	_setting("range_width","Range width",0.3,1.5,0.05,["range"])
	_setting("range_heading","Range rotation",-180.0,180.0,5.0,["range"],"°")
	_setting("range_variation","Range variation",0.0,999.0,1.0,["range"],"",true)
	var range_button := Button.new()
	range_button.text = "Form mountain landscape"
	range_button.focus_mode = Control.FOCUS_NONE
	range_button.pressed.connect(form_range)
	_tools.add_child(range_button)
	_tool_settings[range_button] = ["range"]
	var stream_button:=Button.new()
	stream_button.name="FillLandscapeStreams"
	stream_button.text="Fill landscape streams"
	stream_button.focus_mode=Control.FOCUS_NONE
	stream_button.pressed.connect(fill_landscape_streams)
	_tools.add_child(stream_button)
	_tool_settings[stream_button]=["range"]
	var fall_button:=Button.new()
	fall_button.name="FillLandscapeWaterfall"
	fall_button.text="Fill landscape waterfall"
	fall_button.focus_mode=Control.FOCUS_NONE
	fall_button.pressed.connect(fill_landscape_waterfall)
	_tools.add_child(fall_button)
	_tool_settings[fall_button]=["range"]
	var flora_button:=Button.new()
	flora_button.name="PopulateLandscapeFlora"
	flora_button.text="Populate landscape flora"
	flora_button.focus_mode=Control.FOCUS_NONE
	flora_button.pressed.connect(fill_landscape_flora)
	_tools.add_child(flora_button)
	_tool_settings[flora_button]=["range"]
	_setting("mountain_radius","Mountain base radius",1.0,12.0,0.5,["mountain"])
	_setting("mountain_peak","Peak height",0.5,24.0,0.5,["mountain"])
	_setting("mountain_variation","Variation",1.0,999.0,1.0,["mountain"],"",true)
	_setting("mountain_heading","Ridge rotation",-180.0,180.0,5.0,["mountain"],"°")
	_setting("pond_level","Pond surface height",-1.4,12.0,0.05,["pond"])
	_setting("object_scale","Object size",0.1,5.0,0.1,NativeTerrainData.ASSETS+["assets"])
	_setting("object_heading","Rotation",-180.0,180.0,5.0,["tree","rock","flower","arch","bigfoot_tree","assets"],"°")
	var color_row := HBoxContainer.new()
	var use_color := CheckBox.new()
	use_color.text = "Custom color"
	use_color.focus_mode = Control.FOCUS_NONE
	use_color.toggled.connect(func(enabled: bool): custom_tint = enabled)
	color_row.add_child(use_color)
	var tint_picker := ColorPickerButton.new()
	tint_picker.name = "PlacementColor"
	tint_picker.color = object_tint
	tint_picker.edit_alpha = false
	tint_picker.custom_minimum_size = Vector2(84,0)
	tint_picker.color_changed.connect(func(color: Color):
		object_tint = color
		use_color.button_pressed = true
	)
	color_row.add_child(tint_picker)
	_tools.add_child(color_row)
	_tool_settings[color_row] = ["tree","flower","rock","assets"]
	var pose_tools := ["tree","flower","rock","assets"]
	_setting("object_width","Width",0.25,3.0,0.05,pose_tools)
	_setting("object_height","Height",0.25,3.0,0.05,pose_tools)
	_setting("object_depth","Depth",0.25,3.0,0.05,pose_tools)
	_setting("object_pitch","Tilt forward",-90.0,90.0,5.0,pose_tools,"°")
	_setting("object_roll","Tilt sideways",-90.0,90.0,5.0,pose_tools,"°")
	_setting("object_elevation","Vertical offset",-5.0,10.0,0.05,pose_tools)
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
	_status.text = "Left drag paints · Click places · Right drag orbits\n1-4 tools · [ ] brush size · Shift [ ] strength"
	_status.add_theme_font_size_override("font_size",12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0,34)
	_tools.add_child(_status)

func _section(title: String) -> GridContainer:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size",11)
	label.add_theme_color_override("font_color",Color("8fa694"))
	_tools.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 4
	_tools.add_child(grid)
	return grid

## Continuous settings read as a slider under a label that carries the value;
## seeds stay whole numbers on a spin box.
func _setting(property: String, title: String, low: float, high: float, step: float, modes: Array, unit := "", whole := false) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",1)
	var label := Label.new()
	label.add_theme_font_size_override("font_size",12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value: Range
	if whole:
		value = SpinBox.new()
		var row := HBoxContainer.new()
		row.add_child(label)
		row.add_child(value)
		box.add_child(row)
	else:
		value = HSlider.new()
		value.focus_mode = Control.FOCUS_NONE
		box.add_child(label)
		box.add_child(value)
	value.min_value = low
	value.max_value = high
	value.step = step
	value.value = get(property)
	_settings[property] = {"control":value,"label":label,"title":title,"unit":unit,"whole":whole}
	value.value_changed.connect(func(number: float) -> void:
		set(property,number)
		if property == "object_heading":
			object_angle = deg_to_rad(object_heading)
		_show_setting(property)
	)
	_show_setting(property)
	_tools.add_child(box)
	_tool_settings[box] = modes

func _show_setting(property: String) -> void:
	var entry: Dictionary = _settings[property]
	var number := float(get(property))
	var text: String = "%d" % roundi(number) if entry.whole or entry.unit == "°" else String.num(number,2)
	entry.label.text = entry.title if entry.whole else "%s · %s%s" % [entry.title,text,entry.unit]

## Nudge a setting from a hotkey; the control keeps label and property in step.
func set_setting(property: String, number: float) -> void:
	if _settings.has(property):
		_settings[property].control.value = number
	else:
		set(property,number)

func select_tool(tool: String) -> void:
	finish_stroke()
	_fall_start = null
	mode = tool
	for name: String in _tool_buttons:
		_tool_buttons[name].set_pressed_no_signal(name == tool)
	if TOOL_TEXT.has(tool):
		_status.text = TOOL_TEXT[tool]
	_update_tool_settings()

func _update_tool_settings() -> void:
	for control: Control in _tool_settings:
		control.visible = mode in _tool_settings[control]

## Radius the terrain shader should draw for the tool in hand.
func preview_radius() -> float:
	if mode == "mountain":
		return mountain_radius
	if mode == "flower":
		return 0.15*object_scale
	if mode in NativeTerrainData.ASSETS or mode == "assets":
		return 0.6*object_scale
	return radius

## The circle only reads truthfully where a footprint exists.
func preview_wanted() -> bool:
	if mode == "assets":
		return false
	return mode != "waterfall" or _fall_start == null

func cover_grass() -> void:
	finish_stroke()
	data.begin_stroke()
	data.grass.fill(grass_amount)
	data.end_stroke()
	refresh()

func _build_sky_controls() -> void:
	var toggle := CheckButton.new()
	toggle.text = "Sky & weather · K"
	toggle.focus_mode = Control.FOCUS_NONE
	_sky_toggle = toggle
	_tools.add_child(toggle)
	var sky := VBoxContainer.new()
	sky.visible = false
	_sky_panel = sky
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
	_fall_start = null
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
	if event is InputEventKey and event.pressed and not event.ctrl_pressed and not event.meta_pressed:
		var tools := {KEY_1:"raise",KEY_2:"lower",KEY_3:"smooth",KEY_4:"flatten"}
		if tools.has(event.keycode) and not event.echo:
			select_tool(tools[event.keycode])
			return true
		if event.keycode in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
			var step := 0.25 if event.keycode == KEY_BRACKETRIGHT else -0.25
			var property := "strength" if event.shift_pressed else "radius"
			set_setting(property,get(property)+step)
			return true
		if event.keycode == KEY_K and not event.echo and _sky_toggle != null:
			_sky_toggle.button_pressed = not _sky_toggle.button_pressed
			return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			finish_stroke()
			return true
		var hit: Variant = pick(event.position)
		if hit != null:
			if mode == "waterfall":
				var point := Vector2(hit.x,hit.z)
				if _fall_start == null:
					_fall_start = point
					_status.text = "Now click the lower landing point. Change tools to cancel."
				else:
					data.begin_stroke()
					var placed := data.add_waterfall(_fall_start,point,object_scale)
					data.end_stroke()
					if placed:
						_fall_start = null
						refresh()
					else:
						_status.text = "Choose a lower landing with no ridge blocking the drop."
				return true
			data.begin_stroke()
			_level = hit.y
			_last_point = Vector2(hit.x,hit.z)
			if mode in NativeTerrainData.ASSETS or mode in ["pond","mountain","assets"]:
				if mode == "mountain":
					data.mountain(_last_point,mountain_radius,mountain_peak,mountain_variation,deg_to_rad(mountain_heading))
				elif mode == "pond":
					if not data.add_pond(_last_point,pond_level):
						_status.text = "Dig a hollow, then set water below its banks."
				else:
					if data.place(catalog_asset if mode == "assets" else mode,_last_point,object_angle,object_scale,_placement_pose(),preload("res://scripts/native_object_pose.gd").encode_tint(object_tint.srgb_to_linear()) if custom_tint and mode in ["tree","flower","rock","assets"] else "") < 0:
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
	_material.set_shader_parameter("brush_visible",hit != null and preview_wanted())
	if hit != null:
		var center := Vector2(hit.x,hit.z)
		_material.set_shader_parameter("brush_center",center)
		_material.set_shader_parameter("brush_radius",preview_radius())
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
	_fall_start = null
	finish_stroke()
	if data.undo():
		refresh()

func redo() -> void:
	_fall_start = null
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
	landmarks.rebuild(data)
	falls.rebuild(data)
	var fall_count := 0
	for item: Dictionary in data.objects:
		if item.asset == "waterfall":
			fall_count += 1
	if falls.get_child_count()/2 < fall_count:
		_status.text = "A waterfall is blocked or submerged. Lower the obstruction or undo."
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
	var streams: Image = _original_stream_map.duplicate()
	if data.blank:
		streams.fill(Color(0,0,0,0))
	GardenSurfaceMap.paint_streams(image,streams,content._stream_nodes)
	scene._precipitation.ground_texture.update(image)
	scene._precipitation.stream_texture.update(streams)
	scene._bigfoot.ground.setup(terrain)
	var encounter_pose: Variant = null
	for item: Dictionary in data.objects:
		if item.asset == "bigfoot_tree":
			encounter_pose = Transform3D(Basis(Vector3.UP,item.angle).scaled(Vector3.ONE*item.scale),data.object_position(item))
			break
	scene._bigfoot.set_authored_tree(encounter_pose)
	scene._bird_flight.ground = _original_bird_ground if original else data
	scene._atmosphere.update_ground_bounds(terrain,original)
	scene._precipitation.set_ceiling(_original_precip_top if original else scene._atmosphere._summit.y+5.0)
	if scene._display_fog != null:
		scene._display_fog.update_view()

func _placement_pose() -> Dictionary:
	if mode not in ["tree","flower","rock","assets"] or (object_width == 1.0 and object_height == 1.0 and object_depth == 1.0 and object_pitch == 0.0 and object_roll == 0.0 and object_elevation == 0.0):
		return {}
	var basis := Basis.from_euler(Vector3(deg_to_rad(object_pitch),object_angle,deg_to_rad(object_roll)))
	basis = basis.scaled_local(Vector3(object_width,object_height,object_depth)*object_scale)
	return preload("res://scripts/native_object_pose.gd").make(basis,object_elevation)

func form_range() -> void:
	finish_stroke()
	_fall_start = null
	data.begin_stroke()
	data.form_range(range_height,range_width,deg_to_rad(range_heading),range_variation)
	data.end_stroke()
	refresh()
	_status.text = "Mountain landscape formed, including basin and stream beds. Paint and place to dress it."

func form_foundation() -> void:
	finish_stroke()
	_fall_start = null
	data.begin_stroke()
	data.form_foundation(ground_elevation,ground_relief)
	data.end_stroke()
	refresh()
	_status.text = "Ground formed. Grass paints its surface; sculpting changes its height."

func start_flat() -> void:
	_fall_start = null
	finish_stroke()
	data.begin_stroke()
	data.reset_flat()
	data.end_stroke()
	refresh()

func _rebuild_skirt() -> void:
	var rim_unchanged := true
	for i in range(data.points.size()):
		var point := data.points[i]
		if maxf(absf(point.x),absf(point.y)) > 13.9999 and data.heights[i] != data.original_heights[i]:
			rim_unchanged = false
			break
	if rim_unchanged:
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
		"blades": data.paint_blades(point,radius,blade_amount)
		"meadow": data.paint_meadow(point,radius,amount)
		"erase":
			data.paint_grass(point,radius,0.0)
			data.paint_blades(point,radius,0.0)
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
	_fall_start = null
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

func fill_landscape_streams() -> void:
	finish_stroke()
	data.begin_stroke()
	var accepted:=data.fill_landscape_streams()
	data.end_stroke()
	if accepted:
		refresh()
		_status.text="Landscape streams filled. Save preserves their courses."
	else:
		_status.text="Form a mountain landscape first; its stream must fit inside the chunk."

func fill_landscape_flora() -> void:
	finish_stroke()
	data.begin_stroke()
	var accepted: bool=data.fill_landscape_flora()
	data.end_stroke()
	if accepted:
		refresh()
		_status.text="Landscape flora populated. Save preserves every plant, log and boulder."
	else:
		_status.text="Form a mountain landscape first."

func fill_landscape_waterfall() -> void:
	finish_stroke()
	data.begin_stroke()
	var accepted:=data.fill_landscape_waterfall()
	data.end_stroke()
	if accepted:
		refresh()
		_status.text="Landscape waterfall filled. Save preserves it."
	else:
		_status.text="Form a mountain landscape first."
