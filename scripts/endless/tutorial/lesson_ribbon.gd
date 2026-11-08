extends Node
## The lesson's guide at GRASS and WATER: a ribbon laid ahead of the plane
## along its heading, level at cruise, down to skim height for a stretch,
## and up through a high gate. At WATER the stretch lies over the reach the
## tutorial land stamped ahead (tutorial.gd `ahead`), later over a pond ahead.
## It is only a guide: the lesson counts the pull-outs. A leg flown, or left
## behind (its next gate far off or well behind, round 1's LOST rule), is
## laid again ahead. Drawn by rival_marks.gd in its own inks.
##
## lesson.gd owns it: `set_stage` on each stage change, `step` each frame,
## `clear` when hidden.

const RivalMarks = preload("res://scripts/endless/rival_marks.gd")
const RivalRace = preload("res://scripts/endless/rival_race.gd")
const PlaceLines = preload("res://scripts/endless/place_lines.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Field = preload("res://scripts/endless/land_field.gd")

## The lesson's stages that get a ribbon (lesson.gd Stage.GRASS, WATER).
const GRASS := 0
const WATER := 2
## The skim stretch's middle over the turf or water (m), its gates' half
## width (spans) and half height (m).
const LOW := 3.5
const LOW_HALF := Vector2(3.0,2.0)
## The level stretch at cruise: this high over the highest turf under it (m).
const CRUISE := Vector2(18.0,30.0)
## The high gate the pull-up goes through, over the turf (m).
const HIGH := 30.0
## The leg along the way (m): the level stretch, the way down, the skim
## stretch over land, the way up.
const LEVEL := 100.0
const DOWN := 130.0
const RUN := 150.0
const UP := 200.0
## Over land the skim stretch starts this far ahead (m).
const RUN_AT := 400.0
## A gate nearer than this along the way is left out (m).
const NEAR := 40.0
## A leg is laid again when its next gate is this far off, or this far behind (m).
const LOST := 1300.0
const BEHIND := 120.0
## Ponds weighed for a later water leg: centre this far off (m), at most
## this far off the nose (rad), a stretch over the water at least this long.
const POND_REACH := Vector2(220.0,1200.0)
const POND_TURN := deg_to_rad(40.0)
const POND_RUN := 15.0
## Over water the climb starts this far before the stretch's far end (m).
const UP_OVER := 40.0
## A pond whose line passes more than JOIN_SIDE m off the plane is joined
## from a gate JOIN m ahead: the way from it at least JOIN_MIN m, turned at
## most JOIN_TURN from the flight and from the stretch; its stretch then
## starts at least POND_LEAD m along.
const JOIN_SIDE := 30.0
const JOIN := 120.0
const JOIN_MIN := 60.0
const JOIN_TURN := deg_to_rad(50.0)
const POND_LEAD := 230.0
## A leg whose level stretch starts further than this along the way gets a
## gate JOIN m ahead first (m).
const FAR_IN := 300.0
## How late the way down steepens and how early the way up does (1 an even S).
const SWOOP := 1.6
## The ribbon's points along the way (m).
const STEP := 4.0

var game: Node
var marks: RivalMarks
var stage := -1
var gates: Array = []
var next := 0
## Legs laid this stage, and what the last skim stretch lay over: "land",
## "reach" (the stamped one), "pond" or "none".
var lays := 0
var over := ""
## The skim stretch's ends (world), for drivers and stills.
var dip := []
var _ahead_used := Vector2(INF,INF)
var _prev := Vector3.INF
var _wait := 0.0

func setup(g: Node) -> void:
	game = g
	name = "LessonRibbon"
	marks = RivalMarks.new()
	marks.name = "LessonRibbonMarks"
	add_child(marks)

func set_stage(s: int) -> void:
	stage = s
	lays = 0
	_prev = Vector3.INF
	if s == GRASS or s == WATER: _lay()
	else: clear()

func clear() -> void:
	gates = []
	next = 0
	dip = []
	marks.set_course({})
	marks.step(0.0,null,{})

func shown() -> bool:
	return not gates.is_empty()

## One frame, after the plane moved.
func step(delta: float) -> void:
	if stage != GRASS and stage != WATER:
		return
	var p: Vector3 = game.plane.position
	var a := _prev
	_prev = p
	if a != Vector3.INF and a.distance_to(p) > 150.0: a = Vector3.INF
	# The reach stamped after the leg was laid: the leg laid over it.
	if stage == WATER and _stamped() != _ahead_used and _stamped().x != INF: _lay()
	# No leg could be laid (too near the stage's start): again each second.
	if gates.is_empty():
		_wait += delta
		if _wait >= 1.0:
			_wait = 0.0
			_lay()
	if a != Vector3.INF and bool(game.hand_landing.flying()) and next < gates.size():
		var r := RivalRace.through(gates[next],a,p)
		if r == "through": marks.cleared(next)
		if r != "": next += 1
	if not gates.is_empty() and (next >= gates.size() or _lost(p)): _lay()
	_show(delta,p)

func _lost(p: Vector3) -> bool:
	if next >= gates.size(): return false
	var g: Dictionary = gates[next]
	var to: Vector3 = (g.p as Vector3)-p
	if to.length() > LOST: return true
	to.y = 0.0
	# Passed it by, or turned away from it.
	return to.dot(g.dir) < -BEHIND or to.dot(_way()) < -BEHIND

func _show(delta: float, p: Vector3) -> void:
	var show := {"next":-1,"progress":-1000.0,"alpha":1.0}
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
	if game.get("overlay") != null: show.alpha = 0.0
	marks.step(delta,game.camera,show)

# --- Laying a leg ---------------------------------------------------------------

func _way() -> Vector3:
	var v: Vector3 = game.plane.velocity
	v.y = 0.0
	if v.length() > 5.0: return v.normalized()
	var h := float(game.plane.heading)
	return Vector3(-sin(h),0.0,-cos(h))

## The turf or the water's top at x, z.
func _surf(x: float, z: float) -> float:
	var h := maxf(float(game.field.height(x,z)),Field.SEA_Y)
	return maxf(h,float(game.water_at(Vector3(x,h,z),h)))

## The highest surface along a..b (every 10 m).
func _top(a: Vector3, b: Vector3) -> float:
	var n := maxi(int(a.distance_to(b)/10.0),1)
	var top := -INF
	for k in range(n+1):
		var q := a.lerp(b,float(k)/n)
		top = maxf(top,_surf(q.x,q.z))
	return top

## The stamped reach's centre (INF none).
func _stamped() -> Vector2:
	var w: Variant = game.get("world")
	if w == null or not ("ahead" in w): return Vector2(INF,INF)
	for key: Vector2i in w.ahead:
		return (w.ahead[key] as Array)[0] as Vector2
	return Vector2(INF,INF)

func _lay() -> void:
	lays += 1
	var p: Vector3 = game.plane.position
	var d := _way()
	var run := {}
	if stage == WATER: run = _water_run(p,d)
	if run.is_empty(): run = _land_run(p,d)
	over = str(run.over)
	_set_leg(p,run)

## A skim stretch over land: along the way, RUN_AT m ahead, turned a little
## if a tree stands in it.
func _land_run(p: Vector3, d: Vector3) -> Dictionary:
	var h0 := atan2(-d.x,-d.z)
	for turn: float in [0.0,12.0,-12.0,25.0,-25.0]:
		var way := h0+deg_to_rad(turn)
		var dir := Vector3(-sin(way),0.0,-cos(way))
		var a := p+dir*RUN_AT
		if _clear_run(a,dir,RUN): return {"a":a,"b":a+dir*RUN,"dir":dir,"over":"land"}
	return {"a":p+d*RUN_AT,"b":p+d*(RUN_AT+RUN),"dir":d,"over":"land"}

func _clear_run(a: Vector3, dir: Vector3, length: float) -> bool:
	var trees: Node = game.get("trees")
	var k := -DOWN*0.5
	while k <= length+UP*0.5:
		var q := a+dir*k
		var h := float(game.field.height(q.x,q.z))
		if trees != null and float(trees.top_at(Vector3(q.x,h,q.z))) > h+0.5: return false
		k += 10.0
	return true

## A skim stretch over water: the reach stamped ahead (once), else the
## nearest pond or reach ahead. {} none.
func _water_run(p: Vector3, d: Vector3) -> Dictionary:
	var c := _stamped()
	if c.x != INF and c != _ahead_used:
		_ahead_used = c
		var w: RefCounted = game.get("world")
		for key: Vector2i in w.ahead:
			var s: Array = w.ahead[key]
			var dr := Vector2(cos(float(s[1])),sin(float(s[1])))
			var got := _along(p,d,c,dr,float(s[2]),"reach")
			if not got.is_empty(): return got
	var best := {}
	var best_k := INF
	var r := POND_REACH.y+200.0
	for q: PackedFloat32Array in game.field.ponds_in(p.x-r,p.z-r,p.x+r,p.z+r):
		var pc := Vector2(q[0],q[1])
		var to := pc-Vector2(p.x,p.z)
		var dist := to.length()
		if dist < POND_REACH.x or dist > POND_REACH.y: continue
		var off := absf(Vector2(d.x,d.z).angle_to(to))
		if off > POND_TURN: continue
		var got := {}
		if q.size() >= 14 and q[12] > 0.0:
			# A reach lying across the flight is not flown along.
			var ax := Vector2(cos(q[13]),sin(q[13]))
			if absf(ax.dot(Vector2(d.x,d.z))) < cos(POND_TURN): continue
			got = _along(p,d,pc,Vector2(cos(q[13]),sin(q[13])),q[12],"pond",POND_LEAD)
		else:
			got = _along(p,d,pc,to.normalized(),q[2]*0.8,"pond",POND_LEAD)
		if got.is_empty(): continue
		# Off the plane's line: joined from a gate ahead at cruise, with no
		# hard turn on either side of the one to it.
		var gd: Vector3 = got.dir
		if absf((p-(got.a as Vector3)).cross(gd).y) > JOIN_SIDE:
			var join := p+d*JOIN
			var v: Vector3 = (got.a as Vector3)-gd*DOWN-join
			v.y = 0.0
			if v.length() < JOIN_MIN or v.angle_to(d) > JOIN_TURN or v.angle_to(gd) > JOIN_TURN: continue
			got.join = join
		var k := dist*(1.0+off)
		if k < best_k:
			best_k = k
			best = got
	return best

## A stretch along `dir` (either way, the one nearer the flight's) through
## `c`, `half` m each way, its start pushed on far enough ahead for the way
## down. {} when too little of it is left.
func _along(p: Vector3, d: Vector3, c: Vector2, dir: Vector2, half: float, what: String, lead := DOWN+NEAR) -> Dictionary:
	var fd := Vector2(d.x,d.z)
	if dir.dot(fd) < 0.0: dir = -dir
	var a := c-dir*half
	var b := c+dir*half
	var pp := Vector2(p.x,p.z)
	# The start at least the way down ahead of the plane (along the stretch).
	var need := (pp-a).dot(dir)+lead
	if need > 0.0: a += dir*need
	# The pull-up starts over the water, not on its far bank.
	b -= dir*minf(UP_OVER,half*0.5)
	if (b-a).dot(dir) < POND_RUN: return {}
	var d3 := Vector3(dir.x,0.0,dir.y)
	return {"a":Vector3(a.x,0.0,a.y),"b":Vector3(b.x,0.0,b.y),"dir":d3,"over":what}

## The gates: level at cruise, down to the skim stretch, along it, up through
## the high gate; those nearer than NEAR along the way left out.
func _set_leg(p: Vector3, run: Dictionary) -> void:
	var a: Vector3 = run.a
	var b: Vector3 = run.b
	var dir: Vector3 = run.dir
	var lo := _top(a,b)+LOW
	dip = [Vector3(a.x,lo,a.z),Vector3(b.x,lo,b.z)]
	var in1 := a-dir*DOWN
	var in0: Vector3 = run.get("join",in1-dir*LEVEL)
	var top := _top(in0,a)
	var y_in := clampf(p.y,top+CRUISE.x,top+CRUISE.y)
	var hi := b+dir*UP
	var low_half := Vector2(LOW_HALF.x,LOW_HALF.y/WorldScale.span)
	var spots := [
		{"at":Vector3(in0.x,y_in,in0.z)},
		{"at":Vector3(in1.x,y_in,in1.z)},
		{"at":dip[0],"half":low_half},
		{"at":dip[1],"half":low_half},
		{"at":Vector3(hi.x,_top(b,hi)+HIGH,hi.z)},
	]
	var d := _way()
	# Far off: the ribbon starts near the plane, level, toward it.
	if (in0-p).dot(d) > FAR_IN:
		var j := p+d*JOIN
		spots.push_front({"at":Vector3(j.x,y_in,j.z),"dir":((in0-j)*Vector3(1,0,1)).normalized()})
	gates = []
	next = 0
	for s: Dictionary in spots:
		var at: Vector3 = s.at
		if (at-p).dot(d) < NEAR and gates.is_empty(): continue
		var half: Vector2 = s.get("half",PlaceLines.AIR_HALF)
		var gd: Vector3 = s.get("dir",dir)
		var hw := WorldScale.span*half.x
		var hh := WorldScale.span*half.y
		gates.append({"id":"lesson/%d" % gates.size(),"kind":"air","p":at,"dir":gd,"half_w":hw,"lo":at.y-hh,"hi":at.y+hh,"s":0.0,"through":true})
	if gates.size() < 2:
		clear()
		return
	marks.set_course({"gates":gates,"line":_ribbon(gates),"line_step":STEP})

## The ribbon through the gates' middles: straight along the ground between
## them, its height eased (level at each gate), so it reads level, down,
## level, up (the swoop: SWOOP); each gate's `s` its distance along it.
static func _ribbon(gs: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var s := 0.0
	out.append(gs[0].p)
	for i in range(gs.size()-1):
		gs[i].s = s
		var p1: Vector3 = gs[i].p
		var p2: Vector3 = gs[i+1].p
		var n := maxi(ceili(p1.distance_to(p2)/STEP),1)
		for k in range(1,n+1):
			var t := float(k)/float(n)
			var q := p1.lerp(p2,t)
			# Down: steep late, a tight round-out at the bottom (a pull-out
			# needs the plane still closing on the ground near it). Up:
			# steep early, eased at the top.
			var u := pow(t,SWOOP) if p2.y < p1.y else 1.0-pow(1.0-t,SWOOP)
			q.y = lerpf(p1.y,p2.y,smoothstep(0.0,1.0,u))
			s += q.distance_to(out[out.size()-1])
			out.append(q)
	gs[gs.size()-1].s = s
	return out
