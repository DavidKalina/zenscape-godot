extends RefCounted
## Riding a train's car (docs/design/endless-flight/spec-steam-train.md, lane
## `ride`): the plane lands on a car's top (a flatcar's deck, a roof) and is
## carried with it, as on still ground.
##
## The hand landing (scripts/manual_landing.gd) is left to land and roll as
## anywhere; this only gives it the car as its ground:
## - **The floor.** The study's `floor_at` asks `land_y`: with the plane's middle
##   over a car's top (in the car's frame, no higher than OVER_HIGH m over it),
##   the floor is that top, and off it within EDGE m of the car it is an edge
##   (NAN, as the land's edge over the sea), so rolled off a roof the plane flies
##   off it, never drops onto the bed 9 m under in a frame. Elsewhere the land's.
## - **The touch.** Before the hand landing's step its `under` is told the
##   velocity of the car the plane is over (or rides), so the touch is graded by
##   the speed relative to the car, and leaving the wheels it flies off with it.
## - **The carry.** On the wheels on a car, the plane's place and heading are
##   kept in the car's own frame from one frame to the next (`_local`,
##   `_turn`): after the trains move (RailTrains `before`) and before the hand
##   landing's step, it is put back where it was on the car (ManualLanding
##   `carried`), so it turns with the car on curves and holds through grades,
##   stops and pulling out, with no slide. Whatever else moved the plane in
##   between counts for nothing, and the train ridden holds no keep-out on it
##   (RailTrain `ridden`). A clock jump carries it too.
## - **In the way.** Rolling, another car's body is a wall (`blocked`, for the
##   study's `_blocked`): the plane stops short of it as of an arch's leg.
## - **Sitting and lifting off.** The chase camera reads the plane's motion over
##   the car (GlideCamera `under`, set in the study's tick), so sat on a car it
##   frames and looks round as stood on the land, and while sat no car's hollow
##   makes it tight (a passing doorway drew it in at once). The wings feel the
##   car's speed (ManualLanding `under`): on a moving car Boost and the stick back
##   lift it off at once; at a stop it needs its run, as on the land.
##
## The engine's top is never a floor (the spec: weave round it, don't land).
## Only a train's solid is ridden (built within RailTrains' SOLID_NEAR).

const RailTrain = preload("res://scripts/endless/rail_train.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")

## How high over a car's top the plane's middle still has it for its floor (m).
const OVER_HIGH := 40.0
## How far past a car's sides and ends a point off its top is its edge (m):
## the wheels' and tail skid's reach and a frame's roll.
const EDGE := 4.0
## A top counts under the plane's middle up to this far over it (m): a touch
## settles the middle a hair under the skim.
const GIVE := 0.3
## A car is listed near the plane within its half length and this (m).
const NEAR := 30.0
## The plane is over a car for `under` with its middle this far out past the
## car's top (m): a frame's move onto it is graded on its speed relative to it.
const UNDER_GROW := 1.0
## `blocked`: a car's body is in the rolling plane's way this far past its
## wing's reach (m).
const ROOM := 0.5

var game: Node3D
var trains: Node3D
## The car ridden (a car of `train`'s `cars`), or {}; its train.
var car := {}
var train: Node3D = null
## Landings on a car, and frames carried (for the drivers).
var rides := 0
var carried := 0
## The plane's middle in the ridden car's frame, and its heading less the car's.
var _local := Vector3.ZERO
var _turn := 0.0
## The cars near the plane this frame: [train, car] (`_list`).
var _near: Array = []

func _init(g: Node3D, by: Node3D) -> void:
	game = g
	trains = by

## True while the plane stands on a car.
func riding() -> bool:
	return not car.is_empty()

## One frame, after every train moved and held the plane out of its cars, before
## the hand landing's step: the plane carried with the car it rides, the cars
## near it listed, the hand landing told what moves under it.
func before(_delta: float) -> void:
	var landing = game.get("hand_landing")
	var plane = game.get("plane")
	if landing == null or plane == null: return
	if riding() and (not landing.on_ground() or not _held()): _leave()
	if riding():
		var xf: Transform3D = car.xf
		landing.carried(xf*_local,angle_difference(float(plane.heading),_yaw(xf)+_turn))
		carried += 1
	_list(plane.position)
	landing.under = _under(plane.position)

## One frame, after the hand landing's step: the car the plane stands on now (a
## touch onto it, rolled off it, lifted off), and its place on it kept.
func after(_delta: float) -> void:
	var landing = game.get("hand_landing")
	var plane = game.get("plane")
	if landing == null or plane == null: return
	var on := {} if not landing.on_ground() else _over(plane.position,0.0)
	if on.is_empty():
		_leave()
		return
	var still := riding() and is_same(on.car,car) and int(landing.phase) == ManualLanding.STOPPED
	if not is_same(on.car,car):
		if riding(): _leave()
		rides += 1
		car = on.car
		train = on.train
		train.ridden = true
	var xf: Transform3D = car.xf
	var l: Vector3 = (car.inv as Transform3D)*(plane.position as Vector3)
	# Stood still on it, its place on the car is kept as it was (only its sit
	# taken): read back each frame it would creep by the world's rounding.
	_local = Vector3(_local.x,l.y,_local.z) if still else l
	_turn = angle_difference(_yaw(xf),float(plane.heading))

