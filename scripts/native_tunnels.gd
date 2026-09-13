extends RefCounted
## Bounded straight mine bores. Clip the heightfield skin against a box, then
## clip inward-facing bore walls to each original terrain triangle's solid prism.
## The source heightfield stays intact for landscape algorithms and sealing.
const MAX_TUNNELS := 6
const EPS := 0.00001

static func valid(records: Variant) -> bool:
	if not records is Array or records.size()>MAX_TUNNELS: return false
	for item in records:
		if not item is Dictionary or not item.get("start") is Array or item.start.size()!=3: return false
		for value in item.start:
			if not GardenData._number(value,-64,64): return false
		for key in ["heading","width","height","length"]:
			if not GardenData._number(item.get(key),-TAU if key=="heading" else 1.0,TAU if key=="heading" else 18.0): return false
		if not item.get("sealed") is bool: return false
		if item.has("cave") and not item.cave is bool: return false
		if item.has("cave_scale") and not GardenData._number(item.cave_scale,0.5,1.5): return false
		var size: float = item.get("cave_scale",1.0)
		if item.get("cave",false) and (item.width<6.4*size-0.0001 or item.height<4.8*size-0.0001 or item.length<7.2*size-0.0001): return false
	return true

static func pose(item: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,float(item.heading)),Vector3(item.start[0],item.start[1],item.start[2]))

static func plan(data: NativeTerrainData, hit: Vector3, direction: Vector3, width: float, depth: float) -> Dictionary:
	if data.tunnels.size()>=MAX_TUNNELS: return {}
	direction.y = 0
	if direction.length()<0.01: return {}
	direction = direction.normalized()
	var floor_y := hit.y-0.25
	var height := width*1.1
	var start := hit-direction*0.5
	start.y = floor_y
	# Put the open end wholly outside the slope, avoiding an invisible front wall.
	for i in range(12):
		var outside: Variant = data.ground_height(Vector2(start.x,start.z))
		if outside != null and outside < floor_y-0.05: break
		start -= direction*0.4
	var outside: Variant = data.ground_height(Vector2(start.x,start.z))
	if outside == null or outside >= floor_y: return {}
	var length := Vector2(start.x-hit.x,start.z-hit.z).length()+depth
	var end := start+direction*length
	var roof: Variant = data.ground_height(Vector2(end.x,end.z))
	if roof == null or roof < floor_y+height+0.3 or floor_y < data.MIN_HEIGHT: return {}
	var item := {"start":[start.x,start.y,start.z],"heading":atan2(direction.x,direction.z),"width":width,"height":height,"length":length,"sealed":false}
	# Separate bores keep sealing predictable and avoid internal crossing walls.
	var box := bounds(item).grow(0.15)
	for other in data.tunnels:
		if box.intersects(bounds(other)): return {}
	return item if valid([item]) else {}

static func bounds(item: Dictionary) -> AABB:
	return pose(item)*AABB(Vector3(-item.width/2,0,0),Vector3(item.width,item.height,item.length))

static func inside(item: Dictionary, point: Vector3) -> bool:
	return AABB(Vector3(-item.width/2,-0.1,0),Vector3(item.width,item.height+0.2,item.length)).has_point(pose(item).affine_inverse()*point)

static func charge_point(item: Dictionary) -> Vector3:
	return pose(item)*Vector3(0,0,minf(item.length-0.5,item.length*0.8))

static func build(source: ArrayMesh, records: Array) -> ArrayMesh:
	var result := source
	for item: Dictionary in records:
		if not item.sealed: result = _cut(result,item)
	return result

static func _vertex(arrays: Array, id: int) -> Array:
	return [arrays[Mesh.ARRAY_VERTEX][id],arrays[Mesh.ARRAY_NORMAL][id],arrays[Mesh.ARRAY_COLOR][id],arrays[Mesh.ARRAY_TEX_UV][id],arrays[Mesh.ARRAY_TEX_UV2][id]]

