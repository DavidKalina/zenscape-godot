extends RefCounted
## Flat-shaded meshes built from points, so every face reads as a cut
## facet: the plane (scripts/plane_figure.gd) and the people
## (scripts/person_kit.gd) are made of them. And the soft textures their
## streaks and marks are drawn with. The frustum, the gem and the soft
## textures came from the old glider's figure.

## A flat-shaded body along Z: `rings` of Vector3(z, half width, half
## height), `sides` faces round, capped at both ends.
static func hull(rings: Array, sides: int) -> ArrayMesh:
	var tris := []
	var ring_at := func(r: Vector3, i: int) -> Vector3:
		var a := TAU*(float(i)+0.5)/sides
		return Vector3(cos(a)*r.y,sin(a)*r.z,r.x)
	for k in range(rings.size()-1):
		var r0: Vector3 = rings[k]
		var r1: Vector3 = rings[k+1]
		var inside := Vector3(0.0,0.0,(r0.x+r1.x)*0.5)
		for i in range(sides):
			var a0: Vector3 = ring_at.call(r0,i)
			var a1: Vector3 = ring_at.call(r0,i+1)
			var b0: Vector3 = ring_at.call(r1,i)
			var b1: Vector3 = ring_at.call(r1,i+1)
			tris.append([a0,b0,b1,inside])
			tris.append([a0,b1,a1,inside])
	for end in [0,rings.size()-1]:
		var r: Vector3 = rings[end]
		var centre := Vector3(0.0,0.0,r.x)
		var inside := Vector3(0.0,0.0,r.x+(0.01 if end == 0 else -0.01))
		if r.y > 0.0001:
			for i in range(sides): tris.append([centre,ring_at.call(r,i),ring_at.call(r,i+1),inside])
	return shell(tris)

## Triangles [a, b, c, a point inside] as a flat-shaded mesh, each face
## wound and lit outward from its inside point.
static func shell(tris: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var n := -(b-a).cross(c-a)
		if n.length_squared() < 1e-12: continue
		n = n.normalized()
		if n.dot((a+b+c)/3.0-(t[3] as Vector3)) < 0.0:
			var swap := b
			b = c
			c = swap
			n = -n
		for v in [a,b,c]:
			vertices.append(v)
			normals.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

## A flat-shaded frustum along Y, `sides` faces round, centred.
static func frustum(bottom: float, top: float, height: float, sides: int) -> ArrayMesh:
	var tris := []
	for i in range(sides):
		var a0 := TAU*i/sides
		var a1 := TAU*(i+1)/sides
		var b0 := Vector3(cos(a0)*bottom,-height*0.5,sin(a0)*bottom)
		var b1 := Vector3(cos(a1)*bottom,-height*0.5,sin(a1)*bottom)
		var t0 := Vector3(cos(a0)*top,height*0.5,sin(a0)*top)
		var t1 := Vector3(cos(a1)*top,height*0.5,sin(a1)*top)
		tris.append([b0,t0,t1])
		tris.append([b0,t1,b1])
		tris.append([Vector3(0.0,height*0.5,0.0),t1,t0])
		tris.append([Vector3(0.0,-height*0.5,0.0),b0,b1])
	return faceted(tris)

## A small faceted gem (an octahedron, a little stretched) for a head or a
## rivet.
static func gem(r: float) -> ArrayMesh:
	var top := Vector3(0.0,r*1.15,0.0)
	var bottom := Vector3(0.0,-r,0.0)
	var ring := [Vector3(r,0.0,0.0),Vector3(0.0,0.0,r),Vector3(-r,0.0,0.0),Vector3(0.0,0.0,-r*1.1)]
	var tris := []
	for i in range(4):
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i+1)%4]
		tris.append([top,b,a])
		tris.append([bottom,a,b])
	return faceted(tris)

## Triangles (each an outward-wound [a, b, c]) as a flat-shaded mesh: every
## face takes its own normal, so it reads as cut facets.
static func faceted(tris: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		# Godot's front faces wind clockwise: the cross of the winding
		# points in, so the normal is its opposite.
		var n := -(b-a).cross(c-a).normalized()
		if n.dot((a+b+c)/3.0) < 0.0:
			var swap := b
			b = c
			c = swap
			n = -n
		for v in [a,b,c]:
			vertices.append(v)
			normals.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

## A soft band, clear at its edges, for a streak's width
## (the vapour, a wisp).
static func soft_band() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.5,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0.0),Color(1,1,1,1.0),Color(1,1,1,0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 1
	return texture

## A soft white ring with a faint centre, for a landing mark.
static func soft_ring() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.18,0.62,0.78,1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,0.55),Color(1,1,1,0.12),Color(1,1,1,0.3),Color(1,1,1,0.9),Color(1,1,1,0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1.0,0.5)
	texture.width = 128
	texture.height = 128
	return texture
