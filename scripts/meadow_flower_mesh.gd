extends RefCounted
## The meadow flower kit (docs/scenic/flowers.md): one procedural plant per
## kind, each with a stem, a few leaves and heads whose petals are cut clear
## enough to read from the diorama camera (20-26 m, about 2.5 cm a pixel).
## Shapes are faceted: flat petals, three- or four-sided stems, folded
## leaves. Light is soft: every vertex carries the plant's mass normal (a
## dome over each head, up and out over stems and leaves), so the material
## shades the head as one rounded thing, never as shards.
##
## Vertex layout the flower material (`flower_heads` in
## reference_surface.gdshader) reads:
## - COLOR: the part's own colour, linear. Petals take any instance tint;
##   stems and leaves are recoloured from the family's living green.
## - UV.x: a stem or leaf's shade (about 0.7-1.1). UV.y: how far up the
##   plant's bend this vertex sits (0 root, 1 the tallest neck); a head's
##   vertices all take their neck's value, so the head rides its stem.
## - UV2.x: the part, STEM, LEAF, DISC, PETAL or PUFF. UV2.y: 1 where the
##   vertex nods with its head, plus DETAIL (0.25) on the plant's detail:
##   leaves, bracts and buds, which the material lets go
##   from the diorama's middle distance on (`flower_lod`).
## - CUSTOM0: xyz the offset from the head's neck, the pivot it nods about;
##   w the fraction out from the head's centre, for the petal flutter. The
##   seed clock's head (CYCLE_KINDS) names each vertex's part in the
##   dandelion's round instead (`flower_cycle`, scripts/dandelion_seeds.gd):
##   w is ROLE_SEED plus its parachute's rank (the order the seeds blow
##   off), ROLE_GOLD plus its fraction out for the gold head the plant
##   blooms again with, ROLE_CORE for the core and ROLE_BRACT for the
##   bracts folded back under it.
##
## Heights are at scale 1. Heads are drawn about one and a half to two times
## life size, as the grass tufts are, so a daisy's face is four or five
## pixels across at the diorama camera instead of two.

const NODE_PREFIX := "meadow-flower-"
## Every kind, in catalog order. These names are the catalog keys.
const KINDS := ["oxeye_daisy","buttercup","dandelion","dandelion_clock","cosmos","sunflower","poppy","lupine","wheat"]
const STEM := 0.0
const LEAF := 1.0
const DISC := 2.0
const PETAL := 3.0
const PUFF := 4.0
## Added to UV2.y on detail vertices (see above): a fraction, so UV2.y > 0.5
## still names the nodding head.
const DETAIL := 0.25

## Per kind: the plant's height (m, the top of its tallest head), the
## material's sway (shape and frequency as the source flowers have them),
## flower motion (wave share, head lag in metres upwind, nod in radians at
## full breeze, petal flutter in metres), backlit glow, petal roughness, and
## petal colour variants (sRGB) the material picks per plant.
const SPEC := {
	"oxeye_daisy":{"height":0.58,"sway":Vector4(0.0,0.55,0.05,0.02),"frequency":Vector4(2.6,4.1,0.7,0.3),"motion":Vector4(0.8,0.7,0.30,0.004),"glow":0.75,"roughness":1.0,"variants":[]},
	"buttercup":{"height":0.36,"sway":Vector4(0.0,0.34,0.05,0.02),"frequency":Vector4(2.9,4.5,0.7,0.3),"motion":Vector4(0.8,0.5,0.25,0.003),"glow":0.6,"roughness":0.34,"variants":[]},
	"dandelion":{"height":0.26,"sway":Vector4(0.0,0.24,0.04,0.015),"frequency":Vector4(2.9,4.5,0.6,0.3),"motion":Vector4(0.7,0.5,0.22,0.002),"glow":0.55,"roughness":1.0,"variants":[]},
	"dandelion_clock":{"height":0.40,"sway":Vector4(0.0,0.36,0.05,0.02),"frequency":Vector4(2.7,4.2,0.7,0.3),"motion":Vector4(0.8,0.6,0.18,0.0),"glow":0.95,"roughness":1.0,"variants":[]},
	"cosmos":{"height":0.92,"sway":Vector4(0.0,0.9,0.07,0.03),"frequency":Vector4(2.2,3.7,0.8,0.35),"motion":Vector4(1.0,0.9,0.35,0.006),"glow":0.85,"roughness":1.0,"variants":["e8609f","c22f78","fcefe2","f2a2c4"]},
	"sunflower":{"height":1.85,"sway":Vector4(0.0,1.8,0.03,0.012),"frequency":Vector4(1.3,2.2,0.5,0.2),"motion":Vector4(0.3,2.2,0.16,0.004),"glow":0.6,"roughness":1.0,"variants":[]},
	"poppy":{"height":0.62,"sway":Vector4(0.0,0.6,0.06,0.025),"frequency":Vector4(2.4,3.9,0.8,0.3),"motion":Vector4(0.9,0.8,0.32,0.006),"glow":0.95,"roughness":1.0,"variants":["d92a1c","e8452a","f07a32"]},
	"lupine":{"height":0.82,"sway":Vector4(0.0,0.8,0.04,0.015),"frequency":Vector4(2.0,3.4,0.6,0.25),"motion":Vector4(0.6,0.9,0.12,0.002),"glow":0.55,"roughness":1.0,"variants":["7b4cc6","9c48b8","e07aae","f1e8f0"]},
	# Wheat (docs/scenic/wheat.md) takes the whole of the grass's rolling wave,
	# so a field leans and rights itself as one mass, its ears lagging a metre.
	# Knee-high to a fence: under its posts' tops (scripts/fences.gd).
	"wheat":{"height":0.66,"sway":Vector4(0.0,0.66,0.06,0.02),"frequency":Vector4(1.8,3.0,0.6,0.25),"motion":Vector4(1.0,1.0,0.3,0.0),"glow":0.8,"roughness":1.0,"variants":[]},
}
## How much larger than the builders' sizes each kind's heads are drawn,
## about their centres, so a face is six to eight pixels across at the
## diorama camera. Buds scale with their plant. Sunflowers are big enough.
const HEAD_SCALE := {"oxeye_daisy":1.35,"buttercup":1.45,"dandelion":1.5,"dandelion_clock":1.2,"cosmos":1.3,"poppy":1.3,"lupine":1.2,"wheat":1.3}
## Each kind's petal colour as authored in the mesh (sRGB): the material
## swaps it for a variant, keeping the mesh's own shading over it.
const PETAL_REF := {"cosmos":"e8609f","poppy":"d92a1c","lupine":"6a5ccc"}

