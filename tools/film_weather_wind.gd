extends SceneTree
var scene: Node
var frame := 0
var control := false
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	control = "--control" in OS.get_cmdline_user_args()
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene._ui.visible = false
	scene._auto_orbit = false
	scene._atmosphere.wind_trails.enabled = not control
	scene._atmosphere.strength = 1.2
	scene._atmosphere._air_strength = 1.2
	scene.target = Vector3(0,1.7,0)
	scene.distance = 33.0
	scene.yaw = 0.35
	scene.polar = 0.85
	scene._update_camera()
	process_frame.connect(_frame)
func _frame() -> void:
	frame += 1
	scene._process(1.0/60.0)
	if frame in [240,360,510]: _capture.call_deferred(frame)
	if frame>=600:
		print("WEATHER FILM control=",control," parcels=",scene._atmosphere.wind_trails.parcels.size()," wind=",scene._atmosphere._air_strength)
		quit()
func _capture(at: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/weather-%s-%03d.png" % ["control" if control else "effect",at])
