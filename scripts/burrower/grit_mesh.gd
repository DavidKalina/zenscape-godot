## Faceted, irregular earth meshes for the burrower: crumbs and clods (a low
## icosphere with each corner pushed in or out, flat normals). The soil shader
## (shaders/burrower_soil.gdshader) paints them gritty.
class_name GritMesh
extends RefCounted

## An irregular faceted lump of radius about 0.5. `rough` 0..1 how ragged.
static func lump(seed_: int, rough := 0.35, subdiv := 1) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var t := (1.0+sqrt(5.0))*0.5
	var v: Array = [Vector3(-1,t,0),Vector3(1,t,0),Vector3(-1,-t,0),Vector3(1,-t,0),
		Vector3(0,-1,t),Vector3(0,1,t),Vector3(0,-1,-t),Vector3(0,1,-t),
		Vector3(t,0,-1),Vector3(t,0,1),Vector3(-t,0,-1),Vector3(-t,0,1)]
	var f: Array = [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],
		[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	var pts: Array = []
	for p in v: pts.append((p as Vector3).normalized())
	var faces: Array = f
	for s in subdiv:
		var nf: Array = []
		var cache := {}
		for tri in faces:
			var m: Array = []
			for e in 3:
				var a: int = tri[e]
				var b: int = tri[(e+1)%3]
				var key := Vector2i(mini(a,b),maxi(a,b))
				if not cache.has(key):
					pts.append(((pts[a] as Vector3)+(pts[b] as Vector3)).normalized())
					cache[key] = pts.size()-1
				m.append(cache[key])
			nf.append([tri[0],m[0],m[2]])
			nf.append([tri[1],m[1],m[0]])
			nf.append([tri[2],m[2],m[1]])
			nf.append([m[0],m[1],m[2]])
		faces = nf
	# Each corner out or in, and the whole thing squashed a little.
	var sq := Vector3(rng.randf_range(0.8,1.15),rng.randf_range(0.7,1.0),rng.randf_range(0.8,1.15))
	var verts: Array = []
	for p in pts:
		verts.append((p as Vector3)*0.5*(1.0+rough*rng.randf_range(-1.0,0.7))*sq)
	return _flat(verts,faces)

static func _flat(verts: Array, faces: Array) -> ArrayMesh:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var col := PackedColorArray()
	for tri in faces:
		var a: Vector3 = verts[tri[0]]
		var b: Vector3 = verts[tri[1]]
		var c: Vector3 = verts[tri[2]]
		var n := (b-a).cross(c-a).normalized()
		# Wound so the normal points out from the middle (flip if not).
		var mid := (a+b+c)/3.0
		if n.dot(mid-Vector3(0,0.15,0)) < 0.0:
			n = -n
			var tmp := b
			b = c
			c = tmp
		for q in [a,b,c]:
			pos.append(q)
			nor.append(n)
			col.append(Color.WHITE)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_COLOR] = col
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
	return m
