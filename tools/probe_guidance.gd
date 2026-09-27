extends SceneTree
## Headless A/B probe of quiet guidance (scripts/quiet_guidance.gd,
## docs/scenic/guidance.md). Opens the product scene on the plain, paints a
## standard set of strokes (a hill, three pours, a ruled forest band, a round
## copse), lets emergence run to rest, and scores the result. Then it reloads
## the same plain and paints the same strokes twice more: with the water
## nudges off (the same ground, so only the plant nudges differ), and with
## guidance off. It prints the regional score per stroke and over the plate
## for each, and what changed against the unguided world.
##   godot --headless --path . -s res://tools/probe_guidance.gd -- --plain-seed 7 [--salt=12345] [--seconds=80] [--cases]
## --cases prints only the made-up water and edge cases (WATER_CASES, EDGE_CASES).
const Guidance = preload("res://scripts/quiet_guidance.gd")
const WaterBrush = preload("res://scripts/water_brush.gd")
const BiomeBlend = preload("res://scripts/biome_blend.gd")
const Emergence = preload("res://scripts/emergence.gd")

var scene: Node3D
var editor: NativeChunkEditor
var salt := 12345
var seconds := 80.0
## Main-thread time of each emergence step that planned nothing, per paint.
var step_usec: Array[int] = []

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("Guidance probe timed out"); quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--salt="): salt = int(arg.trim_prefix("--salt="))
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
	root.size = Vector2i(1280,800)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-guidance-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	editor = scene._chunk_editor
	editor.set_process(false)
	scene.set_process(false)
	var emergence = editor.emergence
	emergence.plan_on_worker = false
	emergence.salt = salt
	emergence._fixed_salt = true
	var blank := JSON.stringify(editor.data.to_document())
	# --cases: only the made-up water and edge cases.
	if "--cases" in OS.get_cmdline_user_args():
		print("WATER_CASES ",JSON.stringify(water_cases()))
		print("EDGE_CASES ",JSON.stringify(edge_cases()))
		quit()
		return
	var guided := paint(true,blank)
	Guidance.water_enabled = false
	var plants := paint(true,blank)
	Guidance.water_enabled = true
	var plain := paint(false,blank)
	print("GUIDED ",JSON.stringify(guided.report))
	print("PLANTS_ONLY ",JSON.stringify(plants.report))
	print("UNGUIDED ",JSON.stringify(plain.report))
	print("CHANGED ",JSON.stringify(compare(guided,plain)))
	print("CHANGED_PLANTS_ONLY ",JSON.stringify(compare(plants,plain)))
	print("WATER_CASES ",JSON.stringify(water_cases()))
	print("EDGE_CASES ",JSON.stringify(edge_cases()))
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit()

