extends Node3D
## An islander, standing on their land: one of the sky folk, like the
## pilot in the plane (scripts/plane_pilot.gd, the same parts from
## scripts/person_kit.gd), head to boots: the leather cap and brass
## goggles, the jacket and the scarf, its two short tails hanging behind,
## canvas trousers belted with brass, and boots.
##
## Like the pilot it moves on springs, so it lags, overshoots a little and
## settles. Its moves (`play`):
##   idle  breathing, swaying its weight, now and then looking about;
##   wave  one arm up over the head waving, bouncing with it, looking up;
##   jump  jumping on the spot: a crouch, the spring up with arms flung up
##         and feet tucked, a squashing landing, again;
##   hail  jumping with both arms waving crossed over the head, looking up:
##         the call to a plane passing over;
##   walk  a quick, bouncy toddle on the spot: short steps, feet lifting,
##         bobbing up on every step, waddling foot to foot with the hips
##         turning and the arms swinging stiffly against the legs. Moved at
##         WALK_SPEED the boots stay planted on the ground.
## Driven from outside (the pilot on foot, scripts/pilot_figure.gd):
##   run   the walk sped up to a run as `pace` goes 0 to 1: longer strides,
##         knees and arms pumping, leaning into it; the steps kept to
##         `speed` (units a second it is moved at), so the boots plant;
##   air   in a jump: rising (`rise` 1), a fist thrown up and a knee tucked;
##         falling (`rise` -1), arms out and the legs reaching for the
##         ground; `knees_up` pulls both knees up, for a flip;
##   skid  leaning back on its heels, arms thrown forward.
## `land` squashes it as hard as it came down.
## The scarf's tails lift as it falls and swing as it lands.
##
## Built at the pilot's size, its boots on its origin, facing -Z: scale it
## to stand in the world.

const PersonKit = preload("res://scripts/person_kit.gd")
const Spring = PersonKit.Spring
const MOVES := ["idle","wave","jump","hail","walk","run","air","skid"]
## Scaled to stand in the sky (the clusters' folk, scripts/cluster_dresser.gd,
## and the airships' crews, scripts/sky_airship.gd): its eyes at the
## wanderer's height. And the scarves they wear, picked by seed.
const SKY_SCALE := 1.9
const SCARVES := [Color("d9573a"),Color("e2b84a"),Color("6f8fa8"),Color("7fa08a"),Color("cf6b4a"),Color("b85c7a")]
## The hips over the ground standing, the hip joints on them, the feet's
## stance, the leg bones' lengths and the arm bones'.
const HIPS := 0.17
const HIP := Vector3(0.042,0.0,0.0)
const STANCE := Vector3(0.05,0.0,0.0)
const LEG := Vector2(0.09,0.088)
const ARM := Vector2(0.085,0.08)
## The boot's sole under its ankle.
const ANKLE := 0.024
## A jump: seconds a hop, the share of it crouching, in the air and
## landing, and its height; a hail hops quicker and lower.
const JUMP := {"every":0.95,"crouch":0.2,"air":0.42,"land":0.18,"height":0.11}
const HAIL := {"every":0.8,"crouch":0.18,"air":0.44,"land":0.18,"height":0.07}
## The scarf's tails: segments a tail, each one's length.
const TAIL := 3
const TAIL_LENGTH := 0.036
## The walk: seconds a full step cycle (both feet), a stride's length, how
## high a foot lifts, how far the body bobs, waddles and turns, the arms'
## swing, the forward lean; and the speed (units a second) a figure
## walking should be moved at.
const STEP_CYCLE := 0.72
const STRIDE := 0.07
const STEP_LIFT := 0.028
const BOB := 0.013
const WADDLE := Vector2(0.007,0.06)
const TWIST := 0.12
const SWING := 0.05
const STOOP := -0.08
const WALK_SPEED := 2.0*STRIDE/STEP_CYCLE
## The run at full pace: its stride, the foot's lift, the bob, the lean
## and the arms' pump; and the most step cycles a second, past which the
## boots skid a little rather than whirr.
const RUN_STRIDE := 0.16
const RUN_CADENCE := 4.2
const RUN_LIFT := 0.06
const RUN_BOB := 0.02
const RUN_STOOP := -0.32
const RUN_SWING := 0.085
## Seconds between idle looks, least and most.
const LOOK_EVERY := Vector2(2.5,6.0)

