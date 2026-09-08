extends SceneTree
## Render a deterministic preview fixture without touching the user's world.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/zenscape-pond-render-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.add_child(scene)
	await process_frame
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_process(false)
	editor.data.brush(Vector2.ZERO,4.5,1.6,"lower",0.0)
	editor.refresh()
	scene._build_palette._choose("pond")
	for i in range(3): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/private/tmp/zenscape-pond-before.png")
	var message: String = editor.pond_preview.hover(editor.data,Vector3.ZERO,-0.15,0.2)
	editor._set_status(message)
	for i in range(3): await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/private/tmp/zenscape-pond-preview.png")
	var valid: bool = editor.pond_preview.visible and editor.data.ponds.is_empty()
	print("Preview rendered without placing pond: ",valid)
	scene.free()
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	quit(0 if valid else 1)
