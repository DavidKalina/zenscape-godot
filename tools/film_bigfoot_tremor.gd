extends SceneTree
var scene: Node
var frame := 0
var control := false
var _last_drawn := -1
var states: Array = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	control = "--control" in OS.get_cmdline_user_args()
	scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene._ui.visible = false
	scene._auto_orbit = false
	scene._refresh_habitat()
	scene.brain.enabled = false
	scene.routine._next_action = INF
	scene._celestial.set_phase(0.48)
	scene.frame_creature(7.0,scene.creature.rotation.y-0.65)
	if control: scene._tremor.shaken.disconnect(scene.creature.queue_tremor)
	process_frame.connect(_frame)
func _frame() -> void:
	var drawn := Engine.get_frames_drawn()
	if drawn == _last_drawn: return
	_last_drawn = drawn
	frame += 1
	if frame == 60: scene._tremor.add(0.7)
	if frame == 300: scene._tremor.add(0.3)
	scene._process(1.0/60.0)
	if scene.creature.state not in states: states.append(scene.creature.state)
	if frame in [65,78,95,125,200,320]: _capture.call_deferred(frame)
	if frame>=480:
		print("TREMOR FILM control=",control," states=",states," feet=",scene.creature.position)
		quit()
func _capture(at: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/tremor-%s-%03d.png" % ["control" if control else "effect",at])
