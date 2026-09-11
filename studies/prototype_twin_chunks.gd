extends "res://studies/bigfoot_living_world.gd"
## Throwaway prototype: does a second island across a chasm read as a world?
##
## The playable world is one 28 m chunk. This study leaves that chunk exactly as
## it is and hangs a purely visual copy of it `CHASM_GAP` metres clear of its
## rim, turned 180 degrees about its own centre so it does not read as a mirror.
## Both islands float at the same height, so the deck is level anchor to anchor
## apart from whatever the two rims' own ground does. The gap is the one dial:
## every camera, the deck's length and its sag all follow it, so trying another
## distance is one constant or `--gap=50` on the command line.
##
## A rope bridge joins the two facing rims: a sagging run of short plank boxes on
## a catenary with `DECK_SAG` of the span in sag, so the establishing shot reads
## as rope and slats rather than as a beam. It is only a placeholder -- the
## moment `res://scripts/suspension_bridge.gd` exists this study instantiates
## that instead and calls `setup(a, b, {"sag": DECK_SAG})` with the same anchors.
##
## The copy is scenery and nothing else. It is not registered with the chunk
## editor, owns no terrain document, no collision and no picking, so brush and
## pick rays -- which run in the first terrain's local space through
## `data.ray_hit` -- cannot reach it. Saves, fire, weather and the creature all
## still believe in one chunk, which is the point: this answers a feel question
## and is meant to be deleted.
##
## Keys, all of which override bindings in the base study:
##   `B`  from beyond the far anchor, looking back along the whole span
##   `N`  standing on the middle of the deck, sighted along it at the far island
##   `M`  off the edge of the mid-deck, looking down into the void
##   `R`  back to the establishing shot of both islands
##   `T`  throws a loose rock onto the middle of the deck
##   `G`  drops three at once, to watch the deck take a load
##
## The crossing is wired to the study's live sky, which is the other half of the
## question: a bridge that ignores the weather reads as scenery. Every physics
## tick the wind dial, the wet ground, the snow cover and the ice go into the
## bridge, and a lightning strike inside `STRIKE_REACH` of the deck snaps the
## nearest rope segment. Nothing is stored here that the sky does not already
## own -- see `_physics_process`.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus res://studies/prototype_twin_chunks.tscn
## Stills and a walk clip come from `tools/film_twin_chunks.gd`.

## THE dial. Rim-to-rim clear air between the two islands, in metres. Everything
## downstream is derived from it -- the island's placement, the establishing
## camera, the deck's sag and length, the vertigo camera's stand-off -- so trying
## 40 or 50 instead is this one number, or `--gap=50` on the command line.
const CHASM_GAP := 45.0
## The chunk's half extent in terrain-local XZ. Hard-coded throughout the engine
## scripts too (native_terrain_data.gd clamps to +/-14).
const CHUNK_HALF := 14.0
## How far inside each rim an anchor stands.
const ANCHOR_INSET := 0.5
## When the rim itself is a wall, the bridgehead may sit this far inland, on top
## of it, so long as the ground between it and the edge stays below the deck.
const ANCHOR_MAX_INSET := 5.5
const ANCHOR_INSET_STEP := 1.0
const ANCHOR_LIP_CLEARANCE := 0.2
## Height difference between the islands. Zero: the crossing is level, and the
## only rise or fall in the deck is the two rims' own ground.
const SECOND_CHUNK_LIFT := 0.0
## The anchor search walks the whole facing rim at this spacing. Chunk two is
## turned 180 degrees, so a candidate `z` on chunk one sits directly across from
## `-z` on chunk two, which is what keeps the pair square to the chasm.
const ANCHOR_SEARCH_REACH := 12.0
const ANCHOR_SEARCH_STEP := 1.0
## Ground spread tolerated across a 1 m cross at an anchor before it counts as
## too steep to stand a bridge head on.
const ANCHOR_FLATNESS := 0.45
## A bridgehead is clear when no tree, rock, plant or prop stands within this
## lateral distance of the walker's path: the step-off and the walkable heading.
const ANCHOR_CLEARANCE := 1.2
const ANCHOR_APPROACH := 6.0
## The steepest rise over `ANCHOR_WALK_STEP` metres a walker can take inland from
## the bridgehead; beyond it a mountain wall or a cliff blocks the crossing.
const ANCHOR_WALK_STEP := 0.5
## The straight stretch inland a walker needs before they can turn.
const ANCHOR_STEP_OFF := 1.5
const ANCHOR_WALK_RISE := 0.35
## Names of visual nodes that are ground, water or ground cover a foot walks
## through, never an obstacle. `mesh-10` is the reference chunk's grass tufts.
const NOT_OBSTACLES := ["terrain", "skirt", "sides", "earth", "water", "pond", "stream", "strand", "mist", "foam", "spray", "mesh-41", "bridge", "birds",
	"grass", "tuft", "mesh-10", "stem", "petal", "flower", "fungus", "mushroom", "daisy", "umbel", "spike", "button"]
