extends Node
## The next region laid late (scripts/roguelike/layer_sprawl.gd `dress`,
## windowed play): once the study's layer stands whole (its isles built,
## nothing else on the workers), the next seed's plan is laid on a worker
## (`LayerSprawl.attach_next`), then its silhouette (scripts/roguelike/
## next_region_lod.gd) is built and stood in the stage. So the first layer
## is walkable after one plan, and the second plan never competes with the
## isles' builds.
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
const Summit = preload("res://scripts/roguelike/summit.gd")  # [summit]
const NextRegionLod = preload("res://scripts/roguelike/next_region_lod.gd")

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
	if _task < 0 and Summit.final_plan(plan):  # [summit] nothing lies past the summit
		done = true
		set_process(false)
		return
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

## On the worker: the plan's next region, into `out`.
static func _job(out: Dictionary) -> void:
	var plan: Dictionary = out.plan
	var nxt := LayerSprawl.next_plan(plan)
	if (nxt.problems as Array).is_empty(): out.next = LayerSprawl._place_next(plan,nxt)

func _exit_tree() -> void:
	if _task >= 0:
		# A quit mid-plan: drained as run_layer's own plan (fixed_cache `drain`).
		preload("res://scripts/roguelike/fixed_cache.gd").drain(_task)
		_task = -1
