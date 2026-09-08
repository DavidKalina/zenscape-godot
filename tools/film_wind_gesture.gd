extends SceneTree
var scene: Node
var frame := 0
var control := false
var start: Vector3
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	seed(4707)
	control = "--control" in OS.get_cmdline_user_args()
	scene = load("res://studies/wind_playground.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._play_ui.visible = false
	scene._ui.visible = false
	scene.gust_visuals.enabled = not control
	scene.gust_visuals.aim.visible = not control
	start = scene._home+Vector3(-1.0,0,0.5)
	process_frame.connect(_frame)
func _frame() -> void:
	frame += 1
	scene._atmosphere.advance(1.0/60.0,false)
	RenderingServer.global_shader_parameter_set("zs_motion_time",frame/60.0)
	if frame>=30 and frame<90:
		scene.gust_visuals.set_aim(start,start+Vector3(5.0,0,-1.0)*float(frame-30)/60.0,scene._probe_ground)
	if frame == 90:
		scene.gust_visuals.clear_aim()
		scene.wind.emit_gust(start+Vector3.UP,Vector3(1,0,-0.2),20.0,8.0,1.4)
		print("GESTURE FILM release frame=90 control=",control)
	if frame == 290:
		scene.wind.emit_gust(scene.creature.global_position+Vector3.UP,Vector3(-1,0,-0.4),5.0,6.0,2.0)
	if frame in [70,115,145,325]: _capture.call_deferred(frame)
	if frame>=480: quit()
func _capture(at: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/gesture-%s-%03d.png" % ["control" if control else "effect",at])
