extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._process(0.05)
	scene._paused = true
	var flight = scene._bird_flight
	var before: Array = flight.birds.duplicate(true)
	for terrain in [0.5,0.99,1.0]:
		scene._growth.set_terrain(terrain)
		scene._process(0.05)
		var visible := 0
		for i in range(flight.birds.size()):
			var b: Dictionary = flight.birds[i]
			if b.out > 0.001:
				visible += 1
			check(b.x == before[i].x and b.y == before[i].y and b.z == before[i].z and b.phase == before[i].phase,"Scrubbing paused growth does not advance flight")
		check(visible == 0 if terrain < 0.995 else visible > 0,"Paused flock follows terrain readiness: " + str(terrain))
	scene._growth.set_foliage(0.0)
	scene._process(0.05)
	for b: Dictionary in flight.birds:
		check(b.out == 0.0,"Paused foliage scrub hides wildlife")
	scene.queue_free()
	await process_frame
	print("PASS: paused reveal updates flock visibility without advancing motion" if failures == 0 else "FAIL: paused reveal")
	quit(1 if failures else 0)
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
