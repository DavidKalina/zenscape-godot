extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ground = load("res://scripts/reference_source_ground.gd").new()
	ground.setup()
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/terrain-probes.json"))
	var maximum := 0.0
	var total := 0.0
	for p: Array in info.probes:
		var error: float = absf(ground.height_at(p[0], p[1]) - p[2])
		maximum = maxf(maximum, error)
		total += error
	print("Independent height probes: max ", maximum, " mean ", total / info.probes.size())
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/bird-flight.json"))
	var geometry = load("res://assets/zen_reference/geometry.scn").instantiate()
	root.add_child(geometry)
	var flight = load("res://studies/bird_flight.gd").new()
	flight.setup(geometry.get_node(data.mesh).multimesh, ground, data)
	var checkpoint := 0
	var worst_position := 0.0
	var worst_phase := 0.0
	var mode_errors := 0
	for i in range(300):
		flight.advance(1.0/30.0, false, data.wind, Vector2(data.direction[0], data.direction[1]))
		if i + 1 != int(data.frames[checkpoint].step):
			continue
		for j in range(flight.birds.size()):
			var b: Dictionary = flight.birds[j]
			var expected: Dictionary = data.frames[checkpoint].birds[j]
			worst_position = maxf(worst_position, Vector3(b.x,b.y,b.z).distance_to(Vector3(expected.x,expected.y,expected.z)))
			worst_phase = maxf(worst_phase, absf(b.phase-expected.phase))
			if b.mode != expected.mode:
				mode_errors += 1
		checkpoint += 1
	print("Source terrain flight: position ", worst_position, " phase ", worst_phase, " mode differences ", mode_errors)
	var ok: bool = maximum < 0.0001 and total / info.probes.size() < 0.001 and worst_position < 0.001 and worst_phase < 0.001 and mode_errors == 0
	geometry.queue_free()
	await process_frame
	print("PASS: continuous source terrain and production flight" if ok else "FAIL: continuous source terrain")
	quit(0 if ok else 1)
