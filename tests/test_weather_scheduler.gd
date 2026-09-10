extends SceneTree
## Pure tests for scripts/weather_scheduler.gd. No scenes, headless safe:
##   Godot --path . --headless --script res://tests/test_weather_scheduler.gd

const Scheduler := preload("res://scripts/weather_scheduler.gd")

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1

## A scheduler that is allowed to drift. Drift is off by default (a garden's sky
## stays where it was put), so every test about transitions asks for it.
func drifting(seed: int) -> Scheduler:
	var scheduler := Scheduler.new(seed)
	scheduler.enabled = true
	return scheduler

## Steps a scheduler forward in quarter-hour beats and returns every preset it chose.
func simulate(scheduler: Scheduler, days: int, start := 0.0) -> Array[String]:
	var seen: Array[String] = []
	var steps := days * 24 * 4
	for i in range(steps):
		for name in scheduler.advance(start + float(i) * 0.25):
			seen.append(name)
	return seen

func run() -> void:
	test_matches_precipitation_constant()
	test_off_by_default()
	test_determinism()
	test_idempotent()
	test_capture_restore()
	test_disabled()
	test_enable_after_idle()
	test_snow_floor()
	test_neutral_season()
	test_cold_season()
	test_dwell_bounds()
	test_catch_up_cap()
	test_season_curves()
	print("Failures: ", failures)
	quit(1 if failures else 0)

func test_matches_precipitation_constant() -> void:
	var script: GDScript = load("res://studies/precipitation.gd")
	var names: Variant = script.get_script_constant_map().get("PRESET_NAMES")
	check(names == Scheduler.PRESET_NAMES, "Scheduler preset list matches precipitation PRESET_NAMES")
	var ok := true
	for i in range(Scheduler.PRESET_NAMES.size()):
		if Scheduler.preset_index(Scheduler.PRESET_NAMES[i]) != i:
			ok = false
	check(ok and Scheduler.preset_index("nonsense") == -1, "preset_index resolves every preset and rejects unknown names")

func test_off_by_default() -> void:
	var s := Scheduler.new(11)
	check(not s.enabled, "A fresh scheduler is not drifting yet")
	check(simulate(s, 10).is_empty(), "and a fresh scheduler changes nothing on its own")

func test_determinism() -> void:
	var a := drifting(4242)
	var b := drifting(4242)
	var seen_a := simulate(a, 14)
	var seen_b := simulate(b, 14)
	check(seen_a.size() > 10, "A fortnight of weather produces a stream of transitions (%d)" % seen_a.size())
	check(seen_a == seen_b, "Two schedulers with the same seed fire identical transitions")
	check(a.current == b.current and is_equal_approx(a.next_change_hour, b.next_change_hour), "Same-seed schedulers end in the same state")
	var c := drifting(99)
	check(simulate(c, 14) != seen_a, "A different seed produces a different fortnight")

func test_idempotent() -> void:
	var s := drifting(7)
	var repeats_clean := true
	for i in range(24 * 40):
		var hour := float(i) * 0.5
		s.advance(hour)
		if not s.advance(hour).is_empty():
			repeats_clean = false
		if not s.advance(hour - 3.0).is_empty():
			repeats_clean = false
	check(repeats_clean, "advance() is idempotent at a repeated hour and ignores backwards time")

func test_capture_restore() -> void:
	var a := drifting(1234)
	simulate(a, 5)
	var saved := a.capture()
	var rest_a := simulate(a, 9, 120.0)
	var b := Scheduler.new(0)
	b.restore(saved)
	check(b.current == saved.current and is_equal_approx(b.next_change_hour, float(saved.next_change_hour)), "restore() reinstates the current preset and schedule")
	check(b.history.size() == int((saved["history"] as Array).size()), "restore() reinstates history")
	var rest_b := simulate(b, 9, 120.0)
	check(rest_a == rest_b, "A restored scheduler resumes the same future")
	var round_trip: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var c := Scheduler.new(0)
	c.restore(round_trip)
	check(simulate(c, 9, 120.0) == rest_a, "Capture survives a JSON round trip")

func test_disabled() -> void:
	var s := Scheduler.new(5)
	s.enabled = false
	s.set_current("rain", 0.0)
	var seen := simulate(s, 30)
	check(seen.is_empty() and s.current == "rain" and s.history.size() == 1, "A disabled scheduler never changes the weather")

func test_enable_after_idle() -> void:
	var s := Scheduler.new(7)
	s.enabled = false
	simulate(s, 5)
	check(s.next_change_hour >= 120.0 - 0.25, "A disabled scheduler keeps its schedule ahead of the clock")
	s.enabled = true
	check(s.advance(120.0).is_empty(), "Enabling drift after five idle days fires nothing at once")
	var later := simulate(s, 2, 120.0)
	check(not later.is_empty() and later.size() < 12, "Enabled drift then resumes at a normal pace (%d in two days)" % later.size())

