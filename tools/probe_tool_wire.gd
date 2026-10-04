extends SceneTree
## Headless probe of the Ravine (id `wire`, scripts/clay_tools/wire.gd,
## docs/design/tools/PLAN.md "The Wire" and "The roll, revised") on the real cozy worlds scene,
## driven by synthesized mouse and key input through hand_reach, as
## tools/probe_tool_paddle.gd drives the Paddle. Checks: pressing the wire's
## pocket in the tool roll takes it (the hand grips it over the land, its
## stand-in prop is built, untilted); a drag along a bowed path leaves the land
## untouched until release and then draws a gorge through the land along the
## path it drew, bow and all, not the straight line: deep, narrow,
## steep-walled, rock on its walls and earth on its bed, its bed never
## climbing; partway through the drawing the near end is cut and the far end
## not, with the prop riding the head, and the land it leaves is exactly the
## instant cut along the same path; an L-shaped drag cuts along both legs and
## leaves the corner's outside alone; an undo mid-cut takes it all back, and a
## new press or Esc mid-cut lands the same land (and tint) as the whole
## drawing does; Shift is shallower
## and the size pips widen it; each verb is one undo step that one undo takes
## back exactly; a tap keeps nothing; Esc gives back the Hand.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_wire.gd -- --modeless --no-title
## Nothing here is seen: the dummy renderer draws nothing, so the grip pose,
## the prop and the rock are checked as data only.
const Wire = preload("res://scripts/clay_tools/wire.gd")
## Screen pixels the drag's path bows off the straight line at its middle.
const BOW := 70.0
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

func height(p: Vector2, heights := PackedFloat32Array()) -> float:
	return float(editor.data.sample(p,editor.data.heights if heights.is_empty() else heights))

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

## The tint cell's colour and weight at plate point `p`.
func tint_at(p: Vector2) -> Dictionary:
	var data := editor.data
	var cell: int = data.meadow_cell(p)
	var k := cell*NativeTerrainTint.STRIDE
	return {"color":Color(data.tint[k],data.tint[k+1],data.tint[k+2]),"weight":data.tint[k+3]}

## Grey granite against brown earth: the rock's blue is near its red.
func rocky(t: Dictionary) -> bool:
	var c: Color = t.color
	return t.weight > 0.35 and c.r > 0.0 and c.b/c.r > 0.72

func earthy(t: Dictionary) -> bool:
	var c: Color = t.color
	return t.weight > 0.35 and c.r > 0.0 and c.b/c.r < 0.62

## Plate point `s` metres along `path`, and the path's unit heading there.
func along_path(path: PackedVector2Array, s: float) -> Array:
	var at := 0.0
	for j in range(path.size()-1):
		var run := path[j].distance_to(path[j+1])
		if run <= 0.0: continue
		if s <= at+run or j == path.size()-2:
			return [path[j].lerp(path[j+1],clampf((s-at)/run,0.0,1.0)),(path[j+1]-path[j])/run]
		at += run
	return [path[-1],Vector2.RIGHT]

func path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for j in range(1,path.size()): length += path[j-1].distance_to(path[j])
	return length

## Metres from `p` to the nearest point of `path`.
func off_path(path: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for j in range(path.size()-1):
		best = minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[j],path[j+1])))
	return best

