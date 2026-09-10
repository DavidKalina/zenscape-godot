extends SceneTree
## Reproduce a held terrain brush, not a prop placement. GPU process intervals
## include rendering, the editor and live collision/navigation work. They do not
## measure display presentation. Stage metadata is optional, in milliseconds.
## --wind-control --out=res://... --dabs=30 --size=1440x900
var scene: Node
var editor: Node
var life := true
var output := "res://docs/bigfoot-life/sculpt-latest.json"
var dab_count := 30
var previous := 0
var next_dab := 0
var started := 0
var finish_after := 0
var records: Array[Dictionary] = []
var gaps: Array[float] = []
var idle_gaps: Array[float] = []
var idle_started := 0
var running := false
var ending := false
var initial_heights := PackedFloat32Array()

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var size := Vector2i(1440,900)
	for arg in OS.get_cmdline_user_args():
		if arg == "--wind-control": life = false
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--dabs="): dab_count = maxi(2,int(arg.trim_prefix("--dabs=")))
		if arg.begins_with("--size="):
			var pieces := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(pieces[0]),int(pieces[1]))
	scene = load("res://studies/bigfoot_life.tscn" if life else "res://studies/wind_playground.tscn").instantiate()
	root.add_child(scene)
	scene._auto_orbit = false
	scene._paused = false
	scene.toggle_build()
	editor = scene._chunk_editor
	editor.radius = 2.2
	editor.strength = 2.0
	# Prevent physical mouse state from generating extra brush work. The explicit
	# dabs below reproduce the same brush/refresh path as the 30 Hz editor loop.
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	await create_timer(3.0).timeout
	# Study startup can finish by maximizing the window. Apply the fixture size
	# only after that initialization, then allow the native window to settle.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for _frame in range(3): await process_frame
	root.size = size
	for _frame in range(90): await process_frame
	if root.size != size:
		push_error("Sculpt viewport mismatch: "+str(root.size))
		scene.free()
		quit(1)
		return
	previous = Time.get_ticks_usec()
	idle_started = previous
	process_frame.connect(_frame)

func _frame() -> void:
	var now := Time.get_ticks_usec()
	var gap := float(now-previous)/1000.0
	previous = now
	if not running:
		idle_gaps.append(gap)
		if now-idle_started < 1000000: return
		running = true
		started = now
		next_dab = now
		initial_heights = editor.data.heights.duplicate()
		editor.data.begin_stroke()
	gaps.append(gap)
	if ending:
		if now >= finish_after: _finish()
		return
	if now < next_dab: return
	var index := records.size()
	var split := dab_count/2
	if index == split:
		editor.data.end_stroke()
		editor.data.begin_stroke()
	editor.mode = "raise" if index < split else "lower"
	var along := float(index%split)/maxf(1,split-1)
	var point := Vector2(0.5+cos(along*PI)*0.65,2.7+sin(along*PI)*0.45)
	var before_dab := Time.get_ticks_usec()
	editor.dab(point,editor.strength/30.0)
	var before_refresh := Time.get_ticks_usec()
	editor.refresh()
	var finished := Time.get_ticks_usec()
	var record := {"index":index,"mode":editor.mode,"point":[point.x,point.y],"dab_ms":float(before_refresh-before_dab)/1000.0,"refresh_ms":float(finished-before_refresh)/1000.0,"elapsed_ms":float(finished-started)/1000.0,"stages_usec":editor.last_refresh_usec.duplicate(true)}
	if life:
		record["last_navigation_ms"] = scene.navigation.last_rebuild_usec/1000.0
		record["last_collision_ms"] = scene.last_collision_rebuild_usec/1000.0
		record["collision_stages_usec"] = scene.play_collisions.last_rebuild_usec.duplicate()
	records.append(record)
	next_dab = now+33333
	if records.size() >= dab_count:
		editor.data.end_stroke()
		ending = true
		finish_after = finished+600000

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	var slow := 0
	var over_budget := 0
	for value in values:
		total += value
		if value > 33.333: slow += 1
		if value > 16.667: over_budget += 1
	return {"samples":sorted.size(),"mean_ms":total/sorted.size(),"median_ms":sorted[sorted.size()/2],"p95_ms":sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],"p99_ms":sorted[mini(sorted.size()-1,int(sorted.size()*0.99))],"max_ms":sorted.back(),"over_33_ms":slow,"over_16_67_ms":over_budget}

func _finish() -> void:
	process_frame.disconnect(_frame)
	var refreshes: Array[float] = []
	var dabs: Array[float] = []
	for record in records:
		refreshes.append(record.refresh_ms)
		dabs.append(record.dab_ms)
	var refresh_stats := stats(refreshes)
	var report := {"scene":"bigfoot_life" if life else "wind_control","physical_size":[root.size.x,root.size.y],"gpu":RenderingServer.get_video_adapter_name(),"fps_cap":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"requested_dab_hz":30,"brush_radius":editor.radius,"brush_strength":editor.strength,"dab_count":records.size(),"idle_frames":stats(idle_gaps),"sculpt_frames":stats(gaps),"refresh":refresh_stats,"dab":stats(dabs),"refresh_exceeds_33ms":refresh_stats.max_ms>33.333,"total_elapsed_ms":float(Time.get_ticks_usec()-started)/1000.0,"records":records}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("Cannot save sculpt profile: "+output)
		quit(1)
		return
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("SCULPT ",JSON.stringify({"output":output,"refresh":refresh_stats,"frames":stats(gaps),"idle":stats(idle_gaps)}))
	# Release the scene and join its finite navigation work before shutting down
	# the renderer; quitting directly can strand deferred rendering resources.
	scene.free()
	scene = null
	editor = null
	for _frame in range(3): await process_frame
	quit()
