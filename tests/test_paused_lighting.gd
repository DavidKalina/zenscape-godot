extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = true
	var sky = scene._celestial
	sky.cycling = true
	sky.set_phase(0.5)
	var stopped_phase: float = sky.phase
	var stopped_time: float = scene._motion_time
	var stopped_bow: float = sky._rainbow_growth
	var clear_energy: float = scene._lights[0].light_energy
	scene._cloud_slider.value = 0.9
	scene._process(0.5)
	check(scene._lights[0].light_energy < clear_energy, "Paused cloud edit updates direct lighting")
	check(sky.state.zs_celestial_clear < 0.01, "Paused cloud edit updates celestial visibility")
	scene._cloud_slider.value = 0.0
	scene._process(0.5)
	check(scene._lights[0].light_energy >= clear_energy, "Clearing clouds restores lighting while paused")
	scene._aurora_slider.value = 1.8
	scene._process(0.5)
	check(is_equal_approx(sky.state.zs_aurora.x, 1.8), "Paused aurora slider publishes its value")
	check(sky.phase == stopped_phase and scene._motion_time == stopped_time and sky._rainbow_growth == stopped_bow, "Lighting refresh does not advance time or rainbow formation")
	var frozen_weather: Vector4 = scene._precipitation.state
	scene._precipitation.set_weather(2)
	scene._process(0.5)
	check(scene._precipitation.state == frozen_weather, "Animated weather transitions remain paused")
	scene.queue_free()
	await process_frame
	print("PASS: paused cloud/aurora edits refresh lighting without advancing animation" if failures == 0 else "FAIL: paused lighting")
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
