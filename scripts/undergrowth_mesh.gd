extends RefCounted
## The fern and the shrub, built in the grass tuft's manner (grass_tuft_mesh.gd,
## docs/scenic/grass-look.md) so the three read as one family of soft ground
## plants. Both are indexed meshes with UV.y as the "along" fraction that the
## `grass_blades` mode of reference_surface.gdshader reads: dark and blended
## into the ground at the root, sunlit and lifted at the tips, the meadow's
## living green, a soft dome normal in place of facet shading, and the
## breeze's bow and wave sheen. Vertex colours are a gentle root-to-tip
## gradient with a little lightness jitter per piece (the tuft's tip jitter);
## the shader divides the mesh's own gradient out (grass_source_root/tip, set
## by `dress`), so an instance tint and the jitter survive. The silhouette
## stays cut from flat triangles; only the light is soft.
##
## Fern (asset "fern", part "redwood-fern"): an upright, arching clump of
## pinnate fronds rising from one closed crown. A few short upright new
## fronds stand in the middle and longer ones arch out and down. Counts,
## angles, lengths and lean are jittered, leaflets taper to a point, and the
## colour lightens toward the tips; no dark tips and no hole at the centre.
##
## Shrub (asset "shrub", part "mesh-13"): a low rounded bush of about a
## hundred and fifty small folded leaves on short sprigs fanned from the
## root, so the silhouette is irregular and airy, with gaps onto a darker
## interior and lighter leaf tips on the outside.
const FERN_ROOT := Color("447a40")
const FERN_TIP := Color("a6d27a")
## The tuft's own source gradient, which the fern's gradient sits lighter than.
const GRASS_ROOT := Color("38663a")
const GRASS_TIP := Color("93c05f")
## The colour the baked shrub instances carry (native_flora.gd SHRUB).
const SHRUB_TINT := Color("5c7a3e")
## How dark the inside of the bush is against its sunlit leaf tips.
const SHRUB_ROOT_SHADE := 0.74
const SPRIGS := 18
const LEAVES_MIN := 7
const LEAVES_MAX := 10
## Height of the old bush, which "how far up" is measured against.
const SHRUB_HEIGHT := 0.3

static var _cache := {}

static func fern() -> ArrayMesh:
	if not _cache.has("fern"):
		var mesh := _build_fern()
		mesh.set_meta("grass_root", GRASS_ROOT.srgb_to_linear())
		mesh.set_meta("grass_tip", GRASS_TIP.srgb_to_linear())
		_cache["fern"] = mesh
	return _cache["fern"]

static func shrub() -> ArrayMesh:
	if not _cache.has("shrub"):
		var mesh := _build_shrub()
		var tint := SHRUB_TINT.srgb_to_linear()
		mesh.set_meta("grass_root", Color(tint.r, tint.g, tint.b) * SHRUB_ROOT_SHADE)
		mesh.set_meta("grass_tip", Color(tint.r, tint.g, tint.b))
		_cache["shrub"] = mesh
	return _cache["shrub"]

## The baked shrub (`mesh-13`) swaps to the new bush, keeping its material;
## any other mesh is left alone.
static func swap(node_name: String, original: Mesh) -> Mesh:
	if node_name != "mesh-13": return original
	var source := shrub()
	var mesh := source.duplicate() as ArrayMesh
	for meta in source.get_meta_list(): mesh.set_meta(meta, source.get_meta(meta))
	mesh.surface_set_material(0, original.surface_get_material(0))
	return mesh

## The grass look on a reference_surface material, with the mesh's own root
## and tip colours for the shader to divide out.
static func dress(material: Material, mesh: Mesh) -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null: return
	shader_material.set_shader_parameter("flat_faces", false)
	shader_material.set_shader_parameter("grass_blades", true)
	# Leaves cover the whole plant, so only its very root takes the ground's colour.
	shader_material.set_shader_parameter("grass_root_blend", Vector2(0.6, 0.3))
	if mesh != null and mesh.has_meta("grass_root"):
		var root: Color = mesh.get_meta("grass_root")
		var tip: Color = mesh.get_meta("grass_tip")
		shader_material.set_shader_parameter("grass_source_root", Vector3(root.r, root.g, root.b))
		shader_material.set_shader_parameter("grass_source_tip", Vector3(tip.r, tip.g, tip.b))