## Press at `start` and drag through `offsets` (screen pixels from `start`, one
## a frame), then let go. `shape` names it for the log. The cut is watched as it
## draws through: partway, how deep it is near the path's start and near its
## end, and where the prop rides. `interrupt` cuts the drawing short partway:
## "press" (a new press), "esc" (Esc, the Hand back) or "undo". Measures the cut
## along the path the wire drew (`cut_path`).
func gorge(start: Vector2, offsets: Array, fine := false, shape := "bow", interrupt := "") -> Dictionary:
	var data := editor.data
	var tool: RefCounted = clay.tool
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()
	var tint0 := data.tint.duplicate()
	var a: Vector2 = plate(start)
	if fine: shift(true)
	button(start,true)
	await frames(1)
	var p := start
	var verb := ""
	for offset: Vector2 in offsets:
		var next: Vector2 = start+offset
		motion(next,next-p)
		p = next
		await frames(1)
		if verb.is_empty() and clay.state == 2: verb = clay.verb
	if fine: shift(false)
	await frames(2)
	var untouched_while_drawn: bool = data.heights == base
	var drawn: PackedVector2Array = tool.drawn()
	var b: Vector2 = plate(p)
	button(p,false)
	await frames(1)
	# Drawing through: watch it until it lands (or is cut short).
	var path: PackedVector2Array = tool.cut_path()
	var length := path_length(path)
	var ran := 0
	var partway := {}
	var ride := INF
	var ends_moved := false
	var interrupted := false
	var undo_during: int = data._undo.size()-undo0
	# Wall-clock milliseconds per frame while it draws (headless: the land's
	# light refresh and the cut's own work, no drawing), and refreshes shown.
	var slowest := 0.0
	var tick := Time.get_ticks_usec()
	var refreshes0: int = clay.refreshes
	while clay.state != 0 and ran < 600:
		ran += 1
		var now := Time.get_ticks_usec()
		if ran > 1: slowest = maxf(slowest,(now-tick)/1000.0)
		tick = now
		var share: float = tool.cut_share()
		if partway.is_empty() and share >= 0.35:
			var near: Vector2 = along_path(path,length*0.1)[0]
			var far: Vector2 = along_path(path,length*0.9)[0]
			var head: Vector2 = along_path(path,length*share)[0]
			var work: Variant = clay.get("_work_at")
			ride = Vector2(work.x,work.z).distance_to(head) if work != null else INF
			partway = {"share":share,"near":height(near,base)-height(near),"far":height(far,base)-height(far),"state":clay.state,"undo_open":data._undo.size()-undo0}
		if not partway.is_empty() and not interrupt.is_empty() and not interrupted:
			interrupted = true
			match interrupt:
				"press":
					button(p,true)
					await frames(2)
					button(p,false)
				"esc": await key(KEY_ESCAPE)
				"undo": editor.undo()
			break
		await frames(1)
	await settled()
	if interrupt == "undo":
		return {"partway":partway,"base":base,"undo0":undo0,"undo":data._undo.size()-undo0,"restored":data.heights == base,"tint_restored":data.tint == tint0}
	var along := (b-a).normalized()
	var across := Vector2(-along.y,along.x)
	# Depth along the path, against what the ground allowed.
	var shallowest_share := INF
	var deepest := 0.0
	var line: Array[float] = []
	var digs: Array[float] = []
	for k in range(41):
		var q: Vector2 = along_path(path,length*(0.05+0.9*k/40.0))[0]
		# A run out through the rim climbs to its sill over its last metres.
		if preload("res://scripts/land_clay.gd").PLATE_HALF-maxf(absf(q.x),absf(q.y)) < Wire.RIM_SILL_RUN: continue
		var dug := height(q,base)-height(q)
		var room := minf(Wire.GORGE_DEPTH*(Wire.SHALLOW if fine else 1.0),height(q,base)-NativeTerrainData.MIN_HEIGHT)
		shallowest_share = minf(shallowest_share,dug/room)
		deepest = maxf(deepest,dug)
		digs.append(dug)
		line.append(height(q))
	# The gorge's own depth: the median along the path. Where the ground rises
	# ahead the bed cuts deeper to keep falling, which only the deepest reads.
	digs.sort()
	var typical: float = digs[digs.size()/2]
	# The bed never climbs: read from its higher end.
	if line[0] < line[-1]: line.reverse()
	var climb := 0.0
	for k in range(1,line.size()): climb = maxf(climb,line[k]-line[k-1])
	# The straight line's middle, off the drawn path.
	var chord := a.lerp(b,0.5)
	var chord_off := off_path(path,chord)
	var chord_dug := height(chord,base)-height(chord)
	# Across at the middle of the path: where the depth falls from 90% to 10%, each side.
	var middle: Array = along_path(path,length*0.5)
	var mid: Vector2 = middle[0]
	var side_way := Vector2(-(middle[1] as Vector2).y,(middle[1] as Vector2).x)
	var centre := height(mid,base)-height(mid)
	var steepest := INF
	var outside := 0.0
	var top: float = (Wire.BED_HALF*clay.size_scale+Wire.WALL_RUN)
	for side in [1.0,-1.0]:
		var d90 := -1.0
		var d10 := -1.0
		for n in range(80):
			var d := n*0.05
			var q: Vector2 = mid+side_way*d*side
			var dug := height(q,base)-height(q)
			if d90 < 0.0 and dug < centre*0.9: d90 = d
			if d10 < 0.0 and dug < centre*0.1:
				d10 = d
				break
		steepest = minf(steepest,0.8*centre/maxf(d10-d90,0.05))
		var far: Vector2 = mid+side_way*(top+0.6)*side
		outside = maxf(outside,absf(height(far)-height(far,base)))
	# Rock on the walls, earth on the bed: tint cells along the middle half.
	var wall := 0
	var wall_rock := 0
	var bed := 0
	var bed_earth := 0
	for k in range(9):
		var station: Array = along_path(path,length*(0.3+0.4*k/8.0))
		var q0: Vector2 = station[0]
		var cross := Vector2(-(station[1] as Vector2).y,(station[1] as Vector2).x)
		for n in range(-40,41):
			var q: Vector2 = q0+cross*n*0.05
			var share := (height(q,base)-height(q))/maxf(centre,0.01)
			var t := tint_at(q)
			if share > 0.25 and share < 0.75:
				wall += 1
				if rocky(t): wall_rock += 1
			elif absf(n*0.05) < Wire.BED_HALF*clay.size_scale*0.5:
				bed += 1
				if earthy(t): bed_earth += 1
	# The land it left is the one the instant cut along the same path writes.
	var instant: PackedFloat32Array = base.duplicate()
	tool.cut_gorge(instant,path)
	var count := moved(base,0.03)
	var result := {"verb":verb,"undo":data._undo.size()-undo0,"base":base,"undo0":undo0,"untouched":untouched_while_drawn,
		"shallowest_share":shallowest_share,"deepest":deepest,"typical":typical,"climb":climb,"chord_off":chord_off,"chord_dug":chord_dug,"centre":centre,
		"steepest":steepest,"outside":outside,"down":count.down,"up":count.up,"wall_rock":float(wall_rock)/maxi(wall,1),
		"bed_earth":float(bed_earth)/maxi(bed,1),"length":length,"path":path,"drawn":drawn,"a":a,"b":b,"partway":partway,"ride":ride,
		"ran":ran,"undo_during":undo_during,"same_as_instant":data.heights == instant,"heights":data.heights.duplicate(),"tint":data.tint.duplicate(),
		"interrupted":interrupted}
	print(("SHALLOW GORGE " if fine else "GORGE ")+JSON.stringify({"shape":shape,"interrupt":interrupt,"size":clay.size_scale,"verb":verb,"length_m":snappedf(length,0.01),
		"path_points":path.size(),"ground_at_press":snappedf(height(a,base),0.01),"shallowest_share":snappedf(shallowest_share,0.01),"deepest":snappedf(deepest,0.01),
		"centre_depth":snappedf(centre,0.01),"bed_climb_max":snappedf(climb,0.001),"chord_mid_off_path_m":snappedf(chord_off,0.01),"dug_at_chord_mid":snappedf(chord_dug,0.01),
		"wall_slope":snappedf(steepest,0.01),"outside_moved":snappedf(outside,0.001),"lowered":count.down,"raised":count.up,
		"wall_cells":wall,"wall_rock_share":snappedf(result.wall_rock,0.01),"bed_cells":bed,"bed_earth_share":snappedf(result.bed_earth,0.01),
		"frames_drawing":ran,"partway":partway,"prop_off_head_m":snappedf(ride,0.01),"same_as_instant":result.same_as_instant,
		"slowest_frame_ms":snappedf(slowest,0.1),"refreshes_while_drawing":clay.refreshes-refreshes0}))
	return result

