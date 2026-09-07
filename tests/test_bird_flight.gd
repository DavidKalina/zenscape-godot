extends SceneTree
var failures := 0
class SourceGround extends RefCounted:
	var samples: Array
	var index := 0
	var query_error := 0.0
	func height_at(x: float,z: float) -> float:
		var sample: Array = samples[index]
		index += 1
		query_error = maxf(query_error,Vector2(x-sample[0],z-sample[1]).length())
		return sample[2]
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var geometry = load("res://assets/zen_reference/geometry.scn").instantiate()
	root.add_child(geometry)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/bird-flight.json"))
	var ground = load("res://scripts/reference_ground.gd").new()
	ground.setup(geometry.get_node("terrain"))
	var flight = load("res://studies/bird_flight.gd").new()
	var source_ground := SourceGround.new()
	source_ground.samples = data.heights
	flight.setup(geometry.get_node(data.mesh).multimesh,source_ground,data)
	var direction := Vector2(data.direction[0],data.direction[1])
	var checkpoint := 0
	for i in range(300):
		flight.advance(1.0/30.0,false,data.wind,direction)
		if i+1 == int(data.frames[checkpoint].step):
			var position_error := 0.0
			var phase_error := 0.0
			var mode_errors := 0
			for j in range(flight.birds.size()):
				var b: Dictionary = flight.birds[j]
				var expected: Dictionary = data.frames[checkpoint].birds[j]
				position_error = maxf(position_error,Vector3(b.x,b.y,b.z).distance_to(Vector3(expected.x,expected.y,expected.z)))
				phase_error = maxf(phase_error,absf(b.phase-expected.phase))
				if b.mode != expected.mode:
					mode_errors += 1
			print("Flight step ", i+1, " position error ",position_error," phase error ",phase_error," mode differences ",mode_errors)
			check(position_error < 0.001 and phase_error < 0.001 and mode_errors == 0,"Flight follows exported source trajectory")
			checkpoint += 1
	check(source_ground.query_error < 0.001 and source_ground.index == data.heights.size(), "Native flight requests the same source terrain samples")
	var before: Array = flight.birds.duplicate(true)
	flight.advance(10.0,true,data.wind,direction)
	check(flight.birds == before,"Pause freezes flight and wing phases")
	flight.growth = 0.0
	flight.advance(0.05,false,data.wind,direction)
	for b: Dictionary in flight.birds:
		check(b.out == 0.0,"Ungrown flock is hidden")
	flight.ground = ground
	flight.growth = 1.0
	flight.startle(Vector3.ZERO)
	for b: Dictionary in flight.birds:
		check(b.mode == "pullup" and b.flap == 1.0, "Startle produces sustained climb-out")
	for i in range(1200):
		flight.advance(1.0/30.0,false,2.5,direction)
		for b: Dictionary in flight.birds:
			if b.out > 0.001:
				var floor_y: float = flight.height_at(b.x,b.z) + (1.5 if b.mode == "stoop" else 2.2)*0.8
				check(b.y >= floor_y-0.00001,"Native terrain backstop prevents ground penetration")
	geometry.queue_free()
	await process_frame
	print("PASS: source bird trajectories, modes, wing phase, pause and growth" if failures == 0 else "FAIL: bird flight")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
