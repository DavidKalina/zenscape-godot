extends SceneTree
## Headless probe of Craft mode's fine tools (the old Sculpt/Cover/Place rail)
## against the creation pipeline (docs/scenic/PLAN.md, Phase 3 "Carried
## polish"): provenance (hand, emerged, generated), land weathering and pours
## settling on workers, water ground-shaping, emergence planning, and undo
## order. Strokes are replayed as the editor's own loop drives them; clicks go
## through `place_at` at the object's screen point. Nothing is rendered.
##   godot --headless --path . -s res://tools/probe_craft_tools.gd -- --plain-seed 7
## Prints one CRAFT PASS/FAIL line per check and a summary.
var scene: Node3D
var editor: NativeChunkEditor
var data: NativeTerrainData
var failures := 0
var checks := 0

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	checks += 1
	print("CRAFT %s %s %s" % ["PASS" if ok else "FAIL",label,JSON.stringify(detail)])
	if not ok: failures += 1

func frames(count: int) -> void:
	for _i in range(count): await process_frame

## Wait until nothing is settling: refreshes, pours, weathering, shaping.
func settle(limit := 20.0) -> bool:
	var until := Time.get_ticks_usec()+int(limit*1000000.0)
	var quiet := 0
	while Time.get_ticks_usec() < until:
		await process_frame
		var busy: bool = editor.refresh_pending > 0 or editor.water_settling or editor.land_settling or not editor._pour.is_empty()
		quiet = 0 if busy else quiet+1
		if quiet >= 6: return true
	return false

func _hash(value: Variant) -> String:
	return var_to_bytes(value).hex_encode().sha256_text().left(12)

func records() -> Array:
	var found := []
	for item in data.objects: found.append([item.id,item.asset,NativeTerrainData.object_source(item),snappedf(item.x,0.001),snappedf(item.z,0.001)])
	return found

func state() -> Dictionary:
	return {"heights":_hash(data.heights),"objects":_hash(records()),"ponds":_hash(data.ponds),"streams":_hash(data.streams),"cover":_hash([data.grass,data.meadow,data.tint]),"provenance":_hash(data.provenance),"forest":_hash(editor.emergence.intent.forest)}

func sources() -> Dictionary:
	var counts := {}
	for item in data.objects:
		var key := NativeTerrainData.object_source(item)
		counts[key] = counts.get(key,0)+1
	return counts

## A held craft stroke (raise, lower, smooth, flatten, grass, meadow, paint,
## erase), as place_at opens it and _process continues it at 30 Hz.
func craft_stroke(tool: String, a: Vector2, b: Vector2, ticks := 12) -> void:
	editor.select_tool(tool)
	editor.set_process(false)
	data.begin_stroke()
	editor._stroke_first_id = data.next_id
	editor._stroke_rect = Rect2()
	editor._level = float(data.ground_height(a)) if data.ground_height(a) != null else 0.0
	editor._painting = true
	var last := a
	for i in range(ticks):
		var center := a.lerp(b,float(i)/maxi(1,ticks-1))
		var dabs := maxi(1,ceili(last.distance_to(center)/(editor.radius*0.15)))
		for k in range(1,dabs+1): editor.dab(last.lerp(center,float(k)/dabs),editor.strength/30.0/dabs)
		editor.refresh()
		last = center
		await process_frame
	editor.finish_stroke()
	editor.set_process(true)

## A held creation-brush stroke, as `_land_press` and `_land_step` drive it.
func brush_stroke(brush: String, a: Vector2, b: Vector2, lower := false, ticks := 20) -> void:
	editor.select_brush(brush)
	editor.set_process(false)
	editor._land_lower = lower
	var held = editor.creation_brush()
	held.prepare(data,editor.land_seed)
	held.begin()
	editor._stroke_first_id = data.next_id
	if not held.settles: data.begin_stroke()
	editor._painting = true
	var last := a
	for i in range(ticks):
		var center := a.lerp(b,float(i)/maxi(1,ticks-1))
		var dabs := clampi(ceili(last.distance_to(center)/(editor.brush_radius()*0.2)),1,24)
		for k in range(1,dabs+1):
			var point := last.lerp(center,float(k)/dabs)
			editor.land_dab(point,editor.brush_strength()/30.0/dabs)
			if not held.settles: editor._touch(point,editor.brush_radius())
		if not held.settles: editor.refresh()
		last = center
		await process_frame
	editor.finish_stroke()
	editor.set_process(true)

