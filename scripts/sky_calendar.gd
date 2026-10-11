extends RefCounted
## The year worn by the land and the sky: the world clock's season
## (scripts/world_clock.gd) as shown on screen, laid on the ground's gold and
## cold over the weather preset, and published to the plants and the sky
## layer. Shared by the old game's scene (studies/fidelity.gd
## `_apply_season`, whose state this was) and the kit isles' time and
## weather (scripts/kit_isle/kit_weather.gd), so both wear the year the same
## way. See docs/world-clock/README.md.
##
## The calendar reaches the weather. The scheduler leans on the season when
## it rolls the next sky, and the ground wears the year on top of the
## preset: the preset profile is the base, the season adds a lift (gold
## through autumn, cold through winter), clamped 0..1. Recomputed from the
## profile every frame, so nothing accumulates.
##
## It never fights a hand-set value. The season only rewrites a target that
## is still the one it wrote last frame, or the bare preset value a fresh
## set_weather just installed; a slider, a look preset, a restored garden or
## a --autumn=/--cold= flag therefore keeps its hold until the weather
## changes again (`held` takes a channel away from the calendar outright).
##
## Plants read the same season through the `zs_season` global (bloom, leaf
## fall, dormancy; WeatherScheduler.season_plants), and the sky layer (the
## cloud sea's grade, the cloud volume's, the peaks' snow line) through
## `zs_sky_season` (WeatherScheduler.season_sky), each set only when it
## changes. When the season owns the gold (living weather, the kit's drift)
## the weather preset adds none, so a snow shower does not turn a summer
## wood orange.

## With `glide` on, the season shown moves forward to the clock's season a
## quarter per GLIDE_SECONDS instead of jumping to it.
const GLIDE_SECONDS := 30.0

var glide := false
## The season on screen, 0..1; below 0 until the first frame (or a snap).
var shown := -1.0
## [autumn, cold]: what the season last wrote into the surface targets, and
## whether something (a command-line flag) has taken that channel away.
var wrote := [-1.0,-1.0]
var held := [false,false]
## The values last published to `zs_season` and `zs_sky_season`.
var plants := Vector4(-1.0,-1.0,-1.0,-1.0)
var sky := Vector4(-1.0,-1.0,-1.0,-1.0)
## How many times zs_sky_season has been published (tests/test_sky_seasons.gd).
var published := 0
## The next `apply` adopts the surface's gold and cold as the season's own.
var claim_pending := false

## One frame of the year: the season shown (gliding by `delta`, 0 while
## paused), handed to `scheduler` (or null) for its next roll, laid on
## `precipitation`'s surface weather over its preset (with no gold of the
## preset's own when `owns_gold`), and published where it changed.
func apply(clock: WorldClock, delta: float, precipitation: Node3D, scheduler: WeatherScheduler, owns_gold: bool) -> void:
	var season := shown_season(clock,delta)
	if scheduler != null: scheduler.season = season
	var profile: Dictionary = precipitation.profiles[precipitation.PRESET_NAMES[precipitation.preset_index]]
	var surface: RefCounted = precipitation.surface_weather
	if claim_pending:
		claim_pending = false
		claim(surface)
	var base_autumn := 0.0 if owns_gold else float(profile.autumn)
	surface.target_autumn = target(surface.target_autumn,base_autumn,WeatherScheduler.season_autumn(season),0)
	surface.target_cold = target(surface.target_cold,float(profile.cold),WeatherScheduler.season_cold(season),1)
	publish(season)

## Publishes the plants' and the sky's season for `season`, each only when
## it changed.
func publish(season: float) -> void:
	var now := WeatherScheduler.season_plants(season)
	if now != plants:
		plants = now
		RenderingServer.global_shader_parameter_set("zs_season",now)
	var quarters := WeatherScheduler.season_sky(season)
	if quarters != sky:
		sky = quarters
		published += 1
		RenderingServer.global_shader_parameter_set("zs_sky_season",quarters)

## The season on screen. Without a glide it is the clock's. With one it
## moves forward through the year toward the clock's season, so a step to
## the next season walks the plants through the leaf fall or the blossom
## instead of cutting to them. A small step backwards, or a snap request
## (`shown` below 0), jumps.
func shown_season(clock: WorldClock, delta: float) -> float:
	var season := clock.season
	if not glide or shown < 0.0:
		shown = season
		return season
	var gap := fposmod(season-shown,1.0)
	if gap < 1e-6 or gap > 0.75:
		shown = season
	else:
		shown = fposmod(shown+minf(gap,maxf(delta,0.0)*0.25/GLIDE_SECONDS),1.0)
	return shown

## Adopt the surface's current gold and cold as the season's own, so the
## season keeps steering them (a new world's mood, a restored save, a drift).
func claim(surface: RefCounted) -> void:
	wrote = [surface.target_autumn,surface.target_cold]

## The target for one channel (`slot` 0 gold, 1 cold): `base` plus the
## season's `lift`, unless something else set `current` since.
func target(current: float, base: float, lift: float, slot: int) -> float:
	if held[slot]: return current
	var wanted := clampf(base+lift,0.0,1.0)
	if not (is_equal_approx(current,wrote[slot]) or is_equal_approx(current,base)): return current
	wrote[slot] = wanted
	return wanted
