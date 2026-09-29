extends SceneTree
## Headless probe of the modeless rim slice (docs/scenic/modeless.md): the real
## product scene, `--modeless`, synthesized mouse input at a fixed 60 Hz.
## - a rim push turns the world, decides "turn", and flips nothing;
## - a slow turn leaves the clock alone;
## - a fast spin winds the clock in proportion to the spin, the world keeps
##   the new time, and the pins follow;
## - a shake on the rim still decides a shake and does not wind time;
## - a vertical rim drag emits the flip signals and does not turn;
## - the sun no longer grabs;
## - a left land press is not a turn or a brush stroke, and emits land_pressed;
## - a right drag tilts and looks round without changing time or the room;
## - the hand takes the zone's pose on hover.
## Nothing is rendered: how any of it feels or looks on screen is not checked.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_modeless_rim.gd -- --modeless
var scene: Node3D
var editor: NativeChunkEditor
var rig: Node
var turn: Node
var reach: Node
var clock: WorldClock
var failures := []
var rim_at := Vector2.ZERO
var land_at := Vector2.ZERO

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	event.factor = 1.0
	root.push_input(event)

func motion(at: Vector2, relative: Vector2, index := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

func hours() -> float:
	return float(clock.day)*24.0+clock.hour

## Press at `from`, move by `step` each frame `count` times; hold for `still`
## frames; optionally release. Returns where the pointer ended.
func drag(from: Vector2, step: Vector2, count: int, index := MOUSE_BUTTON_LEFT, release := true, still := 0) -> Vector2:
	button(from,index,true)
	await frames(1)
	var at := from
	for i in range(count):
		at += step
		motion(at,step,index)
		await frames(1)
	await frames(still)
	if release:
		button(at,index,false)
		await frames(1)
	return at

func rim_point() -> Vector2:
	var terrain: Node3D = editor.terrain
	var best := Vector2.ZERO
	var found := false
	for side in range(4):
		for i in range(9):
			var f := -10.0+20.0*i/8.0
			var edge: Vector2 = [Vector2(f,-14.1),Vector2(14.1,f),Vector2(f,14.1),Vector2(-14.1,f)][side]
			var top: float = float(editor.data.ground_height(edge.clamp(Vector2.ONE*-13.9,Vector2.ONE*13.9)))
			var world := terrain.to_global(Vector3(edge.x,top-0.5,edge.y))
			if scene.camera.is_position_behind(world): continue
			var at: Vector2 = scene.camera.unproject_position(world)
			if reach.reach_at(at) != "rim": continue
			if not found or at.y > best.y:
				best = at
				found = true
	return best if found else Vector2.ZERO

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("Modeless rim probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-modeless-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	rig = scene.camera_rig
	turn = rig.turn
	reach = scene.hand_reach
	clock = scene.world_clock
	check("run with --modeless",reach.modeless and turn.modeless)
	var data := editor.data
	data.begin_stroke()
	for _pass in range(14): data.brush(Vector2(5.0,-4.0),4.5,0.5,"raise",0.0)
	data.end_stroke()
	await editor.refresh(self)
	scene._overview()
	await frames(30)
	check("rig live",rig.live)
	scene.select_brush("land")
	await frames(2)
	clock.running = false
	scene.world_clock.season_override = 0.375
	var living: RefCounted = scene.get("living_weather")
	rim_at = rim_point()
	check("a rim point is found on screen",rim_at != Vector2.ZERO,rim_at)
	var ground: Variant = null
	for spot in [Vector2(-3,2),Vector2(0,0),Vector2(-6,4),Vector2(3,5)]:
		var h: Variant = data.ground_height(spot)
		if h == null: continue
		var at: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(Vector3(spot.x,float(h),spot.y)))
		if reach.reach_at(at) == "" and editor.pick(at) != null:
			ground = at
			break
	check("a land point is found on screen",ground != null,ground)
	land_at = ground if ground != null else Vector2(720,450)
	check("the tool rail is hidden",not scene.creation_palette.frame.visible and not scene.creation_palette.bar.visible)

	# --- The sun no longer grabs -----------------------------------------------
	scene._celestial.set_phase(0.5)
	await frames(3)
	var sun_screen: Variant = reach._screen(reach.body_direction("sun",0.5))
	var sun_reach: String = reach.reach_at(sun_screen) if sun_screen != null else ""
	check("the sun is not reached",sun_reach != "sun",sun_reach)
	if sun_screen != null:
		button(sun_screen,MOUSE_BUTTON_LEFT,true)
		await frames(2)
		check("pressing the sun holds nothing",reach.holding != "sun")
		button(sun_screen,MOUSE_BUTTON_LEFT,false)
		await frames(2)

	# --- Hover: the hand takes the zone's pose ---------------------------------
	if scene.god_hand != null:
		reach._hover_key = []
		reach._hover(rim_at)
		reach._drive_hand_modeless()
		check("over the rim the hand takes the rim grip",scene.god_hand.reach_gesture == "rim",scene.god_hand.reach_gesture)
		reach._hover_key = []
		reach._hover(land_at)
		reach._drive_hand_modeless()
		check("over the land it readies a pinch",scene.god_hand.reach_gesture == "pinch",scene.god_hand.reach_gesture)
		reach._hover_key = []
		reach._hover(Vector2(4,4))
		reach._drive_hand_modeless()
		check("over nothing it lets go",scene.god_hand.reach_gesture == "",scene.god_hand.reach_gesture)

	# --- A slow rim push turns the world and leaves the clock alone ------------
	scene._celestial.set_phase(0.5)
	await frames(2)
	var t0 := hours()
	var yaw0: float = scene.yaw
	var room0: float = turn.room_yaw
	var end := await drag(rim_at,Vector2(2.5,0),50,MOUSE_BUTTON_LEFT,false,20)
	check("a sideways rim push decides the turn",reach.rim_intent == "turn",reach.rim_intent)
	check("the rim push turns the world",absf(angle_difference(yaw0,scene.yaw)) > 0.05,rad_to_deg(scene.yaw-yaw0))
	check("the room turns with it",absf(turn.room_yaw-room0) > 0.05,rad_to_deg(turn.room_yaw-room0))
	check("the hand grips the rim",scene.god_hand == null or scene.god_hand.reach_gesture == "rim",scene.god_hand.reach_gesture if scene.god_hand != null else "")
	button(end,MOUSE_BUTTON_LEFT,false)
	await frames(90)
	check("a slow turn leaves the clock alone",absf(hours()-t0) < 0.001,hours()-t0)
	check("a slow turn does not spin on",not turn.spinning())
	check("the sky's shimmer is off for a slow turn",scene._celestial.shimmer == 0.0,scene._celestial.shimmer)

	# --- A fast spin winds the clock in proportion -------------------------------
	var results := []
	for step in [Vector2(50,0),Vector2(90,0)]:
		rim_at = rim_point()
		scene._celestial.set_phase(0.3)
		clock.set_time(clock.day,clock.hour)
		await frames(3)
		var start := hours()
		var season0 := clock.season_override
		var expected := 0.0
		var shimmered := 0.0
		var top := 0.0
		button(rim_at,MOUSE_BUTTON_LEFT,true)
		await frames(1)
		var at := rim_at
		# A push that keeps its direction: the near rim moves along the screen.
		var sign_step := 1.0
		for i in range(8):
			at += step*sign_step
			motion(at,step*sign_step)
			await frames(1)
			expected += scene.spin_time.hours_per_second/60.0
			shimmered = maxf(shimmered,scene._celestial.shimmer)
		button(at,MOUSE_BUTTON_LEFT,false)
		for i in range(1500):
			await frames(1)
			expected += scene.spin_time.hours_per_second/60.0
			top = maxf(top,absf(turn.spin))
			shimmered = maxf(shimmered,scene._celestial.shimmer)
			if not turn.spinning() and not scene.spin_time.winding and i > 10: break
		var wound := hours()-start
		var year_share: float = (clock.season_override-season0)
		print("  step %s: spin up to %.1f rad/s, wound %.1f h (%.2f days), expected %.1f h, season override %.3f -> %.3f, shimmer up to %.2f" % [step,top,wound,wound/24.0,expected,season0,clock.season_override,shimmered])
		results.append(wound)
		check("the fast flick spins on and winds time (%s)" % step,top > 3.0 and wound > 1.0)
		check("the wound time matches the spin's hours a second (%s)" % step,absf(wound-expected) < maxf(0.5,expected*0.03),{"wound":wound,"expected":expected})
		check("the anticipation cue shimmered (%s)" % step,shimmered > 0.2,shimmered)
		check("a held season rolled on with the days (%s)" % step,absf(fposmod(clock.season_override-season0,1.0)-fposmod(wound/24.0/float(clock.year_days),1.0)) < 0.002)
	check("a faster spin winds more",results[1] > results[0]*1.5,results)
	var kept := hours()
	var phase_kept: float = scene._celestial.phase
	await frames(120)
	check("the world keeps the new time",absf(hours()-kept) < 0.001 and absf(scene._celestial.phase-phase_kept) < 0.0005)
	check("the shimmer is gone at rest",scene._celestial.shimmer == 0.0,scene._celestial.shimmer)
	check("the hour is pinned again at rest",scene.mood_look.pins.has("time"),scene.mood_look.pins)
	check("the season pin (if any) follows: none was set, none made",not scene.mood_look.pins.has("season"))

	# --- Weather changes because time passed --------------------------------------
	var before_weather := ""
	if living != null and scene.weather_scheduler.enabled:
		before_weather = str(scene.weather_scheduler.current)
		var changed := false
		var tt: float = scene.weather_scheduler.now_hour()
		# Wind a fortnight through the spin's own path.
		for i in range(40):
			scene.spin_time._wind(clock,24.0*0.4)
			await frames(1)
			if str(scene.weather_scheduler.current) != before_weather: changed = true
		scene.spin_time.winding = true
		scene.spin_time._rest(clock)
		check("the weather changed because time passed",changed,"%s -> %s, scheduler %.1f h -> %.1f h" % [before_weather,scene.weather_scheduler.current,tt,scene.weather_scheduler.now_hour()])
	else:
		print("NOTE living weather is off here; the weather step was not exercised")

	# The diorama has turned under the pointer: find its rim again.
	rim_at = rim_point()
	# --- A vertical rim drag is the flip ------------------------------------------
	var flips := {"began":0,"dragged":[],"released":[]}
	reach.flip_began.connect(func(_p: Vector2) -> void: flips.began += 1)
	reach.flip_dragged.connect(func(p: float) -> void: flips.dragged.append(p))
	reach.flip_released.connect(func(p: float) -> void: flips.released.append(p))
	yaw0 = scene.yaw
	var hour0 := hours()
	end = await drag(rim_at,Vector2(0.6,-5.0),30,MOUSE_BUTTON_LEFT,false,3)
	check("a vertical rim drag is the flip",reach.rim_intent == "flip" and flips.began == 1,reach.rim_intent)
	check("flip progress grows toward 1",flips.dragged.size() > 5 and flips.dragged.back() > flips.dragged[0] and flips.dragged.back() > 0.3,flips.dragged.back() if not flips.dragged.is_empty() else -1)
	check("the flip does not turn the world",absf(angle_difference(yaw0,scene.yaw)) < 0.001,rad_to_deg(scene.yaw-yaw0))
	button(end,MOUSE_BUTTON_LEFT,false)
	await frames(30)
	check("the flip's release reports its progress",flips.released.size() == 1 and flips.released[0] > 0.3,flips.released)
	check("the flip leaves time alone",absf(hours()-hour0) < 0.001)
	check("no spin after a flip",not turn.spinning())

	# --- A shake takes the rim from either axis ------------------------------------
	for axis in [Vector2.RIGHT,Vector2.DOWN]:
		flips.released.clear()
		flips.began = 0
		hour0 = hours()
		var globe: Node = scene.snow_globe
		rim_at = rim_point()
		button(rim_at,MOUSE_BUTTON_LEFT,true)
		await frames(1)
		var pos := rim_at
		for i in range(110):
			var s: Vector2 = axis*(13.0 if int(i/7)%2 == 0 else -13.0)
			pos += s
			motion(pos,s)
			await frames(1)
			if globe.decided and i > 40: break
		check("a shake on the rim is decided (%s)" % axis,globe.decided and reach.rim_intent == "shake",reach.rim_intent)
		check("the turn let go when the shake took over (%s)" % axis,not turn.external)
		if axis == Vector2.DOWN: check("a vertical start that becomes a shake abandons the flip",flips.began == 0 or (flips.released.size() == 1 and flips.released[0] == 0.0),flips.released)
		await frames(20)
		check("a shake does not wind time (%s)" % axis,absf(hours()-hour0) < 0.001,hours()-hour0)
		check("the hand shakes (%s)" % axis,scene.god_hand == null or scene.god_hand.reach_gesture == "shake",scene.god_hand.reach_gesture if scene.god_hand != null else "")
		button(pos,MOUSE_BUTTON_LEFT,false)
		await frames(240)
		check("no spin left by a shake (%s)" % axis,not turn.spinning())

	# --- A left land press is free ----------------------------------------------------
	var lands := {"pressed":0,"dragged":0,"released":0}
	reach.land_pressed.connect(func(_p: Vector2) -> void: lands.pressed += 1)
	reach.land_dragged.connect(func(_p: Vector2, _r: Vector2) -> void: lands.dragged += 1)
	reach.land_released.connect(func(_p: Vector2) -> void: lands.released += 1)
	yaw0 = scene.yaw
	var undo0: int = data._undo.size()
	var heights0 := data.heights.duplicate()
	hour0 = hours()
	end = await drag(land_at,Vector2(5,-3),25,MOUSE_BUTTON_LEFT,false,3)
	check("a land press emits land_pressed and holds the land",lands.pressed == 1 and reach.holding == "land",lands)
	check("a land drag emits land_dragged",lands.dragged >= 20,lands)
	check("the land press does not turn the world",absf(angle_difference(yaw0,scene.yaw)) < 0.0005,rad_to_deg(scene.yaw-yaw0))
	check("the land press paints nothing",not editor._painting and data._undo.size() == undo0 and data.heights == heights0)
	button(end,MOUSE_BUTTON_LEFT,false)
	await frames(30)
	check("the land release emits land_released",lands.released == 1 and reach.holding == "",lands)
	check("no spin after a land drag",not turn.spinning())
	check("the land drag leaves time alone",absf(hours()-hour0) < 0.001)

	# --- A right drag is the camera -------------------------------------------------------
	yaw0 = scene.yaw
	var polar0: float = scene.polar
	room0 = turn.room_yaw
	hour0 = hours()
	end = await drag(land_at,Vector2(26,-6),22,MOUSE_BUTTON_RIGHT,true,0)
	await frames(200)
	check("a right drag tilts",absf(scene.polar-polar0) > 0.05,scene.polar-polar0)
	check("a right drag looks round",absf(angle_difference(yaw0,scene.yaw)) > 0.3,rad_to_deg(scene.yaw-yaw0))
	check("a fast right drag does not change time",absf(hours()-hour0) < 0.001,hours()-hour0)
	check("a right drag leaves the room where it was",absf(turn.room_yaw-room0) < 0.0005,rad_to_deg(turn.room_yaw-room0))
	check("a right drag does not spin the world",not turn.spinning())
	check("the shimmer stays off",scene._celestial.shimmer == 0.0)

	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
