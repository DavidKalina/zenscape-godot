extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var watchdog := create_timer(90)
	watchdog.timeout.connect(func() -> void: push_error("Diorama test timed out"); quit(2))
	var scene = load("res://studies/diorama.tscn").instantiate()
	# Terrain loading can dispatch mouse/key input before the shell exists.
	var motion := InputEventMouseMotion.new()
	scene._input(motion)
	scene._unhandled_input(motion)
	var early_key := InputEventKey.new()
	early_key.keycode = KEY_H
	early_key.pressed = true
	scene._unhandled_input(early_key)
	var folder := "/private/tmp/zenscape-diorama-test-"+str(Time.get_ticks_usec())
	scene.title_seed = 37
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.size = Vector2i(1440,960)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	await process_frame
	check(scene._menu.visible and not scene._has_world,"Startup offers a menu without creating a world")
	check(not scene._paused and scene._auto_orbit,"Cover landscape is alive and gently rotating")
	check(not scene._chunk_editor.data._recipe_settings.is_empty() and Array(scene._chunk_editor.data.heights).max()>1.0,"Title has a landscape without creating a saved world")
	check(scene._menu.buttons[1].has_focus() and not scene._continue.visible,"First launch selects New and hides unavailable Continue")
	check(not scene._save_copy.visible,"Cover does not offer Save a copy")
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	root.push_input(down)
	await process_frame
	check(scene._menu.buttons[2].has_focus(),"Arrow key moves selection to Open")
	scene.new_diorama()
	var editor = scene._chunk_editor
	var first: String = editor.save_path
	check(editor.data.blank and editor.data.objects.is_empty() and editor.data.ponds.is_empty() and editor.data.streams.is_empty(),"New world is truly blank")
	check(not scene.resident_enabled and editor.active,"New world opens in Build without Bigfoot")
	check(editor.data._undo.is_empty(),"Undo cannot bring the previous world into a new one")
	var id: int = editor.data.place("rock",Vector2(4,3),0.0,0.4)
	editor.refresh()
	check(id>0 and scene.invite_bigfoot(Vector3.ZERO),"Blank scene can receive an object and a living Bigfoot")
	check(scene.save_current(),"Save succeeds")
	scene.show_menu()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	scene._input(escape)
	check(not scene._menu.visible and not scene._paused,"Escape returns from the menu without leaving the world paused")
	scene.show_menu()
	scene.new_diorama()
	var second: String = editor.save_path
	check(first != second and FileAccess.file_exists(first),"New uses a separate file and preserves the first world")
	check(editor.data.objects.is_empty() and not scene.resident_enabled,"New clears objects and resident")
	scene.show_menu()
	check(scene.open_path(first),"Open first world")
	check(not editor.data.object_by_id(id).is_empty() and scene.resident_enabled,"Open restores placement and resident")
	check(not scene._paused,"Menu pause does not leak into saved world")
	var before: Dictionary = editor.data.to_document()
	var corrupt := folder+"/broken.json"
	var file := FileAccess.open(corrupt,FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	check(not scene.open_path(corrupt),"Malformed file is rejected")
	check(editor.save_path == first and editor.data.to_document() == before,"Failed open preserves world and current save path")
	check(scene._recent_path() == first,"Continue remembers last successful world")
	scene._has_world = false
	scene.show_menu()
	scene.continue_world()
	check(scene._has_world and scene.resident_enabled,"Continue can load from disk")
	for size in [Vector2i(480,320),Vector2i(960,640),Vector2i(1440,900)]:
		root.size = size
		await process_frame
		scene._layout_shell()
		check(root.get_visible_rect().encloses(Rect2(scene._menu.position,scene._menu.size*scene._menu.scale)),"Menu fits "+str(size))
		for control in scene._menu._frame.get_children():
			if control is Control and control.visible:
				check(root.get_visible_rect().grow(1).encloses(control.get_global_rect()),"Title content fits "+str(size)+": "+str(control.name))
	scene.free()
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	print("DIORAMA FLOW: failures=",failures)
	quit(1 if failures else 0)
