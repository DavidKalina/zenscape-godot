extends RefCounted
## Blender-authored trees (tools/blender_trees) behind the existing catalog parts.
## Geometry is swapped; each part keeps the reference material, wind and tint, so
## everything that reads a part key (roles, tread, fire, selection) is unchanged.
## `--classic-trees` restores the source meshes for comparison.

## node name -> [glb, mesh node, scale, colour mode]. Scale matches the source
## part's height. Colour modes:
## TINT: baked colour becomes greyscale light and shade; the per-tree tint gives the hue.
## OWN: baked colour is the final colour; the material's base colour goes white.
## GREY: the bake is already greyscale; the material's base colour gives the hue.
enum {TINT, OWN, GREY}
const SWAPS := {
	"mesh-11": ["res://assets/models/zenscape-hero-oak.glb", "Bark", Vector3(0.27, 0.36, 0.27), OWN],
	"broadleaf-canopies": ["res://assets/models/zenscape-hero-oak.glb", "Leaves", Vector3(0.27, 0.36, 0.27), TINT],
	"redwood-trunk": ["res://assets/models/zenscape-hero-redwood.glb", "Bark", Vector3(0.6, 0.93, 0.6), OWN],
	"redwood-canopies": ["res://assets/models/zenscape-hero-redwood.glb", "Foliage", Vector3(0.6, 0.93, 0.6), OWN],
}
const SPRUCE_GLB := "res://assets/models/zenscape-spruce-family.glb"
## `--spruce=sprays`: the same six variants rebuilt as drooping bough sprays with
## a sawtooth needle fringe (tools/blender_trees/spruce_sprays.py).
const SPRUCE_LOOKS := {"sprays":"res://assets/models/zenscape-spruce-sprays.glb"}
## Looks whose glb also holds a coarser far crown per variant, which the
## endless land draws past its detail distance (land_trees.gd DETAIL).
const SPRUCE_FAR := ["res://assets/models/zenscape-spruce-sprays.glb"]
## The source pine stands 4.26 m and 1.2 m wide; the family keeps that width and
## height while the variants keep their differences.
const SPRUCE_SCALE := Vector3(1.0, 1.46, 1.0)
## Variant and how often it grows. Dead tops are rare accents.
const SPRUCE := [["mature", 4.0], ["young", 2.0], ["spire", 2.0], ["windswept", 1.5], ["sparse", 1.5], ["dead-top", 0.5]]

## Joshua trees are their own asset kind, so they bring their own material.
const JOSHUA_GLB := "res://assets/models/zenscape-hero-joshua.glb"
const JOSHUA := {"joshua-bark":["Bark",4], "joshua-thatch":["Thatch",4], "joshua-blades":["Blades",2]}
const JOSHUA_SCALE := Vector3(0.85, 0.85, 0.85)

## Birch, willow and juniper are their own asset kinds too: part node -> [glb
## mesh, palette role, colour mode]. Crowns are TINT, so the per-tree tint gives
## the species colour (tree_stands.gd TREE_COLOURS) and `tint` stands in when a
## record has none. Scales bring them to `height` metres at record scale 1,
## which is also the whole-tree wind bend height (stiffer when above it).
const SPECIES := {
	"birch":{"glb":"res://assets/models/zenscape-hero-birch.glb","scale":0.44,"height":3.4,"tint":"86a24c","autumn_yellow":1.0,
		"parts":{"birch-trunk":["Bark",4,OWN],"birch-canopies":["Crown",2,TINT]}},
	"willow":{"glb":"res://assets/models/zenscape-hero-willow.glb","scale":0.44,"height":2.7,"tint":"86a050",
		"parts":{"willow-trunk":["Bark",4,OWN],"willow-canopies":["Crown",2,TINT]}},
	# Stiff and wind-shaped: bends as if twice its height.
	"juniper":{"glb":"res://assets/models/zenscape-hero-juniper.glb","scale":0.5,"height":3.2,"tint":"527d5e",
		"parts":{"juniper-trunk":["Bark",4,OWN],"juniper-deadwood":["Deadwood",4,OWN],"juniper-canopies":["Crown",2,TINT]}},
}

## Each glb's meshes by node name; the instance is freed once read.
static var _scenes := {}

