extends SceneTree
## Headless probe of the lazy Susan turn (scripts/world_turn.gd,
## docs/scenic/hand-turn.md). Opens the product scene on the Genesis plain,
## raises a hill so the land has relief, and drives the camera with
## synthesized input at a fixed 60 Hz:
## - a right drag across the land: how far the grabbed ground strays from the
##   pointer on screen, and from its bearing round the pivot;
## - a flick: the world spins on, slows and stops by itself;
## - a press during a spin: the catch, its overshoot and settle;
## - a slow drag let go when still: no spin;
## - a land-brush press and drag: it paints and the world does not turn;
## - the hand: reach_gesture "turn" while gripping, "catch" on a catch, and
##   cleared after;
## - the idle drift (Space) still turns, and a grab stops it.
## With `-- --classic-orbit` it checks the rig orbits by pixels as before.
## Nothing is rendered: how it feels on screen is not checked here.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_world_turn.gd [-- --classic-orbit]
var scene: Node3D
var editor: NativeChunkEditor
var rig: Node
var turn: Node
var failures := []

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

func motion(at: Vector2, relative: Vector2, index := MOUSE_BUTTON_RIGHT) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

func screen_of(point: Vector3) -> Vector2:
	return scene.camera.unproject_position(point)

## Bearing of a point round the pivot.
func bearing(point: Vector3) -> float:
	return atan2(point.x-scene.target.x,point.z-scene.target.z)

