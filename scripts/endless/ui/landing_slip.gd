extends Control
## The landing slip (the flight UI's landing card; the card before it is
## scripts/endless/landing_summary.gd, kept for --ui=old and --landing=old):
## a cream slip at the right of the screen when the plane comes to rest from
## the air (PilotTallies `landed`), read from the book's `flight`. Top to
## bottom: the flight's number and where it ended, the money earned (counted
## up), time, way and lines in three cells, the best line with its moves as
## small tiles, the flight's tallies two to a row, the records it set, its
## challenges, and what it found as the logbook's slots.
##
## It takes no keys, hides while an overlay is up (`game.overlay`) and goes
## at lift-off. A part with nothing to say is left out. Drawn with the kit
## (ui_kit.gd) and the logbook's slots (book_kit.gd).
##
## The game's side is the old card's: `shown`, `step(delta)`, `lines()`.

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const Book = preload("res://scripts/endless/ui/book_kit.gd")
const Pad = preload("res://scripts/pad.gd")
const Tallies = preload("res://scripts/endless/pilot_tallies.gd")
const PLACE_LINES := "res://scripts/endless/place_lines.gd"

## The slip's width and its gap from the screen's right and top, mock px.
const WIDTH := 316.0
const RIGHT := 28.0
const TOP_MOST := 64.0
## Where its middle sits down the screen.
const MIDDLE := 0.45
## It goes this fast (s); the parts re-read this often (s).
const FADE_OUT := 0.18
const READ_EVERY := 0.25
## Each part arrives this long after the one above, the first after FIRST.
const FIRST := 0.1
const STAGGER := 0.045
const PART_IN := 0.2
## The money counts up from COUNT_AT s after the slip shows, over COUNT_FOR.
const COUNT_AT := 0.35
const COUNT_FOR := 0.9
## New records listed; the rest are counted.
const RECORDS_SHOWN := 4
## Tiles of the best line's moves and of the finds shown in a row.
const MOVES_SHOWN := 9
const FINDS_SHOWN := 7
## The tallies listed when not zero, each [key, the slip's short label].
const ROWS := [["trees","trees"],["grass_m","grass"],["clouds","clouds"],["flocks","flocks"],["skims","skims"],
	["scrapes","scrapes"],["crashes","crashes"],["photos","photos"]]

var game: Node
## Up (wanted).
var shown := false
var _a := 0.0
## Seconds since it showed.
var _t := 0.0
var _read := 0.0
var _card := {}
var _parts: Array = []
var _counted := 0.0

func _init(host: Node = null) -> void:
	game = host
	name = "LandingSlip"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	# Its hiding under an overlay holds while the tree is paused (the logbook).
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	Pad.hub.device_changed.connect(_device_changed)

func _exit_tree() -> void:
	if Pad.hub.device_changed.is_connected(_device_changed): Pad.hub.device_changed.disconnect(_device_changed)

func _device_changed(_pad: bool) -> void:
	queue_redraw()

func _process(_delta: float) -> void:
	if game != null: visible = _a > 0.0 and game.overlay == null

## One frame (from the main scene's tick, after the tallies).
func step(delta: float) -> void:
	var t: RefCounted = game.tallies
	if t.landed:
		shown = true
		_a = 0.0
		_t = 0.0
		_read = 0.0
		_counted = 0.0
	if bool(game.hand_landing.flying()) or t.lifted: shown = false
	if shown:
		_a = 1.0
		_t += delta
	else: _a = maxf(_a-delta/FADE_OUT,0.0)
	visible = _a > 0.0 and game.overlay == null
	if not visible: return
	_read -= delta
	if _read <= 0.0:
		_read = READ_EVERY
		_card = card(game.book,game.get("finds"))
		_parts = parts(_card)
	var earned := float(_card.get("earned",0))
	if _t >= COUNT_AT: _counted = move_toward(_counted,earned,maxf(earned,1.0)*delta/COUNT_FOR)
	queue_redraw()

# --- What it says ------------------------------------------------------------------------

