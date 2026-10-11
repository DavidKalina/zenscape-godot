extends RefCounted
## The hand-flown landing: no F, no sequence flying it in. The pilot finds a
## spot, brings the plane (scripts/sky_plane.gd) down slow and shallow, and
## the wheels decide: a good touch settles and rolls out under the pilot's
## own brakes; a bad one bounces back into the air to go round. Only once it
## has stopped can the pilot get out, and only by asking (Exit). The
## landing study (studies/landing_study.gd) and the game under
## `--manual-landing` (scripts/wanderer_eye.gd) both run it; plain state and
## maths over the plane, so tests can step it.
##
## Its phases:
##   AIR      flying as ever (SkyPlane `step`). Each step the wheels are
##            watched: the first step the plane rides the land (SkyGlide
##            `skimming`, over ground the `floor` has) is the touch, judged
##            on the air step before it (`judge`).
##   ROLL     on its wheels, rolling: it slows by ROLL_DRAG alone, by up to
##            WHEEL_BRAKE more with Brake held, and the land's slope pulls
##            it; the stick steers it on its tail wheel. Boost opens the
##            throttle (PUSH), and at LIFT_SPEED with Boost held it lifts off
##            again (a touch-and-go). Rolled off the land's edge it is
##            flying again, dropping a moment before the air catches it.
##   STOPPED  stood still, the brakes holding, the engine ticking over. Boost
##            rolls it off again; Exit gets out.
##   EXIT     the engine spins down (SPIN) and the pilot hops out (HOP_TIME,
##            `hop` 0 to 1), then OUT: the caller parks it and walks.
##
## The touch (`judge`) is good only if it is all of: slower than TOUCH_FAST
## along the ground, sinking slower than TOUCH_SINK, wings within
## TOUCH_BANK of level and not mid-roll, the nose no lower than TOUCH_NOSE,
## and the land under it no steeper than TOUCH_SLOPE. Anything else is a
## bounce: a thump (`events.bounce`, with the reason, for the caller's sound,
## shake and pad pulse), the plane kicked up at BOUNCE_UP plus BOUNCE_GIVE
## of its sink, the nose up to BOUNCE_NOSE, a little speed scrubbed off,
## and BOUNCE_GRACE s before the wheels count again. Never a crash.
##
## It counts what the study measures (`stats`): every touch (speed, sink,
## bank, what it was), bounces, go-arounds (low over the land, under
## LOW_PASS m, then back up over GO_AROUND m without stopping), the rollout
## from the good touch to the stop (m), the time to the stop, touch-and-gos,
## rolls off the edge and Exit asked before the stop.

const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")
const PlaneLanding = preload("res://scripts/plane_landing.gd")

enum {AIR,ROLL,STOPPED,EXIT,OUT}
const NAMES := ["air","roll","stopped","exit","out"]

## A good touch: the most speed along the ground (m/s), sink (m/s), bank
## (radians), nose down (radians), and slope of the land (m per m).
const TOUCH_FAST := 10.5
const TOUCH_SINK := 2.4
const TOUCH_BANK := 0.35
const TOUCH_NOSE := -0.4
const TOUCH_SLOPE := 0.4
## A bounce: the kick up (m/s) and the share of the sink it gives back, the
## pull that brings the kick down (m/s²), the nose it throws up to
## (radians), the speed it scrubs (m/s) and the seconds before the wheels
## count again (after a touch-and-go too).
const BOUNCE_UP := 3.2
const BOUNCE_GIVE := 0.5
const BOUNCE_PULL := 9.0
const BOUNCE_NOSE := 0.3
const BOUNCE_SCRUB := 1.0
const BOUNCE_GRACE := 0.7
## On the wheels: the slowing rolling with the throttle closed (m/s²), the
## wheel brakes' most (m/s²), the throttle's push (m/s², the takeoff's), how
## hard a slope pulls (m/s² per m per m), the tail wheel's turn (radians a
## second at full stick, at TAXI_FULL m/s and over; a quarter of it
## stopped), and the speed at which it lifts off with Boost held.
const ROLL_DRAG := 0.9
const WHEEL_BRAKE := 4.2
const PUSH := PlaneLanding.PUSH
const SLOPE_PULL := 7.0
const TAXI_TURN := 0.9
const TAXI_FULL := 3.0
const LIFT_SPEED := PlaneLanding.LIFT_SPEED
## Stopped: slower than STOP_SPEED for STOP_HOLD seconds.
const STOP_SPEED := 0.25
const STOP_HOLD := 0.25
## The touch's settle: a small hop or two on the wheels (heights m, lengths
## s), as the scripted landing's.
const SETTLE := Vector2(0.09,0.025)
const SETTLE_TIME := Vector2(0.26,0.16)
## Go-arounds: low over the land under LOW_PASS m, then back over GO_AROUND.
const LOW_PASS := 3.0
const GO_AROUND := 8.0