## Opt-in (`--meadow-flowers`): GardenView draws the reference's four flower
## forms as these kinds, and the painted meadow's flowers as drifts of them.
## Only the drawing changes; records, saves and their digests do not.
const REMAP := {"daisy_flower":"oxeye_daisy","button_flower":"buttercup","spike_flower":"lupine","umbel_flower":"dandelion_clock"}
## The painted meadow's drifts under the remap, one kind per DRIFT_CELLS
## square of meadow cells, sized down a little (DRIFT_SCALE) to sit in the
## tufts. No sunflowers: they are placed, not painted.
const DRIFT := ["oxeye_daisy","buttercup","dandelion","oxeye_daisy","cosmos","poppy","dandelion_clock","buttercup","lupine"]
const DRIFT_CELLS := 5
const DRIFT_SCALE := 0.8

static var _meshes := {}
## Tests set this to force the remap on (1) or off (0); -1 reads the flag.
static var remap_override := -1

static func remap_enabled() -> bool:
	if remap_override >= 0: return remap_override == 1
	return "--meadow-flowers" in preload("res://scripts/launch_args.gd").user_args() or "--meadow-flowers" in OS.get_cmdline_args()

## The kind a painted meadow cell blooms in under the remap.
static func drift_kind(x: int, z: int) -> String:
	var cell := Vector2i(floori(float(x) / DRIFT_CELLS), floori(float(z) / DRIFT_CELLS))
	return DRIFT[posmod(hash(cell), DRIFT.size())]

## The instance colour GardenView draws a placed `kind` with, from the
## record's linear `tint`. A tint that is one of the kind's own variants
## (meadow drifts, scripts/meadow_types.gd) picks that variant for every
## petal: white, its alpha (k + 0.5) / 8 naming variant k, which the
## material reads; discs and stems keep their own colours. Any other tint
## multiplies petals and discs as before.
static func instance_color(kind: String, tint: Color) -> Color:
	var variants: Array = SPEC[kind].variants if SPEC.has(kind) else []
	for k in range(mini(variants.size(), 4)):
		var c := Color(variants[k]).srgb_to_linear()
		if Vector3(c.r - tint.r, c.g - tint.g, c.b - tint.b).length() < 0.01:
			return Color(1.0, 1.0, 1.0, (k + 0.5) / 8.0)
	return tint

## The kinds that go round the dandelion's cycle (docs/scenic/dandelions.md):
## the seed clock sheds its seeds on the air, stands bare, blooms gold and
## fluffs out again, all in its material (`flower_cycle`), from a state
## scripts/dandelion_seeds.gd writes into its instance alpha.
const CYCLE_KINDS := ["dandelion_clock"]
const ROLE_SEED := 2.0
const ROLE_GOLD := 4.0
const ROLE_CORE := 6.0
const ROLE_BRACT := 8.0

## Distance in the material (reference_surface `flower_far`, `flower_lod`),
## measured from the camera:
## - from LOD_NEAR to LOD_FAR metres each plant lets its detail go (leaves,
##   bracts, buds), so beyond it is stems and heads over the painted carpet;
## - from FAR_START to FAR_END metres a kind keeps down to its FAR_KEEP share
##   of its plants, and the kept heads grow by keep^-FAR_GROW so a drift keeps
##   its cover. Sunflowers stand in rows and keep the most.
const FAR_KEEP := {"oxeye_daisy":0.6,"buttercup":0.6,"dandelion":0.6,"dandelion_clock":0.6,"cosmos":0.65,"sunflower":0.8,"poppy":0.65,"lupine":0.7,"wheat":0.7}
const FAR_START := 14.0
const FAR_END := 32.0
const FAR_GROW := 0.5
## Sunflowers keep their leaves at any distance: they are the field's mass.
const KEEP_DETAIL := ["sunflower"]
const LOD_NEAR := 15.0
const LOD_FAR := 20.0
## The kinds whose batches cast shadows: the ones that stand clear of the
## grass, whose shadows give a drift its depth. A shadow under a low flower
## is a pixel at the diorama camera, and drawing them all doubled a meadow's
## triangles.
const SHADOW_KINDS := ["sunflower","cosmos","lupine","poppy","oxeye_daisy"]
## The kinds a pond's reflection copies: the tall ones that stand over a bank.
const REFLECT_KINDS := ["sunflower"]

## The kinds that ripen and are cut (`flower_ripen` in reference_surface,
## docs/scenic/wheat.md): their straw keeps its own gold instead of the
## grass's living green, greens in spring, deepens through autumn and stands
## as stubble through the winter's dormancy (the `zs_season` global).
const RIPEN_KINDS := ["wheat"]
## The green a RIPEN_KINDS plant takes in spring, times its own luminance
## (linear): its ears a lighter yellow-green over deeper green straw, so the
## heads stand out from their stalks in the green months as in the gold.
const RIPEN_GREEN_EAR := Vector3(0.62, 0.78, 0.22)
const RIPEN_GREEN_STRAW := Vector3(0.30, 0.62, 0.12)
## Wheat's look (sRGB), authored ripe: pale golden-cream ears (foot to tip)
## over darker warm ochre straw and blades, so each head reads against its
## stalk; its ears' and straws' radii (m, at size 1; ears are drawn a further
## HEAD_SCALE larger), the ears plump against the straw.
const WHEAT_STRAW := "ad8540"
const WHEAT_BLADE := "b08a48"
const WHEAT_EAR_FOOT := "d8a250"
const WHEAT_EAR_TIP := "f2c868"
const WHEAT_STRAW_RADIUS := 0.0065
const WHEAT_EAR_RADIUS := 0.019
## The stubble's height (m, at record size 1) through the winter.
const STUBBLE := 0.14

static func casts_shadow(kind: String) -> bool:
	return kind in SHADOW_KINDS

static func reflects(kind: String) -> bool:
	return kind in REFLECT_KINDS

## The kit kind a GardenView batch key ("<asset>:<node>") draws, or "".
static func kind_of_part(key: String) -> String:
	var node := key.get_slice(":", 1) if ":" in key else key
	return node.trim_prefix(NODE_PREFIX) if is_node(node) else ""

static func is_node(node_name: String) -> bool:
	return node_name.begins_with(NODE_PREFIX) and node_name.trim_prefix(NODE_PREFIX) in KINDS

static func node_name(kind: String) -> String:
	return NODE_PREFIX + kind

## The kind's mesh, built once, with its flower material on surface 0.
static func mesh(kind: String) -> ArrayMesh:
	if not _meshes.has(kind):
		var built: ArrayMesh = build(kind)
		built.surface_set_material(0, material(kind))
		_meshes[kind] = built
	return _meshes[kind]

