extends "res://studies/fidelity.gd"
## Does `scripts/island_builder.gd` grow islands that read as different places in
## the first chunk's art style?
##
## The study keeps the real chunk exactly as the fidelity scene builds it -- the
## mountain-and-arch, untouched -- and lays three generated islands in a row
## along +X beyond it, `SPACING` apart. Standing them beside the thing they have
## to match is the whole point: a shading, skirt or planting mismatch is obvious
## in one frame and invisible in a still of an island on its own.
##
## The three recipes are chosen to contrast with the first chunk and with each
## other, not to show the generator's range:
##   1  Riverfold valley   a river through open flowered slopes, no peak at all
##   2  Jade terraces      three stepped pools in wetland banks, reeds and moss
##   3  Sunstone canyon    arid stepped cliffs, a thin ribbon of water, bare rock
##
## Each island is scenery: no collision, no picking, no terrain document. The
## chunk editor never hears about them, so brush and pick rays -- which run in
## the first terrain's local space -- cannot reach them. See `island_builder.gd`.
##
## Keys, overriding the base study:
##   `1`  frame the first chunk      `2`..`4`  frame island 1..3
##   `R`  back to the row of four
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus res://studies/prototype_island_variants.tscn
##   ... res://studies/prototype_island_variants.tscn -- --stills=/private/tmp/island-variants

## Centre-to-centre spacing along +X. The chunk is 28 m across, so 40 leaves a
## 12 m gap: close enough that two islands share a frame, far enough that neither
## silhouette runs into the next.
const SPACING := 40.0
## The recipes, in the order they stand along +X. `seed` picks the variation, so
## these three dictionaries are the entire difference between the islands.
const RECIPES := [
	{"name": "Island1_Valley", "seed": 214, "preset": "valley", "water": "connected"},
	{"name": "Island2_Terraces", "seed": 631, "preset": "terraced_pools", "water": "connected"},
	{"name": "Island3_Canyon", "seed": 408, "preset": "canyon", "water": "connected"},
]
## Each island is turned a little so the row does not read as three copies of one
## pose, and lifted or dropped so the row has a skyline rather than a shelf.
const HEADINGS := [0.55, -1.25, 2.35]
const LIFTS := [-0.6, 0.4, -1.4]

const FRAME_SIZE := Vector2i(1600, 1000)
const DT := 1.0 / 60.0
## Late morning: the sun clears every peak in the row, as in `film_twin_chunks.gd`.
const SHOT_HOUR := 11.0
## Three-quarter view of one island. The distance is not a constant: the study
## inherits the source scene's 45-degree lens, and at 40 m that lens puts the
## near corner of a 28 m chunk close enough to overflow the frame. So each solo
## shot fits the island's own corners instead, the same way `_reset_camera` fits
## the first chunk, and lands near 60 m. This polar and yaw show the ground plan,
## the silhouette and the earth sides at once.
const SOLO_POLAR := 1.12
const SOLO_YAW := 2.45
## Breathing room around whatever is being fitted, as a fraction of its extent.
const SOLO_MARGIN := 1.16
## The whole row, from the side. Four 28 m chunks on 40 m centres span 148 m.
const ROW_POLAR := 1.19
const ROW_MARGIN := 1.22
## Driven steps after a pose, so grass, water and sky agree with the camera.
const SETTLE_FRAMES := 6
## Hard stop on a --stills run, in seconds.
const SHOOT_TIMEOUT := 120.0

var islands: Array[Node3D] = []
var islands_ready := false
var _stills_dir := ""
## Terrain-local -> study-root pose for the first chunk, which is what every
## island is placed relative to.
var _base := Transform3D.IDENTITY

func _ready() -> void:
	super._ready()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stills="):
			_stills_dir = argument.trim_prefix("--stills=")
	_base = global_transform.affine_inverse() * _chunk_editor.terrain.global_transform
	get_window().title = "ZenScape prototype · Island variants"
	_build_islands.call_deferred()

## Built deferred and awaited, because `build()` yields when `live` is set and
## because the first chunk's own formation must finish before the row is framed.
func _build_islands() -> void:
	for index in range(RECIPES.size()):
		var recipe: Dictionary = RECIPES[index].duplicate()
		recipe["live"] = true
		var island: Node3D = await IslandBuilder.build(self, recipe)
		island.transform = _placement(index)
		add_child(island)
		islands.append(island)
		print("ISLAND VARIANTS %d: %s, %d visual instances, %d props, %.0f ms" % [
			index + 1, island.describe(), _visual_count(island),
			island.data.objects.size(), island.build_usec / 1000.0])
	islands_ready = true
	_frame_row()
	if not _stills_dir.is_empty():
		await _shoot()

## Island `index` in study-root space: along +X past the first chunk, turned
## about its own centre and lifted, all about the first chunk's centre.
func _placement(index: int) -> Transform3D:
	var centre := _base.origin
	var rotation := Basis(Vector3.UP, HEADINGS[index])
	var offset := Vector3(SPACING * float(index + 1), LIFTS[index], 0.0)
	return Transform3D(rotation, centre + offset - rotation * centre) * _base

func _visual_count(island: Node3D) -> int:
	return island.find_children("*", "VisualInstance3D", true, false).size()

