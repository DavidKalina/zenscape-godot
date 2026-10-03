extends SceneTree
## Headless probe of the drag tools (scripts/clay_tools/hills.gd, mountain.gd,
## crater.gd)
## and the mode fans of the tools with several verbs, on the real
## cozy worlds scene, driven by synthesized input through hand_reach. Checks:
## each drag tool has a pocket and no fan; a Hills drag raises the land along
## the path by how far it goes (rolling, not even), a second pass lifts it
## more, and it lowers nothing; the Mountain fans out Pull and Draw, and a
## Pull press dragged up pulls a peak at once, and dragged down leaves the
## land as it was; a Crater press dragged
## down opens a crater (a sunk floor, a raised rim); the Bowl and the Hammer
## are off the roll; each is
## one undo step one undo takes back exactly; and the
## Paddle's and Modeller's fans pick their verb, hold verbs starting at the
## press.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_drag_tools.gd -- --modeless --no-title
const Mountain = preload("res://scripts/clay_tools/mountain.gd")
const Crater = preload("res://scripts/clay_tools/crater.gd")
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
	create_timer(280).timeout.connect(func() -> void: push_error("drag tools probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-drag-probe-%d/places.json" % Time.get_ticks_usec()
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
	print("spot ",at," on screen ",spot," ground ",snappedf(height(at),0.01))
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	var undo0: int = data._undo.size()
	for id in ["hills","mountain"]:
		var pocket: Vector2 = roll._cell(roll.TOOLS.find(id)).get_center()
		check("the %s has a pocket" % id,roll.tool_at(pocket) == id,roll.tool_at(pocket))
	check("the bowl is off the roll",not "bowl" in roll.TOOLS,roll.TOOLS)
	var hills_pocket: Vector2 = roll._cell(roll.TOOLS.find("hills")).get_center()
	await click(hills_pocket)
	await frames(10)
	check("pressing it takes the hills, with no fan",clay.tool_id == "hills" and roll.modes.is_empty(),[clay.tool_id,roll.modes])

	# --- Hills: a drag raises rolling land along the way ---
	var hill_base := data.heights.duplicate()
	var from := spot+Vector2(-150,0)
	var line: Array[Vector2] = []
	for k in range(13): line.append(plate(from+Vector2(25*k,0)))
	button(from,true)
	await frames(2)
	for k in range(60):
		motion(from+Vector2(5*(k+1),0),Vector2(5,0))
		await frames(1)
	button(from+Vector2(300,0),false)
	await settled()
	var count: Dictionary = moved(hill_base,0.05)
	var rises: Array[float] = []
	for p in line:
		if p != null: rises.append(height(p)-float(data.sample(p,hill_base)))
	var inner := rises.slice(2,rises.size()-2)
	print("HILLS ",JSON.stringify({"raised":count.up,"lowered":count.down,"rises":inner.map(func(r: float) -> float: return snappedf(r,0.01))}))
	check("a hills drag raises the land and lowers none",count.up > 80 and count.down == 0,count)
	check("a metre or two along the path in one pass",float(inner.max()) > 1.0 and float(inner.max()) < 3.0,inner.max())
	check("rolling, not an even ridge",inner.min() < inner.max()*0.8,[inner.min(),inner.max()])
	# Steepest rise over run between neighbouring points the drag raised.
	var steepest := 0.0
	for i in range(data.points.size()):
		if data.heights[i]-hill_base[i] < 0.05: continue
		for j in data._neighbors[i]:
			var run := data.points[i].distance_to(data.points[j])
			if run > 0.0: steepest = maxf(steepest,absf(data.heights[i]-data.heights[j])/run)
	var base_steepest := 0.0
	for i in range(data.points.size()):
		if data.heights[i]-hill_base[i] < 0.05: continue
		for j in data._neighbors[i]:
			var run := data.points[i].distance_to(data.points[j])
			if run > 0.0: base_steepest = maxf(base_steepest,absf(hill_base[i]-hill_base[j])/run)
	print("HILLS SLOPE ",JSON.stringify({"steepest":snappedf(steepest,0.01),"ground_before":snappedf(base_steepest,0.01)}))
	check("hills, not peaks: gentle all over",steepest < 0.6,steepest)
	var after_one: float = inner.max()
	button(from,true)
	await frames(2)
	for k in range(60):
		motion(from+Vector2(5*(k+1),0),Vector2(5,0))
		await frames(1)
	button(from+Vector2(300,0),false)
	await settled()
	var top := 0.0
	for p in line:
		if p != null: top = maxf(top,height(p)-float(data.sample(p,hill_base)))
	check("a second pass lifts it more",top > after_one+0.3,[after_one,top])
	check("each pass is one undo step",data._undo.size() == undo0+2,data._undo.size()-undo0)
	editor.undo()
	await settled()
	await undo_exact(hill_base,undo0,"hills")

	# --- Mountain: press and drag up at once ---
	materials.select_tool("mountain")
	await frames(10)
	var peak_base := data.heights.duplicate()
	var peak_before := height(at)
	button(spot,true)
	await frames(2)
	check("the mountain fans out Pull and Draw, Pull in hand",roll.modes == ["pull","draw"] and clay.tool.mode == "pull",[roll.modes,clay.tool.mode])
	check("a Pull press is a hold at once",clay.state == clay.State.HOLD and clay.verb == "peak",[clay.state,clay.verb])
	for k in range(25):
		motion(spot-Vector2(0,6*(k+1)),Vector2(0,-6))
		await frames(1)
	button(spot-Vector2(0,150),false)
	await settled()
	var peak := height(at)-peak_before
	print("MOUNTAIN ",snappedf(peak,0.01))
	check("dragging up pulls a mountain",peak > 4.0,peak)
	await undo_exact(peak_base,undo0,"mountain")

	# --- Mountain: press and drag down, nothing ---
	var down_base := data.heights.duplicate()
	button(spot,true)
	await frames(2)
	for k in range(20):
		motion(spot+Vector2(0,5*(k+1)),Vector2(0,5))
		await frames(1)
	button(spot+Vector2(0,100),false)
	await settled()
	var moved_down := 0.0
	for i in range(data.points.size()): moved_down = maxf(moved_down,absf(data.heights[i]-down_base[i]))
	check("the mountain only builds up: dragged down, the land stays (%.4f m)" % moved_down,moved_down < 0.005,moved_down)
	if data._undo.size() > undo0: await undo_exact(down_base,undo0,"mountain down")

	# --- Crater: press and drag down ---
	materials.select_tool("crater")
	await frames(30)
	check("the crater has a pocket, its fan Pull and Draw, Pull in hand",roll.tool == "crater" and clay.tool_id == "crater" and roll.modes == ["pull","draw"] and clay.tool.mode == "pull",[roll.tool,clay.tool_id,roll.modes,clay.tool.mode])
	for fine in [false,true]:
		var crater_base := data.heights.duplicate()
		var crater_before := height(at)
		if fine: shift(true)
		button(spot,true)
		await frames(2)
		check("a crater press is a hold at once",clay.state == clay.State.HOLD,clay.state)
		for k in range(20):
			motion(spot+Vector2(0,5*(k+1)),Vector2(0,5))
			await frames(1)
		if fine: shift(false)
		button(spot+Vector2(0,100),false)
		await settled()
		var lift: float = clay.tool.lift
		var spec: Dictionary = Crater.FINE_CRATER if fine else Crater.CRATER
		var radius: float = minf(float(spec.r0)+float(spec.grow)*absf(lift),float(spec.max_radius))*clay.size_scale
		var floor_drop := 0.0
		var rim_rise := 0.0
		var outside := 0
		for i in range(data.points.size()):
			var d: float = data.points[i].distance_to(clay.center)
			var change: float = data.heights[i]-crater_base[i]
			if d < radius*Crater.CRATER_FLOOR: floor_drop = minf(floor_drop,change)
			elif d > radius*0.7 and d < radius*1.1: rim_rise = maxf(rim_rise,change)
			elif d > radius*Crater.CRATER_RIM_OUT*1.05 and absf(change) > 0.005: outside += 1
		var name := "fine_crater" if fine else "crater"
		print(name.to_upper()," ",JSON.stringify({"lift":snappedf(lift,0.01),"radius":snappedf(radius,0.01),"centre":snappedf(height(at)-crater_before,0.01),"floor":snappedf(floor_drop,0.01),"rim":snappedf(rim_rise,0.01),"outside":outside}))
		check("dragging down opens a %s: the floor sinks" % name,lift < -0.5 and floor_drop < -0.4,[lift,floor_drop])
		check("with a rim raised round it (%s)" % name,rim_rise > 0.1,rim_rise)
		check("nothing moved past the rim (%s)" % name,outside == 0,outside)
		check("it is worked as %s, one undo step" % name,not worked.is_empty() and worked.back() == [name,true] and data._undo.size() == undo0+1,[worked.back() if not worked.is_empty() else [],data._undo.size()-undo0])
		await undo_exact(crater_base,undo0,name)
	# Dragged up, the crater does nothing.
	var up_base := data.heights.duplicate()
	button(spot,true)
	await frames(2)
	for k in range(20):
		motion(spot-Vector2(0,5*(k+1)),Vector2(0,-5))
		await frames(1)
	button(spot-Vector2(0,100),false)
	await settled()
	var raised := 0.0
	for i in range(data.points.size()): raised = maxf(raised,data.heights[i]-up_base[i])
	check("dragged up, the crater raises nothing (%.4f m)" % raised,raised < 0.005,raised)
	if data._undo.size() > undo0: await undo_exact(up_base,undo0,"crater up")

	# --- Other tools' modes: the fan picks the verb, no hold-then-drag ---
	materials.select_tool("paddle")
	await frames(30)
	check("the paddle fans out its modes",roll.modes == ["plane","pat"] and roll.mode == "plane",[roll.modes,roll.mode])
	materials.set_mode("pat")
	button(spot,true)
	await frames(2)
	for k in range(20):
		motion(spot+Vector2(5*(k+1),0),Vector2(5,0))
		await frames(1)
	button(spot+Vector2(100,0),false)
	await settled()
	check("in pat mode a dragged press is still a pat",not worked.is_empty() and worked.back()[0] == "pat",worked.back() if not worked.is_empty() else [])
	if data._undo.size() > undo0:
		editor.undo()
		await settled()
	await key(KEY_E)
	check("E steps the paddle's mode, wrapping round to the plane",roll.mode == "plane" and clay.tool.mode == "plane",[roll.mode,clay.tool.mode])
	materials.select_tool("hand")
	await frames(30)
	check("the modeller fans out its modes",roll.modes == ["pinch","groove","palm","poke"],roll.modes)
	var pinch_base := data.heights.duplicate()
	var pinch_before := height(at)
	button(spot,true)
	await frames(2)
	for k in range(20):
		motion(spot-Vector2(0,4*(k+1)),Vector2(0,-4))
		await frames(1)
	button(spot-Vector2(0,80),false)
	await settled()
	check("the modeller's pinch starts at the press",height(at) > pinch_before+0.5,height(at)-pinch_before)
	await undo_exact(pinch_base,undo0,"pinch")
	check("the hammer is off the roll",not "hammer" in roll.TOOLS,roll.TOOLS)

	print("DRAG TOOLS PROBE: ",failures.size()," failures ",failures)
	quit(1 if not failures.is_empty() else 0)
