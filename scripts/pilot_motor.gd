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
## Ledges (`ledge`, a lip finder as scripts/pilot_ledge.gd's `find`): falling
## past a lip he faces, hands come down to it, he catches it; stepping off
## an edge carefully (under CATCH_PACE, or the stick let go or pulled back)
## he turns, lowers himself over it and hangs (pushed out over it at a run,
## he goes). Hanging, the stick along the lip shimmies him hand over hand,
## following its curve and turning to stay facing the wall, stopping where
## it bends too sharply, steps or ends; held towards the wall (CLIMB_HOLD) or
## Jump, he climbs up onto it; held away (DROP_HOLD) he lets go and falls.
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
## The ledge, as art/blender/pilot/pilot_build.py made the clips: hanging,
## the lip's top HANG_DROP over the feet and its edge HANG_OUT ahead; the
## climb (CLIMB_TIME s) ends stood CLIMB_IN in from the edge; the shimmy's
## pace, m/s along the lip.
const HANG_DROP := 0.825
const HANG_OUT := 0.22
const CLIMB_IN := 0.3
const CLIMB_TIME := 0.9
const SHIMMY := 0.7
## Seconds turning round on the edge before lowering over it, and the
## lowering (the climb played back, a little quicker).
const CATCH_TURN := 0.18
const LOWER_TIME := 0.7
## Stepping off an edge under this pace (m/s), or pushing out over it less
## than CATCH_PUSH of the stick, he catches it.
const CATCH_PACE := 2.2
const CATCH_PUSH := 0.35
## Catching a lip in the air: looked for GRAB_REACH m ahead; the hands
## (HANG_DROP over the feet) within GRAB_LOW under it to GRAB_HIGH over it;
## facing it within acos(GRAB_FACING); not rising faster than GRAB_RISE m/s.
## The body is drawn onto the hang over GRAB_SNAP s.
const GRAB_REACH := 0.45
const GRAB_LOW := 0.25
const GRAB_HIGH := 0.35
const GRAB_FACING := 0.5
const GRAB_RISE := 1.0
const GRAB_SNAP := 0.1
## Hanging: seconds before a climb is taken; the stick's share towards or
## away that counts, and seconds it is held to climb or to let go; seconds
## after letting go before another catch; the shimmy's pick-up (m/s²), the
## turn following the lip (radians a second), the sharpest bend it follows
## (radians a metre) and the steepest step along it.
const HANG_SETTLE := 0.2
const PUSH := 0.5
const CLIMB_HOLD := 0.25
const DROP_HOLD := 0.12
const REGRAB := 0.4
const SHIMMY_ACCEL := 6.0
const HANG_TURN := 8.0
const CURL_MOST := 2.5
const SHIMMY_SLOPE := 1.0

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
## On a ledge: "" (not), "catch" (turning round on the edge), "lower"
## (lowering over it), "hang", "climb". `hold_t` is the climb's place in its
## clip, 0 hanging to 1 stood on top (the lowering runs it back); `shimmy`
## the pace along the lip, m/s to his right; `lip` the edge on its top's
## height and `lip_out` the way off it.
var hold := ""
var hold_t := 0.0
var shimmy := 0.0
var lip := Vector3.ZERO
var lip_out := Vector2.ZERO
var _hang_feet := Vector3.ZERO
var _correct := Vector3.ZERO
var _snap := Vector3.ZERO
var _hold_time := 0.0
var _toward := 0.0
var _away := 0.0
var _regrab := 0.0
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
	hold = ""
	hold_t = 0.0
	shimmy = 0.0
	_regrab = 0.0

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
## "fly"; on a ledge (`ledge`: a point (x, z) and a height near the lip,
## giving {"at", "out"} or {}), "grabbed" ("air" or "step"), "hung",
## "climbed", "let_go", "stopped" (a shimmy that can't go on).
func step(delta: float, want: Vector2, top: float, jump: bool, ground: Callable, slide: Callable, ledge := Callable()) -> Dictionary:
	var out := {}
	if want.length() > 1.0: want = want.normalized()
	var pressed := jump and not _held
	_held = jump
	_regrab = maxf(0.0,_regrab-delta)
	if hold != "": return _hold_step(delta,want,pressed,ground,slide,ledge)
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
			if ledge.is_valid() and _careful(h,want) and _catch(ledge,ground):
				out["grabbed"] = "step"
				return out
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
		if not grounded and ledge.is_valid() and _grab(ledge,ground):
			out["grabbed"] = "air"
			return out
	velocity.x = h.x
	velocity.z = h.y
	return out