## ------------------------------------------------------------- the weather
## The wind dial the storm preset carries, which is the top of the map; every
## other preset is a fraction of it. `clear` is 0.5, `rain` 1.6, `storm` 2.5.
const WIND_FULL := 2.5
## Lateral acceleration, in metres per second squared, the deck feels at a full
## storm before gusting. The rail spring pulls each slab back at about 2.8 m/s^2
## per metre of drift over a 46 m span, so this is roughly a metre and a half of
## steady bow with the wind square on -- and the sky's wind sits at 19 degrees
## off the span, so only a third of it pushes across the deck at all. Measured
## at the study's 49 m crossing: 0.02 m of bow under `clear`, 0.42 m under
## `rain`, 1.10 m under `storm`, which `tests/test_bridge_weather.gd` holds to.
const WIND_ACCEL := 13.5
## Wind bites harder than it blows: squared-and-a-bit, so a breeze barely
## registers and the storm lurches. Two and a bit is what put the three presets
## in the three bands the crossing is meant to read in at once.
const WIND_EXPONENT := 2.3
## The felt wind follows the sky's dial at this rate, per second. Presets switch
## instantly; a bridge that snapped with them would read as a cut.
const WIND_RESPONSE := 0.55
## Gusting. One seeded noise channel walked at `GUST_RATE` cycles a second, worth
## this much of the base either way in fair weather and this much more in a
## storm, so the same breeze that breathes becomes a thing that shoves.
const GUST_DEPTH := 0.45
const GUST_STORM := 1.0
const GUST_RATE := 0.3
## How near a strike has to land to be felt in the rope, in metres.
const STRIKE_REACH := 15.0
## A rock thrown at the deck: where it starts, and how hard it is sent down.
## Deliberately gentle. The deck's collision slab is 13 cm thick, so a stone
## arriving faster than about 7 m/s covers more than that in a tick and Jolt's
## linear cast does not always catch it -- a rock lobbed onto the planks lands,
## a rock fired at them from the sky sometimes goes through.
const THROW_HEIGHT := 1.3
const THROW_SPEED := 0.8
const THROW_SPREAD := 0.9      ## How far apart the three of `G` land, in metres.
## The lip along the deck edges the bridge is asked for, in metres. Without it
## nothing stays on the crossing: the deck leans a degree or two downwind and a
## stone rolls off the open side inside two seconds. Measured at 0.10 m -- a
## stone stays, and it is a step rather than a wall.
const DECK_KERB := 0.1
## Rolling resistance for a rock left on the boards: see `throw_rock`.
const ROCK_ROLL_DAMP := 3.2
const ROCK_SLIDE_DAMP := 0.8
## How many thrown rocks the study keeps. Past this the oldest goes, so leaning
## on `T` cannot quietly hang a hundred bodies off one constraint island.
const ROCK_LIMIT := 12
const DECK_WIDTH := 1.0
const DECK_THICKNESS := 0.1
const RAIL_SIDE := 0.07
const RAIL_HEIGHT := 0.55
const DECK_COLOR := Color("6b4f32")   ## Oiled wood.
const RAIL_COLOR := Color("a8915f")   ## Hemp rope.
## Midspan sag as a fraction of the span. The real bridge script gets this too.
const DECK_SAG := 0.13
## Shape of the hanging curve. Higher is more sharply hooked at the ends; 2.0 is
## a rope under its own weight rather than a slack chain.
const CATENARY_K := 2.0
## Slat pitch along the deck. The plank count follows the span, so the boards
## stay a stride apart whether the chasm is 20 m or 100 m.
const DECK_PLANK_STRIDE := 0.9
## How much of each slat's stride is board rather than gap. Real gaps matter: up
## close they are what distinguishes a rope bridge from a plank, and they let the
## drop show through the deck from the `N` camera.
const DECK_PLANK_FILL := 0.78
## The establishing shot pulls back roughly as far as the pair is wide. Checked
## by eye at three gaps -- 22 m, 45 m and 100 m -- and this one factor framed all
## three with a margin at either rim. Slack above and below is unavoidable: a
## strip four times wider than it is tall leaves sky empty at any distance.
const WIDE_FIT := 0.99
const WIDE_POLAR := 1.12
## `B` stands back about two thirds of the span beyond the far anchor: enough to
## watch the deck leave the island and fall away, close enough that the island is
## not a speck. Framing the *whole* span shrank the world to a postage stamp,
## which answers nothing.
const BRIDGE_FIT := 0.7
const BRIDGE_POLAR := 1.24
## Standing on the deck: eye height over the planks. `N` sights straight at the
## far bridgehead rather than at a fixed pitch, because from the sagging midspan
## the deck *rises* toward both ends -- any downward tilt looks into the boards.
const CHASM_EYE := 2.0
const CHASM_REACH := 40.0
## Sun shadow range as a multiple of the layout's width, which puts it past the
## far island's far corner as seen from the establishing camera. See
## `_reach_shadows()` for why the shared 130 m default is not enough here.
const SHADOW_FIT := 1.8
## `M`, the vertigo shot. The geometry rules out the literal version: at midspan
## the deck hangs a full sag-depth below both rims, so the far island's skirt
## sits *above* this camera, and a 38-degree lens cannot hold something a few
## degrees up and something forty degrees down in one frame. A straight-down look
## gets empty air and a plank edge -- both earlier attempts proved it.
##
## So the shot stands off and above the mid-deck and sights a point four fifths
## of the way across. The deck then sweeps up out of the drop toward the far
## island's underside in the top of frame, and the bottom half is the void, which
## is what the drop is supposed to feel like. Both stand-offs are fractions of
## the sag, so the shot holds its shape as the gap changes.
const VOID_EYE := 0.75
const VOID_OFFSET := 0.6
const VOID_SIGHT := 0.82

var second_chunk: Node3D
var bridge: Node3D
var second_chunk_ready := false
## Clear air between the rims. `CHASM_GAP` unless `--gap=` says otherwise.
var chasm_gap := CHASM_GAP
## The far island grows from the chunk pipeline with these settings; an empty
## dictionary falls back to the mirrored stand-in copy of chunk one.
const ISLAND_SEED := 11
var island_settings: Dictionary = {"preset": "valley", "seed": ISLAND_SEED}
## Terrain-local -> study-root pose for chunk one and for its copy.
var _base := Transform3D.IDENTITY
var _mirror := Transform3D.IDENTITY
## Placement of the copy relative to the original, about the original's centre.
var _placement := Transform3D.IDENTITY
var _felt_wind := 0.0
var _gust_clock := 0.0
var _gusts := FastNoiseLite.new()
var _rocks: Array[RigidBody3D] = []
var _anchors: Array[Transform3D] = []
var _copied: Array[String] = []
var _obstacle_cache := {}
var _skipped: Array[String] = []

