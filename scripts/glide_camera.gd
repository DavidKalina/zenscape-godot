extends RefCounted
## The glide's camera (scripts/sky_glide.gd): a chase view behind the glider
## that breathes with the flight. At a cruise it trails a few metres back
## and above; at the float at the top of an arc it swings out wide and high,
## so the island hangs in the view; in a dive it pulls in close behind the
## shoulders, nearly first person. It hangs on a spring off the glider, so
## in a turn it swings out round the outside and catches up after, and it
## leans a little with the bank, never far. Its view widens with speed and
## kicks open on entering a jet stream.
##
## Held, the free look turns it round the glider without steering, to look
## at an island while circling it; let go, it swings back behind, after
## `linger` seconds without a turn (none for the glide; the plane's pan holds
## a while, for the view). It never
## goes inside an island: with `solid` it stops short of rock and ground
## (framed, with `solid` or `sight`, it swings round or lifts over them
## first, DODGES, and only then draws in, never nearer than `near`; drawn
## in, it eases back out).
## `first_person` puts the eye in the glider's head, as before.
##
## `framed` (the game's plane, docs/design/flight-camera.md): the plane
## always stays inside the safe part of the view (SAFE to EDGE of the
## half-screen; `aspect`, its `extent` in m), the view leads a little into
## a turn (LEAD_TIME, LEAD_MAX), and speed is read against the plane's
## `cruise`: the view widens from FOV_SHARE.x to FOV_SHARE.y times it and
## the eye eases back up to PULL_BACK more, rather than tucking in.
##
## A sequence can ask for a framing of its own (`cine`): the plane's landing
## (scripts/plane_landing.gd) swings it wider on final and round to a low
## side view at the touch, eased over EASE_CINE, on top of the free look.
##
## Like the glide, it is plain state and maths, so tests can step it.

## Metres back from the glider and up over it: at a cruise, at the float,
## and tucked in a dive.
const BACK := Vector3(5.2,9.0,1.7)
const UP := Vector3(1.4,3.0,0.45)
## How far ahead it looks (metres, plus seconds of speed), and how high.
const AHEAD := 2.5
const AHEAD_SPEED := 0.12
const LOOK_UP := 0.35
## How fast its idea of the flight's way follows the glide (seconds), and
## how stiff the spring it hangs on is (radians a second).
const EASE_WAY := 0.3
const SPRING := 4.5
## How fast it swings out at the float and back in after (seconds).
const FLOAT_IN := 0.15
const FLOAT_OUT := 1.2
## How much of the glider's bank it leans with, the most it ever leans
## (radians, 12 degrees; it eases into that softly rather than stopping hard), and how
## fast it follows. Flying straight the bank comes off, and it settles level.
const ROLL := 0.4
const ROLL_MAX := 0.21
const EASE_ROLL := 0.25
## The field of view (degrees): at a cruise, the most speed widens it by,
## and in first person. It widens between the airspeeds FOV_SPEED (m/s),
## opening fast at first and gently near the top, so a dive feels it early
## and a cruise's small swells don't breathe it. Entering a jet stream kicks it open a little more
## for a moment (JET_KICK, gone over JET_SETTLE seconds); at the float it
## narrows by FOV_FLOAT. It follows over EASE_FOV seconds.
const FOV := 70.0
const FOV_FAST := 10.0
const FOV_FIRST := 78.0
const FOV_FIRST_FAST := 26.0
const FOV_SPEED := Vector2(8.0,40.0)
const JET_KICK := 5.0
const JET_SETTLE := 0.8
const FOV_FLOAT := 4.0
const EASE_FOV := 0.3
## Free look: the furthest it turns up and down (radians), and how fast it
## swings back once let go (seconds).
const FREE_PITCH := Vector2(-0.9,1.2)
const EASE_BACK := 0.45
## It keeps this far from rock and ground, and checks the way out in this
## many steps.
const KEEP := 0.45
const PROBES := 12
## How fast it eases to a sequence's framing (seconds).
const EASE_CINE := 0.9
## Blocked by rock: the swings round (radians, + left of behind) and lifts
## (radians up; a drop under an island's edge) it tries before drawing in,
## nearest first; how fast it
## eases into one and back out of it (seconds); how fast it eases back
## out once drawn in (seconds).
const DODGES := [Vector2(0.0,0.0),Vector2(0.0,0.3),Vector2(0.35,0.0),Vector2(-0.35,0.0),Vector2(0.35,0.3),Vector2(-0.35,0.3),Vector2(0.0,0.6),Vector2(0.7,0.25),Vector2(-0.7,0.25),Vector2(0.0,0.95),Vector2(0.0,-0.25),Vector2(0.0,-0.45),Vector2(0.7,-0.3),Vector2(-0.7,-0.3),Vector2(1.2,0.1),Vector2(-1.2,0.1),Vector2(0.0,1.4),Vector2(0.0,1.9)]
const EASE_DODGE := 0.1
const EASE_DODGE_BACK := 0.6
const EASE_OUT := 0.35
## The highest a lift (or lowest a drop) takes the eye over the plane
## (radians from level).
const LIFT_MOST := 1.25
## Framed (the game's plane). The least distance rock draws it in to, in
## the plane's spans (the host sets `near`, studies/kit_isle.gd: WorldScale
## TOY_SPAN times the plane's size times this): the whole plane well
## inside the view.
const NEAR_SPANS := 1.7
## The safe part of the view, as shares of the half-screen: past SAFE the
## plane's edge is eased back, and it never passes EDGE.
const SAFE := 0.62
const EDGE := 0.84
## Leading into a turn: the look ahead swung on by the turn's rate times
## LEAD_TIME (s), at most LEAD_MAX (radians); the rate eased over EASE_LEAD.
## None while a sequence frames it (`cine`, the landing's).
const LEAD_TIME := 0.3
const LEAD_MAX := 0.3
const EASE_LEAD := 0.25
## Speed against the plane's cruise: the view widens (FOV_FAST) from
## FOV_SHARE.x to FOV_SHARE.y times the cruise (the old 8 to 40 m/s round
## the toy's 14 m/s cruise, so at `--plane-speed=1` it is as it was), and
## the eye eases back by up to PULL_BACK more from PULL_SHARE.x to
## PULL_SHARE.y times the cruise.
const FOV_SHARE := Vector2(0.57,2.86)
const PULL_BACK := 0.12
const PULL_SHARE := Vector2(1.05,1.65)
## The old toy's cruise, the share's base when no cruise is given.
const TOY_CRUISE: float = preload("res://scripts/sky_plane.gd").CRUISE_SPEED

