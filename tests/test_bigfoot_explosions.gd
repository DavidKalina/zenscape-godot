extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: "+message)
func ticks(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,960)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.title_seed = 37
	scene.library_path = "/private/tmp/bigfoot-blast-test-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.data.objects.clear()
	editor.data.heights.fill(2.0)
	editor.refresh()
	scene.set_building(false)
	check(scene.invite_bigfoot(Vector3(0,2,0)),"Bigfoot invited onto real main-game terrain")
	var actor: CreatureActor = scene.creature
	var remote = editor.explosives
	var before := actor.global_position
	var charge := editor.data.place("explosive",Vector2(-1,0))
	editor.data.update_object(charge,{"blast_radius":2.0})
	editor.refresh()
	remote.target_id = charge
	await remote.detonate(true)
	check(actor.blast_airborne and actor.wind_body.active,"Actual remote launches Bigfoot")
	var small_speed := actor.wind_body.linear_velocity.length()
	await ticks(20)
	check(actor.blast_airborne and actor.global_position.y > before.y+0.5,"Habitat rebuild preserves the airborne reaction")
	scene._paused = true
	await ticks(2)
	var paused := actor.wind_body.global_position
	await ticks(12)
	check(actor.wind_body.global_position.distance_to(paused)<0.01,"Pause freezes launched Bigfoot")
	scene._paused = false
	await ticks(650)
	check(not actor.blast_airborne and not actor.wind_body.active,"Small blast lands and finishes getting up")
	check(actor.global_transform.is_finite() and actor.global_basis.y.dot(Vector3.UP)>0.99,"Bigfoot recovers upright")
	editor.undo()
	check(actor.global_position.distance_to(before)<0.01 and not actor.wind_body.active,"Undo restores Bigfoot and stops his flight")
	editor.data.update_object(charge,{"blast_radius":6.0})
	editor.refresh()
	remote.target_id = charge
	await remote.detonate(true)
	check(actor.wind_body.linear_velocity.length()>small_speed*2.0,"Larger explosives produce a stronger launch")
	# Force the edge crossing to make the off-island recovery deterministic.
	actor.wind_body.global_position = Vector3(40,-19,0)
	await ticks(3)
	check(not actor.blast_airborne and Vector2(actor.global_position.x,actor.global_position.z).length()<8.0,"Falling off the island respawns near the center")
	check(scene.navigation.is_safe(actor.global_position),"Respawn picks safe ground outside the crater")
	editor.undo()
	actor.reset_at(Vector3(12,2,12))
	remote.target_id = charge
	await remote.detonate(true)
	check(not actor.blast_airborne,"Distant Bigfoot is unaffected")
	editor.undo()
	actor.reset_at(before)
	actor.pick_up()
	remote.target_id = charge
	await remote.detonate(true)
	check(actor.is_held(),"A carried Bigfoot remains in the player's hand")
	scene.queue_free()
	await process_frame
	print("Bigfoot explosions: ",failures," failures")
	quit(1 if failures else 0)
