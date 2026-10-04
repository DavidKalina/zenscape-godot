extends RefCounted
## One small islet floating between the sky islands (scripts/sky_islets.gd):
## scenery to fly past, round and under, and to perch on. Not a chunk: nothing
## is built on it and nothing on it is simulated.
##
## Its shape is a handful of seeded numbers, read the same way by the mesh and
## by the glide (`top`, `underside`, `inside`), so what the glide rides along
## is the faceted ground it sees. The frame is the islet's own: the middle of
## the grass top at the origin, y up.
##   outline: OUTLINE points round the middle, each at the radius times a
##     jitter, joined by straight edges;
##   top: a low dome with a few seeded swells; a spring's pond sits in a bowl
##     with a channel out to the rim, where its fall pours off;
##   rock: a grass lip, a band of earth, then stone hanging to a tip a little
##     off the middle, with a spur or two hanging lower.
## Kinds (KINDS): grove, a stand of spruces; spring, a pond with a fall off
## the rim and a few spruces; crag, a stone spire and one windswept spruce;
## tuft, a small one with a young spruce or two.

## Kinds and how often each turns up.
const KINDS := [["grove",0.32],["spring",0.3],["crag",0.18],["tuft",0.2]]
## Radius (m) by kind.
const RADIUS := {"grove":Vector2(5.0,8.0),"spring":Vector2(6.0,8.5),"crag":Vector2(3.5,5.0),"tuft":Vector2(2.4,3.6)}
## Outline points, and how far each may sit in or out (share of the radius).
const OUTLINE := 11
const RIM_JITTER := 0.2
## The top's grid: rings out to the rim (shares of the rim) and segments
## between outline points.
const RINGS := [0.0,0.18,0.34,0.5,0.64,0.77,0.88,0.96,1.0]
const SPLIT := 3
## The dome's height at the middle, and the swells: count, height, radius
## (shares of the islet's radius).
const DOME := 0.45
const SWELLS := 3
const SWELL := Vector2(0.15,0.5)
const SWELL_SIZE := Vector2(0.25,0.45)
## The side: the grass lip (m below the rim, share out), and the earth band's
## foot, where the stone begins.
const LIP := Vector2(0.22,1.04)
const EARTH_FOOT := 1.3
## The stone: depth under the earth's foot as a share of the radius, how it
## tapers (the power of the share in from the rim), and spurs.
const DEPTH := Vector2(1.3,2.1)
const TAPER := 1.3
const SPURS := Vector2i(1,2)
const SPUR := Vector2(0.4,0.9)
## The pond: its middle's distance out (share), its radius (share), the
## bowl's depth, the water's level, and the channel's half width (m).
const POND_OUT := 0.42
const POND_SIZE := 0.3
const BOWL := 0.55
const WATER := -0.14
const CHANNEL := 0.45
## The water's arrays carry the fetch as two float vec4s.
const WATER_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
## Where the bowl's bank meets the water, as a share of the pond's radius.
const SHORE := 0.85
## The crag's spire: height (m), base radius (share), sides.
const SPIRE := Vector2(3.5,6.0)
const SPIRE_BASE := 0.32
const SPIRE_SIDES := 6
## Spruces by kind: count, height (m), and the variants (hero_trees.gd SPRUCE).
const TREES := {"grove":Vector2i(4,8),"spring":Vector2i(2,4),"crag":Vector2i(1,1),"tuft":Vector2i(1,2)}
const TREE_HEIGHT := {"grove":Vector2(3.0,5.0),"spring":Vector2(2.6,4.2),"crag":Vector2(2.2,3.2),"tuft":Vector2(1.6,2.6)}
const TREE_VARIANTS := {"grove":[0,1,2,4],"spring":[0,1,2],"crag":[3],"tuft":[1]}
## Trees keep this far apart (m), and in from the rim (share).
const TREE_APART := 1.6
const TREE_IN := 0.8
## A tree's crown, for the glide to ride over: its radius as a share of its
## height.
const CROWN := 0.28
## Colours down the stone (sRGB): earth under the grass, then stone, then a
## cool, dusky tip, as the plate's own rock (scripts/island_keel.gd).
const EARTH := Color("6e5340")
const STONE := Color("7d7468")
const TIP := Color("5c5a66")

