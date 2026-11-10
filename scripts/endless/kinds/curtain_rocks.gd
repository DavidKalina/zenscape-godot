extends RefCounted
## The boulders at a placed curtain's foot (scripts/endless/kinds/curtain.gd):
## blocks fallen round its plunge pool and heaped at the foot of its
## amphitheatre's walls, with a few strewn on the floor. The world's own
## blocks (scripts/endless/rocks/peak_boulders.gd `_block`, built by
## rock_build.gd) in the land's bare rock, one mesh and its collider; none
## in water or on the outflow. Seeded by the site's handle, so the same
## every time.

const Land = preload("res://scripts/endless/kinds/curtain_land.gd")
const Blocks = preload("res://scripts/endless/rocks/peak_boulders.gd")
const RockBuild = preload("res://scripts/endless/rocks/rock_build.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")

const LAYER := 1
## Round the pool: POOL_BLOCKS tries, POOL_OUT m past its water (min, max),
## radius POOL_SIZE (min, max).
const POOL_BLOCKS := 14
const POOL_OUT := Vector2(1.0,6.0)
const POOL_SIZE := Vector2(1.0,2.8)
## At the walls' foot: TALUS_ROWS heaps a side between TALUS_F (site f),
## each of up to 3 blocks of radius TALUS_SIZE, set TALUS_IN m in from where
## the wall rises WALL_RISE m over the floor.
const TALUS_ROWS := 6
const TALUS_F := Vector2(-66.0,-14.0)
const TALUS_SIZE := Vector2(1.6,4.2)
const TALUS_IN := Vector2(1.0,6.0)
const WALL_RISE := 2.0
## Strewn on the floor: FLOOR_BLOCKS tries of radius FLOOR_SIZE.
const FLOOR_BLOCKS := 8
const FLOOR_SIZE := Vector2(0.7,1.8)
## How far a block keeps off water (m past its radius); how much its ground
## may rise across it (a share of its radius).
const DRY_PAD := 1.0
const LEVEL := 0.8

static var _bare := {}

## Adds the boulders of shape `c` (curtain_land.gd) to curtain `root` (its
## frame the site's).
static func build(root: Node3D, site: Dictionary, c: PackedFloat32Array) -> void:
	var field: Object = site.get("field")
	if field == null: return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(site.get("handle","")),"curtain boulders"])
	var spots: Array = []
	var floor_y := c[Land.I_FLOOR]
	# Round the pool's front and sides (behind the fall is the face).
	for k in POOL_BLOCKS:
		var th := rng.randf_range(-PI*0.62,PI*0.62)
		var dir := Vector2(sin(th),cos(th))
		var ra := dir.x/c[Land.I_POOL_R]
		var rb := dir.y/c[Land.I_POOL_RF]
		var edge := 1.0/sqrt(ra*ra+rb*rb)
		var q := Vector2(0.0,c[Land.I_POOL_F])+dir*(edge+rng.randf_range(POOL_OUT.x,POOL_OUT.y))
		spots.append([q,rng.randf_range(POOL_SIZE.x,POOL_SIZE.y),rng.randf_range(0.3,0.9)])
	# Heaps at the walls' foot, each side.
	for side: float in [-1.0,1.0]:
		for k in TALUS_ROWS:
			var f := lerpf(TALUS_F.x,TALUS_F.y,(k+rng.randf())/TALUS_ROWS)
			var wall := _wall(c,field,f,side,floor_y)
			if is_nan(wall): continue
			var n := rng.randi_range(1,3)
			for m in n:
				var r := rng.randf_range(TALUS_SIZE.x,TALUS_SIZE.y)*(1.0 if m == 0 else 0.6)
				var q := Vector2(side*(wall-rng.randf_range(TALUS_IN.x,TALUS_IN.y)-r*0.5),f+rng.randf_range(-5.0,5.0))
				spots.append([q,r,rng.randf_range(0.4,1.2)])
	# Strewn on the floor between the pool and the foot.
	for k in FLOOR_BLOCKS:
		var q := Vector2(rng.randf_range(-40.0,40.0),rng.randf_range(c[Land.I_POOL_F]+c[Land.I_POOL_RF]+6.0,-6.0))
		spots.append([q,rng.randf_range(FLOOR_SIZE.x,FLOOR_SIZE.y),rng.randf_range(0.2,0.6)])
	var pillars: Array = []
	var anchor := Vector3.INF
	var placed: Array = []
	for sp: Array in spots:
		var q: Vector2 = sp[0]
		var r := float(sp[1])
		var w := Land.world(c,q)
		if not _dry(field,w,r+DRY_PAD) or not _level(field,w,r): continue
		var crowded := false
		for o: Vector3 in placed:
			if Vector2(o.x,o.y).distance_to(w) < (o.z+r)*0.9: crowded = true
		if crowded: continue
		placed.append(Vector3(w.x,w.y,r))
		if anchor == Vector3.INF: anchor = Vector3(w.x,float(field.height(w.x,w.y)),w.y)
		pillars.append(Blocks._block(field,anchor,w,r,r*float(sp[2]),rng))
	if pillars.is_empty(): return
	var b := RockBuild.build({"pos":anchor,"pillars":pillars,"bare":true})
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,b.arrays,[],b.lods,RockShape.format(b.arrays))
	mesh.surface_set_material(0,_material(site))
	var node := Node3D.new()
	node.name = "Boulders"
	var xform: Transform3D = site.get("xform",Transform3D.IDENTITY)
	node.transform = xform.affine_inverse()*Transform3D(Basis.IDENTITY,anchor)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	node.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = LAYER
	body.collision_mask = 0
	for faces: PackedVector3Array in b.faces:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	node.add_child(body)
	root.add_child(node)
	root.set_meta("boulders",pillars.size())

