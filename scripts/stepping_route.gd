extends RefCounted
## A bounded, cancellable extension for one desired stream crossing. Ordinary
## inhabitants keep using ordinary navigation; only this outing can request hops.
const Plate = preload("res://scripts/plate.gd")
const REACH := 1.45
const ARC := 0.42

static func arc_point(a: Vector3, b: Vector3, progress: float) -> Vector3:
	return a.lerp(b,progress)+Vector3.UP*sin(progress*PI)*ARC

static func hop_safe(nav: CreatureNavigation, a: Vector3, b: Vector3) -> bool:
	var distance := Vector2(a.x-b.x,a.z-b.z).length()
	if distance<0.45 or distance>REACH or absf(a.y-b.y)>0.3: return false
	if not nav.is_safe(a) or not nav.is_safe(b): return false
	var middle: Variant = nav._ground(a.lerp(b,0.5))
	if middle == null or not nav._wet(middle): return false
	var over_water := false
	for i in range(1,25):
		var t := float(i)/25.0
		var feet := arc_point(a,b,t)
		var ground: Variant = nav._ground(feet)
		if ground == null or ground.y>feet.y+0.04: return false
		over_water = over_water or nav._wet(ground)
		# Water can be below the arc; trunks, boulders and overhead scenery cannot.
		if nav._clearance.is_valid() and not nav._clearance.call(feet): return false
		if nav.dynamic_clearance.is_valid() and not nav.dynamic_clearance.call(feet): return false
	return over_water

func plan(nav: CreatureNavigation, tree: SceneTree, from: Vector3, to: Vector3, current: Callable, query: RefCounted = null) -> Dictionary:
	if query == null:
		query = preload("res://scripts/creature_route_query.gd").new()
		query.setup(nav,tree,current)
	var start: int = await query.connect_point(from)
	var finish: int = await query.connect_point(to)
	if start<0 or finish<0: return {}
	# The useful stone can be a short walk along the bank from the direct line.
	var corridor := Rect2(Vector2(from.x,from.z),Vector2.ZERO).expand(Vector2(to.x,to.z)).grow(3.0)
	var open: Array[int] = [start]
	var scores := {start:0.0}
	var parents := {}
	var closed := {}
	var hop_edges := {}
	var offsets: Array[Vector2i] = []
	var radius := ceili(REACH/nav._grid_step)
	for z in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			if (x!=0 or z!=0) and Vector2(x,z).length()*nav._grid_step<=REACH: offsets.append(Vector2i(x,z))
	while not open.is_empty() and closed.size()<600:
		if not await query.checkpoint(): return {}
		var best := 0
		for i in range(1,open.size()):
			if float(scores[open[i]])+nav._nodes[open[i]].distance_to(to)<float(scores[open[best]])+nav._nodes[open[best]].distance_to(to): best = i
		var node := open[best]
		open.remove_at(best)
		if node == finish:
			var indices: Array[int] = [finish]
			while node != start:
				node = parents[node]
				indices.push_front(node)
			var points := PackedVector3Array([from])
			var hops := {}
			for i in range(indices.size()):
				if i>0 and hop_edges.get(Vector2i(indices[i-1],indices[i]),false): hops[points.size()] = true
				points.append(nav._nodes[indices[i]])
			points.append(to)
			return {"points":points,"hops":hops}
		closed[node] = true
		var a: Vector3 = nav._nodes[node]
		var cell := Vector2i(roundi((a.x+Plate.HALF)/nav._grid_step),roundi((a.z+Plate.HALF)/nav._grid_step))
		for offset in offsets:
			if not await query.checkpoint(): return {}
			var next: int = nav._cells.get(cell+offset,-1)
			if next<0 or closed.has(next): continue
			var b: Vector3 = nav._nodes[next]
			if not corridor.has_point(Vector2(b.x,b.z)): continue
			var walked := false
			if absi(offset.x)<=1 and absi(offset.y)<=1: walked = await query.segment(a,b)
			var hopped := not walked and hop_safe(nav,a,b)
			if not walked and not hopped: continue
			var cost: float = scores[node]+a.distance_to(b)+(1.0 if hopped else 0.0)
			if not scores.has(next) or cost<float(scores[next]):
				scores[next] = cost
				parents[next] = node
				hop_edges[Vector2i(node,next)] = hopped
				if not open.has(next): open.append(next)
	return {}
