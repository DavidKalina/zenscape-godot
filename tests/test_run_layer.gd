extends SceneTree
## suite: slow
## The generated layer (studies/run_layer.tscn, scripts/roguelike/
## layer_plan.gd),
## headless, over a few seeds: the plan is the same for the same seed (and
## knobs, the gulf's width pinned by its knob); 2 or 3 neighbourhoods of 2+
## isles, a gulf GULF wide between each two, open sky (every isle of
## another neighbourhood HOOD_APART off), each with an honest ride (a
## serpent or the ferry); from each gulf's near rim the far rim is in
## sight (a ray); every route edge is
## sized within the pilot's reach (each stride's gap a share of his
## running jump's reach at its rise and over the least that clears it; a
## bridge within the footbridge's span and grade; the trap level); every
## rim it uses stands on its isle's ground with the drop past its lip; the
## edges' corridors are clear of everything but their own stones, bridges
## and slabs; and, driven through the study's own frame (`tick`, the real
## motor stepping, the stage's traps stepped round it), the pilot crosses
## every route edge and the greed branch onto the next isle, the Loose
## Voussoirs falling behind him; the cannon's shot lands him on the greed
## isle; the gate starts the next layer, the void too. Each gulf is
## crossed through the same frame on its ride: walked up onto the near
## pier, boarded as the serpent's middle goes by (or the ferry rests),
## ridden over and got off onto the far pier and walked onto the far
## isle; a gulf's cannon lands him on the far isle.
##   godot --headless --path . --script tests/test_run_layer.gd
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const Probe = preload("res://scripts/roguelike/isle_probe.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const SerpentRoute = preload("res://scripts/kit_isle/serpent_route.gd")
const Ferry = preload("res://scripts/kit_isle/airship_ferry.gd")
const DT := 1.0/60.0
var SEEDS := [15,1,2] if OS.get_environment("RL_SEEDS") == "" else Array(OS.get_environment("RL_SEEDS").split(",")).map(func(s: String) -> int: return int(s))
## A seed planned again with its gulf's width pinned (the knob).
const KNOB_SEED := 2
const KNOB_GULF := 240.0
## The serpent is placed this far (m round its way) short of the near pier:
## some fifteen seconds off, time to walk out and wait.
const SERPENT_LEAD := 130.0
## The pilot's corridor along an edge: clear from this over the path to his
## head, except this near its lips.
const BODY := Vector2(0.35,1.9)
const LIP_NEAR := 1.0

var failures := 0
var study: Node3D
var m: Object

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(900.0).timeout.connect(func() -> void: push_error("run layer test timed out"); quit(2))
	_plans()
	study = load("res://studies/run_layer.tscn").instantiate()
	study.scripted = true
	study.layer_seed = SEEDS[0]
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	m = study.motor
	for k in range(SEEDS.size()):
		if k > 0: study.start_layer(SEEDS[k])
		var began := Time.get_ticks_msec()
		study.sky.flush()
		await physics_frame
		await physics_frame
		await process_frame
		print("run layer test: seed %d stood in %d ms (flushed)" % [SEEDS[k],Time.get_ticks_msec()-began])
		await _layer(SEEDS[k])
	await _loop()
	print("PASS: run layer" if failures == 0 else "FAIL: run layer (%d)" % failures)
	quit(1 if failures > 0 else 0)

# --- The plans ------------------------------------------------------------------

func _plans() -> void:
	var rides := {}
	for s: int in SEEDS:
		var began := Time.get_ticks_msec()
		var a: Dictionary = LayerPlan.make(s)
		print("run layer test: seed %d planned in %d ms (attempt %d)" % [s,Time.get_ticks_msec()-began,int(a.attempt)])
		var b: Dictionary = LayerPlan.make(s)
		check((a.problems as Array).is_empty(),"seed %d: laid (%s)" % [s,str(a.problems)])
		check(LayerPlan.describe(a) == LayerPlan.describe(b),"seed %d: the same plan twice" % s)
		var route: int = a.isles.filter(func(i: Dictionary) -> bool: return i.role == "route").size()
		check(route >= 2 and a.isles.filter(func(i: Dictionary) -> bool: return i.role == "greed").size() == 1,"seed %d: the base, %d route isles and a greed isle" % [s,route])
		check(a.edges.any(func(e: Dictionary) -> bool: return not (e.trap as Dictionary).is_empty() and e.branch == "route"),"seed %d: a trap on the route" % s)
		check(not (a.prize as Dictionary).is_empty() and (a.prize.runes as Array).size() == LayerPlan.RUNES,"seed %d: a rune set on the greed isle" % s)
		_hoods(s,a)
		for gi: int in a.gulfs: rides[a.edges[gi].ride] = true
		_reach(s,a)
	check(rides.has("serpent") and rides.has("ferry"),"The seeds cross gulfs on both rides (%s)" % ", ".join(PackedStringArray(rides.keys())))
	# The gulf's width, pinned.
	var pinned: Dictionary = LayerPlan.make(KNOB_SEED,{"gulf":KNOB_GULF})
	var again: Dictionary = LayerPlan.make(KNOB_SEED,{"gulf":KNOB_GULF})
	var widths: Array = (pinned.gulfs as Array).map(func(gi: int) -> float: return float(pinned.edges[gi].width))
	check((pinned.problems as Array).is_empty() and not widths.is_empty() and widths.all(func(w: float) -> bool: return is_equal_approx(w,KNOB_GULF)) \
		and LayerPlan.describe(pinned) == LayerPlan.describe(again),"--knob=gulf=%.0f: seed %d's gulfs are %s m wide, the same plan twice" % [KNOB_GULF,KNOB_SEED,str(widths)])
	var three: Dictionary = LayerPlan.make(KNOB_SEED,{"hoods":3})
	check((three.problems as Array).is_empty() and (three.hoods as Array).size() == 3 and (three.gulfs as Array).size() == 2,"--knob=hoods=3: three neighbourhoods, two gulfs")

## Neighbourhoods and gulfs: 2 or 3 of 2+ isles each, the exit in the last,
## a gulf between each two GULF wide with an honest ride, its line clear
## and every isle of another neighbourhood HOOD_APART off.
func _hoods(s: int, plan: Dictionary) -> void:
	var hoods: Array = plan.hoods
	check(hoods.size() >= 2 and hoods.size() <= 3 and hoods.all(func(h: Array) -> bool: return h.size() >= 2),"seed %d: %d neighbourhoods of %s isles" % [s,hoods.size(),str(hoods.map(func(h: Array) -> int: return h.size()))])
	check((hoods[hoods.size()-1] as Array).has(int(plan.exit.isle)),"seed %d: the exit in the last neighbourhood" % s)
	check((plan.gulfs as Array).size() == hoods.size()-1,"seed %d: a gulf between each two" % s)
	for gi: int in plan.gulfs:
		var e: Dictionary = plan.edges[gi]
		var a: int = e.from[0]
		var b: int = e.to[0]
		var w: float = e.width
		var flat := Vector2((e.b as Vector3).x-(e.a as Vector3).x,(e.b as Vector3).z-(e.a as Vector3).z).length()
		check(w >= LayerPlan.GULF.x and w <= LayerPlan.GULF.y and absf(flat-w) < 0.01,"seed %d: gulf %d -> %d is %.0f m rim to rim" % [s,a,b,w])
		check(int(plan.isles[a].hood) != int(plan.isles[b].hood) and e.ride in LayerPlan.RIDES and not (e[e.ride] as Dictionary).is_empty(),"seed %d: gulf %d -> %d is crossed on a %s" % [s,a,b,e.ride])
		var near := INF
		for i in range(plan.isles.size()):
			for j in range(plan.isles.size()):
				if int(plan.isles[i].hood) == int(plan.isles[j].hood): continue
				var p: Rect2 = LayerPlan._rect(plan.isles[i])
				var q: Rect2 = LayerPlan._rect(plan.isles[j])
				if Vector2(maxf(maxf(q.position.x-p.end.x,p.position.x-q.end.x),0.0),maxf(maxf(q.position.y-p.end.y,p.position.y-q.end.y),0.0)).length() >= LayerPlan.HOOD_APART: continue
				if LayerPlan._near_cells(plan.isles[i],plan.isles[j],LayerPlan.HOOD_APART): near = 0.0
		check(near > 0.0,"seed %d: isles of two neighbourhoods keep %.0f m apart" % [s,LayerPlan.HOOD_APART])

## Every edge within his reach, from his own numbers.
func _reach(s: int, plan: Dictionary) -> void:
	var p: Object = LayerPlan.pilot()
	for e: Dictionary in plan.edges:
		if e.kind == "gulf": continue
		var label := "seed %d %s %s %d->%d" % [s,e.branch,e.kind,int(e.from[0]),int(e.to[0])]
		var ok := true
		var worst := 0.0
		for st: Dictionary in e.stones:
			if st.get("landing",false): continue
			var gap: float = st.gap
			var rise: float = st.rise
			var share: float = gap/LayerPlan.reach(rise)
			worst = maxf(worst,share)
			var length: float = (st.size as Vector3).x
			ok = ok and share <= (LayerPlan.GAP_HARD.y if e.branch == "greed" else LayerPlan.GAP_SHARE.y)+0.001 and gap > LayerPlan.clears(rise)
			ok = ok and rise < float(p.jumps[0])*0.55 and gap+length >= LayerPlan.pump_reach(rise)
		for ends: Array in e.bridges:
			var a: Vector3 = ends[0]
			var b: Vector3 = ends[1]
			var span := Vector2(b.x-a.x,b.z-a.z).length()
			ok = ok and span <= Footbridge.MAX_SPAN and absf(b.y-a.y)/span <= Footbridge.MAX_GRADE
		if not (e.trap as Dictionary).is_empty():
			var frame: Transform3D = e.trap.frame
			ok = ok and absf(frame.basis.z.y) < 1e-3
		check(ok,"%s: within his reach (worst stride %.0f%% of his jump's)" % [label,worst*100.0])

# --- A built layer --------------------------------------------------------------

func _layer(s: int) -> void:
	var plan: Dictionary = study.layer
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	check(study.sky.motifs.all_stood() and study.sky.motifs.isles.size() == plan.isles.size()-1,"seed %d: its %d motif isles stand" % [s,plan.isles.size()-1])
	# The rims it uses (past what the layer lays off them).
	var own := _own()
	for e: Dictionary in plan.edges:
		for rim: Dictionary in [e.from_rim,e.to_rim]:
			var why := Probe.rim_ok(space,rim,own)
			check(why == "","seed %d: rim %s stands on its ground over the drop %s" % [s,rim.name,why])
	# The corridors.
	for e: Dictionary in plan.edges:
		if e.kind == "gulf": continue
		var hit := _corridor(space,e)
		check(hit == "","seed %d %s %s: its corridor is clear %s" % [s,e.branch,e.kind,hit])
	# Driven across.
	for e: Dictionary in plan.edges:
		if e.kind == "gulf": continue
		var ok := _cross(e)
		check(ok,"seed %d %s %s (%s): crossed on foot, %s" % [s,e.branch,e.kind,", ".join(PackedStringArray(e.parts)),_feet()])
		if not (e.trap as Dictionary).is_empty():
			var trap: Node3D = study.stage.traps.traps[0]
			check(int(trap.fallen_count) > 0,"seed %d: the voussoirs fell behind him (%d)" % [s,int(trap.fallen_count)])
	_cannon(s,plan)
	await _gulfs(s,plan)

## What stands in the pilot's way along the edge: "" for nothing.
func _corridor(space: PhysicsDirectSpaceState3D, e: Dictionary) -> String:
	var a: Vector3 = e.a
	var b: Vector3 = e.b
	var own := _own()
	var path: Array = e.path
	for i in range(path.size()):
		var p: Vector3 = path[i][0]
		if Vector2(p.x-a.x,p.z-a.z).length() < LIP_NEAR or Vector2(p.x-b.x,p.z-b.z).length() < LIP_NEAR: continue
		var up := PhysicsRayQueryParameters3D.create(p+Vector3.UP*BODY.x,p+Vector3.UP*BODY.y,0xFFFFFFFF,own)
		var hit := space.intersect_ray(up)
		if not hit.is_empty(): return "(%s in it at %s)" % [(hit.collider as Node).get_path(),p]
		if i > 0:
			var q: Vector3 = path[i-1][0]
			var along := PhysicsRayQueryParameters3D.create(q+Vector3.UP*1.0,p+Vector3.UP*1.0,0xFFFFFFFF,own)
			hit = space.intersect_ray(along)
			if not hit.is_empty(): return "(%s across it at %s)" % [(hit.collider as Node).get_path(),p]
	return ""

## What the layer's stage lays (stones, slabs, anchors, the ram, the cannon).
func _own() -> Array[RID]:
	var own: Array[RID] = []
	for node: Node in study.stage.find_children("*","CollisionObject3D",true,false): own.append((node as CollisionObject3D).get_rid())
	return own

# --- Driving --------------------------------------------------------------------

func tick(want: Vector2, jump := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.tick(DT)

func _feet() -> String:
	return "feet %s" % str((m.feet as Vector3).snapped(Vector3.ONE*0.01))

## Across edge `e` from a run-up behind its rim to inland past its far rim:
## running at each support's middle in turn, jumping at the lip and each
## stone's far edge (where the ground drops away, or on reaching it),
## holding the jump while he rises.
## RL_TRACE=<seed> prints that seed's crossings frame by frame.
var trace := false

func _cross(e: Dictionary) -> bool:
	trace = OS.get_environment("RL_TRACE") == str(study.layer_seed)
	if trace: print(" crossing %s %s: %s" % [e.branch,e.kind,e.parts])
	if study.stage != null: study.stage.reset()
	var from: Dictionary = e.from_rim
	var to: Dictionary = e.to_rim
	var dir: Vector3 = e.dir
	var back := minf(float(from.run_up),2.5)
	var start: Vector3 = (from.at as Vector3)-(from.face as Vector3)*back
	study.place(_ground(start),Vector2(dir.x,dir.z).normalized())
	if trace: print("  placed at %s (rim %s at %s), feet %s, layer %d" % [_ground(start),from.name,from.at,m.feet,study.layer_seed])
	for i in range(20): tick(Vector2.ZERO)
	if trace: print("  settled: feet %s, layer %d" % [m.feet,study.layer_seed])
	var targets: Array = [e.a]
	for st: Dictionary in e.stones: targets.append(st.at)
	for ends: Array in e.bridges: targets.append_array([ends[0],ends[1]])
	if not (e.trap as Dictionary).is_empty(): targets.append(e.b)
	targets.append(e.b)
	var end: Vector3 = (to.at as Vector3)-(to.face as Vector3)*1.5
	targets.append(end)
	targets.sort_custom(func(p: Vector3, q: Vector3) -> bool: return (p-start).dot(dir) < (q-start).dot(dir))
	# Where he leaves the ground (along the way): the lip when stones lead
	# off it, each stone's far edge (not a landing's: a bridge or the slabs
	# go on from it).
	var takeoffs: Array = []
	if not (e.stones as Array).is_empty() and not bool(e.stones[0].get("landing",false)): takeoffs.append((e.a as Vector3-start).dot(dir))
	for st: Dictionary in e.stones:
		if st.get("landing",false): continue
		takeoffs.append(((st.at as Vector3)-start).dot(dir)+float((st.size as Vector3).x)*0.5)
	var i := 0
	var rising := false
	var ungrounded := 0
	for f in range(1800):
		var target: Vector3 = targets[i]
		var off := Vector2(target.x-m.feet.x,target.z-m.feet.z)
		# Past it along the way: on to the next.
		if (Vector3(m.feet.x,0.0,m.feet.z)-Vector3(target.x,0.0,target.z)).dot(dir) > -0.3 and i < targets.size()-1:
			i += 1
			continue
		var way := off.normalized() if off.length() > 0.05 else Vector2.ZERO
		var along := (Vector3(m.feet.x,start.y,m.feet.z)-start).dot(dir)
		var leave := false
		# Grounded, or just off it (the motor's coyote time).
		if (m.grounded or ungrounded < 4) and not takeoffs.is_empty():
			var t: float = takeoffs[0]
			var drop: bool = study.ground.ground(Vector2(m.feet.x,m.feet.z)+way*0.12) < m.feet.y-0.25
			if along > t-0.5 and (drop or along > t-0.05): leave = true
		if leave or (not takeoffs.is_empty() and along > float(takeoffs[0])+0.5): takeoffs.pop_front()
		var jump: bool = leave or (rising and not m.grounded and m.velocity.y > 0.0)
		if trace and (f%10 == 0 or leave): print("  f%d target %d %s feet %s g %s v %s %s" % [f,i,target.snapped(Vector3.ONE*0.01),(m.feet as Vector3).snapped(Vector3.ONE*0.01),m.grounded,(m.velocity as Vector3).snapped(Vector3.ONE*0.01),"JUMP" if leave else ""])
		rising = jump
		tick(way if i < targets.size()-1 or off.length() > 0.3 else Vector2.ZERO,jump)
		ungrounded = 0 if m.grounded else ungrounded+1
		if m.feet.y < minf((e.a as Vector3).y,(e.b as Vector3).y)-8.0: return false
		if i == targets.size()-1 and off.length() < 0.6 and m.grounded and absf(m.feet.y-end.y) < 1.0: return true
	return false

func _ground(p: Vector3) -> Vector3:
	var hit := study.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*3.0,p+Vector3.DOWN*3.0,0xFFFFFFFF))
	return (hit.position as Vector3)+Vector3.UP*0.05 if not hit.is_empty() else p

