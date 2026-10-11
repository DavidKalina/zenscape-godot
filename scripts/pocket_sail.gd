extends RefCounted
## The pocket sail: a little cloth wing held overhead, popped out with Jump
## in mid-air (as Wind Waker's Deku Leaf, or the paraglider in Breath of
## the Wild). Not a hang glider and not a parachute: it is for coasting.
## Knocked off an island, thrown high and far enough, the pilot coasts back
## down onto it; too low, or too far, he comes down short and climbs back.
## Height is what it spends, and nothing gives it back for good.
##
## Opened (`deploy`), it kicks him up a little (KICK, once an airtime: the
## first open since he last stood, hung or swam; folding and opening again
## kicks no more), then glides him on at PACE across, sinking at SINK (about
## 3.7 m on for every metre down in still air). Falling faster than it
## sinks when it opens, it catches the fall at CATCH m/s², so opened early
## it saves him and opened late it barely slows him; some of the fall
## (SWOOP of the speed over SINK) goes into the pace, so folding to dive
## and opening again carries him further on, never higher. Pace he brings
## (a long jump's, a slide hop's, a twirl's) is kept and bleeds away at
## BLEED, never over TOP.
##
## Steered (`steer`: the way asked against the way it flies) it turns at
## TURN radians a second; held back (`push` -1: crouch on foot, back or
## Brake out of the plane) it brakes to PACE_SLOW and floats at SINK_SLOW,
## shorter but slower down; pushed on (`push` 1, out of the plane only) it
## dives to PACE_FAST, sinking SINK_FAST.
##
## The air (`air`: {wind, thermal}, as the glide and the skydive read it):
## the wind across carries it (WIND of it, eased in over WIND_EASE). The
## wind's rise (a gust's, LIFT of it) eases its sink or lifts it a little,
## up to RISE_MOST, and never over the airtime's highest point (`peak`, the
## highest the feet were with it folded) by more than CEILING: a gust can
## slow the spend of height, but never climbs him back up. A thermal (rising
## air: THERMAL m/s for each of its units) is the one thing that does: in
## its column the sail climbs, up to THERMAL_MOST m/s, taken up at
## THERMAL_TAKE m/s², with no ceiling (`riding` while it does). Thermals are
## placed and rare, so height stays what it spends everywhere else.
##
## Plain state and maths, as the motor and the glide are, so tests can step
## it. The motor (scripts/pilot_motor.gd) and the skydive
## (scripts/sky_dive.gd) each fly it. Any scene with the game's air
## (studies/atmosphere.gd) gives the motor its wind with `atmosphere_air`
## (the kit isles do, studies/kit_isle.gd; the old plate's walker reads the
## glide's own, scripts/wanderer_eye.gd `_walker_air`).

## Across and down at cruise (m/s): about 3.7 m on for each metre down.
const PACE := 5.5
const SINK := 1.5
## Held back: slower across, floating; pushed on (out of the plane): faster
## and steeper.
const PACE_SLOW := 3.2
const SINK_SLOW := 1.2
const PACE_FAST := 7.5
const SINK_FAST := 2.4
## The fastest across it ever goes (m/s), how fast pace over its own bleeds
## away (m/s²), and how fast it takes up a slower pace asked (s).
const TOP := 10.0
const BLEED := 1.5
const EASE := 0.6
## Its turn at full stick (radians a second), and the angle off the way
## asked (radians) at which the turn is full.
const TURN := 2.4
const TURN_FULL := 0.5
## The kick opening it (m/s up, once an airtime), and how fast a rise is
## spent (m/s²): from a jump's top, about 0.3 m up.
const KICK := 3.5
const RISE_GRAVITY := 20.0
## How fast a fall faster than its sink is caught (m/s²), and how fast it
## takes up a gentler sink, or a lift, otherwise (m/s²). From the motor's
## fastest fall (18 m/s) the catch takes about 1.4 s and 13 m.
const CATCH := 12.0
const SETTLE := 3.0
## The share of the fall over SINK put into its pace as it opens.
const SWOOP := 0.3
## The wind: the share of it across that carries the sail, and how fast that
## follows (s); the share of the wind's rise that lifts it, a thermal's lift
## (m/s for each unit), the fastest it rises, and how far over the
## airtime's peak it may ever go (m).
const WIND := 0.8
const WIND_EASE := 0.5
const LIFT := 0.5
const THERMAL := 2.0
const RISE_MOST := 0.8
const CEILING := 1.0
## In a thermal: the fastest it climbs (m/s), and how fast it takes up the
## climb (m/s²): from its sink to a full climb in under a second.
const THERMAL_MOST := 5.0
const THERMAL_TAKE := 6.0
## The thermal's lift (m/s, after the sink) over which it counts as ridden.
const RIDING := 0.3
## Seconds after folding before it opens again; the least room under the
## feet it opens with (m), plus the fall's speed for this many seconds. So
## it never opens over flat ground from a jump (the pump tops out at
## 1.5 m), nor in a long jump's chain with Jump mashed for the landing (a
## press that close is the jump buffered for the touch): it is for drops,
## off edges and knocked away.
const REOPEN := 0.25
const CLEAR := 1.6
const CLEAR_AHEAD := 0.2

