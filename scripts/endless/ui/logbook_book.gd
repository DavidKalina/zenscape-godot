extends Control
## The logbook as a book of slots (J, or the pause menu's Logbook; the page
## before it is scripts/endless/logbook_view.gd, kept for --ui=old and
## --logbook=old). One cream spread over the held flight:
##
## - the left page: the money, the pages as rows (Wilderness, Pilot), and
##   under them what the cursor is on: its tile large, its name once found,
##   its hint and how it is had until then;
## - the right page, Wilderness: every find in the table as a slot, grouped
##   by area with the area's count. Found, a slot is a dark tile with its
##   glyph in colour; until then an empty recess with the outline of its
##   kind (a ring, a landing, a line, a moment). One found this flight has a
##   dot at its corner;
## - the right page, Pilot: the records as slots with their bests, the
##   tallies, the places and their lines.
##
## An overlay, as the page before it: open, it is `game.overlay` (the main
## scene's keys go quiet) and the tree is held; this runs through it.
## Arrows, WASD, the d-pad or the stick move the cursor; Q / E, Tab or the
## shoulder buttons turn the page; J, Esc or the pad's B close it. The mouse
## moves the cursor when it is free (opened from the pause menu).
##
## The game's side is the old page's: `open_book()`, `close_book()`,
## `is_open()`, `lines()`.

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const Book = preload("res://scripts/endless/ui/book_kit.gd")
const Pad = preload("res://scripts/pad.gd")
const StickSteps = preload("res://scripts/endless/ui/stick_steps.gd")
const Tallies = preload("res://scripts/endless/pilot_tallies.gd")
const PlaceLines = preload("res://scripts/endless/place_lines.gd")
const Table = preload("res://scripts/endless/finds_table.gd")

## The spread and its left page, mock px.
const SIZE := Vector2(1000.0,600.0)
const LEFT_W := 330.0
## The right page's padding: from the gutter, and from the slip's right.
const PAGE_PAD := 28.0
## The slot sizes tried, largest first, until every area fits; the gap
## between slots as a part of the slot.
const SLOTS := [44.0,40.0,36.0,32.0,28.0,24.0]
const GAP := 0.18
## An area's heading, and the gap under its slots.
const AREA_HEAD := 28.0
const AREA_GAP := 4.0
## Room left under the last area is shared out between them, up to this each.
const SPREAD_MOST := 22.0
const WASH_A := 0.42
const WASH_T := 0.2
## The tallies the left page shows large on the Pilot page.
const LARGE := ["aloft","metres","landings"]
const FOOT := [["Arrows","D-pad","browse"],["Q E","LB RB","page"],["Esc","B","close"]]

var game: Node
## The pages' ids, and the one open.
var pages: Array = []
var page := 0
## The slot under the cursor (an index into `slots`).
var cur := 0
## Every find: {id, kind, found, glyph, ghost, title, hint, area, fresh,
## flight, value}.
var slots: Array = []
## The areas: {title, got, of, slots (indices)}.
var groups: Array = []
## The slots as they stand on the page: [[index, ...], ...], top to bottom.
var _grid: Array = []
var _slot := 44.0
var _spread := 0.0
var _rects: Array[Rect2] = []
var _tabs: Array[Rect2] = []
var _age := 0.0
var _page_age := 1.0
var _cur_t := Kit.ON
var _prev := -1
var _prev_t := Kit.OFF
var _tab_t := PackedFloat32Array()
var _was_paused := false
var _stick := StickSteps.new()
var _pilot := {}

func _init(host: Node = null) -> void:
	game = host
	name = "Logbook"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	Pad.hub.device_changed.connect(_device_changed)

func _device_changed(_pad: bool) -> void:
	queue_redraw()

func is_open() -> bool:
	return game != null and game.overlay == self

## Opens it (only when no other overlay is up).
func open_book() -> void:
	if game == null or game.overlay != null: return
	game.overlay = self
	build()
	_age = 0.0
	_page_age = 1.0
	_cur_t = 0.0
	_prev = -1
	_stick.rest()
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	queue_redraw()

func close_book() -> void:
	if not is_open(): return
	game.overlay = null
	visible = false
	get_tree().paused = _was_paused

func _exit_tree() -> void:
	if Pad.hub.device_changed.is_connected(_device_changed): Pad.hub.device_changed.disconnect(_device_changed)
	# Never leave the tree held behind it.
	if is_open(): close_book()

