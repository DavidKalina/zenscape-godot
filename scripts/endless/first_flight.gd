extends Node
## The first flight (endless flight; docs/ship/spec-ship.md, lane
## `tutorial`): a guide over the first minutes of a fresh book. A ribbon
## with gates (rival_marks.gd's, as place_lines.gd draws them) leads the
## way, a card at the top says what to do and with which key (the pad's
## when the pad was used last), and each step ends when the player does it:
##   1 steer: through two level gates, the second off to the side;
##   2 low: the ribbon dips to a few metres over flat meadow; through its
##     low gate under LOW m (the meter fills, the tag pops);
##   3 pitch: the ribbon pulls up through a high gate;
##   4 near miss: the ribbon leads past a tree's crown; a near miss of a
##     tree or stone ends it;
##   5 bank: fly calm until the line banks (near_miss.gd banks a chain
##     BANK_AFTER s after its last move), then land where the marks are and
##     read what it paid on the landing summary.
## Then the book records `tutorial_done` and the game is the game. Skip:
## Backspace or the pad's D-pad down, shown from the start.
##
## Each leg is laid when its step begins, ahead of where the plane is and
## the way it flies, so a gate missed only lays the leg again (and trees,
## which stand as the plane nears, are there to be found). The low leg's
## run: the nearest heading to the plane's (0, +-20, +-40 degrees) with
## RUN_LEN m of dry meadow no rougher than FLAT m; else the nearest meadow
## by menu_spot.gd's search (`fallback` says which).
##
## Wanted on a fresh book (no `tutorial_done`, no flight before this one)
## once the title's takeoff is done; --first-flight starts it in any run
## (with --no-title: at once, in the air), --first-flight=0 never.

const RivalMarks = preload("res://scripts/endless/rival_marks.gd")
const RivalRace = preload("res://scripts/endless/rival_race.gd")
const PlaceLines = preload("res://scripts/endless/place_lines.gd")
const MenuSpot = preload("res://scripts/endless/menu_spot.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const TreePlan = preload("res://scripts/endless/tree_plan.gd")
const Pad = preload("res://scripts/pad.gd")
const WORDS = preload("res://assets/fonts/newsreader-latin.woff2")
const NUMS = preload("res://assets/fonts/barlow-semi-condensed-800-latin.woff2")

const CREAM := Color("f6f3ea")
const GOLD := Color("ffd36b")
const KEY := Color("0e1013")
const GREY := Color("8a93a0")

## Clearance (m over the turf) the low gate takes: its mouth is under it.
const LOW := 5.5
## The low run: this long, no more than FLAT m of rise along it.
const RUN_LEN := 170.0
const FLAT := 2.0
## Where the plane cruises the level gates, over the highest turf under them.
const CRUISE := Vector2(18.0,34.0)
## The high gate, over the turf.
const HIGH := 42.0
## A leg is laid again when its next gate is this far off, or passed by.
const LOST := 900.0
## Seconds the summary is read before the guide ends.
const READ := 4.0

enum {STEER, LOW_RUN, PITCH, NEAR, BANK, LAND, READING, DONE}

var game: Node
var marks: RivalMarks
var step_i := -1
var gates: Array = []
## Gates of `gates` that end each step: index -> step it ends.
var ends := {}
var next := 0
var course := {}
## How the low run was found: "ahead" (along a heading near the plane's),
## "meadow" (menu_spot.gd's nearest meadow) or "none".
var fallback := ""
## `fallback` as it was for the low run (the dip of steps 2 and 3).
var low_run := ""
## The tree the near-miss leg leads past ({} none found: any near miss ends it).
var tree := {}
var banked := false
## Trees the last search weighed.
var trees_seen := 0
var skipped := false
var lays := 0
var _prev := Vector3.INF
var _read := 0.0
var _flash := 0.0
var _card: Control
var _landing := {}

## Whether this run gets the guide.
static func wanted(book: RefCounted) -> bool:
	var args := preload("res://scripts/launch_args.gd").user_args()
	if "--first-flight=0" in args or "--first-flight=off" in args: return false
	if "--first-flight" in args or "--first-flight=1" in args: return true
	if "--no-title" in args: return false
	return not bool(book.get("tutorial_done")) and int(book.flights) <= 1

func setup(g: Node) -> void:
	game = g
	name = "FirstFlight"
	marks = RivalMarks.new()
	marks.name = "FirstFlightMarks"
	add_child(marks)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_card = Card.new()
	_card.guide = self
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_card)
	_card.visible = false