# -------------------------------------------------------------- the cameras

## All four: the first chunk and the three islands, from the side so the row
## spreads across the frame.
func _frame_row() -> void:
	var span := SPACING * float(RECIPES.size())
	target = _base.origin + Vector3(span * 0.5, 1.0, 0.0)
	polar = ROW_POLAR
	yaw = 0.0
	_auto_orbit = false
	# Fit the row's width to the frame rather than guessing a distance: the row
	# grows whenever a fourth recipe is added.
	_update_camera()
	var size := get_viewport().get_visible_rect().size
	var vertical := tan(deg_to_rad(camera.fov) * 0.5)
	var horizontal := vertical * size.x / maxf(size.y, 1.0)
	distance = (span * 0.5 + 14.0) * ROW_MARGIN / horizontal
	_update_camera()

## One island from three-quarters on, fitted to the frame. Index 0 is the first
## chunk, so the same key row compares a generated island against it.
func frame_island(index: int) -> void:
	var corners := _corners(index)
	var bounds := AABB(corners[0], Vector3.ZERO)
	for point: Vector3 in corners:
		bounds = bounds.expand(point)
	target = bounds.get_center()
	polar = SOLO_POLAR
	yaw = SOLO_YAW
	_auto_orbit = false
	# Distance last, and derived: the camera basis has to exist before a corner
	# can be measured against it. Same fit the base study's framing search uses.
	_update_camera()
	var size := get_viewport().get_visible_rect().size
	var vertical := tan(deg_to_rad(camera.fov) * 0.5)
	var horizontal := vertical * size.x / maxf(size.y, 1.0)
	distance = 8.0
	for corner: Vector3 in corners:
		var point := corner - target
		var depth := point.dot(camera.basis.z)
		distance = maxf(distance, depth + absf(point.dot(camera.basis.x)) * SOLO_MARGIN / horizontal)
		distance = maxf(distance, depth + absf(point.dot(camera.basis.y)) * SOLO_MARGIN / vertical)
	_update_camera()

## The eight corners of one chunk's ground and earth sides together, in
## study-root space. Index 0 is the first chunk, 1..n the islands.
func _corners(index: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	var nodes: Array[MeshInstance3D] = []
	var pose := _base
	if index == 0:
		nodes = [_chunk_editor.terrain, $Reference/skirt]
		pose = Transform3D.IDENTITY
	else:
		var island: Node3D = islands[index - 1]
		nodes = [island.terrain, island.skirt]
		pose = island.transform
	for node in nodes:
		if node == null or node.mesh == null:
			continue
		var box: AABB = node.transform * node.mesh.get_aabb()
		for corner in range(8):
			points.append(pose * box.get_endpoint(corner))
	return points

func _reset_camera(reference_pose := false) -> void:
	# The base framing search walks only the real chunk, so `R` would snap back
	# to one island out of four. Keep the row instead.
	if reference_pose or not islands_ready:
		super._reset_camera(reference_pose)
		return
	_frame_row()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and islands_ready:
		# `1`..`4` override the base study's tool hotkeys.
		var index: int = int(event.keycode) - KEY_1
		if index >= 0 and index <= RECIPES.size():
			frame_island(index)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)

# --------------------------------------------------------------- the stills

## `row.png` plus one still per island, then quit. The study drives its own
## clock and `_process` here so nothing eases between a pose and its capture.
func _shoot() -> void:
	# The GPU lock is shared with other agents, so a stalled shoot must not hold
	# the window open forever.
	get_tree().create_timer(SHOOT_TIMEOUT).timeout.connect(func() -> void:
		print("ISLAND VARIANTS: stills timed out")
		get_tree().quit(2))
	DirAccess.make_dir_recursive_absolute(_stills_dir)
	set_process(false)
	if _ui != null:
		_ui.visible = false
	while _chunk_editor.forming or _chunk_editor.refresh_pending > 0:
		await get_tree().process_frame
	_daylight()
	_frame_row()
	await _grab(_stills_dir.path_join("row.png"), "row")
	for index in range(RECIPES.size()):
		frame_island(index + 1)
		await _grab(_stills_dir.path_join("island_%d.png" % (index + 1)), islands[index].describe())
	print("ISLAND VARIANTS stills in %s" % _stills_dir)
	get_tree().quit(0)

## The study opens near dusk; a still of four dark islands says nothing about
## whether they match. Put the sun up and let the rig catch up.
func _daylight() -> void:
	_celestial.cycling = true
	world_clock.set_time(0, SHOT_HOUR)
	for step in range(60):
		_process(DT)

func _grab(path: String, label: String) -> void:
	for step in range(SETTLE_FRAMES):
		_process(DT)
	for step in range(3):
		_hold_frame_size()
		await get_tree().process_frame
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	if image == null:
		print("ISLAND VARIANTS: no image for ", path)
		return
	image.save_png(path)
	print("ISLAND VARIANTS still %s: %.1f m, polar %.2f, yaw %.2f -> %s" % [label, distance, polar, yaw, path])

## The project opens maximized and the window manager re-applies that a few
## frames after the window appears, which would resize images mid-shoot.
func _hold_frame_size() -> void:
	var window := get_viewport()
	if window.size == FRAME_SIZE:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	window.size = FRAME_SIZE
