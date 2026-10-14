extends SceneTree
## The loading screen measured rendered (docs/design/roguelike/loading-screen-round1.md):
## the generator's layer launched as in play, then
##   - when it is playable (the screen gone; with --no-loading-screen, the
##     first frame the stage stands) and when it stands whole, in ms since
##     the engine started (so the boot is in it);
##   - the frame times of the first --secs= (30) seconds of play from
##     playable, and (with --no-loading-screen) of the --secs= seconds after
##     it stands whole: p50, p99, how many ran over 33 / 50 / 100 ms, the worst;
##   - stills: the loading screen at milestones of its bar and the view at
##     playable +1 s, +10 s and the end, and the scene's node count at each.
## The camera turns once round in the window (--turn=0 holds it) so what comes
## into view is seen. Rendered only (needs a window); vsync off, uncapped:
##   Godot --windowed --path . -s res://tools/bench_loading.gd -- --no-title \
##     --shape=sprawl --seed=2 [--no-loading-screen] [--cap=1080] [--secs=30] [--out=/private/tmp/zs-load]
var scene: Node3D
var out := "/private/tmp/zs-load"
var secs := 30.0
var cap := 1080
var window := Vector2i(1920,1080)
var turn := true
var _times: Array = []
var _stamp: Array = []
var _last := 0
var _yaw_from := -1.0
var _tag := ""

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--secs="): secs = float(argument.trim_prefix("--secs="))
		elif argument.begins_with("--cap="): cap = int(argument.trim_prefix("--cap="))
		elif argument == "--turn=0": turn = false
		elif argument.begins_with("--window="): window = Vector2i(int(argument.trim_prefix("--window=").get_slice("x",0)),int(argument.trim_prefix("--window=").get_slice("x",1)))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("bench timed out"); quit(2))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.size = window
	var RenderResolution = preload("res://scripts/render_resolution.gd")
	if cap >= 0: RenderResolution.apply(root,cap)
	var shape := ""
	var seed_value := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shape="): shape = argument.trim_prefix("--shape=")
		if argument.begins_with("--seed="): seed_value = argument.trim_prefix("--seed=")
	var holds := not "--no-loading-screen" in OS.get_cmdline_user_args()
	_tag = "%s-%s-%s%s" % [shape,seed_value,"after" if holds else "before","-nowarm" if "--no-shader-warmup" in OS.get_cmdline_user_args() else ""]
	var began := Time.get_ticks_msec()
	scene = load("res://studies/run_layer.tscn").instantiate()
	scene.set_meta("no_title",true)
	process_frame.connect(_frame)
	RenderingServer.frame_pre_draw.connect(_turn_camera)
	root.add_child(scene)
	current_scene = scene
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("BENCH %s adapter %s driver %s window %s cap %d, scene added %d ms after the engine started" % [_tag,RenderingServer.get_video_adapter_name(),
		RenderingServer.get_current_rendering_driver_name(),root.size,cap,began])
	# --- Waiting: the screen up (stills at milestones of its bar), then gone.
	var milestones := [0.05,0.3,0.6,0.85,0.97]
	var next_m := 0
	var playable := -1
	var whole := -1
	var screen_seen := false
	while playable < 0:
		await process_frame
		var loading: Variant = scene.get("loading")
		if loading != null:
			if loading.active:
				screen_seen = true
				var share: float = loading.screen._shown if loading.screen != null else 0.0
				if next_m < milestones.size() and share >= milestones[next_m]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(out.path_join("%s-loading-%02d.png" % [_tag,int(milestones[next_m]*100)]))
					next_m += 1
			elif screen_seen:
				playable = Time.get_ticks_msec()
		elif scene.get("stage") != null and int(scene.get("layers")) >= 1:
			playable = Time.get_ticks_msec()
		if Time.get_ticks_msec()-began > 600000: break
	print("BENCH %s playable at %d ms since the engine started (%d ms since the scene was added)" % [_tag,playable,playable-began])
	var play_from := _times.size()
	var yaw_start := Time.get_ticks_msec()
	_yaw_from = (scene.camera as Camera3D).global_rotation.y if scene.camera != null else 0.0
	_holdout = [Time.get_ticks_msec(),secs]
	print("BENCH %s nodes at playable: %d" % [_tag,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	var shots := [1.0,10.0,secs-0.5]
	var shot := 0
	var whole_seen := -1
	var end_whole := -1.0
	while true:
		await process_frame
		var t := (Time.get_ticks_msec()-playable)/1000.0
		if whole_seen < 0 and int(scene.layer_up_ms) >= 0:
			whole_seen = Time.get_ticks_msec()
			print("BENCH %s stands whole at %d ms since the engine started (%d ms after playable)" % [_tag,whole_seen,whole_seen-playable])
			whole = _times.size()
		if shot < shots.size() and t >= shots[shot]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("%s-play-%02ds.png" % [_tag,int(shots[shot])]))
			print("BENCH %s nodes at +%.0f s: %d" % [_tag,shots[shot],int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
			shot += 1
			# (saving the still is not a frame of the game's)
			_last = 0
		if t >= secs and (holds or whole_seen >= 0 and (Time.get_ticks_msec()-whole_seen)/1000.0 >= secs): break
		if t > 400.0: break
	_yaw_from = -1.0
	_report("first %.0f s of play" % secs,play_from,play_from+_count_until(playable,secs))
	if not holds and whole >= 0: _report("%.0f s after it stood whole" % secs,whole,_times.size())
	print("BENCH %s done" % _tag)
	quit(0)

var _holdout := []

func _count_until(from_ms: int, seconds: float) -> int:
	var n := 0
	var sum := 0.0
	for i in range(_times.size()-1,-1,-1):
		pass
	# frames whose stamp is within [from_ms, from_ms+seconds)
	for i in range(_stamp.size()):
		if _stamp[i] >= from_ms and _stamp[i] < from_ms+seconds*1000.0: n += 1
	return n

func _frame() -> void:
	var now := Time.get_ticks_usec()
	if _last > 0:
		_times.append((now-_last)/1000.0)
		_stamp.append(Time.get_ticks_msec())
	_last = now

func _turn_camera() -> void:
	if _yaw_from < 0.0 or not turn or scene == null or scene.camera == null: return
	var t := (Time.get_ticks_msec()-int(_holdout[0]))/1000.0/float(_holdout[1])
	var cam: Camera3D = scene.camera
	var basis := Basis(Vector3.UP,TAU*clampf(t,0.0,1.0))
	cam.global_transform = Transform3D(basis*cam.global_transform.basis,cam.global_transform.origin)

func _report(label: String, from: int, to: int) -> void:
	var window_times := _times.slice(from,to)
	if window_times.is_empty():
		print("BENCH %s: %s: no frames" % [_tag,label])
		return
	var sorted := window_times.duplicate()
	sorted.sort()
	var total := 0.0
	for t: float in window_times: total += t
	var over := func(ms: float) -> int: return window_times.filter(func(t: float) -> bool: return t > ms).size()
	print("BENCH %s: %s: %d frames over %.1f s, p50 %.1f ms, p99 %.1f ms, over 33: %d, over 50: %d, over 100: %d, worst %.0f ms" % [
		_tag,label,window_times.size(),total/1000.0,sorted[sorted.size()/2],sorted[mini(int(sorted.size()*0.99),sorted.size()-1)],over.call(33.0),over.call(50.0),over.call(100.0),sorted[sorted.size()-1]])
	var worst := window_times.duplicate()
	worst.sort()
	worst.reverse()
	print("BENCH %s: %s: worst five %s" % [_tag,label,str(worst.slice(0,5))])
