extends SceneTree
## Pose contact sheet using the production actor and environmental controller.
const Fixture = preload("res://tests/test_bigfoot_environment.gd")
var stage := Node3D.new()
var worlds: Array[Node3D] = []
var lives: Array[Node] = []
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("52635d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e1e6d9")
	environment.environment.ambient_light_energy = 0.8
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48,-25,0)
	light.light_energy = 1.6
	light.shadow_enabled = true
	stage.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("718569")
	ground.material_override = material
	stage.add_child(ground)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(12,13,22)
	camera.look_at(Vector3(0,1.1,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.6
	camera.current = true
	var kinds := ["tree_hug","tree_touch","horizon","rain","dry","shock"]
	for i in range(kinds.size()):
		var world := Fixture.World.new()
		stage.add_child(world)
		for child in [world.creature,world.brain,world.routine,world._lightning]: world.add_child(child)
		world.creature.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
		world.creature.set_process(false)
		var coat := StandardMaterial3D.new()
		coat.albedo_color = Color("584438")
		coat.roughness = 0.95
		for mesh: MeshInstance3D in world.creature.actor.find_children("*","MeshInstance3D",true,false):
			if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
		world.creature.position = Vector3((i%3-1)*4.5,0,(i/3)*5.4-2.7)
		world.brain.setup(world.creature,world.navigation,Callable())
		var life := preload("res://scripts/bigfoot_environment.gd").new()
		world.add_child(life)
		life.setup(world)
		life.autonomous = false
		life.active = kinds[i]
		life._duration = 8.0
		life._look = world.creature.position+Vector3(0,4,10)
		if i<2:
			var center := world.creature.position+Vector3(0,0,0.89)
			life.target = {"center":center,"radius":0.25,"id":"study"}
			var trunk := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.23
			cylinder.bottom_radius = 0.27
			cylinder.height = 3.6
			trunk.mesh = cylinder
			trunk.position = center+Vector3.UP*1.8
			var bark := StandardMaterial3D.new()
			bark.albedo_color = Color("695445")
			trunk.material_override = bark
			stage.add_child(trunk)
			life._look = center+Vector3.UP*1.9
		life._perform()
		worlds.append(world)
		lives.append(life)
		var label := Label3D.new()
		label.text = kinds[i].replace("_"," ").to_upper()
		label.font_size = 42
		label.pixel_size = 0.007
		label.position = world.creature.position+Vector3(0,0.1,1.65)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		stage.add_child(label)
	var film := "--film" in OS.get_cmdline_user_args()
	if film: DirAccess.make_dir_recursive_absolute("/private/tmp/bigfoot-environment-frames")
	for frame in range(360 if film else 125):
		for i in range(worlds.size()):
			lives[i]._pose()
			worlds[i].creature.advance(1.0/60.0)
		await process_frame
		if film and frame%2 == 0:
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("/private/tmp/bigfoot-environment-frames/%04d.png" % (frame/2))
	RenderingServer.force_draw(false)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://docs/bigfoot-environment")
	root.get_texture().get_image().save_png("res://docs/bigfoot-environment/poses.png")
	print("Saved environmental pose contact sheet")
	stage.queue_free()
	await process_frame
	quit()