var seed := 0
var kind := "grove"
var radius := 6.0
## Outline points (islet frame, x and z).
var rim := PackedVector2Array()
## Swells: (x, z, radius, height).
var swells := PackedVector4Array()
## How deep the stone hangs under the earth's foot at the middle, and where
## its deepest point lies.
var depth := 10.0
var keel_at := Vector2.ZERO
## Spurs: (x, z, radius, extra depth).
var spurs := PackedVector4Array()
## The pond (x, z, radius), zero radius if none, and the fall's lip on the
## rim with the way out (normal).
var pond := Vector3.ZERO
var lip := Vector2.ZERO
var lip_out := Vector2.ZERO
## The spire (x, z, base radius, height), zero height if none.
var spire := Vector4.ZERO
## Trees: (x, z, height, variant), standing on the top.
var trees: Array[Vector4] = []

## The islet for `seed` (a hash from its cell), of `kind` if given, or one
## drawn by the seed.
static func make(seed_value: int, forced := "") -> RefCounted:
	var islet: RefCounted = new()
	islet._shape(seed_value,forced)
	return islet

static func pick_kind(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k: Array in KINDS: total += float(k[1])
	var roll := rng.randf()*total
	for k: Array in KINDS:
		roll -= float(k[1])
		if roll <= 0.0: return k[0]
	return KINDS[0][0]

func _shape(seed_value: int, forced: String) -> void:
	seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	kind = forced if forced != "" else pick_kind(rng)
	var size: Vector2 = RADIUS[kind]
	radius = rng.randf_range(size.x,size.y)
	var turn := rng.randf()*TAU
	rim.clear()
	for i in range(OUTLINE):
		var a := turn+TAU*i/OUTLINE+rng.randf_range(-0.12,0.12)
		rim.append(Vector2.from_angle(a)*radius*rng.randf_range(1.0-RIM_JITTER,1.0+RIM_JITTER*0.6))
	swells.clear()
	for i in range(SWELLS):
		var at := Vector2.from_angle(rng.randf()*TAU)*radius*rng.randf_range(0.1,0.6)
		swells.append(Vector4(at.x,at.y,radius*rng.randf_range(SWELL_SIZE.x,SWELL_SIZE.y),rng.randf_range(SWELL.x,SWELL.y)))
	depth = radius*rng.randf_range(DEPTH.x,DEPTH.y)
	keel_at = Vector2.from_angle(rng.randf()*TAU)*radius*rng.randf_range(0.05,0.25)
	spurs.clear()
	for i in range(rng.randi_range(SPURS.x,SPURS.y)):
		var at := Vector2.from_angle(rng.randf()*TAU)*radius*rng.randf_range(0.3,0.6)
		spurs.append(Vector4(at.x,at.y,radius*rng.randf_range(0.2,0.32),depth*rng.randf_range(SPUR.x,SPUR.y)))
	pond = Vector3.ZERO
	spire = Vector4.ZERO
	if kind == "spring":
		var way := Vector2.from_angle(rng.randf()*TAU)
		var middle := way*radius*POND_OUT
		pond = Vector3(middle.x,middle.y,radius*POND_SIZE)
		var edge := rim_point(way.angle())
		lip = edge
		lip_out = edge.normalized()
	elif kind == "crag":
		var at := Vector2.from_angle(rng.randf()*TAU)*radius*rng.randf_range(0.0,0.2)
		spire = Vector4(at.x,at.y,radius*SPIRE_BASE*rng.randf_range(0.9,1.15),rng.randf_range(SPIRE.x,SPIRE.y))
	_plant(rng)

## Spruces scattered on the top, apart, in from the rim, clear of the pond's
## water and the spire.
func _plant(rng: RandomNumberGenerator) -> void:
	trees.clear()
	var count: Vector2i = TREES[kind]
	var heights: Vector2 = TREE_HEIGHT[kind]
	var variants: Array = TREE_VARIANTS[kind]
	var want := rng.randi_range(count.x,count.y)
	for attempt in range(want*12):
		if trees.size() >= want: break
		var a := rng.randf()*TAU
		var at := Vector2.from_angle(a)*rim_radius(a)*TREE_IN*sqrt(rng.randf())
		if pond.z > 0.0 and (at.distance_to(Vector2(pond.x,pond.y)) < pond.z+0.8 or _near_channel(at,CHANNEL+0.6)): continue
		if spire.w > 0.0 and at.distance_to(Vector2(spire.x,spire.y)) < spire.z+0.7: continue
		var crowded := false
		for t in trees:
			if at.distance_to(Vector2(t.x,t.y)) < TREE_APART: crowded = true
		if crowded: continue
		var h := rng.randf_range(heights.x,heights.y)
		# On a crag the one tree leans off the spire, out near the rim.
		trees.append(Vector4(at.x,at.y,h,float(variants[rng.randi() % variants.size()])))

## The rim's distance from the middle at angle `a` (radians, from +x toward
## +z), along the straight edge between outline points.
func rim_radius(a: float) -> float:
	return _rim_hit(a).x

## Where the ray from the middle at angle `a` meets the outline: Vector3(its
## distance, the edge's first point, the share along that edge).
func _rim_hit(a: float) -> Vector3:
	var dir := Vector2.from_angle(a)
	for i in range(rim.size()):
		var p := rim[i]
		var q := rim[(i+1) % rim.size()]
		var edge := q-p
		var den := dir.cross(edge)
		if absf(den) < 0.000001: continue
		# Ray dir*t meets p + edge*u.
		var t := p.cross(edge)/den
		var u := p.cross(dir)/den
		if t > 0.0 and u >= -0.0001 and u <= 1.0001: return Vector3(t,i,clampf(u,0.0,1.0))
	return Vector3(radius,0.0,0.0)

func rim_point(a: float) -> Vector2:
	return Vector2.from_angle(a)*rim_radius(a)

## How far out toward the rim a point is: 0 at the middle, 1 on it.
func share(p: Vector2) -> float:
	if p.length() < 0.0001: return 0.0
	return p.length()/rim_radius(p.angle())

func inside(p: Vector2) -> bool:
	return share(p) <= 1.0

## The ground's height at a point inside (islet frame), without the trees.
func top(p: Vector2) -> float:
	var s := minf(share(p),1.0)
	var h := DOME*(1.0-s*s)
	for w in swells:
		var d := p.distance_to(Vector2(w.x,w.y))/w.z
		if d < 1.0: h += w.w*(1.0-d*d)*(1.0-d*d)
	if pond.z > 0.0:
		var middle := Vector2(pond.x,pond.y)
		var d := p.distance_to(middle)/pond.z
		var bowl := 1.0-smoothstep(0.55,1.15,d)
		# The channel to the rim, a shallower cut.
		var cut := 1.0-smoothstep(CHANNEL*0.6,CHANNEL*1.4,_channel_distance(p))
		h = minf(h,lerpf(h,WATER-BOWL,bowl))
		h = minf(h,lerpf(h,WATER-0.12,cut))
	return h

## The ground's height as drawn: on the mesh's own faceted triangles over
## the grid (`_grid`), so a walker's feet and a skimming glide sit on what
## is seen, not on the smooth shape under it.
func ground_at(p: Vector2) -> float:
	var s := share(p)
	if s >= 1.0: return top(p)
	var hit := _rim_hit(p.angle())
	var along := (int(hit.y)+hit.z)*SPLIT
	var j := mini(int(floor(along)),rim.size()*SPLIT-1)
	var k := 0
	while k < RINGS.size()-2 and s > float(RINGS[k+1]): k += 1
	var a := _grid(k,j)
	var b := _grid(k,j+1)
	var c := _grid(k+1,j+1)
	var d := _grid(k+1,j)
	for tri: Array in [[a,b,c],[a,c,d]]:
		var w := _barycentric(p,tri[0],tri[1],tri[2])
		if w.x >= -0.001 and w.y >= -0.001 and w.z >= -0.001:
			return w.x*top(tri[0])+w.y*top(tri[1])+w.z*top(tri[2])
	return top(p)

static func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b-a
	var v1 := c-a
	var v2 := p-a
	var den := v0.cross(v1)
	if absf(den) < 0.0000001: return Vector3(-1.0,-1.0,-1.0)
	var v := v2.cross(v1)/den
	var w := v0.cross(v2)/den
	return Vector3(1.0-v-w,v,w)

## The height the glide rides over: the ground, the spire, the crowns.
func solid_top(p: Vector2) -> float:
	var h := ground_at(p)
	if spire.w > 0.0:
		var d := p.distance_to(Vector2(spire.x,spire.y))/spire.z
		if d < 1.0: h = maxf(h,top(Vector2(spire.x,spire.y))+spire.w*(1.0-d))
	for t in trees:
		if p.distance_to(Vector2(t.x,t.y)) < t.z*CROWN: h = maxf(h,top(Vector2(t.x,t.y))+t.z)
	return h

## The stone's underside under a point inside.
func underside(p: Vector2) -> float:
	var s := minf(share(p),1.0)
	# Deepest toward keel_at: measure the share in from the rim from there.
	var off := p-keel_at
	var reach := maxf(rim_radius(off.angle())*(1.0-keel_at.length()/maxf(radius,0.01)*0.5),0.5)
	var k := clampf(1.0-off.length()/reach,0.0,1.0)
	var d := depth*pow(k,TAPER)*(1.0-smoothstep(0.85,1.0,s))
	for sp in spurs:
		var near := 1.0-clampf(p.distance_to(Vector2(sp.x,sp.y))/sp.z,0.0,1.0)
		d += sp.w*near*near
	return -EARTH_FOOT-d

## The pond's water in the islet frame: level, middle and radius, with the
## channel to the lip; empty if the islet has none.
func water() -> Dictionary:
	if pond.z <= 0.0: return {}
	return {"level":WATER,"middle":Vector2(pond.x,pond.y),"radius":pond.z,"lip":lip,"out":lip_out}

func _channel_distance(p: Vector2) -> float:
	var a := Vector2(pond.x,pond.y)
	var ab := lip-a
	var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
	return p.distance_to(a+ab*t)

func _near_channel(p: Vector2, reach: float) -> bool:
	return _channel_distance(p) < reach

## Points on the top's grid: ring k, segment j (OUTLINE*SPLIT round).
func _grid(k: int, j: int) -> Vector2:
	var n := rim.size()*SPLIT
	j = posmod(j,n)
	var i := j/SPLIT
	var f := float(j % SPLIT)/SPLIT
	var edge := rim[i].lerp(rim[(i+1) % rim.size()],f)
	return edge*float(RINGS[k])

## The islet's body as one mesh, one draw: grass (the top and its lip),
## earth (the band under it), stone (the rock hanging below, the spire).
## Coloured per face as the plate's terrain is: `grass` and `rock` are the
## world's palette (linear), a few greens and greys to pick between, and
## `bank` the pond's bed. The top carries the ground's smoothed normals, so
## the plate's terrain material (reference_surface's ground) lights it as
## soft as the plate; the rest stays faceted. Every vertex is laid `shift`
## off the islet's middle (see SkyIslets OFF_MAP).
func build_mesh(grass: Array, rock: Array, material: Material, bank := Color(0.45,0.4,0.3), shift := Vector3.ZERO) -> ArrayMesh:
	return mesh_from(body_arrays(grass,rock,bank,shift),material)

## The body's surface arrays (`build_mesh`), safe to make on a worker.
func body_arrays(grass: Array, rock: Array, bank := Color(0.45,0.4,0.3), shift := Vector3.ZERO) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*31+7
	var lists := [[],[],[]]
	var n := rim.size()*SPLIT
	var last := RINGS.size()-1
	# Each grid point's ground and stone, worked out once: every point is a
	# corner of six faces.
	var ups := []
	var downs := []
	for k in range(RINGS.size()):
		var up_row := []
		var down_row := []
		for j in range(n):
			var p := _grid(k,j)
			up_row.append(_up(p))
			down_row.append(_down(p))
		ups.append(up_row)
		downs.append(down_row)
	var softs := []
	for k in range(RINGS.size()):
		var row := []
		for j in range(n): row.append(soft_normal(_grid(k,j)))
		softs.append(row)
	var up := func(k: int, j: int) -> Vector3: return ups[k][posmod(j,n)]
	var down := func(k: int, j: int) -> Vector3: return downs[k][posmod(j,n)]
	var soft := func(k: int, j: int) -> Vector3: return softs[k][posmod(j,n)]
	# The top: grass, and under the pond's water its bed.
	for k in range(last):
		for j in range(n):
			var corners := [[k,j],[k,j+1],[k+1,j+1],[k+1,j]]
			var tris := [[0,2,3]] if k == 0 else [[0,1,2],[0,2,3]]
			for t: Array in tris:
				var p := []
				var normals := []
				for i: int in t:
					p.append(up.call(corners[i][0],corners[i][1]))
					normals.append(soft.call(corners[i][0],corners[i][1]))
				var low := minf((p[0] as Vector3).y,minf((p[1] as Vector3).y,(p[2] as Vector3).y))
				var green: Color = grass[rng.randi() % grass.size()]
				var tone := green*rng.randf_range(0.9,1.06)
				if pond.z > 0.0 and low < WATER+0.04:
					tone = bank*lerpf(1.0,0.72,clampf((WATER-low)/BOWL,0.0,1.0))*rng.randf_range(0.94,1.04)
				_tri(lists[0],p[0],p[1],p[2],tone,Vector3.UP,normals)
	# The side: rim, grass lip, earth foot.
	for j in range(n):
		var rp: Vector3 = up.call(last,j)
		var rq: Vector3 = up.call(last,j+1)
		var lp := Vector3(rp.x*LIP.y,-LIP.x,rp.z*LIP.y)
		var lq := Vector3(rq.x*LIP.y,-LIP.x,rq.z*LIP.y)
		var fp := Vector3(rp.x,-EARTH_FOOT,rp.z)
		var fq := Vector3(rq.x,-EARTH_FOOT,rq.z)
		var green: Color = grass[rng.randi() % grass.size()]
		var out := Vector3(rp.x+rq.x,0.0,rp.z+rq.z)
		_quad(lists[0],rp,lp,lq,rq,green*0.82,out)
		var earth := EARTH.srgb_to_linear()*rng.randf_range(0.88,1.08)
		_quad(lists[1],lp,fp,fq,lq,earth,out)
	# The stone underneath, faced down and out.
	for k in range(last):
		for j in range(n):
			var a: Vector3 = down.call(k,j)
			var b: Vector3 = down.call(k,j+1)
			var c: Vector3 = down.call(k+1,j+1)
			var d: Vector3 = down.call(k+1,j)
			if k == 0:
				_tri(lists[2],a,d,c,_stone(a,rock,rng),Vector3.DOWN)
			else:
				_tri(lists[2],a,c,b,_stone((a+c)*0.5,rock,rng),Vector3.DOWN)
				_tri(lists[2],a,d,c,_stone((a+c)*0.5,rock,rng),Vector3.DOWN)
	if spire.w > 0.0: _spire(lists[2],rock,rng)
	return _arrays(lists[0]+lists[1]+lists[2],shift)

## A one-surface mesh from surface arrays, with its material.
static func mesh_from(arrays: Array, material: Material, format := 0) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},format)
	if material != null: mesh.surface_set_material(0,material)
	return mesh