## The camera's eye and the point it looks at (global), its roll and its
## field of view (degrees).
var eye := Vector3.ZERO
var look := Vector3.ZERO
var roll := 0.0
var fov := FOV
var first_person := false
## The free look's turn (radians: round the glider, up and down), and
## whether it is held.
var free := Vector2.ZERO
var free_held := false
## Seconds the free look holds after its last turn before it swings back,
## and seconds since that turn.
var linger := 0.0
var _since_turn := INF
## The framing a sequence asks for: Vector3(how far round the plane it
## swings, radians, right positive; how far it tips down towards level,
## radians; how much further back and up it stands, a share), and where
## it has eased to.
var cine := Vector3.ZERO
var _cine := Vector3.ZERO
## A plane drawn bigger on its wheels (scripts/plane_ground_scale.gd): its
## distance and height times `size`, and the middle it frames lifted by
## `lift`. 1 and none in flight.
var size := 1.0
var lift := Vector3.ZERO
## Launch-flag trials: `--cam-distance=<x>` times the chase's back distance
## and height (on top of `size`), `--cam-fov=<deg>` its base view, and
## `--cam-speed-fov=<x>` times how much speed widens it. 1, FOV, 1 by default.
var distance_scale := _flag("--cam-distance=",1.0)
var base_fov := _flag("--cam-fov=",FOV)
var speed_fov := _flag("--cam-speed-fov=",1.0)
## How close in it is now (0 cruise, 1 tucked) and how wide (the float).
var tuck := 0.0
var float_out := 0.0
var _way := Vector3.FORWARD
var _offset := Vector3.ZERO
var _offset_v := Vector3.ZERO
## The jet as it was felt a moment ago: the kick is how far the jet now
## runs ahead of it.
var _jet_felt := 0.0
## For instruments (tools/flight_frame.gd): the spring's goal offset this
## frame and whether rock turned or stopped the eye short.
var goal := Vector3.ZERO
var clipped := false
## Rock by ray: Callable(from: Vector3, to: Vector3) -> float, the share of
## the way clear (1 clear). Used rather than `solid`'s probes, if given.
var sight := Callable()
## The least it comes in to the glider when rock is in the way (m).
var near := 0.0
## The game's plane (see the top): framed, its cruise (m/s), the view's
## width over height, and the plane's reach from its middle (m).
var framed := false
var cruise := 0.0
var aspect := 16.0/9.0
var extent := 0.0
## The swing round and lift it holds off rock, how far out it is now
## (INF: all the way), the turn's eased rate (radians a second) and the
## heading it was on.
var _dodge := Vector2.ZERO
var _reach := INF
var _yaw_rate := 0.0
var _heading := NAN

