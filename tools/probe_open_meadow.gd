extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var scene = load("res://studies/open_meadow.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	var traveled := 0.0
	var unsafe := 0
	for i in range(60*120):
		var before: Vector3 = scene.creature.position
		scene._process(1.0/60.0)
		traveled += before.distance_to(scene.creature.position)
		if not scene.navigation.is_safe(scene.creature.position): unsafe += 1
		if i%600==0: await process_frame
	print("MEADOW nodes=",scene.navigation._nodes.size()," distance=",traveled," unsafe=",unsafe," actions=",scene.routine.history," cancelled=",scene.routine.last_cancel)
	assert(traveled>20.0 and unsafe==0,"Bigfoot has room to roam safely")
	assert(scene._chunk_editor.data.ponds.size()==1,"The meadow contains its authored pond")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/open-meadow.png")
	scene.free()
	quit()
