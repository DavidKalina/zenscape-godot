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
	scene._ui.hide()
	scene._atmosphere.set_fog(0.0)
	scene._atmosphere.set_haze(0.0)
	scene._celestial.inversion_enabled = false
	scene._process(0.0)
	var fog = scene._display_fog
	var plane := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(6.0, 6.0)
	plane.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.6, 0.2, 0.1)
	plane.material_override = material
	scene.camera.add_child(plane)
	plane.position.z = -10.0
	var before: Image = await rendered()
	var depth: Image = fog.depth.texture.get_image()
	var d := depth.get_pixel(720, 450).r
	var near: float = scene.camera.near
	var far: float = scene.camera.far
	var linear_depth := near * far / (near + d * (far - near))
	check(absf(linear_depth - 10.0) < 0.01, "Depth bridge reconstructs a plane ten units from camera: " + str(linear_depth))
	var partial := 0
	for y in range(depth.get_height()):
		for x in range(depth.get_width()):
			var coverage := depth.get_pixel(x, y).g
			if coverage > 0.0 and coverage < 1.0:
				partial += 1
	check(partial > 0, "Depth bridge preserves partial MSAA silhouette coverage")
	check(depth.get_pixel(10, 10).r == 0.0, "Sky retains the reverse-Z empty depth")
	var target := Vector3(0.2, 0.4, 0.6)
	fog.blend.set_shader_parameter("surface_density", 0.03)
	fog.blend.set_shader_parameter("aerial_gain", 0.0)
	fog.blend.set_shader_parameter("surface_fog_color", target)
	var after: Image = await rendered()
	var b := before.get_pixel(720, 450)
	var expected := Vector3(b.r, b.g, b.b).lerp(target, 1.0 - exp(-0.3 * 0.3))
	var actual := after.get_pixel(720, 450)
	check(Vector3(actual.r, actual.g, actual.b).distance_to(expected) < 0.012, "Haze blends after tone mapping using source exponential view depth")
	check(before.get_pixel(10, 10) == after.get_pixel(10, 10), "Surface haze leaves sky pixels unchanged")
	root.content_scale_size = Vector2i(960, 640)
	root.size = Vector2i(960, 640)
	await process_frame
	fog.update_view()
	await rendered()
	check(fog.depth.texture.get_width() == 960 and fog.depth.texture.get_height() == 640, "Depth bridge follows viewport resize: " + str(fog.depth.texture.get_size()))
	root.msaa_3d = Viewport.MSAA_DISABLED
	await rendered()
	var single: Image = fog.depth.texture.get_image()
	var single_d := single.get_pixel(480, 320).r
	check(absf(near * far / (near + single_d * (far - near)) - 10.0) < 0.01, "Single-sample depth path reconstructs the same plane")
	scene.queue_free()
	await process_frame
	print("PASS: surface depth, display-space haze, sky isolation and resize" if failures == 0 else "FAIL: surface haze")
	quit(1 if failures else 0)
func rendered() -> Image:
	for i in range(5):
		RenderingServer.force_draw(false)
		await process_frame
	return root.get_texture().get_image()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
