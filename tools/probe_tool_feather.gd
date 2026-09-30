extends SceneTree
## Headless probe of the Feather, "Gust" (scripts/clay_tools/feather.gd for
## its prop, scripts/hand_materials.gd "The Feather" for its gestures,
## docs/design/tools/PLAN.md "The Feather") on the real cozy worlds scene,
## driven by synthesized mouse and key input through hand_reach, as
## tools/probe_tool_paddle.gd drives the Paddle. Checks: the roll shows the
## Feather after a divider under the Hammer and its pocket takes it; the hand
## grips the stand-in quill in the tint, leaning -18°; a swipe on the land
## sends one lane gust along the swipe, as wide as the pips say; a still
## press held 400 ms bursts and a shorter one sends nothing; a drag from the
## sky onto the land puts the Feather in hand, its pocket pressed; the faint
## marks show at rest (hotspot), during the swipe (lane) and during the hold
## (ring), under the alpha cap; the Feather adds no undo step and leaves the
## heights as they were; taking a material and Esc give back the Hand.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_feather.gd -- --modeless --no-title
## Nothing here is seen: the dummy renderer draws nothing, so the grip, the
## prop and the marks are checked as data only.
const Feather = preload("res://scripts/clay_tools/feather.gd")
const Marks = preload("res://scripts/ground_marks.gd")
const Materials = preload("res://scripts/hand_materials.gd")
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var marks: Node
var hand: Node
var roll: Control
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

## Input through the Input singleton, so its button state is what the wind
## tool reads each frame (NativeChunkEditor `_gust_process`).
func button(at: Vector2, pressed: bool) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2, held := true) -> void:
	point(at)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point(at: Vector2) -> void:
	reach.pointer_override = at
	editor.pointer_override = at

func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

func frames(count: int) -> void:
	for i in range(count): await process_frame

func click(at: Vector2) -> void:
	button(at,true)
	await frames(2)
	button(at,false)
	await frames(2)

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func plate(at: Vector2) -> Variant:
	var hit: Variant = editor.pick(at)
	return Vector2(hit.x,hit.z) if hit != null else null

func bare(at: Vector2) -> bool:
	return reach.reach_at(at) == "" and reach._land(at) != null and not reach._prop_at(at) and not materials.tray_under(at)

func faint() -> bool:
	return marks.line_alpha_now() <= Marks.FAINT_CAP+1e-4 and Marks.LINE_ALPHA <= Marks.FAINT_CAP and Marks.FILL_ALPHA <= Marks.FAINT_CAP

## Empty sky: void, no cloud.
func empty_sky() -> Vector2:
	for y in [30,60,100,140]:
		for x in [400,600,720,900,1100]:
			var at := Vector2(x,y)
			if reach.void_at(at) and reach._cloud_at(at) == null: return at
	return Vector2.INF

func gust() -> Node:
	return editor.get("gust")

## Rest the hand over `spot` with nothing pressed, long enough for the hover
## and the mark to settle.
func hover(spot: Vector2) -> void:
	motion(spot,Vector2.ZERO,false)
	await frames(20)