# --- What it holds -----------------------------------------------------------------------

## Reads the book and the finds into `slots`, `groups` and the Pilot page.
func build() -> void:
	var book: PilotBook = game.book
	var finds: Variant = game.get("finds")
	slots.clear()
	groups.clear()
	if finds != null and int(finds.rows.size()) > 0:
		var fresh: Array = book.flight.get("found",[])
		for area: String in Table.AREAS:
			var g := {"title":str(Table.AREAS[area]),"got":0,"of":0,"slots":[]}
			for e: Dictionary in finds.rows:
				if str(e.area) != area: continue
				var done: bool = finds.is_found(e)
				var s := {"id":str(e.id),"kind":str(e.kind),"found":done,"glyph":Book.find_glyph(e),"ghost":Book.kind_glyph(str(e.kind)),
					"title":str(e.title),"hint":str(e.get("hint","")),"area":g.title,"fresh":str(e.book_id) in fresh,
					"flight":int(book.found.get(str(e.book_id),0)),"value":""}
				var line := str(e.get("line",""))
				if line != "" and book.records.has(line): s.value = PlaceLines.lap(float(book.records[line]))
				g.of = int(g.of)+1
				if done: g.got = int(g.got)+1
				(g.slots as Array).append(slots.size())
				slots.append(s)
			if int(g.of) > 0: groups.append(g)
	pages = ["wilderness","pilot"] if not slots.is_empty() else ["pilot"]
	page = clampi(page,0,pages.size()-1)
	cur = clampi(cur,0,maxi(slots.size()-1,0))
	_tab_t.resize(pages.size())
	_tab_t.fill(Kit.OFF)
	_tab_t[page] = Kit.ON
	_pilot = pilot(book)
	_fit()

## The Pilot page: {records [{key, label, value, set}], tallies [[label,
## value]], places (PlaceLines' rows), large {key: value}, worn [[slot,
## item]]}.
static func pilot(book: PilotBook) -> Dictionary:
	var out := {"records":[],"tallies":[],"places":[],"large":{},"worn":[]}
	var known := []
	for row: Array in Tallies.RECORDS:
		known.append(row[0])
		var has := book.records.has(row[0])
		out.records.append({"key":row[0],"label":row[1],"value":Tallies.say(row[0],float(book.records[row[0]])) if has else "","set":has})
	for key: String in book.records:
		# The place lines' times read under their place.
		if key.begins_with("line/") or key in known: continue
		out.records.append({"key":key,"label":Tallies.label(key),"value":Tallies.say(key,float(book.records[key])),"set":true})
	known = []
	for row: Array in Tallies.TALLIES:
		known.append(row[0])
		var said := Tallies.say(row[0],float(book.tally.get(row[0],0.0)))
		if row[0] in LARGE: out.large[row[0]] = said
		else: out.tallies.append([row[1],said])
	for key: String in book.tally:
		if not key in known: out.tallies.append([Tallies.label(key),Tallies.say(key,float(book.tally[key]))])
	for kn: Array in Tallies.finds(book.found.keys()):
		if str(kn[0]) != "wilderness finds" and int(kn[1]) > 0: out.tallies.append([str(kn[0])+" found",str(kn[1])])
	out.tallies.append(["items owned",str(book.owned.size())])
	for slot: String in book.worn:
		var item := str(book.worn[slot])
		out.worn.append([slot.replace("_"," "),item.get_slice("/",1) if "/" in item else item])
	return out

## The largest slot at which every area fits the right page, and the slots'
## places on it.
func _fit() -> void:
	var wide := SIZE.x-LEFT_W-PAGE_PAD-Kit.VALUE_PAD
	var tall := SIZE.y-16.0-16.0
	_spread = 0.0
	for px: float in SLOTS:
		_slot = px
		var cols := maxi(floori((wide+px*GAP)/(px*(1.0+GAP))),1)
		_grid = []
		var h := 0.0
		for g: Dictionary in groups:
			var ids: Array = g.slots
			for i in range(0,ids.size(),cols): _grid.append(ids.slice(i,i+cols))
			h += AREA_HEAD+ceilf(float(ids.size())/cols)*px*(1.0+GAP)+AREA_GAP
		if h <= tall:
			_spread = minf((tall-h)/maxf(groups.size(),1.0),SPREAD_MOST)
			break

