extends SceneTree
## Lists every water surface a kit isle draws (docs/scenic/kit-isle-water.md):
## each mesh drawn with a water shader (the plate's lake water, the islets'
## pond water, the aqueduct's channel), its path, shader, triangles and
## bounds. Headless:
##   godot --headless --path . -s res://tools/kit_isle_water_probe.gd -- --isle=cloister_tarn [--old-water]
## Isles: aqueduct, bell_spires, cloister_tarn, sundered_gorge, colonnade_spine.
const WATER_SHADERS := ["reference_water","islet_pond","aqueduct_channel"]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("water probe timed out"); quit(2))
	var isle := "cloister_tarn"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--isle="): isle = arg.get_slice("=",1)
	var path := "res://studies/%s_isle.tscn" % isle
	var study: Node3D = load(path).instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	var found := 0
	for node in _all(study):
		if not node is MeshInstance3D: continue
		var mi := node as MeshInstance3D
		var material := mi.material_override
		if material == null and mi.mesh != null and mi.mesh.get_surface_count() > 0: material = mi.mesh.surface_get_material(0)
		if not material is ShaderMaterial or (material as ShaderMaterial).shader == null: continue
		var shader_path := (material as ShaderMaterial).shader.resource_path
		var water := false
		for s in WATER_SHADERS: if shader_path.contains(s): water = true
		if not water: continue
		found += 1
		var tris := 0
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var arrays := mi.mesh.surface_get_arrays(s)
				var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				tris += (index.size() if not index.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())/3
		var box := mi.global_transform*mi.get_aabb()
		print("WATER %s  shader=%s  tris=%d  aabb=%s..%s" % [study.get_path_to(mi),shader_path.get_file(),tris,box.position,box.end])
	print("water probe %s: %d water meshes" % [isle,found])
	quit(0)

func _all(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children(): out.append_array(_all(child))
	return out
