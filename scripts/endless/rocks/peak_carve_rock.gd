extends RefCounted
## The rock of the Peak's carve (scripts/endless/peak_carve.gd), built on a worker:
## plain data, no nodes. A piece is a table of primitives read as a distance field,
## so a wall can have real holes, a blade can lean and a sill can run into the
## slope, none of which a lofted pillar (rock_build.gd) or the heightfield can hold.
##
## `spec.prims`, all local to `spec.pos`:
##   {wall: [Vector2 xz...], tops: [y...], half: [half thickness at the foot...]}
##       a sheet along a line, its top line and battered sides
##   {blade: Vector2 xz, yaw, long, thin, top, lean: Vector2, tilt}
##       a fin: long and thin in plan, narrowing up to a broken edge
##   {hole: Vector3 middle, way: Vector3 unit, w, h, deep}
##       cut from everything: a squared tube along `way`, w and h its half sizes
## Under the land's height less SINK it stops, so every foot is buried.
##
## The surface is a surface net of the field at `spec.cell` m. Over the shapes go
## the crown's own geology: the towers' beds at the same heights
## (PeakTowerShape.strata), broken across by columnar joints (a cellular noise
## drawn out upward, so faces end in steps, not curves) and a little lump. It takes
## the land's rock paint and RockShape.
##
## Levels: vertices clustered at 2 and 4 cells, indices into the same vertices.
## Collider and flight solid are level 0, so what you see is what you hit.

const Field = preload("res://scripts/endless/land_field.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")
const TowerShape = preload("res://scripts/endless/rocks/peak_tower_shape.gd")
const BuildRock = preload("res://scripts/endless/rocks/rock_build.gd")

## How far under the land a piece's rock goes (m).
const SINK := 10.0
## The land's height is read on a grid of this many m.
const GROUND_STEP := 6.0
## A block of the lattice is read whole only when the field comes this near it.
const BLOCK := 4
## The most the surface moves off the shapes (m).
const PUSH_MOST := 12.0
## The beds (m of push), the joints', the lumps'.
const BED := 3.4
const JOINT := 3.0
const JOINT_SPAN := Vector2(13.0,48.0)
const LUMP := 3.2
const LUMP_SPAN := 34.0
## A hole's corners: 2 round, more squarer.
const HOLE_POWER := 2.8
## How far a hole's wall strays off its section (m, about).
const HOLE_ROUGH := 3.0
## The big blocks: push (m), span across and up.
const CHUNK := 4.5
const CHUNK_SPAN := Vector2(34.0,70.0)

static var _strata := {}
static var _strata_lock := Mutex.new()

static func _geology(land_seed: int) -> Dictionary:
	_strata_lock.lock()
	if not _strata.has(land_seed): _strata[land_seed] = TowerShape.strata(land_seed)
	var got: Dictionary = _strata[land_seed]
	_strata_lock.unlock()
	return got

