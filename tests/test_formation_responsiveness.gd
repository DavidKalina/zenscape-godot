extends SceneTree
var failures := 0
var frames := 0
var max_gap := 0
var previous := 0
var sampling := false
var scene: Node
var attempted_edit := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func frame() -> void:
	if not sampling: return
	var now := Time.get_ticks_usec()
	max_gap = maxi(max_gap,now-previous)
	previous = now
	frames += 1
	scene._process(1.0/60.0)
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
	process_frame.connect(frame)
	for action in ["form_foundation","form_range"]:
		var before: PackedFloat32Array = editor.data.heights.duplicate()
		frames = 0
		max_gap = 0
		attempted_edit = false
		previous = Time.get_ticks_usec()
		sampling = true
		var age: float = scene.creature._age
		var clock: float = scene._motion_time
		await editor.perform_action(action)
		max_gap = maxi(max_gap,Time.get_ticks_usec()-previous)
		check(scene.creature._age>age+0.1,"Creature animation clock continues during formation")
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
		print("FORMATION ",action," failures=",failures," frames=",frames," maximum_gap_ms=",max_gap/1000.0)
	scene.free()
	quit(1 if failures else 0)
