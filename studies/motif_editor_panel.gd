extends Control
## The motif editor's landform generator panel (round 3): top left, on the HUD's
## linen (scripts/hud_linen.gd, design "ZenScape HUD 4c"), the way the tool
## roll and the command palette are drawn: the motif's name and Save, the
## landform list, the landform's sliders, the seed and Re-roll. Under it, at
## the bottom of the screen, a strip of the same cloth carries the hint for
## the tool in hand, the last thing that happened and the brush strength.
##
## It only shows and asks: the editor (studies/motif_editor.gd) owns the
## data, the undo and the rebuilds (`slider_began`, `slider_moved`,
## `slider_ended`, `set_preset`, `reroll`, `dress`, `save`, `set_strength`).

const Linen = preload("res://scripts/hud_linen.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
const MotifAuthored = preload("res://scripts/kit_isle/motif_authored.gd")
const SPECTRAL = preload("res://assets/fonts/spectral-latin-400.woff2")

const T1 := Color("f4ead4")
const T2 := Color("c2b8a3")
const ACC := Color("e3d7bd")
const WELL := Color(0.078,0.055,0.031,0.22)
const CLOTH := Color(0.384,0.345,0.290,0.92)
## Design pixels: the panel's inset and width, its padding.
const INSET := Vector2(16.0,14.0)
const WIDTH := 330.0
const PAD := 14.0
const STRIP_W := 760.0

var editor: Node
var ui_scale := 1.0
var _cloth: Linen.Cloth
var _strip_cloth: Linen.Cloth
var _box: VBoxContainer
var _strip: HBoxContainer
var _theme: Theme
var _caps: FontVariation
var _text: FontVariation
var slug_edit: LineEdit
var _presets := {}
var _slider_box: VBoxContainer
var sliders := {}
var _values := {}
var _seed: Label
var _breakable: Button
var hint: Label
var status: Label
var strength: HSlider
var _strength_row: HBoxContainer
var _dragging := false

func _init() -> void:
	name = "LandformPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func setup(owner_editor: Node) -> void:
	editor = owner_editor
	ui_scale = Linen.hud_scale_for(get_viewport().get_visible_rect().size)
	_caps = Linen.tag_font()
	_text = FontVariation.new()
	_text.base_font = SPECTRAL
	_theme = _make_theme()
	_cloth = Linen.Cloth.new()
	_cloth.material_ref.set_shader_parameter("cloth",CLOTH)
	add_child(_cloth)
	_box = VBoxContainer.new()
	_box.name = "Box"
	_box.theme = _theme
	_box.add_theme_constant_override("separation",roundi(4.0*ui_scale))
	_box.position = (INSET+Vector2.ONE*PAD)*ui_scale
	_box.custom_minimum_size.x = (WIDTH-PAD*2.0)*ui_scale
	add_child(_box)
	# The name and Save.
	var top := HBoxContainer.new()
	slug_edit = LineEdit.new()
	slug_edit.name = "Slug"
	slug_edit.text = str(editor.data.slug)
	slug_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slug_edit.placeholder_text = "motif name"
	slug_edit.text_submitted.connect(func(_t: String) -> void: slug_edit.release_focus())
	top.add_child(slug_edit)
	top.add_child(_button("Save","Save (Ctrl+S): motifs/authored/<name>.json",func() -> void: editor.save()))
	_box.add_child(top)
	_box.add_child(_rule())
	_box.add_child(_caption("Landform"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation",roundi(2.0*ui_scale))
	flow.add_theme_constant_override("v_separation",roundi(2.0*ui_scale))
	for key: String in MotifAuthored.PRESETS:
		var b := _button(str(MotifAuthored.PRESET_NAMES.get(key,key)),"",func() -> void: editor.set_preset(key))
		b.name = "Preset_"+key
		b.toggle_mode = true
		flow.add_child(b)
		_presets[key] = b
	_box.add_child(flow)
	_slider_box = VBoxContainer.new()
	_slider_box.add_theme_constant_override("separation",0)
	_box.add_child(_slider_box)
	var seed_row := HBoxContainer.new()
	_seed = Label.new()
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed)
	var reroll := _button("Re-roll","A new seed, the same sliders",func() -> void: editor.reroll())
	reroll.name = "Reroll"
	seed_row.add_child(reroll)
	seed_row.add_child(_button("Full look","The full look (turf, flora, life, sky) or back to grey (G)",func() -> void: editor.toggle_dress()))
	_box.add_child(seed_row)
	_breakable = _button("Breakable","Its pieces break when hit (off: none of them do; one piece: select it, B)",func() -> void: editor.toggle_motif_breakable())
	_breakable.name = "Breakable"
	_breakable.toggle_mode = true
	_box.add_child(_breakable)
	fill()
	# The strip along the bottom: the hint, what happened, the strength.
	_strip_cloth = Linen.Cloth.new()
	_strip_cloth.material_ref.set_shader_parameter("cloth",CLOTH)
	add_child(_strip_cloth)
	_strip = HBoxContainer.new()
	_strip.name = "Strip"
	_strip.theme = _theme
	_strip.add_theme_constant_override("separation",roundi(14.0*ui_scale))
	add_child(_strip)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation",0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint = Label.new()
	hint.name = "Hint"
	hint.add_theme_color_override("font_color",T1)
	hint.clip_text = true
	words.add_child(hint)
	status = Label.new()
	status.name = "Status"
	status.add_theme_color_override("font_color",T2)
	status.add_theme_font_size_override("font_size",roundi(12.0*ui_scale))
	status.clip_text = true
	words.add_child(status)
	_strip.add_child(words)
	_strength_row = HBoxContainer.new()
	var sl := Label.new()
	sl.text = "STRENGTH"
	sl.add_theme_font_override("font",_caps)
	sl.add_theme_font_size_override("font_size",roundi(10.0*ui_scale))
	sl.add_theme_color_override("font_color",T2)
	_strength_row.add_child(sl)
	strength = HSlider.new()
	strength.name = "Strength"
	strength.min_value = 0.05
	strength.max_value = 1.0
	strength.step = 0.01
	strength.value = float(editor.brush_s)
	strength.focus_mode = Control.FOCUS_NONE
	strength.custom_minimum_size.x = 140.0*ui_scale
	strength.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strength.value_changed.connect(func(v: float) -> void: editor.set_strength(v))
	_strength_row.add_child(strength)
	_strip.add_child(_strength_row)

## The panel's bottom edge (viewport pixels): the tool roll hangs under it.
func bottom() -> float:
	return (INSET.y+PAD*2.0)*ui_scale+_box.size.y

func contains_pointer(point: Vector2) -> bool:
	return visible and (_cloth.strip.has_point(point) or _strip_cloth.strip.has_point(point))

func _process(_delta: float) -> void:
	if not visible: return
	var screen := get_viewport().get_visible_rect().size
	_box.size = Vector2(_box.custom_minimum_size.x,0.0)
	var rect := Rect2(INSET*ui_scale,Vector2(WIDTH*ui_scale,_box.size.y+PAD*2.0*ui_scale))
	_cloth.place(rect,ui_scale,12.0,Vector2(5.0,8.0))
	var w := minf(STRIP_W*ui_scale,screen.x-420.0*ui_scale)
	var h := 46.0*ui_scale
	var strip := Rect2(Vector2(roundf((screen.x-w)*0.5+120.0*ui_scale),screen.y-h-14.0*ui_scale),Vector2(w,h))
	_strip_cloth.place(strip,ui_scale,10.0,Vector2(4.0,7.0))
	_strip.position = strip.position+Vector2(16.0,5.0)*ui_scale
	_strip.size = strip.size-Vector2(32.0,10.0)*ui_scale

## The landform's sliders (again, for a new landform), set to the data.
func fill() -> void:
	for c: Node in _slider_box.get_children(): c.free()
	sliders.clear()
	_values.clear()
	var preset := str(editor.data.preset)
	for spec: Array in MotifAuthored.PRESETS[preset]:
		var key := str(spec[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",roundi(6.0*ui_scale))
		var name_l := Label.new()
		name_l.text = str(spec[1]).get_slice(" (",0).to_upper()
		name_l.add_theme_font_override("font",_caps)
		name_l.add_theme_font_size_override("font_size",roundi(10.0*ui_scale))
		name_l.add_theme_color_override("font_color",T2)
		name_l.custom_minimum_size.x = 92.0*ui_scale
		name_l.clip_text = true
		row.add_child(name_l)
		var slider := HSlider.new()
		slider.name = "Slider_"+key
		slider.min_value = float(spec[2])
		slider.max_value = float(spec[3])
		slider.step = float(spec[4])
		slider.value = MotifAuthored.slider(editor.data,key)
		slider.focus_mode = Control.FOCUS_NONE
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(func(v: float) -> void: editor.slider_moved(key,v))
		slider.drag_started.connect(func() -> void:
			_dragging = true
			editor.slider_began())
		slider.drag_ended.connect(func(_changed: bool) -> void:
			_dragging = false
			editor.slider_ended())
		row.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size.x = 40.0*ui_scale
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_color_override("font_color",T1)
		row.add_child(value)
		_slider_box.add_child(row)
		sliders[key] = slider
		_values[key] = value
	sync()

## The panel set to the data (an undo, a load, a re-roll).
func sync() -> void:
	var preset := str(editor.data.preset)
	for key: String in _presets: (_presets[key] as Button).set_pressed_no_signal(key == preset)
	for key: String in sliders:
		var v := MotifAuthored.slider(editor.data,key)
		(sliders[key] as HSlider).set_value_no_signal(v)
		(_values[key] as Label).text = str(snappedf(v,0.1 if absf(v) >= 10.0 else 0.01))
	_seed.text = "Seed %d" % int(editor.data.seed)
	if _breakable != null: _breakable.set_pressed_no_signal(bool(editor.data.get("breakable",true)))
	if slug_edit.text != str(editor.data.slug) and not slug_edit.has_focus(): slug_edit.text = str(editor.data.slug)
	if strength != null: strength.set_value_no_signal(float(editor.brush_s))

func slider_dragging() -> bool:
	return _dragging

func say(hint_text: String, status_text: String, show_strength: bool) -> void:
	if hint == null: return
	hint.text = hint_text
	status.text = status_text
	_strength_row.modulate.a = 1.0 if show_strength else 0.35

# --- The cloth's controls ----------------------------------------------------------

func _button(text: String, tip: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font",_caps)
	b.add_theme_font_size_override("font_size",roundi(10.0*ui_scale))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func() -> void:
		ClaySound.cue(&"ui_pick")
		pressed.call())
	return b

func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font",_caps)
	l.add_theme_font_size_override("font_size",roundi(11.0*ui_scale))
	l.add_theme_color_override("font_color",ACC)
	return l

## A double stitched rule, as the palette and the roll set things apart.
func _rule() -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = 8.0*ui_scale
	c.draw.connect(func() -> void:
		var line := maxf(1.0,roundf(ui_scale))
		for k in range(2):
			var y := roundf((2.0+k*3.0)*ui_scale)+line*0.5
			Linen.dashed(c,PackedVector2Array([Vector2(0.0,y),Vector2(c.size.x,y)]),Linen.DIVIDER,line,3.0*ui_scale,3.0*ui_scale))
	return c

## The linen's theme for Godot's own controls: the type in the HUD's ink, a
## button a patch pressed into the cloth, a slider a stitched groove with
## a bone grip, a text field a well.
func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _text
	t.default_font_size = roundi(14.0*ui_scale)
	t.set_color("font_color","Label",T1)
	var r := roundi(7.0*ui_scale)
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(r)
		s.content_margin_left = 8.0*ui_scale
		s.content_margin_right = 8.0*ui_scale
		s.content_margin_top = 4.0*ui_scale
		s.content_margin_bottom = 3.0*ui_scale
		s.bg_color = Color(0,0,0,0)
		s.anti_aliasing = true
		match state:
			"hover": s.bg_color = Linen.HOVER
			"pressed", "hover_pressed":
				s.bg_color = Linen.PRESSED
				s.border_width_top = roundi(2.0*ui_scale)
				s.border_color = Linen.PRESSED_SHADE
			"focus": s.draw_center = false
			_: pass
		if state == "normal":
			s.set_border_width_all(1)
			s.border_color = Color(Linen.POCKET_STITCH,0.22)
		t.set_stylebox(state,"Button",s)
	for k: String in ["font_color","font_hover_color","font_focus_color"]: t.set_color(k,"Button",ACC)
	for k: String in ["font_pressed_color","font_hover_pressed_color"]: t.set_color(k,"Button",T1)
	# The slider: a groove pressed in, the filled share stitched in ink.
	var groove := StyleBoxFlat.new()
	groove.bg_color = WELL
	groove.set_corner_radius_all(roundi(3.0*ui_scale))
	groove.content_margin_top = 2.5*ui_scale
	groove.content_margin_bottom = 2.5*ui_scale
	t.set_stylebox("slider","HSlider",groove)
	var filled := groove.duplicate() as StyleBoxFlat
	filled.bg_color = Color(ACC,0.55)
	t.set_stylebox("grabber_area","HSlider",filled)
	var lit := groove.duplicate() as StyleBoxFlat
	lit.bg_color = Color(ACC,0.8)
	t.set_stylebox("grabber_area_highlight","HSlider",lit)
	var grip := _grip(14.0*ui_scale,false)
	t.set_icon("grabber","HSlider",grip)
	t.set_icon("grabber_highlight","HSlider",_grip(14.0*ui_scale,true))
	t.set_icon("grabber_disabled","HSlider",grip)
	# The text field: a well with a stitched edge.
	var well := StyleBoxFlat.new()
	well.bg_color = WELL
	well.set_corner_radius_all(r)
	well.set_border_width_all(1)
	well.border_color = Color(Linen.POCKET_STITCH,0.35)
	well.content_margin_left = 8.0*ui_scale
	well.content_margin_right = 8.0*ui_scale
	well.content_margin_top = 3.0*ui_scale
	well.content_margin_bottom = 3.0*ui_scale
	t.set_stylebox("normal","LineEdit",well)
	var focus := well.duplicate() as StyleBoxFlat
	focus.border_color = Color(ACC,0.7)
	t.set_stylebox("focus","LineEdit",focus)
	t.set_color("font_color","LineEdit",T1)
	t.set_color("font_placeholder_color","LineEdit",Color(T2,0.6))
	t.set_color("caret_color","LineEdit",T1)
	# Tooltips on a scrap of the same cloth.
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.29,0.26,0.22,0.95)
	tip.set_corner_radius_all(r)
	tip.set_content_margin_all(6.0*ui_scale)
	t.set_stylebox("panel","TooltipPanel",tip)
	t.set_color("font_color","TooltipLabel",T1)
	return t

## The slider's grip: a bone disc ringed by a stitch.
func _grip(px: float, lit: bool) -> Texture2D:
	var n := maxi(8,roundi(px))
	var fill := "#efe3c8" if lit else "#e3d7bd"
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 20 20"><circle cx="10" cy="11.2" r="7.6" fill="#140e08" fill-opacity=".35"/><circle cx="10" cy="10" r="7.6" fill="%s"/><circle cx="10" cy="10" r="5.4" fill="none" stroke="#6a5c48" stroke-width="1" stroke-dasharray="1.6 1.6"/></svg>' % [n,n,fill]
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)
