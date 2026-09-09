extends "res://tools/film_god_mode_playground.gd"
var requested := false
var wait_frames := 0
var captured := {}
var peak_carry := 0.0
func _run() -> void:
	Engine.max_physics_steps_per_frame = 1
	await super._run()
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
		root.size = Vector2i(1440,960)
		root.content_scale_factor = 1.0
	if frame == 120:
		requested = scene.mischief.request("log")
		if not requested: quit(1)
	if not requested: return
	var play = scene.mischief
	peak_carry = maxf(peak_carry,play._carry_distance)
	if play.phase in ["perform","carry","toss"]:
		var t: float = scene.creature._age if play.phase != "carry" else play._elapsed
		for sample in [0.9,1.5,2.5,3.9]:
			var key: String = play.phase+"-"+str(sample)
			if t>=sample and not captured.has(key):
				captured[key] = true
				_snapshot.call_deferred(key)
	if not play.busy():
		wait_frames += 1
		if wait_frames>=100:
			print("LOG ANIMATION FILM ",JSON.stringify({"history":play.history,"carry_distance":peak_carry,"frames":frame,"cancel":play.last_cancel}))
			var passed: bool = "log" in play.history and peak_carry>1.0
			physics_frame.disconnect(_frame)
			scene.queue_free()
			await process_frame
			quit(0 if passed else 1)
	if frame>3000: quit(1)
func _snapshot(key: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/log-animation/"+key+".png")
