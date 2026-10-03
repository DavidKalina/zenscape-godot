extends SceneTree
## Headless probe of the stone lamps (docs/scenic/stone-lamps.md;
## scripts/stone_lamp.gd, scripts/stone_lamp_lights.gd) on the real cozy
## worlds scene, driven by synthesized input through hand_reach. Checks:
## - the tray has a "lamp" compartment; taking it puts a lamp in hand;
## - a tap sets one lamp (asset "stone_lamp"), drawn by GardenView, one undo
##   step; undo takes it away;
## - a drag sets a spaced row along it, one undo step, no two too close;
## - night from the world clock: at midnight the lamps glow and the nearest
##   (at most MAX_LIGHTS) have real lights; at noon all is dark again;
## - more lamps than lights: still only MAX_LIGHTS real lights;
## - save round trip: the world's document, through JSON, loads with the
##   lamps back and lit;
## - the trash can sweeps the row away, lights and all; undo brings it back.
## Whether it looks right (the glow, the light on the ground) needs a
## rendered run; headless only proves the logic.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_stone_lamps.gd -- --modeless --no-title
const Lights = preload("res://scripts/stone_lamp_lights.gd")
const Lamp = preload("res://scripts/stone_lamp.gd")

var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var lamps: Node
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

func bare(at: Vector2) -> bool:
	return reach.reach_at(at) == "" and reach._land(at) != null and not reach._prop_at(at)

## The lamp records now, by id.
func lamp_ids() -> Array:
	var out := []
	for item: Dictionary in editor.data.objects:
		if str(item.asset) == "stone_lamp": out.append(int(item.id))
	out.sort()
	return out

## How many lamp instances GardenView draws.
func drawn() -> int:
	var sources: Array = editor.content._sources.get("stone_lamp",[])
	return sources.size()

## Moves the world clock to `hour` and waits out the glow's fade.
func at_hour(hour: float) -> void:
	scene.world_clock.set_time(scene.world_clock.day,hour)
	await create_timer(Lights.FADE_SECONDS+1.0).timeout
	await frames(5)

func take(id: String) -> void:
	for i in range(120):
		if materials.tray.shown > 0.99: break
		await process_frame
	# The case fans a group out under a resting pointer (scripts/materials_tray.gd).
	materials.tray.pointer_override = materials.tray.compartment_centre(id)
	for i in range(120):
		if materials.tray.showing(id): break
		await process_frame
	await click(materials.tray.specimen_centre(id))
	materials.tray.pointer_override = null
	await frames(10)

## Drags with the material in hand from plate `a` to `b`. Headless has no
## mouse, so the pointer the hand reads is overridden as it goes.
func drag(a: Vector2, b: Vector2) -> void:
	var from := screen(a)
	reach.pointer_override = from
	button(from,true)
	await frames(2)
	var steps := 60
	var last := from
	for k in range(1,steps+1):
		var at := screen(a.lerp(b,float(k)/steps))
		reach.pointer_override = at
		motion(at,at-last)
		last = at
		await frames(3)
	button(last,false)
	await frames(4)
	reach.pointer_override = null
	await settled()

