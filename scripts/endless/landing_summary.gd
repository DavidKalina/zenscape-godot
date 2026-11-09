extends Control
## The landing summary (endless flight; docs/design/endless-flight/spec-wild-loop.md,
## lane `logbook`): a card at the right of the screen when the plane comes to
## rest from the air (PilotTallies `landed`), read from the book's `flight`:
## time and distance aloft, the money earned, the best line's read-back, the
## flight's tallies, its challenges, the records it set and what it found.
## It takes no keys, hides while an overlay is up (`game.overlay`) and goes
## at lift-off. Empty parts (no line banked yet, no challenge) leave out
## their rows or say so in a word.
##
## The near-miss tag's look (near_miss_hud_handoff.gd): Newsreader 700 words,
## Barlow Semi Condensed 800 numbers, each with a #0E1013 keyline and drop;
## money and new records in its gold. The drawing helpers here (`ink`,
## `words`, `nums`) are the logbook's too.

const Tag = preload("res://scripts/endless/near_miss_hud_handoff.gd")
const Money = preload("res://scripts/endless/money.gd")
const Tallies = preload("res://scripts/endless/pilot_tallies.gd")
## The places' names (place_lines.gd; loaded when wanted: it preloads this
## card through its HUD).
const PLACE_LINES := "res://scripts/endless/place_lines.gd"

const KEY := Tag.KEY
const CREAM := Tag.CREAM
const GOLD := Tag.GOLD
const GREY := Tag.GREY
const NEAR_C := Tag.NEAR_C
## The card's width and its right margin at a 900 px tall window.
const WIDTH := 400.0
const MARGIN := 40.0
## Fade in and out (s); the rows re-read this often (s).
const FADE_IN := 0.35
const FADE_OUT := 0.2
const READ_EVERY := 0.25
## New records listed on the card; the rest are counted.
const RECORDS_SHOWN := 2
## The tallies the card lists (the time and the way have their own line),
## when not zero.
const ROWS := ["trees","grass_m","clouds","flocks","skims","scrapes","crashes","photos"]

var game: Node
## Up (wanted); its alpha.
var shown := false
var _a := 0.0
var _read := 0.0
var _rows: Array = []

static var _words := {}
static var _nums: FontVariation
static var _nums_i: FontVariation

func _init(host: Node = null) -> void:
	game = host
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# Its hiding under an overlay holds while the tree is paused (the logbook).
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if game != null: visible = _a > 0.0 and game.overlay == null

## One frame (from the main scene's tick, after the tallies).
func step(delta: float) -> void:
	var t: RefCounted = game.tallies
	if t.landed:
		shown = true
		_a = 0.0
		_read = 0.0
	if bool(game.hand_landing.flying()) or t.lifted: shown = false
	_a = clampf(_a+delta/(FADE_IN if shown else -FADE_OUT),0.0,1.0)
	visible = _a > 0.0 and game.overlay == null
	if not visible: return
	_read -= delta
	if _read <= 0.0:
		_read = READ_EVERY
		_rows = rows(game.book)
	queue_redraw()

## The card's rows from `book.flight`, each {kind: "title" | "big" | "row" |
## "sub" | "head" | "rule", label, value, col}.
static func rows(book: PilotBook) -> Array:
	var f: Dictionary = book.flight
	var ft: Dictionary = f.get("tally",{})
	var out := []
	out.append({"kind":"title","label":"LANDED","value":"flight %d" % int(f.get("n",0))})
	# Where, when it is a place (pilot_tallies.gd `_place`).
	if f.has("place"): out.append({"kind":"sub","label":"on %s" % load(PLACE_LINES).place_name(str(f.place)),"col":GOLD})
	out.append({"kind":"big","label":"earned","value":Money.money(int(f.get("earned",0))),"col":GOLD})
	out.append({"kind":"row","label":"aloft","value":"%s  ·  %s" % [Tallies.say("aloft",float(ft.get("aloft",0.0))),Tallies.say("metres",float(ft.get("metres",0.0)))]})
	# The best line, one row; left out when none was banked.
	var line: Dictionary = f.get("best_line",{})
	if not line.is_empty():
		var top := "%s  x%.1f" % [Tallies.big(float(line.get("points",0.0))),float(line.get("mult",1.0))]
		if line.has("name") and str(line.name) != "": top = "%s  ·  %s" % [str(line.name),top]
		out.append({"kind":"row","label":"best line","value":top,"col":GOLD})
	# New records: two, then the count of the rest. The flight's tallies,
	# challenges and finds are in the logbook (J).
	var recs: Array = f.get("records",[])
	for i in mini(recs.size(),RECORDS_SHOWN):
		var key: String = recs[i]
		out.append({"kind":"row","label":"record  "+Tallies.label(key),"value":Tallies.say(key,float(book.records.get(key,0.0))),"col":GOLD})
	if recs.size() > RECORDS_SHOWN: out.append({"kind":"sub","label":"and %d more in the logbook (J)" % (recs.size()-RECORDS_SHOWN),"col":GREY})
	return out

## The rows as text lines (for drivers and checks).
func lines() -> Array:
	var out := []
	for r: Dictionary in (_rows if not _rows.is_empty() else rows(game.book)):
		var s := str(r.get("label",""))
		if r.has("value"): s += "  |  "+str(r.value)
		out.append("%s: %s" % [r.kind,s])
	return out

static func _list(items: Array, sep: String) -> String:
	var parts := PackedStringArray()
	for i: Variant in items: parts.append(str(i))
	return sep.join(parts)

# --- Drawing --------------------------------------------------------------------------