var plane: RefCounted
var phase := AIR
## Seconds in this phase, and since `begin`.
var time := 0.0
var elapsed := 0.0
## The engine running (0 to 1) and the throttle (-1 to 1), for the hum and
## the propeller; the pilot's hop out (0 in, 1 out).
var engine := 1.0
var throttle := 0.0
var hop := 0.0
## What the last touch was ("" none yet; "good", or a bounce's reason).
var last_touch := ""
## The numbers (see the header).
var stats := {}
## Seconds left before the wheels count, and the bounce's kick still
## lifting (m/s).
var _grace := 0.0
var _kick := 0.0
## The air step's velocity before the wheels met the land.
var _air_velocity := Vector3.ZERO
var _air_pitch := 0.0
var _air_bank := 0.0
var _air_rolling := false
## On the wheels: the speed along the ground (m/s), the touch's speed and
## pitch, seconds since the touch, seconds slow, where it touched (for the
## rollout) and the land's height last seen under it.
var _roll_speed := 0.0
var _touch_speed := 0.0
var _touch_pitch := 0.0
var _since_touch := 0.0
var _slow_for := 0.0
var _touch_at := Vector3.ZERO
var _land_y := NAN
## Low over the land since the last go-around.
var _low := false

## Takes charge of `on_plane`: in the air (`on_ground` false, flying as it
## is), or stood stopped where it is (`on_ground`, as a parked plane boarded
## without the takeoff sequence).
func begin(on_plane: RefCounted, on_ground := false) -> void:
	plane = on_plane
	phase = STOPPED if on_ground else AIR
	time = 0.0
	elapsed = 0.0
	engine = 1.0
	throttle = 0.0
	hop = 0.0
	last_touch = ""
	_grace = 0.0
	_kick = 0.0
	_air_velocity = plane.velocity
	_air_pitch = float(plane.pitch)
	_air_bank = float(plane.bank)
	_roll_speed = 0.0
	_low = false
	stats = {"touches":[],"bounces":0,"go_arounds":0,"touch_and_gos":0,"off_edge":0,"early_exits":0,
		"rollout":NAN,"time_to_stop":NAN,"stopped":false,"bounce_reasons":{}}

func flying() -> bool:
	return phase == AIR

func on_ground() -> bool:
	return phase in [ROLL,STOPPED,EXIT]

## True stood still with the pilot still in: Exit gets out.
func can_exit() -> bool:
	return phase == STOPPED

func done() -> bool:
	return phase == OUT

## Whether a touch like this one lands: "" if it is good, else why not:
## "fast", "sink", "bank", "nose" or "rough" (the land too steep).
static func judge(speed: float, sink: float, bank: float, pitch: float, slope: float, rolling := false) -> String:
	if speed > TOUCH_FAST: return "fast"
	if sink > TOUCH_SINK: return "sink"
	if absf(bank) > TOUCH_BANK or rolling: return "bank"
	if pitch < TOUCH_NOSE: return "nose"
	if slope > TOUCH_SLOPE: return "rough"
	return ""

