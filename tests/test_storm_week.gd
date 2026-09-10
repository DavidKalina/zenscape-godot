extends SceneTree
## Slice 2's success criterion (docs/world-progression/PLAN.md): gather fires
## again after every storm in a simulated week, and he is inside for most storm
## hours. "Gather" is the mind's choice, so a bed tended from stored material
## counts as well as a branch carried home. He starts with a full bed. Drives the
## real mind, cave and bed wear through tests/fixtures/living_week.gd. Pure: safe
## to run headless.
const Week := preload("res://tests/fixtures/living_week.gd")
const DAYS := 7
## One extra day so a storm late in the week has time to be answered.
const GRACE_DAYS := 1
## The stormiest sampled weeks: seed 2 has five storms, seed 7 two.
const SEEDS := [2, 7]
var failures := 0

func _initialize() -> void: run.call_deferred()

## Deferred so the harness nodes join a live tree.
func run() -> void:
	for weather_seed in SEEDS:
		var week := Week.new(root, weather_seed, 3)
		week.run(DAYS + GRACE_DAYS)
		var fixes: Array[float] = week.completed(["gather", "tend"])
		var judged := 0
		for storm: Dictionary in week.storms:
			if float(storm.from) >= DAYS * 24.0: continue
			judged += 1
			var fixed := false
			for hour in fixes:
				if hour > float(storm.to): fixed = true
			print("seed %d: storm %.1f-%.1f h, bed %d -> %d, gathered after: %s" % [weather_seed, storm.from, storm.to, storm.bed_before, storm.bed_after, fixed])
			check(fixed, "seed %d: gather fires again after the storm ending at world hour %.1f" % [weather_seed, storm.to])
		check(judged >= 2, "seed %d: the week holds at least two storms to judge (%d)" % [weather_seed, judged])
		var share: float = week.sheltered_storm_hours / week.storm_hours if week.storm_hours > 0.0 else 0.0
		print("seed %d: inside for %.1f of %.1f storm hours; outside: %s" % [weather_seed, week.sheltered_storm_hours, week.storm_hours, week.exposed_storm_hours])
		check(share > 0.5, "seed %d: he is inside for most storm hours (%.0f%%)" % [weather_seed, share * 100.0])
		week.dispose()
	print("PASS: the weather reaches him all week" if failures == 0 else "FAIL: storm week")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	print("FAIL: ", message)
	push_error(message)
