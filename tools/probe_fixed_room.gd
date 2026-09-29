extends SceneTree
## Headless probe of the fixed room under the lazy Susan turn
## (docs/scenic/hand-turn.md, "A fixed room"). Opens the product scene on the
## Genesis plain with the hour held, then turns the world with a right drag,
## a flick and Space's idle drift, and checks after each that:
## - the sun, moon, key light, rim light, alpen glow and cloud light
##   directions have turned by the camera's yaw about the vertical, so seen
##   from the camera they have not moved;
## - the sky's `zs_room_yaw` and the aurora's heading have turned by as much;
## - the hand's sun grab (scripts/hand_reach.gd `body_direction`) finds the
##   sun where it is drawn.
## A pose written from outside moves the camera, not the room. With
## `-- --classic-orbit` the room stays at 0 and nothing turns.
## Nothing is rendered: how it looks on screen is not checked here.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_fixed_room.gd [-- --classic-orbit]
const KEYS := ["zs_sun_direction","zs_moon_direction","zs_key_direction","zs_rim_direction","zs_alpen_direction","zs_cloud_direction"]
## Largest direction error (unit vector length) taken as the same direction.
const CLOSE := 0.0005

var scene: Node3D
var rig: Node
var turn: Node
var sky: RefCounted
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	event.factor = 1.0
	root.push_input(event)

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

func drag(from: Vector2, step: Vector2, count: int) -> void:
	button(from,true)
	await frames(1)
	var at := from
	for i in range(count):
		at += step
		motion(at,step)
		await frames(1)
	button(at,false)

## What the room publishes now: the directions, the room's yaw and the
## aurora's heading, and each direction as the camera sees it.
func snapshot() -> Dictionary:
	var seen := {}
	var world := {}
	var view: Basis = scene.camera.global_basis.inverse()
	for key in KEYS:
		var direction: Vector3 = Vector3(sky.state[key]).normalized()
		world[key] = direction
		seen[key] = view*direction
	return {"yaw":float(scene.yaw),"polar":float(scene.polar),"world":world,"seen":seen,"room":float(sky.state.zs_room_yaw),"aurora":float(sky.state.zs_aurora.w)}

## After the camera's yaw turned from `before` to now: every direction has
## turned by as much about the vertical, and the room with it.
func compare(label: String, before: Dictionary, expect_turn: bool) -> void:
	var now := snapshot()
	var turned: float = now.yaw-before.yaw
	var room: float = now.room-before.room
	var worst := 0.0
	var worst_seen := 0.0
	var still := 0.0
	for key in KEYS:
		var was: Vector3 = before.world[key]
		worst = maxf(worst,(was.rotated(Vector3.UP,turned)-Vector3(now.world[key])).length())
		worst_seen = maxf(worst_seen,(Vector3(before.seen[key])-Vector3(now.seen[key])).length())
		still = maxf(still,(was-Vector3(now.world[key])).length())
	var polar_kept: bool = absf(now.polar-before.polar) < 0.0005
	print(label.to_upper()," ",JSON.stringify({"camera_turned_deg":snappedf(rad_to_deg(turned),0.01),"room_turned_deg":snappedf(rad_to_deg(room),0.01),"aurora_turned_deg":snappedf(rad_to_deg(now.aurora-before.aurora),0.01),"direction_error":snappedf(worst,0.00001),"seen_from_camera_moved":snappedf(worst_seen,0.00001),"world_moved":snappedf(still,0.00001)}))
	if expect_turn:
		check(label+": the camera turned",absf(turned) > 0.03,rad_to_deg(turned))
		check(label+": the room turned by as much (zs_room_yaw)",absf(room-turned) < 0.0001,[rad_to_deg(room),rad_to_deg(turned)])
		check(label+": the aurora's heading turned by as much",absf(now.aurora-before.aurora-turned) < 0.0001,rad_to_deg(now.aurora-before.aurora))
		check(label+": sun, moon, key, rim, alpen and cloud light turned about the vertical by the camera's yaw",worst < CLOSE,worst)
		if polar_kept: check(label+": so seen from the camera they have not moved",worst_seen < CLOSE*4.0,worst_seen)
	else:
		check(label+": the room did not turn",absf(room) < 0.000001 and still < 0.000001,{"room":room,"moved":still})

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("Fixed room probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-room-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	rig = scene.camera_rig
	turn = rig.turn
	sky = scene._celestial
	# Hold the hour just after sunrise, so the sun and the moon are both up
	# and the key is the sun.
	sky.cycling = false
	sky.set_phase(0.3)
	scene._overview()
	await frames(30)
	check("rig live on the plain",rig.live)
	var classic := "--classic-orbit" in OS.get_cmdline_user_args()
	var centre: Vector2 = Vector2(root.size)*0.5
	var room0: float = sky.room_yaw
	if classic:
		check("turn off with --classic-orbit",not turn.enabled)
		var before := snapshot()
		await drag(centre+Vector2(-150,110),Vector2(6,0),30)
		await frames(80)
		compare("classic drag",before,false)
		check("the room's yaw stays 0",sky.room_yaw == 0.0 and float(sky.state.zs_room_yaw) == 0.0 and is_equal_approx(float(sky.state.zs_aurora.w),-1.2),sky.room_yaw)
		finish()
		return
	check("the room starts all but unturned (< 0.01 deg)",absf(rad_to_deg(room0)) < 0.01,room0)

	# A grab turned and held still, then let go.
	var before := snapshot()
	await drag(centre+Vector2(-150,110),Vector2(6,0),50)
	await frames(40)
	compare("grab",before,true)

	# A flick, run down to rest.
	before = snapshot()
	await drag(centre+Vector2(-200,120),Vector2(30,0),8)
	for i in range(1200):
		await frames(1)
		if not turn.spinning() and turn.settle == 0.0: break
	await frames(5)
	compare("flick",before,true)

	# Space's idle drift is a turn too.
	before = snapshot()
	scene._auto_orbit = true
	await frames(90)
	scene._auto_orbit = false
	await frames(5)
	compare("idle drift",before,true)

	# The sun grab: the hand looks for the disc where the sky draws it.
	var reach: Node = scene.get("hand_reach")
	if reach != null:
		var gap: float = (reach.body_direction("sun",float(sky.phase))-Vector3(sky.state.zs_sun_direction)).length()
		var moon_gap: float = (reach.body_direction("moon",float(sky.phase))-Vector3(sky.state.zs_moon_direction)).length()
		check("the hand's sun and moon are where the sky draws them",gap < 0.00001 and moon_gap < 0.00001,[gap,moon_gap])

	# A pose written from outside moves the camera, not the room.
	before = snapshot()
	scene.yaw += 1.0
	await frames(5)
	compare("pose from outside",before,false)
	finish()

func finish() -> void:
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
