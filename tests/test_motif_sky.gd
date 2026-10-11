extends SceneTree
## The ruin motif isles in the aqueduct isle's sky (scripts/kit_isle/
## motif_sky.gd, motif_isle.gd; docs/scenic/motif-sky.md), headless, each
## stood whole (`flush`): the plane lands on its turf by hand (a touch
## nosed down onto an open run, braked to a stop, out), the pilot walks
## off on it; its grass and its life are up round where it stands, its
## foot tokens on it, its rope bridges live underfoot, its bells swing as
## the plane passes, the tarn's water is skimmed. Also: the plane's stone
## query never counts a motif's turf as stone; nothing is built on a worker
## headless; a motif isle not yet near the eye headless stays unbuilt.
##   godot --headless --path . --script tests/test_motif_sky.gd
const ManualLanding = preload("res://scripts/manual_landing.gd")
const RopeBridge = preload("res://scripts/rope_bridge.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const DT := 1.0/60.0
## Open turf this long (m) to land on.
const RUN := 14.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("motif sky test timed out"); quit(2))
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	var motifs: Node3D = study.motifs
	check(motifs != null and not motifs.threaded,"The motif isles are in the sky, built on the main thread headless")
	for i in range(30): await process_frame
	check(motifs.isles.all(func(isle: Node3D) -> bool: return isle.stage == "waiting"),"Headless, none is built while the eye is far (%s)" % str(motifs.isles.map(func(isle: Node3D) -> String: return isle.stage)))
	var began := Time.get_ticks_msec()
	study.sky.flush()
	print("motif sky: flushed in %d ms" % (Time.get_ticks_msec()-began))
	await physics_frame
	await physics_frame
	for isle: Node3D in motifs.isles: print("motif sky: %s %s" % [isle.motif.id(),str(isle.timings)])
	for isle: Node3D in motifs.isles: await _isle(isle)
	print("PASS: motif sky" if failures == 0 else "FAIL: motif sky (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _isle(isle: Node3D) -> void:
	var id: String = isle.motif.id()
	var c: Vector3 = isle.circle()
	check(isle.is_up() and isle.flora != null and isle.life != null,"%s stands whole: art, grass and life" % id)
	check(isle.art.position.is_equal_approx(isle.offset) and isle.art.get_child_count() > 5,"%s's art stands at its place (%s)" % [id,str(isle.offset)])
	# Its grass round its middle, its foot tokens on it.
	var records: Array = isle.flora.get_meta("records")
	var on := records.filter(func(r: Dictionary) -> bool: return Vector2(float(r.x)-c.x,float(r.z)-c.y).length() < c.z+2.0).size()
	check(on == records.size() and records.size() > 1000,"%s's grass grows on it (%d of %d tufts and flowers)" % [id,on,records.size()])
	var tokens: Array = isle.life.tokens.tokens
	var near := tokens.filter(func(t: Dictionary) -> bool: return Vector2((t.at as Vector3).x-c.x,(t.at as Vector3).z-c.y).length() < c.z+15.0).size()
	check(tokens.size() >= 4 and near == tokens.size(),"%s's foot tokens are on it (%d of %d)" % [id,near,tokens.size()])
	var birds: Node3D = isle.life.birds
	check(birds != null and not (birds.groups as Dictionary).is_empty(),"%s's songbirds have their perches (%d groups)" % [id,(birds.groups as Dictionary).size() if birds != null else 0])
	# Its turf, as the plane and the pilot meet it.
	var run_spot := _open_run(isle)
	check(not run_spot.is_empty(),"%s: open turf %d m long to land on" % [id,RUN])
	if run_spot.is_empty(): return
	var at: Vector3 = run_spot.at
	var way: Vector3 = run_spot.way
	var turn := Basis(Vector3.UP,atan2(-way.x,-way.z))
	check(not study._stone_at(at+Vector3.UP*0.6,turn),"%s's turf is no stone to the wheels" % id)
	# Landed by hand: nosed down onto the run, braked to a stop, out.
	if not study.flying: study.board()
	study.fly_from(at-way*4.0+Vector3.UP*2.0,atan2(-way.x,-way.z))
	# Slow, as one comes in to land on a small isle.
	study.plane.speed = SkyPlane.SLOW
	study.plane.velocity = study.plane.forward()*SkyPlane.SLOW
	var ml: RefCounted = study.hand_landing
	var t := 0.0
	while t < 3.0 and ml.flying():
		study.fly_step(DT,{"pitch":-0.6,"brake":1.0})
		t += DT
	check(ml.on_ground(),"%s: the plane touches down on its turf and sticks (%s)" % [id,str(ml.last_touch)])
	t = 0.0
	while study.flying and ml.phase == ManualLanding.ROLL and t < 8.0:
		study.fly_step(DT,{"brake":1.0})
		t += DT
	check(ml.phase == ManualLanding.STOPPED,"%s: braked, it stops on the turf" % id)
	study.fly_step(DT,{"exit":true})
	t = 0.0
	while study.flying and t < 3.0:
		study.fly_step(DT,{})
		t += DT
	check(not study.flying and study.parked,"%s: out, the plane parked on it" % id)
	for i in range(20): study.tick(DT)
	var feet: Vector3 = study.motor.feet
	check(study.motor.grounded and Vector2(feet.x-c.x,feet.z-c.y).length() < c.z,"%s: the pilot stands on it (%s)" % [id,str(feet)])
	# He walks off from the plane over the turf.
	var from: Vector3 = study.motor.feet
	study.script_want = Vector2(way.x,way.z)
	for i in range(int(1.5/DT)): study.tick(DT)
	study.script_want = Vector2.ZERO
	for i in range(20): study.tick(DT)
	var walked := Vector2(study.motor.feet.x-from.x,study.motor.feet.z-from.z).length()
	var now: Vector3 = study.motor.feet
	check(walked > 2.0 and study.motor.grounded and Vector2(now.x-c.x,now.z-c.y).length() < c.z+2.0,"%s: he walks on it (%.1f m, from %s to %s)" % [id,walked,str(from),str(now)])
	match id:
		"bell_spires": await _bells(isle)
		"cloister_tarn": _tarn(isle)
		_: pass
	_bridges(isle)
	study.board()

## The bells swing when the plane passes close.
func _bells(isle: Node3D) -> void:
	var bells: Array = isle.motif.bells
	var bell: Node3D = bells[0].node
	study.fly_from(bell.global_position+Vector3(-30.0,2.0,0.0),-PI*0.5)
	var most := 0.0
	for i in range(int(4.0/DT)):
		study.fly_step(DT,{})
		await process_frame
		most = maxf(most,absf(float(bells[0].angle)))
	check(most > 0.01,"The bell spires' bell swings as the plane passes (%.3f rad)" % most)

## The tarn's water is skimmed as the turf is.
func _tarn(isle: Node3D) -> void:
	var water: MeshInstance3D = isle.motif.water
	var box: AABB = water.global_transform*water.get_aabb()
	var middle := box.get_center()
	var under: Variant = study.plane_ground(Vector3(middle.x,box.end.y+3.0,middle.z))
	check(under != null and absf(float(under)-box.end.y) < 1.5,"The cloister tarn's water is skimmed (%s, its top %.1f)" % [str(under),box.end.y])

## Its rope bridges are live underfoot: in the scene's live set, their
## decks read at their place.
func _bridges(isle: Node3D) -> void:
	var mine := RopeBridge._live.filter(func(b: Node) -> bool: return is_instance_valid(b) and isle.art.is_ancestor_of(b))
	if mine.is_empty(): return
	var bridge: MeshInstance3D = mine[0]
	var mid: Vector3 = bridge.global_transform*((bridge.a as Vector3).lerp(bridge.b,0.5))
	var h: float = study.ground.height_from(Vector2(mid.x,mid.z),mid.y+1.0)
	check(is_finite(h) and absf(h-mid.y) < 1.5,"%s's rope bridges are live underfoot (%d; deck %.2f at its middle %.2f)" % [isle.motif.id(),mine.size(),h,mid.y])

## Open level turf on the isle a run long, clear of stone.
func _open_run(isle: Node3D) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var c: Vector3 = isle.circle()
	for gx in range(24):
		for gz in range(24):
			var x := c.x-c.z+gx*c.z/12.0
			var z := c.y-c.z+gz*c.z/12.0
			var top: Vector3 = study._turf_top(space,x,z)
			if top == Vector3.INF: continue
			for d in range(8):
				var way := Vector3(cos(TAU*d/8.0),0.0,sin(TAU*d/8.0))
				var ok := true
				for s in range(-6,18):
					var p := top+way*RUN*s/17.0
					var there: Vector3 = study._turf_top(space,p.x,p.z)
					if there == Vector3.INF or absf(there.y-top.y) > 0.6: ok = false
				if not ok: continue
				var turn := Basis(Vector3.UP,atan2(-way.x,-way.z))
				for s in range(-6,18):
					var p := top+way*RUN*s/17.0
					if study._stone_at(p+Vector3.UP*0.6,turn) or study._stone_at(p+Vector3.UP*2.5,turn): ok = false
				if ok: return {"at":top,"way":way}
	return {}
