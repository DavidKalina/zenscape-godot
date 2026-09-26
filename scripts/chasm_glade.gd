extends RefCounted
## An approachable first chasm, using the same recipe topology as wild worlds.
const RECIPE := {"kind":"inland","version":5,"seed":7,"composition":"chasm","archetype":"ridgeback","landform":"original","biome":"meadow","relief":1.0,"breadth":1.0}
static func populate(data: NativeTerrainData) -> int:
	var log_id: int = preload("res://scripts/crossing_glade.gd").populate(data)
	data.begin_stroke()
	data._set_recipe(RECIPE)
	data.heights.fill(0.0)
	data.streams.clear()
	# The old stream recipe anchored the log on its submerged bed. A void
	# has no bed, so keep the same bank-level geometry explicitly.
	data.update_object(log_id,{"pose":NativeObjectPose.make(Basis.from_scale(Vector3.ONE*4.0),-0.35)})
	data.objects = data.objects.filter(func(item: Dictionary) -> bool: return item.asset == "log" or data.ground_height(Vector2(item.x,item.z)) != null)
	data.objects_revision += 1
	data.end_stroke()
	return log_id
