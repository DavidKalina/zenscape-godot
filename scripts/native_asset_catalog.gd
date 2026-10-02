class_name NativeAssetCatalog
extends RefCounted
## Compound placeable assets assembled from the reference's original meshes.
const PARTS := {
	"cactus":["desert-cactus"],
	"joshua":["joshua-bark","joshua-thatch","joshua-blades"],
	"layered_tree":["layered-trunk","layered-canopies"],
	"redwood":["redwood-trunk","redwood-canopies"],
	"fern":["redwood-fern"],
	"broadleaf":["mesh-11","broadleaf-canopies"],
	"shrub":["mesh-13"],
	"reeds":["mesh-14"],
	"bank_grass":["mesh-15"],
	"button_flower":["flower-stems","flowers-button"],
	"spike_flower":["flower-stems","flowers-spike"],
	"umbel_flower":["flower-stems","flowers-umbel"],
	"daisy_flower":["flower-stems","flowers-daisy"],
	"oxeye_daisy":["meadow-flower-oxeye_daisy"],
	"buttercup":["meadow-flower-buttercup"],
	"dandelion":["meadow-flower-dandelion"],
	"dandelion_clock":["meadow-flower-dandelion_clock"],
	"cosmos":["meadow-flower-cosmos"],
	"sunflower":["meadow-flower-sunflower"],
	"poppy":["meadow-flower-poppy"],
	"lupine":["meadow-flower-lupine"],
	"grass_tuft":["mesh-10"],
	"log":["logs"],
	"stump":["stumps"],
	"snag":["snags"],
	"mushroom":["fungus-stems","fungus-caps"],
	"boulder_1":["mesh-4"],
	"boulder_2":["mesh-5"],
	"boulder_3":["mesh-6"],
	"boulder_4":["mesh-7"],
	"birch":["birch-trunk","birch-canopies"],
	"willow":["willow-trunk","willow-canopies"],
	"juniper":["juniper-trunk","juniper-deadwood","juniper-canopies"]
}
## Source stems stretch per form to meet the head geometry (foliage.js `stem`).
const STEM_SCALE := {"spike_flower:flower-stems":2.1,"daisy_flower:flower-stems":1.15}
static var _pivots := {}

## The part's transform relative to its record: stem stretch for flower forms,
## and for the single-mesh boulders the source orientation with the visible
## base as the placement pivot.
static func part_pose(key: String, original: Node3D, mesh: Mesh) -> Transform3D:
	if STEM_SCALE.has(key):
		return Transform3D(Basis.from_scale(Vector3(1.0,STEM_SCALE[key],1.0)),Vector3.ZERO)
	if original is MultiMeshInstance3D or original.name.begins_with("redwood-") or original.name.begins_with("layered-") or original.name.begins_with("joshua-") or preload("res://scripts/hero_trees.gd").species_of(original.name) != "":
		return Transform3D.IDENTITY
	# Meadow flowers stand on their root, wherever their heads lean.
	if preload("res://scripts/meadow_flower_mesh.gd").is_node(original.name):
		return Transform3D.IDENTITY
	var pose := Transform3D(original.basis,Vector3.ZERO)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bounds := AABB(pose*vertices[0],Vector3.ZERO)
	for vertex in vertices:
		bounds = bounds.expand(pose*vertex)
	pose.origin = -Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	return pose

## Every part pose keyed "kind:node", read once from the reference geometry.
static func pivots() -> Dictionary:
	if _pivots.is_empty():
		var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
		for kind in PARTS:
			for node_name in PARTS[kind]:
				var original: Node3D = source_node(source,node_name)
				var mesh: Mesh = original.multimesh.mesh if original is MultiMeshInstance3D else original.mesh
				_pivots[kind+":"+node_name] = part_pose(kind+":"+node_name,original,mesh)
		source.free()
	return _pivots

static func source_node(source: Node3D, node_name: String) -> Node3D:
	if source.has_node(node_name): return source.get_node(node_name)
	if preload("res://scripts/meadow_flower_mesh.gd").is_node(node_name):
		var flower := MeshInstance3D.new()
		flower.name = node_name
		flower.mesh = preload("res://scripts/meadow_flower_mesh.gd").mesh(node_name.trim_prefix(preload("res://scripts/meadow_flower_mesh.gd").NODE_PREFIX))
		source.add_child(flower)
		return flower
	if node_name == "desert-cactus":
		var cactus := MeshInstance3D.new()
		cactus.name = node_name
		cactus.mesh = preload("res://scripts/desert_assets.gd").new()._cactus(2)
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/reference_surface.gdshader")
		material.set_shader_parameter("base_color",Color("5e7d4a"))
		material.set_shader_parameter("flat_faces",true)
		cactus.mesh.surface_set_material(0,material)
		source.add_child(cactus)
		return cactus
	if node_name.begins_with("joshua-"):
		var joshua := MeshInstance3D.new()
		joshua.name = node_name
		joshua.mesh = preload("res://scripts/hero_trees.gd").joshua_mesh(node_name)
		source.add_child(joshua)
		return joshua
	if preload("res://scripts/hero_trees.gd").species_of(node_name) != "":
		var species := MeshInstance3D.new()
		species.name = node_name
		species.mesh = preload("res://scripts/hero_trees.gd").species_mesh(node_name)
		source.add_child(species)
		return species
	if node_name.begins_with("layered-"):
		var tree := preload("res://scripts/layered_tree.gd").new()
		tree._ready()
		for pair in [["Branchwork","layered-trunk"],["Crown","layered-canopies"]]:
			var part: MeshInstance3D = tree.get_node(pair[0])
			tree.remove_child(part)
			part.name = pair[1]
			part.mesh.surface_set_material(0,part.material_override)
			source.add_child(part)
		tree.free()
		return source.get_node(node_name)
	assert(node_name.begins_with("redwood-"))
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = preload("res://scripts/redwood_assets.gd").mesh(node_name)
	source.add_child(node)
	return node