## The slip's words from `book.flight` (`finds`: the game's finds, or null):
## {n, place, earned, aloft, metres, lines, best {name, points, mult,
## glyphs}, tallies [[label, value]], records [[label, value]], more,
## challenges [[label, value, done]], found [{glyph, title}], other}.
static func card(book: PilotBook, finds: Variant = null) -> Dictionary:
	var f: Dictionary = book.flight
	var ft: Dictionary = f.get("tally",{})
	var out := {"n":int(f.get("n",0)),"place":"","earned":int(f.get("earned",0)),
		"aloft":Tallies.say("aloft",float(ft.get("aloft",0.0))),"metres":Tallies.say("metres",float(ft.get("metres",0.0))),
		"lines":(f.get("lines",[]) as Array).size(),"best":{},"tallies":[],"records":[],"more":0,"challenges":[],"found":[],"other":""}
	if f.has("place"): out.place = str(load(PLACE_LINES).place_name(str(f.place)))
	var line: Dictionary = f.get("best_line",{})
	if not line.is_empty():
		out.best = {"name":str(line.get("name","")),"points":Tallies.big(float(line.get("points",0.0))),
			"mult":"x%.1f" % float(line.get("mult",1.0)),"glyphs":line.get("glyphs",[])}
	for row: Array in ROWS:
		var v := float(ft.get(row[0],0.0))
		if v > 0.0: out.tallies.append([row[1],Tallies.say(row[0],v).trim_suffix(" blades")])
	var recs: Array = f.get("records",[])
	for i in mini(recs.size(),RECORDS_SHOWN):
		var key: String = recs[i]
		out.records.append([Tallies.label(key),Tallies.say(key,float(book.records.get(key,0.0)))])
	out.more = maxi(recs.size()-RECORDS_SHOWN,0)
	for c: Dictionary in f.get("challenges",[]):
		var done := bool(c.get("done",false))
		var v := "%d/%d" % [int(c.get("got",0)),int(c.get("of",0))]
		if float(c.get("time",0.0)) > 0.0: v += "  "+Tallies.clock(float(c.time))
		if int(c.get("money",0)) > 0: v += "  +%d" % int(c.money)
		out.challenges.append(["%s %s" % [str(c.get("kind","challenge")),"done" if done else "ended"],v,done])
	# The finds: the table's as slots, the rest counted by kind.
	var rest := []
	var by_id := {}
	if finds != null:
		for e: Dictionary in finds.rows: by_id[str(e.book_id)] = e
	for id: Variant in f.get("found",[]):
		if by_id.has(str(id)): out.found.append({"glyph":Book.find_glyph(by_id[str(id)]),"title":str(by_id[str(id)].title)})
		else: rest.append(id)
	var words := PackedStringArray()
	for kn: Array in Tallies.finds(rest):
		if int(kn[1]) > 0: words.append("%d %s" % [kn[1],str(kn[0]).trim_suffix("s") if int(kn[1]) == 1 else kn[0]])
	out.other = "  ·  ".join(words)
	return out

## The slip's parts in order, each {kind, h (mock px), ...}.
static func parts(c: Dictionary) -> Array:
	var out := [{"kind":"top","h":38.0+(15.0 if str(c.place) != "" else 0.0)},{"kind":"earned","h":50.0},{"kind":"cells","h":44.0}]
	out.append({"kind":"head","h":30.0,"label":"Best line"})
	var best: Dictionary = c.best
	if best.is_empty(): out.append({"kind":"quiet","h":22.0,"label":"No line banked"})
	else:
		out.append({"kind":"best","h":24.0})
		if not (best.glyphs as Array).is_empty(): out.append({"kind":"moves","h":32.0})
	var tallies: Array = c.tallies
	if not tallies.is_empty():
		out.append({"kind":"head","h":30.0,"label":"This flight"})
		for i in range(0,tallies.size(),2): out.append({"kind":"pair","h":21.0,"a":tallies[i],"b":tallies[i+1] if i+1 < tallies.size() else []})
	if not (c.records as Array).is_empty():
		out.append({"kind":"head","h":30.0,"label":"New records"})
		for r: Array in c.records: out.append({"kind":"row","h":22.0,"label":r[0],"value":r[1],"tick":true})
		if int(c.more) > 0: out.append({"kind":"quiet","h":20.0,"label":"and %d more in the logbook" % int(c.more)})
	if not (c.challenges as Array).is_empty():
		out.append({"kind":"head","h":30.0,"label":"Challenges"})
		for r: Array in c.challenges: out.append({"kind":"row","h":22.0,"label":r[0],"value":r[1],"tick":bool(r[2])})
	var found: Array = c.found
	if not found.is_empty() or str(c.other) != "":
		out.append({"kind":"head","h":30.0,"label":"Found"})
		if not found.is_empty():
			out.append({"kind":"slots","h":40.0})
			out.append({"kind":"quiet","h":20.0,"label":str(found[0].title) if found.size() == 1 else "%d new in the logbook" % found.size(),"dark":true})
		if str(c.other) != "": out.append({"kind":"quiet","h":20.0,"label":str(c.other)})
	out.append({"kind":"foot","h":12.0})
	return out

