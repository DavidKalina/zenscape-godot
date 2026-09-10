class_name CreatureNavigation
extends RefCounted
## Small, deterministic navigation map for one authored chunk. Rebuild after a
## committed terrain/prop/water edit, not every frame. Routes are ground points.
const STEP := 0.7
const RADIUS := 0.5
const SLOPE_PROBE := 0.3
const MAX_RISE := 0.22
const LIMIT := 41
var _grid_step := STEP
var _slope_rise := MAX_RISE
var _data: RefCounted
var _clearance: Callable
var dynamic_clearance: Callable
var _nodes := PackedVector3Array()
var _cells := {}
var _edges := {}
var _ponds: Array[Dictionary] = []
var _courses: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var last_rebuild_usec := 0
var rebuilding := false
var generation := 0
var _rebuild_cell := 0
var _rebuild_side := 0
var _use_shortcuts := true
var _rejected_connections: Array[Dictionary] = []
## Poll at the caller's existing update boundary. At most one finite group is
## active; repeated edits only replace the generation waiting to be submitted.
var thread_workers := 4
var last_worker_count := 0
var last_worker_usec := 0
var last_submit_usec := 0
var last_validation_usec := 0
var last_worker_executed := false
var _threaded := false
var _work = preload("res://scripts/background_work.gd").new()
var _work_generation := -1
var _worker_checks_clearance := false
var _candidate_parts: Array = []
var _candidate_part := 0
var _candidate_cell := 0
var _replacement_nodes := PackedVector3Array()
var _replacement_cells := {}


## Terrain provider: ground_height, ponds/pond_surface, streams, objects,
## waterfall_impacts. Fidelity supplies imported ground and clearance instead.
func rebuild(data: RefCounted, clearance: Callable, grid_step := STEP, slope_rise := MAX_RISE) -> void:
	begin_rebuild(data,clearance,grid_step,slope_rise)
	while not advance_rebuild(1000000): pass

## Live editors spread the grid scan over frames. Callers suspend route planning
## until completion; a newer edit restarts the scan against the latest world.
func begin_rebuild(data: RefCounted, clearance: Callable, grid_step := STEP, slope_rise := MAX_RISE, threaded := false) -> void:
	generation += 1
	_slope_rise = slope_rise
	_grid_step = clampf(grid_step,0.35,1.0)
	var began := Time.get_ticks_usec()
	_data = data
	_clearance = clearance
	_threaded = threaded and data.has_method("navigation_snapshot")
	_candidate_parts = []
	_candidate_part = 0
	_candidate_cell = 0
	_replacement_nodes = PackedVector3Array()
	_replacement_cells = {}
	last_worker_count = 0
	last_worker_usec = 0
	last_submit_usec = 0
	last_validation_usec = 0
	last_worker_executed = false
	if not _threaded:
		_nodes.clear()
		_cells.clear()
	_edges.clear()
	_use_shortcuts = true
	_rejected_connections.clear()
	_ponds.clear()
	_courses.clear()
	_impacts.clear()
	for pond in data.ponds:
		var vertices: PackedVector3Array = data.pond_surface(pond)
		var bounds := Rect2()
		if not vertices.is_empty():
			bounds = Rect2(Vector2(vertices[0].x,vertices[0].z),Vector2.ZERO)
			for vertex in vertices: bounds = bounds.expand(Vector2(vertex.x,vertex.z))
		_ponds.append({"vertices":vertices,"bounds":bounds.grow(RADIUS),"level":pond.level})
	for stream in data.streams:
		for i in range(stream.pts.size()-1):
			var a: Dictionary = stream.pts[i]
			var b: Dictionary = stream.pts[i+1]
			_courses.append({"a":Vector2(a.x,a.z),"b":Vector2(b.x,b.z),"radius":float(stream.width)*0.5+RADIUS,"level":maxf(a.h,b.h)+float(stream.surface)})
	for item in data.objects:
		if item.asset == "waterfall":
			_courses.append({"a":Vector2(item.x,item.z),"b":Vector2(item.end_x,item.end_z),"radius":float(item.scale)*0.5+RADIUS,"level":INF})
	_impacts = data.waterfall_impacts()
	_rebuild_cell = 0
	_rebuild_side = roundi(28.0/_grid_step)+1
	rebuilding = true
	last_rebuild_usec = Time.get_ticks_usec()-began

