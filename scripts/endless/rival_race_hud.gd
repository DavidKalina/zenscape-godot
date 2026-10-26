extends Control
## The rival race on screen (scripts/endless/rival_race.gd), thin and out
## of the way:
## - the bracket: four corner ticks round a traffic plane that can be
##   challenged, faint; held, they close in and brighten, a line under them
##   filling with the hold.
## - in the race, the marker: a small down-pointing wedge over the rival,
##   bobbing (bone white, a warm ember when it is far), the gap in metres
##   under it; off the screen, the wedge sits at the screen's edge pointing
##   its way. Ahead of it: "ahead" and the lead's hold filling.
## - the result: one short line under the top, in the weight note's style,
##   held, then faded.

const BONE := Color(0.93,0.87,0.72)
const EMBER := Color(0.98,0.5,0.22)
const GOLD := Color("ffd36b")
const MIST := Color("cfe3ee")
const OUTLINE := Color(0.0,0.0,0.0,0.55)
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
## The small text's size, the result's size and its place from the top.
const SMALL := 15
const NOTE_SIZE := 24
const NOTE_TOP := 124.0

## The marks are drawn for a window UI_HEIGHT px tall and grow with a
## taller one (a high-density screen), at least 1x.
const UI_HEIGHT := 900.0

## What to draw this frame (rival_race.gd fills it).
var offer := {}   # {at: Vector2 (screen), size: float (px), hold: 0..1, alpha}
var mark := {}    # {at: Vector2, on_screen: bool, dir: Vector2, far: bool, text: String, lead: 0..1 or -1, alpha}
var _clock := 0.0
var _note: Label
var _note_age := INF
var _note_hold := 2.5
const NOTE_FADE := 0.8

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note = Label.new()
	_note.anchor_left = 0.0
	_note.anchor_right = 1.0
	_note.offset_top = NOTE_TOP
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size",NOTE_SIZE)
	_note.add_theme_color_override("font_outline_color",Color(0,0,0,0.7))
	_note.add_theme_constant_override("outline_size",5)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.modulate.a = 0.0
	add_child(_note)

## The result line, held `hold` s.
func say(text: String, win: bool, hold := 2.5) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color",GOLD if win else MIST)
	_note_age = 0.0
	_note_hold = hold

func note_text() -> String:
	return _note.text if _note.modulate.a > 0.0 else ""

func step(delta: float) -> void:
	_clock += delta
	_note_age += delta
	_note.modulate.a = clampf(1.0-(_note_age-_note_hold)/NOTE_FADE,0.0,1.0) if _note_age < _note_hold+NOTE_FADE else 0.0
	queue_redraw()

## The marks' scale for the window now.
func ui() -> float:
	return maxf(get_viewport_rect().size.y/UI_HEIGHT,1.0)

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
			_lead(at+Vector2(0.0,(WEDGE_OVER*0.9+8.0)*k),float(mark.lead),col,k)
		else:
			# At the edge, pointing its way.
			var d: Vector2 = mark.dir
			var side := d.orthogonal()
			var tip := at+d*w.y*0.5
			draw_colored_polygon(PackedVector2Array([tip,tip-d*w.y+side*w.x*0.5,tip-d*w.y-side*w.x*0.5]),col)
			var inward := at-d*(WEDGE.y+14.0)*k
			_text(font,String(mark.text),inward+Vector2(0.0,5.0*k),col,k)
			_lead(inward+Vector2(0.0,13.0*k),float(mark.lead),col,k)

func _text(font: Font, text: String, at: Vector2, col: Color, k: float) -> void:
	if text == "": return
	var size := roundi(SMALL*k)
	var w := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var p := at+Vector2(-w*0.5,0.0)
	draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,roundi(4.0*k),Color(OUTLINE.r,OUTLINE.g,OUTLINE.b,OUTLINE.a*col.a))
	draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,col)

## The lead's hold, a short line filling (none below 0).
func _lead(at: Vector2, share: float, col: Color, k: float) -> void:
	if share < 0.0: return
	var half := 22.0*k
	draw_line(at-Vector2(half,0.0),at+Vector2(half,0.0),Color(col.r,col.g,col.b,col.a*0.3),2.0*k,true)
	draw_line(at-Vector2(half,0.0),at-Vector2(half,0.0)+Vector2(2.0*half*share,0.0),Color(GOLD.r,GOLD.g,GOLD.b,col.a),2.0*k,true)
