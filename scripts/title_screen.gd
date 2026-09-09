extends Control
## The Electron inscription and quiet desk, over the live Godot landscape.
## Actions and world ownership remain in diorama.gd.
const DISPLAY = preload("res://assets/fonts/newsreader-latin.woff2")
const READING = preload("res://assets/fonts/spectral-latin-400.woff2")
const MONO = preload("res://assets/fonts/IBMPlexMono-Regular.ttf")
var buttons: Array[Button] = []
var _frame := Control.new()
var _legend: Label
var _detail: Label
var _stem := ColorRect.new()
var _veil := ColorRect.new()
var _elapsed := 0.0
var _entrance: Tween
var _selected := 0
var _layout_factor := 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/title_scrim.gdshader")
	scrim.material = material
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.size = Vector2(1180,613)
	var inscription := FontVariation.new()
	inscription.base_font = DISPLAY
	inscription.variation_opentype = {"wght":500.0}
	inscription.spacing_glyph = 15
	var mark := _label("ZENSCAPE",inscription,58,Color("e3d7bd"),Vector2(0,77),Vector2(1180,80))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_color_override("font_color",Color.WHITE)
	var gilt := ShaderMaterial.new()
	gilt.shader = preload("res://shaders/title_gilt.gdshader")
	mark.material = gilt
	_rule(Vector2(390,64),Vector2(400,1),true)
	_rule(Vector2(390,160),Vector2(400,1),true)
	var small_caps := FontVariation.new()
	small_caps.base_font = DISPLAY
	small_caps.spacing_glyph = 3
	var tag := _label("A LITTLE WILDERNESS, MADE BY YOU",small_caps,12,Color("e6decda0"),Vector2(0,181),Vector2(1180,24))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rule(Vector2(130,290),Vector2(360,1),false)
	_stem.color = Color("e2d0aa")
	_stem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_stem)
	_legend = _label("↑ ↓  choose     ·     enter  select",MONO,11,Color("a8b4bebf"),Vector2(0,582),Vector2(1180,20))
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_veil.color = Color("0b0e12")
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.hide()
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()

func _label(text: String, font: Font, font_size: int, color: Color, at: Vector2, extent: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.25))
	label.add_theme_constant_override("shadow_offset_y",1)
	_frame.add_child(label)
	_track_layout(label, at, extent, font_size)
	return label

func _rule(at: Vector2, extent: Vector2, centered: bool) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("e2d0aa00"),Color("e2d0aa66"),Color("e2d0aa00")]) if centered else PackedColorArray([Color("e2e7ec38"),Color("e2e7ec00")])
	gradient.offsets = PackedFloat32Array([0,0.5,1]) if centered else PackedFloat32Array([0,1])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.height = 1
	var line := TextureRect.new()
	line.texture = texture
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.position = at
	line.size = extent
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(line)
	_track_layout(line, at, extent)

func add_action(text: String, detail: String, action: Callable) -> Button:
	var index := buttons.size()
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.position = Vector2(130,222 if index == 0 else 301+(index-1)*49)
	button.size = Vector2(430,38)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",READING)
	button.add_theme_font_size_override("font_size",22 if index == 0 else 18)
	for state in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_color_override("font_color",Color("e9eef2c9"))
	button.add_theme_color_override("font_hover_color",Color("f5f1e6"))
	button.add_theme_color_override("font_focus_color",Color("f5f1e6"))
	button.add_theme_color_override("font_disabled_color",Color("96a2ad55"))
	button.focus_entered.connect(func() -> void: _selected = index)
	button.pressed.connect(action)
	_frame.add_child(button)
	buttons.append(button)
	_track_layout(button, button.position, button.size, 22 if index == 0 else 18)
	if not detail.is_empty():
		_detail = _label(detail,MONO,10,Color("e2d0aaa6"),Vector2(130,263),Vector2(430,20))
	_layout()
	return button

func present(cover: bool) -> void:
	show()
	_legend.text = "↑ ↓  choose     ·     enter  select" + ("     ·     esc  back" if not cover else "")
	var row := 0
	for button in buttons:
		button.visible = not button.disabled
		if button.disabled: continue
		button.set_meta("design_position", Vector2(130,222 if row == 0 else 301+(row-1)*49))
		button.set_meta("design_font_size",22 if row == 0 else 18)
		if row == 0: button.grab_focus()
		row += 1
	_layout()
	_detail.text = "A little wilderness, waiting for you." if not buttons[0].disabled else "Make a little world of your own."
	if _entrance: _entrance.kill()
	modulate.a = 1.0
	_frame.modulate.a = 1.0
	_veil.hide()
	for control in _frame.get_children(): control.modulate.a = 1.0
	if cover:
		_veil.show()
		_veil.modulate.a = 1.0
		_entrance = create_tween().set_parallel(true)
		_entrance.tween_property(_veil,"modulate:a",0.0,1.4)
		for control in _frame.get_children():
			control.modulate.a = 0.0
			var at: Vector2 = control.get_meta("design_position",Vector2(0,222))
			var delay := 1.3 if control == _legend else 0.95 if at.y >= 222 else 0.0
			_entrance.tween_property(control,"modulate:a",1.0,1.2 if delay > 0 else 2.2).set_delay(delay)
		_entrance.chain().tween_callback(_veil.hide)

func _track_layout(control: Control, at: Vector2, extent: Vector2, font_size := 0) -> void:
	control.set_meta("design_position", at)
	control.set_meta("design_size", extent)
	control.set_meta("design_font_size", font_size)
	if font_size > 0:
		var font := control.get_theme_font("font")
		if font is FontVariation:
			control.set_meta("design_tracking", font.spacing_glyph)

func _layout() -> void:
	_layout_factor = minf(minf(size.x/1180.0,size.y/613.0),1.75)
	# Resize geometry and rasterize fonts at the final layout size. Scaling a
	# Control instead magnifies its cached glyphs, even on a native-pixel window.
	_frame.scale = Vector2.ONE
	_frame.size = (Vector2(1180,613)*_layout_factor).round()
	_frame.position = Vector2(roundf((size.x-_frame.size.x)*0.5),0)
	for control in _frame.get_children():
		if not control.has_meta("design_position"): continue
		control.position = (control.get_meta("design_position") * _layout_factor).round()
		var font_size: int = control.get_meta("design_font_size")
		if font_size > 0:
			control.add_theme_font_size_override("font_size",maxi(1,roundi(font_size*_layout_factor)))
			if control.has_meta("design_tracking"):
				control.get_theme_font("font").spacing_glyph = roundi(control.get_meta("design_tracking")*_layout_factor)
		control.size = (control.get_meta("design_size") * _layout_factor).round().max(Vector2.ONE)
		if control.material is ShaderMaterial:
			control.material.set_shader_parameter("glyph_scale", _layout_factor)
	# The inscription is anchored from the top; the key legend hugs the window foot.
	_legend.position.y = size.y - 38.0*_layout_factor
	_update_stem()

func _process(delta: float) -> void:
	if not visible or buttons.is_empty(): return
	_elapsed += delta
	_update_stem()
	_stem.modulate.a = 0.55+0.45*(sin(_elapsed*TAU/5.2)*0.5+0.5)

func _update_stem() -> void:
	if buttons.is_empty(): return
	var button := buttons[_selected]
	_stem.position = button.position+(Vector2(-20,4)*_layout_factor).round()
	_stem.size = Vector2(1,maxf(1.0,roundf(30*_layout_factor)))