## Starts at `from` (the eye it takes over from) behind a glide, its view
## `view` degrees wide (the view it takes over), easing from there.
func reset(glide: RefCounted, from: Vector3, view := FOV) -> void:
	_way = glide.forward()
	_offset = from-glide.position
	_offset_v = Vector3.ZERO
	free = Vector2.ZERO
	free_held = false
	_since_turn = INF
	cine = Vector3.ZERO
	_cine = Vector3.ZERO
	tuck = 0.0
	float_out = 0.0
	roll = _lean(float(glide.bank))
	fov = view
	_jet_felt = float(glide.in_jet)
	_dodge = Vector2.ZERO
	_reach = INF
	_yaw_rate = 0.0
	_heading = NAN
	eye = from
	look = glide.position+_way*AHEAD

## Turns the free look by `by` radians (round, up).
func turn(by: Vector2) -> void:
	free.x = wrapf(free.x+by.x,-PI,PI)
	free.y = clampf(free.y+by.y,FREE_PITCH.x,FREE_PITCH.y)
	_since_turn = 0.0

## One frame behind `glide`, `dive` held 0..1. `solid`, if given, is a
## Callable(Vector3) -> bool: true inside rock or ground.
func step(delta: float, glide: RefCounted, dive: float, solid := Callable()) -> void:
	var at: Vector3 = glide.position+lift
	_widen(delta,glide)
	if first_person:
		_way = glide.forward()
		_offset = Vector3.ZERO
		_offset_v = Vector3.ZERO
		eye = at
		look = at+_way*AHEAD
		roll = -glide.bank
		return
	# The way it flies: half where it points, half where it goes.
	var moving: Vector3 = glide.velocity
	var way: Vector3 = glide.forward()
	if moving.length() > 0.5: way = (way+moving.normalized()).normalized()
	_way = _way.slerp(way,_ease(EASE_WAY,delta)).normalized()
	# Fast, the glide tucks in; the framed plane eases back instead.
	var fast := 0.0 if framed else clampf((float(glide.speed)-16.0)/14.0,0.0,1.0)
	tuck = lerpf(tuck,maxf(clampf(dive,0.0,1.0),fast*0.7),_ease(0.4,delta))
	# The float swings it out quickly and it lingers out there through the
	# tip-over.
	var hang := float(glide.hang)
	float_out = lerpf(float_out,hang,_ease(FLOAT_IN if hang > float_out else FLOAT_OUT,delta))
	_cine = _cine.lerp(cine,_ease(EASE_CINE,delta))
	var pull := 1.0+PULL_BACK*smoothstep(PULL_SHARE.x,PULL_SHARE.y,_pace(glide)) if framed else 1.0
	var back := lerpf(lerpf(BACK.x,BACK.y,float_out),BACK.z,tuck)*(1.0+_cine.z)*size*distance_scale*pull
	var up := lerpf(lerpf(UP.x,UP.y,float_out),UP.z,tuck)*(1.0+_cine.z*0.5)*size*distance_scale
	_since_turn += delta
	if not free_held and _since_turn >= linger: free = free.lerp(Vector2.ZERO,_ease(EASE_BACK,delta))
	var swing := free+Vector2(_cine.x,_cine.y)
	# Behind along the flat of the way, lifted by its climb or dive, then
	# turned by the free look.
	var flat := Vector3(_way.x,0.0,_way.z)
	if flat.length() < 0.05: flat = Vector3(-sin(float(glide.heading)),0.0,-cos(float(glide.heading)))
	flat = flat.normalized()
	var behind := (-_way*back+Vector3.UP*up).rotated(Vector3.UP,swing.x)
	var side := flat.cross(Vector3.UP).rotated(Vector3.UP,swing.x)
	behind = behind.rotated(side.normalized(),swing.y)
	goal = behind
	# The spring it hangs on: critically damped, towards the goal.
	var accel := (behind-_offset)*SPRING*SPRING-_offset_v*2.0*SPRING
	_offset_v += accel*delta
	_offset += _offset_v*delta
	eye = at+_offset
	var on := _way*(AHEAD+AHEAD_SPEED*float(glide.speed))*size
	# Framed, the look ahead leads into the turn a little.
	if framed:
		var h := float(glide.heading)
		var rate := 0.0 if is_nan(_heading) or delta <= 0.0 else angle_difference(_heading,h)/delta
		_heading = h
		_yaw_rate = lerpf(_yaw_rate,clampf(rate,-4.0,4.0),_ease(EASE_LEAD,delta))
		var own := 1.0-clampf(Vector2(_cine.x,_cine.y).length()+absf(_cine.z),0.0,1.0)
		on = on.rotated(Vector3.UP,clampf(_yaw_rate*LEAD_TIME,-LEAD_MAX,LEAD_MAX)*own)
	look = at.lerp(at+on+Vector3.UP*LOOK_UP*size,1.0-smoothstep(0.3,1.0,absf(swing.x)/PI))
	roll = lerpf(roll,_lean(float(glide.bank)),_ease(EASE_ROLL,delta))
	clipped = false
	if framed:
		if solid.is_valid() or sight.is_valid(): _keep_clear(delta,at,solid)
		_keep_in_frame(at)
	elif solid.is_valid(): _stop_short(at,solid)

