extends SceneTree
var scene: Node
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func ticks(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	scene = load("res://studies/god_mode_playground.tscn").instantiate()
	root.add_child(scene)
	for i in range(600):
		await physics_frame
		if not scene._world_dirty and scene._refresh_phase==0: break
	scene.mischief.autonomous = false
	scene._attention_time = 1000.0
	var temper = scene.temper
	check(temper._eyes.size()==2,"Both actual eye meshes are found")
	temper.provoke(0.45)
	temper.provoke(0.45)
	check(not temper.enraged,"Mild provocation builds up before rage")
	temper.provoke(0.45)
	check(temper.enraged and scene.creature.action_tempo>1.0,"Repeated provocation starts faster rage")
	await ticks(15)
	check(temper._puffs.any(func(p): return p.visible),"Steam emits while enraged")
	check(temper._eyes.all(func(e): return e.material_override==temper._red),"Enraged eyes turn red")
	scene._paused = true
	var remaining: float = temper.remaining
	await ticks(20)
	check(is_equal_approx(remaining,temper.remaining),"Pause freezes temper")
	scene._paused = false
	check(scene.mischief.request("stone"),"Rage can plan a physical throw")
	var body = scene.mischief.target
	var speed := 0.0
	for i in range(1600):
		await physics_frame
		if body.launched:
			speed = body.linear_velocity.length()
			break
	check(speed>18.0,"Enraged stone throw exceeds ordinary throw speed")
	scene.reset_creature()
	scene._attention_time = 1000.0
	await ticks(120)
	temper.provoke(1.0)
	check(scene.mischief.request("log"),"Rage can plan a loaded log throw")
	body = scene.mischief.target
	var log_speed := 0.0
	for i in range(1600):
		await physics_frame
		if body.launched:
			log_speed = body.linear_velocity.length()
			break
	check(log_speed>13.0,"Enraged log throw is stronger too")
	scene.mischief.cancel()
	temper.remaining = 0.02
	await ticks(4)
	check(not temper.enraged and scene.creature.action_tempo==1.0,"Rage cools back to ordinary tempo")
	check(temper._eyes.all(func(e): return e.material_override!=temper._red),"Cooling restores eye materials")
	temper.provoke(1.0)
	scene.reset_creature()
	check(not temper.enraged and temper.heat==0.0,"Reset clears temper")
	print("BIGFOOT RAGE ",JSON.stringify({"failures":failures,"stone_speed":speed,"log_speed":log_speed,"eyes":temper._eyes.size(),"puff_pool":temper._puffs.size()}))
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
