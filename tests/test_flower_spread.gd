extends SceneTree
## Pollen and slow creep for the kit's other flowers (scripts/dandelion_seeds.gd
## BLOOMS, docs/scenic/flower-spread.md). Headless: the GPU half (the glints'
## look) is not exercised.
##
## On a flat plate with drifts of daisies, poppies and so on: still air lets no
## grain go, a breeze a few and a gust more; grains ride downwind and land;
## a landed grain takes under the dandelion's rules (near flowers, room, not
## in a full core, not on thinned ground, not into an open stroke) and the new
## plant copies its parent's kind; creep is far slower than the dandelion's and
## stays near the drift; dandelions let no pollen go; blooms have no round.
const Seeds = preload("res://scripts/dandelion_seeds.gd")
const Flowers = preload("res://scripts/meadow_flower_mesh.gd")
const FlowerSowing = preload("res://scripts/flower_sowing.gd")
const Emergence = preload("res://scripts/emergence.gd")

var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: "+message)
	else:
		print("PASS: "+message)

class View extends RefCounted:
	var states := {}
	var drawn: Array = []
	func set_flower_state(id: int, state: float) -> void:
		if is_equal_approx(state,1.0): states.erase(id)
		else: states[id] = state
	func paint_preview(records: Array) -> void:
		drawn.append_array(records)

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
	var source: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	data.reset_flat()
	source.free()
	return data

## A drift on a 0.45 m grid over `size` m round `at`, each cell one of `kinds`.
func _drift(data: NativeTerrainData, at: Vector2, size: float, kinds: Array) -> Array:
	var ids: Array = []
	var n := int(size/0.45)
	for i in range(n):
		for j in range(n):
			var p := at+Vector2(i-n*0.5,j-n*0.5)*0.45
			var id := data.place(str(kinds[(i+j)%kinds.size()]),p,0.0,1.0)
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
	the_spec()
	pollen_in_the_air()
	taking_root()
	creep()
	print("Flower spread: %d failures" % failures)
	quit(1 if failures > 0 else 0)

func the_spec() -> void:
	for kind: String in Seeds.BLOOMS:
		check(Flowers.SPEC.has(kind) and not kind in Flowers.CYCLE_KINDS,"%s is a kit flower with no round" % kind)
		check(FlowerSowing.has(str(Seeds.BLOOMS[kind].slot)),"%s grows by an existing slot (%s)" % [kind,Seeds.BLOOMS[kind].slot])
	check(not Seeds.BLOOMS.has("dandelion") and not Seeds.BLOOMS.has("dandelion_clock"),"the dandelion's kinds keep their seeds, not pollen")
	var covered := true
	for kind: String in Flowers.KINDS:
		if not kind.begins_with("dandelion") and not Seeds.BLOOMS.has(kind): covered = false
	check(covered,"every other kit kind is in the spec")
	check(Seeds.POLLEN_TAKE <= Seeds.TAKE*0.25,"a grain takes at most a quarter as often as a dandelion seed")

func pollen_in_the_air() -> void:
	var data := _flat_data()
	var view := View.new()
	_drift(data,Vector2(-4.0,0.0),4.0,["poppy","oxeye_daisy","cosmos"])
	var seeds := _seeds(data,view)
	check(seeds._bloom_p.size() > 20 and seeds.clocks.is_empty(),"the blooms are known, with no clocks (%d)" % seeds._bloom_p.size())
	seeds.air_override = Vector2.ZERO
	_run_for(seeds,30.0)
	check(seeds.pollen_released == 0 and seeds.pollen_in_air() == 0,"in still air no grain leaves")
	seeds.air_override = Vector2(1.0,0.0)
	_run_for(seeds,20.0)
	var breeze: int = seeds.pollen_released
	check(breeze > 20,"a breeze lifts pollen now and then (%d grains in 20 s)" % breeze)
	var air: int = seeds.pollen_in_air()
	var downwind := 0
	for i in range(seeds._pos.size()):
		if seeds._landed[i] < 0.0 and not seeds._kind[i].is_empty() and seeds._vel[i].x > 0.3: downwind += 1
	check(air > 0 and downwind >= air/2,"grains ride downwind (%d of %d)" % [downwind,air])
	check(seeds.peeled == 0 and seeds.seeds_in_air() == 0 and view.states.is_empty(),"no seeds fly and nothing is peeled or stripped")
	check(seeds._pos.size() <= Seeds.POLLEN_MAX and seeds._pollen_n <= Seeds.POLLEN_MAX,"never more than POLLEN_MAX grains")
	var kinds_ok := true
	for k in seeds._kind: if not k.is_empty() and not Seeds.BLOOMS.has(k): kinds_ok = false
	check(kinds_ok,"each grain comes from a bloom of the spec")
	check(seeds.landed > 0,"grains come down (%d)" % seeds.landed)
	# Stronger air: more of them.
	seeds.clear_air()
	var before: int = seeds.pollen_released
	seeds.air_override = Vector2(1.0,0.0)
	_run_for(seeds,10.0)
	var calm: int = seeds.pollen_released-before
	seeds.clear_air()
	before = seeds.pollen_released
	seeds.air_override = Vector2(2.0,0.0)
	_run_for(seeds,10.0)
	var brisk: int = seeds.pollen_released-before
	check(brisk > calm,"a stronger air lifts more (%d against %d in 10 s)" % [brisk,calm])
	# A gust over a corner shakes loose more than the breeze, from where it blows.
	seeds.clear_air()
	seeds.air_override = Vector2(0.4,0.0)
	var gust := Gust.new()
	gust.at = Vector2(-5.0,0.0)
	gust.reach = 1.4
	gust.lean = 1.1
	seeds.add_child(gust)
	seeds.gust = gust
	before = seeds.pollen_released
	_run_for(seeds,3.0)
	var gusted: int = seeds.pollen_released-before
	seeds.gust = null
	seeds.clear_air()
	before = seeds.pollen_released
	_run_for(seeds,3.0)
	var quiet: int = seeds.pollen_released-before
	check(gusted > quiet*2,"a gust shakes loose far more pollen (%d against %d in 3 s)" % [gusted,quiet])
	seeds.get_parent().free()
	# Dandelions let none go.
	var data2 := _flat_data()
	_drift(data2,Vector2(0.0,0.0),3.0,["dandelion","dandelion_clock"])
	var dandelions := _seeds(data2,View.new())
	dandelions.air_override = Vector2(1.0,0.0)
	_run_for(dandelions,30.0)
	check(dandelions.pollen_released == 0 and dandelions._bloom_p.is_empty(),"dandelions let no pollen go")
	dandelions.get_parent().free()

