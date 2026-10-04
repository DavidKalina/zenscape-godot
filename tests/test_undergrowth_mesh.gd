extends SceneTree
## The fern and the shrub (scripts/undergrowth_mesh.gd): both build as one
## indexed surface within a modest triangle budget, stay near the old
## footprints (fern about 1.7 m across and 0.55 m high; shrub 0.7 x 0.3 m),
## the fern is closed at its centre (no hole), the shrub is many separate
## small leaves, and both ride the catalog under their old names. Headless:
## no shader is compiled here.

const Undergrowth := preload("res://scripts/undergrowth_mesh.gd")
const Redwood := preload("res://scripts/redwood_assets.gd")
const Catalog := preload("res://scripts/native_asset_catalog.gd")

var failures := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		print("FAIL: ", message)
		push_error("FAIL: " + message)

func _run() -> void:
	_fern()
	_shrub()
	_wiring()
	print("Undergrowth: ", failures, " failures")
	quit(1 if failures else 0)

func _valid(mesh: ArrayMesh, label: String) -> void:
	check(mesh.get_surface_count() == 1, label + " is one surface")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	check(indices.size() > 0 and indices.size() % 3 == 0, label + " is indexed triangles")
	var in_range := true
	for i in indices: in_range = in_range and i >= 0 and i < vertices.size()
	check(in_range, label + " indices point at vertices")
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var along_ok := uvs.size() == vertices.size()
	for uv in uvs: along_ok = along_ok and uv.y >= 0.0 and uv.y <= 1.0
	check(along_ok, label + " carries a 0..1 'along' in UV.y for the grass look")
	check(arrays[Mesh.ARRAY_COLOR] != null, label + " has vertex colours")
	check(mesh.has_meta("grass_root") and mesh.has_meta("grass_tip"), label + " carries its gradient for the shader")

func _fern() -> void:
	var mesh := Undergrowth.fern()
	_valid(mesh, "The fern")
	var triangles := Undergrowth.triangle_count(mesh)
	check(triangles >= 120 and triangles <= 400, "The fern stays under 400 triangles (%d)" % triangles)
	var box := mesh.get_aabb()
	check(box.size.x >= 1.0 and box.size.x <= 1.9 and box.size.z >= 1.0 and box.size.z <= 1.9, "The fern spans about the old 1.7 m: %.2f x %.2f m" % [box.size.x, box.size.z])
	check(box.size.y >= 0.35 and box.size.y <= 0.65 and box.position.y > -0.05, "The fern is the old height and stands on its root: %.2f m" % box.size.y)
	# A closed centre: leaf triangles right over the crown, at a couple of heights.
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var central := 0
	var rings := {}
	for t in range(indices.size() / 3):
		var centroid := (vertices[indices[t * 3]] + vertices[indices[t * 3 + 1]] + vertices[indices[t * 3 + 2]]) / 3.0
		var flat := Vector2(centroid.x, centroid.z)
		if flat.length() < 0.14: central += 1
		if flat.length() < 0.2: rings[int((flat.angle() + PI) / TAU * 6.0)] = true
	check(central >= 12, "Geometry fills the fern's centre, no hole: %d triangles within 14 cm" % central)
	check(rings.size() >= 5, "The centre is covered all round, in %d of 6 sectors" % rings.size())
	# Not a perfect star: the fronds' reach differs round the clump.
	var reach: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for v in vertices:
		var s := int((Vector2(v.x, v.z).angle() + PI) / TAU * 8.0) % 8
		reach[s] = maxf(reach[s], Vector2(v.x, v.z).length())
	check(reach.size() == 8 and (reach.max() - reach.min()) > 0.12, "The fern is not rotationally even: reach %.2f to %.2f m" % [reach.min(), reach.max()])
	# Leaflets are attached wedges, not slivers: no triangle is needle-thin.
	var slivers := 0
	for t in range(indices.size() / 3):
		var p0 := vertices[indices[t * 3]]
		var p1 := vertices[indices[t * 3 + 1]]
		var p2 := vertices[indices[t * 3 + 2]]
		var longest := maxf(p0.distance_to(p1), maxf(p1.distance_to(p2), p2.distance_to(p0)))
		var area := (p1 - p0).cross(p2 - p0).length() * 0.5
		if area < 0.02 * longest * longest: slivers += 1
	check(slivers <= 2, "The fern has no needle-thin slivers: %d" % slivers)
	# Fresh, light colour: no dark tips (the brightest vertices are the highest-reaching ones).
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var dark_tip := false
	for i in range(vertices.size()):
		if Vector2(vertices[i].x, vertices[i].z).length() > 0.5 and colors[i].g < 0.2: dark_tip = true
	check(not dark_tip, "No dark tips on the outer fronds")