static func enabled() -> bool:
	return not ("--classic-trees" in preload("res://scripts/launch_args.gd").user_args() or "--classic-trees" in OS.get_cmdline_args())

## The replacement for a catalog part, carrying the original's material; or the original.
static func swap(node_name: String, original: Mesh) -> Mesh:
	if not enabled() or not SWAPS.has(node_name): return original
	var entry: Array = SWAPS[node_name]
	var built := _build(entry[0], entry[1], entry[2], entry[3], original.surface_get_material(0))
	# The oak grows two limbs for songbirds to sit on (scripts/perch_limbs.gd).
	if node_name == "mesh-11": built = preload("res://scripts/perch_limbs.gd").add_to(built)
	return built

## The spruce family's glb: `--spruce=<look>` picks one of SPRUCE_LOOKS.
static func spruce_glb() -> String:
	## Sprays is the default; `--spruce=family` brings back the old faceted family.
	for a in preload("res://scripts/launch_args.gd").user_args():
		if a == "--spruce=family": return SPRUCE_GLB
		if a.begins_with("--spruce=") and SPRUCE_LOOKS.has(a.get_slice("=",1)): return SPRUCE_LOOKS[a.get_slice("=",1)]
	return SPRUCE_LOOKS["sprays"]

## The sprays look's painted crown (shaders/spruce_paint.gdshaderinc): the
## crown lit as a volume, a blue spruce's blue and the world's painted
## patches and stepped light. Knobs (each `--spruce-<knob>=X`; `--spruce-paint=off`
## turns it all off to compare): round, blue, dabs, wrap, glow.
const SPRUCE_PAINT := {"round":0.7, "blue":1.0, "dabs":1.0, "wrap":1.0, "glow":0.35, "fill":2.6, "warm":1.0, "flat":1.25, "fine":3.0, "farlift":2.0,
	"steps":0.25, "soft":0.5, "speck":1.0, "floor":0.85, "olive":1.0, "hemiolive":0.85, "farblue":0.6, "farbaked":0.4, "texgain":1.0,
	"value":1.0, "bfar":1.0, "midlift":0.965, "ringlift":0.965, "ringgain":1.0}
## The default texture b's own knobs over SPRUCE_PAINT (round 5): a little darker,
## the lit and shaded sides alike (`value`; `flat` and `floor` lift the darks so the
## lit/shaded ratio does not rise), and its micro-facets' mean tone kept on
## the distance crowns (`bfar`).
const SPRUCE_B := {"value":0.85, "bfar":0.985, "flat":1.6, "floor":0.95}
const SPRUCE_R3 := {"blue":0.85, "fill":2.2, "flat":1.0, "farlift":1.45, "steps":0.7, "soft":0.18, "speck":0.0, "floor":0.5, "olive":0.0, "hemiolive":0.0, "farblue":1.0, "farbaked":0.75}

## `--spruce-look=g` (docs/design/endless-flight/spruce-plastic-handoff.md,
## round 1, the groundwork), over the default look; each part has its own knob
## (`--spruce-<knob>=X`, only with look g) and 0 turns that part off:
## - bshare, bgrove, blean, bgreen: the share of blue spruces (0..1), the grove
##   scale (m: a low-frequency hash of the world, so a patch shares a lean), how
##   far a grove moves the share (0 none, 1 a whole grove one colour), the little
##   blue a green tree keeps (0..1, over the blue knob);
## - inner, fresh: the older inner needles darker and olive, the fresh outer
##   tips lighter (0..1), from the bake's grey and not eased with distance;
## - haze: a wood keeps its outline at 100 to 300 m (saturation up, a little
##   darker, 0..1; the engine's own fog is about 1 % there, so this is the crowns'
##   own wash, not a fog share);
## - rim, rimwarm, rimday, rimtip: the backlit glow on the silhouette
##   (ZS_BACKLIGHT_SPRUCE's 3.0 times rim/3), its hue's share of a saturated
##   yellow-green, a floor for it by day (zs_backlight is 0 above sun height
##   0.42), and the fresh tips' share of it;
## - flat: the bake's flattening (1.6 with texture b by default, 1.0 here, so the
##   inner/fresh shading shows).
const SPRUCE_G := {"bshare":0.3, "bgrove":160.0, "blean":0.5, "bgreen":0.1, "inner":0.9, "fresh":0.9, "haze":0.6,
	"rim":5.0, "rimwarm":0.7, "rimday":0.3, "rimtip":0.5, "flat":1.0}