static func triangle_count(mesh: Mesh) -> int:
	var indices: PackedInt32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	return indices.size() / 3

# --- fern ---------------------------------------------------------------

static func _build_fern() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Outer fronds fan with uneven gaps (a walk of jittered steps, not an even
	# ring), long and low; inner ones stand short and upright, so the crown is
	# closed and the clump reads as a plant from above, not a star.
	var outer := 9
	var angle := rng.randf() * TAU
	for i in range(outer):
		angle += TAU / outer * rng.randf_range(0.55, 1.45)
		_frond(surface, rng, angle, rng.randf_range(0.5, 0.82), rng.randf_range(0.0, 0.35), rng.randf_range(0.8, 1.05))
	for i in range(5):
		angle += rng.randf_range(1.0, 2.2)
		_frond(surface, rng, angle, rng.randf_range(0.26, 0.42), rng.randf_range(0.55, 1.0), rng.randf_range(0.85, 1.1))
	surface.index()
	return surface.commit()

## One pinnate frond from the crown. `upright` (0 arching, 1 standing) sets
## how steeply it leaves the crown and how little it falls back.
static func _frond(surface: SurfaceTool, rng: RandomNumberGenerator, angle: float, length: float, upright: float, width: float) -> void:
	var steps := 6
	var out := Vector3(cos(angle), 0.0, sin(angle))
	var across := Vector3(-out.z, 0.0, out.x)
	var pitch := lerpf(deg_to_rad(52.0), deg_to_rad(78.0), upright) + rng.randf_range(-0.1, 0.1)
	var bend := lerpf(deg_to_rad(105.0), deg_to_rad(35.0), upright) * rng.randf_range(0.85, 1.15)
	var sway := rng.randf_range(-0.12, 0.12)
	var spine: Array[Vector3] = [out * 0.012]
	for k in range(steps):
		var t := float(k) / steps
		var p := pitch - bend * t * t
		var step_dir := (out * cos(p) + Vector3.UP * sin(p) + across * sway * t).normalized()
		spine.append(spine[k] + step_dir * (length / steps))
	var lift := rng.randf_range(0.0, 0.05)
	for k in range(steps):
		var t0 := float(k) / steps
		var t1 := float(k + 1) / steps
		var a := spine[k]
		var b := spine[k + 1]
		# Leaflets are widest a third of the way up and taper to the tip; each
		# pair sweeps forward and lifts a little, so a frond is a shallow V.
		var reach := width * 0.17 * sin(PI * clampf(0.12 + 0.88 * t1, 0.0, 1.0)) * (1.0 - 0.25 * t1)
		var forward := (b - a).normalized() * 0.5 * length / steps
		for sign in [-1.0, 1.0]:
			var tilt: Vector3 = across * sign * reach + Vector3.UP * reach * (0.38 - 0.5 * t1)
			var leaflet: Vector3 = b + tilt + forward * rng.randf_range(0.6, 1.2)
			var jitter := rng.randf_range(-0.04, 0.04)
			_vertex(surface, a, _along(t0), FERN_ROOT, FERN_TIP, jitter)
			_vertex(surface, leaflet, _along(minf(t1 + 0.1, 1.0)), FERN_ROOT, FERN_TIP, jitter + lift)
			_vertex(surface, b, _along(t1), FERN_ROOT, FERN_TIP, jitter)
	# The pointed tip of the rachis.
	var last := spine[steps]
	var end := last + (spine[steps] - spine[steps - 1]).normalized() * length / steps * 0.9
	var span := across * width * 0.02 * length
	_vertex(surface, last - span, _along(0.95), FERN_ROOT, FERN_TIP, 0.0)
	_vertex(surface, end + Vector3.DOWN * 0.02, 1.0, FERN_ROOT, FERN_TIP, lift)
	_vertex(surface, last + span, _along(0.95), FERN_ROOT, FERN_TIP, 0.0)

static func _along(t: float) -> float:
	return lerpf(0.1, 1.0, clampf(t, 0.0, 1.0))

# --- shrub --------------------------------------------------------------

static func _build_shrub() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1309
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var turn := rng.randf() * TAU
	for s in range(SPRIGS):
		# Golden-angle fan with jitter; the first sprigs stand tall in the
		# middle and the later ones lean out low, so the heap is a dome.
		turn += 2.39996 + rng.randf_range(-0.35, 0.35)
		var rank := float(s) / (SPRIGS - 1)
		var out := Vector3(cos(turn), 0.0, sin(turn))
		var elevation := lerpf(deg_to_rad(82.0), deg_to_rad(20.0), pow(rank, 0.7)) + rng.randf_range(-0.1, 0.1)
		var length := lerpf(0.31, 0.27, rank) * rng.randf_range(0.85, 1.15)
		var base := out * rng.randf_range(0.0, 0.04)
		var leaves := rng.randi_range(LEAVES_MIN, LEAVES_MAX)
		for l in range(leaves):
			var t := (float(l) + 0.6) / leaves
			# The sprig droops a little toward its end.
			var at := base + out * cos(elevation) * length * t + Vector3.UP * (sin(elevation) * length * t - length * 0.1 * t * t)
			var yaw := (1.0 if l % 2 == 0 else -1.0) * rng.randf_range(0.5, 1.2) + rng.randf_range(-0.3, 0.3)
			var rise := rng.randf_range(0.0, 0.6)
			var dir := (out * cos(rise) + Vector3.UP * sin(rise)).rotated(Vector3.UP, yaw).normalized()
			var size := lerpf(0.075, 0.115, rng.randf()) * lerpf(0.8, 1.05, t)
			_leaf(surface, rng, at, dir, size, clampf(at.y / SHRUB_HEIGHT, 0.0, 1.0), t)
	surface.index()
	return surface.commit()

## One small folded leaf: a diamond whose side points sit off the line from
## base to tip, cut into two flat triangles. `height` is how far up the bush
## it sits and `outer` how far out along its sprig, together the leaf's place
## from the dark inside to the sunlit surface.
static func _leaf(surface: SurfaceTool, rng: RandomNumberGenerator, at: Vector3, dir: Vector3, size: float, height: float, outer: float) -> void:
	var right := dir.cross(Vector3.UP)
	if right.length() < 0.05: right = Vector3.RIGHT
	right = right.normalized()
	var normal := right.cross(dir).normalized()
	var half := size * 0.36
	var mid := at + dir * size * 0.45
	var fold := normal * size * 0.14
	var tip := at + dir * size + normal * size * rng.randf_range(-0.1, 0.12) - Vector3.UP * size * 0.12
	var interior := clampf(0.2 + 0.5 * height + 0.3 * outer, 0.1, 1.0)
	var tip_along := clampf(interior + 0.28, 0.0, 1.0)
	var jitter := rng.randf_range(-0.07, 0.07)
	var left_point := mid - right * half + fold
	var right_point := mid + right * half + fold
	_shade(surface, at, interior * 0.8, jitter)
	_shade(surface, left_point, interior, jitter)
	_shade(surface, right_point, interior, jitter)
	_shade(surface, left_point, interior, jitter)
	_shade(surface, tip, tip_along, jitter)
	_shade(surface, right_point, interior, jitter)

## A shrub vertex: a grey ratio (dark inside to 1.0 at the tips) that the
## shader reads against the gradient set by `dress`, so the instance tint
## supplies the hue.
static func _shade(surface: SurfaceTool, point: Vector3, along: float, jitter: float) -> void:
	var level := lerpf(SHRUB_ROOT_SHADE, 1.0, clampf(along, 0.0, 1.0)) * (1.0 + jitter)
	_emit(surface, point, along, Color(level, level, level))

## A fern vertex: the gradient at `along`, lightened or darkened by `jitter`.
static func _vertex(surface: SurfaceTool, point: Vector3, along: float, root: Color, tip: Color, jitter: float) -> void:
	var colour := root.lerp(tip, clampf(along, 0.0, 1.0))
	colour = colour.lightened(jitter) if jitter >= 0.0 else colour.darkened(-jitter)
	_emit(surface, point, along, colour.srgb_to_linear())

static func _emit(surface: SurfaceTool, point: Vector3, along: float, colour: Color) -> void:
	surface.set_color(colour)
	surface.set_uv(Vector2(0.5, clampf(along, 0.0, 1.0)))
	surface.set_uv2(Vector2.ZERO)
	surface.set_normal(Vector3.UP)
	surface.add_vertex(point)
