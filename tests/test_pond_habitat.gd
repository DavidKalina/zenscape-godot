extends SceneTree
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = true
	var growth = scene._growth
	var surface = scene._precipitation.surface_weather
	check_habitat(scene, true, "Warm full pond")
	growth.set_water(0.0)
	check_habitat(scene, false, "Empty pond")
	growth.set_water(0.8)
	check_habitat(scene, false, "Filling pond")
	growth.set_water(1.0)
	check_habitat(scene, true, "Refilled pond")
	surface.cold = 1.0
	check_habitat(scene, false, "Cold pond")
	surface.cold = 0.0
	surface.ice = 0.9
	check_habitat(scene, false, "Warming pond remains frozen")
	surface.ice = 0.0
	check_habitat(scene, true, "Thawed pond")
	growth.set_terrain(0.5)
	check_habitat(scene, false, "Unfinished terrain")
	growth.set_terrain(1.0)
	check_habitat(scene, true, "Restored terrain")
	scene.queue_free()
	await process_frame
	print("PASS: pond wildlife follows filling, cold, thaw and paused terrain scrubbing" if failures == 0 else "FAIL: pond habitat")
	quit(1 if failures else 0)

func check_habitat(scene: Node, expected: bool, label: String) -> void:
	scene._process(0.05)
	for group in ["mesh-39", "mesh-40"]:
		if scene.get_node("Reference/" + group).visible != expected:
			failures += 1
			push_error(label + ": " + group)
