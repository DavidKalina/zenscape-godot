extends SceneTree
const Library = preload("res://scripts/landscape_favorites.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("Favorites timed out"); quit(2))
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	var editor = scene._chunk_editor
	var library = Library.new()
	library.directory = "/private/tmp/zenscape-favorites-test-"+str(Time.get_ticks_usec())
	await editor.form_landscape("terraced_pools","woodland",false,174)
	editor.data.begin_stroke()
	editor.data.brush(Vector2(-8,7),2.0,0.7,"raise",0.0)
	editor.data.place("rock",Vector2(-9,7))
	editor.data.end_stroke()
	preload("res://scripts/scene_look_presets.gd").apply(scene,"halloween_hollow")
	var original_heights: PackedFloat32Array = editor.data.heights.duplicate()
	var original_look: Dictionary = scene._celestial.look.document()
	var original_objects: int = editor.data.objects.size()
	var original_water: Array = editor.data.streams.duplicate(true)
	var preview := Image.create(48,32,false,Image.FORMAT_RGB8)
	preview.fill(Color("653b72"))
	var id: String = library.save(scene,"My haunted terraces",preview)
	check(not id.is_empty(),"Favorite saves to disk")
	var reopened = Library.new()
	reopened.directory = library.directory
	check(reopened.entries().size()==1 and reopened.entries()[0].title=="My haunted terraces","Library survives a new instance")
	check(reopened.preview(id)!=null,"Favorite retains a real preview image")
	await editor.form_landscape("cone","alpine",false,311)
	preload("res://scripts/scene_look_presets.gd").apply(scene,"golden_meadow")
	var before: Dictionary = editor.data._snapshot()
	var before_scene: Dictionary = NativeGardenStore.capture(scene)
	var history_count: int = editor.data._undo.size()
	check(await editor.restore_landscape_favorite(reopened,id,false),"Favorite restores")
	check(editor.data.heights==original_heights,"Favorite restores sculpting")
	check(editor.data.objects.size()==original_objects and editor.data.streams==original_water,"Favorite restores planting, hand-placed objects and water")
	check(scene._celestial.look.document()==original_look,"Favorite restores its palette")
	check(editor.data._undo.size()==history_count+1,"Favorite adds one undo step, retaining earlier history")
	var restored: Dictionary = editor.data._snapshot()
	var restored_scene: Dictionary = NativeGardenStore.capture(scene)
	editor.undo()
	check(editor.data._snapshot()==before,"Undo favorite restores complete previous landscape")
	check(NativeGardenStore.capture(scene)==before_scene,"Undo favorite restores complete previous scene look and controls")
	editor.redo()
	check(editor.data._snapshot()==restored and NativeGardenStore.capture(scene)==restored_scene,"Redo favorite restores terrain and scene together")
	var malformed_id := "123-456"
	DirAccess.make_dir_recursive_absolute(library.directory.path_join(malformed_id))
	Library._write(library.directory.path_join(malformed_id).path_join("scene.json"),{"version":1,"terrain":{},"scene":{}})
	check(not await editor.restore_landscape_favorite(reopened,malformed_id,false),"Malformed favorite rejected")
	check(editor.data._snapshot()==restored and NativeGardenStore.capture(scene)==restored_scene,"Invalid favorite cannot mutate the active garden")
	check(reopened.prepare(scene,"../escape").is_empty(),"Favorite paths stay inside the library")
	scene.edit_landscape_presets()
	var panel = scene._landscape_editor
	check(not scene._build_palette.visible,"Landscape panel clears competing build tools")
	panel.library = reopened
	panel.tabs.current_tab = 1
	panel.refresh_favorites()
	panel.favorite_name.text = "A second discovery"
	var ui_visible: bool = scene._ui.visible
	await panel.save_favorite()
	check(reopened.entries().size()==2,"Favorites UI saves the current scene")
	check(panel.visible and scene._ui.visible == ui_visible and not editor.forming and not panel._saving,"Saving restores the UI and unlocks editing")
	root.content_scale_factor = 2.0
	root.size = Vector2i(960,640)
	await process_frame
	panel._layout()
	await process_frame
	check(root.get_visible_rect().encloses(panel.get_global_rect()),"Favorites fit a small Retina window")
	check(reopened.remove(id) and reopened.entries().size()==1,"Remove takes a favorite out of the library")
	check(FileAccess.file_exists(reopened.directory.path_join(".removed").path_join(id).path_join("scene.json")),"Removed favorite remains recoverable on disk")
	scene.queue_free()
	await process_frame
	print("LANDSCAPE FAVORITES failures=",failures)
	quit(1 if failures else 0)
