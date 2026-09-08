extends SceneTree
## Run with Metal: the Fidelity instance transforms are renderer-backed.
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene._refresh_habitat()
	var distance := 0.0
	var unsafe := 0
	var water_count: int = scene.fish.population.size()
	var previous := ""
	# Longer journeys and arrival pauses spread the same activities over more time.
	for frame in range(60*360):
		var before: Vector3 = scene.creature.position
		scene._process(1.0/60.0)
		distance += before.distance_to(scene.creature.position)
		if not scene.navigation.is_safe(scene.creature.position): unsafe += 1
		var state: String = scene.routine.active+":"+scene.routine._phase
		if previous != state:
			print("DAY ",frame/60.0," ",state," history=",scene.routine.history)
			previous = state
		if frame%600 == 0: await process_frame
	for kind in ["stone","tree","sit","fish","sleep","hibernate"]:
		check(kind in scene.routine.history,"Autonomous routine completes "+kind)
	check(distance>25.0,"He keeps exploring between activities")
	check(unsafe == 0,"Every autonomous frame remains safely grounded")
	check(scene.routine.last_cancel.is_empty(),"No stuck approaches or failed performances: "+scene.routine.last_cancel)
	check(scene.fish.population.size()==water_count,"Fishing preserves the explicit fish population")
	print("ROUTINE DAY: distance=",distance," unsafe=",unsafe," history=",scene.routine.history," failures=",failures)
	scene.free()
	quit(1 if failures else 0)
