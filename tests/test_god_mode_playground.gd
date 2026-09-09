extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	root.unfocusable = true # Automated input must not steal focus from other work.
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	root.content_scale_factor = 1.0 # Match camera/UI coordinates on Retina and headless.
	for i in range(8): await physics_frame
	check(scene.valid_landing(scene._home),"Preset has safe home")
	var yaw_before: float = scene.yaw
	var distance_before: float = scene.distance
	var orbit := InputEventMouseButton.new()
	orbit.position = Vector2(720,700)
	orbit.button_index = MOUSE_BUTTON_RIGHT
	orbit.pressed = true
	scene._unhandled_input(orbit)
	var orbit_motion := InputEventMouseMotion.new()
	orbit_motion.relative = Vector2(30,10)
	scene._input(orbit_motion)
	scene._process(1.0/60.0)
	check(not is_equal_approx(scene.yaw,yaw_before),"Right drag still orbits the playground")
	orbit.pressed = false
	scene._input(orbit)
	var zoom := InputEventMouseButton.new()
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	scene._unhandled_input(zoom)
	check(scene.distance < distance_before,"Scroll still zooms the playground")
	scene.yaw = yaw_before
	scene.polar = 1.05
	scene.distance = distance_before
	scene._orbit_delta = Vector2.ZERO
	scene._update_camera()
	var start: Vector2 = scene.camera.unproject_position(scene.spring_tree.center(3.5))
	var finish: Vector2 = scene.camera.unproject_position(scene.spring_tree.center(3.5)+Vector3(-4.7,0,0))
	check(scene._pick_tree(start),"Visible tree can be picked through camera")
	var press := InputEventMouseButton.new()
	press.position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	scene._unhandled_input(press)
	check(scene._tree_drag,"Pointer press starts tree gesture")
	var move := InputEventMouseMotion.new()
	move.position = finish
	scene._input(move)
	for i in range(15): await physics_frame
	check(scene.creature._age>0.1,"Sustained gaze does not restart anticipation animation")
	for i in range(45): await physics_frame
	check(scene.spring_tree.tension > 0.5,"Camera drag creates substantial bend")
	var release := InputEventMouseButton.new()
	release.position = finish
	release.button_index = MOUSE_BUTTON_LEFT
	scene._input(release)
	var states: Array[int] = []
	var displacement := 0.0
	for i in range(600):
		await physics_frame
		if scene.creature.state not in states: states.append(scene.creature.state)
		displacement = maxf(displacement,scene.creature.global_position.distance_to(scene._home))
	check(CreatureActor.State.WIND in states,"Tree release physically strikes Bigfoot")
	check(displacement>0.6,"Impact visibly displaces Bigfoot")
	check(CreatureActor.State.RECOVERING in states,"Bigfoot recovers after impact")
	check(CreatureActor.State.WALKING in states,"Exploration resumes after the interaction")
	scene.begin_tree_drag(start)
	scene.move_tree_drag(finish)
	for i in range(40): await physics_frame
	check(scene._braced,"Repeated teasing triggers a distinct bracing reaction")
	release.position = scene._play_panel.global_position+Vector2(30,30)
	scene._input(release)
	check(not scene._tree_drag and not scene.spring_tree.armed,"Release over UI cancels without a strike")
	scene.reset_creature()
	check(not scene._tree_drag and scene.spring_tree.bend==Vector2.ZERO,"Reset clears tree gesture/motion")
	scene.begin_tree_drag(start)
	scene.move_tree_drag(finish)
	for i in range(30): await physics_frame
	var cancel := InputEventKey.new()
	cancel.pressed = true
	cancel.keycode = KEY_ESCAPE
	scene._input(cancel)
	check(not scene._tree_drag and not scene.spring_tree.armed,"Escape cancels safely")
	scene.begin_tree_drag(start)
	scene.move_tree_drag(finish)
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not scene._tree_drag and not scene.spring_tree.armed,"Focus loss disarms tree")
	var pause := InputEventKey.new()
	pause.pressed = true
	pause.keycode = KEY_P
	scene.begin_tree_drag(start)
	scene._input(pause)
	scene._unhandled_input(pause)
	check(not scene._tree_drag and not scene.spring_tree.held,"Pause cancels held gesture")
	var frozen: Vector2 = scene.spring_tree.bend
	for i in range(8): await physics_frame
	check(scene.spring_tree.bend==frozen,"Pause freezes spring")
	scene._unhandled_input(press)
	check(not scene._tree_drag,"Pause prevents tree pickup")
	scene._unhandled_input(pause)
	scene.reset_creature()
	scene.begin_tree_drag(start)
	scene._tool_button.pressed.emit()
	check(scene.gust_tool and not scene._tree_drag,"Changing to wind cancels a held tree")
	scene._tool_button.pressed.emit()
	check(not scene.gust_tool,"Hands mode can be restored")
	scene.demo_gust()
	for i in range(80): await physics_frame
	check(scene.creature.state==CreatureActor.State.WIND,"Existing gust still works")
	scene.reset_creature()
	scene._carry_from_tray()
	check(scene.creature.is_held(),"Existing carrying still works")
	scene._unhandled_input(pause)
	var carried_position: Vector3 = scene.creature.global_position
	scene._update_carry(finish,0.1)
	check(scene.creature.global_position==carried_position,"Paused carrying does not move Bigfoot")
	scene._unhandled_input(pause)
	scene.reset_creature()
	print("God mode: ",failures," failures; states=",states," displacement=",displacement)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