## The cannon at its found aim and power fires him onto the greed isle.
func _cannon(s: int, plan: Dictionary) -> void:
	if (plan.cannon as Dictionary).is_empty():
		print("run layer test: seed %d has no cannon shot" % s)
		return
	var field: Node = study.stage.cannons
	var c: Node3D = field.cannons[0]
	study.place(_ground(field.stand(c)),Vector2(0.0,-1.0))
	for i in range(10): tick(Vector2.ZERO)
	field.operate(c)
	c.set_aim(0.0,float(plan.cannon.pitch))
	c.set_power(int(plan.cannon.notch))
	field.climb_in()
	field.launch_self()
	var landed := false
	for f in range(600):
		tick(Vector2.ZERO)
		if m.grounded and f > 10:
			landed = true
			break
	var target: Vector3 = plan.cannon.target
	var miss := Vector2(m.feet.x-target.x,m.feet.z-target.z).length()
	check(landed and miss < 2.5 and absf(m.feet.y-target.y) < 1.5,"seed %d: the cannon lands him on the greed isle (%.1f m off its mark, %s)" % [s,miss,_feet()])

# --- The gulfs ------------------------------------------------------------------

## Each gulf: the far rim in sight from the near; its ride open (both isles
## stand); crossed on it; its cannon, if any, landing him over it.
func _gulfs(s: int, plan: Dictionary) -> void:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var rides: Node3D = study.stage.rides
	for k in range(rides.gulfs.size()):
		var g: Dictionary = rides.gulfs[k]
		var e: Dictionary = g.edge
		var label := "seed %d gulf %d->%d (%.0f m, %s)" % [s,int(e.from[0]),int(e.to[0]),float(e.width),g.ride]
		var eye: Vector3 = (e.from_rim.at as Vector3)+Vector3.UP*LayerPlan.EYE
		var far: Vector3 = (e.to_rim.at as Vector3)+Vector3.UP*LayerPlan.EYE
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,far,0xFFFFFFFF,_own()))
		check(hit.is_empty() or (hit.position as Vector3).distance_to(far) < 3.0,"%s: from the near rim the far rim is in sight across it%s" % [label,"" if hit.is_empty() else " (%s at %s)" % [(hit.collider as Node).name,(hit.position as Vector3).round()]])
		check(g.ready,"%s: its isles stand, its ride open" % label)
		if g.ride == "serpent": await _ride_serpent(label,g)
		else: await _ride_ferry(label,g)
		if g.cannon != null: _gulf_cannon(label,g)