## The slip as text lines (for drivers and checks).
func lines() -> Array:
	var c: Dictionary = _card if not _card.is_empty() else card(game.book,game.get("finds"))
	var out := ["landed | flight %d%s" % [int(c.n)," | on "+str(c.place) if str(c.place) != "" else ""],"earned | +%d" % int(c.earned),
		"aloft | %s" % c.aloft,"flown | %s" % c.metres,"lines | %d" % int(c.lines)]
	if not (c.best as Dictionary).is_empty(): out.append("best line | %s | %s %s | %d moves" % [c.best.name,c.best.points,c.best.mult,(c.best.glyphs as Array).size()])
	for r: Array in c.tallies: out.append("tally | %s | %s" % [r[0],r[1]])
	for r: Array in c.records: out.append("record | %s | %s" % [r[0],r[1]])
	for r: Array in c.challenges: out.append("challenge | %s | %s" % [r[0],r[1]])
	for e: Dictionary in c.found: out.append("found | %s | %s" % [e.title,e.glyph])
	if str(c.other) != "": out.append("found | %s" % c.other)
	return out

# --- Drawing -----------------------------------------------------------------------------

func _draw() -> void:
	if _parts.is_empty() or _a <= 0.003: return
	var k := Kit.scale_of(size)
	var h1 := 0.0
	for p: Dictionary in _parts: h1 += float(p.h)
	# A long slip shrinks to fit under the top margin.
	var s := minf(k,(size.y-2.0*TOP_MOST*k)/h1)
	var w := WIDTH*s
	var h := h1*s
	var arrive := Kit.slip_in(_t)
	var a := arrive.y*_a
	var x := size.x-RIGHT*k-w+arrive.x*s+(1.0-_a)*Kit.SLIP_CUT*s
	var r := Rect2(roundf(x),roundf(maxf((size.y-h)*MIDDLE,TOP_MOST*k*0.5)),w,h)
	Kit.slip(self,r,s,a)
	var y := r.position.y
	for i in _parts.size():
		var p: Dictionary = _parts[i]
		var pa := a*smoothstep(0.0,PART_IN,_t-FIRST-STAGGER*i)
		_part(p,r,y,s,pa)
		y += float(p.h)*s
	# The way to the logbook, under the slip.
	var hint := Kit.pick([["J","","logbook"]])
	if not hint.is_empty(): Kit.prompts(self,hint,Vector2(r.end.x-Kit.SLIP_CUT*s,r.end.y+10.0*s),s,true,true,a*smoothstep(0.6,0.9,_t))

