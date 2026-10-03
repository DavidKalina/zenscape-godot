extends SceneTree
## Headless probe of the Island (scripts/clay_tools/island.gd), on the real
## cozy worlds scene, driven by synthesized input through hand_reach.
## A lake is made first: the Crater's Draw sinks a bed round CENTRE and live
## water is laid level in it to LAKE_UNDER under its shore. Then:
## - the Island fans out Draw and Spread, Draw in hand;
## - a small loop drawn in the lake rises as an isle, one undo step: its
##   drawn shore stands at the water, its middle FREEBOARD and more over it,
##   no water left standing on it, and the lake's level where it was;
## - Spread scrubbed from the isle out across the lake pushes land out to
##   FREEBOARD over the water and never over it, and the lake keeps its level;
## - undoing both puts the lakebed back exactly.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_island.gd -- --modeless --no-title
const Island = preload("res://scripts/clay_tools/island.gd")
const CENTRE := Vector2(0.0,0.0)
## The lake's shore loop (m), and its water's level under the shore's lowest ground.
const LAKE_RADIUS := 9.0
const LAKE_UNDER := 0.6
## The isle's drawn loop (m), and the Spread's run out from its middle.
const ISLE_RADIUS := 2.6
const SPREAD_TO := Vector2(6.0,0.0)
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

## The water's surface over plate point `p` (its cell's ground and depth).
func surface(p: Vector2) -> float:
	var flow: RefCounted = editor.flow
	var c: int = flow.cell_at(p)
	return flow.grounds()[c]+flow.depths()[c]

## The middle surface of the lake's deep water (cells over 0.3 m deep).
func lake_level() -> float:
	var flow: RefCounted = editor.flow
	var depth: PackedFloat32Array = flow.depths()
	var ground: PackedFloat32Array = flow.grounds()
	var found := PackedFloat32Array()
	for c in depth.size():
		if depth[c] > 0.3: found.append(ground[c]+depth[c])
	if found.is_empty(): return NAN
	found.sort()
	return found[found.size()/2]