class Sdf extends RefCounted:
	var walls: Array = []
	var blades: Array = []
	var holes: Array = []
	var hard: PackedFloat32Array
	var dip := Vector2.ZERO
	var at_world := Vector3.ZERO
	var lumps := FastNoiseLite.new()
	var joints := FastNoiseLite.new()
	var ground := PackedFloat32Array()
	var g0 := Vector2.ZERO
	var gn := Vector2i.ZERO

	func land(x: float, z: float) -> float:
		var fx := clampf((x-g0.x)/GROUND_STEP,0.0,gn.x-1.001)
		var fz := clampf((z-g0.y)/GROUND_STEP,0.0,gn.y-1.001)
		var i := int(fx)
		var j := int(fz)
		fx -= i
		fz -= j
		var q := j*gn.x+i
		return lerpf(lerpf(ground[q],ground[q+1],fx),lerpf(ground[q+gn.x],ground[q+gn.x+1],fx),fz)

	## The shapes alone: under 0 inside. Not quite a distance, near enough for the
	## blocks' test (over by the walls' batter, never under by more than a few m).
	func shapes(x: float, y: float, z: float) -> float:
		var d := INF
		for w: Array in walls:
			var pts: PackedVector2Array = w[0]
			var tops: PackedFloat32Array = w[1]
			var half: PackedFloat32Array = w[2]
			var best := INF
			var t_best := 0.0
			var k_best := 0
			for k in pts.size()-1:
				var a := pts[k]
				var ab := pts[k+1]-a
				var t := clampf(((x-a.x)*ab.x+(z-a.y)*ab.y)/ab.length_squared(),0.0,1.0)
				var ex := a.x+ab.x*t-x
				var ez := a.y+ab.y*t-z
				var dist := ex*ex+ez*ez
				if dist < best:
					best = dist
					t_best = t
					k_best = k
			var top := lerpf(tops[k_best],tops[k_best+1],t_best)
			var thick := lerpf(half[k_best],half[k_best+1],t_best)
			var tall := maxf(top-land(x,z),12.0)
			var u := clampf((top-y)/tall,0.0,1.3)
			var e := maxf(sqrt(best)-thick*(0.42+0.58*u),y-top)
			d = minf(d,e)
		for b: Array in blades:
			var at: Vector2 = b[0]
			var u := clampf((y-float(b[8]))/(float(b[4])-float(b[8])),0.0,1.0)
			var lean: Vector2 = b[5]
			var px := x-at.x-lean.x*u*u
			var pz := z-at.y-lean.y*u*u
			var s := px*float(b[1])+pz*float(b[9])
			var q := -px*float(b[9])+pz*float(b[1])
			var narrow := 1.0-0.72*pow(u,1.6)
			var long := float(b[2])*narrow
			var thin := float(b[3])*narrow
			var diamond := (absf(s)/long+absf(q)/thin*0.8-1.0)*thin
			var e := maxf(diamond,y-(float(b[4])-float(b[6])*(s/maxf(long,1.0)+1.0)))
			d = minf(d,e)
		return d

	## Cut by the holes: under 0 still rock.
	func cut(d: float, x: float, y: float, z: float) -> float:
		for h: Array in holes:
			var m: Vector3 = h[0]
			var way: Vector3 = h[1]
			var ox := x-m.x
			var oy := y-m.y
			var oz := z-m.z
			var along := ox*way.x+oy*way.y+oz*way.z
			if absf(along) > float(h[6])+8.0: continue
			var right: Vector3 = h[2]
			var up: Vector3 = h[3]
			var su := (ox*right.x+oy*right.y+oz*right.z)/float(h[4])
			var sv := (ox*up.x+oy*up.y+oz*up.z)/float(h[5])
			var r := pow(pow(absf(su),HOLE_POWER)+pow(absf(sv),HOLE_POWER),1.0/HOLE_POWER)
			# Never a clean ring: the section wanders with the way round, more up
			# top and in the shoulders, the floor flatter.
			if r < 1.8:
				var ang := atan2(sv,su)
				var ph := float(h[7])
				var wander := 0.13*sin(ang*2.0+ph)+0.11*sin(ang*3.0+ph*1.7)+0.07*sin(ang*5.0+ph*2.3)
				r *= 1.0-wander*smoothstep(-0.7,0.2,sv)
			var e := maxf((r-1.0)*minf(float(h[4]),float(h[5])),absf(along)-float(h[6]))
			# Its wall is the same broken rock, not a bored tube.
			if absf(e) < HOLE_ROUGH*2.0+1.0: e -= push(x,y,z)*HOLE_ROUGH/PUSH_MOST
			d = maxf(d,-e)
		return d

	## How far the surface stands out here, by the crown's geology.
	func push(x: float, y: float, z: float) -> float:
		var wx := x+at_world.x
		var wy := y+at_world.y
		var wz := z+at_world.z
		var over := wy-Field.SEA_Y+wx*dip.x+wz*dip.y
		var k := clampi(int(over)-TowerShape.STRATA_LOW,0,hard.size()-1)
		var pinch := lumps.get_noise_3d(wx/110.0,wy/40.0,wz/110.0)*0.9+0.55
		var c := joints.get_noise_3d(wx/JOINT_SPAN.x,wy/JOINT_SPAN.y,wz/JOINT_SPAN.x)
		var l := lumps.get_noise_3d(wx/LUMP_SPAN,wy/LUMP_SPAN,wz/LUMP_SPAN)
		var big := joints.get_noise_3d(wx/CHUNK_SPAN.x+91.0,wy/CHUNK_SPAN.y,wz/CHUNK_SPAN.x)
		return hard[k]*BED*clampf(pinch,0.0,1.0)+c*JOINT+l*LUMP+big*CHUNK

