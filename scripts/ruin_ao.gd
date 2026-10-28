extends RefCounted
## How much sky each vertex of a ruin piece sees, baked into its vertex
## colour when the piece is built (RuinKit Build.finish, on the builder's
## thread). The stone's shade light is emission (shaders/folk_surface.gdshaderinc),
## which no SSAO darkens, so without this a face deep in an arch takes the
## same fill as one in the open. Darkening the vertex colour darkens that
## fill (and the sun a little, where it reaches into a crevice).
##
## The piece's own triangles are stamped into a grid of cells; from each
## vertex a few short rays leave round its normal and march the grid (and
## stop below the piece's ground). A ray blocked near counts more than one
## blocked far. Vertices at one spot facing one way share their answer.
## --ruin-ao=0 off, --ruin-ao=X its strength (STRENGTH by default);
## --ruin-ao-log prints each bake's vertices, cells and time.

const LaunchArgs = preload("res://scripts/launch_args.gd")

## How much a vertex that sees no sky is darkened (0..1).
const STRENGTH := 0.7
## The grid's cell (m); larger for a piece that would need more than MAX_CELLS.
const CELL := 0.7
const MAX_CELLS := 1500000
## Where a ray looks (m out from the vertex, after stepping a cell off its
## face), and what a block found there counts (1: no sky that way).
const STEPS := [0.6, 1.4, 2.8, 5.0]
const WEIGHT := [1.0, 0.85, 0.6, 0.35]
## The rays, round the normal: (angle from it in degrees, how many round).
const RINGS := [[0.0, 1], [52.0, 6]]

static var _strength := NAN
static var _log := false
static var _rays := PackedVector3Array()

static func strength() -> float:
	if is_nan(_strength):
		var s := STRENGTH
		for a: String in LaunchArgs.user_args():
			if a.begins_with("--ruin-ao="): s = clampf(float(a.get_slice("=",1)),0.0,1.0)
			if a == "--ruin-ao-log": _log = true
		_strength = s
	return _strength

## The rays in a frame whose z is the normal.
static func _local_rays() -> PackedVector3Array:
	if _rays.is_empty():
		var out := PackedVector3Array()
		var turn := 0.0
		for ring: Array in RINGS:
			var tilt := deg_to_rad(float(ring[0]))
			var count := int(ring[1])
			for k in range(count):
				var a := turn+TAU*k/count
				out.append(Vector3(sin(tilt)*cos(a),sin(tilt)*sin(a),cos(tilt)))
			turn += PI/count
		_rays = out
	return _rays

## `c` with each vertex darkened by the sky it doesn't see (triangles: v, n,
## c three to a face, as RuinKit draws them). `ground`: the piece's ground
## height (-INF none), below which a ray is blocked.
static func bake(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, ground: float) -> PackedColorArray:
	var amount := strength()
	if amount <= 0.0 or v.size() < 3: return c
	var began := Time.get_ticks_usec()
	var reach: float = STEPS[STEPS.size()-1]
	var box := AABB(v[0],Vector3.ZERO)
	for p in v: box = box.expand(p)
	box = box.grow(reach+CELL*2.0)
	var cell := CELL
	var volume := box.size.x*box.size.y*box.size.z
	if volume/(cell*cell*cell) > MAX_CELLS: cell = pow(volume/MAX_CELLS,1.0/3.0)
	var nx := ceili(box.size.x/cell)
	var ny := ceili(box.size.y/cell)
	var nz := ceili(box.size.z/cell)
	var o := box.position
	var inv := 1.0/cell
	var full := PackedByteArray()
	full.resize(nx*ny*nz)
	# Stamp each triangle: points over it closer than a cell apart.
	for i in range(0,v.size()-2,3):
		var a := v[i]
		var e1 := v[i+1]-a
		var e2 := v[i+2]-a
		var longest := maxf(maxf(e1.length(),e2.length()),(e2-e1).length())
		var k := maxi(1,ceili(longest/(cell*0.6)))
		for s in range(k+1):
			for t in range(k+1-s):
				var p := a+e1*(float(s)/k)+e2*(float(t)/k)
				full[floori((p.x-o.x)*inv)+nx*(floori((p.y-o.y)*inv)+ny*floori((p.z-o.z)*inv))] = 1
	var rays := _local_rays()
	var steps := PackedFloat32Array(STEPS)
	var weights := PackedFloat32Array(WEIGHT)
	var seen := {}
	var out := c.duplicate()
	var off := cell*1.05
	var per := 1.0/rays.size()
	for i in range(v.size()):
		var p := v[i]
		var normal := n[i]
		# One answer per cell and way faced (the normal in 1/3 steps).
		var key := (floori((p.x-o.x)*inv) & 0xFFFF) | (floori((p.y-o.y)*inv) & 0xFFFF) << 16 | (floori((p.z-o.z)*inv) & 0xFFFF) << 32 			| (roundi(normal.x*3.0)+3) << 48 | (roundi(normal.y*3.0)+3) << 52 | (roundi(normal.z*3.0)+3) << 56
		var sky: float
		if seen.has(key): sky = seen[key]
		else:
			# A frame round the normal.
			var side := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
			var tx := side.cross(normal).normalized()
			var ty := normal.cross(tx)
			var start := p+normal*off
			var blocked := 0.0
			for r in rays:
				var d := tx*r.x+ty*r.y+normal*r.z
				for j in range(steps.size()):
					var q := start+d*steps[j]
					if q.y < ground:
						blocked += weights[j]
						break
					var x := floori((q.x-o.x)*inv)
					var y := floori((q.y-o.y)*inv)
					var z := floori((q.z-o.z)*inv)
					if x < 0 or y < 0 or z < 0 or x >= nx or y >= ny or z >= nz: break
					if full[x+nx*(y+ny*z)] != 0:
						blocked += weights[j]
						break
			sky = 1.0-blocked*per
			seen[key] = sky
		var f := 1.0-amount*(1.0-sky)
		var col := out[i]
		out[i] = Color(col.r*f,col.g*f,col.b*f,col.a)
	if _log: print("RUIN_AO %d verts %d looked %d cells (%.2f m) %.1f ms" % [v.size(),seen.size(),nx*ny*nz,cell,(Time.get_ticks_usec()-began)/1000.0])
	return out