## The move now (one of MOVES) and seconds into it.
var move := "idle"
var _t := 0.0
var _clock := 0.0
var _hips: Node3D
var _torso: Node3D
var _neck: Node3D
var _head: Node3D
## Per side (left, right): the arm's and the leg's [upper, lower, end].
var _arms := []
var _legs := []
## Per hand, springs for x, y, z of where it reaches (torso frame).
var _reach := []
## Per tail, the segments' pivots and their swing springs.
var _tails := []
var _swings := []
var _yaw := Spring.new(2.4,0.45)
var _nod := Spring.new(2.8,0.4)
var _tilt := Spring.new(2.4,0.45)
var _lean := Spring.new(2.2,0.4)
var _sway := Spring.new(1.6,0.5)
var _lift_was := 0.0
var _rise := 0.0
var _rng := RandomNumberGenerator.new()
var _look := Vector2.ZERO
var _look_left := 0.0
var _look_next := 2.0
## What drives `run` and `air` (see the moves above).
var pace := 0.0
var speed := 0.0
var rise := 0.0
var knees_up := 0.0
var _stride_phase := 0.0
var _squash := Spring.new(3.2,0.3)
var _impact := 0.0

## `scarf` colours the scarf.
func _init(scarf := PersonKit.SCARF) -> void:
	name = "Islander"
	_rng.randomize()
	var m := PersonKit.outfit(scarf)
	_hips = Node3D.new()
	_hips.position = Vector3(0.0,HIPS,0.0)
	add_child(_hips)
	# The hips in canvas, belted, a brass buckle.
	PersonKit.part(_hips,PersonKit.FacetMesh.hull([Vector3(-0.03,0.06,0.045),Vector3(0.0,0.072,0.052),Vector3(0.035,0.07,0.055)],8),m.trousers,Vector3.ZERO,Vector3(-PI*0.5,0.0,0.0))
	PersonKit.part(_hips,PersonKit.GliderFigure._frustum(0.075,0.075,0.014,8),m.strap,Vector3(0.0,0.03,0.0),Vector3.ZERO,Vector3(1.0,1.0,0.78))
	PersonKit.part(_hips,PersonKit.GliderFigure._gem(0.011),m.brass,Vector3(0.0,0.03,-0.058),Vector3.ZERO,Vector3(1.3,1.0,0.6))
	_torso = Node3D.new()
	_torso.position = Vector3(0.0,0.025,0.0)
	_hips.add_child(_torso)
	PersonKit.chest(_torso,m)
	var pivots := PersonKit.head(_torso,m)
	_neck = pivots[0]
	_head = pivots[1]
	for side in [-1.0,1.0]:
		_arms.append(PersonKit.limb(_torso,Vector2(0.02,0.017),Vector2(0.017,0.015),m.jacket,PersonKit.hand(),m.leather))
		_legs.append(PersonKit.limb(self,Vector2(0.03,0.026),Vector2(0.025,0.021),m.trousers,PersonKit.boot(),m.boots))
		_reach.append([Spring.new(4.0,0.45),Spring.new(4.0,0.45),Spring.new(4.0,0.45)])
		# A scarf tail from the knot, in hinged strips.
		var pivot: Node3D = _torso
		var at := PersonKit.KNOT+Vector3(0.011*side,-0.004,0.0)
		var tail := []
		var swings := []
		for i in range(TAIL):
			var segment := Node3D.new()
			segment.position = at
			pivot.add_child(segment)
			PersonKit.part(segment,PersonKit.GliderFigure._frustum(0.017-i*0.002,0.015-i*0.002,TAIL_LENGTH,4),m.scarf,Vector3(0.0,-TAIL_LENGTH*0.5,0.0),Vector3.ZERO,Vector3(1.0,1.0,0.3))
			tail.append(segment)
			swings.append(Spring.new(2.6-i*0.4,0.25))
			pivot = segment
			at = Vector3(0.0,-TAIL_LENGTH,0.0)
		_tails.append(tail)
		_swings.append(swings)
	advance(0.0)

