extends SceneTree
var failures := 0
var frames := 0
var max_gap := 0
var previous := 0
var sampling := false
var scene: Node
var attempted_edit := false
var animation_advanced := 0.0
var frame_samples: Array[Dictionary] = []
var previous_stage := "preparation"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func frame() -> void:
	if not sampling: return
	var now := Time.get_ticks_usec()
	var stage: String = scene._chunk_editor.refresh_stage
	if stage.is_empty(): stage = "preparation" if scene._chunk_editor.forming else "complete"
	frame_samples.append({"frame":frames,"gap_ms":(now-previous)/1000.0,"from":previous_stage,"to":stage})
	previous_stage = stage
	max_gap = maxi(max_gap,now-previous)
	previous = now
	frames += 1
	var age: float = scene.creature._age
	var process_began := Time.get_ticks_usec()
	scene._process(1.0/60.0)
	frame_samples[-1]["scene_process_ms"] = (Time.get_ticks_usec()-process_began)/1000.0
	# State transitions reset _age; it is not a lifetime animation clock.
	animation_advanced += maxf(0.0,scene.creature._age-age)
	if not attempted_edit and scene._chunk_editor.forming:
		attempted_edit = true
		var editor = scene._chunk_editor
		var heights: PackedFloat32Array = editor.data.heights.duplicate()
		editor.undo()
		editor.start_flat()
		check(editor.data.heights==heights,"Editing cannot interrupt a partially prepared formation")
func run() -> void:
	scene = load("res://studies/open_meadow.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor = scene._chunk_editor
	editor.set_process(false)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--workers="): editor.data.recipe_workers = int(argument.trim_prefix("--workers="))
		if argument == "--quality=beauty": scene._set_quality(0)
		if argument == "--quality=balanced": scene._set_quality(1)
	print("FORMATION_CONFIGURATION ",JSON.stringify({"quality":"beauty" if scene._environment.ssao_enabled else "balanced","pixels":[root.size.x,root.size.y],"msaa":root.msaa_3d,"render_scale":root.scaling_3d_scale,"gpu":RenderingServer.get_video_adapter_name()}))
	if "--warm-scene" in OS.get_cmdline_user_args():
		for _frame in range(60):
			scene._process(1.0/60.0)
			await process_frame
	process_frame.connect(frame)
	for action in ["form_foundation","form_range"]:
		var before: PackedFloat32Array = editor.data.heights.duplicate()
		frames = 0
		max_gap = 0
		attempted_edit = false
		previous = Time.get_ticks_usec()
		sampling = true
		animation_advanced = 0.0
		frame_samples = []
		previous_stage = "preparation"
		var started := Time.get_ticks_usec()
		var clock: float = scene._motion_time
		await editor.perform_action(action)
		max_gap = maxi(max_gap,Time.get_ticks_usec()-previous)
		var elapsed := Time.get_ticks_usec()-started
		print("FORMATION_STAGES ",editor.data.last_recipe_workers," ",JSON.stringify(editor.last_refresh_usec))
		if editor.data.recipe_workers == 0:
			var expected_workers := 1 if action == "form_foundation" else mini(4,maxi(1,OS.get_processor_count()-2))
			check(editor.data.last_recipe_workers == expected_workers,"Automatic concurrency preserves cold foundation headroom and parallel range sampling")
		print("FORMATION_FIRST_FRAMES ",action," ",JSON.stringify(frame_samples.slice(0,3)))
		frame_samples.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.gap_ms>b.gap_ms)
		print("FORMATION_WORST_FRAMES ",action," ",JSON.stringify(frame_samples.slice(0,6)))
		check(animation_advanced>0.1,"Creature animation clock continues during formation")
		check(scene._motion_time>clock+0.1,"World clock continues during formation")
		sampling = false
		check(frames>5,"Formation must yield frames while computing")
		check(max_gap<50000,"Formation must not block the main thread for 50 ms")
		var formed: PackedFloat32Array = editor.data.heights.duplicate()
		var mesh := var_to_bytes(editor.terrain.mesh.surface_get_arrays(0))
		var ground: PackedByteArray = scene._precipitation.ground_texture.get_image().get_data()
		var streams: PackedByteArray = scene._precipitation.stream_texture.get_image().get_data()
		editor.data._water_grid_h.clear() # Compare against a cold, synchronous pond sampler too.
		editor.force_refresh()
		check(mesh==var_to_bytes(editor.terrain.mesh.surface_get_arrays(0)),"Budgeted mesh equals a full rebuild")
		check(ground==scene._precipitation.ground_texture.get_image().get_data(),"Budgeted surface map equals a full rebuild")
		check(streams==scene._precipitation.stream_texture.get_image().get_data(),"Budgeted stream map equals a full rebuild")
		editor.undo()
		check(editor.data.heights==before,"Formation is one undo step")
		editor.redo()
		check(editor.data.heights==formed,"Redo restores the completed terrain")
		print("FORMATION ",action," failures=",failures," frames=",frames," maximum_gap_ms=",max_gap/1000.0," elapsed_ms=",elapsed/1000.0)
	scene.free()
	quit(1 if failures else 0)
