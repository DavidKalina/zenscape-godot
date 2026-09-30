extends SceneTree
## Headless probe of the wind in the sky (scripts/sky_wind.gd,
## docs/scenic/modeless.md "Wind"), on the cozy worlds scene with synthesized
## input:
##   - a click in empty sky blows nothing (and snaps, with --void-snap);
##   - a quick swipe sends one gust across the land, along the swipe as the
##     camera sees it, and leaves the prevailing wind alone;
##   - a held sweep turns the prevailing wind the way it is pulled, the air
##     swings round while held, and it stays when let go, with no gust;
##     pulled further it blows harder; pollen's wind follows it;
##   - a drag from the sky onto the land takes the wind tool in hand there:
##     its lane is promised while held, a swipe on sends it along the drag,
##     a still hold bursts, and the prevailing wind is left as it was.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_sky_wind.gd -- --no-title
const Wind = preload("res://scripts/pollen_wind.gd")
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


## Empty sky: void, no cloud, and room to drag `span` px each way within it.
func empty_sky() -> Vector2:
	for y in [30,60,100,140]:
		for x in [200,400,600,720,900,1100,1250]:
			var at := Vector2(x,y)
			if reach.void_at(at) and reach._cloud_at(at) == null: return at
	return Vector2.INF

## The world way (x, z) a screen direction points, as the camera sees it.
func ground_way(screen: Vector2) -> Vector2:
	var right: Vector3 = scene.camera.global_basis.x
	var away: Vector3 = -scene.camera.global_basis.z
	var way := Vector2(right.x,right.z).normalized()*screen.x-Vector2(away.x,away.z).normalized()*screen.y
	return way.normalized()

