extends SceneTree
## Living weather pacing and odds, headless. Steps WeatherScheduler in climate
## mode through simulated real time exactly as scripts/living_weather.gd feeds
## it, and prints a sample timeline, the time share per sky against the
## generator's odds, and dwell times in real minutes.
##   Godot --headless --path . --script res://tools/probe_living_weather.gd -- [hours] [seeds] [worlds]
## `worlds` > 0 also draws that many generated worlds and tallies the season
## each one opens in.
const Living = preload("res://scripts/living_weather.gd")
const Generator = preload("res://scripts/cozy_world_generator.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var hours := float(args[0]) if args.size() > 0 else 20000.0
	var seeds := int(args[1]) if args.size() > 1 else 8
	var worlds := int(args[2]) if args.size() > 2 else 0
	_timeline(false, 0, 4242, "clear")
	for dry in [false, true]:
		for quarter in ([0, 1, 2, 3] if not dry else [1]):
			_shares(dry, quarter, hours, seeds)
	_plants()
	if worlds > 0: _seasons(worlds)
	quit()

func _scheduler(dry: bool, quarter: int, seed: int, start: String) -> WeatherScheduler:
	var scheduler := WeatherScheduler.new(seed, start, 0.0)
	scheduler.enabled = true
	scheduler.set_climate(Living.climate_for(dry, quarter), Living.DWELL)
	scheduler.set_current(start, 0.0)
	return scheduler

## One hour of simulated real time, stepped at 60 fps like the scene.
func _timeline(dry: bool, quarter: int, seed: int, start: String) -> void:
	var scheduler := _scheduler(dry, quarter, seed, start)
	print("Sample timeline, %s world, %s, seed %d (real time mm:ss):" % ["dry" if dry else "wet", WorldClock.SEASON_NAMES[quarter], seed])
	var line := "  00:00 %s" % start
	var seconds := 0.0
	var step := 1.0 / 60.0
	while seconds < 3600.0:
		seconds += step
		for name in scheduler.advance(scheduler.now_hour() + step / Living.HOUR_SECONDS):
			line += "  %02d:%02d %s" % [int(seconds) / 60, int(seconds) % 60, name]
	print(line)

func _shares(dry: bool, quarter: int, hours: float, seeds: int) -> void:
	var odds := Living.climate_for(dry, quarter)
	var total_odds := 0.0
	for key in odds: total_odds += float(odds[key])
	var time := {}
	var visits := {}
	var changes := 0
	for seed in range(seeds):
		var scheduler := _scheduler(dry, quarter, 1000 + seed, "clear" if dry else "fair")
		var now := 0.0
		var current := scheduler.current
		var since := 0.0
		# Step one scheduler hour at a time; dwell ends land mid-step exactly
		# through the history the scheduler keeps.
		while now < hours:
			now += 1.0
			var before := scheduler.history.size()
			var fired := scheduler.advance(now)
			for i in range(fired.size()):
				var at: float = float(scheduler.history[scheduler.history.size() - fired.size() + i].hour)
				time[current] = float(time.get(current, 0.0)) + (at - since)
				visits[current] = int(visits.get(current, 0)) + 1
				current = fired[i]
				since = at
				changes += 1
		time[current] = float(time.get(current, 0.0)) + (now - since)
	var all := 0.0
	for key in time: all += float(time[key])
	var grey := 0.0
	print("\n%s world, %s: share of time (target) and mean dwell in real minutes" % ["Dry" if dry else "Wet", WorldClock.SEASON_NAMES[quarter]])
	for key in odds:
		var share := float(time.get(key, 0.0)) / all
		if key in ["overcast", "rain", "snow"]: grey += share
		var dwell_minutes := float(time.get(key, 0.0)) / maxf(1.0, float(visits.get(key, 0))) * Living.HOUR_SECONDS / 60.0
		print("  %-9s %5.1f%%  (%4.1f%%)  %4.1f min" % [key, share * 100.0, float(odds[key]) / total_odds * 100.0, dwell_minutes])
	print("  overcast + rain + snow: %.1f%%   a change every %.1f real minutes on average" % [grey * 100.0, all / maxf(1.0, changes) * Living.HOUR_SECONDS / 60.0])

func _plants() -> void:
	print("\nPlants per season (bloom, leaf fall, dormancy) and ground (gold, cold):")
	for i in range(4):
		var season: float = Living.SEASONS[i]
		var plants := WeatherScheduler.season_plants(season)
		print("  %-6s %.3f  bloom %.2f  bare %.2f  dormant %.2f  gold %.2f  cold %.2f" % [WorldClock.SEASON_NAMES[i], season, plants.x, plants.y, plants.z, WeatherScheduler.season_autumn(season), WeatherScheduler.season_cold(season)])
	for amount in [0.4, 0.6, 0.8]:
		var season := Living.autumn_season(amount)
		print("  autumn world with gold %.2f opens at %.4f, which gives gold %.4f" % [amount, season, WeatherScheduler.season_autumn(season)])

func _seasons(count: int) -> void:
	var tally := {}
	var weather := {}
	for seed in range(count):
		var world: Dictionary = Generator.sample(seed)
		var name := WorldClock.name_for_season(Living.season_for(world))
		tally[name] = int(tally.get(name, 0)) + 1
		weather[world.mood.weather] = int(weather.get(world.mood.weather, 0)) + 1
	print("\nOpening season over seeds 0-%d: %s" % [count - 1, tally])
	print("Generated weather over the same seeds: %s" % weather)
