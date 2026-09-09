extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func ticks(count: int) -> void:
	for i in range(count): await physics_frame
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
	scene._attention_time = 100.0
	scene.brain.enabled = false
	var props = scene.loose_props
	check(props.bodies.size()==6,"Preset contains stones, a log and selected boulders")
	var stone = props.bodies[0]
	var log_body = props.bodies[3]
	var boulder = props.bodies[4]
	var mouse: Vector2 = scene.camera.unproject_position(stone.global_position)
	check(props.pick(mouse)==stone,"Loose stone is discoverable through camera picking")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = mouse
	scene._unhandled_input(press)
	check(props.grabbed == stone,"Press grabs a loose stone")
	var start: Vector3 = stone.global_position
	for i in range(12):
		var motion := InputEventMouseMotion.new()
		motion.position = mouse+Vector2(i*9,-i*3)
		scene._input(motion)
		await physics_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = mouse+Vector2(99,-33)
	scene._input(release)
	check(props.grabbed==null and stone.linear_velocity.length()>2.0,"A cursor flick produces release velocity")
	await ticks(30)
	check(stone.global_position.distance_to(start)>0.5,"Thrown stone flies under physics")
	# Direct physical setups isolate solver behavior from the input mapping above.
	scene.reset_creature()
	scene._attention_time = 100.0
	stone.global_position = scene.creature.global_position+Vector3(0,1.3,2.0)
	stone.release(Vector3(0,0,-7))
	await ticks(35)
	check(props.hits.stone>0,"Physical stone contact triggers a light bonk")
	scene.reset_creature()
	scene._attention_time = 100.0
	log_body.global_position = scene.creature.global_position+Vector3(0,0.45,2.7)
	log_body.release(Vector3(0,0,-8))
	await ticks(40)
	check(props.hits.log>0,"A tumbling log contacts Bigfoot")
	check(scene.creature.state in [CreatureActor.State.WIND,CreatureActor.State.RECOVERING],"Log impact knocks him over")
	var recovered := false
	var splashed_in := false
	var log_displacement: float = scene.creature.global_position.distance_to(scene._home)
	for i in range(600):
		await physics_frame
		if scene.creature.state == CreatureActor.State.SWIMMING: splashed_in = true
		log_displacement = maxf(log_displacement,scene.creature.global_position.distance_to(scene._home))
		if scene.creature.can_roam():
			recovered = true
			break
	check(recovered and log_displacement>0.5,"Log visibly displaces Bigfoot and he recovers")
	check(scene.valid_landing(scene.creature.global_position),"Log recovery finishes with clear footing")
	check(splashed_in,"A knock into the pool transitions to playful swimming")
	scene.reset_creature()
	scene._attention_time = 100.0
	stone.global_position = Vector3(2.0,0.4,0)
	stone.release(Vector3(6,-0.8,0))
	await ticks(65)
	check(stone.skip_count>=1,"A low fast stone skips on actual pond water")
	var skips: int = stone.skip_count
	log_body.global_position = Vector3(3,0.8,0)
	log_body.release(Vector3.ZERO)
	await ticks(300)
	check(absf(log_body.global_position.y-(-0.03))<0.55,"Log settles buoyantly at the water surface")
	check(log_body.water_entries>0,"Water entry generates a splash")
	var floating: Vector3 = log_body.global_position
	scene.reset_creature()
	scene._attention_time = 100.0
	boulder.global_position = scene.creature.global_position+Vector3(0,0.85,4.5)
	boulder.release(Vector3(0,0,-4.5))
	var before: Vector3 = scene.creature.global_position
	await ticks(80)
	check(props.dodges>0,"Approaching boulder provokes anticipation")
	check(scene.creature.global_position.distance_to(before)>0.7,"Bigfoot scrambles out of the boulder path")
	scene.reset_creature()
	scene._attention_time = 100.0
	var hill_start: Vector3 = boulder.global_position
	boulder.release(Vector3.ZERO)
	await ticks(150)
	check(boulder.global_position.distance_to(hill_start)>0.5 and boulder.global_position.y<hill_start.y-0.2,"Boulder rolls down the actual terrain slope")
	scene.reset_creature()
	scene._attention_time = 0.0
	stone.global_position = Vector3(3.2,0.5,5.0)
	stone.release(Vector3.ZERO)
	var inspected := false
	for i in range(720):
		await physics_frame
		if scene.brain.phase == CreatureBrain.Phase.INSPECT and scene.brain._interest_id.begins_with("loose:"):
			inspected = true
			break
	check(inspected,"Bigfoot reaches the dropped object and inspects it")
	check(props.investigations>0,"A newly dropped settled object invites investigation")
	var investigated: int = props.investigations
	# Cancellation and pause use the same entry points as live UI events.
	scene.reset_creature()
	mouse = scene.camera.unproject_position(stone.global_position)
	props.begin_grab(stone,mouse)
	var original: Transform3D = stone.global_transform
	props.move_grab(mouse+Vector2(100,20))
	await ticks(10)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	scene._input(escape)
	check(props.grabbed==null and stone.global_transform.is_equal_approx(original),"Escape restores the grabbed object")
	props.begin_grab(stone,mouse)
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(props.grabbed==null,"Focus loss cancels prop grabbing")
	props.begin_grab(stone,mouse)
	release.position = scene._play_panel.global_position+Vector2(25,25)
	scene._input(release)
	check(props.grabbed==null and not stone.launched,"UI release cancels without throwing")
	props.begin_grab(stone,mouse)
	scene._tool_button.pressed.emit()
	check(props.grabbed==null and scene.gust_tool,"Tool change cancels prop grabbing")
	scene._tool_button.pressed.emit()
	stone.release(Vector3(4,2,0))
	var pause := InputEventKey.new()
	pause.pressed = true
	pause.keycode = KEY_P
	scene._input(pause)
	scene._unhandled_input(pause)
	await ticks(2)
	var frozen: Vector3 = stone.global_position
	await ticks(20)
	check(stone.global_position.is_equal_approx(frozen),"Pause freezes physical props")
	scene._unhandled_input(pause)
	await ticks(10)
	check(not stone.global_position.is_equal_approx(frozen),"Resume restores physical motion")
	scene.reset_creature()
	check(props.bodies.all(func(body): return body.global_transform.is_equal_approx(body.home)),"Reset returns every loose prop to its home")
	# The same world-space hand motion should feel distinctly heavier.
	var follows := {}
	for body in [stone,log_body,boulder]:
		var at: Vector2 = scene.camera.unproject_position(body.global_position)
		props.begin_grab(body,at)
		var x_before: float = body.global_position.x
		props.move_grab(scene.camera.unproject_position(props._origin+Vector3.RIGHT))
		await ticks(6)
		follows[body.kind] = absf(body.global_position.x-x_before)
		props.cancel()
	check(follows.stone>follows.log and follows.log>follows.boulder,"Stone, log and boulder have distinct hand-following weight")
	props.begin_grab(stone,scene.camera.unproject_position(stone.global_position))
	await ticks(90)
	props.release()
	check(stone.linear_velocity.length()<0.1,"Holding still produces a quiet drop")
	print("LOOSE PROPS ",JSON.stringify({"failures":failures,"hits":props.hits,"skips":skips,"floating":str(floating),"dodges":props.dodges,"investigations":investigated,"hand_follow":follows,"log_displacement":log_displacement,"log_recovered":recovered,"swam_after_impact":splashed_in,"inspected":inspected}))
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
