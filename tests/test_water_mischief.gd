extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.unfocusable = false
	root.always_on_top = true
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440,960)
	root.content_scale_factor = 1.0
	for i in range(600):
		await physics_frame
		if not scene._world_dirty and scene._refresh_phase == 0: break
	check(not scene._world_dirty and scene._refresh_phase == 0,"Navigation settles")
	scene.brain.enabled = false
	scene._attention_time = 60.0
	var water := Vector3(3,-0.2,0)
	var mouse: Vector2 = scene.camera.unproject_position(water)
	check(scene.water_play.pick(mouse) != null,"Visible pool is cursor-pickable")
	var shore: Variant = scene.water_play.shore_from(water)
	check(shore != null,"Deep pool has an unobstructed dry exit")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = scene.camera.unproject_position(scene.creature.global_position+Vector3.UP*2.2)
	scene._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = press.position+Vector2(8,0)
	scene._input(motion)
	check(scene._carrying,"Can pick up Bigfoot")
	# Drive the same pointer mapping as live carrying, without a physical mouse.
	scene.set_process(false)
	for i in range(90):
		mouse = scene.camera.unproject_position(water)
		scene._update_carry(mouse,1.0/60.0)
		await physics_frame
	check(scene._wet_hold,"Cursor lowers held Bigfoot into water")
	check(scene.creature.global_position.y < -1.0,"Dunk visibly submerges his body")
	check(scene.water_play.splash_count>0,"Dunk produces a splash")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = mouse
	var release_began := Time.get_ticks_usec()
	scene._input(release)
	var release_usec := Time.get_ticks_usec()-release_began
	check(scene.creature.state == CreatureActor.State.SWIMMING,"Release starts swimming")
	var start: Vector3 = scene.creature.global_position
	var saw_shake := false
	var saw_alert := false
	for i in range(600):
		await physics_frame
		scene.water_play.advance(1.0/60.0)
		if scene.creature.state == CreatureActor.State.SHAKING: saw_shake = true
		if saw_shake and scene.creature.state == CreatureActor.State.ALERT: saw_alert = true
	check(saw_shake,"He reaches shore and shakes off")
	check(saw_alert,"Shake-off leads to an annoyed look")
	check(scene.valid_landing(scene.creature.global_position),"Recovery ends on dry safe ground")
	check(scene.creature.global_position.distance_to(start)>1.0,"Paddling visibly moves him to shore")
	scene.set_process(true)
	scene._attention_time = 0.0
	var explored := false
	for i in range(420):
		await physics_frame
		if scene.creature.state == CreatureActor.State.WALKING: explored = true
	check(explored,"Autonomous exploration resumes")
	# Interrupt every water phase without leaving a stuck actor or input gesture.
	scene.reset_creature()
	scene._attention_time = 60.0
	scene._begin_carry(mouse)
	scene.set_process(false)
	for i in range(90): scene._update_carry(mouse,1.0/60.0)
	scene._drop(mouse)
	var pause := InputEventKey.new()
	pause.pressed = true
	pause.keycode = KEY_P
	scene._unhandled_input(pause)
	scene._process(1.0/60.0)
	var frozen: Vector3 = scene.creature.global_position
	var splash_before: int = scene.water_play.splash_count
	for i in range(12): await physics_frame
	check(scene.creature.global_position == frozen,"Pause freezes swimming")
	check(scene.water_play.splash_count == splash_before,"Pause freezes water effects")
	scene._begin_carry(mouse)
	check(not scene._carrying,"Paused swim cannot be picked up")
	scene._unhandled_input(pause)
	scene._process(1.0/60.0)
	scene._begin_carry(mouse)
	check(scene._carrying and scene.creature.is_held(),"Can grab him mid-swim")
	for i in range(90): scene._update_carry(mouse,1.0/60.0)
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not scene._carrying and scene.creature.state == CreatureActor.State.LANDING,"Focus loss cancels a held dunk")
	scene.reset_creature()
	scene._begin_carry(mouse)
	for i in range(90): scene._update_carry(mouse,1.0/60.0)
	var cancel := InputEventKey.new()
	cancel.pressed = true
	cancel.keycode = KEY_ESCAPE
	scene._input(cancel)
	check(not scene._carrying and scene.creature.state == CreatureActor.State.LANDING,"Escape returns dunked Bigfoot safely")
	scene.reset_creature()
	scene._begin_carry(mouse)
	for i in range(90): scene._update_carry(mouse,1.0/60.0)
	scene._drop(Vector2(-1,-1))
	check(not scene._carrying and scene.creature.state == CreatureActor.State.LANDING,"Release outside viewport cancels")
	scene.reset_creature()
	scene._begin_carry(mouse)
	for i in range(90): scene._update_carry(mouse,1.0/60.0)
	scene._tool_button.pressed.emit()
	check(not scene._carrying and scene.gust_tool,"Tool switch cancels a dunk gesture")
	scene._tool_button.pressed.emit()
	scene.reset_creature()
	scene._begin_carry(mouse)
	for i in range(90): scene._update_carry(mouse,1.0/60.0)
	scene._drop(mouse)
	scene.reset_creature()
	check(scene.creature.can_roam() and scene.creature.global_position.is_equal_approx(scene._home) and not scene._carrying,"Reset exits swimming")
	scene._begin_carry(mouse)
	for i in range(90): scene._update_carry(mouse,1.0/60.0)
	scene._drop(scene._play_panel.global_position+Vector2(25,25))
	check(not scene._carrying and scene.creature.state == CreatureActor.State.LANDING,"UI release cancels a held dunk")
	scene.reset_creature()
	scene._begin_carry(mouse)
	for i in range(90): scene._update_carry(mouse,1.0/60.0)
	scene._drop(mouse)
	for i in range(600):
		scene.creature.advance(1.0/60.0)
		if scene.creature.state == CreatureActor.State.SHAKING: break
	check(scene.creature.state == CreatureActor.State.SHAKING,"Repeated dunk reaches shake-off")
	scene._begin_carry(mouse)
	check(scene._carrying and scene.creature.is_held(),"Can interrupt shake-off with another pickup")
	scene.reset_creature()
	check(scene.creature.can_roam() and not scene._water_reaction,"Reset clears the interrupted water reaction")
	check(scene.water_play.drops.all(func(drop): return not drop.mesh.visible),"Reset clears splash pool")
	print("WATER MISCHIEF ",JSON.stringify({"failures":failures,"release_usec":release_usec,"shore":str(shore),"shake":saw_shake,"annoyed":saw_alert,"explored":explored}))
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
