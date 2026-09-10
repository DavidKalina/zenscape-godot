extends SceneTree
## CPU pond vertices must preserve the original nearest-emitter calculation.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func original_points(scene: Node) -> Dictionary:
	var water: MeshInstance3D = scene._chunk_editor.content._water
	var listener: Vector3 = scene.camera.global_position
	var points := {}
	var best := INF
	# Independent oracle reads the published mesh, as the original layout did.
	for vertex in water.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point := water.to_global(vertex)
		var distance := listener.distance_squared_to(point)
		if distance < best:
			best = distance
			points.shore = point
	return points
func run() -> void:
	var scene = load("res://studies/open_meadow.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._chunk_editor.set_process(false)
	var layout = load("res://studies/water_audio_layout.gd").new()
	var began := Time.get_ticks_usec()
	var actual: Dictionary = layout.update(0.0,scene).duplicate()
	var elapsed := Time.get_ticks_usec()-began
	print("WATER_AUDIO_COLD_USEC ",elapsed)
	check(actual == original_points(scene),"Cold emitter positions match original mesh sampling")
	var mesh: ArrayMesh = scene._chunk_editor.content._water.mesh
	var original_vertices := {}
	for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: original_vertices[vertex] = true
	check(layout._mesh_cache[mesh.get_instance_id()] == PackedVector3Array(original_vertices.keys()),"All cached CPU vertices preserve original coordinates and tie-breaking order")
	for position in [Vector3(-8,5,-7),Vector3(3,1,9),Vector3(0,20,0)]:
		scene.camera.global_position = position
		layout.refresh_in = 0.0
		check(layout.update(0.0,scene) == original_points(scene),"Camera movement preserves exact nearest-emitter positions")
	scene._chunk_editor.content._water.position += Vector3(2,1,-3)
	layout.refresh_in = 0.0
	check(layout.update(0.0,scene) == original_points(scene),"Moved water preserves exact emitter positions with cached vertices")
	scene._chunk_editor.content.rebuild(true)
	layout.refresh_in = 0.0
	check(layout.update(0.0,scene) == original_points(scene),"Rebuilt water preserves exact emitter positions")
	check(not layout._mesh_cache.has(mesh.get_instance_id()),"A content revision releases obsolete cached pond vertices")
	scene.free()
	print("Water audio positions: ",failures," failures")
	quit(1 if failures else 0)
