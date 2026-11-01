extends Control
## The place lines on screen (scripts/endless/place_lines.gd), drawn in the
## landing card's look through its helpers (landing_summary.gd `plate`,
## `ink`, `words`, `nums`, `draw_row`):
## - the line's tag, top right (the region's caption has the top middle),
##   while a line is flown: its name and the
##   next gate's number over the clock, the best time beside it. The start
##   moment: it pops in reading START, the clock glowing, and gold brackets
##   swell out from the screen's corners (a gate passed swells them too).
## - an attempt ended (a gate missed): the tag greys, says so, and fades.
## - the finish card, where the landing card stands (right, a little above
##   the middle): the time big in gilt, and the best, beaten or not. Held
##   FINISH_HOLD s, then faded; under the landing card it gives way.
## Sized for a 900 px tall window and scaled with it.

const Card = preload("res://scripts/endless/landing_summary.gd")

const KEY := Card.KEY
const CREAM := Card.CREAM
const GOLD := Card.GOLD
const GREY := Card.GREY

## The tag: width (px at s = 1), its top's distance from the window's top,
## the start moment's length (s), the pop's size and time, the fade after
## an attempt ended (s).
const TAG := Vector2(330.0,96.0)
const TAG_TOP := 26.0
const START_HOLD := 1.8
const POP := 1.25
const POP_TIME := 0.25
const END_FADE := 1.8
## The finish card: width, margin from the right, held (s), fades (s).
const CARD_W := 380.0
const CARD_MARGIN := 40.0
const FINISH_HOLD := 6.0
const FADE_IN := 0.3
const FADE_OUT := 0.4
## The corner brackets: how long (s), their arm's length (px) and width.
const FLASH := 0.55
const ARM := 64.0
const ARM_W := 3.0

var game: Node
## The tag: {title, best (-1 none), next, of, age (s since the start),
## ended ("" or why), end_age}; {} none.
var tag: Dictionary = {}
## The finish card's rows ({} none) and its age (s).
var card: Dictionary = {}
var _flash := -1.0
var _flash_k := 1.0
var _clock := 0.0

func _init(host: Node = null) -> void:
	game = host
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Its hiding under an overlay holds while the tree is paused (the logbook).
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	visible = game == null or game.overlay == null

func started(line: Dictionary, best: float) -> void:
	tag = {"title":str(line.title),"place":str(line.place),"best":best,"mark":float(line.get("mark",-1.0)),"next":1,"of":(line.gates as Array).size(),"age":0.0,"ended":"","end_age":0.0}
	card = {}
	_flash = 0.0
	_flash_k = 1.0

func gate(passed: int, of: int) -> void:
	if tag.is_empty(): return
	tag.next = passed+1
	tag.of = of
	_flash = 0.0
	_flash_k = 0.6

func ended(why: String) -> void:
	if tag.is_empty(): return
	tag.ended = {"missed":"missed gate %d" % (int(tag.next)+1),"skipped":"missed gate %d" % (int(tag.next)+1),
		"lost":"off the line","landed":"touched down","jump":"off the line"}.get(why,"off the line")
	tag.end_age = 0.0

func finished(line: Dictionary, t: float, beat: bool, was: float) -> void:
	tag = {}
	var rows := []
	rows.append({"kind":"title","label":"LINE DONE","value":str(line.place_name)})
	rows.append({"kind":"time","label":str(line.title),"value":lap(t)})
	if beat and was < 0.0:
		rows.append({"kind":"row","label":"best","value":"first time","col":GOLD})
	elif beat:
		rows.append({"kind":"row","label":"new best","value":"-%.1f s" % (was-t),"col":GOLD})
		rows.append({"kind":"sub","label":"was %s" % lap(was),"col":GREY})
	else:
		rows.append({"kind":"row","label":"best","value":lap(was)})
		rows.append({"kind":"sub","label":"+%.1f s off it" % (t-was),"col":GREY})
	var mark := float(line.get("mark",-1.0))
	if mark >= 0.0 and t <= mark and (was < 0.0 or was > mark): rows.append({"kind":"row","label":"under the mark","value":lap(mark),"col":GOLD})
	elif mark >= 0.0 and t > mark and (was < 0.0 or was > mark): rows.append({"kind":"sub","label":"the mark is %s" % lap(mark),"col":GREY})
	card = {"rows":rows,"age":0.0}
	_flash = 0.0
	_flash_k = 1.0

## The words the tag and the card show now (for drivers and checks).
func lines() -> Array:
	var out := []
	if not tag.is_empty(): out.append("tag: %s | %s | %s" % [_tag_head(),lap(_tag_time()),_tag_side()])
	if not card.is_empty():
		for r: Dictionary in card.rows: out.append("card %s: %s | %s" % [r.kind,r.get("label",""),r.get("value","")])
	return out

## One frame (from place_lines.gd, after its passes).
func step(delta: float, lines_node: Node) -> void:
	_clock += delta
	if _flash >= 0.0:
		_flash += delta
		if _flash > FLASH: _flash = -1.0
	if not tag.is_empty():
		tag.age = float(tag.age)+delta
		if str(tag.ended) != "":
			tag.end_age = float(tag.end_age)+delta
			if float(tag.end_age) > END_FADE: tag = {}
		elif not (lines_node.run as Dictionary).is_empty():
			tag.t = float(lines_node.run.t)
	if not card.is_empty():
		card.age = float(card.age)+delta
		if float(card.age) > FINISH_HOLD+FADE_OUT: card = {}
	queue_redraw()

func _tag_head() -> String:
	if str(tag.ended) != "": return str(tag.ended)
	if float(tag.age) < START_HOLD: return "START"
	return str(tag.title)

