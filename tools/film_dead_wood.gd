extends SceneTree
## Evidence that slice 3 is really in the world: a storm strips the canopy of the
## living-world study, the branches lie on the actual terrain under its trees,
## and the resident walks out to one, picks it up and carries it into his cave.
##
## The study family that owns dead wood is `studies/bigfoot_living_world.tscn`
## (through `studies/fidelity_life.gd`, which builds `dead_wood`). The plain
## `studies/fidelity.tscn` has no resident and no forest floor, so nothing falls
## there no matter how long the sky rages -- that is why scrubbing the ordinary
## world never showed a branch.
##
## Branches are small on purpose: a 0.9 m stick of 5 cm radius with a forked
## twig. Read from the study's default 43 m establishing camera they are a few
## pixels, so the stills here put the camera 2 m away and a metre off the ground.
##
## Two phases, either of which can be run alone:
##   --stills  storm the world until several branches lie about, then take one
##             close-up per branch. `--shot=index:distance:polar:yaw-offset`
##             (repeatable) overrides the automatic aim, which stands the camera
##             on the far side of the branch from its tree.
##   --film    plant a branch a short walk from his door, let the mind choose,
##             and record the errand as numbered frames for ffmpeg. The clip opens
##             held on the wood; `--open=distance:polar:yaw-offset` re-aims that
##             opening, `--frames=` and `--substeps=` set its length and pace.
##
## Nothing here touches the branch meshes, the drop rates or the scores. It only
## drives the clock, the sky and the camera, so what it shows is what a player
## sees; the two tuned constants are which drop sites to point at and how.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/film_dead_wood.gd \
##     -- --stills --film
##   ffmpeg -y -framerate 30 -i /private/tmp/zenscape-deadwood-frames/%04d.jpg \
##     -c:v libx264 -pix_fmt yuv420p -crf 26 -vf scale=960:-2 \
##     /private/tmp/zenscape-deadwood.mp4
##
## Never --headless: the study loads a scene and headless hangs. Never
## `await RenderingServer.frame_post_draw` either; it never returns when the
## window is occluded, so every capture forces the draw itself.

const FRAME_SIZE := Vector2i(1280, 800)
const DT := 1.0 / 30.0
const STILL_PREFIX := "/private/tmp/zenscape-deadwood-"
const FILM_DIR := "/private/tmp/zenscape-deadwood-frames"
const STORM_SPEED := 48.0    ## World-clock multiplier while the canopy is stripped: 10 real s a world day.
const WANTED_BRANCHES := 6   ## Enough litter that a close-up has a choice of subjects.
const STORM_LIMIT := 90.0    ## Real seconds of storm before giving up on more wood.
const STILL_DISTANCE := 2.2
const STILL_POLAR := 1.2
const FILM_FRAMES := 540     ## 18 s at 30 fps.
const SUBSTEPS := 2          ## Simulation steps per recorded frame; the errand at double speed.
const SMOOTH := 0.12         ## Camera easing per recorded frame.
const SHOT_HOUR := 12.0      ## Midday after the storm: the sun is high enough to light the forest floor.
const POSE_INTERVAL := 5     ## Recorded frames between two runs of the study's angle search.
const OPENING_FRAMES := 36   ## The clip opens held on the wood before it cuts to the follow shot.
const OPENING_DISTANCE := 2.6
const OPENING_POLAR := 0.85
## A quarter turn off the automatic aim: the drop site by his door has a bank of
## flowers on the tree side, and this looks across the branch from the open grass
## instead of through them. `--open=` overrides all three.
const OPENING_YAW := -1.6
## Branch, camera distance, elevation and yaw offset for the default close-ups.
## Chosen by looking at the results: the storm's other drop sites are on a bare
## slope, inside a thicket or under the lip of a ridge.
const DEFAULT_SHOTS := [[0, 2.2, 1.2, 0.0], [2, 2.2, 1.2, 0.0], [3, 2.2, 1.05, 0.0]]
const SITE_SPACING := 1.1    ## dead_wood.gd's own spacing: nearer than this is the same drop site.

