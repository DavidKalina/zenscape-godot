extends Node
## Spin is time (docs/scenic/modeless.md, docs/scenic/hand-world.md "Verbs on
## the diorama"). Under `--modeless` the speed the world turns at (the lazy
## Susan, scripts/world_turn.gd `own_rate`) winds the world clock. A normal
## turn leaves time alone. Past TIME_MIN a spin winds time on, hours a second
## at first and days a second for the fastest spin the turn allows.
##
## The spin winds a target; the world travels to it over time. What the spin
## has wound and the world has not yet shown is `ahead`. Each frame the world
## takes some of it by its own means: the clock's hour and day move, the
## season override (when one is held) moves with the calendar, and living
## weather is given the real time those hours would have taken, so the sky
## changes because time passed. Nothing is faked; it is only unhurried:
## - The sun travels the hours at up to SKY_HOURS_MAX hours a second. It
##   gathers speed (SKY_ACCEL) and settles onto the target (SKY_RESPONSE), so
##   a flick sweeps the sun across the sky, keeps gliding after the spin has
##   stopped, and comes to rest.
## - Whole days beyond that are not shown as days and nights. While more than
##   SKIP_ABOVE hours are ahead, a day at a time is taken off and the calendar
##   and the season roll through it at SKIP_MIN_DAYS to SKIP_MAX_DAYS days a
##   second, with the sun where it is, so a three-week spin passes through a
##   day or two of sky rather than strobing twenty nights.
## - The season on screen (`_season_shown`, the plants' `zs_season`) moves
##   continuously through the skipped days, not in day steps.
## - Weather changes ease in over real seconds as they always do (living
##   weather's RESPONSE), and the extra weather time the spin hands over does
##   not hurry that ease.
##
## As the spin nears TIME_MIN the light starts to shimmer (`celestial.shimmer`,
## a small wobble of the key light), so the player feels there is more, and it
## eases down once time is really running.
##
## Anything else that moves the clock while the world is gliding (the void's
## snap, scripts/void_snap.gd, a mood fade, N's skip) wins: the glide is
## dropped where it stands and the rest of the wound time is let go.
##
## When the spin has run down and the world has arrived, it stays at the time
## it reached. The pins (scripts/mood_look.gd) are re-pinned to it, not
## released: a held hour is pinned again at the new hour (as letting go of the
## old sun drag did), and a pinned season is retargeted to the quarter the
## world landed in. A clock that was turning its own day keeps turning.

## The turn's speed (rad/s) below which time is untouched: about a third of a
## turn a second, faster than a deliberate push, slower than a flick. Probed
## headless at 60 fps on the near rim: pushes over 0.4 s or more reach 0.8 to
## 1.4 rad/s and wind nothing; a brisk trackpad flick (150 to 300 px in 0.15
## to 0.2 s) lets go at 3.8 to 4.7 rad/s and winds 6 to 22 hours; a hard one
## (250 px in 0.12 s) about two days. It was 3.0, which only the hardest
## flicks reached. The speed is the spin itself once let go (see _process).
const TIME_MIN := 2.2
## The shimmer begins here (rad/s).
const CUE_FROM := 1.3
## Hours a second grow as the square of the excess (rad/s over TIME_MIN):
## HOURS_GAIN*excess^2. Just past the threshold it is a few hours a second, a
## hard flick (6 rad/s) winds about two days in all, and the turn's fastest spin
## (12 rad/s) peaks at about 20 days a second (as at the old 3.0 and 6) and
## winds nearly three weeks, so the seasons roll. The spin runs down by itself (world_turn.gd SPIN_DRAG),
## and each bat adds to it. This is what is wound, not how fast it is shown.
const HOURS_GAIN := 5.0
## The fastest the sun travels while the world catches up, in world hours a
## real second: 6 is a whole day and night in four seconds.
const SKY_HOURS_MAX := 6.0
## How quickly the sun gathers speed, in hours a second per second: 8 reaches
## full speed in about three quarters of a second.
const SKY_ACCEL := 8.0
## How the sun settles: its speed is at most this share of the hours still
## ahead, per second, so the last hours ease in (1.5: most of the last few
## hours in about two seconds).
const SKY_RESPONSE := 1.5
## Hours ahead under which the world has arrived (about a minute of world time).
const ARRIVE := 0.02
## While more than this many hours are ahead, whole days are rolled through
## on the calendar instead of shown as days and nights.
const SKIP_ABOVE := 30.0
## Days a second the calendar rolls through skipped days: DAY_RESPONSE times
## the days still ahead, held between SKIP_MIN_DAYS and SKIP_MAX_DAYS. At 4 a
## second a three-week spin takes about five seconds to roll out, and a
## season (a quarter of the 28-day year) about two.
const DAY_RESPONSE := 0.6
const SKIP_MIN_DAYS := 1.5
const SKIP_MAX_DAYS := 4.0
## Real seconds of living weather each world hour is worth: a day passes as
## about 48 s of drift, so the sky changes every few days.
const WEATHER_SECONDS_PER_HOUR := 2.0
## The most weather seconds one frame may be given.
const WEATHER_MAX := 40.0
## Under this many rad/s (once time has been wound) the spin is at rest.
const REST := 0.9
## The shimmer's own strength once time is running (of its peak).
const SHIMMER_RUNNING := 0.5
## Hours the clock may move on its own in a frame beyond its own running
## before the move counts as someone else's (a snap, a fade).
const OUTSIDE := 0.01

