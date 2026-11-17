extends Node
## Place lines (endless flight; docs/design/endless-flight/spec-peak.md, lane
## `lines`): standing routes at fixed places, each a timed record.
##
## A line: {name, place, title, gates, seed (-1 any), mark (s, the time to
## beat; none under 0)}. `gates` are in order,
## the first the start and the last the finish; each a Vector3 (the mouth's
## middle) or {at, dir (the way through, else along the line), half
## (Vector2, wingspans across and up each way, else AIR_HALF)}. Each gate
## stands where the layout file puts its handle
## `<place>/route/<name>/gate/<n>` (scripts/layout_overrides.gd `xform`; n
## from 0), else at its coded spot facing its way; the handle's basis
## scale grows the mouth (x across, y up).
##
## Gates are rival_course.gd's shape ({id, kind, p, dir, half_w, lo, hi, s,
## through}) and are passed by rival_race.gd's test (`through`), so they
## draw with rival_marks.gd (corner brackets, the ribbon along the line).
##
## Flying a line:
## - through the start gate the clock starts (the start moment on screen;
##   the place is found, `place/<place>`, the first time);
## - the gates in order: going by the next one outside it, through a later
##   one, LOST m from the next, a jump (respawn) or touching down ends the
##   attempt quietly (the tag dims, no record);
## - through the finish the clock stops: the finish card, and the time tried
##   as the record `line/<place>/<name>` (pilot_book.gd: lower wins).
## Times are taken at the crossing inside the frame, not the frame's end.
## The near-miss chain runs as ever beside it; nothing else is scored.
##
## The trunk declares its lines in LINES (fixed spots) or hands them to
## `add_line` once it knows where they stand (from a placed massif).
## Out of the game (2026-11-16): no line stands, and the node is made only
## with --lines=1.

const RivalRace = preload("res://scripts/endless/rival_race.gd")
const RivalCourse = preload("res://scripts/endless/rival_course.gd")
const RivalMarks = preload("res://scripts/endless/rival_marks.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Hud = preload("res://scripts/endless/place_lines_hud.gd")

## The places lines stand at: id -> its name as it reads.
const PLACES := {
	"meadow": "the start meadow",
	"peak": "the Peak",
}

## The declared lines with their gates, built at setup (also listed in the
## logbook under their place with their best, or "-"). None stand yet; the
## main scene can hand one to `add_line` once it knows the spots.
const LINES := []

## A gate's mouth by default, in wingspans each way (the rival's air gates').
const AIR_HALF := RivalCourse.AIR_HALF
## The ribbon's point spacing along a line (m).
const LINE_STEP := 4.0
## An attempt ends this far (m) from its next gate, or on a jump this long
## in one frame (a respawn).
const LOST := 900.0
const JUMP := 150.0
## The marks show within SHOW_NEAR m of a line's nearest gate, fading out
## by SHOW_FAR.
const SHOW_NEAR := 1800.0
const SHOW_FAR := 2800.0

## The lines, built: {name, place, title, key, gates, course ({gates, line,
## line_step}), marks}.
var lines: Array = []
## The attempt under way ({} none): {line (index), next (gate), t (s)}.
var run: Dictionary = {}
## What happened, for drivers: the last start, finish and end.
var last_start: Dictionary = {}
var last_finish: Dictionary = {}
var last_end: Dictionary = {}
var hud: Control
var _seed := 1
var _prev := Vector3.INF

static func wanted() -> bool:
	return "--lines=1" in preload("res://scripts/launch_args.gd").user_args()

func setup(seed: int, game: Node) -> void:
	name = "PlaceLines"
	_seed = seed
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new(game)
	layer.add_child(hud)
	for l: Dictionary in LINES: add_line(l)

## One line more (see the header for its shape); false when it is for
## another seed or has under two gates.
func add_line(decl: Dictionary) -> bool:
	if int(decl.get("seed",-1)) >= 0 and int(decl.seed) != _seed: return false
	var spots: Array = decl.get("gates",[])
	if spots.size() < 2: return false
	var place := str(decl.get("place","place"))
	var line_name := str(decl.get("name","line"))
	var pts: Array = []
	for g: Variant in spots: pts.append(g if g is Vector3 else (g as Dictionary).get("at",Vector3.ZERO))
	var gates: Array = []
	for i in spots.size():
		var g: Dictionary = spots[i] if spots[i] is Dictionary else {}
		var p: Vector3 = pts[i]
		var dir: Vector3 = g.get("dir",(pts[mini(i+1,pts.size()-1)]-pts[maxi(i-1,0)]))
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
		var half: Vector2 = g.get("half",AIR_HALF)
		var coded := Transform3D(Basis.looking_at(dir,Vector3.UP),p)
		var xf := LayoutOverrides.xform("%s/route/%s/gate/%d" % [place,line_name,i],coded)
		var way := -xf.basis.z
		way.y = 0.0
		way = way.normalized() if way.length() > 0.001 else dir
		var hw := WorldScale.span*half.x*xf.basis.x.length()
		var hh := WorldScale.span*half.y*xf.basis.y.length()
		gates.append({"id":"%s/%d" % [line_name,i],"kind":"air","p":xf.origin,"dir":way,
			"half_w":hw,"lo":xf.origin.y-hh,"hi":xf.origin.y+hh,"s":0.0,"through":true})
	var course := {"gates":gates,"line":_ribbon(gates),"line_step":LINE_STEP}
	var marks := RivalMarks.new()
	marks.name = "LineMarks_"+line_name
	add_child(marks)
	marks.set_course(course)
	lines.append({"name":line_name,"place":place,"place_name":place_name(place),"title":str(decl.get("title",line_name.replace("_"," "))),
		"key":key_of(place,line_name),"gates":gates,"course":course,"marks":marks,"mark":float(decl.get("mark",-1.0))})
	return true

## The record's name of line `line_name` at `place`.
static func key_of(place: String, line_name: String) -> String:
	return "line/%s/%s" % [place,line_name]

static func place_name(place: String) -> String:
	return str(PLACES.get(place,place.replace("_"," ")))

## The ribbon through the gates' middles (a Catmull-Rom curve every
## LINE_STEP m); each gate's `s` set to its distance along it.
static func _ribbon(gates: Array) -> PackedVector3Array:
	var mids: Array = []
	for g: Dictionary in gates: mids.append(Vector3(g.p.x,(float(g.lo)+float(g.hi))*0.5,g.p.z))
	var out := PackedVector3Array()
	var s := 0.0
	out.append(mids[0])
	for i in range(mids.size()-1):
		gates[i].s = s
		var p0: Vector3 = mids[maxi(i-1,0)]
		var p1: Vector3 = mids[i]
		var p2: Vector3 = mids[i+1]
		var p3: Vector3 = mids[mini(i+2,mids.size()-1)]
		var n := maxi(ceili(p1.distance_to(p2)/LINE_STEP),1)
		for k in range(1,n+1):
			var t := float(k)/float(n)
			var q := 0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t)
			s += q.distance_to(out[out.size()-1])
			out.append(q)
	gates[gates.size()-1].s = s
	return out

