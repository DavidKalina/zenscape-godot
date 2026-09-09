extends RefCounted
## Shared impact operation: explosions and future meteor impacts use the same crater.
## Heightfield deformation, not voxel destruction: no caves or overhangs.

static func carve(data: LandscapeData, center: Vector2, radius: float) -> void:
	if radius <= 0.0 or not data.contains(center): return
	for z in range(LandscapeData.SIDE):
		for x in range(LandscapeData.SIDE):
			var distance := LandscapeData.grid_position(x, z).distance_to(center)
			var q := distance / radius
			if q >= 1.0: continue
			var index := z * LandscapeData.SIDE + x
			var bowl := (1.0 - smoothstep(0.0, 0.8, q)) * radius * 0.65
			var rim := exp(-pow((q - 0.8) / 0.11, 2.0)) * radius * 0.09
			data.heights[index] = clampf(data.heights[index] - bowl + rim,
				LandscapeData.MIN_HEIGHT, LandscapeData.MAX_HEIGHT)
	if data is GardenData: data.paint_meadow(center, radius, -3.0)

static func impulse(origin: Vector3, point: Vector3, radius: float) -> Vector3:
	var offset := point - origin
	var reach := radius * 1.8
	if offset.length() >= reach: return Vector3.ZERO
	var direction := (offset.normalized() + Vector3.UP * 1.15).normalized()
	return direction * (1.0 - offset.length() / reach) * radius * 8.0

static func carve_native(data: NativeTerrainData, origin: Vector3, radius: float) -> void:
	# Native terrain has irregular, shared vertices rather than the study's grid.
	# Measure from the buried charge, so dirt added above it is excavated too.
	var center := Vector2(origin.x,origin.z)
	for i in range(data.points.size()):
		var q: float = data.points[i].distance_to(center) / radius
		if q >= 1.0: continue
		var cover: float = data.heights[i] - origin.y
		if absf(cover) > radius * 1.8: continue
		var weight := 1.0 - smoothstep(0.0,0.85,q)
		var depth := (radius * 0.65 + maxf(0.0,cover)) * weight
		var rim := exp(-pow((q-0.85)/0.1,2.0)) * radius * 0.07
		data.heights[i] = clampf(data.heights[i]-depth+rim,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	for z in range(data.MEADOW_CELLS):
		for x in range(data.MEADOW_CELLS):
			var p := data.meadow_position(x,z)
			if p.distance_to(center) >= radius: continue
			var i: int = z * data.MEADOW_CELLS + x
			data.grass[i] = 0.0
			data.blades[i] = 0.0
			data.meadow[i] = 0.0
	data.erase_tint(center,radius,1.0)