## The page as text lines (for drivers and checks).
func lines() -> Array:
	var book: PilotBook = game.book
	if _pilot.is_empty(): build()
	var out := ["money | %d" % int(book.money),"flights | %d" % int(book.flights)]
	if not slots.is_empty():
		out.append("[wilderness] %d / %d" % [_got(),slots.size()])
		for g: Dictionary in groups:
			out.append("  %s | %d / %d" % [g.title,int(g.got),int(g.of)])
			for i: int in g.slots:
				var s: Dictionary = slots[i]
				out.append("    %s%s (%s)%s" % ["* " if s.found else "- ",str(s.title) if s.found else (str(s.hint) if str(s.hint) != "" else "?"),
					s.glyph if s.found else s.ghost," | "+str(s.value) if str(s.value) != "" else ""])
	out.append("[records]")
	for r: Dictionary in _pilot.records: out.append("  %s | %s" % [r.label,r.value if r.set else "-"])
	out.append("[tallies]")
	for key: String in _pilot.large: out.append("  %s | %s" % [Tallies.label(key),_pilot.large[key]])
	for r: Array in _pilot.tallies: out.append("  %s | %s" % [r[0],r[1]])
	if not (_pilot.places as Array).is_empty():
		out.append("[places]")
		for r: Dictionary in _pilot.places: out.append(("  %s:" % r.label) if r.get("kind","") == "place" else ("    %s | %s" % [r.label,r.value]))
	return out

func _got() -> int:
	var n := 0
	for s: Dictionary in slots:
		if s.found: n += 1
	return n

# --- The cursor --------------------------------------------------------------------------

func on_slots() -> bool:
	return page < pages.size() and str(pages[page]) == "wilderness"

## The cursor to slot `i`.
func select(i: int) -> void:
	if slots.is_empty(): return
	i = clampi(i,0,slots.size()-1)
	if i == cur: return
	_prev = cur
	_prev_t = -0.001
	cur = i
	_cur_t = 0.0
	queue_redraw()

## The cursor one slot along the reading order (`dx`) or one row up or down
## (`dy`), round the ends.
func move(dx: int, dy: int) -> void:
	if not on_slots() or slots.is_empty(): return
	if dx != 0:
		select(posmod(cur+dx,slots.size()))
		return
	for r in _grid.size():
		var col := (_grid[r] as Array).find(cur)
		if col < 0: continue
		var to: Array = _grid[posmod(r+dy,_grid.size())]
		select(int(to[mini(col,to.size()-1)]))
		return

## The page `by` along, round the ends.
func turn(by: int) -> void:
	if pages.size() < 2: return
	_tab_t[page] = -0.001
	page = posmod(page+by,pages.size())
	_tab_t[page] = 0.0
	_page_age = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not visible: return
	if not is_open():
		visible = false
		return
	_age += delta
	_page_age += delta
	if _cur_t < 0.5: _cur_t += delta
	if _prev_t > -0.5: _prev_t -= delta
	for i in _tab_t.size():
		if absf(_tab_t[i]) < 0.5: _tab_t[i] += delta if _tab_t[i] >= 0.0 else -delta
	var lean := _stick.step(delta)
	if lean != Vector2i.ZERO:
		if on_slots(): move(lean.x,lean.y)
		elif lean.x != 0: turn(lean.x)
	# Cheap enough to draw each frame it is up: the run-ins need it anyway.
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_open(): return
	var view := get_viewport()
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: return
		var at := (make_input_local(event) as InputEventMouse).position
		if on_slots():
			for i in _rects.size():
				if _rects[i].has_point(at): select(i)
		return
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if not b.pressed or b.button_index != MOUSE_BUTTON_LEFT or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: return
		var at := (make_input_local(event) as InputEventMouse).position
		for i in _tabs.size():
			if _tabs[i].has_point(at) and i != page: turn(i-page)
		view.set_input_as_handled()
		return
	# The stick's leans are steps in `_process` (stick_steps.gd).
	if StickSteps.is_stick(event):
		view.set_input_as_handled()
		return
	var key := event as InputEventKey
	var code := KEY_NONE
	if key != null and key.pressed: code = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	var fresh := key == null or not key.echo
	var joy := event as InputEventJoypadButton
	var pad := joy.button_index if joy != null and joy.pressed else JOY_BUTTON_INVALID
	if (code in [KEY_J,KEY_ESCAPE] and fresh) or event.is_action_pressed(&"ui_cancel"): close_book()
	elif (code in [KEY_E,KEY_TAB] and fresh) or pad == JOY_BUTTON_RIGHT_SHOULDER: turn(1)
	elif (code == KEY_Q and fresh) or pad == JOY_BUTTON_LEFT_SHOULDER: turn(-1)
	elif event.is_action_pressed(&"ui_left",true) or code == KEY_A: _side(-1)
	elif event.is_action_pressed(&"ui_right",true) or code == KEY_D: _side(1)
	elif event.is_action_pressed(&"ui_up",true) or code == KEY_W: move(0,-1)
	elif event.is_action_pressed(&"ui_down",true) or code == KEY_S: move(0,1)
	elif key == null and joy == null: return
	# Every key and button stops here while the book is up.
	view.set_input_as_handled()

