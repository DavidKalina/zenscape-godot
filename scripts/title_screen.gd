extends Control
## The Electron inscription over the live Godot landscape, with the menu set
## on a card of the HUD's linen (scripts/hud_linen.gd): each pick a stitched
## row, the one in reach pressed into the cloth, and the quiet ones (Settings,
## Quit) as small caps along the card's foot. Actions and world ownership
## remain in diorama.gd. Mouse and the arrow keys pick; no key legend, the
## menu reads without one.
const DISPLAY = preload("res://assets/fonts/newsreader-latin.woff2")
const READING = preload("res://assets/fonts/spectral-latin-400.woff2")
const Linen = preload("res://scripts/hud_linen.gd")
## The card, design pixels of the 1180-wide frame: its left and top, width,
## padding, the rows' heights (with and without a detail line), the gap
## between rows, the seam above the foot and the foot's height.
const CARD := Vector3(404.0,226.0,372.0)
const PAD := 10.0
const ROW := 58.0
const ROW_BARE := 44.0
const ROW_GAP := 3.0
const SEAM := 17.0
const FOOT := 34.0
var buttons: Array[Button] = []
var _frame := Control.new()
var _card := Linen.Cloth.new()
var _seam := Seam.new()
var _veil := ColorRect.new()
var _elapsed := 0.0
var _entrance: Tween
var _selected := 0
var _layout_factor := 1.0
var _card_rect := Rect2()

## One pick on the card. It draws itself; the Button underneath keeps the
## focus, hover and keyboard behaviour.
class Entry extends Button:
	var detail := ""
	var quiet := false
	var px := 1.0
	var breath := 1.0
	var _tag_font := Linen.tag_font()

	func _draw() -> void:
		var lit := has_focus()
		var rect := Rect2(Vector2.ZERO,size)
		if lit: Linen.pressed_patch(self,rect,px,Linen.PRESSED,Linen.PRESSED_SHADE)
		elif is_hovered(): Linen.pressed_patch(self,rect,px,Linen.HOVER,Linen.HOVER_SHADE)
		if quiet:
			Linen.tag(self,_tag_font,text,size.x*0.5,roundf(size.y*0.5+5.0*px),px,1.0 if lit else 0.62)
			return
		# The stitch where the needle rests: the old stem, sewn in.
		var line := maxf(1.0,roundf(px))
		if lit:
			var stitch := PackedVector2Array([Vector2(9.0*px,9.0*px),Vector2(9.0*px,size.y-9.0*px)])
			Linen.dashed(self,stitch,Color(Linen.FOCUS,0.35+0.5*breath),line,3.0*px,3.0*px)
		var font_size := maxi(1,roundi(19.0*px))
		var baseline := (25.0 if not detail.is_empty() else 28.0)*px
		var ink := Color(Linen.INK,1.0 if lit else 0.84)
		draw_string(READING,Vector2(roundf(22.0*px),roundf(baseline)),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)
		if detail.is_empty(): return
		var caps := maxi(6,roundi(Linen.TAG_CAPS*px))
		_tag_font.spacing_glyph = roundi(Linen.TAG_TRACK*Linen.TAG_SIZE*px)
		draw_string(_tag_font,Vector2(roundf(22.0*px),roundf(44.0*px)),detail.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,caps,Color(Linen.INK,0.62 if lit else 0.42))

## The double stitch between the picks and the foot, as on the tool roll.
class Seam extends Control:
	var px := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var line := maxf(1.0,roundf(px))
		for k in [-1.5,1.5]:
			var y := roundf(size.y*0.5+k*px)
			Linen.dashed(self,PackedVector2Array([Vector2(0,y),Vector2(size.x,y)]),Linen.DIVIDER,line,3.0*px,3.0*px)

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
	# The card first, so it lies under everything sewn onto it.
	_frame.add_child(_card)
	_frame.add_child(_seam)
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
	_rule(Vector2(390,64),Vector2(400,1))
	_rule(Vector2(390,160),Vector2(400,1))
	var small_caps := FontVariation.new()
	small_caps.base_font = DISPLAY
	small_caps.spacing_glyph = 3
	var tag := _label("A LITTLE WILDERNESS, MADE BY YOU",small_caps,12,Color("e6decda0"),Vector2(0,181),Vector2(1180,24))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

func _rule(at: Vector2, extent: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("e2d0aa00"),Color("e2d0aa66"),Color("e2d0aa00")])
	gradient.offsets = PackedFloat32Array([0,0.5,1])
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

