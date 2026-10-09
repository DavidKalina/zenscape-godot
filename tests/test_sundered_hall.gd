extends SceneTree
## suite: slow
## The Sundered hall (scripts/sundered_hall.gd, scripts/sundered_build.gd):
## its plan is well formed for many seeds (the line's length in range, the
## gaps short and gentle enough to carry the line at cruise, a way out at
## least every EXIT_EVERY m of the hall, the islands clear of one another,
## the acts in order); it stands near the home with --motif=sundered (laid
## clear of the islands, the other clusters and the seeded islets), its
## islands bedded under the hall and turned along it; its far detail and
## each piece's near detail within budget; the near detail streams in and
## out by distance; and the game's plane on an autopilot flies the whole
## line headless through the near detail's stone, bumping and recovering,
## in a minute or more at cruise.
const Sundered = preload("res://scripts/sundered_hall.gd")
const SunderedBuild = preload("res://scripts/sundered_build.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyClusters = preload("res://scripts/sky_clusters.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const Solver = preload("res://scripts/cluster_solver.gd")

## Seeds whose layouts are checked; a way out at least every EXIT_EVERY m
## of line (3 s at cruise); budgets: the whole far detail, a piece's near
## detail and its per-bay share; the traversal at cruise (s).
const SEEDS := 60
const EXIT_EVERY := 42.0
const FAR_BUDGET := 30000
const NEAR_BUDGET := 85000
const NEAR_BAY := 8000
const TRAVERSE := Vector2(58.0,100.0)
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _run() -> void:
	_layouts()
	await _standing()
	print("PASS: sundered hall" if failures == 0 else "FAIL: sundered hall")
	quit(1 if failures else 0)

func _layouts() -> void:
	var bad: Array = []
	var lengths := Vector2(INF,-INF)
	var widest_shut := 0.0
	var steepest := 0.0
	var gaps := Vector2(INF,-INF)
	var acts_ok := true
	for seed_value in range(SEEDS):
		var plan := Sundered.layout(seed_value,seed_value*0.37)
		var problems := Sundered.validate(plan)
		if not problems.is_empty(): bad.append("%d: %s" % [seed_value,problems[0]])
		lengths.x = minf(lengths.x,plan.hall_length)
		lengths.y = maxf(lengths.y,plan.hall_length)
		for gap: Dictionary in plan.gaps:
			gaps.x = minf(gaps.x,gap.span)
			gaps.y = maxf(gaps.y,gap.span)
			var ends := Sundered.gap_line(plan,gap)
			steepest = maxf(steepest,absf((ends[1] as Vector3).y-(ends[0] as Vector3).y)/float(gap.span))
		# Ways out along the hall: from the gate's mouth to the apse.
		var last := LEAD_S(plan)
		for e: Dictionary in Sundered.exits(plan):
			widest_shut = maxf(widest_shut,float(e.s)-last)
			last = float(e.s)
		var order: Array = (plan.pieces as Array).map(func(p: Dictionary) -> String: return p.act)
		if order[0] != "gate" or order[order.size()-1] != "apse" or not "cloister" in order or not "slit" in order: acts_ok = false
		var kinds: Array = (plan.gaps as Array).map(func(g: Dictionary) -> String: return g.kind)
		if not "drop" in kinds or not "aqueduct" in kinds: acts_ok = false
	check(bad.is_empty(),"%d layouts well formed%s" % [SEEDS,"" if bad.is_empty() else " (%s)" % str(bad.slice(0,3))])
	check(lengths.x >= Sundered.LENGTH.x-130.0 and lengths.y <= Sundered.LENGTH.y,"The hall runs %.0f to %.0f m, gate to apse (%.0f to %.0f s at cruise)" % [lengths.x,lengths.y,lengths.x/SkyPlane.CRUISE_SPEED,lengths.y/SkyPlane.CRUISE_SPEED])
	check(gaps.x >= Sundered.GAP.x-1.0 and gaps.y <= Sundered.AQUEDUCT_GAP.y+3.0,"Gaps of %.0f to %.0f m" % [gaps.x,gaps.y])
	check(steepest <= Sundered.GRADE+0.001,"Steps across the gaps no steeper than %.2f (%.2f)" % [Sundered.GRADE,steepest])
	check(widest_shut <= EXIT_EVERY,"A way out at least every %.0f m (widest %.1f m, %.1f s at cruise)" % [EXIT_EVERY,widest_shut,widest_shut/SkyPlane.CRUISE_SPEED])
	check(acts_ok,"Every hall runs gate, naves, shafts, a drop, cloisters, the aqueduct, the slit, the apse")
	var a := Sundered.layout(5,0.2)
	var b := Sundered.layout(5,0.2)
	check(Sundered.line(a).size() == Sundered.line(b).size() and (Sundered.line(a)[300].at as Vector3).is_equal_approx(Sundered.line(b)[300].at),"The same seed lays the same hall")

static func LEAD_S(plan: Dictionary) -> float:
	return Sundered.LEAD

func _standing() -> void:
	var cells := SkyCells.new([Vector3.ZERO,Vector3(380.0,-20.0,-160.0)])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var field: Node3D = SkyClusters.new()
	field.islets = islets
	field.with_random = true
	field.with_near = ["sundered","lake"]
	root.add_child(field)
	field.reset(cells)
	var spot: Dictionary = {}
	for s: Dictionary in field.spots:
		if s.key == "near:sundered": spot = s
	check(not spot.is_empty(),"--motif=sundered lays the hall near the home")
	if spot.is_empty(): return
	var crowded := false
	for s: Dictionary in field.spots:
		if s.motif == "sundered": continue
		for f: Vector3 in spot.footprint:
			if Vector2(s.at.x-spot.at.x-f.x,s.at.z-spot.at.z-f.y).length() < f.z+SkyClusters.HALL_KEEP*0.5: crowded = true
	check(not crowded,"No other cluster stands on its footprint")
	var on_island := false
	for f: Vector3 in spot.footprint:
		if not cells.spots_near(spot.at+Vector3(f.x,0.0,f.y),f.z+SkyClusters.HALL_ISLAND-1.0).is_empty(): on_island = true
	check(not on_island,"Its footprint keeps clear of the islands")
	var began := Time.get_ticks_msec()
	field.plan_now(spot.key)
	var c: Dictionary = field.clusters[spot.key]
	var plan: Dictionary = c.plan
	print("  planned and stood in %d ms: %d members, %d pieces, %d bays, line %.0f m" % [Time.get_ticks_msec()-began,plan.members.size(),plan.pieces.size(),_bays(plan),plan.length])
	var stood: Dictionary = field.members_of(spot.key)
	check(stood.size() == plan.members.size() and (c.halls as Array).size() == plan.members.size(),"Every island stands with its hall (%d)" % stood.size())
	# The islands: turned along the hall, clear of one another, the hall's
	# floor on the land.
	var turned := true
	for m: Dictionary in plan.members:
		var b: Dictionary = stood[m.name]
		if absf(angle_difference(SkyIslets.yaw_of(b),float(m.yaw))) > 0.001: turned = false
	check(turned,"Each island turned along its piece")
	var overlap := ""
	var rims := {}
	for m: Dictionary in plan.members:
		var rim := PackedVector2Array()
		for k in range(96): rim.append(Vector2(m.shape.rim_point(TAU*k/96.0)).rotated(-float(m.yaw)))
		rims[m.name] = rim
	for i in range(plan.members.size()):
		for j in range(i+1,plan.members.size()):
			var a: Dictionary = plan.members[i]
			var b: Dictionary = plan.members[j]
			var gap := Solver.rim_gap(rims[a.name],a.offset,rims[b.name],b.offset)
			if gap < 2.0: overlap = "%s-%s %.1f m" % [a.name,b.name,gap]
	check(overlap == "","The islands keep clear of one another%s" % ("" if overlap == "" else " ("+overlap+")"))
	var floor_ok := 0
	var floor_all := 0
	for m: Dictionary in plan.members:
		if m.role != "piece": continue
		var piece: Dictionary = plan.pieces[int(m.piece)]
		var hall: Transform3D = m.hall
		var s := 2.0
		while s < float(piece.length)-2.0:
			for z in [-8.0,0.0,8.0]:
				var q: Vector3 = hall*(piece.path as Hall.HallPath).point(Vector3(s,0.0,z))
				floor_all += 1
				var p := Vector2(q.x,q.z)
				if m.shape.on_land(p) and absf(float(m.shape.ground_at(p))-q.y+0.06) < 0.25: floor_ok += 1
			s += 4.0
	check(floor_ok >= floor_all*0.85,"The hall's floor lies on its bedded island (%d of %d points)" % [floor_ok,floor_all])
	# The aqueduct's arch over the line.
	var aq: Dictionary = plan.aqueduct
	var crossing: Vector3 = aq.crossing
	var member: Dictionary = {}
	for m: Dictionary in plan.members:
		if m.role == "aqueduct": member = m
	var arch_mid: Vector3 = (member.offset as Vector3)+Basis(Vector3.UP,float(member.yaw))*Vector3(float(aq.run.crossing_x),float(aq.run.origin.y),0.0)
	check(Vector2(arch_mid.x-crossing.x,arch_mid.z-crossing.z).length() < 0.05 and absf(crossing.y-arch_mid.y-SunderedBuild.AQ_LINE) < 0.05,"The line threads the aqueduct's arch %.1f m over its island" % (crossing.y-arch_mid.y))
	# Budgets.
	var far := 0
	for live: Dictionary in c.halls: far += _tris((live.far as MeshInstance3D).mesh)
	check(far <= FAR_BUDGET,"The far detail, the whole hall: %d triangles (budget %d)" % [far,FAR_BUDGET])
	# Standing near detail costs a frame little: the mesh, then the body a
	# chunk at a time.
	# (The process's first body in the physics space costs a few ms once.)
	var warm := StaticBody3D.new()
	var warm_shape := CollisionShape3D.new()
	warm_shape.shape = ConvexPolygonShape3D.new()
	(warm_shape.shape as ConvexPolygonShape3D).points = PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3.BACK])
	warm.add_child(warm_shape)
	root.add_child(warm)
	var t_mesh := 0
	var t_chunk := 0
	for pi in [1,2]:
		var probe: Dictionary = c.halls[pi]
		SunderedBuild._start_near(probe,plan)
		WorkerThreadPool.wait_for_task_completion(probe.task)
		probe.task = -1
		var t0 := Time.get_ticks_usec()
		SunderedBuild._stand_near(probe)
		t_mesh = Time.get_ticks_usec()-t0
		var times: Array = []
		while true:
			var t1 := Time.get_ticks_usec()
			if not SunderedBuild._stand_body(probe): break
			# (A piece's first body chunk costs ~5 ms once, the rest ~1.3.)
			if pi == 2 and not times.is_empty(): t_chunk = maxi(t_chunk,Time.get_ticks_usec()-t1)
			times.append((Time.get_ticks_usec()-t1)/100/10.0)
		print("  chunks (ms): ",times)
	print("  standing a piece: its mesh %.1f ms, the slowest body chunk %.1f ms" % [t_mesh/1000.0,t_chunk/1000.0])
	check(t_mesh < 4000 and t_chunk < 4000,"A piece stands without a hitch (mesh %.1f ms, body chunks after the first %.1f ms at most)" % [t_mesh/1000.0,t_chunk/1000.0])
	var worst := 0
	var worst_bay := 0.0
	var builds: Array = []
	var stands: Array = []
	for live: Dictionary in c.halls:
		var t0 := Time.get_ticks_usec()
		SunderedBuild.build_now(live,plan)
		var spent := Time.get_ticks_usec()-t0
		var tris := RuinKit.triangles(live.near)
		if live.member.role == "piece":
			worst = maxi(worst,tris)
			worst_bay = maxf(worst_bay,float(tris)/int(plan.pieces[int(live.member.piece)].bays))
			builds.append(int(live.get("build_usec",0))/1000)
			stands.append((spent-int(live.get("build_usec",0)))/1000)
		var hulls := 0
		for n: Node in (live.near as Node).get_children():
			if n is StaticBody3D: hulls += n.get_child_count()
		print("  near %s: %d triangles, %d hulls" % [live.member.name,tris,hulls])
	check(worst <= NEAR_BUDGET and worst_bay <= NEAR_BAY,"A piece's near detail at most %d triangles (%.0f a bay; budget %d, %d)" % [worst,worst_bay,NEAR_BUDGET,NEAR_BAY])
	print("  near builds (worker, ms): %s" % str(builds))
	await physics_frame
	await physics_frame
	await _fly(field,plan,spot,cells)
	# Streaming: far from every piece the near detail goes, near one it
	# comes back.
	for live: Dictionary in c.halls: live.distance = INF
	SunderedBuild.advance(c.halls,plan,Vector3(9000.0,0.0,9000.0))
	await process_frame
	check((c.halls as Array).all(func(l: Dictionary) -> bool: return l.near == null and (l.far as Node3D).visible),"Past NEAR_FORGET the near detail goes, the far shows")
	var piece0: Dictionary = c.halls[0]
	var near_eye: Vector3 = (piece0.node as Node3D).transform*(piece0.samples[0] as Vector3)+Vector3.UP*5.0
	for i in range(240):
		SunderedBuild.advance(c.halls,plan,near_eye)
		if piece0.near != null: break
		await process_frame
	SunderedBuild.advance(c.halls,plan,near_eye)
	check(piece0.near != null and (piece0.near as Node3D).visible and not (piece0.far as Node3D).visible,"Flown near, a piece's near detail streams in and shows")
	field.queue_free()
	islets.queue_free()
	for n in root.get_children():
		if n is StaticBody3D: n.queue_free()
	for i in range(4): await process_frame

