extends Control
## The logbook (J; endless flight, docs/design/endless-flight/spec-wild-loop.md,
## lane `logbook`): every tally, record and find the pilot's book keeps,
## lifetime, and the money. An overlay: open, it is `game.overlay` (the main
## scene's keys go quiet) and the flight is held (the tree paused; this runs
## through it); J, Esc or the pad's cancel closes it.
##
## Drawn in the near-miss tag's look through LandingSummary's helpers (`ink`,
## `words`, `nums`, `plate`).

const Card = preload("res://scripts/endless/landing_summary.gd")
const Tallies = preload("res://scripts/endless/pilot_tallies.gd")
const PlaceLines = preload("res://scripts/endless/place_lines.gd")

## The page's width at a 900 px tall window, at most the window less MARGIN.
const WIDTH := 1060.0
const MARGIN := 48.0
const FADE := 0.15

var game: Node
var _a := 0.0
var _cols: Array = []
var _was_paused := false

func _init(host: Node = null) -> void:
	game = host
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func is_open() -> bool:
	return game != null and game.overlay == self

## Opens it (only when no other overlay is up).
func open_book() -> void:
	if game == null or game.overlay != null: return
	game.overlay = self
	_cols = columns(game.book)
	_a = 0.0
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	queue_redraw()

func close_book() -> void:
	if not is_open(): return
	game.overlay = null
	visible = false
	get_tree().paused = _was_paused

func _process(delta: float) -> void:
	if not visible: return
	if not is_open():
		visible = false
		return
	if _a < 1.0:
		_a = minf(1.0,_a+delta/FADE)
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open(): return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_J,KEY_ESCAPE]: close_book()
	elif event.is_action_pressed(&"ui_cancel"): close_book()
	else: return
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	# Never leave the tree held behind it.
	if is_open(): close_book()

## The page: [title, rows] columns, each row {label, value, col}.
static func columns(book: PilotBook) -> Array:
	var tallies := []
	var known := []
	for row: Array in Tallies.TALLIES:
		known.append(row[0])
		tallies.append({"label":row[1],"value":Tallies.say(row[0],float(book.tally.get(row[0],0.0)))})
	for key: String in book.tally:
		if not key in known: tallies.append({"label":Tallies.label(key),"value":Tallies.say(key,float(book.tally[key]))})
	var records := []
	known = []
	for row: Array in Tallies.RECORDS:
		known.append(row[0])
		var has := book.records.has(row[0])
		records.append({"label":row[1],"value":Tallies.say(row[0],float(book.records[row[0]])) if has else "-","col":Card.GOLD if has else Card.GREY})
	for key: String in book.records:
		# The place lines' times read under their place.
		if key.begins_with("line/"): continue
		if not key in known: records.append({"label":Tallies.label(key),"value":Tallies.say(key,float(book.records[key])),"col":Card.GOLD})
	var finds := []
	for kn: Array in Tallies.finds(book.found.keys()):
		finds.append({"label":kn[0],"value":str(kn[1])})
	finds.append({"label":"items owned","value":str(book.owned.size())})
	for slot: String in book.worn:
		finds.append({"label":"worn: "+slot.replace("_"," "),"value":str(book.worn[slot]).get_slice("/",1) if "/" in str(book.worn[slot]) else str(book.worn[slot])})
	var out := [["tallies",tallies],["records",records],["finds",finds]]
	# The places, each its lines with their best times (place_lines.gd).
	var places := PlaceLines.logbook_rows(book)
	if not places.is_empty(): out.append(["places",places])
	return out

## The page as text lines (for drivers and checks).
func lines() -> Array:
	var out := ["money | %d" % int(game.book.money),"flights | %d" % int(game.book.flights)]
	for col: Array in (_cols if not _cols.is_empty() else columns(game.book)):
		out.append("[%s]" % col[0])
		for r: Dictionary in col[1]: out.append(("  %s:" % r.label) if r.get("kind","") == "place" else ("  %s%s | %s" % ["  " if r.get("indent",false) else "",r.label,r.value]))
	return out

func _draw() -> void:
	if _cols.is_empty(): return
	var a := _a
	var s := size.y/900.0
	draw_rect(Rect2(Vector2.ZERO,size),Color(Card.KEY,0.5*a))
	var rows := 0
	for col: Array in _cols: rows = maxi(rows,(col[1] as Array).size())
	# A long page (more tallies than these) shrinks to fit.
	s = minf(s,(size.y-MARGIN)/(150.0+rows*30.0+70.0))
	var h := (150.0+rows*30.0+70.0)*s
	var n := maxi(_cols.size(),3)
	var w := minf(WIDTH*s*n/3.0,size.x-MARGIN*2.0)
	var col_w := (w-64.0*s-(n-3)*16.0*s)/float(n)
	var r := Rect2((size.x-w)*0.5,(size.y-h)*0.5,w,h)
	Card.plate(self,r,s,a)
	var left := r.position.x+32.0*s
	var right := r.end.x-32.0*s
	var y := r.position.y+48.0*s
	Card.ink(self,Card.words(30.0*s,0.22),"LOGBOOK",Vector2(left,y),30.0*s,Color(Card.CREAM,a),7.0*s,0.0)
	var book: PilotBook = game.book
	Card.ink(self,Card.nums(true),Tallies.big(float(book.money)),Vector2(right,y-2.0*s),50.0*s,Color(Card.GOLD,a),10.0*s,1.0,Color(Card.GOLD,0.5*a),6.0*s)
	var mw := Card.nums(true).get_string_size(Tallies.big(float(book.money)),HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(50.0*s)).x
	Card.ink(self,Card.words(15.0*s,0.08),"money",Vector2(right-mw-14.0*s,y+4.0*s),15.0*s,Color(Card.GREY,a),4.0*s,1.0)
	Card.ink(self,Card.words(15.0*s,0.06),("%d flight" if int(book.flights) == 1 else "%d flights") % int(book.flights),Vector2(left,y+34.0*s),15.0*s,Color(Card.GREY,a),4.0*s,0.0)
	var top := r.position.y+120.0*s
	for i in _cols.size():
		var cx := left+i*(col_w+16.0*s)
		var cr := cx+col_w-16.0*s
		Card.draw_row(self,{"kind":"head","label":str(_cols[i][0])},cx,cr,top,s,a)
		var cy := top+34.0*s
		for row: Dictionary in _cols[i][1]:
			if row.get("kind","") == "place":
				# A place's name over its lines.
				Card.ink(self,Card.words(15.0*s,0.06),str(row.label),Vector2(cx,cy),15.0*s,Color(Card.GOLD,0.9*a),4.0*s,0.0)
				cy += 30.0*s
				continue
			var ix := cx+(14.0*s if row.get("indent",false) else 0.0)
			Card.ink(self,Card.words(15.0*s,0.02),str(row.label),Vector2(ix,cy),15.0*s,Color(Card.CREAM,0.85*a),4.0*s,0.0)
			Card.ink(self,Card.nums(),str(row.value),Vector2(cr,cy),19.0*s,Color(row.get("col",Card.CREAM),a),5.0*s,1.0)
			cy += 30.0*s
	Card.ink(self,Card.words(14.0*s,0.08),"J or Esc to close",Vector2(r.position.x+r.size.x*0.5,r.end.y-26.0*s),14.0*s,Color(Card.GREY,a),4.0*s,0.5)