## A built piece: {spec, kind "rock", arrays, lods, faces, boxes, tris}.
static func build(spec: Dictionary, field: RefCounted) -> Dictionary:
	var pos: Vector3 = spec.pos
	var cell := float(spec.get("cell",2.5))
	var geo := _geology(int(field.seed))
	var f := Sdf.new()
	f.hard = geo.hard
	f.dip = geo.dip
	f.at_world = pos
	f.lumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	f.lumps.seed = int(spec.seed)
	f.lumps.frequency = 1.0
	f.lumps.fractal_type = FastNoiseLite.FRACTAL_NONE
	f.joints.noise_type = FastNoiseLite.TYPE_CELLULAR
	f.joints.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	f.joints.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	f.joints.seed = int(spec.seed)+7
	f.joints.frequency = 1.0
	f.joints.fractal_type = FastNoiseLite.FRACTAL_NONE
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p: Dictionary in spec.prims:
		if p.has("wall"):
			var pts := PackedVector2Array(p.wall)
			var tops := PackedFloat32Array(p.tops)
			var half := PackedFloat32Array(p.half)
			f.walls.append([pts,tops,half])
			for k in pts.size():
				var r := float(half[k])+PUSH_MOST+cell*2.0
				lo = lo.min(Vector3(pts[k].x-r,tops[k]-260.0,pts[k].y-r))
				hi = hi.max(Vector3(pts[k].x+r,tops[k]+PUSH_MOST+cell*2.0,pts[k].y+r))
		elif p.has("blade"):
			var at: Vector2 = p.blade
			var yaw := float(p.yaw)
			var tilt := float(p.get("tilt",0.0))
			var low := float(p.get("low",-200.0))
			var lean: Vector2 = p.get("lean",Vector2.ZERO)
			f.blades.append([at,cos(yaw),float(p.long),float(p.thin),float(p.top),lean,tilt,0.0,low,sin(yaw)])
			var r := float(p.long)+PUSH_MOST+lean.length()+cell*2.0
			lo = lo.min(Vector3(at.x-r,low,at.y-r))
			hi = hi.max(Vector3(at.x+r,float(p.top)+absf(tilt)+PUSH_MOST+cell*2.0,at.y+r))
		elif p.has("hole"):
			var way: Vector3 = (p.way as Vector3).normalized()
			var right := Vector3.UP.cross(way).normalized()
			if right.length_squared() < 0.5: right = Vector3.RIGHT
			var up := way.cross(right).normalized()
			f.holes.append([p.hole,way,right,up,float(p.w),float(p.h),float(p.deep),(p.hole as Vector3).dot(Vector3(0.13,0.07,0.11))])
	# The land under it, and the box's floor: no deeper than it needs.
	var nx0 := Vector2(floorf(lo.x/GROUND_STEP)*GROUND_STEP,floorf(lo.z/GROUND_STEP)*GROUND_STEP)
	f.g0 = nx0
	f.gn = Vector2i(int(ceil((hi.x-nx0.x)/GROUND_STEP))+2,int(ceil((hi.z-nx0.y)/GROUND_STEP))+2)
	f.ground.resize(f.gn.x*f.gn.y)
	var floor_y := INF
	for j in f.gn.y:
		for i in f.gn.x:
			var h: float = float(field.height(pos.x+nx0.x+i*GROUND_STEP,pos.z+nx0.y+j*GROUND_STEP))-pos.y
			f.ground[j*f.gn.x+i] = h
			floor_y = minf(floor_y,h)
	lo.y = maxf(lo.y,floor_y-SINK-cell*2.0)
	var n := Vector3i(((hi-lo)/cell).ceil())+Vector3i.ONE
	var count := n.x*n.y*n.z
	# Every BLOCK-th node read first, shapes only: far from the surface the block
	# keeps that value and is never meshed.
	var vals := PackedFloat32Array()
	vals.resize(count)
	vals.fill(1000.0)
	var nb := Vector3i((n.x-1)/BLOCK+1,(n.y-1)/BLOCK+1,(n.z-1)/BLOCK+1)
	var keep := PackedByteArray()
	keep.resize(nb.x*nb.y*nb.z)
	var blk := float(BLOCK)*cell
	var near := blk*0.9+PUSH_MOST+6.0
	for bz in nb.z:
		for by in nb.y:
			for bx in nb.x:
				var x := lo.x+(bx+0.5)*blk
				var y := lo.y+(by+0.5)*blk
				var z := lo.z+(bz+0.5)*blk
				var d := maxf(f.shapes(x,y,z),f.land(x,z)-SINK-y)
				if d > near: continue
				if f.cut(d,x,y,z) < -near:
					keep[(bz*nb.y+by)*nb.x+bx] = 2
					continue
				keep[(bz*nb.y+by)*nb.x+bx] = 1
				var i1 := mini((bx+1)*BLOCK,n.x-1)
				var j1 := mini((by+1)*BLOCK,n.y-1)
				var k1 := mini((bz+1)*BLOCK,n.z-1)
				for k in range(bz*BLOCK,k1+1):
					for j in range(by*BLOCK,j1+1):
						var row := (k*n.y+j)*n.x
						for i in range(bx*BLOCK,i1+1):
							if vals[row+i] != 1000.0: continue
							var sx := lo.x+i*cell
							var sy := lo.y+j*cell
							var sz := lo.z+k*cell
							var s := f.shapes(sx,sy,sz)
							var e := s
							if absf(e) < PUSH_MOST+cell*2.0: e -= f.push(sx,sy,sz)
							e = f.cut(e,sx,sy,sz)
							e = maxf(e,f.land(sx,sz)-SINK-sy)
							vals[row+i] = e
	# Blocks whose whole-rock neighbours were skipped read +1000 there: those
	# edges would be false surface, so a skipped solid block has to read inside.
	for bz in nb.z:
		for by in nb.y:
			for bx in nb.x:
				if keep[(bz*nb.y+by)*nb.x+bx] != 2: continue
				var i1 := mini((bx+1)*BLOCK,n.x-1)
				var j1 := mini((by+1)*BLOCK,n.y-1)
				var k1 := mini((bz+1)*BLOCK,n.z-1)
				for k in range(bz*BLOCK,k1+1):
					for j in range(by*BLOCK,j1+1):
						var row := (k*n.y+j)*n.x
						for i in range(bx*BLOCK,i1+1):
							if vals[row+i] == 1000.0: vals[row+i] = -1000.0
	return _mesh(spec,vals,n,lo,cell)

