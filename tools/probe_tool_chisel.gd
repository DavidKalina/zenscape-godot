extends SceneTree
## Headless probe of the Chisel (scripts/clay_tools/chisel.gd,
## docs/design/tools/PLAN.md "The Chisel") on the real cozy worlds scene,
## driven by synthesized mouse and key input through hand_reach, as
## tools/probe_tool_paddle.gd drives the Paddle. Checks: pressing the
## chisel's pocket in the tool roll takes it (the clay works with it, the hand
## grips it, its stand-in prop is built in the icon's steel); the drag leaves
## a level shelf with a face steeper than the Hand's groove banks, painted
## rock while the shelf stays ground; the hold-then-drag raises a flat-topped
## mesa whose top follows the pointer, and a drag down sinks a pit; the tap
## knocks a notch; Shift cuts shallower and the size pips widen the reach;
## each is one undo step that one undo takes back exactly; Esc gives back
## the Hand.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_chisel.gd -- --modeless --no-title
## Nothing here is seen: the dummy renderer draws nothing, so the faces, the
## rock and the prop are checked as data only.
const Chisel = preload("res://scripts/clay_tools/chisel.gd")
const Forms = preload("res://scripts/mountain_forms.gd")
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

## The steepest facet crossed by the line from `a` to `b` on the live ground:
## rise over run sampled every 0.1 m (the land is linear inside a triangle,
## so this reads each facet's own slope along the line).
func steepest(a: Vector2, b: Vector2) -> float:
	var most := 0.0
	var count := int(a.distance_to(b)/0.1)
	var last := height(a)
	for k in range(1,count+1):
		var h := height(a.lerp(b,float(k)/count))
		most = maxf(most,absf(h-last)/(a.distance_to(b)/count))
		last = h
	return most

## Tint cells within `radius` of `at` painted the range's granite (a cell's
## colour within a hair of one of its tones, at weight 0.3 or more), and how
## many of all the cells within it that is.
func rock_cells(at: Vector2, radius: float) -> int:
	var data := editor.data
	var tones: Array = Forms.ROCKS.granite.colors.map(func(hex: String) -> Color: return Color(hex).srgb_to_linear())
	var side := NativeTerrainData.MEADOW_CELLS
	var count := 0
	for z in range(side):
		for x in range(side):
			var p := data.meadow_position(x,z)+Vector2.ONE*NativeTerrainData.MEADOW_STEP*0.5
			if p.distance_to(at) > radius: continue
			if is_rock(data.meadow_cell(p)): count += 1
	return count

func is_rock(cell: int) -> bool:
	var tint := editor.data.tint
	var k := cell*NativeTerrainTint.STRIDE
	if tint[k+3] < 0.3: return false
	var c := Color(tint[k],tint[k+1],tint[k+2])
	for hex: String in Forms.ROCKS.granite.colors:
		var tone := Color(hex).srgb_to_linear()
		if absf(c.r-tone.r)+absf(c.g-tone.g)+absf(c.b-tone.b) < 0.02: return true
	return false