func _ride_frame(g: Dictionary) -> void:
	if g.ride == "serpent":
		g.route.serpent.advance(DT)
		g.route._process(DT)
		g.route.rider.step(DT)
	else: g.ferry.step(DT)
	study.tick(DT)

## Onto a pier from the turf behind it: placed behind its flight's foot, a
## walk straight out up the steps to `stand`. Whether he stands there.
func _walk_onto(g: Dictionary, foot: Vector3, toward: Vector2, stand: Vector3) -> bool:
	var at := foot-Vector3(toward.x,0.0,toward.y)*1.2
	study.place(_ground(at+Vector3.UP*1.0),toward)
	if g.ride == "serpent": g.route.rider.reset()
	for i in range(20):
		study.script_want = Vector2.ZERO
		_ride_frame(g)
	for i in range(60*12):
		var off := Vector2(stand.x-m.feet.x,stand.z-m.feet.z)
		if off.length() < 0.4: break
		study.script_want = off.normalized() if off.length() > 0.6 else off.normalized()*0.4
		study.script_jump = false
		_ride_frame(g)
		if OS.get_environment("RL_TRACE") != "" and i%20 == 0:
			var w := Vector3(off.normalized().x,0.0,off.normalized().y)
			var hit: Dictionary = study.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(m.feet+Vector3.UP*0.5,m.feet+Vector3.UP*0.5+w*1.0))
			print("  onto f%d %s to %s g %s v %s ahead %s" % [i,_feet(),stand.snapped(Vector3.ONE*0.01),m.grounded,(m.velocity as Vector3).snapped(Vector3.ONE*0.01),(hit.collider as Node).get_path() if not hit.is_empty() else "-"])
	study.script_want = Vector2.ZERO
	for i in range(20): _ride_frame(g)
	return Vector2(stand.x-m.feet.x,stand.z-m.feet.z).length() < 1.0 and absf(m.feet.y-stand.y) < 0.4

