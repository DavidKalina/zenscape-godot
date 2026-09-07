class_name NativeAssetCatalog
extends RefCounted
## Compound placeable assets assembled from the reference's original meshes.
const PARTS := {
	"broadleaf":["mesh-11","broadleaf-canopies"],
	"shrub":["mesh-13"],
	"reeds":["mesh-14"],
	"bank_grass":["mesh-15"],
	"button_flower":["flower-stems","flowers-button"],
	"spike_flower":["flower-stems","flowers-spike"],
	"umbel_flower":["flower-stems","flowers-umbel"],
	"daisy_flower":["flower-stems","flowers-daisy"],
	"grass_tuft":["mesh-10"],
	"log":["logs"],
	"stump":["stumps"],
	"snag":["snags"],
	"mushroom":["fungus-stems","fungus-caps"],
	"boulder_1":["mesh-4"],
	"boulder_2":["mesh-5"],
	"boulder_3":["mesh-6"],
	"boulder_4":["mesh-7"]
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
	if original is MultiMeshInstance3D:
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
				var original: Node3D = source.get_node(node_name)
				var mesh: Mesh = original.multimesh.mesh if original is MultiMeshInstance3D else original.mesh
				_pivots[kind+":"+node_name] = part_pose(kind+":"+node_name,original,mesh)
		source.free()
	return _pivots