## The ground's smoothed normal at a point: central differences over the
## shape, as the plate's ground takes its own from the height map.
func soft_normal(p: Vector2) -> Vector3:
	var e := 0.4
	var dx := top(p+Vector2(e,0.0))-top(p-Vector2(e,0.0))
	var dz := top(p+Vector2(0.0,e))-top(p-Vector2(0.0,e))
	return Vector3(-dx/(2.0*e),1.0,-dz/(2.0*e)).normalized()

## A faceted stone spire, jittered, its sides leaning in to a blunt top.
func _spire(out: Array, rock: Array, rng: RandomNumberGenerator) -> void:
	var middle := Vector2(spire.x,spire.y)
	var foot := top(middle)-0.3
	var levels := [[0.0,1.0],[0.45,0.62],[0.8,0.32],[1.0,0.12]]
	var ring := []
	for l: Array in levels:
		var points := []
		for s in range(SPIRE_SIDES):
			var a := TAU*s/SPIRE_SIDES+rng.randf_range(-0.15,0.15)
			var r: float = spire.z*float(l[1])*rng.randf_range(0.85,1.1)
			points.append(Vector3(middle.x+cos(a)*r,foot+spire.w*float(l[0])+rng.randf_range(-0.15,0.15),middle.y+sin(a)*r))
		ring.append(points)
	for l in range(levels.size()-1):
		for s in range(SPIRE_SIDES):
			var a: Vector3 = ring[l][s]
			var b: Vector3 = ring[l][(s+1) % SPIRE_SIDES]
			var c: Vector3 = ring[l+1][(s+1) % SPIRE_SIDES]
			var d: Vector3 = ring[l+1][s]
			var grey: Color = rock[rng.randi() % rock.size()]
			var away := (a+b)*0.5-Vector3(middle.x,(a.y+b.y)*0.5,middle.y)
			_quad(out,a,d,c,b,grey*rng.randf_range(0.85,1.05),away)
	var cap: Array = ring[levels.size()-1]
	var tip := Vector3(middle.x,foot+spire.w+0.25,middle.y)
	for s in range(SPIRE_SIDES):
		var grey: Color = rock[rng.randi() % rock.size()]
		_tri(out,cap[s],tip,cap[(s+1) % SPIRE_SIDES],grey*rng.randf_range(0.9,1.1),Vector3.UP)

