extends Control
## Endless flight's main menu, over the plane parked in a meadow (studies/
## endless_flight.gd runs the plane, the camera and the handoff; this is the
## overlay). The old title's inscription (git tag archive/before-the-cut,
## scripts/title_screen.gd): ZENSCAPE in Newsreader under the gilt (shaders/
## title_gilt.gdshader, cream to dark ochre top to bottom) between two gold
## hairlines, over a light scrim (shaders/menu_scrim.gdshader). One pick,
## Start, in Spectral, its stitch breathing on a BREATH s sine as the old
## selected row's did; Quit as small caps along the foot.
##
## Space, Enter or the pad's A picks; up and down (the d-pad) move between
## Start and Quit; Escape or the pad's B quits; the mouse picks by hovering
## and clicking. `picked` says which ("start" or "quit"). It comes in as
## the old title did (`present`: a dark veil lifting over VEIL s, the
## inscription over MARK_IN s, the picks after PICKS_DELAY s) and goes with
## `leave` (LEAVE s); while leaving or gone it takes no input.

signal picked(what: String)

const DISPLAY = preload("res://assets/fonts/newsreader-latin.woff2")
const READING = preload("res://assets/fonts/spectral-latin-400.woff2")
## The design frame (px) everything is laid out in, scaled to the window.
const FRAME := Vector2(1180.0,613.0)
## The inscription's colour and the picks' ink (the old HUD's INK).
const MARK := Color("e3d7bd")
const INK := Color("e3d7bd")
const HAIR := Color("e2d0aa")
## The picks: Start's baseline and size, Quit's, the small caps' tracking (em).
const START_Y := 510.0
const START_SIZE := 30
const QUIT_Y := 574.0
const QUIT_SIZE := 12
const TRACK := 0.22
const BREATH := 5.2
const VEIL := 1.4
const MARK_IN := 2.2
const PICKS_DELAY := 0.95
const PICKS_IN := 1.2
const LEAVE := 0.7

var _scrim := ColorRect.new()
var _scrim_material := ShaderMaterial.new()
var _frame := Control.new()
var _mark := Label.new()
var _gilt := ShaderMaterial.new()
var _rules: Array[TextureRect] = []
var _picks := Picks.new()
var _veil := ColorRect.new()
var _entrance: Tween
var _scale := 1.0
## Taking input (not while leaving or gone).
var active := false

## Start and Quit, drawn as one control: the selected one lit, Start's
## stitch breathing.
class Picks extends Control:
	var selected := 0
	var hovered := -1
	var px := 1.0
	## How far the picks sit lower than the design frame's (px): the frame
	## runs the window's height, the inscription at its top, the picks at its foot.
	var drop := 0.0
	var breath := 1.0
	var reading: Font
	var caps: FontVariation

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## The design rects of Start and Quit, in this control's own pixels.
	func rect_of(i: int) -> Rect2:
		var w := size.x
		if i == 0:
			var tw := reading.get_string_size("Start",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(START_SIZE*px)).x
			return Rect2(Vector2((w-tw)*0.5-34.0*px,(START_Y-36.0)*px+drop),Vector2(tw+68.0*px,52.0*px))
		var cw := _caps_width("QUIT")
		return Rect2(Vector2((w-cw)*0.5-18.0*px,(QUIT_Y-20.0)*px+drop),Vector2(cw+36.0*px,30.0*px))

	func _caps_width(text: String) -> float:
		caps.spacing_glyph = roundi(TRACK*QUIT_SIZE*px)
		return caps.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(QUIT_SIZE*px)).x

	func _draw() -> void:
		var w := size.x
		var line := maxf(1.0,roundf(px))
		# Start: the word, and under it a dashed stitch that breathes while
		# it is the one picked (the old selected row's).
		var lit := selected == 0
		var fs := roundi(START_SIZE*px)
		var tw := reading.get_string_size("Start",HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
		var r := rect_of(0)
		if lit or hovered == 0:
			draw_rect(r,Color(0.039,0.031,0.016,0.22 if lit else 0.12))
			draw_rect(Rect2(r.position+Vector2(0,r.size.y-line),Vector2(r.size.x,line)),Color(0.0,0.0,0.0,0.12))
		var at := Vector2(roundf((w-tw)*0.5),roundf(START_Y*px+drop))
		draw_string(reading,at+Vector2(0,line),"Start",HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(0,0,0,0.35))
		draw_string(reading,at,"Start",HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(INK,1.0 if lit else 0.78))
		if lit:
			var y := roundf((START_Y+9.0)*px+drop)
			var c := Color(INK,0.3+0.55*breath)
			_dashed(Vector2(r.position.x+12.0*px,y),Vector2(r.end.x-12.0*px,y),c,line,3.0*px)
			# The stitch's ends, sewn down either side of the word.
			for x in [r.position.x+9.0*px,r.end.x-9.0*px]:
				_dashed(Vector2(x,r.position.y+10.0*px),Vector2(x,r.end.y-10.0*px),Color(INK,(0.3+0.55*breath)*0.7),line,3.0*px)
		# Quit: small caps along the foot.
		var q := rect_of(1)
		var qlit := selected == 1
		if qlit or hovered == 1: draw_rect(q,Color(0.039,0.031,0.016,0.2 if qlit else 0.1))
		var cw := _caps_width("QUIT")
		var qa := Vector2(roundf((w-cw)*0.5),roundf(QUIT_Y*px+drop))
		draw_string(caps,qa,"QUIT",HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(QUIT_SIZE*px),Color(INK,1.0 if qlit else 0.6))
		if qlit:
			var y := roundf((QUIT_Y+6.0)*px+drop)
			_dashed(Vector2(qa.x,y),Vector2(qa.x+cw,y),Color(INK,0.3+0.5*breath),line,2.0*px)

	func _dashed(a: Vector2, b: Vector2, c: Color, width: float, dash: float) -> void:
		var length := a.distance_to(b)
		if length <= 0.0: return
		var dir := (b-a)/length
		var d := 0.0
		while d < length:
			draw_line(a+dir*d,a+dir*minf(d+dash,length),c,width)
			d += dash*2.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim_material.shader = preload("res://shaders/menu_scrim.gdshader")
	_scrim.material = _scrim_material
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var inscription := FontVariation.new()
	inscription.base_font = DISPLAY
	inscription.variation_opentype = {"wght":500.0}
	_mark.text = "ZENSCAPE"
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.add_theme_font_override("font",inscription)
	_mark.add_theme_color_override("font_color",Color.WHITE)
	_mark.add_theme_color_override("font_shadow_color",Color(0,0,0,0.3))
	_mark.add_theme_constant_override("shadow_offset_y",1)
	_gilt.shader = preload("res://shaders/title_gilt.gdshader")
	_mark.material = _gilt
	_frame.add_child(_mark)
	for i in 2:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(HAIR,0.0),Color(HAIR,0.4),Color(HAIR,0.0)])
		gradient.offsets = PackedFloat32Array([0,0.5,1])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.height = 1
		var rule := TextureRect.new()
		rule.texture = texture
		rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(rule)
		_rules.append(rule)
	_picks.reading = READING
	_picks.caps = FontVariation.new()
	_picks.caps.base_font = DISPLAY
	_picks.caps.variation_opentype = {"wght":500.0}
	_frame.add_child(_picks)
	_veil.color = Color("0b0e12")
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.hide()
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()

