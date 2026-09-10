extends SceneTree
## Pure clock arithmetic: no scene, no rendering, no wall clock.
var failures := 0

func _initialize() -> void:
	var clock := WorldClock.new()
	check(clock.day == 0 and is_equal_approx(clock.phase, 0.35), "A new clock starts on day 0 at the default phase")
	check(is_equal_approx(clock.elapsed, clock.hour * 3600.0), "Elapsed world seconds follow day and hour")
	check(is_equal_approx(clock.daylight, WorldClock.daylight_for_phase(clock.phase)), "Daylight mirrors the celestial curve")

	# ------------------------------------------------------------ phase mapping
	for pair in [[0.0, 0.0], [6.0, 0.25], [12.0, 0.5], [18.0, 0.75]]:
		check(absf(WorldClock.phase_for_hour(pair[0]) - pair[1]) < 0.0005, "Quarter day %d:00 is phase %s" % [int(pair[0]), str(pair[1])])
		check(absf(WorldClock.hour_for_phase(pair[1]) - pair[0]) < 0.005, "Phase %s is hour %d:00" % [str(pair[1]), int(pair[0])])
	var round_trip := true
	var monotonic := true
	var previous := -1.0
	for i in range(240):
		var hour := float(i) * 0.1
		var mapped := WorldClock.phase_for_hour(hour)
		if mapped < previous: monotonic = false
		previous = mapped
		if absf(WorldClock.hour_for_phase(mapped) - hour) > 0.01: round_trip = false
	check(monotonic, "Phase rises with the hour")
	check(round_trip, "Hour and phase map back onto each other")
	var horizon := WorldClock.phase_for_hour(6.1) - WorldClock.phase_for_hour(6.0)
	var noon := WorldClock.phase_for_hour(12.1) - WorldClock.phase_for_hour(12.0)
	check(horizon < noon * 0.75, "The sun lingers at the horizon while the hour keeps its pace")

	# --------------------------------------------------------- rollover / speed
	clock = WorldClock.new()
	clock.day_length = 24.0  # one real second per world hour, easy arithmetic
	clock.running = true
	clock.set_time(0, 23.0)
	clock.advance(0.5, false)
	check(clock.day == 0 and is_equal_approx(clock.hour, 23.5), "Hours accumulate at the day length")
	clock.advance(1.0, false)
	check(clock.day == 1 and absf(clock.hour - 0.5) < 1e-9, "Midnight rolls the day over")
	check(absf(clock.elapsed - (WorldClock.SECONDS_PER_DAY + 1800.0)) < 1e-6, "Elapsed keeps counting past midnight")
	var before := clock.hour
	clock.advance(1.0, true)
	check(clock.day == 1 and clock.hour == before, "Paused time does not move")
	clock.running = false
	clock.advance(1.0, false)
	check(clock.hour == before, "A stopped clock does not move")
	clock.running = true
	clock.speed = 0.0
	clock.advance(1.0, false)
	check(clock.hour == before, "Speed zero freezes the hands")
	clock.speed = 4.0
	clock.advance(1.0, false)
	check(absf(clock.hour - (before + 4.0)) < 1e-9, "Speed multiplies the hours")
	clock.speed = 1.0
	before = clock.hour
	clock.advance(1000.0, false)
	check(absf(clock.hour - (before + WorldClock.MAX_DELTA)) < 1e-9, "An absurd delta is clamped, never a skipped day")
	clock.advance(NAN, false)
	clock.advance(-3.0, false)
	check(is_finite(clock.hour) and absf(clock.hour - (before + WorldClock.MAX_DELTA)) < 1e-9, "Broken deltas are ignored")

	# --------------------------------------------------------------- skip_to
	clock = WorldClock.new()
	clock.day_length = 480.0
	clock.set_time(3, 22.0)
	clock.skip_to(6.0)
	for i in range(400): clock.advance(1.0 / 60.0, false)
	check(clock.target_hour < 0.0 and absf(clock.hour - 6.0) < 1e-6, "skip_to eases onto its hour and lets go")
	check(clock.day == 4, "Skipping past midnight advances the day")
	check(not clock.running, "skip_to does not start the clock")
	clock.set_time(2, 9.0)
	clock.skip_to(15.0)
	clock.advance(0.25, true)
	check(is_equal_approx(clock.hour, 9.0), "A paused skip waits")
	clock.advance(0.25, false)
	check(clock.hour > 9.0 and clock.hour < 15.0, "A skip crosses the gap gradually")

	# ------------------------------------------------------------ determinism
	var deltas: Array[float] = []
	for i in range(600): deltas.append(0.004 + float(i % 17) * 0.003)
	var first := WorldClock.new()
	first.set_time(2, 5.25)
	first.running = true
	first.speed = 3.0
	first.day_length = 320.0
	var seed_state := first.capture()
	for d in deltas: first.advance(d, false)
	first.skip_to(18.0)
	for d in deltas: first.advance(d, false)
	var second := WorldClock.new()
	second.restore(seed_state)
	for d in deltas: second.advance(d, false)
	second.skip_to(18.0)
	for d in deltas: second.advance(d, false)
	check(first.day == second.day and first.hour == second.hour and first.phase == second.phase and first.elapsed == second.elapsed,
		"The same state and the same deltas give the identical hour: %s vs %s" % [str(first.hour), str(second.hour)])
	var third := WorldClock.new()
	third.restore(seed_state)
	for d in deltas:
		third.advance(d, true)
		third.advance(d, false)
	third.skip_to(18.0)
	for d in deltas:
		third.advance(d, true)
		third.advance(d, false)
	check(third.hour == first.hour and third.day == first.day, "Paused frames in between change nothing")

	# ------------------------------------------------------- capture / restore
	var saved := first.capture()
	var copy := WorldClock.new()
	copy.restore(JSON.parse_string(JSON.stringify(saved)))
	check(WorldClock.valid_state(saved) and WorldClock.valid_state(JSON.parse_string(JSON.stringify(saved))), "A captured clock validates")
	check(copy.day == first.day and absf(copy.hour - first.hour) < 1e-9 and copy.speed == first.speed
		and copy.day_length == first.day_length and copy.running == first.running,
		"Capture and restore round-trip through JSON")
	check(absf(copy.phase - first.phase) < 1e-9 and absf(copy.daylight - first.daylight) < 1e-9, "Restore rebuilds phase and daylight")
	var empty := WorldClock.new()
	empty.restore({})
	check(empty.day == 0 and empty.speed == 1.0 and is_equal_approx(empty.day_length, WorldClock.DEFAULT_DAY_LENGTH) and not empty.running,
		"An empty document restores a fresh clock")
	for broken in [null, [], {"day": "soon"}, {"day": 0, "hour": 99.0}, {"day": 0, "hour": 1.0, "speed": 1.0, "day_length": 480.0, "target": -1.0, "running": 1}]:
		check(not WorldClock.valid_state(broken), "Rejected clock document: " + str(broken))
	check(WorldClock.valid_state({"day": 4, "hour": 6.5, "speed": 1.0, "day_length": 480.0, "target": -1.0, "running": true}), "A hand-written clock document validates")

	# --------------------------------------------------------------- set_phase
	var authored := WorldClock.new()
	authored.set_time(5, 0.0)
	authored.set_phase(0.62)
	check(authored.day == 5 and absf(authored.phase - 0.62) < 0.001, "set_phase keeps the day and lands on the authored hour")

	print("PASS: world clock rollover, speed, pause, skip, determinism and persistence" if failures == 0 else "FAIL: world clock")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	print("FAIL: ", message)
	push_error(message)
