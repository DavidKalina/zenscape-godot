extends SceneTree
## Headless probe of the summoned cloud (docs/scenic/sky-cloud.md "Summoned"),
## on the cozy worlds scene with synthesized input:
##   - no cloud at rest; the session's first world shows it once by itself
##     (the demo), which hangs, drifts off and thins away; then the void's
##     hint names the summon;
##   - a quick click on empty sky still snaps, and a quick drag is still the
##     wind; neither calls the cloud;
##   - a still hold calls it into a cupped hand; its puffs swell with an
##     overshoot; the hold going on into a pull tears a tuft before it has
##     finished forming, and over the land the tuft is the held ball, all in
##     one press; let go, the ball lands;
##   - with no cloud, a press that pauses under the summon's hold and then
##     drags is still the wind;
##   - the lingering cloud plucks again at once, with a pinch;
##   - while it is up, empty sky is the snap's and the wind's: a click
##     snaps, a press that pauses long and then drags is wind, and neither
##     moves or re-calls the cloud; it floats within its bounds over 20 s,
##     and a hand hovering by it keeps it past its linger;
##   - left alone, it drifts off and is gone; wrung dry, it goes sooner;
##   - a hold let go without a pull snaps nothing and leaves the cloud.
## The old always-there cloud (`--always-cloud`) is tools/probe_sky_cloud.gd.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_summoned_cloud.gd -- --no-title
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var cloud: Node3D
var hand: Node3D
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

func ground(p: Vector2) -> Vector2:
	var h := float(editor.data.sample(p,editor.data.heights))
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,h,p.y)))

func gesture() -> String:
	return hand.reach_gesture if hand != null else ""

## Empty sky, clear of the cloud, near `near`.
func sky_near(candidates: Array) -> Vector2:
	for candidate: Vector2 in candidates:
		if reach.void_at(candidate) and reach._cloud_at(candidate) == null: return candidate
	return Vector2.INF

## The biggest puff's size over its full size (breath aside): above 1 in an overshoot.
func swell() -> float:
	var most := 0.0
	for i in range(cloud.BODY): most = maxf(most,cloud._size[i]/(cloud._radius[i]*cloud.size))
	return most

## The cloud's bulk: its puffs' sizes over their full sizes, together.
func bulk() -> float:
	var shown := 0.0
	var full := 0.0
	for i in range(cloud.BODY):
		shown += cloud._size[i]
		full += cloud._radius[i]*cloud.size
	return shown/maxf(full,0.001)

## Press at `at`, wait `pause` frames still, then drag `by` in `steps` frames and let go.
func press_drag(at: Vector2, pause: int, by: Vector2, steps: int) -> void:
	point(at)
	await frames(3)
	button(at,true)
	await frames(pause)
	var p := at
	for i in range(steps):
		p += by/steps
		motion(p,by/steps)
		await frames(1)
	button(p,false)
	await frames(10)

## Empty sky at least `away` px from the cloud on screen, or INF.
func sky_away(away: float) -> Vector2:
	var cloud_at: Vector2 = scene.camera.unproject_position(cloud.centre)
	for y in [20.0,60.0,120.0,200.0]:
		for x in [40.0,1400.0,300.0,1140.0,720.0]:
			var candidate := Vector2(float(x),float(y))
			if candidate.distance_to(cloud_at) >= away and reach.void_at(candidate) and not cloud.near(candidate): return candidate
	return Vector2.INF

## Press at `at`, pull toward the land in `steps` frames; stops once the ball is held.
func pull_to_land(at: Vector2, steps: int) -> Vector2:
	var land := ground(Vector2(0,2))
	var p := at
	for i in range(steps):
		var step := (land-at)/steps
		p += step
		motion(p,step)
		await frames(1)
		if editor._ball_holding: break
	return p

func land_ball(p: Vector2) -> bool:
	var settled := {}
	var catch := func(outcome: Dictionary) -> void: settled.merge(outcome)
	editor.ball_settled.connect(catch)
	button(p,false)
	for i in range(300):
		await frames(1)
		if not settled.is_empty(): break
	editor.ball_settled.disconnect(catch)
	return not settled.is_empty()

