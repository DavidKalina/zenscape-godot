extends RefCounted
## The Broken Viaduct's art (docs/design/roguelike/crossing-viaduct-art.md):
## the sky isles under its rims and the clods of rock its piers stand on,
## in the kit isles' one look (scripts/kit_isle/kit_land.gd, kit_look.gd:
## the plate's turf over a hanging keel of the islets' rock), and the great
## fallen slab of the launch in the ruin kit's stone (scripts/ruin_kit.gd).
## Only looks: the crossing keeps its own clean collision under each walk
## (crossing.gd `box`, drawn nothing), so no edge, height or gap moves.
## What collides here is under the walks: each isle's keel (a convex hull
## inside its drawn rock) and each clod (so a sail can't glide through it).
const RuinKit = preload("res://scripts/ruin_kit.gd")

## An outline (local x, z) round a box `half` (across, along) about
## `middle`, turned to the heading `deg` (Crossing `way`): its corners cut
## `chamfer` m, a point every `step` m, each pulled in up to `wander` m
## (never out: the drawn turf stays inside the walk's collision).
static func rect_ring(middle: Vector3, deg: float, half: Vector2, seed_value: int, chamfer := 0.9, step := 0.75, wander := 0.32) -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.35
	var arc := 0.0
	var a := deg_to_rad(deg)
	var along := Vector2(sin(a),-cos(a))
	var across := Vector2(-along.y,along.x)
	var c := Vector2(middle.x,middle.z)
	var corners: Array[Vector2] = []
	for k in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var q: Vector2 = k
		corners.append(Vector2(q.x*half.x,q.y*half.y))
	var out: Array = []
	for i in range(4):
		var p0 := corners[i]
		var p1 := corners[(i+1)%4]
		var d := (p1-p0).normalized()
		var s := p0+d*chamfer
		var e := p1-d*chamfer
		var n := maxi(1,int(ceil(s.distance_to(e)/step)))
		var inward := -Vector2(d.y,-d.x) if (Vector2(d.y,-d.x)).dot((s+e)*0.5) > 0.0 else Vector2(d.y,-d.x)
		for j in range(n):
			var p := s.lerp(e,float(j)/n)
			# A slow wander along the rim, in only, none at the corners.
			if j > 0: p += inward*wander*clampf(noise.get_noise_1d(arc)*0.9+0.5,0.0,1.0)
			arc += s.distance_to(e)/n
			out.append(c+across*p.x+along*p.y)
		arc += chamfer*1.4
	return out

## A blob outline (local x, z) round a box `half` about `middle`, heading
## `deg`: a rounded, wandering ring (a clod's).
static func blob_ring(middle: Vector3, deg: float, half: Vector2, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a := deg_to_rad(deg)
	var along := Vector2(sin(a),-cos(a))
	var across := Vector2(-along.y,along.x)
	var out: Array = []
	var count := 14
	for k in range(count):
		var t := k*TAU/count+rng.randf_range(-0.1,0.1)
		var r := rng.randf_range(0.9,1.15)
		# A superellipse: squarer than an ellipse, so a row of piers fits.
		var cx := signf(cos(t))*pow(absf(cos(t)),0.6)*half.x*r
		var cz := signf(sin(t))*pow(absf(sin(t)),0.6)*half.y*r
		out.append(Vector2(middle.x,middle.z)+across*cx+along*cz)
	return out

## A sky isle (local frame): its turf top flat at `top` inside `ring` (the
## plate's ground, `wear` (x, z) -> 0..1 worn bare where paved), its sides
## and keel of hanging rock `depth` under it (KitLand `ring_sides`, the
## aqueduct isle's islands'). Draws only, but for its keel: "Keel", a
## convex hull from `solid_from` m under the top (the walk's own box above
## it) inside the drawn rock, so a glide under the isle meets rock.
static func isle(ring: Array, top: float, depth: float, seed_value: int, wear := Callable(), solid_from := 2.0, cell := 1.4) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var flat := func(_x: float, _z: float) -> float: return top
	var node := Node3D.new()
	node.name = "Isle"
	var g := KitLand.Gather.new(ring,flat)
	g.grid(cell,rng,flat)
	var built := KitLand.surface(g.points,g.heights,g.poly,rng,KitLook.turf(seed_value,wear))
	KitLand.draw(node,built)
	var rims := PackedFloat32Array()
	for p: Vector2 in ring: rims.append(top)
	var centre := KitLand.centre_of(ring)
	var sides := KitLand.ring_sides(ring,rims,centre,top,depth,rng,true,false,false)
	node.add_child(sides.node("Mesh"))
	# The keel's hull: the outline pulled in, under the walk's box; half way
	# down pulled in further; the keel's point.
	var hull := PackedVector3Array()
	for i in range(ring.size()):
		var p: Vector2 = ring[i]
		var q := p.lerp(centre,clampf(0.35/maxf(p.distance_to(centre),0.01),0.0,0.9))
		hull.append(Vector3(q.x,top-solid_from,q.y))
		if i%2 == 0:
			var r := p.lerp(centre,0.45)
			hull.append(Vector3(r.x,top-depth*0.5,r.y))
	hull.append(Vector3(centre.x,top-depth*0.92,centre.y))
	var body := StaticBody3D.new()
	body.name = "Keel"
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	node.add_child(body)
	node.set_meta("outline",g.poly)
	return node

## A clod: a little isle of turf and rock (`isle`) that piers stand on,
## its top at `top`, its keel `depth` under; it collides whole (its top
## too: it is under the walks, 26 m under the start rim).
static func clod(ring: Array, top: float, depth: float, seed_value: int) -> Node3D:
	var node := isle(ring,top,depth,seed_value,Callable(),0.0,1.2)
	node.name = "Clod"
	return node

## A fallen run of the deck's masonry (the launch's slab, its lip's broken
## end): `size` (across, thick, along), its top's middle at the pose's
## origin, laid in worn blocks two across and about BLOCK long, joints
## staggered, each settled a little under the top (never over it: the walk
## is the crossing's clean box); drawn only. Ivy hangs off its underside.
const BLOCK := 1.15
static func slab_stone(seed_value: int, weathered: float, size: Vector3, _pieces := 1) -> Node3D:
	var b := RuinKit.Build.new(seed_value,weathered,"FallenSlab")
	var rows := maxi(1,int(round(size.z/BLOCK)))
	var run := size.z/rows
	for side: float in [-1.0,1.0]:
		var z := -size.z*0.5
		var first := run*(0.5 if side > 0.0 else 1.0)
		while z < size.z*0.5-0.05:
			var z1 := minf(size.z*0.5,z+first)
			first = run
			if size.z*0.5-z1 < 0.3: z1 = size.z*0.5
			var half := Vector3(size.x*0.25-0.01,size.y*0.5,(z1-z)*0.5-0.01)
			var sink := b.rng.randf_range(0.015,0.05)
			var tilt := Basis(Vector3.FORWARD,b.rng.randf_range(-0.012,0.012))*Basis(Vector3.RIGHT,b.rng.randf_range(-0.008,0.008))
			b.solid(RuinKit._box(b,half),Transform3D(tilt,Vector3(side*size.x*0.25,-half.y-sink,(z+z1)*0.5)),RuinKit._stone(b,b.rng.randf_range(0.95,1.05)),false)
			z = z1
	for i in range(3):
		b.hang(Vector3(b.rng.randf_range(-0.4,0.4)*size.x,-size.y,b.rng.randf_range(-0.45,0.45)*size.z),b.rng.randf_range(0.8,2.4),true,-size.y)
	return b.finish()
