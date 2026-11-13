class_name WeatherSkyLights
extends RefCounted
## The sky's lights over the endless flight (docs/design/endless-flight/
## spec-weather.md, lane sky-lights): a rainbow after rain and an aurora on
## some clear nights. Both shaders were already in the dome
## (shaders/reference_sky_common.gdshaderinc zsRainbow, zsAurora); this drives
## them. Stepped by scripts/endless/endless_look.gd each frame, after the
## weather's grade and before celestial.advance; it writes celestial's
## weather_bow, weather_bow_double and sky_aurora, and the zs_aurora_shape
## global. Reads the weather (null with --weather=off: the aurora's nights
## still come, the rainbow only by its flag) and never touches the plane.
##
## THE RAINBOW. Sunlight turned back by drops still falling opposite the sun:
## it wants the sun up but under about 42 degrees (the bow's top is above the
## horizon only then; strongest low), the sun reaching the eye (the weather's
## clear sky, less the rain falling here), and rain in the air toward the
## antisolar bearing (Weather.rain_ahead). Eased over BOW_EASE seconds, so it
## comes as a shower moves off and goes as the rain leaves. Each spell rolls
## once whether its bow may double (DOUBLE_CHANCE), shown only when strong.
## The dome draws it on sky pixels; the far land's haze and the cloud
## composite carry it too (shaders/weather_bow.gdshaderinc), so it stands in
## front of far cloud and its lower arc shows against the land from the air.
##
## THE AURORA. Endless flight has no world clock (celestial's own roll never
## fires), and its night is only a blue hour (celestial night_floor), whose
## zs_night never reached the shader's gate. Each night (from the afterglow
## through the blue hour, counted by the day cycle) rolls once (on the
## launch's clock, or --weather-seed=N): AURORA_CHANCE of them glow, at a strength in AURORA_STRENGTH, from an
## onset a little way into the dark. It rises and falls with the blue hour's
## depth, eased over AURORA_EASE s, faded by cloud cover and gone in rain.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const DayCycle = preload("res://scripts/endless/day_cycle.gd")

## The rainbow at its strongest (celestial weather_bow; the shader's scale).
const BOW_MAX := 0.5
## Sun height (sin of its elevation): the bow comes in as the sun clears
## BOW_SUN_UP.x..y (direct light, not the last red sliver) and goes as it
## climbs BOW_SUN_HIGH.x..y (about 28 to 40 degrees: the top sinks under the
## horizon at 42). Strongest low: BOW_LOW_GAIN more under BOW_LOW_E.
const BOW_SUN_UP := Vector2(0.01, 0.07)
const BOW_SUN_HIGH := Vector2(0.47, 0.64)
const BOW_LOW_E := Vector2(0.35, 0.12)
const BOW_LOW_GAIN := 0.35
## The sun out at the eye: the weather's clear_sky() over this ramp (a
## shower's 0.35 lets the sun through its gaps; a storm's 0 does not), times
## the gap in the cells BOW_SUN_GAP m toward the sun (a cell is heavy cloud),
## less BOW_RAIN_HERE of the rain falling on the eye.
const BOW_CLEAR := Vector2(0.12, 0.42)
const BOW_SUN_GAP := 2000.0
const BOW_RAIN_HERE := 0.8
## Rain ahead (Weather.rain_ahead toward the antisolar bearing) over this ramp.
const BOW_RAIN := Vector2(0.01, 0.15)
## Seconds (real) to come and go: an exponential ease with this time constant.
const BOW_EASE := 14.0
## A spell's chance of a double bow, and the strength (of BOW_MAX) it shows over.
const DOUBLE_CHANCE := 0.25
const DOUBLE_OVER := Vector2(0.55, 0.85)
const DOUBLE_EASE := 10.0
## --rainbow alone forces this much.
const BOW_FORCED := 0.5

