extends RefCounted
## The engine's life on the parked plane (scripts/plane_figure.gd `hum`): what
## the title shows, from a cold prop to a running idle, the run-up on the
## brakes and the takeoff roll, as one system. It moves nothing itself: the
## figure reads its numbers each frame. Nothing here touches the flight.
##
## The start-up is keyed by hand against the clock `starter` (seconds; the
## stage's, scripts/endless/menu_stage.gd), and its firing hits on the bursts
## in assets/audio/kit/engine-start.wav, which starts at SOUND_AT (`engine_at`
## raises the engine past the sound's trigger there): the starter swings the
## prop, heavy, hanging at each compression (HITCH); uneven kicks (HITS) rock
## the plane back and pop smoke; CATCH is the last and biggest, the prop leaps
## and the idle comes down to IDLE turns/s through a rough patch.
##
## A hit is an impulse, not a shape: it goes into the body's springs (BODY:
## pitch, roll, yaw and heave on the tyres and legs), and each smaller part is
## its own spring pushed by the body's acceleration and by the prop's air, so
## it arrives late and rings on at its own pitch: the cowl (quick, stiff), the
## wing tips, the elevator, ailerons and rudder. Between hits a running engine
## lopes: small hits at uneven gaps, thinning as it settles. All noise is
## smooth value noise under NOISE_MOST Hz and everything steps at STEP, so the
## motion is the same curve at any frame rate, and nothing can alias.
##
## `rev` is the same engine with the throttle open: the prop's goal rises, the
## lope goes, the nose goes down and the tail comes light (TAIL), the torque
## leans harder, the air works the surfaces harder. Rolling (`pace`), the ground
## feeds the springs (ROLL_BUMPS). With hum gone it all settles out (`spent`).

const STEP := 1.0/240.0
## Each frame at most this much is simulated, so a long hitch skips rather than
## stalls.
const MOST := 0.25

## The starter's clock: the sound's start, and the catch (its first burst that
## holds), the idle settled. Hits on the sound's bursts at 0.12, 0.48, 0.76, 1.16.
const SOUND_AT := 1.25
const CATCH := 2.41
const SETTLED := 5.0
## [when, rock (0 to 1), prop turns/s added, smoke (0 to 1)]
const HITS := [
	[0.0,0.14,0.0,0.0],
	[1.37,0.5,3.2,0.14],
	[1.73,0.36,2.0,0.0],
	[2.01,0.72,4.0,0.5],
	[2.41,1.0,9.0,1.0],
	[2.83,0.34,-2.5,0.3],
	[3.32,0.22,-1.5,0.2],
]
const STARTER_TURNS := 1.5
const STARTER_UP := 0.8
## How far the prop's pace swings with each compression, while it's slow.
const HITCH := 0.72
## Turns/s: the idle's, where the catch leaps to, the run-up's top.
const IDLE := 8.0
const LEAP := 17.0
const FULL := 27.0
const LEAP_S := 0.7
## How fast the prop's pace reaches its goal (s), and a kick's decay.
const RATE_S := 0.16
const KICK_S := 0.22

## Rad/s (m/s for heave) a full hit gives each of the body's springs.
const HIT_PITCH := 0.3
const HIT_ROLL := 0.26
const HIT_YAW := 0.1
const HIT_HEAVE := 0.1
## Pitch, roll, yaw, heave.
const BODY_HZ := [2.1,1.6,2.6,3.3]
const BODY_DAMP := [0.15,0.2,0.24,0.3]
## The noise on each (how far it pushes the spring's rest, at idle; it rings up
## to a few times this) and its rate (Hz).
const BODY_STIR := [0.0024,0.0028,0.0014,0.0007]
const STIR_HZ := 2.3
## Torque's lean (rad) and the run-up's: nose down, tail light, squatting.
const TORQUE := 0.01
const TORQUE_REV := 0.018
const TAIL := 0.05
const SQUAT := 0.006
## Lope: gaps (s) and rock of a settled idle's small hits; how much more when rough.
const LOPE_GAP := Vector2(0.45,1.25)
const LOPE_ROCK := Vector2(0.08,0.17)
const LOPE_DROP := 0.7
## The brakes let go: how much rock, and when the pace says it has.
const LET_GO := 0.8
const ROLLING := 0.25
## The ground under the wheels: the most stir at speed, per m/s up to BUMPS_FULL.
const ROLL_BUMPS := 2.5
const BUMPS_FULL := 10.0

