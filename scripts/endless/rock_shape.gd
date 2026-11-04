extends RefCounted
## The rock's shape, baked once into a mesh for the rock shader
## (shaders/endless_rock.gdshaderinc, rock_shape): how far each vertex stands
## proud of (over 0.5) or sunk below (under) the surface round it, RADII m
## out, in CUSTOM3 (RGBA8): r a worn edge, g a ledge or groove, b a buttress
## or recess; a is 1 where it was baked. A mesh without it is drawn as before.
##
## Any rock mesh drawn with the land's ground material takes it in two lines:
##
##   RockShape.bake(arrays)                         # on the worker, indexed arrays
##   mesh.add_surface_from_arrays(PRIMITIVE_TRIANGLES, arrays, [], lods, RockShape.format(arrays))
##
## The land's chunks use `grid` instead: a height grid's own way, faster, and
## matching their neighbours' edges exactly. --rock-shape=0 bakes nothing.

const RADII := [4.0,14.0,40.0]
## Each radius's proud or sunk height (m per m of radius) that fills its range,
## measured against a ring at the radius (`grid`'s way).
const GAIN := [1.6,1.0,0.7]
## `grid`: each radius's grid, about this many of its nodes to the radius.
const GRID_STEPS := [2,3,3]
## `grid`: a chunk with no ground steeper than this (its normals' up) is no
## rock, and gets no shape.
const STEEP_UP := 0.9
## `grid`: a chunk with ground over this (world y, m; 70 over the sea) gets a
## shape too, for the summits' snow (--summits=old: not).
const HIGH_Y := 30.0

static var SUMMITS := "--summits=old" not in preload("res://scripts/launch_args.gd").user_args()
static var wanted := "--rock-shape=0" not in preload("res://scripts/launch_args.gd").user_args()

## The format flag to add for `arrays`' shape (0 if it has none).
static func format(arrays: Array) -> int:
	if arrays.size() > Mesh.ARRAY_CUSTOM3 and arrays[Mesh.ARRAY_CUSTOM3] != null:
		return Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT
	return 0

# --- Any mesh -----------------------------------------------------------------

## Bakes an indexed mesh's shape into arrays[ARRAY_CUSTOM3], in the mesh's own
## space (a node over it may turn and move it, not scale it). Each vertex is
## measured along its normal against the centroid of the surface within each
## radius, the surface read as clusters of its vertices (each weighted by its
## share of the triangles' area) a radius wide, so the cost is the vertices
## times the clusters near them, whatever the radius.
static func bake(arrays: Array) -> void:
	if not wanted: return
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var count := v.size()
	if count == 0 or idx.is_empty(): return
	var area := PackedFloat32Array()
	area.resize(count)
	for i in range(0,idx.size(),3):
		var a := (v[idx[i+1]]-v[idx[i]]).cross(v[idx[i+2]]-v[idx[i]]).length()/6.0
		area[idx[i]] += a
		area[idx[i+1]] += a
		area[idx[i+2]] += a
	var shape := PackedByteArray()
	shape.resize(count*4)
	for i in count: shape[i*4+3] = 255
	for c in 3:
		var r: float = RADII[c]
		# A ring's mean sits r^2/2 off a bowl's lip, the falloff-weighted disc's
		# centroid r^2/6: three times the gain gives the land's scale.
		var gain: float = GAIN[c]*3.0/r
		# Clusters a radius wide: the weighted sum of their vertices' positions.
		var sums := {}
		var cell_of := PackedInt32Array()
		cell_of.resize(count)
		var keys: Array[Vector3i] = []
		for i in count:
			var k := Vector3i((v[i]/r).floor())
			if not sums.has(k):
				sums[k] = keys.size()
				keys.append(k)
			cell_of[i] = int(sums[k])
		var cp := PackedVector3Array()
		var cw := PackedFloat32Array()
		cp.resize(keys.size())
		cw.resize(keys.size())
		for i in count:
			var w := maxf(area[i],1e-6)
			cp[cell_of[i]] += v[i]*w
			cw[cell_of[i]] += w
		for k in keys.size(): cp[k] /= cw[k]
		# Each cluster's neighbours (the 27 cells round it), gathered once.
		var near: Array[PackedInt32Array] = []
		near.resize(keys.size())
		for k in keys.size():
			var list := PackedInt32Array()
			var at := keys[k]
			for dz in range(-1,2):
				for dy in range(-1,2):
					for dx in range(-1,2):
						var o: Variant = sums.get(at+Vector3i(dx,dy,dz))
						if o != null: list.append(int(o))
			near[k] = list
		var r2 := r*r
		for i in count:
			var p := v[i]
			var acc := Vector3.ZERO
			var wsum := 0.0
			for o in near[cell_of[i]]:
				var d2 := p.distance_squared_to(cp[o])
				if d2 >= r2: continue
				var w := cw[o]*(1.0-d2/r2)
				acc += cp[o]*w
				wsum += w
			var val := 0.0
			if wsum > 0.0: val = nrm[i].dot(p-acc/wsum)*gain
			shape[i*4+c] = int(clampf(val*0.5+0.5,0.0,1.0)*255.0)
	arrays[Mesh.ARRAY_CUSTOM3] = shape