## The kind's material: reference_surface with the flower look on.
static func material(kind: String) -> ShaderMaterial:
	var spec: Dictionary = SPEC[kind]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/reference_surface.gdshader")
	m.set_shader_parameter("base_color", Color.WHITE)
	m.set_shader_parameter("flat_faces", false)
	m.set_shader_parameter("sway_enabled", true)
	m.set_shader_parameter("sway_shape", spec.sway)
	m.set_shader_parameter("sway_frequency", spec.frequency)
	m.set_shader_parameter("sway_phase", Vector3(1.9, 1.4, 1.7))
	m.set_shader_parameter("wet_droop", 0.05)
	m.set_shader_parameter("roughness_value", 1.0)
	m.set_shader_parameter("flower_heads", true)
	m.set_shader_parameter("flower_motion", spec.motion)
	m.set_shader_parameter("flower_glow", spec.glow)
	m.set_shader_parameter("flower_roughness", spec.roughness)
	m.set_shader_parameter("flower_far", Vector4(FAR_START, FAR_END, FAR_KEEP.get(kind, 1.0), FAR_GROW))
	if not kind in KEEP_DETAIL: m.set_shader_parameter("flower_lod", Vector2(LOD_NEAR, LOD_FAR))
	if kind in RIPEN_KINDS:
		m.set_shader_parameter("flower_ripen", true)
		m.set_shader_parameter("flower_stubble", STUBBLE)
		m.set_shader_parameter("flower_ripen_green_ear", RIPEN_GREEN_EAR)
		m.set_shader_parameter("flower_ripen_green_straw", RIPEN_GREEN_STRAW)
	if kind in CYCLE_KINDS:
		m.set_shader_parameter("flower_cycle", true)
		m.set_shader_parameter("flower_cycle_times", preload("res://scripts/dandelion_seeds.gd").cycle_times())
	var variants: Array = spec.variants
	if not variants.is_empty():
		var colors := PackedVector3Array()
		for hex: String in variants:
			var c := Color(hex).srgb_to_linear()
			colors.append(Vector3(c.r, c.g, c.b))
		while colors.size() < 4: colors.append(colors[0])
		var ref := Color(PETAL_REF[kind]).srgb_to_linear()
		m.set_shader_parameter("flower_variants", colors)
		m.set_shader_parameter("flower_variant_count", variants.size())
		m.set_shader_parameter("flower_petal_ref", Vector3(ref.r, ref.g, ref.b))
	return m

static func build(kind: String) -> ArrayMesh:
	var plant := Plant.new(kind, float(SPEC[kind].height))
	match kind:
		"oxeye_daisy": plant.oxeye_daisy()
		"buttercup": plant.buttercup()
		"dandelion": plant.dandelion()
		"dandelion_clock": plant.dandelion_clock()
		"cosmos": plant.cosmos()
		"sunflower": plant.sunflower()
		"poppy": plant.poppy()
		"lupine": plant.lupine()
		"wheat": plant.wheat()
	return plant.commit()

static func _c(hex: String) -> Color:
	return Color(hex).srgb_to_linear()

