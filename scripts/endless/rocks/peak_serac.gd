extends RefCounted
## The Peak's seracs: towers of broken ice, built from hard-edged blocks.
##
## A tower is a stack of convex blocks (a box cut by planes, every face flat):
## a narrow trunk undercut on its downstream side, a wider shoulder leaning out
## over it, a broken crown, slabs split off its faces with a real crack behind
## them, chips on its edges and tumbled blocks round its foot. The blocks cut
## through each other, so the creases between them are sharp.
##
## RockBuild's lofted rings can't hold a flat face or an overhanging shelf, so
## a spec with `mesher` (this script) comes here: `build` returns what
## RockBuild.build returns (arrays, lods, a level-1 trimesh a pillar, the
## ring-and-sector solid), and the kit's collider, flight solid, streaming and
## near misses take it unchanged.
##
## Levels: each block belongs to level 0 only (chips), 0-1 (slabs, tumbled
## blocks) or all three (trunk, shoulder, crown). Vertex colour: r the block's
## tone of ice, g how exposed (0 buried or under an overhang), read by
## shaders/peak_ice.gdshaderinc.
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
## `foot`.
static func _tower(rng: RandomNumberGenerator, rs: float, rf: float, tall: float, foot: float) -> Array:
	var out: Array = []
	var tone := rng.randf_range(0.2,0.8)
	var lean := rng.randf_range(0.05,0.17)
	var t := func(d: float) -> float: return clampf(tone+rng.randf_range(-d,d),0.0,1.0)
	if tall < 13.0:
		# A stump: a block and a broken top.
		var top := tall*rng.randf_range(0.72,0.9)
		var hy := (top-foot)*0.5
		out.append(_block(rng,Vector3(rs*0.82,hy,rf*0.8),Vector3(0.0,foot+hy,0.0),Basis(Vector3.RIGHT,lean),3,t.call(0.1),2))
		var cap := Vector3(rs*0.62,(tall-top)*0.8+0.5,rf*0.6)
		out.append(_block(rng,cap,Vector3(rng.randf_range(-0.2,0.2)*rs,top+cap.y*0.3,rf*0.1),_tilt(rng,0.25,0.5),3,t.call(0.15),2))
		_tumbled(out,rng,rs,rf,rng.randi_range(0,1),t)
		return out
	# The trunk, undercut down the flow: its face leans out as it climbs.
	var trunk_top := tall*rng.randf_range(0.56,0.66)
	var hy := (trunk_top-foot)*0.5
	var under := rf*rng.randf_range(0.34,0.5)/hy
	var norm := sqrt(1.0+under*under)
	var cuts: Array = [[Vector3(0.0,-under,1.0)/norm,rf*0.62/norm]]
	out.append(_block(rng,Vector3(rs*0.74,hy,rf*0.72),Vector3(rs*rng.randf_range(-0.08,0.08),foot+hy,-rf*0.12),Basis(Vector3.RIGHT,lean*0.4),3,t.call(0.12),2,cuts))
	# The shoulder: wider, leaning out over the trunk.
	var sh_mid := tall*rng.randf_range(0.56,0.62)
	var sh_y := tall*rng.randf_range(0.2,0.25)
	out.append(_block(rng,Vector3(rs*1.0,sh_y,rf*0.98),Vector3(rs*rng.randf_range(-0.1,0.1),sh_mid,rf*0.12),Basis(Vector3.RIGHT,lean),4,t.call(0.2),2))
	# Its second lobe: a tower split down its length.
	if rng.randf() < 0.6:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var ly := tall*rng.randf_range(0.28,0.38)
		var lt := Basis(Vector3.BACK,side*rng.randf_range(-0.08,0.12))*Basis(Vector3.RIGHT,lean*0.8)
		out.append(_block(rng,Vector3(rs*0.46,ly,rf*0.7),Vector3(side*rs*0.72,tall*0.4+ly*0.2,-rf*0.08),lt,3,t.call(0.25),2))
	# The crown: a fin, or a slab fallen askew on the shoulder.
	var crown_y := sh_mid+sh_y
	var rest := maxf(tall-crown_y,1.0)
	if rng.randf() < 0.55:
		var s := -1.0 if rng.randf() < 0.5 else 1.0
		var half := Vector3(rs*rng.randf_range(0.5,0.72),rest*0.72+sh_y*0.25,rf*rng.randf_range(0.42,0.6))
		var fin := [[Vector3(s*0.72,0.69,0.0).normalized(),half.y*0.34]]
		out.append(_block(rng,half,Vector3(-s*rs*0.2,crown_y+rest*0.28,rf*0.1),Basis(Vector3.RIGHT,lean*1.6),2,t.call(0.2),2,fin))
	else:
		var half := Vector3(rs*rng.randf_range(0.62,0.86),maxf(rest*0.46,0.8),rf*rng.randf_range(0.55,0.8))
		out.append(_block(rng,half,Vector3(rs*rng.randf_range(-0.16,0.16),crown_y+rest*0.34,rf*0.08),_tilt(rng,0.2,0.46),3,t.call(0.25),2))
	if tall > 20.0:
		var half := Vector3(rs*rng.randf_range(0.2,0.34),rest*0.4+1.0,rf*rng.randf_range(0.2,0.3))
		out.append(_block(rng,half,Vector3(rs*rng.randf_range(-0.5,0.5),crown_y+rest*0.1,rf*rng.randf_range(-0.4,0.4)),_tilt(rng,0.1,0.4),2,t.call(0.2),2))
	# Slabs split off its faces: a real crack behind each.
	for i in rng.randi_range(2,4):
		var along_z := rng.randf() < 0.5
		var s := -1.0 if rng.randf() < 0.5 else 1.0
		var th := clampf(rf*0.1,0.45,1.5)
		var h := tall*rng.randf_range(0.16,0.3)
		var y := tall*rng.randf_range(0.46,0.72)
		var gap := rng.randf_range(0.3,0.8)
		var at: Vector3
		var half: Vector3
		if along_z:
			at = Vector3(rs*rng.randf_range(-0.45,0.45),y,rf*(1.08 if s > 0.0 else -0.92)+s*(th+gap)+rf*0.1)
			half = Vector3(rs*rng.randf_range(0.26,0.5),h,th)
		else:
			at = Vector3(s*(rs*1.0+th+gap),y,rf*rng.randf_range(-0.4,0.5))
			half = Vector3(th,h,rf*rng.randf_range(0.28,0.55))
		var tip := Basis(Vector3.RIGHT if along_z else Vector3.BACK,s*rng.randf_range(0.03,0.12)*(1.0 if along_z else -1.0))
		out.append(_block(rng,half,at,tip,2,t.call(0.3),1))
	# Chips on the shoulder's edges, breaking the outline.
	for i in rng.randi_range(4,7):
		var ang := rng.randf()*TAU
		var y := tall*rng.randf_range(0.5,0.92)
		var sz := minf(rf,rs)*rng.randf_range(0.1,0.24)
		var half := Vector3(sz*rng.randf_range(0.7,1.5),sz*rng.randf_range(1.0,2.2),sz*rng.randf_range(0.7,1.3))
		var at := Vector3(cos(ang)*rs*0.9,y,sin(ang)*rf*0.9+rf*0.1)
		out.append(_block(rng,half,at,_tilt(rng,0.1,0.6),2,t.call(0.3),0))
	_tumbled(out,rng,rs,rf,rng.randi_range(1,3),t)
	return out

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
	var polys := _box(half)
	for c: Array in cuts: polys = _cut(polys,c[0],float(c[1]))
	for i in chops:
		var dir := Vector3(rng.randf_range(-1.0,1.0),rng.randf_range(-0.6,1.0),rng.randf_range(-1.0,1.0)).normalized()
		var reach := absf(dir.x)*half.x+absf(dir.y)*half.y+absf(dir.z)*half.z
		polys = _cut(polys,dir,reach*rng.randf_range(0.6,0.84))
	for i in polys.size():
		var f: PackedVector3Array = polys[i]
		for j in f.size(): f[j] = turn*f[j]+at
		polys[i] = f
	return {"polys":polys,"tone":tone,"level":level}

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
	for p: Dictionary in spec.pillars:
		var at: Vector3 = p.at
		for b: Dictionary in p.blocks: _emit(v,n,c,levels,b,p,at,rng)
		cuts.append((levels[1] as PackedInt32Array).size())
		solid.append(_solid(p))
		radii.append(float(p.r))
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
		lods[float(LOD_ERROR[l-1])*typical] = levels[l]
		tris.append((levels[l] as PackedInt32Array).size()/3)
	var coarse: PackedInt32Array = levels[1]
	var faces: Array = []
	for k in range(cuts.size()-1):
		var f := PackedVector3Array()
		f.resize(int(cuts[k+1])-int(cuts[k]))
		for i in range(f.size()): f[i] = v[coarse[int(cuts[k])+i]]
		faces.append(f)
	return {"spec":spec,"arrays":arrays,"lods":lods,"faces":faces,"solid":solid,"tris":tris}

## One block's faces into the arrays: each face its own vertices, so its
## normal is flat; a fan of triangles into the levels the block is in.
static func _emit(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, levels: Array, b: Dictionary, p: Dictionary, at: Vector3, rng: RandomNumberGenerator) -> void:
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
		var shade := clampf(tone+rng.randf_range(-0.09,0.09),0.0,1.0)
		var first := v.size()
		for q: Vector3 in f:
			v.append(at+q)
			n.append(nrm)
			var open := clampf((q.y-foot)/maxf(tall*0.42,1.0),0.0,1.0)*hollow
			c.append(Color(shade,open,0.0,0.0))
		for l in range(level+1):
			var idx: PackedInt32Array = levels[l]
			for i in range(1,m-1):
				if flip: idx.append_array([first,first+i+1,first+i])
				else: idx.append_array([first,first+i,first+i+1])
			levels[l] = idx
	# (Godot's front faces wind clockwise from outside: the fan above runs the
	# way `flip` found the polygon to, then RockBuild's order.)

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
