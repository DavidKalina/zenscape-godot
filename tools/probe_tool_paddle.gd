extends SceneTree
## Headless probe of the Paddle (scripts/clay_tools/paddle.gd,
## docs/design/tools/PLAN.md) on the real cozy worlds scene, driven by
## synthesized mouse and key input through hand_reach, as
## tools/probe_land_clay.gd drives the Hand. Checks: pressing the paddle's
## pocket in the tool roll takes it (the clay works with it, the hand grips
## it over the land, its stand-in prop is built); the tap pats the land flat
## without raising or sinking it; the drag sweeps a trough with a ridge on
## either bank; the hold-then-drag raises a wide round-shouldered swell that
## follows the pointer, and sinks one; each is one undo step that one undo
## takes back exactly; Shift narrows the blade and the size pips widen it;
## Esc gives back the Hand, whose thumb digs a groove again; taking a
## material puts the paddle back.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_paddle.gd -- --modeless --no-title
## Nothing here is seen: the dummy renderer draws nothing, so the grip pose
## and the prop are checked as data only.
const Paddle = preload("res://scripts/clay_tools/paddle.gd")
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

## A drag of `pixels` px along screen x from `start`, 5 px a frame.
func sweep(start: Vector2, pixels: float, fine := false) -> Dictionary:
	var data := editor.data
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()
	if fine: shift(true)
	button(start,true)
	await frames(1)
	var p := start
	var path: Array[Vector2] = []
	var verb := ""
	for i in range(int(pixels/5.0)):
		p += Vector2(5,0)
		motion(p,Vector2(5,0))
		await frames(1)
		if verb.is_empty() and clay.state == 2: verb = clay.verb
		var q: Variant = plate(p)
		if q != null and i > 6 and i < int(pixels/5.0)-6: path.append(q)
	if fine: shift(false)
	button(p,false)
	await settled()
	var mid: Vector2 = path[path.size()/2]
	var along: Vector2 = (path[-1]-path[0]).normalized()
	var across := Vector2(-along.y,along.x)
	var depths: Array[float] = []
	for q in path: depths.append(float(data.sample(q,base))-height(q))
	var ridge := INF
	var ridge_at: float = Paddle.SWEEP_HALF_WIDTH*clay.size_scale*(Paddle.NARROW if fine else 1.0)*1.6
	for side in [1.0,-1.0]:
		var r: Vector2 = mid+across*ridge_at*side
		ridge = minf(ridge,height(r)-float(data.sample(r,base)))
	var count := moved(base,0.03)
	var result := {"verb":verb,"undo":data._undo.size()-undo0,"shallowest":depths.min(),"deepest":depths.max(),"ridge":ridge,"down":count.down,"up":count.up,"base":base,"undo0":undo0}
	print(("NARROW SWEEP " if fine else "SWEEP ")+JSON.stringify({"size":clay.size_scale,"verb":verb,"shallowest":snappedf(depths.min(),0.01),"deepest":snappedf(depths.max(),0.01),"ridge_min_side":snappedf(ridge,0.01),"lowered":count.down,"raised":count.up,"dabs":clay.dabs}))
	return result

