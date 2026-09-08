extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._refresh_habitat()
	var best_rest := INF
	var best_at := Vector3.ZERO
	for point in scene.navigation._nodes:
		if point.distance_to(scene.creature.position)>8.0 or scene.navigation.path(scene.creature.position,point).is_empty(): continue
		var rise := 0.0
		for offset in [Vector3(0.6,0,0),Vector3(-0.6,0,0),Vector3(0,0,0.6),Vector3(0,0,-0.6)]:
			var ground: Variant = scene.navigation._ground(point+offset)
			rise = maxf(rise,absf(ground.y-point.y)) if ground != null else INF
		if rise<best_rest:
			best_rest=rise
			best_at=point
	print("BEST REST ",best_rest," at=",best_at)
	if "--rest-only" in OS.get_cmdline_user_args():
		scene.free()
		quit()
		return
	var previous := ""
	var distance := 0.0
	var was_safe := true
	for frame in range(60*240):
		var before: Vector3 = scene.creature.position
		scene._process(1.0/60.0)
		distance += before.distance_to(scene.creature.position)
		var safe: bool = scene.navigation.is_safe(scene.creature.position)
		if was_safe and not safe: print("UNSAFE frame=",frame," from=",before," to=",scene.creature.position," routine=",scene.routine.active," brain=",scene.brain.phase," route=",scene.brain._route," waypoint=",scene.brain._waypoint)
		was_safe = safe
		var state: String = scene.routine.active+":"+scene.routine._phase
		if state != previous:
			print("DAY t=",frame/60.0," state=",state," at=",scene.creature.position," cancel=",scene.routine.last_cancel," history=",scene.routine.history)
			previous = state
		if frame%600 == 0:
			print("CLOCK ",frame/60.0," routine=",scene.routine._clock," next=",scene.routine._next_action," choice=",scene.routine._choice," actor=",scene.creature.state," safe=",scene.navigation.is_safe(scene.creature.position)," paused=",scene._paused," blocked=",scene._habitat_blocked," growth=",scene._growth.terrain)
			await process_frame
	print("DAY RESULT distance=",distance," history=",scene.routine.history," lastcancel=",scene.routine.last_cancel)
	scene.free()
	quit()