## The cowl, on the mounts: Hz, damp, noise (toy units), how much a hit throws
## it, how much the body's acceleration does.
const COWL_HZ := 6.6
const COWL_DAMP := 0.1
const COWL_STIR := 0.0008
const COWL_HIT := 0.1
const COWL_THROW := 0.0002
## The smaller parts: Hz, damp; the air's push and the body's throw on them.
const TIP_HZ := 3.3
const TIP_DAMP := 0.08
const TIP_STIR := 0.012
const TIP_THROW := 0.012
const TIP_HIT := 0.5
const ELEVATOR_HZ := 4.3
const ELEVATOR_DAMP := 0.11
const ELEVATOR_AIR := 0.006
const ELEVATOR_THROW := 0.006
const AILERON_HZ := 3.4
const AILERON_DAMP := 0.13
const AILERON_AIR := 0.005
const AILERON_THROW := 0.005
const RUDDER_HZ := 3.8
const RUDDER_DAMP := 0.12
const RUDDER_AIR := 0.006
const RUDDER_THROW := 0.008
## The stick held back on the run-up (rad; negative lifts the trailing edge).
const STICK_BACK := -0.14
const NOISE_MOST := 9.0
## The air a part sees grows as the pace squared, up to this much of idle's.
const AIR_MOST := 3.0

const SMOKE_GAP := Vector2(0.14,0.5)
## The stubs warm over this (s) from the catch, and cool over the other.
const HEAT_UP := 1.6
const HEAT_DOWN := 0.5
const HEAT_IDLE := 0.7
## The prop's pace (turns/s) over which it starts to move air worth the name.
const AIR_FROM := Vector2(2.0,6.0)

## The body now: pitch, roll, yaw (rad), heave (toy units).
var pitch := 0.0
var roll := 0.0
var yaw := 0.0
var heave := 0.0
## The cowl's offset on its mounts (toy units, x and y).
var nose := Vector2.ZERO
## The wing tips' bend, the surfaces' angles (rad).
var tips := 0.0
var elevator := 0.0
var ailerons := Vector2.ZERO
var rudder := 0.0
## The prop: its angle (radians, grows), and how far it went in the last `step`.
var angle := 0.0
var turned := 0.0
## Its pace (turns/s).
var turns := 0.0
## Puffs this frame (how strong, 0 to 1), for the exhaust to spend.
var puffs: Array[float] = []
## How hot the stubs are (0 to 1): up from the catch, and on the run-up.
var heat := 0.0

var _t := 0.0
var _spare := 0.0
var _clock := -1.0
var _level := 0.0
var _rough := 0.0
var _kick := 0.0
var _next_hit := 0
var _next_lope := 0.0
var _next_wisp := 0.0
var _rolled := false
var _rng := RandomNumberGenerator.new()
var _v: Array[float] = [0.0,0.0,0.0,0.0]
var _x: Array[float] = [0.0,0.0,0.0,0.0]
var _v_nose := Vector2.ZERO
var _v_tips := 0.0
var _v_elevator := 0.0
var _v_ailerons := Vector2.ZERO
var _v_rudder := 0.0
var _rev := 0.0

func _init() -> void:
	_rng.seed = 41

## The engine's run for the world (0 to 1, the sound and the wash read it, as
## `stage.engine`) at `starter` s on the clock: past the sound's trigger at
## SOUND_AT, then coming up from the catch.
static func engine_at(starter: float) -> float:
	if starter < SOUND_AT: return 0.0
	return lerpf(0.03,1.0,smoothstep(CATCH-0.1,CATCH+1.0,starter))

## One frame: `starter` the clock (a running engine if it's under 0), `on` if
## the idle is wanted, `rev` 0 to 1, `pace` the ground speed, `rolling` on the wheels.
func step(delta: float, starter: float, on: bool, rev: float, pace: float, rolling: bool) -> void:
	turned = 0.0
	puffs.clear()
	_spare += minf(delta,MOST)
	var was := _clock
	var run := starter < 0.0
	var clock := starter if not run else SETTLED+1.0
	var n := int(_spare/STEP)
	for i in range(n):
		var at := was+(clock-was)*float(i+1)/float(n) if was >= 0.0 else clock
		_tick(at,on,rev,pace,rolling)
	_spare -= n*STEP
	if n > 0: _clock = clock
	# A frame shorter than a step: the prop's still going.
	else: turned = turns*TAU*minf(delta,MOST)

