extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var bolt = scene._lightning
	bolt.strike(Vector2(4,-2), Vector3(30,4,20))
	check(bolt.strike_count == 1 and bolt.flash == 1.0, "Strike begins with a full initial pulse")
	check(absf(bolt._light.light_energy * PI - 900.0) < 0.001, "Full flash carries source irradiance")
	check(not bolt._light.shadow_enabled and bolt._light.omni_range == 160.0 and is_equal_approx(bolt._light.omni_attenuation, 1.6), "Point light preserves source shadow, cutoff and decay settings")
	check(bolt._bolts.get_child_count() >= 4, "Core, halo and descending branches generated")
	check(bolt._pulses.size() >= 2 and bolt._pulses.size() <= 4, "Source return-stroke count")
	var time: float = bolt.clock
	bolt.advance(1, true, 1, 0.4, Vector2.RIGHT, Vector3.ZERO)
	check(bolt.clock == time and bolt.clap.w == 0, "Pause holds flash, thunder and downburst")
	bolt.advance(0.49, false, 0, 0.4, Vector2.RIGHT, Vector3.ZERO)
	check(bolt.clap.w == 0, "Downburst waits half a second")
	bolt.advance(0.51, false, 0, 0.4, Vector2.RIGHT, Vector3.ZERO)
	check(bolt.thunder_count == 0, "Sound has not arrived before its distance delay")
	check(absf(bolt.clap.z - 6.0) < 0.00001, "Front travels twelve units per second after delay")
	check(absf(bolt.clap.w - 0.9 * exp(-0.5 / 2.6)) < 0.00001, "Downburst source decay")
	bolt.advance(10, false, 0, 0.4, Vector2.RIGHT, Vector3.ZERO)
	check(bolt.thunder_count == 1 and bolt.flash < 0.001 and bolt.clap.w == 0, "Thunder fires once; flash and ring retire")
	bolt.next_strike = 0.01
	bolt.advance(0.1, false, 1, 0.4, Vector2.RIGHT, Vector3.ZERO)
	check(bolt.strike_count == 2, "Storm automatically schedules strikes")
	var count: int = bolt.strike_count
	bolt.advance(100, false, 0, 0.4, Vector2.RIGHT, Vector3.ZERO)
	check(bolt.strike_count == count, "Clear weather never schedules a strike")
	scene.queue_free()
	# The mixer lets go of the thunder's playbacks a moment later.
	await create_timer(0.5).timeout
	print("PASS: lightning pulses, pause, downburst, thunder and storm scheduling" if failures == 0 else "FAIL: lightning")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
