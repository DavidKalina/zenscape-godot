extends Control
## The creation palette: one quiet glass strip at the bottom of the screen with
## the brushes genesis_canvas registers (in order, keys 1-9), the size and
## strength of the brush in hand as two thin meters, and Look, which puts the
## brush away. A single line of how-to sits beneath and fades once you paint.
## The scene owns the state (`select_brush`, `set_looking`); the palette only
## shows it and asks.
const Glass = preload("res://scripts/glass_chrome.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const PAD := Vector2(10,8)
const LOOK_HINT := "Just looking  ·  drag to orbit  ·  Tab or a brush to create again"
var scene: Node3D
var editor: NativeChunkEditor
## Normalised registry entries: brush_id, title, hint, size, strength.
var entries: Array[Dictionary] = []
var buttons := {}
var look_button: Button
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

## Registry entries may be Dictionaries, brush objects or brush scripts; read
## the same names from each. Returns {} for an entry without an id.
static func brush_info(entry: Variant) -> Dictionary:
	var source := {}
	if entry is Dictionary: source = entry
	elif entry is Script: source = (entry as Script).get_script_constant_map()
	elif entry is Object:
		for key: String in ["brush_id","title","display_name","hint","size","strength","BRUSH_ID","TITLE","DISPLAY_NAME","HINT"]:
			var value: Variant = entry.get(key)
			if value != null: source[key] = value
	var id := str(source.get("brush_id",source.get("BRUSH_ID",source.get("id",""))))
	if id.is_empty(): return {}
	var title := str(source.get("title",source.get("display_name",source.get("TITLE",source.get("DISPLAY_NAME",id.capitalize())))))
	var info := {"brush_id":id,"title":title,"hint":str(source.get("hint",source.get("HINT",""))),
		"size":str(source.get("size","")),"strength":str(source.get("strength",""))}
	if info.size.is_empty(): info.size = _setting_for(id,"Brush size","radius")
	if info.strength.is_empty(): info.strength = _setting_for(id,"Strength","strength")
	return info

static func _setting_for(id: String, title: String, fallback: String) -> String:
	for spec: Dictionary in NativeChunkEditor.SETTINGS:
		if spec.title == title and id in spec.modes: return spec.property
	return fallback

## Every registered brush, in palette order.
static func registered() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Variant in Genesis.BRUSHES:
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
	hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color(Glass.INK,0.72))
	hint.add_theme_color_override("font_shadow_color",Color("182628",0.8))
	hint.add_theme_constant_override("shadow_offset_y",1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	editor.setting_changed.connect(func(_property: String, _value: float) -> void: _sync_meters())
	editor.tool_changed.connect(func(_tool: String) -> void: sync())
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
	return editor.mode if buttons.has(editor.mode) else ""

func sync() -> void:
	var holding := held()
	for id: String in buttons:
		buttons[id].set_pressed_no_signal(id == holding)
	look_button.set_pressed_no_signal(scene.looking)
	meters.modulate.a = 1.0 if not holding.is_empty() else 0.35
	_sync_meters()
	var state := "look" if scene.looking else holding
	if state == _last_state: return
	_last_state = state
	var text := LOOK_HINT
	if not scene.looking:
		var brush := info_for(holding)
		text = str(brush.get("hint",""))
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

func _sync_meters() -> void:
	var brush := info_for(held() if not held().is_empty() else (scene.brush if scene.get("brush") != null else ""))
	if brush.is_empty(): return
	for pair: Array in [[size_bar,brush.size],[strength_bar,brush.strength]]:
		var spec := editor.setting_spec(pair[1])
		var value: Variant = editor.get(pair[1])
		if spec.is_empty() or value == null: continue
		pair[0].value = inverse_lerp(spec.low,spec.high,float(value))

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
	hint.size = Vector2(screen.x,hint.get_minimum_size().y)
	hint.position = Vector2(0,screen.y-hint.size.y-14.0)

func contains_pointer(point: Vector2) -> bool:
	return is_visible_in_tree() and Rect2(frame.global_position,frame.size*frame.scale).has_point(point)