func test_snow_floor() -> void:
	var s := Scheduler.new(3)
	s.season = 0.5
	check(is_zero_approx(s._season_factor("snow", "overcast")), "Below the cold season snow has no weight")
	s.set_current("snow", 0.0)
	s.set_current("overcast", 4.0)
	check(is_equal_approx(s._season_factor("snow", "overcast"), 1.5), "Straight off snow the cold floor makes snow reachable")
	s.set_current("fair", 8.0)
	check(is_zero_approx(s._season_factor("snow", "fair")), "One preset later the floor has lifted")

func test_neutral_season() -> void:
	var found_autumn := false
	var found_snow := false
	var kinds := {}
	for seed in [1, 2, 3, 11]:
		var s := drifting(seed)
		for name in simulate(s, 30):
			kinds[name] = true
			if name == "autumn":
				found_autumn = true
			if name == "snow":
				found_snow = true
	check(not found_autumn and not found_snow, "Season 0 never rolls autumn or snow across 120 simulated days")
	check(kinds.has("rain") and kinds.has("storm") and kinds.has("mist") and kinds.has("overcast"), "Season 0 still reaches rain, storm, mist and overcast")

func test_cold_season() -> void:
	var kinds := {}
	for seed in [1, 2, 3, 11]:
		var s := drifting(seed)
		s.season = 1.0
		for name in simulate(s, 30):
			kinds[name] = true
	check(kinds.has("autumn"), "Season 1.0 reaches autumn")
	check(kinds.has("overcast"), "Season 1.0 reaches overcast")
	check(kinds.has("snow"), "Season 1.0 reaches snow")

func test_dwell_bounds() -> void:
	var ok := true
	var report := ""
	for seed in [3, 21, 404]:
		var s := drifting(seed)
		s.season = 0.8
		simulate(s, 20)
		for i in range(s.history.size() - 1):
			var name: String = str(s.history[i]["to"])
			var span: Array = Scheduler.DWELL[name]
			var held: float = float(s.history[i + 1]["hour"]) - float(s.history[i]["hour"])
			if held < float(span[0]) - 0.001 or held > float(span[1]) + 0.001:
				ok = false
				report = "%s held %.2f h, bounds %s" % [name, held, str(span)]
	check(ok, "Every preset dwells within its documented bounds %s" % report)
	check(float(Scheduler.DWELL["storm"][1]) <= 3.0 and float(Scheduler.DWELL["fair"][1]) >= 18.0, "Storms are short and fair spells are long")

func test_catch_up_cap() -> void:
	var s := drifting(64)
	var jumped := s.advance(10000.0)
	check(jumped.size() <= Scheduler.MAX_CATCH_UP, "A huge fast-forward fires at most %d transitions (%d)" % [Scheduler.MAX_CATCH_UP, jumped.size()])
	check(jumped.size() == Scheduler.MAX_CATCH_UP, "A huge fast-forward does catch up to the cap")
	check(s.next_change_hour > 10000.0, "After the cap the schedule is re-anchored ahead of the requested hour")
	check(s.advance(10000.0).is_empty(), "A repeated fast-forward hour fires nothing more")
	var small := drifting(64)
	var creep: Array[String] = []
	for i in range(400):
		for name in small.advance(float(i) * 0.25):
			creep.append(name)
	var leap := drifting(64)
	check(leap.advance(99.75).size() == creep.size(), "A single leap fires the same count as the same span walked step by step")

## The season lift the ground wears: gold through autumn, cold through winter.
func test_season_curves() -> void:
	check(is_zero_approx(Scheduler.season_autumn(0.0)) and is_zero_approx(Scheduler.season_cold(0.0)),
		"A fresh calendar (season 0) adds no gold and no cold")
	check(is_zero_approx(Scheduler.season_autumn(0.3)) and is_zero_approx(Scheduler.season_cold(0.3)),
		"Spring and summer stay neutral")
	check(Scheduler.season_autumn(0.675) > 0.85 and Scheduler.season_autumn(0.675) <= 1.0, "Gold peaks in mid autumn")
	check(Scheduler.season_autumn(0.6) > 0.4 and Scheduler.season_autumn(0.75) > 0.4, "Gold covers the whole autumn quarter")
	check(Scheduler.season_cold(0.875) > 0.85 and Scheduler.season_cold(0.875) <= 1.0, "Cold peaks in deep winter")
	check(Scheduler.season_cold(0.8) > 0.3 and Scheduler.season_cold(0.95) > 0.3, "Cold covers the winter quarter")
	check(is_zero_approx(Scheduler.season_cold(0.6)) and is_zero_approx(Scheduler.season_autumn(0.9)),
		"Neither bump spills into the far side of the year")
	var smooth := true
	var previous_autumn := Scheduler.season_autumn(-0.02)
	var previous_cold := Scheduler.season_cold(-0.02)
	for i in range(1, 201):
		var season := -0.02 + float(i) * 0.0002
		var gold := Scheduler.season_autumn(season)
		var chill := Scheduler.season_cold(season)
		if absf(gold - previous_autumn) > 0.02 or absf(chill - previous_cold) > 0.02: smooth = false
		previous_autumn = gold
		previous_cold = chill
	check(smooth, "The year wraps without a step in either curve")
