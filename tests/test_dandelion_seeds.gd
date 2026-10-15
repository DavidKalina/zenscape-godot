extends SceneTree
## The dandelion's round (scripts/dandelion_seeds.gd, docs/scenic/dandelions.md).
## Headless: the GPU half (the material drawing the state) is not exercised.
##
## The clock's mesh names every head vertex's part in the round; its material
## turns the round on. On a flat plate with a painted drift: the breeze peels
## seeds now and then and only in moving air; a wind-tool gust strips the
## clocks under it bare and leaves the rest; seeds fly downwind and land; a
## bare clock comes round to whole; a landed seed takes only near flowers,
## with room, not in a full core, not on thinned ground, not into an open
## stroke; spreading over a while stays near the drift; undo clears it all.
## In the cozy scene: the editor keeps the round under the land, reads a
## painted drift once it is published, draws a new plant at once, keeps out
## of an open stroke, and the world saves and reopens with it.
const Seeds = preload("res://scripts/dandelion_seeds.gd")
const Flowers = preload("res://scripts/meadow_flower_mesh.gd")
const FlowerSowing = preload("res://scripts/flower_sowing.gd")
const Emergence = preload("res://scripts/emergence.gd")
const PlateFixture := preload("res://tests/fixtures/plate.gd")
const WORLD_SEED := 6

var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: "+message)
	else:
		print("PASS: "+message)

## Stands in for GardenView: records the states written and what is drawn.
class View extends RefCounted:
	var states := {}
	var drawn: Array = []
	func set_flower_state(id: int, state: float) -> void:
		if is_equal_approx(state,1.0): states.erase(id)
		else: states[id] = state
	func paint_preview(records: Array) -> void:
		drawn.append_array(records)

## Stands in for the wind tool: one lane leaning the plants `lean` along +x
## within `reach` of `at` (plate = world here).
class Gust extends Node3D:
	var gusts: Array = []
	var wakes: Array = []
	var at := Vector2.ZERO
	var reach := 2.0
	var lean := 0.0
	func aiming() -> bool: return lean > 0.0
	func blow_at(p: Vector2, _motion := 0.0, _phase := 0.0) -> Vector3:
		return Vector3(lean,0.0,0.0) if p.distance_to(at) < reach else Vector3.ZERO

func _flat_data() -> NativeTerrainData:
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.reset_flat()
	return data

## A drift of clocks and dandelions on a 0.45 m grid over `size` m round `at`.
func _drift(data: NativeTerrainData, at: Vector2, size: float) -> Array:
	var ids: Array = []
	var n := int(size/0.45)
	for i in range(n):
		for j in range(n):
			var p := at+Vector2(i-n*0.5,j-n*0.5)*0.45
			var kind := "dandelion_clock" if (i+j)%2 == 0 else "dandelion"
			var id := data.place(kind,p,0.0,1.0)
			if id >= 0: ids.append(id)
	return ids

func _seeds(data: NativeTerrainData, view: View) -> Node3D:
	var plate := Node3D.new()
	root.add_child(plate)
	var seeds: Node3D = Seeds.new()
	seeds.data = data
	seeds.view = view
	seeds.sowing_for = func(slot: String) -> RefCounted: return FlowerSowing.new(data,slot,41)
	seeds.set_process(false)
	plate.add_child(seeds)
	seeds.reindex()
	return seeds

func _run_for(seeds: Node3D, seconds: float) -> void:
	var dt := 1.0/30.0
	for i in range(int(seconds/dt)):
		Emergence.time += dt
		seeds.step(dt)

func run() -> void:
	mesh_roles()
	breeze_and_gust()
	taking_root()
	await in_scene()
	print("Dandelion seeds: %d failures" % failures)
	quit(1 if failures > 0 else 0)

