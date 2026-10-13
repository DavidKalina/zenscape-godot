extends SceneTree
## The dragon's grip in the vision greybox (studies/dragon_vision_study.gd,
## docs/design/dragon-grip/round2-greybox.md), headless, through the real
## play loop: the study's own `_process` frames, the motor stepping on the
## isle's collision, with --attack=grip --grip-now. The pilot is set down on
## home near the rim he is coming to grip, then left standing:
##   - the slam staggers him (a stun, the dragon its source);
##   - the isle tips (the slam's steep moment) and he rides it: never
##     through its turf, carried while it is held;
##   - the gale and the last haul come (the tells), he lets go, and the snap
##     throws him: a hard stun, laid down where he lands, then up;
##   - no two of the dragon's stuns closer than the motor's restun gap;
##   - the dragon rejoins his loop.
##   godot --headless --path . --script tests/test_dragon_grip_stun.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(150.0).timeout.connect(func() -> void: push_error("dragon grip test timed out"); quit(2))
	LaunchArgs.set_override(["--no-title","--attack=grip","--grip-now"])
	var study: Node3D = load("res://studies/dragon_vision_study.tscn").instantiate()
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	var m: PilotMotor = study.motor
	var dragon: Node3D = study.dragon
	var top: float = (study.start as Vector3).y
	var beats: Array = []
	dragon.grip_beat.connect(func(what: String) -> void: beats.append(what))
	# On his way in: the pilot set down 10 m in from the rim, 5 m aside.
	var t := 0.0
	while dragon.grip.is_empty() and t < 10.0:
		await process_frame
		t += root.get_process_delta_time()
	check(not dragon.grip.is_empty() and str(dragon.grip.target.name) == "home","--grip-now: he comes in to grip home")
	if dragon.grip.is_empty():
		quit(1)
		return
	var rim: Vector3 = dragon.grip.rim
	var out: Vector3 = dragon.grip.out
	var tangent: Vector3 = dragon.grip.tangent
	var spot := rim-out*10.0+tangent*5.0
	m.feet = Vector3(spot.x,top+0.05,spot.z)
	m.velocity = Vector3.ZERO
	var isle: Node3D = study.get("_isle_nodes").home
	# Through the grip and a while after.
	var stuns: Array = []
	var was := m.stunned
	var downed_after_throw := false
	var up_after_throw := -1.0
	var thrown_at := -1.0
	var most_tip := 0.0
	var deepest := INF
	var held_frames := 0
	var carried_frames := 0
	var end := INF
	t = 0.0
	while t < 90.0 and t < end:
		await process_frame
		var dt := root.get_process_delta_time()
		t += dt
		if m.stunned == "knock" and was != "knock": stuns.append(t)
		was = m.stunned
		most_tip = maxf(most_tip,rad_to_deg(dragon.gale.tip()))
		# Over home's outline, his feet against its tipped top (its rest
		# frame's TOP).
		var local: Vector3 = isle.transform.affine_inverse()*m.feet
		if absf(local.x) < 41.0 and absf(local.z) < 41.0 and local.y < top+0.5: deepest = minf(deepest,local.y-top)
		if dragon.state == "clinging" and m.grounded and dragon.gale.phase == "held":
			held_frames += 1
			if dragon.gale.stands_on(m.feet,1.5): carried_frames += 1
		if "thrown" in beats and thrown_at < 0.0: thrown_at = t
		if thrown_at >= 0.0:
			if m.downed(): downed_after_throw = true
			if downed_after_throw and up_after_throw < 0.0 and m.move != "tumble" and not m.downed(): up_after_throw = t-thrown_at
			if up_after_throw >= 0.0 and dragon.state == "roaming" and end == INF: end = t+1.0
		if thrown_at < 0.0 and "let go" in beats and dragon.state == "roaming" and end == INF: end = t+1.0
	print("grip: beats %s, stuns at %s, tip at most %.1f°, deepest %.2f m, carried %d/%d held frames, dragon staggered %d knocks %d launched %d" % [str(beats),str(stuns),most_tip,deepest,carried_frames,held_frames,dragon.staggered,dragon.knocks,dragon.launched])
	check(beats.size() > 0 and beats[0] == "grab","he slams onto home's rim")
	check(dragon.staggered == 1 and stuns.size() >= 1,"the slam staggers him near the rim: a stun")
	check(most_tip >= 15.0,"the isle tips under him (%.1f° at most)" % most_tip)
	check(deepest > -0.35,"he never sinks into the tipping turf (%.2f m at worst)" % deepest)
	check(held_frames > 60 and carried_frames >= held_frames*0.9,"standing on it while held, he rides it (%d of %d frames)" % [carried_frames,held_frames])
	check("inhale" in beats and "pull" in beats and "let go" in beats,"the tells come: the inhale, the last haul, then he lets go")
	check(dragon.launched >= 1 and "thrown" in beats,"the snap throws him")
	check(downed_after_throw and up_after_throw > 0.0 and up_after_throw < 10.0,"thrown, he is laid down where he lands, then up (%.1f s after the throw)" % up_after_throw)
	var gap_ok := true
	for i in range(1,stuns.size()): gap_ok = gap_ok and float(stuns[i])-float(stuns[i-1]) >= m.restun_gap-0.05
	check(gap_ok,"no two of his stuns within the restun gap (%s)" % str(stuns))
	check(dragon.state == "roaming" and dragon.grip.is_empty() and dragon.leg_kind == "low pass","he rejoins his loop")
	LaunchArgs.set_override(null)
	print("dragon grip stun: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
