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
	scene.library_path = "/private/tmp/zenscape-interaction-test"
	scene.recent_file = scene.library_path+"/recent.cfg"
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	check(scene.invite_bigfoot(Vector3.ZERO),"Can invite Bigfoot")
	scene._focus_bigfoot()
	await process_frame
	var mouse: Vector2 = scene.camera.unproject_position(scene.creature.global_position+Vector3.UP*1.5)
	var before: Dictionary = scene._chunk_editor.data.to_document()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = mouse
	root.push_input(press,true)
	var move := InputEventMouseMotion.new()
	move.position = mouse+Vector2(35,-30)
	move.relative = Vector2(35,-30)
	root.push_input(move,true)
	await process_frame
	check(scene.creature.is_held(),"Dragging hovered Bigfoot picks him up in Build mode")
	check(before == scene._chunk_editor.data.to_document(),"Pickup does not edit terrain")
	if scene.get("_resident_play") != null:
		check(scene._resident_play.hint.visible,"Carrying has dedicated feedback")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape,true)
		check(not scene.creature.is_held() and not scene._menu.visible,"Escape returns Bigfoot safely before opening the menu")
		check(scene._gust_button.visible,"Wind gust is directly accessible")
		scene._gust_button.pressed.emit()
		check(scene._resident_play.gust,"Toolbar activates gust tool")
		var pending: int = scene._resident_wind._pending.size()
		press.position = scene.camera.unproject_position(Vector3(2,0,2))
		root.push_input(press,true)
		check(scene._resident_wind._pending.size() == pending,"Ground press only starts aiming")
		move.position = scene.camera.unproject_position(Vector3(-1,0,2))
		root.push_input(move,true)
		var gust_release := InputEventMouseButton.new()
		gust_release.button_index = MOUSE_BUTTON_LEFT
		gust_release.position = move.position
		root.push_input(gust_release,true)
		check(scene._resident_wind._pending.size() == pending+1,"Drag release queues a gust")
		scene.creature.reset_at(Vector3.ZERO)
		press.position = scene.camera.unproject_position(Vector3(0,1.5,0))
		root.push_input(press,true)
		move.position = press.position+Vector2(35,-30)
		root.push_input(move,true)
		check(scene.creature.is_held(),"Bigfoot pickup takes priority while gust tool is active")
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = move.position
		root.push_input(release,true)
		check(not scene.creature.is_held(),"Pointer release sets Bigfoot down")
		scene.set_building(false)
		scene.creature.reset_at(Vector3.ZERO)
		root.push_input(press,true)
		root.push_input(move,true)
		check(scene.creature.is_held(),"Pickup works in Enjoy mode too")
		scene.show_menu()
		check(not scene.creature.is_held() and not scene._resident_play.gust,"Menu safely ends carry and gust interactions")
	else:
		check(false,"Dedicated resident interaction and wind access exist")
	scene.free()
	print("RESIDENT INTERACTION failures=",failures)
	quit(failures)
