extends SceneTree
## Headless probe of the in-hand ground marks (scripts/ground_marks.gd,
## docs/design/materials-tray/CURSOR-MARKS.md) on the real cozy worlds scene,
## the pointer driven through hand_reach's `pointer_override` and presses
## synthesized as mouse events. Checks: each kind (hand, paddle, chisel, wire,
## hammer, material) shows over bare land at each size with the right extent
## (terrain metres) and fades in over FADE_IN; it hides over the tray, the
## roll, the void and a tree, while the camera moves, and once a drag or pinch
## starts; the wire's line spans press to pointer during its drag; the drop
## ring follows the material held; alpha stays under FAINT_CAP.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_ground_marks.gd -- --no-title
## Headless draws nothing: this checks what the mark is told to draw, not
## how it looks.
const Marks = preload("res://scripts/ground_marks.gd")
var scene: Node3D
var editor: Node
var reach: Node
var materials: Node
var marks: Node
var failures := []

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

func frames(count: int) -> void:
	for i in range(count): await process_frame

func point_at(at: Vector2) -> void:
	reach.pointer_override = at
	editor.pointer_override = at

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func bare(at: Vector2) -> bool:
	return reach.reach_at(at) == "" and reach._land(at) != null and not reach._prop_at(at) and reach._tree_under(at) <= 0 and not materials.tray_under(at)

func settled() -> void:
	var quiet := 0
	var clay: Node = scene.get("land_clay")
	while quiet < 20:
		await process_frame
		var busy: bool = editor.land_settling or editor.refresh_pending > 0 or (clay != null and (clay.state != 0 or clay.poking))
		quiet = 0 if busy else quiet+1

## The mark's world box contains the ground point `local` (terrain).
func boxed(local: Vector3) -> bool:
	var inside: Vector3 = marks.node.global_transform.affine_inverse()*editor.terrain.to_global(local)
	return absf(inside.x) <= 0.5 and absf(inside.y) <= 0.5 and absf(inside.z) <= 0.5