var scene: Node3D
var clock: WorldClock
var living: RefCounted
var wood: Node
var want_stills := false
var want_film := false
var film_frames := FILM_FRAMES
var substeps := SUBSTEPS
var shots: Array = []        ## [{index, distance, polar, yaw}]
var opening: Dictionary = {} ## Overrides the opening pose on the branch he is sent for.
var _view_target := Vector3.ZERO
var _view_distance := 8.0
var _view_yaw := 0.0
var _view_polar := 1.0
var _pose_yaw := 0.0
var _pose_polar := 1.0
var _pose_age := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(900).timeout.connect(func() -> void:
		print("FILM DEAD WOOD timed out")
		quit(2))
	for argument in OS.get_cmdline_user_args():
		if argument == "--stills": want_stills = true
		elif argument == "--film": want_film = true
		elif argument.begins_with("--frames="): film_frames = int(argument.trim_prefix("--frames="))
		elif argument.begins_with("--substeps="): substeps = maxi(1, int(argument.trim_prefix("--substeps=")))
		elif argument.begins_with("--open="):
			var open := argument.trim_prefix("--open=").split(":")
			opening = {"distance": float(open[0]), "polar": float(open[1]), "yaw": float(open[2]) if open.size() > 2 else 0.0}
		elif argument.begins_with("--shot="):
			var parts := argument.trim_prefix("--shot=").split(":")
			shots.append({
				"index": int(parts[0]),
				"distance": float(parts[1]) if parts.size() > 1 else STILL_DISTANCE,
				"polar": float(parts[2]) if parts.size() > 2 else STILL_POLAR,
				"yaw": float(parts[3]) if parts.size() > 3 else 0.0})
	if not want_stills and not want_film:
		want_stills = true
		want_film = true

	_hold_frame_size()
	scene = load("res://studies/bigfoot_living_world.tscn").instantiate()
	root.add_child(scene)
	# The tool owns the clock: the study's own _process would run the world at
	# play pace while we are waiting on the storm.
	scene.set_process(false)
	_hide_study_ui()
	scene._paused = false
	# A grown world, instantly: the resident is hidden and dead wood's sites are
	# unusable until terrain growth finishes.
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.replaying = false
	scene._growth.publish()
	living = scene.routine.living
	wood = scene.dead_wood
	clock = scene.world_clock
	if wood == null or clock == null:
		print("FILM DEAD WOOD: the study has no forest floor")
		quit(1)
		return
	print("FILM DEAD WOOD sites under trees: ", wood.sites.size())
	scene._celestial.cycling = true
	clock.set_time(0, 10.0)
	await _storm()
	_report_branches()
	if want_stills: await _stills()
	if want_film: await _film()
	print("FILM DEAD WOOD done")
	scene.queue_free()
	await process_frame
	quit(0)

## The study's panels, its status column and the thoughts readout all off, so a
## still is nothing but forest floor.
func _hide_study_ui() -> void:
	scene._ui.visible = false
	var study: Variant = scene.get("_study_ui")
	if study != null: study.visible = false
	var status: Variant = scene.get("_life_status")
	if status != null and status.get_parent() != null: status.get_parent().visible = false

## The project opens maximized and the window manager re-applies that a few
## frames after the window appears, which would resize the images mid-film.
func _hold_frame_size() -> void:
	if root.size == FRAME_SIZE: return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = FRAME_SIZE

## One driven simulation step with the resident's own decisions suppressed, so
## the fast-forward is weather only and he never wanders through the shot.
func _quiet_step(seconds: float) -> void:
	scene.routine._next_action = INF
	scene._process(seconds)

## Storm the canopy at 48x until enough wood is down, then clear the sky and stop
## the clock so nothing rots or moves while the camera works.
func _storm() -> void:
	living.enabled = false
	scene.routine.cancel("film_dead_wood fast-forwards the weather")
	clock.speed = STORM_SPEED
	clock.running = true
	scene._precipitation.set_weather(WeatherScheduler.preset_index("storm"), true)
	var real := 0.0
	while wood.count() < WANTED_BRANCHES and real < STORM_LIMIT:
		for step in range(30):
			_quiet_step(DT)
			real += DT
		await process_frame
	print("FILM DEAD WOOD storm: %.1f s of 48x weather, %d branches down, %.2f world days" % [
		real, wood.count(), clock.elapsed / WorldClock.SECONDS_PER_DAY])
	scene._precipitation.set_weather(WeatherScheduler.preset_index("clear"), true)
	clock.set_time(0, SHOT_HOUR)
	clock.speed = 1.0
	# Ten driven seconds of fair weather: long enough for the storm's cloud, its
	# rain and its wet ground to ease out before anything is shot.
	for step in range(300):
		_quiet_step(DT)
	await process_frame

