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
## tall to matter. Hollow land (a trimesh) counts as something solid when
## the ray starts under its open top (`_under_top`). Nothing under it
## within DEPTH is no ground (-INF).
##
## The body is an upright cylinder RADIUS round, from BODY_LOW over the
## feet (everything lower is the ground's to step over or to stop as a
## wall) to HEAD. A step through the world is cast as that body, slid
## along whatever it touches, up to SLIDES times, a SKIN short of it; a
## body already in something (set down there, or climbed into it) is let
## move, to come out, but not further in. Rising, `head` stops a jump against a ceiling.
##
## Ledges are PilotLedge.find over the same rays cast from the lip's height
## hint, but where a ray starts inside something the lip finder is given
## its real top, looked for from TOWER over the hint (the ground's "a wall
## too tall to matter" would be a step at the ray's start, a lip partway up
## a tall wall that could be hung from and never climbed). Walls (`wall`)
## are two rays along the way asked, at the chest (WALL_CHEST) and at the
## wall's least height (PilotMotor.WALL_TALL) over the feet: both hitting
## within the reach, the wall's way off is the chest's hit's. Water is a
## list of flat pools, {"rect": Rect2 (x, z), "top": the surface's height}:
## the depth at a point is the top over the ground there.
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
## A wall's ray at the chest, over the feet; how high over a lip's hint the
## real top of a tall wall is looked for from.
const WALL_CHEST := 0.75
const TOWER := 40.0

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
## The body's top over the feet: HEAD, times the walker's scale (`scale_body`).
var head_top := HEAD

func _init(physics: PhysicsDirectSpaceState3D, walker: PilotMotor) -> void:
	space = physics
	motor = walker
	walker.ground_from = height_from
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

## The body drawn `s` times its size (--wanderer-scale, a demo): its radius
## and top scaled; BODY_LOW (the step it walks up) kept.
func scale_body(s: float) -> void:
	head_top = maxf(HEAD*s,BODY_LOW+0.3)
	(_body.shape as CylinderShape3D).radius = RADIUS*s
	(_body.shape as CylinderShape3D).height = head_top-BODY_LOW
	(_cap.shape as CylinderShape3D).radius = RADIUS*0.8*s

## The colliders' layers that count from now on (`mask`, and its queries').
func see(layers: int) -> void:
	mask = layers
	_ray.collision_mask = layers
	_body.collision_mask = layers
	_cap.collision_mask = layers

## The motor's callables, wired to this.
func ground_callable() -> Callable:
	return ground

func slide_callable() -> Callable:
	return slide

func ledge_callable() -> Callable:
	return ledge

func water_callable() -> Callable:
	return depth

func wall_callable() -> Callable:
	return wall

func mover_callable() -> Callable:
	return mover

func soft_callable() -> Callable:
	return soft

## Moving ground and soft ground (PilotMotor `mover`, `soft`) are opt-in:
## a body carries him only if it has the MOVING meta (true), and is soft
## only if it has the SOFT meta (a Dictionary: {slow, catch, keep}).
const MOVING := &"moving_ground"
const SOFT := &"soft_ground"
## How far over and under the point the thing under it is looked for (m).
const UNDER_OVER := 0.3
const UNDER_DEPTH := 0.45

## Marks `body` as moving ground: he rides it (PilotMotor `mover`).
static func mark_moving(body: CollisionObject3D) -> void:
	body.set_meta(MOVING,true)

## Marks `body` as soft ground with `how` ({slow, catch, keep}).
static func mark_soft(body: CollisionObject3D, how: Dictionary) -> void:
	body.set_meta(SOFT,how)

## What is right under `p` ({collider, shape} as a ray gives it), or {}.
func _under(p: Vector3) -> Dictionary:
	_ray.from = p+Vector3.UP*UNDER_OVER
	_ray.to = p-Vector3.UP*UNDER_DEPTH
	return space.intersect_ray(_ray)

