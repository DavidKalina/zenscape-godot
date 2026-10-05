extends SceneTree
const Preview = preload("res://scripts/native_pond_preview.gd")
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.reset_flat()
	check(Preview.evaluate(data,Vector2.ZERO,-0.2).message.contains("below"),"Flat ground explains why a hollow is needed")
	check(Preview.evaluate(data,Vector2.ZERO,0.2).message.contains("spill"),"Unbounded water explains spill")
	data.brush(Vector2.ZERO,3.0,1.0,"lower",0.0)
	var plan := Preview.evaluate(data,Vector2.ZERO,-0.2)
	check(not plan.vertices.is_empty(),"A hollow has a valid preview")
	check(data.ponds.is_empty(),"Preview never places water")
	var preview := Preview.new()
	check(preview.hover(data,Vector3.ZERO,-0.2,0.05).is_empty() and not preview.visible,"Moving preview is debounced")
	check(not preview.hover(data,Vector3.ZERO,-0.2,0.08).is_empty() and preview.visible,"Settled pointer shows shoreline")
	check(preview.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == plan.vertices,"Preview uses exact flood geometry")
	var misses := data.pond_cache_misses
	for i in range(60): preview.hover(data,Vector3.ZERO,-0.2,0.016)
	check(data.pond_cache_misses == misses,"Stationary preview does not reflood every frame")
	check(data.add_pond(Vector2.ZERO,-0.2),"Previewed pond can be placed")
	check(data.pond_surface(data.ponds[0]) == plan.vertices,"Placed shoreline equals preview")
	preview.hover(data,null,-0.2,0.2)
	check(not preview.visible,"Leaving terrain hides preview")
	data.reset_flat()
	preview.clear()
	check(preview.hover(data,Vector3.ZERO,-0.2,0.2).contains("below") and not preview.visible,"Terrain refresh invalidates stale preview")
	preview.free()
	print("POND PREVIEW: failures=",failures)
	quit(1 if failures else 0)