func _side(by: int) -> void:
	if on_slots(): move(by,0)
	else: turn(by)

# --- Drawing -----------------------------------------------------------------------------

func _draw() -> void:
	if game == null or pages.is_empty(): return
	var k := Kit.scale_of(size)
	var arrive := Kit.slip_in(_age)
	var a := arrive.y
	draw_rect(Rect2(Vector2.ZERO,size),Color(Kit.NIGHT,WASH_A*clampf(_age/WASH_T,0.0,1.0)))
	var r := Rect2(((size-SIZE*k)*0.5).round(),SIZE*k)
	r.position.x -= roundf(arrive.x*k)
	Kit.slip(self,r,k,a)
	# The gutter: a hairline and the right page's shade falling away from it.
	var gx := roundf(r.position.x+LEFT_W*k)
	var top := r.position.y+14.0*k
	var foot := r.end.y-14.0*k
	var shade := Color(Kit.INK,0.06*a)
	draw_polygon(PackedVector2Array([Vector2(gx,top),Vector2(gx+16.0*k,top),Vector2(gx+16.0*k,foot),Vector2(gx,foot)]),
		PackedColorArray([shade,Color(shade,0.0),Color(shade,0.0),shade]))
	draw_rect(Rect2(gx,top,maxf(roundf(k),1.0),foot-top),Color(Kit.RULE,Kit.RULE.a*a))
	_draw_left(r,k,a)
	var pa := a*smoothstep(0.0,0.14,_page_age)
	if on_slots(): _draw_slots(r,gx,k,pa)
	else: _draw_pilot(r,gx,k,pa)
	Kit.prompts(self,Kit.pick(FOOT if on_slots() else FOOT.slice(1)),size-Vector2(28.0,50.0)*k,k,true,false,a)

func _draw_left(r: Rect2, k: float, a: float) -> void:
	var book: PilotBook = game.book
	var lp := Rect2(r.position,Vector2((LEFT_W-12.0)*k,r.size.y))
	var left := r.position.x+Kit.LABEL_X*k
	var right := r.position.x+(LEFT_W-26.0)*k
	Kit.head(self,lp,r.position.y+8.0*k,k,"Logbook",30.0,0.0,14.0,a)
	# The money.
	var my := r.position.y+62.0*k
	draw_circle(Vector2(left+11.0*k,my+1.5*k),9.5*k,Color(Kit.NIGHT,0.3*a),true,-1.0,true)
	Book.glyph(self,"coin","icon",Vector2(left+11.0*k,my),24.0*k,Color(1,1,1,a))
	Kit.text(self,Kit.NUM,_group(int(book.money)),Vector2(left+29.0*k,my),27.0,k,0.0,Kit.INK,0.0,a)
	Kit.text(self,Kit.MED,("%d FLIGHT" if int(book.flights) == 1 else "%d FLIGHTS") % int(book.flights),Vector2(right,my+5.0*k),10.5,k,0.16,Kit.DIM,1.0,a)
	# The pages.
	_tabs.clear()
	var y := r.position.y+90.0*k
	for i in pages.size():
		var id := str(pages[i])
		var hint := "%d / %d" % [_got(),slots.size()] if id == "wilderness" else ""
		_tabs.append(Kit.row(self,lp,y,k,id,_tab_t[i],30.0,15.0,hint,16.0,a))
		y += 30.0*k
	y += 14.0*k
	Kit.hair(self,Vector2(left,y),right,k,Color(Kit.RULE_SOFT,Kit.RULE_SOFT.a*a))
	y += 18.0*k
	if on_slots(): _draw_detail(left,right,y,r.end.y,k,a)
	else: _draw_pilot_left(left,right,y,k,a)

