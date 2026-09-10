extends SceneTree
## The calendar reaches the sky. Loads the real scene, so never headless:
##   Godot --path . --rendering-method forward_plus --script res://tests/test_season_scene.gd
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
	var surface: RefCounted = scene._precipitation.surface_weather
	check(clock != null and drift != null, "The scene owns a clock and a scheduler")

	# A neutral scene: day 0 is the opening of the calendar and adds nothing.
	clock.set_time(0, 0.0)
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"), true)
	step(scene, 4)
	check(is_zero_approx(drift.season), "Day 0 is season 0")
	check(is_zero_approx(surface.target_autumn) and is_zero_approx(surface.target_cold), "A clear day 0 carries no gold and no cold")

	# The slider's override reaches the scheduler and the ground.
	clock.season_override = 0.675
	step(scene, 4)
	check(is_equal_approx(drift.season, 0.675), "The scheduler reads the pinned season")
	check(absf(surface.target_autumn - WeatherScheduler.season_autumn(0.675)) < 0.001, "Mid autumn golds the ground: %.3f" % surface.target_autumn)
	check(is_zero_approx(surface.target_cold), "Mid autumn is not yet cold")

	clock.season_override = 0.875
	step(scene, 4)
	check(is_equal_approx(drift.season, 0.875), "The scheduler follows the season as it is scrubbed")
	check(absf(surface.target_cold - WeatherScheduler.season_cold(0.875)) < 0.001, "Deep winter chills the ground: %.3f" % surface.target_cold)
	check(surface.target_cold > 0.85 and is_zero_approx(surface.target_autumn), "Winter is cold and the gold has gone")
	var chilled: float = surface.cold
	step(scene, 60)
	check(surface.cold > chilled, "The ground eases toward the season's cold")

	# The season adds to a preset instead of replacing it.
	scene._precipitation.set_weather(WeatherScheduler.preset_index("snow"), true)
	step(scene, 4)
	check(is_equal_approx(surface.target_cold, 1.0) and is_equal_approx(surface.target_autumn, 1.0), "A snowy winter stays clamped at full cold")
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"), true)
	clock.season_override = 0.6
	step(scene, 4)
	check(absf(surface.target_autumn - WeatherScheduler.season_autumn(0.6)) < 0.001, "A fresh preset hands the ground back to the season")

	# Clearing the override hands the year back to the day count.
	clock.season_override = -1.0
	clock.set_time(WorldClock.YEAR_DAYS / 2, 0.0)
	step(scene, 4)
	check(is_equal_approx(drift.season, 0.5), "Without an override the day count sets the season")
	check(is_zero_approx(surface.target_autumn), "Midsummer is neutral again")

	# A hand-set autumn is not fought by the calendar.
	surface.target_autumn = 0.42
	clock.season_override = 0.675
	step(scene, 8)
	check(is_equal_approx(surface.target_autumn, 0.42), "A hand-set autumn holds against the season")
	scene._precipitation.set_weather(WeatherScheduler.preset_index("fair"), true)
	step(scene, 4)
	check(absf(surface.target_autumn - WeatherScheduler.season_autumn(0.675)) < 0.001, "Picking weather returns the ground to the season")

	# The look editor's scrub controls drive all of it.
	scene._ensure_scene_look_editor()
	var panel = scene._look_editor
	panel.sync()
	check(panel.sliders.has("season") and panel.sliders.has("day") and panel.checks.has("season_follows"), "The Air section grew season, day and calendar controls")
	panel.sliders.season.control.value_changed.emit(0.875)
	step(scene, 4)
	check(is_equal_approx(clock.season_override, 0.875) and is_equal_approx(drift.season, 0.875), "The Season slider pins the year")
	check(not panel.season_follows, "Scrubbing the season stops following the calendar")
	panel.checks.season_follows.control.toggled.emit(true)
	step(scene, 4)
	check(clock.season_override < 0.0 and is_equal_approx(drift.season, clock.calendar_season()), "Following the calendar releases the pin")
	panel.sliders.day.control.value_changed.emit(21.0)
	step(scene, 4)
	# The clock runs by default, so a few frames nudge the season past 0.75.
	check(clock.day == 21 and absf(drift.season - 0.75) < 0.001, "The Day slider walks the calendar into winter")
	var stormy := WeatherScheduler.preset_index("storm")
	panel.force_weather_choice.item_selected.emit(stormy)
	step(scene, 4)
	check(scene._precipitation.preset_index == stormy and drift.current == "storm", "The weather picker forces a sky and the scheduler follows")

	scene.free()
	print("PASS: the season reaches the scheduler and the ground" if failures == 0 else "FAIL: season wiring")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func step(scene: Node, frames: int) -> void:
	for i in range(frames): scene._process(1.0 / 30.0)

func check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	print("FAIL: ", message)
	push_error(message)
