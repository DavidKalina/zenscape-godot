extends SceneTree
## The scene's celestial rig, presets and save file all read the same clock.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var clock: WorldClock = scene.get("world_clock")
	check(clock != null, "The scene exposes world_clock")
	check(scene._celestial.clock == clock, "The celestial rig reads the scene's clock")

	# The day/night checkbox is the clock's running flag.
	scene._celestial.cycling = false
	check(not clock.running, "Cycling off stops the clock")
	scene._celestial.cycling = true
	check(clock.running and scene._celestial.cycling, "Cycling on runs the clock")

	clock.set_time(0, 6.0)
	clock.speed = 1.0
	scene._process(0.0)
	check(absf(scene._celestial.phase - clock.phase) < 1e-9, "Phase is the clock's phase")
	check(absf(scene._celestial.phase - 0.25) < 0.001, "Hour 6 renders the sunrise phase")

	# Fixed deltas: the rig tracks the clock exactly, every frame.
	var tracked := true
	var lit := true
	for i in range(120):
		scene._process(1.0 / 60.0)
		if absf(scene._celestial.phase - clock.phase) > 1e-9: tracked = false
		if absf(float(scene._celestial.state.zs_daylight) - clock.daylight) > 1e-5: lit = false
	check(tracked, "Celestial phase tracks the clock across frames")
	check(lit, "Published daylight matches the clock's daylight")
	check(clock.day == 0 and absf(clock.hour - (6.0 + 2.0 * 24.0 / clock.day_length)) < 1e-6, "Two seconds of frames advance two seconds of world time")
	var slow := clock.hour
	scene._paused = true
	for i in range(30): scene._process(1.0 / 60.0)
	check(clock.hour == slow, "A paused scene freezes the clock")
	scene._paused = false
	clock.speed = 12.0
	for i in range(60): scene._process(1.0 / 60.0)
	check(absf((clock.hour - slow) - 12.0 * 24.0 / clock.day_length) < 1e-6, "The speed selector multiplies world time")
	clock.speed = 1.0

	# N still snaps to the next quarter, through the clock, cycling or not.
	scene._celestial.cycling = false
	clock.set_time(1, 7.0)
	scene._celestial.next_hour()
	check(absf(clock.target_hour - 12.0) < 1e-9, "next_hour targets the next quarter day")
	for i in range(600): scene._process(1.0 / 60.0)
	check(clock.target_hour < 0.0 and absf(clock.hour - 12.0) < 1e-6 and absf(scene._celestial.phase - 0.5) < 0.001, "The skip settles on noon")

	# Authored moods and presets place the clock, not just the sun.
	scene._celestial.set_phase(0.62)
	check(absf(clock.phase - 0.62) < 0.001 and absf(clock.hour - WorldClock.hour_for_phase(0.62)) < 1e-9, "An authored phase moves the clock")
	preload("res://scripts/scene_look_presets.gd").apply(scene, "golden_meadow")
	var wanted: float = preload("res://scripts/scene_look_presets.gd").recipe("golden_meadow").phase
	check(absf(clock.phase - wanted) < 0.002, "A look preset lands on its authored hour")

	# The garden file remembers the day.
	clock.set_time(4, 17.5)
	clock.speed = 4.0
	clock.running = true
	scene._process(0.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(NativeGardenStore.capture(scene)))
	check(NativeGardenStore.valid(scene, saved), "A saved garden with a clock validates")
	clock.set_time(0, 2.0)
	clock.speed = 1.0
	NativeGardenStore.restore(scene, saved)
	check(clock.day == 4 and absf(clock.hour - 17.5) < 1e-6 and clock.speed == 4.0 and clock.running, "The store reopens the same day and hour")
	check(absf(scene._celestial.phase - clock.phase) < 1e-9, "The restored rig shows the restored hour")

	# Gardens saved before the clock existed still open, on day 0.
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("world_clock")
	check(NativeGardenStore.valid(scene, legacy), "A garden saved before the clock validates")
	clock.set_time(9, 3.0)
	NativeGardenStore.restore(scene, legacy)
	check(clock.day == 0 and absf(clock.phase - WorldClock.phase_for_hour(17.5)) < 0.001, "A legacy garden derives its hour from the stored phase")

	scene.queue_free()
	await process_frame
	print("PASS: scene clock drives celestial, presets, N and the garden file" if failures == 0 else "FAIL: world clock scene")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	print("FAIL: ", message)
	push_error(message)
