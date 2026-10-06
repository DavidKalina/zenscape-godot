extends SceneTree
## What a sky chunk shows from afar against what the plate shows once it is
## claimed (scripts/sky_islands.gd `claim`): every drawn part of the chunk's
## far version, then every drawn part of the plate (within the plate's reach,
## on a render layer) a few times after the claim, by node path, class,
## instances and material.
##   Godot --headless --path . -s res://tools/probe_chunk_popin.gd

var lines: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(600).timeout.connect(func() -> void: push_error("chunk pop-in probe timed out"); quit(2))
	root.unfocusable = true
	var scene: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-popin-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	var eye: Node = scene.wanderer
	var islands: Node3D = eye.islands
	var waited := 0
	while not islands.sky_ready() and waited < 6000:
		islands.make_ahead(1.0/60.0)
		waited += 1
		await process_frame
	scene.world_clock.running = false
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	for i in range(5): await process_frame
	eye._launch(6.0,false)
	eye.set_process(false)
	for i in range(10): await process_frame
	var index := 0
	while islands.lands[index] == null: await process_frame
	var copy: Node3D = islands._copies[index]
	var land: NativeTerrainData = islands.lands[index]
	lines.append("FAR chunk %s at %s: %d objects %s; blades>0 %d/%d, meadow>0 %d" % [copy.name,islands.offsets[index],land.objects.size(),land.objects,land.blades.size()-land.blades.count(0.0),land.blades.size(),land.meadow.size()-land.meadow.count(0.0)])
	_list(copy,copy,Vector3.INF)
	var target: Vector3 = islands.homes[index]
	eye.glide.position = islands.offsets[index]+Vector3.UP*30.0
	var claim_frame := Engine.get_process_frames()
	eye._claim(index)
	while islands.claiming: await process_frame
	lines.append("claim took %d frames" % (Engine.get_process_frames()-claim_frame))
	var d: NativeTerrainData = scene._chunk_editor.data
	lines.append("PLATE objects after claim: %s; blades>0 %d/%d meadow>0 %d grass>0 %d" % [d.objects,d.blades.size()-d.blades.count(0.0),d.blades.size(),d.meadow.size()-d.meadow.count(0.0),d.grass.size()-d.grass.count(0.0)])
	for wait in [0,30,240]:
		for i in range(wait): await process_frame
		lines.append("--- PLATE drawn parts, %d frames after the claim ---" % wait)
		_list(scene,scene,Vector3.ZERO,islands)
	print("\n".join(lines))
	quit(0)

## Every drawn part under `node`; with `near` set, only those whose box
## middle stands within the plate's reach of it, skipping `skip`.
func _list(top: Node, node: Node, near: Vector3, skip: Node = null) -> void:
	for child in node.get_children():
		if child == skip or child is Camera3D or child is CanvasLayer or child is SubViewport: continue
		_list(top,child,near,skip)
		var g := child as GeometryInstance3D
		if g == null or not g.is_visible_in_tree() or g.layers == 0: continue
		var box := g.global_transform*g.get_aabb()
		if near != Vector3.INF:
			var m := box.get_center()
			if absf(m.x) > 32.0 or absf(m.z) > 32.0 or box.size.x > 80.0 or box.size.z > 80.0: continue
		var what := ""
		if g is MultiMeshInstance3D:
			var mm := (g as MultiMeshInstance3D).multimesh
			what = "instances %d/%d" % [mm.visible_instance_count if mm != null else -1,mm.instance_count if mm != null else -1] if mm != null else "no multimesh"
		elif g is MeshInstance3D:
			var mesh := (g as MeshInstance3D).mesh
			what = "mesh %s surf0mat %s ovr %s" % [mesh.get_class() if mesh != null else "null",_mat(mesh.surface_get_material(0)) if mesh != null and mesh.get_surface_count() > 0 else "-",_mat((g as MeshInstance3D).get_surface_override_material(0)) if (g as MeshInstance3D).get_surface_override_material_count() > 0 else "-"]
		elif g is GPUParticles3D:
			what = "particles %d" % (g as GPUParticles3D).amount
		var shader := _mat(g.material_override)
		lines.append("  %s [%s] %s mat=%s range_end=%.0f transp=%.2f shadow=%d" % [top.get_path_to(child),child.get_class(),what,shader,g.visibility_range_end,g.transparency,g.cast_shadow])

func _mat(m: Material) -> String:
	if m == null: return "null"
	var s := m.get_class()
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null: s = (m as ShaderMaterial).shader.resource_path.get_file()
	return "%s#%d" % [s,m.get_instance_id() % 100000]
