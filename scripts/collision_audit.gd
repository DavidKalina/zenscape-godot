extends RefCounted
## The invisible-hitbox audit (docs/design/plane-ground-scale.md, "Opening
## ratio 1.0 + collision audit"): every collision shape the plane or the
## walker can hit, checked against what is drawn round it. A shape whose
## surface stands more than REACH m off anything drawn (and not inside it)
## is an invisible hitbox: the plane bumps, the walker stops, on air.
##
## How: every drawn mesh (stone, turf, rock; not the growth, the grass,
## the sky or the figures) is copied as a trimesh onto a layer of its own
## (SEEN_LAYER, masked by nothing in the game); then points over each
## collision shape's surface (a box's faces on a grid, a hull's corners, a
## trimesh's triangles' middles) ask: is drawn surface within REACH (a
## sphere query), or is the point inside drawn stone (a ray out along the
## surface's normal meets a drawn face from behind first)? Neither: the
## point is exposed. A shape with an exposed point is reported, with how
## far its worst point stands off (REACH, 1 m, 3 m, or past).
## tools/collision_audit.gd runs it over the game; tests/
## test_collision_audit.gd keeps it at none.

## How far a shape may stand off the drawn stone (m).
const REACH := 0.3
## The bands an exposed point is put in (how far off it stands).
const BANDS := [0.3,1.0,3.0]
## The audit's own layer: the drawn meshes' copies.
const SEEN_LAYER := 1 << 30
## The same, one-sided (front faces only): the inside test's second ray.
const FRONT_LAYER := 1 << 29
## The layers that count: the stone (1), the turf (12th), the ruins'
## bump layer (scripts/ruin_bump.gd) and the solid layers the sky's
## parts and the serpent stand on.
const LAYERS := 1|(1 << 11)|(1 << 3)|(1 << 4)|(1 << 5)
## A box face's grid (m between points, at most this many a side).
const GRID := 0.45
const GRID_MOST := 40
## A trimesh shape's triangles sampled at most.
const TRI_MOST := 4000
## Drawn meshes bigger than this (the sky, the cloud sea) are left out.
const DRAWN_MOST := 1500.0

var _space: PhysicsDirectSpaceState3D
var _seen: Array[StaticBody3D] = []
var _sphere := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
## Nodes whose meshes and shapes are left out (the plane, the walker).
var skip: Array[Node] = []

func _init(space: PhysicsDirectSpaceState3D) -> void:
	_space = space
	_sphere.collision_mask = SEEN_LAYER
	_sphere.margin = 0.0
	_ray.collision_mask = SEEN_LAYER
	_ray.hit_from_inside = false

