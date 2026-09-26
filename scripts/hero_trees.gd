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

static var _scenes := {}

static func enabled() -> bool:
	return not ("--classic-trees" in OS.get_cmdline_user_args() or "--classic-trees" in OS.get_cmdline_args())

## The replacement for a catalog part, carrying the original's material; or the original.
static func swap(node_name: String, original: Mesh) -> Mesh:
	if not enabled() or not SWAPS.has(node_name): return original
	var entry: Array = SWAPS[node_name]
	return _build(entry[0], entry[1], entry[2], entry[3], original.surface_get_material(0))

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
		_scenes[path] = load(path).instantiate()
	var node := (_scenes[path] as Node).find_child(node_name, true, false) as MeshInstance3D
	assert(node != null, "%s has no mesh %s" % [path, node_name])
	var arrays := node.mesh.surface_get_arrays(0)
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