func _up(p: Vector2) -> Vector3:
	return Vector3(p.x,top(p),p.y)

func _down(p: Vector2) -> Vector3:
	return Vector3(p.x,underside(p),p.y)

## A stone face's colour by how deep it hangs, nudged.
func _stone(at: Vector3, rock: Array, rng: RandomNumberGenerator) -> Color:
	var k := clampf((-at.y-EARTH_FOOT)/maxf(depth,0.01),0.0,1.0)
	var grey: Color = rock[rng.randi() % rock.size()]
	var band := EARTH.srgb_to_linear().lerp(grey,smoothstep(0.0,0.3,k)).lerp(TIP.srgb_to_linear(),smoothstep(0.55,1.0,k))
	return band*rng.randf_range(0.88,1.08)

## Adds a triangle facing the side `outward` points to: wound clockwise seen
## from there (Godot's front), with that face's flat normal.
## `normals`, if given, are the corners' own (smooth) normals in a, b, c order.
static func _tri(out: Array, a: Vector3, b: Vector3, c: Vector3, tone: Color, outward: Vector3, normals := []) -> void:
	var nrm := (c-a).cross(b-a)
	if nrm.length_squared() < 0.0000001: return
	var each := [nrm.normalized(),nrm.normalized(),nrm.normalized()] if normals.is_empty() else normals.duplicate()
	if nrm.dot(outward) < 0.0:
		var swap := b
		b = c
		c = swap
		var turn: Vector3 = each[1]
		each[1] = each[2]
		each[2] = turn
	tone.a = 1.0
	if normals.is_empty():
		for i in range(3): each[i] = -each[i] if nrm.dot(outward) < 0.0 else each[i]
	var corners := [a,b,c]
	for i in range(3): out.append([corners[i],each[i],tone])