## The air the prop moves, for the wash on the grass (`thrust`, 0 to 1): a smooth
## pace, without the lope's kicks, so held air holds steady. About the 0.3 a
## parked idle always gave the wash, 1 at the run-up's top; none on the starter.
func air() -> float:
	return clampf(turns/FULL,0.0,1.0)*smoothstep(AIR_FROM.x,AIR_FROM.y,turns)

## The whole of it settled, hum gone: the figure can let go.
func spent() -> bool:
	if _level > 0.002 or turns > 0.05 or heat > 0.01: return false
	for k in range(4):
		if absf(_x[k]) > 0.0002: return false
	return absf(tips)+absf(elevator)+absf(rudder) < 0.001

func _tick(clock: float, on: bool, rev: float, pace: float, rolling: bool) -> void:
	var dt := STEP
	_t += dt
	_level += ((1.0 if on else 0.0)-_level)*(1.0-exp(-dt/0.25))
	_rev += (rev-_rev)*(1.0-exp(-dt/0.18))
	var caught := clock >= CATCH
	# The rough patch, thinning; the run-up smooths it out.
	_rough = (1.0-smoothstep(CATCH,SETTLED,clock))*(1.0-_rev) if caught else 0.0
	while _next_hit < HITS.size() and clock >= float(HITS[_next_hit][0]):
		var h: Array = HITS[_next_hit]
		_hit(float(h[1]),float(h[2]),float(h[3]))
		_next_hit += 1
	if caught and on and _rev < 0.5:
		_next_lope -= dt
		if _next_lope <= 0.0:
			_next_lope = _rng.randf_range(LOPE_GAP.x,LOPE_GAP.y)*(1.0-0.45*_rough)
			var k := _rng.randf()
			var rock := lerpf(LOPE_ROCK.x,LOPE_ROCK.y,k)*(1.0+1.2*_rough)
			_hit(rock,-LOPE_DROP*k*(0.5+_rough),0.0)
	# The prop's pace.
	var goal := 0.0
	if not on: goal = 0.0
	elif caught:
		goal = lerpf(IDLE,LEAP,exp(-(clock-CATCH)/LEAP_S))
		goal = lerpf(goal,FULL,_rev)
		goal *= 1.0+0.05*_noise(_t*1.7,3)
	elif clock >= 0.0: goal = STARTER_TURNS*smoothstep(0.0,STARTER_UP,clock)
	turns += (goal-turns)*(1.0-exp(-dt/RATE_S))
	_kick *= exp(-dt/KICK_S)
	var pace_now := maxf(turns+_kick,0.0)
	# Slow, it hangs on each compression and falls through.
	var hang := HITCH*(1.0-smoothstep(1.5,5.0,pace_now))
	var spin := pace_now*(1.0-hang*cos(2.0*angle))*TAU*dt
	spin = maxf(spin,0.0)
	angle = wrapf(angle+spin,0.0,TAU)
	turned += spin
	# Smoke: a running engine's wisps, at uneven gaps.
	if caught and on:
		_next_wisp -= dt
		if _next_wisp <= 0.0:
			_next_wisp = _rng.randf_range(SMOKE_GAP.x,SMOKE_GAP.y)
			puffs.append(0.06+0.08*_rough+0.1*_rev)
	var running := (1.0 if caught else 0.0)*_level
	var hot := running*lerpf(HEAT_IDLE,1.0,_rev)
	heat += (hot-heat)*(1.0-exp(-dt/(HEAT_UP if hot > heat else HEAT_DOWN)))
	var air := minf(pow(pace_now/IDLE,2.0),AIR_MOST)
	var bump := minf(pace/BUMPS_FULL,1.0)*ROLL_BUMPS if rolling else 0.0
	if rolling and not _rolled and _rev > 0.5 and pace > ROLLING:
		_rolled = true
		_v[0] += HIT_PITCH*LET_GO
		puffs.append(0.3)
	# The body.
	var stir := running*(1.0+1.2*_rough+1.0*_rev)+bump
	var goals := [-TAIL*_rev*_level,-(TORQUE+TORQUE_REV*_rev)*running,0.0,-SQUAT*_rev*_level]
	var accel: Array[float] = [0.0,0.0,0.0,0.0]
	for k in range(4):
		var w := float(BODY_HZ[k])*TAU
		var push := _noise(_t*STIR_HZ+k*7.3,k)*float(BODY_STIR[k])*stir
		var a := -w*w*(_x[k]-float(goals[k])-push)-2.0*float(BODY_DAMP[k])*w*_v[k]
		_v[k] += a*dt
		_x[k] += _v[k]*dt
		accel[k] = a
	pitch = _x[0]
	roll = _x[1]
	yaw = _x[2]
	heave = _x[3]
	# The cowl: its own quick tremble, and the rock arriving through the mounts.
	var w_c := COWL_HZ*TAU
	var shake := Vector2(_noise(_t*NOISE_MOST*0.81,5),_noise(_t*NOISE_MOST,6))*COWL_STIR*stir
	var throw := Vector2(accel[1],-accel[0])*COWL_THROW
	var a_c := -(nose-shake-throw)*w_c*w_c-_v_nose*2.0*COWL_DAMP*w_c
	_v_nose += a_c*dt
	nose += _v_nose*dt
	# The rest: late, each ringing at its own pitch.
	var t_t := _ring(tips,_v_tips,TIP_HZ,TIP_DAMP,0.0,_noise(_t*3.1,11)*TIP_STIR*stir+(accel[3]*2.0+accel[0])*TIP_THROW,dt)
	tips = t_t.x
	_v_tips = t_t.y
	var wash := air*_level
	var e := _ring(elevator,_v_elevator,ELEVATOR_HZ,ELEVATOR_DAMP,STICK_BACK*_rev*_level,_noise(_t*4.1,7)*ELEVATOR_AIR*wash-accel[0]*ELEVATOR_THROW,dt)
	elevator = e.x
	_v_elevator = e.y
	var l := _ring(ailerons.x,_v_ailerons.x,AILERON_HZ,AILERON_DAMP,0.0,_noise(_t*3.3,8)*AILERON_AIR*wash+accel[1]*AILERON_THROW,dt)
	var r := _ring(ailerons.y,_v_ailerons.y,AILERON_HZ*1.08,AILERON_DAMP,0.0,_noise(_t*3.7,9)*AILERON_AIR*wash-accel[1]*AILERON_THROW,dt)
	ailerons = Vector2(l.x,r.x)
	_v_ailerons = Vector2(l.y,r.y)
	var u := _ring(rudder,_v_rudder,RUDDER_HZ,RUDDER_DAMP,0.0,_noise(_t*2.9,10)*RUDDER_AIR*wash-accel[2]*RUDDER_THROW,dt)
	rudder = u.x
	_v_rudder = u.y