func _ready() -> void:
	super._ready()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--gap="):
			chasm_gap = maxf(2.0, float(argument.trim_prefix("--gap=")))
		if argument.begins_with("--island="):
			# `--island=<preset>:<seed>`; `--island=copy` keeps the mirrored stand-in.
			var parts := argument.trim_prefix("--island=").split(":")
			island_settings = {} if parts[0] == "copy" else {"preset": parts[0], "seed": int(parts[1]) if parts.size() > 1 else ISLAND_SEED}
	print("TWIN CHUNKS chasm gap %.1f m, centres %.1f m apart" % [chasm_gap, chunk_spacing()])
	_base = global_transform.affine_inverse() * _chunk_editor.terrain.global_transform
	var centre := _base.origin
	var rotation := Basis(Vector3.UP, PI)
	var offset := Vector3(chunk_spacing(), SECOND_CHUNK_LIFT, 0.0)
	# Turn about the chunk's own centre, then carry it across the gap.
	_placement = Transform3D(rotation, centre + offset - rotation * centre)
	_mirror = _placement * _base
	_gusts.seed = 7
	_gusts.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_gusts.frequency = 1.0
	rebuild_second_chunk()
	_lightning.struck.connect(_strike_near_deck)
	_reach_shadows()
	_frame_wide()
	second_chunk_ready = true
	get_window().title = "ZenScape prototype · Twin chunks"

## Centre to centre along +X: the clear air plus one whole chunk of rim.
func chunk_spacing() -> float:
	return chasm_gap + CHUNK_HALF * 2.0

## How wide the pair is, rim to rim, which is what the establishing shot frames.
func layout_width() -> float:
	return chasm_gap + CHUNK_HALF * 4.0

## `landscape_lighting.gd` sets the sun's shadow range to 130 m, which is the
## right number for a world 28 m across: at the one-chunk framing everything is
## well inside it. Two islands with a chasm between them are not -- from the
## establishing camera much of both falls past 130 m and loses its shadows,
## which is why the wide shot came back flat. Pushed out here, in the study, on
## the live lights; the shared default is left alone because it is correct for
## the game. The cost is shadow resolution spread over four times the range.
func _reach_shadows() -> void:
	for light: DirectionalLight3D in _lights:
		light.directional_shadow_max_distance = maxf(130.0, layout_width() * SHADOW_FIT)

## Rebuild the copy. Worth a second call once `_chunk_editor.refresh_pending`
## has drained, because authored content and landmarks publish asynchronously
## and are empty in a freshly opened study.
func rebuild_second_chunk() -> void:
	if second_chunk != null:
		remove_child(second_chunk)
		second_chunk.queue_free()
	second_chunk = await _build_second_chunk()
	add_child(second_chunk)
	_anchors.clear()  ## A new island means a new rim to look for anchors on.
	_obstacle_cache.clear()
	_place_bridge()

# ------------------------------------------------------------- the island

## The stand-in second island: a visual copy of the first, and the one piece of
## this study meant to be replaced. It answers `ground_height_at()` for itself,
## which is the whole seam -- the anchor search, the framings and the film tool
## ask the SecondChunk node where its ground is and never learn that it happens
## to be a duplicate. A generated island answers the same question its own way.
class DuplicateIsland extends Node3D:
	## Terrain-local -> study-root pose for this island's copy of the heightfield.
	var placement := Transform3D.IDENTITY
	var data: NativeTerrainData

	## Study-root Y of the ground under a world XZ point, or null off the island.
	func ground_height_at(world_xz: Vector2) -> Variant:
		if data == null:
			return null
		var local := placement.affine_inverse() * Vector3(world_xz.x, 0.0, world_xz.y)
		var height: Variant = data.ground_height(Vector2(local.x, local.z))
		if height == null:
			return null
		return (placement * Vector3(local.x, float(height), local.z)).y

	## True where standing on this island would mean standing in water.
	func in_water_at(world_xz: Vector2) -> bool:
		if data == null:
			return false
		var local := placement.affine_inverse() * Vector3(world_xz.x, 0.0, world_xz.y)
		for pond: Dictionary in data.ponds:
			if GardenWater.covers(data.pond_surface(pond), Vector2(local.x, local.z)):
				return true
		return false

## Build the second island and hand it back. Everything downstream -- the anchor
## search, the bridge, the cameras, the film tool -- goes through the returned
## node and its `ground_height_at()`, so replacing this one function with a
## generated landscape is the entire change.
func _build_second_chunk() -> Node3D:
	_copied.clear()
	_skipped.clear()
	if not island_settings.is_empty():
		var settings := island_settings.duplicate()
		settings["name"] = "SecondChunk"
		var grown: Node3D = await IslandBuilder.build(self, settings)
		grown.set_meta("prototype_scenery", true)
		grown.transform = _placement
		print("TWIN CHUNKS grew the far island: %s" % grown.describe())
		return grown
	var island := DuplicateIsland.new()
	island.name = "SecondChunk"
	island.placement = _mirror
	island.data = _chunk_editor.data
	# A marker so anything walking the tree can tell this is scenery, not world.
	island.set_meta("prototype_scenery", true)
	island.transform = _placement
	for node in $Reference.get_children():
		_copy_leaf(island, node)
	for node in _chunk_editor.content.get_children():
		_copy_leaf(island, node)
	for node in _chunk_editor.falls.get_children():
		_copy_leaf(island, node)
	# Landmarks are Node3D wrappers with a mesh subtree, so they copy whole.
	for node in _chunk_editor.landmarks.get_children():
		_copy_subtree(island, node)
	print("TWIN CHUNKS copied %d nodes, %d visual instances: %s" % [
		_copied.size(), island.find_children("*", "VisualInstance3D", true, false).size(),
		", ".join(_copied)])
	print("TWIN CHUNKS skipped: %s" % ("nothing" if _skipped.is_empty() else ", ".join(_skipped)))
	return island

