extends RefCounted
## Walkable tops come from the rendered log triangles, never its bounding box.
## Only low, bank-supported logs qualify. This data is safe to copy to workers.
const FOOT_HALF_WIDTH := 0.18
var surfaces: Array[Dictionary] = []
var disabled := {}
var _faces := PackedVector3Array()

func load_mesh() -> void:
	if not _faces.is_empty(): return
	var source = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var logs: MultiMeshInstance3D = source.get_node("logs")
	_faces = logs.multimesh.mesh.get_faces()
	source.free()

func add(id: int, pose: Transform3D, bounds: AABB, ground: Callable) -> void:
	load_mesh()
	# The authored log runs along local X. Reject upright, steep or tiny logs.
	var axis := pose.basis.x.normalized()
	if absf(axis.y)>0.25 or pose.basis.x.length()<1.5: return
	var faces := PackedVector3Array()
	for vertex in _faces: faces.append(pose*vertex)
	var surface := {"id":id,"bounds":bounds,"faces":faces}
	var local_box := AABB(_faces[0],Vector3.ZERO)
	for vertex in _faces: local_box = local_box.expand(vertex)
	# Both ends must rest on real terrain. A hovering log is never a bridge.
	for fraction in [0.08,0.92]:
		var local := local_box.get_center()
		local.x = lerpf(local_box.position.x,local_box.end.x,fraction)
		var p := pose*local
		var height: Variant = ground.call(Vector2(p.x,p.z))
		var top: Variant = _height(surface,Vector2(p.x,p.z))
		if height == null or top == null or top-height>0.32 or height-top>0.12: return
		var bottom: Variant = _height(surface,Vector2(p.x,p.z),false)
		if bottom == null or bottom-height>0.06: return
	surfaces.append(surface)

func at(point: Vector2) -> Dictionary:
	var best := {}
	var highest := -INF
	for surface in surfaces:
		if disabled.has(int(surface.id)): continue
		var height: Variant = _height(surface,point)
		if height == null or height<=highest: continue
		var supported := true
		for offset in [Vector2(FOOT_HALF_WIDTH,0),Vector2(-FOOT_HALF_WIDTH,0),Vector2(0,FOOT_HALF_WIDTH),Vector2(0,-FOOT_HALF_WIDTH)]:
			var foot: Variant = _height(surface,point+offset)
			if foot == null or absf(foot-height)>0.20:
				supported = false
				break
		if supported:
			highest = height
			best = {"id":surface.id,"height":height,"bounds":surface.bounds}
	return best

func low_edge(surface: Dictionary, feet: Vector3) -> bool:
	if disabled.has(int(surface.id)): return false
	var box: AABB = surface.bounds
	var p := Vector2(clampf(feet.x,box.position.x+0.2,box.end.x-0.2),clampf(feet.z,box.position.z+0.2,box.end.z-0.2))
	var top: Variant = _height(surface,p)
	return top != null and top<=feet.y+0.32

func _height(surface: Dictionary, point: Vector2, upper := true) -> Variant:
	var box: AABB = surface.bounds
	if not Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).has_point(point): return null
	var from := Vector3(point.x,box.end.y+0.1,point.y)
	var to := Vector3(point.x,box.position.y-0.1,point.y)
	var highest: Variant = null
	var faces: PackedVector3Array = surface.faces
	for i in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(from,to,faces[i],faces[i+1],faces[i+2])
		if hit != null and (highest == null or (hit.y>highest if upper else hit.y<highest)): highest = hit.y
	return highest
