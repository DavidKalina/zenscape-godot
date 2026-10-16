extends RigidBody3D
## A load the plane's hitch drags (scripts/interactables/plane_hitch.gd): a
## crate or a boulder, a real rigid body on the turf. Greybox: plain planks
## and a faceted rock, sized and weighed by `kind` (KINDS). The hitch ties
## on where the pilot stands when he clips it (`tie_point`): a crate on the
## face toward him, low; a boulder round its middle.

## kind: size (m: a crate's edge, a boulder's radius), mass (kg), friction.
## Against the pilot's pull (PlaneHitch.PULL, 1800 N) and the winch's
## (PlaneHitch.CRANK_STALL, 6000 N), with friction about mass x 9.8 x mu:
## the small crate is light work, the big crate and small boulder a lean,
## the middle boulder too much by hand but the winch's, the big one neither.
const KINDS := {
	"crate_small":{"size":0.8,"mass":35.0,"friction":0.6},
	"crate_big":{"size":1.2,"mass":110.0,"friction":0.6},
	"boulder_small":{"size":0.45,"mass":150.0,"friction":0.7},
	"boulder_mid":{"size":0.65,"mass":380.0,"friction":0.75},
	"boulder_big":{"size":1.1,"mass":1800.0,"friction":0.8},
}
const WOOD := Color("7a5a3a")
const STONE := Color("615c55")
const TURF_LAYER := 1 << 11

var kind := ""
var size := 1.0
var home := Transform3D.IDENTITY
var _hull := PackedVector3Array()

func setup(load_kind: String, at: Vector3, yaw: float, seed_value: int) -> void:
	kind = load_kind
	var spec: Dictionary = KINDS[kind]
	size = float(spec.size)
	mass = float(spec.mass)
	name = "Load_"+kind
	collision_layer = 1
	collision_mask = 1|TURF_LAYER
	continuous_cd = true
	can_sleep = true
	var stuff := PhysicsMaterial.new()
	stuff.friction = float(spec.friction)
	stuff.rough = true
	physics_material_override = stuff
	angular_damp = 0.6
	var shape := CollisionShape3D.new()
	var mesh := MeshInstance3D.new()
	if kind.begins_with("crate"):
		var box := BoxShape3D.new()
		box.size = Vector3.ONE*size
		shape.shape = box
		mesh.mesh = _crate_mesh(size,seed_value)
		home = Transform3D(Basis(Vector3.UP,yaw),at+Vector3.UP*(size*0.5+0.02))
	else:
		_hull = _rock_points(size,seed_value)
		var hull := ConvexPolygonShape3D.new()
		hull.points = _hull
		shape.shape = hull
		mesh.mesh = _rock_mesh(_hull)
		home = Transform3D(Basis(Vector3.UP,yaw),at+Vector3.UP*(size*0.8))
	add_child(shape)
	add_child(mesh)
	transform = home

## Back where it started, still (lost off the isle).
func reset_home() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = home

## Where the line ties on, in its own frame, for a hand at `hand` (world).
func tie_point(hand: Vector3) -> Vector3:
	var local := to_local(hand)
	if kind.begins_with("crate"):
		# The face toward him (of the four sides), a quarter up from its foot.
		var h := size*0.5
		var down := to_local(global_position+Vector3.DOWN)-to_local(global_position)
		var best := Vector3.ZERO
		var most := -INF
		for face: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK,Vector3.UP,Vector3.DOWN]:
			if absf(face.dot(down.normalized())) > 0.7: continue
			var score := face.dot(local.normalized())
			if score > most:
				most = score
				best = face
		return best*h+down.normalized()*h*0.5
	# Round a boulder's middle, toward him.
	var flat := local
	flat.y = 0.0
	if flat.length() < 0.01: flat = Vector3.FORWARD
	return flat.normalized()*size*0.85