## Whether a touch now would land, as `judge` reads the plane (for a
## landing mark).
func would_land(floor_at: Callable) -> bool:
	if phase != AIR or plane == null: return false
	var v: Vector3 = plane.velocity
	return judge(Vector2(v.x,v.z).length(),-v.y,float(plane.bank),float(plane.pitch),_slope(floor_at,Vector2(plane.position.x,plane.position.z),v),bool(plane.get("rolling"))) == ""

## One step. `input` is the plane's (SkyPlane `step`), plus `exit` (true on
## the frame Exit is asked for). `ground` is the flight's solids (SkyGlide
## `step`), `floor_at` Callable(Vector2) -> float, the land's height under a
## global XZ point (NAN off the land: the wheels' ground); `air` as the
## flight's. `blocked`, if given, Callable(Vector3) -> bool, true where
## something stands in the way of the wheels. Returns what happened:
##   touch {speed, sink, bank, result}, bounce {reason, sink, speed},
##   settled (a good touch), stopped, lifted (a touch-and-go), off_edge,
##   go_around, not_yet (Exit before the stop), hit (rolled into something),
##   out (the pilot is out).
func step(delta: float, input: Dictionary, ground: Callable, floor_at: Callable, air := Callable(), blocked := Callable()) -> Dictionary:
	var out := {}
	time += delta
	elapsed += delta
	if bool(input.get("exit",false)) and phase in [AIR,ROLL]:
		out["not_yet"] = true
		stats.early_exits += 1
	match phase:
		AIR: _fly(delta,input,ground,floor_at,air,out)
		ROLL: _roll(delta,input,floor_at,blocked,out)
		STOPPED:
			engine = 1.0
			throttle = -0.3
			_hold(floor_at)
			if float(input.get("boost",0.0)) > 0.0:
				_enter(ROLL)
				_roll_speed = 0.0
				_since_touch = INF
			elif bool(input.get("exit",false)): _enter(EXIT)
		EXIT:
			engine = maxf(0.0,engine-delta/PlaneLanding.SPIN)
			throttle = -1.0
			hop = clampf((time-PlaneLanding.BEAT_TIME)/PlaneLanding.HOP_TIME,0.0,1.0)
			_hold(floor_at)
			if time >= PlaneLanding.BEAT_TIME+PlaneLanding.HOP_TIME:
				engine = 0.0
				hop = 1.0
				_enter(OUT)
				out["out"] = true
		OUT: _hold(floor_at)
	return out

func _enter(next: int) -> void:
	phase = next
	time = 0.0

# --- In the air ----------------------------------------------------------------------

func _fly(delta: float, input: Dictionary, ground: Callable, floor_at: Callable, air: Callable, out: Dictionary) -> void:
	engine = 1.0
	plane.step(delta,input,ground,air)
	throttle = float(plane.throttle)
	# A bounce's kick, lifting it clear and dying away.
	if _kick > 0.0:
		plane.position.y += _kick*delta
		_kick = maxf(0.0,_kick-BOUNCE_PULL*delta)
	_grace = maxf(0.0,_grace-delta)
	var at := Vector2(plane.position.x,plane.position.z)
	var land := float(floor_at.call(at))
	if not is_nan(land): _land_y = land
	_watch_go_around(land,out)
	var on_land: bool = not is_nan(land) and plane.skimming and plane.position.y <= land+SkyPlane.SKIM+0.05
	if on_land and _grace <= 0.0:
		_touch(at,land,floor_at,out)
		return
	# Riding the land during the grace counts as no sink: judged then on
	# its speed alone.
	_air_velocity = plane.velocity
	_air_pitch = float(plane.pitch)
	_air_bank = float(plane.bank)
	_air_rolling = bool(plane.rolling)

## Low over the land, then back up high without stopping: a go-around.
func _watch_go_around(land: float, out: Dictionary) -> void:
	var over := float(plane.position.y)-(land if not is_nan(land) else _land_y)
	if is_nan(over): return
	if over < LOW_PASS and not is_nan(land): _low = true
	elif _low and over > GO_AROUND:
		_low = false
		stats.go_arounds += 1
		out["go_around"] = true

