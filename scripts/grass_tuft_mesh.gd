extends RefCounted
## The soft tuft every tier draws, behind the source's `mesh-10` (the
## `grass_tuft` catalog part and the painted blades). The source tuft is six
## flat single triangles shaded facet by facet, which read as dark shards
## beside the soft flowers. This one keeps flat, cleanly cut blades (three
## planes each, a pointed tip) but is fuller and lower: ten broad blades
## fanned from the root, the inner standing tallest and the outer leaning
## furthest, so it reads as one rounded clump from the diorama camera (20-26
## m, where a 3 cm blade is about one pixel). The material turns on
## `grass_blades` in reference_surface.gdshader: soft mass light and the
## family's living green (shaders/grass_look.gdshaderinc), the root taking
## the ground's own colour (shaders/ground_look.gdshaderinc). The vertex
## colours are the source's (#38663a to #93c05f) and only carry each blade's
## jitter and any instance tint. UV.y is the height fraction up the blade.
## Two small satellite clumps of three blades stand beside it (SATELLITES),
## so a scatter of tufts reads as patches of field rather than lone plants.
## On by default since round three (docs/scenic/grass-look.md);
## `--classic-grass` draws the source tuft.
const BLADES := 10
const ROWS := [0.0, 0.42, 0.78]
const TAPER := [1.0, 0.88, 0.55]
## Root ring, height and outward lean, in metres. Each blade's place from the
## centre (0 inner, 1 outer) picks its root, height (inner tallest) and lean
## (outer furthest); the lean arcs by LEAN_CURVE up the blade.
const ROOT_RING := Vector2(0.015, 0.09)
const HEIGHT := Vector2(0.2, 0.36)
const LEAN := Vector2(0.09, 0.22)
const LEAN_CURVE := 1.8
const HALF_WIDTH := 0.04
## Lightness jitter on each blade's tip, as the source's offsetHSL.
const TIP_JITTER := 0.04
## Small clumps round the main one, so a tuft reads as a patch of field, not
## a lone plant: [blades, distance from the centre (m), size] each, at
## angles drawn from the seed. Placement is untouched (no digest changes).
const SATELLITES := [[3, 0.27, 0.62], [3, 0.24, 0.55]]

static func enabled() -> bool:
	return not ("--classic-grass" in preload("res://scripts/launch_args.gd").user_args() or "--classic-grass" in OS.get_cmdline_args())

## The replacement for `mesh-10`, carrying the original's material and root
## and tip colours; any other mesh, or with `--classic-grass`, the original.
static func swap(node_name: String, original: Mesh) -> Mesh:
	if node_name != "mesh-10" or not enabled(): return original
	var arrays := original.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var root := Color("38663a").srgb_to_linear()
	var tip := Color("93c05f").srgb_to_linear()
	if colors.size() == vertices.size() and vertices.size() > 0:
		var low := INF
		var high := -INF
		for i in range(vertices.size()):
			if vertices[i].y < low:
				low = vertices[i].y
				root = colors[i]
			if vertices[i].y > high:
				high = vertices[i].y
				tip = colors[i]
	var mesh := build(root, tip)
	mesh.surface_set_material(0, original.surface_get_material(0))
	mesh.set_meta("grass_root", root)
	mesh.set_meta("grass_tip", tip)
	return mesh

## Material settings the soft tuft needs on its reference_surface
## material: smooth mass normals instead of flat facets, the grass look, and
## the mesh's own root and tip colours for the shader to divide out.
static func dress(material: Material, mesh: Mesh = null) -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null: return
	shader_material.set_shader_parameter("flat_faces", false)
	shader_material.set_shader_parameter("grass_blades", true)
	if mesh != null and mesh.has_meta("grass_root"):
		var root: Color = mesh.get_meta("grass_root")
		var tip: Color = mesh.get_meta("grass_tip")
		shader_material.set_shader_parameter("grass_source_root", Vector3(root.r, root.g, root.b))
		shader_material.set_shader_parameter("grass_source_tip", Vector3(tip.r, tip.g, tip.b))

## One line naming the tuft in use, for the startup grass log.
static func describe() -> String:
	return "soft tuft (%d blades, scripts/grass_tuft_mesh.gd; --classic-grass for the source tuft)" % blade_count() if enabled() else "classic source tuft (--classic-grass)"

## Blades in the whole clump: the main tuft and its satellites.
static func blade_count() -> int:
	var count := BLADES
	for satellite: Array in SATELLITES: count += int(satellite[0])
	return count

