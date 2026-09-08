extends SceneTree
## Reopen the garden made by the hands-on editor pass and capture its result.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	# Capture at a fixed logical resolution independently of the monitor DPI.
	root.content_scale_factor = 1.0
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.save_path = "res://selection-garden.json"
	if not editor.open_garden():
		push_error(editor.status)
		quit(1)
		return
	editor.set_active(true)
	editor.select_tool("select")
	editor.select_object(3493)
	scene._paused = true
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/garden/selection-proof/inspector.png")
	scene._ui.visible = false
	editor.select_object(-1)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/garden/selection-proof/landscape.png")
	print("Selection garden reopened and captured: ",editor.data.objects.size()," objects")
	scene.queue_free()
	await process_frame
	quit()
