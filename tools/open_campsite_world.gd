extends SceneTree
## Editable, repeatable campsite demonstration; saved in its own study library.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.library_path = "user://campsite-demo"
	scene.recent_file = "user://campsite-demo/recent.cfg"
	root.size = Vector2i(1440,900)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var data: NativeTerrainData = scene._chunk_editor.data
	data.grass.fill(0.8)
	for x in [-10,-6,-2,2,6,10]:
		for z in [-10]: data.place("tree",Vector2(x,z),x*0.3,1.6)
	for p in [Vector2(-7,-1),Vector2(-4,1),Vector2(4,1),Vector2(7,-1)]:
		data.place("tree",p,0,1.4)
		data.place("rock",p+Vector2(0,0.8),0,1.1)
	data.place("campsite",Vector2(0,-5))
	for p in [Vector2(6,4),Vector2(-6,5),Vector2(3,7),Vector2(-8,-3)]: data.place("fallen_branch",p,0.4,1.0)
	for p in [Vector2(-10,4),Vector2(9,6),Vector2(2,9)]: data.place("shrub",p,0,1.1)
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	scene.invite_bigfoot(Vector3(-3,0,3))
	scene._celestial.cycling = false
	scene._celestial.set_phase(0.48)
	scene.set_building(false)
	scene.target = Vector3(0,0.8,-0.8)
	scene.distance = 17
	scene.yaw = 0.16
	scene.polar = 1.02
	scene._update_camera()
	for tuner in get_nodes_in_group("tree_motion_tuner"): tuner.hide()
	scene.save_current()
	scene.get_window().title = "ZenScape · Campsite life"
	scene._notice.text = "The camper is settling in. Leave fallen branches nearby to draw them out."
	scene.camps.story_event.connect(func(message: String) -> void:
		if not scene._chunk_editor.active: scene._notice.text = message.capitalize())
	scene._button(scene._toolbar,"Camp",func() -> void:
		scene.target = Vector3(0,0.8,-0.8)
		scene.distance = 17
		scene._update_camera())
	scene._button(scene._toolbar,"Day / night",func() -> void:
		scene._celestial.set_phase(0.03 if scene._celestial.daylight>0.2 else 0.48))
	if "--capture" in OS.get_cmdline_user_args(): await capture(scene)
	print("CAMPSITE DEMO: ",scene._chunk_editor.save_path)

func capture(scene: Node) -> void:
	scene.set_process(false)
	for i in range(60):
		scene._process(1.0/60)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/campsite-life/first-camp.png")
	var captured := false
	for frame in range(9000):
		scene._process(1.0/60)
		if frame%60 == 0: await process_frame
		if not captured and scene.camps.bigfoot_activity == "visiting camp" and scene.camps.bigfoot_wait>0.5:
			captured = true
			for i in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/campsite-life/inspecting-tent.png")
	print("CAMP CAPTURE: ",scene.camps.events)
	quit()
