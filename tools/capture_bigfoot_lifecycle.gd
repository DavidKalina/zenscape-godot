extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._ui.hide()
	var encounter = scene._bigfoot
	var camera: Camera3D = scene.camera
	camera.global_position = encounter._frame.to_global(Vector3(0.08,2.45,5.75))
	camera.look_at(encounter._frame.to_global(Vector3(0,1.85,-0.65)))
	RenderingServer.global_shader_parameter_set("zs_camera_position", camera.global_position)
	encounter.random_value = func(): return 0.0
	# Capture exercises real admission/removal but never consumes user cooldown.
	encounter.reserve = func(_next_at, _now): return true
	encounter.check_in = 0.0
	encounter.advance(0.0,false,camera.global_position,camera)
	assert(encounter.active and not encounter.forced)
	if scene._display_fog != null:
		scene._display_fog.update_view()
	var directory := "/private/tmp/bigfoot-automatic-frames"
	DirAccess.make_dir_recursive_absolute(directory)
	for i in range(450):
		encounter.advance(1.0/30.0,false,camera.global_position,camera)
		RenderingServer.force_draw(false)
		await process_frame
		root.get_texture().get_image().save_jpg(directory.path_join("%04d.jpg" % i),0.94)
	print("Automatic encounter film: 15 seconds, active=", encounter.active, ", played=", encounter.played)
	scene.queue_free()
	await process_frame
	quit()
