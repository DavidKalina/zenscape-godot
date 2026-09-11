extends SceneTree
## One continuous shot of the rope bridge being weathered: four seconds of calm,
## six of storm with a strike in the middle of them, four of snow settling on the
## boards. One camera, never moved, because the question is whether the crossing
## changes -- not whether it can be framed well three times.
##
## `--clip=<dir> --frames=N --size=WxH` writes numbered PNGs and, from three of
## them, `calm.png`, `storm.png` and `snow.png`. It prints the ffmpeg line.
##
## The clock is this tool's, not the engine's. Capturing a frame takes far longer
## than a frame's worth of wall time, so `Engine.max_physics_steps_per_frame` is
## pinned to one tick an iteration and each captured frame takes exactly
## `TICKS_PER_FRAME` iterations: the rope then swings at the rate the finished
## clip plays back at, instead of fast-forwarding between captures. The study's
## own `_process` is off for the same reason and is driven a frame at a time.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/film_bridge_weather.gd \
##     -- --clip=/private/tmp/bridge-weather --frames=420 --size=1280x800
##
## Never --headless: the fidelity scene hangs there. Never await
## `RenderingServer.frame_post_draw` either -- it never returns when the window
## is occluded -- so every capture forces its own draw.
const FRAME_SIZE := Vector2i(1280, 800)
const FPS := 30
const TICKS_PER_FRAME := 2     ## 60 Hz physics into a 30 fps clip: real time.
const TOTAL_FRAMES := 420      ## 14 s: four calm, six of storm, four of snow.
## Phase boundaries, in seconds from the first frame.
const STORM_AT := 4.0
const STRIKE_AT := 7.0         ## Three seconds into the storm.
const SNOW_AT := 10.0
## Where the stills come from, in seconds: late in each phase, once it has taken.
const CALM_STILL := 3.5
const STORM_STILL := 9.0
const SNOW_STILL := 13.8
## The shot. Three-quarter on, a little above the deck, far enough back that both
## bridgeheads are in frame and close enough that a plank is a plank.
const SHOT_DISTANCE := 32.0
const SHOT_POLAR := 1.02
const SHOT_YAW := 0.3
const SHOT_LIFT := 3.0         ## Aim above the mid-deck, so the sky is in it.
const SHOT_HOUR := 11.0        ## The study opens near dusk; a storm is dark enough.
## How fast the snow phase lays cover down, per second, so four seconds of it
## reaches full white. The world's own frost takes a winter.
const SNOW_RATE := 0.34
## The storm preset closes the sky to nothing: at full cloud the crossing is a
## silhouette and the clip says only that it got dark. Held here so the wet wood
## and the lurching are visible -- the rain, the wind and the strikes are the
## preset's own, only the ceiling is the tool's.
const STORM_CLOUD := 0.78
## And the storm dial itself, which in `celestial.gd` halves the sky's ambient
## and takes the hemisphere light down with it. Held at less than half so the
## crossing is lit by something. Rain, wind and strikes are all still the
## preset's own -- `state.x` and the wind dial are untouched. Not lower: the
## rainbow `celestial.gd` draws out of a wet sky fades in as the storm dial
## drops, and a double rainbow over a squall reads as the morning after it.
const STORM_GLOOM := 0.62
var scene: Node3D
var frame_size := FRAME_SIZE
var clip_dir := ""
var frames := TOTAL_FRAMES
var _stills: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(900).timeout.connect(func() -> void:
		print("FILM BRIDGE WEATHER: timed out")
		quit(2))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--clip="): clip_dir = argument.trim_prefix("--clip=")
		elif argument.begins_with("--frames="): frames = maxi(2, int(argument.trim_prefix("--frames=")))
		elif argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			frame_size = Vector2i(int(parts[0]), int(parts[1]))
	if clip_dir.is_empty():
		print("FILM BRIDGE WEATHER: pass --clip=<dir>")
		quit(1)
		return
	Engine.physics_ticks_per_second = FPS * TICKS_PER_FRAME
	# One tick an iteration, so a slow capture dilates time instead of skipping it.
	Engine.max_physics_steps_per_frame = 1
	_hold_frame_size()
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._ui.visible = false
	if "_study_ui" in scene: scene._study_ui.visible = false
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	scene.rebuild_second_chunk()
	# The study now opens with the bridge unbuilt; these want the finished deck.
	scene.set_bridge_built(true)
	_daylight()
	_aim()
	print("FILM BRIDGE WEATHER shot: day %d hour %.2f, daylight %.2f, camera (%.1f, %.1f, %.1f) on target (%.1f, %.1f, %.1f)" % [
		scene.world_clock.day, scene.world_clock.hour, float(scene._celestial.state.get("zs_daylight", -1.0)),
		scene.camera.global_position.x, scene.camera.global_position.y, scene.camera.global_position.z,
		scene.target.x, scene.target.y, scene.target.z])
	await _clip()
	print("FILM BRIDGE WEATHER done")
	scene.queue_free()
	await process_frame
	quit(0)

