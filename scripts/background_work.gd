extends RefCounted
## Finite, data-only tasks. Inputs belong to their callables; results become
## readable only after joining. Polling supports physics-boundary publication.
var _task := -1
var _group := false
var _results: Array = []
var _partitions := 0
static var _stats_lock := Mutex.new()
static var _jobs := 0
static var _partitions_pending := 0
static var _peak_jobs := 0
static var _peak_partitions := 0
## Abandoned jobs still running when freed: [task, group, partitions], joined
## once they complete (_reclaim), never waited on from PREDELETE.
static var _orphans: Array = []
## Every submitted task not yet joined (task: group), for the drain at exit.
static var _running := {}
static var _drain_hooked := false

## Submitted work awaiting its join, not the number of CPU threads executing.
static func statistics() -> Dictionary:
	_reclaim()
	_stats_lock.lock()
	var result := {"jobs":_jobs,"partitions":_partitions_pending,"peak_jobs":_peak_jobs,"peak_partitions":_peak_partitions}
	_stats_lock.unlock()
	return result

func _submitted(partitions: int) -> void:
	_reclaim()
	_hook_drain()
	_partitions = partitions
	_stats_lock.lock()
	_running[_task] = _group
	_jobs += 1
	_partitions_pending += partitions
	_peak_jobs = maxi(_peak_jobs,_jobs)
	_peak_partitions = maxi(_peak_partitions,_partitions_pending)
	_stats_lock.unlock()

func active() -> bool:
	return _task != -1

func start(action: Callable) -> void:
	assert(not active(), "A background job cannot be reused while running")
	_group = false
	_results = [null]
	var result := _results
	_task = WorkerThreadPool.add_task(func(): result[0] = action.call(),false,"Background data work")
	_submitted(1)

func start_group(actions: Array[Callable], workers: int) -> void:
	assert(not active(), "A background job cannot be reused while running")
	assert(not actions.is_empty() and actions.size() <= 8, "Groups must have one to eight independent partitions")
	_results = []
	_results.resize(actions.size())
	var result := _results
	var inputs: Array[Callable] = actions.duplicate()
	var mutex := Mutex.new()
	_group = true
	_task = WorkerThreadPool.add_group_task(func(index: int) -> void:
		var value: Variant = inputs[index].call()
		mutex.lock()
		result[index] = value
		mutex.unlock(),actions.size(),clampi(workers,1,8),false,"Background data group")
	_submitted(actions.size())

func completed() -> bool:
	return not active() or (WorkerThreadPool.is_group_task_completed(_task) if _group else WorkerThreadPool.is_task_completed(_task))

func finish() -> Variant:
	assert(active() and completed(), "Poll completion before publishing results")
	return _take()

## Block until the job is done and take its result. Only for a join that must
## publish now, such as a new undo step opening on ground still settling
## (native_chunk_editor.gd `_join_weathering`); everything else polls.
func wait() -> Variant:
	assert(active(), "Nothing to wait for")
	return _take()

func _take() -> Variant:
	_join()
	var result: Variant = _results if _group else _results[0]
	_results = []
	_group = false
	return result

func run(action: Callable, tree: SceneTree = null) -> Variant:
	assert(not active(), "A background job cannot be reused while running")
	if tree == null: return action.call()
	# Keep this finite job alive through its own await even if the scene that
	# requested it is freed. The local releases it immediately after joining.
	var work := self
	work.start(action)
	while not work.completed(): await tree.process_frame
	return work.finish()

func run_group(actions: Array[Callable], tree: SceneTree, workers: int) -> Array:
	assert(not active(), "A background job cannot be reused while running")
	assert(actions.size() <= 8, "Partition before submission; no unbounded job queues")
	if actions.is_empty(): return []
	if tree == null:
		var result := []
		for action in actions: result.append(action.call())
		return result
	var work := self
	work.start_group(actions,workers)
	while not work.completed(): await tree.process_frame
	return work.finish()

func _join() -> void:
	_release(_task,_group,_partitions)
	_task = -1
	_partitions = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _task != -1:
		# The callback captures input/result storage, never the awaiting owner.
		# A finished job joins now. A running one is never waited on here: an
		# abandoned await is freed under GDScript's language lock (a scene freed
		# mid-job, the quit), and a worker reaching for that lock would never
		# finish, so the join waits for _reclaim. At the quit, _drain has let
		# every job finish before the tree came down.
		if _done(_task,_group): _release(_task,_group,_partitions)
		else:
			_stats_lock.lock()
			_orphans.append([_task,_group,_partitions])
			_stats_lock.unlock()
		_task = -1

static func _done(task: int, group: bool) -> bool:
	return WorkerThreadPool.is_group_task_completed(task) if group else WorkerThreadPool.is_task_completed(task)

static func _release(task: int, group: bool, partitions: int) -> void:
	if group: WorkerThreadPool.wait_for_group_task_completion(task)
	else: WorkerThreadPool.wait_for_task_completion(task)
	_stats_lock.lock()
	_running.erase(task)
	_jobs -= 1
	_partitions_pending -= partitions
	_stats_lock.unlock()

## Join the abandoned jobs that have finished since.
static func _reclaim() -> void:
	_stats_lock.lock()
	var finished := _orphans.filter(func(orphan: Array) -> bool: return _done(orphan[0],orphan[1]))
	for orphan in finished: _orphans.erase(orphan)
	_stats_lock.unlock()
	for orphan in finished: _release(orphan[0],orphan[1],orphan[2])

## The quit frees abandoned awaits under the language lock, then shuts the
## script languages down; a worker still running GDScript then would hang or
## crash. So when the root leaves the tree, before any of that, every job
## runs to its end. Results still join where they are taken.
func _hook_drain() -> void:
	if _drain_hooked: return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null: return
	_drain_hooked = true
	tree.root.tree_exiting.connect(Callable(get_script(),"_drain"))

static func _drain() -> void:
	_stats_lock.lock()
	var running := _running.duplicate()
	_stats_lock.unlock()
	for task in running:
		while not _done(task,running[task]): OS.delay_usec(200)
	_reclaim()
