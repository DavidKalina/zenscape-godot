extends SceneTree
## Headless probe of land as clay (scripts/land_clay.gd, docs/scenic/modeless.md
## "Land as clay") on the real cozy worlds scene, driven by synthesized mouse
## input through hand_reach. Checks the tap, drag and hold classification; a
## slow drag's groove; a fast rub's smoothing; the pinch raising and sinking
## and staying; the Shift palm and Shift pinch; one undo step each; that the
## land spring no longer fires from the land; and CPU frame gaps while dragging.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_land_clay.gd -- --modeless
## Frame gaps are CPU main-loop intervals under the dummy renderer: they show
## the cost of the work, not of drawing it.
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var spring: Node
var hand: Node
var failures := []
var worked: Array = []
var sprung := 0
var gaps: Array[float] = []
var _last := 0

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

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func shift(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tick() -> void:
	await process_frame
	var now := Time.get_ticks_usec()
	gaps.append((now-_last)/1000.0)
	_last = now

func frames(count: int) -> void:
	for i in range(count): await tick()

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

## A spot the hand takes as bare land: not rim, no prop, tree or resident.
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

## Mean |h - level| over the points within `radius` of `center`.
func off_level(center: Vector2, radius: float, level: float) -> float:
	var data := editor.data
	var total := 0.0
	var count := 0
	for i in range(data.points.size()):
		if data.points[i].distance_to(center) >= radius: continue
		total += absf(data.heights[i]-level)
		count += 1
	return total/maxi(count,1)

## The mean ground height within `radius` of `center` (signed: a trench lowers it).
func mean_height(center: Vector2, radius: float) -> float:
	var data := editor.data
	var total := 0.0
	var count := 0
	for i in range(data.points.size()):
		if data.points[i].distance_to(center) >= radius: continue
		total += data.heights[i]
		count += 1
	return total/maxi(count,1)

func stats(values: Array[float]) -> String:
	if values.is_empty(): return "-"
	var total := 0.0
	for v in values: total += v
	return "max %.1f ms, mean %.1f ms over %d frames" % [values.max(),total/values.size(),values.size()]

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("clay probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-clay-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	spring = scene.get("land_spring")
	hand = scene.get("god_hand")
	scene.world_clock.running = false
	check("land clay exists under --modeless",clay != null)
	if clay == null:
		quit(1)
		return
	clay.worked.connect(func(verb: String, kept: bool) -> void: worked.append([verb,kept]))
	var prop: Node3D = clay.get("_prop")
	var parts: Array = prop.find_children("*","MeshInstance3D",true,false) if prop != null else []
	check("the Modeller, the tool in hand from the start, has its stand-in prop",clay.tool_id == "hand" and parts.size() >= 3 and ((parts[-1] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color == Color("e0a07a"),parts.size())
	if spring != null: spring.sprung.connect(func(_k: String, _s: float) -> void: sprung += 1)
	await settled()
	var data := editor.data
	# A bare spot near the middle, with room for a stroke either side.
	var at := Vector2.INF
	for candidate in [Vector2(-2,1),Vector2(-3,-2),Vector2(2,3),Vector2(0,-4),Vector2(-5,4),Vector2(4,-3),Vector2(-6,-5)]:
		var s := screen(candidate)
		if bare(s) and bare(s+Vector2(-160,0)) and bare(s+Vector2(160,0)) and bare(s+Vector2(0,-60)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	var ground := height(at)
	print("spot ",at," on screen ",spot," ground ",snappedf(ground,0.01)," points ",data.points.size()," hand ",hand != null)

	# --- Tap ---
	var base := data.heights.duplicate()
	var undo0: int = data._undo.size()
	button(spot,true)
	await frames(1)
	check("a press on bare land is held as land",reach.holding == "land",reach.holding)
	await frames(3)
	var low := height(at)
	button(spot,false)
	await frames(1)
	check("a quick release is a tap: a poke",clay.poking and clay.state == 0,[clay.poking,clay.state])
	check("the hand pokes (press) during the dimple",hand == null or hand.reach_gesture == "press",hand.reach_gesture if hand != null else "")
	var dip := low
	for i in range(40):
		dip = minf(dip,height(at))
		await frames(1)
	check("the poke dimples the spot",dip < ground-0.03,"%.3f m" % (dip-ground))
	check("and ends as a poke",not worked.is_empty() and worked.back() == ["poke",false],worked.back() if not worked.is_empty() else [])
	await settled()
	check("the dimple rings out to the exact ground",data.heights == base)
	check("a tap adds no undo step",data._undo.size() == undo0)
	# A press nudged under MOVE_PIXELS and let go before the hold is still a tap.
	button(spot,true)
	await frames(2)
	motion(spot+Vector2(4,0),Vector2(4,0))
	await frames(8)
	button(spot+Vector2(4,0),false)
	await frames(1)
	check("moved 4 px, let go at 0.17 s: still a tap",worked.back()[0] == "poke",worked.back())
	await settled()
	check("and changes nothing",data.heights == base and data._undo.size() == undo0)

	# --- Hold still, let go: the pinch closes, nothing kept ---
	button(spot,true)
	await frames(int(ceil(clay.HOLD_SECONDS*60.0))-4)
	check("before HOLD_SECONDS the press is undecided",clay.state == 1,clay.state)
	await frames(8)
	check("held still past HOLD_SECONDS: a pinch",clay.verb == "pinch" and clay.state == 3,[clay.verb,clay.state])
	check("the hand closes into a pinch",hand == null or (hand.reach_gesture == "pinch" and String(hand.player.current_animation) == "PinchIn"),[hand.reach_gesture,hand.player.current_animation] if hand != null else "")
	button(spot,false)
	await settled()
	check("a pinch let go without moving keeps nothing",worked.back() == ["pinch",false] and data.heights == base and data._undo.size() == undo0,worked.back())

	# --- Slow drag: a groove ---
	var path: Array[Vector2] = []
	gaps.clear()
	_last = Time.get_ticks_usec()
	button(spot+Vector2(-150,0),true)
	await tick()
	var p := spot+Vector2(-150,0)
	var decided_at := -1
	for i in range(60):
		p += Vector2(5,0)
		motion(p,Vector2(5,0))
		await tick()
		if decided_at < 0 and clay.state == 2: decided_at = i+1
		var q: Variant = plate(p)
		if q != null and i > 4 and i < 55: path.append(q)
	var drag_gaps := gaps.duplicate()
	check("a move past MOVE_PIXELS decides the drag (thumb)",decided_at > 0 and decided_at <= 2 and clay.verb == "thumb",[decided_at,clay.verb])
	check("a slow drag (300 px/s) reads as a groove, not a rub",clay.rub < 0.05,"speed %.0f px/s, rub %.2f" % [clay.speed,clay.rub])
	check("the hand presses along the stroke",hand == null or hand.reach_gesture == "press",hand.reach_gesture if hand != null else "")
	check("the land spring does not start from the land",spring == null or spring.state == 0)
	button(p,false)
	await settled()
	var depths: Array[float] = []
	for q in path: depths.append(float(editor.data.sample(q,base))-height(q))
	var shallowest: float = depths.min() if not depths.is_empty() else 0.0
	var deepest: float = depths.max() if not depths.is_empty() else 0.0
	print("GROOVE ",JSON.stringify({"samples":depths.size(),"shallowest":snappedf(shallowest,0.01),"deepest":snappedf(deepest,0.01),"refreshes":clay.refreshes,"dabs":clay.dabs,"frames":stats(drag_gaps)}))
	check("the slow drag digs a groove all along its path",depths.size() > 20 and shallowest > 0.15 and deepest < clay.GROOVE_DEPTH+0.08,"%.2f..%.2f m" % [shallowest,deepest])
	var side: Vector2 = path[path.size()/2]+Vector2(0,clay.GROOVE_HALF_WIDTH*1.3)
	var side2: Vector2 = path[path.size()/2]-Vector2(0,clay.GROOVE_HALF_WIDTH*1.3)
	var side_rise := maxf(height(side)-float(editor.data.sample(side,base)),height(side2)-float(editor.data.sample(side2,base)))
	check("its banks are not dug (a small lip at most)",side_rise > -0.03 and side_rise < 0.1,"%.3f m" % side_rise)
	check("one undo step for the stroke",worked.back() == ["groove",true] and data._undo.size() == undo0+1,[worked.back(),data._undo.size()-undo0])
	check("frames stay interactive while dragging (CPU)",drag_gaps.max() < 25.0,stats(drag_gaps))
	editor.undo()
	await settled()
	check("one undo restores the ground exactly (groove)",data.heights == base and data._undo.size() == undo0)

	# Roughen the ground round the spot (the probe's own set-up, not an undo step).
	var noise := RandomNumberGenerator.new()
	noise.seed = 7
	var rough := data.heights.duplicate()
	for i in range(data.points.size()):
		if data.points[i].distance_to(at) < 3.5: rough[i] += noise.randf_range(-0.12,0.12)
	data.heights = rough
	editor.force_refresh()
	await settled()
	base = data.heights.duplicate()

	# --- Fast rub: smooths ---
	var before := roughness(at,1.0)
	var mean_before := mean_height(at,1.6)
	button(spot+Vector2(-60,0),true)
	await tick()
	p = spot+Vector2(-60,0)
	var way := 1.0
	gaps.clear()
	_last = Time.get_ticks_usec()
	for i in range(72):
		if (p.x-spot.x)*way > 60.0: way = -way
		p += Vector2(30*way,0)
		motion(p,Vector2(30*way,0))
		await tick()
	var rub_gaps := gaps.duplicate()
	var rub_share: float = clay.rub
	var rub_speed: float = clay.speed
	button(p,false)
	await settled()
	var after := roughness(at,1.0)
	print("RUB ",JSON.stringify({"speed":snappedf(rub_speed,1.0),"rub":snappedf(rub_share,0.01),"roughness_before":snappedf(before,0.0001),"roughness_after":snappedf(after,0.0001),"frames":stats(rub_gaps)}))
	check("a fast back-and-forth (1800 px/s) reads as a rub",rub_share > 0.95,"%.2f at %.0f px/s" % [rub_share,rub_speed])
	check("the rub smooths the land under it",after < before*0.6,"%.4f -> %.4f" % [before,after])
	# The world is random each run, so compare the mean ground under the rub with
	# itself: smoothing keeps it about level, a groove would take ~0.3 m off it.
	var mean_after := mean_height(at,1.6)
	check("without digging a trench",mean_after-mean_before > -0.08,"mean h %.3f -> %.3f" % [mean_before,mean_after])
	check("one undo step for the rub",data._undo.size() == undo0+1)
	check("frames stay interactive while rubbing (CPU)",rub_gaps.max() < 25.0,stats(rub_gaps))
	editor.undo()
	await settled()
	check("one undo restores it exactly (rub)",data.heights == base and data._undo.size() == undo0)

	# --- Shift-drag: the palm levels to the height under the press ---
	# The level is the ground under the press; measured round the press.
	var palm_at: Vector2 = plate(spot+Vector2(-30,0))
	var level := float(editor.data.sample(palm_at,base))
	var palm_mid: Vector2 = plate(spot)
	var palm_centre := (palm_at+palm_mid)*0.5
	var off_before := off_level(palm_centre,1.2,level)
	shift(true)
	button(spot+Vector2(-30,0),true)
	await tick()
	p = spot+Vector2(-30,0)
	for i in range(24):
		p += Vector2(2.5,0)
		motion(p,Vector2(2.5,0))
		await tick()
	var palm_verb: String = clay.verb
	button(p,false)
	shift(false)
	await settled()
	var off_after := off_level(palm_centre,1.2,level)
	print("PALM ",JSON.stringify({"level":snappedf(level,0.01),"off_before":snappedf(off_before,0.001),"off_after":snappedf(off_after,0.001)}))
	check("Shift-drag is the palm",palm_verb == "palm",palm_verb)
	check("the palm levels the land toward the height under the press",off_after < off_before*0.5,"%.3f -> %.3f m" % [off_before,off_after])
	check("one undo step for the palm",worked.back() == ["palm",true] and data._undo.size() == undo0+1)
	editor.undo()
	await settled()
	check("one undo restores it exactly (palm)",data.heights == base)

	# --- Pinch: hold, then up raises, following the pointer, and stays ---
	var raised := await pinch(spot,-60.0,false)
	var raise_at_release: float = raised.release-raised.ground
	check("hold then drag up raises the spot",raise_at_release > 1.0,"%.2f m" % raise_at_release)
	check("the summit follows the pointer (within 12 px)",raised.follow_px < 12.0,"%.1f px" % raised.follow_px)
	check("it stays where it was let go",absf(raised.after-raised.release) < 0.01,"%.3f m later" % (raised.after-raised.release))
	check("the land spring stays out of it",sprung == 0 and (spring == null or spring.state == 0))
	check("one undo step for the pinch",raised.undo == 1)
	check("frames stay interactive while pinching (CPU)",raised.gaps.max() < 25.0,stats(raised.gaps))
	var plain_area: int = raised.moved
	editor.undo()
	await settled()
	check("one undo restores it exactly (pinch up)",data.heights == base)

	var sunk := await pinch(spot,30.0,false)
	check("hold then drag down sinks the spot",sunk.release-sunk.ground < -0.4,"%.2f m" % (sunk.release-sunk.ground))
	check("and it stays",absf(sunk.after-sunk.release) < 0.01)
	check("one undo step for the sink",sunk.undo == 1)
	editor.undo()
	await settled()

	# --- Shift pinch: smaller and gentler ---
	var fine := await pinch(spot,-60.0,true)
	var fine_lift: float = fine.release-fine.ground
	check("Shift pinch is the fine pinch",fine.verb == "fine_pinch",fine.verb)
	check("it raises less than a plain pinch for the same pull",fine_lift > 0.1 and fine_lift < raise_at_release*0.6,"%.2f vs %.2f m" % [fine_lift,raise_at_release])
	check("over less ground",fine.moved < plain_area*0.6,"%d vs %d points" % [fine.moved,plain_area])
	check("one undo step for the fine pinch",fine.undo == 1)
	editor.undo()
	await settled()
	check("and undo restores it exactly",data.heights == base and data._undo.size() == undo0)
	check("the land spring never sprang",sprung == 0 and (spring == null or spring.state == 0),sprung)
	print("FAILURES: ",failures)
	scene.queue_free()
	await frames(3)
	quit(1 if not failures.is_empty() else 0)

## Press at `spot`, hold still past HOLD_SECONDS, drag `pixels` vertically
## (negative is up) over 20 frames, let go, and wait.
func pinch(spot: Vector2, pixels: float, fine: bool) -> Dictionary:
	var data := editor.data
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()
	var at: Vector2 = plate(spot)
	var ground := height(at)
	if fine: shift(true)
	button(spot,true)
	await frames(int(ceil(clay.HOLD_SECONDS*60.0))+3)
	var verb: String = clay.verb
	if fine: shift(false)
	var p := spot
	gaps.clear()
	_last = Time.get_ticks_usec()
	for i in range(20):
		p += Vector2(0,pixels/20.0)
		motion(p,Vector2(0,pixels/20.0))
		await tick()
	var pinch_gaps := gaps.duplicate()
	await frames(2)
	var summit: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(Vector3(at.x,height(at),at.y)))
	var follow := absf(summit.y-p.y) if not fine else 0.0
	button(p,false)
	await frames(1)
	var release := height(at)
	await settled()
	await frames(30)
	var after := height(at)
	var moved := 0
	for i in range(base.size()):
		if absf(data.heights[i]-base[i]) > 0.01: moved += 1
	print(("FINE PINCH " if fine else "PINCH ")+JSON.stringify({"pixels":pixels,"ground":snappedf(ground,0.01),"release":snappedf(release,0.01),"after":snappedf(after,0.01),"lift":snappedf(clay.lift,0.01),"follow_px":snappedf(follow,0.1),"moved_points":moved,"refreshes":clay.refreshes,"frames":stats(pinch_gaps)}))
	return {"verb":verb,"ground":ground,"release":release,"after":after,"follow_px":follow,"moved":moved,"undo":data._undo.size()-undo0,"gaps":pinch_gaps}
