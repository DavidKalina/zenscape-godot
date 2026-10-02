extends SceneTree
## Stills of the wind tool's visible air (scripts/wind_gust.gd,
## docs/scenic/wind-gust.md "How it looks"): a lane gust and a burst on the
## Genesis plain, a small meadow staged round the middle so there is grass,
## flowers and a few trees for the air to move. One shot a run (--shot=):
## - gust: a full swipe sent across the meadow, stills as the air passes;
## - burst: a still press held 1 s, then let go, stills as the ring runs out;
## - close: the gust again, from 9 m, low, toward the sun.
## Stills go to captures/wind-tool/<tag>-<shot>-<n>.png (--tag=, default
## "look"). Rendered (needs a window):
##   Godot --windowed --resolution 1280x720 --path . \
##     -s res://tools/film_wind_tool.gd -- --no-title --shot=gust --tag=after
## Headless it runs the same steps and prints what was sent.
## `--land=cosmos [--seed=meadow-lark-2081]` opens a New world land (a meadow
## type, docs/scenic/meadows.md) instead of staging the plain's small meadow.
## `--film` also saves every other frame for 4 s after the send (run with
## --fixed-fps 60) as captures/wind-tool/<tag>-<shot>-frames/NNNN.jpg, for
## `ffmpeg -framerate 30`.

const MIDDLE := Vector2(0.0,0.0)

var scene: Node3D
var editor: NativeChunkEditor
var shot := "gust"
var tag := "look"
var out := ""
var land := ""
var seed_text := "meadow-lark-2081"
var film := false

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func seconds(value: float) -> void:
	await frames(int(value*60.0))

func world(p: Vector3) -> Vector3:
	return editor.terrain.to_global(p)

func ground(p: Vector2) -> float:
	var h: Variant = editor.data.ground_height(p)
	return float(h) if h != null else 0.0

func look(target: Vector2, distance: float, yaw: float, polar: float) -> void:
	scene.target = world(Vector3(target.x,ground(target),target.y))
	scene.distance = distance
	scene.yaw = yaw
	scene.polar = polar
	scene._update_camera()

func hour(phase: float) -> void:
	var clock: WorldClock = scene.world_clock
	clock.running = false
	clock.set_time(clock.day,WorldClock.hour_for_phase(phase))
	var mood: Node = scene.get("mood_look")
	if mood != null and mood.has_method("pin_hour"): mood.pin_hour(phase)
	scene._celestial.set_phase(phase)
	scene._celestial.update_rig()

func still(n: int) -> void:
	if DisplayServer.get_name() == "headless": return
	if film: return
	await RenderingServer.frame_post_draw
	var path := "%s/%s-%s-%d.png" % [out,tag,shot,n]
	root.get_texture().get_image().save_png(path)
	print("FILM still ",path)

func stage() -> void:
	var data := editor.data
	data.begin_stroke()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for i in range(70):
		var p := MIDDLE+Vector2(rng.randf_range(-9.0,9.0),rng.randf_range(-7.0,7.0))
		var kind: String = ["grass_tuft","grass_tuft","grass_tuft","daisy_flower","button_flower","umbel_flower"][i%6]
		data.place(kind,p,rng.randf()*TAU,rng.randf_range(0.8,1.2))
	for p: Vector2 in [Vector2(-7.5,-6.0),Vector2(8.0,-5.5),Vector2(6.5,6.5)]:
		var id := data.place("broadleaf",p,rng.randf()*TAU,1.0)
		if id >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	await editor.refresh(self)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.trim_prefix("--shot=")
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--land="): land = arg.trim_prefix("--land=")
		if arg.begins_with("--seed="): seed_text = arg.trim_prefix("--seed=")
		if arg == "--film": film = true
	out = ProjectSettings.globalize_path("res://captures/wind-tool")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(300).timeout.connect(func() -> void: push_error("wind tool film timed out"); quit(2))
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-wind-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	print("FILM loading ",Time.get_ticks_msec())
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	editor = scene._chunk_editor
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	scene._auto_orbit = false
	RenderingServer.frame_pre_draw.connect(func() -> void:
		var rig: Variant = scene.get("camera_rig")
		if rig != null and rig.get("layer") != null: rig.layer.visible = false
		if scene.get("god_hand") != null: scene.god_hand.visible = false)
	print("FILM ready ",Time.get_ticks_msec())
	if land.is_empty():
		hour(0.36)
		await stage()
	else:
		await scene.places.open_land(land,preload("res://scripts/world_library.gd").seed_value(seed_text))
		scene._notice.visible = false
		await frames(90)
		hour(0.36)
	editor._make_gust()
	var gust: Node3D = editor.gust
	match shot:
		"gust", "close":
			if shot == "gust": look(MIDDLE,20.0,0.35,1.05)
			else: look(MIDDLE+Vector2(1.0,0.0),9.0,-0.9,1.32)
			await seconds(2.0)
			var origin := MIDDLE+Vector2(-9.0,1.5)
			var g: Dictionary = gust.send_lane(Vector3(origin.x,ground(origin),origin.y),Vector2(1.0,-0.15),0.9,3.0)
			print("FILM sent ",g.kind," reach ",g.reach," run ",g.run)
			if film: await _film()
			for n in range(5):
				await seconds(0.35)
				await still(n)
		"burst":
			look(MIDDLE,18.0,0.35,1.0)
			await seconds(2.0)
			# No mouse is down, so the editor would let the press go at once
			# (_gust_process); it rests while the hand holds.
			editor.set_process(false)
			gust.press(Vector3(MIDDLE.x,ground(MIDDLE),MIDDLE.y),3.0)
			await seconds(1.0)
			await still(0)
			var g: Dictionary = gust.release()
			editor.set_process(true)
			print("FILM sent ",g.kind," reach ",g.reach," run ",g.run)
			if film: await _film()
			for n in range(1,5):
				await seconds(0.3)
				await still(n)
	await seconds(2.0)
	print("FILM done")
	quit(0)

## Every other frame for 4 s, as JPGs to play back at 30 fps.
func _film() -> void:
	if DisplayServer.get_name() == "headless": return
	var dir := "%s/%s-%s-frames" % [out,tag,shot]
	DirAccess.make_dir_recursive_absolute(dir)
	for i in range(240):
		await RenderingServer.frame_post_draw
		if i % 2 == 0: root.get_texture().get_image().save_jpg("%s/%04d.jpg" % [dir,i/2],0.9)
		await process_frame
	print("FILM frames ",dir)