## The glide's speed as a share of the plane's cruise (1 at cruise; of the
## old toy's when none is given).
func _pace(glide: RefCounted) -> float:
	return glide.velocity.length()/(cruise if cruise > 0.0 else TOY_CRUISE)

static func _flag(prefix: String, fallback: float) -> float:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with(prefix): return maxf(0.0,float(arg.substr(prefix.length())))
	return fallback

## The roll for a bank: a share of it, eased softly into ROLL_MAX.
func _lean(bank: float) -> float:
	return -ROLL_MAX*tanh(bank*ROLL/ROLL_MAX)

## The field of view eases towards the speed's, the jet's kick and the
## float's narrowing.
func _widen(delta: float, glide: RefCounted) -> void:
	var t := clampf((glide.velocity.length()-FOV_SPEED.x)/(FOV_SPEED.y-FOV_SPEED.x),0.0,1.0)
	if framed: t = clampf((_pace(glide)-FOV_SHARE.x)/(FOV_SHARE.y-FOV_SHARE.x),0.0,1.0)
	var fast := 1.0-(1.0-t)*(1.0-t)
	var jet := float(glide.in_jet)
	_jet_felt = lerpf(_jet_felt,jet,_ease(JET_SETTLE,delta))
	var kick := smoothstep(0.0,0.5,jet-_jet_felt)
	var want := (FOV_FIRST+FOV_FIRST_FAST*fast) if first_person else (base_fov+FOV_FAST*speed_fov*fast)
	want += JET_KICK*kick-FOV_FLOAT*float(glide.hang)
	fov = lerpf(fov,want,_ease(EASE_FOV,delta))

## Out from the glider towards the eye: if rock is in the way it swings
## round or lifts over it (the nearest of DODGES that sees the glider
## clear, eased), and failing that draws in short of it, never nearer than
## `near`; once clear it eases back out. The spring's own offset is left
## alone, so nothing has to swing back out from close in.
func _keep_clear(delta: float, at: Vector3, solid: Callable) -> void:
	var want := _offset
	var full := want.length()
	if full < 0.01: return
	var pick := _dodge
	var pick_clear := 1.0
	if _dodge != Vector2.ZERO or _clear(at,_turned(want,_dodge),solid) < 1.0:
		var best := -INF
		for d: Vector2 in DODGES:
			var c := _clear(at,_turned(want,d),solid)
			var score := (10.0 if c >= 1.0 else 10.0*c-5.0)-d.length()-d.distance_to(_dodge)*0.5
			if score > best:
				best = score
				pick = d
				pick_clear = c
	var rate := EASE_DODGE if pick.length() >= _dodge.length() else EASE_DODGE_BACK
	_dodge = _dodge.lerp(pick,_ease(rate,delta)) if delta > 0.0 else pick
	if _dodge.length() < 0.002: _dodge = Vector2.ZERO
	var dir := _turned(want,_dodge).normalized()
	# Swinging to a clear way round, it doesn't draw in on the way there.
	var allowed := full
	if pick_clear < 1.0: allowed = minf(full,maxf(_clear(at,dir*full,solid)*full,near))
	if allowed < _reach: _reach = allowed
	else: _reach = minf(lerpf(_reach,allowed,_ease(EASE_OUT,delta)),full)
	eye = at+dir*_reach
	clipped = _dodge != Vector2.ZERO or _reach < full-0.01

