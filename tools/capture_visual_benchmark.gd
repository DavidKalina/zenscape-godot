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
	for name in ["pond", "pond-no-reflections"]:
		study.scene._environment.ssr_enabled = name == "pond"
		study.reflection.visible = name == "pond"
		for i in range(40): await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png("res://docs/visual-benchmark/" + name + ".png")
	study.free()
	await process_frame
	quit()