## How far out from the middle (|s|, m) the wall on `side` rises WALL_RISE
## over the floor at site f `f`; NAN where it doesn't within reach.
static func _wall(c: PackedFloat32Array, field: Object, f: float, side: float, floor_y: float) -> float:
	var s := 6.0
	while s < 90.0:
		var w := Land.world(c,Vector2(side*s,f))
		if float(field.height(w.x,w.y)) > floor_y+WALL_RISE: return s
		s += 1.5
	return NAN

## Whether the ground under a block of radius `r` at world `w` is level
## enough for it to lie on (not against a wall: a block's height is over its
## ground's high side).
static func _level(field: Object, w: Vector2, r: float) -> bool:
	var low := INF
	var high := -INF
	for k in 9:
		var d := Vector2.ZERO if k == 0 else Vector2.from_angle(TAU*k/8.0)*r
		var g := float(field.height(w.x+d.x,w.y+d.y))
		low = minf(low,g)
		high = maxf(high,g)
	return high-low < r*LEVEL

## Whether a block of radius `r` at world `w` keeps off all water.
static func _dry(field: Object, w: Vector2, r: float) -> bool:
	for k in 9:
		var d := Vector2.ZERO if k == 0 else Vector2.from_angle(TAU*k/8.0)*r
		if not is_nan(float(field.river_y(w.x+d.x,w.y+d.y))): return false
	return true

## The land's rock with no turf (as LandRocks `bare`, curtain_cave.gd), from
## the site's ground material (placed_sites.gd); a plain one without it.
static func _material(site: Dictionary) -> Material:
	var ground: Material = site.get("ground")
	if ground is ShaderMaterial:
		if not _bare.has(ground):
			var b := (ground as ShaderMaterial).duplicate() as ShaderMaterial
			b.set_shader_parameter("rock_up",1.2)
			b.set_shader_parameter("thin_up",1.3)
			b.set_shader_parameter("peak_ice_solid",-1.0)
			_bare[ground] = b
		return _bare[ground]
	var plain := StandardMaterial3D.new()
	plain.vertex_color_use_as_albedo = true
	plain.vertex_color_is_srgb = true
	plain.roughness = 1.0
	return plain
