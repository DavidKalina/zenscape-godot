class_name GardenWater
extends RefCounted
## Flood connected terrain triangles at a fixed level, then clip each shoreline
## against its real sloping triangle. Disconnected hollows remain dry.

static func surface(data: LandscapeData, pond: Dictionary) -> PackedVector3Array:
	var triangles: Array[PackedInt32Array] = []
	for z in range(LandscapeData.CELLS):
		for x in range(LandscapeData.CELLS):
			var a := z * LandscapeData.SIDE + x
			triangles.append(PackedInt32Array([a, a + 1, a + LandscapeData.SIDE]))
			triangles.append(PackedInt32Array([a + 1, a + LandscapeData.SIDE + 1, a + LandscapeData.SIDE]))
	var point := Vector2(pond.x, pond.z)
	var level: float = pond.level
	if data.height_at(point) >= level:
		return PackedVector3Array()
	var g := (point + Vector2.ONE * LandscapeData.WIDTH * 0.5) / LandscapeData.STEP
	var x := mini(int(g.x), LandscapeData.CELLS-1)
	var z := mini(int(g.y), LandscapeData.CELLS-1)
	var first := (z * LandscapeData.CELLS + x) * 2 + (1 if g.x-x+g.y-z > 1.0 else 0)
	var positions := PackedVector3Array()
	for i in range(data.heights.size()):
		positions.append(_vertex(data,i))
	return flood(positions,triangles,first,level)

static func flood(positions: PackedVector3Array, triangles: Array[PackedInt32Array], first: int, level: float) -> PackedVector3Array:
	var edges := {}
	for i in range(triangles.size()):
		var t := triangles[i]
		for j in range(3):
			var key := Vector2i(mini(t[j], t[(j+1)%3]), maxi(t[j], t[(j+1)%3]))
			if not edges.has(key):
				edges[key] = []
			edges[key].append(i)
	var queue: Array[int] = [first]
	var visited := {first: true}
	var vertices := PackedVector3Array()
	var cursor := 0
	while cursor < queue.size():
		var index := queue[cursor]
		cursor += 1
		var triangle := triangles[index]
		var polygon: Array[Vector3] = []
		for j in range(3):
			var a := triangle[j]
			var b := triangle[(j+1)%3]
			var pa := positions[a]
			var pb := positions[b]
			if pa.y < level:
				polygon.append(Vector3(pa.x, level, pa.z))
			if (pa.y < level) != (pb.y < level):
				var cut := pa.lerp(pb, (level-pa.y)/(pb.y-pa.y))
				polygon.append(Vector3(cut.x, level, cut.z))
			if minf(pa.y, pb.y) < level:
				var neighbors: Array = edges[Vector2i(mini(a,b), maxi(a,b))]
				# A pond needs a bank: refuse levels that spill off the diorama.
				if neighbors.size() == 1:
					return PackedVector3Array()
				for neighbor: int in neighbors:
					if not visited.has(neighbor):
						visited[neighbor] = true
						queue.append(neighbor)
		for j in range(1, polygon.size()-1):
			vertices.append_array(PackedVector3Array([polygon[0], polygon[j], polygon[j+1]]))
	return vertices

static func _vertex(data: LandscapeData, index: int) -> Vector3:
	var point := LandscapeData.grid_position(index % LandscapeData.SIDE, index / LandscapeData.SIDE)
	return Vector3(point.x, data.heights[index], point.y)

static func covers(vertices: PackedVector3Array, point: Vector2) -> bool:
	for i in range(0, vertices.size(), 3):
		var polygon := PackedVector2Array()
		for j in range(3):
			polygon.append(Vector2(vertices[i+j].x, vertices[i+j].z))
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false

static func fetch(data: LandscapeData, point: Vector2, level: float) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	for i in range(8):
		var direction := Vector2.from_angle(float(i) * PI / 4.0)
		var distance := 0.0
		for step in range(1, 49):
			var sample := point + direction * float(step) * 0.5
			if not data.contains(sample) or data.height_at(sample) >= level:
				break
			distance = float(step) * 0.5
		distances.append(distance)
	return distances
