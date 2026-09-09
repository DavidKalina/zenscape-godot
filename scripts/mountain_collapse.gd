extends RefCounted
## Blast-triggered talus relaxation on the native terrain's connected vertices.
## Vertex control areas conserve displaced volume despite irregular triangles.
## This is a local rockslide model, not a volumetric fracture simulation.
const REPOSE := 0.68
const CONNECT_SLOPE := 0.38
const PASSES := 32
const MAX_VERTICES := 2400
const MAX_CHUNKS := 32

## A null tree keeps this synchronous. The live remote passes the scene tree so
## the relaxation passes spread across a few frames under the blast flash.
static func collapse(data: NativeTerrainData, before_blast: PackedFloat32Array, origin: Vector3, radius: float, surface_colors := PackedColorArray(), frame_tree: SceneTree = null) -> Dictionary:
	var center := Vector2(origin.x,origin.z)
	var reach := clampf(radius*3.4,6.0,16.0)
	var low := INF
	var high := -INF
	var seeds := PackedInt32Array()
	for i in range(data.points.size()):
		if data.points[i].distance_to(center) > reach: continue
		low = minf(low,before_blast[i])
		high = maxf(high,before_blast[i])
		if before_blast[i]-data.heights[i] > 0.12 and data.points[i].distance_to(center) < radius:
			seeds.append(i)
	# Flat-ground craters stay craters. There must be a high, damaged slope and
	# enough downhill relief for gravity to produce a readable collapse.
	if seeds.is_empty() or high-low < 3.8 or origin.y+radius*0.5 < low+(high-low)*0.55: return {}
	var initial := data.heights.duplicate()
	var active := {}
	var frontier := PackedInt32Array()
	for id in seeds:
		active[id] = true
		frontier.append(id)
	var cursor := 0
	while cursor < frontier.size() and active.size() < MAX_VERTICES:
		var id := frontier[cursor]
		cursor += 1
		for neighbor in data._neighbors[id]:
			if active.has(neighbor) or data.points[neighbor].distance_to(center) > reach: continue
			var distance := data.points[id].distance_to(data.points[neighbor])
			if distance < 0.0001: continue
			var slope := maxf(absf(initial[id]-initial[neighbor]),absf(before_blast[id]-before_blast[neighbor]))/distance
			if slope < CONNECT_SLOPE: continue
			active[neighbor] = true
			frontier.append(neighbor)
			if active.size() >= MAX_VERTICES: break
	# One ring of receivers makes a toe of rubble instead of losing mass at the
	# edge of the loosened patch. Receivers do not propagate failure farther.
	var edges: Array[Vector2i] = []
	var seen := {}
	for id: int in active:
		for neighbor in data._neighbors[id]:
			var edge := Vector2i(mini(id,neighbor),maxi(id,neighbor))
			if seen.has(edge): continue
			seen[edge] = true
			edges.append(edge)
	var areas := control_areas(data)
	var height := PackedFloat64Array(Array(initial))
	var budget = preload("res://scripts/frame_work_budget.gd").new(frame_tree)
	for pass_index in range(PASSES):
		if frame_tree != null and pass_index % 8 == 0: await budget.checkpoint()
		for step in range(edges.size()):
			var edge := edges[step if pass_index%2 == 0 else edges.size()-1-step]
			var a := edge.x if height[edge.x] > height[edge.y] else edge.y
			var b := edge.y if a == edge.x else edge.x
			if not active.has(a) or areas[a] < 0.00001 or areas[b] < 0.00001: continue
			var distance := data.points[a].distance_to(data.points[b])
			var excess: float = height[a]-height[b]-REPOSE*distance
			if excess <= 0.0: continue
			var volume := excess*0.42/(1.0/areas[a]+1.0/areas[b])
			var floor_height := maxf(data.MIN_HEIGHT,initial[a]-radius*2.0)
			volume = minf(volume,maxf(0,height[a]-floor_height)*areas[a])
			volume = minf(volume,maxf(0,data.MAX_HEIGHT-height[b])*areas[b])
			height[a] -= volume/areas[a]
			height[b] += volume/areas[b]
	var final := PackedFloat32Array(Array(height))
	var removed := 0.0
	var deposited := 0.0
	var changed := Rect2()
	var has_region := false
	for i in range(final.size()):
		var difference := float(initial[i])-final[i]
		removed += maxf(0,difference)*areas[i]
		deposited += maxf(0,-difference)*areas[i]
		if absf(difference) < 0.08: continue
		changed = changed.expand(data.points[i]) if has_region else Rect2(data.points[i],Vector2.ZERO)
		has_region = true
	if removed < 0.6 or not has_region: return {}
	var chunks := _chunks(data,initial,final,origin,radius,surface_colors)
	data.heights = final
	_strip_cover(data,initial,final,changed)
	return {"before":initial,"after":final,"region":changed,"removed_volume":removed,"deposited_volume":deposited,"chunks":chunks}

static func control_areas(data: NativeTerrainData) -> PackedFloat64Array:
	var areas := PackedFloat64Array()
	areas.resize(data.points.size())
	for face in range(0,data.vertex_ids.size(),3):
		var a := data.vertex_ids[face]
		var b := data.vertex_ids[face+1]
		var c := data.vertex_ids[face+2]
		var third := absf((data.points[b]-data.points[a]).cross(data.points[c]-data.points[a]))/6.0
		areas[a] += third
		areas[b] += third
		areas[c] += third
	return areas

