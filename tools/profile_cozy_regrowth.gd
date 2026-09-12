## Reproducible CPU/GPU frame trace of forest and desert regrowth.
## Run headless with -- --max-frame-ms=50 to check main-thread stalls, or
## in Forward+ to measure window frame intervals (includes GPU/display wait).
extends SceneTree
var scene: Node3D
var rows: Array[Dictionary] = []
var previous := 0
var previous_phase := "idle"
var previous_stage := ""
var collecting := false
var label := "capture"
var frame_limit_ms := 0.0
var failures := 0
func _initialize() -> void: run.call_deferred()
func sample_frame() -> void:
	if not collecting: return
	var now := Time.get_ticks_usec()
	var rid := root.get_viewport_rid()
	rows.append({"ms":(now-previous)/1000.0,"phase":previous_phase,"stage":previous_stage,"scene_ms":scene._performance_trace.last_scene_usec/1000.0,"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid)})
	previous = now
	previous_phase = scene.places.phase
	previous_stage = scene._chunk_editor.refresh_stage if scene._chunk_editor.forming else ""
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with('--label='): label=arg.trim_prefix('--label=').validate_filename()
		if arg.begins_with('--max-frame-ms='): frame_limit_ms=float(arg.trim_prefix('--max-frame-ms='))
	create_timer(240).timeout.connect(func() -> void: quit(2))
	root.size=Vector2i(1440,900)
	scene=load('res://studies/cozy_worlds.tscn').instantiate()
	scene.set_meta('movie_capture',true)
	scene.places_path='/private/tmp/cozy-profile-'+label+'/places.json'
	root.add_child(scene)
	current_scene=scene
	while not scene.places_ready: await process_frame
	await create_timer(2).timeout
	scene._performance_trace.output_directory='/private/tmp/cozy-profile-'+label
	scene._performance_trace.duration_seconds=220
	scene._performance_trace.start(scene)
	process_frame.connect(sample_frame)
	for world_seed in [110,4]:
		rows=[]
		previous=Time.get_ticks_usec()
		previous_phase='idle'
		previous_stage=''
		collecting=true
		await create_timer(1).timeout
		scene.places.regrow(world_seed)
		while scene.places.busy: await process_frame
		await create_timer(1).timeout
		collecting=false
		var report={"seed":world_seed,"rows":rows,"refresh":scene._chunk_editor.last_refresh_usec,"mesh":scene._chunk_editor.data.last_mesh_profile,"instances":scene._chunk_editor.content.last_instance_usec,"pixels":str(root.size),"navigation_submit_usec":scene.navigation.last_submit_usec,"navigation_workers":scene.navigation.last_worker_count,"gpu_timing_note":"Zero may mean unavailable, not zero GPU work"}
		var file=FileAccess.open('/private/tmp/cozy-'+label+'-'+str(world_seed)+'.json',FileAccess.WRITE)
		file.store_string(JSON.stringify(report));file.close()
		var ranked=rows.duplicate()
		ranked.sort_custom(func(a,b):return a.ms>b.ms)
		if frame_limit_ms>0 and ranked[0].ms>frame_limit_ms: failures+=1
		print('COZY PROFILE ',label,' seed=',world_seed,' worst=',JSON.stringify(ranked.slice(0,8)),' refresh=',JSON.stringify(report.refresh))
	scene._performance_trace.finish()
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
