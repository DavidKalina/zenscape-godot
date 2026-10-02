extends SceneTree
## Headless probe of the fall spots (scripts/fall_spots.gd): where poured
## water would make a waterfall, shown as faint rings while water is in hand.
## On the cozy worlds scene with live water, the world it opens on is read
## first (its spots and the scan's cost, for reading); then the plate is laid
## flat. Prints JSON lines and PASS/FAIL:
## - "flat": the flat plate has no spots.
## - "mesa": a 2.5 m mesa with a cliff on its +x side (gentle slopes
##   elsewhere) has spots, all just above the cliff's lip, none on the flat
##   below or the mesa's gentle flanks; the scan's cost.
## - "notch": a notch cut through the +z rim gives an edge spot inside it,
##   after the mesa's lips.
## - "pour": live water poured at the best spot (a tap, as the can's) stands
##   a waterfall (WaterFlow `cascades` with flow_falls.gd DETECT) near it.
## - "shown": the rings come with the can, the case's water or a carried
##   ball while the hand hovers the land, not before DELAY, not with another
##   tool, and go once the can pours.
##   perl -e 'alarm 300; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     --script res://tools/probe_fall_spots.gd -- --no-title --no-rain-runoff
## Nothing here is drawn: the rings' look is unverified headless.

const FallSpots = preload("res://scripts/fall_spots.gd")
const FlowFalls = preload("res://scripts/flow_falls.gd")
## The mesa: its top, the cliff's foot from x = CLIFF.x to CLIFF.y, and the
## gentle ramp up from the west and down to either side.
const TOP := 2.5
const CLIFF := Vector2(-1.4,-0.6)
const RAMP := Vector2(-12.0,-6.0)
const SIDES := Vector2(4.0,10.0)
const LEVEL := 0.5
var scene: Node3D
var editor: NativeChunkEditor
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func screen_of(point: Vector2) -> Vector2:
	var data := editor.data
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(point.x,float(data.sample(point,data.heights)),point.y)))

func mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(seconds: float) -> void:
	for i in range(int(seconds*60.0)): await process_frame

func mesa(p: Vector2) -> float:
	var x := smoothstep(RAMP.x,RAMP.y,p.x)*(1.0-smoothstep(CLIFF.x,CLIFF.y,p.x))
	return LEVEL+TOP*x*(1.0-smoothstep(SIDES.x,SIDES.y,absf(p.y)))

func shape(height: Callable) -> void:
	var heights := editor.data.heights.duplicate()
	for i in range(heights.size()): heights[i] = height.call(editor.data.points[i])
	editor.data.heights = heights
	await editor.refresh(self)

