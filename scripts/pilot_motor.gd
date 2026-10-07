extends RefCounted
## The pilot on foot, moved like a platformer's hero: the stick asks for a
## way and a pace (in the world, the camera's way already taken out), and
## the pilot turns to face it and runs up to speed, quick at a walk and
## wider at a run; thrown hard the other way at a run he skids to a stop
## first and turns on the spot. Let go, he slows to a stand.
##
## Jumps go as high as the button is held: let go on the way up and he
## falls sooner, and he falls faster than he rose. Pressed a moment before
## landing (BUFFER) the jump is kept for the touch; pressed a moment after
## running off a ledge (COYOTE) it still jumps. Jumped again on landing
## (within CHAIN_WINDOW) at a run, the jumps chain, each higher (JUMPS), the
## third with a flip. In the air he keeps his run and steers only a little.
##
## Pressed again in the air on the way up, or falling from high enough
## (FLY_CLEAR), it asks to fly (`step` returns "fly").
##
## Ground is anything `ground` answers, a height for a point of the frame;
## running off ground that drops away by more than SNAP he falls. Moving
## through the world goes through `slide`, which takes the feet and a step
## and gives back where they come to, round whatever stands in the way. Both
## in one frame: the plate's terrain or an islet's.

## Speeds, metres a second, and how fast they are reached and lost.
const WALK := 2.0
const RUN := 4.0
const ACCEL := 14.0
const BRAKE := 18.0
const AIR_ACCEL := 6.0
## Radians a second he turns towards the stick: at a stand, at a full run,
## in the air.
const TURN := 16.0
const TURN_RUN := 7.0
const AIR_TURN := 4.0
## Thrown back against a run faster than this, he skids, braking at
## SKID_BRAKE: from a full run a slide of about 0.3 s and 0.6 m, long enough
## to read.
const SKID_SPEED := 2.8
const SKID_BRAKE := 13.0
## Gravity rising, the share more falling, and the share more rising with
## the button let go; the fastest fall.
const GRAVITY := 26.0
const FALL := 1.5
const CUT := 2.8
const TERMINAL := 18.0
## The chain's jump heights, metres.
const JUMPS := [0.8,1.1,1.55]
## Seconds after a landing the next jump chains, and the pace (of RUN) it
## needs.
const CHAIN_WINDOW := 0.22
const CHAIN_PACE := 0.5
const COYOTE := 0.1
const BUFFER := 0.13
## Ground falling away more than this under a step (plus the step's own
## run) is a ledge to fall from; ground rising more than STEP_UP in a step
## is a wall.
const SNAP := 0.3
const STEP_UP := 0.45
## Over this, metres above the ground, a press falling asks to fly.
const FLY_CLEAR := 1.6
## Seconds the third jump's flip takes.
const FLIP_TIME := 0.55

## The feet, in the frame.
var feet := Vector3.ZERO
var velocity := Vector3.ZERO
## The way he faces: down -Z turned by `facing` about up.
var facing := 0.0
var grounded := true
var skidding := false
## The jump in the chain he is in (1 to 3), 0 on the ground.
var chain := 0
## The third jump's flip, 0 to 1, or -1.
var flip := -1.0
## The ground under the feet last step.
var ground_y := 0.0
var _last_chain := 0
var _since_land := 99.0
var _since_ground := 0.0
var _buffer := 0.0
var _held := false
var _jumped := false

## Stood at `at`, facing `towards`, moving `speed` the way it faces.
func reset(at: Vector3, towards: float, speed := 0.0) -> void:
	feet = at
	ground_y = at.y
	facing = towards
	var f := forward(towards)
	velocity = Vector3(f.x,0.0,f.y)*speed
	grounded = true
	skidding = false
	chain = 0
	flip = -1.0
	_last_chain = 0
	_since_land = 99.0
	_since_ground = 0.0
	_buffer = 0.0
	_jumped = false

## The way `towards` faces, in the frame's plane (x, z).
static func forward(towards: float) -> Vector2:
	return Vector2(-sin(towards),-cos(towards))

## The facing that looks along `way` (x, z).
static func facing_of(way: Vector2) -> float:
	return atan2(-way.x,-way.y)

func speed() -> float:
	return Vector2(velocity.x,velocity.z).length()