func _trees() -> Array:
	var result: Array = []
	for item: Dictionary in scene.habitat.interests:
		if wood._is_tree(item): result.append(item)
	return result

func _nearest_tree(point: Vector3) -> Variant:
	var best: Variant = null
	var best_range := INF
	for item: Dictionary in _trees():
		var reach: float = Vector2(item.position.x - point.x, item.position.z - point.z).length()
		if reach < best_range:
			best_range = reach
			best = item
	return best

func _report_branches() -> void:
	print("FILM DEAD WOOD branches on the ground: ", wood.count())
	for index in range(wood.branches.size()):
		var branch: Dictionary = wood.branches[index]
		var point: Vector3 = branch.position
		var tree: Variant = _nearest_tree(point)
		var reach := 0.0
		if tree != null: reach = Vector2(tree.position.x - point.x, tree.position.z - point.z).length()
		print("  [%d] %s at (%.2f, %.2f, %.2f) age %.2f d, nearest tree %.2f m away" % [
			index, branch.id, point.x, point.y, point.z, branch.age, reach])

## The camera stands on the far side of the branch from its tree, so the trunk
## it fell out of is behind it in frame.
func _auto_yaw(point: Vector3) -> float:
	var tree: Variant = _nearest_tree(point)
	if tree == null: return 0.0
	var away := Vector2(point.x - tree.position.x, point.z - tree.position.z)
	if away.length() < 0.01: return 0.0
	return atan2(away.x, away.y)

func _stills() -> void:
	var plan: Array = shots
	if plan.is_empty():
		for entry: Array in DEFAULT_SHOTS:
			plan.append({"index": int(entry[0]), "distance": float(entry[1]), "polar": float(entry[2]), "yaw": float(entry[3])})
	var shot := 0
	for entry: Dictionary in plan:
		var index: int = entry.index
		if index < 0 or index >= wood.branches.size(): continue
		shot += 1
		var branch: Dictionary = wood.branches[index]
		var point: Vector3 = branch.position
		scene.target = point + Vector3.UP * 0.18
		scene.distance = float(entry.distance)
		scene.polar = float(entry.polar)
		scene.yaw = _auto_yaw(point) + float(entry.yaw)
		scene._update_camera()
		# A few driven steps so grass, sky and the branch material match the pose.
		for step in range(6):
			_quiet_step(DT)
		var path := "%s%d.png" % [STILL_PREFIX, shot]
		await _grab(path)
		print("FILM DEAD WOOD still %s: %s at (%.2f, %.2f, %.2f), camera %.2f m, polar %.2f, yaw %.3f" % [
			path, branch.id, point.x, point.y, point.z, scene.distance, scene.polar, scene.yaw])

func _grab(path: String) -> void:
	for step in range(3):
		_hold_frame_size()
		await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null:
		print("FILM DEAD WOOD: no image for ", path)
		return
	image.save_png(path)

## A branch on real walkable ground a short walk from his door, with him standing
## at the door, exactly the way tests/test_dead_wood_scene.gd stages the errand.
## Returns the branch target, or {}.
func _plant_near_home() -> Dictionary:
	scene.routine.cancel("film_dead_wood stages the errand")
	var route: Dictionary = scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0])
	if route.is_empty(): return {}
	var entrance: Vector3 = route.entrance
	var near: Array[Vector3] = wood.sites.duplicate()
	near.sort_custom(func(a: Vector3, b: Vector3) -> bool: return entrance.distance_to(a) < entrance.distance_to(b))
	for site: Vector3 in near:
		if entrance.distance_to(site) > 12.0 or not scene.navigation.is_safe(site): continue
		scene.creature.reset_at(entrance)
		var path: PackedVector3Array = scene.brain._approach_route(site)
		if path.is_empty() or not scene.routine._rest_stance(path[-1]): continue
		for existing: Dictionary in wood.branches:
			if Vector3(existing.position).distance_to(site) < SITE_SPACING:
				return {"id": str(existing.id), "position": Vector3(existing.position), "kind": "branch"}
		var branch: Dictionary = wood._add_branch(site, 0.0)
		return {"id": str(branch.id), "position": site, "kind": "branch"}
	return {}