## The floor at world `q` (its y the plane's), for the study's `floor_at`: the top
## of the car the plane's middle is over, NAN off it by the car (its edge), else
## `h`.
func land_y(q: Vector3, h: float) -> float:
	if _near.is_empty(): return h
	var plane = game.get("plane")
	if plane == null: return h
	var on := _over(plane.position,0.0)
	if on.is_empty(): return h
	var c: Dictionary = on.car
	var l: Vector3 = (c.inv as Transform3D)*q
	var top := _top_of(c,l)
	if is_nan(top):
		var by := absf(l.x) <= RailTrain.WIDE*0.5+EDGE and absf(l.z) <= float(c.long)*0.5+EDGE
		return NAN if by else h
	return ((c.xf as Transform3D)*Vector3(l.x,top,l.z)).y

## In the rolling plane's way at world `p`: within the wing's reach (the study's
## `solid_pad`) and ROOM of a car's body, inside its height. The car under the
## plane is under it, not in its way. ROOM so the gap between two cars (GAP,
## 1.6 m) is no edge to roll off: the plane, as long as it is wide, doesn't fit
## down it, so it stops short of the next car's end.
func blocked(p: Vector3) -> bool:
	if _near.is_empty(): return false
	var pad := float(game.get("solid_pad"))+ROOM
	for e: Array in _near:
		var c: Dictionary = e[1]
		var l: Vector3 = (c.inv as Transform3D)*p
		for b: AABB in c.all:
			if l.y < b.position.y or l.y > b.end.y: continue
			var dx := maxf(0.0,maxf(b.position.x-l.x,l.x-b.end.x))
			var dz := maxf(0.0,maxf(b.position.z-l.z,l.z-b.end.z))
			if dx*dx+dz*dz <= pad*pad: return true
	return false

## The car ridden still there: its train built and solid.
func _held() -> bool:
	if train == null or not is_instance_valid(train) or not bool(train.solid): return false
	for c: Dictionary in train.cars:
		if is_same(c,car): return true
	return false

func _leave() -> void:
	if train != null and is_instance_valid(train): train.ridden = false
	car = {}
	train = null

## Every solid car within NEAR m (and its half length) of `p`.
func _list(p: Vector3) -> void:
	_near.clear()
	if trains == null: return
	for tr: Node3D in trains.list:
		if not bool(tr.solid): continue
		for c: Dictionary in tr.cars:
			if (c.xf as Transform3D).origin.distance_to(p) <= float(c.long)*0.5+NEAR: _near.append([tr,c])

## The car whose top world `p` is over (its footprint grown by `grow` m), no
## higher than OVER_HIGH: {train, car, top (local y)}, or {}. Never the engine.
func _over(p: Vector3, grow: float) -> Dictionary:
	for e: Array in _near:
		var c: Dictionary = e[1]
		if str(c.kind) == "engine": continue
		var l: Vector3 = (c.inv as Transform3D)*p
		var hw := RailTrain.WIDE*0.5
		var hl := float(c.long)*0.5
		if absf(l.x) > hw+grow or absf(l.z) > hl+grow: continue
		var top := _top_of(c,Vector3(clampf(l.x,-hw,hw),l.y,clampf(l.z,-hl,hl)))
		if is_nan(top) or l.y-top > OVER_HIGH: continue
		return {"train":e[0],"car":c,"top":top}
	return {}

## The highest top of car `c`'s solid under local `l` (no higher than GIVE over
## it: a roof over a doorway is not the floor in it), NAN if none. Never the engine's.
static func _top_of(c: Dictionary, l: Vector3) -> float:
	if str(c.kind) == "engine": return NAN
	var best := NAN
	for b: AABB in c.all:
		if l.x < b.position.x or l.x > b.end.x or l.z < b.position.z or l.z > b.end.z: continue
		if b.end.y > l.y+GIVE: continue
		if is_nan(best) or b.end.y > best: best = b.end.y
	return best

## The velocity of what is under world `p`: the car ridden, else the car the
## plane is over (just past its top too: UNDER_GROW), else nothing.
func _under(p: Vector3) -> Vector3:
	if riding(): return train.velocity_at(car,p)
	var on := _over(p,UNDER_GROW)
	if on.is_empty(): return Vector3.ZERO
	return (on.train as Node3D).velocity_at(on.car,p)

## The heading (the study's yaw: forward is (-sin, -cos)) a frame faces.
static func _yaw(xf: Transform3D) -> float:
	var f := -xf.basis.z
	return atan2(-f.x,-f.z)