## A hit: into the body's springs, the prop, and the stubs.
func _hit(rock: float, kick: float, smoke: float) -> void:
	_v[0] += HIT_PITCH*rock
	_v[1] -= HIT_ROLL*rock
	_v[2] += HIT_YAW*rock*(1.0 if _next_hit%2 == 0 else -1.0)
	_v[3] += HIT_HEAVE*rock
	_v_nose += Vector2(0.0,COWL_HIT*rock)
	_v_tips += rock*TIP_HIT
	_kick += kick
	if smoke > 0.0: puffs.append(smoke)

## One spring's step: (x, v) of a part at `x`, `v`, toward `goal`, pushed by `push`.
static func _ring(x: float, v: float, hz: float, damp: float, goal: float, push: float, dt: float) -> Vector2:
	var w := hz*TAU
	v += (-w*w*(x-goal-push)-2.0*damp*w*v)*dt
	return Vector2(x+v*dt,v)

## Smooth noise, -1 to 1, one octave at unit rate; `s` picks the stream.
static func _noise(t: float, s: int) -> float:
	var i := floorf(t)
	var f := t-i
	var a := _hash(int(i),s)
	var b := _hash(int(i)+1,s)
	return lerpf(a,b,f*f*(3.0-2.0*f))

static func _hash(i: int, s: int) -> float:
	var h := (i*73856093)^(s*19349663)
	h = (h^(h>>13))*1274126177
	h = (h^(h>>16))&0xffffff
	return float(h)/8388607.5-1.0