func _film() -> void:
	DirAccess.make_dir_recursive_absolute(FILM_DIR)
	for stale in DirAccess.get_files_at(FILM_DIR):
		DirAccess.remove_absolute(FILM_DIR.path_join(stale))
	# A bare bed is what makes wood worth fetching, and a clear sky keeps the
	# storm penalty out of the gather score.
	scene.lair.restore_living({"bed_stage": 0, "play_stage": 0})
	scene.lair.restore_stash([])
	clock.speed = 1.0
	clock.running = true
	var target := _plant_near_home()
	if target.is_empty():
		print("FILM DEAD WOOD: no reachable branch site near his door")
		return
	living._remember_home()
	living.enabled = true
	living.mind.cooldowns.clear()
	living.mind.hunger = 0.0
	living.mind.fatigue = 0.0
	living.mind.enrichment = 0.3
	living.mind.disturbance_position = null
	scene.routine._cooldowns.clear()
	scene.routine._next_action = scene.routine._clock
	var context: Dictionary = living._context()
	print("FILM DEAD WOOD context: branches_nearby=", context.get("branches_nearby"), " can_gather=", context.get("can_gather"))
	for option: Dictionary in living.mind.ranked(context):
		print("  score %.2f %s - %s" % [option.score, option.kind, option.reason])
	var chose: bool = living.choose()
	print("FILM DEAD WOOD mind chose: ", living.current, " (", living.reason, ")" if chose else " nothing")
	if living.current != "gather":
		scene.routine.cancel("film_dead_wood insists on the gather")
		var asked: bool = living.request("gather", target)
		print("FILM DEAD WOOD invited the gather directly: ", asked)
		if not asked: return

	var branch_id := str(target.id)
	var branch_point: Vector3 = target.position
	# A clear view of the cave mouth, taken now while he is still standing in it.
	# The carry home ends by walking into rock, and a camera that keeps following
	# him goes in with him; this shot stays outside and watches him disappear.
	scene.frame_creature(9.5, scene.creature.rotation.y - 0.65)
	var doorway := {"target": scene.target, "distance": scene.distance, "yaw": scene.yaw, "polar": scene.polar}
	# Open on the wood itself, so the clip says what it is about before he is
	# anywhere near it. A little higher and further back than a still: the
	# flowers around a drop site hide a branch seen from ground level.
	_view_target = branch_point + Vector3.UP * 0.18
	_view_distance = float(opening.get("distance", OPENING_DISTANCE))
	_view_polar = float(opening.get("polar", OPENING_POLAR))
	_view_yaw = _auto_yaw(branch_point) + float(opening.get("yaw", OPENING_YAW))
	print("FILM DEAD WOOD opening on %s at (%.2f, %.2f, %.2f), camera %.2f m, polar %.2f, yaw %.3f" % [
		branch_id, branch_point.x, branch_point.y, branch_point.z, _view_distance, _view_polar, _view_yaw])
	scene.target = _view_target
	scene.distance = _view_distance
	scene.polar = _view_polar
	scene.yaw = _view_yaw
	scene._update_camera()
	var carried := false
	var delivered := -1
	# One drawn frame before the loop: the first read-back otherwise returns the
	# picture that was on screen before the camera moved.
	RenderingServer.force_draw(false)
	for frame in range(film_frames):
		_hold_frame_size()
		var focus := branch_point
		if wood.targets().filter(func(item: Dictionary) -> bool: return str(item.id) == branch_id).is_empty():
			carried = true
			focus = scene.creature.global_position + scene.creature.global_transform.basis.z * -3.0
		# A straight cut out of the opening rather than a sweep: easing from two
		# metres to a following shot drags the camera through the hillside.
		if frame < OPENING_FRAMES: scene._update_camera()
		elif not scene.routine.cave.phase.is_empty(): _hold(doorway)
		else: _aim(focus, frame == OPENING_FRAMES)
		for step in range(substeps):
			scene._process(DT)
		RenderingServer.force_draw(false)
		var image := root.get_texture().get_image()
		if image != null: image.save_jpg(FILM_DIR.path_join("%04d.jpg" % frame), 0.92)
		if frame % 30 == 0:
			print("FILM DEAD WOOD frame %d: current=%s phase=%s routine=%s cave=%s wood=%d carried=%s" % [
				frame, living.current, living.phase, scene.routine.active, scene.routine.cave.phase, wood.count(), carried])
		if delivered < 0 and ("gather" in living.completed_actions or "branch" in scene.routine.history):
			delivered = frame
			print("FILM DEAD WOOD the branch crossed his threshold at frame ", frame)
		# A second of held picture after the delivery, then stop.
		if delivered >= 0 and frame >= delivered + 30: break
		await process_frame
	print("FILM DEAD WOOD film: frames in %s, delivered at %s, bed %d, stash %s, history %s" % [
		FILM_DIR, str(delivered), scene.lair.bed_stage, str(scene.lair.stash), str(scene.routine.history)])