func advance_rebuild(budget_usec := 2000) -> bool:
	if not rebuilding: return true
	if _threaded: return _advance_threaded(budget_usec)
	# Synchronous callers retain their API. Reclaim a superseded finite task
	# before finishing this rebuild, so completed pool resources cannot linger.
	if _work.active():
		if not _work.completed(): return false
		_work.finish()
	var began := Time.get_ticks_usec()
	while _rebuild_cell < _rebuild_side*_rebuild_side:
		var x := _rebuild_cell % _rebuild_side
		var z := _rebuild_cell / _rebuild_side
		var point := Vector3(-14.0+x*_grid_step,0,-14.0+z*_grid_step)
		var grounded: Variant = _ground(point)
		if grounded != null and _safe_grounded(grounded):
			_cells[Vector2i(x,z)] = _nodes.size()
			_nodes.append(grounded)
		_rebuild_cell += 1
		if Time.get_ticks_usec()-began >= budget_usec: break
	last_rebuild_usec += Time.get_ticks_usec()-began
	rebuilding = _rebuild_cell < _rebuild_side*_rebuild_side
	return not rebuilding

func _submit_scan() -> void:
	var began := Time.get_ticks_usec()
	var count := clampi(thread_workers,1,mini(8,maxi(1,OS.get_processor_count()-2)))
	var total := _rebuild_side*_rebuild_side
	var actions: Array[Callable] = []
	_worker_checks_clearance = false
	for i in range(count):
		var snapshot: RefCounted = _data.navigation_snapshot()
		var scan := CreatureNavigation.new()
		scan._data = snapshot
		scan._grid_step = _grid_step
		scan._slope_rise = _slope_rise
		scan._rebuild_side = _rebuild_side
		scan._ponds.assign(_ponds.duplicate(true))
		scan._courses.assign(_courses.duplicate(true))
		scan._impacts.assign(_impacts.duplicate(true))
		# Only the explicit snapshot provider's pure static clearance is allowed
		# on workers. Arbitrary callbacks and moving-body clearance stay live.
		if snapshot.has_method("clear_at") and _clearance.get_object() == _data and _clearance.get_method() == &"clear_at":
			scan._clearance = Callable(snapshot,"clear_at")
			_worker_checks_clearance = true
		actions.append(_sample_partition.bind(scan,total*i/count,total*(i+1)/count))
	_work.start_group(actions,count)
	_work_generation = generation
	last_worker_count = count
	last_submit_usec = Time.get_ticks_usec()-began
	last_rebuild_usec += last_submit_usec

## A bound RefCounted argument owns the scanner until completion. A method
## Callable alone does not keep its object alive after submission returns.
static func _sample_partition(scan: CreatureNavigation, begin: int, end: int) -> Dictionary:
	return scan._sample_cells(begin,end)

## Executed only on private providers. Contiguous partitions preserve scan order.
func _sample_cells(begin: int, end: int) -> Dictionary:
	var began := Time.get_ticks_usec()
	var nodes := PackedVector3Array()
	var cells: Array[Vector2i] = []
	for index in range(begin,end):
		var x := index % _rebuild_side
		var z := index / _rebuild_side
		var grounded: Variant = _ground(Vector3(-14.0+x*_grid_step,0,-14.0+z*_grid_step))
		if grounded != null and _safe_grounded(grounded):
			nodes.append(grounded)
			cells.append(Vector2i(x,z))
	return {"nodes":nodes,"cells":cells,"usec":Time.get_ticks_usec()-began,"worker":WorkerThreadPool.get_caller_group_id() >= 0}

func _advance_threaded(budget_usec: int) -> bool:
	if _work.active():
		if not _work.completed(): return false
		var result: Array = _work.finish()
		if _work_generation == generation:
			_candidate_parts = result
			last_worker_executed = true
			for part: Dictionary in result:
				last_worker_usec += int(part.usec)
				last_worker_executed = last_worker_executed and part.worker
			last_rebuild_usec += last_worker_usec
	# Do not submit superseded requests. The latest generation is the only one
	# that follows an old task once it has joined, bounding the pool queue.
	if _work_generation != generation:
		_submit_scan()
		return false
	var began := Time.get_ticks_usec()
	while _candidate_part < _candidate_parts.size():
		var part: Dictionary = _candidate_parts[_candidate_part]
		if _candidate_cell >= part.nodes.size():
			_candidate_part += 1
			_candidate_cell = 0
			continue
		var point: Vector3 = part.nodes[_candidate_cell]
		var safe := not dynamic_clearance.is_valid() or bool(dynamic_clearance.call(point))
		if safe and not _worker_checks_clearance and _clearance.is_valid():
			safe = bool(_clearance.call(point))
		if safe:
			_replacement_cells[part.cells[_candidate_cell]] = _replacement_nodes.size()
			_replacement_nodes.append(point)
		_candidate_cell += 1
		if Time.get_ticks_usec()-began >= budget_usec: break
	var spent := Time.get_ticks_usec()-began
	last_validation_usec += spent
	last_rebuild_usec += spent
	if _candidate_part < _candidate_parts.size(): return false
	# No partial candidate map escapes. Physics callbacks above run only at the
	# main-thread boundary where the caller invokes advance_rebuild.
	_nodes = _replacement_nodes
	_cells = _replacement_cells
	_replacement_nodes = PackedVector3Array()
	_replacement_cells = {}
	_candidate_parts = []
	rebuilding = false
	return true

