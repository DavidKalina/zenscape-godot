extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ",message)
func run() -> void:
	create_timer(100).timeout.connect(func() -> void: quit(2))
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/environment-world-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var id: int = scene._chunk_editor.data.place("tree",Vector2.ZERO,0.0,1.0)
	scene._chunk_editor.refresh()
	scene.set_building(false)
	scene.world_play.mischief.autonomous = false
	scene.world_play.rebuild_registry()
	check(scene.invite_bigfoot(Vector3(0,0,-3)),"Invite beside an authored native tree")
	scene.set_process(false)
	var life = scene.environment_life
	life.autonomous = false
	var began := Time.get_ticks_usec()
	check(life.request("tree_hug"),"Main diorama discovers a huggable authored trunk")
	print("Tree planning usec: ",Time.get_ticks_usec()-began)
	var contact := false
	for frame in range(1000):
		scene.world_play.advance(1.0/60.0)
		life.advance(1.0/60.0)
		scene.creature.advance(1.0/60.0)
		if life.phase == "perform" and scene.creature._age>1.5:
			contact = true
			break
		if frame%60 == 0: await process_frame
	check(contact,"Main-world navigation arrives at the authored trunk")
	check(scene.world_play.mischief.active.is_empty(),"Physical mischief does not steal the tree approach")
	check(scene.navigation.is_safe(scene.creature.position),"Tree embrace remains safely grounded")
	if contact:
		for side in ["R","L"]:
			var point: Vector3 = scene.creature.hand_targets[side].point
			check(scene.creature.hand_position(side).distance_to(point)<0.2,"Native trunk palm contact "+side)
	var tree: Node3D = scene.world_play.promote(id)
	tree.held = true
	life.advance(1.0/60.0)
	check(not life.busy(),"Player grabbing the physical trunk releases the embrace")
	tree.held = false
	life._cooldowns.clear()
	check(life.request("tree_touch"),"Stable physical tree can be approached again")
	scene._chunk_editor.data.remove_object(id)
	scene._chunk_editor.refresh()
	check(not life.busy() and scene.creature.hand_targets.is_empty(),"Native tree deletion cancels the embrace immediately")
	scene._refresh_habitat()
	scene._lightning.strike(Vector2(scene.creature.position.x,scene.creature.position.z),scene.camera.position)
	life.advance(1.0/60.0)
	check(life.active == "shock","The real lightning strike signal reaches the resident")
	life.world_changed()
	check(scene.invite_bigfoot(Vector3(9,0,0)),"Invite near the perimeter")
	check(life.request("horizon"),"Main landscape provides an overlook route")
	life.world_changed()
	scene._paused = true
	var before: float = life._clock
	scene._process(0.05)
	check(life._clock == before,"Main pause freezes the environmental clock")
	print("DIORAMA ENVIRONMENT: failures=",failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