## Ease toward a pose that was chosen earlier and never moves again.
func _hold(pose: Dictionary) -> void:
	_view_target = _view_target.lerp(pose.target, SMOOTH)
	_view_distance = lerpf(_view_distance, float(pose.distance), SMOOTH)
	_view_yaw += angle_difference(_view_yaw, float(pose.yaw)) * SMOOTH
	_view_polar = lerpf(_view_polar, float(pose.polar), SMOOTH)
	scene.target = _view_target
	scene.distance = _view_distance
	scene.yaw = _view_yaw
	scene.polar = _view_polar
	scene._update_camera()

## Him in frame, with the camera easing rather than snapping. The pose comes from
## the study's own `frame_creature()` -- the same search the "Find Bigfoot" button
## uses, which scores candidate angles against the ground, the solid rock and the
## canopy. Two things learned the hard way here: an aim point half way between him
## and the branch often sits inside the rock dome by his door, where no angle is
## clear at all, so the aim point stays on him; and the search is expensive
## enough (it rebuilds the foliage bounds every call) to be worth reusing for
## POSE_INTERVAL frames while the easing catches up.
func _aim(focus: Vector3, cut := false) -> void:
	var him: Vector3 = scene.creature.global_position
	var span := Vector2(focus.x - him.x, focus.z - him.z).length()
	var wanted_distance := clampf(6.0 + span * 0.30, 6.5, 10.0)
	if cut or _pose_age <= 0:
		_pose_age = POSE_INTERVAL
		var kept_target: Vector3 = scene.target
		var kept_distance: float = scene.distance
		var kept_yaw: float = scene.yaw
		var kept_polar: float = scene.polar
		scene.frame_creature(wanted_distance, scene.creature.rotation.y - 0.65)
		_pose_yaw = scene.yaw
		_pose_polar = scene.polar
		scene.target = kept_target
		scene.distance = kept_distance
		scene.yaw = kept_yaw
		scene.polar = kept_polar
	_pose_age -= 1
	# The chosen angle is held, but the aim point tracks him every frame so a walk
	# between searches does not drift out of the picture.
	var wanted_target: Vector3 = him + Vector3.UP * 1.3
	if cut:
		_view_target = wanted_target
		_view_distance = wanted_distance
		_view_yaw = _pose_yaw
		_view_polar = _pose_polar
	else:
		_view_target = _view_target.lerp(wanted_target, SMOOTH * 2.0)
		_view_distance = lerpf(_view_distance, wanted_distance, SMOOTH)
		_view_yaw += angle_difference(_view_yaw, _pose_yaw) * SMOOTH
		_view_polar = lerpf(_view_polar, _pose_polar, SMOOTH)
	scene.target = _view_target
	scene.distance = _view_distance
	scene.yaw = _view_yaw
	scene.polar = _view_polar
	scene._update_camera()