func run() -> void:
	create_timer(260).timeout.connect(func() -> void: push_error("summoned cloud probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-summon-cloud-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	editor = scene._chunk_editor
	reach = scene.hand_reach
	hand = scene.get("god_hand")
	scene.world_clock.running = false
	cloud = reach.get("cloud")
	check("the cloud is made under the modeless hand, summoned",cloud != null and cloud.summoned)
	if cloud == null:
		quit(1)
		return
	await frames(10)
	check("no cloud in the sky at rest",not cloud.visible and cloud.presence == "gone",[cloud.visible,cloud.presence])

	# The demo: it forms by itself once, hangs, drifts off and thins away.
	for i in range(int((cloud.DEMO_DELAY+3.0)*60.0)):
		await frames(1)
		if cloud.presence != "gone": break
	check("the first world shows the cloud once by itself",cloud.presence == "forming" and cloud.demo and cloud.visible,[cloud.presence,cloud.demo])
	await frames(int(cloud.FORM_SECONDS*60.0)+10)
	var at: Vector2 = scene.camera.unproject_position(cloud.centre)
	check("the demo hangs in the sky, on screen above the land",cloud.presence == "here" and Rect2(Vector2.ZERO,Vector2(root.size)).has_point(at) and at.y < ground(Vector2.ZERO).y,[cloud.presence,at])
	var hung: Vector3 = cloud.centre
	for i in range(int((cloud.DEMO_LINGER+2.0)*60.0)):
		await frames(1)
		if cloud.presence == "leaving": break
	check("then it leaves",cloud.presence == "leaving",cloud.presence)
	await frames(int(cloud.LEAVE_SECONDS*30.0))
	var thinned := bulk()
	check("drifting off and thinning",cloud.centre.distance_to(hung) > 1.0 and thinned < 0.9,[cloud.centre.distance_to(hung),thinned])
	await frames(int(cloud.LEAVE_SECONDS*30.0)+10)
	check("and is gone",cloud.presence == "gone" and not cloud.visible,cloud.presence)
	await frames(int(cloud.DEMO_DELAY*60.0)+30)
	check("the demo shows only once",cloud.presence == "gone",cloud.presence)

	var sky := sky_near([Vector2(60,30),Vector2(1380,30),Vector2(720,20),Vector2(60,200),Vector2(1380,200)])
	check("found empty sky",sky != Vector2.INF)
	if sky == Vector2.INF:
		quit(1)
		return
	point(sky)
	await frames(4)
	check("after the demo the sky's hint names the summon",reach._hint == reach.SUMMON_HINT,reach._hint)

	# A quick click still snaps.
	var snaps: int = reach.snaps
	button(sky,true)
	await frames(3)
	button(sky,false)
	await frames(20)
	check("a quick click on empty sky still snaps",reach.snaps == snaps+1 and cloud.presence == "gone",[reach.snaps-snaps,cloud.presence])

	# A quick drag is still the wind.
	var winds := int(reach.uses.get("wind",0))
	snaps = reach.snaps
	var across := Vector2(1.0 if sky.x < 720.0 else -1.0,0.0)*220.0
	point(sky)
	await frames(3)
	button(sky,true)
	await frames(1)
	var p := sky
	for i in range(8):
		p += across/8.0
		motion(p,across/8.0)
		await frames(1)
	button(p,false)
	await frames(10)
	check("a quick drag is still the wind",int(reach.uses.get("wind",0)) == winds+1 and reach.snaps == snaps and cloud.presence == "gone" and cloud.summons == 0,[int(reach.uses.get("wind",0))-winds,reach.snaps-snaps,cloud.presence])
	await frames(30)
	# A pause shorter than the summon's hold, then a drag: still the wind.
	winds = int(reach.uses.get("wind",0))
	await press_drag(sky,int(reach.SUMMON_HOLD*60.0)-8,across,20)
	check("with no cloud, a short pause then a drag is still the wind",int(reach.uses.get("wind",0)) == winds+1 and cloud.presence == "gone" and cloud.summons == 0,[int(reach.uses.get("wind",0))-winds,cloud.presence])
	await frames(30)

	# A still hold calls it; the same press pulls, tears and makes the ball.
	snaps = reach.snaps
	point(sky)
	await frames(3)
	button(sky,true)
	await frames(int(reach.SUMMON_HOLD*60.0)-6)
	check("a hold shorter than the summon's is still the snap's",reach.holding == "void" and cloud.presence == "gone",[reach.holding,cloud.presence])
	await frames(8)
	check("held still, it calls the cloud into the hand",reach.holding == "cloud" and cloud.presence == "forming" and cloud.state == "held" and cloud.summons == 1,[reach.holding,cloud.presence,cloud.state])
	await frames(1)
	check("the hand cups as it forms",gesture() == "summon",gesture())
	var pinch: Vector2 = scene.camera.unproject_position(cloud.hand_point())
	check("it forms round the hand's pinch, under the pointer",pinch.distance_to(sky) < 4.0,pinch.distance_to(sky))
	var most := 0.0
	var drops := 0
	for i in range(12):
		await frames(1)
		most = maxf(most,swell())
		drops = maxi(drops,cloud._drop_node.multimesh.visible_instance_count)
	check("droplets gather in as it forms",drops > 5,drops)
	# The pull begins before it has finished forming.
	var tears: int = cloud.tears
	var formed_at_tear := -1.0
	var pinched_before_tear := false
	var land := ground(Vector2(0,2))
	p = sky
	for i in range(40):
		var step := (land-sky)/40.0
		p += step
		motion(p,step)
		await frames(1)
		most = maxf(most,swell())
		if cloud.tears == tears and gesture() == "cloud": pinched_before_tear = true
		if formed_at_tear < 0.0 and cloud.tears > tears: formed_at_tear = cloud._form_time if cloud.forming() else cloud.FORM_SECONDS
		if editor._ball_holding: break
	check("the hand pinches once it pulls",pinched_before_tear)
	check("the puffs swell with an overshoot",most > 1.06 and most < 1.3,"%.3f" % most)
	check("a quick pull tears it before it has finished forming",cloud.tears == tears+1 and formed_at_tear >= cloud.TEAR_FORM-0.001 and formed_at_tear < cloud.FORM_SECONDS,formed_at_tear)
	check("over the land the tuft is the held ball, in the same press",editor._ball_holding and reach.holding.is_empty() and editor.hand_gesture() == "cup" and reach.snaps == snaps,[editor._ball_holding,reach.holding,reach.snaps-snaps])
	await frames(60)
	check("the ball fills from the cloud",absf(cloud.given-editor.ball_volume) < 0.01 and cloud.water < cloud.CAPACITY-0.5,[cloud.given,editor.ball_volume])
	check("let go, the ball lands",await land_ball(p))
	check("the cloud lingers",cloud.presence == "here" and cloud.visible,cloud.presence)

	# The lingering cloud plucks again at once.
	await frames(20)
	at = scene.camera.unproject_position(cloud.centre)
	point(at)
	await frames(4)
	check("hover over the lingering cloud is the cloud's",reach.hover_zone == "cloud",reach.hover_zone)
	button(at,true)
	await frames(2)
	check("pressed, it is pinched straight away",reach.holding == "cloud" and cloud.state == "held" and gesture() == "cloud",[reach.holding,gesture()])
	tears = cloud.tears
	p = await pull_to_land(at,40)
	check("and plucks again: a second ball",cloud.tears == tears+1 and editor._ball_holding and cloud.summons == 1,[cloud.tears,editor._ball_holding])
	check("let go, it lands",await land_ball(p))

	# While it is up, empty sky is the snap's and the wind's.
	var anchor: Vector3 = cloud._anchor
	var bound: Vector2 = cloud.float_reach()
	var elsewhere := sky_away(350.0)
	check("found empty sky away from the cloud",elsewhere != Vector2.INF)
	if elsewhere != Vector2.INF:
		snaps = reach.snaps
		point(elsewhere)
		await frames(3)
		button(elsewhere,true)
		await frames(3)
		button(elsewhere,false)
		await frames(20)
		check("while it is up, a click elsewhere snaps",reach.snaps == snaps+1 and cloud.summons == 1,[reach.snaps-snaps,cloud.summons])
		winds = int(reach.uses.get("wind",0))
		var sweeps: int = reach.wind.sweeps
		var way := Vector2(1.0 if elsewhere.x < 720.0 else -1.0,0.0)*200.0
		# Held still well past the summon's hold, then dragged: a held wind.
		await press_drag(elsewhere,int(reach.SUMMON_HOLD*60.0)*2,way,30)
		check("while it is up, a long pause then a drag elsewhere is the wind",int(reach.uses.get("wind",0)) == winds+1 and reach.wind.sweeps == sweeps+1 and cloud.summons == 1 and reach.holding.is_empty(),[int(reach.uses.get("wind",0))-winds,reach.wind.sweeps-sweeps,cloud.summons])
		check("and the cloud stays where it formed",cloud._anchor == anchor and cloud.presence == "here",[cloud._anchor.distance_to(anchor),cloud.presence])
	# It floats within its bounds; a hand hovering by it keeps it up.
	var farthest := Vector2.ZERO
	for i in range(20*60):
		point(scene.camera.unproject_position(cloud.centre))
		await frames(1)
		var off: Vector3 = cloud.centre-anchor
		farthest = Vector2(maxf(farthest.x,Vector2(off.x,off.z).length()),maxf(farthest.y,absf(off.y)))
	check("over 20 s it floats within its sway, never following",farthest.x <= bound.x+0.01 and farthest.y <= bound.y+0.01 and farthest.x > 0.1,[farthest,bound])
	check("a hand hovering by it keeps it past its linger",cloud.presence == "here" and cloud._idle < 1.0,[cloud.presence,cloud._idle])
	at = scene.camera.unproject_position(cloud.centre)
	point(at)
	await frames(4)
	button(at,true)
	await frames(2)
	tears = cloud.tears
	p = await pull_to_land(at,40)
	check("a press on it still plucks",cloud.tears == tears+1 and editor._ball_holding,[cloud.tears-tears,editor._ball_holding])
	check("and that ball lands",await land_ball(p))
	point(sky_away(350.0))

	# Left alone, it leaves.
	var stood: Vector3 = cloud.centre
	var waited := 0
	for i in range(int((cloud.LINGER+3.0)*60.0)):
		await frames(1)
		waited += 1
		if cloud.presence == "leaving": break
	check("left alone about %d s, it drifts off" % int(cloud.LINGER),cloud.presence == "leaving" and waited > int((cloud.LINGER-1.0)*60.0),[cloud.presence,waited/60.0])
	await frames(int(cloud.LEAVE_SECONDS*60.0)+10)
	check("and thins away",cloud.presence == "gone" and not cloud.visible and cloud.centre.distance_to(stood) > 1.0,[cloud.presence,cloud.centre.distance_to(stood)])
	point(at)
	await frames(4)
	check("where it was is empty sky again",reach.hover_zone != "cloud",reach.hover_zone)

	# A hold let go without a pull: no snap, the cloud stays; wrung dry, it goes sooner.
	snaps = reach.snaps
	point(sky)
	await frames(3)
	button(sky,true)
	await frames(int(reach.SUMMON_HOLD*60.0)+4)
	button(sky,false)
	await frames(int(cloud.FORM_SECONDS*60.0)+10)
	check("a hold let go calls the cloud and snaps nothing",cloud.presence == "here" and reach.snaps == snaps and cloud.summons == 2,[cloud.presence,reach.snaps-snaps])
	point(sky_away(350.0))
	cloud.water = 0.2
	cloud.wrung = true
	waited = 0
	for i in range(int((cloud.LINGER)*60.0)):
		await frames(1)
		waited += 1
		if cloud.presence == "leaving": break
	check("wrung dry, it leaves sooner",cloud.presence == "leaving" and waited < int((cloud.DRY_LINGER+1.0)*60.0),[cloud.presence,waited/60.0])

	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
