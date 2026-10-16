extends SceneTree
## The aqueduct isle's time and weather (scripts/kit_isle/kit_weather.gd,
## docs/design/consolidation-audit.md round 4), headless: the isle opens on
## the live sky (the start look's colours, the world clock attached and
## turning from --hour, the year in --season, the start look's pins handed
## to the drift, living weather's easing); the day turns into night and back
## and the isle's life reads it; the year is worn on the ground and
## published to the sky layer and the plants, steps on (F11) with the plants
## gliding, and turns with the days; the weather drifts on the scheduler's
## seasonal table for the clock's hour, eased, the season keeping the gold,
## and holds when told; a look preset holds the sky (its hour, weather and
## season; the drift off) and Live sky gives it back from the hour it was
## held at, first in L's order; a storm strikes in the towers, the cloud
## sea and from the drifting clouds, never on an isle, thunders, and the
## cloud volume gets the flash; the settings' Day and night and Weather
## apply and keep; and a --still-sky start holds the start look, its flags
## beating the settings. The cost of a frame of it is printed (µs on the
## main thread). Headless: no drawing, only the sky's state.
##   godot --headless --path . --script tests/test_kit_time_weather.gd
const KitWeather = preload("res://scripts/kit_isle/kit_weather.gd")
const Living = preload("res://scripts/living_weather.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const GameSettings = preload("res://scripts/kit_isle/game_settings.gd")
const SettingsMenu = preload("res://scripts/kit_isle/settings_menu.gd")
const CloudVolume = preload("res://scripts/cloud_volume.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const DT := 1.0/30.0
const LOOK_PATH := "user://test_kit_time_weather_look.cfg"
var failures := 0
var study: Node3D
var weather: Node
var clock: WorldClock

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("kit time and weather test timed out"); quit(2))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOOK_PATH))
	GameSettings.look_path = LOOK_PATH
	LaunchArgs.set_override(["--season=autumn","--hour=10","--weather-seed=11"])
	await _build()
	_opens_live()
	_day_turns()
	_year()
	_drift()
	_presets_hold()
	await _storm()
	_settings()
	_cost()
	await _free()
	LaunchArgs.set_override(["--still-sky","--day-length=30"])
	await _build()
	_held_start()
	await _free()
	LaunchArgs.set_override(["--hour=10","--weather-seed=11"])
	await _build()
	_season_row()
	await _free()
	LaunchArgs.set_override(null)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOOK_PATH))
	print("PASS: kit time and weather" if failures == 0 else "FAIL: kit time and weather (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _build() -> void:
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	weather = study.weather
	clock = weather.clock

func _free() -> void:
	study.queue_free()
	study = null
	await process_frame
	await process_frame

## Steps the look (the weather first in it) `seconds` on.
func _run(seconds: float) -> void:
	for i in range(int(seconds/DT)): study._advance_look(DT)

# --- The live sky ------------------------------------------------------------------------

func _opens_live() -> void:
	check(weather is KitWeather and weather.live and study.look_id == KitWeather.LIVE,"The isle opens on the live sky (%s)" % study.look_id)
	check(study._look_ids[0] == KitWeather.LIVE and study._look_ids.size() == SceneLookPresets.PRESETS.size()+1,"Live sky is first in L's order, before every preset")
	check(study._celestial.look.document() == SceneLookPresets.look_document(study.START_LOOK),"In the start look's colours (%s)" % study.START_LOOK)
	check(study._celestial.clock == clock and clock.running and study._celestial.cycling,"The world clock is attached to the sky and turning")
	check(is_equal_approx(clock.day_length,WorldClock.DEFAULT_DAY_LENGTH),"A day of the old game's %d s" % int(clock.day_length))
	check(absf(clock.hour-10.0) < 1.0,"From --hour (%.2f)" % clock.hour)
	check(clock.season >= 0.5 and clock.season < 0.75 and clock.season_name() == "autumn","In --season's quarter (%.3f, %s)" % [clock.season,clock.season_name()])
	var surface: RefCounted = study._precipitation.surface_weather
	check(surface.target_autumn > 0.5 and surface.autumn > 0.5,"The ground wears autumn's gold at once (%.2f)" % surface.autumn)
	check(weather.calendar.sky == WeatherScheduler.season_sky(weather.calendar.shown) and weather.calendar.published >= 1,"The sky layer's season is published (%s)" % str(weather.calendar.sky))
	check(weather.calendar.plants == WeatherScheduler.season_plants(weather.calendar.shown),"and the plants' (%s)" % str(weather.calendar.plants))
	var precipitation: Node3D = study._precipitation
	check(precipitation.cloud_override < 0.0 and precipitation.cold_override < 0.0,"The start look's cloud and cold pins are handed to the drift")
	check(is_equal_approx(precipitation.response,Living.RESPONSE) and precipitation.gather and is_equal_approx(study._atmosphere.weather_response,Living.RESPONSE),"Its skies ease in as living weather's do")
	check(weather.scheduler.enabled and weather.scheduler.current == SceneLookPresets.PRESETS[study.START_LOOK].weather,"The drift is on, from the start look's weather (%s)" % weather.scheduler.current)
	check(study.get("_lightning") == weather.lightning and weather.lightning.aim.is_valid(),"The scene's lightning (the look pass's) is the sky's, aimed by it")
	check(KitWeather.date_season({"year":2026,"month":10,"day":11}) > 0.5 and KitWeather.date_season({"year":2026,"month":10,"day":11}) < 0.75,"The date's season: mid October is autumn")
	check(is_zero_approx(KitWeather.date_season({"month":3,"day":1})) and KitWeather.date_season({"month":1,"day":15}) >= 0.75 and absf(KitWeather.date_season({"month":6,"day":21})-0.31) < 0.05,"1 March opens spring; January is winter; midsummer is summer")
	check(is_equal_approx(KitWeather.season_named("summer"),Living.SEASONS[1]) and is_equal_approx(KitWeather.season_named("0.9"),0.9),"--season by name or number")

func _day_turns() -> void:
	var from := clock.hour
	_run(10.0)
	check(absf(fposmod(clock.hour-from,24.0)-10.0*24.0/clock.day_length) < 0.01,"The hours run with the day (%.2f h in 10 s)" % fposmod(clock.hour-from,24.0))
	var day := clock.day
	clock.day_length = 48.0
	clock.set_time(day,17.0)
	while clock.hour < 21.5: study._advance_look(DT)
	var celestial: RefCounted = study._celestial
	check(celestial.sun_height < 0.0 and float(celestial.state.get("zs_daylight",1.0)) < 0.05,"Evening turns to night (sun %.2f, daylight %.2f)" % [celestial.sun_height,float(celestial.state.get("zs_daylight",1.0))])
	check(celestial.night_grade.x > 0.3,"and the night's look comes in (%.2f)" % celestial.night_grade.x)
	while clock.day == day or clock.hour < 9.0: study._advance_look(DT)
	check(clock.day == day+1 and celestial.sun_height > 0.2 and float(celestial.state.get("zs_daylight",0.0)) > 0.5,"and night to the next morning (day %d, sun %.2f)" % [clock.day,celestial.sun_height])
	clock.day_length = weather.day_length

func _year() -> void:
	var season := clock.season
	var key := InputEventKey.new()
	key.keycode = KEY_F11
	key.pressed = true
	study._unhandled_input(key)
	check(clock.season_name() == "winter" and absf(clock.season-Living.SEASONS[3]) < 0.03,"F11 steps on to winter (%.3f)" % clock.season)
	check(study._look_toast.text.begins_with("Turning toward winter"),"and says so")
	check(absf(weather.calendar.shown-season) < 0.01,"The plants don't cut to it")
	_run(5.0)
	check(weather.calendar.shown > season+0.02 and weather.calendar.shown < clock.season,"They glide toward it (%.3f)" % weather.calendar.shown)
	_run(40.0)
	var surface: RefCounted = study._precipitation.surface_weather
	check(absf(weather.calendar.shown-clock.season) < 0.001 and weather.calendar.sky.w > 0.99,"Then winter is the sky's (%s)" % str(weather.calendar.sky))
	check(surface.target_cold > 0.5 and surface.target_autumn < 0.1,"and the ground's: cold, the gold gone (cold %.2f, gold %.2f)" % [surface.target_cold,surface.target_autumn])
	var before := clock.season
	var from := clock.day+clock.hour/WorldClock.HOURS_PER_DAY
	clock.day_length = 30.0
	_run(60.0)
	clock.day_length = weather.day_length
	var days := clock.day+clock.hour/WorldClock.HOURS_PER_DAY-from
	check(days > 1.9 and absf(fposmod(clock.season-before,1.0)-days/clock.year_days) < 0.001,"The year turns with the days (%.4f in %.2f days; %d days a year)" % [fposmod(clock.season-before,1.0),days,clock.year_days])

func _drift() -> void:
	var scheduler: WeatherScheduler = weather.scheduler
	var precipitation: Node3D = study._precipitation
	var seen := {}
	var eased := 0
	var gold_ok := true
	var history := scheduler.history.size()
	weather.weather_hour = 0.05
	var current := scheduler.current
	for i in range(int(30.0/DT)):
		study._advance_look(DT)
		if scheduler.current != current:
			current = scheduler.current
			seen[current] = true
			if precipitation.state.distance_to(precipitation.target) > 0.01: eased += 1
		var lift := WeatherScheduler.season_autumn(weather.calendar.shown)
		if absf(precipitation.surface_weather.target_autumn-lift) > 0.01: gold_ok = false
	check(seen.size() >= 3 and scheduler.history.size() > history,"The weather drifts (%s)" % ", ".join(seen.keys()))
	check(eased >= seen.size()-1,"Each new sky eases in (%d of %d)" % [eased,seen.size()])
	check(gold_ok,"The season keeps the gold whatever the sky")
	check(is_equal_approx(scheduler.hour_of_day,clock.hour) and is_equal_approx(scheduler.season,weather.calendar.shown),"Drawn for the clock's hour and the season shown")
	weather.choose_drift(false)
	var held := scheduler.current
	var count := scheduler.history.size()
	_run(20.0)
	check(scheduler.current == held and scheduler.history.size() == count,"Told to hold, it holds (%s)" % held)
	weather.choose_drift(true)
	weather.weather_hour = KitWeather.WEATHER_HOUR

# --- The presets over it -----------------------------------------------------------------

func _presets_hold() -> void:
	study.apply_look("nordic_night")
	var hour := clock.hour
	_run(4.0)
	check(not weather.live and not clock.running and not weather.scheduler.enabled,"A look preset holds the sky: the clock and the drift stop")
	check(is_equal_approx(clock.hour,hour) and SceneLookPresets.matches(study,"nordic_night"),"at its hour, as the editor applies it")
	check(is_equal_approx(clock.season,KitWeather.preset_season("nordic_night")) and clock.season < 0.5,"in the season it was drawn for (%.3f)" % clock.season)
	check(is_equal_approx(study._precipitation.response,0.55) and not study._precipitation.gather,"its weather set as the editor sets it, not eased")
	study.apply_look("first_snow")
	_run(2.0)
	check(absf(clock.season-Living.SEASONS[3]) < 0.001 and weather.calendar.sky.w > 0.99,"First snow holds winter, in the sky too")
	check(SceneLookPresets.matches(study,"first_snow"),"its own ground kept, not the calendar's (gold %.2f)" % study._precipitation.surface_weather.target_autumn)
	study.apply_look("copper_autumn")
	check(clock.season >= 0.5 and clock.season < 0.6 and absf(study._precipitation.surface_weather.target_autumn-0.65) < 0.001,"Copper autumn holds autumn, its own gold kept (%.3f)" % clock.season)
	var held_hour := clock.hour
	var day := clock.day
	study.step_look(-1)
	check(study.look_id == SceneLookPresets.PRESETS.keys()[SceneLookPresets.PRESETS.keys().find("copper_autumn")-1],"Shift+L steps back through the presets")
	study.apply_look("copper_autumn")
	held_hour = clock.hour
	study.apply_look(KitWeather.LIVE)
	check(weather.live and clock.running and weather.scheduler.enabled and study.look_id == KitWeather.LIVE,"Live sky gives it back")
	check(absf(clock.hour-held_hour) < 0.01 and clock.day == day and clock.season_override < 0.0,"from the hour it was held at, the year the calendar's again")
	check(study._look_toast.text.begins_with(KitWeather.LIVE_TITLE),"and says so")
	study.step_look(1)
	check(study.look_id == SceneLookPresets.PRESETS.keys()[0] and not weather.live,"L from Live sky goes on to the first preset")
	study.step_look(-1)
	check(study.look_id == KitWeather.LIVE and weather.live,"and Shift+L back to it")

# --- The storm ----------------------------------------------------------------------------

func _storm() -> void:
	var host: Node = study.cloud_host()
	var eye: Vector3 = study.camera.global_position
	# The towers in reach surveyed and made, then stood whole.
	host.towers.advance(1.0,eye)
	host.flush()
	var in_tower: Variant = weather._in_tower(host,eye)
	var inside := false
	if in_tower is Vector3:
		for column: Array in host.towers.screens(eye):
			var middle := Vector2(column[0].x,column[0].y)
			var at := Vector2(in_tower.x,in_tower.z)
			if at.distance_to(middle) <= column[0].z and in_tower.y > column[1].x and in_tower.y < column[1].y and at.distance_to(Vector2(eye.x,eye.z)) < middle.distance_to(Vector2(eye.x,eye.z)): inside = true
	check(inside,"A tower's flash stands inside its column, on the near side (%s)" % str(in_tower))
	var sea: Vector3 = weather._in_sea(eye)
	var ring := Vector2(sea.x-eye.x,sea.z-eye.z).length()
	check(is_equal_approx(sea.y,KitWeather.SEA_TOP-KitWeather.SEA_DEPTH) and ring >= KitWeather.SEA_RING.x-0.1 and ring <= KitWeather.SEA_RING.y+0.1 and weather._clear(sea),"A sea flash sits in the cloud sea's heaps, %d m off, off every isle" % int(ring))
	var lightning: Node3D = weather.lightning
	var isle: Vector3 = study.isle_circle()
	lightning.strike_through(Vector3(isle.x+400.0,40.0,isle.y),KitWeather.SEA_TOP,eye)
	check(lightning._bolts.get_child_count() > 0 and is_equal_approx(lightning.flash_position.y,KitWeather.SEA_TOP),"A bolt falls from a cloud into the sea, the flash where it lands")
	# The storm, held.
	weather.choose_drift(false)
	study._precipitation.set_weather(WeatherScheduler.preset_index("storm"),true)
	var strikes: int = lightning.strike_count
	var heard: int = weather.thunder.played_count
	var flashes: Array = []
	var last: int = lightning.strike_count
	for i in range(int(70.0/DT)):
		study._advance_look(DT)
		if lightning.strike_count != last:
			last = lightning.strike_count
			flashes.append(lightning.flash_position)
	var off := true
	var kinds := {}
	for at: Vector3 in flashes:
		if Vector2(at.x-isle.x,at.z-isle.y).length() < isle.z: off = false
		if is_equal_approx(at.y,KitWeather.SEA_TOP-KitWeather.SEA_DEPTH): kinds["sea"] = true
		elif is_equal_approx(at.y,KitWeather.SEA_TOP): kinds["bolt"] = true
		else: kinds["tower"] = true
	check(flashes.size() >= 5,"A storm strikes on its own (%d strikes in 70 s)" % flashes.size())
	check(kinds.size() >= 2,"in the towers, the sea and from the clouds (%s)" % ", ".join(kinds.keys()))
	check(off,"never on the isle")
	check(weather.thunder.played_count > heard,"and thunders (%d)" % (weather.thunder.played_count-heard))
	check(lightning.clap.w == 0.0,"No downburst: nothing falls on the grass")
	var volume: Node3D = CloudVolume.new()
	study.add_child(volume)
	volume.lightning = study.get("_lightning")
	lightning.flash_in(sea,eye)
	check(lightning.flash > 0.99,"A flash is bright on its own frame, however late in the session (%.2f at %.0f s)" % [lightning.flash,lightning.clock])
	volume.update(study.camera,null,host,null,0.0)
	volume._fill()
	var p: PackedFloat32Array = volume.effect.march_params
	check(Vector3(p[172],p[173],p[174]).distance_to(sea) < 0.01 and is_equal_approx(p[175],lightning.flash*KitWeather.VOLUME_GAIN) and p[175] > 0.0,"The cloud volume lights round the flash, %d times the plate's (%.2f)" % [int(KitWeather.VOLUME_GAIN),p[175]])
	volume.queue_free()
	await process_frame
	study._precipitation.set_weather(WeatherScheduler.preset_index("fair"),true)
	weather.choose_drift(true)
	host.towers.pinned = -1.0

# --- The settings -------------------------------------------------------------------------

func _settings() -> void:
	check(GameSettings.entry("day").options == KitWeather.DAY_NAMES and GameSettings.entry("weather").options == KitWeather.DRIFT_NAMES,"Settings offer Day and night and Weather")
	check(GameSettings.index_of("day") == 0 and GameSettings.index_of("weather") == 0,"An 8 minute day and drifting weather until chosen")
	var menu: Control = SettingsMenu.new()
	check(menu.choice_rows.has("day") and menu.choice_rows.has("weather"),"Both have a row on the settings sheet")
	menu.free()
	GameSettings.choose("day",1,study)
	check(is_equal_approx(clock.day_length,1440.0) and clock.running and GameSettings.index_of("day") == 1,"A day in 24 minutes applies and keeps")
	GameSettings.choose("day",2,study)
	var hour := clock.hour
	_run(3.0)
	check(not clock.running and is_equal_approx(clock.hour,hour) and GameSettings.index_of("day") == 2,"Held holds the hour")
	GameSettings.choose("weather",1,study)
	check(not weather.scheduler.enabled and GameSettings.index_of("weather") == 1,"Still weather holds the sky")
	study.apply_look("golden_meadow")
	GameSettings.choose("day",1,study)
	check(not clock.running,"A preset keeps its hour whatever the day's length")
	study.apply_look(KitWeather.LIVE)
	check(clock.running and is_equal_approx(clock.day_length,1440.0) and not weather.scheduler.enabled,"and Live sky takes up the chosen length and the still weather")
	GameSettings.choose("day",0,study)
	GameSettings.choose("weather",0,study)
	var autumn := clock.season
	GameSettings.choose("season",4,study)
	check(is_equal_approx(clock.season,autumn) and clock.season_override < 0.0,"--season beats the Season setting")
	GameSettings.choose("season",0,study)
	GameSettings.apply_start(study)
	check(is_equal_approx(clock.day_length,WorldClock.DEFAULT_DAY_LENGTH) and weather.scheduler.enabled,"The kept choices apply at the start")

## The Season row: Live by default, a named season holds the year there (the
## calendar doesn't advance, the plants glide), Live turns it again, kept.
func _season_row() -> void:
	check(GameSettings.entry("season").options == KitWeather.SEASON_CHOICES and KitWeather.SEASON_CHOICES.size() == 5,"Settings offer Season: Live, Spring, Summer, Autumn, Winter")
	check(GameSettings.index_of("season") == 0 and weather.season_choice == 0,"Live until chosen")
	var menu: Control = SettingsMenu.new()
	check(menu.choice_rows.has("season"),"Season has a row on the settings sheet")
	menu.free()
	GameSettings.choose("day",0,study)
	GameSettings.choose("season",4,study)
	var shown: float = weather.calendar.shown
	check(clock.season_override >= 0.0 and clock.season_name() == "winter" and GameSettings.index_of("season") == 4,"Winter holds the year at winter and keeps")
	_run(5.0)
	check(not is_equal_approx(weather.calendar.shown,shown) or is_equal_approx(shown,clock.season),"The plants glide there, not snap")
	var held := clock.season
	clock.day_length = 30.0
	_run(60.0)
	clock.day_length = weather.day_length
	check(clock.day > 0 and is_equal_approx(clock.season,held) and clock.season_name() == "winter","The calendar turns on but the season stays winter")
	GameSettings.choose("season",0,study)
	var day := clock.day
	check(clock.season_override < 0.0 and GameSettings.index_of("season") == 0,"Live gives the year back")
	# Either side of the date: the clock counts whole days from its start hour.
	var date_season := KitWeather.date_season(Time.get_date_dict_from_system())
	var off := fposmod(clock.season-date_season,1.0)
	check(minf(off,1.0-off) < 0.05,"at the real date's season (%.3f, the date's %.3f)" % [clock.season,date_season])
	var before := clock.season
	clock.day_length = 30.0
	_run(60.0)
	clock.day_length = weather.day_length
	check(not is_equal_approx(clock.season,before) and clock.day > day,"and turns again")
	GameSettings.choose("season",2,study)
	GameSettings.apply_start(study)
	check(clock.season_name() == "summer" and GameSettings.index_of("season") == 2,"A kept season applies at the start")
	GameSettings.choose("season",0,study)

# --- The cost --------------------------------------------------------------------------------

func _cost() -> void:
	var total := 0
	var steps := 3000
	weather.weather_hour = 0.5
	for i in range(steps):
		weather.step(DT)
		total += weather.spent
	weather.weather_hour = KitWeather.WEATHER_HOUR
	var eye: Vector3 = study.camera.global_position
	var began := Time.get_ticks_usec()
	for i in range(10): weather.lightning.strike_through(eye+Vector3(300.0,0.0,0.0),KitWeather.SEA_TOP,eye)
	var bolt := (Time.get_ticks_usec()-began)/10
	print("kit time and weather: %.1f µs a frame on the main thread (mean of %d steps: the clock, the drift, the year, the storm); a bolt built in %d µs" % [float(total)/steps,steps,bolt])
	check(float(total)/steps < 500.0,"A frame of it is cheap (%.1f µs)" % (float(total)/steps))

# --- A held start ----------------------------------------------------------------------------

func _held_start() -> void:
	check(not weather.live and study.look_id == study.START_LOOK and SceneLookPresets.matches(study,study.START_LOOK),"--still-sky starts held in the start look")
	var hour := clock.hour
	_run(3.0)
	check(not clock.running and is_equal_approx(clock.hour,hour),"its hour still")
	GameSettings.choose("day",1,study)
	study.apply_look(KitWeather.LIVE)
	check(weather.live and is_equal_approx(clock.day_length,30.0),"Live from there on --day-length's day, the flag beating the settings (%d s)" % int(clock.day_length))
	GameSettings.choose("day",0,study)
