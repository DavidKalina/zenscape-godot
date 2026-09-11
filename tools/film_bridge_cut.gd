extends SceneTree
## One shot of the rope crossing being cut: a couple of seconds of an intact
## deck, then the joint at mid-span goes and both halves swing down off their
## own anchors. One camera, never moved, because the whole question is whether
## the fall reads -- not whether the aftermath can be framed well.
##
## `--stills=<dir>` writes `cut_before.png` (the deck whole), `cut_swinging.png`
## (a second after the cut, the halves still going) and `cut_settled.png` (both
## hanging). `--clip=<dir>` additionally writes every frame as a numbered PNG
## and prints the ffmpeg line; `--frames=N --size=WxH` set the length and the
## frame. `--near` cuts two links off the near bridgehead instead of at the
## middle, which is the shot where the long far half swings back against the
## cliff it is tied to.
##
## The clock is this tool's, not the engine's, for the same reason as
## `tools/film_bridge_weather.gd`: capturing a frame takes far longer than a
## frame's worth of wall time, so physics is pinned to one tick an iteration and
## each captured frame takes exactly `TICKS_PER_FRAME` of them. Otherwise the
## rope falls in fast-forward between captures and the clip is a jump cut.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/film_bridge_cut.gd \
##     -- --stills=/private/tmp/bridge-cut-stills
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/film_bridge_cut.gd \
##     -- --stills=/private/tmp/bridge-cut-stills \
##        --clip=/private/tmp/bridge-cut-stills/fall --size=1280x800
##
## Never --headless: the fidelity scene hangs there. Never await
## `RenderingServer.frame_post_draw` either -- it never returns when the window
## is occluded -- so every capture forces its own draw.
const FRAME_SIZE := Vector2i(1600, 1000)
const FPS := 30
const TICKS_PER_FRAME := 2     ## 60 Hz physics into a 30 fps clip: real time.
const TOTAL_FRAMES := 330      ## 11 s: two whole, nine of falling and hanging.
## Seconds from the first frame.
const CUT_AT := 2.0
const BEFORE_STILL := 1.8      ## Late enough that the deck has settled.
const SWINGING_STILL := 3.0    ## One second after the cut, mid-fall.
const SETTLED_STILL := 10.8    ## Both halves hanging off their anchors.
## Where the near cut goes, as a t along the deck. Two links in on a 46 m span.
const NEAR_CUT := 0.08
## The shot. Further back and aimed lower than the weather film's: the halves
## end up half a span below the anchors, and a frame that holds the deck holds
## none of the fall.
const SHOT_DISTANCE := 62.0
const SHOT_POLAR := 1.30
const SHOT_YAW := 0.3
const SHOT_DROP := 9.0         ## Aim below the mid-deck, into the chasm.
const SHOT_HOUR := 11.0        ## The study opens near dusk; this wants the sun.
var scene: Node3D
var frame_size := FRAME_SIZE
var stills_dir := ""
var clip_dir := ""
var frames := TOTAL_FRAMES
var near_cut := false
var _stills: Dictionary = {}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(900).timeout.connect(func() -> void:
		print("FILM BRIDGE CUT: timed out")
		quit(2))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stills="): stills_dir = argument.trim_prefix("--stills=")
		elif argument.begins_with("--clip="): clip_dir = argument.trim_prefix("--clip=")
		elif argument.begins_with("--frames="): frames = maxi(2, int(argument.trim_prefix("--frames=")))
		elif argument == "--near": near_cut = true
		elif argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			frame_size = Vector2i(int(parts[0]), int(parts[1]))
	if stills_dir.is_empty() and clip_dir.is_empty():
		print("FILM BRIDGE CUT: pass --stills=<dir> and optionally --clip=<dir>")
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
	_daylight()
	_aim()
	print("FILM BRIDGE CUT shot: %s cut, camera (%.1f, %.1f, %.1f) on target (%.1f, %.1f, %.1f)" % [
		"near" if near_cut else "mid-span",
		scene.camera.global_position.x, scene.camera.global_position.y, scene.camera.global_position.z,
		scene.target.x, scene.target.y, scene.target.z])
	await _clip()
	print("FILM BRIDGE CUT done")
	scene.queue_free()
	await process_frame
	quit(0)

## The study opens near dusk, where a still of two dark islands says nothing.
func _daylight() -> void:
	scene._celestial.cycling = true
	scene.world_clock.set_time(0, SHOT_HOUR)
	_calm()
	# The sky eases toward a new hour rather than snapping to it, and sixty
	# driven steps leave it still most of the way back at dusk: the crossing
	# comes out a silhouette against mauve. Four seconds of them land the hour.
	for step in range(240):
		scene._process(1.0 / 60.0)

## Three-quarter on and below the mid-deck, set once and left there.
func _aim() -> void:
	scene.target = scene.deck_surface(0.5) - Vector3.UP * SHOT_DROP
	scene.distance = SHOT_DISTANCE
	scene.polar = SHOT_POLAR
	scene.yaw = SHOT_YAW
	scene._auto_orbit = false
	scene._update_camera()

## Dry, still and warm: a cut rope in a gale is two things happening at once.
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
	for where in [stills_dir, clip_dir]:
		if not where.is_empty(): DirAccess.make_dir_recursive_absolute(where)
	var cut := false
	var dt := 1.0 / float(FPS)
	for frame in range(frames):
		var clock := float(frame) * dt
		if clock >= CUT_AT and not cut:
			var took: bool = scene.cut_bridge(NEAR_CUT if near_cut else 0.5)
			cut = true
			var gap: Vector2 = scene.bridge.deck_gap()
			print("FILM BRIDGE CUT %.1f s: the rope parts, t %.3f to %.3f (%s)" % [clock, gap.x, gap.y, "cut" if took else "refused"])
		scene._process(dt)
		for tick in range(TICKS_PER_FRAME):
			await physics_frame
		_grab(frame)
	for label: String in _stills:
		print("FILM BRIDGE CUT still %s -> %s" % [label, _stills[label]])
	if not clip_dir.is_empty():
		print("FILM BRIDGE CUT clip: %d frames in %s" % [frames, clip_dir])
		print("ffmpeg -y -framerate %d -i %s/%%04d.png -c:v libx264 -pix_fmt yuv420p -crf 30 -vf scale=1280:-2 %s" % [
			FPS, clip_dir, clip_dir.path_join("fall.mp4")])

## Frames are picked by number, not by clock: at thirty a second the clock lands
## a hair under a round second and a comparison against it misses.
func _grab(frame: int) -> void:
	var wanted := ""
	for pick in [["cut_before", BEFORE_STILL], ["cut_swinging", SWINGING_STILL], ["cut_settled", SETTLED_STILL]]:
		if frame == int(round(float(pick[1]) * float(FPS))): wanted = String(pick[0])
	if wanted.is_empty() and clip_dir.is_empty(): return
	_hold_frame_size()
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null:
		print("FILM BRIDGE CUT: no image for frame ", frame)
		return
	if not clip_dir.is_empty(): image.save_png(clip_dir.path_join("%04d.png" % frame))
	if not wanted.is_empty() and not stills_dir.is_empty():
		var at := stills_dir.path_join("%s.png" % wanted)
		image.save_png(at)
		_stills[wanted] = at

## The project opens maximized and the window manager re-applies that a few
## frames after the window appears, which would resize images mid-shoot.
func _hold_frame_size() -> void:
	if root.size == frame_size: return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = frame_size