## `--spruce-look=b` (round 2, painterly): g plus these (each `--spruce-<knob>=X`,
## only with look b; 0 turns that part off), shaders/spruce_tiers.gdshaderinc:
## - tilt: the light normal tipped by its place on the tier (up high on it, out
##   and down at the skirt), so the painted steps break across each tier;
## - band, top: a dark cool band under each tier's skirt and a lit warm top, in
##   the albedo (0..1);
## - coolshade: the shade's hue from round 4's olive (0) to a cool blue-green (1);
## - warmlit: the lit side's warm yellow-green (0..1);
## - fardab, dabpx, dabfrom: painted dabs in place of texture b's facets, their gain,
##   their width in pixels (their size grows with distance) and the distance (m)
##   they come in from;
## - steps, soft: the sun's three painted steps made crisper (0.7 and 0.15; the
##   default look's are 0.25 and 0.5).
const SPRUCE_BL := {"tilt":1.8, "band":1.0, "top":1.0, "coolshade":0.25, "warmlit":0.8, "fardab":2.0, "dabpx":5.0, "dabfrom":110.0,
	"steps":0.7, "soft":0.15, "texgain":0.55, "inner":0.6, "fresh":0.7}

## The painted crown's knobs for the picked look ({} when it has none).
static func spruce_paint_knobs() -> Dictionary:
	if spruce_glb() != SPRUCE_LOOKS["sprays"]: return {}
	var knobs := SPRUCE_PAINT.duplicate()
	if spruce_texture() == 2: knobs.merge(SPRUCE_B, true)
	var args: PackedStringArray = preload("res://scripts/launch_args.gd").user_args()
	for a in args:
		if a == "--spruce-paint=off": return {}
		if a == "--spruce-look=r3": knobs.merge(SPRUCE_R3, true)
		if a == "--spruce-look=g": knobs.merge(SPRUCE_G, true)
		if a == "--spruce-look=b":
			knobs.merge(SPRUCE_G, true)
			knobs.merge(SPRUCE_BL, true)
		if a == "--spruce-look=r2": knobs.merge({"wrap":0.6, "fill":0.6, "warm":0.0, "flat":0.0, "blue":0.85, "fine":1.0, "farlift":1.0, "steps":0.7, "soft":0.18, "speck":0.0, "floor":0.5, "olive":0.0, "hemiolive":0.0, "farblue":1.0, "farbaked":0.75}, true)
	for a in args:
		for k in knobs:
			if a.begins_with("--spruce-%s=" % k): knobs[k] = float(a.get_slice("=",1))
	return knobs

## The g and b looks' shader uniforms (spruce_var, spruce_g, spruce_rim, and under b spruce_tier, spruce_tier2 in
## reference_surface, the rings and the sprites) from the knobs; {} when the
## look is not g (the shaders' zeros are the default look).
static func spruce_g_uniforms(knobs: Dictionary) -> Dictionary:
	if not knobs.has("bgrove"): return {}
	var u := {"spruce_var":Vector4(knobs.bshare,knobs.bgrove,knobs.blean,knobs.bgreen),
		"spruce_g":Vector4(knobs.inner,knobs.fresh,knobs.haze,-1.0),
		"spruce_rim":Vector4(knobs.rim,knobs.rimwarm,knobs.rimday,knobs.rimtip)}
	# The b look (SPRUCE_BL).
	if knobs.has("tilt"):
		u["spruce_tier"] = Vector4(knobs.tilt,knobs.band,knobs.top,knobs.coolshade)
		u["spruce_tier2"] = Vector4(knobs.warmlit,knobs.fardab,knobs.dabpx,knobs.dabfrom)
	return u