## The glide's way (not framed): out from the glider towards the eye, it
## stops short of the first rock, and the spring starts again from there.
func _stop_short(at: Vector3, solid: Callable) -> void:
	var out := eye-at
	var reach := out.length()
	if reach < 0.01: return
	var dir := out/reach
	for i in range(1,PROBES+1):
		var d := reach*float(i)/PROBES
		if solid.call(at+dir*(d+KEEP)):
			eye = at+dir*maxf(d-reach/PROBES,0.0)
			clipped = true
			_offset = eye-at
			return

## `off` swung round by `d.x` and lifted by `d.y` (radians; under 0
## dropped), no further than LIFT_MOST over or under level.
static func _turned(off: Vector3, d: Vector2) -> Vector3:
	if d == Vector2.ZERO: return off
	var out := off.rotated(Vector3.UP,d.x)
	var side := out.cross(Vector3.UP)
	if side.length() < 0.001: return out
	var level := atan2(out.y,Vector2(out.x,out.z).length())
	var lift := clampf(d.y,-LIFT_MOST-level,LIFT_MOST-level)
	if is_zero_approx(lift): return out
	return out.rotated(side.normalized(),lift)

## The share of the way from `at` out by `off` that is clear of rock, KEEP
## short of the first (1: clear all the way).
func _clear(at: Vector3, off: Vector3, solid: Callable) -> float:
	var reach := off.length()
	if reach < 0.01: return 1.0
	var dir := off/reach
	if sight.is_valid():
		var share := float(sight.call(at,at+dir*(reach+KEEP)))
		if share >= 1.0: return 1.0
		return clampf((share*(reach+KEEP)-KEEP)/reach,0.0,1.0)
	for i in range(1,PROBES+1):
		var d := reach*float(i)/PROBES
		if solid.call(at+dir*(d+KEEP)): return maxf(d-reach/PROBES,0.0)/reach
	return 1.0

## Framed: the plane (a ball `extent` m round its middle) kept inside the
## safe part of the view: past SAFE of the half-screen it is eased back,
## and it never passes EDGE. The view turns towards it; the eye stays.
func _keep_in_frame(at: Vector3) -> void:
	for i in range(2):
		var to := look-eye
		var reach := to.length()
		if reach < 0.01: return
		var basis := Basis.looking_at(to,Vector3.UP)*Basis(Vector3.FORWARD,roll)
		var p := basis.inverse()*(at-eye)
		if p.z > -0.05: return
		var depth := -p.z
		var half := tan(deg_to_rad(fov)*0.5)
		var pad := extent/depth
		var tx := p.x/depth
		var ty := p.y/depth
		var sx := _soft(tx,half*aspect,pad)
		var sy := _soft(ty,half,pad)
		if is_equal_approx(sx,tx) and is_equal_approx(sy,ty): return
		look = eye+basis*Vector3(tx-sx,ty-sy,-1.0).normalized()*reach

## A tangent `t` across a half-view `half` wide, with the plane `pad` round
## it: as it was within SAFE, eased towards EDGE past that, never over.
static func _soft(t: float, half: float, pad: float) -> float:
	var a := maxf(half*SAFE-pad,0.0)
	var b := maxf(half*EDGE-pad,a+0.001)
	var m := absf(t)
	if m <= a: return t
	return signf(t)*(a+(b-a)*tanh((m-a)/(b-a)))

func _ease(rate: float, delta: float) -> float:
	return 1.0-exp(-delta/rate)
