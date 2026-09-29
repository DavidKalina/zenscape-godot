extends Node
## Spin is time (docs/scenic/modeless.md, docs/scenic/hand-world.md "Verbs on
## the diorama"). Under `--modeless` the speed the world turns at (the lazy
## Susan, scripts/world_turn.gd `own_rate`) winds the world clock. A normal
## turn leaves time alone. Past TIME_MIN a spin advances it, hours a second
## at first and days a second for the fastest spin the turn allows, and it
## does so by the world's own means: the clock's hour and day move, the
## season override (when one is held) moves with the calendar, and living
## weather is given the real time those hours would have taken, so the sky
## changes because time passed. Nothing is faked. The sun, moon, stars,
## leaves and snow all follow the clock as they always do.
##
## As the spin nears TIME_MIN the light starts to shimmer (`celestial.shimmer`,
## a small wobble of the key light), so the player feels there is more, and it
## eases down once time is really running.
##
## When the spin has run down, the world stays at the time it reached. The
## pins (scripts/mood_look.gd) are re-pinned to it, not released: a held hour
## is pinned again at the new hour (as letting go of the old sun drag did),
## and a pinned season is retargeted to the quarter the spin landed in. A
## clock that was turning its own day keeps turning.

## The turn's speed (rad/s) below which time is untouched: about 0.5 of a
## turn a second, faster than a deliberate push, slower than a flick.
const TIME_MIN := 3.0
## The shimmer begins here (rad/s).
const CUE_FROM := 1.8
## Hours a second grow as the square of the excess (rad/s over TIME_MIN):
## HOURS_GAIN*excess^2. Just past the threshold it is a few hours a second, a
## hard flick (6 rad/s) winds about a day in all, and the turn's fastest spin
## (12 rad/s) peaks at about 20 days a second and winds nearly three weeks, so
## the seasons roll. The spin runs down by itself (world_turn.gd SPIN_DRAG),
## and each bat adds to it.
const HOURS_GAIN := 6.0
## Real seconds of living weather each world hour is worth: a day passes as
## about 48 s of drift, so the sky changes every few days.
const WEATHER_SECONDS_PER_HOUR := 2.0
## The most weather seconds one frame may be given.
const WEATHER_MAX := 40.0
## Under this many rad/s (once time has been wound) the spin is at rest.
const REST := 0.9
## The shimmer's own strength once time is running (of its peak).
const SHIMMER_RUNNING := 0.5

var scene: Node3D
## World hours wound since the last rest, and whether time is winding now.
var wound := 0.0
var winding := false
## Hours a second the spin winds now.
var hours_per_second := 0.0
var _resting := true

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "SpinTime"

## Hours a second a turning speed (rad/s, sign ignored) winds the clock.
static func hours_for(speed: float) -> float:
	var excess := absf(speed)-TIME_MIN
	return 0.0 if excess <= 0.0 else HOURS_GAIN*excess*excess

## The shimmer (0..1) that a turning speed makes.
static func shimmer_for(speed: float) -> float:
	var s := absf(speed)
	return smoothstep(CUE_FROM,TIME_MIN,s)*(1.0-(1.0-SHIMMER_RUNNING)*smoothstep(TIME_MIN,TIME_MIN+3.0,s))

func _process(delta: float) -> void:
	delta = minf(delta,0.1)
	var rig: Node = scene.get("camera_rig")
	var clock: WorldClock = scene.get("world_clock")
	if rig == null or clock == null or delta <= 0.0: return
	var speed := absf(float(rig.turn.own_rate))
	# A shake is not a spin: the globe has the rim.
	var globe: Node = scene.get("snow_globe")
	if globe != null and globe.decided: speed = 0.0
	# A turn pushed with Shift winds no time, however fast.
	if bool(rig.turn.get("timeless")): speed = 0.0
	var sky: Object = scene.get("_celestial")
	if sky != null: sky.shimmer = shimmer_for(speed)
	hours_per_second = hours_for(speed)
	if hours_per_second > 0.0:
		_wind(clock,hours_per_second*delta)
	elif winding and speed < REST:
		_rest(clock)

## Wind the clock on by `hours`, its season and the weather with it.
func _wind(clock: WorldClock, hours: float) -> void:
	if not winding:
		winding = true
		var mood: Node = scene.get("mood_look")
		if mood != null: mood.finish_fade()
	var total := float(clock.day)*WorldClock.HOURS_PER_DAY+clock.hour+hours
	clock.set_time(int(floor(total/WorldClock.HOURS_PER_DAY)),fposmod(total,WorldClock.HOURS_PER_DAY))
	wound += hours
	# A held season moves with the calendar; the calendar's own already does.
	if clock.season_override >= 0.0:
		clock.season_override = fposmod(clock.season_override+hours/WorldClock.HOURS_PER_DAY/float(clock.year_days),1.0)
	# The shown season follows at once: no glide behind a spinning world.
	scene._season_shown = clock.season
	var living: RefCounted = scene.get("living_weather")
	if living != null: living.advance(minf(hours*WEATHER_SECONDS_PER_HOUR,WEATHER_MAX),false)

## The spin has run down: keep the pins in step with where time stopped.
func _rest(clock: WorldClock) -> void:
	winding = false
	var mood: Node = scene.get("mood_look")
	if mood == null: return
	mood.finish_fade()
	if not clock.running: mood.pin_hour(clock.phase)
	if mood.pins.has("season"):
		mood.pins["season"] = WorldClock.SEASON_NAMES[clampi(int(fposmod(clock.season,1.0)*4.0),0,3)]