## Puts the painted crown on a crown material; `tint` is the crowns'
## instance tint (so the shader can read the grey bake back out of COLOR).
static func spruce_paint(material: Material, tint: Color) -> void:
	var knobs := spruce_paint_knobs()
	if knobs.is_empty() or not material is ShaderMaterial: return
	var m := material as ShaderMaterial
	m.set_shader_parameter("spruce_round",knobs.round)
	m.set_shader_parameter("spruce_blue",knobs.blue)
	m.set_shader_parameter("spruce_paint",knobs.dabs)
	m.set_shader_parameter("spruce_light",Vector4(knobs.wrap,knobs.glow,knobs.steps,knobs.soft))
	m.set_shader_parameter("spruce_tone",Vector4(knobs.fill,knobs.warm,knobs.flat,knobs.fine))
	m.set_shader_parameter("spruce_tone2",Vector4(knobs.speck,knobs.floor,knobs.olive,knobs.hemiolive))
	m.set_shader_parameter("spruce_bake_luma",maxf(tint.get_luminance(),0.001))
	m.set_shader_parameter("spruce_texture",spruce_texture())
	m.set_shader_parameter("spruce_texture_gain",knobs.texgain)
	m.set_shader_parameter("spruce_value",Vector2(knobs.value,knobs.bfar))
	var g := spruce_g_uniforms(knobs)
	for k: String in g: m.set_shader_parameter(k,g[k])

## `--spruce-texture=off|a|b|c`: a texture variant on the sprays crown, b (micro-facets,
## the glb's "<variant> canopy b") by default (round 5); off is the round-4 look, a a
## per-bough gradient and tone, c dabs along the boughs. `--spruce-texgain=` scales it.
const SPRUCE_TEXTURES := {"a":1, "b":2, "c":3}
static func spruce_texture() -> int:
	if spruce_glb() != SPRUCE_LOOKS["sprays"]: return 0
	for a in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--spruce-texture="): return SPRUCE_TEXTURES.get(a.get_slice("=",1),0)
	return 2

## The far rings' crown colour under the picked look: the sprays' blue, as
## the shader puts it on the near crowns (spruce_paint.gdshaderinc, at a
## middling tree's share).
static func spruce_far_albedo(albedo: Color) -> Color:
	var knobs := spruce_paint_knobs()
	if knobs.is_empty(): return albedo
	var l := albedo.get_luminance()
	var glaucous := Color(0.54,1.115,1.205).lerp(Color(1,1,1),0.12)*l
	var c := albedo.lerp(glaucous,clampf(knobs.blue*0.87*knobs.farblue,0.0,1.0))
	return Color(c.r*knobs.farlift,c.g*knobs.farlift,c.b*knobs.farlift)

## How much of the far rings' baked light and shade shows (the plain value off the sprays look).
static func spruce_far_baked(plain: float) -> float:
	var knobs := spruce_paint_knobs()
	return plain if knobs.is_empty() else knobs.farbaked

## Batch keys for the spruce family: [trunk, canopy] per variant, in SPRUCE order.
## Named so scene_look roles and the "canopies" tint rule apply unchanged.
static func spruce_keys() -> Array:
	var keys := []
	for entry in SPRUCE:
		keys.append(["tree:spruce-%s-trunk" % entry[0], "tree:spruce-%s-canopies" % entry[0]])
	return keys

static func spruce_mesh(index: int, canopy: bool, material: Material) -> Mesh:
	var variant: String = SPRUCE[index][0]
	var part := "canopy b" if canopy and spruce_texture() == 2 else ("canopy" if canopy else "trunk")
	return _build(spruce_glb(), "%s %s" % [variant, part], SPRUCE_SCALE, GREY, material)

## True when the picked look carries a far level of detail ("<variant> canopy far").
static func spruce_has_far() -> bool:
	return spruce_glb() in SPRUCE_FAR

## A variant's crown in the default look (the faceted family), whatever look is picked.
static func spruce_family_crown(index: int, material: Material) -> Mesh:
	return _build(SPRUCE_GLB, "%s canopy" % SPRUCE[index][0], SPRUCE_SCALE, GREY, material)

## A variant's distance crowns (spruce_has_far looks only), the same generator's
## tiers and drooping boughs with fewer faces: "mid" (land_trees.gd, 200 to 400 m)
## and "low" (the mid and far rings).
static func spruce_mid_mesh(index: int, material: Material) -> Mesh:
	return _build(spruce_glb(), "%s canopy mid" % SPRUCE[index][0], SPRUCE_SCALE, GREY, material)

static func spruce_low_mesh(index: int, material: Material) -> Mesh:
	return _build(spruce_glb(), "%s canopy low" % SPRUCE[index][0], SPRUCE_SCALE, GREY, material)

