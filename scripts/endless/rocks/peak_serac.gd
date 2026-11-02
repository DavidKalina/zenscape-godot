extends RefCounted
## The Peak's seracs: towers of broken ice.
##
## A tower is a bundle of convex shards (a box tapered and cut by planes off its
## axes, each turned and leaning its own way), some thin as fins, with a hood
## hung out over the downstream side, slabs split off its faces with a real crack
## behind them and tumbled blocks round its foot. The shards
## cut through each other, so the creases between them are sharp, and each face's
## normals fan out a little, so it shades as if melted.
##
## RockBuild's lofted rings can't hold a shard or an overhanging shelf, so
## a spec with `mesher` (this script) comes here: `build` returns what
## RockBuild.build returns (arrays, lods, a level-1 trimesh a pillar, the
## ring-and-sector solid), and the kit's collider, flight solid, streaming and
## near misses take it unchanged.
##
## Levels: each block belongs to 0-1 (slabs, tumbled blocks, lesser shards) or
## all three (the first shards, the hood). Vertex colour: r the block's
## tone of ice, g how exposed (0 buried or under an overhang), b 1 on a face's
## edge and 0 at its middle (a fan from there, so the shader knows its way to
## the edge, for the bright rims), read by shaders/peak_ice.gdshaderinc.
##
## API: `cluster(rng, big)` the members of one heap (offsets along and across
## the flow, sizes), `pillar(field, pos, q, r, up, long, flow, rng)` one tower
## at world XZ `q` with the flow's direction `flow`. A piece reaches at most
## WIDEST*r*long from its centre.

const RockBuild = preload("res://scripts/endless/rocks/rock_build.gd")

## A piece's reach over its radius and length (PeakValley WIDEST).
const WIDEST := 1.3
## The solid's rings' spacing (m).
const RING := 2.0
## The levels' errors, as shares of the group's typical radius.
const LOD_ERROR := [0.10,0.34]
## How far the solid's outline is sampled along an edge (m).
const SAMPLE := 0.8
## No tower stands taller than this over its ground (m).
const TALLEST := 46.0
## How far a face's corners' normals turn out from its own: the faces shade
## as if melted, for no triangle more.
const SOFT := 0.3
## The C++ twin of `build`'s loops (native/terrain_kernels/serac_mesh.h,
## ZenScapeSerac); --native-serac=0 runs the GDScript ones below.
const NATIVE_CLASS := &"ZenScapeSerac"
## True: the GDScript loops even with the library (a parity check's).
static var gd_only := false
static var _native: Object = _make_twin()

## One heap's members: [[Vector2(along, across) off its middle, radius (along
## the flow), height, length (across over along)]...], the biggest first.
## `big` 0..1: a lone stump to a giant with its court.
static func cluster(rng: RandomNumberGenerator, big: float) -> Array:
	var r: float
	var up: float
	var courts: int
	if big > 0.72:
		r = rng.randf_range(10.0,14.5)
		up = rng.randf_range(30.0,TALLEST)
		courts = rng.randi_range(3,5)
	elif big > 0.34:
		r = rng.randf_range(6.0,10.0)
		up = rng.randf_range(15.0,29.0)
		courts = rng.randi_range(2,3)
	else:
		r = rng.randf_range(3.0,5.5)
		up = rng.randf_range(5.0,12.0)
		courts = rng.randi_range(0,2)
	var long := rng.randf_range(1.05,1.45)
	var out: Array = [[Vector2.ZERO,r,up,long]]
	var wr := r*WIDEST*long
	var ang := rng.randf()*TAU
	for i in courts:
		ang += rng.randf_range(1.0,2.2)
		var share := rng.randf_range(0.3,0.68)
		var rm := maxf(r*share,2.6)
		var um := up*share*rng.randf_range(0.75,1.1)
		var lm := rng.randf_range(1.0,1.4)
		var d := maxf((wr+rm*WIDEST*lm)*rng.randf_range(0.72,0.95),0.75*r)
		out.append([Vector2(cos(ang),sin(ang))*d,rm,um,lm])
	return out