func mesh_roles() -> void:
	var mesh := Flowers.build("dandelion_clock")
	var arrays := mesh.surface_get_arrays(0)
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var parts: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var ranks := {}
	var gold := 0
	var gold_yellow := true
	var core := 0
	var bracts := 0
	var plain := 0
	for v in range(parts.size()):
		var w := custom[v*4+3]
		if w >= Flowers.ROLE_BRACT: bracts += 1
		elif w >= Flowers.ROLE_CORE: core += 1
		elif w >= Flowers.ROLE_GOLD:
			gold += 1
			if colors[v].b > colors[v].g*0.6: gold_yellow = false
		elif w >= Flowers.ROLE_SEED: ranks[snappedf(w-Flowers.ROLE_SEED,0.0001)] = true
		else: plain += 1
	check(ranks.size() == Seeds.SEEDS,"the clock's %d parachutes each have their own rank (%d)" % [Seeds.SEEDS,ranks.size()])
	check(gold > 60 and gold_yellow,"the clock carries a gold head for the round (%d vertices)" % gold)
	check(core > 0 and bracts > 0 and plain > 0,"core, bracts, and stem and leaves keep their own parts (%d, %d, %d)" % [core,bracts,plain])
	var other := Flowers.build("dandelion")
	var other_custom: PackedFloat32Array = other.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
	var most := 0.0
	for v in range(other_custom.size()/4): most = maxf(most,other_custom[v*4+3])
	check(most <= 1.0,"other kinds keep CUSTOM0.w as the fraction out (%.2f)" % most)
	var material := Flowers.material("dandelion_clock")
	check(material.get_shader_parameter("flower_cycle") == true and material.get_shader_parameter("flower_cycle_times") == Seeds.cycle_times(),"the clock's material runs the round")
	check(Flowers.material("dandelion").get_shader_parameter("flower_cycle") != true,"the gold dandelion's does not")

func breeze_and_gust() -> void:
	var data := _flat_data()
	var view := View.new()
	var ids := _drift(data,Vector2(-4.0,0.0),4.0)
	var seeds := _seeds(data,view)
	check(seeds.clocks.size() > 20,"the drift's clocks are known (%d)" % seeds.clocks.size())
	# Still air: nothing goes.
	seeds.air_override = Vector2.ZERO
	_run_for(seeds,30.0)
	check(seeds.peeled == 0 and seeds.seeds_in_air() == 0,"in still air no seed leaves")
	# A brisk breeze: a few seeds now and then, no clock stripped.
	seeds.air_override = Vector2(1.8,0.0)
	_run_for(seeds,40.0)
	var partial := 0
	var bare := 0
	for id: int in view.states:
		if view.states[id] < 2.0: partial += 1
		else: bare += 1
	check(seeds.peeled >= 10 and partial > 0 and bare == 0,"a breeze peels a seed here and there (%d seeds, %d clocks thinned, %d bare)" % [seeds.peeled,partial,bare])
	var air: int = seeds.seeds_in_air()
	var downwind := 0
	for i in range(seeds._pos.size()):
		if seeds._landed[i] < 0.0 and seeds._vel[i].x > 0.5: downwind += 1
	check(air > 0 and downwind >= air/2,"seeds ride downwind (%d of %d in the air)" % [downwind,air])
	check(seeds.landed > 0,"seeds come down (%d)" % seeds.landed)
	# A gust over one side of the drift.
	var gust := Gust.new()
	gust.at = Vector2(-5.0,0.0)
	gust.reach = 1.2
	gust.lean = 1.1
	seeds.add_child(gust)
	seeds.gust = gust
	seeds.air_override = Vector2(0.4,0.0)
	_run_for(seeds,1.5)
	gust.lean = 0.0
	var under := 0
	var under_bare := 0
	var away_bare := 0
	for id: int in seeds.clocks:
		var head: Vector3 = seeds.clocks[id].p
		var d := Vector2(head.x,head.z).distance_to(gust.at)
		if d < 1.0:
			under += 1
			if float(view.states.get(id,1.0)) >= 4.0: under_bare += 1
		elif d > 1.6 and float(view.states.get(id,1.0)) >= 4.0: away_bare += 1
	check(under > 0 and under_bare == under,"a gust strips the clocks under it bare (%d of %d)" % [under_bare,under])
	check(away_bare == 0,"clocks it misses keep their seeds")
	check(seeds.seeds_in_air() > air,"the gust sends a cloud of seed (%d in the air)" % seeds.seeds_in_air())
	check(seeds._pos.size() <= Seeds.SEEDS_MAX,"never more than SEEDS_MAX seeds")
	# The round: bare, gold, closing, fluffing out, then whole.
	var some: int = -1
	for id: int in view.states:
		if view.states[id] >= 4.0: some = id
	var bare_at: float = view.states[some]-4.0
	check(bare_at >= Emergence.time-2.0 and bare_at <= Emergence.time+Seeds.BARE_JITTER,"a bare clock is stamped with when it went bare")
	seeds.air_override = Vector2.ZERO
	_run_for(seeds,Seeds.round_seconds()+Seeds.BARE_JITTER+1.0)
	check(not view.states.has(some),"it comes round to a whole clock again")
	# Undo or load: everything is whole and the air is clear.
	seeds.air_override = Vector2(1.8,0.0)
	_run_for(seeds,20.0)
	seeds.restored()
	check(view.states.is_empty() and seeds.seeds_in_air() == 0,"a restore clears the round and the air")
	seeds.get_parent().free()

