extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: "+message)

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/native-explosives-test-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	var remote = editor.explosives
	check(scene._build_palette.tile_for("explosive") != null,"Main palette exposes the explosive item")
	editor.set_active(true)
	editor.reactions_enabled = false
	# Start with dirt high enough to dig a real hole and cover it again.
	editor.data.heights.fill(2.0)
	editor.refresh()
	editor.select_tool("lower")
	editor.data.begin_stroke()
	editor.data.brush(Vector2.ZERO,3.0,1.0,"lower",0)
	editor.data.end_stroke()
	editor.refresh()
	editor.select_tool("explosive")
	editor.blast_radius = 3.0
	var point := Vector3(0,editor.data.ground_height(Vector2.ZERO),0)
	var mouse: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(point))
	check(editor.place_at(mouse),"Explosive places through the actual main-game pointer tool")
	var charge: Dictionary = remote.charges().back().duplicate(true)
	var fixed := editor.data.object_position(charge)
	check(is_equal_approx(charge.blast_radius,3.0),"Placement stores the configured blast radius")
	check(not editor.trail_available(),"Holding placement does not spray explosives")
	editor.data.begin_stroke()
	editor.data.brush(Vector2(fixed.x,fixed.z),3,1.6,"raise",0)
	editor.data.end_stroke()
	editor.refresh()
	check(editor.data.object_position(editor.data.object_by_id(charge.id)) == fixed,"Raising dirt leaves the charge at its original elevation")
	check(editor.data.ground_height(Vector2(fixed.x,fixed.z)) > fixed.y+0.5,"The charge is buried below the visible terrain")
	check(editor.selection.pick(scene.camera.unproject_position(editor.terrain.to_global(fixed))) != charge.id,"Buried charge is occluded by the actual terrain when picking")
	# Remote selection can reach charges even when terrain hides their triangles.
	remote.target_id = charge.id
	remote._sync_list()
	check(remote.charge_list.get_item_text(remote.charge_list.selected).contains("buried"),"Remote identifies a buried charge")
	remote._cover_changed(true)
	check(editor.data.object_by_id(charge.id).leaf_cover,"Remote can camouflage an existing charge")
	check(editor.content._sources.explosive_leaves.size() == 1,"Camouflage renders the actual leaf pile mesh")
	check(scene.save_current(),"Buried camouflaged charge saves with the main game")
	check(scene.open_path(editor.save_path),"Main game reopens the buried charge")
	var loaded := editor.data.object_by_id(charge.id)
	check(editor.data.object_position(loaded) == fixed and loaded.leaf_cover and loaded.blast_radius == 3.0,"Save/load preserves elevation, camouflage and power")
	var doc := editor.data.to_document()
	for bad in [NAN,INF,"2",-100.0]:
		var invalid := doc.duplicate(true)
		invalid.objects[0].anchor_y = bad
		check(not editor.data.load_document(invalid),"Malformed explosive elevation rejected atomically")
	check(editor.data.to_document() == doc,"Invalid loads leave the live world unchanged")
	var rock := editor.data.place("rock",Vector2(fixed.x+0.8,fixed.z),0,0.7)
	var tree := editor.data.place("tree",Vector2(fixed.x-1.1,fixed.z),0,0.55)
	var far := editor.data.place("rock",Vector2(11,11),0,0.7)
	var other_charge := editor.data.place("explosive",Vector2(10,10))
	editor.refresh()
	editor.select_object(other_charge)
	check(remote.target_id == other_charge,"Selecting an exposed charge targets its remote")
	for index in range(remote.charge_list.item_count):
		if remote.charge_list.get_item_id(index) == charge.id:
			remote.charge_list.select(index)
			remote.charge_list.item_selected.emit(index)
	editor.refresh()
	check(remote.target_id == charge.id,"Remote targeting survives refresh after switching away from a selected object")
	var before := editor.data.to_document()
	var pre_height: float = editor.data.ground_height(Vector2(fixed.x,fixed.z))
	scene.set_building(false)
	remote.target_id = charge.id
	scene._paused = true
	remote.request_detonation()
	check(not remote.requested,"Paused scenes do not arm a pending detonation")
	scene._paused = false
	var original_mesh: Mesh = editor.terrain.mesh
	var staged_frames := 0
	var transition_valid := true
	remote.request_detonation()
	while remote.requested or remote.firing:
		await process_frame
		if not remote.firing: continue
		for body in remote.bodies:
			staged_frames += 1
			transition_valid = transition_valid and body.freeze and body.collision_layer==0 and body.collision_mask==0
			if body.get_meta("mountain_chunk",false):
				transition_valid = transition_valid and body.visible==(editor.terrain.mesh!=original_mesh)
	check(staged_frames>0 and transition_valid,"Prepared debris stays frozen and collision-free; mountain chunks appear with the terrain swap")
	check(editor.data.object_by_id(charge.id).is_empty(),"Remote detonation consumes the buried charge in Enjoy mode")
	check(not editor.data.object_by_id(other_charge).is_empty(),"Targeted remote leaves other charges armed")
	check(editor.data.ground_height(Vector2(fixed.x,fixed.z)) < pre_height-0.5,"Buried blast excavates covering dirt")
	check(editor.data.object_by_id(rock).is_empty() and editor.data.object_by_id(tree).is_empty(),"Explosion releases nearby real scenery from authored batches")
	check(not editor.data.object_by_id(far).is_empty(),"Distant scenery survives")
	check(remote.bodies.size() >= 2,"Explosion launches physical copies and dirt")
	var launch_positions: Array[Vector3] = []
	for body in remote.bodies: launch_positions.append(body.global_position)
	# Publication can finish between physics ticks. Deferred impulses apply at
	# the next eligible boundary; the signal itself precedes node processing.
	await physics_frame
	await physics_frame
	check(remote.bodies.any(func(body: RigidBody3D) -> bool: return body.linear_velocity.length()>1),"Launched scenery really moves in the physics world")
	var moved := false
	for i in range(remote.bodies.size()):
		if remote.bodies[i].global_position.distance_to(launch_positions[i])>0.01: moved = true
	check(moved,"Published debris advances in the actual physics simulation")
	var origin := editor.terrain.to_global(fixed)
	var query := PhysicsRayQueryParameters3D.create(origin+Vector3.UP*15,origin+Vector3.DOWN*15,1)
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty(),"Exploded ground has physics collision")
	if not hit.is_empty():
		check(absf(editor.terrain.to_local(hit.position).y-editor.data.ground_height(Vector2(fixed.x,fixed.z)))<0.04,"Physics ground matches the crater")
	check(remote.can_restore(),"Remote offers restoration after a blast")
	remote.restore_button.pressed.emit()
	await process_frame
	check(editor.data.to_document() == before,"Undo last blast restores the exact landscape, props and armed charges")
	check(remote.bodies.is_empty(),"Undo clears flying copies")
	editor.redo()
	check(editor.data.object_by_id(charge.id).is_empty(),"Redo reapplies explosion damage without replaying effects")
	editor.undo()
	remote.target_id = 0
	var key := InputEventKey.new()
	key.keycode = KEY_X
	key.pressed = true
	root.push_input(key)
	while remote.requested or remote.firing: await process_frame
	check(remote.charges().is_empty(),"X hotkey fires the all-charges salvo through the actual input route")
	check(remote.bodies.size() <= remote.MAX_BODIES,"Live debris stays bounded")
	remote._elapsed = 19.0
	await physics_frame
	await physics_frame
	check(remote.bodies.is_empty(),"Expired wreckage releases its physics bodies")
	var cancelled_id := editor.data.place("explosive",Vector2.ZERO)
	remote.target_id = cancelled_id
	var cancel_before := editor.data.to_document()
	remote.detonate(true)
	check(remote.firing and editor.forming,"Pending preparation excludes competing edits")
	editor.undo()
	check(editor.data.to_document() == cancel_before,"Undo cannot interrupt a pending blast transaction")
	remote.request_detonation()
	check(not remote.requested,"A firing transaction does not queue repeated remote requests")
	remote.clear_effects()
	while remote.firing: await process_frame
	check(editor.data.to_document() == cancel_before and remote.bodies.is_empty(),"Cleared worker results cannot publish damage or debris")
	check(not editor.forming,"Cancelled preparation releases the edit exclusion")
	scene.new_diorama()
	await process_frame
	check(remote.charges().is_empty() and remote.bodies.is_empty(),"Changing worlds clears explosives and blast bodies")
	scene.free()
	await create_timer(0.25).timeout
	print("Native explosives: ",failures," failures")
	quit(1 if failures else 0)