## Off a pier onto the isle behind it: walked back down its steps and on
## past their foot. Whether he stands on the turf there.
func _walk_inland(g: Dictionary, foot: Vector3, toward: Vector2) -> bool:
	var to: Vector3 = _ground(foot-Vector3(toward.x,0.0,toward.y)*1.5+Vector3.UP*1.0)
	for i in range(60*12):
		var off := Vector2(to.x-m.feet.x,to.z-m.feet.z)
		if off.length() < 0.5 and m.grounded: break
		study.script_want = off.normalized()
		_ride_frame(g)
		if OS.get_environment("RL_TRACE") != "" and i%20 == 0: print("  inland f%d feet %s to %s g %s v %s move %s" % [i,_feet(),to.snapped(Vector3.ONE*0.01),m.grounded,(m.velocity as Vector3).snapped(Vector3.ONE*0.01),m.move])
	study.script_want = Vector2.ZERO
	for i in range(20): _ride_frame(g)
	return Vector2(to.x-m.feet.x,to.z-m.feet.z).length() < 1.2 and absf(m.feet.y-to.y) < 1.0 and m.grounded

## The serpent: walked up onto the near pier, waited for, boarded as its
## middle goes by, ridden over the gulf, got off onto the far pier as it
## passes, walked onto the far isle (serpent_route's own test's moves).
func _ride_serpent(label: String, g: Dictionary) -> void:
	var route: Node3D = g.route
	var serpent: Node3D = route.serpent
	var rider: Node3D = route.rider
	serpent.set_process(false)
	route.set_process(false)
	rider.manual = true
	var near: Dictionary = route.spots[0]
	var far: Dictionary = route.spots[1]
	check(near.built != null and far.built != null,"%s: a pier at each rim (%d and %d steps up)" % [label,int(near.get("steps",0)),int(far.get("steps",0))])
	# It comes by in a few seconds (its lap is learnt: it passes each pier
	# once a lap).
	serpent.place(fposmod(float(near.at)-SERPENT_LEAD,float(serpent.route_length)))
	var onto := _walk_onto(g,near.foot,near.toward,near.stand)
	check(onto,"%s: walked up the steps onto the near pier (%s, its end %s)" % [label,_feet(),(near.stand as Vector3).snapped(Vector3.ONE*0.01)])
	if not onto: study.place(near.stand,near.toward)
	# Its middle alongside: run and jump for its back.
	var toward: Vector2 = near.toward
	var end: Vector3 = near.end
	var arcs: PackedFloat32Array = serpent.stations()
	var went := false
	var held := 0.0
	for i in range(60*40):
		if not went:
			var rings: PackedVector3Array = serpent.rings()
			var best := INF
			var k_best := 0
			for k in range(rings.size()):
				var d := Vector2(rings[k].x-end.x,rings[k].z-end.z).length()
				if d < best:
					best = d
					k_best = k
			if arcs[k_best] > 22.0 and arcs[k_best] < 40.0 and best < 8.0: went = true
		var edge := Vector2(m.feet.x-end.x,m.feet.z-end.z).dot(toward) > -0.35
		if went and edge and m.grounded and held == 0.0: held = 0.3
		study.script_want = toward if went else Vector2.ZERO
		study.script_jump = held > 0.0
		held = maxf(held-DT,0.0) if held > 0.0 and not m.grounded else held
		_ride_frame(g)
		if rider.riding_on == "serpent": break
	study.script_want = Vector2.ZERO
	study.script_jump = false
	for i in range(20): _ride_frame(g)
	check(rider.riding_on == "serpent","%s: a running jump off the pier as its middle goes by lands him on its back (%s)" % [label,_feet()])
	if rider.riding_on != "serpent": return
	# Kept to its spine till the far pier comes alongside.
	var frames := 0
	var off_at := Vector3.INF
	var far_end: Vector3 = far.end
	var lost_ok := true
	while frames < 60*120:
		var x: Vector3 = rider.back.frame(rider.anchor.x).basis.x
		study.script_want = -Vector2(x.x,x.z).normalized()*clampf(float(rider.anchor.y)*1.5,-1.0,1.0) if absf(rider.anchor.y) > 0.25 else Vector2.ZERO
		_ride_frame(g)
		frames += 1
		if rider.riding_on != "serpent":
			lost_ok = false
			break
		var to_end := Vector2(far_end.x-m.feet.x,far_end.z-m.feet.z)
		var along := to_end.dot(far.way as Vector2)
		var pace := Vector2(rider.carry_v.x,rider.carry_v.z).length()
		if along > 0.0 and along < pace*1.15+2.0 and to_end.length() < 20.0:
			off_at = m.feet
			break
	check(lost_ok and off_at != Vector3.INF,"%s: it carries him over the gulf alongside the far pier (%.0f s on its back)" % [label,frames*DT])
	if off_at == Vector3.INF: return
	# Off: run across its back and jump at the shoulder, twirling.
	var out: Vector2 = far.toward
	var landed := false
	var twirled := false
	held = 0.0
	for i in range(240):
		var across := Vector2(m.feet.x-far_end.x,m.feet.z-far_end.z).dot(out)
		var at_edge: bool = rider.riding_on == "serpent" and across < float(route.widest_flank())+float(SerpentRoute.LEDGE_GAP)-0.9
		if at_edge and m.grounded and held == 0.0: held = 0.4
		study.script_twirl = not m.grounded and m.velocity.y < 1.0 and not twirled
		if study.script_twirl: twirled = true
		study.script_want = -out
		study.script_jump = held > 0.0
		held = maxf(held-DT,0.0) if held > 0.0 and not m.grounded else held
		_ride_frame(g)
		if rider.riding_on == "still" and m.grounded:
			landed = true
			break
	study.script_want = Vector2.ZERO
	study.script_jump = false
	study.script_twirl = false
	for i in range(10): _ride_frame(g)
	var on_pier: bool = landed and absf(m.feet.y-float(far.top)) < 0.3 and Vector2(m.feet.x-far_end.x,m.feet.z-far_end.z).length() < 6.0
	check(on_pier,"%s: a jump off its back lands him on the far pier (%s, its end %s)" % [label,_feet(),far_end.snapped(Vector3.ONE*0.01)])
	if not on_pier: return
	check(_walk_inland(g,far.foot,far.toward),"%s: down the far pier's steps onto the far isle (%s)" % [label,_feet()])
	rider.manual = false
	serpent.set_process(true)
	route.set_process(true)