func _ground(point: Vector3) -> Variant:
	if _data == null or not point.is_finite(): return null
	var height: Variant = _data.ground_height(Vector2(point.x,point.z))
	return Vector3(point.x,height,point.z) if height != null else null

func _wet(point: Vector3) -> bool:
	var p := Vector2(point.x,point.z)
	for pond in _ponds:
		if point.y > float(pond.level)+0.05 or not pond.bounds.has_point(p): continue
		for offset in [Vector2.ZERO,Vector2(RADIUS,0),Vector2(-RADIUS,0),Vector2(0,RADIUS),Vector2(0,-RADIUS)]:
			if GardenWater.covers(pond.vertices,p+offset): return true
	for course in _courses:
		if point.y <= float(course.level)+0.15 and p.distance_to(Geometry2D.get_closest_point_to_segment(p,course.a,course.b)) < course.radius: return true
	for impact in _impacts:
		if p.distance_to(Vector2(impact.x,impact.z)) < float(impact.radius)+RADIUS: return true
	return false

func is_safe(point: Vector3) -> bool:
	var grounded: Variant = _ground(point)
	if grounded == null or absf(point.y-grounded.y) > 0.25: return false
	return _safe_grounded(grounded)

func _safe_grounded(point: Vector3) -> bool:
	if absf(point.x) > 14.0-RADIUS or absf(point.z) > 14.0-RADIUS: return false
	for offset in [Vector2(SLOPE_PROBE,0),Vector2(-SLOPE_PROBE,0),Vector2(0,SLOPE_PROBE),Vector2(0,-SLOPE_PROBE)]:
		var height: Variant = _data.ground_height(Vector2(point.x,point.z)+offset)
		if height == null or absf(height-point.y) > _slope_rise: return false
	if _wet(point): return false
	if dynamic_clearance.is_valid() and not dynamic_clearance.call(point): return false
	return not _clearance.is_valid() or bool(_clearance.call(point))

func segment_safe(a: Vector3,b: Vector3) -> bool:
	if not a.is_finite() or not b.is_finite(): return false
	var length := Vector2(a.x-b.x,a.z-b.z).length()
	var count := maxi(1,int(ceil(length/0.025)))
	var previous: Variant = null
	for i in range(count+1):
		var position: Variant = _ground(a.lerp(b,float(i)/count))
		if position == null or not _safe_grounded(position): return false
		if previous != null and absf(position.y-previous.y) > MAX_RISE: return false
		previous = position
	return true

## Routes are validated at planning/edit boundaries. During playback check the
## actual next foot displacement, so a long clear leg costs no more per frame
## than a short grid edge. Match CreatureActor's horizontal travel convention.
func motion_safe(from: Vector3, to: Vector3, travel: float) -> bool:
	var distance := Vector2(to.x-from.x,to.z-from.z).length()
	var next := to if distance<=travel else from.lerp(to,travel/distance)
	return segment_safe(from,next)

func nearest_safe(point: Vector3) -> Variant:
	if not point.is_finite(): return null
	var ground: Variant = _ground(point)
	if ground != null and _safe_grounded(ground): return ground
	var nearest: Variant = null
	var distance := INF
	for candidate in _nodes:
		var score := candidate.distance_squared_to(point)
		if score < distance and is_safe(candidate):
			distance = score
			nearest = candidate
	return nearest

func _connect(point: Vector3) -> int:
	var closest := -1
	var cell := Vector2i(roundi((point.x+14.0)/_grid_step),roundi((point.z+14.0)/_grid_step))
	var nearby: Array[int] = []
	for z in range(cell.y-2,cell.y+3):
		for x in range(cell.x-2,cell.x+3):
			var index: int = _cells.get(Vector2i(x,z),-1)
			if index>=0: nearby.append(index)
	nearby.sort_custom(func(a: int,b: int) -> bool: return _nodes[a].distance_squared_to(point)<_nodes[b].distance_squared_to(point))
	for i in nearby:
		var score := _nodes[i].distance_squared_to(point)
		if score>=_grid_step*_grid_step*3.0: break
		var rejected := false
		for connection in _rejected_connections:
			if connection.node==i and point.distance_squared_to(connection.point)<0.0001:
				rejected = true
				break
		if not rejected and segment_safe(point,_nodes[i]): return i
	return closest