var scene: Node3D
## World hours wound since the last rest, and whether time is winding (the
## spin is fast, or the world is still travelling to what it wound).
var wound := 0.0
var winding := false
## Hours a second the spin winds now.
var hours_per_second := 0.0
## Hours wound that the world has not reached yet (days being rolled through
## not included).
var ahead := 0.0
## The sun's travel now, world hours a real second.
var sky_rate := 0.0
## Of the day being rolled through, the share still to roll (0 when none).
var _skip_left := 0.0
## The clock's hours when this node last left it, to notice other movers.
var _mark := -1.0

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

## Whether the world is still travelling to the time the spin wound.
func gliding() -> bool:
	return ahead > 0.0 or _skip_left > 0.0

## Let go of the rest of the wound time where the world stands.
func drop_glide() -> void:
	ahead = 0.0
	sky_rate = 0.0
	_skip_left = 0.0

func _process(delta: float) -> void:
	var raw := delta
	delta = minf(delta,0.1)
	var rig: Node = scene.get("camera_rig")
	var clock: WorldClock = scene.get("world_clock")
	if rig == null or clock == null or delta <= 0.0: return
	_notice_outside(clock,raw)
	# The turn's own speed, and once let go the spin itself: own_rate trails a
	# flick's spin by its smoothing, which would eat the flick's peak.
	var speed := maxf(absf(float(rig.turn.own_rate)),absf(float(rig.turn.spin)))
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
	if gliding():
		_glide(clock,delta)
	elif winding and speed < REST:
		_rest(clock)
	_mark = _total(clock)

static func _total(clock: WorldClock) -> float:
	return float(clock.day)*WorldClock.HOURS_PER_DAY+clock.hour

## Something other than the glide moved the clock since last frame (the snap,
## a mood fade, N's skip): it wins, and the glide is dropped.
func _notice_outside(clock: WorldClock, delta: float) -> void:
	if _mark < 0.0 or not gliding(): return
	var own := 0.0
	if clock.running and clock.day_length > 0.0:
		own = minf(delta,WorldClock.MAX_DELTA)*maxf(clock.speed,0.0)*WorldClock.HOURS_PER_DAY/clock.day_length
	if clock.target_hour >= 0.0 or absf(_total(clock)-_mark) > own+OUTSIDE:
		drop_glide()

## Wind `hours` more onto the time the world is travelling to.
func _wind(_clock: WorldClock, hours: float) -> void:
	if not winding:
		winding = true
		var mood: Node = scene.get("mood_look")
		if mood != null: mood.finish_fade()
	ahead += hours
	wound += hours

## Travel part of the way to the wound time: the sun eases along the hours,
## and whole days beyond SKIP_ABOVE roll by on the calendar.
func _glide(clock: WorldClock, delta: float) -> void:
	var shown := 0.0
	# The sun: gather speed up to the cap, settle as the hours run out.
	var goal := minf(SKY_HOURS_MAX,ahead*SKY_RESPONSE)
	sky_rate = minf(goal,sky_rate+SKY_ACCEL*delta) if goal > sky_rate else goal
	var step := minf(ahead,sky_rate*delta)
	if ahead-step < ARRIVE and _skip_left <= 0.0 and ahead < SKIP_ABOVE:
		step = ahead
	ahead -= step
	if ahead <= 0.0:
		ahead = 0.0
		sky_rate = 0.0
	shown += step
	var total := _total(clock)+step
	var new_day := int(floor(total/WorldClock.HOURS_PER_DAY))
	var new_hour := fposmod(total,WorldClock.HOURS_PER_DAY)
	# Whole days: the calendar moves at the start of each, the season shown
	# moves through it.
	var days := 0.0
	if _skip_left > 0.0 or ahead >= SKIP_ABOVE:
		var rate := clampf(DAY_RESPONSE*(ahead/WorldClock.HOURS_PER_DAY+_skip_left),SKIP_MIN_DAYS,SKIP_MAX_DAYS)
		var budget := rate*delta
		while budget > 0.0:
			if _skip_left <= 0.0:
				if ahead < SKIP_ABOVE: break
				ahead -= WorldClock.HOURS_PER_DAY
				_skip_left = 1.0
				new_day += 1
			var take := minf(budget,_skip_left)
			_skip_left -= take
			budget -= take
			days += take
			if _skip_left < 1e-6: _skip_left = 0.0
	shown += days*WorldClock.HOURS_PER_DAY
	clock.set_time(new_day,new_hour)
	# A held season moves with the calendar, smoothly through rolled days; the
	# calendar's own already moves, and the shown season lags it through the
	# day being rolled.
	if clock.season_override >= 0.0:
		clock.season_override = fposmod(clock.season_override+shown/WorldClock.HOURS_PER_DAY/float(clock.year_days),1.0)
		scene._season_shown = clock.season
	else:
		scene._season_shown = fposmod(clock.season-_skip_left/float(clock.year_days),1.0)
	var living: RefCounted = scene.get("living_weather")
	if living != null and shown > 0.0:
		living.advance(minf(shown*WEATHER_SECONDS_PER_HOUR,WEATHER_MAX),false,0.0)

## The spin has run down: keep the pins in step with where time stopped.
func _rest(clock: WorldClock) -> void:
	winding = false
	drop_glide()
	var mood: Node = scene.get("mood_look")
	if mood == null: return
	mood.finish_fade()
	if not clock.running: mood.pin_hour(clock.phase)
	if mood.pins.has("season"):
		mood.pins["season"] = WorldClock.SEASON_NAMES[clampi(int(fposmod(clock.season,1.0)*4.0),0,3)]
