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
	# The product opens on the Genesis plain with a creation brush in hand.
	var deadline := Time.get_ticks_msec()+120_000
	while not bool(scene.get("shell_ready")):
		if Time.get_ticks_msec() >= deadline or scene.get("shell_ready") == null:
			push_error("FAIL: packaged startup did not reach the creation shell")
			tree.quit(1)
			return
		await tree.process_frame
	var failure := _check_creation_shell(scene)
	if not failure.is_empty():
		push_error("FAIL: packaged "+failure)
		tree.quit(1)
		return
	var folders: Array[String] = [scene.library_path,scene.places_path.get_base_dir()]
	var audio_streams: Array[WeakRef] = []
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for player in scene.find_children("*",kind,true,false):
			if player.stream != null: audio_streams.append(weakref(player.stream))
	scene.free()
	var release_deadline := Time.get_ticks_msec()+2000
	while audio_streams.any(func(stream: WeakRef) -> bool: return stream.get_ref() != null):
		if Time.get_ticks_msec() >= release_deadline:
			push_error("FAIL: packaged audio streams retained after shutdown")
			tree.quit(1)
			return
		await tree.process_frame
	for folder in folders:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
	print("PASS: packaged creation shell, Look, Craft and main menu")
	tree.quit(0)

## Walk the creation shell the way a player first meets it. Returns what
## failed, or "" when every step held.
static func _check_creation_shell(scene: Node) -> String:
	var editor: NativeChunkEditor = scene._chunk_editor
	var palette: Control = scene.creation_palette
	if not scene._has_world or not scene.places.plain or not editor.data.blank:
		return "startup did not open on the Genesis plain"
	var ids: Array = scene.brush_ids
	if palette == null or not palette.is_visible_in_tree() or ids.is_empty() or palette.brush_ids() != ids:
		return "creation palette is missing or does not list the registered brushes"
	for id: String in ids:
		if not palette.buttons.has(id) or not palette.buttons[id].is_visible_in_tree():
			return "creation palette has no button for brush "+id
	if not scene._creating() or editor.mode != ids[0] or not palette.buttons[ids[0]].button_pressed:
		return "launch did not put the first brush in hand"
	var rail: Control = scene._build_palette.get("_tool_rail")
	if rail != null and rail.is_visible_in_tree():
		return "craft rail is showing in creation mode"
	# Look puts the brush away: nothing paints and a press falls to the camera.
	palette.look_button.pressed.emit()
	if not scene.looking or editor.active or scene._creating() or not palette.look_button.button_pressed:
		return "Look did not put the brush away"
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = scene.get_viewport().get_visible_rect().size*0.5
	var revision := editor.data.heights.duplicate()
	scene._unhandled_input(press)
	var orbiting: bool = scene._orbiting
	var release := press.duplicate()
	release.pressed = false
	scene._input(release)
	if editor._painting or editor.data.heights != revision or not orbiting:
		return "a press while looking painted instead of turning the camera"
	palette.buttons[ids[0]].pressed.emit()
	if scene.looking or not scene._creating() or editor.mode != ids[0]:
		return "picking the brush did not end Look"
	# Craft opens the fine tools behind one control; Create returns to the brush.
	scene._build_button.pressed.emit()
	if not scene.crafting or not editor.active or rail == null or not rail.is_visible_in_tree() or palette.is_visible_in_tree():
		return "Craft did not open the fine tools"
	scene._build_button.pressed.emit()
	if scene.crafting or not scene._creating() or rail.is_visible_in_tree() or not palette.is_visible_in_tree():
		return "Create did not return to the brush"
	# The main menu covers the shell and gives it back.
	scene.show_menu()
	if scene._menu == null or not scene._menu.visible or palette.is_visible_in_tree():
		return "main menu is missing"
	scene.close_menu()
	if scene._menu.visible or not palette.is_visible_in_tree() or not scene._creating():
		return "closing the main menu did not return to the brush"
	return ""
