extends RefCounted
## The pilot on foot (scripts/pilot_motor.gd) over real geometry: the
## motor's ground, slide, ledge and water answered from a physics space's
## colliders (StaticBody3D boxes, ramps, cylinders), so walls, overhangs,
## arches and bridges stand as built, without the motor knowing.
##
## The ground at a point is a ray straight down from a little over a step
## above the feet (STEP_UP and LOOK_OVER): the first thing under it. So a
## bridge overhead is passed under, and stood on once the feet are up on
## it. Where that ray starts inside something solid (a wall the feet are
## against), the ground is that thing's top, found by a second ray from
## REACH over the feet; a top higher still is the ray's start, a wall too
## tall to matter. Nothing under it within DEPTH is no ground (-INF).
##
## The body is an upright cylinder RADIUS round, from BODY_LOW over the
## feet (everything lower is the ground's to step over or to stop as a
## wall) to HEAD. A step through the world is cast as that body, slid
## along whatever it touches, up to SLIDES times, a SKIN short of it; a
## body already in something (set down there, or climbed into it) is let
## move, to come out, but not further in. Rising, `head` stops a jump against a ceiling.
##
## Ledges are PilotLedge.find over the same rays cast from the lip's height
## hint. Water is a list of flat pools, {"rect": Rect2 (x, z), "top": the
## surface's height}: the depth at a point is the top over the ground there.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotLedge = preload("res://scripts/pilot_ledge.gd")

## The ray down starts this far over a step's height over the feet.
const LOOK_OVER := 0.05
## Started in something solid, its top is looked for from this far over the
## feet.
const REACH := 3.0
## The furthest the ground is looked for under the ray's start (m).
const DEPTH := 80.0
## The body: its radius, its lowest part over the feet, its top; the gap
## kept from what it slides along.
const RADIUS := 0.28
const BODY_LOW := PilotMotor.STEP_UP+0.05
const HEAD := 1.12
const SKIN := 0.01
const SLIDES := 3

var space: PhysicsDirectSpaceState3D
## The motor whose feet the ground is looked for from.
var motor: PilotMotor
## The colliders' layers that count.
var mask := 1
## The pools: [{"rect": Rect2, "top": float}].
var pools: Array = []
var _ray := PhysicsRayQueryParameters3D.new()
var _body := PhysicsShapeQueryParameters3D.new()
var _cap := PhysicsShapeQueryParameters3D.new()

func _init(physics: PhysicsDirectSpaceState3D, walker: PilotMotor) -> void:
	space = physics
	motor = walker
	_ray.hit_from_inside = true
	_ray.collision_mask = mask
	var body := CylinderShape3D.new()
	body.radius = RADIUS
	body.height = HEAD-BODY_LOW
	_body.shape = body
	_body.collision_mask = mask
	_body.margin = 0.0
	var cap := CylinderShape3D.new()
	cap.radius = RADIUS*0.8
	cap.height = 0.1
	_cap.shape = cap
	_cap.collision_mask = mask
	_cap.margin = 0.0

## The motor's callables, wired to this.
func ground_callable() -> Callable:
	return ground

func slide_callable() -> Callable:
	return slide

func ledge_callable() -> Callable:
	return ledge

func water_callable() -> Callable:
	return depth

## The ground under plate point `p` as the motor sees it from its feet.
func ground(p: Vector2) -> float:
	return height_from(p,motor.feet.y)

## The ground under `p` seen from feet at `y`: see the top.
func height_from(p: Vector2, y: float) -> float:
	var from := y+PilotMotor.STEP_UP+LOOK_OVER
	var hit := _down(p,from)
	if hit == INF:
		# In something: its top, if it is within reach.
		var top := _down(p,y+REACH)
		return from if top == INF or top < from else top
	return hit

## The first thing under `p` from height `from`: its height, INF if `from`
## is inside it, -INF if there is nothing.
func _down(p: Vector2, from: float) -> float:
	_ray.from = Vector3(p.x,from,p.y)
	_ray.to = Vector3(p.x,from-DEPTH,p.y)
	var hit := space.intersect_ray(_ray)
	if hit.is_empty(): return -INF
	if (hit.normal as Vector3) == Vector3.ZERO: return INF
	return (hit.position as Vector3).y

## The feet moved by `step` (x, z), the body slid round what it meets.
func slide(feet: Vector3, step: Vector2) -> Vector3:
	var motion := Vector3(step.x,0.0,step.y)
	if motion.length_squared() < 1e-12: return feet
	var at := feet
	var middle := Vector3.UP*(BODY_LOW+(HEAD-BODY_LOW)*0.5)
	_body.transform = Transform3D(Basis.IDENTITY,at+middle)
	_body.motion = Vector3.ZERO
	if not space.intersect_shape(_body,1).is_empty():
		# Already in something: free to move, but not further into it.
		var inside := space.get_rest_info(_body)
		var out: Vector3 = inside.get("normal",Vector3.ZERO)
		out.y = 0.0
		if out.length_squared() > 1e-6: motion -= out.normalized()*minf(motion.dot(out.normalized()),0.0)
		return feet+motion
	for i in range(SLIDES):
		_body.transform = Transform3D(Basis.IDENTITY,at+middle)
		_body.motion = motion
		var cast := space.cast_motion(_body)
		var safe: float = cast[0]
		if safe >= 1.0:
			at += motion
			break
		var length := motion.length()
		at += motion*maxf(safe-SKIN/length,0.0)
		# What it met, and the way off it.
		_body.transform = Transform3D(Basis.IDENTITY,at+middle+motion*(float(cast[1])-safe+SKIN/length))
		_body.motion = Vector3.ZERO
		var rest := space.get_rest_info(_body)
		if rest.is_empty(): break
		var normal: Vector3 = rest.normal
		normal.y = 0.0
		if normal.length_squared() < 1e-6: break
		normal = normal.normalized()
		motion *= 1.0-safe
		motion -= normal*minf(motion.dot(normal),0.0)
		if motion.length_squared() < 1e-10: break
	return Vector3(at.x,feet.y,at.z)

## Rising into a ceiling: the jump stopped under it. True on the bump.
func head(delta: float) -> bool:
	if motor.grounded or motor.on_ledge() or motor.swimming or motor.velocity.y <= 0.0: return false
	_cap.transform = Transform3D(Basis.IDENTITY,motor.feet+Vector3.UP*(HEAD-0.05))
	_cap.motion = Vector3.UP*(motor.velocity.y*delta+0.02)
	var cast := space.cast_motion(_cap)
	if float(cast[0]) >= 1.0: return false
	motor.velocity.y = 0.0
	return true

## The lip near `near`, its top about `y`, as PilotLedge `find` gives it.
func ledge(near: Vector2, y: float) -> Dictionary:
	return PilotLedge.find(func(p: Vector2) -> float: return height_from(p,y-PilotMotor.STEP_UP*0.5),near,y)

## The water's depth over the ground at `p`, 0 out of every pool.
func depth(p: Vector2) -> float:
	for pool: Dictionary in pools:
		if not (pool.rect as Rect2).has_point(p): continue
		var bed := ground(p)
		return maxf(float(pool.top)-bed,0.0) if is_finite(bed) else 0.0
	return 0.0

## The pool's surface at `p`, or -INF.
func surface(p: Vector2) -> float:
	for pool: Dictionary in pools:
		if (pool.rect as Rect2).has_point(p): return float(pool.top)
	return -INF
