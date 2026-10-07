extends RefCounted
## The mushroom, redesigned (asset "mushroom", baked parts `fungus-stems` and
## `fungus-caps`): a small huddle of four, three standing and one bud, of
## different heights and lean, in the family of the grass tuft and the new
## fern and shrub (scripts/undergrowth_mesh.gd). The silhouette is faceted
## (eight-sided domes with uneven shoulders and a notched rim, six-sided
## stems that taper toward the cap) and the light is soft: UV.y is the along
## fraction, vertex colours run root to tip with a little per-piece jitter,
## and the gills under each cap glow faintly and warmly (`underglow` in
## reference_surface.gdshader, read from UV2.x), strongest by the stem and
## fading toward the rim. Stems are pale cream and darken toward the soil;
## caps are warm cream, tan and a muted red-brown, one to a mushroom, light
## enough that a cluster's own instance tint (native_flora.gd) still reads.
##
## One cluster per record, so the footprint stays close to the old lone
## mushroom's (a cap about 0.2 across, 0.2 tall). The stem and cap meshes
## are built from the same layout so each cap sits on its stem.
const PARTS := ["fungus-stems", "fungus-caps"]
const SIDES := 8
## Stems are six-sided, and only the tall one has a waist ring.
const STEM_SIDES := 6
## Strength of the gill light, a share of the cap's own colour.
const UNDERGLOW := 0.5
## The pilot brushing past tips the huddle about its foot, springing back
## past upright (reference_surface.gdshader `tread_wobble`): metres at the
## tallest cap's top per unit of the wake's lean, and that height.
const WOBBLE := 0.07
const WOBBLE_HEIGHT := 0.21
const STEM_ROOT := Color("b9a98c")
const STEM_TOP := Color("f0e8d4")
## Cap crown and rim shades are `tone` times these.
const CROWN := 1.0
const RIM := 0.86

## Each mushroom of the huddle: where it stands (x, z), its height, stem
## radius at the cap, cap radius and height, the lean (radians) and its
## direction, and the cap's tone.
const HUDDLE := [
	{"at": Vector2(-0.01, 0.0), "h": 0.15, "stem": 0.0155, "cap": 0.092, "cap_h": 0.060, "lean": 0.16, "dir": 0.7, "tone": Color("f2e5c6")},
	{"at": Vector2(0.088, 0.05), "h": 0.095, "stem": 0.0125, "cap": 0.064, "cap_h": 0.044, "lean": 0.30, "dir": 2.5, "tone": Color("e0bd8c")},
	{"at": Vector2(-0.075, 0.075), "h": 0.062, "stem": 0.0105, "cap": 0.050, "cap_h": 0.036, "lean": 0.22, "dir": 4.1, "tone": Color("dba08d")},
	{"at": Vector2(0.035, -0.088), "h": 0.034, "stem": 0.008, "cap": 0.030, "cap_h": 0.024, "lean": 0.12, "dir": 5.4, "tone": Color("efe2c0")},
]

static var _cache := {}

static func is_part(node_name: String) -> bool:
	return node_name in PARTS

## The cluster's stem or cap mesh, `fungus-stems` or `fungus-caps`.
static func mesh(node_name: String) -> ArrayMesh:
	if not _cache.has(node_name):
		_cache[node_name] = _build(node_name == "fungus-caps")
	return _cache[node_name]

## The baked mushroom parts swap to the new cluster, keeping their material;
## any other mesh is left alone.
static func swap(node_name: String, original: Mesh) -> Mesh:
	if not is_part(node_name): return original
	var result := mesh(node_name).duplicate() as ArrayMesh
	result.surface_set_material(0, original.surface_get_material(0))
	return result

## The soft look on the part's material: the faceted body stays flat-shaded,
## the caps' gills glow, and untinted instances take the mesh's own colours
## (the baked tint was only ever a placeholder for the lone old shapes).
static func dress(material: Material, node_name: String, tints: Dictionary, key: String) -> void:
	tints[key] = Color.WHITE
	var shader_material := material as ShaderMaterial
	if shader_material == null: return
	shader_material.set_shader_parameter("flat_faces", true)
	shader_material.set_shader_parameter("base_color", Color.WHITE)
	shader_material.set_shader_parameter("underglow", UNDERGLOW if node_name == "fungus-caps" else 0.0)
	shader_material.set_shader_parameter("tread_wobble", WOBBLE)
	shader_material.set_shader_parameter("tread_wobble_height", WOBBLE_HEIGHT)

static func triangle_count(mesh_to_count: Mesh) -> int:
	return mesh_to_count.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3

## How many separate mushrooms the cluster holds.
static func piece_count() -> int:
	return HUDDLE.size()

