extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1
func run() -> void:
	var scene = load("res://studies/bigfoot_lair.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.replaying = false
	scene._growth.publish()
	scene._precipitation.set_weather(0,true)
	scene.routine._next_action = INF
	scene._bring_fish()
	check(scene.routine.active=="fish","Fish invitation starts from the actual cave spawn")
	if scene.routine.active=="fish":
		for i in range(120*60):
			scene._process(1.0/60.0)
			if "fish" in scene.lair.stash: break
		check("fish" in scene.lair.stash,"Invited resident walks to the pond, catches and delivers a fish")
		check(scene.fish.capture_state().stored_ids.size()==1,"Delivery consumes exactly one real pond fish")
	var depleted: Array[String] = []
	for entry in scene.fish.population: depleted.append(entry.id)
	scene.fish.restore_state({"version":1,"stored_ids":depleted})
	scene._bring_fish()
	scene._process(0.5)
	check(scene._life_status.text.contains("no reachable fishing spot"),"An unavailable fishing request keeps its explanation visible")
	scene.queue_free()
	await process_frame
	print("FISH INVITATION: failures=",failures)
	quit(1 if failures else 0)
