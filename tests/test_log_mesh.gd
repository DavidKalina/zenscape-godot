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
	check(tris > 150 and tris < 400, "Triangle budget under 500 (got %d)" % tris)
	var bounds := mesh.get_aabb()
	var old_bounds := old_mesh.get_aabb()
	print("bounds ", bounds, " source ", old_bounds)
	check(absf(bounds.size.x - 1.0) < 0.08 and absf(bounds.position.x + 0.5) < 0.05, "Spans the unit length along X like the source")
	check(bounds.size.z > old_bounds.size.z * 0.7 and bounds.size.z < old_bounds.size.z * 1.25, "Girth across Z close to the source")
	check(bounds.position.y > old_bounds.position.y - 0.03 and bounds.position.y < old_bounds.position.y + 0.03, "Underside as deep as the source's")
	check(bounds.end.y > 0.17 and bounds.end.y < old_bounds.end.y + 0.05, "Top (moss, stubs) no taller than the source's stub")
	var moss := LogMesh.moss_mesh()
	var moss_tris := LogMesh.triangle_count(moss)
	print("moss triangles: ", moss_tris, " total ", tris + moss_tris)
	check(tris + moss_tris < 550, "Bark and moss together stay under 550 triangles (got %d)" % (tris + moss_tris))
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	check(vertices.size() == colours.size() and vertices.size() == normals.size(), "Colour and normal per vertex")
	var pale := 0
	for c in colours:
		if c.r > 0.35 and c.r > c.b * 1.6: pale += 1
	var dark_ring := 0
	for c in colours:
		if absf(c.r - LogMesh.WOOD_RING.r) < 0.08 and c.r > 0.2 and c.b < 0.16: dark_ring += 1
	check(pale >= 60, "Pale end grain and cut stubs are present (got %d)" % pale)
	check(dark_ring >= 24, "Dark end-grain rings are present (got %d)" % dark_ring)
	# Round outline: the cross-section's radii at mid-length differ little.
	var mid: Array[float] = []
	for v in vertices:
		if absf(v.x) < 0.04 and v.y < 0.12:
			mid.append(Vector2(v.y - LogMesh._centre(v.x).x, v.z - LogMesh._centre(v.x).y).length())
	mid.sort()
	check(mid.size() >= 12 and mid[mid.size() - 1] / mid[0] < 1.22, "Round cross-section (radius ratio %.2f)" % (mid[mid.size() - 1] / mid[0]))
	var finite := true
	for i in range(vertices.size()):
		if not vertices[i].is_finite() or absf(normals[i].length() - 1.0) > 0.01: finite = false
	check(finite, "Finite vertices and unit normals")
	# Moss: many small clumps along the top, on its own grass-look material.
	var moss_arrays := moss.surface_get_arrays(0)
	var mv: PackedVector3Array = moss_arrays[Mesh.ARRAY_VERTEX]
	var muv: PackedVector2Array = moss_arrays[Mesh.ARRAY_TEX_UV]
	var low := INF
	var high := -INF
	var top := 0
	var tallest := 0.0
	var covered := {}
	for i in range(mv.size()):
		low = minf(low, mv[i].x)
		high = maxf(high, mv[i].x)
		if mv[i].y > 0.05: top += 1
		var axis := LogMesh._axis(mv[i].x)
		var radial := Vector3(0.0, mv[i].y - axis.y, mv[i].z - axis.z)
		var theta := atan2(radial.y, radial.z)
		tallest = maxf(tallest, radial.length() - LogMesh._radius(mv[i].x, theta))
		if absf(theta - PI * 0.5) < 0.45: covered[int(floor((mv[i].x + 0.5) * 16.0))] = true
	check(high - low > 0.7, "Moss runs along most of the log")
	check(top > mv.size() / 2, "Most moss is on the upper side")
	check(tallest < 0.05, "Nothing in the moss stands tall (%.3f above the bark)" % tallest)
	check(covered.size() >= 14, "The mat covers the top along its length (%d of 16 bins)" % covered.size())
	var material := moss.surface_get_material(0) as ShaderMaterial
	check(material != null and material.get_shader_parameter("grass_blades") == true, "Moss wears the grass_blades look")
	check(moss.has_meta("grass_root") and moss.has_meta("grass_tip"), "Moss carries its gradient for the shader to divide out")
	# The catalogue draws both parts and the log stays one asset.
	check(NativeAssetCatalog.PARTS["log"] == ["logs", "log-moss"], "log has bark and moss parts")
	check(NativeAssetCatalog.PARTS["log"][0] == "logs", "The first part is still the bark (collision and pivot read it)")
	var holder: Node3D = Node3D.new()
	var node := NativeAssetCatalog.source_node(holder, "log-moss")
	check(node is MeshInstance3D and node.mesh == moss, "The catalogue builds the moss node")
	check(NativeAssetCatalog.part_pose("log:log-moss", node, node.mesh) == Transform3D.IDENTITY, "The moss shares the log's transform")
	holder.free()
	# Swap: the log's node is replaced, keeping its material; others untouched.
	var swapped := LogMesh.swap("logs", old_mesh)
	check(swapped != old_mesh and LogMesh.triangle_count(swapped) == tris, "logs swaps to the new mesh")
	check(swapped.surface_get_material(0) == old_mesh.surface_get_material(0), "The source material is kept")
	check(LogMesh.swap("stumps", old_mesh) == old_mesh and LogMesh.swap("mesh-10", old_mesh) == old_mesh, "Other meshes are left alone")
	check(LogMesh.log_mesh() == mesh, "Built once and cached")
	source.free()
	print("log mesh test ", "passed" if failures == 0 else "FAILED")
	quit(1 if failures > 0 else 0)