## Where along gate `g`'s way the step from `a` to `b` crossed its plane (0..1).
static func _cross_at(g: Dictionary, a: Vector3, b: Vector3) -> float:
	var da := (a-(g.p as Vector3)).dot(g.dir)
	var db := (b-(g.p as Vector3)).dot(g.dir)
	return clampf(da/(da-db),0.0,1.0) if absf(da-db) > 0.000001 else 1.0

## One frame (from the main scene's tick, after the plane moved).
func step(delta: float, game: Node) -> void:
	var p: Vector3 = game.plane.position
	var a := _prev
	_prev = p
	var flying := not bool(game.hand_landing.on_ground())
	if a != Vector3.INF and a.distance_to(p) > JUMP:
		if not run.is_empty(): _end(game,"jump")
		a = Vector3.INF
	if not run.is_empty():
		run.t = float(run.t)+delta
		if not flying: _end(game,"landed")
	if a != Vector3.INF and flying: _passes(game,a,p,delta)
	FrameLog.mark(&"l_pass")
	_show(delta,game,p)
	FrameLog.mark(&"l_show")
	hud.step(delta,self)

func _passes(game: Node, a: Vector3, b: Vector3, delta: float) -> void:
	if not run.is_empty():
		var line: Dictionary = lines[int(run.line)]
		var gates: Array = line.gates
		var next := int(run.next)
		var got := RivalRace.through(gates[next],a,b)
		if got == "through":
			var marks: RivalMarks = line.marks
			marks.cleared(next)
			if next == gates.size()-1:
				_finish(game,float(run.t)-delta*(1.0-_cross_at(gates[next],a,b)))
				return
			run.next = next+1
			hud.gate(next,gates.size())
		elif got == "by":
			_end(game,"missed")
		else:
			for k in range(next+1,gates.size()):
				if RivalRace.through(gates[k],a,b) == "through":
					_end(game,"skipped")
					break
		if not run.is_empty() and b.distance_to(gates[int(run.next)].p) > LOST: _end(game,"lost")
	# A start gate (again, while running: a fresh start).
	for i in lines.size():
		var gates: Array = lines[i].gates
		if RivalRace.through(gates[0],a,b) == "through":
			_start(game,i,delta*(1.0-_cross_at(gates[0],a,b)))
			return

