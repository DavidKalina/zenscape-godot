extends Node3D
## One frozen atlas chunk (scripts/chunk_atlas.gd): a stored document drawn at
## its offset from the live chunk, with its terrain, its earth block walled on
## outer borders only, and its plants, props and ponds through a GardenView of
## its own. Nothing here edits; making a chunk live loads its document into
## the editor instead.

var slot := Vector2i.ZERO
var data: NativeTerrainData
## The document this view was built from, to skip rebuilding an unchanged one.
var document_hash := 0
var terrain: MeshInstance3D
var skirt: MeshInstance3D
var content: GardenView

## `skirt_source` is the authored earth block and `skirt_offset` where it sits
## relative to the terrain. `open_sides` are borders that face another chunk.
func build(document: Dictionary, source_mesh: ArrayMesh, terrain_material: Material, skirt_source: ArrayMesh, skirt_offset: Vector3, open_sides: Dictionary) -> bool:
	data = NativeTerrainData.new()
	data.setup(source_mesh)
	if not data.load_document(document): return false
	document_hash = hash(document.get("heights"))
	terrain = MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = data.play_mesh(data.build_mesh())
	if terrain_material != null: terrain.material_override = terrain_material
	add_child(terrain)
	skirt = MeshInstance3D.new()
	skirt.name = "Skirt"
	skirt.position = skirt_offset
	skirt.mesh = cut_sides(lift_skirt(skirt_source,skirt_offset,data),skirt_offset,open_sides)
	add_child(skirt)
	content = GardenView.new()
	content.name = "Garden"
	content.data = data
	content.plain_water_worker = false
	content.recipe_stream_worker = false
	add_child(content)
	# Its _process drives landscape foam and mist from the owning scene; a
	# frozen chunk's water stays still.
	content.set_process(false)
	content.rebuild(true)
	return true

func set_open_sides(skirt_source: ArrayMesh, skirt_offset: Vector3, open_sides: Dictionary) -> void:
	skirt.mesh = cut_sides(lift_skirt(skirt_source,skirt_offset,data),skirt_offset,open_sides)

## The earth block's top follows the rim, as NativeChunkEditor._rebuild_skirt
## does for the live chunk.
static func lift_skirt(source: ArrayMesh, skirt_offset: Vector3, terrain_data: NativeTerrainData) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var low := source.get_aabb().position.y
	var high := source.get_aabb().end.y
	var half: float = preload("res://scripts/chunk_atlas.gd").HALF
	for i in range(vertices.size()):
		var local := vertices[i]+skirt_offset
		var point := Vector2(local.x,local.z).clamp(Vector2(-half,-half),Vector2(half,half))
		vertices[i].y += terrain_data.delta_at(point)*clampf((vertices[i].y-low)/(high-low),0.0,1.0)
	for i in range(0,vertices.size(),3):
		var normal := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		for j in range(3): normals[i+j] = normal
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,source.surface_get_material(0))
	return mesh

## Drops the earth block's faces beyond each open border, so two chunks meet
## as one ground with no wall between them. A face belongs to the side its
## centre lies furthest out on.
static func cut_sides(mesh: ArrayMesh, skirt_offset: Vector3, open_sides: Dictionary) -> ArrayMesh:
	if open_sides.is_empty(): return mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var keep_vertices := PackedVector3Array()
	var keep_normals := PackedVector3Array()
	var extra := {}
	for key in [Mesh.ARRAY_TEX_UV,Mesh.ARRAY_COLOR,Mesh.ARRAY_TANGENT]:
		if arrays[key] != null: extra[key] = []
	var edge: float = preload("res://scripts/chunk_atlas.gd").HALF-0.1
	for i in range(0,vertices.size(),3):
		var center := (vertices[i]+vertices[i+1]+vertices[i+2])/3.0+skirt_offset
		if maxf(absf(center.x),absf(center.z)) > edge:
			var side := ("e" if center.x > 0.0 else "w") if absf(center.x) >= absf(center.z) else ("s" if center.z > 0.0 else "n")
			if open_sides.has(side): continue
		for j in range(3):
			keep_vertices.append(vertices[i+j])
			keep_normals.append(normals[i+j])
			for key in extra:
				if key == Mesh.ARRAY_TANGENT:
					for k in range(4): extra[key].append(arrays[key][(i+j)*4+k])
				else: extra[key].append(arrays[key][i+j])
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = keep_vertices
	result[Mesh.ARRAY_NORMAL] = keep_normals
	if extra.has(Mesh.ARRAY_TEX_UV): result[Mesh.ARRAY_TEX_UV] = PackedVector2Array(extra[Mesh.ARRAY_TEX_UV])
	if extra.has(Mesh.ARRAY_COLOR): result[Mesh.ARRAY_COLOR] = PackedColorArray(extra[Mesh.ARRAY_COLOR])
	if extra.has(Mesh.ARRAY_TANGENT): result[Mesh.ARRAY_TANGENT] = PackedFloat32Array(extra[Mesh.ARRAY_TANGENT])
	var cut := ArrayMesh.new()
	cut.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result)
	cut.surface_set_material(0,mesh.surface_get_material(0))
	return cut
