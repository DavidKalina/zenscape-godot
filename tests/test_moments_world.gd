extends SceneTree
## suite: slow
## The moments set pieces in the game itself (--moments: scripts/
## sky_moments.gd, scripts/wanderer_eye.gd), headless: the real scene boots
## with them, the sky lays them; N in the plane hops it onto the next one's
## way in, flying its line; flown straight on from there, by the
## wanderer's own frames, the plane passes the leads and goes through the
## hoop, which starts the challenge; a free collectible flown through is
## taken and is in the world's saved sky state; the stone streams in with
## the plane near and goes far off; the frame's cost is printed.
const SkyWorld = preload("res://scripts/sky_world.gd")
const Plan = preload("res://scripts/sky_moments_plan.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
var failures := 0
var scene: Node3D
var eye: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _run() -> void:
	create_timer(600).timeout.connect(func() -> void: push_error("moments world timed out"); quit(2))
	# The set pieces are laid by the ring's world layout (SkyWorld `_moments`),
	# kept but unwired: this runs under --peak-ring --moments.
	preload("res://scripts/sky_homes.gd").use_flags(PackedStringArray(["--peak-ring"]))
	SkyWorld.moments = true
	# A window-sized root: headless it is 64x64, too small for the shell's layout.
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("no_title",true)
	var dir := OS.get_user_data_dir().path_join("test-moments-world-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	scene.places_path = dir.path_join("places.json")
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	eye = scene.wanderer
	var islands: Node3D = eye.islands
	var moments: Node3D = islands.moments
	check(moments != null,"With --moments the sky has its set pieces")
	if moments == null:
		quit(1)
		return
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	for i in range(5): await process_frame
	eye._launch(14.0,false)
	for i in range(10): await process_frame
	check(moments.placements.size() >= 10 and moments.beacons.size() == moments.placements.size(),"The sky lays %d of them, each hoop and beacon standing" % moments.placements.size())
	# N in the plane: onto the next one's way in, flying its line.
	var key := InputEventKey.new()
	key.keycode = KEY_N
	key.pressed = true
	eye.handle(key)
	var p: Dictionary = moments.placements[moments.hopped]
	var glide: RefCounted = eye.glide
	var local := Plan.unplace(p,(glide.position as Vector3)-islands.cells.origin)
	check(moments.hopped == 0 and local.distance_to(Vector3(0,0,moments.HOP_OUT)) < 0.5 and absf(angle_difference(float(glide.heading),Plan.heading(p))) < 0.01,
		"N hops the plane onto set piece %d's way in, flying its line (%s)" % [moments.hopped,local])
	# Flown straight on, the stone streams in and the hoop starts the
	# challenge.
	var worst := 0
	var total := 0
	var frames := 0
	var started := false
	var stood_at := -1.0
	for i in range(60*20):
		glide.position.y = (Plan.place(p,Vector3.ZERO)+islands.cells.origin).y
		glide.pitch = 0.0
		glide.heading = Plan.heading(p)
		eye._advance_flight(1.0/60.0)
		await process_frame
		var spent := int(islands.spent.get("moments",0))
		worst = maxi(worst,spent)
		total += spent
		frames += 1
		if stood_at < 0.0 and moments.standing().has(p.key): stood_at = Plan.unplace(p,(glide.position as Vector3)-islands.cells.origin).z
		if not moments.challenge.is_empty():
			started = true
			break
	check(stood_at > 0.0,"Its stone stood before the plane reached it (%.0f m out)" % stood_at)
	check(started,"Flown straight in through its hoop, the challenge starts")
	check(moments.hud.last_status.begins_with("challenge 0/"),"... and the HUD reads \"%s\"" % moments.hud.last_status)
	print("     the set pieces' frame (main thread): mean %.3f ms, worst %.3f ms over %d frames; stood in %.2f ms (made on a worker in %.1f ms)" % [
		total/1000.0/maxi(frames,1),worst/1000.0,frames,float(moments.stats.get(p.key,{}).get("stand_usec",0))/1000.0,float(moments.stats.get(p.key,{}).get("make_usec",0))/1000.0])
	# A free collectible flown through is taken and saved.
	# (The one whose straight 4 m run-in, along the station's -z, keeps
	# clearest of the stone: in the game's hall a free one by a bay line's
	# beam has its run-in through the beam.)
	var free: Dictionary = {}
	var solids: Array = Plan.local_solids(int(p.layout))
	var clearest := -INF
	for m: Dictionary in Plan.moments(int(p.layout)):
		if m.role != "free": continue
		var c := INF
		for k in range(9):
			for q: Dictionary in solids: c = minf(c,Plan.Course.distance(q,(m.at as Vector3)+Vector3(0,0,4.0-k)))
		if c > clearest:
			clearest = c
			free = m
	var from: Vector3 = Plan.place(p,(free.at as Vector3)+Vector3(0,0,4))+islands.cells.origin
	glide.position = from
	glide.velocity = Vector3.ZERO
	moments._last = Vector3.INF
	for i in range(30):
		glide.position.y = from.y
		glide.pitch = 0.0
		glide.heading = Plan.heading(p)
		eye._advance_flight(1.0/60.0)
		if moments.collected.has("%s:%d" % [p.key,int(free.index)]): break
	var id := "%s:%d" % [p.key,int(free.index)]
	check(moments.collected.has(id),"The plane flown through a free collectible takes it")
	var state: Dictionary = islands.save_state()
	check(state.get("moments",{}).get("free",[]).has(id),"... and it is in the world's saved sky")
	# Far off, the stone goes.
	var far: Vector3 = Plan.place(p,Vector3(0,0,3000))+islands.cells.origin
	# The plane taken there too (the wanderer's own frames advance the sky
	# round it).
	for i in range(90):
		glide.position = far
		islands.advance(1.0/60.0,far,0.0,0.0)
		await process_frame
	check(not moments.stations.has(p.key),"Flown far off, its stone goes (its hoop and beacon stay)")
	scene.queue_free()
	SkyWorld.moments = false
	await process_frame
	print("moments world: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
