extends Node
## The next region laid late (scripts/roguelike/layer_sprawl.gd `dress`,
## windowed play): once the study's layer stands whole (its isles built,
## nothing else on the workers), the next seed's plan is laid on a worker
## (`LayerSprawl.attach_next`), then its silhouette (scripts/roguelike/
## next_region_lod.gd) is built and stood in the stage. So the first layer
## is walkable after one plan, and the second plan never competes with the
## isles' builds.
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
const NextRegionLod = preload("res://scripts/roguelike/next_region_lod.gd")
const IsleStore = preload("res://scripts/roguelike/isle_store.gd")

var stage: Node3D
var plan: Dictionary
var _task := -1
## Laid at once, not after the layer stands (the loading screen's: scripts/
## roguelike/layer_loading.gd), and whether it has finished (stood, or none).
var eager := false
var done := false
var _out := {}
## When it was asked for and when it stood (ms), for the log.
var _began := 0

func _init() -> void:
	name = "NextRegionLoader"

func setup(owner_stage: Node3D, layer: Dictionary) -> void:
	stage = owner_stage
	plan = layer

func _process(_delta: float) -> void:
	if _task < 0:
		var study: Variant = stage.get("study")
		if study == null or (int(study.get("layer_up_ms")) < 0 and not eager): return
		_began = Time.get_ticks_msec()
		_out = {"plan":plan}
		_task = WorkerThreadPool.add_task(_job.bind(_out),true,"next region")
		return
	if not WorkerThreadPool.is_task_completed(_task): return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	set_process(false)
	done = true
	var next: Dictionary = _out.get("next",{})
	if next.is_empty():
		print("next region: none laid past seed %d" % int(plan.seed))
		return
	plan.next = next
	var lod := NextRegionLod.build(next)
	stage.add_child(lod)
	print("next region: layer %d laid and stood in %d ms, after this layer stood" % [int(next.seed),Time.get_ticks_msec()-_began])
	preload("res://scripts/roguelike/layer_loading.gd").mark("next region stood")

## On the worker: the plan's next region, into `out`.
static func _job(out: Dictionary) -> void:
	var plan: Dictionary = out.plan
	var nxt := LayerSprawl.next_plan(plan)
	if (nxt.problems as Array).is_empty():
		out.next = LayerSprawl._place_next(plan,nxt)
		# With --forge-ahead, the next layer's isles built ahead into the isle
		# store by helpers during play (scripts/roguelike/isle_store.gd).
		IsleStore.forge_plan(nxt,true)

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
