extends SceneTree
var scene: Node3D
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.unfocusable = true
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440,900)
	root.content_scale_factor = 1.0
	scene = load("res://studies/god_mode_playground.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	scene.mischief.autonomous = false
	scene._attention_time = 10000.0
	scene.target = Vector3(0,2.2,3.7)
	scene.distance = 12.0
	scene.yaw = 0.0
	scene.polar = 1.25
	scene._update_camera()
	for i in range(90): await physics_frame
	scene.set_physics_process(false)
	scene.set_process(false)
	for profile in [0,1,2]:
		PlaySpringTree.motion_style = profile
		for tuner in get_nodes_in_group("tree_motion_tuner"):
			tuner.profiles.selected = profile
			tuner.status.text = "Capture · "+["Original","Supple","Cartoony"][profile]
		scene.spring_tree.reset()
		scene.spring_tree.begin_grab()
		scene.spring_tree.drag_to(Vector3(-4,0,0))
		for i in range(120): scene.spring_tree.advance(1.0/120.0)
		scene.spring_tree.release()
		for frame in range(181):
			scene.spring_tree.advance(1.0/120.0)
			if frame in [0,24,48,84,180]:
				RenderingServer.force_draw(false)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/private/tmp/tree-%d-%03d.png" % [profile,frame])
			await process_frame
	print("Tree motion captures complete")
	quit()