func angle_off(a: float, b: float) -> float:
	return absf(rad_to_deg(angle_difference(a,b)))

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: push_error("sky wind probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-sky-wind-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	scene.world_clock.running = false
	var wind: RefCounted = reach.get("wind")
	var air: Node = scene._atmosphere
	check("the sky's wind is made under the modeless hand",wind != null and air != null)
	if wind == null or air == null:
		quit(1)
		return
	await frames(30)
	var sky := empty_sky()
	check("found empty sky",sky != Vector2.INF,sky)
	if sky == Vector2.INF:
		quit(1)
		return

	# A click snaps with --void-snap; without it, it does nothing.
	var snaps: int = reach.snaps
	var click := 1 if reach.sky_snap else 0
	point(sky)
	await frames(3)
	button(sky,true)
	await frames(2)
	button(sky,false)
	await frames(3)
	check("a click in the sky %s" % ("still snaps" if reach.sky_snap else "does not snap"),reach.snaps == snaps+click,[snaps,reach.snaps])
	check("and blows nothing",wind.gusts == 0 and wind.sweeps == 0 and (editor.gust == null or editor.gust.gusts.is_empty()))

	# A quick swipe: a gust, the weather left alone.
	var angle_before: float = air.direction_angle
	var strength_before: float = air.strength
	point(sky)
	await frames(2)
	button(sky,true)
	await frames(1)
	var end := await drag(sky,sky+Vector2(360,0),6)
	button(end,false)
	await frames(2)
	check("a quick swipe sends a gust",wind.gusts == 1 and editor.gust != null and editor.gust.gusts.size() == 1,[wind.gusts,editor.gust.gusts.size() if editor.gust != null else -1])
	check("and does not snap",reach.snaps == snaps+click)
	if editor.gust != null and not editor.gust.gusts.is_empty():
		var g: Dictionary = editor.gust.gusts[0]
		var world: Vector3 = editor.terrain.global_basis*Vector3(g.heading.x,0.0,g.heading.y)
		var want := ground_way(Vector2(1,0))
		check("the gust runs along the swipe as the camera sees it",angle_off(atan2(world.z,world.x),want.angle()) < 3.0,[Vector2(world.x,world.z).normalized(),want])
		check("it is a lane across the land",g.kind == "lane" and float(g.reach) > 8.0 and float(g.power) > 0.5,[g.kind,g.reach,g.power])
	check("a swipe leaves the prevailing wind alone",is_equal_approx(air.direction_angle,angle_before) and is_equal_approx(air.strength,strength_before),[angle_before,air.direction_angle])
	await frames(120)

	# A held sweep, pulled up the screen (away from the camera).
	point(sky+Vector2(0,40))
	var from := sky+Vector2(0,40)
	await frames(2)
	button(from,true)
	await frames(1)
	var pulled := await drag(from,from+Vector2(0,-30),5)
	await frames(30)
	check("held past a swipe, it takes the wind in hand",wind.state == "steer",wind.state)
	var want := ground_way(Vector2(0,-1))
	check("the wind turns the way it is pulled",angle_off(deg_to_rad(air.direction_angle),want.angle()) < 3.0,[air.direction_angle,rad_to_deg(want.angle())])
	var gentle: float = air.strength
	await frames(30)
	check("the air swings round while held",angle_off(air._air_angle,want.angle()) < 10.0,[rad_to_deg(air._air_angle),rad_to_deg(want.angle())])
	var pollen_way: Vector2 = Wind.at(scene,editor.terrain,Vector2.ZERO)
	var pollen_world: Vector3 = editor.terrain.global_basis*Vector3(pollen_way.x,0.0,pollen_way.y)
	check("pollen drifts on it",pollen_way.length() > 0.0 and angle_off(atan2(pollen_world.z,pollen_world.x),want.angle()) < 12.0,[pollen_way])
	pulled = await drag(pulled,pulled+Vector2(250,0),10)
	await frames(20)
	var strong: float = air.strength
	check("pulled further it blows harder",strong > gentle+0.3,[gentle,strong])
	var turned := ground_way(pulled-from)
	check("and turns with the pull",angle_off(deg_to_rad(air.direction_angle),turned.angle()) < 3.0,[air.direction_angle,rad_to_deg(turned.angle())])
	var gusts: int = editor.gust.gusts.size() if editor.gust != null else 0
	button(pulled,false)
	await frames(3)
	check("let go, it is a sweep, not a gust",wind.sweeps == 1 and wind.gusts == 1,[wind.sweeps,wind.gusts])
	check("and no snap",reach.snaps == snaps+click)
	var kept: float = air.direction_angle
	await frames(120)
	check("the wind stays as it was left",is_equal_approx(air.direction_angle,kept) and is_equal_approx(air.strength,strong),[kept,air.direction_angle,strong,air.strength])
	check("counted as a use",int(reach.uses.get("wind",0)) == 2,reach.uses.get("wind",0))

	# From the sky onto the land: the wind tool in hand.
	var land := Vector2.INF
	for at: Vector2 in [Vector2(720,450),Vector2(720,520),Vector2(720,380),Vector2(620,450),Vector2(820,450)]:
		if reach._land(at) != null:
			land = at
			break
	check("found land on screen",land != Vector2.INF)
	if land != Vector2.INF:
		var sent: int = editor.gust.gusts.size()
		var wind_angle: float = air.direction_angle
		var wind_strength: float = air.strength
		var start := sky
		point(start)
		await frames(2)
		button(start,true)
		await frames(1)
		var over := await drag(start,land,8,func() -> bool: return editor.gust.aiming())
		check("dragged onto the land, the wind tool is in hand",editor.gust.aiming() and wind.handed == 1 and reach.holding.is_empty(),[editor.gust.aiming(),wind.handed,reach.holding])
		check("the hand blows open",editor.hand_gesture() == "void",editor.hand_gesture())
		check("carrying the flick's heading",editor.gust._aim.heading != Vector2.ZERO and float(editor.gust._aim.power) > 0.15,[editor.gust._aim.heading,editor.gust._aim.power])
		var on := await drag(over,over+Vector2(0,120),6)
		var promised: Dictionary = editor.gust.promise()
		check("its lane is promised while held",promised.get("kind","") == "lane",promised)
		button(on,false)
		await frames(3)
		check("let go, the tool's gust goes",editor.gust.gusts.size() > sent and not editor.gust.aiming(),[sent,editor.gust.gusts.size()])
		if editor.gust.gusts.size() > sent:
			var g: Dictionary = editor.gust.gusts.back()
			var world: Vector3 = editor.terrain.global_basis*Vector3(g.heading.x,0.0,g.heading.y)
			var down := ground_way(Vector2(0,1))  # the swipe on the land runs down the screen
			check("along the drag as the camera sees it",angle_off(atan2(world.z,world.x),down.angle()) < 15.0,[Vector2(world.x,world.z).normalized(),down])
			check("sent as promised",g.kind == promised.kind and absf(float(g.power)-float(promised.power)) < 0.1,[g.power,promised.power])
		check("the prevailing wind is left alone",is_equal_approx(air.direction_angle,wind_angle) and is_equal_approx(air.strength,wind_strength),[wind_angle,air.direction_angle])
		check("and no snap",reach.snaps == snaps+click)
		await frames(120)
		# Onto the land and held still: a burst.
		sent = editor.gust.gusts.size()
		point(start)
		await frames(2)
		button(start,true)
		await frames(1)
		over = await drag(start,land,8,func() -> bool: return editor.gust.aiming())
		await frames(60)
		check("held still on the land, it gathers a burst",editor.gust.aiming() and editor.gust.promise().get("kind","") == "burst",editor.gust.promise())
		button(over,false)
		await frames(3)
		check("and bursts",editor.gust.gusts.size() > sent and editor.gust.gusts.back().kind == "burst")
		check("both counted as uses",int(reach.uses.get("wind",0)) == 4,reach.uses.get("wind",0))
	print("RESULT "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
	quit(0 if failures.is_empty() else 1)
