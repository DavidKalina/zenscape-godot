extends RefCounted
## The painterly grass tuft every tier draws, behind the source's `mesh-10`
## (the `grass_tuft` catalog part and the painted blades). The source tuft is
## six flat single triangles; this one fans more blades out from the root,
## each a tapered strip that arcs outward and lies over toward its tip, in the
## source's own root-to-tip colours (#38663a to #93c05f, as the mesh carries
## them). The material turns on `grass_blades` in reference_surface.gdshader
## for the shared look (shaders/grass_look.gdshaderinc). UV.y is the height
## fraction up the blade. `--classic-grass` keeps the source tuft.
const BLADES := 7
const ROWS := [0.0, 0.4, 0.75]
const TAPER := [1.0, 0.78, 0.45]
## The source's ranges (foliage.js grassTuftGeometry): root ring, height and
## outward lean, in metres; the lean arcs by LEAN_CURVE up the blade.
const ROOT_RING := Vector2(0.03, 0.08)
const HEIGHT := Vector2(0.2, 0.42)
const LEAN := Vector2(0.08, 0.22)
const LEAN_CURVE := 1.8
const HALF_WIDTH := 0.028
## Lightness jitter on each blade's tip, as the source's offsetHSL.
const TIP_JITTER := 0.04

static func enabled() -> bool:
	return not ("--classic-grass" in OS.get_cmdline_user_args() or "--classic-grass" in OS.get_cmdline_args())

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
	return mesh

## Material settings the painterly tuft needs on its reference_surface
## material: smooth mass normals instead of flat facets, and the grass look.
static func dress(material: Material) -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null: return
	shader_material.set_shader_parameter("flat_faces", false)
	shader_material.set_shader_parameter("grass_blades", true)

static func build(root: Color, tip: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(BLADES):
		var angle := (float(blade) / BLADES) * TAU + rng.randf() * 0.9
		var out := Vector2.from_angle(angle)
		var base := out * rng.randf_range(ROOT_RING.x, ROOT_RING.y)
		var height := rng.randf_range(HEIGHT.x, HEIGHT.y)
		var lean := rng.randf_range(LEAN.x, LEAN.y)
		var side := Vector2(-out.y, out.x) * HALF_WIDTH * rng.randf_range(0.85, 1.15)
		var blade_tip := tip.lightened(rng.randf_range(0.0, TIP_JITTER)) if rng.randf() < 0.5 else tip.darkened(rng.randf_range(0.0, TIP_JITTER))
		var strip := []
		for k in range(ROWS.size()):
			var t: float = ROWS[k]
			var centre := _point(base, out, height, lean, t)
			var half: Vector2 = side * float(TAPER[k])
			strip.append([centre - Vector3(half.x, 0.0, half.y), centre + Vector3(half.x, 0.0, half.y), t])
		for k in range(ROWS.size() - 1):
			var a: Array = strip[k]
			var b: Array = strip[k + 1]
			for corner in [[a[0], 0.0, a[2]], [a[1], 1.0, a[2]], [b[0], 0.0, b[2]], [a[1], 1.0, a[2]], [b[1], 1.0, b[2]], [b[0], 0.0, b[2]]]:
				_vertex(surface, corner[0], Vector2(corner[1], corner[2]), root.lerp(blade_tip, corner[2]))
		var last: Array = strip[ROWS.size() - 1]
		_vertex(surface, last[0], Vector2(0.0, last[2]), root.lerp(blade_tip, last[2]))
		_vertex(surface, last[1], Vector2(1.0, last[2]), root.lerp(blade_tip, last[2]))
		_vertex(surface, _point(base, out, height, lean, 1.0), Vector2(0.5, 1.0), blade_tip)
	surface.index()
	return surface.commit()

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
