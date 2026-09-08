extends SceneTree
## In-process alternating control/gust samples; reports presentation frame time
## and render CPU timing separately. GPU timing may be unavailable on Metal.
var scene: Node
var phase := -1
var frame := 0
var last_usec := 0
var frame_times: Array[float] = []
var process_times: Array[float] = []
var render_times: Array[float] = []
var gpu_times: Array[float] = []
var results: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	scene = load("res://studies/wind_playground.tscn").instantiate()
	root.add_child(scene)
	scene._play_ui.visible = false
	scene._auto_orbit = false
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await create_timer(2.0).timeout
	_next()
	process_frame.connect(_frame)
func _next() -> void:
	phase += 1
	if phase == 6:
		var file := FileAccess.open("res://docs/wind-playground/performance.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"viewport":str(root.size),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"phases":results},"\t")+"\n")
		print("WIND PERF ",JSON.stringify(results))
		quit()
		return
	scene.reset_creature()
	frame = 0
	last_usec = Time.get_ticks_usec()
	frame_times.clear()
	process_times.clear()
	render_times.clear()
	gpu_times.clear()
func _frame() -> void:
	if phase >= 6: return
	frame += 1
	var now := Time.get_ticks_usec()
	if phase % 2 == 1 and frame % 90 == 1: scene.demo_gust()
	if frame > 60:
		frame_times.append((now-last_usec)/1000.0)
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		render_times.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	last_usec = now
	if frame >= 420:
		frame_times.sort()
		results.append({"gust":phase%2==1,"frames":frame_times.size(),"median_ms":frame_times[frame_times.size()/2],"p95_ms":frame_times[int(frame_times.size()*0.95)],"process_mean_ms":mean(process_times),"render_cpu_mean_ms":mean(render_times),"render_gpu_mean_ms":mean(gpu_times)})
		_next()
func mean(values: Array[float]) -> float:
	var sum := 0.0
	for value in values: sum += value
	return sum/maxi(1,values.size())
