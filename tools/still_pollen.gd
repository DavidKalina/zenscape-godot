extends SceneTree
## Stills of the other kinds' pollen (docs/scenic/flower-spread.md,
## scripts/dandelion_seeds.gd) over a New world wildflowers meadow: after
## SETTLE seconds in a breeze ("breeze"), and a moment after a wind-tool gust
## goes through ("gust"). Saves captures/pollen/<tag>-<view>.png.
## Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/still_pollen.gd -- --no-title [--tag=name] [--land=wildflowers]
const SETTLE := 14.0
var scene: Node3D

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("pollen still timed out"); quit(2))
	var tag := "now"
	var land := "wildflowers"
	var near := 0.28
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--land="): land = arg.trim_prefix("--land=")
		if arg.begins_with("--distance="): near = float(arg.trim_prefix("--distance="))
	var out := ProjectSettings.globalize_path("res://captures/pollen")
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-pollen-%d/places.json" % Time.get_ticks_usec()
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	var editor: NativeChunkEditor = scene._chunk_editor
	while scene.places.busy or editor.forming: await process_frame
	await scene.places.open_land(land,preload("res://scripts/world_library.gd").seed_value("meadow-lark-2081"))
	scene._notice.visible = false
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	scene.world_clock.running = false
	await frames(90)
	scene._frame_diorama()
	scene.target += Vector3(0.0,0.5,0.0)
	scene.distance *= near
	scene.polar = 1.15
	scene._auto_orbit = false
	var seeds: Node3D = editor.dandelions
	var began := Time.get_ticks_msec()
	while float(Time.get_ticks_msec()-began)/1000.0 < SETTLE:
		scene._atmosphere._air_strength = 0.7
		scene._update_camera()
		await process_frame
	save(out,tag,"breeze",seeds)
	var heading := Vector2(1.0,0.2)
	editor.gust_from_sky(heading,0.8)
	began = Time.get_ticks_msec()
	while float(Time.get_ticks_msec()-began)/1000.0 < 2.2:
		scene._update_camera()
		await process_frame
	save(out,tag,"gust",seeds)
	quit()

func save(out: String, tag: String, view: String, seeds: Node3D) -> void:
	root.get_texture().get_image().save_png(out.path_join("%s-%s.png" % [tag,view]))
	print("POLLEN still ",tag,"-",view," grains in air ",seeds.pollen_in_air()," released ",seeds.pollen_released," blooms ",seeds._bloom_p.size()," taken ",seeds.taken.size())
