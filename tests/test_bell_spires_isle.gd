extends SceneTree
## The bell spires isle (studies/bell_spires_isle.tscn), headless: the ways
## up proven as a player would drive them, with scripted inputs.
##
## - The start stands on the isle's turf.
## - The easy way: walked, never a jump, from the start up the low stack's
##   cut stair, across the low bridge, up the hero's stair round the spire
##   to the summit, and up the belfry's outer stair to its floor.
## - The second easy way: walked up the fin's low stack to the chockstone,
##   round the high stack to its top, across the fin bridge onto the hero's
##   stair (a loop with the first).
## - Each rope bridge walked both ways, never fallen from, its deck sagging
##   under him (the live sim).
## - The gable stack: across its bridge; and the drift of floating stones
##   from the low stack to it, jumped stone to stone.
## - The needle: across the high bridge, up its turret's spiral stair, and
##   over the floating stones from the turret's head to the summit.
## - Expert: wall kicks up the chimney between the fin's stacks; the
##   belfry's corbels up onto its wall head.
## - The cut stairs are sound (no gap a ray drops through); every floating
##   stone stands where it is drawn; the isle draws within its budget.
##   godot --headless --path . --script tests/test_bell_spires_isle.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Art = preload("res://studies/bell_spires_isle_art.gd")
const Belfry = preload("res://scripts/ruin_kit_belfry.gd")
const RopeBridge = preload("res://scripts/rope_bridge.gd")
const DT := 1.0/60.0
const BUDGET := 900000
var failures := 0
## The deepest each bridge sagged (m), by its node's name.
var sags := {}
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("bell spires test timed out"); quit(2))
	study = load("res://studies/bell_spires_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	var tris: int = study.triangles(study.art)
	check(tris > 0 and tris < BUDGET,"The isle draws %d triangles (budget %d)" % [tris,BUDGET])
	_start_stands()
	_easy_way()
	_fin_way()
	_bridges()
	_gable()
	_needle()
	_chimney()
	_corbels()
	_stairs_sound()
	_stones_sound()
	print("PASS: bell spires isle" if failures == 0 else "FAIL: bell spires isle (%d)" % failures)
	quit(1 if failures else 0)

# --- Driving -------------------------------------------------------------------------

func tick(want: Vector2, jump := false, crouch := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl
	study.tick(DT)
	# The bridges' sims step with the frame (as their _process does).
	for bridge: MeshInstance3D in study.bridges:
		bridge._process(DT)
		sags[str(bridge.name)] = maxf(float(sags.get(str(bridge.name),0.0)),float(bridge.sim.deepest()))

func flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

func ahead(way: Vector2, reach := 0.7) -> float:
	return study.ground.ground(flat(m.feet)+way*reach)

func settle(at: Vector3, face: Vector2) -> void:
	study.place(at,face)
	for i in range(30):
		tick(Vector2.ZERO)
		if m.grounded and i > 8: break

## Walked through `points` (world; their x, z), the stick only: true at the
## last, standing; `fell` counts the times he was in the air 0.3 s or hung
## from a ledge on the way; `lowest` how far under the way's height he got.
func walk(points: Array, frames := 6000) -> Dictionary:
	var i := 0
	var air := 0
	var fell := 0
	var lowest := INF
	for f in range(frames):
		var to: Vector3 = points[i]
		var off: Vector2 = flat(to)-flat(m.feet)
		var last := i == points.size()-1
		if off.length() < (0.45 if last else 0.6):
			i += 1
			if i >= points.size(): break
			continue
		tick(off.normalized())
		air = 0 if m.grounded else air+1
		if air == 18: fell += 1
		if m.on_ledge(): fell += 1
		lowest = minf(lowest,m.feet.y-to.y)
		if m.feet.y < to.y-6.0: break
	return {"ok":i >= points.size() and m.grounded,"fell":fell,"reached":i,"of":points.size(),"lowest":lowest}

## From `from` to `to` (a top's point; y its height): jumps at an edge or
## a wall ahead (a running jump, `tech` "jump" or "jump_twirl"), catches
## and climbs a lip. True stood there.
func line(from: Vector3, to: Vector3, tech: String) -> bool:
	var target := Vector2(to.x,to.z)
	settle(from,(target-flat(from)).normalized())
	var jumped := false
	var twirled := false
	for i in range(900):
		var off := target-flat(m.feet)
		var way := off.normalized() if off.length() > 0.05 else Vector2.ZERO
		var jump := false
		var twirl := false
		var edge: bool = m.grounded and ahead(way,0.35) < m.feet.y-0.45
		var wall: bool = m.grounded and ahead(way,0.6) > m.feet.y+0.45
		if not jumped and (edge or wall): jump = true
		jump = jump or (jumped and not m.grounded and m.velocity.y > 0.0) or (m.on_ledge() and i%20 < 3)
		twirl = tech == "jump_twirl" and jumped and not twirled and not m.grounded and m.velocity.y < 0.5
		jumped = jumped or jump
		twirled = twirled or twirl
		tick(way,jump,false,twirl)
		if m.feet.y < to.y-8.0: return false
		if m.grounded and not m.on_ledge():
			if absf(m.feet.y-to.y) < 0.15 and off.length() < 1.2: return true
			if jumped and i > 30 and m.speed() < 0.2: return false
	return false

## From stone `a` (its top) a jump to `b` (a point or a stone's top): a
## run-up from its near side.
func hop(a: Vector3, b: Vector3, tech := "jump") -> bool:
	var way := Vector2(b.x-a.x,b.z-a.z).normalized()
	return line(a-Vector3(way.x,0.0,way.y)*0.7,b,tech)

func stone(name: String) -> Vector3:
	return Art.platform(name).at

## The way along a stair (foot to head), every other point.
func stair(name: String) -> Array:
	var all: Array = Art.stair_way(Art.layout().stairs[name])
	var out: Array = []
	for i in range(all.size()):
		if i%2 == 0 or i == all.size()-1: out.append(all[i])
	return out

## A bridge's ends, a little in off its decks' ends onto the land.
func across(name: String, reverse := false) -> Array:
	var br: Dictionary = Art.bridge(name)
	var a: Vector3 = br.a
	var b: Vector3 = br.b
	if reverse:
		var swap := a
		a = b
		b = swap
	var way := (b-a)
	way.y = 0.0
	way = way.normalized()
	return [a-way*0.9,a+way*0.4,b-way*0.4,b+way*1.2]

# --- The start ----------------------------------------------------------------------

func _start_stands() -> void:
	study.respawn()
	for i in range(40): tick(Vector2.ZERO)
	check(m.grounded and absf(m.feet.y-Art.ground(m.feet.x,m.feet.z)) < 0.1,"Set down at the start he stands on the isle's turf (feet %s)" % m.feet)

# --- The easy ways ------------------------------------------------------------------

## Up the low stack, over the low bridge, up the hero's stair to the summit,
## up the belfry's outer stair to its floor: walked, never jumped.
func _easy_way() -> void:
	var l: Dictionary = Art.layout()
	study.respawn()
	for i in range(20): tick(Vector2.ZERO)
	var low := stair("low")
	var r := walk(low)
	var low_top: float = l.spires.low.top
	check(r.ok and r.fell == 0 and absf(m.feet.y-low_top) < 0.2,"Easy way: walked up the low stack's cut stair from the start to its top at %.2f m (%d of %d points, %d falls, feet %s)" % [low_top,r.reached,r.of,r.fell,m.feet])
	r = walk(across("low",true))
	var first: Dictionary = l.stairs.hero.landings[0]
	check(r.ok and r.fell == 0 and absf(m.feet.y-float(first.y)) < 0.25,"Easy way: walked over the low bridge through the arch onto the hero's stair (%d falls, feet %s)" % [r.fell,m.feet])
	var hero := stair("hero")
	r = walk(hero)
	var top: float = l.spires.hero.top
	check(r.ok and r.fell == 0 and absf(m.feet.y-top) < 0.3,"Easy way: walked up the hero's cut stair round the spire to the summit at %.2f m (%d of %d points, %d falls, feet %s)" % [top,r.reached,r.of,r.fell,m.feet])
	var way: Array = []
	for p: Vector3 in study.belfry.get_meta("way"): way.append(study.belfry.global_transform*p)
	r = walk(way)
	var floor_y: float = (study.belfry.global_transform*Vector3(0.0,Belfry.FLOOR,0.0)).y
	check(r.ok and r.fell == 0 and absf(m.feet.y-floor_y) < 0.2,"Easy way: walked up the belfry's outer stair round three faces to its floor under the bell at %.2f m (%d of %d points, %d falls, feet %s)" % [floor_y,r.reached,r.of,r.fell,m.feet])

## Up the fin: its low stack's stair to the chockstone, round its high
## stack to the top, over the fin bridge onto the hero's stair.
func _fin_way() -> void:
	var l: Dictionary = Art.layout()
	var fl := stair("fin_low")
	var first: Vector3 = fl[0]
	var out: Vector2 = (flat(first)-(l.spires.fin_low.c as Vector2)).normalized()
	settle(Vector3(first.x+out.x*1.6,Art.TOP+0.5,first.z+out.y*1.6),-out)
	var r := walk(fl)
	var chock: Vector3 = l.chock.at
	check(r.ok and r.fell == 0 and absf(m.feet.y-chock.y) < 0.2,"Fin: walked up the low stack's stair to its top by the chockstone at %.2f m (%d of %d points, %d falls, feet %s)" % [chock.y,r.reached,r.of,r.fell,m.feet])
	var fh := stair("fin_high")
	r = walk([chock]+fh)
	var top: float = l.spires.fin_high.top
	check(r.ok and r.fell == 0 and absf(m.feet.y-top) < 0.25,"Fin: over the chockstone and walked round the high stack's stair to its top at %.2f m (%d of %d points, %d falls, feet %s)" % [top,r.reached,r.of,r.fell,m.feet])
	r = walk(across("fin",true))
	check(r.ok and r.fell == 0 and absf(m.feet.y-top) < 0.25,"Fin: walked over the fin bridge onto the hero's stair (a loop with the easy way) (%d falls, feet %s)" % [r.fell,m.feet])

# --- The bridges -----------------------------------------------------------------------

## Each bridge walked both ways from its anchors, never fallen from; under
## him its deck sags (the live sim takes his weight).
func _bridges() -> void:
	for br: Dictionary in Art.layout().bridges:
		var name: String = br.name
		var sagged := 0.0
		var ok := true
		var falls := 0
		for reverse: bool in [false,true]:
			var pts := across(name,reverse)
			settle(pts[0],(flat(pts[1])-flat(pts[0])).normalized())
			var r := walk(pts.slice(1))
			ok = ok and r.ok
			falls += int(r.fell)
			sagged = maxf(sagged,float(sags.get("Bridge_"+name,0.0)))
			if absf(m.feet.y-float((pts[3] as Vector3).y)) > 0.45: ok = false
		var span: float = Vector2(br.b.x-br.a.x,br.b.z-br.a.z).length()
		check(ok and falls == 0,"Bridge %s (%.1f m at %.2f m): walked over both ways, never fallen from (%d falls, feet %s)" % [name,span,float(br.a.y),falls,m.feet])
		check(sagged > 0.02,"Bridge %s: its deck sags under him (%.2f m)" % [name,sagged])

# --- The gable stack and the drift ------------------------------------------------------

func _gable() -> void:
	var l: Dictionary = Art.layout()
	var gable: Dictionary = l.spires.gable
	var low: Dictionary = l.spires.low
	var stones: Array = []
	for p: Dictionary in Art.platforms():
		if p.chain == "drift": stones.append(p)
	var start: Vector3 = stones[0].at
	var from := (low.c as Vector2)+(flat(start)-(low.c as Vector2)).normalized()*(Art.radius_at(low,(flat(start)-(low.c as Vector2)).angle(),float(low.top))-1.0)
	var ok := line(Vector3(from.x,float(low.top),from.y),start,"jump")
	var n := 0
	for k in range(1,stones.size()):
		if not ok: break
		n += 1
		ok = hop(stones[k-1].at,stones[k].at)
	if ok: n += 1
	var last: Vector3 = stones[stones.size()-1].at
	var to := (gable.c as Vector2)+(flat(last)-(gable.c as Vector2)).normalized()*(Art.radius_at(gable,(flat(last)-(gable.c as Vector2)).angle(),float(gable.top))-1.2)
	ok = ok and hop(last,Vector3(to.x,Art.top_height(gable,to),to.y))
	check(ok,"Drift: from the low stack's top over %d of %d floating stones, rising %.2f m a jump, onto the gable stack's top (feet %s)" % [n,stones.size(),(float(gable.top)-float(low.top))/(stones.size()+1),m.feet])
	# And back down it, the other way.
	var back := line(Vector3(to.x,Art.top_height(gable,to),to.y)+Vector3(0,0,0),last,"jump")
	for k in range(stones.size()-1,0,-1):
		if not back: break
		back = hop(stones[k].at,stones[k-1].at)
	check(back,"Drift: and back down it from the gable stack to the first stone (feet %s)" % m.feet)

# --- The needle -----------------------------------------------------------------------

## Over the high bridge, up the turret's spiral, over the stones to the summit.
func _needle() -> void:
	var l: Dictionary = Art.layout()
	var needle: Dictionary = l.spires.needle
	var r := walk_from(across("needle"))
	check(r.ok and r.fell == 0,"Needle: walked over the high bridge to the needle's top (%d falls, feet %s)" % [r.fell,m.feet])
	# The turret's spiral: its wedges round the newel from the door.
	var turret: Node3D = null
	for child in study.art.get_children():
		if str(child.name).begins_with("Turret") and flat((child as Node3D).position).distance_to(needle.c) < 1.0: turret = child
	var spiral: Array = []
	if turret != null:
		var door := TAU*2.0/8.0+PI/8.0+0.1
		var count := int(RuinKit.TURRET_STEPS*RuinKit.TURRET_TURNS)
		spiral.append(turret.transform*Vector3(cos(TAU*2.0/8.0)*2.6,0.0,sin(TAU*2.0/8.0)*2.6))
		spiral.append(turret.transform*Vector3(cos(TAU*2.0/8.0)*1.0,0.0,sin(TAU*2.0/8.0)*1.0))
		for i in range(count):
			var a := door+TAU*(i+0.5)/RuinKit.TURRET_STEPS
			spiral.append(turret.transform*Vector3(cos(a)*0.85,(i+1)*RuinKit.RISER,sin(a)*0.85))
	r = walk(spiral)
	var head: float = float(needle.top)+18*RuinKit.RISER
	check(turret != null and r.ok and m.feet.y > head-0.5,"Needle: walked in at the turret's door and up its spiral stair to its broken head at %.2f m (%d of %d points, %d falls, feet %s)" % [head,r.reached,r.of,r.fell,m.feet])
	var count := 0
	for p: Dictionary in Art.platforms(): count += int(p.chain == "needle")
	var ok := line(m.feet,stone("needle_1"),"jump_twirl")
	var n := 1 if ok else 0
	for k in range(2,count+1):
		if not ok: break
		ok = hop(stone("needle_%d" % (k-1)),stone("needle_%d" % k))
		if ok: n += 1
	var hero: Dictionary = l.spires.hero
	var last := stone("needle_%d" % count)
	var to: Vector2 = Art.HERO+(flat(last)-Art.HERO).normalized()*(Art.radius_at(hero,(flat(last)-Art.HERO).angle(),float(hero.top))-0.8)
	ok = ok and hop(last,Vector3(to.x,Art.top_height(hero,to),to.y))
	check(ok,"Needle: from the turret's head over %d of %d floating stones onto the summit (feet %s)" % [n,count,m.feet])

func walk_from(pts: Array) -> Dictionary:
	settle(pts[0],(flat(pts[1])-flat(pts[0])).normalized())
	return walk(pts.slice(1))

# --- Expert lines ---------------------------------------------------------------------

## Wall kicks up the chimney between the fin's stacks, from the turf onto
## the low stack's top (or the chockstone).
func _chimney() -> void:
	var l: Dictionary = Art.layout()
	var fh: Dictionary = l.spires.fin_high
	var fl: Dictionary = l.spires.fin_low
	var axis: Vector2 = l.chock.axis
	var along: Vector2 = l.chock.along
	var mid: Vector2 = (fh.c as Vector2)+axis*(float(fh.r)*0.78+0.55)-along*0.5
	settle(Vector3(mid.x,Art.TOP+0.5,mid.y),-axis)
	var side := -1.0
	var kicks := 0
	var on := 0
	var was := ""
	var top: float = fl.top
	var best := 0.0
	for i in range(1200):
		on = on+1 if m.move == "wall" else 0
		var jump: bool = (m.grounded and i < 3) or (not m.grounded and m.move != "wall" and m.velocity.y > 0.0 and kicks == 0) or on >= 3
		if m.on_ledge(): jump = i%20 < 3
		var way := axis*side
		if m.move == "kick" and was != "kick":
			kicks += 1
			side = -side
		was = m.move
		# Over the low stack's head: on toward it.
		if m.feet.y > top+0.6: way = axis
		tick(way,jump)
		best = maxf(best,m.feet.y)
		if m.grounded and m.feet.y > Art.TOP+3.0 and i > 30: break
	var kicked := m.feet.y
	# Off whatever ledge the kicks gave out on, a jump-catch onto the top.
	var onto: Vector2 = (fl.c as Vector2)+((fl.c as Vector2).direction_to(flat(m.feet)))*1.6
	var ok: bool = m.grounded and kicked > Art.TOP+3.0 and (absf(kicked-top) < 0.2 or line(m.feet,Vector3(onto.x,Art.top_height(fl,onto),onto.y),"jump"))
	check(ok,"Chimney: %d wall kicks up the 2.6 m chimney between the fin's stacks to %.2f m, then onto the low stack's top at %.2f m (best %.2f, feet %s)" % [kicks,kicked,top,best,m.feet])

## In the belfry: up its corbels, each a jump-catch, onto the wall head.
func _corbels() -> void:
	var xf: Transform3D = study.belfry.global_transform
	var tops: Array = study.belfry.get_meta("corbels")
	var floor_at: Vector3 = xf*Vector3(0.3,Belfry.FLOOR,0.3)
	var ok := line(floor_at,xf*(tops[0] as Vector3),"jump")
	ok = ok and line(xf*((tops[0] as Vector3)+Vector3(0.1,0,0.1)),xf*(tops[1] as Vector3),"jump")
	var c1: Vector3 = tops[1]
	var head := Vector3(c1.x,Belfry.HEAD,c1.z-0.95*signf(c1.z) if absf(c1.z) > 0.0 else c1.z)
	head = Vector3(c1.x*1.0,Belfry.HEAD,-(Belfry.WIDTH*0.5-Belfry.WALL*0.5))
	var w: Vector3 = xf*head
	w.y = study.ground._down(flat(w),w.y+1.5)
	ok = ok and line(xf*c1,w,"jump")
	check(ok,"Belfry: from the floor up its two corbels onto the wall head at %.2f m, the isle's highest walk (feet %s)" % [w.y,m.feet])

# --- Soundness -------------------------------------------------------------------------

## Every cut stair's treads ground their tops: no gap a ray drops through.
func _stairs_sound() -> void:
	var l: Dictionary = Art.layout()
	var bad := 0
	var probes := 0
	for name: String in l.stairs:
		var st: Dictionary = l.stairs[name]
		var s: Dictionary = l.spires[st.spire]
		var all: Array = []
		all.append_array(st.steps)
		all.append_array(st.landings)
		for t: Dictionary in all:
			if float(t.y) <= Art.TOP+0.01: continue
			for u: float in [0.15,0.5,0.85]:
				for v: float in [0.2,0.5,0.8]:
					var a := lerpf(float(t.a0),float(t.a1),u)
					var r := lerpf(float(t.r_in)+Art.CUT_IN+0.3,float(t.r_out)-0.15,v)
					var p: Vector2 = (s.c as Vector2)+Vector2.from_angle(a)*r
					var hit: float = study.ground._down(p,float(t.y)+0.4)
					probes += 1
					if absf(hit-float(t.y)) > 0.05:
						bad += 1
						if bad < 6: print("     %s tread at %s: %.2f vs %.2f" % [name,p,hit,float(t.y)])
	check(bad == 0,"Cut stairs: every tread grounds its top (%d of %d probes off)" % [bad,probes])

func _stones_sound() -> void:
	var off := 0
	for s: Dictionary in Art.platforms():
		var size: Vector3 = s.size
		var basis := Basis(Vector3.UP,float(s.yaw))
		for u: float in [-0.4,0.0,0.4]:
			for v: float in [-0.4,0.0,0.4]:
				var q: Vector3 = s.at+basis*Vector3(u*size.x,0.0,v*size.z)
				var hit_y: float = study.ground._down(Vector2(q.x,q.z),s.at.y+0.4)
				if absf(hit_y-s.at.y) > 0.03:
					off += 1
					print("     stone %s off at %s: %.3f vs %.3f" % [s.name,q,hit_y,s.at.y])
	check(off == 0,"Floating stones: every one stands where its top is drawn (%d of %d probes off)" % [off,Art.platforms().size()*9])
