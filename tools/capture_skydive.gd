extends SceneTree
## The skydive, rendered (scripts/sky_dive.gd through scripts/wanderer_eye.gd):
## the plane high over home, the eject, the fall (and tucked), the canopy
## opening and floating, the flare and the landing, and the plane parked
## after; with close views from the side (the play frozen) of the pilot
## falling and under the canopy. Rendered only when asked for (needs a
## window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_skydive.gd \
##     -- --no-title --out=/private/tmp/zs-skydive
## Options: --out=DIR, --hour=H, --only=NAME (a still's name begins with it).
const SkyPlane = preload("res://scripts/sky_plane.gd")
const SkyDive = preload("res://scripts/sky_dive.gd")
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-skydive"
var hour := WorldClock.hour_for_phase(0.42)
var only := ""

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func seconds(s: float) -> void:
	await create_timer(s).timeout

func still(label: String) -> void:
	if only != "" and not label.begins_with(only): return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label+".png")
	image.save_png(path)
	print("SKYDIVE still ",path)

## Freezes the play and looks at the pilot from `offset` (global, from the
## hips), then lets it go on.
func close(label: String, offset: Vector3, look_up := 0.0) -> void:
	await close_on(label,eye.dive.position+Vector3.UP*look_up,offset)

## Freezes the play and looks at `at` from `offset`, then lets it go on.
func close_on(label: String, at: Vector3, offset: Vector3) -> void:
	eye.set_process(false)
	var from := at+offset
	var dir := (from-at).normalized()
	scene.target = at
	scene.distance = offset.length()
	scene.yaw = atan2(dir.x,dir.z)
	scene.polar = acos(clampf(dir.y,-1.0,1.0))
	scene.camera_roll = 0.0
	eye.camera.fov = 50.0
	await frames(3)
	await still(label)
	eye.set_process(true)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--hour="): hour = float(argument.trim_prefix("--hour="))
		elif argument.begins_with("--only="): only = argument.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("skydive capture timed out"); quit(2))
	Engine.max_fps = 60
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
	await seconds(1.0)
	scene.world_clock.running = false
	scene.world_clock.set_time(scene.world_clock.day,hour)
	eye = scene.wanderer
	eye.place(Vector3.ZERO)
	eye.enter()
	await frames(5)
	eye._layer.visible = false
	var middle: Vector3 = eye.editor.terrain.global_position+eye._land_middle(eye.editor.data)
	var floor_y: float = eye._floor_global(Vector2(middle.x,middle.z))
	if not is_nan(floor_y): middle.y = floor_y
	eye._launch(SkyPlane.CRUISE_SPEED,false,middle+Vector3(0.0,95.0,40.0),0.0)
	eye.chase.reset(eye.glide,eye.glide.position+Vector3(0.0,2.0,6.0))
	await seconds(2.5)
	eye._layer.visible = false
	await still("01-plane")
	eye.eject()
	await seconds(0.2)
	await still("02-pop")
	await close("02b-pop-side",Vector3(3.2,0.4,0.0))
	await seconds(1.6)
	await still("03-freefall")
	await close("04-freefall-side",Vector3(2.2,0.6,0.6))
	Input.action_press(&"fly_boost")
	await seconds(1.6)
	await still("05-tucked")
	Input.action_release(&"fly_boost")
	await seconds(0.8)
	eye._open_asked = true
	await seconds(0.45)
	await still("06-opening")
	await seconds(1.6)
	await still("07-canopy")
	await close("08-canopy-side",Vector3(3.6,0.6,-2.4),1.0)
	await close("09-canopy-front",Vector3(-1.0,1.4,-4.5),1.2)
	await close("10-canopy-wide",Vector3(-14.0,-5.0,10.0),1.0)
	while eye.diving and eye.dive.height > 1.6: await process_frame
	await still("11-flare")
	while eye.diving: await process_frame
	await seconds(0.5)
	await still("12-landed")
	var began := Time.get_ticks_msec()
	while not eye.has_parked() and Time.get_ticks_msec()-began < 40000:
		if eye._drone_landing != null and eye._drone_landing.phase == 3 and only == "": pass
		await process_frame
	await seconds(0.8)
	await still("13-parked")
	if eye.has_parked():
		var feet: Vector3 = eye.figure.global_position
		var plane_at: Vector3 = eye.parked.global_position
		print("SKYDIVE parked %.1f m from the pilot" % Vector2(feet.x-plane_at.x,feet.z-plane_at.z).length())
		await close_on("14-parked-above",(feet+plane_at)*0.5,Vector3(4.0,9.0,9.0))
	print("SKYDIVE done")
	quit(0)
