extends SceneTree
var scene: Node
var phase := -1
var frame := 0
var previous := 0
var gaps: Array[float] = []
var results: Array[Dictionary] = []
var life := true
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	life = "--wind-control" not in OS.get_cmdline_user_args()
	scene = load("res://studies/bigfoot_life.tscn" if life else "res://studies/wind_playground.tscn").instantiate()
	root.add_child(scene)
	scene._play_ui.visible = false
	scene._auto_orbit = false
	await create_timer(2.0).timeout
	_next()
	process_frame.connect(_frame)
func _next() -> void:
	phase += 1
	if phase >= 4:
		var file := FileAccess.open("res://docs/bigfoot-life/performance.json" if life else "res://docs/bigfoot-life/performance-wind-control.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"viewport":str(root.size),"gpu":RenderingServer.get_video_adapter_name(),"phases":results},"\t")+"\n")
		print("LIFE PERF ",JSON.stringify(results))
		quit()
		return
	scene.reset_creature()
	if life: scene.brain.enabled = phase%2==1
	frame = 0
	gaps.clear()
	previous = Time.get_ticks_usec()
func _frame() -> void:
	if phase>=4: return
	frame += 1
	var now := Time.get_ticks_usec()
	if frame>60: gaps.append((now-previous)/1000.0)
	previous = now
	if phase>=2:
		if frame==120:
			scene._chunk_editor.data.begin_stroke()
			scene._chunk_editor.data.place("rock",Vector2(7,5),0.0,0.6)
			scene._chunk_editor.data.end_stroke()
			scene._chunk_editor.refresh()
		if frame in [240,480]: scene._chunk_editor.undo()
		if frame==360: scene._chunk_editor.redo()
	if frame>=540:
		gaps.sort()
		results.append({"roaming":life and phase%2==1,"edits":phase>=2,"samples":gaps.size(),"median_ms":gaps[gaps.size()/2],"p95_ms":gaps[int(gaps.size()*0.95)],"max_ms":gaps.back(),"navigation_rebuild_ms":scene.navigation.last_rebuild_usec/1000.0 if life else 0.0})
		_next()
