extends RefCounted
## Builds the endless land's arches from their specs (scripts/endless/
## arch_plan.gd), on a worker: plain data and nodes not yet in the tree.
##
## Rock arches are procedural meshes: a tube swept along the arch's line,
## its section a squared blob that swells toward the feet, pushed in and
## out by world-space noise and banded into ledges, its feet sunk into the
## ground. They take the land's own ground material (scripts/endless/
## endless_look.gd), so their faces read as the land's rock and their tops
## grow its turf. Ruin arches are RuinKit pieces (an aqueduct run, a pointed
## arch), grown to their opening's size, their piers down to the ground.
##
## Every arch also gives its solid as columns (`columns`): along its own x,
## each metre-wide column's solid stretches (up to three, so a span over
## rubble stays open) and how deep it reaches either side. The flight reads
## them (scripts/endless/land_arches.gd `ground`), since the land is a
## heightfield and cannot hold an overhang.

const Field = preload("res://scripts/endless/land_field.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const RuinLod = preload("res://scripts/ruin_lod.gd")
const BridgeBuild = preload("res://scripts/endless/bridge_build.gd")

## Ruins get their levels of detail (off: --no-arch-lod, to compare).
static var lod: bool = not "--no-arch-lod" in preload("res://scripts/launch_args.gd").user_args()
const WorldScale = preload("res://scripts/world_scale.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")

## Column width (m), the gap under which two stretches count as one, the
## most stretches a column keeps, and how far round the solid the plane's
## wingtip is kept (half its span).
const BIN := 1.0
const JOIN := 1.5
const MOST := 3
const STRIDE := 3+MOST*2
const BAND := 3.0
## Rock: metres of curve a ring, the ring's points, how squared its section
## is (1 round, less squarer), the noise's push.
const RING_EVERY := 1.5
const RING := 18
const SQUARE := 0.5
const LUMPS := 0.3
const GRAIN := 0.09
const LEDGES := 0.06

static func wingtip() -> float:
	return WorldScale.span*0.5

## A built arch: {spec, kind, boxes (local AABBs), and for rock `arrays`
## (a mesh's surface arrays) and `faces` (a collider's), for ruins `node`}.
static func build(spec: Dictionary, field: RefCounted) -> Dictionary:
	if spec.kind == "rock": return _rock(spec,field)
	return _ruin(spec,field)

static func basis_of(spec: Dictionary) -> Basis:
	return Basis(Vector3.UP,float(spec.yaw))

# --- Rock -----------------------------------------------------------------

static func _rock(spec: Dictionary, field: RefCounted) -> Dictionary:
	var pos: Vector3 = spec.pos
	var basis := basis_of(spec)
	var noise := FastNoiseLite.new()
	noise.seed = int(spec.seed)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var ground := func(lx: float, lz: float) -> float:
		var w := pos+basis*Vector3(lx,0.0,lz)
		return float(field.height(w.x,w.z))-pos.y
	var w := float(spec.w)
	var h := float(spec.h)
	var thick := float(spec.thick)
	var depth := float(spec.depth)
	var flare := float(spec.flare)
	var leg := thick*0.5*(1.0+flare)
	var a := w*0.5+leg*0.85
	var power := {"tall":0.5,"wide":0.95,"narrows":0.8}.get(spec.form,0.7) as float
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var boxes: Array = []
	var tubes: Array = []
	if int(spec.arches) == 2:
		var off := a-leg*0.35
		tubes.append([-off,a,h])
		tubes.append([off,a*0.92,h*0.78])
	else:
		tubes.append([0.0,a,h])
	for tube: Array in tubes:
		_tube(v,c,idx,boxes,noise,ground,float(tube[0]),float(tube[1]),float(tube[2]),thick,depth,flare,float(spec.lean),power,pos)
	var n := _normals(v,idx)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	RockShape.bake(arrays)
	var faces := PackedVector3Array()
	faces.resize(idx.size())
	for i in range(idx.size()): faces[i] = v[idx[i]]
	return {"spec":spec,"kind":"rock","arrays":arrays,"faces":faces,"boxes":boxes,"tris":idx.size()/3}

## One arch's tube about local x `ox`: its line's half reach `a`, its
## opening `h` clear over the highest ground under it.
static func _tube(v: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array, boxes: Array, noise: FastNoiseLite, ground: Callable,
		ox: float, a: float, h: float, thick: float, depth: float, flare: float, lean: float, power: float, pos: Vector3) -> void:
	var leg := thick*0.5*(1.0+flare)
	# The ground: under each foot, and the highest under the opening.
	var gl := float(ground.call(ox-a,0.0))
	var gr := float(ground.call(ox+a,0.0))
	var top := -INF
	for i in range(9):
		var x := ox+lerpf(-a+leg,a-leg,i/8.0)
		for z: float in [-depth*0.5,0.0,depth*0.5]: top = maxf(top,float(ground.call(x,z)))
	var bury := 5.0+leg*0.6
	var yl := minf(gl,top)-bury
	var yr := minf(gr,top)-bury
	var crown := top+h+thick*0.5
	# The line: up from the feet, the legs steeper as `power` falls.
	var line := func(t: float) -> Vector3:
		var s := sin(PI*t)
		var base := lerpf(yl,yr,t)
		return Vector3(ox-a*cos(PI*t)+lean*a*s*s,base+(crown-base)*pow(s,power),0.0)
	var length := 0.0
	var last: Vector3 = line.call(0.0)
	for i in range(1,65):
		var p: Vector3 = line.call(i/64.0)
		length += p.distance_to(last)
		last = p
	var rings := clampi(int(length/RING_EVERY),40,220)
	var first := v.size()
	var rock := Field.ROCK
	# The noise's sizes go with the rock's: lumps about its thickness, the
	# beds' height a share of it.
	var lump := clampf(thick*0.8,6.0,22.0)
	var bed := clampf(thick*0.6,4.0,12.0)
	for i in range(rings+1):
		var t := float(i)/rings
		var p: Vector3 = line.call(t)
		var q: Vector3 = line.call(minf(t+0.002,1.0))
		var b: Vector3 = line.call(maxf(t-0.002,0.0))
		var along := (q-b).normalized()
		var out := Vector3(-along.y,along.x,0.0)
		# The legs flare into the ground: most at it (and under), easing
		# off up the leg; along the span the rock thickens and thins.
		var over := p.y-float(ground.call(p.x,0.0))
		var swell := exp(-maxf(over,0.0)/maxf(h*0.28,6.0))
		var vary := 1.0+0.22*noise.get_noise_1d(t*5.0+ox*0.1)
		var rn := thick*0.5*(1.0+flare*swell)*vary
		var rz := depth*0.5*(1.0+0.8*flare*swell)*(2.0-vary)
		var lo := Vector3.INF
		var hi := -Vector3.INF
		# The ledges stand out on the upright legs, not along the span.
		var upright := smoothstep(0.5,0.9,absf(along.y))
		for k in range(RING):
			var ang := TAU*k/RING
			var ca := cos(ang)
			var sa := sin(ang)
			var dir := out*signf(ca)*pow(absf(ca),SQUARE)*rn+Vector3(0.0,0.0,1.0)*signf(sa)*pow(absf(sa),SQUARE)*rz
			var at := p+dir
			var world := pos+at
			var push := noise.get_noise_3d(world.x/lump,world.y/lump,world.z/lump)*LUMPS
			push += noise.get_noise_3d(world.x/(lump*0.33)+31.0,world.y/(lump*0.33),world.z/(lump*0.33))*GRAIN
			# Ledges: bands of the rock's beds standing out and in.
			push += sin(world.y*TAU/bed+noise.get_noise_2d(world.x/(lump*1.5),world.z/(lump*1.5))*4.0)*LEDGES*upright
			at = p+dir*(1.0+push)
			v.append(at)
			lo = lo.min(at)
			hi = hi.max(at)
			var shade := 0.82+noise.get_noise_3d(world.x/6.0,world.y/2.5,world.z/6.0)*0.22+push*0.6
			c.append(Color(rock.r*shade,rock.g*shade,rock.b*shade*0.97,0.0))
		boxes.append(AABB(lo,hi-lo))
	# The tube's skin, and caps over its ends.
	for i in range(rings):
		for k in range(RING):
			var a0 := first+i*RING+k
			var a1 := first+i*RING+(k+1)%RING
			var b0 := a0+RING
			var b1 := a1+RING
			idx.append_array([a0,b0,b1,a0,b1,a1])
	for end: int in [0,rings]:
		var mid := Vector3.ZERO
		for k in range(RING): mid += v[first+end*RING+k]
		v.append(mid/RING)
		c.append(Color(rock.r*0.7,rock.g*0.7,rock.b*0.7,0.0))
		var m := v.size()-1
		for k in range(RING):
			var a0 := first+end*RING+k
			var a1 := first+end*RING+(k+1)%RING
			if end == 0: idx.append_array([m,a1,a0])
			else: idx.append_array([m,a0,a1])
	# Merge the boxes in pairs (a ring's box and the next's), so a segment
	# between two rings is covered.
	var n0 := boxes.size()-(rings+1)
	for i in range(rings):
		boxes[n0+i] = (boxes[n0+i] as AABB).merge(boxes[n0+i+1])

## Smooth normals, each facing out the way the skin's winding does.
static func _normals(v: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(v.size())
	for i in range(0,idx.size(),3):
		var f := (v[idx[i+2]]-v[idx[i]]).cross(v[idx[i+1]]-v[idx[i]])
		n[idx[i]] += f
		n[idx[i+1]] += f
		n[idx[i+2]] += f
	for i in range(n.size()): n[i] = n[i].normalized() if n[i].length_squared() > 0.0 else Vector3.UP
	return n

# --- Ruins ----------------------------------------------------------------

static func _ruin(spec: Dictionary, field: RefCounted) -> Dictionary:
	var pos: Vector3 = spec.pos
	var basis := basis_of(spec)
	var grow := float(spec.grow)
	var piece: Node3D
	var shift := 0.0
	if spec.kind == "aqueduct":
		var count := int(spec.count)
		shift = -Aqueduct.SPAN*count*0.5
		var ground := func(x: float, z: float) -> float:
			var w := pos+basis*(Vector3(x+shift,0.0,z)*grow)
			return (float(field.height(w.x,w.z))-pos.y)/grow
		# A bridge (bridge_plan.gd) lays its own run of the kit's spans.
		if spec.has("bridge"): piece = BridgeBuild.piece(spec,ground)
		else: piece = Aqueduct.run(int(spec.seed),float(spec.weathered),count,int(spec.break_at),bool(spec.head),ground)
	elif spec.has("set"):
		# A set piece (scripts/endless/set_plan.gd): a kit piece as it is.
		piece = RuinKit.piece(String(spec.kind),int(spec.seed),float(spec.weathered))
	else:
		piece = RuinKit.arch(int(spec.seed),float(spec.weathered))
	var root := Node3D.new()
	root.name = "Arch"
	var place := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*grow),Vector3(shift*grow,-0.35*grow if spec.kind == "gate" else 0.0,0.0))
	piece.transform = place
	root.add_child(piece)
	# The kit's colliders, grown here rather than scaled (a body is kept at
	# scale 1): one hull a block, on layer 1.
	var boxes: Array = []
	var body := StaticBody3D.new()
	body.name = "Body"
	for old in piece.find_children("*","StaticBody3D",true,false):
		var to_root := place*(old as Node3D).transform
		for holder in old.get_children():
			if not holder is CollisionShape3D: continue
			var hull := (holder as CollisionShape3D).shape as ConvexPolygonShape3D
			if hull == null: continue
			var xf := to_root*(holder as CollisionShape3D).transform
			var points := PackedVector3Array()
			var lo := Vector3.INF
			var hi := -Vector3.INF
			for p in hull.points:
				var q := xf*p
				points.append(q)
				lo = lo.min(q)
				hi = hi.max(q)
			boxes.append(AABB(lo,hi-lo))
		old.get_parent().remove_child(old)
		old.free()
	# Its colliders: the kit's hulls (one a block, over a thousand on a
	# run) are too many to add in a frame's budget, so boxes from its
	# columns stand in, merged along x where they match. A set piece is
	# hollow (a nave, a belfry), and a road bridge is flown along x (its
	# gates, its deck between the parapets): a column (one z range a bin)
	# would fill it, so its own blocks' boxes stand in, merged where they
	# meet.
	var hollow := spec.has("set") or str((spec.get("bridge",{}) as Dictionary).get("style","")) == "road"
	for box: AABB in (merged(boxes) if hollow else collider_boxes(columns(boxes,0.0))):
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		cs.shape = shape
		cs.position = box.get_center()
		body.add_child(cs)
	root.add_child(body)
	# Its levels of detail (scripts/ruin_lod.gd), so far off it draws less.
	var lods := {}
	if lod: lods = RuinLod.add(root)
	return {"spec":spec,"kind":spec.kind,"node":root,"boxes":boxes}

