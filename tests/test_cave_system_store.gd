extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1
func run() -> void:
	create_timer(150).timeout.connect(func() -> void: quit(2))
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.library_path = "/private/tmp/cave-genome-store"
	DirAccess.make_dir_recursive_absolute(scene.library_path)
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.title_seed = 37
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.set_process(false)
	check(scene.open_path("res://docs/bigfoot-cave/Fidelity cave.json"),"Original prepared world still opens")
	scene.set_process(false)
	var settings := preload("res://scripts/inland_genome.gd").cave(52,"blue slate",0.85)
	scene.restore_cave_state({"genome":settings,"stash":[]})
	check(not scene.fish.population.is_empty(),"Main game retains fish identities")
	var fish_id: String = scene.fish.population[0].id
	var fish_home: Vector3 = scene.fish.population[0].home+Vector3(0.125,0,0)
	scene.fish.population[0].home = fish_home
	scene.fish.population[0].held = true
	check(scene.lair.receive_item("branch") and scene.lair.receive_item_checked("fish",func() -> bool: return scene.fish.store_fish(fish_id)),"Generated cave accepts resources after source commitment")
	check(scene.lair.stockpile.get_child_count()==2,"Stockpile draws one object per stored resource")
	var captured := NativeGardenStore.capture(scene)
	check(NativeGardenStore.valid(scene,captured),"Generated cave world state validates")
	scene._chunk_editor.save_path = scene.library_path+"/generated.json"
	check(scene.save_current(),"Generated cave saves in the main game")
	check(scene.open_path(scene._chunk_editor.save_path),"Generated cave reopens in the main game")
	scene.set_process(false)
	check(scene.lair.genome.seed==52 and scene.lair.genome.palette=="blue slate" and scene.lair.stash==["branch","fish"],"Layout seed, palette and stash survive actual save/reopen")
	check(fish_id in scene.fish.capture_state().stored_ids and scene.fish.population[0].stored,"Delivered fish stays depleted after actual save/reopen")
	check(scene.fish.population[0].home.is_equal_approx(fish_home),"Authored fish starting positions survive actual save/reopen")
	var first: PackedByteArray = var_to_bytes(scene.lair.layout)
	var replacement: Dictionary = scene.capture_cave_state()
	replacement.genome.seed = 53
	scene.restore_cave_state(replacement)
	check(var_to_bytes(scene.lair.layout)!=first and scene.lair.stash==["branch","fish"],"Regenerating terrain preserves collected items")
	scene.restore_cave_state(captured.cave_system)
	check(var_to_bytes(scene.lair.layout)==first,"Original generated layout replays exactly")
	scene.restore_cave_state({})
	check(scene.lair==null and scene.routine.cave.rest_anchor==null,"Worlds without a cave restore ordinary surface behavior")
	scene.queue_free()
	await process_frame
	print("CAVE GENOME STORE: failures=",failures)
	quit(1 if failures else 0)
