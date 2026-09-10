extends SceneTree
## Prints a 7-day weather timeline so a human can eyeball the drift.
##   Godot --path . --headless --script res://tools/simulate_weather.gd -- 4242 0.0 7

const Scheduler := preload("res://scripts/weather_scheduler.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if args.size() > 0 else 4242
	var season := float(args[1]) if args.size() > 1 else 0.0
	var days := int(args[2]) if args.size() > 2 else 7
	var scheduler := Scheduler.new(seed)
	scheduler.enabled = true  # Drift is off by default; this tool exists to watch it.
	scheduler.season = season
	print("seed=%d season=%.2f days=%d" % [seed, season, days])
	print("day 1  00:00  %s (start, next change at %.2f h)" % [scheduler.current, scheduler.next_change_hour])
	var tally := {}
	tally[scheduler.current] = 0.0
	var previous_hour := 0.0
	var previous := scheduler.current
	for step in range(days * 24 * 4):
		var hour := float(step) * 0.25
		for name in scheduler.advance(hour):
			var at: float = float(scheduler.history[scheduler.history.size() - 1]["hour"])
			tally[previous] = float(tally.get(previous, 0.0)) + (at - previous_hour)
			previous = name
			previous_hour = at
			print("day %d  %02d:%02d  %-8s (index %d)" % [
				int(at / 24.0) + 1,
				int(fposmod(at, 24.0)),
				int(fposmod(at, 1.0) * 60.0),
				name,
				Scheduler.preset_index(name),
			])
	tally[previous] = float(tally.get(previous, 0.0)) + (float(days * 24) - previous_hour)
	print("--- hours per preset ---")
	for name in Scheduler.PRESET_NAMES:
		if tally.has(name):
			print("  %-8s %5.1f h" % [name, float(tally[name])])
	quit(0)
