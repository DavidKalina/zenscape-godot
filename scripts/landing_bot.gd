extends RefCounted
## The landing study's CPU pilot (studies/landing_study.gd B key,
## tools/landing_bench.gd): it fills the same input a person's keys do
## (turn, pitch, boost, brake, lean, flaps, exit), so its approaches go
## through the same rules (scripts/manual_landing.gd) and are measured the
## same way (scripts/landing_run.gd). No auto guidance helps it: it reads
## the field as a pilot would, from where the plane is.
##
## Approach: it holds the field's middle line by pure pursuit (a point
## `look` m on along it), steering its track over the ground (so in a
## crosswind it crabs), and holds its height until `descend_at` m out, then
## comes down a straight glide path fixed there, from where it is to its
## aim point (the station's touch spot, off by `aim` m along and `lateral`
## across, once per approach), never steeper than `steepest`. Its `pace`
## is how it comes in: "slow" (round 1's careful pilot: from `brake_at` m
## out it closes the throttle, and with flaps, `flaps` "never", "short" for
## fields under SHORT m, "always", lowers them), "cruise" (no brake, no
## flaps: in hot), "boost" (Boost held to the flare: in very hot) or
## "dive" (round 3: straight down a steep line at the near rim from where it
## starts, no flare; a skill whose `flare` is PULL_SKILL or more pulls out
## of it PULL_OUT m over its aim, to a hot shallow touch, and the rest slam
## and bounce, and come in again slow). Within
## `flare` m of the land it eases the sink off to FLARE_SINK, unless this
## approach it forgets to (chance `flare_miss`), or it is in hot, aiming
## RIM m in from the near rim and slamming the wheels on; its throttle closes
## `brake_jitter` m (gaussian, once per approach) off `brake_at`. Its stick
## wanders by `noise` (a slow random drift) and `gain` is how hard it
## corrects.
##
## On the wheels, after `brake_delay` s, it reads the land ahead along the
## way it is going (ManualLanding `edge_margin`) and how far a straight
## brake would take, misjudged by `judge` (under 1 thinks it needs less).
## With room to spare it brakes straight (`ground_brake` of full) along the
## line. Without, it power-slides: the brakes on and the stick hard over to
## the side with more room, and with `blip` s of throttle (INF: held) to
## swing the tail right round; `slide_let` is the chance it lets the stick
## go too soon in one. Stopped, it asks to get out after `exit_delay` s.
##
## Going round: after a hop with too little field left ahead, a roll off
## the edge, the field's end passed in the air, or arriving too far off the
## line, it opens the throttle, climbs to CIRCUIT m over the field and
## flies a circuit (past the far end, out to the side, back down the side,
## onto a long final) before coming in again, slow (a hot pilot sobered by
## a go-around).