## Copies every drawn mesh under `root` onto SEEN_LAYER (a body added to
## `holder`). Gives back the triangles copied.
func see(root: Node, holder: Node) -> int:
	var growth: Material = preload("res://scripts/ruin_growth.gd").material()
	var tris := 0
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or _skipped(mi): continue
		if not mi.is_visible_in_tree():
			_why("hidden: "+str(mi.get_path()).get_slice("/",3)+"/"+str(mi.get_path()).get_slice("/",4))
			continue
		if mi.get_aabb().get_longest_axis_size() > DRAWN_MOST:
			_why("huge")
			continue
		if mi.mesh is PrimitiveMesh and (mi.mesh as PrimitiveMesh).get_faces().is_empty(): continue
		var xf := mi.global_transform
		var body := StaticBody3D.new()
		body.collision_layer = SEEN_LAYER
		body.collision_mask = 0
		var front := StaticBody3D.new()
		front.collision_layer = FRONT_LAYER
		front.collision_mask = 0
		for s in range(mi.mesh.get_surface_count()):
			var material := mi.get_active_material(s)
			if material == growth:
				_why("growth")
				continue
			if material is ShaderMaterial and _soft((material as ShaderMaterial).shader):
				_why("soft shader: "+(material as ShaderMaterial).shader.resource_path+" "+str(mi.get_path()).get_slice("/",3)+"/"+str(mi.get_path()).get_slice("/",4))
				continue
			if material is BaseMaterial3D and (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				_why("transparent")
				continue
			var faces := _surface_faces(mi.mesh,s)
			if faces.size() < 3 or faces.size()%3 != 0:
				_why("no triangles: "+str(mi.get_path()).get_slice("/",3)+"/"+str(mi.get_path()).get_slice("/",4))
				continue
			var world := PackedVector3Array()
			world.resize(faces.size())
			for i in range(faces.size()): world[i] = xf*faces[i]
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(world)
			var holder_shape := CollisionShape3D.new()
			holder_shape.shape = shape
			body.add_child(holder_shape)
			var one := ConcavePolygonShape3D.new()
			one.set_faces(world)
			var one_holder := CollisionShape3D.new()
			one_holder.shape = one
			front.add_child(one_holder)
			tris += faces.size()/3
		if body.get_child_count() == 0:
			body.free()
			front.free()
			continue
		holder.add_child(body)
		holder.add_child(front)
		_seen.append(body)
		_seen.append(front)
	return tris

## Why drawn surfaces were left out, counted (a diagnostic).
var skipped := {}
func _why(reason: String) -> void:
	skipped[reason] = int(skipped.get(reason,0))+1

## A shader drawn soft (water, clouds, glow): not stone you can stand on.
static func _soft(shader: Shader) -> bool:
	if shader == null: return false
	var code := shader.code
	return code.contains("blend_add") or code.contains("ALPHA =") or code.contains("ALPHA=")

static func _surface_faces(mesh: Mesh, s: int) -> PackedVector3Array:
	var arrays: Array = []
	if mesh.has_meta("arrays") and s == 0: arrays = mesh.get_meta("arrays")
	else: arrays = mesh.surface_get_arrays(s)
	if arrays.is_empty(): return PackedVector3Array()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: Variant = arrays[Mesh.ARRAY_INDEX]
	if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
		var out := PackedVector3Array()
		out.resize((idx as PackedInt32Array).size())
		for i in range(out.size()): out[i] = v[(idx as PackedInt32Array)[i]]
		return out
	return v

func _skipped(node: Node) -> bool:
	for s in skip:
		if s == node or s.is_ancestor_of(node): return true
	return false

## Lets the drawn copies go.
func clear() -> void:
	for body in _seen:
		if is_instance_valid(body): body.queue_free()
	_seen.clear()

## Every collision shape under `root` on LAYERS (the drawn copies, Areas
## and `skip` left out), checked: [{path, layer, kind, box (world AABB),
## points, exposed, far (exposed 1 m or more), worst (m, the band it stood off past), at (the worst
## point)}] for each shape with an exposed point, worst first.
func audit(root: Node) -> Array:
	var found: Array = []
	for node in root.find_children("*","CollisionShape3D",true,false):
		var cs := node as CollisionShape3D
		if cs.disabled or cs.shape == null or _skipped(cs): continue
		var owner_body := cs.get_parent() as CollisionObject3D
		if owner_body == null or owner_body is Area3D or owner_body in _seen: continue
		if owner_body.collision_layer & LAYERS == 0: continue
		if not owner_body.is_inside_tree(): continue
		var samples := _samples(cs)
		var exposed := 0
		var far := 0
		var worst := 0.0
		var worst_at := Vector3.ZERO
		for sample: Array in samples:
			var off := _off(sample[0],sample[1])
			if off > 0.0:
				exposed += 1
				if off >= 1.0: far += 1
				if off > worst:
					worst = off
					worst_at = sample[0]
		if exposed == 0: continue
		found.append({"path":str(root.get_path_to(cs)),"layer":owner_body.collision_layer,"kind":cs.shape.get_class(),
			"box":_world_box(cs),"points":samples.size(),"exposed":exposed,"far":far,"worst":worst,"at":worst_at})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.worst)*float(a.exposed) > float(b.worst)*float(b.exposed))
	return found

## How far point `p` (outward `n`) stands off drawn surface: 0 near it
## (within REACH) or inside it; else the least band past which nothing
## drawn is found (BANDS), INF past them all.
func _off(p: Vector3, n: Vector3) -> float:
	if _near(p,REACH): return 0.0
	if _inside(p,n): return 0.0
	for k in range(1,BANDS.size()):
		if _near(p,float(BANDS[k])): return float(BANDS[k-1])
	return float(BANDS[BANDS.size()-1])

func _near(p: Vector3, r: float) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = r
	_sphere.shape = sphere
	_sphere.transform = Transform3D(Basis.IDENTITY,p)
	return not _space.intersect_shape(_sphere,1).is_empty()