func path(from: Vector3,to: Vector3) -> PackedVector3Array:
	if rebuilding: return PackedVector3Array()
	if not is_safe(from) or not is_safe(to): return PackedVector3Array()
	if _use_shortcuts and segment_safe(from,to): return PackedVector3Array([from,to])
	# Optimistically search the safe-cell graph, then validate just the candidate
	# route. Rejected edges stay blocked for this map lifetime and force a reroute.
	# This preserves exact swept checks without querying physics for every edge
	# of every expanded node. No unvalidated segment is ever returned.
	while true:
		var candidate := _candidate_path(from,to)
		if candidate.is_empty(): return candidate
		var valid := true
		for i in range(1,candidate.size()-2):
			var a: int = _cells[Vector2i(roundi((candidate[i].x+14.0)/_grid_step),roundi((candidate[i].z+14.0)/_grid_step))]
			var b: int = _cells[Vector2i(roundi((candidate[i+1].x+14.0)/_grid_step),roundi((candidate[i+1].z+14.0)/_grid_step))]
			var key := Vector2i(mini(a,b),maxi(a,b))
			if not _edges.has(key): _edges[key] = segment_safe(candidate[i],candidate[i+1])
			if not _edges[key]:
				valid = false
		if valid: return _straighten(candidate) if _use_shortcuts else candidate
	return PackedVector3Array()

## Keep only necessary corners. Every shortcut receives the same swept terrain,
## water and obstacle check as a normal edge; never cut across an unsafe corner.
func _straighten(route: PackedVector3Array) -> PackedVector3Array:
	var result := PackedVector3Array([route[0]])
	var start := 0
	while start < route.size()-1:
		var next := start+1
		# Search only a bounded neighborhood, retaining tested clear shortcuts.
		# A blocked long chord does not invalidate the underlying safe grid path.
		var high := mini(route.size()-1,start+8)
		var candidate := high
		while candidate>next:
			if segment_safe(route[start],route[candidate]): next = candidate
			else: high = candidate-1
			candidate = (next+high+1)/2
		result.append(route[next])
		start = next
	return result

## A moving actor may expose a narrow slope/clearance failure between the
## original edge samples. Reject that graph edge before asking for another route.
func reject_segment(a: Vector3, b: Vector3) -> void:
	# A runtime sample can expose a fine edge missed by a long shortcut.
	# Replan on the original validated grid until the next terrain rebuild.
	_use_shortcuts = false
	var ac := Vector2i(roundi((a.x+14.0)/_grid_step),roundi((a.z+14.0)/_grid_step))
	var bc := Vector2i(roundi((b.x+14.0)/_grid_step),roundi((b.z+14.0)/_grid_step))
	var ai: int = _cells.get(ac,-1)
	var bi: int = _cells.get(bc,-1)
	var a_on_grid := ai>=0 and _nodes[ai].distance_to(a)<=0.01
	var b_on_grid := bi>=0 and _nodes[bi].distance_to(b)<=0.01
	if not a_on_grid and b_on_grid:
		_rejected_connections.append({"point":a,"node":bi})
	elif a_on_grid and not b_on_grid:
		_rejected_connections.append({"point":b,"node":ai})
	elif a_on_grid and b_on_grid:
		_edges[Vector2i(mini(ai,bi),maxi(ai,bi))] = false

func _candidate_path(from: Vector3,to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()

	var start := _connect(from)
	var finish := _connect(to)
	if start < 0 or finish < 0: return result
	var open: Array[int] = [start]
	var scores := {start:0.0}
	var parents := {}
	var closed := {}
	while not open.is_empty():
		var best := 0
		for i in range(1,open.size()):
			if float(scores[open[i]])+_nodes[open[i]].distance_to(to) < float(scores[open[best]])+_nodes[open[best]].distance_to(to): best = i
		var current := open[best]
		open.remove_at(best)
		if current == finish:
			result.append(to)
			while current != start:
				result.append(_nodes[current])
				current = parents[current]
			result.append(_nodes[start])
			result.append(from)
			result.reverse()
			return result
		closed[current] = true
		var cell := Vector2i(roundi((_nodes[current].x+14.0)/_grid_step),roundi((_nodes[current].z+14.0)/_grid_step))
		for offset in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]:
			if not _cells.has(cell+offset): continue
			var next: int = _cells[cell+offset]
			if closed.has(next): continue
			if offset.x != 0 and offset.y != 0 and (not _cells.has(cell+Vector2i(offset.x,0)) or not _cells.has(cell+Vector2i(0,offset.y))): continue
			if not _edges.get(Vector2i(mini(current,next),maxi(current,next)),true): continue
			var score: float = scores[current]+_nodes[current].distance_to(_nodes[next])
			if not scores.has(next) or score < float(scores[next]):
				scores[next] = score
				parents[next] = current
				if not open.has(next): open.append(next)
	return result
