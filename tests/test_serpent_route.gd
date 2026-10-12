extends SceneTree
## suite: slow
## The rune serpent's route between the isles (scripts/kit_isle/
## serpent_route.gd, ridden: scripts/kit_isle/serpent_rider.gd), headless,
## in the aqueduct isle's sky with its motif isles stood up:
##   - the serpent flies the route by default, round the aqueduct isle and
##     three motif isles, a lap in a few minutes; its way's tube is clear of
##     every isle's rock and ground (the ledges aside) and of the airships'
##     loops (the ferry's kept clear by tests/test_airship_ferry.gd);
##   - each isle's boarding ledge stands, and as the serpent passes it its
##     back goes by within a jump of the ledge's end (across and under it),
##     its body never touching the ledge;
##   - a scripted rider on the aqueduct isle's ledge runs and jumps as its
##     middle goes by and lands on its back; stands on it through the dip
##     to the cloister tarn; and jumps off it there onto the tarn;
##   - walked off its back over open sky he falls as the game's walker does
##     (off the edge, no fade back onto it, `lost` set aside) and is
##     stranded and set back beside the parked plane;
##   - --serpent-old-route flies the old long way, with no ledges.
##   godot --headless --path . --script tests/test_serpent_route.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
const SerpentRoute = preload("res://scripts/kit_isle/serpent_route.gd")
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const IsleSky = preload("res://studies/aqueduct_isle_sky.gd")
const DT := 1.0/60.0
## A jump's reach from a ledge's end to its back's spine (m across), and
## how far under the ledge's top its back's crest may pass (m; under 0, it
## passes over it): a hop across onto its shoulder, a hop down getting off.
const JUMP_ACROSS := 4.8
const JUMP_UNDER := Vector2(-1.2,1.0)
## A lap: at most this long (s).
const LAP_MOST := 300.0
var failures := 0
var study: Node3D
var route: Node3D
var serpent: Node3D
var rider: Node3D
var m: RefCounted

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(420.0).timeout.connect(func() -> void: push_error("serpent route test timed out"); quit(2))
	LaunchArgs.set_override(["--no-life","--no-flora"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	route = study.sky.get("route")
	check(route != null,"The serpent flies the route between the isles by default")
	if route == null:
		_finish()
		return
	serpent = route.serpent
	rider = route.rider
	m = study.motor
	check(serpent == study.sky.serpent and serpent.route == SerpentRoute.ROUTE,"It is the sky's serpent, on the route (%.0f m round)" % serpent.route_length)
	study.sky.flush()
	route.build_all()
	for i in range(3): await physics_frame
	serpent.set_process(false)
	rider.manual = true
	_tube()
	_airships()
	await _passes()
	_stand_by()
	await _ride()
	await _off_over_sky()
	await _old_route()
	_finish()

func _finish() -> void:
	LaunchArgs.set_override(null)
	print("PASS: serpent route" if failures == 0 else "FAIL: serpent route (%d)" % failures)
	quit(1 if failures > 0 else 0)

## One frame of the game, in its order: the serpent, the route, the rider,
## then the pilot.
func frame() -> void:
	serpent.advance(DT)
	route._process(DT)
	rider.step(DT)
	study.tick(DT)

func _input(want: Vector2, jump: bool) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = false

## Its way's tube, at its farthest reach, clear of the isles' rock and
## ground; the ledges, which stand a jump off it on purpose, aside.
func _tube() -> void:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	q.shape = ball
	q.collision_mask = 1|IsleSky.TURF_LAYER
	var skip: Array[RID] = [serpent.solid_rid(),rider.back.rid()]
	for s: Dictionary in route.spots:
		if s.built != null: skip.append(((s.built as Node3D).get_node("Body") as CollisionObject3D).get_rid())
	q.exclude = skip
	var blocked := []
	var at := 0.0
	while at < serpent.route_length:
		ball.radius = float(serpent.reach_at(at))+0.5
		q.transform = Transform3D(Basis.IDENTITY,serpent.route_point(at))
		if not space.intersect_shape(q,1).is_empty() and (blocked.is_empty() or at-float(blocked[-1]) > 10.0): blocked.append(at)
		at += 2.0
	check(blocked.is_empty(),"Its way's tube (girth, slither, veer and heave at their most) is clear of every isle (blocked at %s m)" % str(blocked))
	var isles := {}
	for s: Dictionary in route.spots: isles[s.isle] = true
	check(isles.size() == 4 and isles.has("aqueduct"),"It links the aqueduct isle and three motif isles: %s" % ", ".join(isles.keys()))

## The airships' loops never come near its way.
func _airships() -> void:
	var worst := INF
	for a: Dictionary in study.sky.airships:
		# The ferry comes down to the isles by design, over the serpent's
		# home run on its way out; tests/test_airship_ferry.gd keeps its
		# loop (and its hull) clear of this way by its own measure.
		if a.has("ferry"): continue
		for i in range(300):
			var ap: Vector3 = IsleSky._loop(a.points,i/300.0)
			var t := 0.0
			while t < serpent.route_length:
				worst = minf(worst,ap.distance_to(serpent.route_point(t))-float(serpent.reach_at(t)))
				t += 3.0
	var ship: float = Vector2(IsleSky.AirshipBuild.ENVELOPE_LENGTH*0.5,IsleSky.AirshipBuild.ENVELOPE_AT.y+IsleSky.AirshipBuild.ENVELOPE_RADIUS).length()+2.0
	check(worst > ship,"Its way keeps clear of the airships' loops (%.1f m past its reach, a ship's %.1f)" % [worst,ship])

## A whole lap from its start: its time; by each ledge, its back within a
## jump of the ledge's end and its body never touching the ledge.
func _passes() -> void:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	rider._set_live(true)
	var went := 0.0
	var last: float = serpent.s
	var t := 0.0
	var reach := {}
	var touch := {}
	var pace := {}
	while went < serpent.route_length and t < LAP_MOST:
		serpent.advance(DT)
		route._process(DT)
		t += DT
		went += fposmod(float(serpent.s)-last,float(serpent.route_length))
		last = serpent.s
		for s: Dictionary in route.spots:
			var rel := wrapf(float(serpent.s)-float(s.at),-serpent.route_length*0.5,serpent.route_length*0.5)
			if absf(rel) < 1.0: pace[s.id] = serpent.speed()
			# From its head 20 m short of the ledge to its tail past it.
			if rel < -20.0 or rel > 110.0: continue
			rider.back.update()
			await physics_frame
			var body: CollisionObject3D = (s.built as Node3D).get_node("Body") if s.built != null else null
			if body != null and not touch.has(s.id):
				for shape: CollisionShape3D in rider.back.body.get_children():
					var sq := PhysicsShapeQueryParameters3D.new()
					sq.shape = shape.shape
					sq.collision_mask = 1
					for h: Dictionary in space.intersect_shape(sq,8):
						if h.rid == body.get_rid(): touch[s.id] = rel
			var end: Vector3 = s.end
			var best: Vector2 = reach.get(s.id,Vector2(INF,0.0))
			for a: float in [12.0,20.0,30.0,40.0,50.0,60.0,70.0]:
				var top: Vector3 = rider.back.place(rider.back.top(a))
				var flat := Vector2(top.x-end.x,top.z-end.z).length()
				if flat < best.x: best = Vector2(flat,end.y-top.y)
			reach[s.id] = best
	rider._set_live(false)
	print("MEASURE lap %.1f s, %.0f m, %.2f m/s on average; pace by the ledges %s" % [t,went,went/t,str(pace)])
	check(went >= serpent.route_length and t < LAP_MOST,"It flies a whole lap in %.0f s (%.1f min)" % [t,t/60.0])
	for s: Dictionary in route.spots:
		var r: Vector2 = reach.get(s.id,Vector2(INF,0.0))
		print("MEASURE %s ledge: end %s, %d steps; its spine %.2f m across from the end, %.2f m under it at the nearest" % [s.id,(s.end as Vector3).snapped(Vector3.ONE*0.01),int(s.get("steps",0)),r.x,r.y])
		check(s.built != null,"The %s ledge stands (a flight of %d steps up to its landing)" % [s.id,int(s.get("steps",0))])
		check(r.x < JUMP_ACROSS and r.y > JUMP_UNDER.x and r.y < JUMP_UNDER.y,"By the %s ledge its back passes within a jump: %.2f m across, %.2f m under" % [s.id,r.x,r.y])
		check(not touch.has(s.id),"By the %s ledge its body never touches the ledge" % s.id)

## Stood still on each ledge's end as it goes by (its head turned to look
## at him all the way in): never touched, never carried off.
func _stand_by() -> void:
	for s: Dictionary in route.spots:
		route.start_at(s)
		_input(Vector2.ZERO,false)
		var worst := 0.0
		var on := false
		for i in range(60*14):
			frame()
			worst = maxf(worst,m.feet.distance_to(s.stand))
			if rider.riding_on != "still": on = true
		print("MEASURE stood on the %s ledge as it passed: moved %.2f m at most, %s" % [s.id,worst,"carried off" if on else "left alone"])
		check(not on and worst < 0.3,"Stood on the %s ledge as it goes by, he is left alone (moved %.2f m)" % [s.id,worst])

## From the aqueduct isle's ledge: run and jump as its middle goes by; on
## its back through the dip to the cloister tarn; off it there onto the
## tarn.
func _ride() -> void:
	var home: Dictionary = route.spot("home")
	var tarn: Dictionary = route.spot("tarn")
	route.start_at(home)
	_input(Vector2.ZERO,false)
	for i in range(5): frame()
	check(rider.riding_on == "still" and m.feet.distance_to(home.stand) < 0.3,"--serpent-board=home: on the aqueduct isle's ledge, the serpent coming")
	var toward: Vector2 = home.toward
	var went := false
	var held := 0.0
	var end: Vector3 = home.end
	var arcs: PackedFloat32Array = serpent.stations()
	for i in range(1200):
		# Its middle alongside: go.
		if not went:
			var rings: PackedVector3Array = serpent.rings()
			var near := INF
			var k_near := 0
			for k in range(rings.size()):
				var d := Vector2(rings[k].x-end.x,rings[k].z-end.z).length()
				if d < near:
					near = d
					k_near = k
			if arcs[k_near] > 22.0 and arcs[k_near] < 40.0: went = true
		var edge := Vector2(m.feet.x-end.x,m.feet.z-end.z).dot(toward) > -0.35
		if went and edge and m.grounded and held == 0.0: held = 0.3
		_input(toward if went else Vector2.ZERO,held > 0.0)
		held = maxf(held-DT,0.0) if held > 0.0 and not m.grounded else held
		frame()
		if rider.riding_on == "serpent": break
	_input(Vector2.ZERO,false)
	for i in range(20): frame()
	print("MEASURE boarding at home: on %s at %.1f m from the snout, %+.2f across; hulls %.2f ms a frame" % [rider.riding_on,rider.anchor.x,rider.anchor.y,rider.hulls_usec/1000.0])
	check(rider.riding_on == "serpent" and rider.boardings >= 1,"From the home ledge a running jump as its middle goes by lands him on its back")
	if rider.riding_on != "serpent": return
	# On it: kept to its spine, through the dip, until he is alongside the
	# tarn's rim.
	var on := 0
	var frames := 0
	var lowest := INF
	var lost_aside: bool = is_inf(float(study.lost))
	var off_at := Vector3.INF
	var tarn_end: Vector3 = tarn.end
	var tarn_toward: Vector2 = tarn.toward
	while frames < 60*90:
		var x: Vector3 = rider.back.frame(rider.anchor.x).basis.x
		var back_to := -Vector2(x.x,x.z).normalized()*clampf(float(rider.anchor.y)*1.5,-1.0,1.0) if absf(rider.anchor.y) > 0.25 else Vector2.ZERO
		_input(back_to,false)
		frame()
		frames += 1
		if rider.riding_on == "serpent": on += 1
		lowest = minf(lowest,m.feet.y)
		# Its terrace coming up alongside, about as far ahead as the frame
		# carries him in a jump and a run across its back: off.
		var to_end := Vector2(tarn_end.x-m.feet.x,tarn_end.z-m.feet.z)
		var along := to_end.dot(tarn.way as Vector2)
		var pace := Vector2(rider.carry_v.x,rider.carry_v.z).length()
		if along > 0.0 and along < pace*1.15+2.0 and to_end.length() < 20.0 and rider.riding_on == "serpent":
			off_at = m.feet
			break
	print("MEASURE rode %.1f s, on its back %d of %d frames, lowest %.1f m (the dip), lost set aside %s" % [frames*DT,on,frames,lowest,str(lost_aside)])
	check(on == frames and frames > 60*20,"He stays on its back from the aqueduct isle to the cloister tarn (%.0f s, through the dip down to %.0f m)" % [frames*DT,lowest])
	check(lost_aside,"While he rides it the scene's respawn floor is set aside (the dip runs under it)")
	check(off_at != Vector3.INF,"It carries him alongside the cloister tarn's rim")
	if off_at == Vector3.INF: return
	# Off toward the tarn: run across its back and jump at the shoulder.
	var isle_way := -tarn_toward
	held = 0.0
	var landed := false
	var twirled := false
	for i in range(240):
		var across: float = Vector2(m.feet.x-tarn_end.x,m.feet.z-tarn_end.z).dot(tarn_toward)
		# At its flat top's edge (about a metre off its spine): jump, and
		# twirl (X) as it tops out, for the air to reach the ledge.
		var edge: bool = rider.riding_on == "serpent" and across < float(route.widest_flank())+float(SerpentRoute.LEDGE_GAP)-0.9
		if edge and m.grounded and held == 0.0: held = 0.4
		study.script_twirl = not m.grounded and m.velocity.y < 1.0 and not twirled
		if study.script_twirl: twirled = true
		_input(isle_way,held > 0.0)
		held = maxf(held-DT,0.0) if held > 0.0 and not m.grounded else held
		frame()
		if rider.riding_on == "still" and m.grounded:
			landed = true
			break
	_input(Vector2.ZERO,false)
	study.script_twirl = false
	for i in range(10): frame()
	var tarn_isle: Node3D = route.motif_isle("cloister_tarn")
	var c: Vector3 = tarn_isle.circle()
	var off_mid := Vector2(m.feet.x-c.x,m.feet.z-c.y).length()
	print("MEASURE off at the tarn: %s at %s, %.1f m from its middle (its reach %.0f), %.1f m from its ledge" % [rider.riding_on,m.feet.snapped(Vector3.ONE*0.01),off_mid,c.z,m.feet.distance_to(tarn.end)])
	check(landed and rider.riding_on == "still" and off_mid < c.z+2.0,"A jump off its back alongside the tarn lands him on the tarn")
	check(not is_inf(float(study.lost)),"Down on the isle, the respawn floor is the scene's again")

## Walked off its side over open sky: the game's fall, not a fade back.
func _off_over_sky() -> void:
	var dip := float(serpent.marks()["dip"])
	serpent.place(fposmod(dip+40.0,float(serpent.route_length)))
	rider.reset()
	rider._set_live(true)
	study._end_fall()
	var a := 40.0
	study.place(rider.back.place(rider.back.top(a)),rider.back.ahead(a))
	_input(Vector2.ZERO,false)
	for i in range(10): frame()
	check(rider.riding_on == "serpent","Set on its back in the dip")
	var x: Vector3 = rider.back.frame(rider.anchor.x).basis.x
	var side := Vector2(x.x,x.z).normalized()
	var off_edge := false
	var stranded := false
	var t := 0.0
	var reached := false
	while t < 30.0:
		_input(side if rider.riding_on == "serpent" else Vector2.ZERO,false)
		frame()
		t += DT
		if study.off_edge: off_edge = true
		if study._stranded_left >= 0.0: stranded = true
		if stranded and study._stranded_left < 0.0:
			reached = true
			break
	for i in range(5): frame()
	var by_plane: bool = study.parked and m.feet.distance_to(study.parked_at) < 4.0
	print("MEASURE off over open sky: off the edge %s, stranded %s, back by the plane %s after %.1f s (%.1f m from it)" % [str(off_edge),str(stranded),str(reached),t,m.feet.distance_to(study.parked_at)])
	check(off_edge and stranded and reached and by_plane,"Walked off its back over open sky he falls as off any edge, is stranded and is set back beside the parked plane")
	check(rider.riding_on == "still" and not is_inf(float(study.lost)),"Back by the plane, the respawn floor is the scene's again")

## --serpent-old-route: the old long way, no ledges, no rider.
func _old_route() -> void:
	study.queue_free()
	await process_frame
	LaunchArgs.set_override(["--no-life","--no-flora","--serpent-old-route"])
	var old: Node3D = load("res://studies/aqueduct_isle.tscn").instantiate()
	old.scripted = true
	root.add_child(old)
	while not old.isle_up: await process_frame
	var sky: Node3D = old.sky
	check(sky.get("route") == null and sky.serpent != null and sky.serpent.route == RuneSerpent.ROUTE,"--serpent-old-route: the old long way, no ledges and no riding")
	old.queue_free()
	await process_frame
