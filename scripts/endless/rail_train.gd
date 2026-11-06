extends Node3D
## A box train on a rail path (docs/design/endless-flight/spec-railroad.md, lane
## `train`): an engine, its tender and a string of cars, each a plain block, run
## along `path` (the rail path contract: `length`, `pose(s, track)`, `kind`) on
## one track at `speed` m/s. Greybox: no model, no smoke, no sound, nobody aboard.
##
## Its solid, as the pirate ship's: each car one record in LandArches `loose`
## (`xf`, `inv` its whole frame, the bed's grade too), rewritten each frame
## (`before`), so plane_ground, _blocked and the camera read it where it is now;
## and a StaticBody on layer 1 a car for the wing rays. The ship gets away with
## that because she moves 0.15 m a frame, inside the pad her solids are grown by.
## A train moves 0.53 m a frame at 32 m/s, and a car that moves onto the plane
## would leave its middle inside the car's solid, which SkyGlide can only lift
## out of, onto the car's roof (a pop of up to 9 m). So before the plane's move
## (`keep_out`) the plane is held out of every car the way the car came at it, in
## the car's own frame: onto the face it crossed (the car's motion seen from the
## plane), never further than the car moved, so it is neither carried nor flung.
## A car that ran into the plane is a touch like any other (`after` makes it the
## plane's `contact`), and every touch of a car is graded by the speed into it
## relative to the car (`relative`, from FlightContact): a plane level with a car
## that drifts onto its side scrapes it; the engine run into nose first crashes.
##
## Its frame for each car: origin on the bed at the car's middle, -z forward
## (the way the train runs), x to the right, y up. Cars sit between two bogies
## BOGIE m in from each end, each on the path, so a car on a curve cuts its chord.
##
## Its place is a pure function of time: the engine's nose at `s0` + `way`*`speed`
## *`t` along the path (`head`), `t` the seconds it has run (for now its own; the
## world clock's in the trunk).
##
## Knobs: --train-speed=<m/s> (SPEED), --train-keep=0 (no keep-out: the A/B of
## what it fixes).

