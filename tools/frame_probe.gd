extends Node
## Stamps a frame's parts (tools/bench_loading.gd --frames): two of these,
## one first (`first`) and one last in the tree's process and physics order.
## The first's `rows` gets, per process frame: [physics steps, physics usec,
## process usec].
var first := false
var other: Node
var rows: Array = []
var _phys_us := 0
var _phys_n := 0
var _phys_at := 0
var _proc_at := 0

func _init(is_first := false) -> void:
	first = is_first
	process_priority = -100000 if first else 100000
	process_physics_priority = -100000 if first else 100000

func _physics_process(_d: float) -> void:
	if first: _phys_at = Time.get_ticks_usec()
	else:
		other._phys_us += Time.get_ticks_usec()-other._phys_at
		other._phys_n += 1

func _process(_d: float) -> void:
	if first: _proc_at = Time.get_ticks_usec()
	else:
		other.rows.append([other._phys_n,other._phys_us,Time.get_ticks_usec()-other._proc_at])
		other._phys_n = 0
		other._phys_us = 0