static func _build(caps: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2231
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for spec: Dictionary in HUDDLE:
		var lean_dir := Vector3(cos(float(spec.dir)), 0.0, sin(float(spec.dir)))
		var base := Vector3(spec.at.x, -0.008, spec.at.y)
		var span: float = spec.h + 0.008
		# The stem bows toward its lean, so it curves rather than tips.
		var top: Vector3 = base + Vector3.UP * span + lean_dir * spec.lean * span * 0.55
		var jitter := rng.randf_range(-0.05, 0.05)
		var turn := rng.randf() * TAU
		if caps:
			_cap(surface, rng, top, spec, lean_dir, turn, jitter)
		else:
			_stem(surface, rng, base, top, lean_dir, spec, turn, jitter)
	return surface.commit()

## One stem: three rings, thick at the soil and tapered toward the cap, in
## cream that darkens toward the root.
static func _stem(surface: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, top: Vector3, lean_dir: Vector3, spec: Dictionary, turn: float, jitter: float) -> void:
	var count := 3 if spec.h > 0.1 else 2
	var rings: Array = []
	for k in range(count):
		var t := float(k) / (count - 1)
		var radius: float = spec.stem * lerpf(1.45, 1.0, t)
		var centre: Vector3 = base.lerp(top, t) + lean_dir * spec.lean * 0.1 * sin(PI * t) * spec.h
		var ring: Array = []
		for s in range(STEM_SIDES):
			var a := turn + TAU * s / STEM_SIDES
			var point: Vector3 = centre + Vector3(cos(a), 0.0, sin(a)) * radius * rng.randf_range(0.92, 1.08)
			# The top ring is the cap's seat: round and exact.
			if k == count - 1: point = top + Vector3(cos(a), 0.0, sin(a)) * radius
			ring.append([point, _stem_colour(t, jitter, rng), t])
		rings.append(ring)
	for k in range(count - 1):
		for s in range(STEM_SIDES):
			var n := (s + 1) % STEM_SIDES
			var a: Array = rings[k][s]
			var b: Array = rings[k][n]
			var c: Array = rings[k + 1][s]
			var d: Array = rings[k + 1][n]
			_tri(surface, a, c, b)
			_tri(surface, b, c, d)

static func _stem_colour(t: float, jitter: float, rng: RandomNumberGenerator) -> Color:
	var colour := STEM_ROOT.lerp(STEM_TOP, smoothstep(0.0, 1.0, t))
	colour = colour.lightened(jitter) if jitter >= 0.0 else colour.darkened(-jitter)
	colour = colour.lightened(rng.randf_range(-0.02, 0.03))
	return colour.srgb_to_linear()

## One cap: a faceted dome (apex, shoulders, a notched rim), then the
## underside rising to the stem, whose vertices carry the gill light.
static func _cap(surface: SurfaceTool, rng: RandomNumberGenerator, top: Vector3, spec: Dictionary, lean_dir: Vector3, turn: float, jitter: float) -> void:
	var tilt_axis := Vector3.UP.cross(lean_dir).normalized()
	var basis := Basis(tilt_axis, spec.lean * 0.75)
	var cap_r: float = spec.cap
	var cap_h: float = spec.cap_h
	var tone: Color = spec.tone
	var crown := _cap_colour(tone, CROWN, jitter)
	var shoulder: Array = []
	var rim: Array = []
	var under: Array = []
	var inner: Array = []
	for s in range(SIDES):
		var a := turn + TAU * s / SIDES
		var wobble := rng.randf_range(-0.1, 0.1)
		var out := Vector3(cos(a + wobble), 0.0, sin(a + wobble))
		var notch := 1.0 if s % 2 == 0 else 0.93
		var rim_r := cap_r * notch * rng.randf_range(0.96, 1.04)
		shoulder.append(_p(top, basis, out * cap_r * 0.66 + Vector3.UP * cap_h * rng.randf_range(0.76, 0.86), _cap_colour(tone, 0.95, jitter), 0.92, 0.0))
		rim.append(_p(top, basis, out * rim_r + Vector3.UP * cap_h * rng.randf_range(0.30, 0.38), _cap_colour(tone, RIM, jitter), 0.8, 0.0))
		# The gills' outer edge, hanging a little below the rim, and the ring
		# where they meet the stem.
		under.append(_p(top, basis, out * rim_r * 0.94 + Vector3.UP * cap_h * 0.12, _gill_colour(tone, 0.8), 0.7, 0.45))
		var ia := turn + TAU * s / SIDES
		inner.append(_p(top, basis, Vector3(cos(ia), 0.0, sin(ia)) * spec.stem * 0.95 + Vector3.UP * cap_h * 0.02, _gill_colour(tone, 1.0), 0.55, 1.0))
	var apex := _p(top, basis, Vector3.UP * cap_h * rng.randf_range(1.0, 1.05), crown, 1.0, 0.0)
	for s in range(SIDES):
		var n := (s + 1) % SIDES
		_tri(surface, apex, shoulder[n], shoulder[s])
		_tri(surface, shoulder[s], shoulder[n], rim[s])
		_tri(surface, shoulder[n], rim[n], rim[s])
		# The lip turns under to the gills' edge.
		_tri(surface, rim[s], rim[n], under[s])
		_tri(surface, rim[n], under[n], under[s])
		# The underside climbs to the stem.
		_tri(surface, under[s], under[n], inner[s])
		_tri(surface, under[n], inner[n], inner[s])

## A cap's colour at a shade `level` of its tone, with the piece's jitter.
static func _cap_colour(tone: Color, level: float, jitter: float) -> Color:
	var colour := tone * level
	colour.a = 1.0
	colour = colour.lightened(jitter) if jitter >= 0.0 else colour.darkened(-jitter)
	return colour.srgb_to_linear()

## Gills are paler and warmer than the cap, a pale glowing cream.
static func _gill_colour(tone: Color, level: float) -> Color:
	var colour := tone.lerp(Color("fff0cf"), 0.55) * (0.78 + 0.22 * level)
	colour.a = 1.0
	return colour.srgb_to_linear()

## A cap vertex: its place on the cap's frame, colour, UV.y along fraction
## and UV2.x gill-light share.
static func _p(top: Vector3, basis: Basis, local: Vector3, colour: Color, along: float, glow: float) -> Array:
	return [top + basis * local, colour, along, glow]

## A triangle from three [point, colour, along(, glow)] entries.
static func _tri(surface: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	for v: Array in [a, b, c]:
		surface.set_color(v[1])
		surface.set_uv(Vector2(0.5, clampf(v[2], 0.0, 1.0)))
		surface.set_uv2(Vector2(v[3] if v.size() > 3 else 0.0, 0.0))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(v[0])
