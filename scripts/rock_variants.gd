extends RefCounted
## Seeded faceted stones behind the `rock` and `boulder_1..4` props.
## Eight shapes are built once from fixed seeds and shared by every world as
## MultiMesh batches. A world leans on one rock character (SeededVariety), and
## each stone gets its own proportions, tilt and weathering from a stable hash.
## Records are unchanged: the variant is a render-side choice, like the spruce
## family. `--classic-rocks` restores the source sphere and icosahedra.
const Variety = preload("res://scripts/seeded_variety.gd")

## name, seed, [stretch, cuts, cut depth, lumps, taper, flat top, weathering]
## stretch: proportions before normalising the footprint to 1 m.
## cuts: planes sliced off the hull; they make the big facets.
## cut depth: how far a cut may reach into the stone (0..1 of its radius).
## lumps: radial noise before cutting. taper: top width against the base.
## flat top: a horizontal cut through the crown (0 = none).
## weathering: facet contrast and the damp stain near the ground.
const VARIANTS := [
	["rounded", 11, [Vector3(1.0,0.72,0.86), 5, 0.10, 0.10, 0.9, 0.0, 0.5]],
	["lumpy", 23, [Vector3(1.0,0.78,0.92), 9, 0.14, 0.22, 0.85, 0.0, 1.0]],
	["blocky", 37, [Vector3(1.0,0.82,0.8), 10, 0.22, 0.06, 0.95, 0.0, 0.7]],
	["tabular", 41, [Vector3(1.0,0.62,0.9), 7, 0.18, 0.08, 0.92, 0.72, 0.8]],
	["slab", 53, [Vector3(1.0,0.36,0.78), 7, 0.16, 0.06, 0.95, 0.0, 0.6]],
	["flag", 67, [Vector3(1.0,0.5,0.34), 8, 0.2, 0.05, 0.8, 0.0, 0.7]],
	["shard", 71, [Vector3(0.62,0.95,0.58), 8, 0.2, 0.08, 0.45, 0.0, 0.8]],
	["column", 83, [Vector3(0.7,1.05,0.66), 9, 0.24, 0.04, 0.9, 0.82, 0.9]],
]
## Old footprint per kind, in metres at scale 1, so collisions, cover
## and clearings keep their sizes. The rock was a 1.2 m sphere lifted
## 0.24; boulders were rotated icosahedra standing on their lowest point.
const FOOTPRINT := {"rock":1.2,"boulder_1":1.9,"boulder_2":1.55,"boulder_3":1.45,"boulder_4":1.55}
## Rocks sit on this share of their height below the ground.
const SINK := 0.12
## The shared stone material is the boulders' (reference_surface, base
## 0.606/0.577/0.512, flat faces, wet ground). The old `rock` had a white base
## over 969986 vertex colour, so its instances carry that colour over the base.
const BOULDER_BASE := Color(0.6061,0.5768,0.5123)
const ROCK_GREY := Color("969986")

static var _meshes := {}

static func enabled() -> bool:
	return not ("--classic-rocks" in OS.get_cmdline_user_args() or "--classic-rocks" in OS.get_cmdline_args())

static func keys() -> Array:
	var out := []
	for entry in VARIANTS: out.append("boulder_stone:%s" % entry[0])
	return out

static func is_stone(asset: String) -> bool:
	return FOOTPRINT.has(asset)

## The variant index for a stone record in a world (see SeededVariety.world).
static func index(item: Dictionary, world: Dictionary) -> int:
	var weights: Array = world.get("rock",[])
	if weights.size() != VARIANTS.size():
		weights = []
		for entry in VARIANTS: weights.append(1.0)
	return Variety.weighted(weights,Variety.unit(Variety.record_key(int(world.get("salt",0)),item,11)))

## The part transform under the record's own angle and scale: footprint,
## per-stone proportions and a slight tilt. Stable per record.
static func pose(item: Dictionary, world: Dictionary) -> Transform3D:
	var key := Variety.record_key(int(world.get("salt",0)),item,12)
	var size: float = FOOTPRINT[item.asset]
	var stretch := Vector3(lerpf(0.82,1.18,Variety.unit(key+[1])),lerpf(0.78,1.22,Variety.unit(key+[2])),lerpf(0.82,1.18,Variety.unit(key+[3])))
	var tilt_axis := Vector3.RIGHT.rotated(Vector3.UP,Variety.unit(key+[4])*TAU)
	var tilt := Variety.unit(key+[5])*0.14
	var basis := Basis(tilt_axis,tilt)*Basis.from_scale(stretch*size)
	return Transform3D(basis,Vector3.ZERO)

## Instance colour: the user's tint, or the kind's own stone colour with a
## small per-stone value shift (weathered, darker or fresher faces).
static func color(item: Dictionary, tint: Variant, world: Dictionary) -> Color:
	var base := BOULDER_BASE
	if tint != null:
		# Tints were authored over each kind's own base: white for `rock`.
		return Color(tint.r/base.r,tint.g/base.g,tint.b/base.b,tint.a) if item.asset == "rock" else tint
	var own := Color.WHITE
	if item.asset == "rock":
		var grey := ROCK_GREY.srgb_to_linear()
		own = Color(grey.r/base.r,grey.g/base.g,grey.b/base.b)
	var shade := lerpf(0.9,1.08,Variety.unit(Variety.record_key(int(world.get("salt",0)),item,13)))
	return Color(own.r*shade,own.g*shade,own.b*shade,1.0)

static func mesh(index: int, material: Material) -> ArrayMesh:
	if not _meshes.has(index):
		var entry: Array = VARIANTS[index]
		_meshes[index] = build(int(entry[1]),entry[2])
	var out: ArrayMesh = _meshes[index].duplicate()
	if material != null: out.surface_set_material(0,material)
	return out

