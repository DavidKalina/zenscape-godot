extends SceneTree
var scene: Node
var frame := 0
var start := Vector2.ZERO
var finish := Vector2.ZERO
var states: Array[int] = []
var peak := 0.0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	# macOS can reuse the last framebuffer when a movie window is obscured.
	root.unfocusable = false
	root.always_on_top = true
	root.size = Vector2i(1440,960)
	scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440,960)
	root.content_scale_factor = 1.0
	scene._play_ui.visible = false
	for i in range(600):
		await physics_frame
		if not scene._world_dirty and scene._refresh_phase == 0: break
	assert(not scene._world_dirty and scene._refresh_phase == 0,"Capture needs settled navigation")
	root.grab_focus()
	scene.brain.enabled = false
	scene._attention_time = 30.0
	physics_frame.connect(_frame)
func _frame() -> void:
	frame += 1
	if frame == 60:
		scene.reset_creature()
		start = scene.camera.unproject_position(scene.spring_tree.center(3.5))
		finish = scene.camera.unproject_position(scene.spring_tree.center(3.5)+Vector3(-4.7,0,0))
		scene.begin_tree_drag(start)
	if frame > 60 and frame <= 150: scene.move_tree_drag(start.lerp(finish,float(frame-60)/90.0))
	if frame == 180:
		scene.release_tree_drag()
	peak = maxf(peak,scene.creature.global_position.distance_to(scene._home))
	if scene.creature.state not in states: states.append(scene.creature.state)
	if frame in [45,150,195,230,330,540]: _capture.call_deferred(frame)
	if frame == 600:
		print("GOD MODE FILM ",JSON.stringify({"peak_displacement":peak,"states":states}))
		physics_frame.disconnect(_frame)
		scene.queue_free()
		await process_frame
		quit(0 if CreatureActor.State.WIND in states and CreatureActor.State.RECOVERING in states else 1)
func _capture(at: int) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/god-mode-playground/frame-%03d.png" % at)
