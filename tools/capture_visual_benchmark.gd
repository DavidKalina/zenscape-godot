extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(120).timeout.connect(func(): push_error("Benchmark timeout"); quit(2))
	root.size = Vector2i(1440, 900)
	var study = load("res://studies/visual_benchmark.tscn").instantiate()
	root.add_child(study)
	while not study.ready_for_capture: await process_frame
	study.scene._paused = true
	study.scene.set_process_input(false)
	study.scene.set_process_unhandled_input(false)
	study.scene.set_process(false)
	for enhanced in [false, true]:
		study.set_enhanced(enhanced)
		for i in range(40): await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://docs/visual-benchmark/" + ("enhanced" if enhanced else "control") + ".png")
	study.scene.target = Vector3(2, 2, 6)
	study.scene.distance = 14.0
	study.scene.polar = 1.18
	study.scene.yaw = -0.4
	study.scene._update_camera()
	RenderingServer.global_shader_parameter_set("zs_camera_position", study.scene.camera.global_position)
	for name in ["pond", "pond-no-reflections"]:
		for view in study.planar.views: view.material.set_shader_parameter("reflection_strength", 1.0 if name == "pond" else 0.0)
		for i in range(40): await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://docs/visual-benchmark/" + name + ".png")
	for view in study.planar.views: view.material.set_shader_parameter("reflection_strength", 1.0)
	study.scene.target = Vector3(1,2.5,1.5)
	study.scene.distance = 20.0
	study.scene.polar = 1.25
	study.scene.yaw = -0.7
	study.scene._update_camera()
	RenderingServer.global_shader_parameter_set("zs_camera_position", study.scene.camera.global_position)
	for i in range(40):
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://docs/visual-benchmark/hero.png")
	study.free()
	await process_frame
	quit()