static func displacement(data: NativeTerrainData, result: Dictionary, point: Vector2) -> float:
	if result.is_empty() or not result.region.grow(0.1).has_point(point): return 0.0
	return float(data.sample(point,result.before))-float(data.sample(point,result.after))

static func _strip_cover(data: NativeTerrainData, initial: PackedFloat32Array, final: PackedFloat32Array, region: Rect2) -> void:
	for z in range(data.MEADOW_CELLS):
		for x in range(data.MEADOW_CELLS):
			var point := data.meadow_position(x,z)
			if not region.grow(0.1).has_point(point): continue
			var before: Variant = data.sample(point,initial)
			var after: Variant = data.sample(point,final)
			if before == null or after == null or absf(before-after) < 0.12: continue
			var id: int = z*data.MEADOW_CELLS+x
			data.grass[id] = 0
			data.meadow[id] = 0
			data.blades[id] = 0

static func _chunks(data: NativeTerrainData, initial: PackedFloat32Array, final: PackedFloat32Array, origin: Vector3, radius: float, surface_colors: PackedColorArray, radial := false) -> Array[Dictionary]:
	var groups := {}
	var colors: PackedColorArray = surface_colors if not surface_colors.is_empty() else data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var cell := maxf(1.1,radius*0.48)
	for face in range(0,data.vertex_ids.size(),3):
		var ids := [data.vertex_ids[face],data.vertex_ids[face+1],data.vertex_ids[face+2]]
		var loss: float = ((initial[ids[0]]-final[ids[0]])+(initial[ids[1]]-final[ids[1]])+(initial[ids[2]]-final[ids[2]]))/3.0
		if loss < 0.18: continue
		var center: Vector2 = (data.points[ids[0]]+data.points[ids[1]]+data.points[ids[2]])/3.0
		var key := Vector2i(floori(center.x/cell),floori(center.y/cell))
		if not groups.has(key): groups[key] = {"faces":[],"loss":0.0,"center":Vector3.ZERO,"count":0}
		groups[key].faces.append({"ids":ids,"color":colors[face] if colors.size()>face else Color("a39a82").srgb_to_linear()})
		groups[key].loss += loss
		groups[key].center += Vector3(center.x,(initial[ids[0]]+initial[ids[1]]+initial[ids[2]])/3.0,center.y)
		groups[key].count += 1
	var ranked := groups.values()
	ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.loss > b.loss)
	if radial:
		# Reserve representatives around the charge before filling by volume, so
		# the body cap cannot make an internal burst look like a one-sided peel.
		var ordered := []
		var sectors := {}
		for group: Dictionary in ranked:
			var center: Vector3 = group.center/group.count
			var sector := posmod(int(floor((atan2(center.z-origin.z,center.x-origin.x)+PI)/TAU*8)),8)
			if not sectors.has(sector):
				sectors[sector] = true
				ordered.append(group)
		for group: Dictionary in ranked:
			if not ordered.has(group): ordered.append(group)
		ranked = ordered
	var chunks: Array[Dictionary] = []
	for index in range(mini(ranked.size(),MAX_CHUNKS)):
		var group: Dictionary = ranked[index]
		var center: Vector3 = group.center/group.count
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face: Dictionary in group.faces:
			var ids: Array = face.ids
			var top: Array[Vector3] = []
			var bottom: Array[Vector3] = []
			for id: int in ids:
				top.append(Vector3(data.points[id].x,initial[id],data.points[id].y)-center)
				bottom.append(Vector3(data.points[id].x,minf(final[id],initial[id]-0.12),data.points[id].y)-center)
			_triangle(surface,top[0],top[1],top[2],face.color)
			_triangle(surface,bottom[2],bottom[1],bottom[0],face.color*0.5)
			for edge in range(3):
				var next := (edge+1)%3
				_triangle(surface,top[edge],bottom[edge],top[next],face.color*0.72)
				_triangle(surface,top[next],bottom[edge],bottom[next],face.color*0.72)
		var gradient := _gradient(data,initial,Vector2(center.x,center.z))
		var downhill := Vector3(-gradient.x,0,-gradient.y).normalized()
		if downhill.length_squared() < 0.1: downhill = Vector3(center.x-origin.x,0,center.z-origin.z).normalized()
		chunks.append({"mesh":surface.commit(),"center":center,"velocity":downhill*minf(7,2+gradient.length()*2)+Vector3(0,-1,0),"delay":0.12+minf(0.65,center.distance_to(origin)*0.045)})
	return chunks

static func _gradient(data: NativeTerrainData, heights: PackedFloat32Array, point: Vector2) -> Vector2:
	var result := Vector2.ZERO
	for axis in range(2):
		var offset := Vector2(0.35,0) if axis == 0 else Vector2(0,0.35)
		var a: Variant = data.sample(point+offset,heights)
		var b: Variant = data.sample(point-offset,heights)
		if a != null and b != null: result[axis] = (a-b)/0.7
	return result

static func _triangle(surface: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	surface.set_color(Color(color.r,color.g,color.b,1.0))
	surface.set_normal((c-a).cross(b-a).normalized())
	for vertex in [a,b,c]: surface.add_vertex(vertex)