func running() -> bool:
	return step_i >= 0 and step_i < DONE

func _unhandled_input(event: InputEvent) -> void:
	if step_i >= DONE or game == null or game.stage != null: return
	var skip: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_BACKSPACE) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_DOWN)
	if skip:
		skipped = true
		_finish()
		get_viewport().set_input_as_handled()

## One frame, after the plane moved.
func step(delta: float) -> void:
	if step_i >= DONE: return
	# The title's takeoff first: the guide waits until the flight is the player's.
	if game.stage != null or game.plane == null: return
	if step_i < 0:
		step_i = STEER
		_lay()
	_flash = maxf(0.0,_flash-delta)
	var p: Vector3 = game.plane.position
	var a := _prev
	_prev = p
	var flying: bool = game.hand_landing.flying()
	var ev: Dictionary = game._events
	if ev.has("banked") and step_i >= BANK: banked = true
	if a != Vector3.INF and a.distance_to(p) > 150.0: a = Vector3.INF
	match step_i:
		STEER, LOW_RUN, PITCH:
			if a != Vector3.INF and flying: _passes(a,p)
			if _lost(p): _lay()
		NEAR:
			if a != Vector3.INF and flying: _passes(a,p)
			if ev.has("near"):
				var m: Dictionary = ev.near
				var surf := str(m.get("surface",""))
				if surf == "tree" or surf == "stone" or tree.is_empty(): _advance()
			elif _lost(p) or next >= gates.size(): _lay()
		BANK:
			if banked: _advance()
			# No line to bank (it was lost): straight on to the landing.
			elif float(game.near.chain_points) <= 0.0 and not ev.has("near"):
				_advance()
		LAND:
			if a != Vector3.INF and flying: _passes(a,p)
			if flying and _lost(p): _lay()
			if bool(game.summary.shown) and not flying: _advance()
		READING:
			_read += delta
			if _read >= READ or (flying and _read > 0.5): _finish()
	_show(delta,p)

func _advance() -> void:
	step_i += 1
	_flash = 0.6
	if step_i == PITCH: return  # the dip's leg goes on into the high gate
	if step_i == BANK: banked = false
	if step_i >= READING:
		_landing = {}
		marks.set_spot({},null)
		marks.set_course({})
		gates = []
		return
	_lay()

func _passes(a: Vector3, b: Vector3) -> void:
	if next >= gates.size(): return
	var g: Dictionary = gates[next]
	var r := RivalRace.through(g,a,b)
	if r == "through":
		marks.cleared(next)
		var ended: Variant = ends.get(next)
		next += 1
		if ended != null and int(ended) == step_i: _advance()
	elif r == "by": _lay()

## The next gate far off or well behind: the leg again from here.
func _lost(p: Vector3) -> bool:
	if next >= gates.size(): return false
	var g: Dictionary = gates[next]
	var to: Vector3 = (g.p as Vector3)-p
	if to.length() > LOST: return true
	to.y = 0.0
	return to.dot(g.dir) < -120.0

func _finish() -> void:
	step_i = DONE
	marks.set_course({})
	marks.set_spot({},null)
	_card.visible = false
	game.book.set("tutorial_done",true)
	game.book.save()

# --- Laying the legs ---------------------------------------------------------

func _way() -> Vector3:
	var v: Vector3 = game.plane.velocity
	v.y = 0.0
	if v.length() > 5.0: return v.normalized()
	var h := float(game.plane.heading)
	return Vector3(-sin(h),0.0,-cos(h))

func _h(x: float, z: float) -> float:
	return maxf(float(game.field.height(x,z)),Field.SEA_Y)

## The highest turf along a..b (sampled every 10 m).
func _top(a: Vector3, b: Vector3) -> float:
	var n := maxi(int(a.distance_to(b)/10.0),1)
	var top := -INF
	for k in range(n+1):
		var q := a.lerp(b,float(k)/n)
		top = maxf(top,_h(q.x,q.z))
	return top

