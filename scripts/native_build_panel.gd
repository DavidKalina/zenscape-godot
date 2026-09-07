class_name NativeBuildPanel
extends VBoxContainer
## The widgets for the chunk editor. The panel owns every control and reads the
## tool metadata off the editor; the editor keeps the tool logic and reports
## every state change back through its signals.
var editor: NativeChunkEditor
var _tools := VBoxContainer.new()
var _toggle := Button.new()
var _status := Label.new()
var _tool_buttons := {}
var _settings := {}
var _tool_settings := {}
var _sky_panel: VBoxContainer
var _sky_toggle: CheckButton
var _sky_controls := {}

## Take an editor that has already been set up and build its controls.
func attach(target: NativeChunkEditor) -> void:
	editor = target
	editor.tool_changed.connect(_on_tool_changed)
	editor.setting_changed.connect(_on_setting_changed)
	editor.status_changed.connect(_on_status_changed)
	editor.active_changed.connect(_on_active_changed)
	editor.sky_toggle_requested.connect(_on_sky_toggle_requested)
	_build_controls()

func _build_controls() -> void:
	_toggle.text = "Build this chunk"
	_toggle.toggle_mode = true
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.toggled.connect(editor.set_active)
	add_child(_toggle)
	add_child(_tools)
	_tools.visible = false
	var flat := Button.new()
	flat.text = "Start flat · clear this chunk"
	flat.focus_mode = Control.FOCUS_NONE
	flat.pressed.connect(editor.start_flat)
	_tools.add_child(flat)
	var group := ButtonGroup.new()
	for entry: Array in editor.tool_groups():
		var row := _section(entry[0])
		for tool: String in entry[1]:
			var button := Button.new()
			button.text = "Bigfoot tree" if tool == "bigfoot_tree" else tool.capitalize()
			button.toggle_mode = true
			button.button_group = group
			button.button_pressed = tool == editor.mode
			button.focus_mode = Control.FOCUS_NONE
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(editor.select_tool.bind(tool))
			row.add_child(button)
			_tool_buttons[tool] = button
	var asset_picker := OptionButton.new()
	asset_picker.name = "AssetPicker"
	asset_picker.focus_mode = Control.FOCUS_NONE
	for kind in preload("res://scripts/native_asset_catalog.gd").PARTS:
		asset_picker.add_item(kind.replace("_"," ").capitalize())
		asset_picker.set_item_metadata(asset_picker.item_count-1,kind)
	asset_picker.item_selected.connect(func(index: int): editor.catalog_asset = asset_picker.get_item_metadata(index))
	_tools.add_child(asset_picker)
	_tool_settings[asset_picker] = ["assets"]
	_setting("ground_elevation")
	_setting("ground_relief")
	var foundation := Button.new()
	foundation.text = "Form ground foundation"
	foundation.focus_mode = Control.FOCUS_NONE
	foundation.pressed.connect(editor.form_foundation)
	_tools.add_child(foundation)
	_tool_settings[foundation] = ["ground"]
	_setting("radius")
	_setting("strength")
	_setting("grass_amount")
	_setting("blade_amount")
	_setting("paint_amount")
	var paint_row := HBoxContainer.new()
	var paint_label := Label.new()
	paint_label.text = "Paint colour"
	paint_row.add_child(paint_label)
	var paint_picker := ColorPickerButton.new()
	paint_picker.name = "PaintColor"
	paint_picker.color = editor.paint_color
	paint_picker.edit_alpha = false
	paint_picker.custom_minimum_size = Vector2(84,0)
	paint_picker.color_changed.connect(func(color: Color): editor.paint_color = color)
	paint_row.add_child(paint_picker)
	_tools.add_child(paint_row)
	_tool_settings[paint_row] = ["paint"]
	var cover := Button.new()
	cover.text = "Cover chunk in grass"
	cover.focus_mode = Control.FOCUS_NONE
	cover.pressed.connect(editor.cover_grass)
	_tools.add_child(cover)
	_tool_settings[cover] = ["grass"]
	var clear_blades := Button.new()
	clear_blades.text = "Remove Blades-tool patches"
	clear_blades.focus_mode = Control.FOCUS_NONE
	clear_blades.pressed.connect(editor.clear_blades)
	_tools.add_child(clear_blades)
	_tool_settings[clear_blades] = ["blades"]
	_setting("range_height")
	_setting("range_width")
	_setting("range_heading")
	_setting("range_variation")
	var range_button := Button.new()
	range_button.text = "Form mountain landscape"
	range_button.focus_mode = Control.FOCUS_NONE
	range_button.pressed.connect(editor.form_range)
	_tools.add_child(range_button)
	_tool_settings[range_button] = ["range"]
	var stream_button:=Button.new()
	stream_button.name="FillLandscapeStreams"
	stream_button.text="Fill landscape streams"
	stream_button.focus_mode=Control.FOCUS_NONE
	stream_button.pressed.connect(editor.fill_landscape_streams)
	_tools.add_child(stream_button)
	_tool_settings[stream_button]=["range"]
	var fall_button:=Button.new()
	fall_button.name="FillLandscapeWaterfall"
	fall_button.text="Fill landscape waterfall"
	fall_button.focus_mode=Control.FOCUS_NONE
	fall_button.pressed.connect(editor.fill_landscape_waterfall)
	_tools.add_child(fall_button)
	_tool_settings[fall_button]=["range"]
	var flora_button:=Button.new()
	flora_button.name="PopulateLandscapeFlora"
	flora_button.text="Populate landscape flora"
	flora_button.focus_mode=Control.FOCUS_NONE
	flora_button.pressed.connect(editor.fill_landscape_flora)
	_tools.add_child(flora_button)
	_tool_settings[flora_button]=["range"]
	_setting("mountain_radius")
	_setting("mountain_peak")
	_setting("mountain_variation")
	_setting("mountain_heading")
	_setting("pond_level")
	_setting("object_scale")
	_setting("object_heading")
	var color_row := HBoxContainer.new()
	var use_color := CheckBox.new()
	use_color.text = "Custom color"
	use_color.focus_mode = Control.FOCUS_NONE
	use_color.toggled.connect(func(enabled: bool): editor.custom_tint = enabled)
	color_row.add_child(use_color)
	var tint_picker := ColorPickerButton.new()
	tint_picker.name = "PlacementColor"
	tint_picker.color = editor.object_tint
	tint_picker.edit_alpha = false
	tint_picker.custom_minimum_size = Vector2(84,0)
	tint_picker.color_changed.connect(func(color: Color):
		editor.object_tint = color
		use_color.button_pressed = true
	)
	color_row.add_child(tint_picker)
	_tools.add_child(color_row)
	_tool_settings[color_row] = ["tree","flower","rock","assets"]
	_setting("object_width")
	_setting("object_height")
	_setting("object_depth")
	_setting("object_pitch")
	_setting("object_roll")
	_setting("object_elevation")
	_update_tool_settings()
	var history := HBoxContainer.new()
	for entry: Array in [["Undo",editor.undo],["Redo",editor.redo],["Save",editor.save_garden],["Open",editor.open_garden]]:
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
## seeds stay whole numbers on a spin box. Every bound comes from the editor.
func _setting(property: String) -> void:
	var spec := editor.setting_spec(property)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",1)
	var label := Label.new()
	label.add_theme_font_size_override("font_size",12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value: Range
	if spec.whole:
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
	value.min_value = spec.low
	value.max_value = spec.high
	value.step = spec.step
	value.value = editor.get(property)
	_settings[property] = {"control":value,"label":label,"title":spec.title,"unit":spec.unit,"whole":spec.whole}
	value.value_changed.connect(func(number: float) -> void: editor.set_setting(property,number))
	_show_setting(property)
	_tools.add_child(box)
	_tool_settings[box] = spec.modes

func _show_setting(property: String) -> void:
	var entry: Dictionary = _settings[property]
	var number := float(editor.get(property))
	var text: String = "%d" % roundi(number) if entry.whole or entry.unit == "°" else String.num(number,2)
	entry.label.text = entry.title if entry.whole else "%s · %s%s" % [entry.title,text,entry.unit]

func _update_tool_settings() -> void:
	for control: Control in _tool_settings:
		control.visible = editor.mode in _tool_settings[control]

func _on_tool_changed(tool: String) -> void:
	for name: String in _tool_buttons:
		_tool_buttons[name].set_pressed_no_signal(name == tool)
	_update_tool_settings()

func _on_setting_changed(property: String, value: float) -> void:
	if not _settings.has(property):
		return
	_settings[property].control.set_value_no_signal(value)
	_show_setting(property)

func _on_status_changed(text: String) -> void:
	_status.text = text

func _on_active_changed(enabled: bool) -> void:
	_toggle.set_pressed_no_signal(enabled)
	_toggle.text = "Inspect this chunk" if enabled else "Build this chunk"
	_tools.visible = enabled

func _on_sky_toggle_requested() -> void:
	_sky_toggle.button_pressed = not _sky_toggle.button_pressed

func _build_sky_controls() -> void:
	var scene: Node3D = editor.scene
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
	var scene: Node3D = editor.scene
	_sky_controls.weather.select(scene._precipitation.preset_index)
	_sky_controls.time.set_value_no_signal(scene._celestial.phase)
	_sky_controls.clouds.set_value_no_signal(scene._precipitation.cloud_override if scene._precipitation.cloud_override >= 0.0 else scene._celestial.cloud)
	_sky_controls.fog.set_value_no_signal(scene._atmosphere._fog_target)

func _process(_delta: float) -> void:
	if editor != null and editor.active:
		_sync_sky_controls()