## `boxes` (AABBs) with those that meet face to face, the same on the
## other two axes, joined into one: along x, then z, then y.
static func merged(boxes: Array) -> Array:
	var out := boxes.duplicate()
	for axis in [0,2,1]:
		var keyed := {}
		for b: AABB in out:
			var k: Array = []
			for a in [0,1,2]:
				if a == axis: continue
				k.append(roundi(b.position[a]*8.0))
				k.append(roundi(b.end[a]*8.0))
			var list: Array = keyed.get(k,[])
			list.append(b)
			keyed[k] = list
		out = []
		for list: Array in keyed.values():
			list.sort_custom(func(p: AABB, q: AABB) -> bool: return p.position[axis] < q.position[axis])
			var run: AABB = list[0]
			for i in range(1,list.size()):
				var b: AABB = list[i]
				if b.position[axis] <= run.end[axis]+0.15: run = run.merge(b)
				else:
					out.append(run)
					run = b
			out.append(run)
	return out

# --- Columns --------------------------------------------------------------

## The solid of local boxes as columns along x: {x0, n, data} where column
## j (x0+j*BIN .. +BIN) is data[j*STRIDE..]: [count, z low, z high, then
## count (low, high) stretches], grown by the wingtip each way.
static func columns(boxes: Array, grow := -1.0) -> Dictionary:
	if grow < 0.0: grow = wingtip()
	var x0 := INF
	var x1 := -INF
	for b: AABB in boxes:
		x0 = minf(x0,b.position.x)
		x1 = maxf(x1,b.end.x)
	if boxes.is_empty(): return {"x0":0.0,"n":0,"data":PackedFloat32Array(),"y0":0.0,"bands":0,"zb":PackedFloat32Array()}
	var y0 := INF
	var y1 := -INF
	for b: AABB in boxes:
		y0 = minf(y0,b.position.y)
		y1 = maxf(y1,b.end.y)
	x0 -= grow+BIN
	x1 += grow+BIN
	var n := int(ceil((x1-x0)/BIN))
	var lists: Array = []
	var zs: Array = []
	for j in range(n):
		lists.append([])
		zs.append(Vector2(INF,-INF))
	# The depth by height too: BAND m bands, so a leg wide at its foot is
	# only as deep as it is where the plane meets it.
	var bands := maxi(1,int(ceil((y1-y0)/BAND)))
	var zb := PackedFloat32Array()
	zb.resize(n*bands*2)
	for i in range(n*bands):
		zb[i*2] = INF
		zb[i*2+1] = -INF
	for b: AABB in boxes:
		var j0 := clampi(int(floor((b.position.x-grow-x0)/BIN)),0,n-1)
		var j1 := clampi(int(floor((b.end.x+grow-x0)/BIN)),0,n-1)
		for j in range(j0,j1+1):
			(lists[j] as Array).append(Vector2(b.position.y,b.end.y))
			var z: Vector2 = zs[j]
			zs[j] = Vector2(minf(z.x,b.position.z),maxf(z.y,b.end.z))
			var k0 := clampi(int(floor((b.position.y-y0)/BAND)),0,bands-1)
			var k1 := clampi(int(floor((b.end.y-y0)/BAND)),0,bands-1)
			for k in range(k0,k1+1):
				var at := (j*bands+k)*2
				zb[at] = minf(zb[at],b.position.z-grow)
				zb[at+1] = maxf(zb[at+1],b.end.z+grow)
	var data := PackedFloat32Array()
	data.resize(n*STRIDE)
	for j in range(n):
		var merged := _merge(lists[j])
		var at := j*STRIDE
		data[at] = merged.size()
		data[at+1] = (zs[j] as Vector2).x-grow
		data[at+2] = (zs[j] as Vector2).y+grow
		for k in range(merged.size()):
			data[at+3+k*2] = (merged[k] as Vector2).x
			data[at+4+k*2] = (merged[k] as Vector2).y
	return {"x0":x0,"n":n,"data":data,"y0":y0,"bands":bands,"zb":zb}