func taking_root() -> void:
	var data := _flat_data()
	var view := View.new()
	var ids := _drift(data,Vector2(0.0,0.0),3.0,["poppy"])
	var seeds := _seeds(data,view)
	check(seeds.take(Vector2(9.0,9.0),"poppy") < 0,"a grain far from any flower does not take")
	check(seeds.take(Vector2(0.1,0.1),"poppy") < 0,"nor in the drift's full core")
	var edge := Vector2(2.6,0.2)
	var id: int = seeds.take(edge,"poppy")
	check(id >= 0,"one at the drift's edge comes up")
	if id >= 0:
		var item: Dictionary = data.objects[data._object_index(id)]
		check(str(item.asset) == "poppy","it copies its parent's kind (%s)" % item.asset)
		check(str(item.get("source","")) == "emerged" and item.has("born"),"as emerged life, born now")
		check(view.drawn.size() == 1,"drawn at once through the paint preview")
		check(seeds._bloom_p.size() == ids.size()+1,"and it lets pollen go in its turn")
	check(seeds.take(edge+Vector2(0.05,0.0),"poppy") < 0,"not on top of another plant")
	seeds.cleared(ids.slice(0,ids.size()/3))
	var thinned: Vector2 = seeds._flower_ids[int(ids[0])]
	for gone in ids.slice(0,ids.size()/3): data.remove_object(int(gone))
	seeds.reindex()
	check(seeds.take(thinned+Vector2(0.3,0.0),"poppy") < 0,"ground the hand thinned stays clear")
	seeds.held = func() -> bool: return true
	check(seeds.take(Vector2(-2.6,1.0),"poppy") < 0,"nothing is written into an open stroke")
	seeds.held = func() -> bool: return false
	for kind: String in Seeds.BLOOMS:
		var fresh: int = seeds.take(Vector2(-1.0,-2.7)+Vector2(0.4,0.0)*float(Seeds.BLOOMS.keys().find(kind)),kind)
		check(fresh >= 0,"a %s grain comes up beside the drift" % kind)
		if fresh >= 0:
			var made: Dictionary = data.objects[data._object_index(fresh)]
			check(str(made.asset) == kind,"%s grows a %s" % [kind,kind])
	seeds.get_parent().free()

## Creep over a long breeze: slow beside the dandelion's, and near the drift.
func creep() -> void:
	var results := {}
	for kind: String in ["dandelion","poppy","oxeye_daisy"]:
		var data := _flat_data()
		var drift := ["dandelion","dandelion_clock"] if kind == "dandelion" else [kind]
		var ids := _drift(data,Vector2.ZERO,3.0,drift)
		var seeds := _seeds(data,View.new())
		seeds.air_override = Vector2(1.0,0.2)
		_run_for(seeds,1800.0)
		var furthest := 0.0
		var copies := true
		for new_id: int in seeds.taken:
			var item: Dictionary = data.objects[data._object_index(new_id)]
			furthest = maxf(furthest,maxf(absf(float(item.x)),absf(float(item.z))))
			if kind != "dandelion" and str(item.asset) != kind: copies = false
		results[kind] = seeds.taken.size()
		print("  %s: %d new plants in 30 min from %d, furthest %.1f m, pollen %d, refused %s" % [kind,seeds.taken.size(),ids.size(),furthest,seeds.pollen_released,seeds.refused])
		if kind != "dandelion":
			check(seeds.taken.size() >= 1,"%s creeps a little (%d new in 30 min)" % [kind,seeds.taken.size()])
			check(copies,"all of it %s" % kind)
		check(furthest < 1.5+Seeds.CREEP*(seeds.taken.size()+1),"%s creeps, it does not jump (%.1f m)" % [kind,furthest])
		seeds.get_parent().free()
	var slow: float = (float(results.poppy)+float(results.oxeye_daisy))*0.5
	check(slow <= float(results.dandelion)*0.5,"the other kinds creep far slower than dandelions (%.1f against %d)" % [slow,results.dandelion])