## Paint the standard strokes on the blank plain and let emergence finish.
func paint(guided: bool, blank: String) -> Dictionary:
	Guidance.enabled = guided
	var data := editor.data
	data.load_document(JSON.parse_string(blank))
	var emergence = editor.emergence
	emergence.clear()
	emergence.guided = guided
	emergence.refusals = {}
	emergence.guided_sizes = {"up":0,"down":0}
	step_usec.clear()
	var strokes := {}
	var water := []
	var guide_usec := []
	var edges := {}
	# 1. A hill on the left.
	var land = editor.land_brush
	land.prepare(data,editor.land_seed)
	land.begin()
	data.begin_stroke()
	for i in range(60):
		land.dab(data,Vector2(-8.0,-5.0).lerp(Vector2(-3.5,-2.5),i/59.0),3.5,1.0/30.0*1.4,false,editor.land_ceiling)
	data.end_stroke()
	strokes.hill = land.bounds
	emergence.on_region_changed(land.bounds,"land")
	_settle(emergence,6.0,guide_usec)
	# 2. Three pours: at the hill's foot, on open ground, and beside the first.
	for pour in [["foot",Vector2(-2.5,-0.5),3.0],["open",Vector2(4.5,-4.5),3.0],["beside",Vector2(0.5,1.5),2.0]]:
		var plan := _pour(pour[1],pour[2])
		water.append({"pour":pour[0],"ponds":plan.get("added",[]).map(func(entry: Dictionary) -> Array: return [snappedf(entry.record.x,0.1),snappedf(entry.record.z,0.1),snappedf(entry.record.level,0.001)]),"scoops":plan.get("scoops",0),"guided":plan.get("guided",{}),"plan_ms":snappedf(plan.get("usec",0)/1000.0,0.1)})
		if plan.get("changed",false):
			strokes[pour[0]] = plan.rect
			emergence.on_region_changed(plan.rect,"water")
		_settle(emergence,4.0,guide_usec)
	# 3. A ruled forest band across the back, and a round copse.
	var forest = editor.brushes["forest"]
	forest.activate(editor)
	forest.prepare(data,editor.land_seed)
	for band in [[Vector2(-10.0,6.5),Vector2(8.0,6.5),60,"band"],[Vector2(7.5,-9.0),Vector2(7.6,-9.0),30,"copse"]]:
		forest.begin()
		data.begin_stroke()
		for i in range(band[2]):
			forest.dab(data,Vector2(band[0]).lerp(band[1],i/float(band[2]-1)),forest.radius,1.0/30.0*2.0,false)
		var rect: Rect2 = forest.finish(data)
		data.end_stroke()
		strokes[band[3]] = rect
		emergence.on_region_changed(rect,"forest")
		if emergence._blend != null:
			# How straight the wish's edge reads, as the guide will see it.
			var guide = Guidance.plan(emergence,rect,PackedVector4Array())
			var edge := []
			for value in guide.straight:
				if value > 0.0: edge.append(value)
			# Share of lattice points in the rect whose wish the warp moves.
			var moved := 0
			var total := 0
			var shift := 0.0
			for zi in range(int(rect.size.y*4.0)):
				for xi in range(int(rect.size.x*4.0)):
					var p: Vector2 = rect.position+Vector2(xi,zi)*0.25
					total += 1
					shift += guide.warp(p).length()
					if absf(emergence._wish_at(p,guide)-emergence.intent.forest_at(p)) > 0.1: moved += 1
			# Tree candidates whose roll the warp flips (on the ground as it is).
			var flips := 0
			var candidates := 0
			var lattice: float = Emergence.TREE_LATTICE
			for j in range(floori(rect.position.y/lattice)-2,ceili(rect.end.y/lattice)+2):
				for i in range(floori(rect.position.x/lattice)-2,ceili(rect.end.x/lattice)+2):
					var key := [emergence.salt,"tree".hash(),i,j]
					var p := (Vector2(i,j)+Vector2(Emergence.Variety.unit(key+[1]),Emergence.Variety.unit(key+[2])))*lattice
					if maxf(absf(p.x),absf(p.y)) > Emergence.PLATE: continue
					var plain: float = emergence.intent.forest_at(p)
					var warped: float = emergence._wish_at(p,guide)
					if plain <= 0.0 and warped <= 0.0: continue
					candidates += 1
					var roll := Emergence.Variety.unit(key+[4])
					var a: float = minf(emergence._tree_chance("woodland",0.0,plain,emergence._frayed(p,key,plain),true),0.85)
					var b: float = minf(emergence._tree_chance("woodland",0.0,warped,emergence._frayed(p,key,warped),true),0.85)
					if (roll < a) != (roll < b): flips += 1
			edges[band[3]+"_warp"] = {"moved":moved,"points":total,"mean_shift_m":snappedf(shift/maxi(total,1),0.01),"tree_candidates":candidates,"flips":flips}
			edges[band[3]] = {"cells":edge.size(),"mean":snappedf(edge.reduce(func(a: float, b: float) -> float: return a+b,0.0)/maxi(edge.size(),1),0.01),"max":snappedf(edge.max() if not edge.is_empty() else 0.0,0.01)}
	_settle(emergence,seconds,guide_usec)
	# Score the settled world with a fresh live blend, as a planner would.
	var blend = BiomeBlend.live(data)
	var known := Guidance.plants(data.objects,Rect2(-14,-14,28,28),Emergence.TREES)
	var scores := {}
	var all := Rect2()
	var first := true
	for key: String in strokes:
		var rect: Rect2 = strokes[key]
		scores[key] = _terms(Guidance.score(data,blend,known,rect))
		all = rect if first else all.merge(rect)
		first = false
	scores["strokes"] = _terms(Guidance.score(data,blend,known,all))
	scores["plate"] = _terms(Guidance.score(data,blend,known,Rect2(-13,-13,26,26)))
	var began := Time.get_ticks_usec()
	Guidance.score(data,blend,known,Rect2(-13,-13,26,26))
	var score_ms := (Time.get_ticks_usec()-began)/1000.0
	var kinds := {}
	var emerged := []
	for item: Dictionary in data.objects:
		if NativeTerrainData.object_source(item) != "emerged": continue
		kinds[item.asset] = kinds.get(item.asset,0)+1
		emerged.append([item.asset,snappedf(item.x,0.01),snappedf(item.z,0.01),snappedf(float(item.get("scale",1.0)),0.001)])
	guide_usec.sort()
	var steps := step_usec.duplicate()
	steps.sort()
	var step_total := 0
	for value in steps: step_total += value
	var report := {"arrival_steps_ms":{"n":steps.size(),"total":snappedf(step_total/1000.0,0.1),"p95":snappedf(steps[int(steps.size()*0.95)]/1000.0,0.01) if not steps.is_empty() else 0.0,"max":snappedf(steps.back()/1000.0,0.01) if not steps.is_empty() else 0.0},"guided":guided,"scores":scores,"emerged":kinds,"refusals":emergence.refusals,"wish_edges":edges,"sizes":emergence.guided_sizes,"water":water,"ponds":data.ponds.size(),"streams":data.streams.size(),
		"guide_plan_ms":{"max":snappedf(guide_usec.back()/1000.0,0.1) if not guide_usec.is_empty() else 0.0,"n":guide_usec.size()},"plate_score_ms":snappedf(score_ms,0.1)}
	return {"report":report,"emerged":emerged,"heights":data.heights.duplicate(),"ponds":data.ponds.duplicate(true)}

