extends Node
## Opt-in, bounded in-memory capture. No per-frame disk writes or world content.
signal saved(path: String)
var active := false
var duration_seconds := 60.0
var output_directory := "user://performance"
var scene: Node3D
var samples: Array[Dictionary] = []
var metadata := {}
var _monitors := {}
var _started := 0
var _previous := 0
var last_scene_usec := 0

func start(owner_scene: Node3D) -> void:
	if active: return
	scene = owner_scene
	samples.clear()
	_monitors.clear()
	for key in ClassDB.class_get_integer_constant_list("Performance"):
		if "PIPELINE" in key: _monitors[key] = ClassDB.class_get_integer_constant("Performance",key)
	metadata = {"engine":Engine.get_version_info(),"os":OS.get_name(),"os_version":OS.get_version(),
		"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),
		"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"window_size":str(scene.get_viewport().get_visible_rect().size),"fps_cap":Engine.max_fps,
		"vsync":DisplayServer.window_get_vsync_mode(),"msaa":scene.get_viewport().msaa_3d,
		"render_scale":scene.get_viewport().scaling_3d_scale,
		"timing_note":"Frame intervals and prior scene callback duration. Render measurements can be delayed or unavailable; zero GPU time is not proof of zero GPU work."}
	_started = Time.get_ticks_usec()
	_previous = _started
	last_scene_usec = 0
	active = true
	RenderingServer.viewport_set_measure_render_time(scene.get_viewport().get_viewport_rid(),true)
	get_tree().process_frame.connect(_sample)

func _sample() -> void:
	if not active: return
	var now := Time.get_ticks_usec()
	var data: NativeTerrainData = scene._chunk_editor.data
	var viewport := scene.get_viewport().get_viewport_rid()
	var row := {"elapsed_ms":float(now-_started)/1000.0,"frame_ms":float(now-_previous)/1000.0,
		"scene_ms":float(last_scene_usec)/1000.0,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport),
		"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport),
		"object_count":data.objects.size(),"objects_revision":data.objects_revision,"water_revision":scene._chunk_editor.content.revision,
		"preset":data._recipe_settings.get("family",""),"tool":scene._chunk_editor.mode,
		"bigfoot":scene.resident_enabled,"navigation_rebuilding":scene.navigation.rebuilding,
		"forming":scene._chunk_editor.forming,"paused":scene._paused,
		"camera":[scene.yaw,scene.polar,scene.distance],
		"camera_target":[scene.target.x,scene.target.y,scene.target.z],
		"orbiting":scene._orbiting,"panning":scene._panning}
	for key in _monitors: row[key] = Performance.get_monitor(_monitors[key])
	samples.append(row)
	_previous = now
	if now-_started >= duration_seconds*1000000.0 or samples.size() >= 15000: finish()

func finish() -> String:
	if not active: return ""
	active = false
	get_tree().process_frame.disconnect(_sample)
	RenderingServer.viewport_set_measure_render_time(scene.get_viewport().get_viewport_rid(),false)
	var directory := ProjectSettings.globalize_path(output_directory)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		saved.emit("")
		return ""
	var path := directory.path_join("zenscape-performance-%d-%d.json" % [int(Time.get_unix_time_from_system()),Time.get_ticks_msec()])
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		saved.emit("")
		return ""
	file.store_string(JSON.stringify({"metadata":metadata,"samples":samples},"\t"))
	file.close()
	saved.emit(path)
	return path
