extends SceneTree
## THROWAWAY: films and stills a row of the game's layered_tree variants (seed forms
## 0, 1, 2 = VARIANT_SEEDS 0, 5, 12) on a plain patch, to judge the lump motion
## (shaders/layered_clump_motion.gdshaderinc). Ambient breeze, then a wind-tool lane through.
## Rendered (needs a window):
##   Godot --path . --fixed-fps 30 --script res://tools/film_layered_tree.gd -- --no-title \
##     [--only=stills|film] [--seconds=14] [--out=captures/layered-tree-motion] [--tag=a]
## Frames land in <out>/frames (JPG) and ffmpeg makes <out>/layered-tree<tag>.mp4.
const CENTRE := Vector2(1.0, -1.0)
## Row, left to right: [form index (0 original, 1 seed 5, 2 seed 12), x offset from CENTRE, scale].
const ROW := [[0, -3.2, 0.8], [1, 0.0, 0.8], [2, 3.2, 0.8]]
var scene: Node3D
var editor: NativeChunkEditor
var level := 0.0
var out := "res://captures/layered-tree-motion"
var only := ""
var seconds := 14.0
var tag := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		scene._atmosphere._air_strength = 0.5
		if absf(scene._atmosphere.fog_amount - 0.04) > 0.01:
			scene._atmosphere.set_fog(0.04)
			scene._atmosphere.set_haze(0.06)

func view(target: Vector3, distance: float, polar: float, yaw: float) -> void:
	scene.target = editor.terrain.to_global(target)
	scene.distance = distance
	scene.polar = polar
	scene.yaw = yaw
	scene._auto_orbit = false
	scene._update_camera()

func run() -> void:
	create_timer(560).timeout.connect(func() -> void: push_error("layered tree film timed out"); quit(2))
	root.size = Vector2i(1600, 900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-layered-%d/places.json" % Time.get_ticks_usec()
	scene.set_meta("movie_capture", true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	editor = scene._chunk_editor
	scene.world_clock.running = false
	scene.apply_scene_mood("Alpine daylight")
	for overlay: Node in scene.find_children("*", "CanvasLayer", true, false): overlay.visible = false
	var data := editor.data
	var near := PackedFloat32Array()
	for i in range(data.points.size()):
		if data.points[i].distance_to(CENTRE) < 6.0: near.append(data.heights[i])
	near.sort()
	level = near[near.size() / 2]
	data.begin_stroke()
	var heights := data.heights.duplicate()
	for i in range(data.points.size()):
		heights[i] = lerpf(heights[i], level, 1.0 - smoothstep(8.0, 10.5, data.points[i].distance_to(CENTRE)))
	data.heights = heights
	data.end_stroke()
	data.erase_objects(CENTRE, 14.0)
	var world: Dictionary = preload("res://scripts/seeded_variety.gd").world(data._recipe_settings)
	for entry: Array in ROW:
		var point := CENTRE + Vector2(entry[1], 0.0)
		for attempt in range(60):
			var at := point + Vector2(0.0, 0.015 * attempt)
			if data.place("layered_tree", at, 0.0, entry[2]) < 0: continue
			if preload("res://scripts/seeded_variety.gd").layered_index(data.objects[data.objects.size() - 1], world) == entry[0]:
				print("TREE form ", entry[0], " attempt ", attempt)
				break
			data.erase_objects(at, 0.2)
	await editor.refresh(self)
	await frames(60)
	Input.warp_mouse(Vector2(4, 4))
	if only != "film": await stills()
	if only != "stills": await film()
	quit(0)

func save_png(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("%s%s.png" % [name, tag]))
	print("TREEFILM still ", name)

func sun_travel() -> Vector3:
	for light: Node in scene.find_children("*", "DirectionalLight3D", true, false):
		if light.visible and light.light_energy > 0.05: return -light.global_transform.basis.z
	return Vector3(0, -1, 0)

func stills() -> void:
	var look := Vector3(CENTRE.x + 0.3, level + 1.7, CENTRE.y)
	view(look, 14.0, 1.2, 0.0)
	await frames(90)
	await save_png("still-row")
	view(Vector3(CENTRE.x, level + 1.8, CENTRE.y), 8.0, 1.28, 0.25)
	await frames(30)
	await save_png("still-close")

func film() -> void:
	view(Vector3(CENTRE.x + 0.3, level + 1.7, CENTRE.y), 14.0, 1.2, 0.0)
	await frames(30)
	editor._make_gust()
	var count := int(seconds * 30.0)
	var gust_at := int(count * 0.5)
	for i in range(count):
		if i == gust_at:
			# Upwind of the row, along the wind tool's own lane.
			var heading := Vector2(1.0, 0.0)
			var from := CENTRE + Vector2(-9.0, 0.0)
			editor.gust.send_lane(Vector3(from.x, level, from.y), heading, 0.9, 5.0)
		scene._atmosphere._air_strength = 0.5
		await process_frame
		var image := root.get_texture().get_image()
		if image != null: image.save_jpg(out.path_join("frames/%04d.jpg" % i), 0.9)
	var mp4 := out.path_join("layered-tree%s.mp4" % tag)
	var code := OS.execute("/opt/homebrew/bin/ffmpeg", ["-y", "-loglevel", "error", "-framerate", "30", "-i", out.path_join("frames/%04d.jpg"), "-pix_fmt", "yuv420p", mp4])
	print("TREEFILM film ", mp4, " ffmpeg ", code)
