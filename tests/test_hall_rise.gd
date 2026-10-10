extends SceneTree
## The hall rise study (studies/hall_rise.gd, scripts/hall_rise.gd,
## scripts/hall_rise_plan.gd, docs/design/hall-rise.md), headless: the hall
## splits into 3-6 whole chunks of bays that hold every one of its solids
## exactly once, in order (the apse first, or the gate with
## --rise-from=gate); each rises straight and steady with no spring, from
## under the cloud top, at its planned time; nothing collides while it
## moves; each ends exactly in its place, solid, the settled hall the
## in-world hall (its shapes where SkyMoments stands them); a chunk settling
## round the plane waits till the plane is clear (and only then); a slow
## build holds the schedule and the order holds; the plane flies the
## settled hall.
##   godot --headless --path . --script tests/test_hall_rise.gd
const Rise = preload("res://scripts/hall_rise.gd")
const RisePlan = preload("res://scripts/hall_rise_plan.gd")
const Plan = preload("res://scripts/sky_moments_plan.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(170.0).timeout.connect(func() -> void: push_error("hall rise test timed out"); quit(2))
	_plan()
	study = load("res://studies/hall_rise.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	var waited := 0
	while not study.rise.all_built() and waited < 600:
		await process_frame
		study.rise.advance(0.0)
		waited += 1
	check(study.rise.all_built(),"Every chunk made on the worker (%d, in %.3f s, first after %.3f s; heaviest hand-over %.2f ms)" % [study.rise.built,study.rise.build_seconds(),study.rise.first_ready(),study.rise.take_usec/1000.0])
	await _plays()
	await _settled()
	await _plane_waits()
	await _slow_build()
	await _flies()
	print("PASS: hall rise" if failures == 0 else "FAIL: hall rise (%d)" % failures)
	quit(1 if failures > 0 else 0)

## The chunks: 3-6, every hall solid in exactly one, whole runs of bays
## covering the hall, in order; each rise steady, never springing back up,
## ending exactly in its place.
func _plan() -> void:
	var made := RisePlan.make()
	var solids: Array = made.solids
	var chunks: Array = made.chunks
	check(solids.size() == Plan.local_solids(RisePlan.LAYOUT).size(),"The hall's own solids (%d)" % solids.size())
	check(chunks.size() >= 3 and chunks.size() <= 6,"%d chunks (3-6)" % chunks.size())
	var seen := {}
	var twice := 0
	for c: Dictionary in chunks:
		for k: int in c.solids:
			if seen.has(k): twice += 1
			seen[k] = true
	check(seen.size() == solids.size() and twice == 0,"Each hall solid in exactly one chunk (%d of %d, %d twice)" % [seen.size(),solids.size(),twice])
	var info := RisePlan.classify()
	var whole := true
	for c: Dictionary in chunks:
		for k: int in c.solids:
			var b := int(info[k].bay)
			if b < int(c.bays[0]) or b > int(c.bays[1]): whole = false
	var ids := []
	for c: Dictionary in chunks: ids.append(c.id)
	check(whole and ids == ["apse","screens","torn","gate"],"Whole runs of bays, the apse first, the gate last %s" % [ids])
	var gate_first := []
	for c: Dictionary in RisePlan.make({"from":"gate"}).chunks: gate_first.append(c.id)
	check(gate_first == ["gate","torn","screens","apse"],"--rise-from=gate: the gate first %s" % [gate_first])
	var gaps_ok := true
	var r := RisePlan.settings()
	for i in range(1,chunks.size()):
		if absf(float(chunks[i].start)-float(chunks[i-1].start)-float(r.gap)) > 1e-4: gaps_ok = false
	check(gaps_ok and absf(float(chunks[0].start)-float(r.lead)) < 1e-4,"One after another, %.1f s apart after %.1f s" % [r.gap,r.lead])
	var length := float(made.length)
	check(length >= 6.0 and length <= 14.0,"The rise takes %.1f s (6-14)" % length)
	# The motion: steady, never back down till it sinks in, never more than
	# `over` past its place, exactly its place at the end.
	var springy := 0
	var past := 0.0
	var steady := true
	var starts_under := true
	for c: Dictionary in chunks:
		var home := float(c.pivot.y)
		var stop := RisePlan.stops(c)-float(c.start)
		var last := -INF
		for k in range(int(stop/0.01)):
			var y := RisePlan.height_at(c,k*0.01)
			if y < last-1e-5: springy += 1
			last = y
		for k in range(int((RisePlan.settles(c)-float(c.start))/0.01)+1):
			past = maxf(past,RisePlan.height_at(c,k*0.01)-home)
		if RisePlan.height_at(c,RisePlan.settles(c)-float(c.start)+0.01) != home: springy += 1
		if RisePlan.height_at(c,0.0)+float(c.top) > float(made.sea)-float(r.under)+1e-4: starts_under = false
		# At the cloud top it moves at its steady speed.
		for k in range(int(stop/0.01)):
			if RisePlan.height_at(c,k*0.01)+float(c.top) > float(made.sea):
				if absf(RisePlan.speed_at(c,k*0.01)-float(r.speed)) > 0.01: steady = false
				break
	check(springy == 0,"Each rises without a bounce and ends exactly in its place")
	check(past <= float(r.over)+1e-4,"It stops %.2f m over its place at most (over %.2f)" % [past,r.over])
	check(steady,"Each breaks through at its steady %.0f m/s" % r.speed)
	check(starts_under,"Each starts with its top %.0f m under the cloud top" % r.under)
	var quick := RisePlan.make({"speed":18.0,"gap":0.5})
	check(float(quick.length) < length-3.0,"Quicker and closer is shorter (%.1f s)" % quick.length)
	# The additions: keels go with their bays' chunks, stones are a last
	# chunk, clear of the line and every moment.
	var added := RisePlan.make({"keels":true,"stones":true})
	var keels := 0
	for c: Dictionary in added.chunks:
		for q: Dictionary in c.extra:
			if q.get("keel",false): keels += 1
	check(added.chunks.size() == chunks.size()+1 and added.chunks[-1].id == "stones" and keels == 15,"--keels --stones: a keel in each bay's chunk (%d), the stones last" % keels)
	var near := 0
	for q: Dictionary in added.chunks[-1].extra:
		for p: Vector3 in RisePlan.keep_points():
			if p.distance_to(q.middle) < (q.size as Vector3).length()*0.5+3.0: near += 1
	check(near == 0,"The floating stones keep 3 m off the line, its way in and out and the moments")

## Played: every chunk hidden under the cloud till it begins, beginning in
## order at its planned time, under the cloud top, colliding with nothing
## while it moves, breaking through with cloud; settled on time.
func _plays() -> void:
	var e: Node3D = study.rise
	e.play()
	var n: int = e.chunks.size()
	var began := PackedFloat32Array()
	began.resize(n)
	began.fill(-1.0)
	var order: Array = []
	var solid_moving := 0
	var shown_early := 0
	var under := 0
	var most_puffs := 0
	var most_swells := 0
	var steps := int((float(e.plan.length)+1.0)/DT)
	for s in range(steps):
		study.tick(DT)
		for i in range(n):
			var node: Node3D = e.nodes[i]
			if e.state[i] == "waiting":
				if node.visible: shown_early += 1
				continue
			if began[i] < 0.0:
				began[i] = e.clock
				order.append(i)
				if node.position.y+float(e.chunks[i].top) < float(e.sea_y): under += 1
			if e.state[i] == "moving" and (node.get_node(^"Body") as StaticBody3D).collision_layer != 0: solid_moving += 1
		most_puffs = maxi(most_puffs,e.puff_count())
		most_swells = maxi(most_swells,e.swells().size())
	var in_order: bool = order.size() == n
	for k in range(order.size()):
		if order[k] != k: in_order = false
	var worst := 0.0
	for i in range(n): worst = maxf(worst,absf(began[i]-float(e.chunks[i].start)))
	check(in_order,"Every chunk began, in the planned order (%d of %d)" % [order.size(),n])
	check(worst <= DT+1e-4,"Each at its planned time (worst %.3f s off)" % worst)
	check(shown_early == 0,"None shows before it begins")
	check(under == n,"Each begins under the cloud top (%d of %d)" % [under,n])
	check(solid_moving == 0,"Nothing collides while it moves")
	var broke := 0
	for b in e.broke: broke += b
	check(broke == n,"Every chunk broke through the cloud top (%d)" % broke)
	check(most_puffs > 60 and most_swells > 0,"Cloud up (most %d puffs, %d swells)" % [most_puffs,most_swells])
	check(float(e.done_at) > 0.0 and absf(float(e.done_at)-float(e.plan.length)) < 0.05,"Settled at %.2f s (planned %.2f)" % [e.done_at,e.plan.length])

## Settled: in place exactly, solid, the in-world hall's shapes.
func _settled() -> void:
	var e: Node3D = study.rise
	var off := 0
	var layer := 0
	var shapes_off := 0
	var worst := 0.0
	var solids: Array = e.plan.solids
	for i in range(e.chunks.size()):
		var c: Dictionary = e.chunks[i]
		var node: Node3D = e.nodes[i]
		if node.transform != Transform3D(Basis.IDENTITY,c.pivot): off += 1
		var body := node.get_node(^"Body") as StaticBody3D
		if body.collision_layer != RuinBump.LAYER or e.state[i] != "set": layer += 1
		for k in range(c.solids.size()):
			var q: Dictionary = solids[c.solids[k]]
			var shape := body.get_child(k) as CollisionShape3D
			var want := e.global_transform*Transform3D(q.basis if q.kind == "box" else Basis.IDENTITY,q.middle)
			var d := shape.global_transform.origin.distance_to(want.origin)+(shape.global_basis.x-want.basis.x).length()+(shape.global_basis.z-want.basis.z).length()
			worst = maxf(worst,d)
			if d > 1e-3: shapes_off += 1
	check(off == 0,"Every chunk exactly in its place")
	check(layer == 0,"Every chunk solid on the ruins' layer")
	check(shapes_off == 0,"Every hall shape where the in-world hall has it (worst %.5f m)" % worst)
	await physics_frame
	await physics_frame
	var space := study.get_world_3d().direct_space_state
	var bay: Vector3 = RisePlan.bay_at(3)
	var down := PhysicsRayQueryParameters3D.create(e.to_global(bay+Vector3(0.0,30.0,-4.0)),e.to_global(bay+Vector3(0.0,-30.0,-4.0)),RuinBump.LAYER)
	var hit := space.intersect_ray(down)
	check(not hit.is_empty(),"A ray down the nave hits the roof or floor")
	var clear := 0
	var ball := SphereShape3D.new()
	ball.radius = 0.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.collision_mask = RuinBump.LAYER
	for at: Vector3 in Plan.line(RisePlan.LAYOUT):
		query.transform = Transform3D(Basis.IDENTITY,e.to_global(at))
		if not space.intersect_shape(query,4).is_empty(): clear += 1
	check(clear == 0,"The line has its room (0.9 m) all the way")

## A chunk settling with the plane in its stone waits till the plane is
## clear; with the plane only in its nave (inside its box, touching no
## solid) it goes solid at once.
func _plane_waits() -> void:
	var e: Node3D = study.rise
	var first: Dictionary = e.chunks[0]
	var stone: AABB = first.boxes[0]
	var box := {"at":AABB(stone.get_center()-Vector3.ONE,Vector3.ONE*2.0)}
	e.plane_box = func() -> AABB: return box.at
	e.play()
	var t := 0.0
	while t < RisePlan.settles(first)+0.3:
		e.advance(DT)
		t += DT
	var body := e.nodes[0].get_node(^"Body") as StaticBody3D
	check(e.state[0] == "pending" and body.collision_layer == 0,"Settled round the plane, it waits, not solid (%s)" % e.state[0])
	box.at = AABB(stone.get_center()+Vector3(0.0,60.0,0.0),Vector3.ONE*2.0)
	e.advance(DT)
	check(e.state[0] == "set" and body.collision_layer == RuinBump.LAYER,"The plane clear, it is solid")
	# In the nave: the line's point inside the first chunk's box.
	var inside := Vector3.INF
	var mine := AABB(first.lo,(first.hi as Vector3)-(first.lo as Vector3))
	for p: Vector3 in Plan.line(RisePlan.LAYOUT):
		if mine.has_point(p):
			inside = p
			break
	var half := Vector3.ONE*0.5
	box.at = AABB(inside-half,half*2.0)
	e.play()
	t = 0.0
	while t < RisePlan.settles(first)+0.1:
		e.advance(DT)
		t += DT
	check(inside != Vector3.INF and e.state[0] == "set","The plane in its nave but clear of its stone: solid at once (%s)" % e.state[0])
	e.plane_box = study._plane_box
	e.finish_now()

## A slow build (1.5 s before the first chunk, 1 s over them): the schedule
## holds for a chunk not made yet, the order holds, and it all settles.
func _slow_build() -> void:
	var e: Node3D = study.rise
	e.setup({"upfront":1.5,"cost":1.0})
	e.play()
	var began_unbuilt := 0
	var order: Array = []
	var seen := {}
	var frames := 0
	while float(e.done_at) < 0.0 and frames < 3000:
		e.advance(DT)
		frames += 1
		for i in range(e.chunks.size()):
			if e.state[i] != "waiting" and not seen.has(i):
				seen[i] = true
				order.append(i)
				if e.nodes[i] == null: began_unbuilt += 1
		if not e.all_built(): OS.delay_msec(16)
	var in_order: bool = order.size() == e.chunks.size()
	for k in range(order.size()):
		if order[k] != k: in_order = false
	check(float(e.stall) > 0.0,"The schedule held %.2f s for the build (built in %.2f s)" % [e.stall,e.build_seconds()])
	check(in_order and began_unbuilt == 0,"Still in order, none begun before it was made")
	check(float(e.done_at) > 0.0,"It settles (at %.2f s)" % e.done_at)

## The plane flies at the hall from its way in while it rises, and on
## through the settled hall: it keeps flying (bumped, never stuck), never
## inside stone.
func _flies() -> void:
	var e: Node3D = study.rise
	e.play()
	study.board()
	var from: Vector3 = study.plane.position
	var stuck := 0
	var shut := 0
	var last: Vector3 = from
	await physics_frame
	for i in range(int(30.0/DT)):
		study.tick(DT)
		if i % 4 == 0:
			await physics_frame
			if study._inside_stone(study.plane.position): shut += 1
		if i % 60 == 59:
			if study.plane.position.distance_to(last) < 3.0: stuck += 1
			last = study.plane.position
	check(float(e.done_at) > 0.0 and e._all_set(),"Risen and all solid while the plane flew in (%.2f s)" % e.done_at)
	check(stuck == 0 and float(study.plane.speed) >= 6.9,"The plane flies on through 30 s (bumps %d, %.0f m covered)" % [study.bumps,from.distance_to(study.plane.position)])
	check(shut == 0,"The plane is never inside stone")
	study.leave()