func _tag_time() -> float:
	return float(tag.get("t",0.0))

func _tag_side() -> String:
	if str(tag.ended) != "": return ""
	return "gate %d/%d" % [int(tag.next)+1,int(tag.of)]

func _draw() -> void:
	var s := size.y/900.0
	# The corner brackets under the tag and the card.
	if _flash >= 0.0: _draw_flash(s)
	if not tag.is_empty(): _draw_tag(s)
	var summary_up := game != null and game.get("summary") != null and bool(game.summary.shown)
	if not card.is_empty() and not summary_up: _draw_card(s)

func _draw_tag(s: float) -> void:
	var age := float(tag.age)
	var a := clampf(age/0.12,0.0,1.0)
	var ended := str(tag.ended) != ""
	if ended: a *= 1.0-smoothstep(END_FADE*0.4,END_FADE,float(tag.end_age))
	if a <= 0.003: return
	# The pop: in from POP times its size.
	var k := 1.0+(POP-1.0)*(1.0-smoothstep(0.0,POP_TIME,age))
	var w := TAG.x*s*k
	var h := TAG.y*s*k
	var r := Rect2(size.x-CARD_MARGIN*s-w,TAG_TOP*s,w,h)
	Card.plate(self,r,s*k,a)
	var left := r.position.x+22.0*s*k
	var right := r.end.x-22.0*s*k
	var y := r.position.y+24.0*s*k
	var head := _tag_head()
	var head_col := GREY if ended else GOLD
	var start := not ended and age < START_HOLD
	Card.ink(self,Card.words((18.0 if start else 13.0)*s*k,0.22),head.to_upper(),Vector2(left,y),(18.0 if start else 13.0)*s*k,Color(head_col,a),4.0*s,0.0)
	Card.ink(self,Card.words(14.0*s*k,0.06),_tag_side(),Vector2(right,y+1.0*s),14.0*s*k,Color(GREY,a),4.0*s,1.0)
	var cy := y+44.0*s*k
	var glow := 1.0-smoothstep(0.0,START_HOLD,age) if not ended else 0.0
	var tcol := GREY if ended else (GOLD.lerp(CREAM,smoothstep(0.0,START_HOLD,age)))
	Card.ink(self,Card.nums(true),lap(_tag_time()),Vector2(left,cy),40.0*s*k,Color(tcol,a),8.0*s,0.0,Color(GOLD,0.7*glow*a),8.0*s)
	var best := float(tag.best)
	var mark := float(tag.get("mark",-1.0))
	var side := ("best "+lap(best)) if best >= 0.0 else (("mark "+lap(mark)) if mark >= 0.0 else "no time yet")
	if not ended: Card.ink(self,Card.words(15.0*s*k,0.04),side,Vector2(right,cy+4.0*s),15.0*s*k,Color(GREY,a),4.0*s,1.0)

func _draw_card(s: float) -> void:
	var age := float(card.age)
	var a := clampf(age/FADE_IN,0.0,1.0)*(1.0-clampf((age-FINISH_HOLD)/FADE_OUT,0.0,1.0))
	if a <= 0.003: return
	var rows: Array = card.rows
	var h1 := 44.0
	for row: Dictionary in rows: h1 += 62.0 if row.kind == "time" else Card.row_h(str(row.kind))
	var h := h1*s
	var w := CARD_W*s
	var k := 1.0-pow(1.0-a,3.0)
	var x := size.x-CARD_MARGIN*s-w+(1.0-k)*40.0*s
	var y := (size.y-h)*0.42
	var pad := 22.0*s
	Card.plate(self,Rect2(x,y,w,h),s,a)
	var cy := y+pad
	for row: Dictionary in rows:
		var rh := (62.0 if row.kind == "time" else Card.row_h(str(row.kind)))*s
		var mid := cy+rh*0.5
		if row.kind == "time":
			Card.ink(self,Card.nums(true),str(row.value),Vector2(x+pad,mid),50.0*s,Color(GOLD,a),10.0*s,0.0,Color(GOLD,0.5*a),6.0*s)
			Card.ink(self,Card.words(15.0*s,0.08),str(row.label),Vector2(x+w-pad,mid+6.0*s),15.0*s,Color(GREY,a),4.0*s,1.0)
		else:
			Card.draw_row(self,row,x+pad,x+w-pad,mid,s,a)
		cy += rh

## Gold brackets in the screen's corners, swelling out and fading.
func _draw_flash(s: float) -> void:
	var t := clampf(_flash/FLASH,0.0,1.0)
	var a := (1.0-t*t)*0.8*_flash_k
	var inset := lerpf(0.16,0.04,smoothstep(0.0,1.0,t))
	var arm := ARM*s*(0.6+0.4*_flash_k)
	var mid := size*0.5
	for sx: float in [-1.0,1.0]:
		for sy: float in [-1.0,1.0]:
			var c := mid+Vector2(sx*mid.x*(1.0-inset),sy*mid.y*(1.0-inset*1.4))
			for pass_i in range(2):
				var col := Color(KEY,0.5*a) if pass_i == 0 else Color(GOLD,a)
				var ww := ARM_W*s*(2.2 if pass_i == 0 else 1.0)
				draw_line(c,c-Vector2(sx*arm,0.0),col,ww)
				draw_line(c,c-Vector2(0.0,sy*arm),col,ww)

## A line's time as 0:41.3 (place_lines.gd and the logbook read it so too).
static func lap(t: float) -> String:
	var d := roundi(maxf(t,0.0)*10.0)
	return "%d:%02d.%d" % [d/600,(d/10)%60,d%10]
