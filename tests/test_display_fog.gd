extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440, 900)
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = true
	scene._ui.visible = false
	var fog = scene._display_fog
	if fog == null:
		push_error("The default Forward+ fog compositor is missing")
		quit(1)
		return
	scene._atmosphere.set_fog(0.0)
	scene._atmosphere.set_haze(0.0)
	scene._celestial.inversion_enabled = false
	scene._process(0.0)
	scene.get_node("WaterfallSpray").visible = false
	check(not scene._environment.volumetric_fog_enabled, "No double application of native fog")
	check(fog.layer < scene._ui.layer, "Fog composites below controls")
	check(fog.buffer.size == Vector2i(720, 450), "Source half-resolution air buffer")
	fog.visible = false
	var before: Image = await rendered()
	fog.visible = true
	var after: Image = await rendered()
	for point in [Vector2i(10, 10), Vector2i(700, 800), Vector2i(650, 350), Vector2i(1300, 700)]:
		var a := before.get_pixelv(point)
		var b := after.get_pixelv(point)
		check(Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) < 0.02, "Empty air preserves scene color")
	scene._atmosphere.set_fog(0.8)
	fog.update_view()
	await rendered()
	var air: Image = fog.buffer.get_texture().get_image()
	var occupied := 0
	for y in range(air.get_height()):
		for x in range(air.get_width()):
			if air.get_pixel(x, y).a > 0.01:
				occupied += 1
	check(occupied > 1000, "Mist produces a nonempty opacity field")
	var hold := air.get_data()
	await rendered()
	check(hold == fog.buffer.get_texture().get_image().get_data(), "Paused fog field holds exactly")
	# Reproject the world-space volume, rather than leaving screen-space fog.
	var pose: Transform3D = scene.camera.global_transform
	scene.camera.rotate_object_local(Vector3.UP, PI)
	fog.update_view()
	await rendered()
	var away: Image = fog.buffer.get_texture().get_image()
	var max_alpha := 0.0
	for y in range(away.get_height()):
		for x in range(away.get_width()):
			max_alpha = maxf(max_alpha, away.get_pixel(x, y).a)
	check(max_alpha == 0.0, "Looking away from the plot clears its fog")
	scene.camera.global_transform = pose
	fog.update_view()
	await rendered()
	check(hold == fog.buffer.get_texture().get_image().get_data(), "Camera round trip restores the same world-space air")
	scene._growth.set_terrain(0.0)
	fog.update_view()
	await rendered()
	check(hold != fog.buffer.get_texture().get_image().get_data(), "Fog occlusion follows the collapsed terrain")
	scene._growth.set_terrain(1.0)
	fog.update_view()
	await rendered()
	check(hold == fog.buffer.get_texture().get_image().get_data(), "Restored terrain restores the fog field")
	scene._atmosphere.set_fog(0.0)
	scene._atmosphere.shroud = 1.0
	fog.update_view()
	await rendered()
	var bank: Image = fog.buffer.get_texture().get_image()
	var full_mass := opacity_sum(bank)
	check(full_mass > 1000.0, "Shroud fills the lowland without mist")
	scene._atmosphere.shroud = 0.45
	fog.update_view()
	await rendered()
	check(opacity_sum(fog.buffer.get_texture().get_image()) < full_mass * 0.85, "Lower coverage tears away the bank")
	scene._atmosphere.shroud = 1.0
	scene._atmosphere.loosen = 1.0
	fog.update_view()
	await rendered()
	check(bank.get_data() != fog.buffer.get_texture().get_image().get_data(), "Fluidity changes the gust response")
	var flowing: PackedByteArray = fog.buffer.get_texture().get_image().get_data()
	scene._atmosphere.send_gust(Vector3(0.0, 1.0, -8.0))
	scene._atmosphere._gust_distance += 5.0
	scene._atmosphere._publish_wind()
	fog.update_view()
	await rendered()
	check(flowing != fog.buffer.get_texture().get_image().get_data(), "Travelling wind changes the shroud field")
	scene.queue_free()
	await process_frame
	print("PASS: display fog color identity, alpha, pause, camera, growth, shroud, wind, resolution and layering" if failures == 0 else "FAIL: display fog")
	quit(1 if failures else 0)
func rendered() -> Image:
	for i in range(3):
		RenderingServer.force_draw(false)
		await process_frame
	return root.get_texture().get_image()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func opacity_sum(frame: Image) -> float:
	var mass := 0.0
	for y in range(frame.get_height()):
		for x in range(frame.get_width()):
			mass += frame.get_pixel(x, y).a
	return mass