## The ferry: walked up onto the near pier, waited for, walked aboard as it
## rests, carried over, walked off onto the far pier as it rests there and
## on onto the far isle.
func _ride_ferry(label: String, g: Dictionary) -> void:
	var ferry: Node3D = g.ferry
	ferry.manual = true
	var near: Dictionary = g.piers[0][0]
	var far: Dictionary = g.piers[1][0]
	check(g.piers[0][1] != null and g.piers[1][1] != null,"%s: a pier at each rim (%d and %d steps up)" % [label,int(near.get("steps",0)),int(far.get("steps",0))])
	ferry.set_clock(ferry.clock_before("a",6.0))
	var stand: Vector3 = (near.end as Vector3)-Vector3(near.toward.x,0.0,near.toward.y)*0.8
	var onto := _walk_onto(g,near.foot,near.toward,stand)
	check(onto,"%s: walked up the steps onto the near pier (%s)" % [label,_feet()])
	if not onto: study.place(stand,near.toward)
	var waited := 0
	while ferry.resting() != "a" and waited < 60*60:
		study.script_want = Vector2.ZERO
		_ride_frame(g)
		waited += 1
	for i in range(30): _ride_frame(g)
	var had: int = ferry.boardings
	var walked := 0
	while ferry.riding_on != "deck" and walked < 180:
		var to: Vector3 = ferry.deck_point()
		var off := Vector2(to.x-m.feet.x,to.z-m.feet.z)
		study.script_want = off.normalized() if off.length() > 0.3 else Vector2.ZERO
		_ride_frame(g)
		walked += 1
	for i in range(40):
		var to: Vector3 = ferry.deck_point()
		var off := Vector2(to.x-m.feet.x,to.z-m.feet.z)
		study.script_want = off.normalized()*0.5 if off.length() > 0.4 else Vector2.ZERO
		_ride_frame(g)
	study.script_want = Vector2.ZERO
	check(ferry.riding_on == "deck" and ferry.boardings > had,"%s: he walks aboard off the pier as it rests (waited %.0f s, %s)" % [label,waited*DT,_feet()])
	if ferry.riding_on != "deck": return
	# Carried over: stood on the foredeck till it rests at the far pier.
	var frames := 0
	var left := false
	while frames < int(ferry.lap/DT):
		_ride_frame(g)
		frames += 1
		if ferry.resting() == "": left = true
		if left and ferry.resting() == "b": break
		if ferry.riding_on != "deck": break
	check(ferry.resting() == "b" and ferry.riding_on == "deck","%s: it carries him over the gulf to the far pier (%.0f s aboard)" % [label,frames*DT])
	if ferry.resting() != "b": return
	for i in range(30): _ride_frame(g)
	# Off onto the pier and the isle.
	var end: Vector3 = far.end
	var back: Vector3 = end-Vector3(far.toward.x,0.0,far.toward.y)*1.5
	for i in range(60*4):
		var off := Vector2(back.x-m.feet.x,back.z-m.feet.z)
		if off.length() < 0.4: break
		study.script_want = off.normalized()
		_ride_frame(g)
	study.script_want = Vector2.ZERO
	for i in range(10): _ride_frame(g)
	var on_pier: bool = ferry.riding_on == "still" and absf(m.feet.y-float(far.top)) < 0.3
	check(on_pier,"%s: he walks off it onto the far pier as it rests (%s)" % [label,_feet()])
	if not on_pier: return
	check(_walk_inland(g,far.foot,far.toward),"%s: down the far pier's steps onto the far isle (%s)" % [label,_feet()])
	ferry.manual = false

