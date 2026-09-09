extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1200,720)
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("47595b")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("dbe5ed")
	env.environment.ambient_light_energy = 0.65
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	light.light_energy = 1.8
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,3.6,12)
	camera.look_at(Vector3(0,1.4,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.5
	camera.current = true
	for i in range(3):
		var actor := CreatureActor.new()
		stage.add_child(actor)
		actor.position.x = (i-1)*3.1
		actor.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
		actor.set_process(false)
		var coat := ShaderMaterial.new()
		coat.shader = preload("res://shaders/reference_surface.gdshader")
		for mesh: MeshInstance3D in actor.actor.find_children("*","MeshInstance3D",true,false):
			if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
		actor.wet_coat.rain = 1.0 if i>0 else 0.0
		for frame in range(240): actor.advance(0.05)
		if i==2:
			actor.wet_coat.rain = 0.0
			for frame in range(900): actor.advance(0.05)
		var label := Label3D.new()
		stage.add_child(label)
		label.position = Vector3((i-1)*3.1,3.3,0)
		label.text = ["DRY", "SOAKED", "45 SECONDS LATER"][i]
		label.font_size = 38
		label.pixel_size = 0.006
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/bigfoot-wetness")
	root.get_texture().get_image().save_png("res://docs/bigfoot-wetness/coat-comparison.png")
	quit()
