extends SceneTree
## The snag (scripts/snag_plane.gd, studies/snag_study.gd), headless:
##   - the plane's loop is closed and dips to `dip` m over the pier;
##   - the load lags the plane: round the lap it swings well off plumb, and
##     on the banked ends it hangs out of the turn;
##   - in the study, the pilot set where the load passes takes it: it is
##     off the rope, the plane lurches, and a new load hangs RESPAWN s on.
##   godot --headless --path . --script tests/test_snag.gd
const SnagPlane = preload("res://scripts/snag_plane.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("ok   " if ok else "FAIL ")+label)

func run() -> void:
	var ledge := Vector3(0.0,10.0,36.0)
	var a := SnagPlane.path_point(0.0,ledge,9.0)
	check(is_equal_approx(a.y,19.0) and a.distance_to(SnagPlane.path_point(TAU,ledge,9.0)) < 1e-3,"the loop closes and dips 9 m over the pier (%.2f)" % a.y)

	var snag: Node3D = SnagPlane.new()
	snag.setup(26.0,6.0,9.0,ledge,0.0)
	root.add_child(snag)
	snag.set_process(false)
	var most := 0.0
	var outward := 0
	var banked := 0
	for i in range(int(26.0*2.0/DT)):
		snag.advance(DT)
		if i < int(26.0/DT): continue
		most = maxf(most,snag.swing())
		if absf(snag.flight.bank) > 0.4:
			banked += 1
			var centre := ledge-Vector3(0.0,0.0,SnagPlane.RADII.y)
			var hook: Vector3 = snag.points[0]
			var end: Vector3 = snag.points[SnagPlane.LINKS]
			var out := Vector3(hook.x-centre.x,0.0,hook.z-centre.z).normalized()
			if (end-hook).dot(out) > 0.3: outward += 1
	check(most > deg_to_rad(12.0),"the load swings off plumb on the lap (most %.0f°)" % rad_to_deg(most))
	check(banked > 0 and outward > banked*0.6,"on the banked ends it hangs out of the turn (%d of %d frames)" % [outward,banked])
	snag.queue_free()

	var study: Node3D = load("res://studies/snag_study.tscn").instantiate()
	root.add_child(study)
	while not study.walk_ready: await process_frame
	study.scripted = true
	var s: Node3D = study.snag
	s.set_process(false)
	var took := false
	for i in range(240):
		s.advance(DT)
		study.motor.reset(s.load_point()+Vector3.DOWN*1.0,0.0)
		study.tick(DT)
		if not s.attached:
			took = true
			break
	check(took and study.got == 1,"set where the load passes, he takes it")
	check(s.get("_jolt") >= 0.0,"the plane lurches")
	for i in range(int((SnagPlane.RESPAWN+0.2)/DT)): s.advance(DT)
	check(s.attached and s.load_token != null,"a new load hangs on the rope after RESPAWN s")
	print("snag: %d failures" % failures)
	quit(1 if failures > 0 else 0)