## Whether he is on a ledge (catching, hanging, climbing).
func on_ledge() -> bool:
	return hold != ""

## Where the drawn body's origin goes (scripts/pilot_figure.gd): the feet,
## but lowering and climbing the hang's, carried over to where the climb
## really ends as it goes, as the clip moves the body itself.
func origin() -> Vector3:
	return _hang_feet+_correct*hold_t if hold == "lower" or hold == "climb" else feet

## The feet climbing or lowering: from the hang to the top along the clip's
## way, about.
func _climbing_feet() -> Vector3:
	return origin()+(_top_of(_hang_feet)-_hang_feet)*smoothstep(0.0,1.0,hold_t)

## Going over an edge at `h` (m/s, x z), the stick at `want`: carefully?
func _careful(h: Vector2, want: Vector2) -> bool:
	if h.length() <= CATCH_PACE: return true
	return want.dot(h.normalized()) <= CATCH_PUSH

## Stepping off the lip at the feet: turned round to face it, to lower over
## it. False if there is no lip there with room to hang under.
func _catch(ledge: Callable, ground: Callable) -> bool:
	if _regrab > 0.0: return false
	var found: Dictionary = ledge.call(Vector2(feet.x,feet.z),feet.y)
	if found.is_empty() or absf(found.at.y-feet.y) > SNAP+0.1: return false
	if not _room_under(found,ground): return false
	lip = found.at
	lip_out = found.out
	hold = "catch"
	_hold_time = 0.0
	facing = facing_of(-lip_out)
	_still()
	return true

## Falling past a lip ahead, the hands coming down to it: caught.
func _grab(ledge: Callable, ground: Callable) -> bool:
	if _regrab > 0.0 or velocity.y > GRAB_RISE: return false
	var f := forward(facing)
	var at := Vector2(feet.x,feet.z)
	var found: Dictionary = ledge.call(at+f*GRAB_REACH,feet.y+HANG_DROP)
	if found.is_empty(): return false
	var hands: float = found.at.y-feet.y-HANG_DROP
	if hands < -GRAB_LOW or hands > GRAB_HIGH: return false
	var out_way: Vector2 = found.out
	if f.dot(-out_way) < GRAB_FACING: return false
	var off := (at-Vector2(found.at.x,found.at.z)).dot(out_way)
	if off < -0.15 or off > GRAB_REACH+0.15: return false
	if not _room_under(found,ground): return false
	# Only a lip in reach of the hands, not one round a corner.
	var hang := Vector2(found.at.x,found.at.z)+out_way*HANG_OUT
	if hang.distance_to(at) > GRAB_REACH: return false
	var was := feet
	_hang_on(found)
	_snap = was-feet
	feet = was
	return true

## Whether a body hangs under `found` clear of the ground below it.
func _room_under(found: Dictionary, ground: Callable) -> bool:
	var hang := Vector2(found.at.x,found.at.z)+(found.out as Vector2)*HANG_OUT
	return float(ground.call(hang)) < found.at.y-HANG_DROP*0.8

## Hanging from `found`.
func _hang_on(found: Dictionary) -> void:
	lip = found.at
	lip_out = found.out
	hold = "hang"
	hold_t = 0.0
	_hold_time = 0.0
	_toward = 0.0
	_away = 0.0
	_snap = Vector3.ZERO
	facing = facing_of(-lip_out)
	_still()
	feet = _hang_at()

## Where the feet hang under the lip.
func _hang_at() -> Vector3:
	return Vector3(lip.x+lip_out.x*HANG_OUT,lip.y-HANG_DROP,lip.z+lip_out.y*HANG_OUT)

## Where the climb's clip stands him, from the hang at `hang`.
func _top_of(hang: Vector3) -> Vector3:
	return hang+Vector3(-lip_out.x,0.0,-lip_out.y)*(HANG_OUT+CLIMB_IN)+Vector3.UP*HANG_DROP

func _still() -> void:
	velocity = Vector3.ZERO
	grounded = false
	skidding = false
	chain = 0
	flip = -1.0
	shimmy = 0.0