## A box of planks: six faces, each banded into boards of a few tones.
static func _crate_mesh(edge: float, seed_value: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var h := edge*0.5
	var boards := 4
	for axis: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
		var u := axis.cross(Vector3.UP if absf(axis.y) < 0.5 else Vector3.RIGHT).normalized()
		var v := axis.cross(u).normalized()
		for b in range(boards):
			var v0 := -h+edge*float(b)/boards
			var v1 := -h+edge*float(b+1)/boards-0.01
			var tone := WOOD.darkened(rng.randf_range(0.0,0.3)).lerp(Color("8a8070"),rng.randf_range(0.0,0.25))
			var c := axis*h
			var p0 := c+u*-h+v*v0
			var p1 := c+u*h+v*v0
			var p2 := c+u*h+v*v1
			var p3 := c+u*-h+v*v1
			for p: Vector3 in [p0,p1,p2,p0,p2,p3]:
				st.set_color(tone)
				st.set_normal(axis)
				st.add_vertex(p)
		# A dark batten across each face.
		var bat := WOOD.darkened(0.45)
		var c2 := axis*(h+0.012)
		for p: Vector3 in [c2+u*-h+v*-0.05,c2+u*h+v*-0.05,c2+u*h+v*0.05,c2+u*-h+v*-0.05,c2+u*h+v*0.05,c2+u*-h+v*0.05]:
			st.set_color(bat)
			st.set_normal(axis)
			st.add_vertex(p)
	var mesh := st.commit()
	mesh.surface_set_material(0,_material())
	return mesh

## A lumpy rock's points: an icosahedron's twelve and its edges' middles,
## pushed in and out, a little flattened.
static func _rock_points(r: float, seed_value: int) -> PackedVector3Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 5
	var verts: PackedVector3Array = sphere.get_mesh_arrays()[Mesh.ARRAY_VERTEX]
	var seen := {}
	var out := PackedVector3Array()
	for p: Vector3 in verts:
		var key := Vector3i((p*100.0).round())
		if seen.has(key): continue
		seen[key] = true
		var q := p.normalized()*r*rng.randf_range(0.78,1.12)
		q.y *= 0.78
		out.append(q)
	return out

## Its hull drawn flat-shaded in weathered stone tones.
static func _rock_mesh(points: PackedVector3Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = points.size()
	var tris := _hull_tris(points)
	for i in range(0,tris.size(),3):
		var a := tris[i]
		var b := tris[i+1]
		var c := tris[i+2]
		var n := (b-a).cross(c-a).normalized()
		if n.dot((a+b+c)/3.0) < 0.0:
			var t := b
			b = c
			c = t
			n = -n
		# Weathered: tones vary face to face, lichen on the tops, darker under.
		var tone := STONE.darkened(rng.randf_range(0.0,0.25)).lerp(Color("5d6446"),rng.randf_range(0.15,0.45) if n.y > 0.45 else 0.0)
		if n.y < -0.3: tone = tone.darkened(0.25)
		# Godot's front faces wind clockwise seen from outside.
		for p: Vector3 in [a,c,b]:
			st.set_color(tone)
			st.set_normal(n)
			st.add_vertex(p)
	var mesh := st.commit()
	mesh.surface_set_material(0,_material())
	return mesh

## A brute-force hull's triangles (a few dozen points): every triple whose
## plane has all the points on one side.
static func _hull_tris(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := points.size()
	var seen := {}
	for i in range(n):
		for j in range(i+1,n):
			for k in range(j+1,n):
				var a := points[i]
				var b := points[j]
				var c := points[k]
				var nrm := (b-a).cross(c-a)
				if nrm.length() < 1e-6: continue
				nrm = nrm.normalized()
				var above := 0
				var below := 0
				for m in range(n):
					if m == i or m == j or m == k: continue
					var d := nrm.dot(points[m]-a)
					if d > 1e-4: above += 1
					elif d < -1e-4: below += 1
					if above > 0 and below > 0: break
				if above > 0 and below > 0: continue
				var key := "%d,%d,%d" % [i,j,k]
				if seen.has(key): continue
				seen[key] = true
				out.append_array([a,b,c])
	return out

static var _shared: StandardMaterial3D
static func _material() -> StandardMaterial3D:
	if _shared == null:
		_shared = StandardMaterial3D.new()
		_shared.vertex_color_use_as_albedo = true
		_shared.roughness = 1.0
	return _shared
