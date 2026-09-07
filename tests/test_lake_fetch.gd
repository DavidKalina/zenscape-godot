extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://assets/zen_reference/geometry.scn").instantiate()
	root.add_child(scene)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	var wind: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/lake-wind.json"))
	var max_error := 0.0
	var values := 0
	for entry: Dictionary in source.meshes:
		if entry.count > 0:
			var instances: MultiMesh = scene.get_node(entry.name).multimesh
			for i in range(int(entry.count)):
				var actual := instances.get_instance_transform(i)
				var expected := Vector3(entry.instances[i*16+12], entry.instances[i*16+13], entry.instances[i*16+14])
				check(actual.origin.distance_to(expected) < 0.00002, "Saved instance translation survives native import: " + entry.name)
				for axis in range(3):
					var column := Vector3(entry.instances[i*16+axis*4], entry.instances[i*16+axis*4+1], entry.instances[i*16+axis*4+2])
					check(actual.basis[axis].distance_to(column) < 0.00002, "Saved instance basis survives native import: " + entry.name)
		if not wind.has(entry.name): continue
		var node: MeshInstance3D = scene.get_node(entry.name)
		var arrays := node.mesh.surface_get_arrays(0)
		var count: int = arrays[Mesh.ARRAY_VERTEX].size()
		for pair in [[Mesh.ARRAY_CUSTOM0, "aFetchA"], [Mesh.ARRAY_CUSTOM1, "aFetchB"]]:
			var native: PackedFloat32Array = arrays[pair[0]]
			var expected: Array = wind[entry.name][pair[1]].array
			check(native.size() == count * 4, "Every native lake vertex has four fetch values per channel")
			for i in range(0, count, 3):
				var ids := [i, i + 2, i + 1]
				for j in range(3):
					var index: int = int(entry.index[ids[j]]) if entry.index != null else ids[j]
					for axis in range(4):
						max_error = maxf(max_error, absf(native[(i+j)*4+axis]-expected[index*4+axis]))
						values += 1
		var material := node.mesh.surface_get_material(0)
		check(absf(material.get_shader_parameter("lake_swell") - wind[entry.name].look[2]) < 0.00001, "Source lake's swell response is retained")
	check(values > 1000 and max_error < 0.00001, "Fetch values survive source indexing and native winding: " + str(max_error))
	scene.queue_free()
	await process_frame
	print("PASS: source lake fetch import and swell response, ", values, " values" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