## What the cursor is on, from `y` down the left page.
func _draw_detail(left: float, right: float, y: float, foot: float, k: float, a: float) -> void:
	if slots.is_empty(): return
	var s: Dictionary = slots[cur]
	var found := bool(s.found)
	var pop := Kit.bez(_cur_t/0.16,0.2,0.9,0.3,1.3)
	var d := 76.0*k
	var tile := Rect2(left,y,d,d).grow((pop-1.0)*4.0*k)
	Book.slot(self,tile,k,str(s.glyph),found,a,Kit.OFF,false,str(s.ghost))
	var tx := left+d+16.0*k
	Kit.text(self,Kit.MED,Book.kind_word(str(s.kind)).to_upper(),Vector2(tx,y+12.0*k),10.5,k,0.26,Kit.HEAD,0.0,a)
	Kit.text(self,Kit.MED,str(s.area).to_upper(),Vector2(tx,y+31.0*k),11.0,k,0.12,Kit.LAND,0.0,a)
	if found:
		var when := "Found" if int(s.flight) <= 0 else "Found on flight %d" % int(s.flight)
		if bool(s.fresh): when = "Found this flight"
		Kit.slant(self,Rect2(tx+1.0*k,y+47.0*k,3.5*k,12.0*k),Color(Kit.TICK,a))
		Kit.text(self,Kit.NUM,when.to_upper(),Vector2(tx+11.0*k,y+53.0*k),11.5,k,0.08,Kit.INK,0.0,a)
	else:
		Kit.text(self,Kit.MED,"NOT FOUND YET",Vector2(tx,y+53.0*k),10.5,k,0.14,Kit.DIM,0.0,a)
	y += d+24.0*k
	var wide := right-left
	if found:
		y = _para(str(s.title),Kit.SERIF,22.0,27.0,0.0,Kit.INK,left,y,wide,k,a)
		# What led there, kept under its name.
		if str(s.hint) != "": y = _para(str(s.hint),Kit.MED,13.5,19.0,0.03,Kit.DIM,left,y+6.0*k,wide,k,a)
		if str(s.value) != "":
			y += 10.0*k
			Book.stat(self,Vector2(left,y),k,"Best time",str(s.value),a)
	else:
		# Its hint is all the page says of it; with none, only where.
		var lead := str(s.hint) if str(s.hint) != "" else "Somewhere around "+_lower_the(str(s.area))
		y = _para(lead,Kit.SERIF,22.0,27.0,0.0,Kit.LAND if str(s.hint) != "" else Kit.DIM,left,y,wide,k,a)
		y += 8.0*k
		Kit.text(self,Kit.MED,Book.kind_how(str(s.kind)).to_upper(),Vector2(left,y+8.0*k),10.5,k,0.14,Kit.DIM,0.0,a)
	# The count, at the page's foot.
	var got := _got()
	var by := foot-64.0*k
	Kit.text(self,Kit.MED,"FOUND",Vector2(left,by),9.5,k,0.2,Kit.DIM,0.0,a)
	var w := Kit.text(self,Kit.NUM,str(got),Vector2(left,by+24.0*k),30.0,k,0.0,Kit.INK,0.0,a)
	Kit.text(self,Kit.NUM,"/ %d" % slots.size(),Vector2(left+w+7.0*k,by+28.0*k),15.0,k,0.0,Kit.DIM,0.0,a)
	Kit.hair(self,Vector2(left,by+46.0*k),right,k,Color(Kit.TRACK,Kit.TRACK.a*a),2.0)
	Kit.hair(self,Vector2(left,by+46.0*k),left+(right-left)*float(got)/maxf(slots.size(),1.0),k,Color(Kit.INK,a),2.0)

