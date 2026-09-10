extends SceneTree
## Script replacement in inherited scenes must not strand member-owned nodes.
var failures := 0
var frame_signals := 0
func _initialize() -> void:
	process_frame.connect(func() -> void: frame_signals += 1)
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func abandoned_checkpoint() -> WeakRef:
	var budget = preload("res://scripts/frame_work_budget.gd").new(self)
	budget._started = Time.get_ticks_usec()-budget.USEC
	var reference: WeakRef = weakref(budget)
	budget.checkpoint()
	return reference
func run() -> void:
	var budget = preload("res://scripts/frame_work_budget.gd").new(self)
	budget._started = Time.get_ticks_usec()-budget.USEC
	# The first native process_frame can fire while Engine's frame count is
	# still zero. Count the signal we actually await, including that first one.
	var frame_before := frame_signals
	await budget.checkpoint()
	check(frame_signals == frame_before+1,"An exhausted budget waits for the next frame signal")
	frame_before = frame_signals
	await budget.checkpoint()
	check(frame_signals == frame_before,"A resumed budget starts a fresh slice without another immediate yield")
	var pending := abandoned_checkpoint()
	check(pending.get_ref() != null,"A pending frame reset owns its budget until the signal fires")
	for _frame in range(2): await process_frame
	check(pending.get_ref() == null,"The frame reset releases an abandoned budget")
	# The base scene can be discarded before _ready; inherited scenes exercise
	# their actual startup/shutdown, including pending reflection preparation.
	for name in ["fidelity", "bigfoot_life", "open_meadow"]:
		var packed: PackedScene = load("res://studies/"+name+".tscn")
		var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var scene := packed.instantiate()
		if name != "fidelity":
			root.add_child(scene)
			for _frame in range(5): await process_frame
		scene.free()
		for _frame in range(5): await process_frame
		var after := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		check(after == before,name+": scene lifetime leaves no orphan nodes (delta %d)" % int(after-before))
	print("Inherited scene lifecycle: ",failures," failures")
	quit(1 if failures else 0)