func _lay() -> void:
	lays += 1
	var p: Vector3 = game.plane.position
	var d := _way()
	var side := d.cross(Vector3.UP).normalized()
	var spots: Array = []
	ends = {}
	match step_i:
		STEER:
			var a := p+d*200.0
			var b := p+d*420.0+side*70.0
			var y := clampf(p.y,_top(p,b)+CRUISE.x,_top(p,b)+CRUISE.y)
			spots = [{"at":Vector3(a.x,y,a.z)},{"at":Vector3(b.x,y,b.z)}]
			ends = {1:STEER}
		LOW_RUN, PITCH:
			step_i = LOW_RUN
			spots = _low_leg(p,d)
			ends = {2:LOW_RUN,3:PITCH}
		NEAR:
			spots = _tree_leg(p,d)
			ends = {}
		BANK:
			spots = []
		LAND:
			spots = _land_leg(p,d)
	_set_leg(spots)

## The dip: in at cruise height, down to LOW over a flat meadow run, along
## it, and up through a high gate.
func _low_leg(p: Vector3, d: Vector3) -> Array:
	var run := _find_run(p,d)
	low_run = fallback
	var r0: Vector3 = run.a
	var rd: Vector3 = run.dir
	var r1 := r0+rd*RUN_LEN
	var in_at := r0-rd*170.0
	var y_in := clampf(p.y,_top(p,in_at)+CRUISE.x,_top(p,in_at)+CRUISE.y)
	var hi_at := r1+rd*260.0
	var low_half := Vector2(4.0,(LOW*0.5)/WorldScale.span)
	return [
		{"at":Vector3(in_at.x,y_in,in_at.z),"dir":rd},
		{"at":Vector3(r0.x,_h(r0.x,r0.z)+LOW*0.5,r0.z),"dir":rd,"half":low_half},
		{"at":Vector3(r1.x,_h(r1.x,r1.z)+LOW*0.5,r1.z),"dir":rd,"half":low_half},
		{"at":Vector3(hi_at.x,_top(r1,hi_at)+HIGH,hi_at.z),"dir":rd},
	]

## A flat dry meadow run ahead: {a (its start on the turf), dir}.
func _find_run(p: Vector3, d: Vector3) -> Dictionary:
	var h0 := atan2(-d.x,-d.z)
	for turn: float in [0.0,20.0,-20.0,40.0,-40.0]:
		var way := h0+deg_to_rad(turn)
		var dir := Vector3(-sin(way),0.0,-cos(way))
		var s := 380.0
		while s <= 1100.0:
			var a := p+dir*s
			if _run_ok(a,dir):
				fallback = "ahead"
				return {"a":a,"dir":dir}
			s += 30.0
	# None in reach: the nearest meadow menu_spot.gd's search finds.
	var ahead := p+d*450.0
	var got: Array = MenuSpot.find(game.field,Vector2(ahead.x,ahead.z),h0,1)
	if not got.is_empty():
		fallback = "meadow"
		var at: Vector2 = got[0].at
		var hd := float(got[0].heading)
		return {"a":Vector3(at.x,0.0,at.y),"dir":Vector3(-sin(hd),0.0,-cos(hd))}
	fallback = "none"
	return {"a":p+d*450.0,"dir":d}

func _run_ok(a: Vector3, dir: Vector3) -> bool:
	var lo := INF
	var hi := -INF
	var k := 0.0
	while k <= RUN_LEN+60.0:
		var q := a+dir*k
		var h := float(game.field.height(q.x,q.z))
		if h < Field.SEA_Y+MenuSpot.DRY: return false
		var s: Vector2 = game.field.sample(q.x,q.z)
		if s.y < MenuSpot.MEADOW*0.8: return false
		lo = minf(lo,h)
		hi = maxf(hi,h)
		if hi-lo > FLAT: return false
		# Nothing stood in the way (what has stood up yet: trees, rocks, ruins).
		if game.has_method("_blocked") and game._blocked(Vector3(q.x,h+LOW*0.5,q.z)): return false
		k += 10.0
	return true

## Past a tree: in, alongside its crown a wingspan off, and out.
func _tree_leg(p: Vector3, d: Vector3) -> Array:
	tree = _find_tree(p,d)
	if tree.is_empty():
		# No tree stood ahead: a low pass over the grass makes the near miss.
		var a := p+d*250.0
		var b := p+d*450.0
		return [{"at":Vector3(a.x,_h(a.x,a.z)+LOW,a.z)},{"at":Vector3(b.x,_h(b.x,b.z)+LOW*0.5,b.z),"half":Vector2(4.0,(LOW*0.5)/WorldScale.span)}]
	var t := Vector3(float(tree.x),0.0,float(tree.z))
	var to := t-p
	to.y = 0.0
	var way := to.normalized()
	var across := way.cross(Vector3.UP).normalized()
	# The side the plane is already on.
	if across.dot(d) < 0.0: across = -across
	var off := float(tree.reach)+WorldScale.span*0.35
	var y := float(tree.foot)+float(tree.bottom)+(float(tree.height)-float(tree.bottom))*0.35
	var mid := t+across*off
	var a := mid-way*160.0
	var b := mid+way*160.0
	return [
		{"at":Vector3(a.x,maxf(y,_h(a.x,a.z)+6.0),a.z),"dir":way},
		{"at":Vector3(mid.x,y,mid.z),"dir":way,"half":Vector2(1.0,1.2)},
		{"at":Vector3(b.x,maxf(y+6.0,_h(b.x,b.z)+10.0),b.z),"dir":way},
	]

