extends SceneTree
## The plane in the live scene, through the wanderer (scripts/wanderer_eye.gd),
## headless:
##   - the plane is how it flies (the old glider is gone), and the walking
##     and flying hints name its controls;
##   - off the edge and F: the landing runs through its phases and ends
##     walking beside the plane, parked on its wheels and skid, not a record
##     on the land and in the walker's way; F to walking in a few seconds;
##   - Space by it takes off: off the ground and flying, the parked one gone;
##   - F again mid line-up flies on;
##   - F by another island claims it and lands on it;
##   - flying off the edge brings the parked plane along.
##   godot --headless --path . --script tests/test_plane_flight.gd
const WandererEye = preload("res://scripts/wanderer_eye.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneLanding = preload("res://scripts/plane_landing.gd")
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

func run() -> void:
	create_timer(420.0).timeout.connect(func() -> void: push_error("plane flight test timed out"); quit(2))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/plane-flight-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not (scene.places_ready and scene.shell_ready): await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await frames(20)
	eye = scene.wanderer
	# These checks fly the old F landing (--auto-landing); the default hand
	# landing has its own tests (tests/test_manual_landing*.gd).
	eye.manual = false
	await _plane()
	print("PASS: plane flight" if failures == 0 else "FAIL: plane flight (%d)" % failures)
	quit(1 if failures else 0)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func _off_the_edge() -> void:
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	eye._yaw = atan2(-1.0,0.0)+eye._turn()
	eye.motor.facing = eye._yaw-eye._turn()
	eye._polar = PI*0.5
	eye._launch(1.0)
	await frames(2)

## Waits for the eye to come down walking, `most` seconds at most; the
## phases it went through and the seconds it took.
func _until_walking(most: float) -> Array:
	var phases := []
	var began := Time.get_ticks_msec()
	var seconds := 0.0
	while eye.flying and (Time.get_ticks_msec()-began)/1000.0 < most:
		await process_frame
		if eye.landing != null:
			seconds = eye.landing.elapsed
			var name: String = PlaneLanding.NAMES[eye.landing.phase]
			if phases.is_empty() or phases[-1] != name: phases.append(name)
	return [phases,seconds]

func _plane() -> void:
	check(eye.glide is SkyPlane and eye.glider is PlaneFigure,"It flies the plane")
	check("again in the air to fly" in eye._walk_hint() and not "glide" in eye._walk_hint() and not "flap" in eye.PLANE_HINT and "F to land" in eye.PLANE_HINT,"And the hints name the plane's controls")
	var objects: int = eye.editor.data.objects.size()
	await _off_the_edge()
	check(eye.flying,"Off the edge, it flies")
	await create_timer(1.5).timeout
	eye.handle(_key(KEY_F))
	check(eye._landing_wait or eye.landing != null,"F: it comes in to land")
	var out: Array = await _until_walking(40.0)
	var phases: Array = out[0]
	print("     F to the hop out: %.1f s of the sequence (%s), then the %.1f s swoop" % [out[1]," > ".join(phases),eye.SWOOP])
	check(phases == ["line-up","descent","flare","touchdown","rollout","beat","hop-out"],"Through every phase in order")
	check(eye.active and not eye.flying,"And walking at the end")
	await _parked_well(objects)
	# Takeoff from it.
	check(eye.by_plane() and eye._walk_hint() == eye.BOARD_HINT,"Beside it, the hint offers the takeoff")
	eye._board()
	var seen := []
	var began := Time.get_ticks_msec()
	while (eye.landing != null or seen.is_empty()) and Time.get_ticks_msec()-began < 20000:
		await process_frame
		if eye.landing != null:
			var name: String = PlaneLanding.NAMES[eye.landing.phase]
			if seen.is_empty() or seen[-1] != name: seen.append(name)
	check(seen.slice(0,4) == ["board","taxi","roll","lift"] or seen.slice(0,3) == ["board","roll","lift"] or seen.slice(0,3) == ["board","taxi","roll"],"Space by it: %s" % " > ".join(seen))
	check(eye.flying and eye.landing == null and not eye.has_parked(),"Off and flying, the parked plane gone with it")
	var under: Variant = eye._fly_ground(eye.glide.position)
	check(under == null or eye.glide.position.y > (under as Vector2).x+1.0,"Clear of the ground (%.1f m over it)" % (eye.glide.position.y-(under as Vector2).x if under != null else INF))
	# Called off.
	await create_timer(1.0).timeout
	eye.handle(_key(KEY_F))
	var waited := 0
	while eye.landing == null and waited < 300:
		await process_frame
		waited += 1
	await create_timer(0.4).timeout
	var was: bool = eye.landing != null and eye.landing.can_cancel()
	eye.handle(_key(KEY_F))
	check(was and eye.landing == null and not eye._landing_wait and eye.flying,"F again in the line-up: it flies on")
	await create_timer(1.0).timeout
	check(eye.flying and eye.glide.speed >= SkyPlane.SLOW,"Still flying under power")
	# Another island: claimed, then landed on.
	await _other_island(objects)
	# Off the edge again: the parked plane comes along.
	check(eye.has_parked(),"Parked on the island it landed on")
	eye._launch(1.0)
	await frames(2)
	check(eye.flying and not eye.has_parked(),"Flying off the edge brings the parked plane along")
	eye.leave()
	await frames(5)

## The plane parked beside the walker: on its wheels and skid on the
## ground, not a record on the land, nothing to collide with, and in the
## walker's way.
func _parked_well(objects: int) -> void:
	check(eye.has_parked(),"The plane is parked")
	if not eye.has_parked(): return
	var parked: Node3D = eye.parked
	var feet: Vector3 = eye._feet
	var gap := Vector2(feet.x,feet.z).distance_to(eye._parked_at)
	check(gap > eye.PARKED_ROOM and gap <= eye.BOARD_REACH,"The walker stands beside it (%.2f m)" % gap)
	var t := parked.transform
	var worst := 0.0
	for c: Vector3 in [t*Vector3(-PlaneStrip.WHEEL_GAUGE,-PlaneStrip.WHEEL_DROP,-PlaneStrip.WHEEL),t*Vector3(PlaneStrip.WHEEL_GAUGE,-PlaneStrip.WHEEL_DROP,-PlaneStrip.WHEEL),t*Vector3(0.0,-0.12,PlaneStrip.TAIL)]:
		worst = maxf(worst,absf(c.y-eye._ground(c)))
	check(worst < 0.06,"Its wheels and skid stand on the ground (%.3f m off at worst)" % worst)
	check(parked.get_parent() == eye.editor.terrain and eye.editor.data.objects.size() == objects,"It stands with the land, not a record on it (%d objects)" % eye.editor.data.objects.size())
	check(parked.find_children("*","CollisionObject3D",true,false).is_empty(),"Nothing on it for a tool or a pick to hit")
	eye._read_obstacles(false)
	check(eye._blocked(eye._parked_at),"The walker steps round it")
	check(eye.editor.data.has_land(eye._parked_at),"It stands on the island's land")

func _other_island(objects: int) -> void:
	var islands: Node3D = eye.islands
	var index := -1
	var began := Time.get_ticks_msec()
	while index < 0 and Time.get_ticks_msec()-began < 30000:
		for i in range(islands.offsets.size()):
			if islands.lands[i] != null and islands._rise[i] == Vector3.ZERO:
				index = i
				break
		await process_frame
	check(index >= 0,"Another island stands baked in the sky")
	if index < 0: return
	var target: Vector3 = islands.homes[index]
	var origin: Vector3 = islands.origin
	var home: Vector3 = islands.offsets[index]+eye.editor.terrain.global_position
	eye.glide.position = home+Vector3(-90.0,30.0,0.0)
	eye.glide.heading = -PI*0.5
	eye.chase.reset(eye.glide,eye.glide.position+Vector3(-5.0,2.0,0.0))
	await frames(2)
	eye.handle(_key(KEY_F))
	var out: Array = await _until_walking(60.0)
	check(islands.origin != origin,"F by another island claims it (the world shifted %s)" % str(islands.origin-origin))
	check(-islands.origin == target,"Claimed, it is the plate")
	check(eye.active and not eye.flying and (out[0] as Array).has("touchdown"),"And lands on it: %s" % " > ".join(out[0]))
	await _parked_well(eye.editor.data.objects.size())
