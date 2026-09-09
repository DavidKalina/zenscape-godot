extends SceneTree
var failures := 0
var scene: Node
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func ticks(count: int) -> void:
	for i in range(count): await physics_frame
func _run() -> void:
	scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	for i in range(600):
		await physics_frame
		if not scene._world_dirty and scene._refresh_phase == 0: break
	var play = scene.mischief
	play.autonomous = false
	var results := {}
	for kind in ["stone","log","tree"]:
		scene.reset_creature()
		scene._attention_time = 100.0
		await ticks(120)
		var requested: bool = play.request(kind)
		check(requested,"Can plan "+kind+" from the preset")
		var grasped := false
		var launched := false
		var peak := 0.0
		var body: Node3D = play.target
		var origin: Vector3 = body.global_position if body != null else Vector3.ZERO
		for i in range(2100):
			await physics_frame
			if play.held != null: grasped = true
			if kind == "log" and play.phase == "perform" and scene.creature._age>2.4 and scene.creature._age<2.42:
				for side in ["R","L"]:
					check(scene.creature.hand_position(side).distance_to(scene.creature.hand_targets[side].point)<0.15,"Both palms contact the lifted log")
			if kind == "log" and play.phase == "perform" and scene.creature._age>=2.95 and scene.creature._age<3.1:
				check(scene.creature.hand_targets.has("R") and scene.creature.hand_targets.has("L"),"Both arms continue the shove through release")
			if kind == "tree": peak = maxf(peak,scene.spring_tree.tension)
			elif body != null and body.launched:
				launched = true
				peak = maxf(peak,body.global_position.distance_to(origin))
			if not play.busy(): break
		await ticks(120)
		if kind != "tree" and body != null: peak = maxf(peak,body.global_position.distance_to(origin))
		check(kind in play.history,"Completes "+kind+" ("+play.last_cancel+")")
		if kind == "tree": check(peak>0.4,"Bigfoot visibly tensions the real spring")
		else: check(grasped and launched and peak>2.0,"Same "+kind+" is grasped and flies under physics")
		check(scene.creature.can_roam(),"Resumes life after "+kind)
		results[kind] = {"grasped":grasped,"launched":launched,"peak":peak,"cancel":play.last_cancel}

	# Pause preserves the resident's ownership and exact physical pose.
	await prepare("log")
	var log_body = play.held
	check(log_body != null,"Log reaches its two-hand grasp")
	var pause := InputEventKey.new()
	pause.pressed = true
	pause.keycode = KEY_P
	scene._unhandled_input(pause)
	await ticks(3)
	var frozen: Transform3D = log_body.global_transform
	var age: float = scene.creature._age
	await ticks(40)
	check(log_body.global_transform.is_equal_approx(frozen) and is_equal_approx(age,scene.creature._age),"Pause freezes grasp and performance together")
	scene._unhandled_input(pause)
	await ticks(15)
	check(scene.creature._age>age and play.held==log_body,"Resume continues the same grasp")
	scene._carry_from_tray()
	check(not play.busy() and not log_body.held and scene.creature.is_held(),"Picking up Bigfoot drops his actual log")
	check(scene.loose_props.bodies.size()==6,"Interrupted play never duplicates a body")

	await prepare("tree")
	check(scene.spring_tree.held,"Resident owns the spring tree")
	scene._unhandled_input(pause)
	await ticks(3)
	var bend: Vector2 = scene.spring_tree.bend
	await ticks(30)
	check(scene.spring_tree.held and scene.spring_tree.bend.is_equal_approx(bend),"Pause preserves resident tree grip")
	scene._unhandled_input(pause)
	var mouse: Vector2 = scene.camera.unproject_position(scene.spring_tree.center(3.0))
	scene.begin_tree_drag(mouse)
	check(not play.busy() and scene._tree_drag and scene.spring_tree.held and not play.tree_protected,"Player can take over the tree")
	scene.cancel_tree_drag()

	await prepare("stone")
	var stone = play.held
	scene._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not play.busy() and not stone.held,"Focus loss releases resident prop ownership")

	await prepare("log")
	scene.creature.receive_impulse(Vector3(120,90,0))
	await ticks(2)
	check(not play.busy() and not scene.loose_props.bodies[3].held,"Physical interruption releases the log")

	scene.reset_creature()
	scene._attention_time = 100.0
	await ticks(120)
	check(play.request("stone"),"Starts approach for moved-target check")
	var moved = play.target
	moved.global_position += Vector3.RIGHT
	await ticks(2)
	check(not play.busy() and not moved.held,"Moved target cancels approach without teleporting it back")

	await prepare("tree")
	for i in range(200):
		await physics_frame
		if scene.creature._age>=2.9: break
	stone = scene.loose_props.bodies[0]
	stone.global_position = scene.spring_tree.center(2.1)
	await ticks(24)
	check(stone.launched and stone.linear_velocity.length()>1.0,"Tree recoil bats an actual loose body")
	scene.reset_creature()
	check(not play.busy() and not scene.spring_tree.held and scene.loose_props.bodies.all(func(body): return not body.held and body.global_transform.is_equal_approx(body.home)),"Reset clears resident ownership and restores props")
	await ticks(120)
	scene._attention_time = 0.0
	scene.brain.phase = CreatureBrain.Phase.REST
	scene.brain._wait = 0.0
	play.autonomous = true
	play._cooldown = 0.0
	play.advance(1.0/60.0)
	check(play.busy(),"Autonomous play starts between completed journeys")
	play.cancel()
	print("BIGFOOT MISCHIEF ",JSON.stringify({"failures":failures,"actions":results,"history":play.history}))
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)

func prepare(kind: String) -> void:
	scene.reset_creature()
	scene._attention_time = 100.0
	await ticks(120)
	check(scene.mischief.request(kind),"Prepare "+kind)
	for i in range(2100):
		await physics_frame
		if scene.mischief.held != null or (kind == "tree" and scene.spring_tree.held): return
		if not scene.mischief.busy(): break
	check(false,"Reached grasp for "+kind)
