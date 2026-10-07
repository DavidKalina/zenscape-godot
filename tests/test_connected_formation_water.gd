extends SceneTree
const Presets = preload("res://scripts/native_landscape_presets.gd")
const Stream = preload("res://scripts/native_stream_record.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	var data: NativeTerrainData = scene._chunk_editor.data
	for family: String in Presets.PRESETS:
		await scene._chunk_editor.form_landscape(family,"",false)
		# Redwood Grove is a dry woodland (8925214f): no courses or falls.
		var wet: bool = family != "redwood_grove"
		check(not wet or scene._chunk_editor.content._landscape_falls.size()>0,"Steep sections render animated cascade geometry: "+family)
		check(not wet or not data.streams.is_empty(),"Connected courses exist: "+family)
		var submerged := 0
		var total := 0
		for route: Dictionary in data.streams:
			check(Stream.valid(route),"Downhill, saveable route: "+family)
			for station: Dictionary in route.pts:
				var center: float = station.h-route.depth+route.surface*0.065
				var h: float = data.stream_ground_height(station.x,station.z)
				check(h<center-0.05,"Carved channel lies below water: "+family)
				total += 1
				if data.height_at(station.x,station.z)>center: submerged += 1
		print(family," routes=",data.streams.size()," pools=",data.ponds.size()," obscured stations=",submerged,"/",total)
		check(not wet or submerged<float(total)*0.15,"Faceted mesh keeps most of each course visible: "+family)
		for pool: Dictionary in data.ponds:
			var mesh := data.pond_surface(pool)
			check(mesh.size()>30,"Pool renders: "+family)
			for v: Vector3 in mesh:
				check(absf(v.y-pool.level)<0.001,"Each pool retains its own water level")
		var saved := data.to_document()
		check(data.load_document(JSON.parse_string(JSON.stringify(saved,"",true,true))),"Connected water saves: "+family)
		var restored := data.to_document()
		check(restored.streams==saved.streams and restored.heights==saved.heights,"Routes and ground roundtrip exactly: "+family)
		for i in range(saved.ponds.size()):
			for key in ["x","z","level"]:
				check(absf(restored.ponds[i][key]-saved.ponds[i][key])<0.000001,"Pool geometry survives JSON precision: "+family)
			for j in range(2):
				check(absf(restored.ponds[i].basin[j]-saved.ponds[i].basin[j])<0.000001,"Basin extent survives JSON precision: "+family)
	await scene._chunk_editor.form_landscape("terraced_pools","",false)
	var original_cascades: int = scene._chunk_editor.content._landscape_falls.size()
	data.begin_stroke()
	for route: Dictionary in data.streams:
		for station: Dictionary in route.pts:
			data.brush(Vector2(station.x,station.z),1.2,2.0,"raise",0.0)
	data.end_stroke()
	scene._chunk_editor.refresh()
	check(scene._chunk_editor.content._landscape_falls.is_empty(),"Sculpted obstructions invalidate and hide cascade geometry")
	scene._chunk_editor.undo()
	check(scene._chunk_editor.content._landscape_falls.size()==original_cascades,"Undo restores cascade geometry")
	scene.queue_free()
	await process_frame
	print("CONNECTED WATER failures=",failures)
	quit(1 if failures else 0)
