extends SceneTree
## Disposable diorama, actual editor controls, and screenshots at two sizes.
const OUTPUT := "res://docs/design/tactile-editor"
var scene: Node3D
var failures := 0
func _initialize() -> void:
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec",1000.0)
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func snap(file: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join(file))
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/zenscape-tactile-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.add_child(scene)
	await process_frame
	scene.new_diorama()
	scene._paused = true
	var editor: NativeChunkEditor = scene._chunk_editor
	var palette: NativeBuildPalette = scene._build_palette
	await editor.form_landscape("valley","",false)
	preload("res://scripts/scene_look_presets.gd").apply(scene,"golden_meadow")
	scene._frame_diorama()
	palette._choose("tree")
	await snap("tree-in-hand.png")
	var rail = palette._tool_rail
	check(rail.portrait.texture != null,"Held tree has an actual miniature preview")
	for mesh: MeshInstance3D in [editor.terrain,editor._skirt]:
		for surface in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var clear := true
			for vertex: Vector3 in vertices:
				if scene.camera.unproject_position(mesh.to_global(vertex)).y >= rail.dock.get_global_rect().position.y-12: clear = false
			check(clear,"Overview keeps the complete terrain and base above the tray")
	check(not rail.card.visible,"The card stays put away until explicitly requested")
	rail.held.pressed.emit()
	await snap("tool-controls.png")
	check(not editor.pointer_in_world(rail.card.get_global_rect().get_center()),"Open card shields the terrain")
	check(not editor.pointer_in_world(rail.dock.get_global_rect().get_center()),"Dock shields the terrain")
	check(editor.pointer_in_world(root.get_visible_rect().size*0.5),"Space between tools belongs to the diorama")
	rail.quick_row.control.value = 1.7
	check(is_equal_approx(editor.object_scale,1.7),"Quick size edits the placement tool")
	editor.set_setting("object_scale",1.2)
	check(is_equal_approx(rail.quick_row.control.value,1.2),"Keyboard and detailed settings update the quick control")
	rail.miniatures.rock.pressed.emit()
	check(editor.mode == "rock","Shelf chooses real placement tools")
	rail.miniatures.tree.pressed.emit()
	check(is_equal_approx(rail.quick_row.control.value,1.2),"Returning to a piece restores its own size")
	rail.context.get_node("Actions/Settings").pressed.emit()
	await snap("adjust.png")
	check(root.get_visible_rect().encloses(palette._details.get_global_rect()),"Adjust panel fits normal viewport")
	palette._details.hide()
	root.size = Vector2i(960,640)
	await process_frame
	scene._frame_diorama()
	await snap("compact.png")
	check(root.get_visible_rect().encloses(rail.card.get_global_rect()),"Card fits compact viewport")
	check(root.get_visible_rect().encloses(rail.dock.get_global_rect()),"Dock fits compact viewport")
	palette._details.show()
	await snap("compact-adjust.png")
	check(root.get_visible_rect().encloses(palette._details.get_global_rect()),"Adjust fits compact viewport")
	palette._details.hide()
	palette._choose("select")
	await snap("select.png")
	check(not rail.card.visible,"Putting tools down clears the card")
	root.size = Vector2i(1440,900)
	await process_frame
	scene._frame_diorama()
	scene.set_building(false)
	await snap("enjoy.png")
	check(not palette.visible,"Enjoy puts away the building tools")
	scene.free()
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	print("TACTILE EDITOR: failures=",failures)
	quit(1 if failures else 0)