func _part(p: Dictionary, r: Rect2, y: float, k: float, a: float) -> void:
	if a <= 0.003: return
	var left := r.position.x+Kit.LABEL_X*k
	var right := r.end.x-Kit.VALUE_PAD*k
	var cy := y+float(p.h)*k*0.5
	match str(p.kind):
		"top":
			var n := "Flight %d" % int(_card.n)
			var nw := Kit.text_w(Kit.MED,n.to_upper(),10.5,k,0.14)
			Kit.head(self,r,y+8.0*k,k,"Landed",30.0,0.0,Kit.VALUE_PAD+10.0+nw/k,a)
			Kit.text(self,Kit.MED,n.to_upper(),Vector2(right,y+23.0*k),10.5,k,0.14,Kit.DIM,1.0,a)
			if str(_card.place) != "": Kit.text(self,Kit.NUM,("on "+str(_card.place)).to_upper(),Vector2(left,y+41.0*k),11.5,k,0.1,Kit.LAND,0.0,a)
		"earned":
			var earned := int(_card.earned)
			var done := _counted >= float(earned)-0.5
			var kick := 1.0-smoothstep(0.0,0.3,_t-COUNT_AT-COUNT_FOR) if earned > 0 and done else 0.0
			var coin := Vector2(left+12.0*k,cy+1.0*k)
			draw_circle(coin+Vector2(0.0,1.5*k),10.5*k,Color(Kit.NIGHT,0.3*a),true,-1.0,true)
			Book.glyph(self,"coin","icon",coin,26.0*k*(1.0+0.12*kick),Color(1,1,1,a))
			if kick > 0.003: Book.glyph(self,"coin","lit",coin,26.0*k*(1.0+0.12*kick),Color(1,1,1,a*kick))
			Kit.text(self,Kit.NUM,"+"+_group(roundi(_counted)),Vector2(left+31.0*k,cy+1.0*k),36.0,k,0.0,Kit.INK if earned > 0 else Kit.DIM,0.0,a)
			Kit.text(self,Kit.MED,"EARNED",Vector2(right,cy+9.0*k),10.5,k,0.2,Kit.DIM,1.0,a)
		"cells":
			var cw := (right-left)/3.0
			Book.stat(self,Vector2(left,y+2.0*k),k,"Aloft",str(_card.aloft),a)
			Book.stat(self,Vector2(left+cw,y+2.0*k),k,"Flown",str(_card.metres),a)
			Book.stat(self,Vector2(left+cw*2.0,y+2.0*k),k,"Lines",str(int(_card.lines)),a)
		"head":
			Kit.head(self,r,y,k,str(p.label),float(p.h),6.0,Kit.VALUE_PAD,a)
		"quiet":
			Kit.text(self,Kit.MED,str(p.label).to_upper(),Vector2(left,cy),11.0,k,0.12,Kit.LAND if p.get("dark",false) else Kit.DIM,0.0,a)
		"best":
			var best: Dictionary = _card.best
			var mw := Kit.text(self,Kit.NUM,str(best.mult),Vector2(right,cy),13.0,k,0.0,Kit.HEAD,1.0,a)
			var pw := Kit.text(self,Kit.NUM,str(best.points),Vector2(right-mw-7.0*k,cy),17.0,k,0.0,Kit.INK,1.0,a)
			_fit(str(best.name).to_upper(),Vector2(left,cy),13.0,k,0.1,Kit.LAND,right-mw-pw-18.0*k-left,a)
		"moves":
			var ids: Array = _card.best.glyphs
			var d := 24.0*k
			var n := mini(ids.size(),MOVES_SHOWN)
			for i in n:
				Book.slot(self,Rect2(roundf(left+i*(d+4.0*k)),roundf(y+2.0*k),d,d),k,str(ids[i]),true,a)
			if ids.size() > n: Kit.text(self,Kit.NUM,"+%d" % (ids.size()-n),Vector2(left+n*(d+4.0*k)+3.0*k,y+2.0*k+d*0.5),12.5,k,0.0,Kit.DIM,0.0,a)
		"pair":
			var half := (right-left)*0.5
			for i in 2:
				var cell: Array = p.a if i == 0 else p.b
				if cell.is_empty(): continue
				var cx := left+half*i
				var cr := cx+half-(12.0*k if i == 0 else 0.0)
				var vw := Kit.text(self,Kit.NUM,str(cell[1]),Vector2(cr,cy),14.0,k,0.0,Kit.INK,1.0,a)
				_fit(str(cell[0]).to_upper(),Vector2(cx,cy),11.0,k,0.12,Kit.LAND,cr-vw-8.0*k-cx,a)
		"row":
			var x := left
			if bool(p.get("tick",false)):
				Kit.slant(self,Rect2(left+1.0*k,cy-6.0*k,3.5*k,12.0*k),Color(Kit.TICK,a))
				x += 12.0*k
			var vw := Kit.text(self,Kit.NUM,str(p.value),Vector2(right,cy),14.5,k,0.0,Kit.INK,1.0,a)
			_fit(str(p.label).to_upper(),Vector2(x,cy),12.0,k,0.1,Kit.LAND,right-vw-10.0*k-x,a)
		"slots":
			var found: Array = _card.found
			var d := 32.0*k
			var n := mini(found.size(),FINDS_SHOWN)
			for i in n:
				# Each stamps in a beat after the one before.
				var sa := a*smoothstep(0.0,0.15,_t-0.75-0.1*i)
				Book.slot(self,Rect2(roundf(left+i*(d+6.0*k)),roundf(y+3.0*k),d,d),k,str(found[i].glyph),true,sa)
			if found.size() > n: Kit.text(self,Kit.NUM,"+%d" % (found.size()-n),Vector2(left+n*(d+6.0*k)+3.0*k,y+3.0*k+d*0.5),13.0,k,0.0,Kit.DIM,0.0,a)

## `s` from `at`, narrowed to `room` px when it runs longer.
func _fit(s: String, at: Vector2, px: float, k: float, track: float, col: Color, room: float, a: float) -> void:
	var w := Kit.text_w(Kit.MED,s,px,k,track)
	Kit.text(self,Kit.MED,s,at,px*minf(1.0,room/maxf(w,1.0)),k,track,col,0.0,a)

static func _group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = ","+s.right(3)+out
		s = s.left(s.length()-3)
	return ("-" if n < 0 else "")+s+out
