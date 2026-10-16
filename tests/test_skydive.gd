extends SceneTree
## The skydive in the live scene, through the wanderer (scripts/
## wanderer_eye.gd, scripts/sky_dive.gd), headless:
##   - X in the plane ejects: the pilot pops out falling, drawn, and the
##     plane flies on by itself, without its pilot;
##   - Space opens the pocket sail (scripts/pocket_sail.gd; nothing opens
##     by itself), and the soft touch on the home island hands over to
##     walking, the sail folding away;
##   - the plane then comes in, lands near and parks; Space by it boards it;
##   - the sail opened again from a fall and steered;
##   - a landing in deep water swims;
##   - a fall past everything, into the cloud sea, is caught by the plane,
##     and so is a touch on open water;
##   - V mid-dive steps out cleanly.
##   godot --headless --path . --script tests/test_skydive.gd
## suite: slow
## suite: serial
const SkyPlane = preload("res://scripts/sky_plane.gd")
const SkyDive = preload("res://scripts/sky_dive.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
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

func _key(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func run() -> void:
	create_timer(600.0).timeout.connect(func() -> void: push_error("skydive test timed out"); quit(2))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = OS.get_temp_dir().path_join("skydive-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not (scene.places_ready and scene.shell_ready): await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await frames(20)
	eye = scene.wanderer
	check(eye.skydive_start(PackedStringArray(["--skydive"])) == "plane" and eye.skydive_start(PackedStringArray(["--skydive=fall"])) == "fall" and eye.skydive_start(PackedStringArray()) == "","--skydive starts in the plane, --skydive=fall falling")
	check("X to eject" in eye.PLANE_HINT and "{X} eject" in eye.PAD_HINTS[eye.PLANE_HINT],"The plane's hints name the eject, on the keys and the pad")
	Engine.time_scale = 3.0
	await _eject_and_land()
	await _plane_comes_back()
	await _open_by_hand()
	await _lake()
	await _past_everything()
	await _open_water()
	await _step_out()
	Engine.time_scale = 1.0
	print("PASS: skydive" if failures == 0 else "FAIL: skydive (%d)" % failures)
	quit(1 if failures else 0)

## In the plane over the home island's middle, `up` m over its ground,
## flying `heading`.
func _fly_over(up: float, heading := 0.0, back := 0.0) -> void:
	if not eye.active:
		eye.place(Vector3.ZERO)
		eye.enter()
		await frames(3)
	var middle: Vector3 = eye.editor.terrain.global_position+eye._land_middle(eye.editor.data)
	var floor_y: float = eye._floor_global(Vector2(middle.x,middle.z))
	if not is_nan(floor_y): middle.y = floor_y
	var forward := Vector3(-sin(heading),0.0,-cos(heading))
	eye._launch(SkyPlane.CRUISE_SPEED,false,middle+Vector3.UP*up-forward*back,heading)
	await frames(3)

## Waits while the dive is under way, `most` seconds (game time) at most;
## the phases seen.
func _until_down(most: float) -> Array:
	var seen := []
	var began := Time.get_ticks_msec()
	while eye.diving and (Time.get_ticks_msec()-began)/1000.0*Engine.time_scale < most:
		var name: String = SkyDive.NAMES[eye.dive.phase]
		if seen.is_empty() or seen[-1] != name: seen.append(name)
		await process_frame
	return seen

func _eject_and_land() -> void:
	await _fly_over(55.0,0.0,6.0)
	check(eye.flying and eye.glide is SkyPlane,"Flying the plane over home")
	eye.handle(_key(KEY_X))
	check(eye.diving and eye.glide is SkyDive and eye.dive.phase == SkyDive.POP,"X ejects: out of the cockpit")
	check(eye.drone is SkyPlane and eye.glider.visible and not eye.glider._pilot[0].visible,"The plane flies on by itself, its pilot gone from it")
	check(eye.figure.visible and eye._hint.text == eye.DIVE_HINT,"The pilot is drawn falling, the dive's hint up")
	# The pop, watched frame by frame (a headless frame of the live game is
	# long, at 3x a tenth of a second or more of the dive): a kick up first.
	var kicked := -INF
	for i in range(10):
		await process_frame
		if eye.dive.phase == SkyDive.POP: kicked = maxf(kicked,eye.dive.velocity.y)
	check(kicked > 0.0,"A pop up out of it first (%.1f m/s up)" % kicked)
	# Falling, nothing opens by itself; Space 20 m over the land opens the
	# sail, and it circles down (left held).
	var began := Time.get_ticks_msec()
	var opened_alone := false
	while eye.diving and not (eye.dive.under == "ground" and eye.dive.height < 20.0) and (Time.get_ticks_msec()-began)/1000.0*Engine.time_scale < 30.0:
		opened_alone = opened_alone or eye.dive.sailing()
		await process_frame
	check(not opened_alone and eye.dive.falling(),"Falling, nothing opens by itself (%.1f m over the land)" % eye.dive.height)
	eye.handle(_key(KEY_SPACE))
	await frames(2)
	check(eye.dive.sailing() and eye.dive.sail.kicked and eye._hint.text == eye.SAIL_HINT,"Space: the sail, kicked, its hint up")
	Input.action_press(&"move_left")
	var seen: Array = await _until_down(60.0)
	Input.action_release(&"move_left")
	print("     phases: %s" % " > ".join(seen))
	check(seen.has("sail"),"Sails down")
	check(eye.active and not eye.flying and not eye.diving and eye.perch.is_empty(),"Down on the home island, walking")
	check(eye.figure.visible and eye.motor.grounded and eye.editor.data.has_land(Vector2(eye._feet.x,eye._feet.z)),"Stood on its land")
	check(not (eye.dive.touched as Dictionary).get("hard",true),"A soft touch under the sail")
	await frames(20)
	check(not eye.sail_wing.visible,"The sail folds away")
	check(eye.glide is SkyPlane,"The plane's flight is the eye's again")
	# Walks on.
	var was: Vector3 = eye._feet
	Input.action_press(&"move_forward")
	await frames(30)
	Input.action_release(&"move_forward")
	check(eye._feet.distance_to(was) > 0.3,"And walks on (%.1f m)" % eye._feet.distance_to(was))

func _plane_comes_back() -> void:
	var began := Time.get_ticks_msec()
	var came_in := false
	while not eye.has_parked() and (Time.get_ticks_msec()-began)/1000.0*Engine.time_scale < 60.0:
		if eye._drone_landing != null: came_in = true
		await process_frame
	if not came_in: print("     the plane: drone %s, landing %s, flying %s, glider shown %s" % [eye.drone,eye._drone_landing,eye.flying,eye.glider.visible])
	check(came_in,"The plane comes in to land near the pilot")
	check(eye.has_parked() and eye.drone == null,"And parks")
	if not eye.has_parked(): return
	var gap := Vector2(eye._feet.x,eye._feet.z).distance_to(eye._parked_at)
	check(gap < 45.0,"Near them (%.1f m off)" % gap)
	check(eye.editor.data.has_land(eye._parked_at),"On the island's land")
	# Walked up to it, Space boards it.
	eye._feet = eye._clamped(Vector3(eye._parked_at.x+1.2,0.0,eye._parked_at.y))
	eye.motor.reset(eye._feet,eye.motor.facing)
	await frames(2)
	check(eye.by_plane(),"Beside it, it can be boarded")
	eye._board()
	var waited := 0
	while eye.landing != null and waited < 1200:
		await process_frame
		waited += 1
	check(eye.flying and eye.landing == null and not eye.has_parked() and eye.glide is SkyPlane,"Space by it: back in the air in it")

func _open_by_hand() -> void:
	await _fly_over(80.0,PI*0.5,0.0)
	eye.eject()
	await frames(40)
	check(eye.dive.phase == SkyDive.FREEFALL,"Falling")
	eye.handle(_key(KEY_X))
	await frames(2)
	check(eye.dive.falling(),"X no longer opens anything")
	eye.handle(_key(KEY_SPACE))
	await frames(2)
	check(eye.dive.sailing() and eye._hint.text == eye.SAIL_HINT,"Space opens the sail")
	await frames(60)
	var heading: float = eye.dive.heading
	Input.action_press(&"move_left")
	await frames(12)
	Input.action_release(&"move_left")
	check(absf(angle_difference(heading,eye.dive.heading)) > 0.5,"The stick steers it (%.2f rad)" % angle_difference(heading,eye.dive.heading))
	check(eye.sail_wing.visible,"The sail is drawn over the pilot")
	eye.handle(_key(KEY_SPACE))
	await frames(2)
	check(eye.dive.falling() and eye._hint.text == eye.DIVE_HINT,"Space again folds it")
	await frames(30)
	eye.handle(_key(KEY_SPACE))
	await frames(2)
	check(eye.dive.sailing(),"And opens it again")
	# Folded for the way down: a quicker test.
	await frames(10)
	eye.handle(_key(KEY_SPACE))
	await _until_down(60.0)
	check(not eye.diving,"And comes down (%s)" % ("walking" if eye.active and not eye.flying else "picked up"))

## Water to land in. The default home island has no pond deep enough to
## swim and the islets near it no lake, so the walker's water (the motor's
## `water`, which every landing reads, as the walk does) is given a pond
## 1.2 m deep round a point on the land for this part, and taken back after.
func _lake() -> void:
	if not eye.active: await _fly_over(40.0)
	var middle: Vector3 = eye._land_middle(eye.editor.data)
	var pond := Vector2(middle.x,middle.z)
	var real: Callable = eye.motor.water
	eye.motor.water = func(p: Vector2) -> float: return 1.2 if p.distance_to(pond) < 6.0 else 0.0
	await _fly_over(30.0)
	eye.eject()
	var top: Vector3 = eye.editor.terrain.to_global(Vector3(pond.x,eye._ground(Vector3(pond.x,0.0,pond.y)),pond.y))
	eye.dive.drop(top+Vector3.UP*(SkyDive.HIPS+1.0),0.0,0.0)
	eye.dive.phase = SkyDive.SAIL
	eye.dive.sail.open = true
	eye.dive.open = 1.0
	eye.dive.tilt = 0.0
	eye.dive.velocity = Vector3.DOWN*1.5
	await _until_down(10.0)
	var swum := false
	for i in range(60):
		await process_frame
		if eye.motor.swimming: swum = true
	check(eye.active and not eye.flying and Vector2(eye._feet.x,eye._feet.z).distance_to(pond) < 6.0,"Down in the pond")
	check(swum,"In it: swimming")
	eye.motor.water = real
	await frames(5)

## A point `up` m high over open sky, nothing under it from there to the
## cloud sea (nor, under --below, down to the lower world's ocean).
func _open_sky(up: float) -> Vector3:
	for ring in range(4,40):
		for k in range(16):
			var a := TAU*k/16.0
			var p := Vector3(cos(a),0.0,sin(a))*ring*60.0
			var clear := true
			for y in range(int(up),-300,-10):
				var q := Vector3(p.x,y,p.z)
				if eye.islands.body(q) != null or eye.islands.islets.islet_at(q).size() > 0: clear = false
				if eye.lower != null and eye.lower.body(q) != null: clear = false
				if not clear: break
			if clear: return Vector3(p.x,up,p.z)
	return Vector3(2400.0,up,2400.0)

func _past_everything() -> void:
	if eye.perch.is_empty() and not eye.flying: await _fly_over(40.0)
	# Far out from every island, over the open cloud sea.
	var far := _open_sky(30.0)
	eye._launch(SkyPlane.CRUISE_SPEED,false,far,0.0)
	await frames(3)
	eye.eject()
	var seen: Array = await _until_down(90.0)
	print("     phases: %s; below: %s, diving: %s, perched: %s, at %s, water %s, under %s, ground %s" % [" > ".join(seen),eye.below(),eye.diving,not eye.perch.is_empty(),eye.glide.position,eye.glide.water,eye.glide.get("under"),eye._dive_ground(eye.glide.position)])
	if eye.lower != null:
		# Under the cloud sea (--below) the fall carries on into the lower
		# world: down on one of its islands, or the plane picks the pilot
		# up off its ocean.
		check(not eye.diving and eye.flying and eye.glide is SkyPlane and eye.below(),"Fallen through the cloud sea into the lower world, and down there (%s)" % ("on an island" if not eye.perch.is_empty() else "picked up off the ocean"))
		if not eye.perch.is_empty():
			eye._launch(SkyPlane.CRUISE_SPEED,false,eye.glide.position+Vector3.UP*20.0,0.0)
			await frames(3)
		return
	check(not eye.diving and eye.flying and eye.glide is SkyPlane and eye.perch.is_empty(),"Fallen past everything into the cloud sea, the plane catches the pilot and flies on")
	check(eye._hint.text == eye.PICKUP_HINT and eye.glider.visible and eye.glider._pilot[0].visible,"Back in the cockpit")
	await frames(30)
	check(eye.glide.position.y > -60.0 or eye.glide.velocity.y > -2.0,"Climbing out, not falling")

func _open_water() -> void:
	eye._launch(SkyPlane.CRUISE_SPEED,false,_open_sky(0.0),0.0)
	await frames(3)
	eye.eject()
	eye.dive.water = eye.dive.position.y-25.0
	await _until_down(60.0)
	check(not eye.diving and eye.flying and eye.glide is SkyPlane,"Down on open water, the plane picks the pilot up")

func _step_out() -> void:
	eye.eject()
	await frames(20)
	check(eye.diving,"Diving again")
	eye.handle(_key(KEY_V))
	await frames(3)
	check(not eye.active and not eye.diving and not eye.flying and eye.glide is SkyPlane and not eye.sail_wing.visible,"V mid-dive steps out cleanly")
