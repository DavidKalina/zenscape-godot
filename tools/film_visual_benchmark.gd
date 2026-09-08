extends SceneTree
## Matched six-second orbit; fixed simulation clocks, same geometry and camera.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(360).timeout.connect(func(): push_error("Film timed out"); quit(2))
	root.size = Vector2i(1440, 900)
	var study = load("res://studies/visual_benchmark.tscn").instantiate()
	root.add_child(study)
	while not study.ready_for_capture: await process_frame
	study.scene.set_process_input(false)
	study.scene.set_process_unhandled_input(false)
	study.scene._paused = true
	study.scene.set_process(false)
	study.caption.hide()
	for enhanced in [true, false]:
		study.set_enhanced(enhanced)
		var directory := "/private/tmp/zs-beauty-" + ("enhanced" if enhanced else "control")
		DirAccess.make_dir_recursive_absolute(directory)
		for frame in range(-40, 144):
			var t := maxf(frame, 0) / 24.0
			study.scene.yaw = -0.55 + t * 0.035
			study.scene._update_camera()
			RenderingServer.global_shader_parameter_set("zs_camera_position", study.scene.camera.global_position)
			RenderingServer.global_shader_parameter_set("zs_motion_time", t)
			RenderingServer.global_shader_parameter_set("zs_flow_time", t)
			study.scene._display_fog.update_view()
			await process_frame
			RenderingServer.force_draw(false, 1.0 / 24.0)
			if frame >= 0:
				root.get_texture().get_image().save_png(directory + "/%04d.png" % frame)
		print("FILMED ", directory)
	study.free()
	await process_frame
	quit()
