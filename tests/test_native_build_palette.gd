extends SceneTree
## The build palette: every tool and catalog piece has a tile, placeables carry
## a rendered thumbnail, selection follows tools and hotkeys, and dragging a
## tile into the world places exactly what a click at that point would place.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func lit(texture: Texture2D) -> int:
	var image := texture.get_image()
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a > 0.1:
				count += 1
	return count

## The window scales its GUI for the display, so events enter in window pixels
## and every rect and pick point the test reads is in scaled coordinates.
func press(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = root.get_final_transform()*point
	event.global_position = event.position
	root.push_input(event)

func move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform()*point
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func tile_point(palette: NativeBuildPalette, id: String) -> Vector2:
	return palette.tile_for(id).get_global_rect().get_center()

func _run() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.reactions_enabled = false
	editor.set_process(false)
	editor.save_path = "user://palette-test.json"
	var palette: NativeBuildPalette = scene._build_palette
	editor.start_flat()
	check(not palette.visible,"The palette waits until Build is active")
	editor.set_active(true)
	check(palette.visible and palette.get_parent() == scene._ui,"Build opens the palette inside the scene UI")
	for tool: String in editor.tools():
		check(palette.tile_for(tool) != null,"The palette offers a tile for %s" % tool)
	for piece: String in NativeAssetCatalog.PARTS:
		check(palette.tile_for(piece) != null,"The palette offers a tile for the %s piece" % piece)
	check(palette.tile_ids().size() == editor.tools().size()-1+NativeAssetCatalog.PARTS.size(),"Every tool and piece has its own tile")
	# An occluded macOS window may not post a drawn frame; draw the portraits.
	for i in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	for id: String in ["tree","rock","flower","arch","bigfoot_tree","broadleaf","mushroom","log","boulder_1","daisy_flower"]:
		var portrait: Button = palette.tile_for(id)
		check(portrait.icon != null and lit(portrait.icon) > 40,"The %s tile shows a rendered thumbnail" % id)
	check(palette.tile_for("raise").icon == null,"Brush tools keep their drawn glyph instead of a portrait")
	# The side panel would cover the world at this window size; the palette and
	# the terrain under it are what this test drives.
	for child in scene._ui.get_children():
		if child is Control and child != palette:
			child.visible = false
	var view := root.get_visible_rect()
	var target := view.size*Vector2(0.42,0.41)
	check(editor.pick(target) != null,"The chosen point is open terrain")
	# Selection: a click on a tile picks the tool, hotkeys move the highlight.
	palette._show_category("Place")
	for i in range(2):
		await process_frame
	press(tile_point(palette,"rock"),true)
	press(tile_point(palette,"rock"),false)
	check(editor.mode == "rock","Clicking a tile selects its tool")
	check(palette.tile_for("rock").button_pressed,"The clicked tile lights up")
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	editor.handle_input(key)
	check(editor.mode == "lower","Hotkey 2 still selects Lower")
	check(palette.tile_for("lower").button_pressed and not palette.tile_for("rock").button_pressed,"Hotkey 2 moves the palette highlight to Lower")
	check(palette._category == "Sculpt","The palette shows the category the hotkey chose")
	var piece_tile: Button = palette.tile_for("mushroom")
	piece_tile.pressed.emit()
	check(editor.mode == "assets" and editor.catalog_asset == "mushroom","A piece tile selects the catalog tool with that piece")
	check(palette.tile_for("assets") == piece_tile,"The catalog tool reports the piece in hand")
	# Per-tool actions and colours live on the strip, each only for its own tool.
	for action: Dictionary in editor.ACTIONS:
		editor.select_tool(action.tool)
		var offered: Button = palette.action_for(action.name)
		check(offered != null and offered.text == action.title,"The %s strip offers %s" % [action.tool,action.title])
		for other: String in editor.tools():
			if other == action.tool:
				continue
			editor.select_tool(other)
			check(palette.action_for(action.name) == null,"%s stays off the %s strip" % [action.title,other])
	editor.select_tool("grass")
	editor.set_setting("grass_amount",0.6)
	editor.data.begin_stroke()
	editor.data.grass.fill(0.0)
	editor.data.end_stroke()
	palette.action_for("CoverChunkInGrass").pressed.emit()
	var covered := true
	for value: float in editor.data.grass:
		covered = covered and is_equal_approx(value,0.6)
	check(covered,"Cover chunk in grass spreads the strip's density over the chunk")
	editor.select_tool("tree")
	editor.custom_tint = false
	var tint: ColorPickerButton = palette.find_child("PlacementColor",true,false)
	var box: CheckBox = palette.find_child("CustomColor",true,false)
	check(tint != null and box != null,"Placeables carry a custom colour box and picker")
	var chosen := Color("c94f2b")
	tint.color = chosen
	tint.color_changed.emit(chosen)
	check(editor.object_tint == chosen and editor.custom_tint,"The picker tints placements and asks for the custom colour")
	check(box.button_pressed,"The custom colour box follows the picker")
	box.button_pressed = false
	check(not editor.custom_tint,"Unticking the box returns placements to their natural colour")
	editor.select_tool("raise")
	check(palette.find_child("PlacementColor",true,false) == null,"Brush tools show no placement colour")
	# Click placement, kept as the reference the drag has to reproduce.
	editor.select_tool("tree")
	editor.set_setting("object_scale",1.4)
	editor.set_setting("object_heading",30.0)
	check(editor.place_at(target),"A click plants a tree")
	check(editor.data.objects.size() == 1,"The click plants exactly one")
	var clicked: Dictionary = editor.data.objects[0].duplicate(true)
	editor.undo()
	check(editor.data.objects.is_empty(),"Undo clears the reference placement")
	var saved := editor.data.to_document()
	# Drag the tree tile into the world.
	for i in range(2):
		await process_frame
	var start := tile_point(palette,"tree")
	press(start,true)
	move(start+Vector2(30,-30))
	move(target)
	check(palette.dragging(),"Moving off a tile starts a drag")
	check(palette.ghost() != null and palette.ghost().visible,"The drag carries a ghost onto the ground")
	check(editor.data.objects.is_empty() and editor.data.to_document() == saved,"An in-flight ghost is not a record")
	check(editor.save_garden() and JSON.parse_string(FileAccess.get_file_as_string(editor.save_path)).objects.is_empty(),"Saving during a drag writes no ghost")
	press(target,false)
	check(editor.data.objects.size() == 1,"Dropping over terrain plants exactly one tree")
	var dropped: Dictionary = editor.data.objects[0]
	check(dropped.asset == "tree" and is_equal_approx(dropped.x,clicked.x) and is_equal_approx(dropped.z,clicked.z),"The drop lands where a click would have landed")
	check(is_equal_approx(dropped.angle,clicked.angle) and is_equal_approx(dropped.scale,clicked.scale) and dropped.get("pose") == clicked.get("pose"),"The drop takes the pose a click would have taken")
	check(palette.ghost() == null and editor.content.find_child("PaletteGhost",true,false) == null,"The committed drag leaves no ghost behind")
	check(not palette.dragging(),"The drag ends with the drop")
	editor.undo()
	check(editor.data.objects.is_empty(),"Undo removes the dropped tree")
	# A release away from the terrain places nothing.
	start = tile_point(palette,"tree")
	press(start,true)
	move(start+Vector2(30,-30))
	move(target)
	move(palette.get_global_rect().get_center())
	press(palette.get_global_rect().get_center(),false)
	check(editor.data.objects.is_empty(),"Releasing off the world places nothing")
	check(palette.ghost() == null and editor.content.find_child("PaletteGhost",true,false) == null,"A cancelled drag leaves no ghost")
	check(editor.data.to_document() == saved,"A cancelled drag changes no record")
	# Hiding the scene UI hides the palette with it.
	scene._ui.visible = false
	check(not palette.is_visible_in_tree(),"Hiding the scene UI hides the palette")
	scene._ui.visible = true
	scene.queue_free()
	await process_frame
	print("Native build palette: ",failures," failures")
	quit(1 if failures else 0)
