extends SceneTree
## The hall eruption study (studies/hall_eruption.gd, scripts/
## hall_eruption.gd, docs/design/hall-eruption.md), headless: the hall
## breaks into pieces that hold every one of its solids exactly once, base
## first; they rise in their planned order at their planned times, collide
## with nothing while they move, and end exactly in their places, solid,
## the settled hall the in-world hall (its shapes where SkyMoments stands
## them); the additions keep clear of the line and the moments; a piece
## settling round the plane waits till the plane is out; a slow build holds
## the schedule and the order holds; the plane flies the settled hall.
##   godot --headless --path . --script tests/test_hall_eruption.gd
const Eruption = preload("res://scripts/hall_eruption.gd")
const EPlan = preload("res://scripts/hall_eruption_plan.gd")
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
	create_timer(170.0).timeout.connect(func() -> void: push_error("hall eruption test timed out"); quit(2))
	_plan()
	study = load("res://studies/hall_eruption.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	var waited := 0
	while not study.eruption.all_built() and waited < 600:
		await process_frame
		study.eruption.advance(0.0)
		waited += 1
	check(study.eruption.all_built(),"Every piece made on the worker (%d, in %.3f s, first after %.3f s; heaviest hand-over %.2f ms)" % [study.eruption.built,study.eruption.build_seconds(),study.eruption.first_ready(),study.eruption.take_usec/1000.0])
	await _plays()
	await _settled()
	await _plane_waits()
	await _slow_build()
	await _flies()
	print("PASS: hall eruption" if failures == 0 else "FAIL: hall eruption (%d)" % failures)
	quit(1 if failures > 0 else 0)

## The pieces: every hall solid in exactly one, base first and biggest,
## the categories in order, the starts in order, 8-16 s in all.
func _plan() -> void:
	var made := EPlan.make()
	var solids: Array = made.solids
	var pieces: Array = made.pieces
	check(solids.size() == Plan.local_solids(EPlan.LAYOUT).size(),"The hall's own solids (%d)" % solids.size())
	var seen := {}
	var twice := 0
	for p: Dictionary in pieces:
		for k: int in p.solids:
			if seen.has(k): twice += 1
			seen[k] = true
	check(seen.size() == solids.size() and twice == 0,"Each hall solid in exactly one piece (%d of %d, %d twice)" % [seen.size(),solids.size(),twice])
	var counts := {}
	for p: Dictionary in pieces: counts[p.category] = int(counts.get(p.category,0))+1
	check(pieces.size() >= 40 and counts.size() == EPlan.CATEGORIES.size(),"%d pieces in every category %s" % [pieces.size(),counts])
	var ordered := true
	var timed := true
	for i in range(1,pieces.size()):
		if EPlan.CATEGORIES.find(pieces[i].category) < EPlan.CATEGORIES.find(pieces[i-1].category): ordered = false
		if float(pieces[i].start) < float(pieces[i-1].start)-1e-5: timed = false
	check(ordered and pieces[0].category == "base" and pieces[-1].category == "stones","Base first, the floating stones last, categories in order")
	check(timed,"The starts come one after another")
	var base_small := INF
	var rest_big := 0.0
	for p: Dictionary in pieces:
		var v := _volume(p,solids)
		if p.category == "base": base_small = minf(base_small,v)
		else: rest_big = maxf(rest_big,v)
	check(base_small > rest_big,"Each base is bigger than any other piece (%.0f against %.0f m3)" % [base_small,rest_big])
	var late := 0
	var by_id := {}
	for p: Dictionary in pieces: by_id[p.id] = p
	for p: Dictionary in pieces:
		for id: String in p.supports:
			if EPlan.arrives(p) < EPlan.arrives(by_id[id])-1e-4: late += 1
	check(late == 0,"No piece lands before what it stands on")
	var length := float(made.length)
	check(length >= 8.0 and length <= 16.0,"The eruption takes %.1f s (8-16)" % length)
	# Straight: the same pieces, none sliding in.
	var straight := EPlan.make({"path":"straight"})
	var slides := 0
	for p: Dictionary in straight.pieces:
		if float(p.out) > 0.0 or float(p.slot) > 0.0: slides += 1
	check(slides == 0 and straight.pieces.size() == pieces.size(),"--erupt-path=straight: every piece straight up")
	var bare := EPlan.make({"keels":false,"stones":false})
	check(bare.pieces.size() == pieces.size()-int(counts.stones),"--no-keels --no-stones: the hall alone")

func _volume(p: Dictionary, solids: Array) -> float:
	var v := 0.0
	for k: int in p.solids:
		var q: Dictionary = solids[k]
		v += (q.size as Vector3).x*(q.size as Vector3).y*(q.size as Vector3).z if q.kind == "box" else PI*float(q.radius)*float(q.radius)*float(q.height)
	return v

## Played: every piece hidden under the cloud till it begins, beginning in
## order at its planned time, colliding with nothing while it moves,
## breaking through the cloud with a burst; the cloud and dust up.
func _plays() -> void:
	var e: Node3D = study.eruption
	e.play()
	var n: int = e.pieces.size()
	var began := PackedFloat32Array()
	began.resize(n)
	began.fill(-1.0)
	var order: Array = []
	var solid_moving := 0
	var shown_early := 0
	var below := 0
	var most_puffs := 0
	var most_dust := 0
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
				if node.position.y < float(e.pieces[i].pivot.y)-20.0: below += 1
			if e.state[i] == "moving" and (node.get_node(^"Body") as StaticBody3D).collision_layer != 0: solid_moving += 1
		most_puffs = maxi(most_puffs,e.puff_count())
		most_dust = maxi(most_dust,e.dust_count())
	var in_order: bool = order.size() == n
	for k in range(order.size()):
		if order[k] != k: in_order = false
	var worst := 0.0
	for i in range(n): worst = maxf(worst,absf(began[i]-float(e.pieces[i].start)))
	check(in_order,"Every piece began, in the planned order (%d of %d)" % [order.size(),n])
	check(worst <= DT+1e-4,"Each at its planned time (worst %.3f s off)" % worst)
	check(shown_early == 0,"None shows before it begins")
	check(below == n,"Each begins well under its place (%d of %d)" % [below,n])
	check(solid_moving == 0,"Nothing collides while it moves")
	var broke := 0
	for b in e.broke: broke += b
	check(broke == n,"Every piece broke through the cloud top (%d)" % broke)
	check(most_puffs > 100 and most_dust > 20,"Cloud and dust up (most %d puffs, %d dust stones)" % [most_puffs,most_dust])
	check(float(e.done_at) > 0.0 and absf(float(e.done_at)-float(e.plan.length)) < 0.05,"Settled at %.2f s (planned %.2f)" % [e.done_at,e.plan.length])

## Settled: in place exactly, solid, the in-world hall's shapes; the
## additions clear of the line and the moments.
func _settled() -> void:
	var e: Node3D = study.eruption
	var off := 0
	var layer := 0
	var shapes_off := 0
	var worst := 0.0
	var solids: Array = e.plan.solids
	for i in range(e.pieces.size()):
		var p: Dictionary = e.pieces[i]
		var node: Node3D = e.nodes[i]
		if node.transform != Transform3D(Basis.IDENTITY,p.pivot): off += 1
		var body := node.get_node(^"Body") as StaticBody3D
		if body.collision_layer != RuinBump.LAYER or e.state[i] != "set": layer += 1
		for k in range(p.solids.size()):
			var q: Dictionary = solids[p.solids[k]]
			var shape := body.get_child(k) as CollisionShape3D
			var want := e.global_transform*Transform3D(q.basis if q.kind == "box" else Basis.IDENTITY,q.middle)
			var d := shape.global_transform.origin.distance_to(want.origin)+(shape.global_basis.x-want.basis.x).length()+(shape.global_basis.z-want.basis.z).length()
			worst = maxf(worst,d)
			if d > 1e-3: shapes_off += 1
	check(off == 0,"Every piece exactly in its place")
	check(layer == 0,"Every piece solid on the ruins' layer")
	check(shapes_off == 0,"Every hall shape where the in-world hall has it (worst %.5f m)" % worst)
	await physics_frame
	await physics_frame
	var space := study.get_world_3d().direct_space_state
	# The floor under bay 3, a column, a wall.
	var bay: Vector3 = EPlan._bay_at(3)
	var down := PhysicsRayQueryParameters3D.create(e.to_global(bay+Vector3(0.0,30.0,0.0)+Vector3(0.0,0.0,-4.0)),e.to_global(bay+Vector3(0.0,-30.0,-4.0)),RuinBump.LAYER)
	var hit := space.intersect_ray(down)
	check(not hit.is_empty(),"A ray down the nave hits the roof or floor (at %.2f)" % (hit.position.y if not hit.is_empty() else NAN))
	var clear := 0
	var keep := 0
	var ball := SphereShape3D.new()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.collision_mask = RuinBump.LAYER
	for at: Vector3 in Plan.line(EPlan.LAYOUT):
		ball.radius = 0.9
		query.transform = Transform3D(Basis.IDENTITY,e.to_global(at))
		if not space.intersect_shape(query,4).is_empty(): clear += 1
	check(clear == 0,"The line has its room (0.9 m) all the way")
	for at: Vector3 in EPlan.keep_points():
		ball.radius = 3.0
		query.transform = Transform3D(Basis.IDENTITY,e.to_global(at))
		for r: Dictionary in space.intersect_shape(query,16):
			var body := r.collider as Node
			var i := _piece_of(body)
			if i < 0: continue
			var p: Dictionary = e.pieces[i]
			if p.category == "stones" or int(r.shape) >= p.solids.size(): keep += 1
	check(keep == 0,"The keels and stones keep 3 m off the line, its way in and out and the moments")

func _piece_of(body: Node) -> int:
	var e: Node3D = study.eruption
	for i in range(e.nodes.size()):
		if e.nodes[i] == body.get_parent(): return i
	return -1

## A piece settling where the plane is waits till the plane is out.
func _plane_waits() -> void:
	var e: Node3D = study.eruption
	var target := -1
	for i in range(e.pieces.size()):
		if e.pieces[i].category == "piers":
			target = i
			break
	var p: Dictionary = e.pieces[target]
	var box := {"at":AABB(p.pivot-Vector3.ONE,Vector3.ONE*2.0)}
	e.plane_box = func() -> AABB: return box.at
	e.play()
	var t := 0.0
	while t < EPlan.settles(p)+0.3:
		e.advance(DT)
		t += DT
	check(e.state[target] == "pending" and (e.nodes[target].get_node(^"Body") as StaticBody3D).collision_layer == 0,"Settled round the plane, it waits, not solid (%s)" % e.state[target])
	box.at = AABB(p.pivot+Vector3(0.0,40.0,0.0),Vector3.ONE*2.0)
	e.advance(DT)
	check(e.state[target] == "set" and (e.nodes[target].get_node(^"Body") as StaticBody3D).collision_layer == RuinBump.LAYER,"The plane out, it is solid")
	e.plane_box = study._plane_box
	e.finish_now()

## A slow build (1.5 s before the first piece, 1 s over them): the cloud
## churns from the start, the schedule holds for a piece not made yet, the
## order holds, and it all settles.
func _slow_build() -> void:
	var e: Node3D = study.eruption
	e.setup({"upfront":1.5,"cost":1.0})
	e.play()
	var began_unbuilt := 0
	var order: Array = []
	var seen := {}
	var puffs_waiting := 0
	var frames := 0
	while float(e.done_at) < 0.0 and frames < 3000:
		e.advance(DT)
		frames += 1
		if e.built == 0 and e.puff_count() > 0: puffs_waiting = e.puff_count()
		for i in range(e.pieces.size()):
			if e.state[i] != "waiting" and not seen.has(i):
				seen[i] = true
				order.append(i)
				if e.nodes[i] == null: began_unbuilt += 1
		if not e.all_built(): OS.delay_msec(16)
	var in_order: bool = order.size() == e.pieces.size()
	for k in range(order.size()):
		if order[k] != k: in_order = false
	check(puffs_waiting > 0,"The cloud churns before the first piece is made (%d puffs)" % puffs_waiting)
	check(float(e.stall) > 0.0,"The schedule held %.2f s for the build (built in %.2f s)" % [e.stall,e.build_seconds()])
	check(in_order and began_unbuilt == 0,"Still in order, none begun before it was made")
	check(float(e.done_at) > 0.0,"It settles (at %.2f s)" % e.done_at)

## The plane flies at the settled hall from its way in: it keeps flying
## (bumped, never stuck).
func _flies() -> void:
	study.board()
	var from: Vector3 = study.plane.position
	var stuck := 0
	var last: Vector3 = from
	for i in range(int(25.0/DT)):
		study.tick(DT)
		if i % 60 == 59:
			if study.plane.position.distance_to(last) < 3.0: stuck += 1
			last = study.plane.position
	check(stuck == 0 and float(study.plane.speed) >= 6.9,"The plane flies on through 25 s (bumps %d, %.0f m covered)" % [study.bumps,from.distance_to(study.plane.position)])
	study.leave()
