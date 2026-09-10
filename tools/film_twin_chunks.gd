extends SceneTree
## Look at the twin-chunk prototype: three stills that answer whether a second
## island across an 8 m gap reads as a world, and a walk along the bridge deck,
## because the question is about motion as much as composition.
##
## `--stills=<dir>` writes `wide.png` (the startup framing, both islands and the
## chasm), `bridge.png` (the study's `B` framing, back along the whole span),
## `chasm.png` (its `N` framing, stood on the deck sighting the far bridgehead),
## `void.png` (its `M` framing, held beside the mid-deck over the drop) and
## `far_island.png` (the copy's own centre at 30 m, from the side). `--size=WxH`
## sets the frame; stills default to 1600x1000 and a long walk is worth
## dropping to 1280x800 to keep the encode small.
##
## `--walk=<dir> --frames=480` carries the camera target along the sagging deck
## itself -- `deck_point()`, not the straight chord, so it never floats off the
## planks at midspan -- at `WALK_HEIGHT` above the boards, low polar, yaw down
## the deck, as numbered PNGs; it prints the ffmpeg line to encode them.
##
## The study builds its copy inside `_ready()`, but authored content and
## landmarks publish asynchronously, so this waits for `_chunk_editor.forming`
## and `refresh_pending` to drain and calls `rebuild_second_chunk()` before
## shooting -- the same wait `tools/film_dead_wood.gd` does.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/film_twin_chunks.gd \
##     -- --stills=/private/tmp/twin-chunks-100
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/film_twin_chunks.gd \
##     -- --walk=/private/tmp/twin-chunks-100/walk --frames=480 --size=1280x800
##
## Never --headless: the fidelity scene hangs there. Never await
## `RenderingServer.frame_post_draw` either -- it never returns when the window
## is occluded -- so every capture forces its own draw.
const FRAME_SIZE := Vector2i(1600, 1000)
const WALK_SECONDS := 16.0    ## How long the crossing should take to watch.
const DT := 1.0 / 60.0
const FAR_DISTANCE := 30.0    ## Close enough that the copy reads as a whole island.
const FAR_POLAR := 1.15
const WALK_FRAMES := 480      ## 16 s at 30 fps: 100 m should feel like 100 m.
const WALK_HEIGHT := 1.6      ## Eye height over the deck.
const WALK_DISTANCE := 3.6    ## A following shot, not a first-person one.
const WALK_POLAR := 1.48      ## Nearly level with the deck.
const WALK_FPS := 30
## A little run-up and run-out past the anchors, so the clip starts and ends on
## solid ground rather than snapping onto the deck. Small, because at 100 m the
## span carries the clip on its own and a forest run-up only wastes frames.
const WALK_OVERSHOOT := 0.025
const SETTLE_FRAMES := 6      ## Driven steps after a pose so grass and sky agree.
const SHOT_HOUR := 11.0       ## Late morning: the sun clears both islands' peaks.
var scene: Node3D
var frame_size := FRAME_SIZE
var stills_dir := ""
var walk_dir := ""
var walk_frames := WALK_FRAMES

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(900).timeout.connect(func() -> void:
		print("FILM TWIN CHUNKS: timed out")
		quit(2))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stills="): stills_dir = argument.trim_prefix("--stills=")
		elif argument.begins_with("--walk="): walk_dir = argument.trim_prefix("--walk=")
		elif argument.begins_with("--frames="): walk_frames = maxi(2, int(argument.trim_prefix("--frames=")))
		elif argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			frame_size = Vector2i(int(parts[0]), int(parts[1]))
	if stills_dir.is_empty() and walk_dir.is_empty():
		print("FILM TWIN CHUNKS: pass --stills=<dir> or --walk=<dir>")
		quit(1)
		return
	_hold_frame_size()
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	# The tool owns the clock: the study's own _process would drift the weather
	# and ease the camera between a pose and its capture.
	scene.set_process(false)
	scene._ui.visible = false
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	scene.rebuild_second_chunk()
	_daylight()
	print("FILM TWIN CHUNKS world formed: %d visual instances on the copy" % scene.visual_instance_count())
	if not stills_dir.is_empty(): await _stills()
	if not walk_dir.is_empty(): await _walk()
	print("FILM TWIN CHUNKS done")
	scene.queue_free()
	await process_frame
	quit(0)

