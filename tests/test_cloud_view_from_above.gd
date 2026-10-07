extends SceneTree
## GPU regression: the elevated diorama camera must see the cloud deck below it.
## suite: gpu
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("Cloud view requires a GPU window")
		quit(2)
		return
	root.size = Vector2i(640,400)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_sky.gdshader")
	environment.environment.sky.sky_material = material
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,65,65)
	camera.look_at(Vector3.ZERO)
	var sky_state := {"zs_sky_up":Vector3(.1,.2,.3),"zs_sky_down":Vector3(.15,.2,.3),"zs_sky_glow":Vector3.ZERO,"zs_cloud_sky":Vector3(.7,.8,.9),"zs_cloud_sun":Vector3(.9,.8,.7),"zs_cloud_direction":Vector3.UP,"zs_cloud_drift":Vector3.ZERO}
	for key in sky_state: RenderingServer.global_shader_parameter_set(key,sky_state[key])
	RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(0,0,20,12))
	await create_timer(.5).timeout
	RenderingServer.force_draw(false)
	var clear := root.get_texture().get_image()
	RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(1,0,20,12))
	await create_timer(.5).timeout
	RenderingServer.force_draw(false)
	var cloudy := root.get_texture().get_image()
	material.set_shader_parameter("cloud_steps",26)
	await create_timer(.5).timeout
	RenderingServer.force_draw(false)
	var reference := root.get_texture().get_image()
	var difference := 0.0
	var quality_error := 0.0
	var count := 0
	for y in range(0,clear.get_height(),8):
		for x in range(0,clear.get_width(),8):
			var a := clear.get_pixel(x,y)
			var b := cloudy.get_pixel(x,y)
			var c := reference.get_pixel(x,y)
			difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
			quality_error += absf(c.r-b.r)+absf(c.g-b.g)+absf(c.b-b.b)
			count += 1
	difference /= count
	quality_error /= count
	print("Cloud view from above: mean pixel difference = ",difference)
	print("Cloud sampling mean RGB error against 26 steps = ",quality_error)
	if difference<.03: push_error("Downward sky rays dropped the cloud deck")
	if quality_error>.06: push_error("Lower cloud sampling changed the image too much")
	world.queue_free()
	await process_frame
	quit(1 if difference<.03 or quality_error>.06 else 0)