## One faceted stone: an icosphere with lumps, sliced by random planes, then
## normalised to a 1 m footprint standing on its base. Flat-shaded with a
## greyscale weathering bake; the material's base colour gives the hue.
static func build(seed_value: int, shape: Array) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stretch: Vector3 = shape[0]
	var cuts: int = shape[1]
	var depth: float = shape[2]
	var lumps: float = shape[3]
	var taper: float = shape[4]
	var flat_top: float = shape[5]
	var weathering: float = shape[6]
	var sphere := _icosphere()
	var points: Array[Vector3] = sphere[0]
	var faces: PackedInt32Array = sphere[1]
	for i in range(points.size()):
		points[i] = points[i]*(1.0+lumps*(rng.randf()-0.5))*stretch
	# Planar cuts: each one flattens every point beyond it onto the plane.
	var planes: Array[Plane] = []
	for c in range(cuts):
		var normal := Vector3(rng.randf_range(-1,1),rng.randf_range(-0.7,1.0),rng.randf_range(-1,1)).normalized()
		var reach := -INF
		for p in points: reach = maxf(reach,normal.dot(p))
		planes.append(Plane(normal,reach*(1.0-depth*rng.randf_range(0.35,1.0))))
	if flat_top > 0.0:
		var top := -INF
		for p in points: top = maxf(top,p.y)
		planes.append(Plane(Vector3.UP,top*flat_top))
	# A flat base, so the stone seats instead of balancing on a point.
	var bottom := INF
	for p in points: bottom = minf(bottom,p.y)
	planes.append(Plane(Vector3.DOWN,-bottom*0.8))
	for plane in planes:
		for i in range(points.size()):
			var over := plane.normal.dot(points[i])-plane.d
			if over > 0.0: points[i] -= plane.normal*over
	# Taper toward the crown, then stand on the base with a 1 m footprint.
	var bounds := AABB(points[0],Vector3.ZERO)
	for p in points: bounds = bounds.expand(p)
	for i in range(points.size()):
		var t := inverse_lerp(bounds.position.y,bounds.end.y,points[i].y)
		var w := lerpf(1.0,taper,t*t)
		points[i] = Vector3(points[i].x*w,points[i].y,points[i].z*w)
	bounds = AABB(points[0],Vector3.ZERO)
	for p in points: bounds = bounds.expand(p)
	var footprint := maxf(bounds.size.x,bounds.size.z)
	var offset := Vector3(bounds.get_center().x,bounds.position.y+bounds.size.y*SINK,bounds.get_center().z)
	for i in range(points.size()):
		points[i] = (points[i]-offset)/footprint
	var center := Vector3(0.0,(0.5-SINK)*bounds.size.y/footprint,0.0)
	var height := bounds.size.y/footprint
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in range(0,faces.size(),3):
		var vertices: Array[Vector3] = [points[faces[f]],points[faces[f+1]],points[faces[f+2]]]
		var normal := (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0])
		if normal.length_squared() < 1e-10: continue
		normal = normal.normalized()
		var midpoint := (vertices[0]+vertices[1]+vertices[2])/3.0
		if normal.dot(midpoint-center) < 0.0: normal = -normal
		else: vertices.reverse() # Godot front faces use clockwise winding.
		# Weathering, as light and shade only: sunlit tops bleach, faces near
		# the ground carry a damp stain, and each facet keeps its own value.
		var above := clampf(midpoint.y/maxf(height,0.01),0.0,1.0)
		var value := 1.0+0.07*normal.y*weathering
		value += (rng.randf()-0.5)*0.16*weathering
		value -= (1.0-smoothstep(0.0,0.3,above))*0.22*weathering
		value = clampf(value,0.62,1.15)
		for vertex in vertices:
			tool.set_normal(normal)
			tool.set_color(Color(value,value,value))
			tool.add_vertex(vertex)
	return tool.commit()

## A once-subdivided icosahedron: 42 shared points, 80 faces.
static func _icosphere() -> Array:
	var phi := (1.0+sqrt(5.0))/2.0
	var points: Array[Vector3] = [Vector3(-1,phi,0),Vector3(1,phi,0),Vector3(-1,-phi,0),Vector3(1,-phi,0),Vector3(0,-1,phi),Vector3(0,1,phi),Vector3(0,-1,-phi),Vector3(0,1,-phi),Vector3(phi,0,-1),Vector3(phi,0,1),Vector3(-phi,0,-1),Vector3(-phi,0,1)]
	for i in range(points.size()): points[i] = points[i].normalized()
	var base := [0,11,5,0,5,1,0,1,7,0,7,10,0,10,11,1,5,9,5,11,4,11,10,2,10,7,6,7,1,8,3,9,4,3,4,2,3,2,6,3,6,8,3,8,9,4,9,5,2,4,11,6,2,10,8,6,7,9,8,1]
	var middles := {}
	var faces := PackedInt32Array()
	for f in range(0,base.size(),3):
		var a: int = base[f]
		var b: int = base[f+1]
		var c: int = base[f+2]
		var ab := _middle(points,middles,a,b)
		var bc := _middle(points,middles,b,c)
		var ca := _middle(points,middles,c,a)
		faces.append_array([a,ab,ca,b,bc,ab,c,ca,bc,ab,bc,ca])
	return [points,faces]

static func _middle(points: Array[Vector3], middles: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a,b),maxi(a,b))
	if not middles.has(key):
		middles[key] = points.size()
		points.append(((points[a]+points[b])*0.5).normalized())
	return middles[key]
