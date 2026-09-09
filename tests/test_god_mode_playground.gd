extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	for i in range(8): await physics_frame
	check(scene.valid_landing(scene._home),"Preset has safe home")
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
	for i in range(60): await physics_frame
	check(scene.spring_tree.tension > 0.5,"Camera drag creates substantial bend")
	var release := InputEventMouseButton.new()
	release.position = finish
	release.button_index = MOUSE_BUTTON_LEFT
	print("GESTURE ",start," to ",finish," controls=",scene._over_controls(finish)," tension=",scene.spring_tree.tension," pos=",scene.creature.global_position," root=",scene.spring_tree.global_position)
	scene._input(release)
	print("RELEASE armed=",scene.spring_tree.armed," bend=",scene.spring_tree.bend)
	var states: Array[int] = []
	var displacement := 0.0
	var closest := INF
	var peak_speed := 0.0
	var prev_pose: Vector2 = scene.spring_tree.bend
	for i in range(600):
		await physics_frame
		for h in [1.5,2.1,2.7,3.3,3.9]:
			var p: Vector3 = scene.spring_tree.center(h)
			var d := p.distance_to(scene.creature.global_position+Vector3.UP*1.6)
			closest = minf(closest,d)
			if d < 1.25: peak_speed = maxf(peak_speed,p.distance_to(scene.spring_tree.center(h,prev_pose))*60.0)
		prev_pose = scene.spring_tree.bend
		if scene.creature.state not in states: states.append(scene.creature.state)
		displacement = maxf(displacement,scene.creature.global_position.distance_to(scene._home))
	print("CONTACT closest=",closest," peak_speed=",peak_speed)
	check(CreatureActor.State.WIND in states,"Tree release physically strikes Bigfoot")
	check(displacement>0.6,"Impact visibly displaces Bigfoot")
	check(CreatureActor.State.RECOVERING in states,"Bigfoot recovers after impact")
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
	scene._unhandled_input(pause)
	var frozen: Vector2 = scene.spring_tree.bend
	for i in range(8): await physics_frame
	check(scene.spring_tree.bend==frozen,"Pause freezes spring")
	scene._unhandled_input(press)
	check(not scene._tree_drag,"Pause prevents tree pickup")
	scene._unhandled_input(pause)
	scene.reset_creature()
	scene.demo_gust()
	for i in range(80): await physics_frame
	check(scene.creature.state==CreatureActor.State.WIND,"Existing gust still works")
	scene.reset_creature()
	scene._carry_from_tray()
	check(scene.creature.is_held(),"Existing carrying still works")
	scene.reset_creature()
	print("God mode: ",failures," failures; states=",states," displacement=",displacement)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