func run() -> void:
	create_timer(400).timeout.connect(func() -> void: push_error("stone lamp probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-lamp-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	materials = reach.get("materials")
	lamps = editor.get("lamps")
	scene.world_clock.running = false
	check("land clay, the tray and the lamps' lights exist",clay != null and materials != null and lamps != null)
	if clay == null or materials == null or lamps == null:
		quit(1)
		return
	await settled()
	var data := editor.data
	check("stone_lamp is a placeable asset that the drop reactions settle","stone_lamp" in NativeTerrainData.ASSETS and NativeDropReactions.REACTIONS.get("stone_lamp") == "settle")
	check("its mesh is faceted stone, about a metre tall",Lamp.mesh().get_aabb().size.y > 0.9 and Lamp.mesh().get_aabb().size.y < 1.2,Lamp.mesh().get_aabb())

	# A clear line of land, seen from the camera.
	var line := []
	for candidate in [[Vector2(-5,2),Vector2(4,2)],[Vector2(-5,-2),Vector2(4,-2)],[Vector2(-5,5),Vector2(4,5)],[Vector2(-4,-5),Vector2(5,-5)],[Vector2(-6,0),Vector2(3,0)]]:
		var ok := true
		for k in range(11):
			var p: Vector2 = candidate[0].lerp(candidate[1],k/10.0)
			if not bare(screen(p)) or data.ground_height(p) == null: ok = false
		if ok:
			line = candidate
			break
	check("found a clear line of land",not line.is_empty(),line)
	if line.is_empty():
		quit(1)
		return

	# --- The tray slot, and a tap ---
	await take("lamp")
	check("the case has a lamp compartment and it is in hand",materials.held == "lamp",materials.held)
	var tap: Vector2 = line[0].lerp(line[1],0.5)
	var undo0: int = data._undo.size()
	await click(screen(tap))
	await settled()
	var one := lamp_ids()
	check("a tap sets one stone lamp",one.size() == 1,one)
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	check("GardenView draws it",drawn() == 1,drawn())
	await frames(40)
	check("the lights see it",lamps.lamps.size() == 1,lamps.lamps.size())
	editor.undo()
	await settled()
	await frames(40)
	check("undo takes it away, glow and all",lamp_ids().is_empty() and lamps.lamps.is_empty() and drawn() == 0,[lamp_ids(),lamps.lamps.size()])

	# --- A drag lines a path ---
	undo0 = data._undo.size()
	await drag(line[0],line[1])
	var row := lamp_ids()
	check("a drag sets a row of lamps along it",row.size() >= 3,row.size())
	check("the row is one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	var closest := INF
	var off_line := 0.0
	for i in range(row.size()):
		var a := data.object_by_id(row[i])
		var pa := Vector2(float(a.x),float(a.z))
		off_line = maxf(off_line,pa.distance_to(Geometry2D.get_closest_point_to_segment(pa,line[0],line[1])))
		for j in range(i+1,row.size()):
			var b := data.object_by_id(row[j])
			closest = minf(closest,pa.distance_to(Vector2(float(b.x),float(b.z))))
	check("spaced like a path (closest pair %.2f m)" % closest,closest >= 1.1,closest)
	check("and along the drag (furthest %.2f m off it)" % off_line,off_line < 0.6,off_line)

	# --- Refusals: a tap that sets nothing says why ---
	var first := data.object_by_id(row[0])
	var crowd := Vector2(float(first.x),float(first.z))+Vector2(0.0,0.5)
	undo0 = data._undo.size()
	await click(screen(crowd))
	await settled()
	check("a tap beside a lamp is refused (reason 'near'), nothing set, no undo step",lamp_ids() == row and materials.lamp_refused == "near" and data._undo.size() == undo0,[lamp_ids().size(),materials.lamp_refused])
	check("and the hint line says so",reach._hint == materials.LAMP_REFUSALS["near"],reach._hint)
	# Water: some in view, or live water stood on a clear spot off the row
	# (the campfire probe's way).
	var dry: Callable = editor.fence_dry()
	var wet: Variant = null
	var clear: Variant = null
	for x in range(-9,10):
		for z in range(-9,10):
			var p := Vector2(x,z)
			if data.ground_height(p) == null or reach._land(screen(p)) == null or reach.reach_at(screen(p)) != "": continue
			if wet == null and not dry.call(p): wet = p
			if clear == null and bare(screen(p)) and Geometry2D.get_closest_point_to_segment(p,line[0],line[1]).distance_to(p) > 3.0: clear = p
	if wet == null and clear != null and editor.flow != null and editor.flow.ready:
		var flow: RefCounted = editor.flow
		var depth: PackedFloat32Array = flow.kernel.get_depth()
		for dx in range(-8,9):
			for dz in range(-8,9):
				var q: Vector2 = clear+Vector2(dx,dz)*0.25
				var cell: int = flow.cell_at(q)
				if q.distance_to(clear) <= 2.0 and cell >= 0 and cell < depth.size(): depth[cell] = 0.4
		flow.kernel.set_depth(depth)
		await frames(3)
		wet = clear
	if wet != null:
		undo0 = data._undo.size()
		await click(screen(wet))
		await settled()
		check("a tap on water is refused (reason 'water'), nothing set, no undo step",lamp_ids() == row and materials.lamp_refused == "water" and data._undo.size() == undo0,[lamp_ids().size(),materials.lamp_refused,wet])
		check("and the hint line says so",reach._hint == materials.LAMP_REFUSALS["water"],reach._hint)
	else:
		check("found water in view to refuse on",false,"no water on this world")
	materials.put_back()
	await frames(30)

	# --- Dusk and dawn ---
	await at_hour(12.0)
	check("at noon they are dark: no glow, no light",lamps.glow < 0.01 and lamps.lit().is_empty() and not lamps.halos.visible,[lamps.glow,lamps.lit()])
	await at_hour(0.0)
	var lit: Dictionary = lamps.lit()
	check("at midnight they glow (glow %.2f)" % lamps.glow,lamps.glow > 0.95 and lamps.halos.visible,lamps.glow)
	check("and every lamp of the row has a real light",lit.size() == mini(row.size(),Lights.MAX_LIGHTS) and row.all(func(id: int) -> bool: return lit.has(id) or lit.size() == Lights.MAX_LIGHTS),[lit.keys(),row])
	var light: OmniLight3D = lamps.slots[0].light
	check("lights are warm, shadowless and placed in a fire box",not light.shadow_enabled and light.light_color.r > light.light_color.b and light.omni_range > 1.0,[light.light_color,light.omni_range])
	await at_hour(6.5)
	var dawn: float = lamps.glow
	await at_hour(9.0)
	check("they go out with the morning (glow %.2f at 06:30, %.2f at 09:00)" % [dawn,lamps.glow],lamps.glow < 0.01 and lamps.lit().is_empty(),[dawn,lamps.glow])
	await at_hour(17.5)
	var dusk: float = lamps.glow
	await at_hour(21.0)
	check("and come up at dusk (%.2f at 17:30, %.2f at 21:00)" % [dusk,lamps.glow],lamps.glow > 0.95 and dusk < lamps.glow,[dusk,lamps.glow])

	# --- More lamps than lights ---
	data.begin_stroke()
	var extra := []
	for k in range(14):
		var p := Vector2(-6.0+k*0.9,line[0].y+1.6)
		if data.ground_height(p) != null:
			var id := data.place("stone_lamp",p)
			if id >= 0: extra.append(id)
	data.end_stroke()
	editor.force_refresh()
	await settled()
	await frames(60)
	check("with %d lamps, at most %d real lights" % [lamp_ids().size(),Lights.MAX_LIGHTS],lamp_ids().size() > Lights.MAX_LIGHTS and lamps.lit().size() == Lights.MAX_LIGHTS,[lamp_ids().size(),lamps.lit().size()])
	check("every lamp still has a glowing core",lamps.cores.multimesh.instance_count == lamp_ids().size(),lamps.cores.multimesh.instance_count)
	editor.undo()
	await settled()
	await frames(40)
	check("undo takes the extra lamps away",lamp_ids() == row,[lamp_ids().size(),row.size()])

	# --- Save round trip ---
	var saved: Variant = JSON.parse_string(JSON.stringify(data.to_document()))
	data.objects.assign(data.objects.filter(func(item: Dictionary) -> bool: return str(item.asset) != "stone_lamp"))
	data.objects_revision += 1
	editor.force_refresh()
	await settled()
	await frames(40)
	check("cleared for the load",lamp_ids().is_empty() and lamps.lamps.is_empty())
	check("the saved world loads",data.load_document(saved))
	editor.refresh()
	await settled()
	await frames(80)
	check("the lamps come back from the save, same ids",lamp_ids() == row,[lamp_ids(),row])
	check("drawn and lit again",drawn() == row.size() and lamps.lit().size() == mini(row.size(),Lights.MAX_LIGHTS),[drawn(),lamps.lit().size()])

	# --- The trash can ---
	for i in range(120):
		if materials.roll.shown > 0.99: break
		await process_frame
	var pocket: Vector2 = materials.roll._cell(materials.roll.TOOLS.find("trash")).get_center()
	await click(pocket)
	await frames(30)
	check("the trash can is in hand",clay.tool_id == "trash",clay.tool_id)
	undo0 = data._undo.size()
	var from := screen(line[0]-(line[1]-line[0]).normalized()*0.8)
	button(from,true)
	await frames(2)
	var last := from
	for k in range(1,61):
		var at := screen((line[0]-(line[1]-line[0]).normalized()*0.8).lerp(line[1]+(line[1]-line[0]).normalized()*0.8,k/60.0))
		motion(at,at-last)
		last = at
		await frames(2)
	button(last,false)
	await settled()
	await frames(60)
	check("the trash sweeps the row away",lamp_ids().is_empty(),lamp_ids())
	check("their glow and lights go with them",lamps.lamps.is_empty() and lamps.lit().is_empty() and lamps.cores.multimesh.instance_count == 0)
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	editor.undo()
	await settled()
	await frames(60)
	check("undo brings the row back, lit",lamp_ids() == row and lamps.lit().size() == mini(row.size(),Lights.MAX_LIGHTS),[lamp_ids().size(),lamps.lit().size()])

	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
