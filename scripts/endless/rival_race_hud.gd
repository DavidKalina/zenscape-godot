extends Control
## The rival race on screen (scripts/endless/rival_race.gd), out of the way
## of the flying:
## - the bracket: four corner ticks round a traffic plane that can be
##   challenged, faint; held, they close in and brighten, a line under them
##   filling with the hold.
## - in the race, the marker: a small down-pointing wedge over the rival,
##   bobbing (bone white, a warm ember when it is far), the gap in metres
##   under it; off the screen, the wedge sits at the screen's edge pointing
##   its way.
## - the race tag: hung up and right of the plane on screen, tilted as the
##   near-miss tag is (scripts/endless/near_miss_hud_handoff.gd, which hangs
##   up and left), in its fonts: the count (3, 2, 1, GO) while the rival
##   takes its head start; then a line of words (the rule, what to do now,
##   why the lead dropped) over the gap in big gilt numbers, and once ahead
##   the lead's hold filling under them.
## - the result, big, in the tag's place: the word and a line under it,
##   popped in, held, then faded.
## The tag and the result are sized like the near-miss HUD: in D px of a
## 2560 x 1440 window, scaled to the window.

const WORDS = preload("res://assets/fonts/newsreader-latin.woff2")
const NUMS_ITALIC = preload("res://assets/fonts/barlow-semi-condensed-800-italic-latin.woff2")

const BONE := Color(0.93,0.87,0.72)
const EMBER := Color(0.98,0.5,0.22)
const GOLD := Color("ffd36b")
const CREAM := Color("f6f3ea")
const LOST := Color("ff8a6b")
const MIST := Color("cfe3ee")
const OUTLINE := Color(0.0,0.0,0.0,0.55)
const GILT_EDGE := Color(0.23,0.15,0.04,0.8)
## The bracket: its half size (px) for a plane's size on screen, at least
## and at most; its ticks' length (share of the half size) and width (px);
## its alpha offered and held.
const BRACKET := Vector2(16.0,46.0)
const TICK := 0.4
const TICK_WIDTH := 1.5
const OFFERED := 0.42
const HELD := 0.9
## How much the held bracket closes in.
const CLOSE_IN := 0.35
## The marker: its size (px), height over the rival (px), bob (px, Hz);
## past FAR m it's an ember.
const WEDGE := Vector2(13.0,11.0)
const WEDGE_OVER := 22.0
const BOB := Vector2(3.0,0.9)
const FAR := 450.0
## Kept this far in from the screen's edge (px) when off it.
const EDGE := 36.0
## The marker's text size (px of a UI_HEIGHT window).
const SMALL := 15
## The marker is drawn for a window UI_HEIGHT px tall and grows with a
## taller one (a high-density screen), at least 1x.
const UI_HEIGHT := 900.0

## The tag (D px): its tilt, where its lower left corner hangs off the plane
## on screen, how fast it follows, the room it keeps from the window's edges
## (left, top, right, bottom).
const ANGLE := -0.12
const TAG_OFFSET := Vector2(130.0,-70.0)
const FOLLOW := 10.0
const KEEP := Vector4(30.0,330.0,560.0,50.0)
## Its rows (D px): the words, the gap's number, the count's numerals, the
## lead's bar (length, height) and the gap between rows.
const WORDS_PX := 36.0
const BIG_PX := 88.0
const COUNT_PX := 180.0
const LEAD_BAR := Vector2(380.0,11.0)
const ROW_GAP := 10.0
## The count's pop: from POP times its size to 1 over POP_TIME of a beat.
const POP := 1.4
const POP_TIME := 0.18
## The result: the word's size, the line's, how long it pops in (s) and
## fades (s).
const RESULT_PX := 116.0
const RESULT_SMALL_PX := 42.0
const RESULT_POP := 0.2
const NOTE_FADE := 0.8

## What to draw this frame (rival_race.gd fills them).
var offer := {}   # {at: Vector2 (screen), size: float (px), hold: 0..1, alpha}
var mark := {}    # {at: Vector2, on_screen: bool, dir: Vector2, far: bool, text: String, alpha}
## {plane: Vector2 (screen), count: 3..1, 0 GO, -1 none, beat: 0..1 through
## the beat, words: String, warn: bool, big: String, gold: bool, lead: 0..1
## or -1, alpha}
var tag := {}
var _clock := 0.0
var _anchor := Vector2.ZERO
var _anchored := false
var _result := {}   # {big, small, col, px}
var _result_age := INF
var _result_hold := 3.5

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## The result, held `hold` s: `kind` "won", "lost", "time" or "off".
func say(big: String, small: String, kind: String, hold := 3.5) -> void:
	var col: Color = {"won":GOLD,"lost":LOST}.get(kind,CREAM)
	_result = {"big":big,"small":small,"col":col,"px":RESULT_PX*(0.6 if kind == "off" else 1.0)}
	_result_age = 0.0
	_result_hold = hold

