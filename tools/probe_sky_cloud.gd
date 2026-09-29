extends SceneTree
## Headless probe of the sky's cloud (docs/scenic/sky-cloud.md), on the cozy
## worlds scene with synthesized input:
##   - the cloud floats in the sky, on screen, full;
##   - hover takes the "cloud" zone and the hand opens over it; empty sky
##     still snaps;
##   - a press pinches it ("cloud"); a short pull springs back and keeps its
##     water;
##   - a long pull stretches it (the hand lags the pointer), tears a tuft,
##     and carried over the land the tuft becomes the held water ball, which
##     fills from the cloud while drops run into it; let go, it lands;
##   - a tuft let go over the sky drifts home and gives its water back;
##   - a dry cloud stretches but does not tear; it refills with time;
##   - there is no seed pod; the plain has one wild tree;
##   - the tree tugged a little throws nothing; bent well over and let go it
##     flicks its spores the way it whips, which settle and grow mostly its
##     own kind (the land bends some);
##     then it rests.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_sky_cloud.gd -- --no-title
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var cloud: Node3D
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	point(at)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point(at: Vector2) -> void:
	editor.pointer_override = at
	reach.pointer_override = at

func frames(count: int) -> void:
	for i in range(count): await process_frame

## Drag from `from` to `to` in `steps`, a frame each; stops early when `until` says so.
func drag(from: Vector2, to: Vector2, steps: int, until := Callable()) -> Vector2:
	var p := from
	for i in range(steps):
		var step := (to-from)/steps
		p += step
		motion(p,step)
		await frames(1)
		if until.is_valid() and until.call(): break
	return p

func ground(p: Vector2) -> Vector2:
	var h := float(editor.data.sample(p,editor.data.heights))
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,h,p.y)))

func cloud_screen() -> Vector2:
	return scene.camera.unproject_position(cloud.centre)

