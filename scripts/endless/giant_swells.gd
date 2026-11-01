extends RefCounted
## Where the giants' remains lie (giant_ruins.gd), and the land heaped round
## each: a stamp like the coast's isles (coast_isles.gd), a low rise under each
## ruin that the land's height, chunks and grids all carry. It only lifts the
## land; its paint stays. The layout is worked out here, from the seed and the
## bare land, so every machine lays the same ruins on the same land. The
## outline wobbles, so no swell is a circle.
##
## assets/models/giants/poses.json (art/blender/giant_ruins/giant_head_build.py)
## has each pose's reach and lift, and its waterline's middle.

const POSES := "res://assets/models/giants/poses.json"
const SEA_Y := -40.0
## The set lies within RANGE of the origin, a ruin in each CELL or none. The
## fixed world's 17 km across is the limit (AGENTS.md).
const RANGE := 6400.0
const CELL := 1600.0
const TRIES := 8
## Clear of the spawn, and the most the land may step under a ruin.
const SPAWN_CLEAR := 500.0
## The hall's mouth on this side (hall_doors.gd AMBER_AT).
const DOOR_AT: Vector2 = preload("res://scripts/endless/hall_doors.gd").AMBER_AT
const DOOR_CLEAR := 320.0
## The first ruin the hall shows: its pose (ruins.json) and how far out.
const FIRST_POSE := 2
const FIRST_AT := 900.0
const SPACE := 650.0
const STEP_MOST := 26.0
## A swell runs out this many times its ruin's reach, its outline in by up to
## WOBBLE of that.
const OUT := 2.0
const WOBBLE := 0.3

## Dictionaries: pose (its index), x, z, yaw.
var spots: Array = []
var _world: RefCounted
var _x := PackedFloat64Array()
var _z := PackedFloat64Array()
var _r := PackedFloat64Array()
var _lift := PackedFloat64Array()
## Swells by bucket, so a height only tests the few near it.
const BUCKET := 512.0
var _near: Dictionary = {}

## The Amberlands' home in this world: the origin alone (--world=amberlands), the
## far side of the door in the game itself (profiles/doors.gd). ZERO's INF: none.
static func home(world: RefCounted) -> Vector2:
	if world == null: return Vector2.INF
	if str(world.id) == "amberlands": return Vector2.ZERO
	if str(world.id) == "doors": return world.offset
	return Vector2.INF

static func make(world: RefCounted, land_seed: int, impl: Object) -> RefCounted:
	var centre := home(world)
	if not centre.is_finite(): return null
	var poses: Variant = JSON.parse_string(FileAccess.get_file_as_string(POSES))
	if not poses is Array:
		push_error("giant_swells: no %s" % POSES)
		return null
	var s := new()
	s._world = world
	s._lay_out(poses,land_seed,impl,centre)
	return s

