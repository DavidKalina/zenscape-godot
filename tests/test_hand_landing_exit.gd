extends SceneTree
## suite: slow serial
## Getting out after a hand landing in the real game, as
## ./run-manual-landing.command starts it (studies/cozy_worlds.tscn with
## --manual-landing --no-title --skydive, through scripts/launch_args.gd),
## headless:
##   - --skydive puts the eye in the plane high over home;
##   - landed soon after, while the mountain ranges round the world are still
##     being made on the workers (scripts/sky_peaks.gd), hot and sliding or
##     slow, braked to a stop, then F (the key's event) or the pad's Y gets
##     the pilot out beside the plane parked there;
##   - no frame of the get-out takes more than FRAME_MOST s. The glide's end
##     (SkyIslands `show_air(false)`, SkyPeaks `let_go`) used to wait on the
##     main thread for every range under way: 5 s to over 30 s, the game
##     frozen as the pilot got out, which the user force-quit.
##   - the range kept on the workers through the walk is not made again
##     (SkyPeaks `let_go`);
##   - quitting straight after, the workers still busy, does not crash the
##     engine's exit (the runner fails a crash at exit).
## A watchdog thread prints the stage when frames stop and kills the run
## after WATCHDOG_KILL s, so a freeze fails rather than hangs.
##   godot --headless --path . --script tests/test_hand_landing_exit.gd
const SkyPlane = preload("res://scripts/sky_plane.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const FRAME_MOST := 3.0
const WATCHDOG_KILL := 60.0
var failures := 0
var scene: Node3D
var eye: Node
var stage := "boot"
var _watch: Thread
var _watching := true
## The ranges on the workers as the first get-out ended ({key: task}), and
## how many of them the next glide started over.
var _kept := {}
var _restarted := 0

func _initialize() -> void:
	# The ranges being made are the ring's, kept but unwired: this runs
	# under --peak-ring.
	preload("res://scripts/sky_homes.gd").use_flags(PackedStringArray(["--peak-ring"]))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func frames(n: int) -> void:
	for i in range(n): await process_frame

## Frames until `done` (a Callable() -> bool), `most` game seconds at most.
func until(done: Callable, most: float) -> bool:
	var began := Time.get_ticks_msec()
	while not bool(done.call()):
		if (Time.get_ticks_msec()-began)/1000.0*Engine.time_scale > most: return false
		await process_frame
	return true

## Off the main thread: frames that stop advancing are a freeze.
func _watchdog() -> void:
	var last := -1
	var still := 0.0
	while _watching:
		OS.delay_msec(500)
		var now := Engine.get_process_frames()
		if now != last:
			still = 0.0
			last = now
			continue
		still += 0.5
		if stage != "boot" and is_equal_approx(fmod(still,2.0),0.0): print("WATCHDOG: no frame for %.0f s at '%s'" % [still,stage])
		if still >= WATCHDOG_KILL:
			print("FAIL: frozen at '%s'" % stage)
			OS.kill(OS.get_process_id())

func run() -> void:
	_watch = Thread.new()
	_watch.start(_watchdog)
	LaunchArgs.set_override(PackedStringArray(["--manual-landing","--no-title","--skydive"]))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("no_title",true)
	scene.places_path = OS.get_temp_dir().path_join("hand-landing-exit-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not (scene.places_ready and scene.shell_ready): await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	eye = scene.wanderer
	stage = "skydive start"
	var up: bool = await until(func() -> bool: return eye.active and eye.flying and eye.glide is SkyPlane,30.0)
	check(up and eye.manual and eye.hand_landing.flying(),"--skydive: in the plane over home, flown by hand")
	await frames(10)
	var outs := 0
	var busy_at_first := -1
	for i in range(8):
		var under_way: int = eye.islands.peaks._making.size()
		if not await _land(i): continue
		if outs == 0: busy_at_first = under_way
		await _get_out(i,outs == 0)
		outs += 1
		if outs == 1: _kept = _tasks()
		if outs >= 2: break
	check(outs >= 2,"Two landings stopped and got out of (%d)" % outs)
	check(busy_at_first > 0,"The first got out of with ranges still being made (%d)" % busy_at_first)
	check(not _kept.is_empty() and _restarted == 0,"Ranges kept on the workers through the walk, none made again in the next glide (%d kept, %d made again)" % [_kept.size(),_restarted])
	# Quit at once, the ranges and islands still on the workers, as a
	# player might: the quit waits for them (SkyIslands `_join_bakes`).
	stage = "quit"
	_watching = false
	_watch.wait_to_finish()
	LaunchArgs.set_override(null)
	print("PASS: hand landing exit" if failures == 0 else "FAIL: hand landing exit (%d)" % failures)
	quit(1 if failures else 0)

## The ranges being made on the workers: {key: task}.
func _tasks() -> Dictionary:
	var out := {}
	var making: Dictionary = eye.islands.peaks._making
	for key in making:
		if int(making[key].task) >= 0: out[key] = int(making[key].task)
	return out

## Down on a spot of the island at a heading: even tries hot (cruise) and
## slid with a turn and the brake, odd ones slow and braked straight. True
## once stopped on the wheels.
func _land(i: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000+i
	stage = "landing %d" % i
	var spot := Vector2.INF
	for k in range(200):
		var p := Vector2(rng.randf_range(-eye.PLATE_REACH,eye.PLATE_REACH),rng.randf_range(-eye.PLATE_REACH,eye.PLATE_REACH))
		if eye._on_land(p):
			spot = p
			break
	if spot == Vector2.INF: return false
	var heading := rng.randf_range(-PI,PI)
	var at: Vector3 = eye.editor.terrain.to_global(Vector3(spot.x,0.0,spot.y))
	var floor_y: float = eye._floor_global(Vector2(at.x,at.z))
	if not is_nan(floor_y): at.y = floor_y
	var hot := i % 2 == 0
	var pace := 14.0 if hot else 8.0
	eye._launch(pace,false,at+Vector3.UP*(SkyPlane.SKIM+0.2),heading)
	eye.glide.speed = pace
	eye.glide.pitch = -0.1
	eye.glide.velocity = eye.glide.forward()*pace
	eye._hand_begin()
	if not _kept.is_empty():
		# The glide's first survey, then any of them made again.
		await frames(3)
		var now := _tasks()
		for key in _kept:
			if now.has(key) and now[key] != _kept[key]: _restarted += 1
	Input.action_press(&"fly_brake")
	Input.action_press(&"move_forward",0.25)
	await frames(6)
	Input.action_release(&"move_forward")
	if hot: Input.action_press(&"move_right")
	var stopped: bool = await until(func() -> bool: return eye.hand_landing.phase == ManualLanding.STOPPED or (eye.hand_landing.flying() and eye.hand_landing.elapsed > 4.0),12.0)
	Input.action_release(&"move_right")
	Input.action_release(&"fly_brake")
	var s: Dictionary = eye.hand_landing.stats
	print("     try %d %s at %s: %s (touch %s, slid %.1f m)" % [i,"hot" if hot else "slow",str(spot),ManualLanding.NAMES[eye.hand_landing.phase],str(eye.hand_landing.last_touch),float(s.slide_distance)])
	return stopped and eye.hand_landing.phase == ManualLanding.STOPPED

## Out through the real input: F's key event, or the pad's Y; every frame
## from the press to well after timed.
func _get_out(i: int, by_key: bool) -> void:
	await frames(10)
	stage = "getting out %d" % i
	var press: InputEvent
	if by_key:
		var key := InputEventKey.new()
		key.keycode = KEY_F
		key.physical_keycode = KEY_F
		press = key
	else:
		var pad := InputEventJoypadButton.new()
		pad.button_index = JOY_BUTTON_Y
		press = pad
	press.pressed = true
	var longest := {"ms":0,"last":Time.get_ticks_msec()}
	var tick := func() -> void:
		var now := Time.get_ticks_msec()
		longest.ms = maxi(int(longest.ms),now-int(longest.last))
		longest.last = now
	Input.parse_input_event(press)
	await process_frame
	tick.call()
	var release: InputEvent = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	var out: bool = await until(func() -> bool:
		tick.call()
		return not eye.flying,6.0)
	stage = "on foot %d" % i
	for f in range(30):
		await process_frame
		tick.call()
	check(out and eye.active and not eye.flying and eye.has_parked() and eye.by_plane(),"Try %d, %s: out, beside the plane parked where it stopped" % [i,"F" if by_key else "pad Y"])
	check(int(longest.ms) <= FRAME_MOST*1000.0,"Try %d: no frame of the get-out over %.0f s (longest %d ms)" % [i,FRAME_MOST,int(longest.ms)])