## A night's chance of an aurora, its strength range (zs_aurora.x), and its
## onset: how deep into the blue hour it starts (0..1 of blue_hour's rise).
const AURORA_CHANCE := 0.3
const AURORA_STRENGTH := Vector2(0.55, 1.0)
const AURORA_ONSET := Vector2(0.2, 0.7)
const AURORA_EASE := 25.0
const AURORA_COVER := Vector2(0.08, 0.3)
const AURORA_RAIN := Vector2(0.0, 0.04)
const AURORA_SEED := 0x4a7012
## zs_aurora_shape (shaders/reference_sky_common.gdshaderinc zsAurora):
## x a floor under the shader's night gate (the blue hour's depth stands in
## for a full night), y how far the curtains' feet stand raised (in dir.y),
## z their height's scale, w the light's scale.
const AURORA_LIFT := 0.3
const AURORA_TALL := 1.0
const AURORA_GAIN := 1.0

var bow := 0.0
var bow_target := 0.0
var bow_double := 0.0
var aurora := 0.0
var aurora_target := 0.0
## The forced floors: --rainbow[=X], --rainbow-double; -1 none.
var forced_bow := -1.0
var forced_double := false
## --aurora=X: a floor at X (plain --aurora is celestial's own 1.2).
var forced_aurora := 0.0
var _seed := 0
var _night := -999
var _plan := Vector3.ZERO
var _spell_roll := -1.0
var _spell_key := -1.0
## The bow's last inputs (sun, sun out, rain ahead), for the drivers.
var _last := Vector3.ZERO

func setup(flight_seed: int) -> void:
	# The land's seed is the same every flight, so the nights roll on the
	# launch's clock (no draw on the global RNG), unless --weather-seed=N pins
	# them (then the same nights every time).
	_seed = hash(Vector2i(flight_seed,int(Time.get_unix_time_from_system())))
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--weather-seed="): _seed = hash(Vector2i(flight_seed,a.get_slice("=",1).to_int()))
		elif a.begins_with("--aurora="): forced_aurora = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--rainbow": forced_bow = BOW_FORCED
		elif a.begins_with("--rainbow="): forced_bow = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--rainbow-double":
			forced_double = true
			if forced_bow < 0.0: forced_bow = BOW_FORCED

## One frame. `celestial` the look's (its sun_height as of the last rig),
## `weather` the Weather or null, `cycle` the DayCycle.
func step(delta: float, celestial: RefCounted, weather: RefCounted, cycle: RefCounted, eye := Vector3.ZERO) -> void:
	_step_bow(delta,celestial,weather,eye)
	_step_aurora(delta,celestial,weather,cycle)

func _step_bow(delta: float, celestial: RefCounted, weather: RefCounted, eye: Vector3) -> void:
	bow_target = 0.0
	var e := float(celestial.sun_height)
	if weather != null:
		var sun_f := smoothstep(BOW_SUN_UP.x,BOW_SUN_UP.y,e)*(1.0-smoothstep(BOW_SUN_HIGH.x,BOW_SUN_HIGH.y,e))
		sun_f *= (1.0-BOW_LOW_GAIN)+BOW_LOW_GAIN*smoothstep(BOW_LOW_E.x,BOW_LOW_E.y,e)
		var rain := 0.0
		var out := 0.0
		var s: Vector3 = celestial.state.get("zs_sun_direction",Vector3.UP)
		var toward := Vector2(s.x,s.z)
		if sun_f > 0.0 and toward.length() > 1e-4:
			toward = toward.normalized()
			# The sun out at the eye: the sky open enough (a shower's broken
			# cover lets it through, a storm's does not), no cell over the
			# sun's bearing (the cells are the heavy cloud), and not much rain
			# falling on the eye.
			var gap := 1.0-float(weather.cell_at(Vector2(eye.x,eye.z)+toward*BOW_SUN_GAP))
			out = smoothstep(BOW_CLEAR.x,BOW_CLEAR.y,float(weather.clear_sky()))*gap*(1.0-BOW_RAIN_HERE*float(weather.rain_here()))
			if out > 0.0: rain = smoothstep(BOW_RAIN.x,BOW_RAIN.y,float(weather.rain_ahead(-toward)))
		bow_target = BOW_MAX*sun_f*out*rain
		_last = Vector3(sun_f,out,rain)
		# Each spell rolls once for a double (keyed on the spell's start).
		var key := _spell_start(weather)
		if key != _spell_key:
			_spell_key = key
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(Vector2(float(_seed),key))
			_spell_roll = rng.randf()
	# (On the weather's clock, so --weather-pace speeds the bow's ease too.)
	var dt := delta*(float(weather.pace) if weather != null else 1.0)
	bow += (bow_target-bow)*(1.0-exp(-dt/BOW_EASE))
	if bow < 1e-4 and bow_target <= 0.0: bow = 0.0
	var dbl := 0.0
	if _spell_roll >= 0.0 and _spell_roll < DOUBLE_CHANCE:
		dbl = smoothstep(DOUBLE_OVER.x,DOUBLE_OVER.y,bow/BOW_MAX)
	bow_double += (dbl-bow_double)*(1.0-exp(-dt/DOUBLE_EASE))
	var shown := bow
	var shown_double := bow_double
	if forced_bow >= 0.0:
		shown = maxf(shown,forced_bow)
		if forced_double: shown_double = 1.0
	celestial.weather_bow = shown
	celestial.weather_bow_double = shown_double
	# The weather's bow fades in whole: celestial's grow (a sweep round the
	# ring, for the isles' moments) is skipped while it shows.
	if shown > 0.0: celestial._rainbow_growth = 1.0

