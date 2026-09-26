extends SceneTree
## Living weather in the real product scene, headless. Opens studies/diorama,
## applies a generated world's mood, steps the scene through simulated
## minutes and prints what the sky and the season are doing, then checks the
## save round trip and that a save from before living weather still loads.
##   Godot --headless --path . --script res://tools/probe_living_scene.gd -- [seed] [minutes]
const Generator = preload("res://scripts/cozy_world_generator.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := int(args[0]) if args.size() > 0 else 177
	var minutes := float(args[1]) if args.size() > 1 else 20.0
	root.size = Vector2i(1280, 800)
	var scene: Node3D = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.set_process(false)
	var world: Dictionary = Generator.sample(seed)
	Generator.apply_mood(scene, world)
	var living: RefCounted = scene.living_weather
	print("Seed %d: generated %s, season %s (%.3f), drift %s" % [seed, world.mood.weather, scene.world_clock.season_name(), scene.world_clock.season, scene.weather_scheduler.enabled])
	var step := 0.5
	var seconds := 0.0
	var last: String = scene.weather_scheduler.current
	var sample := 0.0
	while seconds < minutes * 60.0:
		scene._process(step)
		seconds += step
		var now: String = scene.weather_scheduler.current
		if now != last:
			print("  %02d:%02d  %s -> %s" % [int(seconds) / 60, int(seconds) % 60, last, now])
			last = now
			sample = 0.0
		sample += step
		if is_equal_approx(fmod(sample, 15.0), 0.0) and sample <= 45.0:
			var p: Node3D = scene._precipitation
			print("          +%2ds  cloud %.2f rain %.2f  wind %.2f fog %.2f  bank x%.2f peaks x%.2f  wet %.2f snow %.2f  autumn %.2f cold %.2f" % [int(sample), scene._celestial.cloud, p.state.x, scene._atmosphere._air_strength, scene._atmosphere.fog_amount, scene._world_visuals.weather_fog, scene._world_visuals.weather_peaks, p.surface_weather.ground_wet, p.surface_weather.snow_cover, p.surface_weather.autumn, p.surface_weather.cold])
	print("Badge line: %s" % living.label())
	# E walks the year: print the plants' season as it glides.
	for press in range(4):
		var name: String = living.next_season()
		var line := "E -> %s:" % name
		for tick in range(8):
			for i in range(10): scene._process(step)
			line += "  %.3f" % scene._season_shown
		var plants: Vector4 = scene._season_plants
		print("%s  plants bloom %.2f bare %.2f dormant %.2f  gold target %.2f cold target %.2f" % [line, plants.x, plants.y, plants.z, scene._precipitation.surface_weather.target_autumn, scene._precipitation.surface_weather.target_cold])
	print("W -> %s" % living.next_weather())
	# Save round trip.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(NativeGardenStore.capture(scene)))
	print("Save valid: %s  scheduler v%s origin %s  season_override %.3f" % [NativeGardenStore.valid(scene, saved), saved.weather_scheduler.get("version"), saved.weather_scheduler.get("origin"), float(saved.world_clock.season_override)])
	NativeGardenStore.restore(scene, saved)
	print("Restored: weather %s, season %s, drift %s" % [scene.weather_scheduler.current, scene.world_clock.season_name(), scene.weather_scheduler.enabled])
	# A save from before living weather: no version, origin or season pin, and
	# drift stored as off.
	var legacy: Dictionary = saved.duplicate(true)
	for key in ["version", "origin", "origin_mood"]: legacy.weather_scheduler.erase(key)
	legacy.weather_scheduler.enabled = false
	legacy.world_clock.erase("season_override")
	legacy.world_clock.erase("year_days")
	legacy.world_clock.running = false
	print("Legacy save valid: %s" % NativeGardenStore.valid(scene, legacy))
	NativeGardenStore.restore(scene, legacy)
	print("Legacy restored: weather %s, origin %s, season %s (%.3f), drift %s" % [scene.weather_scheduler.current, scene.weather_scheduler.origin, scene.world_clock.season_name(), scene.world_clock.season, scene.weather_scheduler.enabled])
	var without: Dictionary = legacy.duplicate(true)
	without.erase("weather_scheduler")
	without.erase("world_clock")
	print("Save without clock or scheduler valid: %s" % NativeGardenStore.valid(scene, without))
	NativeGardenStore.restore(scene, without)
	print("  restored: weather %s, season %s" % [scene.weather_scheduler.current, scene.world_clock.season_name()])
	quit()