func note_text() -> String:
	if _result.is_empty() or _result_alpha() <= 0.0: return ""
	return (String(_result.big)+"  ·  "+String(_result.small)).strip_edges()

func _result_alpha() -> float:
	if _result_age >= _result_hold+NOTE_FADE: return 0.0
	return clampf(1.0-(_result_age-_result_hold)/NOTE_FADE,0.0,1.0)

func step(delta: float) -> void:
	_clock += delta
	_result_age += delta
	queue_redraw()

## The marker's scale for the window now.
func ui() -> float:
	return maxf(get_viewport_rect().size.y/UI_HEIGHT,1.0)

## The tag's scale: D px to the window's.
func _k() -> float:
	var size := get_viewport_rect().size
	return minf(size.x/2560.0,size.y/1440.0)

func _draw() -> void:
	var font := get_theme_default_font()
	var k := ui()
	if not offer.is_empty():
		var at: Vector2 = offer.at
		var hold := float(offer.hold)
		var half := float(offer.size)*k*(1.0-CLOSE_IN*smoothstep(0.0,1.0,hold))
		var a := lerpf(OFFERED,HELD,smoothstep(0.0,0.3,hold))*float(offer.alpha)
		var c := Color(BONE.r,BONE.g,BONE.b,a)
		var t := half*TICK
		for sx: float in [-1.0,1.0]:
			for sy: float in [-1.0,1.0]:
				var corner := at+Vector2(sx*half,sy*half)
				draw_line(corner,corner-Vector2(sx*t,0.0),c,TICK_WIDTH*k,true)
				draw_line(corner,corner-Vector2(0.0,sy*t),c,TICK_WIDTH*k,true)
		if hold > 0.0:
			var y := at.y+half+6.0*k
			draw_line(Vector2(at.x-half,y),Vector2(at.x-half+2.0*half*hold,y),Color(BONE.r,BONE.g,BONE.b,a),TICK_WIDTH*k,true)
	if not mark.is_empty():
		var col: Color = EMBER if bool(mark.far) else BONE
		col.a = 0.9*float(mark.alpha)
		var at: Vector2 = mark.at
		var w := WEDGE*k
		if bool(mark.on_screen):
			var tip := at-Vector2(0.0,(WEDGE_OVER+sin(_clock*TAU*BOB.y)*BOB.x)*k)
			draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(-w.x*0.5,-w.y),tip+Vector2(w.x*0.5,-w.y)]),col)
			_text(font,String(mark.text),at+Vector2(0.0,WEDGE_OVER*0.9*k),col,k)
		else:
			# At the edge, pointing its way.
			var d: Vector2 = mark.dir
			var side := d.orthogonal()
			var tip := at+d*w.y*0.5
			draw_colored_polygon(PackedVector2Array([tip,tip-d*w.y+side*w.x*0.5,tip-d*w.y-side*w.x*0.5]),col)
			var inward := at-d*(WEDGE.y+14.0)*k
			_text(font,String(mark.text),inward+Vector2(0.0,5.0*k),col,k)
	var plane: Variant = tag.get("plane")
	var showing := _result_alpha() > 0.0 and not _result.is_empty()
	if not tag.is_empty() or showing:
		if plane is Vector2: _place(plane as Vector2)
		draw_set_transform(_anchor,ANGLE,Vector2.ONE)
		if showing: _draw_result()
		elif not tag.is_empty(): _draw_tag()
		draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	else: _anchored = false

## The tag's corner: off the plane, kept on the screen, eased.
func _place(plane: Vector2) -> void:
	var k := _k()
	var size := get_viewport_rect().size
	var to := plane+TAG_OFFSET*k
	to = Vector2(clampf(to.x,KEEP.x*k,size.x-KEEP.z*k),clampf(to.y,KEEP.y*k,size.y-KEEP.w*k))
	_anchor = to if not _anchored else _anchor.lerp(to,minf(1.0,get_process_delta_time()*FOLLOW))
	_anchored = true

