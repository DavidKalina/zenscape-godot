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

## Batch keys for the spruce family: [trunk, canopy] per variant, in SPRUCE order.
## Named so scene_look roles and the "canopies" tint rule apply unchanged.
static func spruce_keys() -> Array:
	var keys := []
	for entry in SPRUCE:
		keys.append(["tree:spruce-%s-trunk" % entry[0], "tree:spruce-%s-canopies" % entry[0]])
	return keys

static func spruce_mesh(index: int, canopy: bool, material: Material) -> Mesh:
	var variant: String = SPRUCE[index][0]
	return _build(SPRUCE_GLB, "%s %s" % [variant, "canopy" if canopy else "trunk"], SPRUCE_SCALE, GREY, material)

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
