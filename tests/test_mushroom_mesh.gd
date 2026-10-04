extends SceneTree
## The redesigned mushroom (scripts/mushroom_mesh.gd): a small cluster of two
## to four separate mushrooms, a modest triangle budget, bounds near the old
## lone mushroom's, and the baked fungus parts swap to it keeping their material.

const Mushroom := preload("res://scripts/mushroom_mesh.gd")
const BUDGET := 300
var failures := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		print("FAIL: ", message)
		push_error("FAIL: "+message)

func _run() -> void:
	var stems := Mushroom.mesh("fungus-stems")
	var caps := Mushroom.mesh("fungus-caps")
	var total := Mushroom.triangle_count(stems) + Mushroom.triangle_count(caps)
	print("mushroom triangles: stems ", Mushroom.triangle_count(stems), " caps ", Mushroom.triangle_count(caps), " total ", total)
	check(Mushroom.triangle_count(stems) > 0 and Mushroom.triangle_count(caps) > 0, "both parts have triangles")
	check(total <= BUDGET, "the cluster stays under %d triangles (%d)" % [BUDGET, total])
	var pieces := Mushroom.piece_count()
	check(pieces >= 2 and pieces <= 4, "the cluster holds 2 to 4 mushrooms (%d)" % pieces)
	check(Mushroom.mesh("fungus-caps") == caps, "meshes are built once and cached")
	var box := stems.get_aabb().merge(caps.get_aabb())
	print("mushroom bounds ", box)
	check(box.size.x <= 0.34 and box.size.z <= 0.34, "footprint stays close to the old one (%.2f x %.2f)" % [box.size.x, box.size.z])
	check(box.position.y >= -0.02 and box.end.y > 0.15 and box.end.y <= 0.26, "stands from the soil to about the old height (%.2f to %.2f)" % [box.position.y, box.end.y])
	check(caps.get_aabb().position.y > stems.get_aabb().position.y, "caps sit above the stems' root")
	# Caps and stems break into the same number of separate pieces (each piece
	# is its own island of unshared vertices).
	check(_islands(stems) == pieces and _islands(caps) == pieces, "stems and caps each hold %d separate pieces (%d, %d)" % [pieces, _islands(stems), _islands(caps)])
	# The gills glow: UV2.x is lit on some cap vertices and never on the stems.
	check(_max_glow(caps) > 0.9 and _max_glow(stems) == 0.0, "only the caps carry gill light")
	var arrays := caps.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_TEX_UV] != null, "caps carry vertex colours and UVs")
	# The swap keeps the original material and ignores other parts.
	var original := ArrayMesh.new()
	original.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (PlaneMesh.new() as PlaneMesh).get_mesh_arrays())
	var material := ShaderMaterial.new()
	original.surface_set_material(0, material)
	var swapped := Mushroom.swap("fungus-caps", original)
	check(swapped != original and swapped.surface_get_material(0) == material, "fungus-caps swaps and keeps its material")
	check(Mushroom.swap("mesh-13", original) == original, "other parts are left alone")
	var tints := {}
	var dressed := ShaderMaterial.new()
	Mushroom.dress(dressed, "fungus-caps", tints, "mushroom:fungus-caps")
	check(float(dressed.get_shader_parameter("underglow")) > 0.0 and tints["mushroom:fungus-caps"] == Color.WHITE, "caps are dressed with gill light and a neutral tint")
	# The real baked parts swap in the catalog.
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	for node_name in Mushroom.PARTS:
		var baked: Mesh = source.get_node(node_name).multimesh.mesh
		var mesh := Mushroom.swap(node_name, baked)
		check(mesh != baked and mesh.surface_get_material(0) == baked.surface_get_material(0), "%s builds and swaps over the baked mesh" % node_name)
	source.free()
	print("PASS: mushroom mesh" if failures == 0 else "FAIL: mushroom mesh")
	quit(1 if failures else 0)

## Connected pieces by shared position.
func _islands(mesh: Mesh) -> int:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var parent := {}
	var find := func(key: Vector3i, find_ref: Callable) -> Vector3i:
		while parent[key] != key:
			parent[key] = parent[parent[key]]
			key = parent[key]
		return key
	var keys: Array[Vector3i] = []
	for v in vertices:
		var key := Vector3i((v * 10000.0).round())
		if not parent.has(key): parent[key] = key
		keys.append(key)
	for i in range(0, keys.size(), 3):
		for j in range(1, 3):
			var a: Vector3i = find.call(keys[i], find)
			var b: Vector3i = find.call(keys[i + j], find)
			if a != b: parent[a] = b
	var roots := {}
	for key in keys: roots[find.call(key, find)] = true
	return roots.size()

func _max_glow(mesh: Mesh) -> float:
	var uv2: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	var best := 0.0
	for uv in uv2: best = maxf(best, uv.x)
	return best
