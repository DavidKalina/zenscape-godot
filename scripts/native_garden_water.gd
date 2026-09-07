class_name NativeGardenWater
extends RefCounted
## Flood connected terrain triangles at a fixed level, then clip each shoreline
## against its real sloping triangle. Disconnected hollows remain dry.

static func surface(data: NativeTerrainData, pond: Dictionary) -> PackedVector3Array:
	if data._recipe != null:
		return preload("res://scripts/native_recipe_water.gd").surface(data,pond)
	var triangles: Array[PackedInt32Array] = []
	for i in range(0,data.vertex_ids.size(),3):
		triangles.append(data.vertex_ids.slice(i,i+3))
	var point := Vector2(pond.x, pond.z)
	var level: float = pond.level
	if data.ground_height(point) == null or data.ground_height(point) >= level:
		return PackedVector3Array()
	var first := -1
	for offset: int in data._buckets.get(Vector2i(floori(point.x/2),floori(point.y/2)),[]):
		var triangle := PackedVector2Array([data.points[data.vertex_ids[offset]], data.points[data.vertex_ids[offset+1]], data.points[data.vertex_ids[offset+2]]])
		if Geometry2D.is_point_in_polygon(point,triangle):
			first = offset/3
			break
	if first < 0:
		return PackedVector3Array()
	var positions := PackedVector3Array()
	for i in range(data.points.size()):
		positions.append(data._vertex(i))
	return GardenWater.flood(positions,triangles,first,level)