## The far tuft (KitFlora Site `lod`'s mid ring, seen from 40 m on): LITE_BLADES
## broad blades of one row each (a quad and its tip) and two small satellites,
## about a third of the full tuft's triangles, the same root, height, lean
## and UVs, so the same material lights it alike.
const LITE_BLADES := 7
const LITE_ROWS := [0.0, 0.55]
const LITE_TAPER := [1.0, 0.7]
const LITE_WIDTH := 1.7
const LITE_SATELLITES := [[2, 0.27, 0.62], [2, 0.24, 0.55]]

static func build_lite(root: Color, tip: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_clump(surface, rng, root, tip, LITE_BLADES, Vector2.ZERO, 1.0, LITE_ROWS, LITE_TAPER, LITE_WIDTH)
	var turn := rng.randf() * TAU
	for satellite: Array in LITE_SATELLITES:
		turn += rng.randf_range(2.0, 3.6)
		_clump(surface, rng, root, tip, int(satellite[0]), Vector2.from_angle(turn) * float(satellite[1]), float(satellite[2]), LITE_ROWS, LITE_TAPER, LITE_WIDTH)
	surface.index()
	var mesh := surface.commit()
	mesh.set_meta("grass_root", root)
	mesh.set_meta("grass_tip", tip)
	return mesh

## The lite tuft from far off (the endless grass's far ring past its far lod,
## scripts/endless/endless_grass.gd): the same blades, roots, heights and
## leans, each one triangle (root edge to tip, FAR_WIDTH wider at the root so
## it covers as much), a third of the lite tuft's triangles and 3/5 of its
## vertices. Opt-in: nothing else draws it.
const FAR_WIDTH := 1.25

static func build_far(root: Color, tip: Color) -> ArrayMesh:
	return _build_tier(root, tip, 1)

## The far tuft from farther still (the endless grass's far ring past its
## second far lod): only the SPARSE_KEEP blades of the main clump and of each
## satellite, each SPARSE_WIDTH wider at the root so the tuft covers as much:
## 5 triangles for build_far's 11. build_far and build_lite_morph carry, in
## CUSTOM1.xyz, each vertex's way from build_far's shape to this one (a kept
## blade widening, the others closing onto their roots), so a shader that
## adds it all (endless_tuft_far `far_morph2`) draws these triangles and the
## swap changes no pixel. Opt-in: nothing else draws it.
const SPARSE_KEEP := [0, 2, 5]
const SPARSE_KEEP_SATELLITE := [0]
const SPARSE_WIDTH := 2.0
const SPARSE_WIDTH_SATELLITE := 1.7

static func build_sparse(root: Color, tip: Color) -> ArrayMesh:
	return _build_tier(root, tip, 2)

## The lite tuft carrying, in CUSTOM0.xyz, each vertex's way to build_far's
## shape (the blade's root corners FAR_WIDTH out, its middle row onto the
## straight edge root to tip): a shader that adds it all (shaders/
## endless_tuft_far.gdshader `far_morph`) draws build_far's triangles, so
## the two swap with no pixel changed. Opt-in: nothing else draws it.
static func build_lite_morph(root: Color, tip: Color) -> ArrayMesh:
	return _build_tier(root, tip, 0)

## The far ring's tuft at `tier`: 0 the lite tuft with its ways on, 1
## build_far's, 2 build_sparse's. The same blades from the same seed.
static func _build_tier(root: Color, tip: Color, tier: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A vertex carries only what its tier reads (a channel a mesh lacks reads
	# as zero): the far ring is millions of vertices a frame, and its cost
	# follows the bytes each one fetches.
	if tier == 0: surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	if tier <= 1: surface.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_HALF)
	_clump_morph(surface, rng, root, tip, LITE_BLADES, Vector2.ZERO, 1.0, tier, SPARSE_KEEP, SPARSE_WIDTH)
	var turn := rng.randf() * TAU
	for satellite: Array in LITE_SATELLITES:
		turn += rng.randf_range(2.0, 3.6)
		_clump_morph(surface, rng, root, tip, int(satellite[0]), Vector2.from_angle(turn) * float(satellite[1]), float(satellite[2]), tier, SPARSE_KEEP_SATELLITE, SPARSE_WIDTH_SATELLITE)
	surface.index()
	var mesh := compressed(surface.commit())
	mesh.set_meta("grass_root", root)
	mesh.set_meta("grass_tip", tip)
	return mesh

## `mesh` (one surface) in Godot's compressed vertex: 16-bit places in the
## tuft's box and 16-bit UVs, 12 bytes a vertex fewer, its custom channels
## kept. (It wants a tangent, which no grass material reads.) For the endless
## grass's tufts, drawn by the million vertices: their cost on the GPU
## follows the bytes a vertex fetches.
static func compressed(mesh: ArrayMesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var tangents := PackedFloat32Array()
	for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(): tangents.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 1.0]))
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var ways := mesh.surface_get_format(0) & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT | Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, ways | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	return out