func _draw_pilot_left(left: float, right: float, y: float, k: float, a: float) -> void:
	var book: PilotBook = game.book
	var half := (right-left)*0.5
	var large: Dictionary = _pilot.large
	Book.stat(self,Vector2(left,y),k,"Flights",str(int(book.flights)),a)
	Book.stat(self,Vector2(left+half,y),k,"Landings",str(large.get("landings","0")),a)
	Book.stat(self,Vector2(left,y+46.0*k),k,"Aloft",str(large.get("aloft","0:00")),a)
	Book.stat(self,Vector2(left+half,y+46.0*k),k,"Flown",str(large.get("metres","0 m")),a)
	y += 108.0*k
	var worn: Array = _pilot.worn
	if worn.is_empty(): return
	Kit.text(self,Kit.MED,"WORN",Vector2(left,y),9.5,k,0.2,Kit.DIM,0.0,a)
	y += 20.0*k
	for w: Array in worn:
		var vw := Kit.text(self,Kit.NUM,str(w[1]).to_upper(),Vector2(right,y),12.5,k,0.06,Kit.INK,1.0,a)
		_fit_text(str(w[0]).to_upper(),Vector2(left,y),11.5,k,0.1,Kit.LAND,right-vw-10.0*k-left,a)
		y += 22.0*k

## The Wilderness page: each area's heading and count over its slots.
func _draw_slots(r: Rect2, gx: float, k: float, a: float) -> void:
	var page_r := Rect2(gx+(PAGE_PAD-Kit.LABEL_X)*k,r.position.y,r.end.x-gx-(PAGE_PAD-Kit.LABEL_X)*k,r.size.y)
	var left := gx+PAGE_PAD*k
	var right := r.end.x-Kit.VALUE_PAD*k
	var d := roundf(_slot*k)
	var pitch := roundf(_slot*(1.0+GAP)*k)
	_rects.resize(slots.size())
	var y := r.position.y+16.0*k
	var row := 0
	for g: Dictionary in groups:
		var count := "%d / %d" % [int(g.got),int(g.of)]
		var whole := int(g.got) == int(g.of)
		var cw := Kit.text_w(Kit.NUM,count,12.5,k)
		Kit.head(self,page_r,y,k,str(g.title),AREA_HEAD,6.0,Kit.VALUE_PAD+10.0+cw/k,a)
		Kit.text(self,Kit.NUM,count,Vector2(right,y+(6.0+(AREA_HEAD-6.0)*0.5)*k),12.5,k,0.0,Kit.INK if whole else Kit.DIM,1.0,a)
		y += AREA_HEAD*k
		var ids: Array = g.slots
		while row < _grid.size() and not (_grid[row] as Array).is_empty() and int(_grid[row][0]) in ids:
			var line: Array = _grid[row]
			for c in line.size(): _rects[int(line[c])] = Rect2(roundf(left)+c*pitch,roundf(y),d,d)
			y += pitch
			row += 1
		y += (AREA_GAP+_spread)*k
	# The cursor's slot last, over its neighbours.
	for i in slots.size():
		if i != cur: _draw_slot(i,k,a)
	if not slots.is_empty(): _draw_slot(cur,k,a)

func _draw_slot(i: int, k: float, a: float) -> void:
	var s: Dictionary = slots[i]
	var t := _cur_t if i == cur else (_prev_t if i == _prev else Kit.OFF)
	Book.slot(self,_rects[i],k,str(s.glyph),bool(s.found),a,t,bool(s.fresh),str(s.ghost))