const SkyPlane = preload("res://scripts/sky_plane.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const Course = preload("res://scripts/landing_course.gd")

const VERSION := 3
const SKILLS := {
	"sloppy":{"noise":0.16,"drift":0.5,"gain":1.8,"look":10.0,"descend_at":75.0,"steepest":0.42,"brake_at":40.0,"flaps":"never","flare":0.5,"aim":6.0,"lateral":1.6,"flare_miss":0.5,"brake_jitter":20.0,
		"ground_brake":0.6,"brake_delay":1.0,"exit_delay":0.8,"judge":0.7,"blip":0.0,"slide_let":0.3},
	"decent":{"noise":0.07,"drift":0.5,"gain":2.4,"look":12.0,"descend_at":110.0,"steepest":0.3,"brake_at":110.0,"flaps":"never","flare":1.2,"aim":3.0,"lateral":0.7,"flare_miss":0.15,"brake_jitter":10.0,
		"ground_brake":1.0,"brake_delay":0.4,"exit_delay":0.5,"judge":0.9,"blip":0.25,"slide_let":0.1},
	"sharp":{"noise":0.03,"drift":0.5,"gain":3.0,"look":14.0,"descend_at":150.0,"steepest":0.24,"brake_at":150.0,"flaps":"short","flare":1.5,"aim":1.5,"lateral":0.3,"flare_miss":0.03,"brake_jitter":5.0,
		"ground_brake":1.0,"brake_delay":0.15,"exit_delay":0.3,"judge":1.05,"blip":INF,"slide_let":0.0},
	"perfect":{"noise":0.0,"drift":0.5,"gain":3.2,"look":14.0,"descend_at":INF,"steepest":0.24,"brake_at":170.0,"flaps":"always","flare":1.6,"aim":0.0,"lateral":0.0,"flare_miss":0.0,"brake_jitter":0.0,
		"ground_brake":1.0,"brake_delay":0.0,"exit_delay":0.2,"judge":1.15,"blip":INF,"slide_let":0.0},
}
const SKILL_NAMES := ["sloppy","decent","sharp","perfect"]
const PACES := ["slow","cruise","boost","dive"]

## The sink it flares to (m/s), fields shorter than SHORT m take flaps under "short", the
## circuit's height over the field and its legs (m), and how close a
## circuit point must come before the next (m).
const FLARE_SINK := 0.5
const SHORT := 40.0
const CIRCUIT := 22.0
const UPWIND := 50.0
const ABEAM := 70.0
const FINAL := 170.0
const REACH := 22.0
## On the wheels: the room it wants left at the stop (m).
const SPARE := 3.0
## In hot it aims this far in from the near rim (m), and doesn't flare.
const RIM := 1.5
## Boost closes this far over the land (m) on a boost approach.
const BOOST_TILL := 3.0
## On a dive: how far in from the near rim it aims (m), the steepest line
## it takes (m down per m on), the skill's `flare` that pulls out, how high
## over the aim it starts to (m), and the path it pulls out to (radians,
## nose down).
const DIVE_IN := 10.0
const DIVE_STEEPEST := 1.5
const PULL_SKILL := 1.5
const PULL_OUT := 9.0
const PULL_TO := 0.12

var skill := {}
var pace := "slow"
var rng := RandomNumberGenerator.new()
## "approach", "around" or "ground"; the circuit's points and the next.
var mode := "approach"
var _circuit: Array[Vector3] = []
var _next := 0
## This approach's aim, off the touch spot (m along, m across), whether it
## flares, and where it closes the throttle (m out).
var _aim := Vector2.ZERO
var _flares := true
var _brake_at := 0.0
## The glide path's slope (m down per m on), fixed as the descent begins.
var _slope := NAN
## The stick's wander (turn, pitch), where it heads and when it next turns.
var _wander := Vector2.ZERO
var _wander_to := Vector2.ZERO
var _wander_clock := 0.0
var _ground_time := 0.0
var _stopped_time := 0.0
## On the wheels: power-sliding (the side, -1 left, 1 right; 0 not), for
## how long, and whether this one is let go too soon (at what second).
var _sliding := 0.0
var _slide_time := 0.0
var _let_at := INF

static func params(name: String) -> Dictionary:
	return SKILLS.get(name,SKILLS.decent)

func _init(with: Dictionary, seed := 0, how := "slow") -> void:
	skill = with
	pace = how
	rng.seed = seed
	_new_aim()

func _new_aim() -> void:
	_aim = Vector2(rng.randfn(0.0,float(skill.get("aim",0.0))),rng.randfn(0.0,float(skill.get("lateral",0.0))))
	_slope = NAN
	_flares = rng.randf() >= float(skill.get("flare_miss",0.0))
	_brake_at = maxf(10.0,float(skill.brake_at)+rng.randfn(0.0,float(skill.get("brake_jitter",0.0))))

## The input for this tick, flying `run` (scripts/landing_run.gd).
func input(run: RefCounted, delta: float) -> Dictionary:
	var plane: RefCounted = run.plane
	var ml: RefCounted = run.ml
	var s: Dictionary = run.station
	_drift(delta)
	var out := {"turn":0.0,"pitch":0.0,"look":Vector2.ZERO,"boost":0.0,"brake":0.0,"lean":0.0,"roll":0.0,"flaps":0.0,"exit":false}
	if ml.on_ground():
		mode = "ground"
		return _on_ground(run,delta,out)
	if mode == "ground":
		# Back in the air off the wheels (an edge, a touch-and-go): round.
		_go_round(s)
	var last: Dictionary = run.last
	var touch := Course.touch_at(s)+Vector3(_aim.y,0.0,-_aim.x)
	# In hot, it aims to slam the wheels on at the near rim.
	if pace != "slow": touch = Course.origin(s)+Vector3(_aim.y,float((s.touch as Vector3).y),-RIM-absf(_aim.x)*0.5-(DIVE_IN if pace == "dive" else 0.0))
	var d := Course.way()
	var p: Vector3 = plane.position
	var along := (Vector2(touch.x,touch.z)-Vector2(p.x,p.z)).dot(d)
	var across := (p.x-touch.x)*(-d.y)+(p.z-touch.z)*d.x
	if mode == "approach":
		var past_end := along < -(float(s.length)+(s.touch as Vector3).z)
		var off_line := along < 12.0 and along > -2.0 and absf(across) > float(s.width)*0.5+1.0
		if last.has("bounce"):
			# Shaken: it flares the next one, down a fresh path, and a diver
			# comes in slow.
			_flares = true
			_slope = NAN
			if pace == "dive": pace = "slow"
		if last.has("bounce") and _room_left(run) < 18.0: _go_round(s)
		elif last.has("off_edge") or past_end or off_line: _go_round(s)
	if mode == "around": return _around(run,out)
	# Lined up on the middle line by pure pursuit.
	var carrot := Vector2(touch.x,touch.z)+d*(-along+float(skill.look))
	out.turn = _steer(plane,carrot)
	# Down a line to the aim, flaring over the land.
	var land := Course.floor_at(Vector2(p.x,p.z))
	var aim_y := float(Course.floor_at(Vector2(touch.x,touch.z)))+SkyPlane.SKIM
	var want := clampf((Course.start_at(s,run.approach).y-p.y)*0.05,-0.1,0.1)
	if along <= float(skill.descend_at) or pace != "slow" and along <= 120.0:
		# The glide path, fixed as the descent begins: straight down it to
		# the ground, unless it flares.
		if is_nan(_slope): _slope = clampf((p.y-aim_y)/maxf(along,6.0),0.03,DIVE_STEEPEST if pace == "dive" else float(skill.steepest))
		var line := aim_y+_slope*along
		want = -(atan(_slope) if pace == "dive" else _slope)+clampf((line-p.y)*0.08,-0.12,0.12)
	var over := p.y-land-SkyPlane.SKIM if not is_nan(land) else INF
	if _flares and pace == "slow" and over < float(skill.flare):
		var speed := maxf(float(plane.speed),1.0)
		want = -FLARE_SINK/speed
	# A dive pulled out of in time, by a skill that can.
	if pace == "dive" and float(skill.flare) >= PULL_SKILL and p.y-aim_y < PULL_OUT: want = -PULL_TO
	out.pitch = _pitch(plane,want)
	match pace:
		"slow":
			if along < _brake_at: out.brake = 1.0
			var flaps := str(skill.flaps)
			if along < _brake_at and not s.has("wind") and (flaps == "always" or flaps == "short" and float(s.length) < SHORT): out.flaps = 1.0
		"boost":
			var high := p.y-(land if not is_nan(land) else aim_y-SkyPlane.SKIM)
			if high > BOOST_TILL or along > 20.0: out.boost = 1.0
	return out

## How much field is left ahead of the plane (m).
func _room_left(run: RefCounted) -> float:
	var o := Course.origin(run.station)
	var p: Vector3 = run.plane.position
	return float(run.station.length)-(o.z-p.z)

func _go_round(s: Dictionary) -> void:
	mode = "around"
	pace = "slow"
	var touch := Course.touch_at(s)
	var d := Course.way()
	var far := Course.origin(s)+Vector3(d.x,0.0,d.y)*(float(s.length)+UPWIND)
	var side := Vector3(1.0,0.0,0.0)
	var y := touch.y+CIRCUIT
	far.y = y
	_circuit = [far,far+side*ABEAM,Course.origin(s)-Vector3(d.x,0.0,d.y)*(FINAL*0.8)+side*ABEAM+Vector3.UP*y,
		Course.origin(s)-Vector3(d.x,0.0,d.y)*FINAL+Vector3.UP*y]
	_next = 0

## Round the circuit, climbing to its height; at its end, in again.
func _around(run: RefCounted, out: Dictionary) -> Dictionary:
	var plane: RefCounted = run.plane
	var p: Vector3 = plane.position
	var to: Vector3 = _circuit[_next]
	if Vector2(to.x-p.x,to.z-p.z).length() < REACH:
		_next += 1
		if _next >= _circuit.size():
			mode = "approach"
			_new_aim()
			return input(run,0.0)
		to = _circuit[_next]
	out.turn = _steer(plane,Vector2(to.x,to.z))
	out.pitch = _pitch(plane,clampf((to.y-p.y)*0.04,-0.12,0.22))
	out.boost = 1.0 if p.y < to.y-4.0 or float(plane.speed) < 11.0 else 0.0
	return out

## On the wheels: after the delay, a straight brake if there is room, else
## a power-slide to the side with more; stopped, out.
func _on_ground(run: RefCounted, delta: float, out: Dictionary) -> Dictionary:
	var plane: RefCounted = run.plane
	var ml: RefCounted = run.ml
	_ground_time += delta
	var o := Course.origin(run.station)
	var p: Vector3 = plane.position
	if ml.can_exit():
		_sliding = 0.0
		_stopped_time += delta
		if _stopped_time >= float(skill.exit_delay): out.exit = true
		return out
	var speed: float = ml.roll_speed()
	var at := Vector2(p.x,p.z)
	var way: Vector2 = run.going()
	if _ground_time < float(skill.brake_delay):
		out.turn = _steer(plane,Vector2(o.x,p.z-8.0))*0.5
		return out
	if _sliding == 0.0:
		var floor := Callable(Course,"floor_at")
		var room := ManualLanding.edge_margin(floor,at,way)
		var straight := speed*speed/(2.0*(ManualLanding.ROLL_DRAG+ManualLanding.WHEEL_BRAKE*float(skill.ground_brake)))
		if straight*float(skill.judge)+SPARE > room and speed > ManualLanding.POWER_MIN+1.0:
			var right := Vector2(-way.y,way.x)
			var room_right := ManualLanding.edge_margin(floor,at,right)
			var room_left := ManualLanding.edge_margin(floor,at,-right)
			# The path bends towards the nose: the stick to the roomier side.
			_sliding = 1.0 if room_right >= room_left else -1.0
			_slide_time = 0.0
			_let_at = rng.randf_range(0.3,0.9) if rng.randf() < float(skill.slide_let) else INF
	if _sliding != 0.0:
		_slide_time += delta
		out.brake = 1.0
		out.turn = _sliding if _slide_time < _let_at else 0.0
		out.boost = 1.0 if _slide_time < float(skill.blip) else 0.0
		return out
	out.brake = float(skill.ground_brake)
	out.turn = _steer(plane,Vector2(o.x,p.z-8.0))*0.5
	return out

## The turn that brings the track over the ground round to `at` (global
## XZ): the way it goes, wind and all, so in a crosswind it crabs.
func _steer(plane: RefCounted, at: Vector2) -> float:
	var to := at-Vector2(plane.position.x,plane.position.z)
	if to.length() < 0.01: return 0.0
	var v: Vector3 = plane.velocity
	var track := atan2(-v.x,-v.z) if Vector2(v.x,v.z).length() > 2.0 else float(plane.heading)
	var err := angle_difference(track,atan2(-to.x,-to.y))
	return clampf(-err*float(skill.gain)+_wander.x,-1.0,1.0)

## The pitch input that brings the path to `want` radians: it works on
## the climb or sink (so flaps' extra sink is flown out, as a pilot does).
func _pitch(plane: RefCounted, want: float) -> float:
	var speed := maxf(float(plane.speed),1.0)
	var err := want*speed-float(plane.velocity.y)
	return clampf(err*float(skill.gain)*0.25-float(plane.pitch-want)*0.3+_wander.y,-1.0,1.0)

## The stick's slow random wander.
func _drift(delta: float) -> void:
	var noise := float(skill.get("noise",0.0))
	if noise <= 0.0: return
	_wander_clock -= delta
	if _wander_clock <= 0.0:
		_wander_clock = float(skill.get("drift",0.5))
		_wander_to = Vector2(rng.randfn(0.0,noise),rng.randfn(0.0,noise*0.5))
	_wander = _wander.lerp(_wander_to,1.0-exp(-delta/0.2))
