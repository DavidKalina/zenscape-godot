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
	scene._ui.hide()
	scene.get_node("Reference").hide()
	scene._atmosphere.set_fog(0.0)
	scene._atmosphere.set_haze(0.0)
	scene._celestial.inversion_enabled = false
	scene._process(0.0)
	var fog = scene._display_fog
	# Isolate the surface treatment from the separate marched air volume.
	var empty := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	empty.fill(Color(0, 0, 0, 0))
	fog.blend.set_shader_parameter("air_color", ImageTexture.create_from_image(empty))
	var plane := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(6, 6)
	plane.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("base_color", Color(0.6, 0.2, 0.1))
	plane.material_override = material
	scene.camera.add_child(plane)
	plane.position.z = -10.0
	scene.camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 10))
	RenderingServer.global_shader_parameter_set("zs_camera_position", scene.camera.global_position)
	# Three-unit relief: lid 1.65, band .6, surface .1 -> depth 1.67.
	RenderingServer.global_shader_parameter_set("zs_summit", Vector4(0, 3.15, 0, 0))
	RenderingServer.global_shader_parameter_set("zs_inversion", Vector2.ZERO)
	var tint := Vector3(0.2, 0.7, 0.85)
	RenderingServer.global_shader_parameter_set("zs_inversion_color", tint)
	fog.update_view()
	fog.blend.set_shader_parameter("surface_density", 0.03)
	fog.blend.set_shader_parameter("aerial_gain", 0.0)
	fog.blend.set_shader_parameter("surface_fog_color", Vector3(0.8, 0.2, 0.3))
	var before: Image = await rendered()
	RenderingServer.global_shader_parameter_set("zs_inversion", Vector2(0.9, 0.5))
	var after: Image = await rendered()
	var b := before.get_pixel(720, 450)
	var expected := Vector3(b.r, b.g, b.b).lerp(tint, 1.0 - exp(-1.67 * 0.9))
	var a := after.get_pixel(720, 450)
	check(Vector3(a.r, a.g, a.b).distance_to(expected) < 0.012, "Inversion mixes over the hazed display pixel: actual " + str(a) + " expected " + str(expected) + " before " + str(b))
	check(before.get_pixel(10, 10) == after.get_pixel(10, 10), "Surface inversion leaves sky unchanged")
	# A deliberate double application must separate from the expected result.
	RenderingServer.global_shader_parameter_set("zs_surface_post", false)
	var doubled: Image = await rendered()
	var c := doubled.get_pixel(720, 450)
	check(Vector3(c.r, c.g, c.b).distance_to(expected) > 0.025, "Regression detects an active HDR tint beneath the display tint")
	RenderingServer.global_shader_parameter_set("zs_surface_post", true)
	scene.camera.global_position.y = 3.0
	RenderingServer.global_shader_parameter_set("zs_camera_position", scene.camera.global_position)
	fog.update_view()
	var above: Image = await rendered()
	RenderingServer.global_shader_parameter_set("zs_inversion", Vector2.ZERO)
	var clear: Image = await rendered()
	check(above.get_pixel(720, 450) == clear.get_pixel(720, 450), "Surfaces above the lid band remain clear")
	scene.camera.global_position.y = -0.5
	RenderingServer.global_shader_parameter_set("zs_camera_position",scene.camera.global_position)
	fog.update_view()
	var base_clear: Image = await rendered()
	RenderingServer.global_shader_parameter_set("zs_inversion",Vector2(0.9,0.5))
	var base_mist: Image = await rendered()
	check(base_clear.get_pixel(720,450) == base_mist.get_pixel(720,450),"Morning mist does not whiten the exposed base")
	# Positive-height island sides also lie outside the fog footprint.
	scene.camera.global_position = Vector3(0,0.1,24)
	RenderingServer.global_shader_parameter_set("zs_camera_position",scene.camera.global_position)
	fog.update_view()
	var edge_mist: Image = await rendered()
	RenderingServer.global_shader_parameter_set("zs_inversion",Vector2.ZERO)
	var edge_clear: Image = await rendered()
	check(edge_mist.get_pixel(720,450) == edge_clear.get_pixel(720,450),"Surface inversion fades out with the air at the island edge")
	scene.queue_free()
	await process_frame
	print("PASS: source inversion surface depth, display order, no double tint and sky/peak isolation" if failures == 0 else "FAIL: inversion surface")
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