func _terms(score: Dictionary) -> Dictionary:
	var kept := {}
	for key: String in score: kept[key] = snappedf(float(score[key]),0.001)
	return kept

## Run emergence until at least `at_least` seconds have passed and it rests.
func _settle(emergence: RefCounted, at_least: float, guide_usec: Array) -> void:
	var clock := 0.0
	var last_usec := -1
	while clock < at_least or (emergence.busy() and clock < at_least+120.0):
		# Steps that only take arrivals in (no plan) are the main thread's
		# share in the editor, where plans run on a worker.
		var planning: bool = not emergence._queued.is_empty()
		var began := Time.get_ticks_usec()
		emergence.advance(0.25)
		if not planning: step_usec.append(Time.get_ticks_usec()-began)
		if emergence.guided_usec != last_usec and emergence.guided_usec > 0:
			last_usec = emergence.guided_usec
			guide_usec.append(last_usec)
		clock += 0.25

## Pour at `point` for `pour_seconds` and land the plan as the editor does.
func _pour(point: Vector2, pour_seconds: float) -> Dictionary:
	var brush = editor.water_brush
	brush.begin()
	for tick in range(int(pour_seconds*30.0)):
		brush.dab(editor.data,point,brush.radius,brush.strength/30.0,false)
	var data := editor.data
	var detached := preload("res://scripts/native_terrain_snapshot.gd").for_height(data)
	var plan: Dictionary = WaterBrush.plan(detached,data.ponds.duplicate(true),data.streams.duplicate(true),brush.dabs,true)
	if not plan.changed: return plan
	data.begin_stroke()
	if plan.has("heights"): data.heights = plan.heights
	data.ponds.assign(plan.ponds)
	data.streams.assign(plan.streams)
	editor.emergence.drown(plan.added,plan.added_streams)
	data.end_stroke()
	return plan

## The water nudges on made-up ground, with and without guidance:
## - a hollow whose water came to rest 1.2 m of land away from a pond;
## - a round pond with a one-cell channel running off it just under its level.
func water_cases() -> Dictionary:
	var side: int = WaterBrush.SIDE
	var cases := {}
	for guided in [true,false]:
		Guidance.enabled = guided
		# A flat plate with one bowl pond at the centre.
		var h := PackedFloat32Array()
		h.resize(side*side)
		var drain := PackedByteArray()
		drain.resize(side*side)
		for k in range(side*side):
			var p := WaterBrush.position_of(k)
			h[k] = -0.3*maxf(0.0,1.0-p.length_squared()/4.0)
			if WaterBrush._border(k): drain[k] = 1
		var grid := {"h":h,"drain":drain}
		var ponds := [{"x":0.0,"z":0.0,"level":-0.05}]
		var sites: Array = WaterBrush._scoop_sites(grid,[{"volume":2.0,"start":WaterBrush.cell_of(Vector2(5.5,0.0))}],ponds)
		var site: Dictionary = sites[0]
		# A bowl with a shallow one-cell channel off its east side.
		var basin := PackedFloat32Array()
		basin.resize(side*side)
		for k in range(side*side):
			var p := WaterBrush.position_of(k)
			basin[k] = 0.4-0.4*maxf(0.0,1.0-p.length_squared()/9.0)
			if absf(p.y) < 0.1 and p.x > 2.0 and p.x < 7.0: basin[k] = 0.215
		var level := Guidance.pond_level(basin,WaterBrush.cell_of(Vector2.ZERO),0.25,0.1,side) if guided else 0.25
		cases["guided" if guided else "unguided"] = {"hollow_at":str(WaterBrush.position_of(site.cell)),"moved":snappedf(float(site.get("moved",0.0)),0.01),"stretch":snappedf(float(site.get("stretch",1.0)),0.01),"angle_deg":snappedf(rad_to_deg(float(site.get("angle",0.0))),1.0),
			"channel_pond_level":snappedf(level,0.001),"channel_shape":Guidance._pond_shape(basin,WaterBrush.cell_of(Vector2.ZERO),level,side)}
	Guidance.enabled = true
	return cases

