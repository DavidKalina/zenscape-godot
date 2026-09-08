extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var study = load("res://studies/visual_benchmark.tscn").instantiate()
	root.add_child(study)
	while not study.ready_for_capture: await process_frame
	var scene = study.scene
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene.set_process(false)
	study.caption.hide()
	scene._update_leaf_litter(0.0)
	var litter = scene._leaf_litter
	assert(not litter.leaves.is_empty())
	var home := Vector3.ZERO
	scene.target = Vector3(1,2.2,3.5)
	scene.distance = 25.0
	scene.yaw = -0.45
	scene.polar = 1.0
	scene._update_camera()
	var original: Array = litter.leaves.duplicate(true)
	var air = scene._atmosphere
	# Reset decorative trails so both reels use the same random sequence.
	var trails = air.wind_trails
	for effect in [true,false]:
		for parcel in trails.parcels: parcel.node.free()
		trails.parcels.clear()
		trails._rng.seed = 91623
		trails._until_birth = 0.4
		trails.opacity_scale = 0.45 if effect else 1.0
		trails.width_scale = 0.65 if effect else 1.0
		trails.interval_scale = 1.6 if effect else 1.0
		study.mist.material.set_shader_parameter("density",0.145 if effect else 0.17)
		scene._waterfall_drips.clock = 0.0
		scene._waterfall_drips._draw()
		var dir := "/private/tmp/zs-tuning-"+("effect" if effect else "control")
		DirAccess.make_dir_recursive_absolute(dir)
		litter.leaves = original.duplicate(true)
		litter._clock = 0.0
		litter._accumulator = 0.0
		air.puffs.parcels.fill(Vector4.ZERO)
		air._wind_time = 0.0
		air._gust_distance = 0.0
		air._travel = Vector2.ZERO
		air._cloud_drift = Vector3.ZERO
		air.strength = 1.3
		air._air_strength = 1.3
		air._air_angle = 0.0
		air.direction_angle = 0.0
		var lifted := 0
		for frame in range(-20,192):
			if frame == 12: air.send_gust(home)
			if frame >= 0:
				air.advance(1.0/24.0,false)
				litter.advance(1.0/24.0,false,air)
				scene._waterfall_drips.advance(1.0/24.0,false)
			for leaf in litter.leaves:
				if leaf.airborne: lifted += 1
			RenderingServer.global_shader_parameter_set("zs_camera_position",scene.camera.global_position)
			RenderingServer.global_shader_parameter_set("zs_motion_time",maxf(frame,0)/24.0)
			RenderingServer.global_shader_parameter_set("zs_flow_time",maxf(frame,0)/24.0)
			scene._display_fog.update_view()
			await process_frame
			RenderingServer.force_draw(false)
			if frame>=0: root.get_texture().get_image().save_png(dir+"/%04d.png" % frame)
		print("TUNING FILM ",effect," leaf count=",litter.leaves.size()," lifted leaf-frames=",lifted," home=",home)
	study.free()
	await process_frame
	quit()