## Boxes standing in for columns `col` (unwidened): each stretch of each
## column a box, run on along x while the next column's matches within
## SAME m.
static func collider_boxes(col: Dictionary) -> Array:
	const SAME := 0.75
	var out: Array = []
	var data: PackedFloat32Array = col.data
	var open: Array = []   # the boxes still running: AABB
	for j in range(int(col.n)+1):
		var x := float(col.x0)+j*BIN
		var now: Array = []
		if j < int(col.n):
			var at := j*STRIDE
			for k in range(int(data[at])):
				now.append(AABB(Vector3(x,data[at+3+k*2],data[at+1]),Vector3(BIN,data[at+4+k*2]-data[at+3+k*2],data[at+2]-data[at+1])))
		var still: Array = []
		for b: AABB in open:
			var joined := false
			for i in range(now.size()):
				var c: AABB = now[i]
				if absf(c.position.y-b.position.y) < SAME and absf(c.end.y-b.end.y) < SAME and absf(c.position.z-b.position.z) < SAME*2.0 and absf(c.end.z-b.end.z) < SAME*2.0:
					var grown := b.merge(c)
					still.append(grown)
					now.remove_at(i)
					joined = true
					break
			if not joined: out.append(b)
		still.append_array(now)
		open = still
	return out

## Stretches sorted and joined where they touch (or nearly), at most MOST
## (the narrowest gaps closed first).
static func _merge(list: Array) -> Array:
	if list.is_empty(): return []
	list.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var out: Array = [list[0]]
	for i in range(1,list.size()):
		var s: Vector2 = list[i]
		var last: Vector2 = out[-1]
		if s.x <= last.y+JOIN: out[-1] = Vector2(last.x,maxf(last.y,s.y))
		else: out.append(s)
	while out.size() > MOST:
		var best := 0
		for i in range(out.size()-1):
			if (out[i+1] as Vector2).x-(out[i] as Vector2).y < (out[best+1] as Vector2).x-(out[best] as Vector2).y: best = i
		out[best] = Vector2((out[best] as Vector2).x,(out[best+1] as Vector2).y)
		out.remove_at(best+1)
	return out