## Click a Place tool at a plate point through `place_at`, at its screen point.
func click(tool: String, p: Vector2) -> bool:
	editor.select_tool(tool)
	var h: Variant = data.ground_height(p)
	if h == null: return false
	var world: Vector3 = editor.terrain.to_global(Vector3(p.x,float(h),p.y))
	var mouse: Vector2 = scene.camera.unproject_position(world)
	var placed := editor.place_at(mouse)
	if editor._painting: editor.finish_stroke()
	return placed

func nearest(p: Vector2, source: String) -> Dictionary:
	var best := {}
	var distance := INF
	for item in data.objects:
		if NativeTerrainData.object_source(item) != source: continue
		var d := Vector2(item.x,item.z).distance_to(p)
		if d < distance:
			distance = d
			best = item
	return best

func run() -> void:
	create_timer(170).timeout.connect(func() -> void: push_error("Craft probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-craft-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	data = editor.data
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	editor.set_process_input(false)
	scene.set_building(true)
	editor.emergence.salt = 12345
	editor.emergence._fixed_salt = true
	editor.radius = 2.2
	editor.strength = 2.0
	await settle()
	var initial: Dictionary = state()
	var undo_base: int = data._undo.size()

	# 1. A craft sculpt while a land stroke's weathering is on its worker joins
	# it: the craft stroke starts from weathered ground, and one undo each.
	editor.land_brush.last_weather_usec = -1
	await brush_stroke("land",Vector2(-6,-6),Vector2(-1,-4))
	var weathering: bool = editor.land_settling
	await craft_stroke("raise",Vector2(-4,-5),Vector2(-2,-3),6)
	# The weathering was taken in (not dropped) when the craft stroke opened.
	var joined: bool = not editor.land_settling and editor.land_brush.last_weather_usec >= 0
	await settle()
	var after_both: Dictionary = state()
	check("sculpt joins land weathering",joined and data._undo.size() == undo_base+2,{"weathering_at_press":weathering,"joined":joined,"weather_usec":editor.land_brush.last_weather_usec,"undo":data._undo.size()-undo_base})
	editor.undo()
	await settle()
	var after_one: Dictionary = state()
	check("undo takes the craft sculpt only",after_one.heights != after_both.heights and after_one.heights != initial.heights,{})
	editor.undo()
	await settle()
	check("second undo takes the land stroke and its weathering",state().heights == initial.heights and data._undo.size() == undo_base,{"undo":data._undo.size()-undo_base})

	# 2. A craft sculpt while a pour's ground is moving into place lands the
	# pour first (ground and water, one step), then opens its own step.
	var ponds_before := data.ponds.size()
	var water_before := _hash([data.ponds,data.streams])
	await brush_stroke("water",Vector2(5,5),Vector2(6,6),false,30)
	var until := Time.get_ticks_usec()+15000000
	while not editor._pour.get("shaping",false) and editor.water_settling and Time.get_ticks_usec() < until: await process_frame
	var shaping: bool = editor._pour.get("shaping",false)
	await craft_stroke("raise",Vector2(-8,8),Vector2(-6,9),6)
	await settle()
	var pour_ponds := data.ponds.size()
	var poured := _hash([data.ponds,data.streams])
	check("sculpt lands a shaping pour first",poured != water_before and data._undo.size() == undo_base+2,{"shaping_at_press":shaping,"ponds":pour_ponds-ponds_before,"undo":data._undo.size()-undo_base})
	var with_pour: Dictionary = state()
	editor.undo()
	await settle()
	check("undo keeps the pour, takes the sculpt",_hash([data.ponds,data.streams]) == poured and state().heights != with_pour.heights,{"ponds":data.ponds.size()})
	editor.undo()
	await settle()
	check("second undo takes the pour whole",_hash([data.ponds,data.streams]) == water_before and state().heights == initial.heights,{"ponds":data.ponds.size()})

	# 3. A craft sculpt while a pour plans its last dabs on a worker. The
	# pour closes on what is showing, then the sculpt opens its own step.
	await brush_stroke("water",Vector2(5,5),Vector2(6,6),false,30)
	var planning: bool = editor.water_settling and not editor._pour.get("shaping",false)
	await craft_stroke("lower",Vector2(-8,-8),Vector2(-7,-7),4)
	await settle()
	check("sculpt during a pour's plan leaves one consistent step",data._undo.size() in [undo_base+1,undo_base+2],{"planning_at_press":planning,"ponds":data.ponds.size()-ponds_before,"undo":data._undo.size()-undo_base,"status":editor.status})
	while data._undo.size() > undo_base:
		editor.undo()
		await settle()
	check("undo back to the start",state().heights == initial.heights and data.ponds.size() == ponds_before,{})

	# 4. Emerged ground: a forest grows; craft work on it is hand work.
	Engine.time_scale = 6.0
	await brush_stroke("forest",Vector2(-3,2),Vector2(4,3))
	until = Time.get_ticks_usec()+14000000
	while sources().get("emerged",0) < 12 and Time.get_ticks_usec() < until: await process_frame
	Engine.time_scale = 1.0
	await settle()
	var emerged: int = sources().get("emerged",0)
	# On a recipe world the brushed ground may be rock or already wooded.
	var kind := "emerged" if emerged > 0 else "generated"
	if data._recipe == null: check("forest emerged",emerged >= 6,sources())
	else: print("CRAFT NOTE forest emerged ",JSON.stringify(sources()))
	var tree_at := nearest(Vector2(0,2.5),kind)
	var spot := Vector2(tree_at.get("x",0.0),tree_at.get("z",2.5))+Vector2(0.4,0.0)
	var placed := await click("tree",spot)
	await settle()
	var hand := nearest(spot,"hand")
	check("tree placed on emerged ground is hand",placed and not hand.is_empty() and Vector2(hand.x,hand.z).distance_to(spot) < 0.3,{"placed":placed,"sources":sources()})
	# Moving an emerged plant claims it.
	var moved := nearest(Vector2(2,3),kind)
	editor.select_tool("select")
	editor.select_object(int(moved.get("id",-1)))
	var claimed: bool = editor.update_selected({"x":float(moved.get("x",0.0))+0.2})
	var moved_now := data.object_by_id(int(moved.get("id",-1)))
	check("edited %s plant becomes hand" % kind,claimed and NativeTerrainData.object_source(moved_now) == "hand",{"source":NativeTerrainData.object_source(moved_now)})
	# A duplicate is the player's copy.
	var copy_id := editor.duplicate_selected()
	var copy := data.object_by_id(copy_id)
	check("duplicate of a %s plant is hand" % kind,copy_id > 0 and NativeTerrainData.object_source(copy) == "hand",{"source":NativeTerrainData.object_source(copy)})
	editor.select_object(-1)
	# A firm forest clear keeps hand work and withdraws the rest.
	var hand_ids := []
	for item in data.objects:
		if NativeTerrainData.object_source(item) == "hand": hand_ids.append(item.id)
	await brush_stroke("forest",Vector2(4,3),Vector2(-3,2),true)
	await settle()
	var kept := 0
	for id: int in hand_ids:
		if not data.object_by_id(id).is_empty(): kept += 1
	check("forest clear keeps hand work",kept == hand_ids.size(),{"hand":hand_ids.size(),"kept":kept,"sources":sources()})

	# 5. Craft sculpt under emerged plants replans the ground: plants that
	# end up too steep or wet go; the rest are lifted with it.
	var before_lift: int = sources().get("emerged",0)
	await brush_stroke("forest",Vector2(-8,-6),Vector2(-4,-8))
	Engine.time_scale = 6.0
	until = Time.get_ticks_usec()+10000000
	while sources().get("emerged",0) <= before_lift and Time.get_ticks_usec() < until: await process_frame
	Engine.time_scale = 1.0
	await settle()
	var grown := nearest(Vector2(-6,-7),"emerged")
	var undo_at := data._undo.size()
	await craft_stroke("raise",Vector2(-7,-7),Vector2(-5,-7),10)
	await settle()
	var still := data.object_by_id(int(grown.get("id",-1)))
	var ground: Variant = data.ground_height(Vector2(grown.get("x",0.0),grown.get("z",0.0)))
	var lifted := true
	for batch in editor.content._batches:
		for source: Dictionary in editor.content._sources.get(batch.get_meta("part"),[]):
			if source.item != null and int(source.item.id) == int(grown.get("id",-1)) and ground != null:
				var pose: Variant = editor.content._instance_transform(source)
				if pose is Transform3D and absf(pose.origin.y-float(ground)) > 0.6: lifted = false
	check("sculpt under emerged plants lifts or withdraws them",still.is_empty() or lifted,{"kept":not still.is_empty(),"lifted":lifted,"undo":data._undo.size()-undo_at})

	# 6. Craft cover and erase claim their cells; emergence then leaves them.
	await craft_stroke("paint",Vector2(8,-2),Vector2(10,-1),6)
	var cell := data.meadow_cell(Vector2(9,-1.5))
	check("craft paint marks hand ground",data.provenance[cell] == NativeTerrainData.SOURCE_HAND,{"provenance":data.provenance[cell]})
	var erase_at := nearest(Vector2(0,2.5),"emerged")
	if not erase_at.is_empty():
		await craft_stroke("erase",Vector2(erase_at.x,erase_at.z)-Vector2(0.3,0),Vector2(erase_at.x,erase_at.z)+Vector2(0.3,0),4)
		await settle()
		check("erase removes an emerged plant",data.object_by_id(int(erase_at.id)).is_empty(),{})

	# 6b. The rest of the rail: smooth, flatten, grass, meadow and blades
	# strokes, a flower trail and a mountain click, each one undo step, with
	# records minted by hand.
	for tool: String in ["smooth","flatten","grass","meadow","blades"]:
		var steps_before: int = data._undo.size()
		var looked: Dictionary = state()
		await craft_stroke(tool,Vector2(6,-9),Vector2(9,-8),6)
		await settle()
		check("%s stroke is one step" % tool,data._undo.size() == steps_before+1 or state() == looked,{"undo":data._undo.size()-steps_before})
	var first_id: int = data.next_id
	editor.select_tool("flower")
	var trail_ok := await click("flower",Vector2(-10,-2))
	var minted := 0
	var by_hand := 0
	for item in data.objects:
		if int(item.id) >= first_id:
			minted += 1
			if NativeTerrainData.object_source(item) == "hand": by_hand += 1
	check("flower click is hand work",trail_ok and minted > 0 and by_hand == minted,{"minted":minted,"hand":by_hand})
	var peak_before: int = data._undo.size()
	editor.mountain_peak = 3.0
	editor.mountain_radius = 3.0
	var peaked := await click("mountain",Vector2(10,8))
	await settle()
	check("mountain click is one step",peaked and data._undo.size() == peak_before+1,{"undo":data._undo.size()-peak_before})

	# 7. Craft pond on the plain: the plain's water worker builds it and one
	# undo takes it back.
	await craft_stroke("lower",Vector2(-9,9),Vector2(-8,9.5),16)
	await settle()
	var bottom: float = float(data.ground_height(Vector2(-8.5,9.2)))
	editor.pond_level = bottom+0.2
	var ponds_now := data.ponds.size()
	var filled := await click("pond",Vector2(-8.5,9.2))
	await settle()
	check("craft pond fills on the plain",filled and data.ponds.size() == ponds_now+1 and not editor.content.pond_vertices.is_empty(),{"filled":filled,"status":editor.status,"vertices":editor.content.pond_vertices.size()})
	editor.undo()
	await settle()
	check("undo takes the craft pond",data.ponds.size() == ponds_now,{})

	# 8. Everything undone returns the world to where it began.
	var steps := 0
	while data._undo.size() > undo_base and steps < 60:
		editor.undo()
		steps += 1
		await settle()
	var final := state()
	check("undo all returns to the start",final.heights == initial.heights and final.objects == initial.objects and final.ponds == initial.ponds and final.forest == initial.forest and final.provenance == initial.provenance and final.cover == initial.cover,{"steps":steps,"final":final,"initial":initial})
	print("CRAFT SUMMARY ",JSON.stringify({"checks":checks,"failures":failures}))
	scene.queue_free()
	await frames(3)
	quit(1 if failures > 0 else 0)
