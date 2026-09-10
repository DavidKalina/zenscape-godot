extends RefCounted
## Run Godot's existing convex cleaner against retained CPU vertices. This
## adapter is never rendered and never creates an ArrayMesh/upload/readback.
## Shape creation stays on the main thread with the other physics resources.
class CpuMesh extends Mesh:
	var arrays: Array
	func _get_surface_count() -> int: return 1
	func _surface_get_arrays(_index: int) -> Array: return arrays

static func build(vertices: PackedVector3Array) -> ConvexPolygonShape3D:
	var source := CpuMesh.new()
	source.arrays = []
	source.arrays.resize(Mesh.ARRAY_MAX)
	source.arrays[Mesh.ARRAY_VERTEX] = vertices
	return source.create_convex_shape(true,false)