## The feel, this sail's own: each starts as its constant above; a study may
## turn them live.
var pace := PACE
var sink := SINK
var top := TOP
var bleed := BLEED
var turn := TURN
var kick := KICK
var catch := CATCH
var swoop := SWOOP
var wind_share := WIND
var lift := LIFT
var thermal := THERMAL
var rise_most := RISE_MOST
var ceiling := CEILING
var thermal_most := THERMAL_MOST
var thermal_take := THERMAL_TAKE
var reopen := REOPEN

## Open now; this airtime's kick spent; the way it flies (the motor's
## facing convention) and its own pace along it; the wind's carry across
## (x, z); the airtime's highest point with it folded; seconds since it
## folded; the air's lift now (m/s, for the numbers); climbing in a
## thermal now (for the cues: the wing's billow, the camera, the numbers).
var open := false
var kicked := false
var heading := 0.0
var speed := 0.0
var drift := Vector2.ZERO
var peak := -INF
var since_fold := 99.0
var lift_now := 0.0
var riding := false

## Stood, hung or afloat: packed, the kick ready for the next airtime.
func rest() -> void:
	open = false
	kicked = false
	peak = -INF
	since_fold = 99.0
	drift = Vector2.ZERO
	lift_now = 0.0
	riding = false

## Each step in the air with it folded: the highest point kept, the fold's
## seconds counted.
func track(y: float, delta: float) -> void:
	peak = maxf(peak,y)
	since_fold += delta

## Whether it opens now, `clear` metres over the ground, rising (or, below
## 0, falling) at `rise` m/s.
func can_open(clear: float, rise: float) -> bool:
	if open or since_fold < reopen: return false
	return clear > CLEAR+maxf(-rise,0.0)*CLEAR_AHEAD

## Opened, moving at `velocity`, facing `facing`: the velocity with the
## kick (the first open this airtime), its pace taken from the way it goes.
func deploy(velocity: Vector3, facing: float, y := -INF) -> Vector3:
	open = true
	peak = maxf(peak,y)
	var across := Vector2(velocity.x,velocity.z)
	heading = atan2(-across.x,-across.y) if across.length() > 0.5 else facing
	speed = across.length()
	var falling := -velocity.y
	if falling > sink: speed += swoop*(falling-sink)
	speed = minf(speed,top)
	drift = Vector2.ZERO
	lift_now = 0.0
	riding = false
	if not kicked:
		velocity.y = maxf(velocity.y,minf(velocity.y+kick,kick))
		kicked = true
	return Vector3(-sin(heading)*speed,velocity.y,-cos(heading)*speed)

## Folded: falling again, the kick not given back.
func fold() -> void:
	open = false
	riding = false
	since_fold = 0.0

## The turn (-1 right to 1 left) towards the way asked, `want` (x, z, at
## most 1 long), flying along `heading`.
static func steer(heading: float, want: Vector2) -> float:
	if want.length() < 0.15: return 0.0
	var off := angle_difference(heading,atan2(-want.x,-want.y))
	return clampf(off/TURN_FULL,-1.0,1.0)*minf(want.length()*1.25,1.0)