## The start of the weather's spell now or next (its key for the double's
## roll), or -1 when it is held by a flag.
static func _spell_start(weather: RefCounted) -> float:
	var spells: Array = weather.get("_spells")
	if spells == null or spells.is_empty(): return -1.0
	for s: Array in spells:
		if float(weather.time) < float(s[0])+float(s[2])+float(s[3])+float(s[4]): return float(s[0])
	return float(spells.back()[0])

func _step_aurora(delta: float, celestial: RefCounted, weather: RefCounted, cycle: RefCounted) -> void:
	var blue := float(celestial.blue_hour)
	# Night n runs from the sun's noon (phase 0.5) to the next: the dark part
	# sits round the cycle's midnight, where the day count turns.
	var phase := float(celestial.phase)
	var n := int(cycle.day)+(1 if phase >= 0.5 else 0)
	if n != _night:
		_night = n
		var p := plan_of(n)
		_plan = Vector3(p.x,p.y,0.0)
	# Rising: in once the blue hour is `onset` deep, and out as it lifts.
	var dark := smoothstep(_plan.y,1.0,blue)
	var sky := 1.0
	if weather != null:
		sky = (1.0-smoothstep(AURORA_COVER.x,AURORA_COVER.y,float(weather.cover())))*(1.0-smoothstep(AURORA_RAIN.x,AURORA_RAIN.y,float(weather.rain_level())))
	aurora_target = _plan.x*dark*sky
	# (On the day's clock: a faster or shorter day eases it as fast.)
	var day_dt := delta*float(cycle.speed())*DayCycle.LENGTH/maxf(float(cycle.length),1.0) if cycle.running else delta
	aurora += (aurora_target-aurora)*(1.0-exp(-day_dt/AURORA_EASE))
	if aurora < 1e-4 and aurora_target <= 0.0: aurora = 0.0
	celestial.sky_aurora = maxf(aurora,forced_aurora)
	# The shader's night gate: the blue hour's depth (the endless night).
	RenderingServer.global_shader_parameter_set("zs_aurora_shape",Vector4(smoothstep(0.3,1.0,blue),AURORA_LIFT,AURORA_TALL,AURORA_GAIN))

## Night `n`'s roll: (strength, 0 for none; onset).
func plan_of(n: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3(float(_seed),float(n),float(AURORA_SEED)))
	var strength := rng.randf_range(AURORA_STRENGTH.x,AURORA_STRENGTH.y)
	var onset := rng.randf_range(AURORA_ONSET.x,AURORA_ONSET.y)
	return Vector2(strength if rng.randf() < AURORA_CHANCE else 0.0,onset)

## A planned night: [strength (0 none), onset], for the drivers.
func night_plan() -> Vector2:
	return Vector2(_plan.x,_plan.y)

func note() -> String:
	return "bow %.2f (target %.2f, double %.2f)  Â·  aurora %.2f (target %.2f, night %d plan %.2f)" % [bow,bow_target,bow_double,aurora,aurora_target,_night,_plan.x]
