extends SceneTree
var scene: Node
var frame := 0
var ready_to_film := false
var control := false
var peak_displacement := 0.0
var states: Array[int] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	seed(4707)
	control = "--control" in OS.get_cmdline_user_args()
	scene = load("res://studies/wind_playground.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._play_ui.visible = false
	scene._ui.visible = false
	scene.creature.reset_at(scene._home)
	ready_to_film = true
	process_frame.connect(_frame)

func _frame() -> void:
	frame += 1
	scene._atmosphere.advance(1.0/60.0,false)
	RenderingServer.global_shader_parameter_set("zs_motion_time",frame/60.0)
	if frame == 60 and not control: scene.demo_gust()
	peak_displacement = maxf(peak_displacement,scene.creature.global_position.distance_to(scene._home))
	if scene.creature.state not in states: states.append(scene.creature.state)
	if frame in [45,100,160,300]:
		_capture.call_deferred(frame)
	if frame >= 480:
		print("WIND FILM ",JSON.stringify({"control":control,"peak_displacement":peak_displacement,"states":states,"final_position":str(scene.creature.global_position)}))
		quit()

func _capture(at: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/wind-%s-%03d.png" % ["control" if control else "effect",at])