static func _cut(source: ArrayMesh, item: Dictionary) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty():
		var expanded := SurfaceTool.new()
		expanded.create_from(source,0)
		expanded.deindex()
		arrays = expanded.commit_to_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var transform := pose(item)
	var w: float = item.width/2
	var h: float = item.height
	var d: float = item.length
	var planes: Array[Plane] = []
	for side in [[Vector3.RIGHT,w],[Vector3.LEFT,w],[Vector3.UP,h],[Vector3.DOWN,0.0],[Vector3.BACK,d],[Vector3.FORWARD,0.0]]:
		var normal: Vector3 = transform.basis*side[0]
		planes.append(Plane(normal,normal.dot(transform.origin)+side[1]))
	var quads := [
		[Vector3(-w,0,0),Vector3(w,0,0),Vector3(w,0,d),Vector3(-w,0,d)],
		[Vector3(-w,h,0),Vector3(-w,h,d),Vector3(w,h,d),Vector3(w,h,0)],
		[Vector3(-w,0,0),Vector3(-w,0,d),Vector3(-w,h,d),Vector3(-w,h,0)],
		[Vector3(w,0,0),Vector3(w,h,0),Vector3(w,h,d),Vector3(w,0,d)],
		[Vector3(-w,0,d),Vector3(w,0,d),Vector3(w,h,d),Vector3(-w,h,d)],
	]
	var wall_normals := [Vector3.UP,Vector3.DOWN,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := bounds(item)
	for face in range(0,vertices.size(),3):
		var polygon: Array = [_vertex(arrays,face),_vertex(arrays,face+1),_vertex(arrays,face+2)]
		var tri_box := AABB(vertices[face],Vector3.ZERO).expand(vertices[face+1]).expand(vertices[face+2]).grow(EPS)
		# A triangle wholly above the roof still supplies interior wall clipping.
		var footprint := AABB(Vector3(tri_box.position.x,box.position.y,tri_box.position.z),Vector3(tri_box.size.x,box.size.y,tri_box.size.z))
		if not box.grow(EPS).intersects(footprint):
			_emit(surface,polygon)
			continue
		var remaining := polygon
		for plane in planes:
			_emit(surface,_clip(remaining,plane,false))
			remaining = _clip(remaining,plane,true)
			if remaining.size()<3: break
		# Closed triangular column beneath the original skin. Skip vertical
		# bore walls from earlier cuts (overlapping bores are rejected at creation).
		var a := vertices[face]
		var b := vertices[face+1]
		var c := vertices[face+2]
		var upward := (c-a).cross(b-a).normalized()
		if absf(upward.y)<0.0001: continue
		if upward.y<0: upward = -upward
		var solid: Array[Plane] = [Plane(upward,upward.dot(a))]
		var corners := [a,b,c]
		for edge in range(3):
			var first: Vector3 = corners[edge]
			var second: Vector3 = corners[(edge+1)%3]
			var third: Vector3 = corners[(edge+2)%3]
			var normal := Vector3(second.z-first.z,0,first.x-second.x).normalized()
			if normal.dot(third-first)>0: normal = -normal
			solid.append(Plane(normal,normal.dot(first)))
		for wall in range(quads.size()):
			var inner: Array = []
			var color := Color("746552").srgb_to_linear()*(0.92+float((face/3)%5)*0.035)
			for corner: Vector3 in quads[wall]:
				var point: Vector3 = transform*corner
				inner.append([point,transform.basis*wall_normals[wall],color,Vector2(0,1),Vector2(0.5,point.y)])
			for plane in solid: inner = _clip(inner,plane,true)
			_emit(surface,inner)
	var result := surface.commit()
	result.surface_set_material(0,source.surface_get_material(0))
	# Preserve separately shaded outer banks when the terrain has a chasm.
	for i in range(1,source.get_surface_count()):
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(i))
		result.surface_set_material(i,source.surface_get_material(i))
	return result

static func _clip(polygon: Array, plane: Plane, negative: bool) -> Array:
	var result := []
	if polygon.is_empty(): return result
	var previous: Array = polygon.back()
	var before := plane.distance_to(previous[0])*(1.0 if negative else -1.0)
	for current: Array in polygon:
		var after := plane.distance_to(current[0])*(1.0 if negative else -1.0)
		if (before<=0) != (after<=0):
			var weight := before/(before-after)
			var crossing := []
			for channel in range(5): crossing.append(previous[channel].lerp(current[channel],weight))
			result.append(crossing)
		if after<=0: result.append(current)
		previous = current
		before = after
	return result

static func _emit(surface: SurfaceTool, polygon: Array) -> void:
	for i in range(1,polygon.size()-1):
		var triangle := [polygon[0],polygon[i],polygon[i+1]]
		if (triangle[1][0]-triangle[0][0]).cross(triangle[2][0]-triangle[0][0]).length_squared()<0.00000001: continue
		# Match Godot's clockwise front face, including inward-facing tunnel walls.
		if (triangle[2][0]-triangle[0][0]).cross(triangle[1][0]-triangle[0][0]).dot(triangle[0][1])<0: triangle.reverse()
		for vertex: Array in triangle:
			surface.set_normal(vertex[1])
			surface.set_color(vertex[2])
			surface.set_uv(vertex[3])
			surface.set_uv2(vertex[4])
			surface.add_vertex(vertex[0])
