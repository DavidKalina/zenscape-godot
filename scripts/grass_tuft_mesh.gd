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
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := [0.0]
	var taper := [FAR_WIDTH]
	_clump(surface, rng, root, tip, LITE_BLADES, Vector2.ZERO, 1.0, rows, taper, LITE_WIDTH)
	var turn := rng.randf() * TAU
	for satellite: Array in LITE_SATELLITES:
		turn += rng.randf_range(2.0, 3.6)
		_clump(surface, rng, root, tip, int(satellite[0]), Vector2.from_angle(turn) * float(satellite[1]), float(satellite[2]), rows, taper, LITE_WIDTH)
	surface.index()
	var mesh := surface.commit()
	mesh.set_meta("grass_root", root)
	mesh.set_meta("grass_tip", tip)
	return mesh

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

static func _vertex(surface: SurfaceTool, point: Vector3, uv: Vector2, color: Color) -> void:
	surface.set_color(color)
	surface.set_uv(uv)
	surface.set_uv2(Vector2.ZERO)
	surface.set_normal(Vector3.UP)
	surface.add_vertex(point)
