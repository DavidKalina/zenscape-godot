extends Control
## The creation palette: one quiet glass strip at the bottom of the screen with
## the brushes genesis_canvas registers (`BRUSHES`, in order, keys 1-9), the size and
## strength of the brush in hand as two thin meters, and Look, which puts the
## brush away. A single line of how-to sits beneath and fades once you paint.
## The scene owns the state (`select_brush`, `set_looking`); the palette only
## shows it and asks.
const Glass = preload("res://scripts/glass_chrome.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const PAD := Vector2(10,8)
const LOOK_HINT := "Just looking  ·  drag to orbit  ·  P for a photo  ·  Tab or a brush to create again"
var scene: Node3D
var editor: NativeChunkEditor
## Normalised registry entries: brush_id, title, hint.
var entries: Array[Dictionary] = []
var buttons := {}
var look_button: Button
## Photo mode (scripts/photo_mode.gd), beside Look.
var photo_button: Button
var frame := Control.new()
var glass: Panel
var row := HBoxContainer.new()
var meters := VBoxContainer.new()
var size_bar := ProgressBar.new()
var strength_bar := ProgressBar.new()
var hint := Label.new()
var _hint_tween: Tween
var _painted := false
var _last_state := ""
## The land brush's forms (scripts/mountain_forms.gd FORMS), in a plain row
## over the strip while land is in hand. Built from the list, so a restyle
## only needs `_form_button`.
const Forms = preload("res://scripts/mountain_forms.gd")
var form_frame := Control.new()
var form_glass: Panel
var form_row := HBoxContainer.new()
var form_buttons := {}

## One registry entry (genesis_canvas.gd `BRUSHES`) as the palette shows it.
## Returns {} for an entry without an id.
static func brush_info(entry: Dictionary) -> Dictionary:
	var id := str(entry.get("brush_id",""))
	if id.is_empty(): return {}
	return {"brush_id":id,"title":str(entry.get("title",id.capitalize())),"hint":str(entry.get("hint",""))}

## Every registered brush, in palette order.
static func registered() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Dictionary in Genesis.BRUSHES:
		var info := brush_info(entry)
		if not info.is_empty(): found.append(info)
	return found

func brush_ids() -> Array:
	return entries.map(func(info: Dictionary) -> String: return info.brush_id)

func info_for(id: String) -> Dictionary:
	for info in entries:
		if info.brush_id == id: return info
	return {}

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	name = "CreationPalette"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	entries = registered()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	glass = Glass.surface(16)
	frame.add_child(glass)
	row.add_theme_constant_override("separation",2)
	row.position = PAD
	frame.add_child(row)
	for index in range(entries.size()):
		var info: Dictionary = entries[index]
		var button := _tool_button(info.title,Glass.glyph(info.brush_id,22))
		button.tooltip_text = info.title+(" · %d" % (index+1) if index < 9 else "")
		button.pressed.connect(func() -> void: scene.select_brush(info.brush_id))
		buttons[info.brush_id] = button
		row.add_child(button)
	row.add_child(_divider())
	meters.add_theme_constant_override("separation",7)
	meters.alignment = BoxContainer.ALIGNMENT_CENTER
	meters.custom_minimum_size.x = 64
	meters.mouse_filter = Control.MOUSE_FILTER_PASS
	meters.tooltip_text = "Brush size  [ ]\nStrength  Shift [ ]"
	for bar: ProgressBar in [size_bar,strength_bar]:
		var line := VBoxContainer.new()
		line.add_theme_constant_override("separation",2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var caption := Label.new()
		caption.text = "size" if bar == size_bar else "strength"
		caption.add_theme_font_size_override("font_size",10)
		caption.add_theme_color_override("font_color",Color(Glass.MUTED,0.8))
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(caption)
		_style_meter(bar)
		line.add_child(bar)
		meters.add_child(line)
	row.add_child(meters)
	row.add_child(_divider())
	look_button = _tool_button("Look",Glass.glyph("look",22))
	look_button.tooltip_text = "Put the brush away and just look · Tab"
	look_button.pressed.connect(func() -> void: scene.set_looking(not scene.looking))
	row.add_child(look_button)
	photo_button = _tool_button("Photo",preload("res://scripts/photo_mode.gd").glyph("camera",22))
	photo_button.toggle_mode = false
	photo_button.tooltip_text = "Compose and take a photo, with no UI · P"
	photo_button.pressed.connect(func() -> void: scene.enter_photo())
	row.add_child(photo_button)
	hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color(Glass.INK,0.72))
	hint.add_theme_color_override("font_shadow_color",Color("182628",0.8))
	hint.add_theme_constant_override("shadow_offset_y",1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	_build_forms()
	editor.setting_changed.connect(func(_property: String, _value: float) -> void: _sync_meters())
	editor.tool_changed.connect(func(_tool: String) -> void: sync())
	editor.brush_changed.connect(func(_id: String) -> void: sync())
	editor.active_changed.connect(func(_enabled: bool) -> void: sync())
	editor.stroke_finished.connect(func(_center: Vector3, _radius: float, _mode: String) -> void:
		if not _painted:
			_painted = true
			_fade_hint(2.5))
	get_viewport().size_changed.connect(fit)
	sync()
	fit.call_deferred()

func _tool_button(title: String, glyph: Texture2D) -> Button:
	var button := Button.new()
	button.text = title
	button.icon = glyph
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.custom_minimum_size = Vector2(62,56)
	button.add_theme_font_size_override("font_size",12)
	button.add_theme_constant_override("h_separation",3)
	Glass.button(button)
	return button

func _divider() -> Control:
	var line := VSeparator.new()
	var style := StyleBoxLine.new()
	style.vertical = true
	style.color = Color(Glass.INK,0.12)
	style.grow_begin = -10
	style.grow_end = -10
	line.add_theme_stylebox_override("separator",style)
	line.add_theme_constant_override("separation",14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _style_meter(bar: ProgressBar) -> void:
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.custom_minimum_size = Vector2(56,3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(Glass.INK,0.12)
	back.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(Glass.ACCENT,0.75)
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background",back)
	bar.add_theme_stylebox_override("fill",fill)

## The brush in hand, or "" while looking or crafting.
func held() -> String:
	if scene.looking or not editor.active: return ""
	var id := editor.held_brush()
	return id if buttons.has(id) else ""

func sync() -> void:
	var holding := held()
	for id: String in buttons:
		buttons[id].set_pressed_no_signal(id == holding)
	look_button.set_pressed_no_signal(scene.looking)
	meters.modulate.a = 1.0 if not holding.is_empty() else 0.35
	_sync_meters()
	_sync_forms(holding)
	var state := "look" if scene.looking else holding+("/"+editor.land_form if holding == "land" else "")
	if state == _last_state: return
	_last_state = state
	var text := LOOK_HINT
	if not scene.looking:
		var brush := info_for(holding)
		text = str(brush.get("hint",""))
		if holding == "land": text = str(Forms.form_entry(editor.land_form).get("hint",text))+"  ·  1 for forms"
		text = ("" if text.is_empty() else text+"  ·  ")+"[ ] size  ·  Tab to just look"
	hint.text = text
	hint.modulate.a = 1.0
	if _hint_tween != null: _hint_tween.kill()
	# Until the first stroke the how-to stays; after it, each change shows briefly.
	if _painted: _fade_hint(5.0)
	fit()

func _fade_hint(delay: float) -> void:
	if _hint_tween != null: _hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(delay)
	_hint_tween.tween_property(hint,"modulate:a",0.0,1.4)

## The size and strength of the brush in hand, or of the last one while looking.
func _sync_meters() -> void:
	var id := held() if not held().is_empty() else str(scene.get("brush") if scene.get("brush") != null else "")
	for pair: Array in [[size_bar,"size"],[strength_bar,"strength"]]:
		var setting := editor.brush_setting(id,pair[1])
		if setting.is_empty(): continue
		pair[0].value = inverse_lerp(setting.low,setting.high,setting.value)

func fit() -> void:
	if not is_inside_tree(): return
	var screen := get_viewport().get_visible_rect().size
	var factor := minf(1.0,minf(screen.x/1080.0,screen.y/720.0))
	row.size = row.get_combined_minimum_size()
	glass.size = row.size+PAD*2.0
	frame.size = glass.size
	frame.scale = Vector2.ONE*factor
	var hint_room := 34.0*factor
	frame.position = Vector2((screen.x-frame.size.x*factor)*0.5,screen.y-frame.size.y*factor-hint_room-14.0)
	form_row.size = form_row.get_combined_minimum_size()
	form_glass.size = form_row.size+PAD*2.0
	form_frame.size = form_glass.size
	form_frame.scale = Vector2.ONE*factor
	form_frame.position = Vector2((screen.x-form_frame.size.x*factor)*0.5,frame.position.y-(form_frame.size.y+6.0)*factor)
	hint.size = Vector2(screen.x,hint.get_minimum_size().y)
	hint.position = Vector2(0,screen.y-hint.size.y-14.0)

func contains_pointer(point: Vector2) -> bool:
	if form_frame.visible and is_visible_in_tree() and Rect2(form_frame.global_position,form_frame.size*form_frame.scale).has_point(point): return true
	return is_visible_in_tree() and Rect2(frame.global_position,frame.size*frame.scale).has_point(point)

func _build_forms() -> void:
	form_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(form_frame)
	form_glass = Glass.surface(12)
	form_frame.add_child(form_glass)
	form_row.add_theme_constant_override("separation",2)
	form_row.position = PAD
	form_frame.add_child(form_row)
	for entry: Dictionary in Forms.FORMS:
		var button := _form_button(entry)
		button.pressed.connect(func() -> void: editor.select_land_form(entry.id))
		form_buttons[entry.id] = button
		form_row.add_child(button)
	editor.land_form_changed.connect(func(_id: String) -> void: sync())

func _form_button(entry: Dictionary) -> Button:
	var button := _tool_button(entry.title,Glass.glyph(entry.glyph,18))
	button.custom_minimum_size = Vector2(52,44)
	button.add_theme_font_size_override("font_size",11)
	button.tooltip_text = entry.title+" · 1 steps through the forms"
	return button

func _sync_forms(holding: String) -> void:
	form_frame.visible = holding == "land"
	for id: String in form_buttons:
		form_buttons[id].set_pressed_no_signal(id == editor.land_form)