func _lay_out(poses: Array, land_seed: int, impl: Object, centre: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919+land_seed*104729
	_first_sight(poses,impl,centre)
	var next := rng.randi_range(0,poses.size()-1)
	var n := int(RANGE*2.0/CELL)
	for j in n:
		for i in n:
			var p: Dictionary = poses[next]
			for t in TRIES:
				var at := Vector2(i+rng.randf_range(0.15,0.85),j+rng.randf_range(0.15,0.85))*CELL-Vector2.ONE*RANGE
				var yaw := rng.randf_range(0.0,TAU)
				if at.length() < SPAWN_CLEAR or at.length() > RANGE: continue
				if at.distance_to(DOOR_AT) < DOOR_CLEAR+float(p.reach): continue
				if _crowded(at+centre): continue
				if not _fits(impl,at+centre,float(p.reach)): continue
				_add(next,p,at+centre,yaw)
				next = (next+3)%poses.size()
				break

## The mourner's head straight out of the hall, watching the player leave it.
func _first_sight(poses: Array, impl: Object, centre: Vector2) -> void:
	var out := -DOOR_AT.normalized()
	var p: Dictionary = poses[FIRST_POSE]
	var yaw := atan2(-out.x,-out.y)
	for d: float in [FIRST_AT,FIRST_AT+160.0,FIRST_AT-160.0,FIRST_AT+320.0,FIRST_AT+480.0,FIRST_AT+640.0]:
		for turn: float in [0.0,0.2,-0.2,0.4,-0.4,0.6,-0.6]:
			var at := DOOR_AT+out.rotated(turn)*d
			if _fits(impl,at+centre,float(p.reach)):
				_add(FIRST_POSE,p,at+centre,atan2(-out.rotated(turn).x,-out.rotated(turn).y))
				return

func _crowded(at: Vector2) -> bool:
	for s: Dictionary in spots:
		if at.distance_to(Vector2(float(s.x),float(s.z))) < SPACE: return true
	return false

## Land on the Amberlands' side, and near enough level, right round the ruin.
func _fits(impl: Object, at: Vector2, reach: float) -> bool:
	if _world.has_method("side_of") and int(_world.side_of(at.x,at.y)) != 1: return false
	var lo := INF
	var hi := -INF
	for i in 12:
		var off := Vector2.from_angle(i*TAU/12.0)*(reach if i%2 == 0 else reach*0.5)
		var h := float(impl.height(at.x+off.x,at.y+off.y))
		lo = minf(lo,h)
		hi = maxf(hi,h)
	return lo > SEA_Y+6.0 and hi-lo < STEP_MOST

func _add(pose: int, p: Dictionary, at: Vector2, yaw: float) -> void:
	var rim := Vector2(float(p.rim_x),float(p.rim_z)).rotated(-yaw)
	var c := at+rim
	var i := _r.size()
	_x.append(c.x)
	_z.append(c.y)
	_r.append(float(p.reach)*OUT)
	_lift.append(float(p.lift))
	spots.append({"pose":pose,"x":at.x,"z":at.y,"yaw":yaw})
	var r := _r[i]
	for bx in range(_b(c.x-r),_b(c.x+r)+1):
		for bz in range(_b(c.y-r),_b(c.y+r)+1):
			var key := Vector2i(bx,bz)
			if not _near.has(key): _near[key] = PackedInt32Array()
			(_near[key] as PackedInt32Array).append(i)

static func _b(v: float) -> int:
	return floori(v/BUCKET)

func reaches(x: float, z: float) -> bool:
	return _near.has(Vector2i(_b(x),_b(z)))

func meets(x0: float, z0: float, x1: float, z1: float) -> bool:
	for i in _r.size():
		var dx := _x[i]-clampf(_x[i],x0,x1)
		var dz := _z[i]-clampf(_z[i],z0,z1)
		if dx*dx+dz*dz < _r[i]*_r[i]: return true
	return false

## Whether (x, z) is `room` m or more off every ruin.
func clear_of(x: float, z: float, room: float) -> bool:
	for i in _r.size():
		var r := _r[i]/OUT+room
		var dx := x-_x[i]
		var dz := z-_z[i]
		if dx*dx+dz*dz < r*r: return false
	return true

## How far the land rises at (x, z).
func lift(x: float, z: float) -> float:
	var key := Vector2i(_b(x),_b(z))
	if not _near.has(key): return 0.0
	var most := 0.0
	for i: int in _near[key]:
		var dx := x-_x[i]
		var dz := z-_z[i]
		var d2 := dx*dx+dz*dz
		if d2 >= _r[i]*_r[i]: continue
		var a := atan2(dz,dx)
		var edge := _r[i]*(1.0-WOBBLE*(0.5+0.32*sin(3.0*a+i*1.7)+0.18*sin(5.0*a+i*2.9)))
		var t := clampf(sqrt(d2)/edge,0.0,1.0)
		var f := 1.0-t*t
		most = maxf(most,_lift[i]*f*f)
	return most

## Vector2(height, meadow) `got` with the swells on it.
func apply(got: Vector2, x: float, z: float) -> Vector2:
	got.x += lift(x,z)
	return got

## land_stream's chunk arrays with the swells on them: the heights, the verts
## and their normals, the skirts after them.
func apply_chunk(impl: Object, made: Dictionary, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var w := n+2
	var heights: PackedFloat32Array = made.heights
	var hs := PackedFloat32Array()
	var mv := PackedByteArray()
	hs.resize(w*w)
	mv.resize(w*w)
	for j in w:
		for i in w:
			var x := x0+(i-1)*step
			var z := z0+(j-1)*step
			var inner := i >= 1 and i <= n and j >= 1 and j <= n
			var base := heights[(j-1)*n+i-1] if inner else float(impl.height(x,z))
			var up := lift(x,z)
			hs[j*w+i] = base+up
			if up > 0.0: mv[j*w+i] = 1
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	for j in n:
		for i in n:
			var k := (j+1)*w+i+1
			if mv[k]+mv[k-1]+mv[k+1]+mv[k-w]+mv[k+w] == 0: continue
			var v := j*n+i
			normals[v] = Vector3(hs[k-1]-hs[k+1],2.0*step,hs[k-w]-hs[k+w]).normalized()
			heights[v] = hs[k]
			verts[v] = Vector3(i*step,hs[k],j*step)
	for e in 4:
		for t in n:
			var from: int = t if e == 0 else (t*n+cells if e == 1 else (cells*n+t if e == 2 else t*n))
			var sv := n*n+e*n+t
			verts[sv] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[sv] = normals[from]
	made.heights = heights
	made.verts = verts
	made.normals = normals

## `grid`'s arrays with the swells on them.
func apply_grid(got: Dictionary, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var heights: PackedFloat32Array = got.heights
	for j in nz:
		for i in nx:
			heights[j*nx+i] += lift(x0+(i-pad)*step,z0+(j-pad)*step)
	got.heights = heights
