extends SceneTree
## The scene's weather follows the player's pick, then drifts on the world
## clock once enabled, and the garden file carries the drift's future.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 800)
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var clock: WorldClock = scene.get("world_clock")
	var drift: WeatherScheduler = scene.get("weather_scheduler")
	check(drift != null, "The scene exposes weather_scheduler")
	check(not drift.enabled, "Weather drift is off by default")

	# With drift off the sky stays where the player put it, however long the day runs.
	scene._celestial.cycling = true
	clock.set_time(0, 8.0)
	clock.speed = 12.0
	scene._precipitation.set_weather(WeatherScheduler.preset_index("overcast"), true)
	for i in range(600): scene._process(1.0 / 30.0)
	check(scene._precipitation.preset_index == WeatherScheduler.preset_index("overcast"), "Disabled drift never changes the weather")
	check(drift.current == "overcast", "The scheduler follows the player's pick")

	# Enabled, a seeded scheduler moves the sky, and precipitation follows.
	drift.restore(WeatherScheduler.new(4707, "overcast", clock.day * 24.0 + clock.hour).capture())
	drift.enabled = true
	var changed := false
	var consistent := true
	for i in range(6000):
		scene._process(1.0 / 30.0)
		var shown: String = scene._precipitation.PRESET_NAMES[scene._precipitation.preset_index]
		if shown != drift.current: consistent = false
		if shown != "overcast": changed = true
		if changed: break
	check(changed, "Enabled drift changes the weather within a few world days")
	check(consistent, "Precipitation always shows the scheduler's current preset")
	check(not drift.history.is_empty(), "Drift transitions are recorded in the history")

	# Pausing freezes the sky along with the clock.
	var before := drift.current
	scene._paused = true
	for i in range(3000): scene._process(1.0 / 30.0)
	check(drift.current == before, "A paused scene does not drift")
	scene._paused = false

	# A manual pick while drifting re-anchors the scheduler instead of fighting it.
	scene._precipitation.set_weather(WeatherScheduler.preset_index("storm"), true)
	scene._process(1.0 / 30.0)
	check(drift.current == "storm", "A manual pick becomes the scheduler's current weather")

	# The garden file carries the drift state and its seeded future.
	var saved: Dictionary = NativeGardenStore.capture(scene)
	check(saved.has("weather_scheduler"), "The store saves the weather scheduler")
	var expected := WeatherScheduler.new()
	expected.restore(saved.weather_scheduler)
	drift.enabled = false
	drift.set_current("clear", 0.0)
	NativeGardenStore.restore(scene, saved)
	check(drift.enabled and drift.current == "storm", "The store restores drift state")
	var replay_a := expected.advance(saved.weather_scheduler.next_change_hour + 200.0)
	var replay_b := drift.advance(saved.weather_scheduler.next_change_hour + 200.0)
	check(replay_a == replay_b and not replay_a.is_empty(), "A restored garden replays the same future weather")

	# Gardens saved before the scheduler existed still open.
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("weather_scheduler")
	check(NativeGardenStore.valid(scene, legacy), "A garden saved before weather drift validates")
	check(not NativeGardenStore.valid(scene, {"weather_scheduler": 3}), "A malformed scheduler entry is rejected")

	scene.queue_free()
	await process_frame
	print("PASS: weather drift follows the clock and the garden file" if failures == 0 else "FAIL: weather drift")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	print("FAIL: ", message)
	push_error(message)