## A drag of `pixels` px along screen x from `start`, 5 px a frame. Measures
## across the path at stations along its middle: the ground level on the
## line (the shelf), the steepest facet across, and the drop from the shelf
## to the ground beyond its downhill edge.
func drag(start: Vector2, pixels: float, fine := false) -> Dictionary:
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
		# The path as the clay laid it (picked on the ground as it stood when
		# the stroke began), not a pick on the cut ground.
		var q: Variant = clay.last_plate if clay.state == 2 else null
		if q != null and i > 10 and i < int(pixels/5.0)-10: path.append(q)
	if fine: shift(false)
	button(p,false)
	await settled()
	var along: Vector2 = (path[-1]-path[0]).normalized()
	var across := Vector2(-along.y,along.x)
	var levels: Array[float] = []
	var steep: Array[float] = []
	var drops: Array[float] = []
	for k in range(5):
		var q: Vector2 = path[int(float(k+1)/6.0*(path.size()-1))]
		# The shelf's middle: near enough the line that every facet sampled
		# has all its corners on the shelf (the points are at most 0.75 m apart).
		for s in [-0.3,0.0,0.3]: levels.append(height(q+across*s))
		steep.append(steepest(q-across*3.5,q+across*3.5))
		# The face's foot: the lowest ground across the bench, either side.
		var h := height(q)
		var drop := 0.0
		for side in [1.0,-1.0]:
			var t: float = Chisel.SHELF_HALF_WIDTH*clay.size_scale
			while t <= (Chisel.SHELF_HALF_WIDTH+Chisel.BENCH)*clay.size_scale:
				drop = maxf(drop,h-height(q+across*t*side))
				t += 0.1
		drops.append(drop)
	var mid: Vector2 = path[path.size()/2]
	# The side the face dropped to, as a unit plate vector.
	var foot: float = Chisel.SHELF_HALF_WIDTH*clay.size_scale+Chisel.BENCH*0.5*clay.size_scale
	var down := across if height(mid+across*foot) < height(mid-across*foot) else -across
	steep.sort()
	drops.sort()
	var count := moved(base,0.03)
	var result := {"verb":verb,"undo":data._undo.size()-undo0,"level_spread":levels.max()-levels.min(),"level":levels[levels.size()/2],
		"press":float(data.sample(plate(start),base)),"steep":steep[steep.size()/2],"drop":drops[drops.size()/2],"rock":rock_cells(mid,4.0),
		"mid_rock":is_rock(data.meadow_cell(mid)),"moved":count.moved,"base":base,"undo0":undo0,"mid":mid,"down":down,"foot":foot}
	print("DRAG "+JSON.stringify({"size":clay.size_scale,"verb":verb,"level_spread":snappedf(result.level_spread,0.001),"level":snappedf(result.level,0.01),
		"press":snappedf(result.press,0.01),"steepest_median":snappedf(result.steep,0.01),"drop_median":snappedf(result.drop,0.01),"rock_cells":result.rock,
		"line_rock":result.mid_rock,"moved":count.moved,"lowered":count.down,"raised":count.up,"dabs":clay.dabs}))
	return result

## Press at `spot`, hold still past HOLD_SECONDS, drag `pixels` vertically
## (negative is up) over 20 frames, let go, and wait.
func hold(spot: Vector2, pixels: float, fine := false) -> Dictionary:
	var data := editor.data
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()
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
	var at: Vector2 = clay.center
	var crown := height(at)-float(data.sample(at,base))
	var summit: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(Vector3(at.x,height(at),at.y)))
	var follow := absf(summit.y-p.y)
	button(p,false)
	await frames(1)
	var release := height(at)
	await settled()
	await frames(30)
	var after := height(at)
	# The top's spread: every point within TOP of the outline's least radius.
	var radius: float = Chisel.MESA_RADIUS*clay.size_scale*(1.0-Chisel.MESA_JAG)
	var top_low := INF
	var top_high := -INF
	for i in range(data.points.size()):
		if data.points[i].distance_to(at) < radius*0.8:
			top_low = minf(top_low,data.heights[i])
			top_high = maxf(top_high,data.heights[i])
	# The walls: the steepest facet on eight rays out from the middle.
	var walls: Array[float] = []
	for k in range(8):
		var dir := Vector2.from_angle(TAU*k/8.0)
		walls.append(steepest(at+dir*radius*0.5,at+dir*Chisel.MESA_RADIUS*clay.size_scale*1.6))
	walls.sort()
	var count := moved(base)
	var result := {"verb":verb,"gesture":gesture,"crown":crown,"spread":top_high-top_low,"follow":follow,"release":release,"after":after,
		"wall":walls[walls.size()/2],"rock":rock_cells(at,Chisel.MESA_RADIUS*clay.size_scale*1.4),"top_rock":is_rock(data.meadow_cell(at)),
		"moved":count.moved,"undo":data._undo.size()-undo0,"base":base,"undo0":undo0}
	print(("SHALLOW HOLD " if fine else "HOLD ")+JSON.stringify({"pixels":pixels,"verb":verb,"crown":snappedf(crown,0.01),"top_spread":snappedf(result.spread,0.001),
		"follow_px":snappedf(follow,0.1),"wall_steepest_median":snappedf(result.wall,0.01),"rock_cells":result.rock,"top_rock":result.top_rock,"moved_points":count.moved,
		"release":snappedf(release,0.01),"after":snappedf(after,0.01)}))
	return result

