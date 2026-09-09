extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
	else: print("PASS: "+message)
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/world-play-test-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var editor = scene._chunk_editor
	var ids := {}
	var kinds := ["tree","layered_tree","redwood","broadleaf","bigfoot_tree","snag","rock","log","stump","boulder_1","boulder_2","boulder_3","boulder_4"]
	for i in range(kinds.size()): ids[kinds[i]] = editor.data.place(kinds[i],Vector2(-9+(i%5)*4,-8+(i/5)*5),0.3,0.65)
	editor.refresh()
	scene.set_building(false)
	var play = scene.world_play
	play.mischief.autonomous = false
	play.rebuild_registry()
	check(play._parts.size() == kinds.size(),"Every authored tree, log and rock kind is registered")
	check(play._active.is_empty(),"Scenery stays batched until interacted with")
	for kind in kinds:
		var id: int = ids[kind]
		var parts: Array = play._parts[id]
		var node: Node3D = play.promote(id)
		check(node != null,"Promote "+kind)
		var children: Array[Node] = node.find_children("*","MeshInstance3D",true,false)
		check(children.size() == parts.size(),"Preserve mesh parts for "+kind)
		for i in range(parts.size()): check(children[i].global_transform.is_equal_approx(parts[i].transform),"Preserve world pose for "+kind)
		if node is PlaySpringTree:
			node.begin_grab()
			node.drag_to(Vector3(4,0,-3))
			for i in range(50): node.advance(1.0/60)
			check(node.tension>0.9,"Full directional bend for "+kind)
			node.release()
			check(node.armed,"Spring release armed for "+kind)
		else:
			check(play.play_collisions.get_node("Prop_%d" % id).collision_layer == 0,"Disable original solid for "+kind)
	var rock = play._active[ids.rock]
	rock.grab()
	rock.global_position = Vector3(1,3,4)
	rock.release(Vector3(3,1,0))
	var before: Vector3 = rock.global_position
	for i in range(40): await physics_frame
	check(rock.global_position.distance_to(before)>0.3,"Thrown world rock moves under physics")
	scene._paused = true
	await process_frame
	await process_frame
	check(rock.freeze,"Pause freezes active world props")
	scene._paused = false
	rock.grab()
	rock.global_position = Vector3(2,2,5)
	rock.release(Vector3.ZERO)
	var expected: Transform3D = rock.global_transform*rock.record_in_body
	check(scene.save_current(),"Save physical world")
	var record: Dictionary = editor.data.object_by_id(ids.rock)
	check(editor.data.object_position(record).distance_to(expected.origin)<0.001,"Saved record follows actual moved rock")
	check(play._active.is_empty(),"Save returns active copies to persistent batches")
	check(NativeObjectPose.decode_basis(record.pose).is_equal_approx(expected.basis),"Saved orientation preserved")
	check(scene.open_path(editor.save_path),"Reopen saved physical world")
	check(editor.data.object_position(editor.data.object_by_id(ids.rock)).distance_to(expected.origin)<0.001,"Moved rock survives reopening")
	scene.set_building(true)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(600,400)
	check(not play.handle(down),"Build retains editor gestures")
	scene.set_building(false)
	play.rebuild_registry()
	play.promote(ids.log)
	scene.new_diorama()
	check(play._active.is_empty(),"New world clears physical copies")
	for kind in ["stone","log","tree"]:
		scene.new_diorama()
		var asset: String = "rock" if kind == "stone" else kind
		var id: int = editor.data.place(asset,Vector2(0,4),0.0,0.4 if kind == "stone" else 0.65)
		editor.refresh()
		check(scene.invite_bigfoot(Vector3.ZERO),"Invite Bigfoot for "+kind)
		scene.set_building(false)
		scene.routine._next_action = 10000.0
		play._attention_time = 10000.0
		for i in range(120): await physics_frame
		play.rebuild_registry()
		var node: Node3D = play.promote(id)
		var accepted: bool = play.mischief.request(kind,node)
		check(accepted,"Bigfoot plans physical world "+kind)
		var completed := false
		for i in range(2100 if accepted else 0):
			await physics_frame
			if not play.mischief.busy():
				completed = kind in play.mischief.history
				break
		check(completed,"Bigfoot completes physical world "+kind+" ("+play.mischief.last_cancel+")")
		if kind != "tree" and completed: check(node.launched,"Bigfoot releases actual world "+kind+" into physics")
		if kind == "tree":
			play.temper.provoke(1.0)
			check(play.temper.enraged and scene.creature.locomotion_tempo == 2.0,"Main Bigfoot enters rage with faster movement")
	scene.new_diorama()
	for i in range(editor.data.heights.size()):
		var distance: float = editor.data.points[i].length()
		editor.data.heights[i] = -1.3*(1.0-smoothstep(2.0,6.0,distance))
	check(editor.data.add_pond(Vector2.ZERO,-0.2),"Create a main-world pond")
	editor.refresh()
	scene.set_building(false)
	check(play.water_play.surface_at(Vector3.ZERO) != null,"World water sampler sees the pond")
	play.ensure_collision()
	for i in range(3): await physics_frame
	var shore: Variant = play.water_play.shore_from(Vector3.ZERO)
	check(shore != null,"Main-world pond has a checked dry exit")
	if shore != null:
		check(scene.invite_bigfoot(shore),"Invite Bigfoot beside pond")
		check(scene.creature.pick_up(),"Pick up resident for dunk")
		scene.creature.move_held(Vector3(0,-1.2,0),0.016)
		var mouse: Vector2 = scene.camera.unproject_position(Vector3(0,-0.2,0))
		scene._resident_play.carrying = true
		scene._resident_play.release(mouse)
		check(scene.creature.state == CreatureActor.State.SWIMMING,"Resident release enters swimming in main scene")
	print("Diorama world play failures: ",failures)
	quit(0 if failures == 0 else 1)
