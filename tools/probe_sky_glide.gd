extends SceneTree
## Headless probe of the glide (scripts/sky_glide.gd) in the cozy worlds
## scene, through the wanderer (scripts/wanderer_eye.gd):
##   - walked off the plate's edge, the figure glides and the plate is copied
##     out into the sky (scripts/sky_islands.gd);
##   - the view widens and leans into a turn;
##   - flying over a copy swaps it for the plate, the eye shifted with it;
##   - a slow skim on the plate lands, back to walking;
##   - V mid-glide steps out onto the plate.
## Visuals (the copies' look, the streaks) need a rendered run.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_sky_glide.gd -- --no-title
var scene: Node3D
var editor: NativeChunkEditor
var eye: Node
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func frames(count: int) -> void:
	for i in range(count): await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	create_timer(260).timeout.connect(func() -> void: push_error("sky glide probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-glide-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	eye = scene.wanderer
	scene.world_clock.running = false
	await frames(30)

	# Off the edge.
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	eye._yaw = atan2(-1.0,0.0)+eye._turn()
	eye._polar = PI*0.5
	key(KEY_W,true)
	for i in range(120):
		await frames(1)
		if eye.flying: break
	key(KEY_W,false)
	check("walked off the edge, it glides",eye.flying)
	if not eye.flying:
		finish()
		return
	check("the plate is copied out into the sky",eye.islands.copy_count() == eye.islands.OFFSETS.size() and eye.islands._copies[0].get_child_count() > 3,
		"%d copies of %d parts" % [eye.islands.copy_count(),eye.islands._copies[0].get_child_count()])
	var start_y: float = eye.glide.position.y
	await frames(40)
	check("it drops away off the edge",eye.glide.position.y < start_y-1.0,"%.1f to %.1f m" % [start_y,eye.glide.position.y])
	check("the view widens",scene.camera.fov > eye.FOV+2.0,"%.1f deg" % scene.camera.fov)
	key(KEY_D,true)
	await frames(45)
	key(KEY_D,false)
	check("a turn leans the view",scene.camera_roll < -0.2,"%.2f rad" % scene.camera_roll)
	check("the camera follows the glide",scene.camera.global_position.distance_to(eye.glide.position) < 0.5,scene.camera.global_position.distance_to(eye.glide.position))

	# Over a copy: the swap.
	var offset: Vector3 = eye.islands.offsets[0]
	eye.glide.position = offset+Vector3(2.0,25.0,1.0)
	await frames(2)
	var flat := Vector2(eye.glide.position.x,eye.glide.position.z)
	check("over a copy, the copy becomes the plate",flat.length() < 4.0,flat)
	check("the island left behind takes the copy's place",eye.islands.offsets[0].is_equal_approx(-offset),eye.islands.offsets[0])

	# The sky answers: the sea slides by and swells, parts under a fall,
	# and a cloud's heart is a white-out.
	var flight: Vector4 = eye.sky.flight
	check("the cloud sea follows the glide",flight.z != 1.0 or Vector2(flight.x,flight.y).length() > 0.0,flight)
	eye.glide.position = Vector3(300.0,-95.0,300.0)
	eye.glide.airborne = 10.0
	await frames(30)
	check("falling to the cloud sea parts it",eye.sky.flight.w > 0.5,"%.2f" % eye.sky.flight.w)
	eye.glide.position = eye.islands.clouds.centre(0,scene._motion_time)
	await frames(30)
	check("flown into a cloud, the view goes to vapour",eye.sky.vapour > 0.3,"%.2f" % eye.sky.vapour)
	check("the clouds show while gliding",eye.islands.clouds.visible)

	# A slow skim lands.
	var ground: float = eye.islands.ground(Vector3(3.0,0.0,3.0))
	eye.glide.position = Vector3(3.0,ground+1.0,3.0)
	eye.glide.speed = 5.5
	eye.glide.pitch = -0.3
	for i in range(240):
		await frames(1)
		if not eye.flying: break
	check("a slow skim on the plate lands",not eye.flying and eye.active,"flying %s" % eye.flying)
	check("landed, the feet are on the plate",absf(eye._feet.x) <= eye.PLATE_REACH and absf(eye._feet.z) <= eye.PLATE_REACH,eye._feet)
	check("landed, the lean is gone",scene.camera_roll == 0.0)
	await frames(120)
	check("landed, the cloud sea settles back to rest",eye.sky.flight.is_equal_approx(Vector4(0.0,0.0,1.0,0.0)) and eye.sky.vapour < 0.01,eye.sky.flight)
	check("landed, the clouds hide",not eye.islands.clouds.visible)

	# Off again, and V mid-glide.
	eye._feet = eye._clamped(Vector3(0.0,0.0,-(eye.PLATE_REACH-0.4)))
	eye._yaw = 0.0+eye._turn()
	key(KEY_W,true)
	for i in range(120):
		await frames(1)
		if eye.flying: break
	key(KEY_W,false)
	await frames(60)
	check("off another edge, it glides again",eye.flying)
	key(KEY_V,true)
	key(KEY_V,false)
	await frames(60)
	check("V mid-glide steps out",not eye.active and not eye.flying)
	check("stepped out, the figure stands on the plate",absf(eye._feet.x) <= eye.PLATE_REACH and absf(eye._feet.z) <= eye.PLATE_REACH,eye._feet)
	finish()

func finish() -> void:
	print("sky glide probe: %s" % ("PASS" if failures.is_empty() else "FAIL %s" % str(failures)))
	quit(0 if failures.is_empty() else 1)
