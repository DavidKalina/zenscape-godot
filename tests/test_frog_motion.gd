extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var motion = scene._frog_motion
	for f in motion.frogs:
		print("Frog bank ",f.home," landing ",f.landing," native ground ",motion._ground.height_at(f.home.x,f.home.z))
		check(absf(f.home.y-motion._ground.height_at(f.home.x,f.home.z)-0.02) < 0.0001,"Resting feet follow native terrain")
		check(f.landing != f.home and motion.is_water(f.landing),"Each frog has a wet landing")
	motion.startle()
	var saw_hop := false
	var saw_swim := false
	var saw_return := false
	for i in range(180):
		motion.advance(1.0/30.0,false)
		for f in motion.frogs:
			saw_hop = saw_hop or f.mode == "in"
			saw_swim = saw_swim or f.mode == "swim"
			saw_return = saw_return or f.mode == "out"
			if f.mode == "swim":
				check(motion.is_water(Vector3(f.position.x,f.landing.y,f.position.z)),"Paddling remains over water")
	check(saw_hop and saw_swim and saw_return,"Startle completes hop, paddle and return")
	for f in motion.frogs:
		check(f.mode == "sit" and f.position.distance_to(f.home) < 0.0001,"Frog lands back on its bank")
	check(motion._next_ring == 2,"One contact ripple per water entry")
	var before: Array = motion.frogs.duplicate(true)
	var stopped: float = motion.time
	motion.advance(1.0,true)
	check(motion.frogs == before and motion.time == stopped,"Pause preserves exact frog state")
	scene._growth.set_water(0.0)
	motion.advance(1.0,false)
	check(motion.frogs == before and motion.time == stopped,"Absent habitat freezes frog motion")
	scene.queue_free()
	await process_frame
	print("PASS: frog hops, wet paddling, return, ripples and pause" if failures == 0 else "FAIL: frog motion")
	quit(1 if failures else 0)
