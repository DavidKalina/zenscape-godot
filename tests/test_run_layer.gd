extends SceneTree
## suite: slow
## The generated layer (studies/run_layer.tscn, scripts/roguelike/
## layer_plan.gd; docs/design/roguelike/layer-round2.md), headless, over a
## few seeds: the plan is the same for the same seed; every route edge is
## sized within the pilot's reach (each stride's gap a share of his
## running jump's reach at its rise and over the least that clears it; a
## bridge within the footbridge's span and grade; the trap level); every
## rim it uses stands on its isle's ground with the drop past its lip; the
## edges' corridors are clear of everything but their own stones, bridges
## and slabs; and, driven through the study's own frame (`tick`, the real
## motor stepping, the stage's traps stepped round it), the pilot crosses
## every route edge and the greed branch onto the next isle, the Loose
## Voussoirs falling behind him; the cannon's shot lands him on the greed
## isle; the gate starts the next layer, the void too.
##   godot --headless --path . --script tests/test_run_layer.gd
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const Probe = preload("res://scripts/roguelike/isle_probe.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const DT := 1.0/60.0
var SEEDS := [3,4,9,12] if OS.get_environment("RL_SEEDS") == "" else Array(OS.get_environment("RL_SEEDS").split(",")).map(func(s: String) -> int: return int(s))
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
		print("run layer test: seed %d stood in %d ms (flushed)" % [SEEDS[k],Time.get_ticks_msec()-began])
		await _layer(SEEDS[k])
	await _loop()
	print("PASS: run layer" if failures == 0 else "FAIL: run layer (%d)" % failures)
	quit(1 if failures > 0 else 0)

# --- The plans ------------------------------------------------------------------

func _plans() -> void:
	for s: int in SEEDS:
		var a: Dictionary = LayerPlan.make(s)
		var b: Dictionary = LayerPlan.make(s)
		check((a.problems as Array).is_empty(),"seed %d: laid (%s)" % [s,str(a.problems)])
		check(LayerPlan.describe(a) == LayerPlan.describe(b),"seed %d: the same plan twice" % s)
		var route: int = a.isles.filter(func(i: Dictionary) -> bool: return i.role == "route").size()
		check(route >= 2 and a.isles.filter(func(i: Dictionary) -> bool: return i.role == "greed").size() == 1,"seed %d: the base, %d route isles and a greed isle" % [s,route])
		check(a.edges.any(func(e: Dictionary) -> bool: return not (e.trap as Dictionary).is_empty() and e.branch == "route"),"seed %d: a trap on the route" % s)
		check(not (a.prize as Dictionary).is_empty() and (a.prize.runes as Array).size() == LayerPlan.RUNES,"seed %d: a rune set on the greed isle" % s)
		_reach(s,a)

## Every edge within his reach, from his own numbers.
func _reach(s: int, plan: Dictionary) -> void:
	var p: Object = LayerPlan.pilot()
	for e: Dictionary in plan.edges:
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
		var hit := _corridor(space,e)
		check(hit == "","seed %d %s %s: its corridor is clear %s" % [s,e.branch,e.kind,hit])
	# Driven across.
	for e: Dictionary in plan.edges:
		var ok := _cross(e)
		check(ok,"seed %d %s %s (%s): crossed on foot, %s" % [s,e.branch,e.kind,", ".join(PackedStringArray(e.parts)),_feet()])
		if not (e.trap as Dictionary).is_empty():
			var trap: Node3D = study.stage.traps.traps[0]
			check(int(trap.fallen_count) > 0,"seed %d: the voussoirs fell behind him (%d)" % [s,int(trap.fallen_count)])
	_cannon(s,plan)

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

# --- The loop -------------------------------------------------------------------

func _loop() -> void:
	var was: int = study.layer_seed
	var exit: Dictionary = study.layer.exit
	study.place(exit.at,Vector2(1.0,0.0))
	tick(Vector2.ZERO)
	check(study.layer_seed == was+1 and study.last_end.begins_with("Through the gate"),"At the gate, the next layer (seed %d -> %d)" % [was,study.layer_seed])
	var spawn: Vector3 = study.layer.spawn.at
	check((m.feet as Vector3).distance_to(spawn) < 1.0,"He starts the new layer at its spawn on the base")
	was = study.layer_seed
	study.place(Vector3(m.feet.x,float(study.layer.void_y)+1.0,m.feet.z),Vector2(1.0,0.0))
	for i in range(30): tick(Vector2.ZERO)
	check(study.layer_seed == was+1 and study.last_end.begins_with("Into the void"),"Into the void, the next layer (seed %d -> %d)" % [was,study.layer_seed])
