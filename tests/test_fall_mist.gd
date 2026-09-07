extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(256,256)
	root.content_scale_size = Vector2i(256,256)
	root.transparent_bg = true
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position.z = 5
	var cloud = load("res://studies/fall_mist.gd").new()
	root.add_child(cloud)
	cloud.setup({"positions":[0,0,0],"velocity":[0,0,0],"phase":[0.25],"size":[1.0],"rise":0.0})
	cloud.update_view(camera)
	var material: ShaderMaterial = cloud.material
	RenderingServer.global_shader_parameter_set("zs_motion_time",0.0)
	RenderingServer.global_shader_parameter_set("zs_wind_strength",0.0)
	RenderingServer.global_shader_parameter_set("zs_exposure",1.0)
	for ice in [0.0,0.5,1.0]:
		for daylight in [0.0,1.0]:
			for growth in [0.4,0.75,1.0]:
				RenderingServer.global_shader_parameter_set("zs_ice",ice)
				RenderingServer.global_shader_parameter_set("zs_daylight",daylight)
				RenderingServer.global_shader_parameter_set("zs_water_growth",growth)
				for frame in range(3):
					cloud.update_view(camera)
					RenderingServer.force_draw(false)
					await process_frame
				var image := root.get_texture().get_image()
				var expected: float = 0.3 * (1-ice*0.9) * lerpf(0.18,1,daylight) * smoothstep(0.5,1,growth)
				var actual := image.get_pixel(128,128).a
				if absf(actual-expected)>0.015:
					failures += 1
					push_error("Mist alpha differs: " + str(actual) + " expected " + str(expected))
	RenderingServer.global_shader_parameter_set("zs_ice",0.0)
	RenderingServer.global_shader_parameter_set("zs_daylight",1.0)
	RenderingServer.global_shader_parameter_set("zs_water_growth",1.0)
	RenderingServer.global_shader_parameter_set("zs_motion_time",1.5625)
	var motion := PackedVector4Array()
	motion.resize(64)
	motion[0] = Vector4(0.4,0,0.25,1)
	material.set_shader_parameter("motion",motion)
	for frame in range(3):
		cloud.update_view(camera)
		RenderingServer.force_draw(false)
		await process_frame
	var moving := root.get_texture().get_image()
	var weight := 0.0
	var moment := Vector2.ZERO
	for y in range(moving.get_height()):
		for x in range(moving.get_width()):
			var alpha := moving.get_pixel(x,y).a
			weight += alpha
			moment += Vector2(x+0.5,y+0.5)*alpha
	# Source phase = fract(1.5625*.16+.25) = .5; velocity drift = .4*.5.
	var expected_center := camera.unproject_position(Vector3(0.2,0,0))
	if weight <= 0 or (moment/maxf(weight,0.0001)).distance_to(expected_center)>1.5:
		failures += 1
		push_error("Rendered mist center does not follow source phase/velocity")
	var blocker := MeshInstance3D.new()
	blocker.mesh = QuadMesh.new()
	blocker.mesh.size = Vector2(10,10)
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	blocker.material_override = black
	root.add_child(blocker)
	for z in [1.0,-1.0]:
		blocker.position.z = z
		for frame in range(4):
			cloud.update_view(camera)
			RenderingServer.force_draw(false)
			await process_frame
		var color := root.get_texture().get_image().get_pixel(128,128)
		if (z > 0 and color.r > 0.01) or (z < 0 and color.r < 0.1):
			failures += 1
			push_error("Mist does not respect opaque scene depth")
	blocker.queue_free()
	cloud.queue_free()
	camera.queue_free()
	await process_frame
	print("PASS: source mist opacity across freeze, daylight and growth" if failures == 0 else "FAIL: fall mist")
	quit(1 if failures else 0)