## One flat visual node: copied with its resources shared, its children dropped.
## The reference geometry's children are leaf meshes; the only child anyone adds
## is the editor's pond preview under `terrain`, which belongs to the real world.
func _copy_leaf(island: Node3D, node: Node) -> void:
	if not _wanted(node):
		return
	var copy: Node3D = node.duplicate(0)
	for child in copy.get_children():
		copy.remove_child(child)
		child.queue_free()
	_adopt(island, copy, node)

## A wrapper node kept with its mesh subtree, for landmarks.
func _copy_subtree(island: Node3D, node: Node) -> void:
	if node is not Node3D:
		_skipped.append("%s (not a Node3D)" % node.name)
		return
	if node.find_children("*", "VisualInstance3D", true, false).is_empty():
		_skipped.append("%s (no visuals)" % node.name)
		return
	_adopt(island, node.duplicate(0), node)

## `duplicate(0)` shares mesh and material resources rather than copying them, so
## the copy cannot drift in look from the original -- and costs no extra memory.
func _adopt(island: Node3D, copy: Node3D, source: Node3D) -> void:
	copy.name = "Twin_" + source.name
	island.add_child(copy)
	# The copy's local pose is the source's pose in study-root space; the island's
	# own transform then carries it across the chasm and turns it.
	copy.transform = global_transform.affine_inverse() * source.global_transform
	_copied.append(source.name)

## Scenery worth copying. Everything that is not a VisualInstance3D falls out
## here, which is how cameras, lights, the screen-space mists (`fall_mist.gd` is
## a CanvasLayer), the fog volumes under `_world_visuals` and the UI are all
## excluded without naming them.
func _wanted(node: Node) -> bool:
	if node is not VisualInstance3D:
		_skipped.append("%s (%s, not a VisualInstance3D)" % [node.name, node.get_class()])
		return false
	# The flock is driven by one global shader clock over one shared MultiMesh; a
	# second copy would fly the identical birds in lockstep 36 m away.
	if node.get_meta("source_kind", "static") == "birds":
		_skipped.append("%s (birds: one shared animated flock)" % node.name)
		return false
	if node is MeshInstance3D and node.mesh == null:
		_skipped.append("%s (no mesh)" % node.name)
		return false
	if node is MultiMeshInstance3D and (node.multimesh == null or node.multimesh.instance_count == 0):
		_skipped.append("%s (empty MultiMesh)" % node.name)
		return false
	return true

func visual_instance_count() -> int:
	if second_chunk == null:
		return 0
	return second_chunk.find_children("*", "VisualInstance3D", true, false).size()

# ------------------------------------------------------------- the anchors

## Two world-space poses on the facing rims, `ANCHOR_INSET` inside each, their
## +Z axes pointing at one another across the chasm.
##
## The search runs entirely in world XZ and asks each island for its own ground,
## so it holds no opinion about what the far island is: chunk one answers through
## its terrain document, the second island answers through `ground_height_at()`
## on the SecondChunk node. A pair sharing a world Z is square across the chasm
## whatever the far island's own shape happens to be.
func bridge_anchors() -> Array[Transform3D]:
	if not _anchors.is_empty():
		return _anchors
	var best := {}
	# Five passes, each dropping one requirement, so a world whose whole rim is
	# steep, flooded or overgrown still yields a crossing rather than nothing.
	# Clearance goes late (when nothing is clear, the chosen bridgehead is
	# cleared) and walkability last: a bridge nobody can walk off is the failure
	# this search exists to avoid.
	for relaxation in range(6):
		for step_index in range(int(ANCHOR_SEARCH_REACH * 2.0 / ANCHOR_SEARCH_STEP) + 1):
			var z := _base.origin.z - ANCHOR_SEARCH_REACH + float(step_index) * ANCHOR_SEARCH_STEP
			var head_a := _bridgehead(z, false)
			var head_b := _bridgehead(z, true)
			if head_a.is_empty() or head_b.is_empty():
				continue
			var near: Vector2 = head_a.xz
			var far: Vector2 = head_b.xz
			if relaxation < 2 and (_in_water(near, false) or _in_water(far, true)):
				continue
			var roughness := maxf(_roughness(near, false), _roughness(far, true))
			if relaxation < 1 and roughness > ANCHOR_FLATNESS:
				continue
			if relaxation < 4 and not (head_a.walkable and head_b.walkable):
				continue
			var blockers := _blockers(head_a, false) + _blockers(head_b, true)
			var fixed := 0
			for obstacle in blockers:
				if obstacle.fixed:
					fixed += 1
			# The cave and the lair are never cleared for a bridge.
			if relaxation < 5 and fixed > 0:
				continue
			if relaxation < 3 and not blockers.is_empty():
				continue
			var a := Vector3(near.x, float(head_a.y), near.y)
			var b := Vector3(far.x, float(head_b.y), far.y)
			var step_up := absf(a.y - b.y)
			# Fewer things to clear outranks a smaller step.
			var cost := float(blockers.size()) * 10.0 + step_up
			if best.is_empty() or cost < float(best.cost):
				best = {"a": a, "b": b, "z": z, "step": step_up, "roughness": roughness, "cost": cost, "blockers": blockers}
		if not best.is_empty():
			print("TWIN CHUNKS anchor search settled at relaxation %d (walkable rim spots: %d near, %d far)" % [relaxation, _walkable_count(false), _walkable_count(true)])
			if relaxation >= 4:
				push_warning("twin chunks: no walkable bridgehead pair on the facing rims; the crossing may dead-end")
			if relaxation >= 5:
				push_warning("twin chunks: the only bridgehead runs into the cave or the lair")
			break
	if best.is_empty():
		push_error("twin chunks: no anchor pair on the facing rims")
		return _anchors
	var a: Vector3 = best.a
	var b: Vector3 = best.b
	if not best.blockers.is_empty():
		var movable: Array[Dictionary] = []
		for obstacle in best.blockers:
			if not obstacle.fixed:
				movable.append(obstacle)
		_clear_obstacles(movable)
		var tally := {}
		for obstacle in best.blockers:
			tally[obstacle.node.name] = int(tally.get(obstacle.node.name, 0)) + 1
		print("TWIN CHUNKS no clear bridgehead on the rims; cleared %d obstacles at the chosen one: %s" % [best.blockers.size(), tally])
	_anchors = [Transform3D(_facing(b - a), a), Transform3D(_facing(a - b), b)]
	print("TWIN CHUNKS anchors at world z %+.1f: A (%.2f, %.2f, %.2f) -> B (%.2f, %.2f, %.2f); span %.2f m, horizontal %.2f m, step %.2f m, roughness %.2f" % [
		float(best.z), a.x, a.y, a.z, b.x, b.y, b.z, a.distance_to(b),
		Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)), float(best.step), float(best.roughness)])
	return _anchors