## Drag from `from` by `step` pixels a frame for `count` frames, holding the
## grabbed ground's screen and bearing error each frame. Returns the errors.
func drag(from: Vector2, step: Vector2, count: int, index := MOUSE_BUTTON_RIGHT, release := true) -> Dictionary:
	var grabbed: Variant = rig.inspector.ground_hit(from)
	button(from,index,true)
	await frames(1)
	var at := from
	var worst_px := 0.0
	var worst_bearing := 0.0
	var worst_px_early := 0.0
	var hand := {}
	var clips := {}
	var lean := 0.0
	for i in range(count):
		at += step
		motion(at,step,index)
		await frames(1)
		if scene.god_hand != null:
			hand[scene.god_hand.reach_gesture] = true
			clips[String(scene.god_hand.player.current_animation)] = true
			lean = maxf(lean,scene.god_hand._lean.length())
		if turn.grab == null: continue
		var held: Vector3 = turn.grab
		var error: float = screen_of(held).distance_to(at)
		worst_px = maxf(worst_px,error)
		if i < 10: worst_px_early = maxf(worst_px_early,error)
		if i < 6 and "--trace" in OS.get_cmdline_user_args(): print("TRACE ",i," ",error," P ",screen_of(held)," at ",at," pivot ",screen_of(scene.target)," polar ",scene.polar)
		# The bearing of the ground now under the pointer, on the grab's level.
		var origin: Vector3 = scene.camera.project_ray_origin(at)
		var direction: Vector3 = scene.camera.project_ray_normal(at)
		var t: float = (held.y-origin.y)/direction.y
		var under: Vector3 = origin+direction*t
		worst_bearing = maxf(worst_bearing,absf(angle_difference(bearing(under),bearing(held))))
	if release: button(at,index,false)
	return {"clips":clips.keys(),"lean":lean,"on_land":grabbed != null,"end":at,"px":worst_px,"px_first_10":worst_px_early,"bearing_deg":rad_to_deg(worst_bearing),"hand":hand.keys()}

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: push_error("World turn probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-turn-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	rig = scene.camera_rig
	turn = rig.turn
	var data := editor.data
	data.begin_stroke()
	for _pass in range(14): data.brush(Vector2(5.0,-4.0),4.5,0.5,"raise",0.0)
	data.end_stroke()
	await editor.refresh(self)
	scene._overview()
	await frames(30)
	check("rig live on the plain",rig.live)
	var classic := "--classic-orbit" in OS.get_cmdline_user_args()
	var centre: Vector2 = Vector2(root.size)*0.5
	if classic:
		await run_classic(centre)
		finish()
		return
	check("turn on by default",turn.enabled)
	scene.select_brush("land")
	await frames(2)

	# A grab below and left of the pivot, dragged right: the world turns and
	# the grabbed ground keeps its bearing under the pointer.
	var yaw0: float = scene.yaw
	var grab := await drag(centre+Vector2(-150,110),Vector2(6,0),60,MOUSE_BUTTON_RIGHT,false)
	# Held still a moment before letting go.
	await frames(12)
	button(grab.end,MOUSE_BUTTON_RIGHT,false)
	await frames(2)
	print("GRAB ",JSON.stringify({"on_land":grab.on_land,"turned_deg":snappedf(rad_to_deg(scene.yaw-yaw0),0.1),"screen_px":snappedf(grab.px,0.1),"screen_px_first_10":snappedf(grab.px_first_10,0.1),"bearing_deg":snappedf(grab.bearing_deg,0.001),"hand":grab.hand}))
	var near_turn: float = scene.yaw-yaw0
	check("the drag turns the world",absf(scene.yaw-yaw0) > 0.2,rad_to_deg(scene.yaw-yaw0))
	check("the grabbed ground keeps its bearing under the pointer (< 0.05 deg)",grab.bearing_deg < 0.05,grab.bearing_deg)
	# The yaw is the only thing the side-to-side turns, so the grabbed ground
	# keeps its bearing but slides in and out along it as a straight drag
	# leaves the ground's circle: reported, not checked.
	check("the hand grips while turning",grab.hand.has("turn"),grab.hand)
	check("and plays TurnIn into TurnHold",grab.clips.has("TurnIn") and grab.clips.has("TurnHold"),grab.clips)
	check("and leans into the push",grab.lean > 0.05,grab.lean)
	check("a drag that stopped before release does not spin",not turn.spinning(),turn.spin)
	await frames(40)
	check("the hand lets go after",scene.god_hand == null or scene.god_hand.reach_gesture == "",scene.god_hand.reach_gesture if scene.god_hand != null else "")

	# A grab above the pivot, on the far side, dragged the same way: the far
	# side of a lazy Susan goes the other way.
	var far_from: float = scene.yaw
	var far := await drag(centre+Vector2(-120,-60),Vector2(3,0),20,MOUSE_BUTTON_RIGHT,false)
	var far_turn: float = scene.yaw-far_from
	await frames(12)
	button(far.end,MOUSE_BUTTON_RIGHT,false)
	await frames(2)
	print("FAR ",JSON.stringify({"on_land":far.on_land,"turned_deg":snappedf(rad_to_deg(far_turn),0.1),"screen_px":snappedf(far.px,0.1),"bearing_deg":snappedf(far.bearing_deg,0.001)}))
	check("the far side turns the other way",absf(far_turn) > 0.01 and signf(far_turn) != signf(near_turn),rad_to_deg(far_turn))
	await frames(30)

	# A flick: fast, let go while moving.
	await drag(centre+Vector2(-200,120),Vector2(30,0),8)
	await frames(1)
	var spin0: float = turn.spin
	check("a flick spins the world on",absf(spin0) > turn.FLICK_MIN,spin0)
	var yaws: Array[float] = [scene.yaw]
	var stopped := -1
	for i in range(600):
		await frames(1)
		yaws.append(scene.yaw)
		if not turn.spinning():
			stopped = i
			break
	var decays := true
	for i in range(2,yaws.size()):
		if absf(yaws[i]-yaws[i-1]) > absf(yaws[i-1]-yaws[i-2])+0.0001: decays = false
	var last_step := absf(yaws[-1]-yaws[-2]) if yaws.size() > 1 else 0.0
	print("SPIN ",JSON.stringify({"speed_rad_s":snappedf(spin0,0.01),"on_deg":snappedf(rad_to_deg(yaws[-1]-yaws[0]),0.1),"stopped_s":snappedf(stopped/60.0,0.01),"last_step_deg":snappedf(rad_to_deg(last_step),0.004)}))
	check("the spin slows every frame",decays)
	check("the spin runs down by itself (under 5 s)",stopped > 0 and stopped < 300,stopped/60.0)
	check("and eases out (last frame under 0.02 deg)",rad_to_deg(last_step) < 0.02,rad_to_deg(last_step))

	# A catch: flick, then a click mid-spin.
	await drag(centre+Vector2(-200,120),Vector2(30,0),8)
	await frames(15)
	var speed: float = turn.spin
	var catch_at: Vector2 = centre+Vector2(80,90)
	var caught: float = scene.yaw
	button(catch_at,MOUSE_BUTTON_RIGHT,true)
	await frames(1)
	button(catch_at,MOUSE_BUTTON_RIGHT,false)
	var peak := 0.0
	var back := 0.0
	var hand_caught := false
	var settled := -1
	var offsets: Array[float] = []
	for i in range(120):
		await frames(1)
		var offset: float = (scene.yaw-caught)*signf(speed)
		offsets.append(offset)
		peak = maxf(peak,offset)
		if peak > 0.0 and offset < 0.0: back = minf(back,offset)
		if scene.god_hand != null and scene.god_hand.reach_gesture == "catch": hand_caught = true
		if settled < 0 and turn.settle == 0.0 and turn.settle_speed == 0.0: settled = i
	print("CATCH ",JSON.stringify({"speed_rad_s":snappedf(speed,0.01),"overshoot_deg":snappedf(rad_to_deg(peak),0.01),"back_deg":snappedf(rad_to_deg(back),0.01),"final_deg":snappedf(rad_to_deg(offsets[-1]),0.001),"settled_s":snappedf(settled/60.0,0.01)}))
	check("a press mid-spin catches it",not turn.spinning())
	check("the catch overshoots a little (1-8 deg)",rad_to_deg(peak) > 1.0 and rad_to_deg(peak) < 8.0,rad_to_deg(peak))
	check("and comes back to where it was caught (< 0.05 deg)",absf(rad_to_deg(offsets[-1])) < 0.05,rad_to_deg(offsets[-1]))
	check("settled within a second",settled > 0 and settled < 60,settled/60.0)
	check("the hand catches",hand_caught or scene.god_hand == null)
	await frames(30)
	check("the hand lets go of the catch",scene.god_hand == null or scene.god_hand.reach_gesture == "")

	# Painting with the land brush: a left press on the land paints, and the
	# world does not turn.
	var heights: PackedFloat32Array = data.heights.duplicate()
	var yaw_paint: float = scene.yaw
	var undo_before: int = data._undo.size()
	var painted := await drag(centre+Vector2(40,60),Vector2(4,0),10,MOUSE_BUTTON_LEFT)
	await frames(4)
	check("a brush drag paints",data.heights != heights or data._undo.size() != undo_before,{"undo":[undo_before,data._undo.size()]})
	check("and the world does not turn",absf(scene.yaw-yaw_paint) < 0.0001 and not turn.grabbing,rad_to_deg(scene.yaw-yaw_paint))
	check("nor does the hand grip",not painted.hand.has("turn"),painted.hand)
	await frames(20)

	# The idle drift (Space) still turns, and a grab takes over from it.
	scene._auto_orbit = true
	var drift_from: float = scene.yaw
	await frames(60)
	check("the idle drift turns the world",scene.yaw-drift_from > 0.03,scene.yaw-drift_from)
	await drag(centre+Vector2(-150,110),Vector2(3,0),5)
	check("a grab stops the idle drift",not scene._auto_orbit)
	await frames(30)
	finish()

## `--classic-orbit`: no turn; a right drag orbits by pixels as before.
func run_classic(centre: Vector2) -> void:
	check("turn off with --classic-orbit",not turn.enabled)
	var yaw0: float = scene.yaw
	await drag(centre+Vector2(-150,110),Vector2(6,0),30)
	await frames(80)
	var expected := -TAU*6.0*30.0/900.0
	var turned: float = scene.yaw-yaw0
	# The rig's fling adds a little on release.
	check("a right drag orbits by pixels (a screen height a turn)",absf(turned-expected) < absf(expected)*0.25,{"turned":snappedf(turned,0.001),"pixels":snappedf(expected,0.001)})
	check("no grab",turn.grab == null and not turn.grabbing)

func finish() -> void:
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
