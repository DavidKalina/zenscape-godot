extends SceneTree
## Headless probe of the Hammer (scripts/clay_tools/hammer.gd,
## docs/design/tools/PLAN.md) on the real cozy worlds scene, driven by
## synthesized mouse and key input through hand_reach, as
## tools/probe_tool_paddle.gd drives the Paddle. Checks: pressing the
## hammer's pocket takes it (the clay works with it, its stand-in prop is
## built in the icon's tint); a tap on grass only dents it; the Hand's pinch
## raises a rock horn, and a tap on it lowers the peak and spills the volume
## downhill as scree (the heights' sum kept, the true volume roughly), no
## scree steeper than the repose angle, the scree painted; Shift is a
## smaller blow and the widest pip a wider one; a drag strikes along its
## path and a hold strikes at release; each is one undo step that one undo
## takes back exactly (heights and tint); Esc gives back the Hand.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_hammer.gd -- --modeless --no-title
## Nothing here is seen: the dummy renderer draws nothing, so the swing, the
## prop and the paint are checked as data only.
const Hammer = preload("res://scripts/clay_tools/hammer.gd")
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
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or clay.state != 0 or clay.poking or clay.tool.busy()
		quiet = 0 if busy else quiet+1

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func plate(at: Vector2) -> Variant:
	var hit: Variant = editor.pick(at)
	return Vector2(hit.x,hit.z) if hit != null else null

## True when a press at `at` (screen) would reach the land and nothing else:
## not the rim's band, the void, a prop, tree or cloud, nor any of the HUD
## (the tray, the tool roll and its foot, the almanac, an open page).
func bare(at: Vector2) -> bool:
	return reach.reach_at(at) == "" and reach._land(at) != null and not reach._prop_at(at) \
		and not materials.tray_under(at) and reach._cloud_at(at) == null and reach._tree_under(at) < 0

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


## The ground's true volume over a square `half` metres round `at`: the
## heights sampled on a 0.2 m grid (the land's points taken as they lie, not
## as equal areas).
func volume(at: Vector2, half: float, values: PackedFloat32Array) -> float:
	var total := 0.0
	var step := 0.2
	var x := at.x-half
	while x < at.x+half:
		var z := at.y-half
		while z < at.y+half:
			var h: Variant = editor.data.sample(Vector2(x,z),values)
			if h != null: total += float(h)*step*step
			z += step
		x += step
	return total

## A tap at `at` (screen) with the hammer; waits out the swing. Returns what
## the blow did against the land before it.
func blow(at: Vector2, fine := false) -> Dictionary:
	var data := editor.data
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()
	var tint := data.tint.duplicate()
	if fine: shift(true)
	button(at,true)
	await frames(2)
	button(at,false)
	if fine: shift(false)
	await frames(1)
	var early := data.heights == base
	await settled()
	var count := moved(base,0.01)
	var raised := 0
	var dent := 0.0
	var sum := 0.0
	for i in range(base.size()):
		var d := data.heights[i]-base[i]
		sum += d
		dent = minf(dent,d)
		if d > 0.03: raised += 1
	return {"undo":data._undo.size()-undo0,"undo0":undo0,"base":base,"tint":tint,"moved":count.moved,"down":count.down,"up":count.up,"raised":raised,"dent":dent,"sum":sum,"last":(clay.tool.last as Dictionary).duplicate(),"worked":worked.back() if not worked.is_empty() else [],"early":early}

