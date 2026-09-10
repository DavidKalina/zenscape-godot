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
	check(scene._has_world and not scene._menu.visible,"Startup enters Fidelity directly")
	check(not scene._paused and not scene._chunk_editor.active,"Fidelity starts alive in Enjoy mode")
	check(not scene._chunk_editor.data.blank and scene.resident_enabled,"Startup retains the original world and Bigfoot")
	check(scene.habitat.solids.size()>100 and scene.habitat.waters.size()>0,"Fidelity retains its scenery and water")
	check(not scene.fish.population.is_empty(),"Fidelity has its pond fish")
	check(scene._chunk_editor.data.tunnels.size()==1 and scene.cave_sites.get_child_count()==1,"Startup includes Bigfoot's prepared cave")
	check(scene.lair != null and scene.lair.position.y < 0,"Startup includes the underground story")
	scene._world_menu.get_popup().id_pressed.emit(101)
	check(is_equal_approx(scene.polar,1.63),"World menu inspects the lower story")
	scene._world_menu.get_popup().id_pressed.emit(100)
	check(is_equal_approx(scene.distance,64.0) and is_equal_approx(scene.polar,1.3),"World menu frames both stories")
	for tuner in get_nodes_in_group("tree_motion_tuner"):
		check(not tuner.visible,"Startup keeps the motion tuning panel hidden")
	scene.show_menu()
	check(scene._continue.has_focus(),"Menu selects Continue for the active world")
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	root.push_input(down)
	await process_frame
	check(scene._menu.buttons[1].has_focus() and scene._menu.buttons[1].text == "Fidelity world","Arrow key selects Fidelity world")
	scene.new_diorama()
	var editor = scene._chunk_editor
	var first: String = editor.save_path
	check(editor.data.blank and editor.data.objects.is_empty() and editor.data.ponds.is_empty() and editor.data.streams.is_empty(),"New world is truly blank")
	check(not scene.resident_enabled and editor.active,"New world opens in Build without Bigfoot")
	check(scene.lair == null,"New diorama has no inherited lower story")
	scene._world_menu.about_to_popup.emit()
	check(scene._world_menu.get_popup().is_item_disabled(scene._world_menu.get_popup().get_item_index(101)),"Lair inspection is unavailable in a blank world")
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
	scene.show_menu()
	scene._menu.buttons[1].pressed.emit()
	check(not editor.data.blank and scene.resident_enabled and not editor.active,"Fidelity menu action restores the inhabited world in Enjoy mode")
	check(editor.save_path != first and FileAccess.file_exists(first),"Launching Fidelity preserves the previous world's save")
	check(editor.data._undo.is_empty() and editor.data._redo.is_empty(),"Fidelity cannot undo into the previous world")
	check(not scene.fish.population.is_empty(),"Relaunch restores pond fish")
	check(editor.data.tunnels.size()==1 and scene.cave_sites.get_child_count()==1,"Fidelity menu action restores the cave")
	check(scene.lair != null,"Fidelity relaunch restores the lower story")
	scene.fish.population[0].stored = true
	check(scene.save_current(),"Fidelity saves successfully")
	var fidelity_path: String = editor.save_path
	scene.new_diorama()
	check(scene.open_path(fidelity_path) and scene.resident_enabled and not editor.data.blank,"Saved Fidelity can be reopened")
	check(scene.fish.population[0].stored,"Reopening preserves stored fish")
	check(scene.lair != null,"Save and reopen preserve the lower story")
	scene.show_menu()
	for size in [Vector2i(480,320),Vector2i(960,640),Vector2i(1440,900)]:
		root.size = size
		await process_frame
		await process_frame
		scene._layout_shell()
		check(root.get_visible_rect().encloses(Rect2(scene._menu.position,scene._menu.size*scene._menu.scale)),"Menu fits "+str(size))
		for control in scene._menu._frame.get_children():
			if control is Control and control.visible:
				check(root.get_visible_rect().grow(1).encloses(control.get_global_rect()),"Title content fits "+str(size)+": "+str(control.name)+" "+str(control.get_global_rect())+" "+str(control.get("text")))
	scene.free()
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	print("DIORAMA FLOW: failures=",failures)
	quit(1 if failures else 0)
