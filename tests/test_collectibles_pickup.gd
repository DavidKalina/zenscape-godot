extends SceneTree
## suite: slow
## The sky's collectible tokens picked up in the game itself (scripts/
## wanderer_eye.gd, scripts/sky_collectibles.gd): the plane flown straight
## through an air token takes it, and the pilot perched on a cluster member
## walking onto a foot token takes that; both are in the world's saved sky
## state afterwards. Boots the real scene with --collectibles-near-home.
const SkyCollectibles = preload("res://scripts/sky_collectibles.gd")
var failures := 0
var scene: Node3D
var eye: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _run() -> void:
	create_timer(600).timeout.connect(func() -> void: push_error("collectibles pickup timed out"); quit(2))
	# A window-sized root: headless it is 64x64, too small for the shell's layout.
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("no_title",true)
	var dir := OS.get_user_data_dir().path_join("test-collectibles-pickup-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	scene.places_path = dir.path_join("places.json")
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	eye = scene.wanderer
	var islands: Node3D = eye.islands
	var tokens: Node3D = islands.collectibles
	check(tokens != null,"The sky has its collectible tokens")
	if tokens == null:
		quit(1)
		return
	tokens.near_home = true
	islands.clusters.with_near = SkyCollectibles.NEAR_MOTIFS.duplicate()
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	for i in range(5): await process_frame
	eye._launch(6.0,false)
	for i in range(30): await process_frame
	var home := Vector3(0.0,30.0,40.0)
	for s: Dictionary in islands.clusters.spots:
		if str(s.key).begins_with("near:"): islands.clusters.plan_now(s.key)
	for i in range(60):
		islands.advance(1.0/60.0,home,0.0,0.0)
		await process_frame
	tokens.flush(home)

	# The plane: set a little way short of an air token, heading straight
	# at it, flown on by the wanderer's own frames.
	var air := _token(tokens,"air")
	check(not air.is_empty(),"An air token stands near the home")
	if not air.is_empty():
		var at: Vector3 = air.holder.global_position
		var glide: RefCounted = eye.glide
		var from := islands.global_transform.affine_inverse()*(at+Vector3(0.0,0.0,6.0))
		glide.position = from
		glide.heading = 0.0
		glide.pitch = 0.0
		glide.bank = 0.0
		glide.speed = 14.0
		glide.velocity = glide.forward()*14.0
		tokens._last.clear()
		for i in range(40):
			glide.position.y = from.y
			glide.pitch = 0.0
			eye._advance_flight(1.0/60.0)
			if tokens.collected.has(air.id): break
		check(tokens.collected.has(air.id),"The plane flown through an air token takes it")

	# The pilot: perched on the member under a foot token, his feet set on
	# it by one step of the walker's own frame.
	var foot := _token(tokens,"foot")
	check(not foot.is_empty(),"A foot token stands near the home")
	if not foot.is_empty():
		var at: Vector3 = foot.holder.global_position
		var point: Vector3 = islands.global_transform.affine_inverse()*at
		var islet: Dictionary = islands.islets.islet_at(point)
		check(not islet.is_empty(),"The foot token stands over an islet")
		if not islet.is_empty():
			eye._perch(islet)
			for i in range(3): await process_frame
			var local: Vector3 = islands.islets.local_of(islet,point)
			eye.motor.feet = Vector3(local.x,float(islet.shape.ground_at(Vector2(local.x,local.z))),local.z)
			eye.motor.velocity = Vector3.ZERO
			tokens._last.clear()
			eye._advance_perch(1.0/60.0)
			check(tokens.collected.has(foot.id),"The pilot walking onto a foot token takes it")
	var state: Dictionary = islands.save_state()
	var kept: Dictionary = state.get("collectibles",{}).get("collected",{})
	check((air.is_empty() or kept.has(air.id)) and (foot.is_empty() or kept.has(foot.id)),"Both are in the world's saved sky (%d kept)" % kept.size())
	print("PASS: collectibles pickup" if failures == 0 else "FAIL: collectibles pickup (%d)" % failures)
	quit(1 if failures else 0)

## A standing token of `category` nearest the home: {id, holder}, or {}.
func _token(tokens: Node3D, category: String) -> Dictionary:
	var best := {}
	var best_d := INF
	for key in tokens.sources:
		var s: Dictionary = tokens.sources[key]
		for l: Dictionary in s.lines:
			if l.category != category or (category == "air" and l.kind == "trail"): continue
			for k in range((l.points as PackedVector3Array).size()):
				var id := "%s:%d" % [l.id,k]
				if not s.live.has(id) or not is_instance_valid(s.live[id]) or tokens.collected.has(id): continue
				var d: float = (s.live[id] as Node3D).global_position.length()
				if d < best_d:
					best_d = d
					best = {"id":id,"holder":s.live[id]}
	return best
