extends SceneTree
## Photograph the build palette for the documentation. The fidelity scene's own
## --capture flag hides the UI, so this drives the scene and shoots the window.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.size = Vector2i(1800,1200)
	root.add_child(scene)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_active(true)
	editor.select_tool("tree")
	scene._build_palette._show_category("Place")
	for i in range(12):
		await process_frame
	RenderingServer.force_draw(false)
	var result := root.get_texture().get_image().save_png("res://docs/garden/palette.png")
	print("Palette capture: docs/garden/palette.png result=",result)
	scene._build_palette._show_category("Sky")
	for i in range(6):
		await process_frame
	RenderingServer.force_draw(false)
	var sky := root.get_texture().get_image().save_png("res://docs/garden/palette-sky.png")
	print("Sky capture: docs/garden/palette-sky.png result=",sky)
	scene.queue_free()
	await process_frame
	quit(0)
