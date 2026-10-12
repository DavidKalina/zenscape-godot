extends RefCounted
## The sky dragon's body in flight (docs/design/dragon-spine/round1.md):
## the spine, neck, head and hind legs taking part in what the wings and
## the flight do, on damped springs, so they answer whatever he flies
## rather than keyed curves. scripts/sky_dragon.gd `_pose` steps it each
## flying frame (`step`) and lays its turns on top of its own.
##
## The spine is a chain of springs. Each bone's angle (pitch, yaw; rad,
## about the model's RIGHT and UP, relative to the flown body) chases the
## bone before it plus its own goal, slower down the chain, so a push on the
## chest travels out along the neck and back into the hips (and from them
## into the tail's rope) late: follow-through, not lockstep. A bone's turn
## (`turn_of`) is its angle less its parent's, so a bone that lags is seen
## to bend.
##   - the beat: on each downstroke the shoulders drive down (the chest
##     pitched nose down and swelled), recovering on the upstroke; the hips
##     lag the chest, the neck's bones each a little later;
##   - turns: the spine curves into the turn from the neck through the
##     chest and hips (the hips the other way about, so the tail's side of
##     the body bends in too) into the tail (`tail_curl`);
##   - climbing: the chest lifts and the neck reaches up into the climb, the
##     beats bigger (`beat_gain`); diving: tucked and streamlined (the neck
##     straight, `neck_s`; the head in line, `head_level`; the legs drawn
##     up; the wings part folded, `fold`); levelling out of a dive he flares
##     (the chest up, wings cupped, `sweep`, the legs and tail dropping);
##   - gliding: slow breathing (`swell`) and small spine shifts against the
##     air, the head steady;
##   - the head held steady against the beat's bob (`neck.0` dips as the
##     body rises) and against the chain's own sway (`head_steady`);
##   - the hind legs hang on springs: they swing late with each heave and
##     out of turns, and tuck in a dive (`leg`).
## All the tuning is here, below.

## The chain: bone, the bone it chases, whether that is its rig parent (its
## turn is then the difference), its spring (Hz) and damping ratio.
const CHAIN := [
	["chest","",false,0.5,0.55],
	["spine.2","chest",true,0.55,0.5],
	["neck.0","spine.2",true,0.7,0.55],
	["neck.1","neck.0",true,0.65,0.55],
	["neck.2","neck.1",true,0.6,0.55],
	["neck.3","neck.2",true,0.55,0.55],
	["hips","chest",false,0.32,0.5],
]
## How much of the chest's angle the hips chase (pitch, yaw): pitch the same
## way keeps chest and hips in line, so the hips lag a beat's push; yaw not,
## the turn's bend is their own.
const HIPS_FOLLOW := Vector2(0.7,0.0)

## The beat (rad): the downstroke's push on the chest (nose down), and the
## upstroke's recovery share of it. The chest's swell with each push (scale
## share, x and z).
const BEAT_CHEST := 0.09
const BEAT_RECOVER := 0.35
const BEAT_SWELL := 0.035
## Climbing: the beat's push and the wings' stroke larger by this share
## (`beat_gain`).
const CLIMB_BEAT := 0.25

## Turns, per unit of the turn's share of its most (rad): the chest, the
## spine's front, each neck bone (on top of the dragon's own lead), the hips
## (the other way about), and the tail's curl per segment.
const TURN_CHEST := 0.12
const TURN_SPINE := 0.1
const TURN_NECK := 0.07
const TURN_HIPS := 0.22
const TURN_TAIL := 0.08
## The turn eases in and out this fast (1/s), so the bend comes on heavily.
const TURN_EASE := 1.2

## Climb (rad, at full climb): the chest up, the spine's front up, the neck
## reaching up (each bone, more toward the head); the head's levelling
## against the flight's pitch eased to this share of the dragon's own.
const CLIMB_CHEST := 0.09
const CLIMB_SPINE := 0.04
const CLIMB_NECK := 0.05
const CLIMB_LEVEL := 0.55
## Dive (rad, at full tuck): the chest down, the hips up (the tail in
## line), the neck's S straightened to this share, the head's levelling to
## this share (so it points along the neck), the wings' extra fold and
## sweep back.
const TUCK_CHEST := -0.06
const TUCK_HIPS := -0.07
const TUCK_NECK_S := 0.2
## ...and each neck bone's pitch, root to head, stretching the neck out
## forward in line with the body (the root down, the head end up).
const TUCK_NECK := [-0.12,-0.08,0.0,0.1]
const TUCK_LEVEL := 0.15
const TUCK_FOLD := 0.35
const TUCK_SWEEP := 0.12
## The dive's tuck: from this dive (rad, down) to full at this.
const TUCK_FROM := 0.15
const TUCK_FULL := 0.45
## The level-out flare: the pull up out of a dive at FLARE_RATE rad/s (and
## below FLARE_BELOW rad of climb) flares fully. The chest up, the hips
## down (tail dropping), the wings swept forward (rad), the legs forward.
const FLARE_RATE := 0.3
const FLARE_BELOW := 0.08
const FLARE_CHEST := 0.1
const FLARE_HIPS := 0.08
const FLARE_SWEEP := 0.3
## The signals (climb, tuck, flare) ease this fast (1/s).
const SIGNAL_EASE := 1.0

