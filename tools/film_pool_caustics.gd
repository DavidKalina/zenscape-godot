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
	var drips = scene._waterfall_drips
	var home := Vector3(-0.7,1.3,5.6)
	scene.target = home
	scene.distance = 7.0
	scene.yaw = -0.45
	scene.polar = 0.72
	scene._update_camera()
	var original: Array = litter.leaves.duplicate(true)
	var air = scene._atmosphere
	# Decorative trails have their own random lifecycle; hide them in both reels.
	if air.wind_trails != null: air.wind_trails.hide()
	for effect in [true,false]:
		study.get_meta("caustics_material").set_shader_parameter("caustics_strength",0.45 if effect else 0.0)
		drips.clock = 0.0
		drips._draw()
		var dir := "/private/tmp/zs-caustics-"+("effect" if effect else "control")
		DirAccess.make_dir_recursive_absolute(dir)
		litter.leaves = original.duplicate(true)
		litter._clock = 0.0
		litter._accumulator = 0.0
		air.puffs.parcels.fill(Vector4.ZERO)
		air._wind_time = 0.0
		air._gust_distance = 0.0
		air._travel = Vector2.ZERO
		air._cloud_drift = Vector3.ZERO
		air.strength = 0.35
		air._air_strength = 0.35
		air._air_angle = 0.0
		air.direction_angle = 0.0
		var lifted := 0
		for frame in range(-20,192):

			if frame >= 0:
				air.advance(1.0/24.0,false)
				litter.advance(1.0/24.0,false,air)
				drips.advance(1.0/24.0,false)
			for leaf in litter.leaves:
				if leaf.airborne: lifted += 1
			RenderingServer.global_shader_parameter_set("zs_camera_position",scene.camera.global_position)
			RenderingServer.global_shader_parameter_set("zs_motion_time",maxf(frame,0)/24.0)
			RenderingServer.global_shader_parameter_set("zs_flow_time",maxf(frame,0)/24.0)
			scene._display_fog.update_view()
			await process_frame
			RenderingServer.force_draw(false)
			if frame>=0: root.get_texture().get_image().save_png(dir+"/%04d.png" % frame)
		print("CAUSTICS FILM ",effect," leaf count=",litter.leaves.size()," lifted leaf-frames=",lifted," home=",home)
	study.free()
	await process_frame
	quit()
