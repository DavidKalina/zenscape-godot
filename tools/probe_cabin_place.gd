extends SceneTree
## Headless probe of the placeable cabin (docs/scenic/cabin.md;
## scripts/cabin.gd, scripts/cabin_lights.gd) on the real cozy worlds scene,
## driven by synthesized input through hand_reach. Checks:
## - the cabin is a placeable asset; its mesh keeps to the size budget
##   (footprint at most 3.2 x 3.4 m, chimney top under 3.2 m);
## - the tray has a "cabin" compartment; a tap on a flat plain sets one
##   cabin (asset "cabin"), drawn by GardenView, one undo step, its door
##   (+Z) facing down the slope or toward the camera; undo takes it away;
## - refusals (nothing set, no undo step, the hint's reason): on a slope
##   ("steep"), in water ("water"), in a wood ("tree"), beside another cabin
##   ("near");
## - night: at midnight its window pane glows and it has a real light from
##   the lamps' shared pool; by day neither; with many cabins and lamps, never
##   more than the pool's MAX_LIGHTS; a thin chimney smoke within its cap;
## - save round trip through JSON; the trash can takes it in one undo step
##   (swept over its roof, not just its middle), undo brings it back.
## Whether it looks right (the model on the land, the window glow, the
## smoke) needs a rendered run; headless only proves the logic.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_cabin_place.gd -- --modeless --no-title
const Cabin = preload("res://scripts/cabin.gd")
const CabinLights = preload("res://scripts/cabin_lights.gd")
const Lights = preload("res://scripts/stone_lamp_lights.gd")

var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var cabins: Node
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

## The camera, plate space.
func eye() -> Vector2:
	var local: Vector3 = editor.terrain.to_local(scene.camera.global_position)
	return Vector2(local.x,local.z)

## Why a cabin would be refused at `p`, facing as the hand would turn it.
func why(p: Vector2) -> String:
	return Cabin.refusal(editor,p,Cabin.facing(editor.data,p,eye()))

func cabin_ids() -> Array:
	var out := []
	for item: Dictionary in editor.data.objects:
		if str(item.asset) == "cabin": out.append(int(item.id))
	out.sort()
	return out

func drawn() -> int:
	return (editor.content._sources.get("cabin",[]) as Array).size()

func at_hour(hour: float) -> void:
	scene.world_clock.set_time(scene.world_clock.day,hour)
	await create_timer(Lights.FADE_SECONDS+1.0).timeout
	await frames(5)

func take(id: String) -> void:
	for i in range(120):
		if materials.tray.shown > 0.99: break
		await process_frame
	await click(materials.tray.specimen_centre(id))
	await frames(10)

func light_on(id: int) -> float:
	return float(lamps.lit().get(id,0.0))

