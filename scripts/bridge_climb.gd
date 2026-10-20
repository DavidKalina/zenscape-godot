extends RefCounted
## Holding on to a snapped bridge's hanging half and climbing it like a
## ladder (docs/design/bridge-snap/spec-bridge-snap.md, task 4). The halves
## are scripts/bridge_load.gd's plank chains (`half_points`).
##
## In the air (falling with the deck, off it, or jumping at it), his hands
## or chest within REACH of a half's chain catch it, where they touch: the
## motor's rider (PilotMotor `mount`, the swing rope's way), hung under his
## hands as from a ledge (hold "swing"), facing the cliff, carried by the
## chain as it swings down to the face; his pace jolts the link he caught
## and his weight pulls on it (BridgeLoad `hang_on`).
##
## Held: the stick toward the cliff climbs (CLIMB m/s along the chain), away
## climbs down. His hands at the lip, he is let go hanging from the lip, so
## the motor's own ledge hang takes him (and the stick still held climbs him
## onto the top). Jump lets go with a push off the face (out into the void);
## crouch lets go where he is. A mended bridge (R, a respawn) lets go too.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")

## Catch reach (m, times his size) from his hands or chest to the chain.
const REACH := 0.8
## Climbing pace along the chain (m/s, times his size).
const CLIMB := 2.0
## No catching again this long after letting go (s).
const REGRAB := 0.5
## Off the lip: his hands this far under its top (m) when let go there, for
## the motor's ledge grab.
const LIP_UNDER := 0.05
## A jump off: out from the face and up (m/s).
const JUMP_OUT := 3.0
const JUMP_UP := 3.5
## The chain's pull on his hands: their pace, eased (s).
const PACE_EASE := 0.08

var load: Node = null
var kg := 60.0
## Holding: which half (-1 none), how far along it from its end (m).
var half := -1
var along := 0.0
var facing := 0.0
## How many catches, climbs to the top and let-gos (for drivers).
var caught := 0
var topped := 0
var dropped := 0
var _cool := 0.0
var _crouch_was := false
var _hands := Vector3.INF
var _pace := Vector3.ZERO

func _init(on: Node, weight := 60.0) -> void:
	load = on
	kg = weight

func holding() -> bool:
	return half >= 0

## Each frame he is his own (no rider, no hold, off the ground): catches a
## chain in reach. Whether it did.
func catch(walker: PilotMotor, delta: float) -> bool:
	_cool = maxf(_cool-delta,0.0)
	if holding() or _cool > 0.0 or load == null or not load.broken: return false
	if walker.grounded or walker.hold != "" or walker.rider != null or walker.swimming: return false
	var s := walker.size
	var hands := _hand_of(walker)
	var chest := walker.feet+Vector3.UP*walker.hang_drop*0.7
	var best := INF
	var pick := [-1,0.0]
	for i in range(load.halves.size()):
		var pts: PackedVector3Array = load.half_points(i)
		var run := 0.0
		for k in range(pts.size()-1):
			var seg := pts[k+1]-pts[k]
			var l := seg.length()
			if l < 0.0001: continue
			for at: Vector3 in [hands,chest]:
				var u := clampf((at-pts[k]).dot(seg)/(l*l),0.0,1.0)
				var d := at.distance_to(pts[k]+seg*u)
				if d < best:
					best = d
					pick = [i,run+u*l]
			run += l
	if pick[0] < 0 or best > REACH*s: return false
	half = pick[0]
	along = pick[1]
	facing = PilotMotor.facing_of(-_out(half))
	_crouch_was = walker.crouch
	_hands = Vector3.INF
	_pace = walker.velocity
	walker.mount(self,walker.feet,false,facing,true)
	walker.hold = "swing"
	walker.move = ""
	_place(walker,0.0)
	load.hang_on(half,_link(),kg*s*s*s,walker.velocity)
	caught += 1
	return true

