extends RefCounted
## The flight's solid of a built thing's boxes (local AABBs: a ruin arch's
## stones, a hall's kit colliders, a rock arch's skin sampled by
## `from_faces`), kept exact. A grid of CELL m
## cells lists the boxes within GROW_MOST of each, so a query at a point
## reads one cell and grows each box there by the pad it asks: the plane's
## reach that way (WorldScale `reach_rolled`) for its middle, none for a
## wingtip's or the nose's point, which is itself on the plane's edge.
##
## {x0, z0, nx, nz, start (each cell's first index into idx; nx*nz+1),
## idx (box numbers), b (6 floats a box: x0, y0, z0, x1, y1, z1)}.

const WorldScale = preload("res://scripts/world_scale.gd")

const CELL := 2.0
## `from_faces`: the spacing of its upright samples (m), the gap under which
## two crossings are one (an edge both its triangles meet), and how near two
## neighbours' stretches run on as one box (m).
const SAMPLE := 0.5
const SAME_HIT := 0.01
const RUN_SAME := 0.3

## The most a query may grow a box (m): the wingtip's reach and a little.
static func grow_most() -> float:
	return WorldScale.span*0.5+0.1

## The solid of `boxes`, each moved `shift` m along x.
static func build(boxes: Array, shift := 0.0) -> Dictionary:
	var grow := grow_most()
	if boxes.is_empty(): return {"x0":0.0,"z0":0.0,"nx":0,"nz":0,"start":PackedInt32Array([0]),"idx":PackedInt32Array(),"b":PackedFloat32Array()}
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	var b := PackedFloat32Array()
	b.resize(boxes.size()*6)
	for i in range(boxes.size()):
		var a: AABB = boxes[i]
		var x0 := a.position.x+shift
		b[i*6] = x0
		b[i*6+1] = a.position.y
		b[i*6+2] = a.position.z
		b[i*6+3] = x0+a.size.x
		b[i*6+4] = a.end.y
		b[i*6+5] = a.end.z
		lo = lo.min(Vector2(x0,a.position.z))
		hi = hi.max(Vector2(x0+a.size.x,a.end.z))
	lo -= Vector2.ONE*grow
	hi += Vector2.ONE*grow
	var nx := maxi(1,int(ceil((hi.x-lo.x)/CELL)))
	var nz := maxi(1,int(ceil((hi.y-lo.y)/CELL)))
	var lists: Array = []
	lists.resize(nx*nz)
	for i in range(boxes.size()):
		var i0 := clampi(int(floor((b[i*6]-grow-lo.x)/CELL)),0,nx-1)
		var i1 := clampi(int(floor((b[i*6+3]+grow-lo.x)/CELL)),0,nx-1)
		var j0 := clampi(int(floor((b[i*6+2]-grow-lo.y)/CELL)),0,nz-1)
		var j1 := clampi(int(floor((b[i*6+5]+grow-lo.y)/CELL)),0,nz-1)
		for j in range(j0,j1+1):
			for k in range(i0,i1+1):
				var at := j*nx+k
				# A plain Array: a packed one read out of `lists` is a copy.
				if lists[at] == null: lists[at] = [i]
				else: (lists[at] as Array).append(i)
	var start := PackedInt32Array()
	start.resize(nx*nz+1)
	var idx := PackedInt32Array()
	for at in range(nx*nz):
		start[at] = idx.size()
		if lists[at] != null: idx.append_array(PackedInt32Array(lists[at]))
	start[nx*nz] = idx.size()
	return {"x0":lo.x,"z0":lo.y,"nx":nx,"nz":nz,"start":start,"idx":idx,"b":b}

## Boxes for a closed skin (triangles `faces`, local): upright lines every
## SAMPLE m through it, each line's stretches between where it goes in and
## out (from the top down; a skin open at the foot runs to its lowest
## point), each a SAMPLE-wide box round its line, run on along x while the
## next line's match within RUN_SAME. Within SAMPLE/2 of the skin.
static func from_faces(faces: PackedVector3Array, sample := SAMPLE) -> Array:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in faces:
		lo = lo.min(v)
		hi = hi.max(v)
	if faces.is_empty(): return []
	var x0 := floorf(lo.x/sample)*sample
	var z0 := floorf(lo.z/sample)*sample
	var nx := int(ceil((hi.x-x0)/sample))+1
	var nz := int(ceil((hi.z-z0)/sample))+1
	var hits: Array = []
	hits.resize(nx*nz)
	for t in range(0,faces.size()-2,3):
		var a := faces[t]
		var b := faces[t+1]
		var c := faces[t+2]
		var area := (b.x-a.x)*(c.z-a.z)-(c.x-a.x)*(b.z-a.z)
		if absf(area) < 1e-8: continue
		var i0 := maxi(0,int(ceil((minf(a.x,minf(b.x,c.x))-x0)/sample)))
		var i1 := mini(nx-1,int(floor((maxf(a.x,maxf(b.x,c.x))-x0)/sample)))
		var j0 := maxi(0,int(ceil((minf(a.z,minf(b.z,c.z))-z0)/sample)))
		var j1 := mini(nz-1,int(floor((maxf(a.z,maxf(b.z,c.z))-z0)/sample)))
		for j in range(j0,j1+1):
			var z := z0+j*sample
			for i in range(i0,i1+1):
				var x := x0+i*sample
				# Barycentric over the triangle's footprint.
				var u := ((b.x-x)*(c.z-z)-(c.x-x)*(b.z-z))/area
				var v := ((c.x-x)*(a.z-z)-(a.x-x)*(c.z-z))/area
				var w := 1.0-u-v
				if u < 0.0 or v < 0.0 or w < 0.0: continue
				var y := a.y*u+b.y*v+c.y*w
				var at := j*nx+i
				if hits[at] == null: hits[at] = [y]
				else: (hits[at] as Array).append(y)
	var out: Array = []
	var half := sample*0.5
	for j in range(nz):
		var z := z0+j*sample
		var open: Array = []   # [AABB] still running along x
		for i in range(nx+1):
			var now: Array = []
			if i < nx and hits[j*nx+i] != null: now = _stretches_of(hits[j*nx+i],lo.y)
			var still: Array = []
			for box: AABB in open:
				var k := -1
				for m in range(now.size()):
					var s: Vector2 = now[m]
					if absf(s.x-box.position.y) < RUN_SAME and absf(s.y-box.end.y) < RUN_SAME:
						k = m
						break
				if k < 0:
					out.append(box)
					continue
				var s: Vector2 = now[k]
				now.remove_at(k)
				var y0 := minf(box.position.y,s.x)
				var y1 := maxf(box.end.y,s.y)
				still.append(AABB(Vector3(box.position.x,y0,box.position.z),Vector3(box.size.x+sample,y1-y0,box.size.z)))
			var x := x0+i*sample
			for s: Vector2 in now: still.append(AABB(Vector3(x-half,s.x,z-half),Vector3(sample,s.y-s.x,sample)))
			open = still
	return _run_z(out,sample)

