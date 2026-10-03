extends SceneTree
## The evening, rendered: one world held at a row of clock hours from late
## afternoon into night, the same overview each time, plus a low look across
## the land at golden hour, so the sunset's light, mist and sky can be judged
## side by side. The clock is stopped and the weather held for every still.
##
## World: --resume with a places file (--places=PATH) opens a saved world; else
## --seed N grows a generated one (saves go to a temporary folder).
## Options: --out=DIR, --hours=16.5,17.25,..., --weather=clear|overcast|mist|...,
## --mood=<scene_look_presets id>, --low-hour=17.5.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_golden_hour.gd \
##     -- --no-title --still-weather --resume --places=/private/tmp/zs-golden/world/places.json \
##     --out=/private/tmp/zs-golden/after
const DEFAULT_HOURS := [16.5, 17.25, 17.67, 18.0, 18.25, 18.75, 20.0]
var scene: Node3D
var out := "/private/tmp/zs-golden/out"
var hours: Array = DEFAULT_HOURS.duplicate()
var weather := ""
var mood := ""
var low_hour := 17.5

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280, 720): image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label + ".png")
	image.save_png(path)
	print("GOLDEN still ", path)

func hold_hour(hour: float, count: int) -> void:
	for i in range(count):
		scene.world_clock.running = false
		scene.world_clock.set_time(scene.world_clock.day, hour)
		await process_frame

func run() -> void:
	var places := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--places="): places = argument.trim_prefix("--places=")
		elif argument.begins_with("--weather="): weather = argument.trim_prefix("--weather=")
		elif argument.begins_with("--mood="): mood = argument.trim_prefix("--mood=")
		elif argument.begins_with("--low-hour="): low_hour = float(argument.trim_prefix("--low-hour="))
		elif argument.begins_with("--hours="):
			hours = []
			for part in argument.trim_prefix("--hours=").split(","): hours.append(float(part))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("golden hour capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture", true)
	scene.set_meta("no_title", true)
	if places.is_empty():
		scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
		DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	else:
		scene.places_path = places
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	await frames(30)
	while true:
		while scene.places.busy or scene._chunk_editor.forming or scene._growth.terrain < 0.995: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	if mood != "":
		scene.mood_look.choose(mood, false)
		await frames(10)
	if weather != "":
		scene.mood_look.pin("weather", weather, false)
		await frames(10)
	scene._overview()
	scene._update_camera()
	var view := [scene.target, scene.distance, scene.yaw, scene.polar]
	print("GOLDEN world ready; weather %s, mood %s, cloud %.2f, mist %.2f" % [weather, mood, scene._celestial.cloud, scene._atmosphere._fog_target])
	# Let the held air settle before the first still.
	await hold_hour(float(hours[0]), 240)
	for hour: float in hours:
		await hold_hour(hour, 150)
		var e: float = scene._celestial.sun_height
		print("GOLDEN %05.2f sun %.3f daylight %.2f day_mist %.2f" % [hour, e, scene._celestial.daylight, scene._atmosphere.day_mist])
		await still("%05.2f" % hour)
	# A low look across the land, toward the sun's side.
	scene.target = view[0]
	scene.distance = view[1] * 0.7
	scene.polar = 1.32
	scene._update_camera()
	await hold_hour(low_hour, 150)
	await still("low-%05.2f" % low_hour)
	scene.yaw = view[2] + PI
	scene._update_camera()
	await hold_hour(low_hour, 90)
	await still("low-back-%05.2f" % low_hour)
	print("GOLDEN done")
	quit(0)