## One step held (the motor's rider).
func ride(walker: PilotMotor, delta: float, want: Vector2, pressed: bool) -> Dictionary:
	var out := {}
	if load == null or not load.broken or half >= load.halves.size():
		_free(walker)
		walker.release(self)
		return out
	var dropped_now := walker.crouch and not _crouch_was
	_crouch_was = walker.crouch
	if pressed or dropped_now:
		var o := _out(half)
		var v := Vector3(o.x,0.0,o.y)*JUMP_OUT+Vector3.UP*JUMP_UP if pressed else _pace
		_let_go(walker,v)
		dropped += 1
		if pressed: out["jumped"] = 1
		return out
	var o2 := _out(half)
	var climb := want.dot(-o2)
	var s := walker.size
	if absf(climb) > 0.2: along = maxf(along-climb*CLIMB*s*delta,0.0)
	along = minf(along,_length())
	walker.shimmy = 0.0
	_place(walker,delta)
	load.hang_on(half,_link(),kg*s*s*s)
	# Hands up at the lip: off the chain, hanging from the lip.
	var top := _top()
	if _hands.y >= top.y-LIP_UNDER*2.0 or along <= load.lip+0.05:
		var o := _out(half)
		var flat := Vector3(o.x,0.0,o.y)
		walker.feet = Vector3(top.x,top.y-walker.hang_drop-LIP_UNDER,top.z)+flat*walker.hang_out
		walker.facing = facing
		_free(walker)
		walker.rider = null
		walker.hold = ""
		walker.velocity = Vector3.ZERO
		walker.grounded = false
		topped += 1
		out["climbed_chain"] = true
	return out

## The lip his half folds over (the world): the half's end, `lip` out.
func _top() -> Vector3:
	var pts: PackedVector3Array = load.half_points(half)
	var o := _out(half)
	return pts[0]+Vector3(o.x,0.0,o.y)*float(load.lip)

## Half `i`'s way out of its cliff (flat, the world).
func _out(i: int) -> Vector2:
	var br: Node3D = load.bridge
	var d: Vector3 = br.global_transform*(br.b as Vector3)-br.global_transform*(br.a as Vector3)
	var v := Vector2(d.x,d.z).normalized()
	return v if i == 0 else -v

func _length() -> float:
	var pts: PackedVector3Array = load.half_points(half)
	var run := 0.0
	for k in range(pts.size()-1): run += pts[k].distance_to(pts[k+1])
	return run

## The link his hands hold (index into the half's points).
func _link() -> int:
	var pts: PackedVector3Array = load.half_points(half)
	var run := 0.0
	for k in range(pts.size()-1):
		run += pts[k].distance_to(pts[k+1])
		if run >= along: return k+1
	return pts.size()-1

## His hands' spot on the chain and the chain's way up there.
func _grip() -> Array:
	var pts: PackedVector3Array = load.half_points(half)
	var run := 0.0
	for k in range(pts.size()-1):
		var l := pts[k].distance_to(pts[k+1])
		if run+l >= along or k == pts.size()-2:
			var u := clampf((along-run)/maxf(l,0.0001),0.0,1.0)
			var up := (pts[k]-pts[k+1]).normalized() if l > 0.0001 else Vector3.UP
			return [pts[k].lerp(pts[k+1],u),up]
		run += l
	return [pts[0],Vector3.UP]

## His body under his hands, hanging along the chain, facing the cliff.
func _place(walker: PilotMotor, delta: float) -> void:
	var g: Array = _grip()
	var hands: Vector3 = g[0]
	var up: Vector3 = g[1]
	if up.y < 0.3: up = (up+Vector3.UP).normalized()
	if delta > 0.0 and _hands.is_finite():
		_pace = _pace.lerp((hands-_hands)/delta,clampf(delta/PACE_EASE,0.0,1.0))
	_hands = hands
	var f := PilotMotor.forward(facing)
	var ahead := Vector3(f.x,0.0,f.y)
	ahead = (ahead-up*ahead.dot(up)).normalized()
	var frame := Basis(up.cross(-ahead),up,-ahead)
	walker.facing = facing
	walker.velocity = _pace
	walker.feet = hands-frame*Vector3(0.0,walker.hang_drop,-walker.hang_out-0.03)
	walker.ground_y = walker.feet.y

func _let_go(walker: PilotMotor, v: Vector3) -> void:
	_free(walker)
	walker.toss(v)
	walker.feet.y -= 0.02

func _free(_walker: PilotMotor) -> void:
	if half >= 0 and load != null: load.hang_on(half,0,0.0)
	half = -1
	_cool = REGRAB
	_hands = Vector3.INF

## Where his hands are, as they hang from a ledge (PilotFigure GRIP).
static func _hand_of(walker: PilotMotor) -> Vector3:
	var f := PilotMotor.forward(walker.facing)
	return walker.feet+Vector3.UP*walker.hang_drop+Vector3(f.x,0.0,f.y)*(walker.hang_out+0.03)