## A pick on the card. `quiet` ones (Settings, Quit) sit along its foot as
## small caps; `at` places it among the others (-1 appends).
func add_action(text: String, detail: String, action: Callable, quiet := false, at := -1) -> Button:
	var button := Entry.new()
	button.text = text
	button.detail = detail
	button.quiet = quiet
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled","hover_pressed"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	# The entry draws its own words; the Button's are kept for focus only.
	for colour in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color","font_disabled_color"]:
		button.add_theme_color_override(colour,Color.TRANSPARENT)
	button.focus_entered.connect(func() -> void:
		_selected = buttons.find(button)
		_redraw_entries())
	button.focus_exited.connect(button.queue_redraw)
	button.mouse_entered.connect(func() -> void: if button.is_visible_in_tree(): button.grab_focus())
	button.pressed.connect(action)
	_frame.add_child(button)
	if at < 0 or at >= buttons.size(): buttons.append(button)
	else: buttons.insert(at,button)
	_arrange()
	return button

func present(cover: bool) -> void:
	show()
	_arrange()
	for button in buttons:
		if button.visible:
			button.grab_focus()
			break
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
			var delay := 0.95 if at.y >= 222 else 0.0
			_entrance.tween_property(control,"modulate:a",1.0,1.2 if delay > 0 else 2.2).set_delay(delay)
		_entrance.chain().tween_callback(_veil.hide)

## Lays the enabled picks down the card, the quiet ones along its foot, in
## design pixels; `_layout` scales them.
func _arrange() -> void:
	var left := CARD.x+PAD
	var width := CARD.z-PAD*2.0
	var y := CARD.y+PAD
	var foot: Array[Button] = []
	for button in buttons:
		button.visible = not button.disabled
		if not button.visible: continue
		if button.quiet:
			foot.append(button)
			continue
		var height := ROW if not button.detail.is_empty() else ROW_BARE
		_track_layout(button,Vector2(left,y),Vector2(width,height))
		y += height+ROW_GAP
	y -= ROW_GAP
	_seam.visible = not foot.is_empty()
	if not foot.is_empty():
		_track_layout(_seam,Vector2(left+6.0,y),Vector2(width-12.0,SEAM))
		y += SEAM
		var x := left
		var tag_font := Linen.tag_font()
		for button in foot:
			var extent := Vector2(Linen.tag_width(tag_font,button.text,1.0)+32.0,FOOT)
			_track_layout(button,Vector2(x,y),extent)
			x += extent.x+4.0
		y += FOOT
	_card_rect = Rect2(CARD.x,CARD.y,CARD.z,y+PAD-CARD.y)
	_layout()

func _track_layout(control: Control, at: Vector2, extent: Vector2, font_size := 0) -> void:
	control.set_meta("design_position", at)
	control.set_meta("design_size", extent)
	control.set_meta("design_font_size", font_size)
	if font_size > 0:
		var font := control.get_theme_font("font")
		if font is FontVariation:
			control.set_meta("design_tracking", font.spacing_glyph)

func _layout() -> void:
	var design_height := maxf(613.0,_card_rect.end.y+40.0)
	_layout_factor = minf(minf(size.x/1180.0,size.y/design_height),1.75)
	# Resize geometry and rasterize fonts at the final layout size. Scaling a
	# Control instead magnifies its cached glyphs, even on a native-pixel window.
	_frame.scale = Vector2.ONE
	_frame.size = (Vector2(1180,design_height)*_layout_factor).round()
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
	_card.visible = _card_rect.size.y > 0.0
	if _card.visible:
		var rect := Rect2((_card_rect.position*_layout_factor).round(),(_card_rect.size*_layout_factor).round())
		_card.place(rect,_layout_factor)
	_seam.px = _layout_factor
	_seam.queue_redraw()
	for button in buttons: (button as Entry).px = _layout_factor
	_redraw_entries()

func _redraw_entries() -> void:
	for button in buttons: button.queue_redraw()

func _process(delta: float) -> void:
	if not visible or buttons.is_empty(): return
	_elapsed += delta
	# The resting stitch breathes, as the stem did.
	var entry := buttons[clampi(_selected,0,buttons.size()-1)] as Entry
	entry.breath = sin(_elapsed*TAU/5.2)*0.5+0.5
	entry.queue_redraw()
