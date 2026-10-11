extends SceneTree
## The title's first look, captured (scripts/kit_isle/front_door.gd): the
## front door opened as the game opens it (the project's main scene, made
## current, so the title shows over the orbiting isle), held WAIT seconds
## after the isle is up, saved, and the sky's state printed (the weather,
## the hour, the season, the orbit). Flags after the out path go to the
## isle as launch flags (kit_weather's --weather=, --hour=, --season=...).
##   Godot --windowed --path . --resolution 1440x900 -s res://tools/capture_front_door.gd \
##     -- --out=/private/tmp/zs-title/now.png [--wait=6] [--rescale] [--weather=clear ...]
## --rescale then changes the 3D render scale and saves a second view
## (<out>_rescaled.png), to see the cloud volume through a resize.
const LaunchArgs = preload("res://scripts/launch_args.gd")
const FRONT_DOOR := "res://studies/zenscape.tscn"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var out := "/private/tmp/zs-title/title.png"
	var wait := 6.0
	var rescale := false
	var passed := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.get_slice("=",1)
		elif arg.begins_with("--wait="): wait = float(arg.get_slice("=",1))
		elif arg == "--rescale": rescale = true
		elif arg != "--no-title": passed.append(arg)
	create_timer(400).timeout.connect(func() -> void: print("capture_front_door: timed out"); quit(2))
	LaunchArgs.set_override(passed)
	change_scene_to_file(FRONT_DOOR)
	while current_scene == null or current_scene.scene_file_path != FRONT_DOOR: await process_frame
	var game: Node3D = current_scene
	while not game.isle_up: await process_frame
	await create_timer(wait).timeout
	var door: Node = game.front_door
	var isle: Node3D = door.isle
	var weather: Node = isle.get("weather")
	var precipitation: Node3D = isle._precipitation
	print("capture_front_door: titled=%s orbit middle=%s distance=%.1f eye=%s" % [door.titled,door.orbit_middle,door.orbit_distance,isle.camera.global_position])
	if weather != null:
		print("capture_front_door: live=%s hour=%.2f day=%.0f weather=%s state=%s" % [weather.live,weather.clock.hour,float(weather.clock.day),
			precipitation.PRESET_NAMES[precipitation.preset_index],precipitation.state])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("capture_front_door: saved ",out)
	if rescale:
		# The render resolution changed mid-run, as the settings change it:
		# the cloud volume's targets are remade (scripts/cloud_volume_effect.gd).
		root.scaling_3d_scale = 0.75 if root.scaling_3d_scale > 0.8 else 1.0
		await create_timer(3.0).timeout
		await RenderingServer.frame_post_draw
		var again := "%s_rescaled.png" % out.get_basename()
		root.get_texture().get_image().save_png(again)
		print("capture_front_door: saved ",again)
	quit(0)
