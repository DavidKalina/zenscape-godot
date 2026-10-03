extends SceneTree
## Headless probe of the campfire (docs/scenic/campfire.md; scripts/campfire.gd,
## scripts/campfire_fire.gd) on the real cozy worlds scene, driven by
## synthesized input through hand_reach. Checks:
## - the tray has a "campfire" compartment; a tap sets one campfire (asset
##   "campfire"), drawn by GardenView, flames laid, one undo step; undo takes
##   it away, fire and all;
## - refusals: on water, too near another campfire, under a tree (nothing
##   set, the hint line says why), and steep ground (Campfire `refusal`);
## - light: at midnight the fire has a real light from the lamps' shared
##   pool, smaller by day; with many fires and lamps, never more than the
##   pool's MAX_LIGHTS; the flicker is gentle; rain dims it;
## - no wildfire: a tree beside a burning campfire stays a tree, the
##   FireField never lights;
## - save round trip through JSON; the trash can takes it, undo brings it back.
## Whether it looks right (the flame, glow, smoke, sparks, the light on the
## ground) needs a rendered run; headless only proves the logic.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_campfire.gd -- --modeless --no-title
const Campfire = preload("res://scripts/campfire.gd")
const Fire = preload("res://scripts/campfire_fire.gd")
const Lights = preload("res://scripts/stone_lamp_lights.gd")

var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var fire: Node
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

## A tap with the material in hand at plate point `p`.
func tap(p: Vector2) -> void:
	var at := screen(p)
	reach.pointer_override = at
	await click(at)
	reach.pointer_override = null
	await settled()

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

func fire_ids() -> Array:
	var out := []
	for item: Dictionary in editor.data.objects:
		if str(item.asset) == "campfire": out.append(int(item.id))
	out.sort()
	return out

func drawn() -> int:
	return (editor.content._sources.get("campfire",[]) as Array).size()

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

## The real light on fire `id` now (0 for none).
func light_on(id: int) -> float:
	return float(lamps.lit().get(id,0.0))

