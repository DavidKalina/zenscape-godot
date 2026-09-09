extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/world-reference-test-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440,960)
	scene.new_diorama()
	var editor = scene._chunk_editor
	editor.data.blank = false
	editor.data.heights = editor.data.original_heights.duplicate()
	editor.refresh()
	var original_count: int = editor.data.objects.size()
	scene.set_building(false)
	check(editor.data.objects.size()>original_count,"Imported trees and props become authored records")
	check(editor.data.source_replacements.size()>0,"Imported source suppression is tracked")
	var count: int = editor.data.objects.size()
	var hidden: Array = editor.data.source_replacements.duplicate()
	scene.world_play.prepare()
	check(editor.data.objects.size()==count,"Repeated preparation does not duplicate scenery")
	check(scene.save_current(),"Save upgraded legacy world")
	var saved: String = editor.save_path
	scene.new_diorama()
	check(editor.data.source_replacements.is_empty(),"New world clears legacy suppression")
	check(scene.open_path(saved),"Reopen upgraded legacy world")
	check(editor.data.source_replacements == hidden,"Source suppression survives reopening")
	check(editor.data.objects.size()==count,"Reopening does not duplicate legacy objects")
	for key in hidden:
		var pair: PackedStringArray = key.split(":")
		var node: Node3D = scene.get_node("Reference").get_node(pair[0])
		if node is MeshInstance3D: check(not node.visible,"Replaced boulder stays hidden")
	print("WORLD REFERENCE PLAY failures=",failures," objects=",count)
	quit(failures)