func _draw_tag() -> void:
	var k := _k()
	var a := float(tag.get("alpha",1.0))
	var count := int(tag.get("count",-1))
	var y := 0.0
	if count >= 0:
		# The count: a big numeral popping in each beat, GO in gold.
		var beat := float(tag.get("beat",0.0))
		var pop := lerpf(POP,1.0,smoothstep(0.0,POP_TIME,beat))
		var fade := 1.0 if count == 0 else 1.0-smoothstep(0.75,1.0,beat)
		var text := "GO" if count == 0 else str(count)
		_gilt(NUMS_ITALIC,text,Vector2(0.0,y),COUNT_PX*pop*k,Color(GOLD.r,GOLD.g,GOLD.b,a*fade),k)
		y -= (COUNT_PX*pop*0.78+ROW_GAP*1.5)*k
		_words(String(tag.get("words","")),Vector2(0.0,y),false,a)
		return
	var lead := float(tag.get("lead",-1.0))
	if lead >= 0.0:
		_lead_bar(Vector2(0.0,y),lead,a)
		y -= (LEAD_BAR.y+ROW_GAP*1.4)*k
	var big := String(tag.get("big",""))
	if big != "":
		var col := GOLD if bool(tag.get("gold",false)) else CREAM
		_gilt(NUMS_ITALIC,big,Vector2(0.0,y),BIG_PX*k,Color(col.r,col.g,col.b,a),k)
		y -= BIG_PX*0.95*k+ROW_GAP*k
	_words(String(tag.get("words","")),Vector2(0.0,y),bool(tag.get("warn",false)),a)

func _draw_result() -> void:
	var k := _k()
	var a := _result_alpha()
	var pop := lerpf(1.25,1.0,smoothstep(0.0,RESULT_POP,_result_age))
	var col: Color = _result.col
	var px := float(_result.px)
	_gilt(NUMS_ITALIC,String(_result.big),Vector2.ZERO,px*pop*k,Color(col.r,col.g,col.b,a),k)
	var small := String(_result.small)
	if small != "":
		var at := Vector2(4.0*k,-(px*pop*0.95+ROW_GAP)*k)
		_words(small,at,false,a,RESULT_SMALL_PX)

## Big numbers or a word, baseline at `at` (left), with a dark edge.
func _gilt(font: Font, text: String, at: Vector2, px: float, col: Color, k: float) -> void:
	var size := maxi(roundi(px),8)
	# A soft shadow under it, so it reads on cloud and snow.
	draw_string_outline(font,at+Vector2(3.0,5.0)*k,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,maxi(roundi(12.0*k),3),Color(0,0,0,0.25*col.a))
	draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,maxi(roundi(8.0*k),2),Color(GILT_EDGE.r,GILT_EDGE.g,GILT_EDGE.b,GILT_EDGE.a*col.a))
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,col)

## A line of words after a small faceted diamond, baseline at `at`.
func _words(text: String, at: Vector2, warn: bool, a: float, px := WORDS_PX) -> void:
	if text == "": return
	var k := _k()
	var col := LOST if warn else CREAM
	col.a = a
	var size := maxi(roundi(px*k),8)
	var r := px*0.2*k
	var c := at+Vector2(r,-px*0.32*k)
	_facet(c,r,Color(col.r,col.g,col.b,a))
	var p := at+Vector2(r*3.0,0.0)
	draw_string_outline(WORDS,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,maxi(roundi(6.0*k),2),Color(0,0,0,0.6*a))
	draw_string(WORDS,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,col)

## A small faceted diamond: lit top left, shaded bottom right.
func _facet(c: Vector2, r: float, col: Color) -> void:
	var top := c+Vector2(0.0,-r*1.25)
	var bottom := c+Vector2(0.0,r*1.25)
	var left := c+Vector2(-r,0.0)
	var right := c+Vector2(r,0.0)
	draw_colored_polygon(PackedVector2Array([top,right,bottom,left]),Color(0,0,0,0.5*col.a))
	draw_colored_polygon(PackedVector2Array([top,c,left]),col.lightened(0.35))
	draw_colored_polygon(PackedVector2Array([top,right,c]),col)
	draw_colored_polygon(PackedVector2Array([left,c,bottom]),col.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([c,right,bottom]),col.darkened(0.45))

## The lead's hold: a track and a gold fill with a facet at its head.
func _lead_bar(at: Vector2, share: float, a: float) -> void:
	var k := _k()
	var w := LEAD_BAR.x*k
	var h := LEAD_BAR.y*k
	draw_rect(Rect2(at+Vector2(0.0,-h),Vector2(w,h)),Color(0,0,0,0.45*a))
	draw_rect(Rect2(at+Vector2(0.0,-h),Vector2(w,h)),Color(CREAM.r,CREAM.g,CREAM.b,0.18*a))
	if share > 0.0:
		draw_rect(Rect2(at+Vector2(0.0,-h),Vector2(w*share,h)),Color(GOLD.r,GOLD.g,GOLD.b,a))
		_facet(at+Vector2(w*share,-h*0.5),h*0.9,Color(GOLD.r,GOLD.g,GOLD.b,a))

func _text(font: Font, text: String, at: Vector2, col: Color, k: float) -> void:
	if text == "": return
	var size := roundi(SMALL*k)
	var w := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var p := at+Vector2(-w*0.5,0.0)
	draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,roundi(4.0*k),Color(OUTLINE.r,OUTLINE.g,OUTLINE.b,OUTLINE.a*col.a))
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,col)
