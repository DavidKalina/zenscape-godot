extends SceneTree
## The sky world's mountains from the build view, rendered (scripts/
## sky_islands.gd `_process`, scripts/sky_peaks.gd `overview`): no one
## steps out; the shell waits for the ranges' skyline to stand whole, then
## stills from the plate's own cameras:
##   overview: the build view's overview framing (the game's main view);
##   overview-low: the same, tipped down to the horizon (the orbit's lowest),
##     looking toward the range in sight of the plate;
##   overview-back: tipped down, looking the other way, toward the knot;
##   inspect: the chunk inspected (the build toggle off), tipped down;
## each at noon and golden hour (overview-low at night too).
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_overview.gd \
##     -- --no-title --out=/private/tmp/zs-pass3
## Options: --out=DIR, --only=overview,inspect,..., --sky-seed=N,
## --style=0|1|2 (the cloud sea: Opal, Storybook, Mystic), --tag=SUFFIX.
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
const GOLDEN_SUN := 0.1
var scene: Node3D
var out := "/private/tmp/zs-overview"
var tag := ""
var only: Array = []
var style := -1
var noon := WorldClock.hour_for_phase(0.5)
var golden := WorldClock.hour_for_phase(0.75-asin(clampf(GOLDEN_SUN/WorldClock.elevation_for_phase(0.5),-1.0,1.0))/TAU)
var night := WorldClock.hour_for_phase(0.0)

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label+tag+".png")
	image.save_png(path)
	print("OVERVIEW still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument.begins_with("--tag="): tag = argument.trim_prefix("--tag=")
		elif argument.begins_with("--style="): style = int(argument.trim_prefix("--style="))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("sky overview capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	# Never takes the keyboard: keys meant for another window can't step the
	# wanderer out (it is held still below as well).
	root.unfocusable = true
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	scene.world_clock.running = false
	if scene.wanderer != null:
		scene.wanderer.set_process(false)
		scene.wanderer.set_process_input(false)
		scene.wanderer.set_process_unhandled_input(false)
		scene.wanderer.set_process_unhandled_key_input(false)
	if style >= 0 and scene.look_pass.has_method("set_cloud_style"): scene.look_pass.set_cloud_style(style)
	# The ranges' skyline whole and faded in, if this build has one.
	var islands: Node = scene.wanderer.islands if scene.wanderer != null else null
	var began := Time.get_ticks_msec()
	if islands != null and islands.peaks.ring.get("whole") != null:
		while not islands.peaks.ring.whole and Time.get_ticks_msec()-began < 240000: await process_frame
		await create_timer(3.0).timeout
	else: await create_timer(20.0).timeout
	print("OVERVIEW skyline after %.1f s, camera far %.0f m" % [(Time.get_ticks_msec()-began)/1000.0,scene.camera.far])
	var to_range := atan2(SkyHomes.RANGE.x,SkyHomes.RANGE.z)
	var knot: Vector3 = SkyWorld.layout().knot if SkyWorld.ring_on() else -SkyHomes.RANGE
	var to_knot := atan2(knot.x,knot.z)
	for hour: float in [noon,golden,night]:
		var time_tag := "noon" if hour == noon else ("golden" if hour == golden else "night")
		for shot in ["overview","overview-low","overview-back","inspect"]:
			if not only.is_empty() and shot not in only: continue
			if hour == night and shot != "overview-low": continue
			scene.set_building(shot != "inspect")
			await frames(2)
			scene._frame_diorama()
			# The orbit's own yaw puts the camera on the far side of the
			# target: the camera looks along -(sin yaw, cos yaw).
			if shot in ["overview-low","inspect"]:
				scene.yaw = to_range+PI
				scene.polar = 1.5
			elif shot == "overview-back":
				scene.yaw = to_knot+PI
				scene.polar = 1.5
			scene._auto_orbit = false
			scene._update_camera()
			for i in range(40):
				scene.world_clock.set_time(scene.world_clock.day,hour)
				await process_frame
			await still("overview-%s-%s" % [shot.trim_prefix("overview-") if shot != "overview" else "plate",time_tag] if shot != "inspect" else "overview-inspect-%s" % time_tag)
	print("OVERVIEW done")
	quit(0)