func run() -> void:
	create_timer(260).timeout.connect(func() -> void: push_error("sky cloud probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-sky-cloud-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	scene.world_clock.running = false
	cloud = reach.get("cloud")
	check("the cloud is made under the modeless hand",cloud != null)
	if cloud == null:
		quit(1)
		return
	await frames(90)
	var size := Vector2(root.size)
	var at := cloud_screen()
	check("it floats in the sky, full",cloud.visible and cloud.water == cloud.CAPACITY and not scene.camera.is_position_behind(cloud.centre),[cloud.centre,cloud.water])
	check("it is on screen",Rect2(Vector2.ZERO,size).has_point(at),at)
	check("it stands above the land on screen",at.y < ground(Vector2.ZERO).y,[at,ground(Vector2.ZERO)])

	# Hover.
	var hand: Node3D = scene.get("god_hand")
	point(at)
	await frames(4)
	check("hover over it is the cloud's zone",reach.hover_zone == "cloud",reach.hover_zone)
	check("the hand opens over it",hand == null or hand.reach_gesture == "void",hand.reach_gesture if hand != null else "")

	# Empty sky still snaps.
	var sky := Vector2.INF
	for candidate in [Vector2(40,20),Vector2(1400,20),Vector2(720,10),Vector2(40,200),Vector2(1400,200)]:
		if reach.void_at(candidate) and reach._cloud_at(candidate) == null:
			sky = candidate
			break
	check("found empty sky beside it",sky != Vector2.INF)
	if sky != Vector2.INF:
		var snaps: int = reach.snaps
		point(sky)
		await frames(3)
		button(sky,true)
		await frames(2)
		button(sky,false)
		await frames(20)
		check("a click on empty sky still snaps",reach.snaps == snaps+1)

	# A short pull springs back.
	at = cloud_screen()
	point(at)
	await frames(4)
	button(at,true)
	await frames(2)
	check("a press pinches the cloud",reach.holding == "cloud" and cloud.state == "held",[reach.holding,cloud.state])
	check("the hand pinches",hand == null or hand.reach_gesture == "cloud",hand.reach_gesture if hand != null else "")
	var p: Vector2 = await drag(at,at+Vector2(0,60),10)
	await frames(10)
	var stretch: float = cloud._stretch.length()
	check("a short pull stretches it",stretch > 0.5 and cloud.tension > 0.2 and cloud.tension < 1.0,[stretch,cloud.tension])
	button(p,false)
	await frames(90)
	var offset := 0.0
	for i in range(cloud.BODY): offset = maxf(offset,cloud._offset[i].length())
	check("let go, it springs back and keeps its water",cloud.state == "idle" and offset < 0.2 and cloud.water == cloud.CAPACITY and cloud.tears == 0,[cloud.state,offset,cloud.water])

	# A long pull tears a tuft; over the land it is the ball.
	var land := ground(Vector2(0,2))
	var settled := {}
	editor.ball_settled.connect(func(outcome: Dictionary) -> void: settled.merge(outcome))
	at = cloud_screen()
	point(at)
	await frames(4)
	button(at,true)
	await frames(2)
	var lag := 0.0
	var steps := 40
	p = at
	for i in range(steps):
		var step := (land-at)/steps
		p += step
		motion(p,step)
		await frames(1)
		if cloud.state == "held":
			lag = maxf(lag,scene.camera.unproject_position(cloud.hand_point()).distance_to(p))
		if editor._ball_holding: break
	check("pulled, the hand lags the pointer (the cloud resists)",lag > 30.0,"%.0f px" % lag)
	check("pulled far enough, a tuft tears",cloud.tears == 1,cloud.tears)
	check("over the land the tuft becomes the held ball",editor._ball_holding and reach.holding.is_empty() and cloud.state in ["into","idle"],[editor._ball_holding,reach.holding,cloud.state])
	check("the hand cups it",editor.hand_gesture() == "cup")
	var water_at_tear: float = cloud.water
	await frames(90)
	var drops: int = cloud._drop_node.multimesh.visible_instance_count
	check("the ball fills from the cloud",editor.ball_volume > editor.BALL_MIN_VOLUME+0.5 and cloud.water < water_at_tear-0.5,[editor.ball_volume,cloud.water])
	check("what the ball holds is what the cloud gave",absf(cloud.given-editor.ball_volume) < 0.01 and absf(cloud.CAPACITY-cloud.water-cloud.given) < 0.01,[cloud.given,editor.ball_volume,cloud.water])
	check("drops run into it",drops > 0,drops)
	var shown: float = cloud.shown
	check("the cloud looks thinner",shown < 0.98,shown)
	button(p,false)
	for i in range(240):
		await frames(1)
		if not settled.is_empty(): break
	check("let go, the ball lands",not settled.is_empty(),settled)
	await frames(10)
	check("the drops stop",cloud._drop_node.multimesh.visible_instance_count == 0)

	# A tuft let go over the sky goes home.
	cloud.water = cloud.CAPACITY
	await frames(30)
	at = cloud_screen()
	point(at)
	await frames(4)
	button(at,true)
	await frames(2)
	var up := Vector2(at.x,maxf(at.y-400.0,-600.0))
	p = await drag(at,up,30,func() -> bool: return cloud.torn())
	check("pulled up into the sky, a tuft tears too",cloud.torn(),cloud.state)
	var before: float = cloud.water
	button(p,false)
	await frames(2)
	check("let go over the sky, it drifts home",cloud.state == "returning",cloud.state)
	await frames(120)
	check("and gives its water back",cloud.state == "idle" and cloud.water >= before+cloud.TEAR_TAKES-0.001,[cloud.state,cloud.water,before])

	# Dry.
	cloud.water = 0.3
	await frames(30)
	at = cloud_screen()
	point(at)
	await frames(4)
	button(at,true)
	await frames(2)
	p = await drag(at,at+Vector2(0,300),30)
	check("a dry cloud stretches but does not tear",cloud.state == "held" and cloud.dry and cloud.tears == 2,[cloud.state,cloud.dry,cloud.tears])
	button(p,false)
	await frames(60)
	var low: float = cloud.water
	await create_timer(1.0).timeout
	check("it refills with time",cloud.water > low+0.3,[low,cloud.water])

	await wild_tree()
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

## The wild tree and its flick.
func camera() -> Camera3D:
	return scene.camera

func wild_tree() -> void:
	check("there is no seed pod",reach.get("pod") == null)
	var play: Variant = scene.get("world_play")
	var wild := editor.data.objects.filter(func(r: Dictionary) -> bool: return str(r.asset) in preload("res://scripts/genesis_canvas.gd").WILD_KINDS and is_equal_approx(float(r.scale),1.35))
	check("the plain has its one wild tree",wild.size() == 1,wild.size())
	var id := -1
	var foot := Vector3.ZERO
	for record_id in play._records:
		var record: Dictionary = play._records[record_id]
		if wild.is_empty() or int(record_id) != int(wild[0].id): continue
		var base: Vector3 = editor.terrain.global_transform*editor.data.object_position(record)
		# A birch's trunk is slim: up in its crown if the trunk misses.
		for height: float in [1.5,3.0,4.5]:
			var s: Vector2 = camera().unproject_position(base+Vector3.UP*height)
			if Rect2(Vector2(100,100),Vector2(root.size)-Vector2(200,200)).has_point(s) and play.pick_object(s) == int(record_id):
				id = int(record_id)
				foot = base+Vector3.UP*(height-1.5)
				break
	if id < 0:
		check("the wild tree is on screen to grab",false)
		return
	var kind := str(play._records[id].asset)
	var at_tree: Vector2 = camera().unproject_position(foot+Vector3.UP*1.5)
	point(at_tree)
	await frames(3)
	button(at_tree,true)
	await frames(2)
	check("a press on a tree takes it in hand",reach.holding == "tree",[reach.holding,kind])
	var spores: int = reach.tree_spores
	# Pulled away from the plate's middle, it throws inward over open land.
	var outward: Vector2 = (at_tree-ground(Vector2.ZERO)).normalized()*6.0
	# A little tug throws nothing.
	var p := at_tree
	for i in range(3):
		p += outward
		motion(p,outward)
		await frames(1)
	var tree: Node3D = reach._tree
	var small: float = tree.tension if is_instance_valid(tree) else -1.0
	button(p,false)
	await frames(2)
	check("a little tug throws nothing",small < reach.FLICK_MIN and reach.tree_spores == spores and (editor.handful == null or not editor.handful.active()),[small,reach.tree_spores])
	# A tree still springing cannot be picked (world play skips promoted ones).
	for i in range(600):
		await frames(1)
		if not reach._springing.has(id): break
	at_tree = camera().unproject_position(foot+Vector3.UP*1.5)
	point(at_tree)
	await frames(3)
	button(at_tree,true)
	await frames(2)
	check("pressed again, it is in hand",reach.holding == "tree",[reach.holding,reach.hover_zone])
	p = at_tree
	for i in range(80):
		p += outward
		motion(p,outward)
		await frames(1)
		tree = reach._tree
		if is_instance_valid(tree) and tree.tension > 0.9: break
	var tension: float = tree.tension if is_instance_valid(tree) else -1.0
	var sowings: Dictionary = editor.last_sowing
	button(p,false)
	await frames(2)
	tree = play._active.get(id)
	check("bent well over and let go, it flicks its spores",tension > 0.9 and reach.tree_spores == spores+1 and reach.holding.is_empty() and editor.handful.active() and not editor._handful_holding,[tension,reach.tree_spores,reach.holding])
	check("the spores carry the tree's kind",str(editor.handful.seed_kind) == kind,[editor.handful.seed_kind,kind])
	check("and whip out of its crown",editor.handful.motes_in_air() > 0 and is_instance_valid(tree) and not tree.held)
	# Up to 15 s: the slowest mote is down about 10.3 s after the flick
	# (PollenCloud LIFT + WAVE + JITTER + FALL.y).
	for i in range(900):
		await frames(1)
		if editor.last_sowing != sowings: break
	var seeds: PackedVector2Array = editor.last_sowing.get("seeds",PackedVector2Array())
	var middle := Vector2.ZERO
	for q in seeds: middle += q/float(maxi(seeds.size(),1))
	var foot_plate := Vector2(float(play._records[id].x),float(play._records[id].z))
	check("they land the way it whipped, against the pull",seeds.size() > 0 and (middle-foot_plate).dot(foot_plate) < 0.0,[seeds.size(),middle,foot_plate])
	check("let go, it sows that kind",str(editor.last_sowing.get("kind","")) == kind,editor.last_sowing.get("kind",""))
	# The forest comes up from the seeds: mostly the tree's own kind.
	var before := {}
	for record: Dictionary in editor.data.objects: before[int(record.id)] = true
	var area: Rect2 = (editor.last_sowing.bounds as Rect2).grow(2.0)
	# Wait (up to 40 s) for a few of its trees; the water's may be planned first.
	var grown := {}
	var total := 0
	var waited := 0.0
	while total < 4 and waited < 40.0:
		await create_timer(1.0).timeout
		waited += 1.0
		grown.clear()
		total = 0
		for record: Dictionary in editor.data.objects:
			if before.has(int(record.id)) or str(record.get("source","")) != "emerged" or not str(record.asset) in reach.SPORE_KINDS+["joshua","cactus"]: continue
			# Only this sowing's forest, not the water's still coming up elsewhere.
			if not area.has_point(Vector2(float(record.x),float(record.z))): continue
			grown[str(record.asset)] = int(grown.get(str(record.asset),0))+1
			total += 1
	# The trees standing on the seeds themselves are all its kind.
	var on_seeds := {}
	for record: Dictionary in editor.data.objects:
		if before.has(int(record.id)) or str(record.get("source","")) != "emerged": continue
		var at_record := Vector2(float(record.x),float(record.z))
		for seed: Vector2 in (editor.last_sowing.seeds as PackedVector2Array):
			if seed.distance_to(at_record) < 0.05:
				on_seeds[str(record.asset)] = int(on_seeds.get(str(record.asset),0))+1
				break
	# The land bends the kind (Emergence `_heir_kind`): mostly its own, not all.
	var own_on_seeds := int(on_seeds.get(kind,0))
	var all_on_seeds := 0
	for n: int in on_seeds.values(): all_on_seeds += n
	check("its kind leads on its seeds",all_on_seeds > 0 and own_on_seeds*2 >= all_on_seeds,on_seeds)
	check("and its kind leads the forest round them",total > 0 and int(grown.get(kind,0))*2 >= total,grown)
	# Bent again at once, it rests.
	await frames(30)
	at_tree = camera().unproject_position(foot+Vector3.UP*1.5)
	point(at_tree)
	await frames(3)
	button(at_tree,true)
	await frames(2)
	tree = reach._tree
	check("a second press takes the tree again",reach.holding == "tree" and is_instance_valid(tree),reach.holding)
	p = at_tree
	for i in range(80):
		p += outward
		motion(p,outward)
		await frames(1)
	# The hand keeps the bend across world refreshes (the forest coming up).
	tree = reach._tree
	var bent: bool = is_instance_valid(tree) and reach.holding == "tree" and tree.tension > 0.9
	check("bent again at once, it stays in hand through the refreshes",bent,[reach.holding,tree.tension if is_instance_valid(tree) else -1.0])
	button(p,false)
	await frames(2)
	check("and let go, a tree that has just given its spores throws none",reach.tree_spores == spores+1 and not editor.handful.active(),[reach.tree_spores,editor.handful.motes_in_air()])
	await frames(240)
	var rested: Variant = play._active.get(id)
	# At rest a refresh may hand it back to its batch, which is the same pose.
	check("let go, it springs back to rest",not reach._springing.has(id) and (not is_instance_valid(rested) or rested.bend == Vector2.ZERO),rested.bend if is_instance_valid(rested) else "back in its batch")
