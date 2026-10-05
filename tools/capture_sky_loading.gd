extends SceneTree
## A world's start, rendered: the loading veil while its sky is made
## (scripts/sky_reveal.gd), the reveal as the veil fades, and the build
## view's default framing once shown (studies/diorama.gd `_frame_diorama`),
## the clock held at noon. Prints the time from launch to the reveal.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_loading.gd \
##     -- --no-title --out=/private/tmp/zs-loading [--tag=after] [--yaw=0.35]
## The world is the shell's own new one, its veil asked for ("sky_veil"),
## as a start from the title or --resume has it.
var scene: Node3D
var out := "/private/tmp/zs-loading"
var tag := ""
var yaw := INF
## --polars=A,B: the overview's angles tried (studies/diorama.gd
## `overview_polar`), a framing still each.
var polars: Array = []

func _initialize() -> void:
	run.call_deferred()

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label+("-"+tag if tag != "" else "")+".png")
	image.save_png(path)
	print("LOADING still ",path)

func run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		elif a.begins_with("--tag="): tag = a.trim_prefix("--tag=")
		elif a.begins_with("--yaw="): yaw = float(a.trim_prefix("--yaw="))
		elif a.begins_with("--polars="): polars = Array(a.trim_prefix("--polars=").split(",")).map(func(v: String) -> float: return float(v))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("loading capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.unfocusable = true
	root.size = Vector2i(1280,720)
	var launched := Time.get_ticks_msec()
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.set_meta("sky_veil",true)
	scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	var loading_shot := false
	while not scene.shell_ready:
		await process_frame
		var veil: Node = _veil()
		if not loading_shot and veil != null and veil.get("_progress") != null and float(veil._progress) >= 0.3:
			loading_shot = true
			await still("loading")
	print("LOADING shown %.1f s after launch (scene %.1f s)" % [Time.get_ticks_msec()/1000.0,(Time.get_ticks_msec()-launched)/1000.0])
	scene.world_clock.running = false
	scene.world_clock.set_time(scene.world_clock.day,WorldClock.hour_for_phase(0.5))
	if yaw != INF:
		scene.yaw = yaw
		scene._update_camera()
	await create_timer(0.45).timeout
	await still("reveal-fading")
	await create_timer(1.6).timeout
	await still("reveal")
	# Without a veil (an older build), the mountains stood and faded in
	# first, for a like-for-like framing.
	var peaks: Node3D = scene.wanderer.islands.peaks
	while not peaks.ring.whole: await process_frame
	await create_timer(3.0).timeout
	for p: float in (polars if not polars.is_empty() else [INF]):
		if p != INF: scene.set("overview_polar",p)
		scene._frame_diorama()
		if yaw != INF:
			scene.yaw = yaw
			scene._update_camera()
		for i in range(30): await process_frame
		await still("framing" if p == INF else "framing-%.2f" % p)
		print("LOADING framing polar %.3f distance %.1f target %s" % [scene.polar,scene.distance,str(scene.target)])
	quit(0)

func _veil() -> Node:
	for child in scene.get_children():
		if child is CanvasLayer and child.get_script() == preload("res://scripts/title_loading.gd"): return child
	return null
