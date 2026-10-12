extends SceneTree
## The sky round the aqueduct isle (studies/aqueduct_isle_sky.gd), headless:
## the four ruin motif isles stand where they are placed (scripts/kit_isle/
## motif_sky.gd, docs/scenic/motif-sky.md), whole: their art, turf, grass,
## life and tokens; their ground meets the plane (skimmed); the CPU planes
## fly their laps over what stands; the airships ply their loops (and the
## ferry its own), solid to the plane; the open-air life stands on the nearest motif isles; the motes
## are out; and each token is taken on its flying line without a bump, the
## knife-edge pair only on knife edge (level, the plane is bumped off the
## stumps). The far isles, clusters and pierced isle are gone.
##   godot --headless --path . --script tests/test_aqueduct_isle_sky.gd
const IsleSky = preload("res://studies/aqueduct_isle_sky.gd")
const Study = preload("res://studies/aqueduct_isle.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const MotifSky = preload("res://scripts/kit_isle/motif_sky.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var sky: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("aqueduct isle sky test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	sky = study.sky
	check(sky != null and sky.on.values().all(func(v: bool) -> bool: return v),"The sky stands with every part on by default")
	var began := Time.get_ticks_msec()
	sky.flush()
	print("sky: flushed in %d ms" % (Time.get_ticks_msec()-began))
	await physics_frame
	await physics_frame
	_isles()
	await _traffic()
	_airships()
	_life()
	check(sky.motes.size() == 3 and sky.motes.all(func(m: Node3D) -> bool: return m.visible),"The motes are out round the isle and the two nearest motif isles")
	_tokens()
	print("PASS: aqueduct isle sky" if failures == 0 else "FAIL: aqueduct isle sky (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _isles() -> void:
	var motifs: Node3D = sky.motifs
	# The motif isles, and the dragon's roost past them (on by default,
	# scripts/kit_isle/motif_dragon_roost.gd): its own checks, not a motif's.
	check(motifs != null and motifs.isles.size() == MotifSky.PLACES.size()+1,"The eight motif isles and the roost are in the sky (%d)" % (motifs.isles.size() if motifs != null else 0))
	check(sky.get("islets") == null and sky.get("clusters") == null and sky.get("pierced") == null,"No far isles, clusters or pierced isle")
	check(motifs.all_stood() and sky.isles_ready(),"Every motif isle stands whole")
	var ids := []
	for isle: Node3D in motifs.isles:
		var id: String = isle.motif.id()
		if id == "dragon_roost": continue
		ids.append(id)
		var c: Vector3 = isle.circle()
		var off := Vector2(c.x-sky.MIDDLE.x,c.y-sky.MIDDLE.z).length()
		var flora: int = (isle.flora.get_meta("records") as Array).size() if isle.flora != null else 0
		var tokens: int = isle.life.tokens.tokens.size() if isle.life != null and isle.life.tokens != null else 0
		print("sky: %s at (%.0f, %.0f) r %.0f, top %.1f, %.0f m off, %d plants, %d foot tokens" % [id,c.x,c.y,c.z,isle.isle_top(),off,flora,tokens])
		check(off > 250.0 and off < 700.0,"%s stands a few hundred metres off the isle (%.0f m)" % [id,off])
		check(flora > 1000 and tokens >= 4,"%s has its grass and flowers (%d) and its foot tokens (%d)" % [id,flora,tokens])
		# Its ground meets the plane: over a tuft of its grass the turf's ray
		# finds the turf it grows on, and the traffic's eye finds it too.
		var tuft: Dictionary = (isle.flora.get_meta("records") as Array)[0] if flora > 0 else {}
		var at := Vector3(float(tuft.get("x",c.x)),isle.isle_top()+30.0,float(tuft.get("z",c.y)))
		var top: Variant = study.plane_ground(at)
		check(top != null and absf(float(top)-isle.isle_top()) < 25.0,"The plane reads %s's turf (%s, its datum %.0f)" % [id,str(top),isle.isle_top()])
		check(sky.ground(at) != null,"%s's ground is there to the traffic's eye" % id)
	var sources: Array = sky.collectibles.sources.keys()
	check(["aqueduct","bell_spires","cloister","sundered_gorge","colonnade","broken_ring","nave","stair_clouds","hollow_keel"].all(func(k: String) -> bool: return sources.has(k)),"Each motif's plane tokens are in the sky's collectibles (%s)" % str(sources))
	check(ids == ["bell_spires","cloister_tarn","sundered_gorge","colonnade_spine","broken_ring","drowned_nave","stair_clouds","hollow_keel"],"The eight motif isles, in their order (%s)" % str(ids))
	for a: int in range(motifs.isles.size()):
		for b: int in range(a+1,motifs.isles.size()):
			var ca: Vector3 = motifs.isles[a].circle()
			var cb: Vector3 = motifs.isles[b].circle()
			var gap := Vector2(ca.x-cb.x,ca.y-cb.y).length()-ca.z-cb.z
			check(gap > 150.0,"%s and %s stand apart (%.0f m of sky between)" % [motifs.isles[a].motif.id(),motifs.isles[b].motif.id(),gap])

func _traffic() -> void:
	var planes: Array = sky.traffic.planes
	check(planes.size() == 4 and planes.all(func(p: Dictionary) -> bool: return p.figure.visible),"Four CPU biplanes fly, shown")
	var low := INF
	var flown: Array = planes.map(func(_p: Dictionary) -> float: return 0.0)
	var goals := {}
	for i in range(int(40.0/DT)):
		var was: Array = planes.map(func(p: Dictionary) -> Vector3: return p.flight.position)
		sky.traffic._process(DT)
		for k in range(planes.size()):
			flown[k] += (planes[k].flight.position as Vector3).distance_to(was[k])
			goals[str(planes[k].goal.kind)] = true
		if i % 20 == 0:
			for p: Dictionary in planes:
				var under: Variant = sky.ground(p.flight.position)
				if under != null: low = minf(low,float(p.flight.position.y)-float(under))
	check(flown.all(func(d: float) -> bool: return d > 350.0),"Over 40 s each flies on (%s m)" % str(flown.map(func(d: float) -> int: return int(d))))
	print("sky: traffic goals seen %s" % str(goals.keys()))
	check(low > 2.0,"They keep clear over what stands (lowest %.1f m)" % low)
	await process_frame

func _airships() -> void:
	# Their loops, and the ferry last on its own (scripts/kit_isle/
	# airship_ferry.gd; tests/test_airship_ferry.gd rides it).
	check(sky.airships.size() == IsleSky.ROUTES.size()+1 and sky.ferry != null and sky.airships[-1].has("ferry"),"%d airships ply their loops, the ferry last" % sky.airships.size())
	var a: Dictionary = sky.airships[0]
	var was: Vector3 = a.at
	for i in range(60): sky._advance_airships(DT,study.camera.global_position)
	var went := (a.at as Vector3).distance_to(was)
	check(absf(went-float(a.speed)) < 1.5,"An airship goes on at its pace (%.1f m in a second)" % went)
	var space := study.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.position = (a.ship._ship as Node3D).global_transform*(sky.AirshipBuild.ENVELOPE_AT)
	q.collision_mask = 1
	var r := PhysicsRayQueryParameters3D.create(q.position+Vector3.UP*20.0,q.position,1)
	check(not space.intersect_ray(r).is_empty(),"Its envelope is solid to the plane")
	# Close to one, its drone hums.
	sky.drone.engine(7.0,0.0,1.0)
	check(float(sky.drone._hum_goal) > 0.0,"The drone hums close by")

func _life() -> void:
	var bell: Vector3 = MotifSky.places()[0][1]
	for i in range(240): sky._advance_life(DT,bell+Vector3(0.0,20.0,60.0))
	check(sky.life.hosts.size() >= 1,"Open-air life stands on the nearest motif isles (%d)" % sky.life.hosts.size())
	var gulls := 0
	for host in sky.life.hosts.values(): gulls += (host.gulls as Array).size()
	check(gulls > 0,"Gulls ride the thermals over them (%d)" % gulls)

## Flies the plane `seconds` from `at` heading `heading` (radians, the
## plane's), on knife edge if `lean`; returns the bumps and the tokens taken.
func _fly(at: Vector3, heading: float, seconds: float, lean := 0.0) -> Dictionary:
	if not study.flying: study.board()
	var plane: RefCounted = study.plane
	plane.position = at
	plane.heading = heading
	plane.pitch = 0.0
	plane.bank = 0.0
	plane.knife = lean
	plane.speed = 14.0
	plane.velocity = plane.forward()*14.0
	study.bumps = 0
	var had: int = sky.collectibles.collected.size()
	sky.collectibles._last.clear()
	var lowest := INF
	for i in range(int(seconds/DT)):
		study.fly_step(DT,{"turn":0.0,"pitch":0.0,"look":Vector2.ZERO,"lean":lean,"boost":0.0,"brake":0.0,"roll":0.0})
		sky._process(DT)
		lowest = minf(lowest,plane.position.y)
	return {"bumps":study.bumps,"took":sky.collectibles.collected.size()-had,"at":plane.position}

func _tokens() -> void:
	var c: Node3D = sky.collectibles
	c.flush(Vector3(90.0,25.0,-20.0))
	var count := 0
	for l: Dictionary in c.sources.aqueduct.lines: count += (l.points as PackedVector3Array).size()
	check(count >= 4 and count <= 6,"A few tokens for the plane (%d)" % count)
	# Knife edge east along the stumps' slot: both taken, no bump.
	var level := _fly(Vector3(70.0,25.0,Art.KNIFE_Z),-PI*0.5,2.2,0.0)
	check(level.bumps > 0,"Level, the stumps' gap bumps the plane (%d bumps)" % level.bumps)
	c.collected.clear()
	c.flush(Vector3(90.0,25.0,-20.0))
	var knife := _fly(Vector3(70.0,25.0,Art.KNIFE_Z),-PI*0.5,3.0,1.0)
	check(knife.bumps == 0 and knife.took == 2,"On knife edge it slips the stumps and the arch, taking both (%d bumps, %d taken, at %s)" % [knife.bumps,knife.took,str(knife.at)])
	var lines := [["the fallen span",Vector3(80.0,Art.TOP+1.5*Art.GROW,-Art.arch(Art.FALLEN)),-PI*0.5,3.0],
		["under the keel",Vector3(65.0,-9.5,0.0),-PI*0.5,3.0],
		["the west gap",Vector3(37.8,34.0,20.0),0.0,3.0],
		["the east gap",Vector3(128.8,27.5,12.0),0.0,3.0]]
	for line: Array in lines:
		c.flush(line[1])
		var r := _fly(line[1],line[2],line[3])
		check(r.bumps == 0 and r.took == 1,"Through %s: taken, no bump (%d bumps, %d taken, at %s)" % [line[0],r.bumps,r.took,str(r.at)])
	study.leave_plane()