## One step on a ledge.
func _hold_step(delta: float, want: Vector2, pressed: bool, ground: Callable, slide: Callable, ledge: Callable) -> Dictionary:
	var out := {}
	_hold_time += delta
	match hold:
		"catch":
			if _hold_time >= CATCH_TURN:
				# Lowered by the climb played back, from where he stands.
				_hang_feet = _hang_at()
				_correct = feet-_top_of(_hang_feet)
				hold = "lower"
				hold_t = 1.0
				feet = _climbing_feet()
		"lower":
			hold_t = maxf(0.0,hold_t-delta/LOWER_TIME)
			feet = _climbing_feet()
			if hold_t <= 0.0:
				hold = "hang"
				_hold_time = 0.0
				_toward = 0.0
				_away = 0.0
				out["hung"] = true
		"climb":
			hold_t = minf(1.0,hold_t+delta/CLIMB_TIME)
			feet = _climbing_feet()
			if hold_t >= 1.0:
				hold = ""
				grounded = true
				ground_y = feet.y
				facing = facing_of(-lip_out)
				velocity = Vector3.ZERO
				_since_land = 99.0
				_jumped = false
				out["climbed"] = true
		"hang":
			_hang_step(delta,want,pressed,ground,slide,ledge,out)
	return out

func _hang_step(delta: float, want: Vector2, pressed: bool, ground: Callable, slide: Callable, ledge: Callable, out: Dictionary) -> void:
	var toward := -lip_out
	var right := Vector2(-toward.y,toward.x)
	var along := want.dot(right)
	var push := want.dot(toward)
	_toward = _toward+delta if push > PUSH and absf(along) < push else 0.0
	_away = _away+delta if -push > PUSH and absf(along) < -push else 0.0
	if _hold_time >= HANG_SETTLE and (pressed or _toward >= CLIMB_HOLD) and _climb(ground,slide):
		return
	if _away >= DROP_HOLD:
		# Let go: falling, a touch out from the wall.
		hold = ""
		grounded = false
		velocity = Vector3(lip_out.x,0.0,lip_out.y)*0.6
		_regrab = REGRAB
		_jumped = true
		_since_ground = COYOTE
		out["let_go"] = true
		return
	var goal := 0.0
	if absf(along) > 0.3 and absf(along) >= absf(push)*0.8: goal = signf(along)*SHIMMY*minf(absf(along)/0.9,1.0)
	shimmy = move_toward(shimmy,goal,SHIMMY_ACCEL*delta)
	var go := right*shimmy*delta
	if go.length() > 0.0001 and ledge.is_valid():
		var next := Vector2(lip.x,lip.z)+go
		var found: Dictionary = ledge.call(next,lip.y)
		var ok := not found.is_empty()
		if ok:
			var to := Vector2(found.at.x,found.at.z)
			var moved := to.distance_to(Vector2(lip.x,lip.z))
			var bend := absf((found.out as Vector2).angle_to(lip_out))
			ok = to.distance_to(next) < 0.05 and moved > 0.0 and moved < go.length()*2.0+0.005 and bend/maxf(moved,0.01) < CURL_MOST 				and absf(float(found.at.y)-lip.y)/maxf(moved,0.01) < SHIMMY_SLOPE and _room_under(found,ground)
		if ok:
			lip = found.at
			lip_out = found.out
		else:
			shimmy = 0.0
			out["stopped"] = true
	facing = rotate_toward(facing,facing_of(-lip_out),HANG_TURN*delta)
	var r := Vector2(lip_out.y,-lip_out.x)
	velocity = Vector3(r.x,0.0,r.y)*shimmy
	# Drawn in from where he caught it.
	_snap = _snap.lerp(Vector3.ZERO,1.0-exp(-delta/(GRAB_SNAP*0.35)))
	feet = _hang_at()+_snap

## Up onto the lip, if there is room to stand on it.
func _climb(ground: Callable, slide: Callable) -> bool:
	var edge := Vector2(lip.x,lip.z)
	var stand := edge-lip_out*CLIMB_IN
	var h := float(ground.call(stand))
	if not is_finite(h) or absf(h-lip.y) > 0.5: return false
	var on := edge-lip_out*0.05
	var reached: Vector3 = slide.call(Vector3(on.x,lip.y,on.y),stand-on)
	if Vector2(reached.x,reached.z).distance_to(stand) > 0.1: return false
	_hang_feet = _hang_at()
	_correct = Vector3(stand.x,h,stand.y)-_top_of(_hang_feet)
	hold = "climb"
	hold_t = 0.0
	shimmy = 0.0
	velocity = Vector3.ZERO
	_snap = Vector3.ZERO
	return true

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
