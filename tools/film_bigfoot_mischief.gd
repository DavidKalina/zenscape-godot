extends "res://tools/film_god_mode_playground.gd"
var caption := Label.new()
var kind_index := 0
var waiting := 0
var requested := false
var shots := {}
var rendered := 0
var max_render_delta := 0.0
func _run() -> void:
	Engine.max_physics_steps_per_frame = 1
	process_frame.connect(func() -> void:
		rendered += 1
		if is_instance_valid(scene): max_render_delta = maxf(max_render_delta,scene.get_process_delta_time()))
	await super._run()
	scene.mischief.autonomous = false
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(caption)
	caption.position = Vector2(80,70)
	caption.add_theme_font_size_override("font_size",36)
	caption.add_theme_color_override("font_color",Color("ffe8bd"))
	caption.add_theme_color_override("font_shadow_color",Color("193126"))
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
func _frame() -> void:
	frame += 1
	if frame == 10:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1440,960)
		root.content_scale_factor = 1.0
	if frame<150: return
	if not requested:
		scene.creature.reset_at(scene._home)
		scene.brain.reset_behavior()
		scene._attention_time = 100.0
		var kind: String = ["stone","log","tree"][kind_index]
		caption.text = {"stone":"He can throw things too.","log":"Two hands. A little effort. A flying log.","tree":"He has been paying attention."}[kind]
		if not scene.mischief.request(kind):
			push_error("Cannot stage "+kind)
			quit(1)
			return
		requested = true
	if scene.mischief.phase == "perform":
		var t: float = scene.creature._age
		for at in [1.3,2.4,3.1]:
			var key := str(kind_index)+"-"+str(at)
			if t>=at and not shots.has(key):
				shots[key] = true
				_snapshot.call_deferred(key)
	if not scene.mischief.busy():
		waiting += 1
		if waiting>=140:
			kind_index += 1
			waiting = 0
			requested = false
			if kind_index>=3:
				print("BIGFOOT MISCHIEF FILM ",JSON.stringify({"history":scene.mischief.history,"physics_frames":frame,"rendered_frames":rendered,"max_render_delta":max_render_delta}))
				physics_frame.disconnect(_frame)
				scene.queue_free()
				await process_frame
				quit(0)
	if frame>6000: quit(1)
func _snapshot(key: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/bigfoot-mischief/"+key+".png")
