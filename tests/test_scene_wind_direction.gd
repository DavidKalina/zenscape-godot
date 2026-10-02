extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func center(image: Image, start: int, end: int) -> float:
	var sum := 0.0
	var count := 0
	for y in range(30,100):
		for x in range(start,end):
			var color := image.get_pixel(x,y)
			if color.r + color.g + color.b > 0.15:
				sum += x
				count += 1
	return sum / maxf(count,1)
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: foliage displacement requires GPU")
		quit()
		return
	var wind = preload("res://scripts/local_wind_field.gd").new()
	root.add_child(wind)
	RenderingServer.global_shader_parameter_set("zs_wind_strength", 0.0)
	RenderingServer.global_shader_parameter_set("zs_breeze", 0.0)
	RenderingServer.global_shader_parameter_set("zs_motion_time", 0.0)
	RenderingServer.global_shader_parameter_set("zs_exposure", 1.0)
	RenderingServer.global_shader_parameter_set("zs_surface_post", false)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400,200)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.BLACK
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	camera.position = Vector3(0,1,10)
	viewport.add_child(camera)
	camera.current = true
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://shaders/reference_surface.gdshader").replace("render_mode ","render_mode unshaded, ")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("sway_enabled", true)
	material.set_shader_parameter("sway_shape", Vector4(-1,1,0.8,0.0))
	material.set_shader_parameter("sway_frequency", Vector4.ZERO)
	material.set_shader_parameter("base_color",Color.WHITE)
	# One stem at one root, drawn plain and then turned and widened in place,
	# so both feel the same air (the breeze varies from root to root).
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6,2,0.6)
	instance.mesh = box
	instance.material_override = material
	instance.position = Vector3(0,1,0)
	viewport.add_child(instance)
	var shifts: Array[float] = []
	for turned in [false,true]:
		instance.rotation.y = PI * 0.5 if turned else 0.0
		instance.scale = Vector3(1.4,1,1.4) if turned else Vector3.ONE
		RenderingServer.global_shader_parameter_set("zs_wind_strength", 0.0)
		RenderingServer.global_shader_parameter_set("zs_breeze", 0.0)
		await process_frame
		RenderingServer.force_draw(false)
		var before := viewport.get_texture().get_image()
		RenderingServer.global_shader_parameter_set("zs_wind_strength", 2.0)
		RenderingServer.global_shader_parameter_set("zs_breeze", 2.0)
		RenderingServer.global_shader_parameter_set("zs_wind_direction", Vector2.RIGHT)
		await process_frame
		RenderingServer.force_draw(false)
		var after := viewport.get_texture().get_image()
		shifts.append(center(after,0,400) - center(before,0,400))
	var first := shifts[0]
	var rotated := shifts[1]
	check(first > 4, "Original crown bends right in world space: %s px" % first)
	check(rotated > 4, "Rotated/scaled crown bends right in world space: %s px" % rotated)
	check(absf(first-rotated) < 3, "Scale and rotation do not distort shared world displacement: %s vs %s" % [first,rotated])
	wind.clear()
	wind.queue_free()
	viewport.queue_free()
	await process_frame
	print("PASS: atmospheric foliage follows world wind across instance rotation/scale" if failures == 0 else "FAIL: local foliage")
	quit(1 if failures else 0)