## Swipe `pixels` along screen x from `start` in `steps` frames and let go.
## Returns [the gust sent or {}, the lane mark seen mid-swipe, the plate way].
func swipe(start: Vector2, pixels: float, steps := 10) -> Array:
	var sent: int = int(materials.feather_sent.lane)
	await hover(start)
	button(start,true)
	await frames(1)
	var p := start
	var seen := {}
	for i in range(steps):
		p += Vector2(pixels/steps,0)
		motion(p,Vector2(pixels/steps,0))
		await frames(1)
		if i == steps-2: seen = {"kind":marks.kind,"shown":marks.shown,"visible":marks.node.visible,"half":marks.half,"from":marks.wire_start,"alpha":marks.line_alpha_now(),"holding":reach.holding}
	button(p,false)
	await frames(2)
	var way: Vector2 = (plate(p)-plate(start)).normalized()
	var g: Dictionary = gust().gusts.back() if gust() != null and int(materials.feather_sent.lane) > sent else {}
	return [g,seen,way]

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("feather probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-feather-probe-%d/places.json" % Time.get_ticks_usec()
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
	marks = reach.get("marks")
	scene.world_clock.running = false
	check("land clay, the materials tray and the marks exist",clay != null and materials != null and marks != null)
	if clay == null or materials == null or marks == null:
		quit(1)
		return
	roll = materials.roll
	var data := editor.data
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
	print("spot ",at," on screen ",spot," hand ",hand != null)
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()

	# --- The roll: the Feather after a divider, and its pocket takes it ---
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	var index: int = roll.TOOLS.find("feather")
	check("the roll holds the Feather last, after the Hammer",index == roll.TOOLS.size()-1 and roll.TOOLS[index-1] == "hammer",roll.TOOLS)
	check("  with a divider before it",index in roll.DIVIDER_BEFORE,roll.DIVIDER_BEFORE)
	var gap: float = roll._cell(index).position.y-roll._cell(index-1).end.y
	check("  the divider opens the gap under the Hammer (%.0f px)" % gap,gap >= (roll.GAP+roll.DIVIDER)*roll.ui_scale-1.0,gap)
	check("  built, with its icon",roll.discovered("feather") and str(preload("res://scripts/hud_icons.gd").item("feather").get("label","")) == "Feather · Gust")
	var pocket: Vector2 = roll._cell(index).get_center()
	check("  its pocket hit-tests to it",roll.tool_at(pocket) == "feather",roll.tool_at(pocket))
	await click(pocket)
	check("pressing the pocket takes the Feather",roll.tool == "feather" and clay.tool_id == "feather",[roll.tool,clay.tool_id])

	# --- The prop and the grip ---
	var prop: Node3D = clay.get("_prop")
	var parts: Array = prop.find_children("*","MeshInstance3D",true,false) if prop != null else []
	var tinted := parts.any(func(p: MeshInstance3D) -> bool: return (p.material_override as StandardMaterial3D).albedo_color == Color("cbb994"))
	check("its stand-in quill is built, faceted, in the tint #cbb994",parts.size() >= 3 and (parts[0] as MeshInstance3D).mesh is ArrayMesh and tinted,parts.size())
	check("  leaning -18°",is_equal_approx(clay.tool.prop_tilt(),-18.0),clay.tool.prop_tilt())
	await hover(spot)
	check("the hand grips the Feather over the land",hand == null or hand.reach_gesture == "grip",hand.reach_gesture if hand != null else "")
	if prop != null and prop.visible:
		var lean := rad_to_deg(prop.transform.basis.y.normalized().angle_to(Vector3.UP))
		check("  the quill rides in the shown hand, leaning %.1f°" % lean,absf(lean-18.0) < 0.5,lean)
	else:
		check("  the quill rides only in a shown hand",hand == null or prop.visible == (hand.visible and float(hand.opacity) > 0.3),[prop.visible if prop != null else null])

	# --- At rest: the hotspot ---
	check("at rest the mark is the hotspot",marks.kind == "feather" and marks.shown > 0.99 and marks.node.visible and marks.half.distance_to(Marks.FEATHER_HOTSPOT) < 1e-4,[marks.kind,marks.shown,marks.half,marks.reason])
	check("  faint: line alpha %.2f <= %.2f" % [marks.line_alpha_now(),Marks.FAINT_CAP],faint())

	# --- Swipe: one lane along the swipe, as wide as the pips ---
	var widths := {}
	for level in [1,2,0]:
		materials.set_size(level)
		var want: float = Materials.FEATHER_HALF*float(roll.SIZES[level].scale)
		var result := await swipe(spot+Vector2(-120,0),240.0)
		var g: Dictionary = result[0]
		var seen: Dictionary = result[1]
		var way: Vector2 = result[2]
		widths[level] = float(g.get("half",0.0))
		print("SWIPE ",JSON.stringify({"size":roll.SIZES[level].scale,"kind":g.get("kind",""),"half":snappedf(float(g.get("half",0.0)),0.01),"power":snappedf(float(g.get("power",0.0)),0.01),"reach":snappedf(float(g.get("reach",0.0)),0.01),"mark":seen.get("kind",""),"mark_half":seen.get("half",Vector2.ZERO),"alpha":snappedf(float(seen.get("alpha",0.0)),0.01)}))
		check("size %.1f: a swipe sends one lane gust" % roll.SIZES[level].scale,g.get("kind","") == "lane" and materials.feather_last == "lane",[g.get("kind",""),materials.feather_last])
		if g.is_empty(): continue
		var off := absf(rad_to_deg((g.heading as Vector2).angle_to(way)))
		check("  along the swipe (%.1f° off)" % off,off < 15.0,[g.heading,way])
		check("  its lane %.1f m either side" % want,absf(float(g.half)-want) < 1e-3,g.half)
		check("  mid-swipe the mark is the lane, %.1f m either side, held %s" % [want,seen.get("holding","")],seen.get("kind","") == "feather_lane" and bool(seen.get("visible",false)) and absf((seen.half as Vector2).x-want) < 1e-3,seen)
		check("  faint: %.2f" % float(seen.get("alpha",1.0)),float(seen.get("alpha",1.0)) <= Marks.FAINT_CAP+1e-4 and Marks.FILL_ALPHA <= Marks.FAINT_CAP)
		await frames(20)
	check("the pips widen the lane 0.6 / 1 / 1.5",widths.size() == 3 and float(widths[0]) < float(widths[1]) and float(widths[1]) < float(widths[2]),widths)
	materials.set_size(1)

	# --- Hold still: a burst at 400 ms, nothing sooner ---
	await hover(spot)
	var none: int = int(materials.feather_sent.none)
	var bursts: int = int(materials.feather_sent.burst)
	button(spot,true)
	await frames(int(Materials.FEATHER_BURST_SECONDS*60.0*0.5))
	button(spot,false)
	await frames(3)
	check("a still press let go before 400 ms sends nothing",int(materials.feather_sent.none) == none+1 and int(materials.feather_sent.burst) == bursts and not gust().aiming(),materials.feather_sent)
	await hover(spot)
	button(spot,true)
	await frames(int(Materials.FEATHER_BURST_SECONDS*60.0*0.5))
	var early := {"kind":marks.kind,"shown":marks.shown}
	await frames(int(Materials.FEATHER_BURST_SECONDS*60.0*0.5)+6)
	var first := {"kind":marks.kind,"radius":marks.half.x,"alpha":marks.line_alpha_now(),"holding":reach.holding}
	await frames(60)
	var grown := {"kind":marks.kind,"radius":marks.half.x,"alpha":marks.line_alpha_now()}
	var half: float = materials.feather_half()
	print("HOLD ",JSON.stringify({"before":early,"at_0.5s":first,"at_1.5s":grown,"lane_half":half,"promise":gust().promise()}))
	check("held still, the hotspot stays until 400 ms",early.kind == "feather" and float(early.shown) > 0.99,early)
	check("  then the burst ring (held %s), from the lane's half-width" % first.holding,first.kind == "feather_burst" and float(first.radius) >= half-1e-3 and float(first.radius) < half*1.2,first)
	check("  growing to 1.5x it",grown.kind == "feather_burst" and float(grown.radius) > float(first.radius) and float(grown.radius) <= half*Materials.FEATHER_RING+1e-3,grown)
	check("  faint: %.2f" % float(grown.alpha),float(grown.alpha) <= Marks.FAINT_CAP+1e-4)
	button(spot,false)
	await frames(3)
	check("let go, it bursts",int(materials.feather_sent.burst) == bursts+1 and materials.feather_last == "burst" and gust().gusts.back().kind == "burst",[materials.feather_sent,materials.feather_last])
	await frames(30)

	# --- No land changed, no undo step ---
	check("the Feather adds no undo step",data._undo.size() == undo0,[undo0,data._undo.size()])
	check("and leaves the heights as they were",data.heights == base)

	# --- Taking a material gives back the Hand ---
	for i in range(60):
		if materials.tray.shown > 0.99: break
		await process_frame
	await click(materials.tray.specimen_centre("stone"))
	check("taking a stone puts the Feather back",materials.held == "stone" and roll.tool == "hand" and clay.tool_id == "hand",[materials.held,roll.tool,clay.tool_id])
	await key(KEY_ESCAPE)
	check("Esc puts the stone down",materials.held.is_empty())

	# --- Dragging wind from the sky onto the land puts the Feather in hand ---
	var sky := empty_sky()
	check("found empty sky",sky != Vector2.INF,sky)
	if sky != Vector2.INF:
		var lanes: int = int(materials.feather_sent.lane)
		# Counted as they go: the array also retires settled gusts.
		var went := []
		gust().sent.connect(func(g: Dictionary) -> void: went.append(g.kind))
		await hover(sky)
		button(sky,true)
		await frames(1)
		var p := sky
		for i in range(12):
			var step := (spot-sky)/12.0
			p += step
			motion(p,step)
			await frames(1)
			if gust().aiming(): break
		await frames(2)
		check("dragged from the sky onto the land, the Feather is in hand",roll.tool == "feather" and clay.tool_id == "feather" and gust().aiming(),[roll.tool,clay.tool_id,gust().aiming()])
		check("  its pocket pressed in the roll",roll.tool == "feather" and not roll.material_held,[roll.tool,roll.material_held])
		check("  the lane is the Feather's width",gust().aiming() and absf(float(gust().promise().get("half",0.0))-materials.feather_half()) < 1e-3,gust().promise().get("half",0.0))
		var on := p
		for i in range(6):
			on += Vector2(0,20)
			motion(on,Vector2(0,20))
			await frames(1)
		check("  the swipe on shows the lane mark",marks.kind == "feather_lane" and marks.node.visible,[marks.kind,marks.reason])
		button(on,false)
		await frames(3)
		check("  let go, one gust goes",went.size() == 1 and not gust().aiming(),went)
		check("  and the Feather stays in hand",roll.tool == "feather" and int(materials.feather_sent.lane) == lanes,roll.tool)
		await frames(20)

	# --- Esc gives back the Hand ---
	await key(KEY_ESCAPE)
	check("Esc puts the Feather back: the Hand again",roll.tool == "hand" and clay.tool_id == "hand",[roll.tool,clay.tool_id])
	check("its prop gives way to the Modeller's",not is_instance_valid(prop) and clay.get("_prop") is Node3D and (clay.get("_prop") as Node3D).find_children("*","MeshInstance3D",true,false).size() >= 3)
	await hover(spot)
	check("the hand hovers ready to pinch again",hand == null or hand.reach_gesture == "pinch",hand.reach_gesture if hand != null else "")
	check("still no undo step, heights unchanged",data._undo.size() == undo0 and data.heights == base)
	print("FAILURES: ",failures)
	scene.queue_free()
	await frames(3)
	quit(1 if not failures.is_empty() else 0)
