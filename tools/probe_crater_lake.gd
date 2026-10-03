extends SceneTree
## Headless probe of the Crater's Draw mode (scripts/clay_tools/crater.gd), on
## the real cozy worlds scene, driven by synthesized input through hand_reach.
## Checks: the Crater fans out Pull and Draw; in Draw a loop drawn round a
## big stretch of the plain leaves the land untouched while it is drawn, and
## let go the land inside sinks into a lake bed (its middle about LAKE_DEPTH
## under the shore's lowest ground, level), the land outside the shore
## untouched, the land shuddering as it sinks, as one undo step one undo
## takes back exactly; the watering can reads its middle as a hollow (so it
## gushes to fill it); and a click in Draw leaves the land alone.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_crater_lake.gd -- --modeless --no-title
const Crater = preload("res://scripts/clay_tools/crater.gd")
## The drawn shore: a loop RADIUS m round CENTRE, in STEPS moves.
const CENTRE := Vector2(0.0,0.0)
const RADIUS := 9.0
const STEPS := 60
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
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

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("crater lake probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-lake-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	materials = reach.get("materials")
	scene.world_clock.running = false
	check("land clay and the materials tray exist",clay != null and materials != null)
	if clay == null or materials == null:
		quit(1)
		return
	await settled()
	var data := editor.data
	var undo0: int = data._undo.size()
	materials.select_tool("crater")
	await frames(10)
	var roll: Control = materials.roll
	check("the crater fans out Pull and Draw, Pull in hand",roll.modes == ["pull","draw"] and clay.tool.mode == "pull",[roll.modes,clay.tool.mode])
	materials.set_mode("draw")
	await frames(2)
	check("Draw is in hand",clay.tool.mode == "draw",clay.tool.mode)

	# --- A loop round the plain ---
	var base := data.heights.duplicate()
	var tint0 := data.tint.duplicate()
	var loop: Array[Vector2] = []
	for k in range(STEPS+1):
		var a := TAU*float(k)/STEPS
		loop.append(screen(CENTRE+Vector2(cos(a),sin(a)*0.8)*RADIUS))
	var shudder: Node = scene.get("clay_tremor")
	var kicks0: int = shudder.kicks if shudder != null else 0
	button(loop[0],true)
	await frames(1)
	for k in range(1,loop.size()):
		motion(loop[k],loop[k]-loop[k-1])
		await frames(1)
	var still := 0.0
	for i in range(base.size()): still = maxf(still,absf(data.heights[i]-base[i]))
	check("drawing the shore leaves the land untouched",clay.state == clay.State.DRAG and clay.verb == "lake" and still < 1e-5,[clay.state,clay.verb,still])
	button(loop[-1],false)
	await frames(1)
	check("let go, the bed sinks",clay.tool.busy(),clay.tool.busy())
	await settled()
	var shore: PackedVector2Array = clay.tool.lake_shore()
	var low := INF
	for p in shore: low = minf(low,float(data.sample(p,base)))
	var middle := height(CENTRE)
	# The floor: every point 4 m or more inside the shore.
	var floor_low := INF
	var floor_high := -INF
	var outside := 0.0
	for i in range(base.size()):
		var p: Vector2 = data.points[i]
		var d := INF
		for j in range(shore.size()-1): d = minf(d,p.distance_to(Geometry2D.get_closest_point_to_segment(p,shore[j],shore[j+1])))
		if Geometry2D.is_point_in_polygon(p,shore):
			if d >= 4.0:
				floor_low = minf(floor_low,data.heights[i])
				floor_high = maxf(floor_high,data.heights[i])
		elif d > 0.6:
			outside = maxf(outside,absf(data.heights[i]-base[i]))
	var kicks: int = (shudder.kicks if shudder != null else 0)-kicks0
	print("LAKE ",JSON.stringify({"shore_points":shore.size(),"shore_low":snappedf(low,0.01),"middle":snappedf(middle,0.01),"floor":[snappedf(floor_low,0.01),snappedf(floor_high,0.01)],"outside_moved":snappedf(outside,0.001),"kicks":kicks}))
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	check("its middle stands about LAKE_DEPTH under the shore's lowest ground",absf((low-middle)-Crater.LAKE_DEPTH) < 0.3,low-middle)
	check("its floor is level",floor_high-floor_low < 0.05,floor_high-floor_low)
	check("the land outside the shore is untouched",outside < 1e-4,outside)
	check("the land shudders as it sinks",kicks >= 5,kicks)
	# The can's own hollow test, as the editor's can stream is made (it is
	# made at the can's first press).
	var can: Node3D = preload("res://scripts/watering_can.gd").new()
	can.flow = editor.flow
	can.ground_at = func(point: Vector2) -> Variant: return data.ground_height(point)
	check("the can reads the lake's middle as a hollow",can._basin(CENTRE))
	can.free()
	editor.undo()
	await settled()
	check("one undo takes the lake back exactly",data.heights == base and data.tint == tint0 and data._undo.size() == undo0)

	# --- A click in Draw: nothing ---
	check("Draw is still in hand",clay.tool.mode == "draw",clay.tool.mode)
	var spot := screen(CENTRE)
	button(spot,true)
	await frames(2)
	button(spot,false)
	await settled()
	var clicked := 0.0
	for i in range(base.size()): clicked = maxf(clicked,absf(data.heights[i]-base[i]))
	check("a click in Draw leaves the land alone",clicked < 1e-5 and data._undo.size() == undo0,[clicked,data._undo.size()-undo0])

	print("CRATER LAKE PROBE: ",failures.size()," failures ",failures)
	quit(1 if not failures.is_empty() else 0)
