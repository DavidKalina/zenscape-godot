extends SceneTree
## `--manual-landing` in the live scene (scripts/wanderer_eye.gd over
## scripts/manual_landing.gd), headless:
##   - stepping in with no plane parked parks one beside the pilot;
##   - a jump and a second press in the air is only a jump: no flight;
##   - walking off the island's edge drops into the canopy, the plane left
##     parked where it was, and stranded a while, the pilot is back on foot
##     beside it;
##   - Space by the plane boards it and takes off, flown by hand after;
##   - F in the air lowers the flaps, never lands it;
##   - a hot touch bounces back up; a slow one rolls, brakes to a stop, F
##     rolling is refused, F stopped gets out, the plane parked there;
##   - a flight set from outside (--skydive's start) takes the parked plane.
##   godot --headless --path . --script tests/test_manual_landing_game.gd
## suite: slow
const SkyPlane = preload("res://scripts/sky_plane.gd")
const SkyDive = preload("res://scripts/sky_dive.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")
var failures := 0
var scene: Node3D
var eye: Node

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func frames(n: int) -> void:
	for i in range(n): await process_frame

## Frames until `done` (a Callable() -> bool), `most` game seconds at most.
func until(done: Callable, most: float) -> bool:
	var began := Time.get_ticks_msec()
	while not bool(done.call()):
		if (Time.get_ticks_msec()-began)/1000.0*Engine.time_scale > most: return false
		await process_frame
	return true

func run() -> void:
	create_timer(600.0).timeout.connect(func() -> void: push_error("manual landing game test timed out"); quit(2))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/manual-landing-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not (scene.places_ready and scene.shell_ready): await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await frames(20)
	eye = scene.wanderer
	eye.manual = true
	Engine.time_scale = 3.0
	await _step_in()
	await _no_jump_flight()
	await _off_the_edge()
	await _board()
	await _flaps()
	await _bounce_and_land()
	Engine.time_scale = 1.0
	print("PASS: manual landing game" if failures == 0 else "FAIL: manual landing game (%d)" % failures)
	quit(1 if failures else 0)

func _step_in() -> void:
	if eye.has_parked(): eye._unpark(false)
	eye.place(eye._land_middle(eye.editor.data))
	eye.enter()
	await frames(5)
	check(eye.active and not eye.flying,"In the eyes, on foot")
	check(eye.has_parked(),"Stepping in with no plane parked parks one beside the pilot")
	check(eye._hint.text in [eye.MANUAL_WALK_HINT,eye.BOARD_HINT],"The walk's hint names the plane, not a jump to fly")

func _no_jump_flight() -> void:
	# Away from the plane first, so Space is not a boarding.
	var parked_at: Vector2 = eye._parked_at
	var away: Vector3 = eye._clamped(eye._free_spot(eye._clamped(Vector3(parked_at.x-6.0,0.0,parked_at.y))))
	eye._feet = away
	eye.motor.reset(away,0.0)
	await frames(3)
	check(not eye.by_plane(),"Away from the plane")
	Input.action_press(&"walk_jump")
	await frames(2)
	Input.action_release(&"walk_jump")
	await frames(8)
	Input.action_press(&"walk_jump")
	await frames(30)
	Input.action_release(&"walk_jump")
	await frames(30)
	check(not eye.flying and eye.has_parked(),"A jump, and again in the air, is only a jump: no flight")

func _off_the_edge() -> void:
	var parked_at: Vector2 = eye._parked_at
	# The shore: from the land's middle on along +x until off the land.
	var middle: Vector3 = eye._land_middle(eye.editor.data)
	var p: Vector2 = Vector2(middle.x,middle.z)
	while eye._on_land(p+Vector2(0.5,0.0)) and p.x < eye.PLATE_REACH: p.x += 0.5
	var start: Vector3 = eye._clamped(Vector3(p.x-6.0,0.0,p.y))
	eye._feet = start
	eye.motor.reset(start,-PI*0.5)
	eye._yaw = -PI*0.5+eye._turn()
	Input.action_press(&"move_forward")
	print("     shore at %s, start %s, on land %s" % [str(p),str(start),eye._on_land(Vector2(start.x,start.z))])
	var off: bool = await until(func() -> bool: return eye.diving,8.0)
	print("     stepped off: motor feet %s on land %s, dive at %s, under %s" % [str(eye.motor.feet),eye._on_land(Vector2(eye.motor.feet.x,eye.motor.feet.z)),str(eye.dive.position) if eye.dive != null else "-",str(eye._dive_ground(eye.dive.position)) if eye.dive != null else "-"])
	Input.action_release(&"move_forward")
	check(off and eye.diving and eye._stepped_off,"Walked off the edge: the drop and the canopy")
	check(eye.glide is SkyDive and eye.drone == null,"No plane flying: not a flight, nothing summoned")
	check(eye.has_parked() and eye._parked_at.distance_to(parked_at) < 0.01,"The plane stays parked where it was")
	var opened: bool = await until(func() -> bool: return eye.dive.under_canopy(),4.0)
	check(opened,"The canopy opens by itself")
	if not opened:
		print("     dive %s at %s touched %s, diving %s, feet %s, off_y %.1f" % [SkyDive.NAMES[eye.dive.phase],str(eye.dive.position),str(eye.dive.touched),eye.diving,str(eye._feet),eye._off_y])
	var stranded: bool = await until(func() -> bool: return eye._stranded_left >= 0.0 or not eye.diving,20.0)
	if stranded and eye._stranded_left >= 0.0:
		check(true,"Well under the edge: stranded")
		var back: bool = await until(func() -> bool: return not eye.diving,eye.STRANDED_WAIT+3.0)
		await frames(5)
		check(back and not eye.flying and eye.active,"Then back on foot")
		check(eye.by_plane(),"Beside the parked plane")
	else:
		# The canopy came down on a lower part of the same island: home, on
		# foot, to walk back to the plane.
		await frames(5)
		check(not eye.flying and eye.active and eye._on_land(Vector2(eye._feet.x,eye._feet.z)) and eye.has_parked(),"Down on the plane's own island, on foot (not stranded)")
		var h: float = eye._parked_heading
		var beside: Vector3 = eye._clamped(Vector3(eye._parked_at.x-cos(h)*1.4,0.0,eye._parked_at.y+sin(h)*1.4))
		eye._feet = beside
		eye.motor.reset(beside,0.0)
		await frames(3)
		check(eye.by_plane(),"Walked back beside the parked plane")
	print("     the plane parked at %s" % str(eye._parked_at))

