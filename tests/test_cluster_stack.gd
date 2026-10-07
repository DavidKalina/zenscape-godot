extends SceneTree
## The hermit's stack (scripts/cluster_stack.gd, the "stack" motif of
## scripts/cluster_motifs.gd): over SEEDS seeds, every plan passes the
## validator; the members stand one over another, each risen so its hanging
## rock keeps HEADROOM over the land under it, the column tall; each is
## joined to the one under it by a stair whose foot and head sit on the
## land; the pilot (scripts/pilot_motor.gd) walks every stair up and back
## down without falling, reading the ground as the perch does (its own
## islet first, then the group's); the hut stands on the top with its
## window, and the lanterns climb the stairs. Stood in the sky (scripts/
## sky_clusters.gd), the islets read the right member where two stand one
## over the other, and at night the window and the stair's lanterns light.
const Solver = preload("res://scripts/cluster_solver.gd")
const Stack = preload("res://scripts/cluster_stack.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyClusters = preload("res://scripts/sky_clusters.gd")
const Dresser = preload("res://scripts/cluster_dresser.gd")
const SEEDS := 12
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _run() -> void:
	var bad: Array = []
	var short := 0
	var unjoined := 0
	var low := 0
	var keel := 0
	var no_hut := 0
	var dim := 0
	var falls: Array = []
	var walks := 0
	var tallest := 0.0
	for s in range(SEEDS):
		var seed_value := 300+s*65537
		var plan := Solver.solve("stack",seed_value)
		var problems := Solver.validate(plan)
		if not problems.is_empty(): bad.append("seed %d: %s" % [seed_value,problems[0]])
		var members: Array = plan.members
		if members.size() < 4: short += 1
		var by := {}
		for m: Dictionary in members: by[m.name] = m
		var stairs: Array = plan.get("stairs",[])
		var joined := {}
		for st: Dictionary in stairs: joined[st.to] = st
		for m: Dictionary in members:
			if m.name != "foot" and not joined.has(m.name): unjoined += 1
		# Stacked: each over the one under it, its keel clear of the land.
		for st: Dictionary in stairs:
			var a: Dictionary = by[st.from]
			var b: Dictionary = by[st.to]
			if float(b.offset.y) <= float(a.offset.y)+Stack.RISE.x-0.01: low += 1
		for i in range(members.size()):
			for j in range(i+1,members.size()):
				var gap := Stack.vertical_gap(members[i].shape,members[i].offset,members[j].shape,members[j].offset,0.5)
				if gap < Stack.HEADROOM*0.95: keel += 1
		var top: Dictionary = members[0]
		for m: Dictionary in members:
			if float(m.offset.y) > float(top.offset.y): top = m
		tallest = maxf(tallest,float(top.offset.y))
		if not (top.features as Array).any(func(f: Dictionary) -> bool: return f.type == "cabin"): no_hut += 1
		var lanterns := 0
		for st: Dictionary in stairs: lanterns += (st.lanterns as Array).size()
		if lanterns < 3*stairs.size(): dim += 1
		for st: Dictionary in stairs:
			for down: bool in [false,true]:
				walks += 1
				var fell := _walk(plan,st,down)
				if fell != "": falls.append("seed %d %s-%s %s: %s" % [seed_value,st.from,st.to,"down" if down else "up",fell])
	check(bad.is_empty(),"%d stacks pass the validator%s" % [SEEDS,"" if bad.is_empty() else " (%d fail, e.g. %s)" % [bad.size(),bad[0]]])
	check(short == 0,"Every stack has a foot, two ledges or more and a top")
	check(unjoined == 0,"Every member above the foot has a stair up to it")
	check(low == 0 and keel == 0,"Each member stands over the one under it, its rock %.1f m clear of the land under it" % Stack.HEADROOM)
	check(tallest > 25.0,"The column stands tall (up to %.0f m)" % tallest)
	check(no_hut == 0,"The hut stands on the top")
	check(dim == 0,"Lanterns climb every stair")
	check(falls.is_empty(),"The pilot walks every stair up and down (%d walks)%s" % [walks,"" if falls.is_empty() else ": "+"; ".join(falls)])
	await _stood()
	print("PASS: cluster stack" if failures == 0 else "FAIL: cluster stack")
	quit(1 if failures else 0)

## Walks the pilot along a stair, from its foot to its head and on onto the
## upper land (or back down), reading the ground as the perch does: its own
## islet first, then the first of the group whose land or deck holds the
## point. "" when it arrives without falling, else what went wrong.
func _walk(plan: Dictionary, st: Dictionary, down: bool) -> String:
	var members: Array = plan.members
	var by := {}
	for m: Dictionary in members: by[m.name] = m
	var from: Dictionary = by[st.from]
	var to: Dictionary = by[st.to]
	var path: Array = []
	for p: Vector3 in st.points: path.append(p+(from.offset as Vector3))
	# On past the head onto the upper land (or back from the foot).
	var head: Vector3 = path.back()
	var into := Vector2(head.x-to.offset.x,head.z-to.offset.z).normalized()*-1.2
	path.append(head+Vector3(into.x,0.0,into.y))
	if down: path.reverse()
	# Held in a box: a lambda keeps the box it was made with.
	var held := {"perch":to if down else from,"feet":0.0}
	var ground := func(p: Vector2) -> float:
		var perch: Dictionary = held.perch
		var own := Vector2(p.x-perch.offset.x,p.y-perch.offset.z)
		if perch.shape.inside(own): return float(perch.offset.y)+float(perch.shape.ground_at(own))
		var next := _neighbour(members,perch,p,float(held.feet))
		return float(next.ground) if not next.is_empty() else -INF
	var motor := PilotMotor.new()
	var start: Vector3 = path[0]
	start.y = ground.call(Vector2(start.x,start.z))
	motor.reset(start,0.0)
	held.feet = start.y
	var slide := func(feet: Vector3, step: Vector2) -> Vector3: return Vector3(feet.x+step.x,feet.y,feet.z+step.y)
	var next := 1
	for frame in range(60*60):
		if next >= path.size(): break
		var aim: Vector3 = path[next]
		var way := Vector2(aim.x-motor.feet.x,aim.z-motor.feet.z)
		if way.length() < 0.25:
			next += 1
			continue
		held.feet = motor.feet.y
		motor.step(1.0/60.0,way.normalized(),PilotMotor.WALK,false,ground,slide)
		var at := Vector2(motor.feet.x,motor.feet.z)
		if motor.grounded:
			var perch: Dictionary = held.perch
			if not perch.shape.inside(Vector2(at.x-perch.offset.x,at.y-perch.offset.z)):
				var onto := _neighbour(members,perch,at,motor.feet.y)
				if not onto.is_empty(): held.perch = onto.member
		if not motor.grounded: return "fell at %s" % str(motor.feet.snapped(Vector3.ONE*0.1))
		if motor.velocity.length() < 0.05 and frame > 30: return "stopped at %s" % str(motor.feet.snapped(Vector3.ONE*0.1))
	if next < path.size(): return "never got there"
	var end: Dictionary = from if down else to
	if held.perch.name != end.name: return "ended on %s" % held.perch.name
	return ""

## The group's member other than `perch` whose land or deck holds `p`, as
## the perch reads it (WandererEye `_perch_neighbour`): the highest whose
## ground is within a step over the feet, else the lowest; {member, ground}.
func _neighbour(members: Array, perch: Dictionary, p: Vector2, feet: float) -> Dictionary:
	var best := {}
	var reach := feet+PilotMotor.STEP_UP
	for m: Dictionary in members:
		if m == perch: continue
		var q := Vector2(p.x-m.offset.x,p.y-m.offset.z)
		if not m.shape.inside(q): continue
		var hit := {"member":m,"ground":float(m.offset.y)+float(m.shape.ground_at(q))}
		if best.is_empty() or (float(hit.ground) <= reach and (float(best.ground) > reach or float(hit.ground) > float(best.ground))) \
				or (float(hit.ground) > reach and float(best.ground) > reach and float(hit.ground) < float(best.ground)):
			best = hit
	return best

## A stack stood in the sky: the islets read the right member over another,
## and at night its window and its lanterns light.
func _stood() -> void:
	var cells := SkyCells.new([Vector3.ZERO,Vector3(380.0,-20.0,-160.0)])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var field: Node3D = SkyClusters.new()
	field.islets = islets
	field.with_showcase = false
	field.with_random = true
	root.add_child(field)
	field.reset(cells)
	var spot: Dictionary = field.spots[0]
	spot.motif = "stack"
	spot.seed = 4711
	field.plan_now(spot.key)
	var stood: Dictionary = field.members_of(spot.key)
	var plan: Dictionary = field.clusters[spot.key].plan
	check(stood.size() == (plan.members as Array).size() and stood.size() >= 4,"The stack stands whole (%d members)" % stood.size())
	# A point of a lower member's land under an upper member's rock (not
	# where a stair's head lies on it).
	var heads: Array[Vector3] = []
	for st: Dictionary in plan.stairs: heads.append(stood[st.from].home+((st.points as Array).back() as Vector3))
	var picked := 0
	var tried := 0
	for low: Dictionary in stood.values():
		for high: Dictionary in stood.values():
			if islets.place(high).y <= islets.place(low).y: continue
			var shape: RefCounted = low.shape
			for i in range(0,shape.points.size(),3):
				var p: Vector2 = shape.points[i]
				if shape.shore_distance[i] < 0.5 or shape.deck_y(p) > -INF: continue
				var g: Vector3 = islets.place(low)+Vector3(p.x,Stack.land_y(shape,p),p.y)
				if heads.any(func(h: Vector3) -> bool: return Vector2(h.x-(g.x-islets.position.x),h.z-(g.z-islets.position.z)).length() < 2.5): continue
				var q: Vector3 = g-islets.place(high)
				if not high.shape.inside(Vector2(q.x,q.z)): continue
				tried += 1
				# Over the upper land, the upper islet (or a stair's head lying
				# on it, the same ground).
				var over: Vector3 = islets.place(high)+Vector3(q.x,float(high.shape.ground_at(Vector2(q.x,q.z)))+0.3,q.z)
				var read: Dictionary = islets.islet_at(over)
				var seen := -INF
				if not read.is_empty():
					var local: Vector3 = over-islets.place(read)
					seen = islets.place(read).y+float(read.shape.ground_at(Vector2(local.x,local.z)))
				if islets.islet_at(g+Vector3.UP*0.3) == low and absf(seen-(over.y-0.3)) < 0.15: picked += 1
	check(tried > 0 and picked == tried,"Where one stands over another, the islets read the one under the point (%d of %d)" % [picked,tried])
	field.daylight_override = 0.0
	for i in range(160):
		field.advance(1.0/30.0,spot.at+cells.origin)
		await process_frame
	var stairs := 0
	var posts := 0
	var windows := 0
	for b: Dictionary in stood.values():
		for child: Node in (b.node as Node3D).get_children():
			# Same-named nodes are renamed; the posts are known by their mesh.
			if child.name.contains("Stair"): stairs += 1
			elif child is MeshInstance3D and (child as MeshInstance3D).mesh == Dresser._mats().post: posts += 1
			elif child.name.contains("CabinWindow"): windows += 1
	var lanterns := 0
	for st: Dictionary in plan.stairs: lanterns += (st.lanterns as Array).size()
	check(stairs == (plan.stairs as Array).size() and stairs >= 3,"Its stairs stand (%d)" % stairs)
	check(windows == 1,"One window, at the top")
	check(posts >= lanterns and lanterns >= 6,"The lanterns climb the stairs (%d, %d posts)" % [lanterns,posts])
	var lit := 0
	for entry: Array in field.clusters[spot.key].live.lights:
		if (entry[0] as OmniLight3D).visible: lit += 1
	check(field.night > 0.9 and lit >= lanterns,"At night they are lit (%d lights)" % lit)
	field.queue_free()
	islets.queue_free()
	await process_frame
