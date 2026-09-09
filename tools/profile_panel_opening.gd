extends SceneTree
var scene: Node
var previous := 0
var gaps: Array[float] = []
var rows: Array[Dictionary] = []
var output := "/tmp/zs-panels.json"

func _initialize() -> void: run.call_deferred()
func frame() -> void:
	var now := Time.get_ticks_usec()
	gaps.append(float(now-previous)/1000.0)
	previous = now

func measure(label: String, open: Callable, close: Callable) -> void:
	gaps.clear()
	var canvas := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
	var draw := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
	var began := Time.get_ticks_usec()
	open.call()
	var cpu := float(Time.get_ticks_usec()-began)/1000.0
	for i in range(12): await process_frame
	var row := {"panel":label,"open_cpu_ms":cpu,"max_frame_ms":gaps.max(),
		"canvas_compilations":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)-canvas,
		"draw_compilations":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)-draw}
	rows.append(row)
	print("PANEL ",JSON.stringify(row))
	close.call()
	await create_timer(0.3).timeout

func run() -> void:
	root.size = Vector2i(1440,900)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene.close_menu()
	await create_timer(1.0).timeout
	previous = Time.get_ticks_usec()
	process_frame.connect(frame)
	await measure("build_first",func(): scene._chunk_editor.set_active(true),func(): scene._chunk_editor.set_active(false))
	await measure("build_repeat",func(): scene._chunk_editor.set_active(true),func(): pass)
	for suffix in ["first","repeat"]:
		await measure("palette_"+suffix,scene._build_palette.open_palette,scene._build_palette.close_palette)
		await measure("landscape_"+suffix,scene.edit_landscape_presets,func(): scene._landscape_editor.hide())
		await measure("appearance_"+suffix,scene.edit_scene_look,func(): scene._look_editor.hide())
	process_frame.disconnect(frame)
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"rows":rows},"\t"))
	quit()
