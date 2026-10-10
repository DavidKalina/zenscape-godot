extends RefCounted
## The pilot's drawn height on steps: smooth up and down a stair, where the
## motor's feet (scripts/pilot_motor.gd) stand on each tread in turn and pop
## a riser at a time. The figure and the camera follow `lift` over the feet
## instead, so neither shakes on a stair; the motor, its routes and its
## replays are untouched (this only draws).
##
## Two parts. Moving on the ground, the height aimed for is the ground's
## averaged along the way he goes (a triangle FILTER metres either side of
## the feet, SAMPLES rays): over a stair that is a ramp through its treads'
## middles, risen into before the riser (no lag behind it), and over a
## plane or a slope it is the ground itself. Samples off the ground's
## reach (a wall's face, a drop over STEP_UP) count as the feet's own, so a
## ledge or a wall never pulls him. Off the ground (jumping, falling,
## swimming, on a ledge) it is the feet. The height drawn follows that aim
## on a critically damped spring (SPRING s) told the aim's own rate too
## (eased over RATE_EASE s on the ground, the motor's in the air), so it
## keeps up with a stair's ramp or a jump without lagging, never jumps,
## and never strays more than MOST from the feet.
const PilotMotor = preload("res://scripts/pilot_motor.gd")

## The averaging's reach either side of the feet at a run (m: a stair's
## tread), how many rays, and how fast he goes for the full reach (m/s;
## slower, it narrows, to none standing still).
const FILTER := 0.5
const SAMPLES := 13
const FULL_AT := 2.0
## The spring's time (s), the easing of the aim's rate on the ground (s),
## the most the drawn height strays from the feet (m).
const SPRING := 0.04
const RATE_EASE := 0.06
const MOST := 0.3

## Off, the figure and the camera are drawn at the feet (to compare).
var on := true
## The drawn height over the feet (m, up).
var lift := 0.0
var _y := INF
var _rate := 0.0
var _aim := INF
var _aim_rate := 0.0

## Back to the feet (set down, respawned).
func reset() -> void:
	lift = 0.0
	_y = INF
	_rate = 0.0
	_aim = INF
	_aim_rate = 0.0

## One frame: `motor` after its step, `ground` its ground (Callable(Vector2)
## -> float). Returns `lift`.
func step(motor: PilotMotor, ground: Callable, delta: float) -> float:
	var feet := motor.feet
	if not on or delta <= 0.0 or not is_finite(_y):
		reset()
		_y = feet.y
		_aim = feet.y
		return lift
	var grounded := motor.grounded and not motor.on_ledge() and not motor.swimming
	var aim := feet.y
	if grounded:
		var way := Vector2(motor.velocity.x,motor.velocity.z)
		var reach := FILTER*clampf(way.length()/FULL_AT,0.0,1.0)
		if reach > 0.02 and ground.is_valid():
			way = way.normalized()
			var at := Vector2(feet.x,feet.z)
			var sum := 0.0
			var weight := 0.0
			var half := (SAMPLES-1)/2
			for i in range(SAMPLES):
				var u := float(i-half)/half
				var w := 1.0-absf(u)*0.85
				var h: float = ground.call(at+way*u*reach)
				if not is_finite(h) or absf(h-feet.y) > PilotMotor.STEP_UP+0.05: h = feet.y
				sum += h*w
				weight += w
			aim = sum/weight
		var rate := (aim-_aim)/delta if is_finite(_aim) else 0.0
		_aim_rate = lerpf(_aim_rate,clampf(rate,-8.0,8.0),1.0-exp(-delta/RATE_EASE))
	else:
		_aim_rate = motor.velocity.y
	_aim = aim
	# The spring, in small steps, the aim carried on at its rate.
	var omega := 1.0/SPRING
	var left := minf(delta,0.1)
	var goal := aim-_aim_rate*left
	while left > 0.0:
		var dt := minf(left,1.0/120.0)
		goal += _aim_rate*dt
		_rate += (omega*omega*(goal-_y)+2.0*omega*(_aim_rate-_rate))*dt
		_y += _rate*dt
		left -= dt
	if absf(_y-feet.y) > MOST:
		_y = feet.y+clampf(_y-feet.y,-MOST,MOST)
		_rate = _aim_rate
	lift = _y-feet.y
	return lift