## A loop of screen points `radius` m round `at`.
func loop(at: Vector2, radius: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in range(STEPS+1):
		var a := TAU*float(k)/STEPS
		out.append(screen(at+Vector2(cos(a),sin(a)*0.8)*radius))
	return out

func drag(path: Array[Vector2]) -> void:
	button(path[0],true)
	await frames(1)
	for k in range(1,path.size()):
		motion(path[k],path[k]-path[k-1])
		await frames(1)
	button(path[-1],false)
	await frames(1)

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("island probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-island-probe-%d/places.json" % Time.get_ticks_usec()
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
	check("land clay, the materials tray and live water exist",clay != null and materials != null and editor.flow != null and editor.flow.ready)
	if failures.size() > 0:
		quit(1)
		return
	await settled()
	var data := editor.data

	# --- The lake: the Crater's Draw, and water laid level in it ---
	materials.select_tool("crater")
	await frames(5)
	materials.set_mode("draw")
	await frames(2)
	await drag(loop(CENTRE,LAKE_RADIUS))
	await settled()
	await frames(10)
	var shore: PackedVector2Array = clay.tool.lake_shore()
	var low := INF
	for p in shore: low = minf(low,height(p))
	var level := low-LAKE_UNDER
	var flow: RefCounted = editor.flow
	var ground: PackedFloat32Array = flow.grounds()
	var depth: PackedFloat32Array = flow.depths()
	var found: Dictionary = flow.hollow(CENTRE,ground)
	for c: int in found.get("cells",PackedInt32Array()): depth[c] = maxf(level-ground[c],0.0)
	flow.kernel.set_depth(depth)
	await create_timer(3.0).timeout
	var still := lake_level()
	print("LAKE ",JSON.stringify({"level":snappedf(level,0.01),"settled":snappedf(still,0.01),"middle_depth":snappedf(flow.depth_at(CENTRE),0.01),"volume":snappedf(flow.volume(),0.1)}))
	check("the lake stands where it was laid",absf(still-level) < 0.05,still-level)
	var bed := data.heights.duplicate()
	var undo0: int = data._undo.size()

	# --- The Island's fan ---
	materials.select_tool("island")
	await frames(10)
	var roll: Control = materials.roll
	check("the Island has a pocket and fans out Draw and Spread, Draw in hand",clay.tool_id == "island" and roll.modes == ["draw","spread"] and clay.tool.mode == "draw",[clay.tool_id,roll.modes,clay.tool.mode])

	# --- Draw: an isle in the lake ---
	var volume0: float = flow.volume()
	var drawn := loop(CENTRE,ISLE_RADIUS)
	button(drawn[0],true)
	await frames(1)
	for k in range(1,drawn.size()):
		motion(drawn[k],drawn[k]-drawn[k-1])
		await frames(1)
	var moved := 0.0
	for i in range(bed.size()): moved = maxf(moved,absf(data.heights[i]-bed[i]))
	check("drawing the shore leaves the land untouched",clay.state == clay.State.DRAG and clay.verb == "island" and moved < 1e-5,[clay.state,clay.verb,moved])
	button(drawn[-1],false)
	await frames(1)
	check("let go, the isle rises",clay.tool.busy())
	await settled()
	var isle: PackedVector2Array = clay.tool.isle_shore()
	var shore_err := 0.0
	for p in isle: shore_err = maxf(shore_err,absf(height(p)-level))
	var middle := height(CENTRE)-level
	var far := 0.0
	for i in range(bed.size()):
		var p: Vector2 = data.points[i]
		var d := INF
		for j in range(isle.size()-1): d = minf(d,p.distance_to(Geometry2D.get_closest_point_to_segment(p,isle[j],isle[j+1])))
		if d > Island.SHELF_OUT+0.6 and not Geometry2D.is_point_in_polygon(p,isle): far = maxf(far,absf(data.heights[i]-bed[i]))
	await create_timer(3.0).timeout
	var after := lake_level()
	var on_top: float = flow.depth_at(CENTRE)
	print("ISLE ",JSON.stringify({"shore_points":isle.size(),"middle_over_water":snappedf(middle,0.01),"shore_off_water":snappedf(shore_err,0.01),"lake_level_moved":snappedf(after-level,0.001),"water_on_top":snappedf(on_top,0.001),"volume_taken":snappedf(volume0-flow.volume(),0.1),"far_moved":snappedf(far,0.001)}))
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	check("its drawn shore stands at the water",shore_err < 0.2,shore_err)
	check("its middle stands FREEBOARD or more over the water, under a crown",middle >= Island.FREEBOARD-0.02 and middle <= Island.FREEBOARD+Island.CROWN*1.3,middle)
	check("no water stands on it",on_top < 0.02,on_top)
	check("the lake keeps its level",absf(after-level) < 0.05,after-level)
	check("the land past its shelf is untouched",far < 1e-4,far)
	var trees: RefCounted = preload("res://scripts/tree_paint.gd").new(editor.emergence,data,preload("res://scripts/emergence.gd").TREES[0],1.0,false,1,editor._paint_wet())
	check("a tree takes root on its middle, and not out in the lake",trees.suits(CENTRE) and not trees.suits(CENTRE+Vector2(6.5,0.0)),[trees.suits(CENTRE),trees.suits(CENTRE+Vector2(6.5,0.0))])

	# --- Spread: land pushed out from the isle across the lake ---
	materials.set_mode("spread")
	await frames(2)
	check("Spread is in hand and paints",clay.tool.mode == "spread" and clay.tool.paints(),clay.tool.mode)
	var before := data.heights.duplicate()
	var run_out: Array[Vector2] = []
	for pass_ in range(3):
		for k in range(STEPS+1):
			var t := float(k)/STEPS
			if pass_%2 == 1: t = 1.0-t
			run_out.append(screen(CENTRE.lerp(SPREAD_TO,t)))
	await drag(run_out)
	await settled()
	var over := -INF
	for i in range(before.size()):
		if data.heights[i] > before[i]+0.01: over = maxf(over,data.heights[i]-(level+Island.FREEBOARD))
	var spread_at := height(SPREAD_TO*0.8)-level
	await create_timer(3.0).timeout
	var spread_level := lake_level()
	print("SPREAD ",JSON.stringify({"at_4_8m_over_water":snappedf(spread_at,0.01),"highest_new_over_top":snappedf(over,0.01),"lake_level_moved":snappedf(spread_level-level,0.001)}))
	check("one more undo step",data._undo.size() == undo0+2,data._undo.size()-undo0)
	check("the spread land stands out of the water",spread_at > Island.FREEBOARD*0.6,spread_at)
	check("it never rises over FREEBOARD above the water",over < 0.02,over)
	check("the lake keeps its level",absf(spread_level-level) < 0.05,spread_level-level)

	editor.undo()
	await settled()
	editor.undo()
	await settled()
	check("two undos put the lakebed back exactly",data.heights == bed and data._undo.size() == undo0)

	print("ISLAND PROBE: ",failures.size()," failures ",failures)
	quit(1 if not failures.is_empty() else 0)
