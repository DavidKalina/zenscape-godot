extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var weather = scene._precipitation
	var surface = weather.surface_weather
	weather.set_weather(7, true)
	scene._process(0.0)
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/autumn-checks.json"))
	check(surface.autumn == source.uAutumn, "Source autumn preset")
	for key in ["Sun", "Sky"]:
		var a = source["u" + key + "Color"]
		var expected := Vector3(a[0], a[1], a[2])
		check(scene._celestial.state["zs_cloud_" + key.to_lower()].distance_to(expected) < 0.00002, "Captured source autumn " + key + " color")
	# Matched source arch patch is warm stone. The old backface-normal bug
	# made this same visible face blue-black despite the warm light.
	# The DPI-scaled control panel would cover the sampled patch at this size.
	scene._ui.visible = false
	for i in range(30):
		RenderingServer.force_draw(false)
		await process_frame
	var image := root.get_texture().get_image()
	var arch := Vector3.ZERO
	for y in range(285, 297):
		for x in range(725, 765):
			var c := image.get_pixel(x, y)
			arch += Vector3(c.r, c.g, c.b)
	arch /= 480.0
	check(arch.x > arch.z * 1.25 and arch.x > 0.25, "Arch backface receives source-facing warm light: " + str(arch))
	weather.set_weather(0, true)
	weather.set_weather(7)
	surface.advance(1.0, true, 0.0, 0.3, 1.15)
	check(surface.autumn == 0.0, "Pause holds seasonal transition")
	surface.advance(1.0, false, 0.0, 0.3, 1.15)
	check(absf(surface.autumn - (1.0 - exp(-0.55))) < 0.00001, "Source seasonal response")
	weather.set_weather(3, true)
	check(surface.autumn == 1.0 and surface.cold == 1.0, "Snow settles onto turned foliage")
	var sky = scene._celestial
	sky.cloud = 0.3
	sky.storm = 0.0
	sky.autumn = 1.0
	sky.cold = 0.0
	sky.update_rig()
	var warm: Vector3 = sky.state.zs_hemi_sky
	sky.cold = 1.0
	sky.update_rig()
	check(sky.state.zs_hemi_sky.distance_to(warm.lerp(Vector3(0.62, 0.70, 0.85), 0.35)) < 0.00001, "Cold light is applied after autumn warmth")
	weather.set_weather(0, true)
	scene._process(0.0)
	check(surface.autumn == 0.0 and scene._autumn_slider.value == 0.0, "Clear resets season and control")
	scene.queue_free()
	await process_frame
	print("PASS: source autumn lighting, presets, transition, pause and cold ordering" if failures == 0 else "FAIL: autumn")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