func _draw() -> void:
	if _rows.is_empty(): return
	var s := size.y/900.0
	# The rows' heights at s = 1, for the plate; a long card shrinks to fit.
	var h1 := 44.0
	for r: Dictionary in _rows: h1 += row_h(str(r.kind))
	s = minf(s,(size.y-2.0*MARGIN*s)/h1)
	var h := h1*s
	var w := WIDTH*s
	var k := 1.0-pow(1.0-_a,3.0)
	var x := size.x-MARGIN*size.y/900.0-w+(1.0-k)*40.0*s
	var pad := 22.0*s
	var y := (size.y-h)*0.42
	plate(self,Rect2(x,y,w,h),s,_a)
	var cy := y+pad
	for r: Dictionary in _rows:
		var rh := row_h(str(r.kind))*s
		draw_row(self,r,x+pad,x+w-pad,cy+rh*0.5,s,_a)
		cy += rh

## A row's height at s = 1.
static func row_h(kind: String) -> float:
	match kind:
		"title": return 40.0
		"big": return 58.0
		"head": return 34.0
		"sub": return 24.0
		"rule": return 12.0
	return 27.0

## The card's plate: KEY, its top-left corner cut, a gold rule along the top.
static func plate(ci: CanvasItem, r: Rect2, s: float, a: float) -> void:
	var cut := 18.0*s
	var pts := PackedVector2Array([r.position+Vector2(cut,0.0),Vector2(r.end.x,r.position.y),r.end,
		Vector2(r.position.x,r.end.y),r.position+Vector2(0.0,cut)])
	ci.draw_colored_polygon(pts,Color(KEY,0.74*a))
	ci.draw_line(r.position+Vector2(cut,0.0),Vector2(r.end.x,r.position.y),Color(GOLD,0.85*a),2.0*s)
	ci.draw_line(r.position+Vector2(0.0,cut),r.position+Vector2(cut,0.0),Color(GOLD,0.85*a),2.0*s)

## One row between `left` and `right`, its middle at `y`.
static func draw_row(ci: CanvasItem, r: Dictionary, left: float, right: float, y: float, s: float, a: float) -> void:
	var col: Color = r.get("col",CREAM)
	var label := str(r.get("label",""))
	var value := str(r.get("value",""))
	match str(r.kind):
		"title":
			ink(ci,words(22.0*s,0.18),label,Vector2(left,y),22.0*s,Color(CREAM,a),6.0*s,0.0)
			ink(ci,words(15.0*s,0.06),value,Vector2(right,y+2.0*s),15.0*s,Color(GREY,a),4.0*s,1.0)
		"big":
			ink(ci,nums(true),"+"+value,Vector2(left,y),46.0*s,Color(col,a),10.0*s,0.0,Color(GOLD,0.5*a),6.0*s)
			ink(ci,words(15.0*s,0.08),label,Vector2(right,y+6.0*s),15.0*s,Color(GREY,a),4.0*s,1.0)
		"head":
			ink(ci,words(13.0*s,0.22),label.to_upper(),Vector2(left,y+5.0*s),13.0*s,Color(GOLD,0.9*a),4.0*s,0.0)
			ci.draw_line(Vector2(left,y+15.0*s),Vector2(right,y+15.0*s),Color(GOLD,0.25*a),1.0*s)
		"sub":
			ink(ci,words(15.0*s,0.02),label,Vector2(left,y),15.0*s,Color(r.get("col",CREAM),a),4.0*s,0.0)
		"rule":
			ci.draw_line(Vector2(left,y),Vector2(right,y),Color(GOLD,0.25*a),1.0*s)
		_:
			ink(ci,words(16.0*s,0.02),label,Vector2(left,y),16.0*s,Color(CREAM,0.85*a),4.0*s,0.0)
			ink(ci,nums(),value,Vector2(right,y),20.0*s,Color(col,a),5.0*s,1.0)

## `text` at `at` (its middle at at.y; `align` 0 left, 0.5 centre, 1 right):
## the tag's #0E1013 keyline `stroke` px, a drop shadow, and a glow.
static func ink(ci: CanvasItem, font: Font, text: String, at: Vector2, px: float, col: Color, stroke: float, align := 0.0, glow := Color(0,0,0,0), glow_px := 0.0) -> void:
	if text.is_empty() or col.a <= 0.003: return
	var ipx := maxi(roundi(px),4)
	var w := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx).x
	var p := at+Vector2(-w*align,ipx*0.35)
	var st := maxi(roundi(stroke),1)
	if glow.a > 0.0 and glow_px > 0.0:
		ci.draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,roundi(st+glow_px*1.6),Color(glow,glow.a*0.22*col.a))
	ci.draw_string_outline(font,p+Vector2(0.0,maxf(stroke*0.5,1.0)),text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,st,Color(KEY,0.45*col.a))
	ci.draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,st,Color(KEY,col.a))
	ci.draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,col)

## Newsreader 700 at `px`, tracked `track` em (the tag's words).
static func words(px: float, track: float) -> FontVariation:
	var key := "%d/%d" % [roundi(px),roundi(track*100.0)]
	if _words.has(key): return _words[key]
	var f := FontVariation.new()
	f.base_font = Tag.WORDS
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):700}
	f.spacing_glyph = roundi(px*track)
	_words[key] = f
	return f

## Barlow Semi Condensed 800, tabular (the tag's numbers); `italic` its slant.
static func nums(italic := false) -> FontVariation:
	if _nums == null:
		var tnum := {TextServerManager.get_primary_interface().name_to_tag("tnum"):1}
		_nums = FontVariation.new()
		_nums.base_font = Tag.NUMS
		_nums.opentype_features = tnum
		_nums_i = FontVariation.new()
		_nums_i.base_font = Tag.NUMS_ITALIC
		_nums_i.opentype_features = tnum
	return _nums_i if italic else _nums