## One plant under construction. Geometry helpers take plant-space points
## (metres, y up, root at the origin).
class Plant:
	var surface := SurfaceTool.new()
	var rng := RandomNumberGenerator.new()
	var bend_height: float
	var head_scale: float
	## Small petals are cut as kites (two rows and a tip) instead of three
	## rows: the same face at the diorama camera for 40 % fewer vertices.
	var kite_petals := false
	## True while building detail the far plant goes without (DETAIL).
	var detail := false
	## The dandelion's round: while `role` is set (ROLE_SEED, ROLE_GOLD,
	## ROLE_CORE), head vertices carry it in CUSTOM0.w, plus `rank` when that
	## is set (a seed's), else their fraction out.
	var role := 0.0
	var rank := -1.0
	## The stems' and leaves' authored colours. The material recolours them
	## living green on every kind but RIPEN_KINDS, which keep these (wheat's
	## straw).
	var stem_hex := STEM_GREEN
	var leaf_hex := LEAF_GREEN
	const STEM_GREEN := "4d7a34"
	const LEAF_GREEN := "5d8c3c"

	func _init(kind: String, height: float) -> void:
		rng.seed = hash(kind)
		bend_height = height
		head_scale = HEAD_SCALE.get(kind, 1.0)
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)

	func commit() -> ArrayMesh:
		surface.index()
		return surface.commit()

	func along(p: Vector3) -> float:
		return clampf(p.y / bend_height, 0.0, 1.0)

	# --- vertices -----------------------------------------------------------

	## A vertex that stays with its stem (no nod).
	func plain(p: Vector3, n: Vector3, color: Color, part: float, shade: float) -> Array:
		return [p, n.normalized(), color, Vector2(shade, along(p)), Vector2(part, DETAIL if detail else 0.0), Color(0, 0, 0, 0)]

	## A vertex of `head`: it nods about the head's neck and rides the neck's bend.
	func headed(h: Dictionary, p: Vector3, color: Color, part: float, shade := 1.0) -> Array:
		# Heads are drawn larger than life (HEAD_SCALE) about their centre.
		var scale: float = h.get("scale", 1.0)
		var middle: Vector3 = h.centre
		p = middle + (p - middle) * scale
		var dome: Vector3 = middle + (h.dome - middle) * scale
		var n := (p - dome).normalized()
		if h.get("axis", false):
			# A spike's mass is a column: out from its axis, a little up.
			var on_axis := Vector3(dome.x, p.y - 0.02, dome.z)
			n = (p - on_axis).normalized()
		var offset: Vector3 = p - h.neck
		var radial := clampf((p - middle).length() / maxf(h.radius * scale, 0.001), 0.0, 1.0)
		if role > 0.0: radial = role + minf(rank if rank >= 0.0 else radial, 0.999)
		return [p, n, color, Vector2(shade, h.along), Vector2(part, 1.0 + (DETAIL if detail else 0.0)), Color(offset.x, offset.y, offset.z, radial)]

	func tri(a: Array, b: Array, c: Array) -> void:
		for v: Array in [a, b, c]:
			surface.set_color(v[2])
			surface.set_normal(v[1])
			surface.set_uv(v[3])
			surface.set_uv2(v[4])
			surface.set_custom(0, v[5])
			surface.add_vertex(v[0])

	func quad(a: Array, b: Array, c: Array, d: Array) -> void:
		tri(a, b, c)
		tri(a, c, d)

	# --- stems --------------------------------------------------------------

	## A faceted tube along `points`, `sides` round, tapering `radii`.
	func tube(points: Array, radii: Array, sides := 3, shade := 0.8) -> void:
		var color := MeadowFlowerColor.of(stem_hex)
		var rings: Array = []
		for i in range(points.size()):
			var p: Vector3 = points[i]
			var ahead: Vector3 = points[mini(i + 1, points.size() - 1)]
			var behind: Vector3 = points[maxi(i - 1, 0)]
			var t := (ahead - behind).normalized()
			var side := t.cross(Vector3.FORWARD if absf(t.z) < 0.9 else Vector3.RIGHT).normalized()
			var other := t.cross(side).normalized()
			var ring: Array = []
			for k in range(sides):
				var a := TAU * float(k) / sides + 0.4
				var out := side * cos(a) + other * sin(a)
				ring.append(plain(p + out * float(radii[i]), out * 0.7 + Vector3.UP * 0.7, color, STEM, shade))
			rings.append(ring)
		for i in range(rings.size() - 1):
			for k in range(sides):
				var k2 := (k + 1) % sides
				quad(rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k])

	## A curving stem from `base` to `top`, leaning by `bow` sideways at its middle.
	func stem(base: Vector3, top: Vector3, radius: float, bow := Vector3.ZERO, segments := 4, sides := 3) -> void:
		var points: Array = []
		var radii: Array = []
		for i in range(segments + 1):
			var t := float(i) / segments
			points.append(base.lerp(top, t) + bow * sin(t * PI) * (1.0 - t * 0.3))
			radii.append(radius * lerpf(1.0, 0.65, t))
		tube(points, radii, sides)

	## A curved neck that ends heading `face` at `top`: a short hook for
	## drooping heads.
	func hooked_stem(base: Vector3, top: Vector3, face: Vector3, radius: float, sides := 3, segments := 6) -> void:
		var points: Array = []
		var radii: Array = []
		var reach := (top - base).length()
		var control := top - face * reach * 0.35
		for i in range(segments + 1):
			var t := float(i) / segments
			var a := base.lerp(control, t)
			var b := control.lerp(top, t)
			points.append(a.lerp(b, t))
			radii.append(radius * lerpf(1.0, 0.7, t))
		tube(points, radii, sides)

	# --- leaves -------------------------------------------------------------

	## A folded leaf from `base`, heading `azimuth` (radians) and rising at
	## `rise` (rise over run) before drooping by `droop`. `outline` is
	## [fraction along, half width as a share of `width`] rows; `teeth` notches
	## alternate rows outward. The midrib sits below the edges by `fold`.
	func leaf(base: Vector3, azimuth: float, length: float, width: float, rise: float, droop: float, outline: Array, fold := 0.25, teeth := 0.0, shade := 0.9) -> void:
		var was := detail
		detail = true
		var d := Vector3(cos(azimuth), 0.0, sin(azimuth))
		var side := Vector3.UP.cross(d).normalized()
		var color := MeadowFlowerColor.of(leaf_hex)
		var up_n := (Vector3.UP + d * 0.45).normalized()
		var rows: Array = []
		for r in range(outline.size()):
			var t: float = outline[r][0]
			var half: float = float(outline[r][1]) * width
			if teeth > 0.0 and r % 2 == 1: half *= 1.0 + teeth
			var c := base + d * (length * t) + Vector3.UP * (length * (rise * t - droop * t * t))
			var lift := Vector3.UP * fold * half
			rows.append([plain(c - side * half + lift, up_n, color, LEAF, shade), plain(c, up_n, color, LEAF, shade * 0.92), plain(c + side * half + lift, up_n, color, LEAF, shade)])
		var tip_c := base + d * length + Vector3.UP * (length * (rise - droop))
		var tip := plain(tip_c, up_n, color, LEAF, shade)
		for r in range(rows.size() - 1):
			quad(rows[r][0], rows[r][1], rows[r + 1][1], rows[r + 1][0])
			quad(rows[r][1], rows[r][2], rows[r + 1][2], rows[r + 1][1])
		var last: Array = rows[rows.size() - 1]
		tri(last[0], last[1], tip)
		tri(last[1], last[2], tip)
		detail = was

	## Basal leaves round the root, flat to the ground.
	func rosette(count: int, length: Vector2, width: float, outline: Array, teeth := 0.0, rise := 0.18) -> void:
		var start := rng.randf() * TAU
		for i in range(count):
			var a := start + TAU * float(i) / count + rng.randf_range(-0.25, 0.25)
			leaf(Vector3(cos(a), 0.0, sin(a)) * 0.01 + Vector3.UP * 0.005, a, rng.randf_range(length.x, length.y), width, rise, rise * 0.9, outline, 0.2, teeth, rng.randf_range(0.82, 0.98))

	# --- heads --------------------------------------------------------------

	## A head on `neck` facing `face`, its petals out to `radius`. The dome
	## its normals come from sits `depth` radii behind the face.
	func head(neck: Vector3, face: Vector3, radius: float, offset := 0.0, depth := 0.9) -> Dictionary:
		face = face.normalized()
		var centre := neck + face * offset
		var u := face.cross(Vector3.FORWARD if absf(face.z) < 0.9 else Vector3.RIGHT).normalized()
		var v := face.cross(u).normalized()
		return {"neck":neck, "face":face, "centre":centre, "u":u, "v":v, "radius":radius, "dome":centre - face * radius * depth, "along":along(neck), "scale":head_scale}

	func head_point(h: Dictionary, angle: float, r: float, lift: float, across := 0.0) -> Vector3:
		var out: Vector3 = h.u * cos(angle) + h.v * sin(angle)
		var tangent: Vector3 = h.face.cross(out)
		return h.centre + out * r + h.face * lift + tangent * across

	## A ray of petals round `h`. Each petal runs from `r0` to `r1` with
	## `width`; `cup` lifts its tip toward the face, `reflex` lowers it; a
	## `notch` (share of length) cuts its tip into two lobes; `tilt` lifts
	## the whole ray. Colours run base to tip.
	func petals(h: Dictionary, count: int, r0: float, r1: float, width: float, base: Color, tip: Color, cup := 0.0, reflex := 0.0, notch := 0.0, tilt := 0.0, start := 0.0, jitter := 0.06) -> void:
		for i in range(count):
			var a := start + TAU * float(i) / count + rng.randf_range(-jitter, jitter)
			var length := (r1 - r0) * rng.randf_range(0.92, 1.06)
			var w := width * rng.randf_range(0.9, 1.08)
			var bend := cup - reflex + rng.randf_range(-0.05, 0.05)
			var at := func(t: float, across: float) -> Vector3:
				return head_point(h, a, r0 + length * t, length * (tilt * t + bend * t * t), across * w)
			var shade := rng.randf_range(0.95, 1.05)
			var col := func(t: float) -> Color: return base.lerp(tip, clampf(t, 0.0, 1.0)) * shade
			var rows := [[0.0, 0.18], [0.55, 0.5]] if kite_petals and notch <= 0.0 else [[0.0, 0.18], [0.5, 0.5], [0.82, 0.44]]
			var verts: Array = []
			for row: Array in rows:
				verts.append([headed(h, at.call(row[0], -row[1]), col.call(row[0]), PETAL), headed(h, at.call(row[0], row[1]), col.call(row[0]), PETAL)])
			for r in range(rows.size() - 1):
				quad(verts[r][0], verts[r][1], verts[r + 1][1], verts[r + 1][0])
			var last: Array = verts[rows.size() - 1]
			if notch > 0.0:
				var lobe_l: Array = headed(h, at.call(1.0, -0.26), col.call(1.0), PETAL)
				var lobe_r: Array = headed(h, at.call(1.0, 0.26), col.call(1.0), PETAL)
				var cut: Array = headed(h, at.call(1.0 - notch, 0.0), col.call(1.0), PETAL)
				tri(last[0], cut, lobe_l)
				tri(last[0], last[1], cut)
				tri(last[1], lobe_r, cut)
			else:
				tri(last[0], last[1], headed(h, at.call(1.0, 0.0), col.call(1.0), PETAL))

	## A low faceted dome on the face (the disc), with a receptacle behind it.
	func disc(h: Dictionary, radius: float, height: float, sides: int, edge: Color, top: Color, back: float = 0.6, back_color := Color()) -> void:
		var crown: Array = headed(h, h.centre + h.face * height, top, DISC)
		var ring: Array = []
		for k in range(sides):
			ring.append(headed(h, head_point(h, TAU * k / sides, radius, height * 0.25), edge, DISC))
		for k in range(sides):
			tri(ring[k], ring[(k + 1) % sides], crown)
		if back <= 0.0: return
		var green := back_color if back_color != Color() else MeadowFlowerColor.of(LEAF_GREEN)
		var under: Array = []
		for k in range(sides):
			under.append(headed(h, head_point(h, TAU * (k + 0.5) / sides, radius * 0.75, -radius * back), green, LEAF, 0.8))
		var heel: Array = headed(h, h.centre - h.face * radius * back * 1.4, green, LEAF, 0.75)
		for k in range(sides):
			var k2 := (k + 1) % sides
			var rim_k: Array = ring[k].duplicate()
			var rim_k2: Array = ring[k2].duplicate()
			rim_k[2] = green; rim_k[4] = Vector2(LEAF, 1.0); rim_k[3] = Vector2(0.8, h.along)
			rim_k2[2] = green; rim_k2[4] = Vector2(LEAF, 1.0); rim_k2[3] = Vector2(0.8, h.along)
			tri(rim_k, rim_k2, under[k])
			tri(under[k], rim_k2, under[k2])
			tri(under[k], under[k2], heel)

	## Thin green bracts folded back under a head.
	func bracts(h: Dictionary, count: int, length: float, width: float, droop: float) -> void:
		var green := MeadowFlowerColor.of(LEAF_GREEN)
		var was := detail
		detail = true
		for i in range(count):
			var a := TAU * (float(i) + 0.5) / count
			var b0: Array = headed(h, head_point(h, a, length * 0.15, -length * 0.1, -width * 0.5), green, LEAF, 0.8)
			var b1: Array = headed(h, head_point(h, a, length * 0.15, -length * 0.1, width * 0.5), green, LEAF, 0.8)
			var t: Array = headed(h, head_point(h, a, length * 0.8, -length * droop), green, LEAF, 0.85)
			tri(b0, b1, t)
		detail = was

	## A faceted ball (a bud, or a seed clock's core): an icosphere with
	## radial normals, its radius and colour jittered by `jitter`.
	## `fine` subdivides the icosahedron once (42 points); a bud is a few
	## pixels and keeps the plain 12.
	func puff(h: Dictionary, radius: float, color: Color, part := DISC, jitter := Vector2(0.94, 1.05), fine := true) -> Array:
		var base := _icosphere(fine)
		var points: Array = base[0]
		var faces: Array = base[1]
		var placed: Array = []
		for p: Vector3 in points:
			var r := radius * rng.randf_range(jitter.x, jitter.y)
			var c := color * rng.randf_range(0.94, 1.03)
			var v: Array = headed(h, h.centre + p * r, c, part)
			v[1] = p
			placed.append(v)
		for f: Vector3i in faces:
			tri(placed[f.x], placed[f.y], placed[f.z])
		return points

	## A seed clock: a soft core inside a halo of seed parachutes, one small
	## flat star of a triangle facing out along each of the core's 42
	## directions, so the edge is airy and catches the light, not a stone.
	## Each parachute has its own rank, the order the air takes them in
	## (the dandelion's round), shuffled so a clock thins all over.
	func seed_clock(h: Dictionary, radius: float) -> void:
		role = ROLE_CORE
		var points: Array = puff(h, radius * 0.6, MeadowFlowerColor.of("ddd8c8"), PUFF, Vector2(0.95, 1.03))
		role = ROLE_SEED
		var white := MeadowFlowerColor.of("f8f7f1")
		var ranks: Array = []
		for i in range(points.size()): ranks.append((float(i) + 0.5) / points.size())
		var shuffle := RandomNumberGenerator.new()
		shuffle.seed = 5521
		for i in range(ranks.size() - 1, 0, -1):
			var j := shuffle.randi_range(0, i)
			var swap: float = ranks[i]
			ranks[i] = ranks[j]
			ranks[j] = swap
		for s in range(points.size()):
			var p: Vector3 = points[s]
			rank = ranks[s]
			var r := radius * rng.randf_range(0.9, 1.1)
			var c: Vector3 = h.centre + p * r
			var t1 := p.cross(Vector3.UP if absf(p.y) < 0.9 else Vector3.RIGHT).normalized()
			var t2 := p.cross(t1).normalized()
			var size := radius * 0.32
			var turn := rng.randf() * TAU
			var corners: Array = []
			for k in range(3):
				var a := turn + TAU * k / 3.0
				var v: Array = headed(h, c + (t1 * cos(a) + t2 * sin(a)) * size, white * rng.randf_range(0.95, 1.02), PUFF)
				v[1] = p
				corners.append(v)
			tri(corners[0], corners[1], corners[2])
		role = 0.0
		rank = -1.0

	static func _icosphere(fine := true) -> Array:
		var t := (1.0 + sqrt(5.0)) / 2.0
		var points: Array = []
		for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
			points.append(p.normalized())
		var faces: Array = [Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11), Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8), Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9), Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1)]
		if not fine: return [points, faces]
		var split := {}
		var finer: Array = []
		for f: Vector3i in faces:
			var m: Array = []
			for pair in [[f.x, f.y], [f.y, f.z], [f.z, f.x]]:
				var key := Vector2i(mini(pair[0], pair[1]), maxi(pair[0], pair[1]))
				if not split.has(key):
					split[key] = points.size()
					points.append(((points[pair[0]] + points[pair[1]]) * 0.5).normalized())
				m.append(split[key])
			finer.append_array([Vector3i(f.x, m[0], m[2]), Vector3i(f.y, m[1], m[0]), Vector3i(f.z, m[2], m[1]), Vector3i(m[0], m[1], m[2])])
		return [points, finer]

	# --- the kinds ----------------------------------------------------------

	const LANCE := [[0.0, 0.1], [0.3, 0.5], [0.65, 0.42]]
	## A narrow leaf in one row and a tip: thread and leaflet leaves, which
	## are a line or two of pixels from any camera.
	const SLIM := [[0.0, 0.12], [0.45, 0.5]]
	## A broad lobe in two rows: a buttercup's leaf fan.
	const LOBE := [[0.0, 0.15], [0.4, 0.5], [0.75, 0.32]]
	const BROAD := [[0.0, 0.15], [0.25, 0.48], [0.55, 0.5], [0.8, 0.3]]

	## White rays round a raised yellow disc: two heads and a bud on a
	## branching stem, toothed leaves low and clasping leaves up the stem.
	func oxeye_daisy() -> void:
		var white := MeadowFlowerColor.of("f6f3ea")
		var cream := MeadowFlowerColor.of("ece6d4")
		var gold := MeadowFlowerColor.of("f0b31c")
		var amber := MeadowFlowerColor.of("d9900f")
		var tops := [[Vector3(0.025, 0.55, 0.01), Vector3(0.25, 1.0, 0.1), 0.056], [Vector3(-0.075, 0.46, 0.04), Vector3(-0.35, 1.0, 0.15), 0.048]]
		stem(Vector3.ZERO, tops[0][0], 0.0045, Vector3(0.02, 0.0, 0.0))
		stem(Vector3(0.006, 0.24, 0.0), tops[1][0], 0.0035, Vector3(-0.02, 0.0, 0.01), 3)
		kite_petals = true
		detail = false
		for i in range(tops.size()):
			var top: Array = tops[i]
			var h := head(top[0], top[1], top[2], 0.004)
			petals(h, 14, top[2] * 0.3, top[2], top[2] * 0.36, cream, white, 0.0, 0.16, 0.0, 0.06, rng.randf() * TAU)
			disc(h, top[2] * 0.32, top[2] * 0.2, 9, gold, amber, 0.35)
		detail = false
		rosette(3, Vector2(0.09, 0.12), 0.03, LANCE, 0.35)
		for y: float in [0.16, 0.3]:
			leaf(Vector3(0.008, y, 0.0), rng.randf() * TAU, 0.06, 0.018, 0.6, 0.5, SLIM, 0.2, 0.3)

	## Low glossy gold cups, three on a forked stem, over three-lobed leaves.
	func buttercup() -> void:
		var gold := MeadowFlowerColor.of("f7c815")
		var deep := MeadowFlowerColor.of("e9a90b")
		var tops := [[Vector3(0.0, 0.34, 0.0), Vector3(0.1, 1.0, 0.05)], [Vector3(0.07, 0.29, 0.035), Vector3(0.45, 1.0, 0.2)], [Vector3(-0.055, 0.26, -0.05), Vector3(-0.35, 1.0, -0.3)]]
		stem(Vector3.ZERO, tops[0][0], 0.0035, Vector3(0.01, 0.0, 0.0))
		stem(Vector3(0.002, 0.15, 0.0), tops[1][0], 0.003, Vector3(0.015, 0.0, 0.0), 3)
		stem(Vector3(0.002, 0.12, 0.0), tops[2][0], 0.003, Vector3(-0.01, 0.0, 0.0), 3)
		for i in range(tops.size()):
			var r := 0.03 if i == 0 else 0.026
			var h := head(tops[i][0], tops[i][1], r, 0.003, 1.2)
			petals(h, 5, r * 0.15, r, r * 0.95, deep, gold, 0.55, 0.0, 0.0, 0.35, rng.randf() * TAU, 0.03)
			disc(h, r * 0.24, r * 0.25, 6, MeadowFlowerColor.of("d39a0c"), MeadowFlowerColor.of("a8b437"), 0.4)
		detail = false
		# Basal leaves: each a fan of three broad lobes.
		for i in range(2):
			var a := PI * i + rng.randf()
			for lobe in [-0.55, 0.0, 0.55]:
				leaf(Vector3(cos(a), 0.0, sin(a)) * 0.012 + Vector3.UP * 0.03, a + lobe, 0.06, 0.04, 0.5, 0.6, LOBE, 0.2, 0.0, rng.randf_range(0.82, 0.95))

	## A low golden pompom: three rings of strap florets, the inner ones
	## rising, over a rosette of long toothed leaves.
	func dandelion() -> void:
		var gold := MeadowFlowerColor.of("ffd024")
		var deep := MeadowFlowerColor.of("f7b916")
		var neck := Vector3(0.01, 0.23, 0.0)
		stem(Vector3.ZERO, neck, 0.004, Vector3(0.012, 0.0, 0.0), 4, 4)
		var h := head(neck, Vector3(0.12, 1.0, 0.05), 0.042, 0.006, 0.8)
		kite_petals = true
		petals(h, 18, 0.008, 0.042, 0.011, deep, gold, 0.0, 0.08, 0.0, 0.08, 0.0, 0.08)
		# The middle ring is detail: from the middle distance the outer ring
		# and the rising heart read as the same gold pompom.
		detail = true
		petals(h, 13, 0.006, 0.032, 0.011, deep, gold, 0.0, 0.0, 0.0, 0.55, 0.2, 0.08)
		detail = false
		petals(h, 8, 0.003, 0.02, 0.01, deep, gold, 0.0, 0.0, 0.0, 1.1, 0.4, 0.08)
		disc(h, 0.009, 0.012, 6, deep, deep, 0.5)
		bracts(h, 7, 0.022, 0.006, 0.9)
		rosette(5, Vector2(0.12, 0.16), 0.024, LANCE, 0.7, 0.12)

	## The seed clock: a faceted white puff on a tall stalk that glows when
	## the sun is behind it, over a few rosette leaves.
	func dandelion_clock() -> void:
		var neck := Vector3(0.015, 0.34, 0.0)
		stem(Vector3.ZERO, neck, 0.0038, Vector3(0.015, 0.0, 0.0), 4, 4)
		var h := head(neck, Vector3(0.1, 1.0, 0.0), 0.052, 0.046, 1.0)
		h.dome = h.centre
		seed_clock(h, 0.052)
		role = ROLE_BRACT
		bracts(h, 8, 0.018, 0.005, 1.4)
		role = 0.0
		rosette(4, Vector2(0.1, 0.13), 0.022, LANCE, 0.7, 0.1)
		# The gold head it blooms again with in the dandelion's round, on the
		# same neck, folded away while the clock stands (`flower_cycle`).
		var bloom := head(neck, Vector3(0.12, 1.0, 0.05), 0.042, 0.006, 0.8)
		bloom.scale = HEAD_SCALE["dandelion"]
		var gold := MeadowFlowerColor.of("ffd024")
		var deep := MeadowFlowerColor.of("f7b916")
		role = ROLE_GOLD
		kite_petals = true
		petals(bloom, 18, 0.008, 0.042, 0.011, deep, gold, 0.0, 0.08, 0.0, 0.08, 0.0, 0.08)
		petals(bloom, 8, 0.003, 0.02, 0.01, deep, gold, 0.0, 0.0, 0.0, 1.1, 0.4, 0.08)
		disc(bloom, 0.009, 0.012, 6, deep, deep, 0.0)
		kite_petals = false
		role = 0.0

	## Eight broad notched petals round a small gold disc, on a tall wiry
	## branching stem with thread-fine leaves; a closed bud beside.
	func cosmos() -> void:
		var pink := MeadowFlowerColor.of("e8609f")
		var blush := MeadowFlowerColor.of("d9518f")
		var tops := [[Vector3(0.03, 0.9, 0.0), Vector3(0.3, 1.0, 0.1), 0.062], [Vector3(-0.11, 0.78, 0.06), Vector3(-0.4, 1.0, 0.2), 0.055]]
		stem(Vector3.ZERO, tops[0][0], 0.004, Vector3(0.025, 0.0, -0.01), 5)
		stem(Vector3(0.008, 0.45, 0.0), tops[1][0], 0.003, Vector3(-0.03, 0.0, 0.02), 4)
		detail = true
		stem(Vector3(0.01, 0.6, 0.0), Vector3(0.09, 0.74, -0.06), 0.0025, Vector3(0.01, 0.0, 0.0), 3)
		detail = false
		for i in range(tops.size()):
			var top: Array = tops[i]
			var h := head(top[0], top[1], top[2], 0.004)
			petals(h, 8, top[2] * 0.2, top[2], top[2] * 0.62, blush, pink, 0.12, 0.0, 0.14, 0.04, rng.randf() * TAU, 0.04)
			disc(h, top[2] * 0.22, top[2] * 0.18, 8, MeadowFlowerColor.of("f2b51e"), MeadowFlowerColor.of("e39a12"), 0.4)
		detail = true
		var bud := head(Vector3(0.09, 0.74, -0.06), Vector3(0.2, 1.0, -0.1), 0.014, 0.008)
		bud.dome = bud.centre
		puff(bud, 0.012, MeadowFlowerColor.of("8a7a3c"), DISC, Vector2(0.94, 1.05), false)
		detail = false
		# Thread-fine leaves: narrow forks up the stem.
		for y: float in [0.14, 0.3, 0.48]:
			var a := rng.randf() * TAU
			for fork in [-0.5, 0.0, 0.5]:
				leaf(Vector3(0.008, y, 0.0), a + fork, 0.085, 0.009, 0.5, 0.7, SLIM, 0.0, 0.0, rng.randf_range(0.85, 1.0))

	## Tall and bright: a thick stem bending over at the top so the big head
	## turns its face up and out toward the sun side (local +x), a small
	## brown disc inside two long rings of gold petals, a green back, and a
	## few broad heart-shaped leaves. From the diorama camera the face is
	## mostly gold: the petals reach out to 2.6 disc radii.
	func sunflower() -> void:
		var gold := MeadowFlowerColor.of("ffd43a")
		var deep := MeadowFlowerColor.of("f6b01c")
		var face := Vector3(0.62, 0.72, 0.1).normalized()
		var neck := Vector3(0.1, 1.7, 0.01)
		stem(Vector3.ZERO, Vector3(0.0, 1.4, 0.0), 0.017, Vector3(0.02, 0.0, 0.0), 5, 5)
		hooked_stem(Vector3(0.0, 1.4, 0.0), neck, face, 0.012, 5, 4)
		var h := head(neck, face, 0.21, 0.02, 0.7)
		petals(h, 22, 0.075, 0.21, 0.042, deep, gold, 0.0, 0.08, 0.0, 0.02, 0.0, 0.05)
		petals(h, 16, 0.07, 0.18, 0.04, deep, gold, 0.0, 0.0, 0.0, 0.12, PI / 16.0, 0.05)
		disc(h, 0.08, 0.025, 10, MeadowFlowerColor.of("7a4a1c"), MeadowFlowerColor.of("4a2c12"), 0.3)
		bracts(h, 10, 0.06, 0.02, 0.5)
		var heart := [[0.0, 0.08], [0.12, 0.42], [0.35, 0.5], [0.6, 0.4], [0.82, 0.22]]
		var ys := [0.4, 0.75, 1.05]
		for i in range(ys.size()):
			var a := float(i) * 2.4 + 0.3
			var length := lerpf(0.32, 0.24, float(i) / ys.size())
			leaf(Vector3(0.0, ys[i], 0.0), a, length, length * 0.72, 0.55, 0.9, heart, 0.12, 0.0, rng.randf_range(0.78, 0.9))

	## Four broad scarlet petals cupped round a dark centre, each with a dark
	## basal blotch, on a wiry stem; a nodding bud and a few lobed leaves.
	func poppy() -> void:
		var red := MeadowFlowerColor.of("d92a1c")
		var blotch := MeadowFlowerColor.of("2a1410")
		var neck := Vector3(0.03, 0.58, 0.0)
		stem(Vector3.ZERO, neck, 0.0035, Vector3(0.035, 0.0, 0.01), 5)
		var h := head(neck, Vector3(0.15, 1.0, 0.05), 0.05, 0.004, 1.1)
		petals(h, 2, 0.004, 0.056, 0.064, blotch.lerp(red, 0.35), red, 0.32, 0.0, 0.0, 0.22, 0.0, 0.0)
		petals(h, 2, 0.004, 0.052, 0.06, blotch.lerp(red, 0.35), red, 0.42, 0.0, 0.0, 0.32, PI / 2.0, 0.0)
		disc(h, 0.011, 0.016, 7, MeadowFlowerColor.of("4c5a30"), MeadowFlowerColor.of("2b2a1c"), 0.4)
		var bud_neck := Vector3(-0.07, 0.42, 0.03)
		detail = true
		hooked_stem(Vector3(0.005, 0.2, 0.0), bud_neck, Vector3(-0.3, -1.0, 0.1), 0.0028)
		var bud := head(bud_neck, Vector3(-0.3, -1.0, 0.1), 0.016, 0.012)
		bud.dome = bud.centre
		puff(bud, 0.014, MeadowFlowerColor.of("5d7e36"), DISC, Vector2(0.94, 1.05), false)
		detail = false
		rosette(5, Vector2(0.08, 0.11), 0.026, LANCE, 0.7, 0.2)

	## A tapering spike of pea florets in whorls, open below and budded at
	## the tip, over palmate leaves of narrow leaflets.
	func lupine() -> void:
		var violet := MeadowFlowerColor.of("6a5ccc")
		var pale := MeadowFlowerColor.of("d4bfe6")
		var base := Vector3(0.0, 0.42, 0.0)
		stem(Vector3.ZERO, base, 0.006, Vector3(0.01, 0.0, 0.0), 4, 4)
		var h := head(base, Vector3.UP, 0.04, 0.0)
		h.axis = true
		h.dome = base
		h.centre = base + Vector3.UP * 0.2
		h.radius = 0.2
		tube([base, base + Vector3.UP * 0.4], [0.005, 0.002], 3)
		var whorls := 9
		for w in range(whorls):
			var t := float(w) / (whorls - 1)
			var y := base.y + 0.02 + t * 0.36
			var size := lerpf(0.025, 0.011, t)
			var color := violet.lerp(pale, smoothstep(0.55, 1.0, t))
			for k in range(4):
				var a := TAU * k / 4.0 + w * 0.8
				var out := Vector3(cos(a), 0.0, sin(a))
				var side := Vector3.UP.cross(out).normalized()
				var root := Vector3(0.0, y, 0.0) + out * 0.006
				var banner := root + out * size * 0.7 + Vector3.UP * size * 0.35
				var low: Array = headed(h, root + out * size * 0.3, color * 0.85, PETAL)
				var left: Array = headed(h, banner - side * size * 0.5, color, PETAL)
				var right: Array = headed(h, banner + side * size * 0.5, color, PETAL)
				var top: Array = headed(h, banner + Vector3.UP * size * 0.55 + out * size * 0.1, color.lerp(Color(1, 1, 1), 0.25), PETAL)
				quad(low, right, top, left)
				var keel: Array = headed(h, root + out * size - Vector3.UP * size * 0.1, color * 0.9, PETAL)
				tri(headed(h, root - side * size * 0.15, color * 0.8, PETAL), keel, headed(h, root + side * size * 0.15, color * 0.8, PETAL))
		# Palmate leaves on short stalks: seven narrow leaflets in a star.
		for i in range(3):
			var a := TAU * i / 3.0 + rng.randf() * 0.6
			var at := Vector3(cos(a), 0.0, sin(a)) * 0.06 + Vector3.UP * rng.randf_range(0.1, 0.2)
			tube([Vector3(0.0, at.y * 0.6, 0.0), at], [0.0025, 0.002], 3)
			for k in range(6):
				leaf(at, a + TAU * k / 6.0, 0.062, 0.014, 0.15, 0.4, SLIM, 0.2, 0.0, rng.randf_range(0.8, 0.95))

	## A tidy clump of wheat from one root (docs/scenic/wheat.md): six
	## straws in a short line along the clump's x (the row, as FlowerSowing
	## turns each record along it), each a faceted three-sided stalk bowing a
	## little, topped by an ear (a flattened four-sided spindle whose rings
	## turn half a facet each, so its outline zigzags kernel by kernel, with
	## one short awn at its tip), and a pair of slim blades low down along
	## the row. Narrow across, so the furrows between rows stay open. Authored
	## ripe: plump pale golden-cream ears, deepening toward their foot, over
	## darker ochre straw (WHEAT_*); the material greens it in spring (ears
	## lighter than straw, RIPEN_GREEN_*) and cuts it to stubble in winter
	## (RIPEN_KINDS). One record is one clump, so a field is a sixth as many
	## instances as it has straws.
	func wheat() -> void:
		stem_hex = WHEAT_STRAW
		leaf_hex = WHEAT_BLADE
		var gold := MeadowFlowerColor.of(WHEAT_EAR_TIP)
		var deep := MeadowFlowerColor.of(WHEAT_EAR_FOOT)
		var count := 6
		for i in range(count):
			var x := lerpf(-0.07, 0.07, (float(i) + rng.randf_range(0.2, 0.8)) / count)
			var foot := Vector3(x * 0.3, 0.0, rng.randf_range(-0.006, 0.006))
			# Fanned a little across the row too, so the heads close over
			# the furrow while the feet keep to their drill line.
			var out := Vector3(x, 0.0, rng.randf_range(-0.045, 0.045))
			var neck := out + Vector3.UP * rng.randf_range(0.36, 0.48)
			stem(foot, neck, WHEAT_STRAW_RADIUS, Vector3(0.0, 0.0, rng.randf_range(-0.012, 0.012)), 2, 3)
			# Each head leans its own way, some nodding with their weight.
			var lean := Vector3.UP + out * 2.0 + Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.16, 0.16))
			lean += Vector3(out.x, 0.0, out.z).normalized() * (rng.randf_range(0.15, 0.4) if rng.randf() < 0.35 else 0.0)
			ear(neck, lean.normalized(), rng.randf_range(0.11, 0.135), WHEAT_EAR_RADIUS, deep, gold)
		for k in range(2):
			var a := PI * k + rng.randf_range(-0.35, 0.35)
			leaf(Vector3(cos(a), 0.0, sin(a)) * 0.01 + Vector3.UP * rng.randf_range(0.12, 0.2), a, 0.15, 0.011, 0.5, 0.9, SLIM, 0.0, 0.0, rng.randf_range(0.85, 0.95))
		stem_hex = STEM_GREEN
		leaf_hex = LEAF_GREEN

	## One ear on `neck` heading `face`, `length` long and `radius` round,
	## `foot` to `tip` in colour: a slim spindle, fullest a third of the way
	## up and drawn to a point, with a fan of long awns from its upper half.
	## Its vertices nod with it about the neck; their normals run out from its
	## axis, so it shades as one spindle.
	func ear(neck: Vector3, face: Vector3, length: float, radius: float, foot: Color, tip: Color) -> void:
		var h := head(neck, face, length * 0.5, length * 0.5, 0.0)
		h.dome = h.centre
		var sides := 4
		var rows := [[0.12, 0.8], [0.42, 1.0], [0.76, 0.7]]
		var rings: Array = []
		for r in range(rows.size()):
			var t: float = rows[r][0]
			var ring: Array = []
			for k in range(sides):
				var angle := TAU * (float(k) + 0.5 * float(r % 2)) / sides
				# Flattened, two-rowed: the staggered rings cut its outline
				# into a zigzag of kernels seen from the side.
				var out: Vector3 = h.u * cos(angle) + h.v * sin(angle) * 0.62
				var v: Array = headed(h, neck + face * (length * t) + out * (radius * float(rows[r][1])), foot.lerp(tip, t), PETAL)
				v[1] = (out + face * 0.35).normalized()
				ring.append(v)
			rings.append(ring)
		var bottom: Array = headed(h, neck + face * 0.004, foot, PETAL)
		bottom[1] = -face
		var top: Array = headed(h, neck + face * length, tip, PETAL)
		top[1] = face
		var last: Array = rings[rings.size() - 1]
		for k in range(sides):
			var k2 := (k + 1) % sides
			tri(bottom, rings[0][k2], rings[0][k])
			tri(last[k], last[k2], top)
		for r in range(rings.size() - 1):
			for k in range(sides):
				var k2 := (k + 1) % sides
				tri(rings[r][k], rings[r][k2], rings[r + 1][k])
				tri(rings[r][k2], rings[r + 1][k2], rings[r + 1][k])
		# A fan of long awns from the upper half, splayed out along the ear's
		# flat face, so a field's top reads bristly: detail the far field goes
		# without.
		var was := detail
		detail = true
		var awn_tip := tip.lerp(Color(1, 1, 1), 0.25)
		for k in range(4):
			var side := -1.0 if k % 2 == 0 else 1.0
			var t := 0.5 + 0.13 * float(k)
			var root: Vector3 = neck + face * (length * t) + h.u * side * radius * 0.5
			var heading: Vector3 = (face + h.u * side * rng.randf_range(0.3, 0.55)).normalized()
			var reach := length * rng.randf_range(0.55, 0.75)
			var a: Array = headed(h, root - face * 0.006, tip, PETAL)
			var b: Array = headed(h, root + h.v * radius * 0.25, tip, PETAL)
			var end: Array = headed(h, root + heading * reach, awn_tip, PETAL)
			for v: Array in [a, b, end]: v[1] = (h.u * side + face).normalized()
			tri(a, b, end)
		detail = was

## Linear colours from sRGB hex, so the kinds read as their names.
class MeadowFlowerColor:
	static func of(hex: String) -> Color:
		return Color(hex).srgb_to_linear()
