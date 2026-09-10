extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1
func run() -> void:
	create_timer(150).timeout.connect(func() -> void: quit(2))
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/cave-store-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	scene.title_seed = 37
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.set_process(false)
	check(scene.open_path("res://docs/bigfoot-cave/Fidelity cave.json"),"Prepared cave world opens in the main game")
	scene.set_process(false)
	check(scene._chunk_editor.data.tunnels.size()==1 and scene.cave_sites.get_child_count()==1,"Saved cave restores its terrain cut and approved model")
	check(scene.resident_enabled and scene.creature.visible,"Saved world restores a visible exterior resident")
	check(scene.routine.cave.request(),"Main-game resident can use the restored cave")
	for frame in range(1200):
		scene._process(1.0/60.0)
		if scene.routine.cave.concealed: break
	check(scene.routine.cave.concealed and not scene.creature.visible,"Main-game resident disappears through the saved black entrance")
	scene._chunk_editor.save_path = folder+"/saved.json"
	check(scene.save_current(),"World saves while its resident is concealed")
	check(scene.open_path(scene._chunk_editor.save_path),"Saved cave reopens after an interrupted visit")
	check(not scene.routine.cave.concealed and scene.navigation.is_safe(scene.creature.position),"Reload releases cave ownership and restores safe exterior ground")
	scene.queue_free()
	await process_frame
	print("CAVE STORE: failures=",failures)
	quit(1 if failures else 0)
