extends SceneTree
## The drowned nave (studies/drowned_nave_isle.tscn), headless: the isle
## builds within its triangle budget and the pilot starts dry on the beach;
## no hole in the ground; the water is skimmed as the turf is; the plane's
## lines are clear of stone (the nave's axis along the water, the south
## row's gap and the north row's great arch at the crossing, the pull-up past the chancel's springers);
## and on foot: the causeway hopped down the nave from stone to stone, the
## grand stair walked up the apse to the lookout, the moat swum, every
## stone's walked top where it is drawn.
##   godot --headless --path . --script tests/test_drowned_nave_isle.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const NaveArt = preload("res://studies/drowned_nave_isle_art.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const DT := 1.0/60.0
## The most triangles the isle may draw (the aqueduct isle's cap).
const BUDGET := 900000
var failures := 0
var study: Node3D
var m: PilotMotor
var debug := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(600.0).timeout.connect(func() -> void: push_error("drowned nave test timed out"); quit(2))
	study = load("res://studies/drowned_nave_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	var tris: int = study.triangles(study.art)
	check(tris > 0 and tris < BUDGET,"The isle draws %d triangles (budget %d; the water %d)" % [tris,BUDGET,int(study.water.get_meta("triangles",0))])
	await physics_frame
	await physics_frame
	_start_stands()
	_ground_sound()
	_water_skimmed()
	_skim_lines()
	_causeway()
	_stair()
	_swim()
	_platforms_true()
	_tokens()
	print("PASS: drowned nave" if failures == 0 else "FAIL: drowned nave (%d)" % failures)
	quit(1 if failures else 0)

# --- Driving ---------------------------------------------------------------------------

func tick(want: Vector2, jump := false, crouch := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl
	study.tick(DT)

func settle(at: Vector3, face: Vector2) -> void:
	study.place(at,face)
	for i in range(20): tick(Vector2.ZERO)

func flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

func ahead(way: Vector2, reach := 0.7) -> float:
	return study.ground.ground(flat(m.feet)+way*reach)

func feet() -> String:
	return "feet %s" % m.feet

## Walked through `points` (world x, z) with the stick only: {ok, fell,
## reached}.
func walk_only(points: Array, frames := 6000) -> Dictionary:
	var i := 0
	var air := 0
	var fell := 0
	for f in range(frames):
		var to: Vector2 = points[i]
		var off: Vector2 = to-flat(m.feet)
		if off.length() < (0.5 if i == points.size()-1 else 1.0):
			i += 1
			if i >= points.size(): break
			continue
		tick(off.normalized())
		air = 0 if m.grounded else air+1
		if air == 15: fell += 1
		if m.on_ledge(): fell += 1
		if m.feet.y < NaveArt.W-20.0: break
	return {"ok":i >= points.size() and m.grounded,"fell":fell,"reached":i}

## A jump from where he stands (or `from`) to `to` (a top's middle): run at
## it, jump at the edge or the rise; true landed on it.
func leap(to: Vector3, from := Vector3.INF) -> bool:
	var target := Vector2(to.x,to.z)
	if from != Vector3.INF: settle(from,(target-Vector2(from.x,from.z)).normalized())
	var jumped := false
	for i in range(600):
		var off := target-flat(m.feet)
		var way := off.normalized() if off.length() > 0.05 else Vector2.ZERO
		var edge: bool = m.grounded and ahead(way,0.35) < m.feet.y-0.3
		var wall: bool = m.grounded and ahead(way,0.6) > m.feet.y+0.3
		var close: bool = m.grounded and off.length() < 1.9 and (absf(to.y-m.feet.y) > 0.2 or ahead(way,0.6) < m.feet.y-0.25)
		var jump := not jumped and (edge or wall or close)
		jump = jump or (jumped and not m.grounded and m.velocity.y > 0.0) or (m.on_ledge() and i%20 < 3)
		jumped = jumped or jump
		tick(way*(0.0 if off.length() < 0.2 and m.grounded else 1.0),jump)
		if m.feet.y < NaveArt.W-20.0: return false
		if jumped and m.grounded and not m.on_ledge() and absf(m.feet.y-to.y) < 0.12 and off.length() < 1.2: return true
	if debug: print("  leap to %s failed: %s grounded %s v %s" % [to,m.feet,m.grounded,m.velocity])
	return false

# --- The checks -------------------------------------------------------------------------

func _start_stands() -> void:
	study.respawn()
	for i in range(40): tick(Vector2.ZERO)
	check(m.grounded and m.feet.y > NaveArt.W+0.2 and m.wade <= 0.0,"Start: he stands dry on the beach (%s)" % feet())

## No hole in the ground: a ray down anywhere on the isle lands within
## 0.35 m of the ground's lowest close by.
func _ground_sound() -> void:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1
	var outline := PackedVector2Array(NaveArt.outline())
	var probes := 0
	var holes := 0
	var worst := Vector3.ZERO
	var x := NaveArt.C.x-64.0+0.173
	while x < NaveArt.C.x+64.0:
		var z := NaveArt.C.y-48.0+0.291
		while z < NaveArt.C.y+48.0:
			var p := Vector2(x,z)
			z += 0.83
			if not Geometry2D.is_point_in_polygon(p,outline) or Art._edge_distance(p,outline) < 1.0: continue
			var low := INF
			for d: Vector2 in [Vector2.ZERO,Vector2(0.7,0.0),Vector2(-0.7,0.0),Vector2(0.0,0.7),Vector2(0.0,-0.7)]: low = minf(low,NaveArt.ground(p.x+d.x,p.y+d.y))
			ray.from = Vector3(p.x,NaveArt.W+40.0,p.y)
			ray.to = Vector3(p.x,NaveArt.W-20.0,p.y)
			var hit := space.intersect_ray(ray)
			probes += 1
			if hit.is_empty() or (hit.position as Vector3).y < low-0.35:
				holes += 1
				worst = Vector3(p.x,(hit.position as Vector3).y if not hit.is_empty() else -INF,p.y)
		x += 0.83
	check(holes == 0,"Ground: no hole in the isle's ground (%d probes, %d holes, e.g. %s)" % [probes,holes,worst])

## The basin's water is skimmed as the turf is.
func _water_skimmed() -> void:
	var c := NaveArt.C
	var under: Variant = study.plane_ground(Vector3(c.x-3.0,NaveArt.W+4.0,c.y+1.0))
	check(under != null and absf(float(under)-NaveArt.W) < 0.3,"Water: the plane skims the basin (%s, its level %.1f)" % [str(under),NaveArt.W])
	var spill: Variant = study.plane_ground(Vector3(NaveArt.lip().x,NaveArt.W+4.0,NaveArt.lip().z+8.0))
	check(spill != null and absf(float(spill)-NaveArt.W) < 0.3,"Water: and the spill channel (%s)" % str(spill))
	check(study.water.get_meta("triangles",0) > 4000,"Water: the shared pond water is laid over the basin (%d triangles)" % int(study.water.get_meta("triangles",0)))

## The plane's lines are clear of stone: sampled every metre by the wing-wide
## bump body, along `from` to `to`, heading as the line goes.
func _line_clear(from: Vector3, to: Vector3) -> Dictionary:
	var way := Vector2(to.x-from.x,to.z-from.z)
	var turn := Basis(Vector3.UP,atan2(-way.x,-way.y) if way.length() > 0.01 else 0.0)
	var n := ceili(from.distance_to(to))
	var hit := 0
	var first := Vector3.ZERO
	for i in range(n+1):
		var p := from.lerp(to,float(i)/maxf(n,1))
		if study._stone_at(p,turn):
			hit += 1
			if first == Vector3.ZERO: first = p
	return {"hits":hit,"first":first}

func _skim_lines() -> void:
	var c := NaveArt.C
	var w := NaveArt.W
	var axis := _line_clear(Vector3(c.x-36.0,w+1.1,c.y),Vector3(c.x+22.0,w+1.1,c.y))
	check(axis.hits == 0,"Skim: the nave's axis from the beach to the chancel is clear of stone at 1.1 m over the water (%d hits, first %s)" % [axis.hits,str(axis.first)])
	# The crossing: out through the south row's gap, back and out through the
	# north row's great arch facing it (NaveArt CROSS, an opening).
	var x := c.x+NaveArt.cross_mid()
	var gap := _line_clear(Vector3(x,w+1.5,c.y),Vector3(x,w+1.5,c.y+10.0))
	check(gap.hits == 0,"Skim: out through the south row's gap at the crossing (%d hits, first %s)" % [gap.hits,str(gap.first)])
	var bay := _line_clear(Vector3(x,w+1.8,c.y),Vector3(x,w+1.8,c.y-10.0))
	check(bay.hits == 0,"Skim: out through the north row's great arch standing at the crossing (%d hits, first %s)" % [bay.hits,str(bay.first)])
	# Both a wing's room and more off its piers' stone (the gap's stubs, the
	# great arch's piers): the crossing is CROSS_CLEAR, THREAD-class.
	for side: float in [-1.0,1.0]:
		for off: float in [-1.0,1.0]:
			var edge := x+off*(NaveArt.CROSS_CLEAR*0.5-1.6)
			var row := _line_clear(Vector3(edge,w+1.6,c.y),Vector3(edge,w+1.6,c.y+side*10.0))
			check(row.hits == 0,"Skim: the crossing's %s row clear %.1f m off its middle (%d hits, first %s)" % ["south" if side > 0.0 else "north",edge-x,row.hits,str(row.first)])
	var pull := _line_clear(Vector3(c.x+14.0,w+1.5,c.y),Vector3(c.x+25.0,w+6.8,c.y))
	check(pull.hits == 0,"Skim: the pull-up past the chancel's springers (%d hits, first %s)" % [pull.hits,str(pull.first)])
	# And the stone is there to be missed: a bay's pier, a stub.
	var px: float = c.x+float(NaveArt.PIERS[NaveArt.CROSS_AT-1])
	var pier := _line_clear(Vector3(px,w+1.5,c.y-NaveArt.ROW_Z-4.0),Vector3(px,w+1.5,c.y-NaveArt.ROW_Z+4.0))
	check(pier.hits > 0,"Skim: a pier of the north row stands in the way across the row (%d hits)" % pier.hits)

## The causeway hopped down the nave from stone to stone, from the first
## to the last, and off it onto the chancel's shallows.
func _causeway() -> void:
	var stones: Array = NaveArt.platforms().filter(func(p: Dictionary) -> bool: return p.chain == "causeway")
	var first: Vector3 = stones[0].at
	settle(first+Vector3(-2.2,0.0,0.0),Vector2(1.0,0.0))
	check(m.wade > 0.0 or m.feet.y < NaveArt.W+0.2,"Causeway: he wades in the drowned nave before the first stone (%s, wade %.2f)" % [feet(),m.wade])
	var hopped := 0
	var from := Vector3.INF
	for p: Dictionary in stones:
		if not leap(p.at as Vector3,from): break
		hopped += 1
		from = Vector3.INF
	check(hopped == stones.size(),"Causeway: %d of %d stones hopped down the nave from the beach end to the chancel (%s)" % [hopped,stones.size(),feet()])

## The grand stair walked up the apse from the shore, no jump, onto the
## plateau and to the rose gable.
func _stair() -> void:
	var c := NaveArt.C
	var foot := NaveArt.world(Vector2(NaveArt.STAIR_FOOT_X+0.4,0.0))
	settle(Vector3(foot.x,NaveArt.ground(foot.x,foot.y),foot.y),Vector2(1.0,0.0))
	var path: Array = []
	var x := NaveArt.STAIR_FOOT_X+1.0
	while x < NaveArt.GABLE_X-2.0:
		path.append(Vector2(c.x+x,c.y))
		x += 2.0
	var walked := walk_only(path)
	if debug: print("  stair end: %s ground there %.2f" % [m.feet,NaveArt.ground(m.feet.x,m.feet.z)])
	check(walked.ok and absf(m.feet.y-NaveArt.plateau_top()) < 0.15,"Stair: up the apse's grand stair onto the plateau at %.2f m, walked (%d of %d points, %d falls, %s)" % [NaveArt.plateau_top(),walked.reached,path.size(),walked.fell,feet()])

## From the south shore into the moat: he wades, then swims.
func _swim() -> void:
	var c := NaveArt.C
	var z0 := c.y+NaveArt.basin_r(270.0)+3.0
	settle(Vector3(c.x,NaveArt.ground(c.x,z0),z0),Vector2(0.0,-1.0))
	var waded := false
	var swam := false
	for i in range(900):
		tick(Vector2(0.0,-1.0))
		waded = waded or m.wade > 0.0
		swam = swam or m.swimming
		if m.feet.z < c.y+9.0: break
	check(waded and swam,"Moat: walked in from the south shore he wades, then swims (wade %s, swim %s, %s)" % [waded,swam,feet()])

## Every stone's walked top stands where it is drawn.
func _platforms_true() -> void:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	var off := 0
	for p: Dictionary in NaveArt.platforms():
		var a: Vector3 = p.at
		ray.from = a+Vector3.UP*2.0
		ray.to = a+Vector3.DOWN*2.0
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or absf((hit.position as Vector3).y-a.y) > 0.03: off += 1
	check(off == 0,"Stones: every stone's walked top is where it is drawn (%d of %d off)" % [off,NaveArt.platforms().size()])

func _tokens() -> void:
	var life: Node = study.get("life")
	if life == null or life.tokens == null:
		check(false,"Tokens: the isle's life and its tokens are there")
		return
	var all: Array = life.tokens.tokens.map(func(t: Dictionary) -> String: return t.name)
	check(all.size() >= 4,"Tokens: %d on-foot tokens (%s)" % [all.size(),", ".join(all)])
	var taken: Array = life.tokens.taken
	print("Tokens: the routes took %d of %d (%s)" % [taken.size(),all.size(),", ".join(taken)])
