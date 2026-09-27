extends RefCounted
## Private inputs for triangle-height, instance and blast calculations.
## Deliberately excludes render/physics resources and mutable recipe objects.
static func for_queries(source: NativeTerrainData, with_neighbors := false) -> NativeTerrainData:
	var data := for_height(source)
	if with_neighbors: data._neighbors.assign(source._neighbors.duplicate(true))
	data.grass = source.grass.duplicate()
	data.meadow = source.meadow.duplicate()
	data.blades = source.blades.duplicate()
	data.tint = source.tint.duplicate()
	data.objects.assign(source.objects.duplicate(true))
	data.cover_births = source.cover_births.duplicate(true)
	return data

## Height-only consumers do not copy potentially thousands of object records.
static func for_height(source: NativeTerrainData) -> NativeTerrainData:
	var data := NativeTerrainData.new()
	data.points = source.points.duplicate()
	data.vertex_ids = source.vertex_ids.duplicate()
	data._buckets = source._buckets.duplicate(true)
	data.heights = source.heights.duplicate()
	data.void_faces = source.void_faces.duplicate()
	return data