## A tap at `spot`: the notch.
func notch(spot: Vector2, fine := false) -> Dictionary:
	var data := editor.data
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()
	var at: Vector2 = plate(spot)
	if fine: shift(true)
	await click(spot)
	if fine: shift(false)
	await settled()
	var depth := float(data.sample(at,base))-height(at)
	var count := moved(base,0.01)
	var result := {"depth":depth,"moved":count.moved,"up":count.up,"undo":data._undo.size()-undo0,"base":base,"undo0":undo0,"rock":rock_cells(at,2.0),
		"worked":worked.back() if not worked.is_empty() else []}
	print(("SHALLOW NOTCH " if fine else "NOTCH ")+JSON.stringify({"depth":snappedf(depth,0.01),"moved_points":count.moved,"raised":count.up,"rock_cells":result.rock,"worked":result.worked}))
	return result

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("chisel probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-chisel-probe-%d/places.json" % Time.get_ticks_usec()
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

	# --- The Hand's groove, the bar the chisel's faces must beat ---
	var groove := await drag(spot+Vector2(-150,0),300.0)
	check("the Hand's drag is its groove",groove.verb == "thumb",groove.verb)
	await undo_exact(groove.base,groove.undo0,"groove")

	# --- Taking the chisel from the roll ---
	check("the chisel is built (off UNBUILT)",roll.discovered("chisel") and not "chisel" in roll.UNBUILT)
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	var pocket: Vector2 = roll._cell(roll.TOOLS.find("chisel")).get_center()
	check("the chisel's pocket hit-tests to it",roll.tool_at(pocket) == "chisel",roll.tool_at(pocket))
	await click(pocket)
	check("pressing the pocket takes the chisel",roll.tool == "chisel" and clay.tool_id == "chisel",[roll.tool,clay.tool_id])
	var prop: Node3D = clay.get("_prop")
	var parts: Array = prop.find_children("*","MeshInstance3D",true,false) if prop != null else []
	var steel := parts.filter(func(m: MeshInstance3D) -> bool: return (m.material_override as StandardMaterial3D).albedo_color == Color("6f8aa6"))
	check("its stand-in prop is built, faceted, in the icon's steel",parts.size() >= 5 and steel.size() >= 2 and (steel[0] as MeshInstance3D).mesh is ArrayMesh,[parts.size(),steel.size()])
	check("it is untilted",is_zero_approx(clay.tool.prop_tilt()))
	reach.pointer_override = spot
	motion(spot,Vector2.ZERO,false)
	await frames(20)
	check("the hand grips the chisel over the land",hand == null or hand.reach_gesture == "grip",hand.reach_gesture if hand != null else "")
	reach.pointer_override = null
	var undo0: int = data._undo.size()

	# --- Drag: the shelf ---
	var shelf := await drag(spot+Vector2(-150,0),300.0)
	check("a drag is the shelf",shelf.verb == "shelf" and worked.back() == ["shelf",true],[shelf.verb,worked.back()])
	check("the shelf is level along its line (within 3 cm)",shelf.level_spread < 0.03,"%.3f m" % shelf.level_spread)
	check("at the height of the press (within 5 cm)",absf(shelf.level-shelf.press) < 0.05,"%.2f vs %.2f m" % [shelf.level,shelf.press])
	check("a face drops off its downhill edge",shelf.drop > Chisel.FACE_DROP*0.6,"%.2f m" % shelf.drop)
	check("steeper than the Hand's groove banks",shelf.steep > groove.steep*1.3,"%.2f vs %.2f rise/run" % [shelf.steep,groove.steep])
	check("the face is painted rock",shelf.rock >= 4,"%d cells" % shelf.rock)
	check("the shelf's line stays ground",not shelf.mid_rock)
	check("one undo step for the shelf",shelf.undo == 1)
	await undo_exact(shelf.base,shelf.undo0,"shelf")
	var shallow := await drag(spot+Vector2(-150,0),300.0,true)
	check("Shift-drag is the shallow shelf",shallow.verb == "shallow_shelf",shallow.verb)
	check("it cuts a shallower face",shallow.drop < shelf.drop*0.7 and shallow.drop > 0.2,"%.2f vs %.2f m" % [shallow.drop,shelf.drop])
	await undo_exact(shallow.base,shallow.undo0,"shallow shelf")

	# --- The size pips widen it ---
	await key(KEY_3)
	check("the size key 3 sets 1.5x",is_equal_approx(clay.size_scale,1.5))
	var wide := await drag(spot+Vector2(-150,0),300.0)
	check("the widest pip cuts over more ground",wide.moved > shelf.moved*1.3,"%d vs %d points" % [wide.moved,shelf.moved])
	check("at least as deep (the pips scale widths, not depths)",wide.drop > shelf.drop*0.8,"%.2f vs %.2f m" % [wide.drop,shelf.drop])
	await undo_exact(wide.base,wide.undo0,"wide shelf")
	await key(KEY_2)
	check("and 2 sets it back",is_equal_approx(clay.size_scale,1.0))

	# --- Terraces: a second stroke pressed on the first's lower bench ---
	var first := await drag(spot+Vector2(-150,0),300.0)
	var bench: Vector2 = first.mid+first.down*first.foot
	var second := await drag(screen(bench)+Vector2(-150,0),300.0)
	var upper := height(first.mid-first.down*0.7)
	print("TERRACE ",JSON.stringify({"upper":snappedf(upper,0.01),"lower":snappedf(second.level,0.01),"lower_spread":snappedf(second.level_spread,0.001),"lower_drop":snappedf(second.drop,0.01)}))
	check("a stroke pressed on the bench below cuts a second level: a terrace",upper-second.level > 0.3 and second.level_spread < 0.03 and absf(upper-first.level) < 0.03,"upper %.2f, lower %.2f m" % [upper,second.level])
	check("with its own face below it",second.drop > Chisel.FACE_DROP*0.6,"%.2f m" % second.drop)
	editor.undo()
	await settled()
	await undo_exact(first.base,first.undo0,"terrace")

	# --- Hold then drag: the mesa, and the pit ---
	var up := await hold(spot,-60.0)
	check("hold then drag up is the mesa, the hand gripping",up.verb == "mesa" and (hand == null or up.gesture == "grip"),[up.verb,up.gesture])
	check("it raises the spot",up.crown > 1.5,"%.2f m" % up.crown)
	check("its top is flat (spread under 2 cm)",up.spread < 0.02,"%.3f m" % up.spread)
	check("the top follows the pointer (within 12 px)",up.follow < 12.0,"%.1f px" % up.follow)
	check("with cliff walls steeper than the groove's banks",up.wall > groove.steep*2.0,"%.2f vs %.2f" % [up.wall,groove.steep])
	check("the walls take rock, the top stays ground",up.rock >= 6 and not up.top_rock,"%d cells" % up.rock)
	check("it stays where it was let go",absf(up.after-up.release) < 0.01)
	check("one undo step for the mesa",up.undo == 1 and worked.back() == ["mesa",true],worked.back())
	await undo_exact(up.base,up.undo0,"mesa")
	var pit := await hold(spot,30.0)
	check("hold then drag down sinks a pit",pit.crown < -0.4,"%.2f m" % pit.crown)
	check("with a flat floor",pit.spread < 0.02,"%.3f m" % pit.spread)
	await undo_exact(pit.base,pit.undo0,"pit")
	var low := await hold(spot,-60.0,true)
	check("Shift holds the shallow mesa",low.verb == "shallow_mesa" and low.crown < up.crown*0.7 and low.crown > 0.3,"%.2f vs %.2f m" % [low.crown,up.crown])
	await undo_exact(low.base,low.undo0,"shallow mesa")
	await key(KEY_1)
	var small := await hold(spot,-60.0)
	check("the smallest pip raises a smaller mesa",small.moved < up.moved*0.6,"%d vs %d points" % [small.moved,up.moved])
	await undo_exact(small.base,small.undo0,"small mesa")
	await key(KEY_2)

	# --- Tap: the notch ---
	var knock := await notch(spot)
	check("a tap is the notch",knock.worked == ["notch",true],knock.worked)
	check("it knocks the spot down",knock.depth > Chisel.NOTCH_DEPTH*0.6,"%.2f m" % knock.depth)
	check("a small notch, nothing raised",knock.moved >= 1 and knock.moved <= 16 and knock.up == 0,"%d points" % knock.moved)
	check("one undo step for the notch",knock.undo == 1)
	await undo_exact(knock.base,knock.undo0,"notch")
	var soft := await notch(spot,true)
	check("Shift knocks a shallower notch",soft.worked == ["shallow_notch",true] and soft.depth < knock.depth*0.7 and soft.depth > 0.1,"%.2f vs %.2f m" % [soft.depth,knock.depth])
	await undo_exact(soft.base,soft.undo0,"shallow notch")
	check("every verb undone: the undo stack is back where it began",data._undo.size() == undo0)

	# --- Esc gives back the Hand ---
	await key(KEY_ESCAPE)
	check("Esc puts the chisel back: the Hand again",roll.tool == "hand" and clay.tool_id == "hand",[roll.tool,clay.tool_id])
	check("its prop is gone",clay.get("_prop") == null or not is_instance_valid(clay.get("_prop")))
	print("FAILURES: ",failures)
	scene.queue_free()
	await frames(3)
	quit(1 if not failures.is_empty() else 0)