## The edges term on made-up stands, so its reading is known: a wood with a
## ruled edge, the same wood with its edge in bays, and a round copse.
func edge_cases() -> Dictionary:
	var blend = BiomeBlend.live(editor.data)
	var cases := {}
	for shape in ["ruled","bays","round"]:
		var trees := PackedVector4Array()
		for j in range(-16,17):
			for i in range(-16,17):
				var p := Vector2(i,j)*0.8+Vector2(Emergence.Variety.unit([i,j,1]),Emergence.Variety.unit([i,j,2]))*0.5
				var inside := false
				match shape:
					"ruled": inside = p.y < 0.0 and absf(p.x) < 9.0 and p.y > -9.0
					"bays": inside = p.y < sin(p.x*0.9)*1.6 and absf(p.x) < 9.0 and p.y > -9.0
					"round": inside = p.length() < 5.0
				if inside and Emergence.Variety.unit([i,j,3]) < 0.55: trees.append(Vector4(p.x,p.y,1.0,1.0))
		var score := Guidance.score(editor.data,blend,trees,Rect2(-10,-10,20,20))
		cases[shape] = {"edges":snappedf(score.edges,0.001),"edge_straight":snappedf(score.edge_straight,0.001),"trees":trees.size()}
	return cases

## What guidance changed: score deltas, plants only in one world, and water.
func compare(guided: Dictionary, plain: Dictionary) -> Dictionary:
	var deltas := {}
	for region: String in guided.report.scores:
		var a: Dictionary = guided.report.scores[region]
		var b: Dictionary = plain.report.scores.get(region,{})
		var delta := {}
		for term in ["total","relief","water","edges","openness","variety","framing"]:
			delta[term] = snappedf(float(a.get(term,0.0))-float(b.get(term,0.0)),0.001)
		deltas[region] = delta
	var only_guided := _only(guided.emerged,plain.emerged)
	var only_plain := _only(plain.emerged,guided.emerged)
	var resized := 0
	var at := {}
	for item: Array in plain.emerged: at[str([item[0],item[1],item[2]])] = item[3]
	for item: Array in guided.emerged:
		var key := str([item[0],item[1],item[2]])
		if at.has(key) and absf(float(at[key])-float(item[3])) > 0.001: resized += 1
	var moved := 0
	for i in range(mini(guided.heights.size(),plain.heights.size())):
		if absf(guided.heights[i]-plain.heights[i]) > 0.005: moved += 1
	return {"score_delta":deltas,"only_guided":_kinds(only_guided),"only_unguided":_kinds(only_plain),"resized":resized,"emerged":[guided.emerged.size(),plain.emerged.size()],
		"ground_vertices_differ":moved,"ponds":[guided.ponds.map(func(p: Dictionary) -> Array: return [snappedf(p.x,0.1),snappedf(p.z,0.1),snappedf(p.level,0.001)]),plain.ponds.map(func(p: Dictionary) -> Array: return [snappedf(p.x,0.1),snappedf(p.z,0.1),snappedf(p.level,0.001)])]}

func _only(a: Array, b: Array) -> Array:
	var seen := {}
	for item: Array in b: seen[str([item[0],item[1],item[2]])] = true
	return a.filter(func(item: Array) -> bool: return not seen.has(str([item[0],item[1],item[2]])))

func _kinds(items: Array) -> Dictionary:
	var counts := {}
	for item: Array in items: counts[item[0]] = counts.get(item[0],0)+1
	return counts
