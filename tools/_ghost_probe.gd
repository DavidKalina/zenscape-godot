extends SceneTree
## Photograph a drag in flight: the object ghost and the landform ghost sitting
## on the terrain under the pointer, so the two can be looked at side by side.
func _initialize() -> void:
	_run.call_deferred()

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

func shoot(path: String) -> void:
	for i in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	print(path," result=",root.get_texture().get_image().save_png(path))

func _run() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.size = Vector2i(1600,1000)
	root.add_child(scene)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.reactions_enabled = false
	var palette: NativeBuildPalette = scene._build_palette
	editor.start_flat()
	editor.set_active(true)
	for child in scene._ui.get_children():
		if child is Control and child != palette:
			child.visible = false
	for i in range(20):
		await process_frame
	var target := root.get_visible_rect().size*Vector2(0.45,0.40)
	for probe: Array in [["tree","Place",1.8,"res://docs/garden/ghost-object.png"],
			["mountain","Landscape",1.0,"res://docs/garden/ghost-landform.png"]]:
		palette._show_category(probe[1])
		editor.select_tool(probe[0])
		if probe[0] == "tree":
			editor.set_setting("object_scale",probe[2])
		else:
			editor.set_setting("mountain_radius",5.0)
			editor.set_setting("mountain_peak",7.0)
		for i in range(3):
			await process_frame
		var start: Vector2 = palette.tile_for(probe[0]).get_global_rect().get_center()
		press(start,true)
		move(start+Vector2(30,-30))
		move(target)
		print(probe[0]," dragging=",palette.dragging()," ghost=",palette.ghost()," visible=",palette.ghost() != null and palette.ghost().visible)
		await shoot(probe[3])
		press(palette.get_global_rect().get_center(),false)
		for i in range(3):
			await process_frame
	scene.queue_free()
	await process_frame
	quit(0)
