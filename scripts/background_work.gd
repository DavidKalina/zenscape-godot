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

## Submitted work awaiting its join, not the number of CPU threads executing.
static func statistics() -> Dictionary:
	_stats_lock.lock()
	var result := {"jobs":_jobs,"partitions":_partitions_pending,"peak_jobs":_peak_jobs,"peak_partitions":_peak_partitions}
	_stats_lock.unlock()
	return result

func _submitted(partitions: int) -> void:
	_partitions = partitions
	_stats_lock.lock()
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
	_submitted(1)
	_task = WorkerThreadPool.add_task(func(): result[0] = action.call(),false,"Background data work")

func start_group(actions: Array[Callable], workers: int) -> void:
	assert(not active(), "A background job cannot be reused while running")
	assert(not actions.is_empty() and actions.size() <= 8, "Groups must have one to eight independent partitions")
	_results = []
	_results.resize(actions.size())
	var result := _results
	var inputs: Array[Callable] = actions.duplicate()
	var mutex := Mutex.new()
	_group = true
	_submitted(actions.size())
	_task = WorkerThreadPool.add_group_task(func(index: int) -> void:
		var value: Variant = inputs[index].call()
		mutex.lock()
		result[index] = value
		mutex.unlock(),actions.size(),clampi(workers,1,8),false,"Background data group")

func completed() -> bool:
	return not active() or (WorkerThreadPool.is_group_task_completed(_task) if _group else WorkerThreadPool.is_task_completed(_task))

func finish() -> Variant:
	assert(active() and completed(), "Poll completion before publishing results")
	_join()
	var result: Variant = _results if _group else _results[0]
	_results = []
	_group = false
	return result

func run(action: Callable, tree: SceneTree = null) -> Variant:
	assert(not active(), "A background job cannot be reused while running")
	if tree == null: return action.call()
	start(action)
	while not completed(): await tree.process_frame
	return finish()

func run_group(actions: Array[Callable], tree: SceneTree, workers: int) -> Array:
	assert(not active(), "A background job cannot be reused while running")
	assert(actions.size() <= 8, "Partition before submission; no unbounded job queues")
	if actions.is_empty(): return []
	if tree == null:
		var result := []
		for action in actions: result.append(action.call())
		return result
	start_group(actions,workers)
	while not completed(): await tree.process_frame
	return finish()

func _join() -> void:
	if _group: WorkerThreadPool.wait_for_group_task_completion(_task)
	else: WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_stats_lock.lock()
	_jobs -= 1
	_partitions_pending -= _partitions
	_stats_lock.unlock()
	_partitions = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _task != -1:
		# The callback captures input/result storage, never the awaiting owner.
		# Abandoned finite jobs still join, including when the scene exits.
		if _group: WorkerThreadPool.wait_for_group_task_completion(_task)
		else: WorkerThreadPool.wait_for_task_completion(_task)
		_stats_lock.lock()
		_jobs -= 1
		_partitions_pending -= _partitions
		_stats_lock.unlock()
