extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func click(point: Vector2) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = root.get_final_transform()*point
		event.global_position = event.position
		root.push_input(event)
func run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1800,1200)
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/zenscape-coherence-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.add_child(scene)
	await process_frame
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	var palette: NativeBuildPalette = scene._build_palette
	palette._choose("broadleaf")
	editor.set_setting("object_scale",3.3)
	editor.set_setting("object_heading",65.0)
	palette._choose("rock")
	check(is_equal_approx(editor.object_scale,1.0) and is_zero_approx(editor.object_heading),"A rock does not inherit the large tree's size or heading")
	editor.set_setting("object_scale",0.4)
	palette._choose("broadleaf")
	check(is_equal_approx(editor.object_scale,3.3) and is_equal_approx(editor.object_heading,65.0),"Returning to broadleaf restores its settings")
	palette._choose("rock")
	check(is_equal_approx(editor.object_scale,0.4),"Returning to rock restores its own settings")
	palette._choose("boulder_1")
	check(is_equal_approx(editor.object_scale,1.0),"Separate catalog assets get separate defaults")
	palette._choose("broadleaf")
	check(is_equal_approx(editor.object_scale,3.3),"Catalog assets sharing the same tool mode retain their own settings")
	palette._choose("rock")
	await process_frame
	var count := editor.data.objects.size()
	click(scene._build_button.get_global_rect().get_center())
	await process_frame
	check(not editor.active,"Enjoy responds during active placement")
	check(editor.data.objects.size() == count,"Toolbar click cannot place an object")
	scene.set_building(true)
	palette._choose("rock")
	click(scene._toolbar.get_child(4).get_global_rect().get_center())
	await process_frame
	check(palette._placing == "bigfoot","Bigfoot toolbar button can replace an active placement tool")
	click(scene._toolbar.get_child(0).get_global_rect().get_center())
	await process_frame
	check(scene._menu.visible,"Menu can open while holding a placeable object")
	scene.close_menu()
	palette._choose("tree")
	check(palette._tool_rail.title.text.ends_with("Pine"),"Sidebar uses the same Pine name as the catalog")
	palette._choose("raise")
	check(palette._tool_rail.title.text.ends_with("Rolling hill"),"Sidebar uses the same Rolling hill name as the catalog")
	palette._details.show()
	await process_frame
	palette._fit_details()
	var rail: Rect2 = palette._tool_rail.get_global_rect()
	check(absf(palette._details.position.x-rail.end.x)<24.0,"Tool settings are adjacent to the tool rail")
	check(root.get_visible_rect().encloses(palette._details.get_global_rect()),"Settings stay inside the viewport")
	palette._choose("select")
	check(not palette._details.visible,"Select does not leave an empty settings panel")
	root.size = Vector2i(960,640)
	await process_frame
	palette._choose("tree")
	palette._details.show()
	await process_frame
	palette._fit_details()
	check(root.get_visible_rect().encloses(palette._details.get_global_rect()),"Settings fit a small scaled viewport")
	check(palette._details_title.text == "Pine settings","Settings identify the current item")
	palette._strip.get_node("SettingsHeading/CloseSettings").pressed.emit()
	check(not palette._details.visible,"Settings can be dismissed from their own panel")
	palette._choose("pond")
	check(palette._tool_rail.dig.visible,"Pond offers a hollow shortcut")
	palette._tool_rail.dig.pressed.emit()
	check(editor.mode == "lower","Hollow shortcut selects the digging brush")
	palette._tool_rail.activate("Water")
	check(editor.mode == "pond","Water returns from digging to pond placement")
	palette._details.show()
	await process_frame
	var water_slider: Control = palette._strip_rows.pond_level.control
	check(water_slider.size.x > 280.0,"Single water slider uses the available settings width")
	palette._details.hide()
	editor.data.brush(Vector2.ZERO,3.0,1.0,"lower",0.0)
	editor.refresh()
	var pond_point: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(Vector3(0,editor.data.height_at(0,0),0)))
	editor.place_at(pond_point)
	check(editor.data.ponds.size() == 1 and editor.status.begins_with("Pond filled"),"Successful fill feedback survives the terrain refresh")
	scene._notice.text = "Water is below this ground. Dig a hollow, or raise the water level in Settings."
	scene._layout_shell()
	await process_frame
	check(root.get_visible_rect().encloses(scene._notice.get_global_rect()),"Long pond feedback remains inside the viewport")
	check(scene._notice.size.x <= 560.0,"Feedback uses readable wrapped lines")
	scene.free()
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	print("EDITOR COHERENCE: failures=",failures)
	quit(1 if failures else 0)
