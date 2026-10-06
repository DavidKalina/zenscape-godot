extends RefCounted
## Flat-shaded meshes built from points, so every face reads as a cut
## facet: the plane (scripts/plane_figure.gd) and the people
## (scripts/person_kit.gd) are made of them.

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
