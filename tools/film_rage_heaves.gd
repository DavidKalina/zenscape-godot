extends SceneTree
var kind := "tree"
var scene: Node
var frame := 0
func _initialize() -> void: _run.call_deferred()
var requested := false
var wait_frames := 0
var captured := {}
func _run() -> void:
	if OS.get_cmdline_user_args().has("--log"): kind = "log"
	Engine.max_physics_steps_per_frame = 1
	root.unfocusable = false
	root.always_on_top = true
	root.size = Vector2i(1440,960)
	scene = load("res://studies/god_mode_playground.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440,960)
	root.content_scale_factor = 1.0
	scene._play_ui.visible = false
	for i in range(600):
		await physics_frame
		if not scene._world_dirty and scene._refresh_phase==0: break
	root.grab_focus()
	physics_frame.connect(_frame)
	process_frame.connect(_draw_capture)
	scene.mischief.autonomous = false
	scene._attention_time = 1000.0
	scene.target = Vector3(4,1.5,3.9) if kind=="log" else Vector3(0,2,3.7)
	scene.distance = 10.0
	scene.yaw = 2.2 if kind=="log" else -0.6
	scene.polar = 1.15
	scene._update_camera()
func _frame() -> void:
	frame += 1
	if frame == 10:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1440,960)
		root.content_scale_factor = 1.0
	if frame == 100: scene.temper.provoke(1.0)
	if frame == 120:
		requested = scene.mischief.request(kind)
		if not requested: quit(1)
	if not requested: return
	var play = scene.mischief
	if play.phase in ["perform","carry","toss"]:
		var t: float = scene.creature._age if play.phase != "carry" else play._elapsed
		for sample in [0.9,1.5,2.5,2.85,3.05,3.3,3.9]:
			var key: String = play.phase+"-"+str(sample)
			if t>=sample and not captured.has(key):
				captured[key] = true
				print("STONE SAMPLE ",key," frame=",frame," age=",t," position=",play.target.global_position if play.target!=null else Vector3.ZERO)
				_snapshot.call_deferred(key)
	if not play.busy():
		wait_frames += 1
		if wait_frames>=120:
			print("BIGFOOT RAGE FILM ",JSON.stringify({"history":play.history,"frames":frame,"cancel":play.last_cancel}))
			var passed: bool = kind in play.history
			physics_frame.disconnect(_frame)
			scene.queue_free()
			await process_frame
			quit(0 if passed else 1)
	if frame>3000: quit(1)
func _snapshot(key: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/rage-heaves/"+kind+"-"+key+".png")

func _draw_capture() -> void:
	# Keep offline captures updating even when the desktop occludes the window.
	RenderingServer.force_draw(false,1.0/60.0)
