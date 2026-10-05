extends RefCounted
## The earth sides of an island with an outline (scripts/island_outline.gd):
## a wall hung under every shore edge, from the land's own edge down to
## NativeTerrainData.SLAB_BASE, and a flat floor under the land there. It
## stands in for the square plate's authored sides (NativeChunkEditor
## `skirt_mesh_for` returns it), in the same mesh and material, so the strata
## (scripts/strata.gd) and the mist toward the foot paint it as they paint the
## square's sides: each vertex carries its rim top in UV (the earth-sides
## switch in shaders/reference_surface.gdshader).
##
## Each shore point hangs a ring a little under the rim, stood out from the
## land by a seeded amount, so the wall breaks into facets as the authored
## sides do instead of running down as one sheet. The floor is flat for now.

## The facet ring: how far under the rim (m), and how far out it stands (m).
const RING_DROP := Vector2(0.55,1.5)
const RING_OUT := Vector2(0.02,0.2)

## The wall and floor for `data`'s outline in the earth sides' own space:
## `placing` takes that space to the terrain's (NativeChunkEditor's skirt
## placing; translation only). Empty without an outline.
static func build(data: NativeTerrainData, placing: Transform3D, material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if data.outline.is_empty(): return mesh
	var into := placing.affine_inverse()
	var lift := into.origin.y
	var points := data.points
	var heights := data.heights
	var edges := data.shore_edges
	var outward := _outward(points,edges)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var base := NativeTerrainData.SLAB_BASE
	for k in range(0,edges.size(),3):
		var a := edges[k]
		var b := edges[k+1]
		var pa := points[a]
		var pb := points[b]
		var out: Vector2 = (outward[a]+outward[b]).normalized()
		var top_a := Vector3(pa.x,heights[a],pa.y)
		var top_b := Vector3(pb.x,heights[b],pb.y)
		var ring_a := _ring(a,top_a,outward[a])
		var ring_b := _ring(b,top_b,outward[b])
		var foot_a := Vector3(pa.x,base,pa.y)
		var foot_b := Vector3(pb.x,base,pb.y)
		var face := Vector3(out.x,0.0,out.y)
		var ha := heights[a]
		var hb := heights[b]
		_add(vertices,uvs,into,[top_a,top_b,ring_b],face,[ha,hb,hb],lift)
		_add(vertices,uvs,into,[top_a,ring_b,ring_a],face,[ha,hb,ha],lift)
		_add(vertices,uvs,into,[ring_a,ring_b,foot_b],face,[ha,hb,hb],lift)
		_add(vertices,uvs,into,[ring_a,foot_b,foot_a],face,[ha,hb,ha],lift)
	# The floor: every land face again at the base, facing down.
	var ids := data.vertex_ids
	for f in range(data.outline.size()):
		if data.outline[f] != 0: continue
		var a := points[ids[f*3]]
		var b := points[ids[f*3+1]]
		var c := points[ids[f*3+2]]
		_add(vertices,uvs,into,[Vector3(a.x,base,a.y),Vector3(b.x,base,b.y),Vector3(c.x,base,c.y)],Vector3.DOWN,[],lift)
	if vertices.is_empty(): return mesh
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3): normals[i+j] = normal
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,material)
	return mesh

## A triangle into the soup, wound to face `face` (the terrain's frame), in
## the sides' own space. `tops` are the rim heights over its corners (the
## terrain's frame); none for the floor, which reads `earth_sides_top`.
static func _add(vertices: PackedVector3Array, uvs: PackedVector2Array, into: Transform3D, tri: Array, face: Vector3, tops: Array, lift: float) -> void:
	var a: Vector3 = tri[0]
	var b: Vector3 = tri[1]
	var c: Vector3 = tri[2]
	var order := [0,1,2]
	# The shader's front: (c-a)×(b-a), as the terrain's own faces.
	if (c-a).cross(b-a).dot(face) < 0.0: order = [0,2,1]
	for j: int in order:
		vertices.append(into*(tri[j] as Vector3))
		uvs.append(Vector2(float(tops[j])+lift,1.0) if not tops.is_empty() else Vector2.ZERO)

## The facet ring's point under shore point `i`: under its top, stood out.
static func _ring(i: int, top: Vector3, out: Vector2) -> Vector3:
	var drop := lerpf(RING_DROP.x,RING_DROP.y,_hash(i,3))
	var reach := lerpf(RING_OUT.x,RING_OUT.y,_hash(i,7))
	return Vector3(top.x+out.x*reach,maxf(top.y-drop,NativeTerrainData.SLAB_BASE+0.5),top.z+out.y*reach)

## Each shore point's way out from the land: the mean of its shore edges'
## outward normals (away from the land face's third corner).
static func _outward(points: PackedVector2Array, edges: PackedInt32Array) -> Dictionary:
	var sums := {}
	for k in range(0,edges.size(),3):
		var a := points[edges[k]]
		var b := points[edges[k+1]]
		var c := points[edges[k+2]]
		var along := (b-a).normalized()
		var normal := Vector2(along.y,-along.x)
		if normal.dot(a-c) < 0.0: normal = -normal
		for i in [edges[k],edges[k+1]]: sums[i] = sums.get(i,Vector2.ZERO)+normal
	for i in sums: sums[i] = (sums[i] as Vector2).normalized()
	return sums

static func _hash(i: int, salt: int) -> float:
	return float(hash([i,salt,"shore"])%10000)/10000.0