## The wheels meet the land: judged on the air step before.
func _touch(at: Vector2, land: float, floor_at: Callable, out: Dictionary) -> void:
	var v := _air_velocity
	var speed := Vector2(v.x,v.z).length()
	var sink := maxf(0.0,-v.y)
	var slope := _slope(floor_at,at,v)
	var reason := judge(speed,sink,_air_bank,_air_pitch,slope,_air_rolling)
	last_touch = "good" if reason == "" else reason
	var touch := {"t":elapsed,"speed":speed,"sink":sink,"bank":_air_bank,"pitch":_air_pitch,"slope":slope,"result":last_touch}
	(stats.touches as Array).append(touch)
	out["touch"] = touch
	_low = true
	if reason != "":
		_bounce(reason,sink,speed,out)
		return
	_enter(ROLL)
	_roll_speed = speed
	_touch_speed = maxf(speed,0.1)
	_touch_pitch = clampf(_air_pitch,-0.1,0.35)
	_since_touch = 0.0
	_slow_for = 0.0
	_touch_at = plane.position
	plane.rolling = false
	plane.spin = 0.0
	plane.knife = 0.0
	out["settled"] = true
	_place_on(land,floor_at,0.0)

## Back up into the air, never down: kicked up and the nose thrown up.
func _bounce(reason: String, sink: float, speed: float, out: Dictionary) -> void:
	stats.bounces += 1
	var reasons: Dictionary = stats.bounce_reasons
	reasons[reason] = int(reasons.get(reason,0))+1
	_kick = BOUNCE_UP+BOUNCE_GIVE*sink
	_grace = BOUNCE_GRACE
	plane.pitch = maxf(float(plane.pitch),BOUNCE_NOSE)
	plane.speed = maxf(float(plane.speed)-BOUNCE_SCRUB,SkyPlane.FLAP_SLOW)
	plane.position.y += 0.15
	if plane.velocity.y < 0.0: plane.velocity.y = 0.0
	out["bounce"] = {"reason":reason,"sink":sink,"speed":speed}

# --- On the wheels -------------------------------------------------------------------

func _roll(delta: float, input: Dictionary, floor_at: Callable, blocked: Callable, out: Dictionary) -> void:
	engine = 1.0
	_since_touch += delta
	var boost := clampf(float(input.get("boost",0.0)),0.0,1.0)
	var brake := clampf(float(input.get("brake",0.0)),0.0,1.0)
	throttle = boost-brake if boost > 0.0 else -1.0
	var heading := float(plane.heading)
	var dir := Vector2(-sin(heading),-cos(heading))
	var at := Vector2(plane.position.x,plane.position.z)
	# The tail wheel steers, more as it goes.
	var turn := clampf(float(input.get("turn",0.0)),-1.0,1.0)
	heading -= turn*TAXI_TURN*lerpf(0.25,1.0,clampf(_roll_speed/TAXI_FULL,0.0,1.0))*delta
	plane.heading = heading
	dir = Vector2(-sin(heading),-cos(heading))
	# The slope along the way: uphill slows, downhill runs on.
	var here := float(floor_at.call(at))
	var ahead := float(floor_at.call(at+dir*0.5))
	var grade := (ahead-here)/0.5 if not is_nan(here) and not is_nan(ahead) else 0.0
	var accel := boost*PUSH-SLOPE_PULL*grade
	var slowing := (ROLL_DRAG*(1.0-boost)+WHEEL_BRAKE*brake) if _roll_speed > 0.0 else 0.0
	_roll_speed = maxf(0.0,_roll_speed+(accel-slowing)*delta)
	var next := at+dir*_roll_speed*delta
	if blocked.is_valid() and _roll_speed > 0.0 and bool(blocked.call(Vector3(next.x,plane.position.y,next.y))):
		# Into something: stopped short with a thump, never through it.
		out["hit"] = {"speed":_roll_speed}
		_roll_speed = 0.0
		next = at
	var land := float(floor_at.call(next))
	if is_nan(land):
		# Off the land's edge: flying again, dropping a moment first.
		stats.off_edge += 1
		out["off_edge"] = true
		plane.position = Vector3(next.x,plane.position.y,next.y)
		_lift(maxf(_roll_speed,SkyPlane.FLAP_SLOW),0.0,true)
		return
	plane.position = Vector3(next.x,plane.position.y,next.y)
	var settle := smoothstep(0.0,1.0,1.0-_roll_speed/maxf(_touch_speed,0.1)) if _since_touch < INF else 1.0
	_place_on(land,floor_at,settle)
	plane.speed = _roll_speed
	plane.velocity = Vector3(dir.x,0.0,dir.y)*_roll_speed
	if boost > 0.0 and _roll_speed >= LIFT_SPEED:
		stats.touch_and_gos += 1
		out["lifted"] = true
		_lift(_roll_speed,0.15,false)
		return
	_slow_for = _slow_for+delta if _roll_speed < STOP_SPEED and boost <= 0.0 else 0.0
	if _slow_for >= STOP_HOLD:
		_roll_speed = 0.0
		plane.speed = 0.0
		plane.velocity = Vector3.ZERO
		if not bool(stats.stopped):
			stats.stopped = true
			stats.time_to_stop = elapsed
			stats.rollout = Vector2(plane.position.x-_touch_at.x,plane.position.z-_touch_at.z).length()
		_enter(STOPPED)
		out["stopped"] = true