## The study opens near dusk, where a still of two dark islands says nothing.
func _daylight() -> void:
	scene._celestial.cycling = true
	scene.world_clock.set_time(0, SHOT_HOUR)
	_calm()
	for step in range(60):
		scene._process(1.0 / 60.0)

## Three-quarter on the mid-deck, set once and left there.
func _aim() -> void:
	scene.target = scene.deck_surface(0.5) + Vector3.UP * SHOT_LIFT
	scene.distance = SHOT_DISTANCE
	scene.polar = SHOT_POLAR
	scene.yaw = SHOT_YAW
	scene._auto_orbit = false
	scene._update_camera()

## Dry, still and warm: the state the clip has to start from, forced rather than
## waited for, because ground wet takes a minute of world time to shed.
func _calm() -> void:
	scene._precipitation.set_weather(0, true)
	var surface: RefCounted = scene._precipitation.surface_weather
	surface.ground_wet = 0.0
	surface.snow_cover = 0.0
	surface.cold = 0.0
	surface.target_cold = 0.0
	surface.ice = 0.0
	scene._felt_wind = float(scene._precipitation.profiles["clear"]["wind"])

func _clip() -> void:
	DirAccess.make_dir_recursive_absolute(clip_dir)
	var struck := false
	var snowing := false
	var dt := 1.0 / float(FPS)
	for frame in range(frames):
		var clock := float(frame) * dt
		if clock >= STORM_AT and clock < STORM_AT + dt:
			# Rain and wind arrive together and the wet soaks in on its own.
			scene._precipitation.set_weather(2, true)
			scene._precipitation.cloud_override = STORM_CLOUD
			scene._precipitation.state.w = STORM_GLOOM
			scene._precipitation.target.w = STORM_GLOOM
			print("FILM BRIDGE WEATHER %.1f s: the storm" % clock)
		if clock >= STRIKE_AT and not struck:
			var mid: Vector3 = scene.deck_surface(0.5)
			scene._lightning.strike(Vector2(mid.x, mid.z), scene.camera.global_position)
			struck = true
			print("FILM BRIDGE WEATHER %.1f s: lightning" % clock)
		if clock >= SNOW_AT:
			if not snowing:
				scene._precipitation.set_weather(3, true)
				scene._precipitation.cloud_override = STORM_CLOUD
				snowing = true
				print("FILM BRIDGE WEATHER %.1f s: the cold" % clock)
			var surface: RefCounted = scene._precipitation.surface_weather
			surface.cold = 1.0
			surface.target_cold = 1.0
			surface.ice = minf(1.0, surface.ice + SNOW_RATE * dt)
			surface.snow_cover = minf(1.0, surface.snow_cover + SNOW_RATE * dt)
		scene._process(dt)
		for tick in range(TICKS_PER_FRAME):
			await physics_frame
		_grab(clip_dir.path_join("%04d.png" % frame), frame)
	for label: String in _stills:
		var at: String = _stills[label]
		DirAccess.copy_absolute(at, clip_dir.path_join("%s.png" % label))
		print("FILM BRIDGE WEATHER still %s from %s" % [label, at])
	print("FILM BRIDGE WEATHER clip: %d frames in %s" % [frames, clip_dir])
	print("ffmpeg -y -framerate %d -i %s/%%04d.png -c:v libx264 -pix_fmt yuv420p -crf 30 -vf scale=1280:-2 %s" % [
		FPS, clip_dir, clip_dir.path_join("clip.mp4")])

func _grab(path: String, frame: int) -> void:
	_hold_frame_size()
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null:
		print("FILM BRIDGE WEATHER: no image for ", path)
		return
	image.save_png(path)
	# Picked by frame number, not by clock: at thirty frames a second the clock
	# lands a hair under a round second and a comparison against it misses.
	for pick in [["calm", CALM_STILL], ["storm", STORM_STILL], ["snow", SNOW_STILL]]:
		if frame == int(round(float(pick[1]) * float(FPS))): _stills[pick[0]] = path

## The project opens maximized and the window manager re-applies that a few
## frames after the window appears, which would resize images mid-shoot.
func _hold_frame_size() -> void:
	if root.size == frame_size: return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = frame_size