## One tower at world XZ `q` (a pillar of a group anchored at `pos`): radius
## `r` along the flow, `long` times it across, `up` m over the high side of its
## ground, leaning down `flow` (a unit XZ direction).
static func pillar(field: RefCounted, pos: Vector3, q: Vector2, r: float, up: float, long: float, flow: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var across := Vector2(-flow.y,flow.x)
	var low := INF
	var high := -INF
	for k in range(9):
		var ang := TAU*k/8.0
		var d := Vector2.ZERO if k == 0 else flow*cos(ang)*r+across*sin(ang)*r*long
		var g := float(field.height(q.x+d.x,q.y+d.y))
		low = minf(low,g)
		high = maxf(high,g)
	var ground := float(field.height(q.x,q.y))
	var over := maxf(high-ground,0.0)
	var tall := over+up
	var foot := low-ground-2.0
	var blocks := _tower(rng,r*long,r,tall,foot)
	# Stood with the flow, a little off square, its reach kept.
	var yaw := rng.randf_range(-0.3,0.3)
	var f3 := Vector3(flow.x,0.0,flow.y).rotated(Vector3.UP,yaw)
	var s3 := Vector3(across.x,0.0,across.y).rotated(Vector3.UP,yaw)
	var most := 0.0
	for b: Dictionary in blocks:
		for f: PackedVector3Array in b.polys:
			for p: Vector3 in f: most = maxf(most,Vector2(p.x,p.z).length())
	var fit := minf(1.0,r*WIDEST*long/maxf(most,0.01))
	for b: Dictionary in blocks:
		var polys: Array = b.polys
		for i in polys.size():
			var f: PackedVector3Array = polys[i]
			for j in f.size():
				var p := f[j]
				f[j] = s3*p.x*fit+Vector3.UP*p.y+f3*p.z*fit
			polys[i] = f
	return {"at":Vector3(q.x-pos.x,ground-pos.y,q.y-pos.z),"blocks":blocks,"r":r,"foot":foot,"tall":tall}

## A tower's blocks in its own frame (x across the flow, z down it, y up, 0 at
## its ground): half-widths `rs` across, `rf` along, `tall` high, buried to
## `foot`. A bundle of shards, each turned its own way and leaning, the first
## the tallest; fins among them; a hood hung out over the downstream side; slabs
## split off with a crack behind them; tumbled blocks round the foot.
static func _tower(rng: RandomNumberGenerator, rs: float, rf: float, tall: float, foot: float) -> Array:
	var out: Array = []
	var tone := rng.randf_range(0.3,0.7)
	var lean := rng.randf_range(0.06,0.2)
	var t := func(d: float) -> float: return clampf(tone+rng.randf_range(-d,d),0.0,1.0)
	var count := clampi(2+int(tall/9.0),2,6)
	var ang := rng.randf()*TAU
	for i in count:
		var share := float(i)/count
		var high := tall if i == 0 else tall*rng.randf_range(0.42,0.86)
		var wide := lerpf(0.66,0.34,share)*rng.randf_range(0.85,1.15)
		var out_by := 0.0 if i == 0 else rng.randf_range(0.42,0.72)
		ang += rng.randf_range(1.2,2.6)
		var hy := (high-foot)*0.5
		# A third of them fins, thin across their own width.
		var thin := rng.randf_range(0.28,0.42) if rng.randf() < 0.34 else rng.randf_range(0.7,1.05)
		var half := Vector3(rs*wide,hy,rf*wide*thin)
		var turn := Basis(Vector3.UP,rng.randf_range(-0.7,0.7))*Basis(Vector3.RIGHT,lean*rng.randf_range(0.5,1.3))*Basis(Vector3.BACK,rng.randf_range(-0.1,0.1))
		var at := Vector3(cos(ang)*rs*out_by,foot+hy,sin(ang)*rf*out_by)
		# A tall one is two, the upper knocked askew on the lower: no long prisms.
		if high > 16.0 and thin > 0.5:
			var cut_at := foot+(high-foot)*rng.randf_range(0.52,0.68)
			var ly := (cut_at-foot)*0.56
			out.append(_shard(rng,Vector3(half.x,ly,half.z),Vector3(at.x,foot+ly,at.z),turn,t.call(0.1),2 if i < 3 else 1))
			var uy := (high-cut_at)*0.62
			var off := Vector3(rng.randf_range(-0.34,0.34)*half.x,0.0,rng.randf_range(-0.3,0.3)*half.z)
			var askew := Basis(Vector3.UP,rng.randf_range(-0.8,0.8))*turn*Basis(Vector3.BACK,rng.randf_range(-0.16,0.16))
			out.append(_shard(rng,Vector3(half.x*rng.randf_range(0.7,0.95),uy,half.z*rng.randf_range(0.7,0.95)),Vector3(at.x,high-uy,at.z)+off,askew,t.call(0.14),2 if i < 2 else 1))
		else:
			out.append(_shard(rng,half,at,turn,t.call(0.1),2 if i < 3 else 1))
	if tall < 13.0:
		_tumbled(out,rng,rs,rf,rng.randi_range(0,1),t)
		return out
	# The hood: a wedge hung out over the downstream side, its belly in shade.
	var hood_y := tall*rng.randf_range(0.14,0.2)
	var hood := Vector3(rs*rng.randf_range(0.5,0.72),hood_y,rf*rng.randf_range(0.42,0.6))
	var hung := Basis(Vector3.UP,rng.randf_range(-0.5,0.5))*Basis(Vector3.RIGHT,rng.randf_range(0.18,0.42))
	out.append(_shard(rng,hood,Vector3(rs*rng.randf_range(-0.3,0.3),tall*rng.randf_range(0.5,0.62),rf*rng.randf_range(0.22,0.4)),hung,t.call(0.14),2))
	# Slabs split off its faces: a real crack behind each.
	for i in rng.randi_range(1,3):
		var a2 := rng.randf()*TAU
		var th := clampf(rf*0.1,0.45,1.4)
		var to := Vector3(cos(a2),0.0,sin(a2))
		var turned := Basis(Vector3.UP,atan2(to.x,to.z)+rng.randf_range(-0.2,0.2))*Basis(Vector3.RIGHT,rng.randf_range(0.02,0.14))
		var half := Vector3(minf(rs,rf)*rng.randf_range(0.3,0.5),tall*rng.randf_range(0.14,0.26),th)
		var at := Vector3(to.x*rs*0.86,tall*rng.randf_range(0.34,0.62),to.z*rf*0.86)
		out.append(_shard(rng,half,at,turned,t.call(0.2),1))
	_tumbled(out,rng,rs,rf,rng.randi_range(2,3),t)
	return out

## A shard: a block tapered up all four sides, broken across its top by a slant
## or two, its edges chopped. Nothing of the box's own faces is left whole.
static func _shard(rng: RandomNumberGenerator, half: Vector3, at: Vector3, turn: Basis, tone: float, level: int) -> Dictionary:
	var planes := PackedFloat64Array()
	var taper := rng.randf_range(0.14,0.3)
	for side: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
		var w := absf(side.dot(half))
		var n := (side*half.y+Vector3.UP*w*taper*rng.randf_range(0.7,1.3)+Vector3(side.z,0.0,side.x)*half.y*rng.randf_range(-0.28,0.28)).normalized()
		_plane(planes,n,n.dot(side*w*rng.randf_range(0.82,1.0)-Vector3.UP*half.y))
	# The broken top: down one way, then a nick the other.
	var way := rng.randf()*TAU
	var slant := Vector3(cos(way)*rng.randf_range(0.5,1.15),1.0,sin(way)*rng.randf_range(0.5,1.15)).normalized()
	_plane(planes,slant,slant.dot(Vector3(0.0,half.y*rng.randf_range(0.62,0.86),0.0)))
	way += rng.randf_range(2.2,4.0)
	var nick := Vector3(cos(way)*1.2,0.8,sin(way)*1.2).normalized()
	_plane(planes,nick,nick.dot(Vector3(cos(way)*0.3*half.x,half.y*0.8,sin(way)*0.3*half.z)))
	for i in 3:
		var dir := Vector3(rng.randf_range(-1.0,1.0),rng.randf_range(-0.5,0.8),rng.randf_range(-1.0,1.0)).normalized()
		var reach := absf(dir.x)*half.x+absf(dir.y)*half.y+absf(dir.z)*half.z
		_plane(planes,dir,reach*rng.randf_range(0.5,0.72))
	return {"polys":_carve(half,planes,turn,at),"tone":tone,"level":level}

static func _plane(planes: PackedFloat64Array, n: Vector3, d: float) -> void:
	planes.append_array(PackedFloat64Array([n.x,n.y,n.z,d]))

## The box of half-widths `half` cut by `planes` ([nx, ny, nz, d]..., kept
## where p.n <= d) in turn, turned and put at `at`: [face...]. In C++ when the
## library has it (ZenScapeSerac `carve`).
static func _carve(half: Vector3, planes: PackedFloat64Array, turn: Basis, at: Vector3) -> Array:
	var twin: Object = _twin()
	if twin != null: return twin.carve(half,planes,turn,at)
	var polys := _box(half)
	for i in range(0,planes.size()-3,4):
		polys = _cut(polys,Vector3(planes[i],planes[i+1],planes[i+2]),planes[i+3])
	for i in polys.size():
		var f: PackedVector3Array = polys[i]
		for j in f.size(): f[j] = turn*f[j]+at
		polys[i] = f
	return polys

## Blocks fallen round a tower's foot, half sunk, tilted hard.
static func _tumbled(out: Array, rng: RandomNumberGenerator, rs: float, rf: float, n: int, t: Callable) -> void:
	for i in n:
		var ang := rng.randf()*TAU
		var sz := minf(rf,rs)*rng.randf_range(0.2,0.42)
		var half := Vector3(sz*rng.randf_range(0.9,1.5),sz*rng.randf_range(0.6,1.1),sz*rng.randf_range(0.8,1.3))
		var at := Vector3(cos(ang)*(rs+sz*0.3),half.y*0.3,sin(ang)*(rf+sz*0.3))
		out.append(_block(rng,half,at,_tilt(rng,0.35,0.95),3,t.call(0.35),1))

## A random tilt: `lo` to `hi` rad about a level axis.
static func _tilt(rng: RandomNumberGenerator, lo: float, hi: float) -> Basis:
	var ang := rng.randf()*TAU
	return Basis(Vector3(cos(ang),0.0,sin(ang)),rng.randf_range(lo,hi))

## A convex block: a box of half-widths `half`, cut by `cuts` ([[normal, d]...]:
## kept where p.n <= d) and `chops` random corners, turned and put at `at`.
## {polys: [face...], tone, level}.
static func _block(rng: RandomNumberGenerator, half: Vector3, at: Vector3, turn: Basis, chops: int, tone: float, level: int, cuts: Array = []) -> Dictionary:
	var planes := PackedFloat64Array()
	for c: Array in cuts: _plane(planes,c[0],float(c[1]))
	for i in chops:
		var dir := Vector3(rng.randf_range(-1.0,1.0),rng.randf_range(-0.6,1.0),rng.randf_range(-1.0,1.0)).normalized()
		var reach := absf(dir.x)*half.x+absf(dir.y)*half.y+absf(dir.z)*half.z
		_plane(planes,dir,reach*rng.randf_range(0.6,0.84))
	return {"polys":_carve(half,planes,turn,at),"tone":tone,"level":level}

static func _box(h: Vector3) -> Array:
	var c := [Vector3(-h.x,-h.y,-h.z),Vector3(h.x,-h.y,-h.z),Vector3(h.x,-h.y,h.z),Vector3(-h.x,-h.y,h.z),
		Vector3(-h.x,h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(h.x,h.y,h.z),Vector3(-h.x,h.y,h.z)]
	var out: Array = []
	for q: Array in [[0,1,2,3],[7,6,5,4],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
		out.append(PackedVector3Array([c[q[0]],c[q[1]],c[q[2]],c[q[3]]]))
	return out

## A convex block's faces cut by a plane: what lies past it goes, the cut
## closed by a new face.
static func _cut(polys: Array, n: Vector3, d: float) -> Array:
	var out: Array = []
	var cap := PackedVector3Array()
	for f: PackedVector3Array in polys:
		var kept := PackedVector3Array()
		var m := f.size()
		for i in m:
			var a := f[i]
			var b := f[(i+1)%m]
			var da := a.dot(n)-d
			var db := b.dot(n)-d
			if da <= 0.0: kept.append(a)
			if (da < 0.0 and db > 0.0) or (da > 0.0 and db < 0.0):
				var x := a.lerp(b,da/(da-db))
				kept.append(x)
				cap.append(x)
		if kept.size() >= 3: out.append(kept)
	if cap.size() < 3: return out
	var mid := Vector3.ZERO
	for p: Vector3 in cap: mid += p
	mid /= cap.size()
	var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := n.cross(u)
	var order: Array = []
	for p: Vector3 in cap: order.append([atan2((p-mid).dot(w),(p-mid).dot(u)),p])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var face := PackedVector3Array()
	for e: Array in order:
		var p: Vector3 = e[1]
		if face.is_empty() or p.distance_squared_to(face[face.size()-1]) > 1e-5: face.append(p)
	if face.size() >= 3: out.append(face)
	return out

## A group's mesh, levels, colliders and solid: what RockBuild.build returns.
static func build(spec: Dictionary) -> Dictionary:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var levels: Array = [PackedInt32Array(),PackedInt32Array(),PackedInt32Array()]
	var cuts: Array = [0]
	var solid: Array = []
	var radii := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed",1))
	# Each face's shade jitter, one a face in order (degenerate ones too).
	var jit := PackedFloat32Array()
	for p: Dictionary in spec.pillars:
		radii.append(float(p.r))
		for b: Dictionary in p.blocks:
			for f: PackedVector3Array in b.polys: jit.append(rng.randf_range(-0.04,0.04))
	var twin: Object = _twin()
	var made: Dictionary = twin.build(spec.pillars,jit,RockBuild.SECTORS,RING,SAMPLE,SOFT) if twin != null else {}
	var faces: Array = []
	if not made.is_empty():
		v = made.v
		n = made.n
		c = made.c
		levels = [made.l0,made.l1,made.l2]
		solid = made.solid
		faces = made.faces
	else:
		var ji: Array = [0]
		for p: Dictionary in spec.pillars:
			var at: Vector3 = p.at
			for b: Dictionary in p.blocks: _emit(v,n,c,levels,b,p,at,jit,ji)
			cuts.append((levels[1] as PackedInt32Array).size())
			solid.append(_solid(p))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = levels[0]
	radii.sort()
	var typical := radii[radii.size()/2] if not radii.is_empty() else 4.0
	var lods := {}
	var tris: Array = [(levels[0] as PackedInt32Array).size()/3]
	for l in range(1,3):
		# (A level no smaller than the one before is no level: the server refuses it.)
		if (levels[l] as PackedInt32Array).size() < (levels[l-1] as PackedInt32Array).size():
			lods[float(LOD_ERROR[l-1])*typical] = levels[l]
		tris.append((levels[l] as PackedInt32Array).size()/3)
	var coarse: PackedInt32Array = levels[1]
	for k in range(cuts.size()-1):
		var f := PackedVector3Array()
		f.resize(int(cuts[k+1])-int(cuts[k]))
		for i in range(f.size()): f[i] = v[coarse[int(cuts[k])+i]]
		faces.append(f)
	return {"spec":spec,"arrays":arrays,"lods":lods,"faces":faces,"solid":solid,"tris":tris}

## One block's faces into the arrays: each face its own vertices, so its
## normal is flat; a fan of triangles into the levels the block is in.
static func _emit(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, levels: Array, b: Dictionary, p: Dictionary, at: Vector3, jit: PackedFloat32Array, ji: Array) -> void:
	var polys: Array = b.polys
	var mid := Vector3.ZERO
	var count := 0
	for f: PackedVector3Array in polys:
		for q: Vector3 in f:
			mid += q
			count += 1
	mid /= maxi(count,1)
	var foot := float(p.foot)
	var tall := float(p.tall)
	var tone := float(b.tone)
	var level := int(b.level)
	for f: PackedVector3Array in polys:
		var m := f.size()
		var jitter := jit[int(ji[0])]
		ji[0] = int(ji[0])+1
		var nrm := Vector3.ZERO
		var centre := Vector3.ZERO
		for i in m:
			var q := f[i]
			var r := f[(i+1)%m]
			nrm += Vector3((q.y-r.y)*(q.z+r.z),(q.z-r.z)*(q.x+r.x),(q.x-r.x)*(q.y+r.y))
			centre += q
		centre /= m
		if nrm.length_squared() < 1e-8: continue
		nrm = nrm.normalized()
		var flip := nrm.dot(centre-mid) < 0.0
		if flip: nrm = -nrm
		var hollow := 0.3 if nrm.y < -0.12 else 1.0
		var shade := clampf(tone+jitter,0.0,1.0)
		var first := v.size()
		v.append(at+centre)
		n.append(nrm)
		c.append(Color(shade,clampf((centre.y-foot)/maxf(tall*0.42,1.0),0.0,1.0)*hollow,0.0,0.0))
		for q: Vector3 in f:
			v.append(at+q)
			# (Corners turned out from the face's middle: a block melted soft, not cut.)
			n.append((nrm+(q-centre).normalized()*SOFT).normalized())
			var open := clampf((q.y-foot)/maxf(tall*0.42,1.0),0.0,1.0)*hollow
			c.append(Color(shade,open,1.0,0.0))
		for l in range(level+1):
			var idx: PackedInt32Array = levels[l]
			for i in m:
				var i0 := first+1+i
				var i1 := first+1+(i+1)%m
				if flip: idx.append_array([first,i0,i1])
				else: idx.append_array([first,i1,i0])
			levels[l] = idx
	# (Godot's front faces wind clockwise from outside, and `f` runs anticlockwise
	# from outside unless `flip`. The ground shader turns a back face's normal
	# round, so a face wound the other way is lit from inside: dark in the sun.)

## The C++ twin, or null (no library, or --native-serac=0). Made once, when
## the script loads (the workers only read it).
static func _twin() -> Object:
	return null if gd_only else _native

static func _make_twin() -> Object:
	if "--native-serac=0" in preload("res://scripts/launch_args.gd").user_args(): return null
	if not ClassDB.class_exists(NATIVE_CLASS): return null
	return ClassDB.instantiate(NATIVE_CLASS)

## The ring-and-sector solid (RockBuild `_pillar`'s): the outline of every
## block at each ring's height, its sectors' most, local to the group.
static func _solid(p: Dictionary) -> Dictionary:
	var at: Vector3 = p.at
	var lo := INF
	var hi := -INF
	for b: Dictionary in p.blocks:
		for f: PackedVector3Array in b.polys:
			for q: Vector3 in f:
				lo = minf(lo,q.y)
				hi = maxf(hi,q.y)
	var rings := maxi(4,ceili((hi-lo)/RING))
	var dy := (hi-lo)/rings
	var segs: Array = []
	for k in rings+1: segs.append(PackedVector2Array())
	for b: Dictionary in p.blocks:
		for f: PackedVector3Array in b.polys:
			var y0 := INF
			var y1 := -INF
			for q: Vector3 in f:
				y0 = minf(y0,q.y)
				y1 = maxf(y1,q.y)
			var k0 := clampi(ceili((y0-lo)/dy),0,rings)
			var k1 := clampi(floori((y1-lo)/dy),0,rings)
			for k in range(k0,k1+1):
				var y := lo+k*dy
				var ring: PackedVector2Array = segs[k]
				var m := f.size()
				var got := 0
				var first := Vector2.ZERO
				for i in m:
					var a := f[i]
					var b2 := f[(i+1)%m]
					if (a.y <= y) == (b2.y <= y): continue
					var x := a.lerp(b2,(y-a.y)/(b2.y-a.y))
					var pt := Vector2(x.x,x.z)
					if got == 0: first = pt
					else:
						ring.append(first)
						ring.append(pt)
					got += 1
				segs[k] = ring
	var centres := PackedVector2Array()
	var rad := PackedFloat32Array()
	var sectors: int = RockBuild.SECTORS
	rad.resize((rings+1)*sectors)
	var last := Vector2.ZERO
	var base := Vector2(at.x,at.z)
	for k in rings+1:
		var ring: PackedVector2Array = segs[k]
		var mean := Vector2.ZERO
		for e: Vector2 in ring: mean += e
		mean = mean/ring.size() if not ring.is_empty() else last
		last = mean
		centres.append(base+mean)
		for i in range(0,ring.size(),2):
			var a := ring[i]-mean
			var b2 := ring[i+1]-mean
			var steps := clampi(ceili(a.distance_to(b2)/SAMPLE),1,40)
			for j in steps+1:
				var e := a.lerp(b2,float(j)/steps)
				var s := clampi(int(floor((e.angle()+PI)/TAU*sectors)),0,sectors-1)
				rad[k*sectors+s] = maxf(rad[k*sectors+s],e.length())
	var mid := Vector2.ZERO
	for i in rings+1: mid += centres[i]
	mid /= rings+1
	var reach := 0.0
	for i in rings+1:
		for k in sectors: reach = maxf(reach,rad[i*sectors+k]+centres[i].distance_to(mid))
	return {"c":centres,"r":rad,"y0":at.y+lo,"dy":dy,"rings":rings+1,"top":at.y+hi,"mid":mid,"reach":reach,"size":float(p.r),"base":at.y}
