extends SceneTree
## Open an editable copy of the size-trial woodland in the normal game.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	# Set trial size before restoring homes, whose headroom depends on it.
	scene.creature.actor.scale *= 0.7
	if not scene.open_path("res://docs/bigfoot-scale/woodland.json"):
		push_error("Could not open woodland")
		quit(1)
		return
	scene.get_window().title = "ZenScape · Woodland size trial"
	DirAccess.make_dir_recursive_absolute(scene.library_path)
	scene._chunk_editor.save_path = scene.library_path+"/Woodland-"+Time.get_datetime_string_from_system().replace(":","-")+".json"
	scene.save_current()
	scene._notice.text = "Woodland · Bigfoot at 70% · Scroll to zoom · Right drag to orbit"
	print("WOODLAND OPEN: ",scene._chunk_editor.save_path,"; objects=",scene._chunk_editor.data.objects.size(),"; model scale=",scene.creature.actor.scale)
