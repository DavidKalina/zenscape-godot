class_name NativeBuildPanel
extends VBoxContainer
## The global widgets for the chunk editor: entering and leaving Build, the
## history and files, the status line and the sky. Every per-tool control lives
## on the build palette, which reads the same tool metadata off the editor.
var editor: NativeChunkEditor
var _tools := VBoxContainer.new()
var _toggle := Button.new()
var _status := Label.new()
var _sky_panel: VBoxContainer
var _sky_toggle: CheckButton
var _sky_controls := {}

## Take an editor that has already been set up and build its controls.
func attach(target: NativeChunkEditor) -> void:
	editor = target
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
