extends Node3D
## The pilot in the plane's cockpit (scripts/plane_figure.gd), alive in the
## seat like a kart racer's driver: chest up out of the cockpit in a leather
## jacket, the scarf wrapped at the neck, a faceted head in a leather cap and
## brass goggles, both gloved hands on the stick.
##
## Everything moves on springs, so it lags, overshoots a little and settles:
## the body leans into a turn and the head looks into it, levelling against
## the lean; a pull-up sinks them into the seat and a push lifts them; boost
## hunches them forward, the brake sits them back; the engine buzzes through
## them. The hands work the stick with the turn and climb. Left alone, every
## few seconds they do something: glance down at the land, look back over a
## shoulder, bob their head along, or wave back at whoever is following. In
## a barrel roll both arms go up.
##
## Built in the figure's frame: it sits at the seat, the nose along -Z.

const PersonKit = preload("res://scripts/person_kit.gd")
const Spring = PersonKit.Spring

## The seat in the figure's frame.
const SEAT := Vector3(0.0,0.11,0.24)
## Arms: the upper arm's and forearm's length, and where the hands hold
## the stick.
const ARM := Vector2(0.07,0.07)
const STICK := Vector3(0.022,0.05,-0.09)
## The head's size against the body.
const HEAD_SCALE := 0.9
## Seconds between idle moves, least and most.
const IDLE_EVERY := Vector2(2.5,6.0)

var _torso: Node3D
var _neck: Node3D
var _head: Node3D
## Per arm (left, right): the upper arm, the forearm and the hand.
var _arms := []
var _lean := Spring.new(2.2,0.35)
var _hunch := Spring.new(2.0,0.45)
var _twist := Spring.new(2.0,0.5)
var _bob := Spring.new(3.0,0.3)
var _yaw := Spring.new(2.6,0.45)
var _nod := Spring.new(3.0,0.4)
var _tilt := Spring.new(2.4,0.45)
## Each hand's offset from the stick, as springs (x, y, z per hand).
var _reach := []
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
## The idle move now: its name, seconds left in it, its look (yaw, nod) and
## which side it favours; and the seconds till the next.
var _idle := ""
var _idle_left := 0.0
var _idle_look := Vector2.ZERO
var _idle_next := 2.0

## `materials` is a PersonKit outfit.
func _init(materials: Dictionary) -> void:
	name = "Pilot"
	position = SEAT
	_rng.randomize()
	_idle_next = _rng.randf_range(IDLE_EVERY.x,IDLE_EVERY.y)
	_torso = Node3D.new()
	add_child(_torso)
	PersonKit.chest(_torso,materials)
	var pivots := PersonKit.head(_torso,materials,HEAD_SCALE)
	_neck = pivots[0]
	_head = pivots[1]
	# The arms, posed each frame from shoulder to hand.
	for side in [-1.0,1.0]:
		_arms.append(PersonKit.limb(_torso,Vector2(0.019,0.016),Vector2(0.016,0.014),materials.jacket,PersonKit.hand(),materials.leather))
		_reach.append([Spring.new(3.2,0.5),Spring.new(3.2,0.5),Spring.new(3.2,0.5)])
	animate(0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0)

## The scarf's knot in the figure's frame.
func knot() -> Vector3:
	return transform*(_torso.transform*PersonKit.KNOT)

## One frame: `bank` and `pitch` the flight's, `roll_rate` and `pitch_rate`
## how fast they change (rad/s), `throttle` -1 braking to 1 boosting,
## `spin` the barrel roll's angle, `engine` 0 to 1.
func animate(delta: float, bank: float, pitch: float, roll_rate: float, pitch_rate: float, throttle: float, spin: float, engine: float) -> void:
	_clock += delta
	_think(delta)
	var trick := absf(spin) > 0.05
	var look := _idle_look
	if trick: look = Vector2(0.0,0.35)
	# The body: leaning into the turn, hunched or sat back, sunk or lifted.
	var lean := _lean.step(clampf(-bank*0.45-roll_rate*0.04,-0.5,0.5),delta)
	var hunch := _hunch.step(clampf(-0.22*maxf(throttle,0.0)+0.12*maxf(-throttle,0.0)+pitch_rate*0.06,-0.35,0.25),delta)
	var twist := _twist.step(look.x*0.25,delta)
	var bob := _bob.step(clampf(-pitch_rate*0.012,-0.02,0.02),delta)
	var buzz := sin(_clock*37.0)*0.0012*engine
	_torso.position = Vector3(0.0,bob+buzz,0.0)
	_torso.rotation = Vector3(hunch,twist,lean)
	# The head: looking into the turn and at whatever the idle picked,
	# levelling against the body's lean, half the turn in the neck.
	var yaw := _yaw.step(clampf(-bank*0.9,-0.9,0.9)+look.x-twist,delta)
	var groove := sin(_clock*TAU*2.1)*0.12 if _idle == "groove" else 0.0
	var nod := _nod.step(look.y-hunch*0.6+groove,delta)
	var tilt := _tilt.step(-lean*0.7+(sin(_clock*TAU*1.05)*0.1 if _idle == "groove" else 0.0),delta)
	_neck.rotation = Vector3(nod*0.4,yaw*0.4,tilt*0.4)
	_head.rotation = Vector3(nod*0.6,yaw*0.6,tilt*0.6)
	# The hands: on the stick, which moves with the turn and the climb;
	# up for a trick; the right one waving.
	for s in range(2):
		var side := -1.0 if s == 0 else 1.0
		var target := STICK*Vector3(side,1.0,1.0)+Vector3(clampf(roll_rate*0.012,-0.02,0.02),0.0,clampf(-pitch_rate*0.03,-0.02,0.02))
		if trick: target = Vector3(0.11*side,0.25,-0.02)
		elif _idle == "wave" and side > 0.0: target = Vector3(0.12+sin(_clock*12.0)*0.03,0.24,-0.03)
		var springs: Array = _reach[s]
		var hand := Vector3((springs[0] as Spring).step(target.x,delta),(springs[1] as Spring).step(target.y,delta),(springs[2] as Spring).step(target.z,delta))
		PersonKit.pose(_arms[s],PersonKit.SHOULDER*Vector3(side,1.0,1.0),hand,ARM,Vector3(side,-0.6,0.4))

## Every few seconds an idle move: a glance down at the land, a look back
## over a shoulder, a head-bob, or a wave back at the follower.
func _think(delta: float) -> void:
	if _idle != "":
		_idle_left -= delta
		if _idle_left <= 0.0:
			_idle = ""
			_idle_look = Vector2.ZERO
			_idle_next = _rng.randf_range(IDLE_EVERY.x,IDLE_EVERY.y)
		return
	_idle_next -= delta
	if _idle_next > 0.0: return
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var pick := _rng.randf()
	if pick < 0.45:
		_idle = "glance"
		_idle_left = _rng.randf_range(0.8,1.8)
		_idle_look = Vector2(_rng.randf_range(0.5,1.2)*side,-_rng.randf_range(0.15,0.5))
	elif pick < 0.65:
		_idle = "look_back"
		_idle_left = _rng.randf_range(1.0,1.6)
		_idle_look = Vector2(1.9*side,0.1)
	elif pick < 0.85:
		_idle = "groove"
		_idle_left = _rng.randf_range(2.0,3.5)
		_idle_look = Vector2.ZERO
	else:
		_idle = "wave"
		_idle_left = 1.8
		_idle_look = Vector2(-1.9,0.15)
