extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var scene = load("res://studies/wind_playground.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	check(scene.valid_landing(scene._home),"Combined demo has safe dry home")
	check(scene.creature.wind_body != null,"Physics actor integrated")
	check(not scene.building and not scene._chunk_editor.active,"Starts in coherent play mode")
	scene.toggle_build()
	check(scene.building and scene._chunk_editor.active,"Native building active")
	scene._chunk_editor.set_active(false)
	check(not scene.building and not scene._chunk_editor.active,"Native Inspect switches back to play")
	await physics_frame
	check(not scene.valid_landing(Vector3(3,-1.1,0)),"Pond cannot accept placement")
	var origin: Vector2 = scene.camera.unproject_position(scene._home+Vector3(-0.7,0,0.6))
	var finish: Vector2 = scene.camera.unproject_position(scene._home+Vector3(1.0,0,0.6))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = origin
	scene._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	scene._input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = finish
	scene._input(release)
	scene.wind.advance(0.2)
	var aimed: Vector3 = scene.wind.sample_local(scene._home+Vector3.UP)
	check(aimed.x>10.0 and absf(aimed.z)<1.0,"Camera-projected drag emits wind in aimed world direction")
	scene.wind.clear()
	scene.demo_gust()
	for i in range(80): await physics_frame
	check(scene.creature.state == CreatureActor.State.WIND,"Real demo gust starts physical tumble")
	var pause := InputEventKey.new()
	pause.keycode = KEY_P
	pause.pressed = true
	scene._unhandled_input(pause)
	await process_frame
	await physics_frame
	var before: Vector3 = scene.creature.wind_body.global_position
	for i in range(6): await physics_frame
	check(scene.creature.wind_body.global_position.distance_to(before)<0.001,"Pause freezes physical displacement")
	scene._unhandled_input(pause)
	check(not scene._paused,"P resumes from a paused scene")
	scene.reset_creature()
	check(scene.creature.global_position.distance_to(scene._home)<0.001,"Reset restores safe demo home")
	print("Wind playground: ",failures," failures")
	quit(1 if failures else 0)