## Gliding: the spine's slow shift against the air (rad of chest pitch per
## rad of the air's pitch, the hips' rudder per rad of its roll), a slow
## sway of its own (rad, Hz), and the breath (chest scale share, Hz).
const AIR_CHEST := -0.5
const AIR_RUDDER := 0.6
const GLIDE_SWAY := 0.025
const GLIDE_SWAY_HZ := 0.07
const BREATH := 0.03
const BREATH_HZ := 0.18

## The head: the share of the chain's sway (and of the body's nod and the
## air's pitch) it cancels, holding steady in the air; the share of the
## beat's bob the neck takes up (neck.0 dipping as the body rises), over
## the neck's length (m, the model's, root to head).
const HEAD_STEADY := 0.8
const BOB_STEADY := 0.5
const NECK_LENGTH := 17.6

## The hind legs (rad): the swing per unit of the beat's heave (they drop
## late as he surges up), out of a turn per unit of its rate, drawn up in a
## dive, forward in a flare, hanging lower climbing; the lower leg chases
## the upper's swing by this share (a dangling knee). Their springs (Hz,
## damping): heavy and loose.
const LEG_HEAVE := 0.12
const LEG_TURN := 0.12
const LEG_TUCK := -0.35
const LEG_TUCK_KNEE := 0.35
const LEG_FLARE := 0.3
const LEG_CLIMB := 0.12
const LEG_KNEE := 0.8
const LEG_SPRING := Vector2(0.55,0.35)
const KNEE_SPRING := Vector2(0.7,0.3)

## Unstepped for longer than this (s: clinging, asleep), it starts again
## from rest.
const STALE := 0.25

## Out: each chain bone's turn (pitch, yaw), the tail's curl per segment
## (rad, yaw) and droop (rad, pitch), the chest's swell (scale share), the
## wings' stroke gain, extra fold and sweep, the neck's S share, the head's
## levelling share and its steadying turn (pitch, yaw), and the legs'
## (upper pitch, upper roll, lower pitch).
var tail_curl := 0.0
var tail_droop := 0.0
var swell := 0.0
var beat_gain := 1.0
var fold := 0.0
var sweep := 0.0
var neck_s := 1.0
var head_level := 1.0
var head_steady := Vector2.ZERO
var leg := Vector3.ZERO
## The eased signals, 0..1 (turn -1..1), for logs and tests.
var climb := 0.0
var tuck := 0.0
var flare := 0.0
var turn := 0.0

var _x := {}
var _v := {}
var _leg_x := Vector3.ZERO
var _leg_v := Vector3.ZERO
var _gamma_was := 0.0
var _gamma_rate := 0.0
var _last := -INF

func _init() -> void:
	reset()

## Back to rest: no bend, no motion.
func reset() -> void:
	for link: Array in CHAIN:
		_x[link[0]] = Vector2.ZERO
		_v[link[0]] = Vector2.ZERO
	_leg_x = Vector3.ZERO
	_leg_v = Vector3.ZERO
	climb = 0.0
	tuck = 0.0
	flare = 0.0
	turn = 0.0
	_gamma_rate = 0.0
	_last = -INF

