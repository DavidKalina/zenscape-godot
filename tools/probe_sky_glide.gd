extends SceneTree
## Headless probe of the glide (scripts/sky_glide.gd) in the cozy worlds
## scene, through the wanderer (scripts/wanderer_eye.gd):
##   - walked off the plate's edge, the figure glides and the plate is copied
##     out into the sky (scripts/sky_islands.gd);
##   - the view widens and leans into a turn;
##   - flying over a copy swaps it for the plate, the eye shifted with it;
##   - wandered far off, an island rises ahead with a thermal; fallen into
##     the parted sea, one surfaces just ahead; past the cap the farthest go;
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
	# A cloud near the field's middle, so following the eye doesn't re-wrap it.
	var clouds: Node3D = eye.islands.clouds
	var middle: Vector3 = Vector3(clouds.field.x+clouds.field.z*0.5,0.0,clouds.field.y+clouds.field.w*0.5)+clouds.shift
	var cloud := 0
	for i in range(clouds.clouds.size()):
		var c: Vector3 = clouds.centre(i,scene._motion_time)
		var best: Vector3 = clouds.centre(cloud,scene._motion_time)
		if Vector2(c.x-middle.x,c.z-middle.z).length() < Vector2(best.x-middle.x,best.z-middle.z).length(): cloud = i
	eye.glide.position = clouds.centre(cloud,scene._motion_time)
	await frames(30)
	check("flown into a cloud, the view goes to vapour",eye.sky.vapour > 0.3,"%.2f" % eye.sky.vapour)
	check("the clouds show while gliding",eye.islands.clouds.visible)

	# Wandered off: an island rises ahead, with a thermal.
	var isl: Node3D = eye.islands
	var thermals := func() -> int: return isl.currents.currents.filter(func(c: Dictionary) -> bool: return c.kind == "thermal").size()
	var had: int = isl.copy_count()
	var had_thermals: int = thermals.call()
	eye.glide.position = Vector3(2600.0,10.0,-2300.0)
	eye.glide.heading = 0.7
	eye.glide.pitch = 0.0
	await frames(2)
	isl.cells.wandered = isl.cells.WANDER_TIME
	await frames(2)
	var new_at: Vector3 = isl.offsets[isl.offsets.size()-1]
	var out := Vector2(new_at.x-eye.glide.position.x,new_at.z-eye.glide.position.z).length()
	check("wandered off, an island turns up ahead",isl.copy_count() == had+1 and out > isl.cells.NEAR-20.0 and out < isl.cells.FAR+20.0,"%d copies, %.0f m out" % [isl.copy_count(),out])
	check("it rises out of the haze",isl.sunk(isl.offsets.size()-1) > 30.0,"%.0f m below" % isl.sunk(isl.offsets.size()-1))
	check("it brings a thermal",thermals.call() == had_thermals+1,"%d thermals" % thermals.call())
	await frames(int(isl.WANDER_RISE.y*60.0)+10)
	check("then it stands at its spot",isl.sunk(isl.offsets.size()-1) == 0.0 and isl._copies[isl.offsets.size()-1].position.is_equal_approx(new_at))
	# Fallen into the parted sea: one surfaces just ahead.
	had = isl.copy_count()
	eye.glide.position = Vector3(-2400.0,-95.0,2600.0)
	eye.glide.airborne = 10.0
	for i in range(60):
		await frames(1)
		if isl.copy_count() > had: break
	var fall_at: Vector3 = isl.offsets[isl.offsets.size()-1]
	var gap := Vector2(fall_at.x-eye.glide.position.x,fall_at.z-eye.glide.position.z).length()
	check("fallen into the sea, an island surfaces just ahead",isl.copy_count() == had+1 and gap < isl.cells.AHEAD+isl.cells.RANGE,"%.0f m off, parted %.2f" % [gap,eye.sky.flight.w])
	await frames(30)
	check("with one in reach, no more turn up",isl.copy_count() == had+1,"%d copies" % isl.copy_count())
	# Past the cap the farthest go, never the newest.
	var home: Vector3 = eye.glide.position-isl.cells.origin
	var taken := []
	for h: Vector3 in isl.homes: taken.append(h)
	for s: Vector3 in isl.cells.spots_near(home,2000.0):
		if isl.copy_count() >= isl.CAP+3: break
		var free := true
		for t: Vector3 in taken: if Vector2(t.x-s.x,t.z-s.z).length() < 1.0: free = false
		if free: isl.realise(s,"wander")
	var newest: Vector3 = isl._newest
	await frames(2)
	check("past the cap the farthest copies go",isl.copy_count() <= isl.CAP,"%d copies" % isl.copy_count())
	check("never the newest",isl.homes.any(func(h: Vector3) -> bool: return h.distance_to(newest) < 1.0))

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