## Inside drawn stone: straight up (or out along `n`) the first drawn face
## met is met from behind (a ray that meets back faces meets it nearer
## than one that meets only front faces).
func _inside(p: Vector3, n: Vector3) -> bool:
	for dir: Vector3 in [Vector3.UP,n]:
		if dir.length_squared() < 0.5: continue
		_ray.from = p
		_ray.to = p+dir*80.0
		_ray.hit_back_faces = true
		var any := _space.intersect_ray(_ray)
		if any.is_empty(): continue
		_ray.hit_back_faces = false
		_ray.collision_mask = FRONT_LAYER
		var front := _space.intersect_ray(_ray)
		_ray.collision_mask = SEEN_LAYER
		_ray.hit_back_faces = true
		if front.is_empty() or p.distance_to(front.position) > p.distance_to(any.position)+0.01: return true
	return false

## Points over the shape's surface in the world, with their outward
## normals: [[point, normal]].
func _samples(cs: CollisionShape3D) -> Array:
	var xf := cs.global_transform
	var out: Array = []
	var shape := cs.shape
	if shape is BoxShape3D:
		var h := (shape as BoxShape3D).size*0.5
		for axis in range(3):
			for sgn: float in [-1.0,1.0]:
				var u := (axis+1)%3
				var v := (axis+2)%3
				var nu := clampi(int(ceil(h[u]*2.0/GRID)),1,GRID_MOST)
				var nv := clampi(int(ceil(h[v]*2.0/GRID)),1,GRID_MOST)
				for i in range(nu+1):
					for j in range(nv+1):
						var q := Vector3.ZERO
						q[axis] = sgn*h[axis]
						q[u] = -h[u]+2.0*h[u]*i/nu
						q[v] = -h[v]+2.0*h[v]*j/nv
						var n := Vector3.ZERO
						n[axis] = sgn
						# Pulled a hair in, so an edge point is the face's.
						out.append([xf*(q*0.999),(xf.basis*n).normalized()])
	elif shape is ConvexPolygonShape3D:
		var pts := (shape as ConvexPolygonShape3D).points
		if pts.is_empty(): return out
		var mid := Vector3.ZERO
		for q in pts: mid += q
		mid /= pts.size()
		for q in pts: out.append([xf*(mid+(q-mid)*0.98),(xf.basis*(q-mid)).normalized()])
	elif shape is ConcavePolygonShape3D:
		var faces := (shape as ConcavePolygonShape3D).get_faces()
		var count := faces.size()/3
		var step := maxi(1,count/TRI_MOST)
		for t in range(0,count,step):
			var a := faces[t*3]
			var b := faces[t*3+1]
			var c := faces[t*3+2]
			var n := (c-a).cross(b-a)
			if n.length_squared() < 1e-10: continue
			out.append([xf*((a+b+c)/3.0),(xf.basis*n).normalized()])
	elif shape is CylinderShape3D or shape is CapsuleShape3D or shape is SphereShape3D:
		var r: float = shape.get("radius")
		var hh: float = float(shape.get("height"))*0.5 if shape.has_method("get_height") else r
		for k in range(12):
			var a := TAU*k/12.0
			var d := Vector3(cos(a),0.0,sin(a))
			for y: float in [-hh*0.9,0.0,hh*0.9]: out.append([xf*(d*r*0.99+Vector3.UP*y),(xf.basis*d).normalized()])
		out.append([xf*(Vector3.UP*hh*0.99),xf.basis*Vector3.UP])
	return out

static func _world_box(cs: CollisionShape3D) -> AABB:
	var debug := cs.shape.get_debug_mesh()
	if debug == null: return AABB(cs.global_position,Vector3.ZERO)
	return cs.global_transform*debug.get_aabb()

## One line for a found shape.
static func line(f: Dictionary) -> String:
	var box: AABB = f.box
	return "%-70s %-24s off>%.1f m  %d/%d pts  size %s  at %s" % [str(f.path).right(70),str(f.kind),float(f.worst),int(f.exposed),int(f.points),
		str(box.size.snapped(Vector3.ONE*0.1)),str((f.at as Vector3).snapped(Vector3.ONE*0.1))]
