extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var air = scene._atmosphere
	var sky = scene._celestial
	var weather = scene._precipitation
	weather.set_weather(0, true)
	weather.surface_weather.air_wet = 1.0
	sky.rainbow_strength = 0.0
	air.shroud = 0.0
	scene._process(0.0)
	var energy: float = sky._sun.light_energy
	var sun_color: Vector3 = sky.state.zs_cloud_sun
	var sky_color: Vector3 = sky.state.zs_cloud_sky
	var dome: Vector3 = sky.state.zs_sky_up
	var bow: float = sky.weather_bow
	check(bow > 0.9, "Wet clear daylight produces an automatic bow")
	for coverage in [0.25, 0.5, 1.0]:
		air.shroud = coverage
		scene._process(0.0)
		check(absf(sky._sun.light_energy / energy - lerpf(1.0, 0.86, coverage)) < 0.00001, "Source shroud sun attenuation")
		check(absf(sky.weather_bow - bow * (1.0 - coverage)) < 0.00001, "Shroud suppresses automatic rainbow")
		check(sky.state.zs_cloud_sky == sky_color and sky.state.zs_sky_up == dome, "Shroud leaves hemisphere tint and dome unchanged")
		var clear_dim: float = lerpf(1.0, 0.44, sky.cloud)
		var expected := sun_color * ((0.9 + 0.5 * clear_dim * lerpf(1.0, 0.86, coverage)) / (0.9 + 0.5 * clear_dim))
		check(sky.state.zs_cloud_sun.distance_to(expected) < 0.00001, "Air scattering follows the same source sun dimming")
	sky.rainbow_strength = 0.7
	scene._process(0.0)
	check(sky.state.zs_bow > 0.69, "Explicit rainbow dial remains a floor under full shroud")
	air.shroud = 0.0
	scene._process(0.0)
	check(is_equal_approx(sky._sun.light_energy, energy), "Clearing the bank restores daylight")
	scene.queue_free()
	await process_frame
	print("PASS: shroud daylight, scattering, sky isolation and rainbow coupling" if failures == 0 else "FAIL: shroud weather")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
