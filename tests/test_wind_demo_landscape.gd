extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor = scene._chunk_editor
	var clearing: Vector3 = preload("res://scripts/wind_demo_landscape.gd").populate(editor)
	var data = editor.data
	var valid: bool = data.ponds.size() == 1 and editor.falls.get_child_count() == 2 and clearing.is_finite()
	valid = valid and data.pond_surface(data.ponds[0]).size() > 0
	var snapshot: Dictionary = data.to_document()
	valid = valid and data.load_document(JSON.parse_string(JSON.stringify(snapshot,"",true,true)))
	editor.refresh()
	valid = valid and editor.falls.get_child_count() == 2 and data.objects.size() == 7
	# Deliberate safe clearing: dry, low slope, ample space to land the creature.
	var center := Vector2(clearing.x, clearing.z)
	for offset in [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var height: float = data.ground_height(center + offset * 0.5)
		valid = valid and absf(height - clearing.y) < 0.25 and height > -0.2
	scene._ui.visible = false
	scene._build_palette.visible = false
	scene._reset_camera()
	for i in range(5):
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/wind-demo-landscape.png")
	print("Wind landscape pond/fall/reopen/clearing ", valid, "; clearing ", clearing)
	scene.queue_free()
	await process_frame
	quit(0 if valid else 1)
