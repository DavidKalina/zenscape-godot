extends Control
## The run's tally in the corner (docs/design/roguelike/game-v1-
## collectibles.md), on the hearts' row past the last heart (scripts/
## roguelike/run_overlay.gd): the rune glyph and the runes carried, then
## the rare's stand-in glyph (the sun, scripts/hud_icons.gd) and the rares
## found this run, each count in the readout's reading face. It rides the
## readout's alpha (never under the hearts' while he moves). A count that
## changes swells a moment; a rare's find (`pop_rare`) swells bigger, with
## a flash.
const Icons = preload("res://scripts/hud_icons.gd")
const Splash = preload("res://scripts/isle_splash.gd")

## Design px: the gap after the last heart, a glyph's size, a count's type,
## the gap between the two.
const AFTER := 22.0
const GLYPH := 22.0
const TYPE := 17
const BETWEEN := 18.0
## A change's swell (s), and the rare's.
const POP := 0.4
const POP_RARE := 1.1
## The rune's gold (scripts/roguelike/collectibles.gd RUNE_TINT, lit).
const RUNE_GOLD := Color("d6ad66")

var overlay: CanvasLayer
var runes := 0
var rares := 0
var _rune_age := INF
var _rare_age := INF
var _tex := {}
var _tex_px := 0.0

func _init() -> void:
	name = "Tally"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_counts(rune_count: int, rare_count: int) -> void:
	if rune_count != runes: _rune_age = 0.0
	if rare_count != rares and _rare_age == INF: _rare_age = 0.0
	runes = rune_count
	rares = rare_count

func pop_rare() -> void:
	_rare_age = 0.0

func _process(delta: float) -> void:
	if _rune_age != INF:
		_rune_age += delta
		if _rune_age > POP: _rune_age = INF
	if _rare_age != INF:
		_rare_age += delta
		if _rare_age > POP_RARE: _rare_age = INF
	queue_redraw()

func _draw() -> void:
	if overlay == null or not overlay.readout.visible: return
	var a: float = overlay._hearts_a()
	if a <= 0.0: return
	var px: float = overlay._px
	var y: float = (overlay.CORNER.y+overlay.HEARTS_ROW+overlay.HEART*0.5)*px
	var x: float = (overlay.CORNER.x+(overlay.HEART+overlay.HEART_GAP)*float(overlay._hearts_most)+AFTER)*px
	_textures(roundf(GLYPH*px*2.0))
	x = _count(Vector2(x,y),"rune",runes,_swell(_rune_age,POP,0.18),0.0,a,px)
	x += BETWEEN*px
	var flash := 0.0 if _rare_age == INF else 1.0-smoothstep(0.0,0.5,_rare_age/POP_RARE)
	_count(Vector2(x,y),"sun",rares,_swell(_rare_age,POP_RARE,0.5),flash,a*(1.0 if rares > 0 else 0.55),px)

## A swell of `most` over `length` s at `age` (INF none): up fast, back slow.
static func _swell(age: float, length: float, most: float) -> float:
	if age == INF: return 1.0
	var k := clampf(age/length,0.0,1.0)
	return 1.0+most*sin(PI*pow(k,0.6))

## One glyph and its count from `at` (its glyph's left middle); answers the
## x past the count.
func _count(at: Vector2, glyph: String, n: int, swell: float, flash: float, a: float, px: float) -> float:
	var size := GLYPH*px
	var tex: Texture2D = _tex.get(glyph)
	var extent := size*Icons.BOX/24.0*swell
	var mid := at+Vector2(size*0.5,0.0)
	if glyph == "rune":
		# Drawn in the world's rune gold (the HUD glyph is the sky's cyan).
		var h := extent*0.36
		var w := extent*0.2
		var pts := PackedVector2Array([mid+Vector2(0,-h),mid+Vector2(w,0),mid+Vector2(0,h*0.75),mid+Vector2(-w,0)])
		var shade := PackedVector2Array()
		for p: Vector2 in pts: shade.append(p+Vector2(0.0,1.6*px))
		draw_colored_polygon(shade,Color(0.03,0.025,0.02,0.45*a))
		draw_colored_polygon(pts,Color(RUNE_GOLD,a))
		draw_colored_polygon(PackedVector2Array([pts[0],pts[1],mid,pts[3]]),Color(RUNE_GOLD.lightened(0.35),a))
		draw_arc(mid,extent*0.3,0.0,TAU,24,Color(RUNE_GOLD.lightened(0.2),0.6*a),1.2*px,true)
	elif tex != null:
		var shade := Color(0.03,0.025,0.02,0.45*a)
		draw_texture_rect(tex,Rect2(mid-Vector2.ONE*extent*0.5+Vector2(0.0,1.6*px),Vector2.ONE*extent),false,shade)
		draw_texture_rect(tex,Rect2(mid-Vector2.ONE*extent*0.5,Vector2.ONE*extent),false,Color(1.0+flash,1.0+0.8*flash,1.0+0.5*flash,a))
	var font: Font = Splash.READING
	var fs := int(roundf(TYPE*px*lerpf(1.0,swell,0.5)))
	var text := str(n)
	var tx := at.x+size+6.0*px
	var base := at.y+fs*0.36
	draw_string(font,Vector2(tx+1.0*px,base+1.4*px),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(Splash.SHADOW,0.5*a))
	draw_string(font,Vector2(tx,base),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(Splash.INK,0.92*a))
	return tx+font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x

func _textures(px: float) -> void:
	if is_equal_approx(px,_tex_px) and not _tex.is_empty(): return
	_tex_px = px
	for glyph: String in ["rune","sun"]:
		var t: Texture2D = Icons.texture(glyph,"icon",px)
		if t != null: _tex[glyph] = t