## Boxes of the same x run (`from_faces`' rows) run on along z while the
## next row's matches within RUN_SAME.
static func _run_z(boxes: Array, sample := SAMPLE) -> Array:
	var by := {}
	for b: AABB in boxes:
		var key := Vector2i(roundi(b.position.x/sample*2.0),roundi(b.end.x/sample*2.0))
		if not by.has(key): by[key] = []
		(by[key] as Array).append(b)
	var out: Array = []
	for key in by:
		var list: Array = by[key]
		list.sort_custom(func(a: AABB, b: AABB) -> bool: return a.position.z < b.position.z)
		var used := {}
		for i in range(list.size()):
			if used.has(i): continue
			var b: AABB = list[i]
			for k in range(i+1,list.size()):
				if used.has(k): continue
				var c: AABB = list[k]
				if c.position.z > b.end.z+0.01: break
				if absf(c.position.z-b.end.z) < 0.01 and absf(c.position.y-b.position.y) < RUN_SAME and absf(c.end.y-b.end.y) < RUN_SAME:
					b = b.merge(c)
					used[k] = true
			out.append(b)
	return out

## One upright line's stretches (low, high) from its crossings, paired from
## the top down; one left over runs down to `bottom`.
static func _stretches_of(ys: Array, bottom: float) -> Array:
	ys.sort()
	var keep: Array = []
	for y: float in ys:
		if keep.is_empty() or y-float(keep[-1]) > SAME_HIT: keep.append(y)
	var out: Array = []
	var k := keep.size()-1
	while k >= 0:
		var top := float(keep[k])
		var low := float(keep[k-1]) if k >= 1 else bottom
		out.append(Vector2(low,top))
		k -= 2
	return out

## The y-stretches (local, plus `oy`) of every box within `pad` m of local
## XZ (`x`, `z`), onto `out`.
static func stretches(g: Dictionary, x: float, z: float, pad: float, oy: float, out: Array) -> void:
	var i := int(floor((x-float(g.x0))/CELL))
	var j := int(floor((z-float(g.z0))/CELL))
	if i < 0 or j < 0 or i >= int(g.nx) or j >= int(g.nz): return
	var start: PackedInt32Array = g.start
	var idx: PackedInt32Array = g.idx
	var b: PackedFloat32Array = g.b
	var at := j*int(g.nx)+i
	var pp := pad*pad
	for n in range(start[at],start[at+1]):
		var k := idx[n]*6
		var dx := maxf(0.0,maxf(b[k]-x,x-b[k+3]))
		var dz := maxf(0.0,maxf(b[k+2]-z,z-b[k+5]))
		if dx*dx+dz*dz <= pp: out.append(Vector2(b[k+1]+oy,b[k+4]+oy))

## True when local `q` is within `pad` m of a box, inside its height.
static func inside(g: Dictionary, q: Vector3, pad: float) -> bool:
	var i := int(floor((q.x-float(g.x0))/CELL))
	var j := int(floor((q.z-float(g.z0))/CELL))
	if i < 0 or j < 0 or i >= int(g.nx) or j >= int(g.nz): return false
	var start: PackedInt32Array = g.start
	var idx: PackedInt32Array = g.idx
	var b: PackedFloat32Array = g.b
	var at := j*int(g.nx)+i
	var pp := pad*pad
	for n in range(start[at],start[at+1]):
		var k := idx[n]*6
		if q.y < b[k+1] or q.y > b[k+4]: continue
		var dx := maxf(0.0,maxf(b[k]-q.x,q.x-b[k+3]))
		var dz := maxf(0.0,maxf(b[k+2]-q.z,q.z-b[k+5]))
		if dx*dx+dz*dz <= pp: return true
	return false

## Stretches sorted low to high and joined where they overlap or the gap
## between them is under `join` m (no plane fits through it).
static func joined(list: Array, join := 0.0) -> Array:
	if list.size() < 2: return list
	list.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array = [list[0]]
	for i in range(1,list.size()):
		var s: Vector2 = list[i]
		var last: Vector2 = out[-1]
		if s.x <= last.y+join: out[-1] = Vector2(last.x,maxf(last.y,s.y))
		else: out.append(s)
	return out

## The boxes' local extent (x0, x1) along x, for a reach check.
static func span_x(g: Dictionary) -> Vector2:
	return Vector2(float(g.x0),float(g.x0)+int(g.nx)*CELL)