## The study opens near dusk, where a still of two dark islands says nothing
## about whether they read as one world. Put the sun overhead and let the rig
## catch up before anything is shot.
func _daylight() -> void:
	scene._celestial.cycling = true
	scene.world_clock.set_time(0, SHOT_HOUR)
	for step in range(60):
		scene._process(DT)

func _stills() -> void:
	DirAccess.make_dir_recursive_absolute(stills_dir)
	scene._frame_wide()
	await _grab(stills_dir.path_join("wide.png"), "wide")
	scene.frame_bridge()
	await _grab(stills_dir.path_join("bridge.png"), "bridge")
	scene.frame_chasm()
	await _grab(stills_dir.path_join("chasm.png"), "chasm")
	scene.frame_void()
	await _grab(stills_dir.path_join("void.png"), "void")
	# The copy from the side, at its own centre, lifted to roughly its skyline.
	scene.target = scene.second_chunk_centre() + Vector3.UP * 2.0
	scene.distance = FAR_DISTANCE
	scene.polar = FAR_POLAR
	scene.yaw = 0.0
	scene._update_camera()
	await _grab(stills_dir.path_join("far_island.png"), "far_island")

## The crossing on foot: the target slides from anchor to anchor while the camera
## trails it down the deck line.
func _walk() -> void:
	DirAccess.make_dir_recursive_absolute(walk_dir)
	var anchors: Array[Transform3D] = scene.bridge_anchors()
	if anchors.size() != 2:
		print("FILM TWIN CHUNKS: no anchors to walk between")
		return
	var direction := (anchors[1].origin - anchors[0].origin).normalized()
	scene.distance = WALK_DISTANCE
	scene.polar = WALK_POLAR
	scene.yaw = atan2(-direction.x, -direction.z)
	for frame in range(walk_frames):
		var along := lerpf(-WALK_OVERSHOOT, 1.0 + WALK_OVERSHOOT, float(frame) / float(walk_frames - 1))
		# `deck_point` extrapolates sensibly past either end, so the run-up and
		# run-out stay on the line the deck arrives at.
		scene.target = scene.deck_point(along) + Vector3.UP * WALK_HEIGHT
		scene._update_camera()
		await _grab(walk_dir.path_join("%04d.png" % frame), "")
	print("FILM TWIN CHUNKS walk: %d frames in %s" % [walk_frames, walk_dir])
	print("ffmpeg -y -framerate %d -i %s/%%04d.png -c:v libx264 -pix_fmt yuv420p -crf 28 %s" % [
		WALK_FPS, walk_dir, walk_dir.get_base_dir().path_join("walk.mp4")])

func _grab(path: String, label: String) -> void:
	# Driven steps rather than idle ones: the study's _process is off, so grass,
	# water and sky only advance because this asks them to.
	for step in range(SETTLE_FRAMES):
		scene._process(DT)
	for step in range(3):
		_hold_frame_size()
		await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null:
		print("FILM TWIN CHUNKS: no image for ", path)
		return
	image.save_png(path)
	if not label.is_empty():
		print("FILM TWIN CHUNKS still %s: target (%.2f, %.2f, %.2f), %.1f m, polar %.2f, yaw %.3f -> %s" % [
			label, scene.target.x, scene.target.y, scene.target.z,
			scene.distance, scene.polar, scene.yaw, path])

## The project opens maximized and the window manager re-applies that a few
## frames after the window appears, which would resize images mid-shoot.
func _hold_frame_size() -> void:
	if root.size == frame_size: return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = frame_size