## One flying frame: the beat (`phase`, 0 the top; `down` its downstroke's
## share; `flap_w` how much it beats), the flight (`gamma` climb, rad;
## `turning`, the turn's rate over its most, -1..1, + left), the air's pitch and roll on him (rad), the
## clock (s) and the beat's bob (m, the model's, + up).
func step(delta: float, clock: float, phase: float, down: float, flap_w: float, gamma: float, turning: float, air_pitch: float, air_roll: float, bob: float) -> void:
	if delta <= 0.0: return
	if clock-_last > STALE+delta:
		reset()
		_gamma_was = gamma
	_last = clock
	# The signals, eased: heavy, so nothing snaps.
	_gamma_rate = lerpf(_gamma_rate,(gamma-_gamma_was)/delta,1.0-exp(-delta*4.0))
	_gamma_was = gamma
	var k := 1.0-exp(-delta*SIGNAL_EASE)
	climb = lerpf(climb,smoothstep(0.08,0.4,gamma),k)
	tuck = lerpf(tuck,smoothstep(TUCK_FROM,TUCK_FULL,-gamma),k)
	var pull := clampf(_gamma_rate/FLARE_RATE,0.0,1.0)*(1.0-smoothstep(FLARE_BELOW-0.1,FLARE_BELOW+0.1,gamma))
	flare = lerpf(flare,pull,1.0-exp(-delta*SIGNAL_EASE*1.5))
	turn = lerpf(turn,clampf(turning,-1.0,1.0),1.0-exp(-delta*TURN_EASE))
	var still := 1.0-flap_w
	beat_gain = 1.0+CLIMB_BEAT*climb
	# The beat's push: a pulse through the downstroke, a softer recovery
	# through the upstroke.
	var push := sin(PI*phase/down) if phase < down else -BEAT_RECOVER*sin(PI*(phase-down)/(1.0-down))
	push *= flap_w*beat_gain
	var heave := cos(TAU*phase)*flap_w*beat_gain
	var sway := GLIDE_SWAY*still*Vector2(sin(clock*TAU*GLIDE_SWAY_HZ*0.8+1.1),sin(clock*TAU*GLIDE_SWAY_HZ+0.4))
	# Each bone's own goal.
	var goal := {}
	goal["chest"] = Vector2(-BEAT_CHEST*push+CLIMB_CHEST*climb+TUCK_CHEST*tuck+FLARE_CHEST*flare+AIR_CHEST*air_pitch*still+sway.x,TURN_CHEST*turn+sway.y)
	goal["spine.2"] = Vector2(CLIMB_SPINE*climb,TURN_SPINE*turn)
	# The neck: neck.0 takes up the bob (dipping as the body rises), the
	# reach of a climb grows toward the head.
	var dip := -BOB_STEADY*bob/NECK_LENGTH
	for i in 4:
		var g := Vector2(CLIMB_NECK*climb*float(i+1)/4.0,TURN_NECK*turn)
		if i == 0: g.x += dip
		g.x += float(TUCK_NECK[i])*tuck
		goal["neck.%d" % i] = g
	goal["hips"] = Vector2(TUCK_HIPS*tuck-FLARE_HIPS*flare-sway.x*0.5,-TURN_HIPS*turn+AIR_RUDDER*air_roll*still-sway.y*1.5)
	# The chain, stepped in short steps (a frame may be long).
	var n := maxi(1,ceili(delta/(1.0/60.0)))
	var h := delta/float(n)
	for s in n:
		for link: Array in CHAIN:
			var b: String = link[0]
			var want: Vector2 = goal[b]
			if link[1] != "":
				var p: Vector2 = _x[link[1]]
				want += p*HIPS_FOLLOW if b == "hips" else p
			_x[b] = _spring(b,want,float(link[3]),float(link[4]),h)
		# The legs: the upper's swing (pitch, roll) and the knee.
		var lw := Vector3(LEG_HEAVE*heave+LEG_TUCK*tuck+LEG_FLARE*flare+LEG_CLIMB*climb,LEG_TURN*turn,0.0)
		var w1 := TAU*LEG_SPRING.x
		var w2 := TAU*KNEE_SPRING.x
		var acc := Vector3((lw.x-_leg_x.x)*w1*w1-2.0*LEG_SPRING.y*w1*_leg_v.x,(lw.y-_leg_x.y)*w1*w1-2.0*LEG_SPRING.y*w1*_leg_v.y,(LEG_KNEE*-_leg_x.x+LEG_TUCK_KNEE*tuck-_leg_x.z)*w2*w2-2.0*KNEE_SPRING.y*w2*_leg_v.z)
		_leg_v += acc*h
		_leg_x += _leg_v*h
	leg = _leg_x
	tail_curl = -TURN_TAIL*turn
	tail_droop = FLARE_HIPS*flare
	swell = BEAT_SWELL*maxf(push,0.0)+BREATH*sin(clock*TAU*BREATH_HZ)
	fold = TUCK_FOLD*tuck
	sweep = TUCK_SWEEP*tuck-FLARE_SWEEP*flare
	neck_s = lerpf(1.0,TUCK_NECK_S,tuck)
	head_level = lerpf(lerpf(1.0,CLIMB_LEVEL,climb),TUCK_LEVEL,tuck)
	# The head steady: it cancels the chain's sway as carried to it.
	head_steady = -(_x["neck.3"] as Vector2)*HEAD_STEADY

## A chain bone's turn (pitch, yaw; rad): its angle less its rig parent's.
func turn_of(b: String) -> Vector2:
	for link: Array in CHAIN:
		if link[0] != b: continue
		var x: Vector2 = _x[b]
		return x-(_x[link[1]] as Vector2) if link[2] else x
	return Vector2.ZERO

func _spring(b: String, want: Vector2, hz: float, damp: float, h: float) -> Vector2:
	var w := TAU*hz
	var x: Vector2 = _x[b]
	var v: Vector2 = _v[b]
	v += ((want-x)*w*w-v*2.0*damp*w)*h
	x += v*h
	_v[b] = v
	return x
