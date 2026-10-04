extends SceneTree
## What lies behind the plate, rendered: grows a world, then shoots the
## overview, a wider and higher view and a low view at a few hours (and one
## overcast), so the backdrop can be judged against the hour and the weather.
## --looks adds the overview under a few authored looks; --only=NAME keeps
## only the shots whose name holds NAME (overview, wide, low, overcast);
## --hours=23,1.5 shoots at those hours instead.
## Rendered only when asked for:
##   Godot --path . --windowed --resolution 1280x720 -s res://tools/capture_backdrop.gd \
##     -- --no-title --seed 184 --looks --backdrop-dir=/private/tmp/zs-backdrop/after
## Saves go to a temporary places folder, never the player's.
const HOURS := [10.0, 17.67, 18.25, 23.0]
const LOOKS := ["desert_afternoon", "misty_hollow", "storm_gathering", "rosewater_dusk", "nordic_night", "first_snow"]
var scene: Node3D
var out := "/private/tmp/zs-backdrop/out"
var only := ""
var hours: Array = HOURS

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func still(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null: return
	if image.get_size() != Vector2i(1280, 720): image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	image.save_png(out.path_join(name))
	var cam := root.get_viewport().get_camera_3d()
	print("BACKDROP camera fov %.1f forward y %.3f height %.1f distance %.1f" % [cam.fov, -cam.global_basis.z.y, cam.global_position.y, scene.distance])
	print("BACKDROP still ", out.path_join(name))

func pose(polar: float, distance_scale: float, yaw_turn := 0.0) -> void:
	scene._overview()
	scene.polar = polar if polar > 0.0 else scene.polar
	scene.distance *= distance_scale
	scene.yaw += yaw_turn
	scene._update_camera()

func hour(value: float, cloud := -1.0) -> void:
	scene.world_clock.set_time(scene.world_clock.day, value)
	scene._celestial.cycling = false
	if cloud >= 0.0:
		scene._celestial.cloud = cloud
		scene._precipitation.cloud_override = cloud

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--backdrop-dir="): out = argument.trim_prefix("--backdrop-dir=")
		if argument.begins_with("--only="): only = argument.trim_prefix("--only=")
		if argument.begins_with("--hours="): hours = Array(argument.trim_prefix("--hours=").split(",")).map(func(h: String) -> float: return h.to_float())
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	scene.set_meta("movie_capture", true)
	scene.set_meta("no_title", true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready:
		await process_frame
	await frames(30)
	while scene._growth.terrain < 0.995 or scene.places.busy or scene._chunk_editor.forming:
		await process_frame
	await frames(60)
	hour(23.0, 0.06)
	pose(1.2, 1.0, 0.0)
	await frames(120)
	var cam := root.get_viewport().get_camera_3d()
	var dirp := Vector3(-0.73, -0.21, 0.65).normalized()
	for shot in [["planet-wide", 55.0], ["planet-mid", 22.0], ["planet-close", 9.0]]:
		for i in 25:
			cam.fov = shot[1]
			cam.look_at(cam.global_position + dirp * 100.0, Vector3.UP)
			await process_frame
		await still("%s.png" % shot[0])
	quit(0)
