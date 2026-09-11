extends SceneTree
## Bigfoot on the bridge: a still of him mid-deck and, optionally, the clip.
##
## Builds the twin-chunk study, sends him across with the study's own `X` (so
## what is filmed is the feature and not a camera trick), then follows him. The
## camera trails his actual position rather than sliding down the deck curve --
## the whole question a crossing clip answers is whether a walker and a rope
## bridge look like they belong to each other.
##
## `--frames=<dir>` writes numbered PNGs of the deck crossing and prints the
## ffmpeg line. `--still=<path>` writes one frame from midspan; both default on,
## to `/private/tmp/bridge-crossing-frames` and `crossing.png` inside it.
## `--stride=<n>` is simulated frames per captured frame (6 is about a quarter
## speed at 30 fps, which is what a slow walk over fifty metres wants).
## `--size=WxH` sets the frame.
##
## Never --headless: the fidelity scene hangs there. Never await
## `RenderingServer.frame_post_draw` either -- it never returns when the window
## is occluded -- so every capture forces its own draw.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/film_bridge_crossing.gd \
##     -- --frames=/private/tmp/bridge-crossing-frames
const DT := 1.0 / 60.0
const FRAME_SIZE := Vector2i(1600, 1000)
const SHOT_HOUR := 11.0        ## Late morning: the sun clears both islands' peaks.
const SETTLE_FRAMES := 6
const FOLLOW_DISTANCE := 8.0   ## Far enough back that the ropes and the drop fit.
const FOLLOW_POLAR := 1.40
const FOLLOW_HEIGHT := 1.9
const STILL_AT := 0.5          ## Where along the deck the still is taken.
const CAPTURE_FPS := 30
const MAX_SIM_FRAMES := 30000  ## Two crossings' worth; he is walking, not waiting.
var scene: Node3D
var frame_size := FRAME_SIZE
var frames_dir := "/private/tmp/bridge-crossing-frames"
var still_path := ""
var stride := 6
var clip := true

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(1200).timeout.connect(func() -> void:
		print("FILM BRIDGE CROSSING: timed out")
		quit(2))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--frames="): frames_dir = argument.trim_prefix("--frames=")
		elif argument.begins_with("--still="): still_path = argument.trim_prefix("--still=")
		elif argument.begins_with("--stride="): stride = maxi(1, int(argument.trim_prefix("--stride=")))
		elif argument == "--no-clip": clip = false
		elif argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			frame_size = Vector2i(int(parts[0]), int(parts[1]))
	if still_path.is_empty(): still_path = frames_dir.path_join("crossing.png")
	DirAccess.make_dir_recursive_absolute(frames_dir)
	_hold_frame_size()
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._ui.visible = false
	if "_study_ui" in scene: scene._study_ui.visible = false
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	await scene.rebuild_second_chunk()
	# The study now opens with the bridge unbuilt; these want the finished deck.
	scene.set_bridge_built(true)
	_daylight()
	var camps: Node = scene.island_camps
	if camps == null or scene.crossing == null:
		print("FILM BRIDGE CROSSING: no camp and no crossing to film")
		quit(1)
		return
	if not scene.send_bigfoot_across():
		print("FILM BRIDGE CROSSING: he would not set out")
		quit(1)
		return
	print("FILM BRIDGE CROSSING: %.1f m of deck, following him across" % scene.crossing.span())
	var captured := 0
	var still_taken := false
	var since := 0
	for frame in range(MAX_SIM_FRAMES):
		scene._process(DT)
		since += 1
		if frame % 30 == 0:
			await process_frame  ## Let the rope tick; the deck is physics.
		var walk: CrossingWalk = camps.bigfoot_walk
		if walk == null:
			if captured > 0 or still_taken: break
			continue
		if not walk.on_deck():
			continue
		var along: float = scene.crossing.deck_t_at(scene.creature.global_position)
		if not still_taken and absf(along - STILL_AT) < 0.03:
			still_taken = true
			_aim()
			await _grab(still_path, "midspan")
		if not clip or since < stride:
			continue
		since = 0
		_aim()
		await _grab(frames_dir.path_join("%04d.png" % captured), "")
		captured += 1
	print("FILM BRIDGE CROSSING: %s" % ("he never reached the boards" if captured == 0 and not still_taken else "%d frames in %s" % [captured, frames_dir]))
	if captured > 1:
		print("ffmpeg -y -framerate %d -i %s/%%04d.png -c:v libx264 -pix_fmt yuv420p -crf 28 %s" % [
			CAPTURE_FPS, frames_dir, frames_dir.path_join("crossing.mp4")])
	scene.queue_free()
	await process_frame
	quit(0)

## Over his shoulder, down the span. The yaw follows the direction he is walking
## so the shot turns round with him when he comes back.
func _aim() -> void:
	var anchors: Array[Transform3D] = scene.bridge_anchors()
	var walk: CrossingWalk = scene.island_camps.bigfoot_walk
	var heading: Vector3 = (walk.target() - scene.creature.global_position) if walk != null else (anchors[1].origin - anchors[0].origin)
	if heading.length() < 0.01: heading = anchors[1].origin - anchors[0].origin
	heading = heading.normalized()
	scene.target = scene.creature.global_position + Vector3.UP * FOLLOW_HEIGHT
	scene.distance = FOLLOW_DISTANCE
	scene.polar = FOLLOW_POLAR
	scene.yaw = atan2(-heading.x, -heading.z)
	scene._update_camera()

## The study opens near dusk and a crossing takes two minutes of world time, so
## the hour is set once and then the clock is stopped: a clip that walks into
## the evening says nothing about the bridge.
func _daylight() -> void:
	scene._celestial.cycling = true
	scene.world_clock.set_time(0, SHOT_HOUR)
	for step in range(90):
		scene._process(DT)
	scene._celestial.cycling = false
	print("FILM BRIDGE CROSSING: hour %.1f, daylight %.2f" % [SHOT_HOUR, scene._celestial.daylight])

func _grab(path: String, label: String) -> void:
	for step in range(SETTLE_FRAMES):
		scene._process(DT)
	for step in range(3):
		_hold_frame_size()
		await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null:
		print("FILM BRIDGE CROSSING: no image for ", path)
		return
	image.save_png(path)
	if not label.is_empty():
		print("FILM BRIDGE CROSSING still %s: he is at (%.2f, %.2f, %.2f) -> %s" % [
			label, scene.creature.global_position.x, scene.creature.global_position.y,
			scene.creature.global_position.z, path])

func _hold_frame_size() -> void:
	if root.size == frame_size: return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = frame_size