## Came down `hard` metres a second: a squash that springs back.
func land(hard: float) -> void:
	_impact = clampf(hard/9.0,0.0,1.0)

## Starts a move, one of MOVES.
func play(next: String) -> void:
	if not (next in MOVES) or next == move: return
	move = next
	_t = 0.0

func _process(delta: float) -> void:
	advance(delta)

## One frame of the move.
func advance(delta: float) -> void:
	_t += delta
	_clock += delta
	var breathe := sin(_clock*TAU*0.25)
	var lift := 0.0
	var crouch := 0.0
	var tuck := 0.0
	var squash := 0.0
	var look := Vector2.ZERO
	var lean := 0.0
	var hands := [Vector3(-0.1,-0.03,0.01),Vector3(0.1,-0.03,0.01)]
	var w := _t*TAU*2.2
	var steps := [Vector3.ZERO,Vector3.ZERO]
	var toes := [0.0,0.0]
	var bob := 0.0
	var waddle := 0.0
	var roll := 0.0
	var twist := 0.0
	var stoop := 0.0
	match move:
		"idle":
			_think(delta)
			look = _look
			hands[0] += Vector3(0.0,breathe*0.004,0.0)
			hands[1] += Vector3(0.0,breathe*0.004,0.0)
		"wave":
			hands[1] = Vector3(0.11+sin(w)*0.045,0.25,-0.03)
			crouch = absf(sin(w*0.5))*0.012
			lean = -0.07
			look = Vector2(0.0,0.3)
		"jump", "hail":
			var hop: Dictionary = JUMP if move == "jump" else HAIL
			var p := fmod(_t,float(hop.every))/float(hop.every)
			var c := float(hop.crouch)
			var a := float(hop.air)
			var l := float(hop.land)
			if p < c:
				crouch = 0.045*smoothstep(0.0,1.0,p/c)
				squash = -0.5*p/c
			elif p < c+a:
				var s := (p-c)/a
				lift = 4.0*float(hop.height)*s*(1.0-s)
				tuck = 0.03*sin(PI*s)
				squash = 1.0-s*1.4
			elif p < c+a+l:
				var s := (p-c-a)/l
				crouch = 0.04*sin(PI*s)
				squash = -sin(PI*s)
			if move == "jump":
				var up := p >= c*0.7 and p < c+a
				hands = [Vector3(-0.09,0.26,-0.02),Vector3(0.09,0.26,-0.02)] if up else [Vector3(-0.1,-0.01,0.06),Vector3(0.1,-0.01,0.06)]
				look = Vector2(0.0,0.15 if up else -0.1)
			else:
				var x := 0.06-0.07*sin(w)
				hands = [Vector3(-x,0.27,-0.03),Vector3(x,0.27,-0.03)]
				look = Vector2(0.0,0.35)
		"walk":
			# Each foot: half the cycle planted, sliding back under the body
			# as it moves on, half swinging forward, lifted, toe up.
			var phase := fmod(_t/STEP_CYCLE,1.0)
			for f in range(2):
				var q := fmod(phase+0.5*f,1.0)
				if q < 0.5:
					steps[f] = Vector3(0.0,0.0,-STRIDE*0.5+STRIDE*q/0.5)
				else:
					var u := (q-0.5)/0.5
					steps[f] = Vector3(0.0,STEP_LIFT*sin(PI*u),STRIDE*0.5-STRIDE*smoothstep(0.0,1.0,u))
					toes[f] = 0.3*sin(PI*u)
			var beat := sin(PI*fmod(phase*2.0,1.0))
			var gait := phase*TAU
			bob = BOB*beat
			squash = 0.4*(beat-0.5)
			waddle = -WADDLE.x*sin(gait)
			roll = WADDLE.y*sin(gait)
			twist = -TWIST*cos(gait)
			stoop = STOOP
			hands = [Vector3(-0.095,-0.02,SWING*cos(gait)),Vector3(0.095,-0.02,-SWING*cos(gait))]
			look = Vector2(0.0,0.05)
		"run":
			var k := clampf(pace,0.0,1.0)
			var stride := lerpf(STRIDE,RUN_STRIDE,k)
			_stride_phase = fmod(_stride_phase+minf(speed/(2.0*stride),RUN_CADENCE)*delta,1.0)
			var phase := _stride_phase
			var foot_lift := lerpf(STEP_LIFT,RUN_LIFT,k)
			for f in range(2):
				var q := fmod(phase+0.5*f,1.0)
				if q < 0.5:
					steps[f] = Vector3(0.0,0.0,-stride*0.5+stride*q/0.5)
				else:
					var u := (q-0.5)/0.5
					steps[f] = Vector3(0.0,foot_lift*sin(PI*u),stride*0.5-stride*smoothstep(0.0,1.0,u))
					toes[f] = 0.3*sin(PI*u)
			var beat := sin(PI*fmod(phase*2.0,1.0))
			var gait := phase*TAU
			bob = lerpf(BOB,RUN_BOB,k)*beat
			squash = 0.4*(beat-0.5)
			waddle = -WADDLE.x*(1.0-k)*sin(gait)
			roll = WADDLE.y*(1.0-0.6*k)*sin(gait)
			twist = -lerpf(TWIST,TWIST*1.4,k)*cos(gait)
			stoop = lerpf(STOOP,RUN_STOOP,k)
			var swing := lerpf(SWING,RUN_SWING,k)
			var bent := lerpf(-0.02,0.02,k)
			hands = [Vector3(-0.095,bent,swing*cos(gait)-0.02*k),Vector3(0.095,bent,-swing*cos(gait)-0.02*k)]
			look = Vector2(0.0,0.05+0.1*k)
		"air":
			var up := clampf(rise*0.5+0.5,0.0,1.0)
			var rising := [Vector3(-0.1,-0.02,0.07),Vector3(0.07,0.28,-0.02)]
			var falling := [Vector3(-0.15,0.09,0.0),Vector3(0.15,0.09,0.0)]
			hands = [(falling[0] as Vector3).lerp(rising[0],up),(falling[1] as Vector3).lerp(rising[1],up)]
			# One knee up rising; both reaching down falling; both up tucked.
			steps = [Vector3(0.0,0.06*up,-0.035*up),Vector3(0.0,0.012*up,0.03*up)]
			var knees := clampf(knees_up,0.0,1.0)
			steps[0] = (steps[0] as Vector3).lerp(Vector3(0.0,0.09,-0.03),knees)
			steps[1] = (steps[1] as Vector3).lerp(Vector3(0.0,0.09,-0.03),knees)
			toes = [0.3*up,-0.2*(1.0-up)]
			stoop = -0.12*up+0.06*(1.0-up)
			look = Vector2(0.0,0.25*up-0.2*(1.0-up))
		"skid":
			steps = [Vector3(0.0,0.0,-0.06),Vector3(0.0,0.0,0.01)]
			toes = [-0.4,0.0]
			stoop = 0.28
			crouch = 0.02
			hands = [Vector3(-0.1,0.06,-0.1),Vector3(0.1,0.06,-0.1)]
			look = Vector2(0.0,-0.05)
	# A landing's squash, springing back.
	_impact = maxf(0.0,_impact-delta*6.0)
	var landed := _squash.step(_impact,delta)
	crouch += 0.05*maxf(landed,0.0)
	squash -= 1.6*landed
	# The body: lifted, crouched, squashed and stretched a touch.
	var sway := _sway.step(sin(_clock*0.6)*0.006 if move == "idle" else 0.0,delta)
	_hips.position = Vector3(sway+waddle,HIPS+lift-crouch+bob,0.0)
	_hips.rotation = Vector3(0.0,twist,0.0)
	var stretch := 1.0+0.05*squash
	_hips.scale = Vector3(1.0/sqrt(stretch),stretch,1.0/sqrt(stretch))
	_rise = (lift-crouch+bob-_lift_was)/delta if delta > 0.0 else 0.0
	_lift_was = lift-crouch+bob
	var leaning := _lean.step(lean,delta)
	_torso.rotation = Vector3(0.02*breathe-crouch*2.0+stoop,-twist*1.6,leaning+roll)
	# The head: where the move looks, nodding with the rise and fall.
	var yaw := _yaw.step(look.x,delta)
	var nod := _nod.step(look.y-clampf(_rise*0.4,-0.25,0.25),delta)
	var tilt := _tilt.step(-(leaning+roll)*0.6,delta)
	_neck.rotation = Vector3(nod*0.4,yaw*0.4,tilt*0.4)
	_head.rotation = Vector3(nod*0.6,yaw*0.6,tilt*0.6)
	for s in range(2):
		var side := -1.0 if s == 0 else 1.0
		var target: Vector3 = hands[s]
		var springs: Array = _reach[s]
		var hand := Vector3((springs[0] as Spring).step(target.x,delta),(springs[1] as Spring).step(target.y,delta),(springs[2] as Spring).step(target.z,delta))
		PersonKit.pose(_arms[s],PersonKit.SHOULDER*Vector3(side,1.0,1.0),hand,ARM,Vector3(side,-0.3,0.5))
		# The legs from the hips to the boots, knees forward, tucked in the air.
		var hip := _hips.transform*(HIP*Vector3(side,1.0,1.0))
		var foot := STANCE*Vector3(side,1.0,1.0)+Vector3(0.0,lift+tuck+ANKLE,tuck*0.4)+(steps[s] as Vector3)
		PersonKit.pose(_legs[s],hip,foot,LEG,Vector3(side*0.2,0.0,-1.0))
		(_legs[s][2] as Node3D).rotation = Vector3(toes[s],0.0,0.0)
		_swing_tail(s,delta,side)

## A scarf tail: hanging back, blown a little, lifting as the body falls,
## each strip lagging the one above.
func _swing_tail(s: int, delta: float, side: float) -> void:
	var tail: Array = _tails[s]
	var swings: Array = _swings[s]
	var lifted := clampf(-_rise*3.0,-0.4,1.4)
	for i in range(TAIL):
		var breeze := sin(_clock*2.3+i*0.8+side)*0.12
		var target := (-0.35-lifted if i == 0 else -0.15-lifted*0.4)+breeze
		var angle := (swings[i] as Spring).step(target,delta)
		(tail[i] as Node3D).rotation = Vector3(angle,0.0,side*0.08)

## Now and then, idling, a look about: aside, down, up at the sky.
func _think(delta: float) -> void:
	if _look_left > 0.0:
		_look_left -= delta
		if _look_left <= 0.0:
			_look = Vector2.ZERO
			_look_next = _rng.randf_range(LOOK_EVERY.x,LOOK_EVERY.y)
		return
	_look_next -= delta
	if _look_next > 0.0: return
	_look_left = _rng.randf_range(1.0,2.2)
	_look = Vector2(_rng.randf_range(-1.0,1.0),_rng.randf_range(-0.3,0.4))