## A point on the hanging deck, `t` from the near anchor to the far one. The
## planks, the rails and the walking shot all read the same curve, so nothing
## can drift off the boards.
func deck_point(t: float) -> Vector3:
	var anchors := bridge_anchors()
	if anchors.size() != 2:
		return Vector3.ZERO
	var a := anchors[0].origin
	var b := anchors[1].origin
	# Clamped, not extrapolated: past either anchor the catenary would curve back
	# upward, and the walking shot's run-up would climb into the air.
	return a.lerp(b, t) - Vector3.UP * a.distance_to(b) * DECK_SAG * _sag_profile(clampf(t, 0.0, 1.0))

## A catenary segment scaled to 0 at both anchors and 1 at midspan.
func _sag_profile(t: float) -> float:
	var ends := cosh(CATENARY_K)
	return (cosh(CATENARY_K * (2.0 * t - 1.0)) - ends) / (1.0 - ends)

## +Z down `direction`, which is what a bridge head faces.
func _facing(direction: Vector3) -> Basis:
	var z := direction.normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, z.cross(x), z)

## Study-root Y of the ground under a world XZ point, on whichever island. Null
## off that island. Chunk one is asked through its terrain document; the second
## island is asked through its own `ground_height_at()`, which is what lets a
## generated landscape drop in without touching any of this.
func ground_y_at(world_xz: Vector2, second := false) -> Variant:
	if second:
		if second_chunk == null or not second_chunk.has_method("ground_height_at"):
			return null
		return second_chunk.ground_height_at(world_xz)
	var local := _base.affine_inverse() * Vector3(world_xz.x, 0.0, world_xz.y)
	var height: Variant = _chunk_editor.data.ground_height(Vector2(local.x, local.z))
	if height == null:
		return null
	return (_base * Vector3(local.x, float(height), local.z)).y

## Height spread over the patch a bridge head actually stands on: the deck's
## width along the rim, and half a metre inland. Deliberately not sampled
## outward, because every island rim falls away there -- measuring the drop the
## bridge is there to cross would reject the whole rim.
func _roughness(world_xz: Vector2, second: bool) -> float:
	var low := INF
	var high := -INF
	# Inland is +X for the far island's facing rim and -X for chunk one's.
	var inland := 0.5 if second else -0.5
	var footprint: Array[Vector2] = [
		Vector2.ZERO, Vector2(inland, 0.0),
		Vector2(0.0, DECK_WIDTH * 0.5), Vector2(0.0, -DECK_WIDTH * 0.5),
		Vector2(inland, DECK_WIDTH * 0.5), Vector2(inland, -DECK_WIDTH * 0.5)]
	for offset: Vector2 in footprint:
		var height: Variant = ground_y_at(world_xz + offset, second)
		if height == null:
			continue
		low = minf(low, float(height))
		high = maxf(high, float(height))
	return 0.0 if low > high else high - low

## Everything standing on an island, as world XZ points with a footprint radius:
## each MultiMesh instance and each single mesh under the island's visual root,
## minus ground and water. Read once per island and cached until it is rebuilt.
func _obstacles(second: bool) -> Array[Dictionary]:
	var key := 1 if second else 0
	if _obstacle_cache.has(key):
		return _obstacle_cache[key]
	var found: Array[Dictionary] = []
	var roots: Array[Node] = []
	roots.append(second_chunk if second else $Reference)
	if not second:
		# The living world adds the cave dome and the lair beside the reference geometry.
		for field in ["cave_sites", "lair"]:
			if field in self and get(field) is Node:
				roots.append(get(field))
	for root in roots:
		if root == null:
			continue
		var fixed := root != $Reference and root != second_chunk
		for node in root.find_children("*", "VisualInstance3D", true, false):
			if _not_obstacle(node):
				continue
			if node is GeometryInstance3D:
				# Anything wholly below the ground (the lair's lower story) is no obstacle to a walker.
				var box: AABB = node.global_transform * node.get_aabb()
				var ground: Variant = ground_y_at(Vector2(box.get_center().x, box.get_center().z), second)
				if ground != null and box.end.y < float(ground) + 0.3:
					continue
			if node is MultiMeshInstance3D and node.multimesh != null:
				var mm: MultiMesh = node.multimesh
				var extent: Vector3 = mm.mesh.get_aabb().size if mm.mesh != null else Vector3.ONE
				for i in range(mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count):
					var pose: Transform3D = node.global_transform * mm.get_instance_transform(i)
					var radius := minf(1.5, maxf(extent.x, extent.z) * pose.basis.get_scale().x * 0.5)
					found.append({"node": node, "index": i, "xz": Vector2(pose.origin.x, pose.origin.z), "radius": radius, "fixed": fixed})
			elif node is MeshInstance3D and node.mesh != null:
				var box: AABB = node.global_transform * node.mesh.get_aabb()
				var centre := box.get_center()
				found.append({"node": node, "index": -1, "xz": Vector2(centre.x, centre.z), "radius": minf(3.0, maxf(box.size.x, box.size.z) * 0.5), "fixed": fixed})
	_obstacle_cache[key] = found
	return found

