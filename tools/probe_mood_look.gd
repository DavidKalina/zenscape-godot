extends SceneTree
## Moods and pins (scripts/mood_look.gd, docs/scenic/mood.md) in the product
## scene, headless: opens the plain, applies each mood, pins a purple rock and
## a winter, switches moods and checks the pins survive, clears them, round
## trips the save (and a save from before moods), and times the rebuild and
## every frame of a cross-fade. The look itself is not checked.
##   Godot --headless --path . -s res://tools/probe_mood_look.gd

var scene: Node3D
var mood: Node
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ")+what)
	if not ok: failures += 1

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("Mood probe timed out"); quit(2))
	root.size = Vector2i(1280,800)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-mood-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(0.5).timeout
	mood = scene.mood_look
	var look: SceneLook = scene._celestial.look
	print("Plain: mood '%s', season %s, weather %s, rock %s" % [mood.mood,scene.world_clock.season_name(),mood.value("weather"),look.colors.rock.to_html(false)])
	check(scene.creation_palette.mood_button != null,"palette has a Mood button")
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	scene._unhandled_input(key)
	await process_frame
	check(scene.mood_open() and scene.mood_panel.visible,"M opens the panel over the palette")
	check(scene.mood_panel.frame.position.y+scene.mood_panel.frame.size.y*scene.mood_panel.frame.scale.y <= scene.creation_palette.frame.position.y,"panel sits above the palette")
	check(scene.world_clock.running,"the plain's day turns")
	# Every mood, faded, with frame costs. On the plain a mood sets its hour and
	# the day keeps turning, except the moods defined by their hour.
	var worst_build := 0
	var worst_frame := 0
	for id: String in mood.mood_ids():
		mood.choose(id)
		worst_build = maxi(worst_build,mood.last_build_usec)
		var frames := 0
		while mood.fading():
			await process_frame
			frames += 1
		worst_frame = maxi(worst_frame,mood.max_fade_usec)
		var p: Dictionary = SceneLookPresets.PRESETS[id]
		var sky := Color(p.colors.sky)
		check(look.colors.sky.is_equal_approx(sky) and mood.value("weather") == p.weather and mood.value("season") == mood.MOOD_SEASONS[id],
			"%s: sky, weather %s, season %s after %d frames" % [id,mood.value("weather"),mood.value("season"),frames])
		var holds: bool = id in mood.HOUR_MOODS
		var hour_gap := absf(angle_difference(float(p.phase)*TAU,scene._celestial.phase*TAU))/TAU
		check(scene.world_clock.running == (not holds) and hour_gap < 0.01,"%s: %s from its hour (%.3f off)" % [id,"holds" if holds else "turns",hour_gap])
	print("Rebuild worst %.2f ms, fade frame worst %.3f ms" % [worst_build/1000.0,worst_frame/1000.0])
	# Mid-fade frame: the sky is between the two moods.
	mood.choose("golden_meadow",false)
	mood.choose("nordic_night")
	for i in range(8): await process_frame
	var mid: Color = look.colors.sky
	check(not mid.is_equal_approx(Color("7c9daf")) and not mid.is_equal_approx(Color("536884")),"mid-fade sky is between golden meadow and nordic night (%s)" % mid.to_html(false))
	while mood.fading(): await process_frame
	# Pins survive a mood change.
	mood.choose("golden_meadow",false)
	mood.pin("rock","8a5fb0")
	mood.pin("season","winter")
	mood.pin("weather","mist")
	mood.pin("rock_type","slate")
	mood.pin("time","dusk")
	while mood.fading(): await process_frame
	check(look.colors.rock.to_html(false) == "8a5fb0","purple rock pinned")
	check(scene._world_visuals.rock_style == 1 and is_equal_approx(scene._world_visuals.rock_detail,0.9),"slate faces (layered, 0.9 detail)")
	check(scene.world_clock.season_name() == "winter" and scene._season_plants.y > 0.9,"winter pinned: bare crowns %.2f" % scene._season_plants.y)
	check(scene._precipitation.surface_weather.snow_cover > 0.3,"winter frost on the ground under golden meadow (%.2f)" % scene._precipitation.surface_weather.snow_cover)
	check(not scene.weather_scheduler.enabled,"pinned weather holds the drift")
	mood.choose("first_snow")
	while mood.fading(): await process_frame
	check(look.colors.rock.to_html(false) == "8a5fb0","purple rock survives golden meadow -> first snow")
	check(mood.value("weather") == "mist" and mood.value("time") == "dusk" and mood.value("season") == "winter","weather, time and season pins survive")
	check(not scene.world_clock.running,"a pinned hour holds under a turning mood")
	check(look.colors.sky.is_equal_approx(Color("879cb9")),"first snow's own sky is not pinned")
	mood.pin("season","summer")
	while mood.fading(): await process_frame
	check(scene._precipitation.surface_weather.snow_cover < 0.01 and scene._precipitation.cold_override < 0.0,"summer under first snow clears the mood's snow")
	mood.choose("golden_meadow")
	await process_frame
	NativeGardenStore.capture(scene)
	check(not mood.fading() and mood.value("weather") == "mist","saving lands a running fade first")
	mood.choose("first_snow",false)
	# Save round trip.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(NativeGardenStore.capture(scene)))
	check(NativeGardenStore.valid(scene,saved),"save with mood is valid")
	mood.clear_pins()
	while mood.fading(): await process_frame
	check(mood.pins.is_empty() and look.colors.rock.is_equal_approx(Color(SceneLookPresets.look_document("first_snow").colors.rock[0],SceneLookPresets.look_document("first_snow").colors.rock[1],SceneLookPresets.look_document("first_snow").colors.rock[2])),"Back to mood clears pins and the rock")
	check(scene.weather_scheduler.enabled,"unpinning weather lets the drift go again")
	NativeGardenStore.restore(scene,saved)
	check(mood.mood == "first_snow" and mood.pins.get("rock") == "8a5fb0" and mood.pins.size() == 5,"restore brings back mood and pins")
	check(look.colors.rock.to_html(false) == "8a5fb0","restored rock is purple")
	mood.choose("")
	while mood.fading(): await process_frame
	check(mood.mood == "" and look.colors.rock.to_html(false) == "8a5fb0","This world keeps pins over the world's own look")
	mood.clear_pins()
	while mood.fading(): await process_frame
	var origin_rock: Array = mood.origin.look.colors.rock
	check(look.colors.rock.is_equal_approx(Color(origin_rock[0],origin_rock[1],origin_rock[2])),"back to the world's own rock")
	# Old saves.
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("mood")
	check(NativeGardenStore.valid(scene,legacy),"save without mood is valid")
	NativeGardenStore.restore(scene,legacy)
	check(mood.mood == "" and mood.pins.is_empty() and mood.origin.is_empty(),"old save opens on its own look, nothing pinned")
	var broken: Dictionary = saved.duplicate(true)
	broken.mood.pins["rock"] = "not a colour"
	check(not NativeGardenStore.valid(scene,broken),"a broken pin is refused")
	# The colour picker path: direct, no fade.
	mood.choose("alpine_morning",false)
	var started := Time.get_ticks_usec()
	for i in range(30): mood.pin("grass",Color(0.3+i*0.01,0.6,0.3).to_html(false),false)
	print("Picker drag: %.3f ms per colour" % ((Time.get_ticks_usec()-started)/30000.0))
	check(mood.pinned("grass") and not mood.fading(),"picker pins without a fade")
	scene.toggle_mood()
	check(not scene.mood_open(),"toggle closes the panel")
	# A new plain opens on its own look with nothing pinned.
	mood.pin("rock","8a5fb0")
	await scene.places.new_plain(11)
	check(mood.mood == "" and mood.pins.is_empty() and mood.origin.is_empty(),"a new plain resets mood and pins")
	print("Failures: %d" % failures)
	quit(1 if failures > 0 else 0)