## The Node3D carrying what stands at `p` (the shape's owner of a body
## marked MOVING, so each capsule of a serpent is its own), or null.
func mover(p: Vector3) -> Node3D:
	var hit := _under(p)
	if hit.is_empty(): return null
	var body := hit.get("collider") as CollisionObject3D
	if body == null or not body.has_meta(MOVING): return null
	var owner_id := body.shape_find_owner(int(hit.get("shape",0)))
	if owner_id < 0: return body
	var shape_owner := body.shape_owner_get_owner(owner_id) as Node3D
	return shape_owner if shape_owner != null else body

## The soft ground at `p` (its SOFT meta), or {}.
func soft(p: Vector3) -> Dictionary:
	var hit := _under(p)
	if hit.is_empty(): return {}
	var body := hit.get("collider") as CollisionObject3D
	if body == null or not body.has_meta(SOFT): return {}
	return body.get_meta(SOFT)

## The ground under plate point `p` as the motor sees it from its feet.
func ground(p: Vector2) -> float:
	return height_from(p,motor.feet.y)

## The ground under `p` seen from feet at `y`: see the top.
func height_from(p: Vector2, y: float) -> float:
	var from := y+PilotMotor.STEP_UP+LOOK_OVER
	var hit := _down(p,from)
	if hit != INF and hit < y-PilotMotor.STEP_UP and _under_top(p,from,y): hit = INF
	if hit == INF:
		# In something: its top, if it is within reach.
		var top := _down(p,y+REACH)
		return from if top == INF or top < from else top
	return hit

## True if `from` (over feet at `y`) lies under the open top of hollow
## land: a ray up from it meets something within REACH, and that something
## is the topmost surface there (a ray down from TOWER lands on the same
## height). KitLand's land is a hollow trimesh, so on steep turf the ray
## down from under its sheet passes through and finds the sides far below,
## or nothing; this sees it as being inside, as a convex start is. Facing
## isn't used (Jolt flips the normal on back-face hits). Only asked when the
## ray down fell more than a step, so flat walking pays nothing. An
## overhang, a rim's hanging side or a deck isn't the top seen from TOWER
## (a deck's top is its thickness higher): reads under them and at cliff
## edges in the air stay as they were. Known limit: a collided overhang
## whose underside is also the topmost surface still passes.
const TOP_SAME := 0.02
func _under_top(p: Vector2, from: float, y: float) -> bool:
	return not is_nan(top_over(space,_ray,Vector3(p.x,from,p.y),y+REACH,y+TOWER))

## The shared form of `_under_top`, for any reader (the enemies' too,
## scripts/enemies/enemy_field.gd floor_under, headless_body _floor): the
## height of the open top over `from` if `from` lies under it in hollow
## land (a ray up to `reach_y` meets it, and a ray down from `tower_y`
## lands on it within TOP_SAME), else NAN. `ray` keeps its mask and
## exclusions; only its ends are set.
static func top_over(at: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D, from: Vector3, reach_y: float, tower_y: float) -> float:
	ray.from = from
	ray.to = Vector3(from.x,reach_y,from.z)
	var up := at.intersect_ray(ray)
	if up.is_empty(): return NAN
	var top := (up.position as Vector3).y
	ray.from = Vector3(from.x,tower_y,from.z)
	ray.to = Vector3(from.x,tower_y-DEPTH,from.z)
	var over := at.intersect_ray(ray)
	if over.is_empty() or (over.normal as Vector3) == Vector3.ZERO: return NAN
	return top if absf((over.position as Vector3).y-top) < TOP_SAME else NAN

## A down read from `up` over `p` that met nothing: the open top over its
## start if the start lies in hollow land (`top_over`, within REACH), else
## -INF, a void as before.
static func land_top(at: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D, p: Vector3, up: float) -> float:
	var top := top_over(at,ray,p+Vector3.UP*up,p.y+up+REACH,p.y+TOWER)
	return -INF if is_nan(top) else top

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
	var middle := Vector3.UP*(BODY_LOW+(head_top-BODY_LOW)*0.5)
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
	_cap.transform = Transform3D(Basis.IDENTITY,motor.feet+Vector3.UP*(head_top-0.05))
	_cap.motion = Vector3.UP*(motor.velocity.y*delta+0.02)
	var cast := space.cast_motion(_cap)
	if float(cast[0]) >= 1.0: return false
	motor.velocity.y = 0.0
	return true