## The surface net of `vals` (`n` nodes, `cell` m from `lo`), in local space.
static func _mesh(spec: Dictionary, vals: PackedFloat32Array, n: Vector3i, lo: Vector3, cell: float) -> Dictionary:
	var sx := 1
	var sy := n.x
	var sz := n.x*n.y
	var vert_of := PackedInt32Array()
	vert_of.resize(vals.size())
	vert_of.fill(-1)
	var v := PackedVector3Array()
	var cells := PackedInt32Array()
	var corner := PackedInt32Array([0,sx,sy,sx+sy,sz,sz+sx,sz+sy,sz+sy+sx])
	const EDGES := [[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]]
	const OFFS := [Vector3(0,0,0),Vector3(1,0,0),Vector3(0,1,0),Vector3(1,1,0),Vector3(0,0,1),Vector3(1,0,1),Vector3(0,1,1),Vector3(1,1,1)]
	for k in n.z-1:
		for j in n.y-1:
			var row := (k*n.y+j)*n.x
			for i in n.x-1:
				var q := row+i
				var inside := 0
				var outside := 0
				var c0 := vals[q]
				if c0 < 0.0: inside += 1
				else: outside += 1
				for m in range(1,8):
					if vals[q+corner[m]] < 0.0: inside += 1
					else: outside += 1
				if inside == 0 or outside == 0: continue
				var sum := Vector3.ZERO
				var hits := 0
				for e: Array in EDGES:
					var a := float(vals[q+corner[int(e[0])]])
					var b := float(vals[q+corner[int(e[1])]])
					if (a < 0.0) == (b < 0.0): continue
					if absf(a) >= 999.0 or absf(b) >= 999.0:
						sum += (OFFS[int(e[0])] as Vector3).lerp(OFFS[int(e[1])],0.5)
					else:
						sum += (OFFS[int(e[0])] as Vector3).lerp(OFFS[int(e[1])],a/(a-b))
					hits += 1
				vert_of[q] = v.size()
				v.append(lo+(Vector3(i,j,k)+sum/hits)*cell)
				cells.append(q)
	var idx := PackedInt32Array()
	# A quad round each edge the surface crosses.
	for t in cells.size():
		var q: int = cells[t]
		var c0 := vals[q]
		var ins := c0 < 0.0
		var i := q%n.x
		var j := (q/n.x)%n.y
		var k := q/(n.x*n.y)
		# Edge along x from the cell's first node: the cells round it.
		if j > 0 and k > 0 and (vals[q+sx] < 0.0) != ins:
			_quad(idx,vert_of,q,q-sy,q-sy-sz,q-sz,ins)
		if i > 0 and k > 0 and (vals[q+sy] < 0.0) != ins:
			_quad(idx,vert_of,q,q-sz,q-sx-sz,q-sx,ins)
		if i > 0 and j > 0 and (vals[q+sz] < 0.0) != ins:
			_quad(idx,vert_of,q,q-sx,q-sx-sy,q-sy,ins)
	var nrm := BuildRock._normals(v,idx)
	var c := PackedColorArray()
	c.resize(v.size())
	var rock := Field.ROCK
	var shade := FastNoiseLite.new()
	shade.seed = int(spec.seed)+3
	shade.frequency = 0.08
	for i in v.size():
		var s := 0.82+shade.get_noise_3dv(v[i])*0.2
		c[i] = Color(rock.r*s,rock.g*s,rock.b*s*0.97,0.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = nrm
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	RockShape.bake(arrays)
	var lods := {}
	var tris: Array = [idx.size()/3]
	for level in range(1,3):
		var size := cell*(1 << level)
		var coarse := _clustered(v,idx,lo,size)
		lods[size*0.7] = coarse
		tris.append(coarse.size()/3)
	var faces := PackedVector3Array()
	faces.resize(idx.size())
	for i in idx.size(): faces[i] = v[idx[i]]
	# The mesh is made here: packing its arrays is what would cost the main thread.
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods,RockShape.format(arrays))
	return {"spec":spec,"kind":"rock","mesh":mesh,"faces":faces,"boxes":[],"tris":tris[0],"levels":tris}

