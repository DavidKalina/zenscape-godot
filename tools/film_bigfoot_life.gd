extends SceneTree
var scene: Node
var frame := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	seed(4707)
	scene = load("res://studies/bigfoot_life.tscn").instantiate()
	root.add_child(scene)
	scene._play_ui.visible = false
	scene._ui.visible = false
	scene._auto_orbit = false
	process_frame.connect(_frame)
func _frame() -> void:
	frame += 1
	if frame == 30:
		scene.brain.investigate(Vector3(4,0,3.6),false,"film-curious")
	if frame == 420:
		scene.brain.investigate(Vector3(-2,0,3.6),true,"film-excited")
	if frame == 470:
		scene._chunk_editor.data.begin_stroke()
		scene._chunk_editor.data.place("rock",Vector2(0.3,4.2),0.0,1.1)
		scene._chunk_editor.data.end_stroke()
		scene._chunk_editor.refresh()
	if frame in [60,180,300,450,490,650,850]: _capture.call_deferred(frame)
	if frame >= 960:
		print("LIFE FILM position ",scene.creature.global_position," phase ",scene.brain.phase)
		quit()
func _capture(at: int) -> void:
	print("LIFE FRAME ",at," position ",scene.creature.global_position," actor ",scene.creature.state," brain ",scene.brain.phase," route ",scene.brain._waypoint,"/",scene.brain._route.size())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/bigfoot-life-%03d.png" % at)