## A stood tree (7 m or taller, on land) 150..600 m ahead, within 80
## degrees of the way, the nearest the way and 280 m off first.
func _find_tree(p: Vector3, d: Vector3) -> Dictionary:
	var c := p+d*300.0
	trees_seen = 0
	var best := {}
	var best_cost := INF
	var ck0 := TreePlan.cell_of(c.x,c.z)
	for dz in range(-3,4):
		for dx in range(-3,4):
			var ck := ck0+Vector2i(dx,dz)
			var trees: PackedFloat32Array = game.trees.cell_trees(ck)
			for i in range(trees.size()/8):
				var q := i*8
				if trees[q+3] < 7.0 or trees[q+5] <= 0.0: continue
				var t := Vector3(trees[q],trees[q+2],trees[q+1])
				var to := t-p
				to.y = 0.0
				var dist := to.length()
				if dist < 150.0 or dist > 600.0: continue
				if t.y < Field.SEA_Y+1.0: continue
				var ang := absf(d.signed_angle_to(to.normalized(),Vector3.UP))
				if ang > deg_to_rad(80.0): continue
				trees_seen += 1
				var cost := ang*300.0+absf(dist-280.0)
				if cost >= best_cost: continue
				best_cost = cost
				best = {"x":trees[q],"z":trees[q+1],"foot":trees[q+2],"height":trees[q+3],"bottom":trees[q+4],"reach":trees[q+5],"radius":trees[q+6]}
	return best

## The landing: a meadow strip ahead, its marks on the ground and a ribbon
## easing down to it.
func _land_leg(p: Vector3, d: Vector3) -> Array:
	var h0 := atan2(-d.x,-d.z)
	var ahead := p+d*500.0
	var got: Array = MenuSpot.find(game.field,Vector2(ahead.x,ahead.z),h0,1,5)
	if got.is_empty(): got = MenuSpot.find(game.field,Vector2(ahead.x,ahead.z),h0,1)
	var c: Vector3
	var axis: Vector3
	if not got.is_empty():
		var at: Vector2 = got[0].at
		var hd := float(got[0].heading)
		axis = Vector3(-sin(hd),0.0,-cos(hd))
		c = Vector3(at.x,_h(at.x,at.y),at.y)+axis*40.0
	else:
		# No meadow by the menu's search: the flattest run ahead (as the dip's).
		var run := _find_run(p,d)
		axis = run.dir
		c = (run.a as Vector3)+axis*60.0
		c.y = _h(c.x,c.z)
	_landing = {"spot":{"centre":c,"half_len":45.0,"half_wide":9.0},"axis":axis,"across":axis.cross(Vector3.UP).normalized()}
	marks.set_spot(_landing,game.field)
	var a := c-axis*260.0
	return [{"at":Vector3(a.x,_h(a.x,a.z)+18.0,a.z),"dir":axis},{"at":c+Vector3(0.0,3.0,0.0),"dir":axis,"half":Vector2(4.0,1.5)}]

## The leg's gates and ribbon (place_lines.gd's shape), the plane's way in first.
func _set_leg(spots: Array) -> void:
	gates = []
	next = 0
	if spots.is_empty():
		course = {}
		marks.set_course({})
		return
	var pts: Array = []
	for s: Dictionary in spots: pts.append(s.at)
	for i in spots.size():
		var s: Dictionary = spots[i]
		var p: Vector3 = pts[i]
		var dir: Vector3 = s.get("dir",(pts[mini(i+1,pts.size()-1)]-pts[maxi(i-1,0)]))
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
		var half: Vector2 = s.get("half",PlaceLines.AIR_HALF)
		var hw := WorldScale.span*half.x
		var hh := WorldScale.span*half.y
		gates.append({"id":"first/%d" % i,"kind":"air","p":p,"dir":dir,"half_w":hw,"lo":p.y-hh,"hi":p.y+hh,"s":0.0,"through":true})
	course = {"gates":gates,"line":PlaceLines._ribbon(gates),"line_step":PlaceLines.LINE_STEP}
	marks.set_course(course)

