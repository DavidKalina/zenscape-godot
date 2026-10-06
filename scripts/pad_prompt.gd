extends Label
## A hint line that names the controls of the device in hand
## (docs/gamepad.md "Prompts"). It is a Label, and `text` stays the keyboard
## and mouse line its owner set, so nothing that sets or reads it changes.
## `alternates` gives each such line its pad form; while the pad was used last
## (scripts/pad.gd `using_pad`) that form is drawn instead, with "{A}",
## "{LB}", "{LS}" and the like (or an action's name, "{fly_land}", for its
## pad binding) drawn as small faceted buttons in the linen's thread, each
## face button keeping a muted touch of its Xbox colour.
##
## `shown_text` reads back the line on screen, for tests.

const Pad = preload("res://scripts/pad.gd")
const Linen = preload("res://scripts/hud_linen.gd")
## Face buttons' muted colours.
const FACE := {"A":Color("a9c98f"),"B":Color("e7a08a"),"X":Color("97b6dc"),"Y":Color("e9d27f")}
const CHIP_FILL := Color(0.078,0.055,0.031,0.62)
const CHIP_EDGE := Color(0.890,0.843,0.741,0.85)
const CHIP_INK := Color("f1e8d4")
## A glyph's height as a share of the line's font size, and the gap round it.
const GLYPH := 1.45
const GAP := 0.3

## Keyboard text -> pad text.
var alternates := {}
var _shown := ""
var _tokens := false

## The line on screen now: the pad form while the pad is in hand.
func shown_text() -> String:
	if Pad.using_pad() and alternates.has(text): return str(alternates[text])
	return text

func _process(_delta: float) -> void:
	var want := shown_text()
	if want == _shown: return
	_shown = want
	_tokens = want.contains("{")
	visible_characters = 0 if _tokens else -1
	queue_redraw()

func _draw() -> void:
	if not _tokens: return
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var parts := split(_shown)
	var height := font_size*GLYPH
	var width := _width(parts,font,font_size)
	# A long line steps its size down to fit the label and the screen, never
	# below 10 px (the keys' longer line can have widened the label past it).
	var room := minf(size.x,get_viewport_rect().size.x-48.0)
	while width > room and font_size > 10:
		font_size -= 1
		height = font_size*GLYPH
		width = _width(parts,font,font_size)
	var x := (size.x-width)*0.5 if horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0
	var middle := size.y*0.5
	var ink := get_theme_color("font_color")
	var shadow := get_theme_color("font_shadow_color")
	var baseline := middle+(font.get_ascent(font_size)-font.get_descent(font_size))*0.5
	for part: Array in parts:
		if part[0] == "glyph":
			var w := glyph_width(str(part[1]),height)
			draw_glyph(self,str(part[1]),Vector2(x+w*0.5,middle),height,font,ink.a)
			x += w
		else:
			var words := str(part[1])
			if shadow.a > 0.0: draw_string(font,Vector2(x,baseline+1.0),words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,shadow)
			draw_string(font,Vector2(x,baseline),words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)
			x += font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x

