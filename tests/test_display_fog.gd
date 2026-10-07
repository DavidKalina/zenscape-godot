extends SceneTree
## suite: gpu
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
	check(fog.march.size == Vector2i(360, 225), "March lands on a quarter of the resolved pixels")
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
	fog.forget()
	await rendered(1)
	var fresh: Image = fog.buffer.get_texture().get_image()
	var landed: Image = fog.march.get_texture().get_image()
	var fresh_mean := mean_rgb(fresh)
	var landed_mean := mean_rgb(landed)
	check(absf(fresh_mean - landed_mean) < 0.02 * maxf(landed_mean, 0.05) + 0.002, "A fresh resolve passes the march through unconverted")
	await settled()
	var air: Image = fog.buffer.get_texture().get_image()
	var occupied := 0
	for y in range(air.get_height()):
		for x in range(air.get_width()):
			if air.get_pixel(x, y).a > 0.01:
				occupied += 1
	check(occupied > 1000, "Mist produces a nonempty opacity field")
	var hold := air
	await settled()
	var drift := mean_diff(hold, fog.buffer.get_texture().get_image())
	print("  paused field drift over a settled interval: %.5f mean" % drift)
	check(drift < 0.003, "Paused fog field holds within the temporal jitter")
	# Reproject the world-space volume, rather than leaving screen-space fog.
	var pose: Transform3D = scene.camera.global_transform
	scene.camera.rotate_object_local(Vector3.UP, PI)
	fog.update_view()
	await settled()
	var away: Image = fog.buffer.get_texture().get_image()
	var max_alpha := 0.0
	for y in range(away.get_height()):
		for x in range(away.get_width()):
			max_alpha = maxf(max_alpha, away.get_pixel(x, y).a)
	check(max_alpha == 0.0, "Looking away from the plot clears its fog")
	scene.camera.global_transform = pose
	fog.update_view()
	await settled()
	check(mean_diff(hold, fog.buffer.get_texture().get_image()) < 0.003, "Camera round trip restores the same world-space air")
	scene._growth.set_terrain(0.0)
	fog.update_view()
	await settled()
	check(mean_diff(hold, fog.buffer.get_texture().get_image()) > 0.005, "Fog occlusion follows the collapsed terrain")
	scene._growth.set_terrain(1.0)
	fog.update_view()
	await settled()
	check(mean_diff(hold, fog.buffer.get_texture().get_image()) < 0.003, "Restored terrain restores the fog field")
	scene._atmosphere.set_fog(0.0)
	scene._atmosphere.shroud = 1.0
	fog.update_view()
	await settled()
	var bank: Image = fog.buffer.get_texture().get_image()
	var full_mass := opacity_sum(bank)
	check(full_mass > 1000.0, "Shroud fills the lowland without mist")
	scene._atmosphere.shroud = 0.45
	fog.update_view()
	await settled()
	check(opacity_sum(fog.buffer.get_texture().get_image()) < full_mass * 0.85, "Lower coverage tears away the bank")
	scene._atmosphere.shroud = 1.0
	scene._atmosphere.loosen = 1.0
	fog.update_view()
	await settled()
	check(moved_fraction(bank, fog.buffer.get_texture().get_image()) > 0.002, "Fluidity changes the gust response")
	var flowing: Image = fog.buffer.get_texture().get_image()
	scene._atmosphere.send_gust(Vector3(0.0, 1.0, -8.0))
	scene._atmosphere._gust_distance += 5.0
	scene._atmosphere._publish_wind()
	fog.update_view()
	await settled()
	check(moved_fraction(flowing, fog.buffer.get_texture().get_image()) > 0.002, "Travelling wind changes the shroud field")
	scene.queue_free()
	await process_frame
	print("PASS: display fog color identity, alpha, pause, camera, growth, shroud, wind, resolution and layering" if failures == 0 else "FAIL: display fog")
	quit(1 if failures else 0)
func rendered(frames: int = 3) -> Image:
	for i in range(frames):
		RenderingServer.force_draw(false)
		await process_frame
	return root.get_texture().get_image()

## Enough frames for the temporal history to converge (0.88^48 is under 1%).
func settled() -> Image:
	return await rendered(48)

## Mean absolute channel difference: the temporal history leaves single
## pixels on the fog's silhouette jittering, so fields are judged as a whole.
func mean_diff(a: Image, b: Image) -> float:
	var total := 0.0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			total += absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) + absf(p.a - q.a)
	return total / (4.0 * a.get_width() * a.get_height())

## Fraction of pixels whose summed channel change exceeds 0.2: settled jitter
## moves 0.05%, a fluidity change 0.4%, a travelling gust 4%.
func moved_fraction(a: Image, b: Image) -> float:
	var moved := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) + absf(p.a - q.a) > 0.2:
				moved += 1
	return float(moved) / (a.get_width() * a.get_height())

func mean_rgb(frame: Image) -> float:
	var total := 0.0
	for y in range(frame.get_height()):
		for x in range(frame.get_width()):
			var p := frame.get_pixel(x, y)
			total += p.r + p.g + p.b
	return total / (3.0 * frame.get_width() * frame.get_height())
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
