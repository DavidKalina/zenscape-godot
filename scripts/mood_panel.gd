extends Control
## The mood panel over the creation palette (M, or the palette's Mood): a row of
## mood chips, and a Customise drawer of the controls scripts/mood_look.gd
## lists. Widgets only; the moods, controls, options and swatches are all read
## from mood_look.gd, so a restyle replaces this file alone.
const Glass = preload("res://scripts/glass_chrome.gd")
const Mood = preload("res://scripts/mood_look.gd")
const PAD := Vector2(12,10)
const CHIP := Vector2i(40,40)
const GLYPH := '<circle cx="12" cy="12" r="8.5"/><path d="M12 3.5 A8.5 8.5 0 0 0 12 20.5 Z" fill="#ffffff" fill-opacity="0.55"/><path d="M4 9 H20 M3.6 15 H20.4" stroke-opacity="0.6"/>'
var scene: Node3D
var mood: Node
var frame := Control.new()
var glass: Panel
var body := VBoxContainer.new()
var chips := HBoxContainer.new()
var chip_buttons := {}
var status := Label.new()
var customise := Button.new()
var back := Button.new()
var drawer := VBoxContainer.new()
## Control id -> {dot: Button, buttons: {option id: Button}}.
var rows := {}
var color_tabs := {}
var swatch_row := HBoxContainer.new()
var picker := ColorPickerButton.new()
var color_dot: Button
var color_key := "grass"
var open := false
var _sync_time := 0.0
var _textures := {}
var _origin_chip := {}

static func glyph(size := 22) -> Texture2D:
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#ffffff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'+GLYPH+'</g></svg>',size/24.0)
	return ImageTexture.create_from_image(image)

## A rounded chip of horizontal bands, top to bottom.
static func chip_texture(colors: Array, size := CHIP) -> Texture2D:
	var image := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	var radius := 9.0
	for y in range(size.y):
		var color: Color = colors[mini(int(float(y)/size.y*colors.size()),colors.size()-1)]
		for x in range(size.x):
			var corner := Vector2(clampf(x+0.5,radius,size.x-radius),clampf(y+0.5,radius,size.y-radius))
			var alpha := clampf(radius+0.5-Vector2(x+0.5,y+0.5).distance_to(corner),0.0,1.0)
			image.set_pixel(x,y,Color(color,alpha))
	return ImageTexture.create_from_image(image)

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	mood = scene.mood_look
	name = "MoodPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	glass = Glass.surface(16)
	frame.add_child(glass)
	body.position = PAD
	body.add_theme_constant_override("separation",8)
	frame.add_child(body)
	chips.add_theme_constant_override("separation",6)
	body.add_child(chips)
	for id in [""]+Mood.mood_ids(): chips.add_child(_chip(id))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",8)
	body.add_child(line)
	_style(customise,"Customise")
	customise.toggle_mode = true
	customise.tooltip_text = "Season, time, weather, rock and colours. What you set stays through mood changes."
	customise.toggled.connect(func(on: bool) -> void:
		drawer.visible = on
		fit())
	line.add_child(customise)
	status.add_theme_font_size_override("font_size",12)
	status.add_theme_color_override("font_color",Color(Glass.MUTED,0.9))
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(status)
	_style(back,"Back to mood")
	back.tooltip_text = "Let every control follow the mood again"
	back.pressed.connect(func() -> void: mood.clear_pins())
	line.add_child(back)
	drawer.add_theme_constant_override("separation",6)
	drawer.hide()
	body.add_child(drawer)
	for control: Dictionary in Mood.CONTROLS:
		if control.id == "colors": _color_rows(control.title)
		else: _choice_row(control.id,control.title)
	mood.changed.connect(sync)
	get_viewport().size_changed.connect(fit)
	hide()
	sync()

func _style(button: Button, text: String) -> void:
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",12)
	Glass.button(button)

