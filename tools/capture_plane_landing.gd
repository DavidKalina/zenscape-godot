extends SceneTree
## The plane's landing, parking and takeoff, rendered (scripts/plane_landing.gd,
## scripts/wanderer_eye.gd): the wanderer flies off the plate's edge, turns
## for home and presses F; a still a little way into each part of the
## landing (line-up, final, flare, touchdown, rollout, hop-out), one once
## walking beside the plane, one stepped out to the build view with the
## plane parked, and the takeoff (taxi, roll, lift).
## Rendered only when asked for (needs a window):
##   Godot --windowed --fixed-fps 30 --path . --resolution 1280x720 \
##     -s res://tools/capture_plane_landing.gd -- --no-title --out=/private/tmp/zs-plane-landing
## Options: --out=DIR, --away=SECONDS (flown out before F).
const PlaneLanding = preload("res://scripts/plane_landing.gd")
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-plane-landing"
var away := 2.0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label+".png")
	image.save_png(path)
	print("PLANE LANDING still ",path)

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

## Stills `delays` seconds into each named phase as the sequence runs.
func shoot(delays: Dictionary, most: float) -> void:
	var done := {}
	var began := Time.get_ticks_msec()
	while eye.landing != null and (Time.get_ticks_msec()-began)/1000.0 < most:
		var name: String = PlaneLanding.NAMES[eye.landing.phase]
		if delays.has(name) and not done.has(name) and eye.landing.time >= float(delays[name]):
			done[name] = true
			await still("%02d-%s" % [delays.keys().find(name)+(0 if delays.has("line-up") else 10),name])
		await process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--away="): away = float(argument.trim_prefix("--away="))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("plane landing capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
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
	await frames(60)
	eye = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,4.0))
	eye.enter()
	eye._yaw = atan2(-1.0,0.0)+eye._turn()
	eye.motor.facing = eye._yaw-eye._turn()
	eye._polar = PI*0.5
	eye._launch(1.0)
	await create_timer(away).timeout
	eye.handle(key(KEY_F))
	while eye.landing == null and eye.flying: await process_frame
	await shoot({"line-up":1.2,"descent":0.6,"flare":0.25,"touchdown":0.12,"rollout":0.5,"hop-out":0.3},40.0)
	await create_timer(1.4).timeout
	await still("07-walking-beside")
	# The build view with the plane parked.
	eye.leave()
	await create_timer(1.5).timeout
	var parked: Node3D = eye.parked
	if parked != null:
		scene.target = parked.global_position
		scene.distance = 9.0
		scene.polar = 1.05
		scene.yaw = parked.global_rotation.y+2.3
		await create_timer(0.6).timeout
	await still("08-parked-build-view")
	scene.target = eye.editor.terrain.global_position
	scene.distance = 60.0
	scene.polar = 0.9
	await create_timer(0.8).timeout
	await still("09-parked-whole-island")
	# Back in and away.
	eye.enter()
	await frames(10)
	eye._board()
	await shoot({"taxi":0.3,"roll":0.9,"lift":0.6},20.0)
	await create_timer(1.0).timeout
	await still("13-flying-on")
	quit(0)