func _board() -> void:
	Input.action_press(&"walk_jump")
	await frames(3)
	Input.action_release(&"walk_jump")
	check(eye.flying and eye.landing != null and eye._taking_off and not eye.has_parked(),"Space by the plane: in, and the takeoff")
	var up: bool = await until(func() -> bool: return eye.landing == null,15.0)
	check(up and eye.flying and eye.glide is SkyPlane,"Flying after the takeoff")
	check(eye.hand_landing.plane == eye.glide and eye.hand_landing.flying(),"Flown by hand from there")
	check(eye._hint.text.begins_with(eye.MANUAL_HINT.left(20)),"The plane's hint has no F to land")

func _flaps() -> void:
	eye._land_key()
	check(eye._flaps and eye.landing == null and not eye._landing_wait,"F in the air lowers the flaps; nothing lands it")
	eye._land_key()
	check(not eye._flaps,"F again raises them")

## The stick a little forward a moment (W): the nose down against the air.
func _nose_down() -> void:
	Input.action_press(&"move_forward",0.25)
	await frames(6)
	Input.action_release(&"move_forward")

## Over the island's best clear strip, `up` m over its ground, at `pace`,
## nose `nose`.
func _fly_low(up: float, pace: float, nose: float) -> void:
	# The island's best clear strip (PlaneStrip, as the old F landing picks
	# it): no trees to ride over, room to roll.
	var strip: Dictionary = eye._strip_global(PlaneStrip.pick(eye._strip_map()))
	var dir: Vector3 = strip.dir
	var at: Vector3 = strip.touch
	var heading := atan2(-dir.x,-dir.z)
	# The highest ground under the next few metres, so it touches at once.
	var floor_y := -INF
	for k in range(5):
		var p: Vector3 = at+dir*k
		var h: float = eye._floor_global(Vector2(p.x,p.z))
		if not is_nan(h): floor_y = maxf(floor_y,h)
	if floor_y > -INF: at.y = floor_y
	eye._launch(pace,false,at+Vector3.UP*(SkyPlane.SKIM+up),heading)
	eye.glide.speed = pace
	eye.glide.pitch = nose
	eye.glide.velocity = eye.glide.forward()*pace
	eye._hand_begin()
	await frames(1)

func _bounce_and_land() -> void:
	# The island's air (ridge lift, gust fronts) can hold a low plane up,
	# so each approach is tried a few times, the nose pushed down a moment.
	var bounced := false
	for attempt in range(4):
		await _fly_low(0.3,14.0,-0.15)
		await _nose_down()
		bounced = await until(func() -> bool: return int(eye.hand_landing.stats.bounces) > 0,3.0)
		if bounced: break
	check(bounced and eye.hand_landing.flying() and eye.flying,"A touch at cruise bounces back up, still flying")
	check(bounced and str(eye.hand_landing.stats.touches[0].result) == "fast","Too fast")
	var down := false
	for attempt in range(4):
		await _fly_low(0.08,8.0,-0.08)
		Input.action_press(&"fly_brake")
		await _nose_down()
		down = await until(func() -> bool: return eye.hand_landing.on_ground() or not eye.flying,3.0)
		if down and eye.hand_landing.on_ground(): break
	check(down and eye.hand_landing.on_ground(),"A slow touch settles on the wheels (%s)" % str(eye.hand_landing.last_touch))
	if eye.hand_landing.phase == ManualLanding.ROLL:
		eye._land_key()
		await frames(2)
		check(eye.hand_landing.on_ground() and eye.hand_landing.phase != ManualLanding.EXIT and int(eye.hand_landing.stats.early_exits) > 0,"F while rolling is refused: stop first")
	var stopped: bool = await until(func() -> bool: return eye.hand_landing.phase == ManualLanding.STOPPED,8.0)
	Input.action_release(&"fly_brake")
	check(stopped and eye.flying,"It brakes to a stop, the pilot still in")
	if not stopped:
		print("     phase %s, stats %s, at %s" % [ManualLanding.NAMES[eye.hand_landing.phase],str(eye.hand_landing.stats),str(eye.glide.position)])
	await frames(60)
	check(eye.hand_landing.phase == ManualLanding.STOPPED and eye.flying,"Stopped, it waits: not out by itself")
	eye._land_key()
	var out: bool = await until(func() -> bool: return not eye.flying,4.0)
	await frames(3)
	check(out and eye.active and eye.has_parked() and eye.by_plane(),"F stopped: out, beside the plane parked where it stopped")
	# A flight set from outside (--skydive, a set piece's hop) takes the
	# parked plane: only ever the one.
	eye._launch(SkyPlane.CRUISE_SPEED,false,eye._eye_global()+Vector3.UP*60.0,0.0)
	await frames(2)
	check(eye.flying and not eye.has_parked() and eye.hand_landing.flying(),"A flight set from outside takes the parked plane: only the one")
