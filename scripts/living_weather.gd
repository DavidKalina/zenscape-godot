extends RefCounted
## Weather and seasons for the product diorama (studies/diorama.gd).
##
## The sky drifts: WeatherScheduler runs in climate mode with the generator's
## own odds (cozy_world_generator.gd WET_WEATHER / DRY_WEATHER), on a clock of
## its own that ticks whenever the scene is not paused, so the weather lives
## even though a generated world holds its hour of day. Each change eases in
## over about half a minute.
##
## The year holds: a generated world is pinned to the season its mood was drawn
## for (snow is winter, gold leaves are autumn, the rest spring or summer) in
## `world_clock.season_override`, which saves with the clock. E steps to the
## next season and the scene glides there. `--seasons-turn` lets it advance
## slowly on its own instead.
##
## Nothing here scales with instance counts: plants read the season from the
## `zs_season` shader global, published by studies/fidelity.gd only when it
## changes.

const Generator = preload("res://scripts/cozy_world_generator.gd")
const Desert = preload("res://scripts/desert_landscape.gd")

## Real seconds per scheduler hour. Dwell times below are in these hours.
const HOUR_SECONDS := 20.0
## How long each sky holds, [min, max] scheduler hours: bright skies about
## three to five minutes, grey and wet ones two to three, mist a little less.
const DWELL := {
	"clear": [8.0, 14.0],
	"fair": [8.0, 14.0],
	"overcast": [5.0, 9.0],
	"mist": [4.0, 7.0],
	"rain": [5.0, 9.0],
	"snow": [6.0, 10.0],
}
## Easing rate for cloud, rain, wind, fog and haze, per second. 0.08 reaches
## 95% of a change in about 37 s; the source's 0.55 takes about 5 s.
const RESPONSE := 0.08
## Gold, cold, ice and snow cover run at this fraction of the source rate.
const SURFACE_PACE := 0.3
## A long cold spell frosts the ground up to this snow cover and no further.
const FROST_LIMIT := 0.5
## The generator's fog bank and peak cloud density per weather, relative to a
## clear sky (means of its draws). The saved values belong to the world's own
## weather, so drift scales them by current / origin.
const FOG := {"clear": 1.0, "fair": 1.0, "overcast": 1.2, "mist": 4.2, "rain": 1.9, "snow": 1.9, "storm": 1.9, "autumn": 1.0}
const PEAKS := {"clear": 1.0, "fair": 1.0, "overcast": 3.4, "mist": 3.4, "rain": 3.4, "snow": 3.4, "storm": 3.4, "autumn": 1.0}
## The generator's mean air mist per weather. The preset profiles run much
## heavier (mist 1.0), so drift moves the world's own mist by the generator's
## difference instead.
const MIST := {"clear": 0.16, "fair": 0.16, "overcast": 0.25, "mist": 0.585, "rain": 0.25, "snow": 0.25, "storm": 0.25, "autumn": 0.16}
## Where E lands in each quarter: spring in full blossom, midsummer, autumn
## gold, deep winter with bare trees.
const SEASONS := [0.14, 0.375, 0.64, 0.87]
## `--seasons-turn`: real seconds per quarter when the year advances itself.
const TURN_SECONDS := 600.0
## Share of generated spring-or-summer worlds that open in spring.
const SPRING_SHARE := 0.45

var scene: Node3D
## Off with --still-weather: the sky stays on the world's own weather.
var drift := true
## On with --seasons-turn: a pinned season creeps forward through the year.
var turning := false
var _climate_key := -1

func setup(owner: Node3D) -> void:
	scene = owner
	var args := preload("res://scripts/launch_args.gd").user_args()
	drift = "--still-weather" not in args
	turning = "--seasons-turn" in args
	scene.season_glide = true
	var surface: RefCounted = scene._precipitation.surface_weather
	surface.frost_limit = FROST_LIMIT
	if not drift:
		scene.weather_scheduler.enabled = false
		return
	scene.weather_scheduler.enabled = true
	scene._precipitation.response = RESPONSE
	scene._precipitation.gather = true
	scene._atmosphere.weather_response = RESPONSE
	surface.pace = SURFACE_PACE

