extends RefCounted
## The storm's gust front in the sound (docs/design/endless-flight/spec-
## storm-front.md, lane gust): a roar that rises as the band reaches the eye
## and holds, lower, under the core. Two beds on FlightSound's Ambience bus
## (it steps them with its own): the howl (kit/air-howl-loop) pitched with
## the wind and the wind bed (wind-bed) pitched down to a deep rush; a
## rumble of the band coming, heard before it arrives; and slams
## (kit/wind-slam-1/2) on the squalls, every few seconds in the thick of it.
## Built only with a storm (study.storm); reads StormFront on the CPU.

const FlightSound = preload("res://scripts/endless/flight_sound.gd")

## The roar's gains at full wind (linear), the slams' gain, and how far
## ahead toward the storm (m) the band is heard coming.
const ROAR := 0.85
const RUSH := 0.75
const SLAM := 0.55
const HEAR_AHEAD := 350.0
## The wind under the core, as a share of the storm's amount.
const UNDER := 0.45
## Seconds between slams at full wind (more apart as it eases).
const SLAM_EVERY := Vector2(1.8,4.5)

var storm: RefCounted
var sound: Node
var roar: RefCounted
var rush: RefCounted
## The wind at the eye now (0..1), for a look.
var wind := 0.0
var _slam_wait := 2.0
var _rng := RandomNumberGenerator.new()

func _init(storm_front: RefCounted, flight_sound: Node) -> void:
	storm = storm_front
	sound = flight_sound
	_rng.randomize()
	roar = sound._bed(FlightSound.KIT+"air-howl-loop.wav",FlightSound.AMBIENCE)
	rush = sound._bed(FlightSound.OLD+"wind-bed.wav",FlightSound.AMBIENCE)
	for bed: RefCounted in [roar,rush]:
		bed.attack = 0.8
		bed.release = 0.5
	sound._clips["storm_slam"] = FlightSound._takes(FlightSound.KIT+"wind-slam-%d.wav",2)

## One frame at the eye (the camera).
func step(delta: float, eye: Vector3) -> void:
	var q := Vector2(eye.x,eye.z)
	wind = maxf(float(storm.gust_at(q)),UNDER*float(storm.amount_at(q)))
	# The band coming: its roar heard over the land before it arrives.
	var coming := float(storm.gust_at(q-storm.heading()*HEAR_AHEAD))*0.35
	var w := maxf(wind,coming)
	roar.goal = ROAR*pow(w,1.4)
	roar.pitch_goal = 0.7+0.4*w
	rush.goal = RUSH*w
	rush.pitch_goal = 0.55+0.3*w
	_slam_wait -= delta
	if _slam_wait <= 0.0:
		_slam_wait = lerpf(SLAM_EVERY.y,SLAM_EVERY.x,wind)*_rng.randf_range(0.7,1.3)
		if wind > 0.3: sound.shot("storm_slam",SLAM*wind,_rng.randf_range(0.75,1.0),Vector3.INF,FlightSound.AMBIENCE)
