extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var study = load("res://studies/redwood_forest.tscn").instantiate()
	root.add_child(study)
	study.caption.hide()
	study.paused = true
	study.clock = 4.0
	for i in range(30):
		await process_frame
		RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://docs/redwood-forest/hero.png")
	print("REDWOOD CAPTURED")
	study.free()
	quit()
