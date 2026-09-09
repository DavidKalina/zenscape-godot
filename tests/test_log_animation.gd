extends SceneTree
var failures := 0
var scene: Node
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func ticks(n: int) -> void:
	for i in range(n): await physics_frame
func begin() -> void:
	scene.reset_creature()
	scene._attention_time = 1000.0
	await ticks(120)
	check(scene.mischief.request("log"),"Log has a reachable approach")
func wait_for(phase: String) -> bool:
	for i in range(2400):
		await physics_frame
		if scene.mischief.phase==phase: return true
		if not scene.mischief.busy(): return false
	return false
func run() -> void:
	scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	for i in range(600):
		await physics_frame
		if not scene._world_dirty and scene._refresh_phase==0: break
	var play = scene.mischief
	play.autonomous = false
	await begin()
	var turn_seen := false
	var carried := false
	var max_turn := 0.0
	var max_prop_step := 0.0
	var previous_yaw: float = scene.creature.rotation.y
	var previous_phase: String = play.phase
	var previous_pose: Variant = null
	for i in range(2400):
		await physics_frame
		if play.phase=="turn" or previous_phase=="turn":
			turn_seen = true
			max_turn = maxf(max_turn,absf(angle_difference(previous_yaw,scene.creature.rotation.y)))
		if play.held != null:
			if previous_pose != null: max_prop_step = maxf(max_prop_step,previous_pose.distance_to(play.held.global_position))
			previous_pose = play.held.global_position
		else: previous_pose = null
		if play.phase=="carry":
			carried = true
			check(play.held==scene.loose_props.bodies[3] and play.held.held,"Carry preserves the original log")
		previous_phase = play.phase
		previous_yaw = scene.creature.rotation.y
		if not play.busy(): break
	check(turn_seen and max_turn<0.04,"Facing changes gradually before grasp")
	check(max_prop_step<0.22,"Lift, shoulder settle and toss stay connected")
	check(carried and play._carry_distance>1.5,"He actually walks with the log on his shoulder")
	check("log" in play.history and scene.creature.can_roam(),"Physical toss ends in ordinary locomotion")
	var distance: float = play._carry_distance
	await begin()
	check(await wait_for("carry"),"Reach carry for pause test")
	scene._paused = true
	await ticks(3)
	var feet: Vector3 = scene.creature.global_position
	var log_pose: Transform3D = play.held.global_transform
	await ticks(30)
	check(scene.creature.global_position.is_equal_approx(feet) and play.held.global_transform.is_equal_approx(log_pose),"Pause holds feet and shouldered log")
	scene._paused = false
	await ticks(15)
	check(scene.creature.global_position.distance_to(feet)>0.05,"Loaded walk resumes")
	scene._carry_from_tray()
	check(not play.busy() and not scene.loose_props.bodies[3].held,"Player pickup interrupts shoulder carry cleanly")
	await begin()
	check(await wait_for("carry"),"Reach carry for changed path test")
	var obstacle = scene.loose_props.bodies[4]
	obstacle.global_position = scene.creature.global_position+scene.creature.global_basis.z*0.65+Vector3.UP*0.8
	await ticks(2)
	check(play.phase=="toss","Blocked loaded path stops and transitions to toss")
	print("LOG ANIMATION ",JSON.stringify({"failures":failures,"max_turn_radians":max_turn,"max_prop_step":max_prop_step,"carry_distance":distance}))
	scene.reset_creature()
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