## The lip near `near`, its top about `y`, as PilotLedge `find` gives it.
func ledge(near: Vector2, y: float) -> Dictionary:
	return PilotLedge.find(func(p: Vector2) -> float: return top_from(p,y-PilotMotor.STEP_UP*0.5),near,y)

## As `height_from`, but a wall too tall to matter is its real top, looked
## for from TOWER over `y`.
func top_from(p: Vector2, y: float) -> float:
	var h := height_from(p,y)
	if h != y+PilotMotor.STEP_UP+LOOK_OVER: return h
	var top := _down(p,y+TOWER)
	return top if is_finite(top) else h

## The way off a wall standing PilotMotor.WALL_TALL over `feet`, within
## `reach` of them along `way` (x, z); Vector2.ZERO if there is none.
func wall(feet: Vector3, way: Vector2, reach: float) -> Vector2:
	var along := Vector3(way.x,0.0,way.y).normalized()*reach
	var normal := Vector3.ZERO
	for up: float in [WALL_CHEST,PilotMotor.WALL_TALL]:
		_ray.from = feet+Vector3.UP*up
		_ray.to = _ray.from+along
		var hit := space.intersect_ray(_ray)
		if hit.is_empty() or (hit.normal as Vector3) == Vector3.ZERO: return Vector2.ZERO
		if up == WALL_CHEST: normal = hit.normal
	if absf(normal.y) > 0.35: return Vector2.ZERO
	return Vector2(normal.x,normal.z).normalized()

## The water's depth over the ground at `p`, 0 out of every pool. A pool
## held up in something (the aqueduct's channel on its deck) is not over
## him when he is under it: the ground he stands on lies under the pool's
## own bed (the ground seen from its surface) by more than BED_UNDER m.
## (Under the aqueduct's arches the channel overhead read as 10 m of water
## over the turf: he floated up through the deck onto its top.)
const BED_UNDER := 0.3
func depth(p: Vector2) -> float:
	for pool: Dictionary in pools:
		var top := _pool_top(pool,p)
		if top == -INF: continue
		var bed := ground(p)
		if not is_finite(bed): return 0.0
		var pool_bed := height_from(p,top)
		if is_finite(pool_bed) and bed < pool_bed-BED_UNDER: return 0.0
		return maxf(top-bed,0.0)
	return 0.0

## The pool's surface at `p`, or -INF.
func surface(p: Vector2) -> float:
	for pool: Dictionary in pools:
		var top := _pool_top(pool,p)
		if top != -INF: return top
	return -INF

## `pool`'s surface over world `p` (x, z), or -INF off it. A pool with a
## "node" (and its "rest" transform) rides that node: a motif isle the rim
## dragon tips (docs/design/rim-dragon.md, round 9) carries its tarn with
## it, so the rect is read in the node's rest frame and the top is the
## posed (tipped) surface's height over `p`.
## A pool with an "inside" (Callable(Vector2) -> bool, world x, z) is
## water only where that says so: a lake of any shape in its box.
static func _pool_top(pool: Dictionary, p: Vector2) -> float:
	var inside: Variant = pool.get("inside")
	if inside is Callable and (pool.rect as Rect2).has_point(p) and not bool((inside as Callable).call(p)): return -INF
	var node: Variant = pool.get("node")
	if node == null or not is_instance_valid(node):
		return float(pool.top) if (pool.rect as Rect2).has_point(p) else -INF
	var rest: Transform3D = pool.rest
	var now: Transform3D = (node as Node3D).transform
	if now.is_equal_approx(rest):
		return float(pool.top) if (pool.rect as Rect2).has_point(p) else -INF
	# The world point over `p` on the posed surface: its rest-frame height
	# is linear in the world height.
	var back := rest*now.affine_inverse()
	var l0 := back*Vector3(p.x,0.0,p.y)
	var l1 := back*Vector3(p.x,1.0,p.y)
	var rise := l1.y-l0.y
	if absf(rise) < 0.2: return -INF
	var y := (float(pool.top)-l0.y)/rise
	var l := back*Vector3(p.x,y,p.y)
	return y if (pool.rect as Rect2).has_point(Vector2(l.x,l.z)) else -INF
