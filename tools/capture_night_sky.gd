extends SceneTree
## The night sky from the ground, rendered: grows a fresh world, steps into
## photo mode's ground eye, clears the weather, sets deep night and looks up
## into the sky on a few bearings, saving a raw still of each. Pass
## --shader-stars for the dome's painted stars (the before), and --aurora to
## force the aurora on. Rendered only when asked for:
##   Godot --path . --windowed --script res://tools/capture_night_sky.gd \
##     -- --no-title --seed 184 --aurora --sky-dir=/private/tmp/zs-sky/after
## Saves go to a temporary places folder, never the player's.
const BEARINGS := [0.0, 1.6, 3.2, 4.8]
## Ground-eye pitches: 27 degrees up (the steepest it allows) and just over
## the horizon.
const PITCHES := [2.05, 1.72]
var scene: Node3D
var photo: Node
var out := "/private/tmp/zs-sky/out"

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

## Holds deep night, clear air and the pose against auto-level while waiting.
func hold(count: int, yaw: float, polar: float) -> void:
	for i in range(count):
		_night()
		photo._goal.yaw = yaw
		photo._goal.polar = polar
		await process_frame

func _night() -> void:
	scene._celestial.cycling = false
	scene._celestial.set_phase(0.02)
	scene._celestial.cloud = 0.04
	scene._precipitation.cloud_override = 0.04

func still(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null: image.save_png(out.path_join(name))
	print("SKY still ", out.path_join(name))

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sky-dir="): out = argument.trim_prefix("--sky-dir=")
	DirAccess.make_dir_recursive_absolute(out)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 1000)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	scene.set_meta("movie_capture", true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready:
		await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 1000)
	await frames(30)
	# --seed regrows on the next frame; wait for the new world to settle.
	while scene._growth.terrain < 0.995 or scene.places.busy or scene._chunk_editor.forming:
		await process_frame
	await frames(60)
	photo = scene.photo
	scene.creation_palette.photo_button.pressed.emit()
	await frames(10)
	if not photo.active:
		print("SKY could not enter photo mode")
		quit(1)
		return
	photo.set_ground(true)
	print("SKY viewport ", root.get_texture().get_size(), " stars ", "painted" if "--shader-stars" in OS.get_cmdline_user_args() else "real")
	# Let night, the clear sky and the eye settle before the first still.
	await hold(240, photo._goal.yaw, PITCHES[0])
	var start: float = photo._goal.yaw
	for b in BEARINGS.size():
		for p in PITCHES.size():
			await hold(90, start + BEARINGS[b], PITCHES[p])
			await still("sky-b%d-%s.png" % [b, "up" if p == 0 else "low"])
	photo.leave()
	await frames(5)
	quit(0)