## One step. `want` is the way asked, at most 1 long; `top` the pace it
## asks for at full stick; `jump` whether the jump is held. `ground` takes a
## point (x, z) and gives its height; `slide` takes the feet and a step
## (x, z) and gives back the feet moved. Returns what happened:
## "jumped" (the chain's number), "landed" (how hard, metres a second),
## "fly".
func step(delta: float, want: Vector2, top: float, jump: bool, ground: Callable, slide: Callable) -> Dictionary:
	var out := {}
	if want.length() > 1.0: want = want.normalized()
	var pressed := jump and not _held
	_held = jump
	_buffer = BUFFER if pressed else maxf(0.0,_buffer-delta)
	_since_land += delta
	if grounded: _since_ground = 0.0
	else: _since_ground += delta
	if _since_land > CHAIN_WINDOW: _last_chain = 0
	var h := Vector2(velocity.x,velocity.z)
	if grounded: h = _run(h,want,top,delta)
	else: h = _steer(h,want,top,delta)
	# The jump: from the ground, or just off it.
	if _buffer > 0.0 and (grounded or (_since_ground < COYOTE and not _jumped)):
		var next := 1
		if _last_chain > 0 and _last_chain < JUMPS.size() and h.length() >= CHAIN_PACE*RUN: next = _last_chain+1
		chain = next
		velocity.y = sqrt(2.0*GRAVITY*float(JUMPS[next-1]))
		grounded = false
		skidding = false
		_jumped = true
		_buffer = 0.0
		flip = 0.0 if next == JUMPS.size() else -1.0
		out["jumped"] = next
	elif pressed and not grounded and (velocity.y > 0.0 or feet.y-ground_y > FLY_CLEAR):
		_buffer = 0.0
		out["fly"] = true
	if flip >= 0.0: flip = minf(1.0,flip+delta/FLIP_TIME)
	var moved: Vector3 = slide.call(feet,h*delta)
	var under: float = ground.call(Vector2(moved.x,moved.z))
	if grounded and under > feet.y+STEP_UP:
		# A wall: stood against it.
		h = Vector2.ZERO
		moved = feet
		under = ground.call(Vector2(feet.x,feet.z))
	if grounded:
		if under < feet.y-SNAP-h.length()*delta:
			# Off a ledge: falling, the run kept.
			grounded = false
			_jumped = false
			velocity.y = 0.0
			feet = Vector3(moved.x,feet.y,moved.z)
		else:
			feet = Vector3(moved.x,under,moved.z)
			ground_y = under
	else:
		if under > feet.y+STEP_UP:
			# A wall in the air: stopped against it.
			h = Vector2.ZERO
			under = ground.call(Vector2(feet.x,feet.z))
			moved = feet
		var g := GRAVITY
		if velocity.y < 0.0: g *= FALL
		elif not jump and chain < JUMPS.size(): g *= CUT
		velocity.y = maxf(velocity.y-g*delta,-TERMINAL)
		var y := feet.y+velocity.y*delta
		ground_y = under
		if y <= under and velocity.y <= 0.0:
			out["landed"] = -velocity.y
			y = under
			grounded = true
			velocity.y = 0.0
			_last_chain = chain
			chain = 0
			flip = -1.0
			_since_land = 0.0
			_jumped = false
		elif y < under:
			y = under
		feet = Vector3(moved.x,y,moved.z)
	velocity.x = h.x
	velocity.z = h.y
	return out

## On the ground: turn to the stick and run up to its pace, or skid.
func _run(h: Vector2, want: Vector2, top: float, delta: float) -> Vector2:
	var pace := h.length()
	if want == Vector2.ZERO:
		skidding = false
		pace = move_toward(pace,0.0,BRAKE*delta)
		return h.normalized()*pace if h != Vector2.ZERO else Vector2.ZERO
	var way := want.normalized()
	if pace > SKID_SPEED and h.normalized().dot(way) < -0.6: skidding = true
	if skidding:
		pace = move_toward(pace,0.0,SKID_BRAKE*delta)
		if pace < 0.4:
			skidding = false
			facing = facing_of(way)
		return h.normalized()*pace if h != Vector2.ZERO else Vector2.ZERO
	var rate := lerpf(TURN,TURN_RUN,clampf(pace/RUN,0.0,1.0))
	facing = rotate_toward(facing,facing_of(way),rate*delta)
	var f := forward(facing)
	var goal := want.length()*top*(0.5+0.5*maxf(f.dot(way),0.0))
	pace = move_toward(pace,goal,(ACCEL if pace < goal else BRAKE)*delta)
	return f*pace

## In the air: the run kept, steered a little.
func _steer(h: Vector2, want: Vector2, top: float, delta: float) -> Vector2:
	if want == Vector2.ZERO: return h
	facing = rotate_toward(facing,facing_of(want.normalized()),AIR_TURN*delta)
	var goal := want*maxf(top,h.length())
	return h.move_toward(goal,AIR_ACCEL*delta)
