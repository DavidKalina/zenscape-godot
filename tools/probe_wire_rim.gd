extends SceneTree
## Headless probe of the Wire at the plate's rim (scripts/clay_tools/wire.gd
## `_to_rim`): a gorge drawn to within RIM_REACH of the rim runs on out
## through it and cuts the rim's own points to full depth; a slice held at
## the rim and dragged down cuts the rim's points to its plane too; each is
## one undo step.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_wire_rim.gd -- --modeless --no-title
const Wire = preload("res://scripts/clay_tools/wire.gd")
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


func on_screen(s: Vector2) -> bool:
	return Rect2(Vector2(200,60),Vector2(1040,780)).has_point(s)

## Points within `radius` of `at` (plate) at least `out` from the middle on
## the rim's axis.
func rim_points(at: Vector2, radius: float, out: float) -> PackedInt32Array:
	var data := editor.data
	var found := PackedInt32Array()
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if p.distance_to(at) < radius and maxf(absf(p.x),absf(p.y)) >= out: found.append(i)
	return found

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: push_error("wire rim probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-wire-rim-probe-%d/places.json" % Time.get_ticks_usec()
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
	await settled()
	var data := editor.data
	var roll: Control = materials.roll
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	materials.select_tool("wire")
	await frames(20)
	check("the wire is in hand on its gorge",clay.tool_id == "wire" and clay.tool.mode == "gorge",[clay.tool_id,clay.tool.mode])
	# A run from the middle out to 12 m along whichever axis shows on screen.
	var line: Array[Vector2] = []
	for axis: Vector2 in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]:
		var across := Vector2(-axis.y,axis.x)
		for offset in [0.0,2.0,-2.0,4.0]:
			var a: Vector2 = axis*4.0+across*offset
			var b: Vector2 = axis*12.0+across*offset
			if on_screen(screen(a)) and on_screen(screen(b)) and bare(screen(a)) and bare(screen(b)):
				line = [a,b]
				break
		if not line.is_empty(): break
	check("found a run to the rim on screen",not line.is_empty())
	if line.is_empty():
		quit(1)
		return
	print("run ",line)
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()
	var from := screen(line[0])
	var to := screen(line[1])
	button(from,true)
	await frames(2)
	for k in range(30):
		var p := from.lerp(to,float(k+1)/30.0)
		motion(p,(to-from)/30.0)
		await frames(1)
	await frames(4)
	button(to,false)
	await settled()
	var path: PackedVector2Array = clay.tool.cut_path()
	var outward: Vector2 = line[1].normalized()
	print("CUT PATH END ",path[-1] if not path.is_empty() else null)
	check("the drawn path runs on out through the rim",not path.is_empty() and path[-1].dot(outward) > 14.0,path[-1] if not path.is_empty() else null)
	var rim := rim_points(line[1]+outward*2.0,0.8,13.6)
	var deepest := 0.0
	for i in rim: deepest = maxf(deepest,base[i]-data.heights[i])
	print("RIM ",JSON.stringify({"points":rim.size(),"deepest":snappedf(deepest,0.01)}))
	check("the rim's points are cut to full depth",rim.size() > 0 and deepest > Wire.GORGE_DEPTH*0.8,[rim.size(),deepest])
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	editor.undo()
	await settled()
	check("undo restores the ground",data.heights == base)

	# --- The slice at the rim ---
	materials.set_mode("slice")
	await frames(10)
	var at: Vector2 = line[1]+outward*0.8
	var spot := screen(at)
	var before := height(at)
	button(spot,true)
	await frames(3)
	for k in range(20):
		motion(spot+Vector2(0,4*(k+1)),Vector2(0,4))
		await frames(1)
	button(spot+Vector2(0,80),false)
	await settled()
	var level: float = clay.tool.slice_level()
	var edge := rim_points(at,Wire.SLICE_RADIUS*clay.size_scale*0.9,13.6)
	var standing := 0
	for i in edge:
		if data.heights[i] > level+0.01: standing += 1
	print("SLICE ",JSON.stringify({"before":snappedf(before,0.01),"level":snappedf(level,0.01),"rim_points":edge.size(),"left_standing":standing}))
	check("a slice cuts the rim's points to its plane",edge.size() > 0 and level < before-0.2 and standing == 0,[edge.size(),level,standing])
	editor.undo()
	await settled()
	check("undo restores the ground after the slice",data.heights == base)
	print("WIRE RIM PROBE ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