## The gulf's cannon at its found aim and power fires him over onto the far
## isle.
func _gulf_cannon(label: String, g: Dictionary) -> void:
	var c: Node3D = g.cannon
	var plan_c: Dictionary = g.edge.cannon
	var field: Node = study.stage.cannons
	# The ferry out over the gulf's middle (resting by a pier or passing
	# its ship may stand in the shot's way: a risk in play, not this
	# check's).
	if g.has("ferry"):
		g.ferry.set_clock(g.ferry.clock_before("a",-Ferry.HOLD-float(g.ferry.stop("a").travel)*0.5))
	study.place(_ground(field.stand(c)),Vector2(0.0,-1.0))
	for i in range(10): tick(Vector2.ZERO)
	field.operate(c)
	c.set_aim(0.0,float(plan_c.pitch))
	c.set_power(int(plan_c.notch))
	field.climb_in()
	field.launch_self()
	var landed := false
	for f in range(60*15):
		tick(Vector2.ZERO)
		if m.grounded and f > 10:
			landed = true
			break
	var target: Vector3 = plan_c.target
	var miss := Vector2(m.feet.x-target.x,m.feet.z-target.z).length()
	check(landed and miss < 3.0 and absf(m.feet.y-target.y) < 1.5,"%s: its cannon (%.1f runs) lands him on the far isle (%.1f m off its mark, %s)" % [label,float(plan_c.speed)/float(LayerPlan.pilot().run),miss,_feet()])

# --- The loop -------------------------------------------------------------------

func _loop() -> void:
	var was: int = study.layer_seed
	var exit: Dictionary = study.layer.exit
	study.place(exit.at,Vector2(1.0,0.0))
	tick(Vector2.ZERO)
	check(study.layer_seed == was+1 and study.last_end.begins_with("Through the gate"),"At the gate, the next layer (seed %d -> %d)" % [was,study.layer_seed])
	var spawn: Vector3 = study.layer.spawn.at
	check(Vector2(m.feet.x-spawn.x,m.feet.z-spawn.z).length() < 1.0 and absf(m.feet.y-spawn.y) < 2.0,"He starts the new layer at its spawn on the base (%s, the spawn %s)" % [_feet(),spawn.snapped(Vector3.ONE*0.01)])
	was = study.layer_seed
	study.place(Vector3(m.feet.x,float(study.layer.void_y)+1.0,m.feet.z),Vector2(1.0,0.0))
	for i in range(30): tick(Vector2.ZERO)
	check(study.layer_seed == was+1 and study.last_end.begins_with("Into the void"),"Into the void, the next layer (seed %d -> %d)" % [was,study.layer_seed])