## Sat on its wheels on the land at `land` under it: the tail coming down
## as it slows (`settle` 0 at the touch to 1 stopped), the settle's hops.
func _place_on(land: float, floor_at: Callable, settle: float) -> void:
	var at := Vector2(plane.position.x,plane.position.z)
	var rest := PlaneStrip.rest(func(p: Vector2) -> float:
		var h := float(floor_at.call(p))
		return land if is_nan(h) else h,at,float(plane.heading))
	var pitch := lerpf(_touch_pitch,rest.y,settle)
	var hops := _hops(_since_touch)
	plane.pitch = pitch-hops*0.6
	plane.bank = lerpf(float(plane.bank),rest.z*settle,0.2)
	plane.position.y = rest.w+PlaneStrip.contact(pitch)+hops

func _hops(t: float) -> float:
	if t < SETTLE_TIME.x: return SETTLE.x*sin(PI*t/SETTLE_TIME.x)
	t -= SETTLE_TIME.x
	if t < SETTLE_TIME.y: return SETTLE.y*sin(PI*t/SETTLE_TIME.y)
	return 0.0

## Stood still where it is, on its wheels and tail skid.
func _hold(floor_at: Callable) -> void:
	_roll_speed = 0.0
	plane.speed = 0.0
	plane.velocity = Vector3.ZERO
	var at := Vector2(plane.position.x,plane.position.z)
	var land := float(floor_at.call(at))
	if is_nan(land): return
	_since_touch = INF
	_place_on(land,floor_at,1.0)

## Off the wheels and flying: at `pace` m/s, the nose at `nose`; off an
## edge (`drop`) it falls a moment before the air catches it.
func _lift(pace: float, nose: float, drop: bool) -> void:
	plane.resume(maxf(pace,SkyPlane.SLOW),nose)
	if drop: plane.airborne = 0.0
	_grace = BOUNCE_GRACE
	_kick = 0.0
	_enter(AIR)

## The land's steepest slope under `at` (m per m), along the way `v` and
## across it.
static func _slope(floor_at: Callable, at: Vector2, v: Vector3) -> float:
	var way := Vector2(v.x,v.z)
	way = way.normalized() if way.length() > 0.01 else Vector2(0.0,-1.0)
	var side := Vector2(-way.y,way.x)
	var here := float(floor_at.call(at))
	if is_nan(here): return 0.0
	var most := 0.0
	for d: Vector2 in [way,-way,side,-side]:
		var h := float(floor_at.call(at+d*0.6))
		if not is_nan(h): most = maxf(most,absf(h-here)/0.6)
	return most

## Where the wheels set down (global), for the rollout.
func touched_at() -> Vector3:
	return _touch_at

## The speed along the ground while rolling (m/s).
func roll_speed() -> float:
	return _roll_speed