func faint() -> bool:
	return marks.line_alpha_now() <= Marks.FAINT_CAP+1e-4 and Marks.FILL_ALPHA <= Marks.FAINT_CAP and Marks.LINE_ALPHA <= Marks.FAINT_CAP and Marks.WIRE_ALPHA <= Marks.FAINT_CAP

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("ground marks probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-marks-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	scene.world_clock.running = false
	materials = reach.get("materials")
	marks = reach.get("marks")
	check("the tray and the marks exist",materials != null and marks != null)
	if marks == null:
		quit(1)
		return
	await settled()
	var roll: Control = materials.roll
	var at := Vector2.INF
	for candidate in [Vector2(-2,1),Vector2(-3,-2),Vector2(2,3),Vector2(0,-4),Vector2(-5,4),Vector2(4,-3),Vector2(-6,-5),Vector2(1,-1)]:
		var s := screen(candidate)
		if bare(s) and bare(s+Vector2(140,0)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	print("spot ",at," on screen ",spot)
	point_at(spot)
	await frames(30)
	check("hovering bare land reads as land",reach.hover_zone == "land",reach.hover_zone)

	# --- Each tool at each size ---
	var sizes: Array = []
	for level in range(3): sizes.append(float(roll.SIZES[level].scale))
	# Each tool's own reach (clay_tool.gd `mark_size`): the Hand's rub, the
	# paddle's pat across the view, the chisel's notch, the hammer's crack.
	var expect := {"hand":Vector2(1.6,1.6),"paddle":Vector2(3.0,1.5),"chisel":Vector2(0.8,0.8),"wire":Vector2.ZERO,"hammer":Vector2(1.8,1.8)}
	var linked := {"hand":Vector2.ONE*preload("res://scripts/clay_tools/hand.gd").RUB_RADIUS,
		"paddle":Vector2(1.0,preload("res://scripts/clay_tools/paddle.gd").MARK_DEPTH)*preload("res://scripts/clay_tools/paddle.gd").PAT_RADIUS,
		"chisel":Vector2.ONE*preload("res://scripts/clay_tools/chisel.gd").NOTCH_HALF,
		"hammer":Vector2.ONE*preload("res://scripts/clay_tools/hammer.gd").CRACK_RADIUS}
	check("the expected sizes are the tools' own reaches",linked.keys().all(func(k: String) -> bool: return (linked[k] as Vector2).is_equal_approx(expect[k])),linked)
	for tool: String in ["hand","paddle","chisel","wire","hammer"]:
		roll.tool = tool
		for level in range(3):
			materials.set_size(level)
			await frames(2)
			var want: Vector2 = expect[tool]*float(sizes[level])
			await frames(14)
			var ok: bool = marks.kind == tool and marks.node.visible and marks.shown > 0.99 and marks.half.distance_to(want) < 1e-3
			check("%s at size %.1f shows over the land, half %s m" % [tool,sizes[level],want],ok,[marks.kind,marks.shown,marks.half,marks.reason])
			check("  and lies on the hover point, boxed",(marks.centre as Vector3).distance_to(reach._hover_point) < 1e-3 and boxed(marks.centre),marks.centre)
			check("  faint: line alpha %.2f <= %.2f" % [marks.line_alpha_now(),Marks.FAINT_CAP],faint())
		if tool == "hammer": check("the hammer scatters %d scree specks" % Marks.SCREE.size(),marks.specks.size() == Marks.SCREE.size(),marks.specks.size())
		if tool == "chisel": check("the chisel lies in the ground's plane",absf((marks.axis as Vector3).dot(marks.normal)) < 1e-3,marks.axis)
	materials.set_size(1)
	roll.tool = "hand"

	# --- Fade in over FADE_IN, only on land ---
	var sky := Vector2(720,20)
	point_at(sky)
	await frames(20)
	check("over the sky (%s) it is gone" % reach.hover_zone,marks.shown == 0.0 and not marks.node.visible,[reach.hover_zone,marks.reason])
	point_at(spot)
	await frames(1)
	var early: float = marks.shown
	await frames(5)
	var mid: float = marks.shown
	await frames(10)
	check("it fades in over about %.2f s" % Marks.FADE_IN,early < 0.2 and mid > 0.2 and mid < 0.8 and marks.shown > 0.99,[early,mid,marks.shown])

	# --- Over the tray and the roll ---
	var bar: Vector2 = materials.tray.specimen_centre("water")
	point_at(bar)
	await frames(20)
	check("over the materials bar it hides",marks.shown == 0.0,[reach.hover_zone,marks.reason])
	point_at(roll._cell(0).get_center())
	await frames(20)
	check("over the tool roll it hides",marks.shown == 0.0,[reach.hover_zone,marks.reason])
	point_at(spot)
	await frames(20)
	check("back on the land it shows",marks.shown > 0.99)

	# --- The camera moving ---
	scene._orbiting = true
	await frames(12)
	check("while the camera moves it hides",marks.shown == 0.0 and marks.reason == "camera",marks.reason)
	scene._orbiting = false
	await frames(20)

	# --- Under a tree ---
	var play: Variant = scene.get("world_play")
	var tree_at := Vector2.INF
	if play != null and play.get("_records") != null:
		for id: int in play._records:
			var record: Dictionary = play._records[id]
			if not str(record.get("asset","")) in play.TREES: continue
			var world: Vector3 = editor.data.object_position(record)
			for lift in [1.0,2.0,3.0]:
				var s: Vector2 = scene.camera.unproject_position(world+Vector3.UP*lift)
				if Rect2(Vector2(200,100),Vector2(1040,650)).has_point(s) and reach._tree_under(s) > 0:
					tree_at = s
					break
			if tree_at != Vector2.INF: break
	if tree_at == Vector2.INF: print("SKIP no tree on screen to hover")
	else:
		point_at(tree_at)
		await frames(20)
		check("over a tree it hides",marks.shown == 0.0,[reach.hover_zone,marks.reason])
		point_at(spot)
		await frames(20)

	# --- A press: gone once a pinch or drag starts ---
	check("shown before the press",marks.shown > 0.99)
	button(spot,true)
	await frames(10)
	check("a press on the land (held %s) fades it out" % reach.holding,marks.shown == 0.0 and not marks.node.visible,[marks.shown,marks.reason])
	await frames(20)
	check("still gone through the pinch",marks.shown == 0.0,[scene.land_clay.verb if scene.get("land_clay") != null else ""])
	button(spot,false)
	await settled()
	point_at(spot)
	await frames(20)

	# --- The wire: press to pointer ---
	roll.tool = "wire"
	await frames(16)
	check("the wire on hover is a single toggle at the pointer",marks.kind == "wire" and marks.shown > 0.99 and (marks.wire_start as Vector3).distance_to(marks.centre) < 1e-3)
	var start: Vector3 = marks.centre
	button(spot,true)
	await frames(2)
	var p := spot
	for i in range(24):
		p += Vector2(5,0)
		point_at(p)
		motion(p,Vector2(5,0))
		await frames(1)
	await frames(2)
	var ground: Variant = reach._land(p)
	check("during the drag (held %s) the wire shows" % reach.holding,marks.kind == "wire" and marks.shown > 0.99 and marks.node.visible,[marks.reason,marks.shown])
	check("  from the press point",(marks.wire_start as Vector3).distance_to(start) < 1e-3,[marks.wire_start,start])
	check("  to the pointer's ground",ground != null and (marks.centre as Vector3).distance_to(ground) < 1e-3,[marks.centre,ground])
	check("  both ends inside the decal box",boxed(marks.wire_start) and boxed(marks.centre))
	check("  and faint: %.2f" % marks.line_alpha_now(),faint())
	button(p,false)
	await settled()
	roll.tool = "hand"
	point_at(spot)
	await frames(20)

	# --- Materials: the drop ring ---
	for id: String in ["wildflower","reed","stone","water","oak"]:
		if not materials.tray.discovered(id):
			print("SKIP %s not found yet" % id)
			continue
		materials._take(id)
		for level in [0,2]:
			materials.set_size(level)
			await frames(16)
			var r := 0.0
			match id:
				"wildflower": r = 0.75
				"reed": r = 0.45
				"stone": r = 0.45
				"water": r = 1.0
				"oak": r = 1.3
			var want := Vector2(r,r)*float(sizes[level])
			check("holding %s at size %.1f: the drop ring, half %s m" % [id,sizes[level],want],marks.kind == "material" and marks.shown > 0.99 and marks.half.distance_to(want) < 1e-3,[marks.kind,marks.half,marks.reason])
		materials.put_back()
		materials.set_size(1)
		await frames(16)
	check("put down, the Hand's mark is back",marks.kind == "hand" and marks.shown > 0.99,marks.kind)

	print("failures=%d %s" % [failures.size(),failures])
	quit(1 if failures.size() > 0 else 0)