func _not_obstacle(node: Node) -> bool:
	var name := node.name.to_lower()
	for word in NOT_OBSTACLES:
		if name.contains(word):
			return true
	var parent := node.get_parent()
	return parent != null and parent != $Reference and parent != second_chunk and _not_obstacle(parent) and parent is not Node3D

## Where on this rim, at this Z, a bridgehead stands: the first inset from the
## edge whose approach is walkable and whose lip stays below the deck, else the
## rim edge itself flagged unwalkable. Empty when there is no ground at all.
func _bridgehead(z: float, second: bool) -> Dictionary:
	var edge_x := (second_chunk_centre().x - CHUNK_HALF) if second else (_base.origin.x + CHUNK_HALF)
	var inland := 1.0 if second else -1.0
	var fallback := {}
	var inset := ANCHOR_INSET
	while inset <= ANCHOR_MAX_INSET + 0.001:
		var xz := Vector2(edge_x + inland * inset, z)
		var y: Variant = ground_y_at(xz, second)
		if y != null:
			var head := {"xz": xz, "y": float(y), "inset": inset, "walkable": false}
			if fallback.is_empty():
				fallback = head
			var heading: Variant = _walkable_heading(xz, second)
			if heading != null and _lip_clear(xz, float(y), inset, second):
				head.walkable = true
				head.heading = heading
				return head
		inset += ANCHOR_INSET_STEP
	return fallback

## Between the bridgehead and the rim edge the ground must stay under the deck.
func _lip_clear(xz: Vector2, y: float, inset: float, second: bool) -> bool:
	var outward := Vector2(-1.0 if second else 1.0, 0.0)
	var along := ANCHOR_WALK_STEP
	while along < inset:
		var height: Variant = ground_y_at(xz + outward * along, second)
		if height != null and float(height) > y + ANCHOR_LIP_CLEARANCE:
			return false
		along += ANCHOR_WALK_STEP
	return true

## Can a walker step off this bridgehead and keep going? The first stretch
## straight inland must be walkable (that is where the deck lands them), and
## from there at least one heading -- inland, quartering, or along the rim --
## must run `ANCHOR_APPROACH` metres without a step steeper than a walker takes.
## (The resident's navigation grid was tried here and rejected flat open grass,
## so slope and the obstacle sweep are the whole test on both islands.)
func _approach_walkable(world_xz: Vector2, second: bool) -> bool:
	return _walkable_heading(world_xz, second) != null

## The first walkable heading off this bridgehead, or null when there is none.
func _walkable_heading(world_xz: Vector2, second: bool) -> Variant:
	var inland := Vector2(1.0 if second else -1.0, 0.0)
	if not _ray_walkable(world_xz, inland, ANCHOR_STEP_OFF, second):
		return null
	for turn in [0.0, PI * 0.25, -PI * 0.25, PI * 0.5, -PI * 0.5]:
		if _ray_walkable(world_xz, inland.rotated(turn), ANCHOR_APPROACH, second):
			return inland.rotated(turn)
	return null

## Ground exists the whole way and never rises or falls faster than a step.
func _ray_walkable(from: Vector2, direction: Vector2, length: float, second: bool) -> bool:
	var previous: Variant = null
	var along := 0.0
	while along <= length + 0.001:
		var height: Variant = ground_y_at(from + direction * along, second)
		if height == null:
			return false
		if previous != null and absf(float(height) - float(previous)) > ANCHOR_WALK_RISE:
			return false
		previous = height
		along += ANCHOR_WALK_STEP
	return true

## How many rim candidates a walker could step off; diagnostic only.
func _walkable_count(second: bool) -> int:
	var count := 0
	for step_index in range(int(ANCHOR_SEARCH_REACH * 2.0 / ANCHOR_SEARCH_STEP) + 1):
		var z := _base.origin.z - ANCHOR_SEARCH_REACH + float(step_index) * ANCHOR_SEARCH_STEP
		var head := _bridgehead(z, second)
		if not head.is_empty() and head.walkable:
			count += 1
	return count

## The obstacles that stand on a bridgehead or its approach.
func _blockers(head: Dictionary, second: bool) -> Array[Dictionary]:
	var start: Vector2 = head.xz
	var inland := Vector2(1.0 if second else -1.0, 0.0)
	var heading: Vector2 = head.get("heading", inland)
	var corner := start + inland * ANCHOR_STEP_OFF
	var hits: Array[Dictionary] = []
	for obstacle in _obstacles(second):
		var xz: Vector2 = obstacle.xz
		var reach: float = ANCHOR_CLEARANCE + float(obstacle.radius) * 0.5
		var on_step := start + inland * clampf((xz - start).dot(inland), 0.0, ANCHOR_STEP_OFF)
		var on_way := corner + heading * clampf((xz - corner).dot(heading), 0.0, ANCHOR_APPROACH)
		if xz.distance_to(on_step) < reach or xz.distance_to(on_way) < reach:
			hits.append(obstacle)
	return hits

## Fold the blockers away: a MultiMesh instance shrinks to nothing in place, a
## single mesh hides. Scenery only; no terrain document changes.
func _clear_obstacles(blockers: Array[Dictionary]) -> void:
	for obstacle in blockers:
		var node: Node = obstacle.node
		if int(obstacle.index) >= 0:
			var mm: MultiMesh = node.multimesh
			var pose := mm.get_instance_transform(int(obstacle.index))
			mm.set_instance_transform(int(obstacle.index), Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), pose.origin))
		else:
			node.visible = false
	_obstacle_cache.clear()

## The repo has no single water predicate; on chunk one this is the idiom the
## water course, the falls and the navigation all use. The second island answers
## for itself when it can, and is taken to be dry when it cannot.
func _in_water(world_xz: Vector2, second: bool) -> bool:
	if second:
		if second_chunk == null or not second_chunk.has_method("in_water_at"):
			return false
		return second_chunk.in_water_at(world_xz)
	var local := _base.affine_inverse() * Vector3(world_xz.x, 0.0, world_xz.y)
	for pond: Dictionary in _chunk_editor.data.ponds:
		if GardenWater.covers(_chunk_editor.data.pond_surface(pond), Vector2(local.x, local.z)):
			return true
	return false