## Once per frame, from the scene's weather step. `blend_seconds` is how much
## of `delta` the fog and cloud peaks may ease by (all of it when negative):
## a spin (scripts/spin_time.gd) hands over extra weather time with 0, so the
## sky's change still eases in over the real seconds of the frame's own step.
func advance(delta: float, paused: bool, blend_seconds := -1.0) -> void:
	var scheduler: WeatherScheduler = scene.weather_scheduler
	_refresh_climate()
	var precipitation: Node3D = scene._precipitation
	var picked: String = precipitation.PRESET_NAMES[precipitation.preset_index]
	# Whatever set the weather last (a regrown mood, the dropdown, a save),
	# the drift carries on from there.
	if picked != scheduler.current:
		scheduler.set_current(picked, scheduler.now_hour())
	var hours := 0.0 if paused or not is_finite(delta) else maxf(delta, 0.0) / HOUR_SECONDS
	for name in scheduler.advance(scheduler.now_hour() + hours):
		_apply(name)
	if not paused and delta > 0.0:
		var origin := scheduler.origin if FOG.has(scheduler.origin) else scheduler.current
		var eased := delta if blend_seconds < 0.0 else minf(blend_seconds, delta)
		var blend := 1.0 - exp(-eased * RESPONSE)
		var visuals: Node3D = scene._world_visuals
		visuals.weather_fog = lerpf(visuals.weather_fog, float(FOG.get(scheduler.current, 1.0)) / float(FOG[origin]), blend)
		visuals.weather_peaks = lerpf(visuals.weather_peaks, float(PEAKS.get(scheduler.current, 1.0)) / float(PEAKS[origin]), blend)
		var clock: WorldClock = scene.world_clock
		if turning and clock.season_override >= 0.0:
			clock.season_override = fposmod(clock.season_override + delta * 0.25 / TURN_SECONDS, 1.0)

## W: skip the rest of this sky and start easing toward the next one now.
func next_weather() -> String:
	_refresh_climate()
	var name: String = scene.weather_scheduler.force_next(scene.weather_scheduler.now_hour())
	_apply(name)
	return name

## Shift+W: hold the current sky, or let it drift again.
func toggle_drift() -> bool:
	scene.weather_scheduler.enabled = not scene.weather_scheduler.enabled
	return scene.weather_scheduler.enabled

## E: on to the middle of the next season. The scene glides there.
func next_season() -> String:
	var clock: WorldClock = scene.world_clock
	var quarter := (clampi(int(fposmod(clock.season, 1.0) * 4.0), 0, 3) + 1) % 4
	clock.season_override = SEASONS[quarter]
	return WorldClock.SEASON_NAMES[quarter]

## "Spring · fair": for the badge.
func label() -> String:
	var precipitation: Node3D = scene._precipitation
	return "%s · %s" % [WorldClock.name_for_season(scene.world_clock.season).capitalize(), precipitation.PRESET_NAMES[precipitation.preset_index]]

## A freshly generated world, before its mood is applied: remember the weather
## and air it was drawn with, restart the drift from its own sky and pin its
## season.
func establish(world: Dictionary) -> void:
	var mood: Dictionary = world.get("mood", {})
	var weather := str(mood.get("weather", "clear"))
	var scheduler: WeatherScheduler = scene.weather_scheduler
	var profiles: Dictionary = scene._precipitation.profiles
	if not profiles.has(weather): weather = "clear"
	var profile: Dictionary = profiles[weather]
	scheduler.origin = weather
	scheduler.origin_mood = {
		"wind": float(mood.get("wind", profile.wind)),
		"cloud": clampf(float(mood.get("clouds", profile.cloud)) - float(profile.cloud), -0.3, 0.3),
		"mist": float(mood.get("mist", MIST[weather])),
		"haze": float(mood.get("haze", profile.haze)),
	}
	scheduler.set_current(weather, scheduler.now_hour())
	scene._world_visuals.weather_fog = 1.0
	scene._world_visuals.weather_peaks = 1.0
	scene.world_clock.season_override = season_for(world)
	_climate_key = -1

## A restored save. Worlds saved before living weather have no origin and,
## with a held clock, no pinned season: take both from what the save shows.
func restored() -> void:
	var scheduler: WeatherScheduler = scene.weather_scheduler
	var precipitation: Node3D = scene._precipitation
	var weather: String = precipitation.PRESET_NAMES[precipitation.preset_index]
	if not FOG.has(scheduler.origin) or scheduler.origin_mood.size() < 4:
		var profile: Dictionary = precipitation.profiles[weather]
		var cloud: float = precipitation.cloud_override if precipitation.cloud_override >= 0.0 else precipitation.target.z
		scheduler.origin = weather
		scheduler.origin_mood = {
			"wind": scene._atmosphere.strength,
			"cloud": clampf(cloud - float(profile.cloud), -0.3, 0.3),
			"mist": scene._atmosphere._fog_target,
			"haze": scene._atmosphere._haze_target,
		}
	var visuals: Node3D = scene._world_visuals
	visuals.weather_fog = float(FOG.get(weather, 1.0)) / float(FOG[scheduler.origin])
	visuals.weather_peaks = float(PEAKS.get(weather, 1.0)) / float(PEAKS[scheduler.origin])
	var clock: WorldClock = scene.world_clock
	if clock.season_override < 0.0 and not clock.running:
		var surface: RefCounted = precipitation.surface_weather
		if surface.target_cold > 0.5: clock.season_override = SEASONS[3]
		elif surface.target_autumn > 0.05: clock.season_override = autumn_season(surface.target_autumn)
		else: clock.season_override = SEASONS[1]
	_climate_key = -1