static func _bays(plan: Dictionary) -> int:
	var n := 0
	for p: Dictionary in plan.pieces: n += int(p.bays)
	return n

static func _tris(mesh: Mesh) -> int:
	var n := 0
	if mesh == null: return 0
	for s in range(mesh.get_surface_count()): n += mesh.surface_get_array_len(s)/3
	return n

## The game's plane on an autopilot down the line (the lane's middle),
## through the near detail's stone, bumping and recovering
## (scripts/ruin_bump.gd): the time from the gate's mouth to the apse.
func _fly(field: Node3D, plan: Dictionary, spot: Dictionary, cells: SkyCells) -> void:
	var line := Sundered.line(plan,1.0)
	var islets: Node3D = field.islets
	var stood: Dictionary = field.members_of(spot.key)
	var any: Dictionary = stood.values()[0]
	var to_world := func(p: Vector3) -> Vector3:
		var bob: Vector3 = (any.node as Node3D).position-(any.home as Vector3)
		return islets.position+(spot.at as Vector3)+p+bob
	var plane := SkyPlane.new()
	plane.floor_y = -400.0
	var start: Vector3 = to_world.call(line[0].at)
	var way0: Vector3 = line[0].way
	plane.launch(start,atan2(-way0.x,-way0.z),SkyPlane.CRUISE_SPEED,false)
	var space := (islets as Node3D).get_world_3d().direct_space_state
	var ground := func(p: Vector3) -> Variant: return islets.body(p-islets.position)
	var delta := 1.0/60.0
	var t := 0.0
	var index := 0
	var bumps := 0
	var bump_at: Array = []
	var worst := 0.0
	var entered := -1.0
	var left := -1.0
	var hall_from: float = Sundered.LEAD
	var hall_to: float = Sundered.LEAD+float(plan.hall_length)
	while t < 160.0 and index < line.size()-2:
		# The nearest sample ahead.
		var best := INF
		for k in range(index,mini(index+40,line.size())):
			var d := (to_world.call(line[k].at) as Vector3).distance_squared_to(plane.position)
			if d < best:
				best = d
				index = k
		var sample: Dictionary = line[index]
		var at: Vector3 = to_world.call(sample.at)
		var way: Vector3 = sample.way
		var ahead: Dictionary = line[mini(index+8,line.size()-1)]
		var right := Vector3(way.x,0.0,way.z).normalized().cross(Vector3.UP)
		var off: Vector3 = plane.position-at
		var lz := off.dot(right)
		var ly := off.y
		var mz: float = (plane.velocity as Vector3).dot(right)
		var my: float = (plane.velocity as Vector3).y-SkyPlane.CRUISE_SPEED*(ahead.way as Vector3).y
		var input := {"turn":clampf(-lz*0.35-mz*0.3,-0.8,0.8),"pitch":clampf(-ly*0.4-my*0.25,-0.7,0.7),"look":Vector2.ZERO,"lean":0.0,"boost":0.0,"brake":0.0,"roll":0.0}
		var was: Vector3 = plane.position
		plane.step(delta,input,ground)
		if RuinBump.bump(space,plane,was):
			bumps += 1
			if bump_at.size() < 8: bump_at.append("%.0f m %s" % [float(sample.s),sample.kind])
		worst = maxf(worst,Vector2(lz,ly).length())
		if entered < 0.0 and float(sample.s) >= hall_from: entered = t
		if left < 0.0 and float(sample.s) >= hall_to: left = t
		t += delta
		field.advance(delta,plane.position)
		islets.advance(delta,plane.position)
		if int(t/delta) % 6 == 0: await process_frame
	var through := left-entered if left > 0.0 and entered >= 0.0 else -1.0
	print("  autopilot: gate to apse in %.1f s at cruise (line %.0f m, hall %.0f m), %d bumps %s, farthest off the line %.1f m" % [through,plan.length,plan.hall_length,bumps,str(bump_at),worst])
	check(through >= TRAVERSE.x and through <= TRAVERSE.y,"The plane flies the hall in %.0f s (%.0f to %.0f)" % [through,TRAVERSE.x,TRAVERSE.y])
	check(bumps <= 6,"Down the lane it seldom touches stone (%d bumps)" % bumps)
