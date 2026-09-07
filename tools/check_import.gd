extends SceneTree

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this check with a graphics renderer; the headless dummy renderer does not retain MultiMesh buffers.")
		quit(1)
		return
	_check_import.call_deferred()

func _check_import() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	var scene: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	await process_frame
	var failures := 0
	var instances := 0
	if scene.get_child_count() != source.meshes.size():
		failures += 1
	for i in range(scene.get_child_count()):
		var node: Node3D = scene.get_child(i)
		var entry: Dictionary = source.meshes[i]
		if node is MultiMeshInstance3D:
			instances += node.multimesh.instance_count
			for index in range(node.multimesh.instance_count):
				var offset := index * 16
				var expected := Vector3(entry.instances[offset + 12], entry.instances[offset + 13], entry.instances[offset + 14])
				if node.multimesh.get_instance_transform(index).origin.distance_to(expected) > 0.00001:
					failures += 1
	if failures:
		push_error("Imported geometry checks failed: %d" % failures)
	else:
		print("PASS: %d native mesh groups; all %d instance positions match the source" % [scene.get_child_count(), instances])
	scene.free()
	quit(1 if failures else 0)
