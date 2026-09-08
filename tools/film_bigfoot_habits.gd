extends SceneTree
## Highlight reel of autonomous visits. Between chapters, simulate ordinary
## play without rendering; never request actions or alter routine timers.
var scene: Node
var frame := 0
var chapter := 0
var seconds := 0.0
var control := false
var label: Label
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	control = "--control" in OS.get_cmdline_user_args()
	scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene._ui.visible = false
	scene._life_status.get_parent().get_parent().visible = false
	scene._auto_orbit = false
	scene._refresh_habitat()
	scene._celestial.cycling = false
	scene._celestial.set_phase(0.48)
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	label = Label.new()
	label.position = Vector2(24,20)
	label.add_theme_font_size_override("font_size",22)
	overlay.add_child(label)
	_seek()
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	process_frame.connect(_frame)
func _tick() -> void:
	scene._process(1.0/30.0)
	seconds += 1.0/30.0
func _seek() -> void:
	while seconds<400.0:
		_tick()
		var habits = scene.routine.habits
		if chapter<3:
			if habits.visits==chapter+1 and scene.routine._phase=="perform" and scene.creature.action_clip=="SitDown": break
		elif habits.visits>=4 and habits.home!=null and scene.creature.position.distance_to(habits.home)>1.8: break
	var home: Vector3 = scene.routine.habits.home
	if chapter<3: scene.frame_creature(7.0,0.4)
	scene.target = home+Vector3.UP*1.0
	scene._update_camera()
	label.text = ["A second visit · gathering leaves","Returning to his spot · a larger bed","Settling in · the finished bed","His spot stays behind when he explores"][chapter]
	print("HABITS FILM chapter=",chapter," simulation_seconds=",seconds," memory=",scene.routine.habits.capture())
func _frame() -> void:
	frame += 1
	_tick()
	if control:
		for entry in scene._chunk_editor._anchors:
			if entry.node.name in ["mesh-14","mesh-15"]: entry.node.multimesh = entry.source
		for batch in scene._chunk_editor.content._batches:
			if batch.get_meta("part")=="leaf_bed": batch.visible = false
	if frame%240 in [60,180]: _capture.call_deferred(frame)
	if frame%240 == 0:
		chapter += 1
		if chapter==4:
			quit()
			return
		_seek()
func _capture(at: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/habits-%s-%04d.png" % ["control" if control else "effect",at])