## The worn arrises rounded: a thin face (a chamfer strip, under THIN m
## across) takes at each corner the mean of its own normal and the faces'
## that meet it there, so the light runs across it from one face's to the
## other's instead of a hard lit line. Wide faces keep their flat normals.
## --ruin-soft=0 off.
const THIN := 0.16
const MEET := 0.17  # cos of the widest turn to a neighbour taken (80 deg)
static var _soft := -1

static func soft() -> bool:
	if _soft < 0:
		_soft = 1
		for a: String in LaunchArgs.user_args():
			if a.begins_with("--ruin-soft="): _soft = 0 if a.get_slice("=",1) == "0" else 1
	return _soft == 1

static func _spot(p: Vector3) -> int:
	return (roundi(p.x*500.0) & 0x1FFFFF) | (roundi(p.y*500.0) & 0x1FFFFF) << 21 | (roundi(p.z*500.0) & 0x1FFFFF) << 42

static func soften(v: PackedVector3Array, n: PackedVector3Array) -> PackedVector3Array:
	if not soft() or v.size() < 3: return n
	strength()
	var began := Time.get_ticks_usec()
	var thin := PackedByteArray()
	thin.resize(v.size()/3)
	var spots := {}
	for t in range(v.size()/3):
		var a := v[t*3]
		var e1 := v[t*3+1]-a
		var e2 := v[t*3+2]-a
		var longest := maxf(maxf(e1.length(),e2.length()),(e2-e1).length())
		if longest <= 0.0: continue
		var across := e1.cross(e2).length()/longest
		if across < THIN and across < longest*0.35:
			thin[t] = 1
			for k in range(3): spots[_spot(v[t*3+k])] = []
	if spots.is_empty():
		if _log: print("RUIN_SOFT %d verts %.1f ms" % [v.size(),(Time.get_ticks_usec()-began)/1000.0])
		return n
	# The distinct normals of the faces meeting at each of those corners.
	for i in range(v.size()):
		var key := _spot(v[i])
		if not spots.has(key): continue
		var list: Array = spots[key]
		var m := n[i]
		var known := false
		for q: Vector3 in list:
			if q.dot(m) > 0.999:
				known = true
				break
		if not known: list.append(m)
	var out := n.duplicate()
	for t in range(thin.size()):
		if thin[t] == 0: continue
		for k in range(3):
			var i := t*3+k
			var own := n[i]
			var sum := Vector3.ZERO
			for q: Vector3 in spots[_spot(v[i])]:
				if q.dot(own) > MEET: sum += q
			if sum.length_squared() > 1e-6: out[i] = sum.normalized()
	if _log: print("RUIN_SOFT %d verts %.1f ms" % [v.size(),(Time.get_ticks_usec()-began)/1000.0])
	return out
