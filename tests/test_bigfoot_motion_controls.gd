extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _run() -> void:
	var scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	for i in range(120): await physics_frame
	var tuner = get_first_node_in_group("tree_motion_tuner")
	check(tuner != null,"Animation controls are available in the game")
	tuner._watch_idle()
	check(tuner.idle_watch>0.0,"Idle preview starts")
	for i in range(180): await physics_frame
	check(scene.creature.state == CreatureActor.State.IDLE,"Idle preview suppresses autonomous movement")
	tuner._stroll()
	check(scene.brain.phase == CreatureBrain.Phase.MOVE,"Stroll chooses a reachable route")
	var start: Vector3 = scene.creature.global_position
	for i in range(150): await physics_frame
	check(scene.creature.global_position.distance_to(start)>0.5,"Stroll actually moves the character")
	check(scene.creature.player.current_animation=="Walk","Stroll plays the walk")
	scene.creature.set_personality(false)
	for i in range(90): await physics_frame
	check(scene.creature.player.is_playing(),"Original remains animated after switching during a stroll")
	scene.creature.set_personality(true)
	tuner._watch_idle()
	for i in range(90): await physics_frame
	check(scene.creature.player.current_animation=="Idle","Idle preview returns from walking")
	print("Bigfoot motion controls: ",failures," failures")
	quit(1 if failures else 0)
