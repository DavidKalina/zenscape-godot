extends SceneTree
var kind := "log"
var scene: Node
var frame := 0
func _initialize() -> void: _run.call_deferred()
var requested := false
var wait_frames := 0
var captured := {}
var peak_carry := 0.0
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="): kind = arg.trim_prefix("--kind=")
	DirAccess.make_dir_recursive_absolute("/private/tmp/bigfoot-actions-"+kind)
	Engine.max_physics_steps_per_frame = 1
	root.unfocusable = false
	root.always_on_top = false
	root.size = Vector2i(960,720)
	scene = load("res://studies/god_mode_playground.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960,720)
	root.content_scale_size = Vector2i(960,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	scene._play_ui.visible = false
	get_first_node_in_group("tree_motion_tuner").visible = false
	for i in range(600):
		await physics_frame
		if not scene._world_dirty and scene._refresh_phase==0: break
	pass
	physics_frame.connect(_frame)
	process_frame.connect(_draw_capture)
	scene.mischief.autonomous = false
	scene._attention_time = 1000.0
	scene.target = Vector3(4,1.5,3.9)
	scene.distance = 10.0
	scene.yaw = 2.2
	scene.polar = 1.15
	scene._update_camera()
func _frame() -> void:
	frame += 1
	if frame == 10:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(960,720)
		root.content_scale_factor = 1.0
	if frame == 120:
		requested = scene.mischief.request(kind)
		if not requested: quit(1)
	if not requested: return
	var play = scene.mischief
	peak_carry = maxf(peak_carry,play._carry_distance)
	if play.phase in ["perform","carry","toss"]:
		scene.target = scene.creature.global_position+Vector3.UP*1.5
		scene.distance = 8.0
		scene.yaw = scene.creature.rotation.y+0.8
		scene._update_camera()
		var t: float = scene.creature._age if play.phase != "carry" else play._elapsed
		for sample in [0.55,0.75,1.5,2.5,2.85,3.05,3.6,3.9]:
			var key: String = play.phase+"-"+str(sample)
			if t>=sample and not captured.has(key):
				captured[key] = true
				print("LOG SAMPLE ",key," frame=",frame," age=",t," position=",play.target.global_position if play.target!=null else Vector3.ZERO)
				_snapshot.call_deferred(key)
	if not play.busy():
		wait_frames += 1
		if wait_frames>=100:
			print("LOG ANIMATION FILM ",JSON.stringify({"history":play.history,"carry_distance":peak_carry,"frames":frame,"cancel":play.last_cancel}))
			var passed: bool = kind in play.history
			physics_frame.disconnect(_frame)
			scene.queue_free()
			await process_frame
			quit(0 if passed else 1)
	if frame>3000: quit(1)
func _snapshot(key: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/bigfoot-actions-"+kind+"/"+key+".png")

func _draw_capture() -> void:
	# Keep offline captures updating even when the desktop occludes the window.
	RenderingServer.force_draw(false,1.0/60.0)