## One step open: `velocity` now, the feet at `y`, `steering` -1 right to
## 1 left, `push` -1 held back to 1 pushed on, `air` the air there
## ({wind, thermal}). Returns the new velocity.
func step(delta: float, velocity: Vector3, y: float, steering: float, push: float, air := {}) -> Vector3:
	heading = wrapf(heading+clampf(steering,-1.0,1.0)*turn*delta,-PI,PI)
	push = clampf(push,-1.0,1.0)
	var want_pace := pace
	var want_sink := sink
	if push < 0.0:
		want_pace = lerpf(pace,PACE_SLOW,-push)
		want_sink = lerpf(sink,SINK_SLOW,-push)
	elif push > 0.0:
		want_pace = lerpf(pace,PACE_FAST,push)
		want_sink = lerpf(sink,SINK_FAST,push)
	# Pace it brought bleeds away; a brake, or a pace under, eases.
	if speed > want_pace and push >= 0.0: speed = move_toward(speed,want_pace,bleed*delta)
	else: speed = lerpf(speed,want_pace,1.0-exp(-delta/EASE))
	speed = minf(speed,top)
	var wind: Vector3 = air.get("wind",Vector3.ZERO)
	drift = drift.lerp(Vector2(wind.x,wind.z)*wind_share,1.0-exp(-delta/WIND_EASE))
	var gust := maxf(wind.y,0.0)*lift
	var warm := maxf(float(air.get("thermal",0.0)),0.0)*thermal
	lift_now = gust+warm
	var target := minf(-want_sink+gust,rise_most)
	# A gust never lifts him back up over the airtime's peak (nor, over it,
	# drops him faster than his sink).
	if is_finite(peak): target = minf(target,maxf(peak+ceiling-y,-want_sink))
	# A thermal climbs him, with no ceiling: the height it gives is his to
	# spend (the peak goes up with him).
	var climb := minf(-want_sink+lift_now,thermal_most)
	riding = warm > 0.0 and climb > RIDING
	if warm > 0.0: target = maxf(target,climb)
	if riding: peak = maxf(peak,y)
	var rise := velocity.y
	if rise > target: rise = maxf(target,rise-RISE_GRAVITY*delta)
	elif riding: rise = minf(target,rise+maxf(thermal_take,catch if rise < -want_sink-1.0 else SETTLE)*delta)
	else: rise = minf(target,rise+(catch if rise < -want_sink-1.0 else SETTLE)*delta)
	return Vector3(-sin(heading)*speed+drift.x,rise,-cos(heading)*speed+drift.y)

## The game's air (studies/atmosphere.gd) at `point`: its breeze across
## (BREEZE of it), and its gust fronts' push and lift by their lean
## (GUST_PUSH, GUST_LIFT m/s at a full lean, as the glide reads them,
## scripts/wanderer_eye.gd `_fly_air`). {wind, thermal}; none, still air.
const BREEZE := 0.5
const GUST_PUSH := 5.0
const GUST_LIFT := 9.0
static func atmosphere_air(atmosphere: Node, point: Vector3) -> Dictionary:
	if atmosphere == null or not is_instance_valid(atmosphere): return {}
	var angle: float = atmosphere.get("_air_angle")
	var way := Vector2(cos(angle),sin(angle))
	var breeze: float = (1.6+1.9*float(atmosphere.get("_air_strength")))*BREEZE
	var wind := Vector3(way.x,0.0,way.y)*breeze
	var fronts: RefCounted = atmosphere.get("fronts")
	if fronts != null:
		var lean: float = fronts.lean_at(Vector2(point.x,point.z),way)
		if lean > 0.0: wind += Vector3(way.x*GUST_PUSH,GUST_LIFT,way.y*GUST_PUSH)*lean
	return {"wind":wind,"thermal":0.0}

## Across the ground per metre down, in still air at cruise.
func ratio() -> float:
	return pace/sink
