extends RefCounted
## Cancellable main-thread route work. Every terrain probe and graph expansion
## shares one frame budget; waiting never stalls the actor's animation/rendering.
const Plate = preload("res://scripts/plate.gd")
const BUDGET_USEC := 1500
var navigation: CreatureNavigation
var tree: SceneTree
var valid: Callable
var peak_slice_usec := 0
var slices := 0
var _started := 0
var _generation := 0
var aborted := false

func setup(map: CreatureNavigation, scene_tree: SceneTree, still_valid: Callable) -> void:
	navigation = map
	tree = scene_tree
	valid = still_valid
	_generation = map.generation
	_started = Time.get_ticks_usec()

func current() -> bool:
	return not aborted and navigation.generation == _generation and not navigation.rebuilding and valid.is_valid() and valid.call()

func finish_slice() -> void:
	peak_slice_usec = maxi(peak_slice_usec,Time.get_ticks_usec()-_started)

func checkpoint() -> bool:
	if not current():
		aborted = true
		return false
	if Time.get_ticks_usec()-_started>=BUDGET_USEC:
		finish_slice()
		slices += 1
		await tree.process_frame
		_started = Time.get_ticks_usec()
		if not current():
			aborted = true
			return false
	return true

func segment(a: Vector3,b: Vector3) -> bool:
	if not a.is_finite() or not b.is_finite(): return false
	var count := maxi(1,int(ceil(Vector2(a.x-b.x,a.z-b.z).length()/0.025)))
	var previous: Variant = null
	for i in range(count+1):
		if not await checkpoint(): return false
		var point: Variant = navigation._ground(a.lerp(b,float(i)/count))
		if point == null or not navigation._safe_grounded(point): return false
		if previous != null and absf(point.y-previous.y)>CreatureNavigation.MAX_RISE: return false
		previous = point
	return true

func nearest(point: Vector3) -> Variant:
	if not await checkpoint() or not point.is_finite(): return null
	var ground: Variant = navigation._ground(point)
	if ground != null and navigation._safe_grounded(ground): return ground
	var result: Variant = null
	var distance := INF
	for candidate in navigation._nodes:
		if not await checkpoint(): return null
		var score := candidate.distance_squared_to(point)
		if score<distance and navigation.is_safe(candidate):
			distance = score
			result = candidate
	return result

func connect_point(point: Vector3) -> int:
	var cell := Vector2i(roundi((point.x+Plate.HALF)/navigation._grid_step),roundi((point.z+Plate.HALF)/navigation._grid_step))
	var candidates: Array[int] = []
	for z in range(cell.y-2,cell.y+3):
		for x in range(cell.x-2,cell.x+3):
			var id: int = navigation._cells.get(Vector2i(x,z),-1)
			if id>=0: candidates.append(id)
	candidates.sort_custom(func(a: int,b: int) -> bool: return navigation._nodes[a].distance_squared_to(point)<navigation._nodes[b].distance_squared_to(point))
	for id in candidates:
		if not await checkpoint(): return -1
		if navigation._nodes[id].distance_squared_to(point)>=navigation._grid_step*navigation._grid_step*3.0: break
		var rejected := false
		for connection in navigation._rejected_connections:
			if connection.node == id and connection.point.distance_squared_to(point)<0.0001:
				rejected = true
				break
		if not rejected and await segment(point,navigation._nodes[id]): return id
	return -1

func path(from: Vector3,to: Vector3) -> PackedVector3Array:
	var empty := PackedVector3Array()
	if not await checkpoint() or not navigation.is_safe(from) or not navigation.is_safe(to): return empty
	if navigation._use_shortcuts and await segment(from,to): return PackedVector3Array([from,to])
	var start := await connect_point(from)
	var finish := await connect_point(to)
	if start<0 or finish<0: return empty
	while await checkpoint():
		var candidate := await graph_path(from,to,start,finish)
		if candidate.is_empty(): return empty
		var accepted := true
		for i in range(1,candidate.size()-2):
			if not await checkpoint(): return empty
			var a := cell_id(candidate[i])
			var b := cell_id(candidate[i+1])
			var key := Vector2i(mini(a,b),maxi(a,b))
			# Check dynamic clearance afresh even when a static edge was cached.
			if not navigation._edges.has(key) or navigation.dynamic_clearance.is_valid():
				var safe := await segment(candidate[i],candidate[i+1])
				if not current(): return empty
				navigation._edges[key] = safe
			if not navigation._edges[key]: accepted = false
		if accepted:
			return await straighten(candidate) if navigation._use_shortcuts else candidate
	return empty

func cell_id(point: Vector3) -> int:
	return navigation._cells[Vector2i(roundi((point.x+Plate.HALF)/navigation._grid_step),roundi((point.z+Plate.HALF)/navigation._grid_step))]

func graph_path(from: Vector3,to: Vector3,start: int,finish: int) -> PackedVector3Array:
	var open: Array[int] = [start]
	var scores := {start:0.0}
	var parents := {}
	var closed := {}
	while not open.is_empty():
		if not await checkpoint(): return PackedVector3Array()
		var best := 0
		for i in range(1,open.size()):
			if scores[open[i]]+navigation._nodes[open[i]].distance_to(to)<scores[open[best]]+navigation._nodes[open[best]].distance_to(to): best = i
		var node := open[best]
		open.remove_at(best)
		if node == finish:
			var result := PackedVector3Array([to])
			while node != start:
				result.append(navigation._nodes[node])
				node = parents[node]
			result.append(navigation._nodes[start])
			result.append(from)
			result.reverse()
			return result
		closed[node] = true
		var cell := Vector2i(roundi((navigation._nodes[node].x+Plate.HALF)/navigation._grid_step),roundi((navigation._nodes[node].z+Plate.HALF)/navigation._grid_step))
		for offset in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]:
			var next: int = navigation._cells.get(cell+offset,-1)
			if next<0 or closed.has(next): continue
			if offset.x!=0 and offset.y!=0 and (not navigation._cells.has(cell+Vector2i(offset.x,0)) or not navigation._cells.has(cell+Vector2i(0,offset.y))): continue
			if not navigation._edges.get(Vector2i(mini(node,next),maxi(node,next)),true): continue
			var score: float = scores[node]+navigation._nodes[node].distance_to(navigation._nodes[next])
			if not scores.has(next) or score<scores[next]:
				scores[next] = score
				parents[next] = node
				if not open.has(next): open.append(next)
	return PackedVector3Array()

func straighten(route: PackedVector3Array) -> PackedVector3Array:
	var result := PackedVector3Array([route[0]])
	var start := 0
	while start<route.size()-1:
		if not await checkpoint(): return PackedVector3Array()
		var next := start+1
		var high := mini(route.size()-1,start+8)
		var candidate := high
		while candidate>next:
			if await segment(route[start],route[candidate]): next = candidate
			else: high = candidate-1
			if not current(): return PackedVector3Array()
			candidate = (next+high+1)/2
		if not current(): return PackedVector3Array()
		result.append(route[next])
		start = next
	return result