func run() -> void:
	create_timer(500).timeout.connect(func() -> void: push_error("campfire probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-campfire-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	materials = reach.get("materials")
	fire = editor.get("campfires")
	lamps = editor.get("lamps")
	scene.world_clock.running = false
	check("land clay, the tray, the campfires' fire and the lamps' light pool exist",clay != null and materials != null and fire != null and lamps != null)
	if clay == null or materials == null or fire == null or lamps == null:
		quit(1)
		return
	await settled()
	var data := editor.data
	check("campfire is a placeable asset that the drop reactions settle","campfire" in NativeTerrainData.ASSETS and NativeDropReactions.REACTIONS.get("campfire") == "settle")
	check("the wildfire takes it as inert: it neither burns nor spreads",FireField.group_of("campfire") == "inert")
	var box := Campfire.mesh().get_aabb()
	check("its mesh is a low faceted ring about a metre across",box.size.x > 0.9 and box.size.x < 1.3 and box.size.y < 0.6,box)

	# Spots: a clear dry flat one in view, and one on water.
	var spot: Variant = null
	var wet: Variant = null
	var steep: Variant = null
	for x in range(-9,10):
		for z in range(-9,10):
			var p := Vector2(x,z)
			var why := Campfire.refusal(editor,p)
			var seen := bare(screen(p))
			if why == "" and seen and spot == null and p.length() < 6.0: spot = p
			if why == "water" and wet == null and data.ground_height(p) != null and reach._land(screen(p)) != null and reach.reach_at(screen(p)) == "": wet = p
			if why == "steep" and steep == null: steep = p
	check("found a clear flat dry spot in view",spot != null,spot)
	if spot == null:
		quit(1)
		return
	# A second clear spot, away from the first, to flood if the world has no
	# water in view.
	var other: Variant = null
	for x in range(-9,10):
		for z in range(-9,10):
			var p := Vector2(x,z)
			if other == null and p.distance_to(spot) > 6.0 and Campfire.refusal(editor,p) == "" and bare(screen(p)): other = p
	print("spot ",spot," water ",wet," other ",other," steep ",steep)

	# --- The tray slot, and a tap ---
	await take("campfire")
	check("the case has a campfire compartment and it is in hand",materials.held == "campfire",materials.held)
	var undo0: int = data._undo.size()
	await tap(spot)
	var one := fire_ids()
	check("a tap sets one campfire",one.size() == 1,one)
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	check("GardenView draws it",drawn() == 1,drawn())
	await frames(40)
	check("its fire is laid: %d tongues of flame, a glow" % fire.flames.multimesh.instance_count,fire.fires.size() == 1 and fire.flames.multimesh.instance_count == Fire.FLAME_TONGUES.size() and fire.halos.multimesh.instance_count == 1 and fire.flames.visible)
	await frames(120)
	check("it smokes and sparks a little (%d puffs, %d sparks)" % [fire.puffs.size(),fire.embers.size()],fire.puffs.size() > 0 and fire.embers.size() > 0 and fire.puffs.size() <= Fire.SMOKE_CAP and fire.embers.size() <= Fire.SPARK_CAP)
	editor.undo()
	await settled()
	await frames(40)
	check("undo takes it away, fire and all",fire_ids().is_empty() and fire.fires.is_empty() and drawn() == 0 and fire.flames.multimesh.instance_count == 0,[fire_ids(),fire.fires.size()])

	# --- Refusals ---
	if wet == null and other != null and editor.flow != null and editor.flow.ready:
		# Live water stood on the other spot (the fence probe's way): the
		# kernel's depth set over a disc of it, tapped before it runs off.
		var flow: RefCounted = editor.flow
		var depth: PackedFloat32Array = flow.kernel.get_depth()
		for dx in range(-8,9):
			for dz in range(-8,9):
				var q: Vector2 = other+Vector2(dx,dz)*0.25
				var cell: int = flow.cell_at(q)
				if q.distance_to(other) <= 2.0 and cell >= 0 and cell < depth.size(): depth[cell] = 0.4
		flow.kernel.set_depth(depth)
		await frames(3)
		wet = other
		print("flooded ",other," depth ",flow.depth_at(other))
	if wet != null:
		undo0 = data._undo.size()
		await tap(wet)
		check("on water: refused (reason 'water'), nothing set, no undo step",fire_ids().is_empty() and materials.campfire_refused == "water" and data._undo.size() == undo0,[fire_ids(),materials.campfire_refused])
	else:
		check("found water in view to refuse on",false,"no water on this world")
	await tap(spot)
	var first := fire_ids()
	check("set again on the clear spot",first.size() == 1,first)
	await tap(spot+Vector2(1.2,0.4))
	check("too near another: refused",fire_ids() == first and materials.campfire_refused == "near",[fire_ids(),materials.campfire_refused])
	# The refusal's line is a notice: with the day clock running (the hover
	# reads afresh as the sun moves) it is still there two seconds on.
	var said: String = materials.CAMPFIRE_REFUSALS["near"]
	check("the hint line says why",reach._hint == said,reach._hint)
	scene.world_clock.running = true
	var phase0 := float(scene._celestial.phase)
	await create_timer(2.0).timeout
	check("two seconds on, with the clock running, it still says why",reach._hint == said,[reach._hint,float(scene._celestial.phase)-phase0])
	await create_timer(materials.reach.NOTICE_SECONDS).timeout
	check("and in time it goes",reach._hint != said,reach._hint)
	scene.world_clock.running = false
	if steep != null: check("steep ground is refused",Campfire.refusal(editor,steep) == "steep",steep)
	else: print("(no steep ground on this world to test)")
	# A tree beside the spot: a fire under it is refused.
	var tree_at: Vector2 = spot+Vector2(4.0,0.0)
	var tree_id := data.place("tree",tree_at,0.0,1.0)
	data.objects_revision += 1
	check("under a tree: refused (%s)" % Campfire.refusal(editor,tree_at+Vector2(0.8,0.0)),tree_id >= 0 and Campfire.refusal(editor,tree_at+Vector2(0.8,0.0)) == "tree",tree_id)
	materials.put_back()
	await frames(30)

	# --- Light ---
	var id: int = first[0]
	await at_hour(0.0)
	var night_light := light_on(id)
	check("at midnight it has a real light from the shared pool (%.2f)" % night_light,night_light > 0.5)
	var light: OmniLight3D = null
	for slot in lamps.slots:
		if int(slot.id) == id: light = slot.light
	check("warm, shadowless, reaching a few metres",light != null and not light.shadow_enabled and light.light_color.r > light.light_color.b and light.omni_range > 3.0,[light.light_color if light else null,light.omni_range if light else 0.0])
	# The flicker: gentle, no frame jumps, never near dark.
	var low := INF
	var high := 0.0
	var jump := 0.0
	var last: float = fire.energy(id)
	for k in range(180):
		await process_frame
		var now: float = fire.energy(id)
		low = minf(low,now)
		high = maxf(high,now)
		jump = maxf(jump,absf(now-last)/maxf(last,0.001))
		last = now
	check("the flicker is gentle (%.2f..%.2f, at most %.1f%% a frame)" % [low,high,jump*100.0],high > low and low/high > 0.65 and jump < 0.05,[low,high,jump])
	fire.rain_override = 1.0
	var dry_tongue: float = fire.tall
	await create_timer(Fire.RAIN_SECONDS+1.0).timeout
	var wet_light: float = fire.energy(id)/Fire.flicker(fire._by_id[id].phase,fire._clock)
	var wet_tongue: float = fire.tall
	check("rain dims it: light %.2f -> %.2f, flames %.2f -> %.2f of their height" % [Fire.NIGHT_ENERGY,wet_light,dry_tongue,wet_tongue],wet_light < Fire.NIGHT_ENERGY*0.6 and wet_tongue < dry_tongue*0.7)
	fire.rain_override = 0.0
	await create_timer(Fire.RAIN_SECONDS+1.0).timeout
	fire.rain_override = -1.0
	await at_hour(12.0)
	var day_light := light_on(id)
	check("by day a smaller light (%.2f, night %.2f)" % [day_light,night_light],day_light > 0.0 and day_light < night_light*0.5)

	# --- Many fires and lamps: the cap ---
	await at_hour(0.0)
	data.begin_stroke()
	var extra := 0
	for k in range(16):
		var p := Vector2(-8.0+(k%8)*2.2,-7.0+int(k/8)*12.0)
		if data.ground_height(p) != null:
			if data.place("campfire" if k%2 == 0 else "stone_lamp",p) >= 0: extra += 1
	data.end_stroke()
	editor.force_refresh()
	await settled()
	await frames(90)
	var lit: Dictionary = lamps.lit()
	check("with %d fires and lamps, at most %d real lights (%d lit)" % [fire.fires.size()+lamps.lamps.size(),Lights.MAX_LIGHTS,lit.size()],fire.fires.size()+lamps.lamps.size() > Lights.MAX_LIGHTS and lit.size() == Lights.MAX_LIGHTS)
	check("every fire still has its flames in one batch",fire.flames.multimesh.instance_count == fire.fires.size()*Fire.FLAME_TONGUES.size(),fire.flames.multimesh.instance_count)
	check("only the nearest %d smoke and spark" % Fire.ACTIVE_FIRES,fire.active.size() == mini(Fire.ACTIVE_FIRES,fire.fires.size()) and fire.puffs.size() <= Fire.SMOKE_CAP and fire.embers.size() <= Fire.SPARK_CAP,[fire.active.size(),fire.puffs.size(),fire.embers.size()])
	editor.undo()
	await settled()
	await frames(40)
	check("undo takes the extras away",fire_ids() == first and lamps.lamps.is_empty(),[fire_ids(),lamps.lamps.size()])

	# --- No wildfire ---
	var near_tree: Vector2 = Vector2(data.object_by_id(id).x,data.object_by_id(id).z)+Vector2(0.0,2.2)
	var neighbour := data.place("broadleaf",near_tree,0.0,1.0)
	data.objects_revision += 1
	editor.force_refresh()
	await settled()
	await create_timer(25.0).timeout
	var field: Variant = scene.get("_fire_field")
	var calm: bool = field == null or (not field.active() and field.burning_objects().is_empty())
	check("25 s beside a burning campfire: no wildfire (field %s)" % ("absent" if field == null else "quiet" if calm else "ALIGHT"),calm)
	check("and the trees beside it are still trees",data.object_by_id(neighbour).get("asset") == "broadleaf" and data.object_by_id(tree_id).get("asset") == "tree")

	# --- Save round trip ---
	var saved: Variant = JSON.parse_string(JSON.stringify(data.to_document()))
	data.objects.assign(data.objects.filter(func(item: Dictionary) -> bool: return str(item.asset) != "campfire"))
	data.objects_revision += 1
	editor.force_refresh()
	await settled()
	await frames(40)
	check("cleared for the load",fire_ids().is_empty() and fire.fires.is_empty() and light_on(id) == 0.0)
	check("the saved world loads",data.load_document(saved))
	editor.refresh()
	await settled()
	await frames(80)
	check("the campfire comes back from the save, same id, burning and lit",fire_ids() == first and drawn() == 1 and fire.fires.size() == 1 and light_on(id) > 0.0,[fire_ids(),drawn(),light_on(id)])

	# --- The trash can ---
	for i in range(120):
		if materials.roll.shown > 0.99: break
		await process_frame
	await click(materials.roll._cell(materials.roll.TOOLS.find("trash")).get_center())
	await frames(30)
	check("the trash can is in hand",clay.tool_id == "trash",clay.tool_id)
	undo0 = data._undo.size()
	var foot := Vector2(data.object_by_id(id).x,data.object_by_id(id).z)
	var a := screen(foot+Vector2(-1.0,0.0))
	var b := screen(foot+Vector2(1.0,0.0))
	button(a,true)
	await frames(2)
	var was := a
	for k in range(1,31):
		var at := a.lerp(b,k/30.0)
		motion(at,at-was)
		was = at
		await frames(2)
	button(was,false)
	await settled()
	await frames(60)
	check("the trash takes it",fire_ids().is_empty(),fire_ids())
	check("its fire and light go with it",fire.fires.is_empty() and light_on(id) == 0.0 and fire.flames.multimesh.instance_count == 0)
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	editor.undo()
	await settled()
	await frames(60)
	check("undo brings it back, burning and lit",fire_ids() == first and fire.fires.size() == 1 and light_on(id) > 0.0,[fire_ids(),light_on(id)])

	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
