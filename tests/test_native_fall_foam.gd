extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor=scene._chunk_editor
	editor.content.set_process(false)
	editor.start_flat()
	editor.form_range()
	editor.fill_landscape_waterfall()
	var foam=editor.content._landscape_foam
	var expected: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/fall-foam.json")).blobs
	var error:=0.0
	var actual: Array=foam.animator.blobs
	var ok: bool=actual.size()==expected.size()
	for i in range(mini(actual.size(),expected.size())):
		for key in ["baseY","gate"]: error=maxf(error,absf(actual[i][key]-expected[i][key]))
		for axis in [0,2]: error=maxf(error,absf(actual[i].position[axis]-expected[i].position[axis]))
		var source_mesh=scene.get_node("Reference/"+expected[i].mesh).mesh
		var source_vertices: PackedVector3Array=source_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var generated_vertices: PackedVector3Array=foam.animator.nodes[i].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for j in range(source_vertices.size()): error=maxf(error,source_vertices[j].distance_to(generated_vertices[j]))
	foam.animator.advance(1.0,true,0.0,0.0,true)
	var hidden: bool=foam.animator.nodes.all(func(node): return not node.visible)
	foam.animator.advance(1.0,false,0.0,1.0,true)
	var visible: bool=foam.animator.nodes.all(func(node): return node.visible)
	var pose: Transform3D=foam.animator.nodes[0].transform
	foam.animator.advance(2.0,false,0.0,1.0,true)
	var moving: bool=foam.animator.nodes[0].transform!=pose
	pose=foam.animator.nodes[0].transform
	foam.animator.advance(3.0,true,0.0,1.0,true)
	var paused: bool=foam.animator.nodes[0].transform==pose
	editor.data.undo()
	editor.refresh()
	var removed: bool=not is_instance_valid(editor.content._landscape_foam)
	editor.data.redo()
	editor.refresh()
	var restored: bool=editor.content._landscape_foam.animator.blobs.size()==expected.size()
	print("Authored foam blobs ",actual.size(),"; geometry/anchor/gate error ",error,"; growth hidden/visible ",hidden,"/",visible,"; moves ",moving,"; pauses ",paused,"; undo/redo ",removed,"/",restored)
	ok=ok and error<0.000001 and hidden and visible and moving and paused and removed and restored
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)