func _shrub() -> void:
	var mesh := Undergrowth.shrub()
	_valid(mesh, "The shrub")
	var triangles := Undergrowth.triangle_count(mesh)
	check(triangles >= 200 and triangles <= 600, "The shrub stays under 600 triangles (%d)" % triangles)
	var box := mesh.get_aabb()
	# The old bush: 0.69 x 0.30 x 0.71 m, rooted at y = 0.
	check(box.size.x >= 0.55 and box.size.x <= 0.95 and box.size.z >= 0.55 and box.size.z <= 0.95, "The shrub keeps the old footprint: %.2f x %.2f m" % [box.size.x, box.size.z])
	check(box.size.y >= 0.24 and box.size.y <= 0.42 and box.position.y > -0.05, "The shrub keeps the old height: %.2f m" % box.size.y)
	check(absf(box.get_center().x) < 0.12 and absf(box.get_center().z) < 0.12, "The shrub is centred on its root (the pose pivots on the base)")
	# Many separate pieces: every leaf owns its vertices (no shared edges to the next).
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var parent := {}
	for i in range(vertices.size()): parent[i] = i
	for t in range(indices.size() / 3):
		for k in range(1, 3):
			var a := _root(parent, indices[t * 3])
			var b := _root(parent, indices[t * 3 + k])
			if a != b: parent[a] = b
	var pieces := {}
	for i in range(vertices.size()): pieces[_root(parent, i)] = true
	check(pieces.size() >= 100, "The shrub is many small leaves, not lumps: %d separate pieces" % pieces.size())
	check(triangles / maxi(pieces.size(), 1) <= 3, "Each piece is a small leaf (about %d triangles each)" % (triangles / maxi(pieces.size(), 1)))
	# Airy: a patch of the plan view is empty, so the darker inside shows.
	var cells := {}
	for t in range(indices.size() / 3):
		var centroid := (vertices[indices[t * 3]] + vertices[indices[t * 3 + 1]] + vertices[indices[t * 3 + 2]]) / 3.0
		cells[Vector2i(floori(centroid.x / 0.06), floori(centroid.z / 0.06))] = true
	var disc := 0
	var covered := 0
	for x in range(-8, 8):
		for z in range(-8, 8):
			if Vector2((x + 0.5) * 0.06, (z + 0.5) * 0.06).length() < 0.27:
				disc += 1
				if cells.has(Vector2i(x, z)): covered += 1
	check(covered < disc and float(covered) / disc > 0.45, "Gaps show within a full canopy: %d of %d cells hold a leaf centre" % [covered, disc])

func _root(parent: Dictionary, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i

func _wiring() -> void:
	check(Catalog.PARTS.fern == ["redwood-fern"] and Catalog.PARTS.shrub == ["mesh-13"], "Both keep their catalog names and parts")
	var fern := Redwood.mesh("redwood-fern")
	check(fern == Undergrowth.fern(), "redwood-fern is the new fern")
	var material := fern.surface_get_material(0) as ShaderMaterial
	check(material != null and material.get_shader_parameter("grass_blades") == true and material.get_shader_parameter("flat_faces") == false, "The fern is dressed for the grass look")
	check(material.get_shader_parameter("sway_enabled") == true, "The fern keeps its sway")
	var baked := ArrayMesh.new()
	var material2 := ShaderMaterial.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _tri())
	baked.surface_set_material(0, material2)
	check(Undergrowth.swap("mesh-9", baked) == baked, "Other meshes are left alone")
	var swapped := Undergrowth.swap("mesh-13", baked)
	check(swapped != baked and swapped.surface_get_material(0) == material2 and swapped.has_meta("grass_root"), "mesh-13 swaps to the new bush, keeping the source material")
	Undergrowth.dress(material2, swapped)
	check(material2.get_shader_parameter("grass_blades") == true, "The shrub material is dressed for the grass look")

func _tri() -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	return arrays
