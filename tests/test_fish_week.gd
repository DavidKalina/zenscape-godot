extends SceneTree
## Slice 1's success criterion of the world-progression plan: over a simulated
## week the fish action keeps firing and the stash never sits empty for more than
## one world day. Drives the real mind, pond and cave through
## tests/fixtures/living_week.gd. Pure: safe to run headless.
const Week := preload("res://tests/fixtures/living_week.gd")
const DAYS := 7
## Seed 1 is the driest sampled week (no storm, under five hours of rain), seed 2
## the wettest (five storms); rain speeds the pond, so both ends are covered.
const SEEDS := [1, 2]
var failures := 0

func _initialize() -> void: run.call_deferred()

## Deferred so the harness nodes join a live tree.
func run() -> void:
	for weather_seed in SEEDS:
		var week := Week.new(root, weather_seed)
		week.run(DAYS)
		var fish: Array[float] = week.completed(["fish"])
		var days := {}
		for hour in fish: days[int(hour/24.0)] = true
		print("seed %d: %d fish, %d meals, longest empty stash %.1f world hours" % [weather_seed, fish.size(), week.completed(["eat"]).size(), week.longest_empty_food_hours])
		for day in range(DAYS):
			check(days.has(day), "seed %d: he brings a fish home on world day %d" % [weather_seed, day])
		check(week.longest_empty_food_hours <= 24.0, "seed %d: the stash is never empty for more than one world day (longest %.1f h)" % [weather_seed, week.longest_empty_food_hours])
		week.dispose()
	print("PASS: the fish loop holds for a week" if failures == 0 else "FAIL: fish week")
	print("Failures: ", failures)
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if ok:
		return
	failures += 1
	print("FAIL: ", message)
	push_error(message)