func _start(game: Node, i: int, t: float) -> void:
	var line: Dictionary = lines[i]
	run = {"line":i,"next":1,"t":t}
	var first := bool(game.book.find("place/"+str(line.place)))
	last_start = {"line":line.name,"place":line.place,"first_find":first,"frame":Engine.get_process_frames()}
	(line.marks as RivalMarks).cleared(0)
	var key: String = line.key
	hud.started(line,float(game.book.records[key]) if game.book.records.has(key) else -1.0)
	print("place lines: started %s at %s" % [line.key,"%.0f,%.0f,%.0f" % [game.plane.position.x,game.plane.position.y,game.plane.position.z]])

func _finish(game: Node, t: float) -> void:
	var line: Dictionary = lines[int(run.line)]
	var key: String = line.key
	var had: bool = game.book.records.has(key)
	var was := float(game.book.records[key]) if had else -1.0
	var beat := bool(game.book.best(key,t))
	last_finish = {"line":line.name,"place":line.place,"key":key,"time":t,"beat":beat,"was":was,"frame":Engine.get_process_frames()}
	run = {}
	hud.finished(line,t,beat,was)
	print("place lines: finished %s in %.2f s (%s)" % [key,t,"new best" if beat else "best %.2f" % was])

func _end(_game: Node, why: String) -> void:
	var line: Dictionary = lines[int(run.line)]
	last_end = {"line":line.name,"why":why,"gate":int(run.next),"t":float(run.t),"frame":Engine.get_process_frames()}
	run = {}
	hud.ended(why)
	print("place lines: %s ended (%s at gate %d)" % [line.key,why,int(last_end.gate)])

## The marks: the line under way (its next gate gold, the ribbon fading
## behind), else each line near enough, its start gate gold, no ribbon.
func _show(delta: float, game: Node, p: Vector3) -> void:
	var camera: Camera3D = game.camera
	for i in lines.size():
		var line: Dictionary = lines[i]
		var marks: RivalMarks = line.marks
		var show := {"next":0,"progress":-1000.0,"alpha":0.0}
		if not run.is_empty() and int(run.line) == i:
			var gates: Array = line.gates
			var next := int(run.next)
			var g0: Dictionary = gates[next-1]
			var g1: Dictionary = gates[next]
			var seg: Vector3 = (g1.p as Vector3)-(g0.p as Vector3)
			var k := clampf((p-(g0.p as Vector3)).dot(seg)/maxf(seg.length_squared(),1.0),0.0,1.0)
			show = {"next":next,"progress":lerpf(float(g0.s),float(g1.s),k),"alpha":1.0}
		elif run.is_empty():
			var near := INF
			for g: Dictionary in line.gates: near = minf(near,p.distance_to(g.p))
			show.alpha = 1.0-smoothstep(SHOW_NEAR,SHOW_FAR,near)
			# A line not being flown marks its gates; a ribbon ruled across the view reads as a glitch.
			show.line = false
		if game.overlay != null: show.alpha = 0.0
		marks.step(delta,camera,show)

## The lines at `place` and their bests, for the logbook: [{title, key,
## best (-1 none)}]; the declared ones first, then any recorded elsewhere.
static func lines_at(book: PilotBook, place: String) -> Array:
	var out := []
	var keys := []
	for l: Dictionary in LINES:
		if str(l.place) != place: continue
		var key := key_of(place,str(l.name))
		keys.append(key)
		out.append({"title":str(l.get("title",l.name)),"key":key,"best":float(book.records.get(key,-1.0))})
	for key: String in book.records:
		if not key.begins_with("line/%s/" % place) or key in keys: continue
		out.append({"title":key.get_slice("/",2).replace("_"," "),"key":key,"best":float(book.records[key])})
	return out

## The places the book has met or has line times at, in PLACES' order then
## the rest.
static func places_in(book: PilotBook) -> Array:
	var seen := []
	for id: String in PLACES:
		if book.found.has("place/"+id): seen.append(id)
	for key: String in book.records:
		if not key.begins_with("line/"): continue
		var id := key.get_slice("/",1)
		if not id in seen: seen.append(id)
	for id: String in book.found:
		if id.begins_with("place/") and not id.get_slice("/",1) in seen: seen.append(id.get_slice("/",1))
	return seen

## The logbook's places column: each place's name, then its lines with
## their best times.
static func logbook_rows(book: PilotBook) -> Array:
	var rows := []
	for id: String in places_in(book):
		rows.append({"kind":"place","label":place_name(id),"value":""})
		for l: Dictionary in lines_at(book,id):
			var has := float(l.best) >= 0.0
			rows.append({"label":str(l.title),"value":lap(float(l.best)) if has else "-","col":Hud.GOLD if has else Hud.GREY,"indent":true})
	return rows

## A line's time as 0:41.3.
static func lap(s: float) -> String:
	return Hud.lap(s)