## Press at `spot`, hold still past HOLD_SECONDS, drag `pixels` vertically
## (negative is up) over 20 frames, let go, and wait.
func swell(spot: Vector2, pixels: float, fine := false) -> Dictionary:
	var data := editor.data
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()
	var at: Vector2 = plate(spot)
	if fine: shift(true)
	button(spot,true)
	await frames(int(ceil(clay.HOLD_SECONDS*60.0))+3)
	var verb: String = clay.verb
	var gesture: String = hand.reach_gesture if hand != null else ""
	if fine: shift(false)
	var p := spot
	for i in range(20):
		p += Vector2(0,pixels/20.0)
		motion(p,Vector2(0,pixels/20.0))
		await frames(1)
	await frames(2)
	var crown := height(at)-float(data.sample(at,base))
	var summit: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(Vector3(at.x,height(at),at.y)))
	var follow := absf(summit.y-p.y)
	button(p,false)
	await frames(1)
	var release := height(at)
	await settled()
	await frames(30)
	var after := height(at)
	# The shoulder: the mean rise on a ring SHOULDER of the radius out, as a
	# share of the crown's.
	var radius: float = Paddle.SWELL_RADIUS*clay.size_scale*(Paddle.NARROW if fine else 1.0)
	var ring := 0.0
	for k in range(8):
		var r := at+Vector2.from_angle(TAU*k/8.0)*radius*0.3
		ring += height(r)-float(data.sample(r,base))
	ring /= 8.0
	var count := moved(base)
	print(("NARROW SWELL " if fine else "SWELL ")+JSON.stringify({"pixels":pixels,"verb":verb,"crown":snappedf(crown,0.01),"shoulder_share":snappedf(ring/crown if absf(crown) > 0.001 else 0.0,0.01),"follow_px":snappedf(follow,0.1),"moved_points":count.moved,"release":snappedf(release,0.01),"after":snappedf(after,0.01)}))
	return {"verb":verb,"gesture":gesture,"crown":crown,"ring":ring,"follow":follow,"moved":count.moved,"release":release,"after":after,"undo":data._undo.size()-undo0,"base":base,"undo0":undo0}

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
	create_timer(280).timeout.connect(func() -> void: push_error("paddle probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-paddle-probe-%d/places.json" % Time.get_ticks_usec()
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
	print("spot ",at," on screen ",spot," ground ",snappedf(height(at),0.01)," points ",data.points.size()," hand ",hand != null)

	# --- Taking the paddle from the roll ---
	check("the paddle is built (off UNBUILT), the unbuilt are not",roll.discovered("paddle") and roll.UNBUILT.all(func(t: String) -> bool: return not roll.discovered(t)))
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	check("the tool roll shows",roll.shown > 0.99,roll.shown)
	var pocket: Vector2 = roll._cell(roll.TOOLS.find("paddle")).get_center()
	check("the paddle's pocket hit-tests to it",roll.tool_at(pocket) == "paddle",roll.tool_at(pocket))
	await click(pocket)
	check("pressing the pocket takes the paddle",roll.tool == "paddle" and clay.tool_id == "paddle",[roll.tool,clay.tool_id])
	var prop: Node3D = clay.get("_prop")
	var parts: Array = prop.find_children("*","MeshInstance3D",true,false) if prop != null else []
	check("its stand-in prop is built, faceted, in the icon's tint",parts.size() >= 3 and (parts[-1] as MeshInstance3D).mesh is ArrayMesh and ((parts[-1] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color == Color("c49a5e"),parts.size())
	reach.pointer_override = spot
	motion(spot,Vector2.ZERO,false)
	await frames(20)
	check("the hand grips the paddle over the land",hand == null or hand.reach_gesture == "grip",hand.reach_gesture if hand != null else "")
	check("the prop rides in the shown hand",hand == null or prop.visible == (hand.visible and float(hand.opacity) > 0.3),[prop.visible,hand.visible if hand != null else null])
	reach.pointer_override = null
	var undo0: int = data._undo.size()

	# --- Tap: a pat flattens ---
	await roughen(at,4.0,11)
	var base := data.heights.duplicate()
	var rough_before := roughness(at,2.0)
	var mean_before := mean_height(at,2.5)
	await click(spot)
	await settled()
	var rough_after := roughness(at,2.0)
	var mean_after := mean_height(at,2.5)
	var pat_moved: int = moved(base,0.005).moved
	print("PAT ",JSON.stringify({"roughness_before":snappedf(rough_before,0.0001),"roughness_after":snappedf(rough_after,0.0001),"mean_before":snappedf(mean_before,0.001),"mean_after":snappedf(mean_after,0.001),"moved_points":pat_moved}))
	check("a tap is the pat",not worked.is_empty() and worked.back() == ["pat",true],worked.back() if not worked.is_empty() else [])
	check("the pat flattens the land under it",rough_after < rough_before*0.6,"%.4f -> %.4f" % [rough_before,rough_after])
	check("without raising or sinking it",absf(mean_after-mean_before) < 0.03,"mean h %.3f -> %.3f" % [mean_before,mean_after])
	check("one undo step for the pat",data._undo.size() == undo0+1)
	await undo_exact(base,undo0,"pat")
	shift(true)
	await click(spot)
	shift(false)
	await settled()
	var narrow_pat: int = moved(base,0.005).moved
	check("Shift pats with a narrower blade",worked.back() == ["narrow_pat",true] and narrow_pat < pat_moved*0.5,"%d vs %d points" % [narrow_pat,pat_moved])
	await undo_exact(base,undo0,"narrow pat")

	# --- Drag: the sweep ---
	var plain := await sweep(spot+Vector2(-150,0),300.0)
	check("a drag is the sweep",plain.verb == "sweep" and worked.back() == ["sweep",true],[plain.verb,worked.back()])
	check("it leaves a soft trough all along the path",plain.shallowest > 0.15 and plain.deepest < Paddle.SWEEP_DEPTH+0.08,"%.2f..%.2f m" % [plain.shallowest,plain.deepest])
	check("with a ridge on either bank",plain.ridge > 0.08 and plain.ridge < Paddle.SWEEP_RIDGE+0.05,"lower bank %.2f m" % plain.ridge)
	check("one undo step for the sweep",plain.undo == 1)
	await undo_exact(plain.base,plain.undo0,"sweep")
	var fine := await sweep(spot+Vector2(-150,0),300.0,true)
	check("Shift-drag is the narrower sweep",fine.verb == "narrow_sweep",fine.verb)
	check("it cuts a narrower trough",fine.down < plain.down*0.7 and fine.shallowest > 0.1,"%d vs %d points lowered" % [fine.down,plain.down])
	await undo_exact(fine.base,fine.undo0,"narrow sweep")

	# --- The size pips widen it ---
	await key(KEY_3)
	check("the size key 3 sets 1.5x",is_equal_approx(clay.size_scale,1.5) and roll.size_level == 2,clay.size_scale)
	var wide := await sweep(spot+Vector2(-150,0),300.0)
	check("the widest pip sweeps a wider trough",wide.down > plain.down*1.3,"%d vs %d points lowered" % [wide.down,plain.down])
	await undo_exact(wide.base,wide.undo0,"wide sweep")
	await key(KEY_2)
	check("and 2 sets it back",is_equal_approx(clay.size_scale,1.0))

	# --- Hold then drag: the swell ---
	var up := await swell(spot,-60.0)
	check("hold then drag up is the swell, the hand gripping",up.verb == "swell" and (hand == null or up.gesture == "grip"),[up.verb,up.gesture])
	check("it raises the spot",up.crown > 1.0,"%.2f m" % up.crown)
	check("round-shouldered: 0.3 of the way out it stands at least 0.7 of the crown",up.ring > up.crown*0.7,"%.2f of %.2f m" % [up.ring,up.crown])
	check("wide: several times the pinch's spread",up.moved > 250,"%d points" % up.moved)
	check("the crown follows the pointer (within 12 px)",up.follow < 12.0,"%.1f px" % up.follow)
	check("it stays where it was let go",absf(up.after-up.release) < 0.01)
	check("one undo step for the swell",up.undo == 1 and worked.back() == ["swell",true],worked.back())
	await undo_exact(up.base,up.undo0,"swell")
	var down := await swell(spot,30.0)
	check("hold then drag down sinks a hollow",down.crown < -0.4,"%.2f m" % down.crown)
	await undo_exact(down.base,down.undo0,"hollow")
	var narrow := await swell(spot,-60.0,true)
	check("Shift holds the narrower swell over less ground",narrow.verb == "narrow_swell" and narrow.moved < up.moved*0.5,"%d vs %d points" % [narrow.moved,up.moved])
	await undo_exact(narrow.base,narrow.undo0,"narrow swell")

	# --- Esc gives back the Hand ---
	await key(KEY_ESCAPE)
	check("Esc puts the paddle back: the Hand again",roll.tool == "hand" and clay.tool_id == "hand",[roll.tool,clay.tool_id])
	check("its prop is gone",clay.get("_prop") == null or not is_instance_valid(clay.get("_prop")))
	reach.pointer_override = spot
	motion(spot,Vector2.ZERO,false)
	await frames(20)
	check("the hand hovers ready to pinch again",hand == null or hand.reach_gesture == "pinch",hand.reach_gesture if hand != null else "")
	reach.pointer_override = null
	var thumb := await sweep(spot+Vector2(-150,0),300.0)
	check("a drag is the Hand's thumb again, digging a groove",thumb.verb == "thumb" and worked.back() == ["groove",true] and thumb.shallowest > 0.15,[thumb.verb,worked.back()])
	await undo_exact(thumb.base,thumb.undo0,"groove")

	# --- One thing in hand: a material puts the paddle back ---
	await click(pocket)
	check("the paddle again",clay.tool_id == "paddle")
	for i in range(60):
		if materials.tray.shown > 0.99: break
		await process_frame
	await click(materials.tray.specimen_centre("stone"))
	check("taking a stone puts the paddle back",materials.held == "stone" and roll.tool == "hand" and clay.tool_id == "hand",[materials.held,roll.tool,clay.tool_id])
	await key(KEY_ESCAPE)
	check("Esc puts the stone down",materials.held.is_empty())
	print("FAILURES: ",failures)
	scene.queue_free()
	await frames(3)
	quit(1 if not failures.is_empty() else 0)
