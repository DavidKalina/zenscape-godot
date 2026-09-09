extends SceneTree
## Pose strip for the fire behaviour: flee, watch, warm hands. Uses the real
## actor and the real controller, with no fire field — each stand is driven
## straight into the pose it should hold, so the strip reads the authoring and
## not the simulation. `--film` also writes a frame sequence to /private/tmp.
const FIRE = preload("res://scripts/bigfoot_fire.gd")
const WARM = preload("res://scripts/bigfoot_warm_hands.gd")
const Fixture = preload("res://tests/test_bigfoot_fire.gd")

var stage := Node3D.new()
var worlds: Array[Node3D] = []
var fires: Array[Node] = []
var kinds := ["flee","watch","warm hands"]
## Seconds into each performance to hold for the still.
var marks := [0.55,2.40,3.80]

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1440,760)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.add_child(stage)
	_lighting()
	var camera := Camera3D.new()
	stage.add_child(camera)
	# Three quarters, not head on: a crouch and a forward reach are sagittal,
	# and a front view foreshortens both into nothing.
	camera.position = Vector3(8.5,5.4,13.0)
	camera.look_at(Vector3(0,1.15,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.8
	camera.current = true
	for i in range(kinds.size()):
		_stand(i)
	var film := "--film" in OS.get_cmdline_user_args()
	if film: DirAccess.make_dir_recursive_absolute("/private/tmp/bigfoot-fire-frames")
	var frames := roundi(WARM.DURATION*60.0) if film else 1
	for frame in range(frames):
		var t := float(frame)/60.0
		for i in range(worlds.size()):
			_drive(i,t if film else marks[i])
			worlds[i].creature.advance(1.0/60.0)
		await process_frame
		if film and frame%2 == 0:
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png("/private/tmp/bigfoot-fire-frames/%04d.png" % (frame/2))
	# Settle the still on its marks whatever the film loop left behind.
	for pass_index in range(180):
		for i in range(worlds.size()):
			_drive(i,marks[i])
			worlds[i].creature.advance(1.0/60.0)
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://docs/fire")
	root.get_texture().get_image().save_png("res://docs/fire/bigfoot-poses.png")
	print("Saved fire pose strip to docs/fire/bigfoot-poses.png")
	stage.queue_free()
	await process_frame
	quit()

func _lighting() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("2f2b2c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e6dccb")
	environment.environment.ambient_light_energy = 0.75
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-46,-28,0)
	light.light_energy = 1.7
	light.shadow_enabled = true
	stage.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("6d7a63")
	ground.material_override = material
	stage.add_child(ground)

func _stand(index: int) -> void:
	var world := Fixture.World.new()
	stage.add_child(world)
	for child in [world.creature,world.brain,world.routine,world.world_play,world._lightning]: world.add_child(child)
	world.creature.setup("res://assets/models/zenscape-bigfoot-breathing.glb")
	world.creature.set_process(false)
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color("584438")
	coat.roughness = 0.95
	for mesh: MeshInstance3D in world.creature.actor.find_children("*","MeshInstance3D",true,false):
		if "_n7_" not in mesh.name and "_n8_" not in mesh.name: mesh.material_override = coat
	world.creature.position = Vector3(float(index-1)*4.0,0,0)
	world.brain.setup(world.creature,world.navigation,Callable())
	var behaviour := FIRE.new()
	world.add_child(behaviour)
	behaviour.setup(world,null)
	worlds.append(world)
	fires.append(behaviour)
	# A knot of embers in front of him gives the eye something to warm at.
	var embers := MeshInstance3D.new()
	var pile := SphereMesh.new()
	pile.radius = 0.52
	pile.height = 0.34
	embers.mesh = pile
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("d8501a") if index != 1 else Color("e2601f")
	glow.emission_enabled = true
	glow.emission = Color("ff7a22")
	glow.emission_energy_multiplier = 2.4
	embers.material_override = glow
	embers.position = world.creature.position+Vector3(0,0.1,1.62 if index == 2 else 3.2)
	embers.visible = index != 0
	stage.add_child(embers)
	var label := Label3D.new()
	label.text = kinds[index].to_upper()
	label.font_size = 44
	label.pixel_size = 0.0065
	label.position = world.creature.position+Vector3(0,0.08,2.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stage.add_child(label)

func _drive(index: int, t: float) -> void:
	var behaviour: Node = fires[index]
	var world: Node3D = worlds[index]
	var actor: CreatureActor = world.creature
	if actor.state != CreatureActor.State.ACTION:
		actor.perform_action("Idle",60.0)
	actor._age = t
	actor.clear_hand_targets()
	match index:
		0:
			# Startle, the first beat of a flee.
			actor.environment_pose = "startle"
			var weight := smoothstep(0.0,0.12,t)
			for side in ["R","L"]:
				var sign := -1.0 if side == "R" else 1.0
				actor.reach_hand(actor.to_global(Vector3(sign*0.48,2.48,0.25)),weight,side)
			actor.track_gaze(actor.to_global(Vector3(0,2.4,6.0)))
		1:
			behaviour.active = "watch"
			behaviour.phase = "perform"
			behaviour._duration = 16.0
			behaviour._threat = actor.global_position+Vector3(0,0,3.2)
			actor.environment_pose = "fire_watch"
			var weight := smoothstep(0.0,0.9,t)
			actor.track_gaze(behaviour._threat+Vector3.UP*0.6)
			actor.reach_hand(actor.to_global(Vector3(-0.32,2.65,0.4)),weight*0.95,"R",
				actor.to_global(Vector3(-1.0,2.1,0.2)),Basis(-actor.basis.z,actor.basis.x,-actor.basis.y))
		2:
			behaviour.active = "warm"
			behaviour.phase = "perform"
			behaviour._variant = {}
			behaviour._duration = WARM.DURATION
			behaviour._ash = actor.global_position+Vector3(0,0.1,1.62)
			actor.environment_pose = "fire_warm"
			behaviour._pose_warm(actor,0.0)
