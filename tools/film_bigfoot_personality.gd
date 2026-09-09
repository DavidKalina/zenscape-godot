extends SceneTree
## Repeatable visual QA: actual actors, translating walk, planted idle, same light.
var stage := Node3D.new()
var camera := Camera3D.new()
var actors: Array[CreatureActor] = []
var frame := 0
var destination := "/private/tmp/bigfoot-personality-frames"
var walk_reference := ""
var walk_only := false
var held_only := false
var held_reference := ""
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--walk-reference="): walk_reference = argument.trim_prefix("--walk-reference=")
		if argument == "--walk-only": walk_only = true
		if argument == "--held-only": held_only = true
		if argument.begins_with("--held-reference="): held_reference = argument.trim_prefix("--held-reference=")
	if not walk_reference.is_empty(): destination = "/private/tmp/bigfoot-arms-frames"
	if held_only: destination = "/private/tmp/bigfoot-held-frames"
	DirAccess.make_dir_recursive_absolute(destination)
	root.unfocusable = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960,720)
	root.content_scale_size = Vector2i(960,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_factor = 1.0
	root.add_child(stage)
	process_frame.connect(func() -> void: RenderingServer.force_draw(false))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("839c89")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d9e6d8")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = 1.6
	light.shadow_enabled = true
	stage.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8e9b74")
	material.roughness = 1.0
	ground.material_override = material
	stage.add_child(ground)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.8
	stage.add_child(camera)
	camera.current = true
	for i in range(2):
		var actor := CreatureActor.new()
		stage.add_child(actor)
		actor.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
		actor.set_personality(i == 1 or not walk_reference.is_empty() or not held_reference.is_empty())
		if i == 0 and not held_reference.is_empty():
			var library := actor.player.get_animation_library("")
			library.remove_animation("Held")
			library.add_animation("Held",load(held_reference))
		if i == 0 and not walk_reference.is_empty():
			var library := actor.player.get_animation_library("")
			library.remove_animation("Walk")
			library.add_animation("Walk",load(walk_reference))
		var coat := ShaderMaterial.new()
		coat.shader = preload("res://shaders/reference_surface.gdshader")
		for mesh: MeshInstance3D in actor.actor.find_children("*","MeshInstance3D",true,false):
			if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
		actor.set_process(false)
		actor.reset_at(Vector3(-1.5+i*3,0,0))
		actors.append(actor)
		if held_only:
			actor.position.y = 1.0
			actor.pick_up()
			var grip := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.055
			sphere.height = 0.11
			grip.mesh = sphere
			grip.position = Vector3(0,actor.grasp_height,0.04)
			actor.add_child(grip)
		var label := Label3D.new()
		label.text = ("PREVIOUS WALK" if i == 0 else "LOOSER ARMS") if not walk_reference.is_empty() else ("ORIGINAL" if i == 0 else "BUOYANT & CURIOUS")
		if held_only: label.text = "PREVIOUS HELD" if i == 0 else "AIR-SWIMMING"
		label.font_size = 36
		label.pixel_size = 0.003
		label.position.y = 3.2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(label)
	for i in range(3): await process_frame
	for index in range(300 if held_only else 180 if walk_only else 660):
		frame = index
		for actor in actors:
			if frame<180 and not held_only:
				actor.walk_step(Vector3(actor.position.x,0,100),0.65,1.0/30.0)
			elif frame == 180 and not held_only:
				actor.stop_walking()
				actor.player.seek(0,true)
			actor.advance(1.0/30.0)
		var z := actors[0].position.z
		camera.position = Vector3(2.3,4.0 if held_only else 3.0,z+8.5)
		camera.look_at(Vector3(0,2.45 if held_only else 1.45,z))
		RenderingServer.force_draw(false)
		await RenderingServer.frame_post_draw
		# Resize QA frames only through the engine's render target settings, no asset edits.
		root.get_texture().get_image().save_png(destination+"/%04d.png" % frame)
		await process_frame
	print("BIGFOOT PERSONALITY FILM READY ",destination)
	quit()
