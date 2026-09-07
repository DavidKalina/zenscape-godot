extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var flies = scene._fireflies
	check(flies.multimesh.instance_count == 90, "Imported firefly habitat is populated")
	flies.update_conditions(1.0, 0.0, 0.0, 1.0)
	check(not flies.visible, "Daylight hides fireflies")
	flies.update_conditions(0.0, 0.0, 0.0, 1.0)
	var clear_activity: float = flies.activity
	check(flies.visible, "Warm nights bring out fireflies")
	flies.update_conditions(0.0, 1.0, 0.0, 1.0)
	check(flies.activity > 0.0 and flies.activity < clear_activity, "Rain reduces activity")
	flies.called = true
	flies.update_conditions(1.0, 0.0, 0.0, 1.0)
	check(flies.visible, "Invitation works in daylight")
	flies.update_conditions(0.0, 0.0, 1.0, 1.0)
	check(not flies.visible, "Cold suppresses even invited fireflies")
	scene._paused = true
	var stopped_time: float = scene._motion_time
	scene._growth.set_terrain(0.5)
	scene._process(0.05)
	check(not flies.visible, "Paused terrain scrub hides fireflies")
	scene._growth.set_terrain(1.0)
	scene._growth.set_foliage(0.0)
	scene._process(0.05)
	check(not flies.visible, "Unformed foliage hides fireflies")
	scene._growth.set_foliage(1.0)
	scene._process(0.05)
	check(flies.visible, "Restored habitat brings fireflies back while paused")
	check(scene._motion_time == stopped_time, "Pause freezes the shared shader animation clock")
	scene.queue_free()
	await process_frame
	print("PASS: firefly habitat, weather, invitation and paused growth" if failures == 0 else "FAIL: fireflies")
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