# -------------------------------------------------------------- the bridge

## The real span when it lands, a plank deck until then. Both take the anchors.
func _place_bridge() -> void:
	var anchors := bridge_anchors()
	if anchors.size() != 2:
		return
	if bridge != null:
		remove_child(bridge)
		bridge.queue_free()
	const REAL := "res://scripts/suspension_bridge.gd"
	if ResourceLoader.exists(REAL):
		bridge = load(REAL).new()
		bridge.name = "Bridge"
		add_child(bridge)
		bridge.setup(anchors[0], anchors[1], {"sag": DECK_SAG, "kerb": DECK_KERB})
		print("TWIN CHUNKS bridge: %s, sag %.2f, kerb %.2f" % [REAL, DECK_SAG, DECK_KERB])
		return
	bridge = _placeholder_bridge()
	add_child(bridge)
	var span := anchors[0].origin.distance_to(anchors[1].origin)
	print("TWIN CHUNKS bridge: placeholder rope deck, %.2f m span, %d planks, %.2f m of sag (no %s yet)" % [
		span, plank_count(), span * DECK_SAG, REAL])

## Slats needed to cover the span at `DECK_PLANK_STRIDE`.
func plank_count() -> int:
	var anchors := bridge_anchors()
	if anchors.size() != 2:
		return 0
	return maxi(8, int(round(anchors[0].origin.distance_to(anchors[1].origin) / DECK_PLANK_STRIDE)))

## A rope bridge in the crudest possible terms: short plank boxes laid end to
## end down the hanging curve, with a rope box either side following the same
## curve a rail's height up. Slats and sag are the whole point -- one long beam
## at this span reads as a girder, and the question being asked is whether the
## crossing feels like a crossing.
func _placeholder_bridge() -> Node3D:
	var node := Node3D.new()
	node.name = "Bridge"
	var deck := _material(DECK_COLOR)
	var rope := _material(RAIL_COLOR)
	var planks := plank_count()
	var previous := deck_point(0.0)
	for plank in range(planks):
		var next := deck_point(float(plank + 1) / float(planks))
		var stride := previous.distance_to(next)
		var pose := Transform3D(_facing(next - previous), (previous + next) * 0.5)
		node.add_child(_slab("Plank%03d" % plank,
			Vector3(DECK_WIDTH, DECK_THICKNESS, stride * DECK_PLANK_FILL),
			pose * Vector3(0.0, -DECK_THICKNESS * 0.5, 0.0), pose.basis, deck))
		# The ropes overlap into the next segment so the two handlines read as
		# continuous cable where the curve bends hardest, at the two ends.
		for side: float in [-1.0, 1.0]:
			node.add_child(_slab("Rope%s%03d" % ["L" if side < 0.0 else "R", plank],
				Vector3(RAIL_SIDE, RAIL_SIDE, stride * 1.06),
				pose * Vector3(side * DECK_WIDTH * 0.5, RAIL_HEIGHT, 0.0), pose.basis, rope))
		previous = next
	return node

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _slab(slab_name: String, size: Vector3, origin: Vector3, basis: Basis, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = slab_name
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.transform = Transform3D(basis, origin)
	node.material_override = material
	return node

# ------------------------------------------------------------- the weather

## The sky, every physics tick, turned into the four things the crossing can
## answer: a wind vector, wet boards, snow cover and frost. Read straight off
## the live `_precipitation`, so the bridge needs no weather state of its own and
## this study stores nothing the sky does not already own.
func _physics_process(delta: float) -> void:
	if bridge == null or not bridge.has_method("apply_wind"): return
	var sky := _precipitation
	var weather: RefCounted = sky.surface_weather
	# The storm dial deepens the gusting as well as raising the mean: the
	# difference between a breeze and a squall is mostly in the variance.
	var storm: float = clampf(sky.state.w, 0.0, 1.0)
	var dial: float = clampf(float(sky.wind), 0.0, WIND_FULL * 1.4)
	_felt_wind = lerpf(_felt_wind, dial, 1.0 - exp(-delta * WIND_RESPONSE))
	_gust_clock += delta
	var gust := 1.0 + (GUST_DEPTH + GUST_STORM * storm) * _gusts.get_noise_1d(_gust_clock * GUST_RATE)
	var accel := WIND_ACCEL * pow(_felt_wind / WIND_FULL, WIND_EXPONENT) * maxf(0.0, gust)
	# The sky's own air angle. Only the part of it across the span bows the deck;
	# the rest pulls along a rope with its linear axes locked and does nothing.
	var angle: float = _atmosphere._air_angle
	bridge.apply_wind(Vector3(cos(angle), 0.0, sin(angle)), accel)
	bridge.apply_weather(maxf(weather.ground_wet, sky.state.x) * (1.0 - weather.snow_phase), weather.snow_cover, weather.ice)

## A strike close enough to be felt in the rope. Lightning already lights the
## whole world, so all this adds is the flick that runs off down the deck.
func _strike_near_deck(point: Vector3) -> void:
	if bridge == null or not bridge.has_method("jolt"): return
	var nearest := INF
	var at := point
	for step in range(11):
		var on_deck: Vector3 = bridge.deck_point(float(step) / 10.0)
		var gap := on_deck.distance_to(point)
		if gap < nearest:
			nearest = gap
			at = on_deck
	if nearest > STRIKE_REACH: return
	# A near miss is a shove; a hit on the deck itself is a crack.
	bridge.jolt(at, 1.0 - 0.6 * nearest / STRIKE_REACH)
	print("TWIN CHUNKS lightning %.1f m from the deck: the rope takes it" % nearest)

# --------------------------------------------------------------- the props

## Where the deck's walking surface really is at `t`: the bridge's own answer
## when there is a real one, and the study's stand-in catenary otherwise.
func deck_surface(t: float) -> Vector3:
	if bridge != null and bridge.has_method("deck_point"): return bridge.deck_point(t)
	return deck_point(t)

## A rock thrown at the deck at `t`, the same prop the player can pick up and
## throw anywhere else in the world. It is meant to land, roll with the sway and
## slide toward the middle, so nothing here holds it in place.
func throw_rock(t: float, sideways := 0.0) -> RigidBody3D:
	var rock: RigidBody3D = preload("res://scripts/play_loose_body.gd").new()
	var ball := SphereMesh.new()
	ball.radius = 0.2
	ball.height = 0.4
	ball.radial_segments = 8
	ball.rings = 4
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.44, 0.42, 0.39)
	skin.roughness = 1.0
	add_child(rock)
	rock.setup("stone", ball, skin)
	var lateral := bridge_anchors()[0].basis.x if bridge_anchors().size() == 2 else Vector3.RIGHT
	rock.global_position = deck_surface(t) + Vector3.UP * THROW_HEIGHT + lateral * sideways
	rock.linear_velocity = Vector3.DOWN * THROW_SPEED
	# A plank deck is ruts, gaps and proud nail heads, and the collision slab
	# under it is a smooth box: a ball left on that box rolls off the open side
	# inside two seconds. The roughness the planks would give it goes in as
	# rolling resistance on the rock, here in the study rather than in the
	# bridge, because it is a property of what is being dropped.
	rock.angular_damp = ROCK_ROLL_DAMP
	rock.linear_damp = ROCK_SLIDE_DAMP
	rock.sleeping = false
	_rocks.append(rock)
	while _rocks.size() > ROCK_LIMIT:
		var oldest: RigidBody3D = _rocks.pop_front()
		if is_instance_valid(oldest): oldest.queue_free()
	return rock