func _show(delta: float, p: Vector3) -> void:
	var show := {"next":-1,"progress":-1000.0,"alpha":1.0,"spot":not _landing.is_empty(),"in_spot":false}
	if not gates.is_empty() and next < gates.size():
		var g1: Dictionary = gates[next]
		var g0: Dictionary = gates[next-1] if next > 0 else {}
		var prog := -1000.0
		if not g0.is_empty():
			var seg: Vector3 = (g1.p as Vector3)-(g0.p as Vector3)
			var k := clampf((p-(g0.p as Vector3)).dot(seg)/maxf(seg.length_squared(),1.0),0.0,1.0)
			prog = lerpf(float(g0.s),float(g1.s),k)
		show.next = next
		show.progress = prog
	if game.overlay != null: show.alpha = 0.0
	marks.step(delta,game.camera,show)
	_card.visible = running() and game.overlay == null
	if _card.visible: _card.queue_redraw()

## The card's lines: [title, what to do, the keys].
func card_text() -> Array:
	var pad := Pad.using_pad()
	var n := "%d / 5" % mini(step_i+1,5)
	match step_i:
		STEER: return [n+"  steer",
			"Fly through the two gold gates.",
			Pad.pick("A D bank  ·  mouse steers","LS bank and steer")]
		LOW_RUN: return [n+"  low",
			"Follow the ribbon down to the grass and hold it low through the gate.",
			Pad.pick("W nose down  ·  S nose up","LS up and down")]
		PITCH: return [n+"  pull up",
			"Pull up through the high gate.",
			Pad.pick("S nose up  ·  Space boost","LS back  ·  RT boost")]
		NEAR: return [n+"  near miss",
			"Pass close by the tree: a wingtip's width." if not tree.is_empty() else "Skim close over the grass.",
			Pad.pick("A D bank  ·  Q E knife edge","LS bank  ·  LB RB knife edge")]
		BANK: return ["5 / 5  bank",
			"Fly calm a moment: the line banks.",
			Pad.pick("keep it steady","keep it steady")]
		LAND: return ["5 / 5  land",
			"Land on the marked grass to see what the line paid." if not _landing.is_empty() else "Land on flat grass to see what the line paid.",
			Pad.pick("Shift brake  ·  ease the nose down","LT brake  ·  ease the nose down")]
		READING: return ["5 / 5  paid",
			"That's the line's money. The sky is yours.",
			""]
	return ["","",""]

func skip_text() -> String:
	return Pad.pick("Backspace  skip the guide","D-pad down  skip the guide")

## The card at the top of the screen.
class Card extends Control:
	var guide: Node

	func _draw() -> void:
		if guide == null: return
		var lines: Array = guide.card_text()
		var w := size.x
		var cx := w*0.5
		var y := 70.0
		var f := float(guide._flash)/0.6
		var title := str(lines[0])
		var body := str(lines[1])
		var keys := str(lines[2])
		var bw := maxf(WORDS.get_string_size(body,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x,NUMS.get_string_size(keys,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x)+80.0
		draw_rect(Rect2(cx-bw*0.5,y-34.0,bw,150.0 if keys != "" else 118.0),Color(KEY,0.55))
		_text(NUMS,title.to_upper(),Vector2(cx,y-8.0),18,GOLD.lerp(CREAM,f))
		_text(WORDS,body,Vector2(cx,y+24.0),26,CREAM)
		if keys != "": _text(NUMS,keys,Vector2(cx,y+58.0),20,GOLD)
		_text(NUMS,str(guide.skip_text()),Vector2(cx,y+(84.0 if keys != "" else 52.0)),15,Color(GREY.lightened(0.25),0.9))

	func _text(font: Font, t: String, at: Vector2, px: int, col: Color, align := 0.5) -> void:
		var tw := font.get_string_size(t,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
		var p := Vector2(at.x-tw*align,at.y)
		draw_string_outline(font,p,t,HORIZONTAL_ALIGNMENT_LEFT,-1,px,6,Color(KEY,0.85))
		draw_string(font,p,t,HORIZONTAL_ALIGNMENT_LEFT,-1,px,col)
