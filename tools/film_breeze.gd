extends SceneTree
## A short reel of the ambient breeze (docs/scenic/breeze.md) over a grown
## Genesis plain: meadow in the middle, a forest round the back. The air is
## left as the plain drew it. Frames go to captures/breeze/frames (JPG), one a
## frame at the fixed rate, so play them back at that rate:
##   Godot --path . --fixed-fps 30 --script res://tools/film_breeze.gd \
##     -- --no-title --plain-seed 7 [--seconds=8] [--out=captures/breeze]
##   ffmpeg -framerate 30 -i captures/breeze/frames/%04d.jpg -pix_fmt yuv420p captures/breeze/breeze.mp4
## `--land=wildflowers [--seed=meadow-lark-2081]` films a New world land
## instead (a meadow type, docs/scenic/meadows.md) from a lower view across
## it, and `--near` frames it closer. Before filming it times
## 120 frames without saving (wall clock, so run with --fixed-fps) and prints
## FRAMETIME.
## Rendered, so a window opens for the run. Saves go to /private/tmp/zs-film,
## never the player's places.
## [target (terrain-local), distance, polar°, yaw°]: the diorama camera's
## usual reach over the meadow.
const VIEW := [Vector3(0.0,0.4,0.0),23.0,58.0,-20.0]
var scene: Node3D
var out := "res://captures/breeze"
var seconds := 8.0
var land := ""
var seed_text := "meadow-lark-2081"
var near := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--land="): land = arg.trim_prefix("--land=")
		if arg.begins_with("--seed="): seed_text = arg.trim_prefix("--seed=")
		if arg == "--near": near = true
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute("/private/tmp/zs-film")
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film/places-breeze-%d.json" % Time.get_ticks_usec()
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready:
		await process_frame
	var editor: NativeChunkEditor = scene._chunk_editor
	if not land.is_empty():
		while scene.places.busy or editor.forming: await process_frame
		await scene.places.open_land(land,preload("res://scripts/world_library.gd").seed_value(seed_text))
		scene._notice.visible = false
		for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
		scene.world_clock.running = false
		await frames(90)
		scene._frame_diorama()
		scene.target += Vector3(0.0,0.6 if near else 0.3,0.0)
		scene.distance *= 0.45 if near else 0.7
		scene.polar = 1.08 if near else 0.95
		scene._auto_orbit = false
		for i in range(10):
			scene._update_camera()
			await process_frame
	else:
		await _plain(editor)
	var air: Node3D = scene._atmosphere
	print("BREEZE air %.3f eased %.3f zs_wind_strength %.3f zs_breeze %.3f" % [air.strength,air._air_strength,(air._air_strength+air.swell)*air.gust_at(air._wind_time),air.breeze()])
	var timed := PackedFloat32Array()
	var last := Time.get_ticks_usec()
	for i in range(120):
		scene._update_camera()
		await process_frame
		var now := Time.get_ticks_usec()
		timed.append((now-last)/1000.0)
		last = now
	timed.sort()
	var mean := 0.0
	for t in timed: mean += t
	mean /= timed.size()
	print("FRAMETIME mean %.2f ms, median %.2f, p95 %.2f, max %.2f; %d primitives, %d draw calls, %d objects" % [mean,timed[60],timed[113],timed[119],
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	var count := int(seconds*30.0)
	for i in range(count):
		scene._update_camera()
		await process_frame
		var image := root.get_texture().get_image()
		if image != null: image.save_jpg(out.path_join("frames/%04d.jpg" % i),0.88)
		if i % 30 == 0: print("FRAME %d breeze %.3f" % [i,air.breeze()])
	scene.queue_free()
	await process_frame
	quit()

func _plain(editor: NativeChunkEditor) -> void:
	while scene._growth.terrain < 0.995:
		await process_frame
	scene._notice.visible = false
	if scene.places.get("cover") != null: scene.places.cover.visible = false
	scene.set_looking(true)
	scene.world_clock.running = false
	scene._celestial.set_phase(0.36)
	var emergence: RefCounted = editor.emergence
	emergence.plan_on_worker = false
	var data: RefCounted = editor.data
	# A forest round the back of the plate; the meadow keeps the middle.
	for z in range(data.MEADOW_CELLS):
		for x in range(data.MEADOW_CELLS):
			var at: Vector2 = data.meadow_position(x,z)
			if at.length() > 6.5 and at.length() < 11.0 and at.y < 0.0:
				emergence.intent.forest[z*data.MEADOW_CELLS+x] = 1.0
	emergence.intent.revision += 1
	emergence.on_region_changed(Rect2(-12,-12,24,24))
	for n in range(480): emergence.advance(0.25)
	await editor.refresh(self)
	await frames(30)
	scene.target = editor.terrain.to_global(VIEW[0])
	scene.distance = VIEW[1]
	scene.polar = deg_to_rad(VIEW[2])
	scene.yaw = deg_to_rad(VIEW[3])
	for i in range(10):
		scene._update_camera()
		await process_frame
