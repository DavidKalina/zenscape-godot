extends SceneTree
## Blast debris knocks the resident down and unseats authored props it hits.
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
	scene.library_path = "/private/tmp/debris-strike-test-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.data.objects.clear()
	editor.data.heights.fill(2.0)
	var rock := editor.data.place("rock",Vector2(6,6),0,0.8)
	editor.refresh()
	scene.set_building(false)
	check(scene.invite_bigfoot(Vector3(0,2,0)),"Bigfoot invited onto flat main-game terrain")
	var actor: CreatureActor = scene.creature
	var remote = editor.explosives
	var charge := editor.data.place("explosive",Vector2(-9,0))
	editor.data.update_object(charge,{"blast_radius":2.0})
	# Scenery beside the charge becomes the heavy debris this test throws.
	editor.data.place("rock",Vector2(-8.2,0),0,0.7)
	editor.data.place("log",Vector2(-9.8,0.6),0,0.7)
	editor.refresh()
	remote.target_id = charge
	remote.detonate()
	check(not actor.blast_airborne,"A distant charge leaves Bigfoot standing")
	var slab: RigidBody3D = null
	for body in remote.bodies:
		if float(body.get_meta("radius",0.0)) >= remote.STRIKE_RADIUS and (slab == null or body.mass > slab.mass): slab = body
	check(slab != null and slab.mass > 1.0,"Debris carries rock-like mass")
	check(slab != null and slab.collision_mask & 2 != 0,"Debris collides with the resident's tumble proxy")
	# Pebbles drift past the resident harmlessly.
	var pebble: RigidBody3D = null
	for body in remote.bodies:
		if float(body.get_meta("radius",0.0)) < remote.STRIKE_RADIUS: pebble = body
	if pebble != null:
		pebble.global_position = actor.global_position+Vector3(0.3,1.0,0)
		pebble.linear_velocity = Vector3(-9,0,0)
		await ticks(2)
	check(not actor.blast_airborne,"Small dirt does not knock Bigfoot down")
	# A slow slab resting against him does not either.
	slab.global_position = actor.global_position+Vector3(0.4,1.0,0)
	slab.linear_velocity = Vector3(-1,0,0)
	await ticks(2)
	check(not actor.blast_airborne,"Slow debris does not knock Bigfoot down")
	var before := actor.global_position
	slab.global_position = actor.global_position+Vector3(1.2,1.2,0)
	slab.linear_velocity = Vector3(-12,0,0)
	await ticks(3)
	check(actor.blast_airborne and actor.wind_body.active,"Fast heavy debris knocks Bigfoot into a tumble")
	check(actor.wind_body.linear_velocity.x < -2.0,"Bigfoot is carried along the debris direction")
	check(actor.wind_body.collision_mask & 4 != 0,"A tumbling Bigfoot keeps colliding with debris")
	await ticks(60)
	check(actor.global_position.distance_to(before) > 0.5,"Bigfoot is actually moved by the hit")
	editor.undo()
	check(actor.global_position.distance_to(before) < 0.01 and not actor.wind_body.active,"Undo last blast restores Bigfoot after a debris hit")
	# A static authored rock joins the solver when struck.
	editor.data.place("rock",Vector2(-8.2,0),0,0.7)
	editor.refresh()
	remote.target_id = charge
	remote.detonate()
	var world_play = scene.world_play
	check(not world_play._active.has(rock),"Distant rock stays authored before any hit")
	var rock_point: Vector3 = editor.terrain.to_global(editor.data.object_position(editor.data.object_by_id(rock)))
	slab = null
	for body in remote.bodies:
		if float(body.get_meta("radius",0.0)) >= remote.STRIKE_RADIUS and (slab == null or body.mass > slab.mass): slab = body
	slab.global_position = rock_point+Vector3(-1.4,0.6,0)
	slab.linear_velocity = Vector3(14,0,0)
	var struck := false
	for i in range(40):
		await physics_frame
		if world_play._active.has(rock):
			struck = true
			break
	check(struck,"Debris unseats an authored rock it strikes")
	var loose: Node3D = world_play._active.get(rock)
	check(loose is RigidBody3D and not loose.freeze and loose.linear_velocity.length() > 0.5,"The struck rock takes the hit and moves")
	# Debris reaching a pond splashes it and wallows instead of skating on.
	editor.undo()
	editor.data.begin_stroke()
	editor.data.brush(Vector2(0,-8),2.5,1.0,"lower",0.0)
	editor.data.end_stroke()
	check(editor.data.add_pond(Vector2(0,-8),1.6),"Dig a pond for debris to land in")
	editor.refresh()
	remote.target_id = charge
	remote.detonate()
	var water = world_play.water_play
	var splashes: int = water.splash_count
	slab = null
	for body in remote.bodies:
		if float(body.get_meta("radius",0.0)) >= remote.STRIKE_RADIUS and (slab == null or body.mass > slab.mass): slab = body
	slab.global_position = Vector3(0,3.5,-8)
	slab.linear_velocity = Vector3(0,-6,0)
	var splashed := false
	for i in range(60):
		await physics_frame
		if water.splash_count > splashes:
			splashed = true
			break
	check(splashed and slab.has_meta("wet"),"Debris splashes the pond it falls into")
	check(slab.linear_damp > 1.0,"Wet debris wallows instead of skating")
	scene.queue_free()
	await process_frame
	print("Debris strikes: ",failures," failures")
	quit(1 if failures else 0)
