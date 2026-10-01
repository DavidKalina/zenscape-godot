extends SceneTree
## Headless probe of the Sculpt (scripts/clay_tools/sculpt.gd), the painting
## tool, on the real cozy worlds scene, driven by synthesized input through
## hand_reach. Checks: its pocket takes it; the mode strip and Q/E pick its
## modes; a press held still raises (or lowers) the ground continuously, more
## the longer it is held, with no hold-then-drag; a quick click still leaves
## a mark; a Hills drag sets down several separate hills; Smooth softens
## rough ground; Shift inverts Raise; each press is one undo step that one
## undo takes back exactly.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_sculpt.gd -- --modeless --no-title
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var hand: Node
var failures := []
var worked: Array = []

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
	root.push_input(event)

func motion(at: Vector2, relative: Vector2, held := true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event)

func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)
		await process_frame

func shift(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func click(at: Vector2) -> void:
	button(at,true)
	await frames(2)
	button(at,false)
	await frames(2)

func settled() -> void:
	var quiet := 0
	while quiet < 20:
		await process_frame
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or clay.state != 0 or clay.poking
		quiet = 0 if busy else quiet+1

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func plate(at: Vector2) -> Variant:
	var hit: Variant = editor.pick(at)
	return Vector2(hit.x,hit.z) if hit != null else null

func bare(at: Vector2) -> bool:
	return reach.reach_at(at) == "" and reach._land(at) != null and not reach._prop_at(at)

## Mean |h - mean of neighbours| over the points within `radius` of `center`.
func roughness(center: Vector2, radius: float) -> float:
	var data := editor.data
	var total := 0.0
	var count := 0
	for i in range(data.points.size()):
		if data.points[i].distance_to(center) >= radius: continue
		var around: PackedInt32Array = data._neighbors[i]
		if around.is_empty(): continue
		var mean := 0.0
		for j in around: mean += data.heights[j]
		total += absf(data.heights[i]-mean/around.size())
		count += 1
	return total/maxi(count,1)

func mean_height(center: Vector2, radius: float) -> float:
	var data := editor.data
	var total := 0.0
	var count := 0
	for i in range(data.points.size()):
		if data.points[i].distance_to(center) >= radius: continue
		total += data.heights[i]
		count += 1
	return total/maxi(count,1)

## Points moved from `base`: {"up","down","moved"} counts past `least` metres.
func moved(base: PackedFloat32Array, least := 0.01) -> Dictionary:
	var up := 0
	var down := 0
	var heights := editor.data.heights
	for i in range(base.size()):
		var d := heights[i]-base[i]
		if d > least: up += 1
		elif d < -least: down += 1
	return {"up":up,"down":down,"moved":up+down}

## One undo takes the land back to `base` exactly, with no step left over.
func undo_exact(base: PackedFloat32Array, undo0: int, what: String) -> void:
	editor.undo()
	await settled()
	check("one undo restores the ground exactly (%s)" % what,editor.data.heights == base and editor.data._undo.size() == undo0)

## Roughen the ground round `at` (the probe's own set-up, not an undo step).
func roughen(at: Vector2, radius: float, seed_value: int) -> void:
	var noise := RandomNumberGenerator.new()
	noise.seed = seed_value
	var data := editor.data
	var rough := data.heights.duplicate()
	for i in range(data.points.size()):
		if data.points[i].distance_to(at) < radius: rough[i] += noise.randf_range(-0.12,0.12)
	data.heights = rough
	editor.force_refresh()
	await settled()

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("sculpt probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-sculpt-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	hand = scene.get("god_hand")
	materials = reach.get("materials")
	scene.world_clock.running = false
	check("land clay and the materials tray exist",clay != null and materials != null)
	if clay == null or materials == null:
		quit(1)
		return
	clay.worked.connect(func(verb: String, kept: bool) -> void: worked.append([verb,kept]))
	await settled()
	var data := editor.data
	var roll: Control = materials.roll
	var at := Vector2.INF
	for candidate in [Vector2(-2,1),Vector2(-3,-2),Vector2(2,3),Vector2(0,-4),Vector2(-5,4),Vector2(4,-3),Vector2(-6,-5),Vector2(1,0)]:
		var s := screen(candidate)
		if bare(s) and bare(s+Vector2(-160,0)) and bare(s+Vector2(160,0)) and bare(s+Vector2(0,-60)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	print("spot ",at," on screen ",spot," ground ",snappedf(height(at),0.01))
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	var pocket: Vector2 = roll._cell(roll.TOOLS.find("sculpt")).get_center()
	check("the sculpt's pocket hit-tests to it",roll.tool_at(pocket) == "sculpt",roll.tool_at(pocket))
	await click(pocket)
	check("pressing the pocket takes the sculpt",roll.tool == "sculpt" and clay.tool_id == "sculpt",[roll.tool,clay.tool_id])
	var sculpt: RefCounted = clay.tool
	# The mode strip and the keys.
	for i in range(30): await process_frame
	var cells: Array = roll._mode_cells()
	check("the strip has a cell per mode",cells.size() == 4,cells.size())
	await click((cells[2] as Rect2).get_center())
	check("pressing Hills on the strip takes it",sculpt.mode == "hills" and roll.mode == "hills",[sculpt.mode,roll.mode])
	await key(KEY_E)
	check("E steps to Smooth",sculpt.mode == "smooth" and roll.mode == "smooth",sculpt.mode)
	await key(KEY_E)
	await key(KEY_Q)
	await key(KEY_Q)
	await key(KEY_Q)
	check("Q steps back, wrapping round to Lower",sculpt.mode == "lower",sculpt.mode)
	var undo0: int = data._undo.size()

	# --- Raise and lower: held still, it keeps working ---
	for way in ["raise","lower"]:
		materials.set_mode(way)
		var base := data.heights.duplicate()
		var before := height(at)
		button(spot,true)
		await frames(15)
		var early := height(at)-before
		await frames(45)
		var late := height(at)-before
		button(spot,false)
		await settled()
		print(way.to_upper()," ",JSON.stringify({"after_15":snappedf(early,0.01),"after_60":snappedf(late,0.01)}))
		var sign := 1.0 if way == "raise" else -1.0
		check("%s held still moves the ground at once" % way,early*sign > 0.15,early)
		check("%s keeps going while held" % way,late*sign > early*sign*2.0,[early,late])
		check("%s is one undo step" % way,data._undo.size() == undo0+1,data._undo.size()-undo0)
		await undo_exact(base,undo0,way)

	# --- A quick click still leaves a mark ---
	materials.set_mode("raise")
	var tap_base := data.heights.duplicate()
	var tap_before := height(at)
	await click(spot)
	await settled()
	var tap := height(at)-tap_before
	check("a click raises a little",tap > 0.2 and tap < 1.5,tap)
	await undo_exact(tap_base,undo0,"click")

	# --- Shift inverts Raise ---
	var shift_base := data.heights.duplicate()
	var shift_before := height(at)
	shift(true)
	button(spot,true)
	await frames(30)
	button(spot,false)
	shift(false)
	await settled()
	check("Shift with Raise lowers",height(at) < shift_before-0.2,height(at)-shift_before)
	await undo_exact(shift_base,undo0,"shift raise")

	# --- Hills: a drag sets down several ---
	materials.set_mode("hills")
	var hill_base := data.heights.duplicate()
	var from := spot+Vector2(-150,0)
	button(from,true)
	await frames(2)
	for k in range(60):
		motion(from+Vector2(5*(k+1),0),Vector2(5,0))
		await frames(1)
	button(from+Vector2(300,0),false)
	await settled()
	var count := moved(hill_base,0.05)
	# Peaks: points higher than all their neighbours and raised 0.3 m or more.
	var peaks := 0
	for i in range(data.points.size()):
		if data.heights[i]-hill_base[i] < 0.3: continue
		var top := true
		for j in data._neighbors[i]:
			if data.heights[j] > data.heights[i]: top = false
		if top: peaks += 1
	print("HILLS ",JSON.stringify({"raised":count.up,"lowered":count.down,"peaks":peaks}))
	check("a hills drag raises ground and lowers none",count.up > 50 and count.down == 0,count)
	check("as several hills",peaks >= 2,peaks)
	check("hills are one undo step",data._undo.size() == undo0+1)
	await undo_exact(hill_base,undo0,"hills")

	# --- Smooth softens rough ground ---
	await roughen(at,4.0,11)
	materials.set_mode("smooth")
	var smooth_base := data.heights.duplicate()
	var rough_before := roughness(at,1.5)
	button(spot,true)
	await frames(30)
	button(spot,false)
	await settled()
	var rough_after := roughness(at,1.5)
	check("smooth softens rough ground",rough_after < rough_before*0.5,"%.4f -> %.4f" % [rough_before,rough_after])
	await undo_exact(smooth_base,undo0,"smooth")

	# --- Other tools' modes: the fan picks the verb, no hold-then-drag ---
	materials.select_tool("paddle")
	await frames(30)
	check("the paddle fans out its modes",roll.modes == ["swell","sweep","pat"] and roll.mode == "swell",[roll.modes,roll.mode])
	var swell_base := data.heights.duplicate()
	var swell_before := height(at)
	button(spot,true)
	await frames(2)
	check("a swell press is a hold at once",clay.state == clay.State.HOLD and clay.verb == "swell",[clay.state,clay.verb])
	for k in range(20):
		motion(spot-Vector2(0,4*(k+1)),Vector2(0,-4))
		await frames(1)
	button(spot-Vector2(0,80),false)
	await settled()
	check("dragging up straight away swells the land",height(at) > swell_before+0.5,height(at)-swell_before)
	await undo_exact(swell_base,undo0,"swell")
	materials.set_mode("pat")
	button(spot,true)
	await frames(2)
	for k in range(20):
		motion(spot+Vector2(5*(k+1),0),Vector2(5,0))
		await frames(1)
	button(spot+Vector2(100,0),false)
	await settled()
	check("in pat mode a dragged press is still a pat",not worked.is_empty() and worked.back()[0] == "pat",worked.back() if not worked.is_empty() else [])
	if data._undo.size() > undo0:
		editor.undo()
		await settled()
	await key(KEY_E)
	check("E steps the paddle's mode, wrapping round",roll.mode == "swell" and clay.tool.mode == "swell",[roll.mode,clay.tool.mode])
	materials.select_tool("hand")
	await frames(30)
	check("the modeller fans out its modes",roll.modes == ["pinch","groove","palm","poke"],roll.modes)
	var pinch_base := data.heights.duplicate()
	var pinch_before := height(at)
	button(spot,true)
	await frames(2)
	for k in range(20):
		motion(spot-Vector2(0,4*(k+1)),Vector2(0,-4))
		await frames(1)
	button(spot-Vector2(0,80),false)
	await settled()
	check("the modeller's pinch starts at the press",height(at) > pinch_before+0.5,height(at)-pinch_before)
	await undo_exact(pinch_base,undo0,"pinch")
	materials.select_tool("hammer")
	await frames(10)
	check("the hammer, one verb, has no fan",roll.modes.is_empty())

	print("SCULPT PROBE: ",failures.size()," failures ",failures)
	quit(1 if not failures.is_empty() else 0)