## `_clump` at the lite tuft's rows, each vertex with its way to build_far's
## (CUSTOM0) and on to build_sparse's (CUSTOM1); `tier` 1 or 2: that shape
## itself, a triangle a blade (2: the `keep` blades only, `widen` wider).
static func _clump_morph(surface: SurfaceTool, rng: RandomNumberGenerator, root: Color, tip: Color, blades: int, at: Vector2, size: float, tier := 0, keep: Array = [], widen := 1.0) -> void:
	for blade in range(blades):
		var angle := (float(blade) / blades) * TAU + rng.randf() * 0.9
		var out := Vector2.from_angle(angle)
		var ring := clampf((0.25 if blade % 2 == 0 else 0.8) + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
		var base := at + out * lerpf(ROOT_RING.x, ROOT_RING.y, ring) * size
		var height := lerpf(HEIGHT.y, HEIGHT.x, ring) * rng.randf_range(0.88, 1.08) * size
		var lean := lerpf(LEAN.x, LEAN.y, ring) * rng.randf_range(0.85, 1.15) * size
		var side := Vector2(-out.y, out.x) * HALF_WIDTH * LITE_WIDTH * rng.randf_range(0.85, 1.15) * lerpf(1.0, size, 0.5)
		var blade_tip := tip.lightened(rng.randf_range(0.0, TIP_JITTER)) if rng.randf() < 0.5 else tip.darkened(rng.randf_range(0.0, TIP_JITTER))
		var top := _point(base, out, height, lean, 1.0)
		var c0 := _point(base, out, height, lean, 0.0)
		var far_half := side * FAR_WIDTH
		var far_l := c0 - Vector3(far_half.x, 0.0, far_half.y)
		var far_r := c0 + Vector3(far_half.x, 0.0, far_half.y)
		# The sparse tuft's blade: a kept one wider at the root, the others
		# closed onto their roots.
		var kept := keep.has(blade)
		var sparse_l := c0 - Vector3(far_half.x, 0.0, far_half.y) * widen if kept else c0
		var sparse_r := c0 + Vector3(far_half.x, 0.0, far_half.y) * widen if kept else c0
		var sparse_top := top if kept else c0
		if tier == 2:
			if not kept: continue
			_vertex(surface, sparse_l, Vector2(0.0, 0.0), root, false)
			_vertex(surface, sparse_r, Vector2(1.0, 0.0), root, false)
			_vertex(surface, top, Vector2(0.5, 1.0), blade_tip, false)
			continue
		if tier == 1:
			_vertex_morph(surface, far_l, Vector2(0.0, 0.0), root, far_l, sparse_l, false)
			_vertex_morph(surface, far_r, Vector2(1.0, 0.0), root, far_r, sparse_r, false)
			_vertex_morph(surface, top, Vector2(0.5, 1.0), blade_tip, top, sparse_top, false)
			continue
		var strip := []
		for k in range(LITE_ROWS.size()):
			var t: float = LITE_ROWS[k]
			var centre := _point(base, out, height, lean, t)
			var half: Vector2 = side * float(LITE_TAPER[k])
			strip.append([centre - Vector3(half.x, 0.0, half.y), centre + Vector3(half.x, 0.0, half.y), t, far_l.lerp(top, t), far_r.lerp(top, t), sparse_l.lerp(sparse_top, t), sparse_r.lerp(sparse_top, t)])
		var a: Array = strip[0]
		var b: Array = strip[1]
		for corner in [[a[0], 0.0, a[2], a[3], a[5]], [a[1], 1.0, a[2], a[4], a[6]], [b[0], 0.0, b[2], b[3], b[5]], [a[1], 1.0, a[2], a[4], a[6]], [b[1], 1.0, b[2], b[4], b[6]], [b[0], 0.0, b[2], b[3], b[5]]]:
			_vertex_morph(surface, corner[0], Vector2(corner[1], corner[2]), root.lerp(blade_tip, corner[2]), corner[3], corner[4])
		_vertex_morph(surface, b[0], Vector2(0.0, b[2]), root.lerp(blade_tip, b[2]), b[3], b[5])
		_vertex_morph(surface, b[1], Vector2(1.0, b[2]), root.lerp(blade_tip, b[2]), b[4], b[6])
		_vertex_morph(surface, top, Vector2(0.5, 1.0), blade_tip, top, sparse_top)

## A vertex at `point` with its way to `goal` (build_far's shape) in CUSTOM0
## and from there on to `sparse` (build_sparse's) in CUSTOM1.
static func _vertex_morph(surface: SurfaceTool, point: Vector3, uv: Vector2, color: Color, goal: Vector3, sparse: Vector3, first := true) -> void:
	var way := goal - point
	var on := sparse - goal
	if first: surface.set_custom(0, Color(way.x, way.y, way.z, 0.0))
	surface.set_custom(1, Color(on.x, on.y, on.z, 0.0))
	_vertex(surface, point, uv, color, false)

static func build(root: Color, tip: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_clump(surface, rng, root, tip, BLADES, Vector2.ZERO, 1.0)
	var turn := rng.randf() * TAU
	for satellite: Array in SATELLITES:
		turn += rng.randf_range(2.0, 3.6)
		_clump(surface, rng, root, tip, int(satellite[0]), Vector2.from_angle(turn) * float(satellite[1]), float(satellite[2]))
	surface.index()
	return surface.commit()

## One clump of `blades` fanned round `at`, scaled by `size`.
static func _clump(surface: SurfaceTool, rng: RandomNumberGenerator, root: Color, tip: Color, blades: int, at: Vector2, size: float, rows: Array = ROWS, taper: Array = TAPER, width := 1.0) -> void:
	for blade in range(blades):
		var angle := (float(blade) / blades) * TAU + rng.randf() * 0.9
		var out := Vector2.from_angle(angle)
		# Alternate inner and outer blades, jittered, so the mound fills.
		var ring := clampf((0.25 if blade % 2 == 0 else 0.8) + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
		var base := at + out * lerpf(ROOT_RING.x, ROOT_RING.y, ring) * size
		var height := lerpf(HEIGHT.y, HEIGHT.x, ring) * rng.randf_range(0.88, 1.08) * size
		var lean := lerpf(LEAN.x, LEAN.y, ring) * rng.randf_range(0.85, 1.15) * size
		var side := Vector2(-out.y, out.x) * HALF_WIDTH * width * rng.randf_range(0.85, 1.15) * lerpf(1.0, size, 0.5)
		var blade_tip := tip.lightened(rng.randf_range(0.0, TIP_JITTER)) if rng.randf() < 0.5 else tip.darkened(rng.randf_range(0.0, TIP_JITTER))
		var strip := []
		for k in range(rows.size()):
			var t: float = rows[k]
			var centre := _point(base, out, height, lean, t)
			var half: Vector2 = side * float(taper[k])
			strip.append([centre - Vector3(half.x, 0.0, half.y), centre + Vector3(half.x, 0.0, half.y), t])
		for k in range(rows.size() - 1):
			var a: Array = strip[k]
			var b: Array = strip[k + 1]
			for corner in [[a[0], 0.0, a[2]], [a[1], 1.0, a[2]], [b[0], 0.0, b[2]], [a[1], 1.0, a[2]], [b[1], 1.0, b[2]], [b[0], 0.0, b[2]]]:
				_vertex(surface, corner[0], Vector2(corner[1], corner[2]), root.lerp(blade_tip, corner[2]))
		var last: Array = strip[rows.size() - 1]
		_vertex(surface, last[0], Vector2(0.0, last[2]), root.lerp(blade_tip, last[2]))
		_vertex(surface, last[1], Vector2(1.0, last[2]), root.lerp(blade_tip, last[2]))
		_vertex(surface, _point(base, out, height, lean, 1.0), Vector2(0.5, 1.0), blade_tip)

## A blade's centre line: rising, arcing outward, and dropping a little as it
## lies over so its length holds.
static func _point(base: Vector2, out: Vector2, height: float, lean: float, t: float) -> Vector3:
	var reach := lean * pow(t, LEAN_CURVE)
	var p := base + out * reach
	return Vector3(p.x, height * t - reach * reach / (2.0 * height), p.y)

## (`uv2` false: no second UV on the vertex, for a material that reads none.)
static func _vertex(surface: SurfaceTool, point: Vector3, uv: Vector2, color: Color, uv2 := true) -> void:
	surface.set_color(color)
	surface.set_uv(uv)
	if uv2: surface.set_uv2(Vector2.ZERO)
	surface.set_normal(Vector3.UP)
	surface.add_vertex(point)