## The drag's screen path: `pixels` along screen x in 5 px steps, bowed BOW px
## down the screen at its middle.
func bowed(pixels: float) -> Array:
	var offsets := []
	var steps := int(pixels/5.0)
	for i in range(1,steps+1): offsets.append(Vector2(5.0*i,BOW*sin(PI*i/steps)))
	return offsets

## An L: `across` pixels along screen x, then `down` pixels down the screen,
## in 5 px steps.
func ell(across: float, down: float) -> Array:
	var offsets := []
	for i in range(1,int(across/5.0)+1): offsets.append(Vector2(5.0*i,0.0))
	for i in range(1,int(down/5.0)+1): offsets.append(Vector2(across,5.0*i))
	return offsets

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("wire probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-wire-probe-%d/places.json" % Time.get_ticks_usec()
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
		if bare(s) and bare(s+Vector2(-160,0)) and bare(s+Vector2(160,0)) and bare(s+Vector2(0,-60)) and bare(s+Vector2(0,BOW)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	print("spot ",at," on screen ",spot," ground ",snappedf(height(at),0.01)," points ",data.points.size()," hand ",hand != null)

	# --- Taking the wire from the roll ---
	check("the wire is built (off UNBUILT)",roll.discovered("wire"))
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	check("the tool roll shows",roll.shown > 0.99,roll.shown)
	var pocket: Vector2 = roll._cell(roll.TOOLS.find("wire")).get_center()
	check("the wire's pocket hit-tests to it",roll.tool_at(pocket) == "wire",roll.tool_at(pocket))
	await click(pocket)
	check("pressing the pocket takes the wire",roll.tool == "wire" and clay.tool_id == "wire",[roll.tool,clay.tool_id])
	var prop: Node3D = clay.get("_prop")
	var parts: Array = prop.find_children("*","MeshInstance3D",true,false) if prop != null else []
	check("its stand-in prop is built, faceted, in the icon's tint",parts.size() >= 3 and (parts[-1] as MeshInstance3D).mesh is ArrayMesh and ((parts[-1] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color == Color("b8683f"),parts.size())
	check("and untilted",clay.tool.prop_tilt() == 0.0)
	check("it is labelled the Ravine",str(preload("res://scripts/hud_icons.gd").item("wire").get("label","")) == "Ravine · Carve",preload("res://scripts/hud_icons.gd").item("wire").get("label",""))
	check("it has no fan, and a press is a drag at once",clay.tool.modes().is_empty() and clay.tool.press_kind() == "drag",[clay.tool.modes(),clay.tool.press_kind()])
	reach.pointer_override = spot
	motion(spot,Vector2.ZERO,false)
	await frames(20)
	check("the hand grips the wire over the land",hand == null or hand.reach_gesture == "grip",hand.reach_gesture if hand != null else "")
	reach.pointer_override = null
	var undo0: int = data._undo.size()

	# --- Tap: nothing yet ---
	var before := data.heights.duplicate()
	await click(spot)
	await settled()
	check("a tap keeps nothing",data.heights == before and data._undo.size() == undo0)

	# --- Drag: the gorge ---
	var plain := await gorge(spot+Vector2(-150,0),bowed(300.0))
	check("a drag is the gorge",plain.verb == "gorge" and worked.back() == ["gorge",true],[plain.verb,worked.back()])
	check("the land is untouched while the wire is drawn",plain.untouched)
	check("the drawn path is the path the cut runs",plain.drawn.size() >= 2 and plain.path == plain.drawn,[plain.drawn.size(),plain.path.size()])
	check("cut along the drawn path, full depth where the ground allows",plain.shallowest_share > 0.9,"shallowest %.2f of the room, deepest %.2f m" % [plain.shallowest_share,plain.deepest])
	check("it follows the bow, not the straight line (its middle %.1f m off the path)" % plain.chord_off,plain.chord_off > 2.5 and absf(plain.chord_dug) < 0.02,"%.3f m dug there" % plain.chord_dug)
	var partway: Dictionary = plain.partway
	var expected_frames := clampf(plain.length/Wire.CUT_SPEED,Wire.CUT_SECONDS.x,Wire.CUT_SECONDS.y)*60.0
	check("it is drawn through, not cut at once: %d frames for %.1f m" % [plain.ran,plain.length],absf(plain.ran-expected_frames) <= 3.0,"expected about %.0f" % expected_frames)
	check("partway, the near end is cut and the far end not yet",not partway.is_empty() and partway.near > 0.5 and absf(partway.far) < 0.005,partway)
	check("  the stroke stays open while it draws (no undo step yet)",plain.undo_during == 0 and not partway.is_empty() and partway.undo_open == 0 and partway.state == 4)
	check("  the prop rides the head (within 1.5 m)",plain.ride < 1.5,"%.2f m" % plain.ride)
	check("the land it leaves is the instant cut along the same path",plain.same_as_instant)
	check("its bed never climbs",plain.climb < 0.02,"%.3f m" % plain.climb)
	check("narrow: the ground past its rim is untouched",plain.outside < 0.005,"%.4f m" % plain.outside)
	check("steep-walled: the walls stand at least 1.5 (56°)",plain.steepest > 1.5,"%.2f" % plain.steepest)
	check("it only cuts",plain.up == 0,plain.up)
	check("rock on its walls",plain.wall_rock > 0.6,"%.2f of the wall cells" % plain.wall_rock)
	check("earth on its bed",plain.bed_earth > 0.6,"%.2f of the bed cells" % plain.bed_earth)
	check("one undo step for the gorge",plain.undo == 1)
	await undo_exact(plain.base,plain.undo0,"gorge")

	# --- Cut short mid-drawing ---
	var undone := await gorge(spot+Vector2(-150,0),bowed(300.0),false,"bow","undo")
	check("an undo mid-cut takes all of it back, heights and tint",not undone.partway.is_empty() and undone.restored and undone.tint_restored and undone.undo == 0,undone.partway)
	for how in ["press","esc"]:
		if clay.tool_id != "wire" or roll.tool != "wire":
			await click(pocket)
		var short := await gorge(spot+Vector2(-150,0),bowed(300.0),false,"bow",how)
		if how == "esc": check("  Esc mid-cut gives back the Hand, in the roll and the clay alike",roll.tool == "hand" and clay.tool_id == "hand",[roll.tool,clay.tool_id])
		check("%s mid-cut lands the whole cut at once: the same land as the full drawing" % how,short.interrupted and short.heights == plain.heights and short.same_as_instant and short.ran < plain.ran,[short.ran,plain.ran])
		check("  and the same dirt and rock",short.tint == plain.tint)
		check("  in one undo step",short.undo == 1)
		await undo_exact(short.base,short.undo0,"gorge cut short by "+how)
	if clay.tool_id != "wire" or roll.tool != "wire":
		await click(pocket)
	check("the wire is in hand again",clay.tool_id == "wire" and roll.tool == "wire",[roll.tool,clay.tool_id])

	# --- An L: the gorge takes the bend ---
	# The corner picked on the ground as it stands before the cut, as the drag's are.
	var corner: Vector2 = plate(spot+Vector2(20,-60))
	var bend := await gorge(spot+Vector2(-150,-60),ell(170.0,140.0),false,"ell")
	var first_leg: Vector2 = bend.a.lerp(corner,0.5)
	var second_leg: Vector2 = corner.lerp(bend.b,0.5)
	var way_in: Vector2 = (corner-bend.a).normalized()
	var way_out: Vector2 = (bend.b-corner).normalized()
	var beyond: Vector2 = corner+(way_in-way_out).normalized()*(Wire.BED_HALF+Wire.WALL_RUN+0.8)
	var leg_dug := [height(first_leg,bend.base)-height(first_leg),height(second_leg,bend.base)-height(second_leg)]
	var beyond_dug: float = height(beyond,bend.base)-height(beyond)
	var corner_dug: float = height(corner,bend.base)-height(corner)
	print("ELL ",JSON.stringify({"corner":[snappedf(corner.x,0.01),snappedf(corner.y,0.01)],"corner_off_path":snappedf(off_path(bend.path,corner),0.01),"corner_dug":snappedf(corner_dug,0.01),"legs_dug":[snappedf(leg_dug[0],0.01),snappedf(leg_dug[1],0.01)],
		"beyond_corner_dug":snappedf(beyond_dug,0.001),"beyond_off_path":snappedf(off_path(bend.path,beyond),0.01),"chord_mid_dug":snappedf(bend.chord_dug,0.01)}))
	check("an L-shaped drag cuts along both legs",leg_dug[0] > 0.9 and leg_dug[1] > 0.9,"%.2f and %.2f m" % leg_dug)
	check("  full depth all along where the ground allows",bend.shallowest_share > 0.9,"%.2f" % bend.shallowest_share)
	check("  its bed never climbs round the bend",bend.climb < 0.02,"%.3f m" % bend.climb)
	check("  and round the bend itself",corner_dug > 0.9,"%.2f m, the corner %.2f m off the path" % [corner_dug,off_path(bend.path,corner)])
	check("  the corner's outside is untouched",absf(beyond_dug) < 0.005,"%.4f m" % beyond_dug)
	check("  and so is the straight line across the bend",bend.chord_off > 2.0 and absf(bend.chord_dug) < 0.005,"%.1f m off, %.3f m dug" % [bend.chord_off,bend.chord_dug])
	check("  it only cuts",bend.up == 0,bend.up)
	check("  and lands the instant cut along its path",bend.same_as_instant)
	check("  in one undo step",bend.undo == 1)
	await undo_exact(bend.base,bend.undo0,"L gorge")

	var fine := await gorge(spot+Vector2(-150,0),bowed(300.0),true)
	check("Shift-drag is the shallow gorge",fine.verb == "shallow_gorge" and worked.back() == ["shallow_gorge",true],fine.verb)
	# Read by the typical depth: a falling bed through rising ground cuts as
	# deep as it must for either gorge (wire.gd "The gorge"). The full gorge
	# may stop on the land's floor, so the shallow one is held to its own
	# depth, SHALLOW of the gorge's, and to less than the full one's.
	var shallow_depth := Wire.GORGE_DEPTH*Wire.SHALLOW
	check("it cuts shallower",absf(fine.typical-shallow_depth) < shallow_depth*0.25 and fine.typical < plain.typical*0.8 and fine.shallowest_share > 0.9,"typical %.2f (made %.2f) vs %.2f m (deepest %.2f vs %.2f)" % [fine.typical,shallow_depth,plain.typical,fine.deepest,plain.deepest])
	check("one undo step for the shallow gorge",fine.undo == 1)
	await undo_exact(fine.base,fine.undo0,"shallow gorge")

	# --- The size pips widen it ---
	await key(KEY_3)
	check("the size key 3 sets 1.5x",is_equal_approx(clay.size_scale,1.5) and roll.size_level == 2,clay.size_scale)
	var wide := await gorge(spot+Vector2(-150,0),bowed(300.0))
	check("the widest pip cuts a wider gorge",wide.down > plain.down*1.25,"%d vs %d points lowered" % [wide.down,plain.down])
	await undo_exact(wide.base,wide.undo0,"wide gorge")
	await key(KEY_1)
	var small := await gorge(spot+Vector2(-150,0),bowed(300.0))
	check("the smallest a narrower one",small.down < plain.down*0.85,"%d vs %d points lowered" % [small.down,plain.down])
	await undo_exact(small.base,small.undo0,"small gorge")
	await key(KEY_2)
	check("and 2 sets it back",is_equal_approx(clay.size_scale,1.0))

	# --- Esc gives back the Hand ---
	await key(KEY_ESCAPE)
	check("Esc puts the wire back: the Hand again",roll.tool == "hand" and clay.tool_id == "hand",[roll.tool,clay.tool_id])
	check("its prop gives way to the Modeller's",not is_instance_valid(prop) and clay.get("_prop") is Node3D and (clay.get("_prop") as Node3D).find_children("*","MeshInstance3D",true,false).size() >= 3)
	reach.pointer_override = spot
	motion(spot,Vector2.ZERO,false)
	await frames(20)
	check("the hand hovers ready to pinch again",hand == null or hand.reach_gesture == "pinch",hand.reach_gesture if hand != null else "")
	reach.pointer_override = null
	print("FAILURES: ",failures)
	scene.queue_free()
	await frames(3)
	quit(1 if not failures.is_empty() else 0)