func spot_json(spot: Dictionary) -> Dictionary:
	return {"kind":spot.kind,"at":[snappedf(spot.at.x,0.01),snappedf(spot.at.z,0.01),snappedf(spot.at.y,0.01)],"drop":snappedf(spot.drop,0.01),"score":snappedf(spot.score,0.01)}

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("Fall spots probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-fall-spots-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	editor = scene._chunk_editor
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	while editor.flow == null or not editor.flow.ready: await process_frame
	var flow: RefCounted = editor.flow
	flow.runoff = preload("res://scripts/rain_runoff.gd").new()

	# The world the scene opened on, for reading: its spots and their cost.
	var world := FallSpots.Scan.new(editor.data)
	world.advance(-1)
	print(JSON.stringify({"world":world.found.map(spot_json),"candidates":world.candidates.size(),"scan_usec":world.usec}))

	# Flat: nothing.
	await shape(func(_p: Vector2) -> float: return LEVEL)
	var flat := FallSpots.scan(editor.data)
	print(JSON.stringify({"flat":flat.map(spot_json)}))
	check(flat.is_empty(),"the flat plate has no fall spots (%d)" % flat.size())

	# The mesa.
	await shape(mesa)
	var job := FallSpots.Scan.new(editor.data)
	job.advance(-1)
	var spots := job.found
	var again := FallSpots.Scan.new(editor.data)
	again.advance(-1)
	var slices := FallSpots.Scan.new(editor.data)
	var count := 0
	while not slices.advance(FallSpots.SCAN_BUDGET_USEC): count += 1
	print(JSON.stringify({"mesa":spots.map(spot_json),"candidates":job.candidates.size(),"scan_usec":job.usec,"again_usec":again.usec,"sliced_frames":count+1,"sliced_usec":slices.usec}))
	check(spots.size() >= 2 and spots.size() <= FallSpots.MAX_SPOTS,"the mesa has 2-%d spots (%d)" % [FallSpots.MAX_SPOTS,spots.size()])
	var lip_ok := true
	for spot: Dictionary in spots:
		# Just above the lip: on the mesa's top within reach of the cliff, and
		# not out on its gentle sides.
		lip_ok = lip_ok and spot.kind == "lip" and spot.at.x >= CLIFF.x-FallSpots.APPROACH-0.6 and spot.at.x <= CLIFF.y and absf(spot.at.z) <= SIDES.x+1.0 and spot.at.y >= LEVEL+TOP*0.6
	check(lip_ok,"every spot stands just above the cliff's lip")
	var apart := true
	for a in range(spots.size()):
		for b in range(a+1,spots.size()):
			apart = apart and Vector2(spots[a].at.x,spots[a].at.z).distance_to(Vector2(spots[b].at.x,spots[b].at.z)) >= FallSpots.SPACING
	check(apart,"the spots stand %.0f m apart or more" % FallSpots.SPACING)
	check(slices.found.size() == spots.size(),"the scan in slices finds the same spots")
	check(job.usec < 250000,"one whole scan costs under 250 ms (%d µs)" % job.usec)

	# A notch through the +z rim, east of the mesa.
	var notch := Vector2(8.0,14.0)
	await shape(func(p: Vector2) -> float:
		var cut := 0.6*(1.0-smoothstep(0.6,1.6,absf(p.x-notch.x)))*smoothstep(10.5,13.5,p.y)
		return mesa(p)-cut)
	var notched := FallSpots.scan(editor.data)
	print(JSON.stringify({"notch":notched.map(spot_json)}))
	var edges := notched.filter(func(spot: Dictionary) -> bool: return spot.kind == "edge")
	check(not edges.is_empty() and absf(edges[0].at.x-notch.x) <= 1.5 and edges[0].at.z >= 11.0,"the notch gives an edge spot inside it")
	check(notched[0].kind == "lip","the mesa's lips rank above the notch")
	await shape(mesa)

	# Pour at the best spot: a tap, as the can's, and the flow's own falls.
	var best: Dictionary = spots[0]
	var at := Vector2(best.at.x,best.at.z)
	flow.taps["probe"] = [at.x,at.y,0.45,0.5]
	var falls: Array = []
	var waited := 0.0
	while waited < 30.0 and falls.is_empty():
		await frames(1.0)
		waited += 1.0
		falls = flow.cascades(FlowFalls.DETECT)
	flow.taps.erase("probe")
	var nearest := INF
	for fall: Dictionary in falls: nearest = minf(nearest,Vector2(fall.lip.x,fall.lip.z).distance_to(at))
	print(JSON.stringify({"pour":{"native":flow.native,"seconds":waited,"falls":falls.map(func(fall: Dictionary) -> Dictionary: return {"lip":[snappedf(fall.lip.x,0.01),snappedf(fall.lip.z,0.01),snappedf(fall.lip.y,0.01)],"drop":snappedf(fall.drop,0.01),"flux":snappedf(fall.flux,0.001)}),"nearest_lip":snappedf(nearest,0.01)}}))
	check(not falls.is_empty() and nearest <= 2.5,"water poured at the best spot stands a waterfall with its lip within 2.5 m")
	editor.flow.drain(Vector2.ZERO,40.0)
	await frames(0.5)

	# Shown only with water in hand, hovering the land, and gone in a pour.
	var reach: Node = scene.hand_reach
	var materials: Node = reach.materials
	var rings: Node = reach.spots
	check(rings != null,"the hand made the fall spots")
	if rings == null:
		quit(1)
		return
	scene.set("crafting",false)
	var hover := Vector2(4.0,0.0)
	reach.pointer_override = screen_of(hover)
	materials.select_tool("hand",true)
	await frames(1.5)
	var state := func() -> Dictionary: return {"visible":rings.visible_count(),"shown":snappedf(rings.shown,0.01),"reason":rings.reason,"holding":reach.holding,"zone":reach.hover_zone}
	print(JSON.stringify({"hand":state.call()}))
	check(rings.visible_count() == 0,"no rings with the Modeller in hand (%s)" % rings.reason)
	materials.select_tool("can",true)
	await frames(0.3)
	print(JSON.stringify({"can_early":state.call()}))
	check(rings.visible_count() == 0,"no rings before DELAY")
	await frames(1.5)
	var t0 := Time.get_ticks_usec()
	for k in range(60): rings.step(1.0/60.0)
	print(JSON.stringify({"can":state.call(),"step_usec":(Time.get_ticks_usec()-t0)/60}))
	check(rings.visible_count() == rings.spots.size() and rings.visible_count() > 0 and rings.shown > 0.9,"the can hovering the land shows the rings")
	var screen := screen_of(hover)
	reach.take_hold("can",screen)
	check(editor.can_in_hand(screen,1.0,false),"the can takes a press")
	await frames(0.5)
	print(JSON.stringify({"pouring":state.call()}))
	check(rings.visible_count() == 0 and rings.reason == "pouring","the rings go once the can pours (%s)" % rings.reason)
	reach.release(screen)
	await frames(1.5)
	check(rings.visible_count() > 0,"they come back on the hover after the pour")
	materials.select_tool("hand",true)
	await frames(0.5)
	check(rings.visible_count() == 0,"they go when the can is put down")
	materials.take("water")
	await frames(1.5)
	print(JSON.stringify({"case_water":state.call()}))
	check(rings.visible_count() > 0,"the case's water in hand shows the rings")
	materials.put_back()
	await frames(0.5)
	check(rings.visible_count() == 0,"they go when the water is put back")
	reach.pointer_override = screen
	# The ball is carried while the button is down.
	mouse(screen,true)
	check(editor.ball_from_sky(screen),"a ball forms (as from the sky)")
	await frames(1.5)
	print(JSON.stringify({"ball":state.call()}))
	check(rings.visible_count() > 0,"a carried ball shows the rings")
	mouse(screen,false)
	editor._ball_release()
	await frames(0.3)
	print(JSON.stringify({"ball_dropped":state.call()}))
	check(rings.visible_count() == 0,"they go when the ball is let go")
	print("Failures: %d" % failures)
	quit(1 if failures > 0 else 0)
