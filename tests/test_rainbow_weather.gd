extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = true
	scene._celestial.set_phase(0.35)
	scene._precipitation.cloud_override = 0.1
	var surface = scene._precipitation.surface_weather
	surface.air_wet = 0.8
	surface.cold = 0.0
	scene._process(0.0)
	check(scene._celestial.weather_bow > 0.5,"Warm clearing air produces a rainbow")
	surface.cold = 1.0
	scene._process(0.0)
	check(scene._celestial.weather_bow == 0.0,"Fully snowy conditions suppress automatic rainbows")
	surface.cold = 0.0
	scene._process(0.0)
	check(scene._celestial.weather_bow > 0.5,"Warm humid air restores the automatic rainbow")
	scene._celestial.rainbow_strength = 1.0
	surface.cold = 1.0
	scene._process(0.0)
	check(scene._celestial.state.zs_bow > 0.5,"Explicit Hold rainbow remains a creative override")
	scene._auto_orbit = true
	scene._face_rainbow()
	var sun: Vector3 = scene._celestial.state.zs_sun_direction
	var look: Vector3 = -scene.camera.global_basis.z
	check(Vector2(look.x,look.z).normalized().dot(-Vector2(sun.x,sun.z).normalized()) > 0.999,"Rainbow view faces the antisolar direction")
	var elevation := asin(sun.y)
	var top_arc := deg_to_rad(42.0)-elevation
	var vertical_view: float = PI/2.0-scene.polar
	check(top_arc < deg_to_rad(scene.camera.fov)*0.5-vertical_view,"Typical rainbow arc fits above the horizon in the camera")
	check(not scene._auto_orbit,"Rainbow view holds its orientation")
	scene.queue_free()
	await process_frame
	print("PASS: automatic rainbow weather and camera framing" if failures == 0 else "FAIL: rainbow weather")
	quit(1 if failures else 0)
