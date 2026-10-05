extends RefCounted
## The plate the game plays on, for tests that build terrain data: the made
## mesh (scripts/plate_mesh.gd) wearing the authored terrain's material from
## assets/zen_reference/geometry.scn, as studies/fidelity.gd puts it on the
## scene (marked as PlateMesh.adopt marks it). One mesh for the whole run,
## so data set up twice shares it.

const PlateMesh := preload("res://scripts/plate_mesh.gd")

static var _mesh: ArrayMesh

## The plate's terrain mesh.
static func mesh() -> ArrayMesh:
	if _mesh == null:
		var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
		_mesh = PlateMesh.build(source.get_node("terrain").mesh.surface_get_material(0))
		_mesh.set_meta(&"plate_mesh",true)
		source.free()
	return _mesh

## Puts the plate on an instanced geometry.scn's terrain node in place of
## the authored mesh, as the game does before anything reads the scene.
static func dress(scene: Node) -> Node:
	scene.get_node("terrain").mesh = mesh()
	return scene
