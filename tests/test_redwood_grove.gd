extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = true
	var editor = scene._chunk_editor
	var data: NativeTerrainData = editor.data
	editor.save_path = "/private/tmp/zs-redwood-roundtrip.json"
	await editor.form_landscape("redwood_grove","",false)
	var trees: Array = data.objects.filter(func(item): return item.asset == "redwood")
	check(trees.size()>30,"Grove generates clustered redwoods")
	check(data.objects.any(func(item): return item.asset == "fern"),"Grove has editable fern undergrowth")
	check(data.ponds.is_empty() and data.streams.is_empty(),"Grove leaves water to the builder")
	check(scene._build_palette.tile_for("redwood") != null and scene._build_palette.tile_for("fern") != null,"New assets are available in the palette")
	var id: int = trees[0].id
	check(editor.selection.parts().any(func(part): return part.id == id),"Redwood participates in normal mesh selection")
	editor.select_object(id)
	var before: Dictionary = data.object_by_id(id).duplicate(true)
	check(editor.update_selected({"x":before.x+0.5,"scale":1.05}),"Selected redwood moves and resizes")
	check(data.object_by_id(id).scale==1.05,"Edited scale reaches saved object")
	editor.undo()
	check(data.object_by_id(id)==before,"Undo restores edited tree")
	editor.redo()
	scene._redwood_mist.sync(scene)
	check(scene._redwood_mist.redwoods == trees.size(),"Mist derives cover from live redwoods")
	var cover_before: PackedByteArray = scene._redwood_mist.cover_image.get_data()
	editor.delete_selected()
	# Undo/redo can clear selection; explicitly delete a known remaining tree.
	if not data.object_by_id(id).is_empty():
		editor.select_object(id)
		editor.delete_selected()
	scene._redwood_mist.sync(scene)
	check(scene._redwood_mist.redwoods == trees.size()-1,"Deleting a tree updates mist cover")
	check(scene._redwood_mist.cover_image.get_data()!=cover_before,"Clearing changes the actual cover texture")
	data.begin_stroke()
	data.brush(Vector2(0,0),2.0,0.6,"raise",0.0)
	data.end_stroke()
	await editor.refresh()
	scene._redwood_mist.sync(scene)
	check(scene._redwood_mist.fog_material.get_shader_parameter("ground_map") == scene._precipitation.ground_texture,"Mist uses current sculpted terrain map")
	var original_heights: PackedFloat32Array = data.heights.duplicate()
	var snapshot: Dictionary = data.to_document()
	check(editor.save_garden(),"Redwood world saves to disk")
	editor.start_flat()
	check(editor.open_garden(),"Redwood world reopens through the normal store")
	check(data.heights == original_heights,"Save/load preserves sculpted terrain exactly")
	check(data.objects.size()==snapshot.objects.size(),"Save/load preserves object count")
	for i in range(mini(data.objects.size(),snapshot.objects.size())):
		for key in snapshot.objects[i]:
			var expected: Variant = snapshot.objects[i][key]
			var actual: Variant = data.objects[i].get(key)
			# JSON decimal parsing can change the final bit of a scalar double.
			check(is_equal_approx(actual,expected) if expected is float else actual==expected,"Saved object field survives: "+str(key))
	for key in snapshot:
		if key != "objects": check(data.to_document()[key]==snapshot[key],"Saved terrain field survives: "+str(key))
	scene._redwood_mist.sync(scene)
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		check(scene._redwood_mist.active,"Native grove activates volumetric mist")
		scene._atmosphere.set_fog(0.0)
		scene._redwood_mist.sync(scene)
		check(not scene._redwood_mist.active,"Existing fog control can remove grove mist")
		scene._atmosphere.set_fog(0.45)
	await editor.change_landscape_biome("woodland",false)
	scene._redwood_mist.sync(scene)
	check(not scene._redwood_mist.redwood,"Changing biome switches to ordinary landscape mist")
	await editor.form_landscape("redwood_grove","",false,174)
	check(data.heights != original_heights,"Another grove variation changes the terrain")
	scene.free()
	print("REDWOOD GROVE: ",failures," failures")
	quit(1 if failures else 0)
