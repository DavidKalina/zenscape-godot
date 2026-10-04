extends SceneTree
## The redesigned fallen log (scripts/log_mesh.gd): modest triangle budget,
## bounds close to the source log's (placement, collision and walkways depend
## on them), moss and grass present, bark faceted, and the baked `logs` mesh
## swaps for it while other meshes are left alone.
const LogMesh := preload("res://scripts/log_mesh.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var old_node: MultiMeshInstance3D = source.get_node("logs")
	var old_mesh: Mesh = old_node.multimesh.mesh
	var mesh := LogMesh.log_mesh()
	check(mesh.get_surface_count() == 1, "One surface, so the catalogue's single part draws it")
	var tris := LogMesh.triangle_count(mesh)
	print("log triangles: ", tris, " (source ", LogMesh.triangle_count(old_mesh), ")")
	check(tris > 150 and tris < 500, "Triangle budget under 500 (got %d)" % tris)
	var bounds := mesh.get_aabb()
	var old_bounds := old_mesh.get_aabb()
	print("bounds ", bounds, " source ", old_bounds)
	check(absf(bounds.size.x - 1.0) < 0.08 and absf(bounds.position.x + 0.5) < 0.05, "Spans the unit length along X like the source")
	check(bounds.size.z > old_bounds.size.z * 0.7 and bounds.size.z < old_bounds.size.z * 1.25, "Girth across Z close to the source")
	check(bounds.position.y > old_bounds.position.y - 0.03 and bounds.position.y < old_bounds.position.y + 0.03, "Underside as deep as the source's")
	check(bounds.end.y > 0.17 and bounds.end.y < old_bounds.end.y + 0.05, "Top (moss, stubs) no taller than the source's stub")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	check(vertices.size() == colours.size() and vertices.size() == normals.size(), "Colour and normal per vertex")
	var soft := LogMesh.soft_vertex_count(mesh)
	check(soft >= 60, "Moss and grass carry green vertex colour (got %d)" % soft)
	# Moss lies along the top, over the bark's upper half.
	var moss_top := -INF
	var moss_x_low := INF
	var moss_x_high := -INF
	var pale := 0
	for i in range(vertices.size()):
		var c := colours[i]
		if c.g > c.r * 1.2 and c.g > c.b * 1.3 and vertices[i].y > 0.05:
			moss_top = maxf(moss_top, vertices[i].y)
			moss_x_low = minf(moss_x_low, vertices[i].x)
			moss_x_high = maxf(moss_x_high, vertices[i].x)
		if c.r > 0.35 and c.r > c.b * 1.8: pale += 1
	check(moss_top > 0.1 and moss_x_high - moss_x_low > 0.5, "A moss strip runs along the upper side")
	check(pale >= 40, "Pale end grain and cut stubs are present (got %d)" % pale)
	var finite := true
	for i in range(vertices.size()):
		if not vertices[i].is_finite() or absf(normals[i].length() - 1.0) > 0.01: finite = false
	check(finite, "Finite vertices and unit normals")
	# Swap: the log's node is replaced, keeping its material; others untouched.
	var swapped := LogMesh.swap("logs", old_mesh)
	check(swapped != old_mesh and LogMesh.triangle_count(swapped) == tris, "logs swaps to the new mesh")
	check(swapped.surface_get_material(0) == old_mesh.surface_get_material(0), "The source material is kept")
	check(LogMesh.swap("stumps", old_mesh) == old_mesh and LogMesh.swap("mesh-10", old_mesh) == old_mesh, "Other meshes are left alone")
	var material := old_mesh.surface_get_material(0).duplicate()
	LogMesh.dress(material)
	check(material.get_shader_parameter("flat_faces") == false, "Dress turns derivative flat faces off for the soft moss")
	check(LogMesh.log_mesh() == mesh, "Built once and cached")
	source.free()
	print("log mesh test ", "passed" if failures == 0 else "FAILED")
	quit(1 if failures > 0 else 0)