func _chip(id: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(CHIP)+Vector2(8,8)
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = Mood.mood_title(id)+"\n"+Mood.mood_description(id)
	Glass.button(button,Glass.ACCENT,12)
	button.pressed.connect(func() -> void: mood.choose(id))
	chip_buttons[id] = button
	return button

## The pin dot: lit while the control is pinned; pressing it lets it follow the mood.
func _dot() -> Button:
	var dot := Button.new()
	dot.text = "●"
	dot.flat = true
	dot.focus_mode = Control.FOCUS_NONE
	dot.custom_minimum_size = Vector2(16,0)
	dot.add_theme_font_size_override("font_size",9)
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color"]:
		dot.add_theme_color_override(state,Glass.ACCENT)
	dot.tooltip_text = "Set by you · click to follow the mood again"
	return dot

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 78
	label.add_theme_font_size_override("font_size",12)
	label.add_theme_color_override("font_color",Color(Glass.INK,0.8))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _choice_row(id: String, title: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation",2)
	drawer.add_child(line)
	var dot := _dot()
	dot.pressed.connect(func() -> void: mood.unpin(id))
	line.add_child(dot)
	line.add_child(_label(title))
	var buttons := {}
	for entry: Dictionary in Mood.options(id):
		var button := Button.new()
		_style(button,entry.title)
		button.toggle_mode = true
		button.custom_minimum_size.y = 26
		button.pressed.connect(func() -> void: mood.pin(id,entry.id))
		buttons[entry.id] = button
		line.add_child(button)
	rows[id] = {"dot":dot,"buttons":buttons}

func _color_rows(title: String) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation",2)
	drawer.add_child(tabs)
	color_dot = _dot()
	color_dot.pressed.connect(func() -> void: mood.unpin(color_key))
	tabs.add_child(color_dot)
	tabs.add_child(_label(title))
	for entry: Dictionary in Mood.COLORS:
		var button := Button.new()
		_style(button,entry.title)
		button.toggle_mode = true
		button.custom_minimum_size.y = 26
		button.pressed.connect(func() -> void:
			color_key = entry.id
			sync())
		color_tabs[entry.id] = button
		tabs.add_child(button)
	swatch_row.add_theme_constant_override("separation",6)
	var indent := Control.new()
	indent.custom_minimum_size.x = 96
	swatch_row.add_child(indent)
	drawer.add_child(swatch_row)
	for index in range(6):
		var swatch := Button.new()
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.custom_minimum_size = Vector2(30,30)
		Glass.button(swatch,Glass.ACCENT,8)
		swatch.pressed.connect(func() -> void:
			var colors := Mood.swatches(color_key)
			if index < colors.size(): mood.pin(color_key,colors[index]))
		swatch_row.add_child(swatch)
	picker.edit_alpha = false
	picker.focus_mode = Control.FOCUS_NONE
	picker.custom_minimum_size = Vector2(54,30)
	picker.tooltip_text = "Any colour"
	picker.color_changed.connect(func(c: Color) -> void: mood.pin(color_key,c.to_html(false),false))
	swatch_row.add_child(picker)

func toggle() -> void:
	set_open(not open)

func set_open(value: bool) -> void:
	open = value
	visible = open and _palette_shown()
	if visible:
		sync()
		fit()

func _palette_shown() -> bool:
	var palette: Control = scene.get("creation_palette")
	return palette != null and palette.is_visible_in_tree()

func sync() -> void:
	if scene == null: return
	for id: String in chip_buttons:
		var button: Button = chip_buttons[id]
		button.visible = id != "" or not mood.origin.is_empty()
		button.set_pressed_no_signal(id == mood.mood and not mood.origin.is_empty())
		if button.icon == null: button.icon = chip_texture(mood.chip_colors(id))
		elif id == "" and not is_same(_origin_chip,mood.origin):
			_origin_chip = mood.origin
			button.icon = chip_texture(mood.chip_colors(id))
	for id: String in rows:
		var current: String = mood.value(id)
		rows[id].dot.modulate.a = 1.0 if mood.pinned(id) else 0.0
		rows[id].dot.disabled = not mood.pinned(id)
		for option: String in rows[id].buttons:
			rows[id].buttons[option].set_pressed_no_signal(option == current)
	for key: String in color_tabs:
		var tab: Button = color_tabs[key]
		tab.set_pressed_no_signal(key == color_key)
		tab.text = Mood.COLORS[Mood.color_keys().find(key)].title+(" ●" if mood.pinned(key) else "")
	color_dot.modulate.a = 1.0 if mood.pinned(color_key) else 0.0
	color_dot.disabled = not mood.pinned(color_key)
	var swatches := Mood.swatches(color_key)
	var current_color: String = mood.value(color_key)
	for index in range(6):
		var swatch: Button = swatch_row.get_child(index+1)
		swatch.visible = index < swatches.size()
		if swatch.visible:
			var html: String = swatches[index]
			if not _textures.has(html): _textures[html] = chip_texture([Color(html)],Vector2i(22,22))
			swatch.icon = _textures[html]
			swatch.tooltip_text = "#"+html
			swatch.modulate = Color.WHITE if html == current_color else Color(1,1,1,0.8)
	if not picker.get_popup().visible: picker.color = Color(current_color)
	var title := Mood.mood_title(mood.mood)
	status.text = title+(" · %d set by you" % mood.pins.size() if not mood.pins.is_empty() else "")
	back.disabled = mood.pins.is_empty()
	fit()

func _process(delta: float) -> void:
	var shown := open and _palette_shown()
	if visible != shown:
		visible = shown
		if shown: sync()
	if not visible: return
	# Living weather and a turning day move under the panel.
	_sync_time += delta
	if _sync_time > 0.5:
		_sync_time = 0.0
		sync()

func fit() -> void:
	if not is_inside_tree(): return
	var screen := get_viewport().get_visible_rect().size
	var factor := minf(1.0,minf(screen.x/1080.0,screen.y/720.0))
	body.size = body.get_combined_minimum_size()
	glass.size = body.size+PAD*2.0
	frame.size = glass.size
	frame.scale = Vector2.ONE*factor
	var palette: Control = scene.get("creation_palette")
	var top: float = screen.y-120.0*factor
	if palette != null: top = palette.frame.position.y
	frame.position = Vector2((screen.x-frame.size.x*factor)*0.5,top-frame.size.y*factor-10.0)

func contains_pointer(point: Vector2) -> bool:
	return is_visible_in_tree() and Rect2(frame.global_position,frame.size*frame.scale).has_point(point)
