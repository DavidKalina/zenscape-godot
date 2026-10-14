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
## Stills saved (--no-stills: none; a PNG save blocks the main thread about
## a second, and the loading ones fall inside the time measured).
var stills := true
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
		elif argument == "--no-stills": stills = false
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
	if "--frames" in OS.get_cmdline_user_args():
		_rows = []
		_probe = preload("res://tools/frame_probe.gd").new(true)
		var last := preload("res://tools/frame_probe.gd").new(false)
		last.other = _probe
		root.add_child(_probe)
		root.add_child(last)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
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
				_load_frames += 1
				_load_process += Performance.get_monitor(Performance.TIME_PROCESS)
				_load_physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
				if _rows != null: _rows.append([Time.get_ticks_msec(),_times[-1] if not _times.is_empty() else 0.0,SkyCommits._used/1000.0,
					Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
					RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
					RenderingServer.get_frame_setup_time_cpu(),str(loading.phase),
					_probe.rows[-1][0] if not _probe.rows.is_empty() else 0,(_probe.rows[-1][1] if not _probe.rows.is_empty() else 0)/1000.0,(_probe.rows[-1][2] if not _probe.rows.is_empty() else 0)/1000.0,_stages()])
				var share: float = loading.screen._shown if loading.screen != null else 0.0
				if stills and next_m < milestones.size() and share >= milestones[next_m]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(out.path_join("%s-loading-%02d.png" % [_tag,int(milestones[next_m]*100)]))
					next_m += 1
			elif screen_seen:
				playable = Time.get_ticks_msec()
		elif scene.get("stage") != null and int(scene.get("layers")) >= 1:
			playable = Time.get_ticks_msec()
		if Time.get_ticks_msec()-began > 600000: break
	print("BENCH %s playable at %d ms since the engine started (%d ms since the scene was added)" % [_tag,playable,playable-began])
	if _rows != null:
		var f := FileAccess.open(out.path_join("%s-frames.csv" % _tag),FileAccess.WRITE)
		f.store_line("ms,dt,sky_used_prev,process,physics,render_cpu,render_gpu,setup_cpu,phase,steps,phys_ms,proc_ms,stages")
		for r: Array in _rows: f.store_line(",".join(r.map(func(v: Variant) -> String: return str(v))))
	print("BENCH %s loading frames %d: process %.1f s, physics %.1f s (engine monitors, summed)" % [_tag,_load_frames,_load_process,_load_physics])
	var play_from := _times.size()
	var yaw_start := Time.get_ticks_msec()
	_yaw_from = (scene.camera as Camera3D).global_rotation.y if scene.camera != null else 0.0
	_holdout = [Time.get_ticks_msec(),secs]
	var sky_now: Variant = scene.get("sky")
	if sky_now != null and sky_now.get("motifs") != null:
		var k := 0
		for isle: Node3D in sky_now.motifs.isles:
			var counts: Variant = isle.flora.get_meta("counts") if isle.get("flora") != null else {}
			print("BENCH %s flora %d %s %s" % [_tag,k,str(isle.motif.id()),str(counts)])
			if "--flora-records" in OS.get_cmdline_user_args() and isle.get("flora") != null:
				var rf := FileAccess.open(out.path_join("flora-%d.txt" % k),FileAccess.WRITE)
				for item: Dictionary in isle.flora.get_meta("records"): rf.store_line("%s %.4f %.4f" % [item.asset,float(item.x),float(item.z)])
			k += 1
	print("BENCH %s nodes at playable: %d" % [_tag,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	if "--raygrid" in OS.get_cmdline_user_args(): _raygrid()
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
		if stills and shot < shots.size() and t >= shots[shot]:
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
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--change-after="): await _change(float(argument.get_slice("=",1)))
	if not holds and whole >= 0: _report("%.0f s after it stood whole" % secs,whole,_times.size())
	print("BENCH %s done" % _tag)
	quit(0)

var _holdout := []
var _who := {}
var _who_done := false
var _load_frames := 0
## Per loading frame (--frames): written to <out>/<tag>-frames.csv.
var _rows = null
var _probe: Node
const SkyCommits = preload("res://scripts/sky_commits.gd")
var _load_process := 0.0
var _load_physics := 0.0

## Each motif isle's stage, first letters (--frames).
func _stages() -> String:
	var sky: Variant = scene.get("sky")
	var motifs: Variant = sky.get("motifs") if sky != null else null
	if motifs == null: return ""
	var out := PackedStringArray()
	for isle: Node3D in motifs.isles: out.append(str(isle.stage).left(3))
	return " ".join(out)

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
	var long := PackedStringArray()
	for i in range(from,to):
		if float(_times[i]) > 100.0 and i < _stamp.size(): long.append("%.1fs:%.0f" % [(int(_stamp[i])-int(_holdout[0]))/1000.0,float(_times[i])])
	if not long.is_empty(): print("BENCH %s: %s: frames over 100 ms at %s" % [_tag,label,", ".join(long)])
	var worst := window_times.duplicate()
	worst.sort()
	worst.reverse()
	print("BENCH %s: %s: worst five %s" % [_tag,label,str(worst.slice(0,5))])

## Downward rays in a 40 x 40 grid over each placed isle's circle: hits (to
## the millimetre) and what they hit, hashed per isle (moving bodies by class
## only), to compare collision between builds.
func _raygrid() -> void:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	var all := 0
	for isle: Node3D in scene.sky.motifs.isles:
		var c: Vector3 = isle.circle()
		var top: float = isle.isle_top()
		var lines := PackedStringArray()
		var hits := 0
		for i in range(40):
			for j in range(40):
				var x := c.x-c.z+2.0*c.z*(i+0.5)/40.0
				var z := c.y-c.z+2.0*c.z*(j+0.5)/40.0
				q.from = Vector3(x,top+120.0,z)
				q.to = Vector3(x,top-200.0,z)
				var hit := q.from
				var r := space.intersect_ray(q)
				# Static collision only: past anything that moves.
				var skipped: Array[RID] = []
				while not r.is_empty() and (r.collider as Node).get_class() != "StaticBody3D" and skipped.size() < 16:
					skipped.append(r.rid)
					q.exclude = skipped
					r = space.intersect_ray(q)
				q.exclude = []
				if r.is_empty():
					lines.append("-")
					continue
				hits += 1
				var n := r.collider as Node
				if str(isle.motif.id()) == "stair_clouds" and not _who_done:
					var key := str(n.get_path()).replace("/root/RunLayer/","")
					_who[key] = int(_who.get(key,0))+1
				var what := n.get_class() if n.get_class() != "StaticBody3D" else "static"
				lines.append("%d,%s" % [roundi((r.position as Vector3).y*1000.0),what])
		all += hits
		if str(isle.motif.id()) == "stair_clouds" and not _who_done:
			_who_done = true
			var keys := _who.keys()
			keys.sort()
			for k: Variant in keys: print("RAYWHO %s x%d" % [str(k),int(_who[k])])
		print("BENCH raygrid %s %s: %d of 1600 hit, hash %s" % [_tag,str(isle.motif.id()),hits,"".join(lines).md5_text().left(12)])
		var rf := FileAccess.open(out.path_join("raygrid-%s-%d.txt" % [_tag,all]),FileAccess.WRITE)
		if rf != null: rf.store_string("\n".join(lines))
	print("BENCH raygrid %s: %d hits in all" % [_tag,all])

## The next layer asked for (as the gate does) `wait` s into play; how long
## play is held (the request to the screen gone).
func _change(wait: float) -> void:
	var until := Time.get_ticks_msec()+int(maxf(wait-secs,0.0)*1000.0)
	while Time.get_ticks_msec() < until: await process_frame
	var shapes = load("res://scripts/roguelike/layer_shapes.gd")
	var asked := Time.get_ticks_msec()
	var from_seed := int(scene.layer_seed)
	scene.request_layer(from_seed+1,"Through the gate",shapes.after(scene.layer))
	var seen := false
	while true:
		await process_frame
		var loading: Variant = scene.get("loading")
		if loading != null and loading.active: seen = true
		elif seen or (loading == null and int(scene.layer_seed) != from_seed and scene.get("stage") != null): break
		if Time.get_ticks_msec()-asked > 300000: break
	print("BENCH %s layer change %d -> %d held play %d ms" % [_tag,from_seed,int(scene.layer_seed),Time.get_ticks_msec()-asked])