## The season a generated world opens in. Its own random stream, so no other
## draw of the generator moves.
static func season_for(world: Dictionary) -> float:
	var mood: Dictionary = world.get("mood", {})
	if str(mood.get("weather", "")) == "snow" or float(mood.get("cold", 0.0)) > 0.5:
		return SEASONS[3]
	var autumn := float(mood.get("autumn", 0.0))
	if autumn > 0.01:
		return autumn_season(autumn)
	if str(world.get("terrain", {}).get("composition", "")) in Desert.KINDS:
		return SEASONS[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["season", int(world.get("seed", 0))])
	return SEASONS[0] if rng.randf() < SPRING_SHARE else SEASONS[1]

## The early-autumn season whose gold (WeatherScheduler.season_autumn) is
## exactly this amount, so the world keeps the gold it was drawn with.
static func autumn_season(amount: float) -> float:
	var shape: Array = WeatherScheduler.SEASON_AUTUMN
	var y := clampf(amount / float(shape[4]), 0.0, 1.0)
	# Inverse of smoothstep's 3t² - 2t³.
	var t := 0.5 - sin(asin(1.0 - 2.0 * y) / 3.0)
	return lerpf(float(shape[0]), float(shape[1]), t)

## The generator's odds for this world. Wet worlds trade snow for rain in
## summer and rain for snow in winter; the grey and wet share stays the same.
static func climate_for(dry: bool, quarter: int) -> Dictionary:
	var odds: Dictionary = (Generator.DRY_WEATHER if dry else Generator.WET_WEATHER).duplicate()
	if not dry and quarter == 1:
		odds.rain = odds.rain + odds.snow
		odds.erase("snow")
	elif not dry and quarter == 3:
		odds.snow = odds.snow + odds.rain
		odds.erase("rain")
	return odds

func _refresh_climate() -> void:
	var composition := str(scene._chunk_editor.data._recipe_settings.get("composition", ""))
	var dry := composition in Desert.KINDS
	var quarter := clampi(int(fposmod(scene.world_clock.season, 1.0) * 4.0), 0, 3)
	var key := (4 if dry else 0) + quarter
	if key == _climate_key: return
	_climate_key = key
	scene.weather_scheduler.set_climate(climate_for(dry, quarter), DWELL)

## Ease toward a new sky, starting from what is on screen and keeping the
## world's own air: its cloud offset, and wind, mist and haze moved from its
## own values by (part of) the difference between the two weathers.
func _apply(name: String) -> void:
	var precipitation: Node3D = scene._precipitation
	var scheduler: WeatherScheduler = scene.weather_scheduler
	var profiles: Dictionary = precipitation.profiles
	# A mood pins the visible cloud with an override. Start the ease from it,
	# so clearing the override does not step the sky, the light or the rays.
	if precipitation.cloud_override >= 0.0:
		precipitation.state.z = precipitation.cloud_override
	precipitation.set_weather(WeatherScheduler.preset_index(name))
	var profile: Dictionary = profiles[name]
	var air := scheduler.origin_mood
	if profiles.has(scheduler.origin) and air.size() >= 4:
		var from: Dictionary = profiles[scheduler.origin]
		var atmosphere: Node3D = scene._atmosphere
		precipitation.target.z = clampf(float(profile.cloud) + float(air.cloud), 0.0, 1.0)
		atmosphere.strength = clampf(float(air.wind) + (float(profile.wind) - float(from.wind)) * 0.5, 0.12, 1.4)
		atmosphere._fog_target = clampf(float(air.mist) + float(MIST.get(name, 0.16)) - float(MIST.get(scheduler.origin, 0.16)), 0.02, 0.8)
		atmosphere._haze_target = clampf(float(air.haze) + (float(profile.haze) - float(from.haze)) * 0.5, 0.05, 0.6)
	# The season owns the leaves' gold; the weather keeps only the cold.
	precipitation.surface_weather.target_autumn = 0.0
	scene.claim_season()
	scene._apply_season(0.0)
