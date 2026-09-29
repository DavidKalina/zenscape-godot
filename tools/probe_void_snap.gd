extends SceneTree
## Headless: the void and the snap (docs/scenic/modeless.md "Void slice"). Over
## the sky the hand floats ready on the pointer's ray and hides over the UI; a
## click snaps day to night and back at once, Shift-click steps the golden
## hours, a drag does not snap, a right drag fades the hand and it comes back,
## land and rim presses are untouched, and the pins behave.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_void_snap.gd -- --modeless
const VoidSnap = preload("res://scripts/void_snap.gd")
var scene: Node3D
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, pressed: bool, shift := false, which := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.shift_pressed = shift
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if which == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	root.push_input(event)

func motion(at: Vector2, relative: Vector2, mask := MOUSE_BUTTON_MASK_LEFT) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = mask
	root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

## Point the (headless) pointer at `at` and hover there.
func hover(at: Vector2) -> void:
	motion(at,Vector2.ZERO,0)
	await frames(1)
	scene.hand_reach.pointer_override = at
	scene.hand_reach._hover_key = []
	scene.hand_reach._hover(at)
	scene.hand_reach._drive_hand_modeless()

func click(at: Vector2, shift := false) -> void:
	button(at,true,shift)
	await frames(2)
	button(at,false,shift)
	await frames(1)

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("void snap probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-voidsnap-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	var reach: Node = scene.hand_reach
	var hand: Node3D = scene.god_hand
	var clock: WorldClock = scene.world_clock
	var sky: RefCounted = scene._celestial
	var mood: Node = scene.mood_look
	var editor: Node = scene._chunk_editor
	check("modeless is on",reach.modeless)
	for clip in ["VoidIn","VoidHold","VoidOut","SnapIn","SnapHold","SnapOut"]:
		check("the glb has "+clip,hand.player.has_animation(clip))
	scene._overview()
	await frames(150)
	var camera: Camera3D = scene.camera
	# A point in the sky, over no land: scan down from the top middle.
	var sky_at := Vector2(-1,-1)
	for y in range(30,400,10):
		for x in [720,300,1140]:
			if reach.void_at(Vector2(x,y)):
				sky_at = Vector2(x,y)
				break
		if sky_at.x >= 0: break
	var land_at: Vector2 = camera.unproject_position(editor.terrain.to_global(Vector3(0,float(editor.data.ground_height(Vector2.ZERO)),0)))
	var ui_at := Vector2(-1,-1)
	for y in range(20,900,20):
		for x in range(20,1440,40):
			if not editor.pointer_in_world(Vector2(x,y)):
				ui_at = Vector2(x,y)
				break
		if ui_at.x >= 0: break
	print("camera distance ",scene.distance," sky ",sky_at," land ",land_at," ui ",ui_at)
	check("a sky point is void",sky_at.x >= 0)
	check("the land's middle is not void",not reach.void_at(land_at))

	# --- Hover: the ready hand in the void, gone over the UI.
	await hover(sky_at)
	check("hover over the sky is the void zone",reach.hover_zone == "void",reach.hover_zone)
	check("the hand takes the void pose",hand.reach_gesture == "void",hand.reach_gesture)
	await frames(40)
	check("the hand plays the void clips",String(hand.player.current_animation).begins_with("Void"),hand.player.current_animation)
	check("the hand shows in the void",hand.opacity > 0.95,hand.opacity)
	var depth: float = camera.global_position.distance_to(hand.get_parent().to_global(hand.reach_point))
	var want: float = maxf(scene.distance*reach.VOID_DEPTH,reach.VOID_NEAR)
	check("it floats at the void depth along the ray",absf(depth-want) < 0.05,[depth,want])
	var on_screen: Vector2 = camera.unproject_position(hand.get_parent().to_global(hand.reach_point))
	check("its point is under the pointer",on_screen.distance_to(sky_at) < 2.0,on_screen)
	if ui_at.x >= 0:
		await hover(ui_at)
		check("over the UI the hover is nobody's",reach.hover_zone == "",reach.hover_zone)
		check("over the UI the hand lets go",hand.reach_gesture == "",hand.reach_gesture)
		await frames(30)
		check("over the UI the hand is hidden",hand.opacity < 0.05,hand.opacity)
	else:
		check("found a UI point",false)
	await hover(sky_at)
	await frames(30)

	# --- The snap: a running clock, day to night and back, at once.
	clock.running = true
	mood.pins.erase("time")
	sky.set_phase(0.4)
	await frames(2)
	var energy_day: float = sky._sun.light_energy
	var up_day: Vector3 = sky.state.zs_sky_up
	var day0 := clock.day
	button(sky_at,true)
	await frames(2)
	check("a press in the void is held by the hand",reach.holding == "void",reach.holding)
	check("the press loads the snap",hand.reach_gesture == "snap",hand.reach_gesture)
	button(sky_at,false)
	check("night at once, the same frame",absf(angle_difference(clock.phase*TAU,VoidSnap.NIGHT*TAU)) < 0.002 and float(sky.state.zs_night) > 0.9,[clock.phase,sky.state.zs_night])
	check("the key light changed at once",absf(sky._sun.light_energy-energy_day) > 0.05,[energy_day,sky._sun.light_energy])
	check("the sky changed at once",(sky.state.zs_sky_up as Vector3).distance_to(up_day) > 0.02,[up_day,sky.state.zs_sky_up])
	check("time went forward (a new day)",clock.day == day0+1,[day0,clock.day])
	check("the sky's radiance runs in real time",scene._environment.sky.process_mode == Sky.PROCESS_MODE_REALTIME)
	await frames(1)
	check("the hand snaps",String(hand.player.current_animation) == "SnapOut",hand.player.current_animation)
	check("a running clock keeps running",clock.running)
	check("and no hour is pinned",not mood.pins.has("time"),mood.pins)
	await frames(80)
	check("the radiance goes back to incremental",scene._environment.sky.process_mode == Sky.PROCESS_MODE_INCREMENTAL)
	check("the hand is back in the void hold",String(hand.player.current_animation) == "VoidHold",hand.player.current_animation)
	await click(sky_at)
	check("a second click: day",absf(angle_difference(clock.phase*TAU,VoidSnap.DAY*TAU)) < 0.003 and float(sky.state.zs_daylight) > 0.8,[clock.phase,sky.state.zs_daylight])

	# --- Pins: a held clock is pinned at the new hour.
	clock.running = false
	await frames(30)
	await click(sky_at)
	check("a held clock snaps to night",absf(clock.phase-VoidSnap.NIGHT) < 0.0005,clock.phase)
	check("and stays held",not clock.running)
	check("pinned as a held hour",str(mood.pins.get("time","")).begins_with(mood.HELD_HOUR),mood.pins.get("time",""))
	await frames(30)
	# A mood fading in is landed, not left to drag the hour back.
	mood.choose("golden_meadow")
	await frames(2)
	var was_fading: bool = mood.fading()
	mood.finish_fade()
	var expected := VoidSnap.target_phase(clock.phase,false)
	mood.choose("alpine_morning")
	await frames(2)
	was_fading = was_fading and mood.fading()
	expected = VoidSnap.target_phase(clock.phase,false)
	await click(sky_at)
	await frames(5)
	check("a mood's fade is landed by the snap",was_fading and not mood.fading(),[was_fading,mood.fading()])
	check("and the snapped hour holds after it",absf(angle_difference(clock.phase*TAU,expected*TAU)) < 0.01,[clock.phase,expected])
	await frames(30)

	# --- Shift: the golden hours in order.
	sky.set_phase(0.1)
	mood.pin_hour(0.1)
	await frames(30)
	var seen := []
	for i in range(5):
		await click(sky_at,true)
		seen.append(snappedf(clock.phase,0.001))
		await frames(30)
	var steps_ok := true
	for i in range(5): steps_ok = steps_ok and absf(seen[i]-[0.275,0.47,0.705,0.035,0.275][i]) < 0.0015
	check("Shift-click steps dawn, noon, dusk, night, dawn",steps_ok,seen)

	# --- A drag in the void is not a snap.
	var before: float = clock.phase
	var count: int = reach.snaps
	button(sky_at,true)
	await frames(2)
	var p := sky_at
	for i in range(8):
		p += Vector2(6,2)
		motion(p,Vector2(6,2))
		await frames(1)
	check("a drag relaxes the loaded hand",hand.reach_gesture == "void",hand.reach_gesture)
	button(p,false)
	await frames(2)
	check("a drag in the void does not snap",reach.snaps == count and is_equal_approx(clock.phase,before),[reach.snaps,clock.phase])
	check("and lets go",reach.holding == "",reach.holding)

	# --- The camera: a right drag fades the hand, which comes back after.
	await hover(sky_at)
	await frames(30)
	var shown: float = hand.opacity
	button(sky_at,true,false,MOUSE_BUTTON_RIGHT)
	await frames(1)
	p = sky_at
	for i in range(20):
		p += Vector2(8,0)
		motion(p,Vector2(8,0),MOUSE_BUTTON_MASK_RIGHT)
		await frames(1)
	check("the camera moves under a right drag",reach.camera_moving())
	check("the hand stands down",hand.held_off)
	check("and fades",shown > 0.9 and hand.opacity < 0.2,[shown,hand.opacity])
	button(p,false,false,MOUSE_BUTTON_RIGHT)
	var waited := 0
	while reach.camera_moving() and waited < 300:
		await frames(1)
		waited += 1
	await hover(sky_at)
	await frames(30)
	check("once the camera stops the hand comes back",not hand.held_off and hand.opacity > 0.9,[waited,hand.opacity])

	# --- Land and rim presses are as before.
	count = reach.snaps
	await hover(land_at)
	button(land_at,true)
	await frames(2)
	check("a land press is the land's",reach.holding == "land",reach.holding)
	button(land_at,false)
	await frames(2)
	var rim_at: Vector2 = camera.unproject_position(editor.terrain.to_global(reach._edge(Vector2(0,14))))
	button(rim_at,true)
	await frames(2)
	check("a rim press is the rim's",reach.holding == "rim",[reach.holding,rim_at])
	button(rim_at,false)
	await frames(5)
	check("neither snapped",reach.snaps == count,reach.snaps)
	print("snaps ",reach.snaps)
	print("FAILURES: ",failures)
	quit(1 if not failures.is_empty() else 0)
