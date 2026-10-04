extends SceneTree
## Headless probe of the footbridge (scripts/footbridge.gd, docs/scenic/bridges.md)
## on the real cozy worlds scene, the bridge taken from the case and dragged
## with synthesized input through hand_reach. Checks:
## - A trench dug across the land and filled with live water: a drag across it
##   shows a valid ghost and lays one bridge, snapped bank to bank (both ends
##   dry, on either side of the water, at most 6 m), as one undo step, moving
##   no ground; the water still stands under it after running on.
## - Over dry land the ghost shows invalid and nothing is laid.
## - Over a basin 8 m across nothing is laid ("too_long").
## - Cmd+Z takes the bridge away; the trash can's stroke over its middle takes
##   it as one undo step, and undo brings it back.
## - Saved and loaded (through JSON, as the place file is) it comes back the
##   same and is drawn; a saved bridge with no far end is refused.
##   perl -e 'alarm 600; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     --script res://tools/probe_bridges.gd -- --modeless --no-title --no-rain-runoff
const Footbridge = preload("res://scripts/footbridge.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const Trash = preload("res://scripts/clay_tools/trash.gd")

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

func motion(at: Vector2, relative: Vector2, held := true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event)

func cmd_z() -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_Z
		event.physical_keycode = KEY_Z
		event.meta_pressed = true
		event.ctrl_pressed = OS.get_name() != "macOS"
		event.pressed = down
		root.push_input(event)
		await process_frame

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

func bridges_now() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for item: Dictionary in editor.data.objects:
		if item.asset == "bridge": found.append(item)
	return found

## Digs a flat-floored hole `size` (x, z extents, m) round `centre`, `depth`
## m under the lowest ground at its rim, as one stroke, and pours `volume` m³
## of live water into it, run until it settles.
func dig_and_fill(centre: Vector2, size: Vector2, depth: float, volume: float) -> float:
	var data := editor.data
	var rim := INF
	for k in range(16):
		var a := TAU*k/16.0
		rim = minf(rim,height(centre+Vector2(cos(a)*size.x*0.5,sin(a)*size.y*0.5)))
	var floor_height := rim-depth
	data.begin_stroke()
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if absf(p.x-centre.x) <= size.x*0.5 and absf(p.y-centre.y) <= size.y*0.5:
			data.heights[i] = minf(data.heights[i],floor_height)
	data.end_stroke()
	editor.force_refresh()
	await settled()
	var spots := 4
	for k in range(spots):
		var along := (k+0.5)/spots-0.5
		editor.flow.kernel.add_water(centre+Vector2(along*size.x*0.7,0.0),minf(size.y,size.x)*0.3,volume/spots)
	editor.flow.run(900)
	await frames(5)
	return floor_height

## Takes the footbridge from the case and drags it from `from` to `to`
## (plate). Returns the ghost states seen during the drag.
func drag_bridge(from: Vector2, to: Vector2) -> Dictionary:
	if materials.held != "bridge": materials.take("bridge")
	await frames(3)
	var start := screen(from)
	var seen := {}
	motion(start,Vector2.ZERO,false)
	await frames(2)
	button(start,true)
	await frames(2)
	var steps := 20
	var last := start
	for k in range(1,steps+1):
		var at := screen(from.lerp(to,float(k)/steps))
		motion(at,at-last)
		last = at
		await frames(1)
		seen[editor.bridges.ghost_state()] = true
	await frames(3)
	button(last,false)
	await frames(3)
	await settled()
	return seen

func run() -> void:
	create_timer(400).timeout.connect(func() -> void: push_error("bridge probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-bridge-probe-%d/places.json" % Time.get_ticks_usec()
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
	check("the editor, the clay, the materials tray and the bridges exist",clay != null and materials != null and editor.get("bridges") != null)
	if clay == null or materials == null or editor.get("bridges") == null:
		quit(1)
		return
	while editor.flow == null or not editor.flow.ready: await process_frame
	await settled()
	var data := editor.data
	var tray: Control = materials.tray
	check("the footbridge has a compartment in the case",tray.discovered("bridge") and not Icons.item("bridge").is_empty())

	# --- A trench across the land, filled with live water ---
	var at := Vector2.INF
	for candidate in [Vector2(-3,0),Vector2(-2,2),Vector2(-4,-2),Vector2(0,-3),Vector2(2,2),Vector2(-1,4)]:
		var s := screen(candidate)
		var spread := absf(height(candidate+Vector2(0,-2.5))-height(candidate+Vector2(0,2.5)))
		if Rect2(Vector2(200,150),Vector2(1040,600)).has_point(s) and reach._land(s) != null and spread < 0.6:
			at = candidate
			break
	check("found a gentle spot in view",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var floor_height := await dig_and_fill(at,Vector2(5.0,1.6),0.5,2.4)
	var depth: float = editor.flow.depth_at(at)
	print("trench at %s, floor %.2f, water %.2f m deep, %.2f m³ on the plate" % [at,floor_height,depth,editor.flow.volume()])
	check("the dug trench holds water",depth > 0.12,depth)
	check("its banks are dry",editor.flow.depth_at(at+Vector2(0,-1.6)) < Footbridge.WET and editor.flow.depth_at(at+Vector2(0,1.6)) < Footbridge.WET)

	# --- A drag across it lays a bridge, bank to bank ---
	var undo0: int = data._undo.size()
	var heights0 := data.heights.duplicate()
	var seen := await drag_bridge(at+Vector2(0.3,-1.5),at+Vector2(-0.2,1.7))
	var laid := bridges_now()
	check("the ghost showed a valid bridge during the drag",seen.has("ok"),seen.keys())
	check("the ghost is gone after",editor.bridges.ghost_state() == "")
	check("one bridge laid",laid.size() == 1,materials.bridge_last)
	if laid.size() != 1:
		print("RESULT FAIL ",failures)
		quit(1)
		return
	var bridge: Dictionary = laid[0]
	var a := Vector2(bridge.x,bridge.z)
	var b := Vector2(bridge.end_x,bridge.end_z)
	print("bridge %s -> %s, %.2f m, ground %.2f / %.2f" % [a,b,a.distance_to(b),height(a),height(b)])
	check("it spans bank to bank across the water",minf(a.y,b.y) < at.y-0.8 and maxf(a.y,b.y) > at.y+0.8,[a,b])
	check("both ends rest on dry ground",editor.flow.depth_at(a) < Footbridge.WET and editor.flow.depth_at(b) < Footbridge.WET)
	# The water's width along the bridge's line, from the live water itself.
	var wet := 0.0
	for k in range(200):
		var p := a.lerp(b,(k+0.5)/200.0)
		if editor.flow.depth_at(p) >= Footbridge.WET: wet += a.distance_to(b)/200.0
	var dragged := (at+Vector2(0.3,-1.5)).distance_to(at+Vector2(-0.2,1.7))
	check("it snapped to the water's edges plus a bank each side, not to the drag's ends",absf(a.distance_to(b)-(wet+2.0*Footbridge.BANK)) < 0.3 and a.distance_to(b) < dragged and a.distance_to(b) <= Footbridge.MAX_SPAN,"span %.2f, water %.2f wide, drag %.2f" % [a.distance_to(b),wet,dragged])
	check("it is one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	check("it moved no ground",data.heights == heights0)
	var node: MeshInstance3D = editor.bridges.node_of(int(bridge.id))
	check("it is drawn under the terrain",node != null and node.mesh != null and node.mesh.get_faces().size() > 300 and node.get_parent().get_parent() == editor.terrain,node.mesh.get_faces().size()/3 if node != null else 0)
	if node != null:
		var box: AABB = node.get_aabb()
		check("its deck stands over the water",box.end.y > float(materials.bridge_last.get("water",INF)),[box.end.y,materials.bridge_last.get("water")])
	var short := a.distance_to(b) < Footbridge.RAILS_FROM
	print("rails: %s" % ("no (short span)" if short else "yes"))
	editor.flow.run(600)
	await frames(5)
	check("the water still stands under it after running on",editor.flow.depth_at(at) > 0.1,editor.flow.depth_at(at))

	# --- Walked on foot: the wanderer crosses on the deck, not through it ---
	var eye: Node = scene.wanderer
	eye._read_obstacles(true)
	eye._read_depths()
	var way := (b-a).normalized()
	var start := a+way*0.2
	eye._feet = eye._clamped(Vector3(start.x,0.0,start.y))
	var lowest := INF
	var arch_y := INF
	var walked := 0
	while Vector2(eye._feet.x,eye._feet.z).distance_to(b) > 0.25 and walked < 400:
		eye._feet = eye._clamped(eye._walk(eye._feet,way*0.03))
		var feet := Vector2(eye._feet.x,eye._feet.z)
		var deck: Dictionary = Footbridge.deck_at(Footbridge.decks(data),feet)
		if not deck.is_empty(): lowest = minf(lowest,eye._feet.y-float(deck.y))
		if absf(feet.distance_to(a)-feet.distance_to(b)) < 0.1: arch_y = eye._feet.y
		walked += 1
	var far := Vector2(eye._feet.x,eye._feet.z).distance_to(b)
	var crown := lerpf(height(a),height(b),0.5)+Footbridge.bow(a.distance_to(b))
	check("the wanderer walks across it to the far bank",far <= 0.25,"%.2f m short after %d steps" % [far,walked])
	check("their feet stay on the planks all the way",lowest > -0.01,lowest)
	check("at mid-span they stand on the arch, over the water",absf(arch_y-crown) < 0.03 and arch_y > float(materials.bridge_last.get("water",INF)),[arch_y,crown])
	check("the deck is dry underfoot (no wading)",eye._depth((a+b)*0.5) == 0.0 and editor.flow.depth_at((a+b)*0.5) > Footbridge.WET)
	if not short:
		var aside: Vector3 = eye._walk(Vector3(((a+b)*0.5).x,crown,((a+b)*0.5).y),Vector2(-way.y,way.x)*0.6)
		check("its rails keep them on it",absf((Vector2(aside.x,aside.z)-a).cross(way)) <= Footbridge.WIDTH*0.5,aside)
	var ground_eye: Vector3 = scene.photo._grounded(editor.terrain.to_global(Vector3(((a+b)*0.5).x,0.0,((a+b)*0.5).y)))
	check("the photo ground eye stands on the deck too",absf(editor.terrain.to_local(ground_eye).y-(crown+scene.photo.EYE_HEIGHT)) < 0.03,editor.terrain.to_local(ground_eye).y)

	# --- Cmd+Z takes it away ---
	var undos0: int = editor.undos
	await cmd_z()
	await settled()
	await frames(4)
	check("Cmd+Z is one undo",editor.undos == undos0+1,editor.undos-undos0)
	check("it takes the bridge away",bridges_now().is_empty())
	check("and its drawing",editor.bridges.count() == 0)
	check("and leaves the trench as dug",data.heights == heights0)

	# --- Dry land: an invalid ghost, nothing laid ---
	var dry := at+Vector2(0,4.5)
	var dry_plan := Footbridge.plan(Footbridge.water(editor),dry+Vector2(0,-1.5),dry+Vector2(0,1.5))
	check("the plan over dry land is refused as dry",not dry_plan.ok and dry_plan.reason == "dry",dry_plan)
	var count0 := data.objects.size()
	seen = await drag_bridge(dry+Vector2(0,-1.5),dry+Vector2(0,1.5))
	check("over dry land the ghost shows invalid",seen.has("no") and not seen.has("ok"),seen.keys())
	check("and nothing is laid",data.objects.size() == count0 and materials.bridge_last.get("reason","") == "dry",materials.bridge_last.get("reason",""))

	# --- A basin too wide to span ---
	# Long across x, clear of the trench, the dry test and the peaks.
	var wide := Vector2(0.0,-6.0)
	await dig_and_fill(wide,Vector2(22.0,3.0),0.5,28.0)
	print("wide basin at %s: %.2f m deep" % [wide,editor.flow.depth_at(wide)])
	check("the wide basin holds water",editor.flow.depth_at(wide) > 0.12,editor.flow.depth_at(wide))
	count0 = data.objects.size()
	var long := editor.place_bridge(wide+Vector2(-2.0,0),wide+Vector2(2.0,0))
	check("a span 22 m across is refused as too long",not long.ok and long.reason == "too_long",long)
	check("and nothing is laid",data.objects.size() == count0)

	# --- Banks too uneven: the far bank raised 2 m ---
	data.begin_stroke()
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if absf(p.x-at.x) <= 2.5 and p.y-at.y >= 1.0 and p.y-at.y <= 3.5: data.heights[i] += 2.0
	data.end_stroke()
	editor.force_refresh()
	await settled()
	var steep := editor.place_bridge(at+Vector2(0,-1.5),at+Vector2(0,1.5))
	check("a span between banks 2 m apart in height is refused as too steep",not steep.ok and steep.reason == "too_steep",steep)
	check("and nothing is laid",data.objects.size() == count0)
	if steep.get("ok",false):
		editor.undo()
		await settled()
	editor.undo()
	await settled()

	# --- The trash can takes it whole, one undo step; undo brings it back ---
	var again := editor.place_bridge(at+Vector2(0,-1.5),at+Vector2(0,1.5))
	check("laid again over the trench",again.get("ok",false),again)
	await settled()
	var id := int(again.get("id",-1))
	materials.put_back()
	materials.select_tool("trash")
	await frames(10)
	check("the trash can is in hand",clay.tool_id == "trash",clay.tool_id)
	var middle: Vector2 = (again.a as Vector2).lerp(again.b,0.5)+Vector2(0.9,0.0)
	var spot := screen(middle)
	var undo1: int = data._undo.size()
	var from := spot+Vector2(-60,0)
	button(from,true)
	await frames(2)
	for k in range(12):
		motion(from+Vector2(10*(k+1),0),Vector2(10,0))
		await frames(1)
	await frames(6)
	button(from+Vector2(120,0),false)
	await settled()
	check("the trash can takes the bridge",bridges_now().is_empty())
	var record := {"asset":"bridge","x":(again.a as Vector2).x,"z":(again.a as Vector2).y,"end_x":(again.b as Vector2).x,"end_z":(again.b as Vector2).y}
	var mid: Vector2 = (again.a as Vector2).lerp(again.b,0.5)
	check("the can measures a bridge by its span, not its foot",Trash.reach_of(record,mid) < 0.05 and (again.a as Vector2).distance_to(mid) > Trash.RADIUS,"foot %.2f m from the middle" % (again.a as Vector2).distance_to(mid))
	check("one undo step",data._undo.size() == undo1+1,data._undo.size()-undo1)
	await frames(40)
	check("its drawing is gone",editor.bridges.count() == 0)
	editor.undo()
	await settled()
	await frames(3)
	check("undo brings it back",bridges_now().size() == 1 and int(bridges_now()[0].id) == id)
	check("drawn again",editor.bridges.node_of(id) != null)

	# --- Save and load ---
	var kept: Dictionary = bridges_now()[0].duplicate(true)
	var text := JSON.stringify(data.to_document())
	var parsed: Variant = JSON.parse_string(text)
	check("the document saves with the bridge's two ends",text.contains("\"end_x\"") and text.contains("\"bridge\""))
	data.begin_stroke()
	data.objects.assign(data.objects.filter(func(item: Dictionary) -> bool: return item.asset != "bridge"))
	data.objects_revision += 1
	data.end_stroke()
	await frames(3)
	check("cleared before loading",bridges_now().is_empty() and editor.bridges.count() == 0)
	check("the saved world loads",data.load_document(parsed))
	editor.refresh()
	await settled()
	await frames(3)
	var back := bridges_now()
	check("the bridge comes back the same",back.size() == 1 and int(back[0].id) == id and is_equal_approx(float(back[0].end_x),float(kept.end_x)) and is_equal_approx(float(back[0].end_z),float(kept.end_z)) and is_equal_approx(float(back[0].x),float(kept.x)),back)
	check("and is drawn",editor.bridges.node_of(id) != null)
	var broken: Dictionary = (JSON.parse_string(text) as Dictionary)
	for item: Dictionary in broken.objects:
		if item.asset == "bridge": item.erase("end_x")
	check("a saved bridge with no far end is refused",not data.load_document(broken))

	await mountains()
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

## Raises the ground in `box` (plate) to a flat top `top` m high, as one stroke.
func plateau(box: Rect2, top: float) -> void:
	var data := editor.data
	data.begin_stroke()
	for i in range(data.points.size()):
		if box.has_point(data.points[i]): data.heights[i] = top
	data.end_stroke()
	editor.force_refresh()
	await settled()

## Bridges over a gap in the land: two flat peaks 8 m apart take a rope
## bridge from rim to rim, walked across on its sag; a peak with no level
## top takes none; a short dry ravine takes a timber one.
func mountains() -> void:
	var data := editor.data
	var c := Vector2(0.0,9.5)
	var top := -INF
	for x in range(-8,9):
		for z in range(-2,3): top = maxf(top,height(c+Vector2(x,z)))
	top += 2.5
	await plateau(Rect2(c+Vector2(-7.0,-1.5),Vector2(3.0,3.0)),top)
	await plateau(Rect2(c+Vector2(4.0,-1.5),Vector2(3.0,3.0)),top)
	var west := c+Vector2(-5.5,0.0)
	var east := c+Vector2(5.5,0.0)
	print("peaks at %.2f m, gap floor about %.2f m" % [top,height(c)])
	var count0 := data.objects.size()
	var found := editor.place_bridge(west,east)
	check("a drag from peak to peak lays a bridge across the gap",found.get("ok",false) and found.get("gap",false),found)
	if not found.get("ok",false): return
	var a: Vector2 = found.a
	var b: Vector2 = found.b
	var span := a.distance_to(b)
	# Within a metre of each rim (the heightfield's last raised row stands a
	# little back from the plateau's drawn edge), not back where the drag began.
	check("its ends stand at the rims, on the peaks",a.x <= c.x-4.0 and a.x >= c.x-5.0 and b.x >= c.x+4.0 and b.x <= c.x+5.0 and absf(height(a)-top) < 0.05 and absf(height(b)-top) < 0.05,[a,b])
	check("past six metres it is a rope bridge",Footbridge.roped(span) and span <= Footbridge.MAX_SPAN,span)
	check("one record, drawn",data.objects.size() == count0+1 and editor.bridges.node_of(int(found.id)) != null)
	var middle := a.lerp(b,0.5)
	var deck: Dictionary = Footbridge.deck_at(Footbridge.decks(data),middle)
	var sagged := top-Footbridge.sag(span)
	check("its deck sags at mid-span, high over the gap",not deck.is_empty() and absf(float(deck.y)-sagged) < 0.03 and float(deck.y)-height(middle) > 1.5,[deck.get("y"),sagged,height(middle)])
	var eye: Node = scene.wanderer
	eye._read_obstacles(true)
	eye._read_depths()
	var way := (b-a).normalized()
	eye._feet = eye._clamped(Vector3(a.x,0.0,a.y))
	var lowest := INF
	var steps := 0
	while Vector2(eye._feet.x,eye._feet.z).distance_to(b) > 0.25 and steps < 600:
		eye._feet = eye._clamped(eye._walk(eye._feet,way*0.03))
		var under: Dictionary = Footbridge.deck_at(Footbridge.decks(data),Vector2(eye._feet.x,eye._feet.z))
		if not under.is_empty(): lowest = minf(lowest,eye._feet.y-float(under.y))
		steps += 1
	check("the wanderer walks it from peak to peak, on the planks",Vector2(eye._feet.x,eye._feet.z).distance_to(b) <= 0.25 and lowest > -0.01,[Vector2(eye._feet.x,eye._feet.z).distance_to(b),lowest])
	editor.undo()
	await settled()
	# A peak with no level top: one end on a steep slope.
	data.begin_stroke()
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if Rect2(c+Vector2(4.0,-1.5),Vector2(3.0,3.0)).has_point(p): data.heights[i] = top+(p.x-(c.x+4.0))*0.8
	data.end_stroke()
	editor.force_refresh()
	await settled()
	count0 = data.objects.size()
	var steep := editor.place_bridge(west,east)
	check("with no level ground for an end, nothing is laid",not steep.ok and steep.reason == "no_footing" and data.objects.size() == count0,steep)
	# A short dry ravine: a timber bridge.
	await plateau(Rect2(c+Vector2(4.0,-1.5),Vector2(3.0,3.0)),top)
	await plateau(Rect2(c+Vector2(-4.0,-1.5),Vector2(5.0,3.0)),top)
	var short := editor.place_bridge(c+Vector2(-0.5,0.0),c+Vector2(5.5,0.0))
	check("a ravine 3 m across takes a timber arch",short.get("ok",false) and short.get("gap",false) and not Footbridge.roped(float(short.get("span",0.0))),short)

