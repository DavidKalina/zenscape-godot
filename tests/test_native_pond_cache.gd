extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func same_as_fresh(data: NativeTerrainData, pond: Dictionary, label: String) -> void:
	check(data.pond_surface(pond) == NativeGardenWater.surface(data,pond), label)
func run() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	data.brush(Vector2.ZERO,3.0,1.0,"lower",0.0)
	var pond := {"x":0.0,"z":0.0,"level":-0.2}
	var original := data.pond_surface(pond)
	check(not original.is_empty(),"Native pond fixture floods")
	var misses := data.pond_cache_misses
	for i in range(64): check(data.pond_surface(pond) == original,"Warm result remains exact")
	check(data.pond_cache_misses == misses and data.pond_cache_hits == 64,"64 cross-section queries reuse one flood")
	var owned := data.pond_surface(pond)
	owned[0] = Vector3(100,100,100)
	check(data.pond_surface(pond) == original,"Caller cannot mutate cached surface")
	data.begin_stroke()
	data.brush(Vector2.ZERO,1.0,0.7,"raise",0.0)
	data.end_stroke()
	same_as_fresh(data,pond,"In-place height edits invalidate exact surface")
	check(data.pond_cache_misses > misses,"Height contents trigger miss")
	data.undo()
	check(data.pond_surface(pond) == original,"Undo restores original flood exactly")
	data.redo()
	same_as_fresh(data,pond,"Redo invalidates restored state")
	pond.level = -0.35
	same_as_fresh(data,pond,"Pond level key changes surface")
	pond.x = 0.4
	same_as_fresh(data,pond,"Pond seed key changes surface")
	data.ponds.append(pond.duplicate())
	same_as_fresh(data,pond,"Pond record mutation invalidates state")
	misses = data.pond_cache_misses
	data.streams.append({"pts":[{"x":-5.0,"z":0.0,"h":0.0},{"x":5.0,"z":0.0,"h":0.0}],"width":1.0,"depth":0.1,"surface":0.1,"capHead":false,"capTail":false})
	same_as_fresh(data,pond,"Stream record mutation remains exact")
	check(data.pond_cache_misses == misses+1,"Stream mutation invalidates cache")
	misses = data.pond_cache_misses
	data.landscape_waterfall = true
	same_as_fresh(data,pond,"Landscape waterfall mutation remains exact")
	check(data.pond_cache_misses == misses+1,"Landscape waterfall invalidates cache")
	data.discard_cache()
	check(data._pond_surfaces.is_empty(),"Explicit discard clears pond cache")
	same_as_fresh(data,pond,"Discard reproduces fresh result")
	for i in range(24): data.pond_surface({"x":0.0,"z":0.0,"level":-0.2-float(i)*0.01})
	check(data._pond_surfaces.size() == data.POND_CACHE_LIMIT,"Multiple pond keys remain bounded")
	data.begin_probe()
	var probed := data.pond_surface(pond)
	var record := data.end_probe()
	check(probed == NativeGardenWater.surface(data,pond) and not record.ids.is_empty(),"Cached API preserves terrain probe dependency reads")
	data.reset_flat()
	data.form_foundation(0.6,0.8)
	var recipe_pond := {"x":0.0,"z":0.0,"level":0.7}
	same_as_fresh(data,recipe_pond,"Recipe path matches uncached native flood")
	data.form_foundation(0.4,1.0)
	same_as_fresh(data,recipe_pond,"Changed recipe settings invalidate flood")
	print("Pond cache: ",failures," failures; hits ",data.pond_cache_hits," misses ",data.pond_cache_misses)
	quit(1 if failures else 0)