static func _quad(idx: PackedInt32Array, vert_of: PackedInt32Array, a: int, b: int, c: int, d: int, ins: bool) -> void:
	var va := vert_of[a]
	var vb := vert_of[b]
	var vc := vert_of[c]
	var vd := vert_of[d]
	if va < 0 or vb < 0 or vc < 0 or vd < 0: return
	if ins: idx.append_array([va,vc,vb,va,vd,vc])
	else: idx.append_array([va,vb,vc,va,vc,vd])

## `idx` with each vertex moved to its cluster's nearest-the-middle vertex
## (`size` m clusters), the triangles that closed dropped.
static func _clustered(v: PackedVector3Array, idx: PackedInt32Array, lo: Vector3, size: float) -> PackedInt32Array:
	var best := {}
	var best_d := {}
	var cluster := PackedInt32Array()
	cluster.resize(v.size())
	var keys: Array[Vector3i] = []
	for i in v.size():
		var rel := (v[i]-lo)/size
		var key := Vector3i(rel.floor())
		var d := (rel-Vector3(key)-Vector3(0.5,0.5,0.5)).length_squared()
		if not best.has(key) or d < float(best_d[key]):
			best[key] = i
			best_d[key] = d
		keys.append(key)
	for i in v.size(): cluster[i] = int(best[keys[i]])
	var out := PackedInt32Array()
	for t in range(0,idx.size(),3):
		var a := cluster[idx[t]]
		var b := cluster[idx[t+1]]
		var c := cluster[idx[t+2]]
		if a == b or b == c or a == c: continue
		out.append(a)
		out.append(b)
		out.append(c)
	return out
