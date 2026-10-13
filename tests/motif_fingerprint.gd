extends RefCounted
## A motif's built isle as one string's hash (tests/test_motif_families.gd):
## every mesh's vertex count and bounds, every collider's shape and every
## node's transform under its Art, rounded to the millimetre. The same
## seed and knobs give the same hash; a moved stone changes it.

static func of(art: Node) -> String:
	var lines := PackedStringArray()
	_walk(art,"",lines)
	return "%d:%s" % [lines.size(),"\n".join(lines).md5_text()]

## The node's path by name, an engine-made name (@Class@n, numbered for the
## process) by its class and place among its siblings instead.
static func _walk(node: Node, path: String, lines: PackedStringArray) -> void:
	if node is Node3D:
		var t := (node as Node3D).transform
		lines.append("%s %s %s" % [path,_v(t.origin),_v(t.basis.x)+_v(t.basis.y)])
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh := (node as MeshInstance3D).mesh
		var count := 0
		for s in range(mesh.get_surface_count()):
			count += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var box := mesh.get_aabb()
		lines.append("%s mesh %d %s %s" % [path,count,_v(box.position),_v(box.size)])
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		lines.append("%s multimesh %d" % [path,(node as MultiMeshInstance3D).multimesh.instance_count])
	if node is CollisionShape3D and (node as CollisionShape3D).shape != null:
		var shape := (node as CollisionShape3D).shape
		var detail := shape.get_class()
		if shape is BoxShape3D: detail += _v((shape as BoxShape3D).size)
		elif shape is ConvexPolygonShape3D: detail += " %d" % (shape as ConvexPolygonShape3D).points.size()
		elif shape is ConcavePolygonShape3D: detail += " %d" % (shape as ConcavePolygonShape3D).get_faces().size()
		lines.append("%s shape %s" % [path,detail])
	for child in node.get_children():
		var own := str(child.name)
		if own.begins_with("@"): own = "%s#%d" % [child.get_class(),child.get_index()]
		_walk(child,path+"/"+own,lines)

static func _v(v: Vector3) -> String:
	return "(%d,%d,%d)" % [roundi(v.x*1000.0),roundi(v.y*1000.0),roundi(v.z*1000.0)]
