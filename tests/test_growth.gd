extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/growth.json"))
	# The scene's land is the made plate now; the authored terrain these
	# attributes were exported from is still in the asset.
	var asset: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	for name: String in source:
		var node: MeshInstance3D = asset.get_node(name) if name == "terrain" else scene.get_node("Reference/" + name)
		var arrays := node.mesh.surface_get_arrays(0)
		var attrs: Dictionary = source[name]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var meadow: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		var max_error := 0.0
		for i in range(vertices.size()):
			var index: int = (i / 3) * 3 + [0, 2, 1][i % 3]
			max_error = maxf(max_error, absf(uv[i].x - attrs.aDelay.array[index]))
			max_error = maxf(max_error, absf(uv[i].y - attrs.aHold.array[index]))
			max_error = maxf(max_error, absf(uv2[i].x - attrs.aDirt.array[index]))
			max_error = maxf(max_error, absf(uv2[i].y - attrs.aTo.array[index]))
			for axis in range(3):
				max_error = maxf(max_error, absf(meadow[i * 3 + axis] - attrs.aBaseColor.array[index * 3 + axis]))
			check(absf(uv2[i].y - vertices[i].y) < 0.00001, "Full growth retains imported vertex height")
		check(max_error < 0.00001, "All source growth attributes survive winding conversion: " + name)
	asset.free()
	var growth: RefCounted = scene._growth
	var encounter = scene._bigfoot
	var tree_rest: Transform3D = encounter._tree.transform
	encounter.update_growth(1.0,0.5)
	check(encounter.visible and encounter._tree.basis.x.length() < tree_rest.basis.x.length(), "Shelter tree grows from its anchor with foliage")
	encounter.update_growth(0.5,1.0)
	check(not encounter.visible, "Shelter tree stays hidden over unfinished terrain")
	encounter.update_growth(1.0,1.0)
	check(encounter._tree.transform.is_equal_approx(tree_rest), "Full growth restores the shelter tree asset transform")
	var boulders: Array[Transform3D] = []
	for name in ["mesh-4","mesh-5","mesh-6","mesh-7"]:
		boulders.append(scene.get_node("Reference/"+name).transform)
	growth.set_terrain(0.82)
	var arriving: Node3D = scene.get_node("Reference/mesh-4")
	check(arriving.visible and arriving.basis.x.length() < boulders[0].basis.x.length(), "Boulders rise and scale in before terrain completes")
	check(not scene.get_node("Reference/mesh-7").visible, "Boulder arrivals are staggered")
	growth.replay()
	check(growth.terrain == 0.0 and growth.foliage == 0.0 and growth.water == 0.0, "Replay starts at bare earth")
	growth.advance(1.0, true, scene._tremor)
	check(growth.terrain == 0.0 and growth.foliage == 0.0 and growth.water == 0.0, "Pause freezes formation")
	growth.advance(0.5, false, scene._tremor)
	check(absf(growth.terrain - (1.0 - exp(-0.7))) < 0.00001, "Terrain follows original conductor response")
	check(growth.foliage == 0.0, "Replay waits for land before plants")
	check(scene._tremor.trauma > 0.0, "Positive formation produces source tremor feedback")
	for i in range(600):
		growth.advance(1.0 / 30.0, false, scene._tremor)
	check(growth.terrain == 1.0 and growth.foliage == 1.0 and growth.water == 1.0 and not growth.replaying, "Replay reaches exact full-grown endpoints")
	growth.replay()
	growth.set_terrain(0.25)
	growth.advance(1.0, false, scene._tremor)
	check(growth.terrain == 0.25 and not growth.replaying, "Manual scrub stops replay")
	growth.set_terrain(1.0)
	growth.set_foliage(1.0)
	for i in range(4):
		check(scene.get_node("Reference/mesh-"+str(i+4)).transform.is_equal_approx(boulders[i]), "Finished growth restores the exact boulder transform")
	check(scene.get_node("Reference/landmark-arch").visible, "Full growth restores landmark")
	print("Growth checks: ", failures, " failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