# --- A height grid (the land's chunks) ------------------------------------------

## The shape of a land chunk (land_stream `_build`: `made` from build_chunk,
## `cells` quads of `step` m from (x0, z0), then its skirt's four edges): each
## radius read off its own grid, about GRID_STEPS of its nodes to the radius
## (a power of two of the chunk's steps), against the ring round each node,
## with a ring past the chunk so the edges match the neighbouring chunks'; a
## grid that is the chunk's own reuses its heights and samples only the ring.
## Empty for a chunk with no rock (no ground steeper than STEEP_UP).
static func grid(f: RefCounted, made: Dictionary, x0: float, z0: float, step: float, cells: int) -> PackedByteArray:
	var n := cells+1
	var normals: PackedVector3Array = made.normals
	var steep := false
	for v in n*n:
		if normals[v].y < STEEP_UP:
			steep = true
			break
	# A chunk with high ground gets it too (the summits' snow reads the 40 m
	# radius), unless --summits=old.
	if not steep and SUMMITS:
		var hs: PackedFloat32Array = made.heights
		for v in n*n:
			if hs[v] > HIGH_Y:
				steep = true
				break
	if not steep: return PackedByteArray()
	var shape := PackedByteArray()
	shape.resize((n*n+4*n)*4)
	for v in n*n: shape[v*4+3] = 255
	for c in 3:
		var r: float = RADII[c]
		var k: int = GRID_STEPS[c]
		# The grid: a power of two of the chunk's steps, about k nodes to the radius.
		var per := 1 << clampi(roundi(log(r/k/step)/log(2.0)),0,4)
		var g := per*step
		k = maxi(1,roundi(r/g))
		var d := roundi(k*0.7071)
		var gn := cells/per+1
		var m := gn+2*k
		var hs := _padded(f,made,x0,z0,step,cells,per,gn,k)
		var a: float = GAIN[c]/(k*g)*0.0625
		var lay := PackedFloat32Array()
		lay.resize(gn*gn)
		for j in gn:
			var row := (j+k)*m+k
			for i in gn:
				var q := row+i
				lay[j*gn+i] = clampf(0.5+(hs[q]*8.0-hs[q-k]-hs[q+k]-hs[q-k*m]-hs[q+k*m]-hs[q-d-d*m]-hs[q+d-d*m]-hs[q-d+d*m]-hs[q+d+d*m])*a,0.0,1.0)
		if per == 1:
			for v in n*n: shape[v*4+c] = int(lay[v]*255.0)
			continue
		# Coarser than the chunk: eased between the grid's nodes.
		var inv := 1.0/per
		for j in n:
			var iz := mini(j/per,gn-2)
			var fz := (j-iz*per)*inv
			for i in n:
				var ix := mini(i/per,gn-2)
				var fx := (i-ix*per)*inv
				var q := iz*gn+ix
				shape[(j*n+i)*4+c] = int(lerpf(lerpf(lay[q],lay[q+1],fx),lerpf(lay[q+gn],lay[q+gn+1],fx),fz)*255.0)
	# The skirt: its edge's shape.
	for e in 4:
		for t in n:
			var from: int = t if e == 0 else (t*n+cells if e == 1 else (cells*n+t if e == 2 else t*n))
			var v := n*n+e*n+t
			for c in 4: shape[v*4+c] = shape[from*4+c]
	return shape

## The field's heights on a grid of every `per`th chunk node (gn a side)
## with `pad` nodes more each way, row by row: the chunk's own heights inside
## (made.heights), the field sampled for the ring.
static func _padded(f: RefCounted, made: Dictionary, x0: float, z0: float, step: float, cells: int, per: int, gn: int, pad: int) -> PackedFloat32Array:
	var n := cells+1
	var g := per*step
	var m := gn+2*pad
	var out := PackedFloat32Array()
	out.resize(m*m)
	var own: PackedFloat32Array = made.heights
	for j in gn:
		for i in gn:
			out[(j+pad)*m+i+pad] = own[j*per*n+i*per]
	# The ring: full rows above and below, then the sides between.
	var top: PackedFloat32Array = f.grid(x0,z0,g,m,pad,pad).heights
	var low: PackedFloat32Array = f.grid(x0,z0+(gn+pad)*g,g,m,pad,pad).heights
	var left: PackedFloat32Array = f.grid(x0,z0+pad*g,g,pad,gn,pad).heights
	var right: PackedFloat32Array = f.grid(x0+gn*g,z0,g,pad,gn,0).heights
	for j in pad:
		for i in m:
			out[j*m+i] = top[j*m+i]
			out[(j+pad+gn)*m+i] = low[j*m+i]
	for j in gn:
		for i in pad:
			out[(j+pad)*m+i] = left[j*pad+i]
			out[(j+pad)*m+pad+gn+i] = right[j*pad+i]
	return out
