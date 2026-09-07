extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var weather = scene._precipitation
	var air = scene._atmosphere
	for i in range(weather.PRESET_NAMES.size()):
		weather.set_weather(i, true)
		var source: Dictionary = weather.profiles[weather.PRESET_NAMES[i]]
		check(weather.state.is_equal_approx(Vector4(source.rain, 0, source.cloud, source.storm)), "Source precipitation preset " + weather.PRESET_NAMES[i])
		check(is_equal_approx(air._air_strength, source.wind) and is_equal_approx(air.fog_amount, source.mist) and is_equal_approx(air.haze_amount, source.haze), "Preset drives wind, mist and haze")
		check(is_equal_approx(weather.surface_weather.cold, source.cold), "Preset cold phase")
		check(is_equal_approx(weather.surface_weather.autumn, source.autumn), "Preset autumn turn")
	weather.set_weather(0, true)
	weather.set_weather(2)
	scene._paused = true
	scene._process(1.0)
	check(is_equal_approx(air._air_strength, 0.5) and weather.state.x == 0.0, "Pause holds every weather channel")
	scene._paused = false
	scene._process(1.0)
	check(absf(air._air_strength - (2.5 - 2.0 * exp(-0.55))) < 0.00001, "Wind follows source easing")
	check(absf(weather.state.x - (1.0 - exp(-0.55))) < 0.00001, "Rain follows same source easing")
	check(scene._wind_slider.max_value >= 2.5 and scene._wind_slider.value == 2.5, "UI can represent storm strength")
	scene._set_wind(0.3)
	air.set_fog(0.2)
	air.set_haze(0.1)
	scene._process(1.0)
	check(air.strength == 0.3 and is_equal_approx(air.fog_amount, 0.2), "Manual adjustments persist after preset selection")
	weather.set_weather(2, true)
	check(air.strength == 2.5 and is_equal_approx(air.fog_amount, 0.42), "Selecting a new preset restores its full weather")
	scene.queue_free()
	await process_frame
	print("PASS: source weather presets, linked air, easing, pause and manual controls" if failures == 0 else "FAIL: weather profiles")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