## A variant's far crown (spruce_has_far looks only).
static func spruce_far_mesh(index: int, material: Material) -> Mesh:
	return _build(spruce_glb(), "%s canopy far" % SPRUCE[index][0], SPRUCE_SCALE, GREY, material)

static func joshua_mesh(node_name: String) -> Mesh:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("flat_faces",true)
	material.set_shader_parameter("plant_growth",true)
	# Stiff: the whole-tree bend is measured against a much taller tree.
	material.set_shader_parameter("conifer_sway",true)
	material.set_shader_parameter("conifer_height",7.0)
	return _build(JOSHUA_GLB,JOSHUA[node_name][0],JOSHUA_SCALE,OWN,material)

## The species a part node belongs to, or "".
static func species_of(node_name: String) -> String:
	var kind := node_name.get_slice("-",0)
	return kind if SPECIES.has(kind) and SPECIES[kind].parts.has(node_name) else ""

static func species_mesh(node_name: String) -> Mesh:
	var entry: Dictionary = SPECIES[species_of(node_name)]
	var part: Array = entry.parts[node_name]
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("flat_faces",true)
	material.set_shader_parameter("plant_growth",true)
	# Trunk and crown bend as one tree, so the crown never slides off its limbs.
	material.set_shader_parameter("conifer_sway",true)
	material.set_shader_parameter("conifer_height",float(entry.height))
	if part[2] == TINT: material.set_shader_parameter("autumn_yellow",float(entry.get("autumn_yellow",0.0)))
	return _build(entry.glb,part[0],Vector3.ONE*float(entry.scale),part[2],material)

## A species part's palette role, or -1 when the key is not one.
static func species_role(key: String) -> int:
	var node_name := key.get_slice(":",1)
	var kind := species_of(node_name)
	return SPECIES[kind].parts[node_name][1] if kind != "" and key.get_slice(":",0) == kind else -1

## The crown colour a species part shows when its record carries no tint.
static func species_tint(node_name: String, fallback: Color) -> Color:
	var kind := species_of(node_name)
	if kind == "" or SPECIES[kind].parts[node_name][2] != TINT: return fallback
	return Color(SPECIES[kind].tint).srgb_to_linear()

## Stable weighted choice per tree record, so a tree keeps its variant across rebuilds.
static func spruce_index(item: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([item.get("id", 0), snappedf(float(item.x), 0.01), snappedf(float(item.z), 0.01)])
	var total := 0.0
	for entry in SPRUCE: total += entry[1]
	var roll := rng.randf() * total
	for i in range(SPRUCE.size()):
		roll -= SPRUCE[i][1]
		if roll <= 0.0: return i
	return 0

static func _build(path: String, node_name: String, scale: Vector3, mode: int, material: Material) -> ArrayMesh:
	if not _scenes.has(path):
		var scene: Node = load(path).instantiate()
		var meshes := {}
		for part: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if not meshes.has(part.name): meshes[String(part.name)] = part.mesh
		scene.free()
		_scenes[path] = meshes
	var source: Mesh = _scenes[path].get(node_name)
	assert(source != null, "%s has no mesh %s" % [path, node_name])
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		vertices[i] *= scale
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(normals.size()):
			normals[i] = (normals[i] / scale).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	if mode == TINT and arrays[Mesh.ARRAY_COLOR] != null:
		arrays[Mesh.ARRAY_COLOR] = _greyscale(arrays[Mesh.ARRAY_COLOR])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		var own := material.duplicate()
		# The baked colours carry the part's own hue; a tinted base would darken them twice.
		if mode == OWN and own is ShaderMaterial: own.set_shader_parameter("base_color", Color.WHITE)
		mesh.surface_set_material(0, own)
	return mesh

## Keep brightest-to-darkest variation, drop the hue; mean luminance lands near 0.85.
static func _greyscale(colors: PackedColorArray) -> PackedColorArray:
	var mean := 0.0
	for c in colors: mean += c.get_luminance()
	mean = maxf(mean / maxf(colors.size(), 1), 0.001)
	var out := PackedColorArray()
	out.resize(colors.size())
	for i in range(colors.size()):
		var v := clampf(colors[i].get_luminance() / mean * 0.85, 0.35, 1.1)
		out[i] = Color(v, v, v, colors[i].a)
	return out