## Lays the design frame out at the window's size: the fonts set at the
## final size (not a scaled Control, which magnifies its glyphs).
func _layout() -> void:
	_scale = minf(minf(size.x/FRAME.x,size.y/FRAME.y),1.9)
	if _scale <= 0.0: return
	var frame := (FRAME*_scale).round()
	# The frame runs the window's height: the inscription at the top, the
	# picks dropped to the foot, the plane in the open middle.
	_frame.size = Vector2(frame.x,size.y)
	_frame.position = Vector2(roundf((size.x-frame.x)*0.5),0.0)
	_picks.drop = maxf(0.0,size.y-frame.y)
	_mark.position = (Vector2(0,77)*_scale).round()
	_mark.size = (Vector2(FRAME.x,80)*_scale).round()
	_mark.add_theme_font_size_override("font_size",roundi(58*_scale))
	(_mark.get_theme_font("font") as FontVariation).spacing_glyph = roundi(15*_scale)
	_gilt.set_shader_parameter("glyph_scale",_scale)
	for i in 2:
		_rules[i].position = (Vector2(390,64 if i == 0 else 160)*_scale).round()
		_rules[i].size = Vector2(roundf(400*_scale),maxf(1.0,roundf(_scale)))
	_picks.position = Vector2.ZERO
	_picks.size = _frame.size
	_picks.px = _scale
	_picks.queue_redraw()

## Comes in: the veil lifting, the inscription and then the picks fading in.
func present() -> void:
	show()
	active = true
	_picks.selected = 0
	modulate.a = 1.0
	if _entrance: _entrance.kill()
	_veil.show()
	_veil.modulate.a = 1.0
	_entrance = create_tween().set_parallel(true)
	_entrance.tween_property(_veil,"modulate:a",0.0,VEIL)
	for c: Control in [_mark,_rules[0],_rules[1]]:
		c.modulate.a = 0.0
		_entrance.tween_property(c,"modulate:a",1.0,MARK_IN)
	_picks.modulate.a = 0.0
	_entrance.tween_property(_picks,"modulate:a",1.0,PICKS_IN).set_delay(PICKS_DELAY)
	_entrance.chain().tween_callback(_veil.hide)

## Goes: the lot fading out over LEAVE s, then hidden; no input from now.
func leave() -> void:
	active = false
	if _entrance: _entrance.kill()
	_veil.hide()
	_entrance = create_tween()
	_entrance.tween_property(self,"modulate:a",0.0,LEAVE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_entrance.tween_callback(hide)

## Start (0) or Quit (1) picked now.
func selected() -> int:
	return _picks.selected

func _process(_delta: float) -> void:
	if not visible: return
	var t := Time.get_ticks_msec()*0.001
	_picks.breath = sin(t*TAU/BREATH)*0.5+0.5
	_picks.queue_redraw()

func _input(event: InputEvent) -> void:
	if not active or not visible: return
	if event is InputEventMouseMotion:
		var over := _over((event as InputEventMouseMotion).position)
		_picks.hovered = over
		if over >= 0: _picks.selected = over
		return
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT and b.pressed:
			var over := _over(b.position)
			if over >= 0:
				_pick(over)
				get_viewport().set_input_as_handled()
		return
	if event.is_echo(): return
	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_focus_next"):
		_picks.selected = 1-_picks.selected
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		_pick(_picks.selected)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		_pick(1)
		get_viewport().set_input_as_handled()

## The pick under `at` (viewport pixels): 0 Start, 1 Quit, -1 neither.
func _over(at: Vector2) -> int:
	var local := at-_frame.global_position
	for i in 2:
		if _picks.rect_of(i).grow(4.0).has_point(local): return i
	return -1

func _pick(i: int) -> void:
	_picks.selected = i
	picked.emit("start" if i == 0 else "quit")
