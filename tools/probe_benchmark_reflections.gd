extends SceneTree
func _initialize() -> void: run.call_deferred()
func shot(path: String) -> void:
	for i in range(30):
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size = Vector2i(1440,900)
	var study = load("res://studies/visual_benchmark.tscn").instantiate()
	root.add_child(study)
	while not study.ready_for_capture: await process_frame
	study.scene.set_process(false)
	study.scene.set_process_input(false)
	study.scene.set_process_unhandled_input(false)
	study.scene.target = Vector3(-0.7,1.8,5.6)
	study.scene.distance = 13.0
	study.scene.polar = 1.22
	study.scene.yaw = 0.15
	study.scene._update_camera()
	RenderingServer.global_shader_parameter_set("zs_camera_position", study.scene.camera.global_position)
	study.mist.hide()
	study.scene._environment.volumetric_fog_enabled = false
	study.set_process(false)
	await shot("/private/tmp/water-shader.png")
	var mirror := StandardMaterial3D.new()
	mirror.albedo_color = Color.WHITE
	mirror.metallic = 1.0
	mirror.roughness = 0.02
	for item in study.water:
		var arrays = item.node.mesh.surface_get_arrays(0)
		var indices := PackedInt32Array()
		for i in range(0, arrays[Mesh.ARRAY_VERTEX].size(), 3): indices.append_array([i, i+2, i+1])
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, item.node.mesh.surface_get_format(0))
		item.node.mesh = mesh
		item.node.material_override = mirror
	await shot("/private/tmp/water-mirror.png")
	study.scene._environment.ssr_enabled = false
	study.reflection.hide()
	await shot("/private/tmp/water-mirror-sky.png")
	study.free()
	await process_frame
	quit()