func taking_root() -> void:
	var data := _flat_data()
	var view := View.new()
	var ids := _drift(data,Vector2(0.0,0.0),3.0)
	var seeds := _seeds(data,view)
	var before := data.objects.size()
	check(seeds.take(Vector2(9.0,9.0)) < 0,"a seed far from any flower does not take")
	check(seeds.take(Vector2(0.1,0.1)) < 0,"nor in the drift's full core")
	var edge := Vector2(2.6,0.2)
	var id: int = seeds.take(edge)
	check(id >= 0,"one at the drift's edge comes up")
	if id >= 0:
		var item: Dictionary = data.objects[data._object_index(id)]
		check(str(item.get("source","")) == "emerged" and item.has("born"),"as emerged life, born now")
		check(str(item.asset) in ["dandelion","dandelion_clock"],"a dandelion or a clock (%s)" % item.asset)
		check(view.drawn.size() == 1,"drawn at once through the paint preview")
	check(seeds.take(edge+Vector2(0.05,0.0)) < 0,"not on top of another plant")
	# The hand thinned the drift's other side.
	seeds.cleared(ids.slice(0,ids.size()/3))
	var thinned: Vector2 = seeds._flower_ids[int(ids[0])]
	for gone in ids.slice(0,ids.size()/3): data.remove_object(int(gone))
	seeds.reindex()
	check(seeds.take(thinned+Vector2(0.3,0.0)) < 0,"ground the hand thinned stays clear")
	# An open stroke is the player's.
	seeds.held = func() -> bool: return true
	check(seeds.take(Vector2(-2.6,1.0)) < 0,"nothing is written into an open stroke")
	seeds.held = func() -> bool: return false
	before = data.objects.size()
	# A breeze over a while: the drift creeps downwind, never far.
	seeds.air_override = Vector2(1.0,0.2)
	var count_before: int = seeds.taken.size()
	_run_for(seeds,900.0)
	var grown: Array = seeds.taken.slice(count_before)
	var reach := 0.0
	for q: Vector2 in seeds.landings: reach += q.length()
	print("  seeds landed %d, mean %.1f m from the drift's middle; refused %s" % [seeds.landings.size(),reach/maxf(seeds.landings.size(),1),seeds.refused])
	var furthest := 0.0
	for new_id: int in grown:
		var index := data._object_index(new_id)
		if index < 0: continue
		var item: Dictionary = data.objects[index]
		var p := Vector2(float(item.x),float(item.z))
		furthest = maxf(furthest,maxf(absf(p.x),absf(p.y)))
	check(grown.size() >= 1,"seeds that come down take now and then (%d new in 15 min)" % grown.size())
	check(furthest < 1.5+Seeds.CREEP*(grown.size()+1),"the drift creeps, it does not jump (furthest %.1f m)" % furthest)
	check(data.objects.size() >= before,"nothing standing is taken away")
	seeds.get_parent().free()

func in_scene() -> void:
	root.size = Vector2i(1440,900)
	# The cozy scene rolls its land with randi(): pin it so the drift sits inland.
	seed(WORLD_SEED)
	var scene: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = OS.get_temp_dir().path_join("zs-dandelions-%d/places.json" % Time.get_ticks_usec())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	var editor: NativeChunkEditor = scene._chunk_editor
	var seeds: Node3D = editor.dandelions
	check(seeds != null and seeds.get_parent() == editor.terrain,"The editor keeps the dandelion's round under the land")
	if seeds == null: return
	var data: NativeTerrainData = editor.data
	data.begin_stroke()
	var ids := _drift(data,Vector2(2.0,-1.0),2.5)
	data.end_stroke()
	await editor.refresh(self)
	for i in range(4): await process_frame
	var clocks := 0
	for id in ids: if seeds.clocks.has(int(id)): clocks += 1
	check(clocks > 5,"It reads a painted drift's clocks once the land is published (%d)" % clocks)
	data.begin_stroke()
	check(seeds.take(Vector2(4.0,-1.0)) < 0,"No seed takes into an open stroke")
	data.end_stroke()
	var drawn: int = editor.content.paint_preview_count()
	var id: int = seeds.take(Vector2(4.0,-0.9))
	check(id >= 0 and editor.content.paint_preview_count() > drawn,"A seed that takes is drawn at once")
	var reopened := NativeTerrainData.new()
	reopened.setup(data.source_mesh)
	var ok := reopened.load_document(JSON.parse_string(JSON.stringify(data.to_document())))
	var index := reopened._object_index(id) if ok else -1
	check(index >= 0 and str(reopened.objects[index].get("source","")) == "emerged" and not reopened.objects[index].has("born"),"The world saves and reopens with it, as emerged life")
	scene.queue_free()
	await process_frame
	await process_frame
