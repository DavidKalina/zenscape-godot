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

	# The four quarters, each with its own ground and its own sky.
	clock.season_override = -1.0
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"), true)
	for quarter: Array in [["spring", 0.125], ["summer", 0.375], ["autumn", 0.625], ["winter", 0.875]]:
		var name := str(quarter[0])
		var at := float(quarter[1])
		clock.season_override = at
		scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"), true)
		step(scene, 4)
		var gold: float = surface.target_autumn
		var chill: float = surface.target_cold
		match name:
			"spring", "summer":
				check(is_zero_approx(gold) and is_zero_approx(chill), "Mid %s leaves the ground neutral" % name)
			"autumn":
				check(gold > 0.5 and is_zero_approx(chill), "Mid autumn golds the ground and does not chill it: %.2f" % gold)
			"winter":
				check(chill > 0.5, "Deep winter chills the ground: %.2f" % chill)
	check(clock.season_name() == "winter", "The clock names the quarter it is standing in")
	_weather_mix()

	scene.free()
	print("PASS: the season reaches the scheduler and the ground" if failures == 0 else "FAIL: season wiring")
	print("Failures: ", failures)
	quit(1 if failures else 0)

## Four simulated years of drift, one per quarter, pinned so the mix is the
## season's alone. Each quarter has to look like itself.
func _weather_mix() -> void:
	var hours := {}
	for quarter: Array in [["spring", 0.125], ["summer", 0.375], ["autumn", 0.625], ["winter", 0.875]]:
		hours[str(quarter[0])] = _hours_by_preset(float(quarter[1]))
	for name in hours:
		print("  %s: %s" % [name, hours[name]])
	var spring: Dictionary = hours.spring
	var summer: Dictionary = hours.summer
	var autumn: Dictionary = hours.autumn
	var winter: Dictionary = hours.winter
	check(not spring.has("snow") and not spring.has("autumn") and not summer.has("snow") and not summer.has("autumn"),
		"Neither spring nor summer rolls snow or the autumn sky")
	check(float(spring.get("rain", 0.0)) > float(summer.get("rain", 0.0)), "Spring is showerier than summer")
	check(float(spring.get("mist", 0.0)) > float(summer.get("mist", 0.0)), "Spring holds more mist than summer")
	# Storms only follow rain, and summer is dry, so the honest measure is how
	# often the rain it does get turns to thunder.
	var thunder := func(mix: Dictionary) -> float: return float(mix.get("storm", 0.0)) / maxf(1.0, float(mix.get("rain", 0.0)))
	check(thunder.call(summer) > thunder.call(spring) * 1.5, "Summer rain turns to thunder far more readily than spring rain")
	check(thunder.call(winter) < thunder.call(spring), "Winter rain hardly ever thunders")
	var bright := func(mix: Dictionary) -> float: return float(mix.get("clear", 0.0)) + float(mix.get("fair", 0.0))
	check(bright.call(summer) > bright.call(spring), "Summer is the brightest quarter")
	check(bright.call(autumn) < bright.call(summer) and bright.call(winter) < bright.call(autumn), "The bright skies fade as the year turns")
	check(float(autumn.get("autumn", 0.0)) > 0.0, "Autumn reaches the autumn sky")
	check(float(autumn.get("rain", 0.0)) > float(summer.get("rain", 0.0)), "Autumn is wetter than summer")
	check(float(winter.get("snow", 0.0)) > 0.0, "Winter snows")
	check(float(winter.get("overcast", 0.0)) > float(spring.get("overcast", 0.0)), "Winter is the greyest quarter")
	check(float(winter.get("storm", 0.0)) < float(summer.get("storm", 0.0)), "Winter storms far less than summer")
	check(float(winter.get("rain", 0.0)) < float(autumn.get("rain", 0.0)), "Winter rains less than autumn; it snows instead")

## World hours spent in each preset over 4 seeds x 60 days at a pinned season.
func _hours_by_preset(season: float) -> Dictionary:
	var totals := {}
	for drift_seed in [1, 7, 42, 404]:
		var drift := WeatherScheduler.new(drift_seed, "fair", 0.0)
		drift.enabled = true
		drift.season = season
		var hour := 0.0
		while hour < 60.0 * 24.0:
			hour += 1.0
			drift.advance(hour)
			totals[drift.current] = float(totals.get(drift.current, 0.0)) + 1.0
	return totals

func step(scene: Node, frames: int) -> void:
	for i in range(frames): scene._process(1.0 / 30.0)

func check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	print("FAIL: ", message)
	push_error(message)
