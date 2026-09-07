extends Node3D
## Input and application state for the first sculpting study.

const SAVE_PATH := "user://landscape.json"
const TOOLS := ["raise", "lower", "smooth", "flatten"]

var mode := "raise"
var radius := 2.2
var strength := 2.0
var _painting := false
var _level := 0.0
var _dirty := false
var _hit: Variant = null
var _elapsed := 0.0
var _last_brush: Variant = null
var _status: Label
var _panel: PanelContainer
var _radius_slider: HSlider
var _buttons: Array[Button] = []

@onready var terrain: TerrainView = $Terrain
@onready var orbit: Node3D = $OrbitCamera
@onready var camera: Camera3D = $OrbitCamera/Camera3D

func _ready() -> void:
	_build_interface()
	if FileAccess.file_exists(SAVE_PATH):
		_load()
	get_tree().auto_accept_quit = false

func _process(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var on_ui := _panel.get_global_rect().has_point(mouse)
	var inside_window := get_viewport().get_visible_rect().has_point(mouse)
	_hit = null
	if not on_ui and inside_window and not orbit.navigating:
		_hit = terrain.ray_hit(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	var center := Vector2.ZERO
	if _hit != null:
		center = Vector2(_hit.x, _hit.z)
	terrain.show_brush(center, radius, _hit != null)
	if _painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_stroke()
	if _painting and _hit != null:
		# Limit mesh regeneration to 30 Hz while keeping brush speed time-based.
		_elapsed += minf(delta, 0.05)
		if _elapsed >= 1.0 / 30.0:
			var previous: Vector2 = _last_brush if _last_brush != null else center
			var dabs := maxi(1, int(ceil(previous.distance_to(center) / (radius * 0.15))))
			for i in range(1, dabs + 1):
				terrain.data.brush(previous.lerp(center, float(i) / dabs), radius, strength, _elapsed / dabs, mode, _level)
			terrain.rebuild()
			_elapsed = 0.0
			_last_brush = center
	elif _painting:
		# Re-entering the terrain should not paint across a gap or through the UI.
		_last_brush = null
		_elapsed = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _hit != null and not orbit.navigating:
			terrain.data.begin_stroke()
			_level = _hit.y
			_painting = true
			_elapsed = 0.0
			_last_brush = Vector2(_hit.x, _hit.z)
			# A quick click should make a dab even before the next render frame.
			terrain.data.brush(Vector2(_hit.x, _hit.z), radius, strength, 1.0 / 30.0, mode, _level)
			terrain.rebuild()
		elif not event.pressed:
			_finish_stroke()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed or event.meta_pressed:
			match event.keycode:
				KEY_Z:
					if event.shift_pressed:
						_redo()
					else:
						_undo()
				KEY_Y: _redo()
				KEY_S: _save()
		else:
			match event.keycode:
				KEY_1: _select_tool("raise")
				KEY_2: _select_tool("lower")
				KEY_3: _select_tool("smooth")
				KEY_4: _select_tool("flatten")
				KEY_BRACKETLEFT: _radius_slider.value -= 0.25
				KEY_BRACKETRIGHT: _radius_slider.value += 0.25

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_finish_stroke()
		if _dirty:
			_save()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_finish_stroke()
		if not _dirty or _save():
			get_tree().quit()

func _finish_stroke() -> void:
	if not _painting:
		return
	_painting = false
	_elapsed = 0.0
	_last_brush = null
	if terrain.data.end_stroke():
		_dirty = true
		_status.text = "Landscape changed · ⌘S to save"

func _select_tool(selected: String) -> void:
	_finish_stroke()
	mode = selected
	for i in range(_buttons.size()):
		_buttons[i].set_pressed_no_signal(TOOLS[i] == selected)
	var descriptions := {
		"raise": "Build hills with slow, gentle strokes.",
		"lower": "Press valleys and hollows into the land.",
		"smooth": "Soften slopes and blend your brushwork.",
		"flatten": "Level toward the height where you click.",
	}
	_status.text = descriptions[selected]

func _undo() -> void:
	_finish_stroke()
	if terrain.data.undo():
		terrain.rebuild()
		_dirty = true
		_status.text = "Undid one brushstroke."

func _redo() -> void:
	_finish_stroke()
	if terrain.data.redo():
		terrain.rebuild()
		_dirty = true
		_status.text = "Restored one brushstroke."

func _save() -> bool:
	_finish_stroke()
	# Write beside the previous save, then replace it only after a successful write.
	var temporary := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_status.text = "Could not save. Your landscape is still open."
		return false
	file.store_string(JSON.stringify(terrain.data.to_document()))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or DirAccess.rename_absolute(temporary, SAVE_PATH) != OK:
		_status.text = "Could not finish saving. Please try again."
		return false
	_dirty = false
	_status.text = "Landscape saved."
	return true

func _load() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null or not terrain.data.load_document(JSON.parse_string(file.get_as_text())):
		_status.text = "Saved landscape could not be read. Started fresh."
		return
	terrain.rebuild()
	_dirty = false
	_status.text = "Welcome back. Your landscape is here."

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(28, 28)
	_panel.custom_minimum_size = Vector2(290, 0)
	var panel_style := _style(Color("f0f0e3"), 16)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 20
	panel_style.shadow_color = Color(0.12, 0.18, 0.12, 0.12)
	panel_style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", panel_style)
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 15
	ui_theme.set_color("font_color", "Label", Color("39473b"))
	ui_theme.set_color("font_color", "Button", Color("39473b"))
	ui_theme.set_color("font_hover_color", "Button", Color("283a2c"))
	ui_theme.set_color("font_pressed_color", "Button", Color("ffffff"))
	ui_theme.set_stylebox("normal", "Button", _style(Color("e1e5d6"), 8))
	ui_theme.set_stylebox("hover", "Button", _style(Color("d2dbc4"), 8))
	ui_theme.set_stylebox("pressed", "Button", _style(Color("637e57"), 8))
	_panel.theme = ui_theme
	layer.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	var eyebrow := _label("L A N D S C A P E   S T U D Y   0 1", 11)
	eyebrow.modulate = Color("7a876f")
	column.add_child(eyebrow)
	column.add_child(_label("A little room to grow.", 24))
	var intro := _label("Shape a place, one brushstroke at a time.", 13)
	column.add_child(intro)
	column.add_child(HSeparator.new())
	var group := ButtonGroup.new()
	for i in range(TOOLS.size()):
		var tool: String = TOOLS[i]
		var button := _button("%d   %s" % [i + 1, tool.capitalize()])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == 0
		button.pressed.connect(_select_tool.bind(tool))
		column.add_child(button)
		_buttons.append(button)
	var radius_label := _label("Brush size   %.1f" % radius, 14)
	column.add_child(radius_label)
	_radius_slider = HSlider.new()
	_radius_slider.min_value = 0.75
	_radius_slider.max_value = 5.0
	_radius_slider.step = 0.05
	_radius_slider.value = radius
	_radius_slider.focus_mode = Control.FOCUS_NONE
	_radius_slider.custom_minimum_size.y = 20
	_radius_slider.value_changed.connect(func(value: float) -> void:
		radius = value
		radius_label.text = "Brush size   %.1f" % radius
	)
	column.add_child(_radius_slider)
	var strength_label := _label("Strength   %.1f" % strength, 14)
	column.add_child(strength_label)
	var strength_slider := HSlider.new()
	strength_slider.min_value = 0.3
	strength_slider.max_value = 5.0
	strength_slider.step = 0.1
	strength_slider.value = strength
	strength_slider.focus_mode = Control.FOCUS_NONE
	strength_slider.custom_minimum_size.y = 20
	strength_slider.value_changed.connect(func(value: float) -> void:
		strength = value
		strength_label.text = "Strength   %.1f" % strength
	)
	column.add_child(strength_slider)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	for action: Array in [["Undo", _undo], ["Redo", _redo], ["Save", _save]]:
		var button := _button(action[0])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(action[1])
		actions.add_child(button)
	column.add_child(actions)
	column.add_child(HSeparator.new())
	var help := _label("Drag to sculpt\nRight-drag to orbit · Scroll to zoom\nMiddle-drag to pan\n[ ] Brush size · ⌘Z Undo · ⌘S Save", 12)
	help.add_theme_constant_override("line_spacing", 5)
	help.modulate = Color("718069")
	column.add_child(help)
	_status = _label("Build hills with slow, gentle strokes.", 12)
	_status.custom_minimum_size = Vector2(258, 42)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 37
	button.focus_mode = Control.FOCUS_NONE
	return button

func _style(color: Color, corner: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(corner)
	box.content_margin_left = 12
	box.content_margin_right = 12
	return box
