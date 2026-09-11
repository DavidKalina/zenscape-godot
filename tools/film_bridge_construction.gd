extends SceneTree
## The bridge going up. Four stills of the same framing at nought, a quarter,
## half and all of the deck, then a fifth of somebody walking the finished
## thing, plus numbered frames of the build so the growth can be watched
## rather than inferred.
##
## The point of shooting all five from one camera is that the only thing that
## changes between them is the deck. `frame_bridge()` is the study's own `B`
## framing, back along the whole span from beyond the far anchor, so the ropes
## fill the frame whether or not there are boards on them.
##
## `--stills=<dir>` writes `built_000.png`, `built_025.png`, `built_050.png`,
## `built_100.png` and `crossing.png`; defaults to
## `/private/tmp/bridge-construction-stills`. `--frames=<dir>` writes the
## numbered growth frames (default `frames/` inside the stills directory) and
## prints the ffmpeg line; `--steps=<n>` is how many of them, spread evenly over
## the plank count. `--size=WxH` sets the frame.
##
## Never --headless: the fidelity scene hangs there. Never await
## `RenderingServer.frame_post_draw` either -- it never returns when the window
## is occluded -- so every capture forces its own draw.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/film_bridge_construction.gd \
##     -- --stills=/private/tmp/bridge-construction-stills
const DT := 1.0 / 60.0
const FRAME_SIZE := Vector2i(1600, 1000)
const SHOT_HOUR := 11.0        ## Late morning: the sun clears both islands' peaks.
const SETTLE_FRAMES := 6
## Driven steps for the sky to catch up with a jumped hour. The rig eases; one
## second of them is not enough from a dusk start.
const DAYLIGHT_STEPS := 240
const BUILD_STEPS := 60        ## Growth frames; 2 s at 30 fps.
const CAPTURE_FPS := 30
## Simulated frames between growth captures, so the rope settles onto each new
## load rather than snapping between poses.
const GROWTH_SETTLE := 10
const CROSS_FRAMES := 20000    ## A crossing is ~50 m at about a metre a second.
const CROSS_AT := 0.5          ## Where along the deck the crossing still is taken.
const CROSS_TRIES := 15        ## Asks, two simulated seconds apart, before giving up.
var scene: Node3D
var frame_size := FRAME_SIZE
var stills_dir := "/private/tmp/bridge-construction-stills"
var frames_dir := ""
var steps := BUILD_STEPS

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(1500).timeout.connect(func() -> void:
		print("FILM BRIDGE CONSTRUCTION: timed out")
		quit(2))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stills="): stills_dir = argument.trim_prefix("--stills=")
		elif argument.begins_with("--frames="): frames_dir = argument.trim_prefix("--frames=")
		elif argument.begins_with("--steps="): steps = maxi(2, int(argument.trim_prefix("--steps=")))
		elif argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			frame_size = Vector2i(int(parts[0]), int(parts[1]))
	if frames_dir.is_empty(): frames_dir = stills_dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(stills_dir)
	DirAccess.make_dir_recursive_absolute(frames_dir)
	_hold_frame_size()
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	# The tool owns the clock: the study's own _process would drift the weather,
	# ease the camera, and build the bridge underneath the shot.
	scene.set_process(false)
	scene._ui.visible = false
	if "_study_ui" in scene: scene._study_ui.visible = false
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	await scene.rebuild_second_chunk()
	_daylight()
	var bridge: Node3D = scene.bridge
	if bridge == null or not bridge.has_method("is_complete"):
		print("FILM BRIDGE CONSTRUCTION: the study has no buildable bridge")
		quit(1)
		return
	var slots: int = bridge.plank_count()
	print("FILM BRIDGE CONSTRUCTION: %d plank slots over %.1f m" % [slots, scene.crossing.span() if scene.crossing != null else 0.0])
	# ------------------------------------------------------------ the stills
	for share: int in [0, 25, 50, 100]:
		scene.set_bridge_built(false)
		bridge.set_laid(int(round(float(slots) * float(share) / 100.0)))
		await _settle(0.8)
		# The framing and the hour are re-applied per shot: a settle is a second
		# of the study's own process, which eases the camera and turns the sky.
		_daylight()
		scene.frame_bridge()
		await _grab(stills_dir.path_join("built_%03d.png" % share), "%d%% (%d/%d planks, extent t %.3f)" % [share, bridge.laid_count(), slots, bridge.built_extent()])

	# ------------------------------------------------------- the growth frames
	scene.set_bridge_built(false)
	await _settle(0.6)
	_daylight()
	scene.frame_bridge()
	for step in range(steps):
		bridge.set_laid(int(round(float(slots) * float(step + 1) / float(steps))))
		for tick in range(GROWTH_SETTLE):
			scene._process(DT)
			if tick % 4 == 0: await process_frame
		await _grab(frames_dir.path_join("%04d.png" % step), "")
	print("FILM BRIDGE CONSTRUCTION build: %d frames in %s" % [steps, frames_dir])
	print("ffmpeg -y -framerate %d -i %s/%%04d.png -c:v libx264 -pix_fmt yuv420p -crf 28 %s" % [
		CAPTURE_FPS, frames_dir, stills_dir.path_join("construction.mp4")])

	# ---------------------------------------------------------- the crossing
	# The whole point of finishing it. Sent with the study's own key, so what is
	# filmed is the feature: before the last plank this call refuses.
	scene.set_bridge_built(true)
	await _settle(1.0)
	# He may be part way through something of his own; ask again for a while
	# rather than declaring the crossing unfilmable on the first no.
	var sent := false
	for attempt in range(CROSS_TRIES):
		sent = scene.send_bigfoot_across()
		if sent: break
		await _settle(2.0)
	if not sent:
		print("FILM BRIDGE CONSTRUCTION: nobody would cross the finished bridge")
	else:
		var camps: Node = scene.island_camps
		var taken := false
		for frame in range(CROSS_FRAMES):
			scene._process(DT)
			if frame % 30 == 0: await process_frame
			var walk: CrossingWalk = camps.bigfoot_walk
			if walk == null:
				if taken: break
				continue
			if not walk.on_deck(): continue
			if absf(scene.crossing.deck_t_at(scene.creature.global_position) - CROSS_AT) > 0.04: continue
			taken = true
			await _grab(stills_dir.path_join("crossing.png"), "a walker on the finished deck")
			break
		if not taken: print("FILM BRIDGE CONSTRUCTION: he never reached midspan")
	print("FILM BRIDGE CONSTRUCTION done: %s" % stills_dir)
	scene.queue_free()
	await process_frame
	quit(0)

## The study opens near dusk, where a still of two dark islands says nothing.
func _daylight() -> void:
	scene._celestial.cycling = true
	scene.world_clock.set_time(0, SHOT_HOUR)
	for step in range(DAYLIGHT_STEPS):
		scene._process(DT)

## Let the rope hang onto its new load before the shutter.
func _settle(seconds: float) -> void:
	for step in range(int(seconds * 60.0)):
		scene._process(DT)
		if step % 6 == 0: await process_frame

func _grab(path: String, label: String) -> void:
	for step in range(SETTLE_FRAMES):
		scene._process(DT)
	for step in range(3):
		_hold_frame_size()
		await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null:
		print("FILM BRIDGE CONSTRUCTION: no image for ", path)
		return
	image.save_png(path)
	if not label.is_empty():
		print("FILM BRIDGE CONSTRUCTION still %s -> %s" % [label, path])

## The project opens maximized and the window manager re-applies that a few
## frames after the window appears, which would resize images mid-shoot.
func _hold_frame_size() -> void:
	if root.size == frame_size: return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = frame_size