func _width(parts: Array, font: Font, font_size: int) -> float:
	var width := 0.0
	for part: Array in parts:
		width += glyph_width(str(part[1]),font_size*GLYPH) if part[0] == "glyph" else font.get_string_size(str(part[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	return width

## A line as ["text", words] and ["glyph", id] parts.
static func split(line: String) -> Array:
	var out: Array = []
	var at := 0
	while at < line.length():
		var open := line.find("{",at)
		if open < 0:
			out.append(["text",line.substr(at)])
			break
		var close := line.find("}",open)
		if close < 0:
			out.append(["text",line.substr(at)])
			break
		if open > at: out.append(["text",line.substr(at,open-at)])
		var token := line.substr(open+1,close-open-1)
		var id := token if token in Pad.GLYPHS else Pad.glyph(token)
		out.append(["glyph",id if not id.is_empty() else "?"])
		at = close+1
	return out

## The words of a line with its glyphs named ("A", "LB"), for the card and
## the field notes, which draw plain text.
static func plain(line: String) -> String:
	var out := ""
	for part: Array in split(line):
		out += str(part[1])
	return out

## How wide a glyph draws, with its gap, at `height`.
static func glyph_width(id: String, height: float) -> float:
	var gap := height*GAP
	match id:
		"LB","RB","LT","RT","VIEW","MENU": return height*1.5+gap
		"DPAD","UP","DOWN","LEFT","RIGHT": return height+gap
	return height+gap

## Draws glyph `id` centred on `centre`, `height` tall: face buttons as
## round studs with their letter, bumpers and triggers as rounded pills
## (triggers squared at the top), the sticks as a ring round a cap, the D-pad
## as a cross with the pressed arm lit, View and Menu as their little marks.
static func draw_glyph(item: CanvasItem, id: String, centre: Vector2, height: float, font: Font, alpha := 1.0) -> void:
	var r := height*0.5
	var edge := Color(CHIP_EDGE,CHIP_EDGE.a*alpha)
	var fill := Color(CHIP_FILL,CHIP_FILL.a*alpha)
	var ink := Color(CHIP_INK,alpha)
	var line := maxf(1.0,height*0.08)
	var letter_size := int(round(height*0.62))
	match id:
		"A","B","X","Y":
			item.draw_circle(centre,r,fill,true,-1.0,true)
			item.draw_circle(centre,r-line*0.5,Color(FACE[id],0.9*alpha),false,line,true)
			_letter(item,font,id,centre,letter_size,Color(FACE[id].lerp(CHIP_INK,0.35),alpha))
		"LB","RB","LT","RT","VIEW","MENU":
			var rect := Rect2(centre-Vector2(r*1.5,r*0.82),Vector2(r*3.0,r*1.64))
			Linen.fill_round(item,rect,r*0.7,fill)
			var outline := Linen.round_points(rect.grow(-line*0.5),r*0.7)
			outline.append(outline[0])
			item.draw_polyline(outline,edge,line,true)
			if id == "VIEW":
				item.draw_rect(Rect2(centre+Vector2(-r*0.55,-r*0.35),Vector2(r*0.7,r*0.5)),ink,false,line)
				item.draw_rect(Rect2(centre+Vector2(-r*0.2,-r*0.1),Vector2(r*0.7,r*0.5)),ink,false,line)
			elif id == "MENU":
				for k in range(3): item.draw_line(centre+Vector2(-r*0.45,(k-1)*r*0.32),centre+Vector2(r*0.45,(k-1)*r*0.32),ink,line,true)
			else:
				_letter(item,font,id,centre,int(round(height*0.5)),ink)
		"LS","RS","L3","R3":
			item.draw_circle(centre,r,fill,true,-1.0,true)
			item.draw_circle(centre,r-line*0.5,edge,false,line,true)
			item.draw_circle(centre,r*0.55,Color(edge,edge.a*0.35),true,-1.0,true)
			# A click of a stick reads "L3", "R3"; the stick itself its letter.
			var click := id.ends_with("3")
			_letter(item,font,id if click else id.left(1),centre,int(round(height*(0.4 if click else 0.5))),ink)
		"DPAD","UP","DOWN","LEFT","RIGHT":
			var arm := r*0.36
			var cross := [Rect2(centre+Vector2(-arm,-r),Vector2(arm*2.0,r*2.0)),Rect2(centre+Vector2(-r,-arm),Vector2(r*2.0,arm*2.0))]
			for box: Rect2 in cross: item.draw_rect(box,fill,true)
			for box: Rect2 in cross: item.draw_rect(box.grow(-line*0.5),edge,false,line)
			var lit := {"UP":Vector2(0,-1),"DOWN":Vector2(0,1),"LEFT":Vector2(-1,0),"RIGHT":Vector2(1,0)}
			if lit.has(id):
				var d: Vector2 = lit[id]
				item.draw_circle(centre+d*r*0.62,arm*0.7,ink,true,-1.0,true)
		_:
			item.draw_circle(centre,r,fill,true,-1.0,true)
			_letter(item,font,"?",centre,letter_size,ink)

static func _letter(item: CanvasItem, font: Font, words: String, centre: Vector2, font_size: int, colour: Color) -> void:
	var extent := font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var baseline := centre.y+(font.get_ascent(font_size)-font.get_descent(font_size))*0.5
	item.draw_string(font,Vector2(centre.x-extent.x*0.5,baseline),words,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,colour)
