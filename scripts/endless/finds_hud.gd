extends Control
## The world tally (lane `finds`): `3 / 30`, small, in the top left corner, in
## the near-miss look (a faceted glyph, gilt numbers). It comes up for a moment
## when the count changes and when the flight starts, stays while the logbook
## is open, and is gone otherwise, so the land keeps the eye. A find's name
## shows under it for that moment, and a very slight warm lift of the whole
## screen marks the beat.

const Card = preload("res://scripts/endless/landing_summary.gd")
const Glyphs = preload("res://scripts/endless/near_glyphs.gd")
const GILT := preload("res://shaders/near_gilt.gdshader")

const MARGIN := Vector2(30.0,26.0)
const GLYPH := "relic"
const HOLD := 3.4
const FADE_IN := 0.16
const FADE_OUT := 0.7
const POP := 1.28
const POP_TIME := 0.28
const LIFT := 0.055
const LIFT_FOR := 0.26

var game: Node
var finds: Node
var _shown := 0.0
var _age := 99.0
var _pop := 99.0
var _lift := 99.0
var _got := 0
var _of := 0
var _name := ""
var _started := false
var _count: Label
var _total: Label
var _a := 0.0
## False when the corner HUD draws the tally (scripts/endless/ui/flight_hud.gd):
## this keeps the count, the name and the screen's lift, and draws only the lift.
var counter := true

func setup(host: Node, keeper: Node) -> void:
	game = host
	finds = keeper
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_count = _gilt()
	_total = _gilt()

func _gilt() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font",Card.nums(true))
	l.add_theme_color_override("font_outline_color",Color("2a1c0e"))
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,0.45))
	var m := ShaderMaterial.new()
	m.shader = GILT
	l.material = m
	add_child(l)
	return l

## A find made: the count up, `e`'s name under it.
func found(e: Dictionary, got: int, of: int) -> void:
	_got = got
	_of = of
	_name = str(e.title)
	_age = 0.0
	_pop = 0.0
	_lift = 0.0

## Shows the tally without a find.
func glance() -> void:
	_got = int(finds.got())
	_of = int(finds.of())
	_name = ""
	_age = minf(_age,0.0)

func _book_open() -> bool:
	return game != null and game.overlay != null and game.overlay == game.logbook

func _process(delta: float) -> void:
	if game == null or finds == null: return
	var dt := minf(delta,0.1)
	if game.stage == null and not _started:
		_started = true
		_age = 99.0
		glance()
		_age = 0.0
	var books := _book_open()
	if books and _a <= 0.0: glance()
	_age += dt
	_pop += dt
	_lift += dt
	var wanted := 0.0
	if int(finds.of()) > 0 and game.stage == null and (game.overlay == null or books):
		if books: wanted = 1.0
		elif _age < HOLD: wanted = 1.0
		else: wanted = 1.0-clampf((_age-HOLD)/FADE_OUT,0.0,1.0)
	_a = move_toward(_a,wanted,dt/FADE_IN) if wanted > _a else wanted
	if visible != (_a > 0.003 or _lift < LIFT_FOR): visible = not visible
	if not visible: return
	_lay()
	queue_redraw()

func _scale() -> float:
	return size.y/900.0

func _lay() -> void:
	if not counter:
		_count.visible = false
		_total.visible = false
		return
	var s := _scale()
	var k := 1.0+(POP-1.0)*(1.0-smoothstep(0.0,POP_TIME,_pop))
	var flash := 1.0-smoothstep(0.0,0.5,_pop)
	var x := MARGIN.x*s+44.0*s
	var big := roundi(34.0*s*k)
	var small := roundi(20.0*s)
	_count.text = str(_got)
	_count.add_theme_font_size_override("font_size",big)
	_count.add_theme_constant_override("outline_size",maxi(roundi(7.0*s),1))
	_count.add_theme_constant_override("shadow_offset_y",maxi(roundi(2.0*s),1))
	_count.reset_size()
	_count.position = Vector2(x,MARGIN.y*s+17.0*s-_count.size.y*0.5)
	_total.text = "/ %d" % _of
	_total.add_theme_font_size_override("font_size",small)
	_total.add_theme_constant_override("outline_size",maxi(roundi(5.0*s),1))
	_total.reset_size()
	_total.position = Vector2(x+_count.size.x+7.0*s,MARGIN.y*s+20.0*s-_total.size.y*0.5)
	for l: Label in [_count,_total]:
		l.modulate.a = _a*(1.0 if l == _count else 0.8)
		var m: ShaderMaterial = l.material
		m.set_shader_parameter("flash",flash*0.8 if l == _count else 0.0)
		m.set_shader_parameter("top",0.0)
		m.set_shader_parameter("height",l.size.y)

func _draw() -> void:
	if _lift < LIFT_FOR:
		var k := 1.0-_lift/LIFT_FOR
		draw_rect(Rect2(Vector2.ZERO,size),Color(1.0,0.86,0.62,LIFT*k*k))
	if _a <= 0.003 or not counter: return
	var s := _scale()
	var px := roundf(30.0*s/2.0)*2.0
	var draw_px := px*Glyphs.BOX/24.0
	var c := MARGIN*s+Vector2(17.0*s,17.0*s)
	var r := Rect2(c-Vector2.ONE*draw_px*0.5,Vector2.ONE*draw_px)
	var shadow := Glyphs.texture(GLYPH,"shadow",px)
	if shadow != null: draw_texture_rect(shadow,Rect2(r.position+Vector2(0.0,2.0)*s,r.size),false,Color(0.08,0.05,0.03,0.6*_a))
	var tex := Glyphs.texture(GLYPH,"icon",px)
	if tex != null: draw_texture_rect(tex,r,false,Color(1,1,1,_a))
	var gleam := 1.0-smoothstep(0.0,0.6,_pop)
	if gleam > 0.0:
		var lit := Glyphs.texture(GLYPH,"lit",px)
		if lit != null: draw_texture_rect(lit,r,false,Color(1,1,1,_a*gleam))
	if _name != "" and not _book_open():
		Card.ink(self,Card.words(16.0*s,0.04),_name,Vector2(MARGIN.x*s+2.0*s,MARGIN.y*s+50.0*s),16.0*s,Color(Card.CREAM,_a),4.0*s,0.0)