# -------------------------------------------------------------- the camera

## Both islands and the chasm, from the side so they spread across the frame.
func _frame_wide() -> void:
	var centre := _base.origin
	target = centre + Vector3(chunk_spacing(), SECOND_CHUNK_LIFT, 0.0) * 0.5
	distance = layout_width() * WIDE_FIT
	polar = WIDE_POLAR
	yaw = 0.0
	_auto_orbit = false
	_update_camera()

## Low and close, sighted down the deck. Aimed at the near anchor from beyond
## the far one rather than the other way round: the ground behind either bridge
## head is forest, and at this distance a camera standing there sees nothing but
## trunks, while a camera over the far rim looks back along the whole span.
func frame_bridge() -> void:
	var anchors := bridge_anchors()
	if anchors.size() != 2:
		return
	var a := anchors[0].origin
	var b := anchors[1].origin
	var direction := (b - a).normalized()
	target = a + Vector3.UP * 1.0
	distance = a.distance_to(b) * BRIDGE_FIT
	polar = BRIDGE_POLAR
	yaw = atan2(direction.x, direction.z)
	_auto_orbit = false
	_update_camera()

## Standing on the middle of the deck, looking down the span into the drop.
## `_update_camera` derives the camera from `target`, so the pose is expressed
## backwards: pick where the camera must stand and which way it must look, then
## put the target out along that look direction.
func frame_chasm() -> void:
	var anchors := bridge_anchors()
	if anchors.size() != 2:
		return
	var stand := deck_point(0.5) + Vector3.UP * CHASM_EYE
	_look_from(stand, (anchors[1].origin + Vector3.UP * 2.0 - stand).normalized(), CHASM_REACH)

## The drop, from beside the mid-deck. See `VOID_EYE` for why the literal
## straight-down version is impossible here: this stands off to the side of
## and above the mid-deck and sights four fifths of the way across, so the deck
## climbs out of the drop toward the far island and the bottom of frame is void.
func frame_void() -> void:
	var anchors := bridge_anchors()
	if anchors.size() != 2:
		return
	var sag := anchors[0].origin.distance_to(anchors[1].origin) * DECK_SAG
	var stand := deck_point(0.5) + Vector3.UP * sag * VOID_EYE + anchors[0].basis.x * sag * VOID_OFFSET
	_look_from(stand, (deck_point(VOID_SIGHT) - stand).normalized(), CHASM_REACH)

## `_update_camera` derives the camera from `target`, so a shot that wants the
## camera at a particular place is expressed backwards: choose where to stand
## and which way to look, then put the target out along that look direction.
func _look_from(stand: Vector3, look: Vector3, reach: float) -> void:
	distance = reach
	polar = acos(clampf(-look.y, -1.0, 1.0))
	yaw = atan2(-look.x, -look.z)
	target = stand + look * reach
	_auto_orbit = false
	_update_camera()

## Where the second island is placed, in world space. A property of the layout,
## not of what happens to be standing there, so it stays true when a generated
## landscape replaces the copy.
func second_chunk_centre() -> Vector3:
	return _placement * _base.origin

func _reset_camera(reference_pose := false) -> void:
	# The base framing search walks only the real chunk, so `R` would snap back
	# to one island. Keep the two-island establishing shot instead.
	if reference_pose or not second_chunk_ready:
		super._reset_camera(reference_pose)
		return
	_frame_wide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# These override base-study bindings on purpose: `B` summoned Bigfoot and
		# `N` stepped the hour, `T` shook the ground and `G` sent a wind puff --
		# and in a study whose wind comes from the preset every tick, a decorative
		# puff is worth less than a rock on the deck. `M` was unbound.
		if event.keycode == KEY_B:
			frame_bridge()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_N:
			frame_chasm()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_M:
			frame_void()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_T:
			throw_rock(0.5)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_G:
			for i in range(3):
				throw_rock(0.42 + 0.08 * float(i), (float(i) - 1.0) * THROW_SPREAD)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)