func run() -> void:
	create_timer(500).timeout.connect(func() -> void: push_error("cabin probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-cabin-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	materials = reach.get("materials")
	cabins = editor.get("cabins")
	lamps = editor.get("lamps")
	scene.world_clock.running = false
	check("land clay, the tray, the cabins' windows and the lamps' light pool exist",clay != null and materials != null and cabins != null and lamps != null)
	if clay == null or materials == null or cabins == null or lamps == null:
		quit(1)
		return
	await settled()
	var data := editor.data
	check("cabin is a placeable asset that the drop reactions settle","cabin" in NativeTerrainData.ASSETS and NativeDropReactions.REACTIONS.get("cabin") == "settle")
	check("the wildfire takes it as inert",FireField.group_of("cabin") == "inert")
	var box: AABB = Cabin.info().box
	var foot := Cabin.footprint()
	check("a small cabin: footprint %.2f x %.2f m, chimney top %.2f m" % [foot.size.x,foot.size.y,box.end.y],foot.size.x <= 3.2 and foot.size.y <= 3.4 and box.end.y < 3.2 and box.end.y > 2.4,[foot,box])
	var pane: AABB = Cabin.info().pane
	check("the window glass is found in the model (%s)" % pane,pane.size.y > 0.2 and pane.size.z > 0.3)

	# Spots: a clear flat one in view, and a steep one, a wet one.
	var spot: Variant = null
	var steep: Variant = null
	var wet: Variant = null
	var other: Variant = null
	for x in range(-10,11):
		for z in range(-10,11):
			var p := Vector2(x,z)
			var reason := why(p)
			var seen := bare(screen(p))
			if reason == "" and seen and spot == null and p.length() < 7.0: spot = p
			if reason == "steep" and seen and steep == null: steep = p
			if reason == "water" and wet == null and data.ground_height(p) != null and reach._land(screen(p)) != null and reach.reach_at(screen(p)) == "": wet = p
	check("found a clear flat dry spot in view",spot != null,spot)
	if spot == null:
		quit(1)
		return
	for x in range(-10,11):
		for z in range(-10,11):
			var p := Vector2(x,z)
			if other == null and p.distance_to(spot) > 7.0 and why(p) == "" and bare(screen(p)): other = p
	print("spot ",spot," steep ",steep," water ",wet," other ",other)

	# --- The tray slot, and a tap on the plain ---
	await take("cabin")
	check("the case has a cabin compartment and it is in hand",materials.held == "cabin",materials.held)
	var undo0: int = data._undo.size()
	var expected := Cabin.facing(data,spot,eye())
	await tap(spot)
	var one := cabin_ids()
	check("a tap on the plain sets one cabin",one.size() == 1 and materials.cabin_refused == "",[one,materials.cabin_refused])
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	check("GardenView draws it",drawn() == 1,drawn())
	if one.size() == 1:
		var record := data.object_by_id(one[0])
		var door := Basis(Vector3.UP,float(record.angle))*Vector3(0.0,0.0,1.0)
		var to_eye: Vector2 = (eye()-spot).normalized()
		var fall: Vector2 = Vector2(height(spot+Vector2(1.5,0.0))-height(spot-Vector2(1.5,0.0)),height(spot+Vector2(0.0,1.5))-height(spot-Vector2(0.0,1.5)))/3.0
		var want: Vector2 = -fall.normalized() if fall.length() > Cabin.FACE_SLOPE else to_eye
		check("its door faces %s (door %s, want %s)" % ["down the slope" if fall.length() > Cabin.FACE_SLOPE else "the camera",Vector2(door.x,door.z),want],
			absf(float(record.angle)-expected) < 0.001 and Vector2(door.x,door.z).dot(want) > 0.99 and is_equal_approx(float(record.scale),1.0))
	await frames(30)
	check("its window is laid (one pane)",cabins.cabins.size() == 1 and cabins.panes.multimesh.instance_count == 1)
	editor.undo()
	await settled()
	await frames(30)
	check("undo takes it away, window and all",cabin_ids().is_empty() and drawn() == 0 and cabins.cabins.is_empty() and cabins.panes.multimesh.instance_count == 0,[cabin_ids(),drawn()])

	# --- Refusals ---
	if steep != null:
		undo0 = data._undo.size()
		await tap(steep)
		check("on a slope: refused ('steep'), nothing set, no undo step",cabin_ids().is_empty() and materials.cabin_refused == "steep" and data._undo.size() == undo0,[cabin_ids(),materials.cabin_refused])
	else:
		# No slope in view on this world: tilt the plain under the spot into
		# a hillside (a ramp rising 0.3 m a metre), tap, then put it back.
		var flat: PackedFloat32Array = data.heights.duplicate()
		for i in range(data.points.size()):
			var d: Vector2 = data.points[i]-spot
			if d.length() < 5.0: data.heights[i] += 0.3*d.x*(1.0-smoothstep(3.5,5.0,d.length()))
		await editor.refresh(self)
		await settled()
		print("tilted the plain at ",spot,": refusal ",why(spot))
		undo0 = data._undo.size()
		await tap(spot)
		check("on a slope (a hillside made under the spot): refused ('steep'), nothing set, no undo step",cabin_ids().is_empty() and materials.cabin_refused == "steep" and data._undo.size() == undo0,[cabin_ids(),materials.cabin_refused])
		data.heights = flat
		await editor.refresh(self)
		await settled()
		check("the plain put back takes a cabin again",why(spot) == "",why(spot))
	if wet == null and other != null and editor.flow != null and editor.flow.ready:
		var flow: RefCounted = editor.flow
		var depth: PackedFloat32Array = flow.kernel.get_depth()
		for dx in range(-12,13):
			for dz in range(-12,13):
				var q: Vector2 = other+Vector2(dx,dz)*0.25
				var cell: int = flow.cell_at(q)
				if q.distance_to(other) <= 1.2 and cell >= 0 and cell < depth.size(): depth[cell] = 0.4
		flow.kernel.set_depth(depth)
		await frames(3)
		wet = other
		print("flooded ",other," depth ",flow.depth_at(other))
	if wet != null:
		undo0 = data._undo.size()
		await tap(wet)
		check("in water: refused ('water'), nothing set, no undo step",cabin_ids().is_empty() and materials.cabin_refused == "water" and data._undo.size() == undo0,[cabin_ids(),materials.cabin_refused])
	else:
		check("found water in view to refuse on",false,"no water on this world")
	# A wood: a ring of trees round the spot.
	var count := data.objects.size()
	for k in range(6):
		data.place("tree",spot+Vector2.from_angle(TAU*k/6.0)*2.0,0.0,1.0)
	data.objects_revision += 1
	editor.force_refresh()
	await settled()
	undo0 = data._undo.size()
	await tap(spot)
	check("in a wood: refused ('tree'), nothing set, no undo step",cabin_ids().is_empty() and materials.cabin_refused == "tree" and data._undo.size() == undo0,[cabin_ids(),materials.cabin_refused])
	data.objects.resize(count)
	data.objects_revision += 1
	editor.force_refresh()
	await settled()
	await tap(spot)
	var first := cabin_ids()
	check("the wood cleared, set again on the plain",first.size() == 1,first)
	await tap(spot+Vector2(2.0,0.5))
	check("beside another cabin: refused",cabin_ids() == first and materials.cabin_refused == "near",[cabin_ids(),materials.cabin_refused])
	materials.put_back()
	await frames(30)

	# --- Night ---
	var id: int = first[0]
	await at_hour(12.0)
	check("by day the window is dark and casts no light",not cabins.panes.visible and light_on(id) == 0.0,[cabins.panes.visible,light_on(id)])
	await at_hour(0.0)
	await frames(30)
	var night_light := light_on(id)
	check("at midnight the window glows (emission %.2f)" % cabins._pane_material.emission_energy_multiplier,cabins.panes.visible and cabins._pane_material.emission_energy_multiplier > 1.0)
	check("and has a real light from the shared pool (%.2f)" % night_light,night_light > 0.5)
	var light: OmniLight3D = null
	for slot in lamps.slots:
		if int(slot.id) == id: light = slot.light
	check("warm, shadowless, reaching a few metres",light != null and not light.shadow_enabled and light.light_color.r > light.light_color.b and light.omni_range > 2.5,[light.light_color if light else null,light.omni_range if light else 0.0])
	await frames(240)
	check("a thin chimney smoke (%d puffs, cap %d)" % [cabins.puffs.size(),CabinLights.SMOKE_CAP],cabins.puffs.size() > 0 and cabins.puffs.size() <= CabinLights.SMOKE_CAP)
	# Many cabins and lamps: the cap.
	data.begin_stroke()
	var extra := 0
	for k in range(16):
		var p := Vector2(-9.0+(k%8)*2.5,-8.0+int(k/8)*15.0)
		if data.ground_height(p) != null and data.place("cabin" if k%2 == 0 else "stone_lamp",p) >= 0: extra += 1
	data.end_stroke()
	editor.force_refresh()
	await settled()
	await frames(90)
	var lit: Dictionary = lamps.lit()
	check("with %d cabins and lamps, at most %d real lights (%d lit)" % [cabins.cabins.size()+lamps.lamps.size(),Lights.MAX_LIGHTS,lit.size()],cabins.cabins.size()+lamps.lamps.size() > Lights.MAX_LIGHTS and lit.size() <= Lights.MAX_LIGHTS and lit.size() > 0)
	check("smoke only from the nearest %d" % CabinLights.ACTIVE_CABINS,cabins.active.size() == mini(CabinLights.ACTIVE_CABINS,cabins.cabins.size()) and cabins.puffs.size() <= CabinLights.SMOKE_CAP)
	editor.undo()
	await settled()
	await frames(40)
	check("undo takes the extras away",cabin_ids() == first and lamps.lamps.is_empty(),[cabin_ids(),lamps.lamps.size()])

	# --- Save round trip ---
	var saved: Variant = JSON.parse_string(JSON.stringify(data.to_document()))
	var before := data.object_by_id(id)
	data.objects.assign(data.objects.filter(func(item: Dictionary) -> bool: return str(item.asset) != "cabin"))
	data.objects_revision += 1
	editor.force_refresh()
	await settled()
	await frames(40)
	check("cleared for the load",cabin_ids().is_empty() and cabins.cabins.is_empty() and light_on(id) == 0.0)
	check("the saved world loads",data.load_document(saved))
	editor.refresh()
	await settled()
	await frames(80)
	var after := data.object_by_id(id)
	check("the cabin comes back from the save: same id, place and facing, drawn and lit",cabin_ids() == first and drawn() == 1 and light_on(id) > 0.0 and is_equal_approx(float(after.angle),float(before.angle)) and is_equal_approx(float(after.x),float(before.x)),[cabin_ids(),drawn(),light_on(id)])

	# --- The trash can, swept over its roof's edge ---
	for i in range(120):
		if materials.roll.shown > 0.99: break
		await process_frame
	await click(materials.roll._cell(materials.roll.TOOLS.find("trash")).get_center())
	await frames(30)
	check("the trash can is in hand",clay.tool_id == "trash",clay.tool_id)
	undo0 = data._undo.size()
	var at := Vector2(float(after.x),float(after.z))
	var side := Cabin.to_plate(at,float(after.angle),Vector2(Cabin.footprint().end.x+1.0,0.0))
	var a := screen(side+Vector2(0.0,-0.6))
	var b := screen(side+Vector2(0.0,0.6))
	button(a,true)
	await frames(2)
	var was := a
	for k in range(1,21):
		var to := a.lerp(b,k/20.0)
		motion(to,to-was)
		was = to
		await frames(2)
	button(was,false)
	await settled()
	await frames(60)
	check("the trash takes it from beside its wall",cabin_ids().is_empty(),cabin_ids())
	check("its window and light go with it",cabins.cabins.is_empty() and light_on(id) == 0.0 and cabins.panes.multimesh.instance_count == 0)
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	editor.undo()
	await settled()
	await frames(60)
	check("undo brings it back, lit",cabin_ids() == first and cabins.cabins.size() == 1 and light_on(id) > 0.0,[cabin_ids(),light_on(id)])

	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