## The Pilot page: the records as slots, the tallies, the places.
func _draw_pilot(r: Rect2, gx: float, k: float, a: float) -> void:
	var page_r := Rect2(gx+(PAGE_PAD-Kit.LABEL_X)*k,r.position.y,r.end.x-gx-(PAGE_PAD-Kit.LABEL_X)*k,r.size.y)
	var left := gx+PAGE_PAD*k
	var right := r.end.x-Kit.VALUE_PAD*k
	var y := r.position.y+16.0*k
	var records: Array = _pilot.records
	var set_n := 0
	for rec: Dictionary in records:
		if rec.set: set_n += 1
	var count := "%d / %d" % [set_n,records.size()]
	var cw := Kit.text_w(Kit.NUM,count,12.5,k)
	Kit.head(self,page_r,y,k,"Records",AREA_HEAD,6.0,Kit.VALUE_PAD+10.0+cw/k,a)
	Kit.text(self,Kit.NUM,count,Vector2(right,y+(6.0+(AREA_HEAD-6.0)*0.5)*k),12.5,k,0.0,Kit.DIM,1.0,a)
	y += (AREA_HEAD+4.0)*k
	var cols := 4
	var cell := (right-left)/cols
	var d := roundf(40.0*k)
	for i in records.size():
		var rec: Dictionary = records[i]
		var cx := left+cell*(i%cols)
		var cy := y+floorf(float(i)/cols)*54.0*k
		var id := Book.stat_glyph(str(rec.key))
		Book.slot(self,Rect2(roundf(cx),roundf(cy),d,d),k,id if id != "" else "line",bool(rec.set),a)
		var tx := cx+d+10.0*k
		_fit_text(str(rec.label).to_upper(),Vector2(tx,cy+11.0*k),9.5,k,0.16,Kit.DIM,cx+cell-8.0*k-tx,a)
		Kit.text(self,Kit.NUM,str(rec.value) if rec.set else "–",Vector2(tx,cy+28.0*k),16.0,k,0.0,Kit.INK if rec.set else Kit.DIM,0.0,a)
	y += ceilf(float(records.size())/cols)*54.0*k+2.0*k
	y = _draw_list("Tallies",_pilot.tallies,page_r,left,right,y,k,a)
	var places: Array = []
	for p: Dictionary in _pilot.places:
		if p.get("kind","") == "place": places.append([str(p.label),"",true])
		else: places.append([str(p.label),str(p.value),false])
	if not places.is_empty(): _draw_list("Places",places,page_r,left,right,y,k,a)

## A heading and `rows` ([label, value] or [label, "", true] for a name over
## its rows) down three columns. Returns the y under it.
func _draw_list(title: String, rows: Array, page_r: Rect2, left: float, right: float, y: float, k: float, a: float) -> float:
	Kit.head(self,page_r,y,k,title,AREA_HEAD,6.0,Kit.VALUE_PAD,a)
	y += (AREA_HEAD+2.0)*k
	var cols := 3
	var each := ceili(float(rows.size())/cols)
	var cell := (right-left+18.0*k)/cols
	for i in rows.size():
		var row: Array = rows[i]
		var cx := left+cell*floorf(float(i)/each)
		var cr := cx+cell-18.0*k
		var cy := y+(i%each)*22.0*k+11.0*k
		if row.size() > 2 and bool(row[2]):
			Kit.text(self,Kit.NUM,str(row[0]).to_upper(),Vector2(cx,cy),12.0,k,0.08,Kit.INK,0.0,a)
			continue
		var vw := Kit.text(self,Kit.NUM,str(row[1]),Vector2(cr,cy),14.0,k,0.0,Kit.INK,1.0,a)
		_fit_text(str(row[0]).to_upper(),Vector2(cx,cy),11.5,k,0.1,Kit.LAND,cr-vw-8.0*k-cx,a)
	return y+each*22.0*k+4.0*k

# --- Words -------------------------------------------------------------------------------

## `s` wrapped to `wide` px from (left, y): each line `lead` mock px. Returns
## the y under the last.
func _para(s: String, which: int, px: float, lead: float, track: float, col: Color, left: float, y: float, wide: float, k: float, a: float) -> float:
	var line := ""
	for word: String in s.split(" ",false):
		var next := word if line == "" else line+" "+word
		if line != "" and Kit.text_w(which,next,px,k,track) > wide:
			Kit.text(self,which,line,Vector2(left,y+lead*k*0.5),px,k,track,col,0.0,a)
			y += lead*k
			line = word
		else: line = next
	if line != "":
		Kit.text(self,which,line,Vector2(left,y+lead*k*0.5),px,k,track,col,0.0,a)
		y += lead*k
	return y

## `s` from `at`, narrowed to `room` px when it runs longer.
func _fit_text(s: String, at: Vector2, px: float, k: float, track: float, col: Color, room: float, a: float) -> void:
	var w := Kit.text_w(Kit.MED,s,px,k,track)
	Kit.text(self,Kit.MED,s,at,px*minf(1.0,room/maxf(w,1.0)),k,track,col,0.0,a)

## "The near coast" as it reads inside a sentence.
static func _lower_the(area: String) -> String:
	return "the"+area.substr(3) if area.begins_with("The ") else area

static func _group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = ","+s.right(3)+out
		s = s.left(s.length()-3)
	return ("-" if n < 0 else "")+s+out
