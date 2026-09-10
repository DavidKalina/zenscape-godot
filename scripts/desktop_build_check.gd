extends RefCounted
## Explicit CI self-check: release templates disallow --script/path overrides.
static func run(scene: Node) -> void:
	var tree := scene.get_tree()
	var kernel = preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	if kernel == null or not kernel.has_method("shade"):
		push_error("FAIL: packaged native terrain kernel is unavailable")
		tree.quit(1)
		return
	print("PASS: packaged native terrain kernel loaded")
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.paint_grass(Vector2.ZERO,3.0,0.7)
	for fixture in range(3):
		if fixture == 1:
			data.reset_flat()
			await data.form_foundation(1.0,1.0)
			data.paint_tint(Vector2(-3,2),4.0,Color(0.7,0.1,0.3),0.6)
		elif fixture == 2:
			await preload("res://scripts/native_landscape_presets.gd").form(data,"horn")
			data.brush(Vector2.ZERO,4.0,0.8,"raise",0.0)
		data.native_mesh_enabled = false
		var reference := var_to_bytes(data.build_mesh(true).surface_get_arrays(0))
		data.native_mesh_enabled = true
		if var_to_bytes(data.build_mesh(true).surface_get_arrays(0)) != reference:
			push_error("FAIL: packaged native synchronous mesh differs from GDScript")
			tree.quit(1)
			return
		for workers in [0,1,2,4,8]:
			data.mesh_workers = workers
			var mesh := await data.build_mesh_budgeted(true,tree)
			if mesh == null or var_to_bytes(mesh.surface_get_arrays(0)) != reference:
				push_error("FAIL: packaged native worker mesh differs from GDScript")
				tree.quit(1)
				return
	print("PASS: packaged native mesh equivalence")
	if not scene.title_loaded or scene._menu == null or not scene._menu.visible:
		push_error("FAIL: packaged main menu is missing")
		tree.quit(1)
		return
	scene.new_diorama()
	var rail = scene._build_palette.get("_tool_rail")
	if not scene._chunk_editor.active or rail == null or not rail.visible:
		push_error("FAIL: packaged New diorama editor is missing")
		tree.quit(1)
		return
	var folder: String = scene.library_path
	var audio_streams: Array[WeakRef] = []
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for player in scene.find_children("*",kind,true,false):
			if player.stream != null: audio_streams.append(weakref(player.stream))
	scene.free()
	var deadline := Time.get_ticks_msec()+2000
	while audio_streams.any(func(stream: WeakRef) -> bool: return stream.get_ref() != null):
		if Time.get_ticks_msec() >= deadline:
			push_error("FAIL: packaged audio streams retained after shutdown")
			tree.quit(1)
			return
		await tree.process_frame
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(name))
	DirAccess.remove_absolute(folder)
	print("PASS: packaged main menu and New diorama editor")
	tree.quit(0)
