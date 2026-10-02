extends SceneTree
## Builds every meadow flower kind (scripts/meadow_flower_mesh.gd) and prints
## its size and triangle count. Headless:
##   Godot --headless --path . -s res://tools/probe_meadow_flowers.gd
const Kit := preload("res://scripts/meadow_flower_mesh.gd")

func _initialize() -> void:
	for kind: String in Kit.KINDS:
		var mesh: ArrayMesh = Kit.mesh(kind)
		var arrays := mesh.surface_get_arrays(0)
		var box := mesh.get_aabb()
		print("%-16s height %.2f m, width %.2f x %.2f m, %d vertices, %d triangles" % [kind, box.end.y, box.size.x, box.size.z, (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
	quit()