static func _quad(out: Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tone: Color, outward: Vector3) -> void:
	_tri(out,a,b,c,tone,outward)
	_tri(out,a,c,d,tone,outward)

## Surface arrays for faces [point, normal, colour]. Every vertex carries
## what the plate terrain's growth reads (reference_surface
## `terrain_growth`): UV.y 1, fully grown, and its height in UV2.y, where the
## grown ground stands.
static func _arrays(entries: Array, shift := Vector3.ZERO) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for e: Array in entries:
		var v: Vector3 = (e[0] as Vector3)+shift
		vertices.append(v)
		normals.append(e[1])
		colors.append(e[2])
		uv.append(Vector2(0.0,1.0))
		uv2.append(Vector2(0.5,v.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	return arrays

## The pond's surface for the plate's own still-water material
## (reference_water_body): a fine sheet, so its chop has vertices to stand
## on, a disc over the pond and a strip down the channel to the lip. Each
## vertex carries what that water reads: its depth over the bed (UV2.x),
## a run to the bank for the shore foam (UV.x), and the fetch, open water
## upwind in eight directions (CUSTOM0, CUSTOM1), for the chop. `color` is
## the body where the material has no depth tint. Laid `shift` off, as the
## body is.
func build_water(material: Material, color := Color(0.25,0.57,0.59), shift := Vector3.ZERO) -> ArrayMesh:
	var arrays := water_arrays(color,shift)
	return null if arrays.is_empty() else mesh_from(arrays,material,WATER_FORMAT)

## The pond's surface arrays (`build_water`), empty with no pond; safe to
## make on a worker.
func water_arrays(color := Color(0.25,0.57,0.59), shift := Vector3.ZERO) -> Array:
	if pond.z <= 0.0: return []
	var middle := Vector2(pond.x,pond.y)
	var r := pond.z*1.1
	var rings := maxi(int(ceil(r/0.28)),4)
	var segments := 36
	var faces := []
	var at := func(p: Vector2) -> Vector3: return Vector3(p.x,WATER,p.y)
	var ring := func(k: int, s: int) -> Vector2: return middle+Vector2.from_angle(TAU*s/segments)*r*k/rings
	for k in range(rings):
		for s in range(segments):
			var a: Vector2 = ring.call(k,s)
			var b: Vector2 = ring.call(k,s+1)
			var c: Vector2 = ring.call(k+1,s+1)
			var d: Vector2 = ring.call(k+1,s)
			if k == 0:
				_tri(faces,at.call(a),at.call(c),at.call(d),color,Vector3.UP)
			else:
				_quad(faces,at.call(a),at.call(b),at.call(c),at.call(d),color,Vector3.UP)
	# The channel: from inside the pond to just past the lip.
	var way := (lip-middle).normalized()
	var side := Vector2(-way.y,way.x)*CHANNEL*0.85
	var from := middle+way*pond.z*0.6
	var to := lip+way*0.05
	var steps := maxi(int(ceil(from.distance_to(to)/0.3)),1)
	for i in range(steps):
		var p0 := from.lerp(to,float(i)/steps)
		var p1 := from.lerp(to,float(i+1)/steps)
		_quad(faces,at.call(p0-side),at.call(p0+side),at.call(p1+side),at.call(p1-side),color,Vector3.UP)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var fetch_a := PackedFloat32Array()
	var fetch_b := PackedFloat32Array()
	var dirs := []
	for i in range(8): dirs.append(Vector2.from_angle(TAU*i/8.0))
	for f: Array in faces:
		var v: Vector3 = f[0]
		var p := Vector2(v.x,v.z)
		var depth := maxf(WATER-ground_at(p),0.0)
		vertices.append(v+shift)
		normals.append(Vector3.UP)
		colors.append(f[2])
		uv.append(Vector2(depth*2.5,0.0))
		uv2.append(Vector2(depth,0.0))
		# Fetch order (reference_lake_chop zsFetch): +x, +x+z, +z, -x+z, then
		# the opposites.
		# The open water that way: to the pond's shore, taken as a circle
		# where the bowl meets the water (SHORE of its radius).
		var runs := []
		for d: Vector2 in [dirs[0],dirs[1],dirs[2],dirs[3],-dirs[0],-dirs[1],-dirs[2],-dirs[3]]:
			var o := p-middle
			var shore := pond.z*SHORE
			var bq := o.dot(d)
			var cq := o.length_squared()-shore*shore
			var disc := bq*bq-cq
			runs.append(clampf(-bq+sqrt(disc),0.0,9.0) if disc > 0.0 else 0.0)
		fetch_a.append_array([runs[0],runs[1],runs[2],runs[3]])
		fetch_b.append_array([runs[4],runs[5],runs[6],runs[7]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = fetch_a
	arrays[Mesh.ARRAY_CUSTOM1] = fetch_b
	return arrays