## One undo takes the land back to `base` and `tint` exactly.
func undo_all(result: Dictionary, what: String) -> void:
	editor.undo()
	await settled()
	check("one undo restores the ground and its paint exactly (%s)" % what,editor.data.heights == result.base and editor.data.tint == result.tint and editor.data._undo.size() == result.undo0)

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("hammer probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-hammer-probe-%d/places.json" % Time.get_ticks_usec()
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
		if bare(s) and bare(s+Vector2(-160,0)) and bare(s+Vector2(160,0)) and bare(s+Vector2(0,-160)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	print("spot ",at," on screen ",spot," ground ",snappedf(height(at),0.01)," points ",data.points.size())

	# --- Taking the hammer from the roll ---
	check("the hammer is built (off UNBUILT)",roll.discovered("hammer"))
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	var pocket: Vector2 = roll._cell(roll.TOOLS.find("hammer")).get_center()
	check("the hammer's pocket hit-tests to it",roll.tool_at(pocket) == "hammer",roll.tool_at(pocket))
	await click(pocket)
	check("pressing the pocket takes the hammer",roll.tool == "hammer" and clay.tool_id == "hammer",[roll.tool,clay.tool_id])
	var prop: Node3D = clay.get("_prop")
	var parts: Array = prop.find_children("*","MeshInstance3D",true,false) if prop != null else []
	check("its stand-in prop is built, faceted, the head in the icon's tint",parts.size() >= 5 and (parts[-1] as MeshInstance3D).mesh is ArrayMesh and ((parts[-1] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color == Color("7a6a5a"),parts.size())
	check("it leans -30 degrees",is_equal_approx(clay.tool.prop_tilt(),-30.0))
	reach.pointer_override = spot
	motion(spot,Vector2.ZERO,false)
	await frames(20)
	check("the hand grips the hammer over the land",hand == null or hand.reach_gesture == "grip",hand.reach_gesture if hand != null else "")
	reach.pointer_override = null

	# --- A tap on grass: a dull knock ---
	var knock := await blow(spot)
	print("KNOCK ",JSON.stringify({"worked":knock.worked,"moved":knock.moved,"raised":knock.raised,"deepest":snappedf(knock.dent,0.001)}))
	check("a tap on grass is a knock",knock.worked == ["knock",true],knock.worked)
	check("it only dents: nothing raised, no deeper than %.2f m" % Hammer.KNOCK_DEPTH,knock.up == 0 and knock.raised == 0 and knock.dent < -0.02 and knock.dent >= -Hammer.KNOCK_DEPTH-0.001,"%.3f m, %d up" % [knock.dent,knock.up])
	check("one undo step for the knock",knock.undo == 1)
	await undo_all(knock,"knock")
	await key(KEY_1)
	var small := await blow(spot)
	check("the smallest pip knocks a smaller dent",small.worked == ["knock",true] and small.moved < knock.moved,"%d vs %d" % [small.moved,knock.moved])
	await undo_all(small,"small knock")
	await key(KEY_2)
	check("and 2 sets it back",is_equal_approx(clay.size_scale,1.0))

	# --- Esc gives back the Hand; its pinch raises a rock horn ---
	await key(KEY_ESCAPE)
	check("Esc puts the hammer back: the Hand again",roll.tool == "hand" and clay.tool_id == "hand",[roll.tool,clay.tool_id])
	check("its prop gives way to the Modeller's",not is_instance_valid(prop) and clay.get("_prop") is Node3D and (clay.get("_prop") as Node3D).find_children("*","MeshInstance3D",true,false).size() >= 3)
	var pinch_undo: int = data._undo.size()
	button(spot,true)
	await frames(int(ceil(clay.HOLD_SECONDS*60.0))+3)
	var p := spot
	for i in range(20):
		p += Vector2(0,-6)
		motion(p,Vector2(0,-6))
		await frames(1)
	button(p,false)
	await settled()
	var peak := -1
	for i in range(data.points.size()):
		if data.points[i].distance_to(at) < 3.0 and (peak < 0 or data.heights[i] > data.heights[peak]): peak = i
	var summit: Vector2 = data.points[peak]
	var top := data.heights[peak]
	var cell := data.meadow_cell(summit)
	print("PEAK ",JSON.stringify({"worked":worked.back(),"summit":summit,"height":snappedf(top,0.01),"rise":snappedf(top-height(at+Vector2(12,0)) if height(at+Vector2(12,0)) else 0.0,0.01),"tint_weight":snappedf(NativeTerrainTint.weight_at(data.tint,cell),0.01)}))
	check("the Hand's pinch raised a horn",worked.back() == ["pinch",true] and data._undo.size() == pinch_undo+1)
	await click(pocket)
	check("the hammer again",clay.tool_id == "hammer")
	# Aim just under the tip on screen: a ray at the tip's own vertex can
	# graze past it to the ground behind.
	var tall := screen(summit)+Vector2(0,8)
	var hit: Variant = plate(tall)
	check("the pointer under the tip picks the horn",hit != null and (hit as Vector2).distance_to(summit) < 1.2,hit)
	var hit_cell: int = data.meadow_cell(hit) if hit != null else -1
	print("TALL pick ",hit," h ",height(hit) if hit != null else null," slope ",preload("res://scripts/native_landscape_presets.gd")._slope(data,hit) if hit != null else null," tint ",NativeTerrainTint.weight_at(data.tint,hit_cell) if hit_cell >= 0 else -1.0," colour ",NativeTerrainTint.color_at(data.tint,hit_cell) if hit_cell >= 0 else Color())

	# --- A tap on the rock horn: a crack ---
	var crack := await blow(tall)
	var drop := top-data.heights[peak]
	var vol_before := volume(summit,12.0,crack.base)
	var vol_after := volume(summit,12.0,data.heights)
	var lowered := 0.0
	for i in range(crack.base.size()): lowered += maxf(crack.base[i]-data.heights[i],0.0)
	# Scree: every raised point stands no steeper than repose over its lower
	# neighbours (inside the plate's fade), and is painted.
	var steepest := 0.0
	var painted := 0
	var thick := 0
	var tones: Array = Hammer.SCREE.map(func(hex: String) -> Color: return Color(hex).srgb_to_linear())
	var lowest_scree := INF
	var farthest := 0.0
	for i in range(crack.base.size()):
		var d: float = data.heights[i]-crack.base[i]
		if d <= 0.03: continue
		lowest_scree = minf(lowest_scree,data.heights[i])
		farthest = maxf(farthest,data.points[i].distance_to(summit))
		for j in data._neighbors[i]:
			if clay.fade(j) < 1.0: continue
			steepest = maxf(steepest,(data.heights[i]-data.heights[j])/data.points[i].distance_to(data.points[j]))
		if d < 0.12: continue
		thick += 1
		var c := data.meadow_cell(data.points[i])
		var colour := NativeTerrainTint.color_at(data.tint,c)
		var near_tone := false
		for tone: Color in tones: near_tone = near_tone or Vector3(colour.r-tone.r,colour.g-tone.g,colour.b-tone.b).length() < 0.06
		if NativeTerrainTint.weight_at(data.tint,c) >= 0.5 and near_tone: painted += 1
	print("CRACK ",JSON.stringify({"worked":crack.worked,"top_cut":snappedf(crack.last.get("top_cut",0.0),0.01),"summit_drop":snappedf(drop,0.01),"cut_points":crack.last.get("cut",0),"scree_points":crack.raised,"lowered_sum":snappedf(lowered,0.01),"sum_moved":snappedf(crack.sum,0.0001),"volume_before":snappedf(vol_before,0.01),"volume_after":snappedf(vol_after,0.01),"steepest_scree":snappedf(steepest,0.001),"scree_painted":"%d/%d" % [painted,thick],"scree_lowest":snappedf(lowest_scree,0.01),"scree_farthest_m":snappedf(farthest,0.1)}))
	check("a tap on the horn is a crack",crack.worked == ["crack",true],crack.worked)
	check("the blow lands after the wind-up, not on the release",crack.early)
	check("it lowers the peak",drop > 0.5,"%.2f m" % drop)
	check("and spills scree downhill",crack.raised > 5 and lowest_scree < top-2.0,"%d points raised, lowest %.2f m" % [crack.raised,lowest_scree])
	check("the heights' sum is kept",absf(crack.sum) < 0.001*maxf(lowered,1.0)+0.001,"%.4f of %.2f" % [crack.sum,lowered])
	var broke: float = lowered*(4.0*clay.PLATE_HALF*clay.PLATE_HALF)/data.points.size()
	check("the true volume roughly (within 15% of what broke off)",absf(vol_after-vol_before) < 0.15*broke+0.05,"%.3f m3 changed of %.2f m3 broken" % [vol_after-vol_before,broke])
	check("no scree steeper than repose (%.2f)" % Hammer.REPOSE,steepest <= Hammer.REPOSE+0.03,"%.3f" % steepest)
	check("the scree is painted broken rock",thick > 0 and painted >= thick*0.8,"%d of %d" % [painted,thick])
	check("one undo step for the crack",crack.undo == 1)
	await undo_all(crack,"crack")

	# --- Shift: a smaller crack ---
	var fine := await blow(tall,true)
	print("FINE CRACK ",JSON.stringify({"worked":fine.worked,"cut_points":fine.last.get("cut",0),"top_cut":snappedf(fine.last.get("top_cut",0.0),0.01),"moved":fine.moved}))
	check("Shift is the smaller crack",fine.worked == ["fine_crack",true] and fine.moved < crack.moved and float(fine.last.top_cut) < float(crack.last.top_cut),"%d vs %d points, %.2f vs %.2f m" % [fine.moved,crack.moved,fine.last.top_cut,crack.last.top_cut])
	await undo_all(fine,"fine crack")

	# --- The pips: a wider crack ---
	await key(KEY_3)
	check("the size key 3 sets 1.5x",is_equal_approx(clay.size_scale,1.5))
	var wide := await blow(tall)
	print("WIDE CRACK ",JSON.stringify({"worked":wide.worked,"cut_points":wide.last.get("cut",0),"top_cut":snappedf(wide.last.get("top_cut",0.0),0.01),"moved":wide.moved}))
	check("the widest pip cracks more",float(wide.last.top_cut) > float(crack.last.top_cut) and wide.moved > crack.moved,"%.2f vs %.2f m off the top, %d vs %d moved" % [wide.last.top_cut,crack.last.top_cut,wide.moved,crack.moved])
	await undo_all(wide,"wide crack")
	await key(KEY_2)

	# --- Drag: blows along the path ---
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()
	var tint := data.tint.duplicate()
	# The drag runs 240 px through the horn's tip. Its start must be bare land:
	# 120 px left of the tip can fall in the rim's band or the void, which then
	# take the press (the rim a spin, the void a gust) and the hammer never sees
	# it. So it comes from whichever side is clear.
	var way := Vector2.ZERO
	for side in [Vector2(1,0),Vector2(-1,0),Vector2(0,-1)]:
		if bare(tall-side*120.0):
			way = side
			break
	check("the drag starts on bare land, clear of the rim, the void and the HUD",way != Vector2.ZERO,[reach.reach_at(tall+Vector2(-120,0)),reach.reach_at(tall+Vector2(120,0))])
	var from := tall-way*120.0
	button(from,true)
	await frames(1)
	p = from
	var verb := ""
	for i in range(48):
		p += way*5.0
		motion(p,way*5.0)
		await frames(1)
		if verb.is_empty() and clay.state == 2: verb = clay.verb
	button(p,false)
	await settled()
	var dragged: Dictionary = moved(base)
	print("STRIKES ",JSON.stringify({"verb":verb,"worked":worked.back(),"moved":dragged.moved,"raised":dragged.up}))
	check("a drag strikes along the path, one undo step",verb == "strikes" and worked.back() == ["strikes",true] and data._undo.size() == undo0+1 and dragged.moved > 0,[verb,worked.back()])
	await undo_all({"base":base,"tint":tint,"undo0":undo0},"strikes")

	# --- Hold: a blow at release ---
	undo0 = data._undo.size()
	check("the hold's point is bare land",bare(tall))
	button(tall,true)
	await frames(int(ceil(clay.HOLD_SECONDS*60.0))+10)
	var held_verb: String = clay.verb
	var still := data.heights == base
	button(tall,false)
	await settled()
	print("HOLD ",JSON.stringify({"verb":held_verb,"worked":worked.back(),"moved":moved(base).moved}))
	check("a hold changes nothing while held, then cracks at release",held_verb == "crack" and still and worked.back() == ["crack",true] and data._undo.size() == undo0+1,[held_verb,still,worked.back()])
	await undo_all({"base":base,"tint":tint,"undo0":undo0},"hold")

	# --- Esc gives back the Hand ---
	await key(KEY_ESCAPE)
	check("Esc gives back the Hand",roll.tool == "hand" and clay.tool_id == "hand",[roll.tool,clay.tool_id])
	print("FAILURES: ",failures)
	scene.queue_free()
	await frames(3)
	quit(1 if not failures.is_empty() else 0)
