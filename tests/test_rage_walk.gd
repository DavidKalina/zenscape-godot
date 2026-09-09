extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	for i in range(600):
		await physics_frame
		if not scene._world_dirty and scene._refresh_phase==0: break
	scene.mischief.autonomous = false
	scene._attention_time = 1000.0
	var actor: CreatureActor = scene.creature
	var start := actor.global_position
	var destination := start+Vector3(0.5,0,0)
	actor.walk_step(destination,0.4,1.0/60.0)
	var calm := Vector2(actor.global_position.x-start.x,actor.global_position.z-start.z).length()
	var calm_stride := actor.player.speed_scale
	scene.temper.provoke(1.0)
	start = actor.global_position
	actor.walk_step(destination,0.4,1.0/60.0)
	var angry := Vector2(actor.global_position.x-start.x,actor.global_position.z-start.z).length()
	check(absf(angry/calm-2.0)<0.01,"Rage doubles actual travel during an existing walk")
	check(is_equal_approx(actor.player.speed_scale/calm_stride,2.0),"Stride speeds up with the feet")
	check(is_equal_approx(actor.walking_speed(0.4),0.8),"Navigation can check the full accelerated distance")
	scene.temper.reset()
	start = actor.global_position
	actor.walk_step(destination,0.4,1.0/60.0)
	var cooled := Vector2(actor.global_position.x-start.x,actor.global_position.z-start.z).length()
	check(absf(cooled/calm-1.0)<0.01,"Cooling restores walking speed without restarting the walk")
	print("RAGE WALK ",JSON.stringify({"failures":failures,"travel_ratio":angry/calm,"cooled_ratio":cooled/calm}))
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
