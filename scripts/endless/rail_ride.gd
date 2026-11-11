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
## - **No scoring sat.** The near misses are measured only while flying (the
##   study's `_near_misses`, NearMiss `_track`), so a train passing 7 m off a
##   plane sat on a car scores nothing; lifted off, a channel arms only once it
##   has been clear of its reach, so the car it sat on scores nothing either
##   until it is flown at again.
## - **The quick start** --rail-start=ride (`line_start`, by RailTrains'): sat on
##   train 0's flatcar with the lowest cars either side, at RIDE_STOP, RIDE_SIT
##   s before it pulls out (the study parks the plane on the deck: `ground`).
##   --ride-car=<kind> sits on another kind with a top (box: the tallest roof,
##   9 m), --ride-at=<s> that many seconds further on, wherever the train is then
##   moving or not. The ride start's lap (s after it pulls out, period 960):
##   farm town 176, the inner viaduct 255-275, the north tunnel 276-291 (the
##   meeting about 335 on the clock's lap: 515), mine town 436 (up on the
##   Peak's shelf), down the shelf to the cattle town 680, the bay bridge
##   780-850 (the meeting), the start station again 900.
## - **On the line** it rides the whole lap with nothing in its way: the bores'
##   vault is the least room over it, 6.9 m over the plane's top sat on the
##   tallest roof (a boxcar, 9 m: RailBoreShape sizes the vault on it); the spans
##   are decks and the stops stand beside the track.
## - **The wheels' size.** The plane's ground scale (plane_ground_scale.gd) reads
##   its speed over the car, so sat on a moving car it is drawn as parked.
## - **Getting out.** Nothing in the game asks Exit (walking was cut); if it were,
##   the plane would be carried on through EXIT and OUT as while sat.
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
## The quick start --rail-start=ride: the station train 0 is sat at, the
## seconds before it pulls out, and the kind of car sat on.
const RIDE_STOP := "rail/start-station"
const RIDE_SIT := 3.0
const RIDE_KIND := "flat"
const LaunchArgs = preload("res://scripts/launch_args.gd")

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
	if riding() and (not _down(landing) or not _held()): _leave()
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
	var on := {} if not _down(landing) else _over(plane.position,0.0)
	if on.is_empty():
		_leave()
		return
	var still := riding() and is_same(on.car,car) and int(landing.phase) in [ManualLanding.STOPPED,ManualLanding.EXIT,ManualLanding.OUT]
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

## On its wheels: rolling, stood still, or the pilot getting out or out.
static func _down(landing: Variant) -> bool:
	return landing.on_ground() or landing.done()

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

## The quick start --rail-start=ride on `line` (RailLine) with the line's
## timetables `tables` (RailTrains `line_tables`): sat on train 0's car of kind
## RIDE_KIND (--ride-car=) with the lowest cars either side (`_ride_car`), its
## nose at RIDE_STOP, RIDE_SIT s before it pulls out (or --ride-at= s on from
## that). {at (Vector2, x z: the deck's middle), heading (the car's way), y (the
## deck's top, world), clock (s), s (the car's middle), car (its number), ground
## (Callable(Vector2) -> float: the deck's height at a world x z, for PlaneStrip
## `rest`)}; {} if the line lacks the stop or the train the kind.
static func line_start(line: RefCounted, tables: Array) -> Dictionary:
	var t0: RefCounted = tables[0]
	var st: Dictionary = line.piece(RIDE_STOP)
	var pick := _ride_car(kind_flag())
	if pick.is_empty(): push_warning("--ride-car=%s: no car of that kind with a top between two others" % kind_flag())
	if st.is_empty() or pick.is_empty(): return {}
	# Track 0's nose halts half a train past the station's s (RailTrains `line_tables`).
	var nose := float(st.s0)+RailTrain.length_of()*0.5
	var n := float(line.length())
	var i := -1
	for k in range((t0.stop_s as PackedFloat64Array).size()):
		var off := absf(wrapf(float(t0.stop_s[k])-nose,-n*0.5,n*0.5))
		if i < 0 or off < absf(wrapf(float(t0.stop_s[i])-nose,-n*0.5,n*0.5)): i = k
	if i < 0: return {}
	var clock := fposmod(float(t0.time_at(float(t0.stop_s[i])))+float(t0.wait(i))-RIDE_SIT+at_flag(),float(t0.period))
	var xf := car_xf(line,t0,0,float(t0.at(clock).d),float(pick.front),float(pick.long))
	var top := float(pick.top)
	var deck := xf*Vector3(0.0,top,0.0)
	var up := xf.basis.y.normalized()
	var f := -xf.basis.z
	return {"at":Vector2(deck.x,deck.z),"heading":atan2(-f.x,-f.z),"y":deck.y,"clock":clock,
		"s":float(t0.s_of(float(t0.at(clock).d)-float(pick.front)-float(pick.long)*0.5)),"car":int(pick.i),
		"ground":func(p: Vector2) -> float: return deck.y-(up.x*(p.x-deck.x)+up.z*(p.y-deck.z))/up.y}

## --ride-car=<kind>: the kind of car the ride start sits on, else RIDE_KIND.
static func kind_flag() -> String:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--ride-car="): return a.trim_prefix("--ride-car=")
	return RIDE_KIND

## --ride-at=<s>: the ride start that many seconds on from its sit (0).
static func at_flag() -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--ride-at="): return a.trim_prefix("--ride-at=").to_float()
	return 0.0

## Train 0's car to sit on for the quick start: of kind `kind`, the one with
## the lowest cars either side (the first of those), so the view isn't walled
## in: {i, front (m from the nose), long, top (its deck, local y)}, or {}.
static func _ride_car(kind := RIDE_KIND) -> Dictionary:
	var cars: Array = RailTrain.CARS
	var best := {}
	var low := INF
	var front := 0.0
	for i in range(cars.size()):
		var c: Array = cars[i]
		if str(c[0]) == kind and i > 0 and i < cars.size()-1:
			var by := float(cars[i-1][2])+float(cars[i+1][2])
			if by < low:
				var boxes: Array = []
				for part: Array in (RailTrain._parts(str(c[0]),float(c[1]),float(c[2])).solid as Array): boxes.append(part[0])
				var top := _top_of({"kind":str(c[0]),"all":boxes},Vector3(0.0,INF,0.0))
				if not is_nan(top):
					low = by
					best = {"i":i,"front":front,"long":float(c[1]),"top":top}
		front += float(c[1])+RailTrain.GAP
	return best

## A car's frame with the nose at odometer `d` on `path`'s `track` by `table`,
## the car `front` m behind the nose and `long` long: between its bogies, as
## RailTrain `place` puts it.
static func car_xf(path: RefCounted, table: RefCounted, track: int, d: float, front: float, long: float) -> Transform3D:
	var a: Transform3D = path.pose(table.s_of(d-front-RailTrain.BOGIE),track)
	var b: Transform3D = path.pose(table.s_of(d-front-long+RailTrain.BOGIE),track)
	var f := (a.origin-b.origin).normalized()
	var up := (a.basis.y+b.basis.y).normalized()
	up = (up-f*f.dot(up)).normalized()
	var z := -f
	return Transform3D(Basis(up.cross(z),up,z),(a.origin+b.origin)*0.5)
