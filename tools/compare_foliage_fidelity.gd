extends SceneTree
## Native playable-grove comparison. --film adds deterministic 24 fps reels;
## --profile measures unrecorded frame intervals independently of PNG readback.
const Assets = preload("res://scripts/redwood_assets.gd")
const BaselineAssets = preload("res://tools/fixtures/redwood_assets_control.gd")
var scene: Node
var viewport: SubViewport
var crowns: Array[MultiMeshInstance3D] = []
var improved: Mesh
var original: Mesh
func _initialize() -> void: run.call_deferred()
func set_effect(enabled: bool) -> void:
	for crown in crowns:
		crown.multimesh.mesh = improved if enabled else original
		if crown.material_override is ShaderMaterial:
			crown.material_override.set_shader_parameter("foliage_transmission",0.42 if enabled else 0.0)
func find_crowns(node: Node) -> void:
	if node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh == improved:
		crowns.append(node)
	for child in node.get_children(): find_crowns(child)
func draw() -> void:
	await process_frame
	RenderingServer.force_draw(false)
func run() -> void:
	seed(4707)
	root.size = Vector2i(1440,900)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440,900)
	viewport.msaa_3d = Viewport.MSAA_8X
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = load("res://studies/diorama.tscn").instantiate()
	viewport.add_child(scene)
	scene._menu.get_parent().hide()
	scene._paused = true
	scene._ui.hide()
	await scene._chunk_editor.form_landscape("redwood_grove","",false,37)
	preload("res://scripts/scene_look_presets.gd").apply(scene,"golden_meadow")
	scene._atmosphere.set_fog(0.45)
	scene._redwood_mist.sync(scene)
	scene._auto_orbit = false
	scene.set_process(false)
	if scene._atmosphere.wind_trails != null: scene._atmosphere.wind_trails.hide()
	improved = Assets.mesh("redwood-canopies")
	original = BaselineAssets.mesh("redwood-canopies")
	find_crowns(scene)
	assert(not crowns.is_empty(),"Must compare the live grove crowns")
	print("FOLIAGE crowns=",crowns.size()," trees=",scene._redwood_mist.redwoods)
	for view in ["overview","canopy"]:
		scene.target = Vector3(0,7,0) if view == "overview" else Vector3(1.2,10,-3)
		scene.distance = 43.0 if view == "overview" else 17.0
		scene.polar = 1.12 if view == "overview" else 1.65
		scene.yaw = -0.45 if view == "overview" else 0.0
		scene._update_camera()
		RenderingServer.global_shader_parameter_set("zs_camera_position",scene.camera.global_position)
		scene._display_fog.update_view()
		for effect in [true,false]:
			set_effect(effect)
			RenderingServer.global_shader_parameter_set("zs_motion_time",0.0)
			for frame in range(20): await draw()
			viewport.get_texture().get_image().save_png("res://docs/foliage-fidelity/"+view+("-effect" if effect else "-control")+".png")
		set_effect(true)
		for crown in crowns: crown.material_override.set_shader_parameter("foliage_transmission",0.0)
		for frame in range(20): await draw()
		viewport.get_texture().get_image().save_png("res://docs/foliage-fidelity/"+view+"-shape-only.png")
	if "--film" in OS.get_cmdline_user_args():
		for effect in [true,false]:
			set_effect(effect)
			var dir := "/private/tmp/zs-foliage-"+("effect" if effect else "control")
			DirAccess.make_dir_recursive_absolute(dir)
			for frame in range(-20,144):
				var t := maxf(frame,0)/24.0
				RenderingServer.global_shader_parameter_set("zs_motion_time",t)
				RenderingServer.global_shader_parameter_set("zs_gust_distance",t*3.0)
				await draw()
				if frame >= 0: viewport.get_texture().get_image().save_png(dir+"/%04d.png" % frame)
			print("FOLIAGE FILM effect=",effect," frames=144 wind=",scene._atmosphere._air_strength)
	if "--profile" in OS.get_cmdline_user_args():
		var results: Array = []
		for effect in [false,true,false,true]:
			set_effect(effect)
			for frame in range(60): await process_frame
			var times: Array[float] = []
			var previous := Time.get_ticks_usec()
			for frame in range(180):
				await process_frame
				var now := Time.get_ticks_usec()
				times.append((now-previous)/1000.0)
				previous = now
			times.sort()
			results.append({"effect":effect,"median_ms":times[90],"p95_ms":times[171]})
		var report := {"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":"1440x900","msaa":"8x","frames_per_sample":180,"samples":results,"note":"Frozen scene; no readback or forced draw during samples. Not a full gameplay benchmark."}
		FileAccess.open("res://docs/foliage-fidelity/performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
		print("FOLIAGE PERF ",JSON.stringify(report))
	scene.free()
	quit()