const WorldScale = preload("res://scripts/world_scale.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const TestPath = preload("res://scripts/endless/rail_test_path.gd")

## A bit under the plane's cruise (36.75): at cruise it creeps up the train a car
## at a time, Boost runs it up to the engine.
const SPEED := 32.0
## The gap between two trains' sides on the two tracks, threaded side by side:
## an opening (WorldScale) from this toy width (7.0 m at plane 2).
const TOY_BETWEEN := 3.5
## Every car's width, and its floor over the bed (m): over the wheels.
const WIDE := 6.0
const FLOOR := 1.4
## How far a car's underframe reaches under the bed (m): down into it, so
## nothing flies under a car where the bed stands off the land or the water.
const UNDER := 2.0
## The gap between two cars (m, coupler to coupler) and each bogie's way in
## from its car's end.
const GAP := 1.6
const BOGIE := 3.0
## The train, front to back: [kind, length, height over the bed] (m).
const CARS := [
	["engine",22.0,8.5],["tender",12.0,6.0],
	["box",24.0,9.0],["flat",20.0,2.6],["box",24.0,9.0],["flat",20.0,2.6],
	["box",24.0,9.0],["flat",20.0,2.6],["box",24.0,9.0],["van",14.0,7.5]]
## The keep-out: a car is asked only with the plane within its half length plus
## NEAR m of its middle; a plane already inside (its roll grew its reach by a
## car's side) is put out the nearest way if that is under KEEP_MOST m, else left
## to SkyGlide; EASE m more than the face, so the next test is clear.
const NEAR := 12.0
const KEEP_MOST := 1.2
const EASE := 0.02
## A car that runs into the plane: its speed into the plane given to the plane's
## own (when the face is at least CATCH_ALONG ahead of its way) or as a shove,
## at most CATCH_MOST m/s (more is a crash anyway).
const CATCH_ALONG := 0.25
const CATCH_MOST := 12.0
## A touch is a car's if its point is within this of the car's solid (m).
const TOUCH := 1.0
## The test: where the plane starts by the train (--train-test): this far behind
## the last car's end, this far out from the train's side, this high over the bed.
const START_BACK := 30.0
const START_OUT := 9.0
const START_UP := 4.0
## The test train's nose at the start (m along the test path).
const TEST_HEAD := 700.0

## The share of a block's colour it shows in shade (greybox sky fill).
const FILL := 0.35
const LOOKS := {
	"under":Color(0.12,0.12,0.13), "iron":Color(0.17,0.18,0.2), "cab":Color(0.3,0.12,0.1),
	"box":Color(0.55,0.25,0.17), "flat":Color(0.45,0.37,0.28), "van":Color(0.62,0.2,0.14),
	"load":Color(0.36,0.4,0.3)}

var game: Node3D
var path: RefCounted
var track := 0
## +1 runs +s along the path, -1 the other way.
var way := 1.0
var speed := SPEED
var s0 := 0.0
var t := 0.0
var head := 0.0
var label := "rail/train"
var keep := true
## Each car: {kind, long, tall, front (m from the nose to its front), node, body,
## record, boxes, xf, inv, was (last frame's xf), was_inv}.
var cars: Array[Dictionary] = []
## The touch a car made running into the plane this frame: {normal, at, car}, or {}.
var rammed := {}
## How many frames a car has run into the plane, and the most it moved it (m).
var rams := 0
var ram_most := 0.0
var _dt := 1.0/60.0
var _mats := {}

## The spacing of a path's two tracks, centre to centre, that leaves an
## opening between two trains side by side (m).
static func spacing() -> float:
	return WIDE+WorldScale.opening(TOY_BETWEEN)

static func test_wanted() -> bool:
	return "--train-test" in LaunchArgs.user_args()

## The test path in `field` (rail_test_path.gd: on the sea north-east of the start).
static func test_path(field: RefCounted) -> RefCounted:
	var sea: float = preload("res://scripts/endless/land_field.gd").SEA_Y
	var h := func(x: float, z: float) -> float: return maxf(float(field.height(x,z)),sea)+TestPath.BED
	return TestPath.new(h,spacing())

static func length_of() -> float:
	var n := 0.0
	for c: Array in CARS: n += float(c[1])
	return n+GAP*(CARS.size()-1)

## Where the plane starts on the test (--train-test): {at (XZ), heading, alt
## (over the sea)}, beside the test train's last car, flying its way, the
## train on its right.
static func test_start(p: RefCounted) -> Dictionary:
	var s := TEST_HEAD-length_of()-START_BACK
	var x: Transform3D = p.pose(s,0)
	var at := x.origin+x.basis.x*(-0.5*WIDE-START_OUT)
	var f := -x.basis.z
	var sea: float = preload("res://scripts/endless/land_field.gd").SEA_Y
	return {"at":Vector2(at.x,at.z),"heading":atan2(-f.x,-f.z),"alt":at.y-sea+START_UP}

static func speed_flag(otherwise := SPEED) -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--train-speed="): return maxf(0.0,a.trim_prefix("--train-speed=").to_float())
	return otherwise

func setup(g: Node3D, rail_path: RefCounted, on_track := 0, runs := 1.0, nose := TEST_HEAD, handle := "rail/train") -> void:
	game = g
	path = rail_path
	track = on_track
	way = runs
	s0 = nose
	label = handle
	name = "RailTrain"
	speed = speed_flag()
	keep = not ("--train-keep=0" in LaunchArgs.user_args())
	var front := 0.0
	for i in range(CARS.size()):
		var spec: Array = CARS[i]
		var car := {"kind":str(spec[0]),"long":float(spec[1]),"tall":float(spec[2]),"front":front}
		front += float(spec[1])+GAP
		_build(car,i)
		cars.append(car)
	_pose()
	for car: Dictionary in cars:
		car.was = car.xf
		car.was_inv = car.inv

## One frame, before the plane's move (after the study's `solid_pad` is set):
## the train runs on, and the plane is held out of the cars that came at it.
func before(delta: float) -> void:
	_dt = maxf(delta,0.0001)
	t += delta
	rammed = {}
	for car: Dictionary in cars:
		car.was = car.xf
		car.was_inv = car.inv
	_pose()
	if keep: keep_out()

## One frame, after the plane's move and before FlightContact: a car that ran
## into the plane gives it the speed it came at it by, along the face (so the
## same face doesn't catch it again next frame, and the plane is pushed once,
## not carried), and is the plane's touch if its own move made none.
func after(_delta: float) -> void:
	if rammed.is_empty(): return
	var plane = game.plane
	var n: Vector3 = rammed.normal
	var v: Vector3 = plane.velocity
	var into := -(v-velocity_at(rammed.car,rammed.at)).dot(n)
	if into > 0.0:
		var along := v.normalized().dot(n) if v.length() > 1.0 else 0.0
		if along > CATCH_ALONG: plane.speed = float(plane.speed)+minf(into/along,CATCH_MOST)
		else: plane.bump = (plane.bump as Vector3)+n*minf(into,CATCH_MOST)
	if not (plane.contact as Dictionary).is_empty(): return
	plane.contact = {"kind":"brush","velocity":v,"normal":n}

## `v` (a touch's velocity at world `at`) less the velocity of the car `at` is
## on, if any: what FlightContact grades a touch of a car by.
func relative(at: Vector3, v: Vector3) -> Vector3:
	for car: Dictionary in cars:
		if (car.xf as Transform3D).origin.distance_to(at) > float(car.long)*0.5+NEAR: continue
		var l: Vector3 = (car.inv as Transform3D)*at
		for b: AABB in car.boxes:
			if l.y < b.position.y-TOUCH or l.y > b.end.y+TOUCH: continue
			var dx := maxf(0.0,maxf(b.position.x-l.x,l.x-b.end.x))
			var dz := maxf(0.0,maxf(b.position.z-l.z,l.z-b.end.z))
			if dx*dx+dz*dz <= TOUCH*TOUCH: return v-velocity_at(car,at)
	return v

## The velocity (m/s) of the point of `car` now at world `at`.
func velocity_at(car: Dictionary, at: Vector3) -> Vector3:
	var then: Vector3 = (car.was as Transform3D)*((car.inv as Transform3D)*at)
	return (at-then)/_dt

## The plane held out of every car near it the way the car came at it (above).
func keep_out() -> void:
	var plane = game.plane
	var p: Vector3 = plane.position
	var pad := float(game.solid_pad)
	for car: Dictionary in cars:
		var xf: Transform3D = car.xf
		if xf.origin.distance_to(p) > float(car.long)*0.5+NEAR: continue
		var l: Vector3 = (car.inv as Transform3D)*p
		var lw: Vector3 = (car.was_inv as Transform3D)*p
		var out := l
		for _again in range(2):
			for b: AABB in car.boxes:
				var r := _out_of(b,out,lw,pad)
				if r.is_empty(): continue
				out = r.at
				var n: Vector3 = xf.basis*(r.normal as Vector3)
				rammed = {"normal":n.normalized(),"at":xf*out,"car":car}
		if out == l: continue
		var moved := (xf*out).distance_to(p)
		rams += 1
		ram_most = maxf(ram_most,moved)
		p = xf*out
	if p != plane.position: plane.position = p

## Local `l` put out of box `b` grown by `pad` round (in XZ, under its top), by
## the face the plane's way from `lw` (where it was in the car last frame) crossed,
## or, already inside, the nearest side under KEEP_MOST: {at, normal} (local), or
## {} if `l` is clear of it. Over the box's top is SkyGlide's to ride.
static func _out_of(b: AABB, l: Vector3, lw: Vector3, pad: float) -> Dictionary:
	if l.y < b.position.y or l.y > b.end.y: return {}
	var dx := maxf(0.0,maxf(b.position.x-l.x,l.x-b.end.x))
	var dz := maxf(0.0,maxf(b.position.z-l.z,l.z-b.end.z))
	if dx*dx+dz*dz > pad*pad: return {}
	var lo := Vector2(b.position.x-pad,b.position.z-pad)
	var hi := Vector2(b.end.x+pad,b.end.z+pad)
	# The faces crossed, and when on the way from `lw` to `l` (the latest is the one).
	var best := -1.0
	var face := Vector3.ZERO
	var at := l
	var d := l-lw
	if lw.x < lo.x and d.x > 0.0:
		var f := (lo.x-lw.x)/d.x
		if f > best:
			best = f
			face = Vector3(-1.0,0.0,0.0)
			at = Vector3(lo.x-EASE,l.y,l.z)
	if lw.x > hi.x and d.x < 0.0:
		var f := (hi.x-lw.x)/d.x
		if f > best:
			best = f
			face = Vector3(1.0,0.0,0.0)
			at = Vector3(hi.x+EASE,l.y,l.z)
	if lw.z < lo.y and d.z > 0.0:
		var f := (lo.y-lw.z)/d.z
		if f > best:
			best = f
			face = Vector3(0.0,0.0,-1.0)
			at = Vector3(l.x,l.y,lo.y-EASE)
	if lw.z > hi.y and d.z < 0.0:
		var f := (hi.y-lw.z)/d.z
		if f > best:
			best = f
			face = Vector3(0.0,0.0,1.0)
			at = Vector3(l.x,l.y,hi.y+EASE)
	if best >= 0.0: return {"at":at,"normal":face}
	# Inside already: the nearest side, if near.
	var ways := [Vector4(l.x-lo.x,-1.0,0.0,lo.x-EASE),Vector4(hi.x-l.x,1.0,0.0,hi.x+EASE),Vector4(l.z-lo.y,0.0,-1.0,lo.y-EASE),Vector4(hi.y-l.z,0.0,1.0,hi.y+EASE)]
	var near := Vector4(INF,0.0,0.0,0.0)
	for w: Vector4 in ways:
		if w.x < near.x: near = w
	if near.x > KEEP_MOST: return {}
	if near.y != 0.0: return {"at":Vector3(near.w,l.y,l.z),"normal":Vector3(near.y,0.0,0.0)}
	return {"at":Vector3(l.x,l.y,near.w),"normal":Vector3(0.0,0.0,near.z)}

## Every car where the train is now: between its bogies on the path.
func _pose() -> void:
	var n: float = path.length()
	head = fposmod(s0+way*speed*t,n)
	for car: Dictionary in cars:
		var sf := head-way*(float(car.front)+BOGIE)
		var sr := head-way*(float(car.front)+float(car.long)-BOGIE)
		var a: Transform3D = path.pose(sf,track)
		var b: Transform3D = path.pose(sr,track)
		var f := (a.origin-b.origin).normalized()
		var up := (a.basis.y+b.basis.y).normalized()
		up = (up-f*f.dot(up)).normalized()
		var z := -f
		var xf := Transform3D(Basis(up.cross(z),up,z),(a.origin+b.origin)*0.5)
		car.xf = xf
		car.inv = xf.affine_inverse()
		(car.node as Node3D).transform = xf
		var r: Dictionary = car.record
		r.pos = xf.origin
		var yaw := atan2(-f.x,-f.z)
		r.cos = cos(yaw)
		r.sin = sin(yaw)
		r.xf = xf
		r.inv = car.inv
	GroundNative.bump_loose()

## Car `car` (number `i`): its blocks, its StaticBody, its record in `loose`.
func _build(car: Dictionary, i: int) -> void:
	var node := Node3D.new()
	node.name = "Car%d" % i
	add_child(node)
	car.node = node
	var parts := _parts(str(car.kind),float(car.long),float(car.tall))
	var boxes: Array[AABB] = []
	for part: Array in parts:
		var box: AABB = part[0]
		boxes.append(box)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		mi.mesh = mesh
		mi.position = box.get_center()
		mi.material_override = _mat(str(part[1]))
		node.add_child(mi)
	car.boxes = boxes
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = game.arches.LAYER
	body.collision_mask = 0
	for box: AABB in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	node.add_child(body)
	car.body = body
	var record := {"name":"%s/car%d" % [label,i],"kind":"train","node":node,"pos":Vector3.ZERO,"cos":1.0,"sin":0.0,
		"xf":Transform3D.IDENTITY,"inv":Transform3D.IDENTITY,"solid":BoxSolid.build(boxes),
		"reach":float(car.long)*0.5+BoxSolid.grow_most()+2.0,"spec":{},"no_break":true,"adopted":0}
	car.record = record
	game.arches.loose.append(record)
	GroundNative.bump_loose()

## A car's blocks in its frame: [AABB, look] each. Every car has its underframe
## from UNDER under the bed to its floor; on it the kind's body.
static func _parts(kind: String, long: float, tall: float) -> Array:
	var h := long*0.5
	var w := WIDE*0.5
	var out: Array = [[_box(-w*0.9,-UNDER,-h,w*0.9,FLOOR,h),"under"]]
	match kind:
		"engine":
			var cab := 7.0
			out.append([_box(-w*0.72,FLOOR,-h+1.0,w*0.72,6.2,h-cab),"iron"])
			out.append([_box(-w,FLOOR,h-cab,w,tall,h),"cab"])
			out.append([_box(-0.8,6.2,-h+2.4,0.8,tall,-h+4.0),"iron"])
			out.append([_box(-1.0,6.2,-h+9.0,1.0,7.4,-h+11.0),"iron"])
			out.append([_box(-w,-UNDER,-h-1.2,w,FLOOR+0.6,-h),"iron"])
		"tender":
			out.append([_box(-w,FLOOR,-h,w,tall,h),"iron"])
		"box":
			out.append([_box(-w,FLOOR,-h,w,tall,h),"box"])
		"flat":
			out.append([_box(-w,FLOOR,-h,w,tall,h),"flat"])
		"van":
			out.append([_box(-w*0.9,FLOOR,-h,w*0.9,tall-1.8,h),"van"])
			out.append([_box(-w*0.55,tall-1.8,-2.0,w*0.55,tall,2.0),"van"])
	return out

static func _box(x0: float, y0: float, z0: float, x1: float, y1: float, z1: float) -> AABB:
	return AABB(Vector3(x0,y0,z0),Vector3(x1-x0,y1-y0,z1-z0))

func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	var c: Color = LOOKS.get(key,Color.MAGENTA)
	m.albedo_color = c
	m.roughness = 0.85
	# A sky fill of its own: the land's shaders bring theirs, a plain material
	# none, and a car's shaded side went black.
	m.emission_enabled = true
	m.emission = c*FILL
	_mats[key] = m
	return m

func _exit_tree() -> void:
	if game == null or not is_instance_valid(game.arches): return
	for car: Dictionary in cars: game.arches.loose.erase(car.record)
	GroundNative.bump_loose()
