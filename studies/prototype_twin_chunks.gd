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
##   `C`  the camp on the far island, from the chasm side
##   `X`  sends Bigfoot across the bridge to the far camp, now
##   `V`  sends a camper across the bridge to chunk one, now
##
## The far island has campers. A tent, its resident and a few fallen branches
## go into the grown island's own document, and `campsite_life.gd` runs them
## over a navigation grid built on that island (`CampsiteWorld.for_island`).
## The campers gather wood, stack it by the tent and explore. See `_settle_camp`.
##
## The two grounds are joined by a `CrossingRoute` (`scripts/crossing_route.gd`),
## built here from the two bridgeheads and the live deck, and handed to the far
## camp. Through it Bigfoot walks over to raid an unattended tent and walks back,
## and a camper with a full wood pile goes to look at chunk one. While he is on
## the island the island's `CampsiteWorld.resident` is him, so the campers see,
## flee from and photograph him with no further change. See `_wire_crossing` and
## `docs/campsite-life/README.md`.
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
## `_reachable_head` answers, keyed by rim spot. The search asks each candidate
## up to six times and every answer is two A* queries.
var _reach_cache := {}
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
	island_camps = null  ## Goes with the island it hangs off.
	camp_id = -1
	if second_chunk != null:
		remove_child(second_chunk)
		second_chunk.queue_free()
	second_chunk = await _build_second_chunk()
	add_child(second_chunk)
	# Before the anchor search: the tent is an obstacle a bridgehead avoids.
	_settle_camp(second_chunk)
	_anchors.clear()  ## A new island means a new rim to look for anchors on.
	_obstacle_cache.clear()
	_reach_cache.clear()
	_place_bridge()
	if _cleared_for_bridge:
		_cleared_for_bridge = false
		_refresh_habitat(false)
	_clear_trail()
	_wire_crossing()

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
			# A bridgehead the creatures' own grid cannot reach is a bridge
			# nobody walks. Dropped at the same relaxation as walkability: past
			# that point the search is already settling for a crossing that may
			# dead-end, and this is the same complaint in stronger terms.
			var reachable := _reachable_head(near, false) and _reachable_head(far, true)
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
			var cost := float(blockers.size()) * 10.0 + step_up + (0.0 if reachable else 100.0)
			if best.is_empty() or cost < float(best.cost):
				best = {"a": a, "b": b, "z": z, "step": step_up, "roughness": roughness, "cost": cost, "blockers": blockers, "reachable": reachable}
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
		# `fidelity_habitat.gd` reads exactly this geometry, so until chunk one's
		# habitat is read again its grid still walls off the step-off and no
		# walker can reach the deck at all. Raised here, acted on in
		# `rebuild_second_chunk` -- this runs inside the anchor search, which is
		# called from half a dozen places and must stay cheap and idempotent.
		_cleared_for_bridge = not movable.is_empty()
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

## How near the bridgehead the grid's nearest safe node has to be before the two
## count as the same place, in metres.
const ANCHOR_GRID_REACH := 1.5

## Can a walker already living on this island get to this bridgehead? The
## anchor search's own walkability test is a pair of ground rays down the
## approach; this is the question the creatures actually answer at every step --
## `creature_navigation.gd`, with its clearance, its slope limit and its water --
## and it is the one that decides whether the crossing is ever used. Cached per
## rim spot: A* over two grids for every candidate is the expensive part of the
## search.
func _reachable_head(world_xz: Vector2, second: bool) -> bool:
	var world: CampsiteWorld = island_world if second else (camps.world if camps != null else null)
	if world == null or world.navigation == null or world.navigation.rebuilding:
		return true  ## No grid to ask; the ray test is the only opinion available.
	var key := "%s:%.1f" % ["far" if second else "near", world_xz.y]
	if _reach_cache.has(key):
		return bool(_reach_cache[key])
	var wanted: Vector3 = world.to_local(Vector3(world_xz.x, 0.0, world_xz.y))
	var heart: Variant = _grid_heart(world, second)
	var head: Variant = world.navigation.nearest_safe(wanted)
	var reachable := false
	if heart is Vector3 and head is Vector3 and Vector2(head.x - wanted.x, head.z - wanted.z).length() < ANCHOR_GRID_REACH:
		reachable = not world.navigation.path(heart, head).is_empty()
	_reach_cache[key] = reachable
	return reachable

## Somewhere a walker already stands on this ground, to path from: Bigfoot on
## chunk one, the tent door on the island.
func _grid_heart(world: CampsiteWorld, second: bool) -> Variant:
	if not second:
		return world.navigation.nearest_safe(world.to_local(creature.global_position)) if creature != null else null
	if island_camps != null and island_camps.camps.has(camp_id) and island_camps.camps[camp_id].home != null:
		return island_camps.camps[camp_id].home
	return world.navigation.nearest_safe(Vector3.ZERO)

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

## How wide a trail to the bridge is cleared, in metres, and how many rounds of
## clearing-then-reading-the-habitat it is worth.
const TRAIL_WIDTH := 1.4
const TRAIL_ROUNDS := 3
## Near enough. The last stride onto the boards is off the grid anyway -- the
## rim is where `_safe_grounded` stops answering -- so a trail that gets the
## walkers this close to the bridgehead has done its job, and clearing more
## scenery to satisfy the grid would take the forest with it.
const TRAIL_DONE := 4.0
## Grid nodes near the bridgehead tested for a way home before the trail gives
## up. Each is an A* query over about fifteen hundred nodes, and the pocket a
## walled-off bridgehead sits in is a few hundred of them at 0.35 m spacing.
const TRAIL_PROBES := 600

## A bridge has a path to it.
##
## The bridgehead search clears whatever stands on the step-off and the first
## `ANCHOR_APPROACH` metres inland, but chunk one is dense forest and the
## creatures' own grid can still be walled off a stride or two further in. That
## is the failure the anchor search exists to avoid, stated in the only terms
## that matter once a navigation grid exists: on the default world the rim spot
## it picks is safe ground in a pocket of trees, and every walker on the island
## is on the far side of them.
##
## So: find the ground the walkers can already reach that lies nearest the
## bridgehead, fold away the scenery standing between it and the deck, read the
## habitat again, and repeat while it helps. Scenery only, no terrain document
## changes -- the same clearing `_clear_obstacles` does, along a line instead of
## around a point. True when the bridgehead is reachable at the end of it.
func _clear_trail() -> bool:
	var world: CampsiteWorld = camps.world if camps != null else null
	if world == null or world.navigation == null or creature == null:
		return false
	var anchors := bridge_anchors()
	if anchors.size() != 2:
		return false
	var head_at: Vector3 = world.to_local(anchors[0].origin)
	for attempt in range(TRAIL_ROUNDS):
		var navigation: RefCounted = world.navigation
		var heart: Variant = navigation.nearest_safe(world.to_local(creature.global_position))
		var head: Variant = navigation.nearest_safe(head_at)
		if not heart is Vector3 or not head is Vector3:
			push_warning("twin chunks: no safe ground at the bridgehead to make a trail to")
			return false
		var reached: Variant = _nearest_reached(navigation, heart, head)
		if not reached is Vector3:
			push_warning("twin chunks: nothing the creatures can reach lies anywhere near the bridgehead")
			return false
		var gap: float = reached.distance_to(head)
		if gap <= TRAIL_DONE:
			print("TWIN CHUNKS trail: the walkers reach within %.1f m of the bridgehead after %d clearing(s)" % [gap, attempt])
			return true
		var from_at: Vector3 = world.to_world(reached)
		var trail := _trail_blockers(Vector2(from_at.x, from_at.z), Vector2(anchors[0].origin.x, anchors[0].origin.z))
		if trail.is_empty():
			push_warning("twin chunks: the way to the bridgehead is ground, not scenery; no trail to clear")
			return false
		_clear_obstacles(trail)
		print("TWIN CHUNKS trail: %.1f m short; cleared %d things between local (%.1f, %.1f) and the bridgehead" % [gap, trail.size(), reached.x, reached.z])
		_refresh_habitat(false)
	push_warning("twin chunks: the bridgehead stays walled off after %d clearings" % TRAIL_ROUNDS)
	return false

## The nearest node to the bridgehead that a walker at `heart` can actually get
## to. Null when the pocket round the bridgehead is bigger than `TRAIL_PROBES`.
func _nearest_reached(navigation: RefCounted, heart: Vector3, head: Vector3) -> Variant:
	var nodes: Array[Vector3] = []
	for node in navigation._nodes:
		nodes.append(node)
	nodes.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(head) < b.distance_squared_to(head))
	for i in range(mini(TRAIL_PROBES, nodes.size())):
		if not navigation.path(heart, nodes[i]).is_empty():
			return nodes[i]
	return null

## Scenery standing on the line between the reachable ground and the bridgehead.
func _trail_blockers(from_xz: Vector2, to_xz: Vector2) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for obstacle in _obstacles(false):
		if obstacle.fixed:
			continue
		var xz: Vector2 = obstacle.xz
		if xz.distance_to(Geometry2D.get_closest_point_to_segment(xz, from_xz, to_xz)) < TRAIL_WIDTH + float(obstacle.radius) * 0.5:
			hits.append(obstacle)
	return hits

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

# ----------------------------------------------------------------- the camp

## Where the tent would like to stand, island-local. The far island is turned
## 180 degrees, so its local +X is the rim facing the chasm: the camp sits on
## that half, a little off centre, so the crossing looks across at a lit tent.
const CAMP_NEAR := Vector2(2.0, 0.0)
## Where a tent may stand at all, island-local. Its far edge stops short of
## the bridgehead's approach, which comes in from the +X rim at 14, so the
## anchor search never has to clear the camp away.
const CAMP_SEARCH := Rect2(-6.0, -10.0, 12.0, 20.0)
const CAMP_STEP := 1.0
## Ground spread across the pegs, the door and the first stride out of it,
## with the door turned whichever of four ways lies flattest. On the valley
## island the floor is a strip along Z: a door up the wall fails, a door along
## the strip is a hand's breadth of rise.
const CAMP_FLATNESS := 0.4
## Which way the door faces when the ground gives no reason to prefer one:
## +X, toward the chasm, so the crossing looks straight into the camp.
const CAMP_DOOR := PI * 0.5
const CAMP_HEADINGS := [PI * 0.5, 0.0, PI, -PI * 0.5]
## The tent's own half extents (`native_play_collisions.gd`), so a footprint is
## measured where the pegs really go.
const TENT_HALF := Vector2(1.15, 1.18)
## No trunk or boulder edge this close to the tent's centre: the half width
## and a stride of margin. Flowers, ferns and grass do not count; a tent goes
## down on top of those. Measured on the valley island: at 2.6 m no spot on
## the floor is clear, at 1.6 m several are.
const CAMP_CLEARANCE := 1.6
const CAMP_SOFT := ["flower", "fern", "leaf_bed", "bank_grass", "button_flower", "spike_flower", "umbel_flower", "daisy_flower", "grass_tuft", "mushroom", "reeds"]
## Fallen branches for the resident to go out for: how many, how far from the
## door, how far from one another, and the longest walk the grid may route to
## one. Candidates on three rings round the door, the shortest walks first --
## inside the 11 m the camper will go, and the walk cap keeps a branch four
## metres away from being a thirty-metre detour round the tent and the
## boulders, which is what the valley floor first produced.
const CAMP_BRANCHES := 4
const BRANCH_RINGS := [3.0, 4.5, 6.0, 7.5]
const BRANCH_SPACING := 2.5
const BRANCH_WALK := 18.0
## A branch is a small prop: it lies this close to a trunk or boulder edge,
## and its ring point may be nudged this far onto walkable ground.
const BRANCH_CLEARANCE := 0.8
const BRANCH_NUDGE := 1.0
## The camp shot: from this far, preferring the chasm side and a low eye, but
## searched round the tent for a line the valley walls do not cut -- the
## first try at a fixed angle from the chasm put the camera inside the hill.
const CAMP_DISTANCE := 11.0
const CAMP_YAW := -PI * 0.5 + 0.55
const CAMP_POLARS := [1.1, 0.9, 0.7]
const CAMP_YAW_STEPS := 16
const CAMP_CANOPY := 6.0    ## How high a tree stands in the way of the shot.
## The camp on the far island, or null when the island is the stand-in copy or
## no clearing was found. Child of the island, so camper positions are in the
## island's own frame.
var island_camps: Node
var camp_id := -1
## Chunk one's ground, as the camps see it, and the far island's. Kept so the
## link has two stable ends: identity matters, `CrossingRoute.other()` compares
## the objects themselves.
var chunk_world: CampsiteWorld
var island_world: CampsiteWorld
## The bridge as a walkable link, or null while there is no camp to cross to.
var crossing: CrossingRoute
## The far camp has Bigfoot's legs. Read by `_refresh_habitat` and passed to
## chunk one's own camps controller, which is the one `fidelity_life` asks.
var _far_owns_bigfoot := false
## The anchor search folded scenery away at a bridgehead; chunk one's habitat
## has not been read since.
var _cleared_for_bridge := false

## A tent, its resident and a few branches on a freshly grown island. The
## stand-in copy shares chunk one's document and gets nothing.
func _settle_camp(island: Node3D) -> void:
	island_camps = null
	island_world = null
	camp_id = -1
	if not island is IslandBuilder:
		return
	var data: NativeTerrainData = island.data
	var pitch := _camp_spot(island)
	if pitch.is_empty():
		push_warning("twin chunks: no flat, dry clearing for a tent on the far island")
		return
	var spot: Vector2 = pitch.spot
	var heading: float = pitch.heading
	camp_id = data.place("campsite", spot, heading)
	if camp_id < 0:
		push_warning("twin chunks: the island's document refused the tent")
		return
	island_camps = preload("res://scripts/campsite_life.gd").new()
	island_camps.name = "Campers"
	island.add_child(island_camps)
	# The grid is built with the tent already in the document, so it is solid.
	var world := CampsiteWorld.for_island(island, self)
	var doorway := Vector2(sin(heading), cos(heading)) * 2.25
	var door: Variant = world.navigation.nearest_safe(Vector3(spot.x + doorway.x, 0.0, spot.y + doorway.y))
	var branches := 0
	if door == null:
		push_warning("twin chunks: the tent door opens onto nothing walkable")
	else:
		var candidates: Array[Dictionary] = []
		var refused := {"off the grid": 0, "wet": 0, "against a trunk": 0, "too far to walk": 0}
		for radius: float in BRANCH_RINGS:
			for step in range(12):
				var bearing := float(step) * TAU / 12.0 + radius
				var wanted: Vector3 = door + Vector3(sin(bearing), 0.0, cos(bearing)) * radius
				var foot: Variant = world.navigation.nearest_safe(wanted)
				if foot == null or foot.distance_to(wanted) > BRANCH_NUDGE:
					refused["off the grid"] += 1
					continue
				var xz := Vector2(foot.x, foot.z)
				if island.flooded_at(xz):
					refused["wet"] += 1
					continue
				if not _clear_of_records(data, xz, BRANCH_CLEARANCE):
					refused["against a trunk"] += 1
					continue
				var walk := _walk_length(world.navigation.path(door, foot))
				if walk > BRANCH_WALK:
					refused["too far to walk"] += 1
					continue
				candidates.append({"foot": foot, "bearing": bearing, "walk": walk})
		print("TWIN CHUNKS branch spots: %d fine, refused %s" % [candidates.size(), refused])
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.walk) < float(b.walk))
		var placed: Array[Vector3] = []
		for candidate in candidates:
			if placed.size() >= CAMP_BRANCHES:
				break
			var foot: Vector3 = candidate.foot
			var crowded := false
			for other in placed:
				if other.distance_to(foot) < BRANCH_SPACING:
					crowded = true
			if crowded or data.place("fallen_branch", Vector2(foot.x, foot.z), float(candidate.bearing)) < 0:
				continue
			placed.append(foot)
		branches = placed.size()
	island.landmarks.rebuild(data)
	island_world = world
	island_camps.bind(world)
	print("TWIN CHUNKS camp on the far island at (%.1f, %.1f) island-local, door at %.0f degrees, %d branches to gather" % [spot.x, spot.y, rad_to_deg(heading), branches])

## The flattest dry clearing nearest `CAMP_NEAR`, as `{spot, heading}`; empty
## when the island offers none.
func _camp_spot(island: IslandBuilder) -> Dictionary:
	var best := {}
	var best_cost := INF
	var x := CAMP_SEARCH.position.x
	while x <= CAMP_SEARCH.end.x + 0.001:
		var z := CAMP_SEARCH.position.y
		while z <= CAMP_SEARCH.end.y + 0.001:
			var point := Vector2(x, z)
			if _clear_of_records(island.data, point, CAMP_CLEARANCE):
				for heading: float in CAMP_HEADINGS:
					var spread := _camp_spread(island, point, heading)
					if spread > CAMP_FLATNESS:
						continue
					# A metre of distance is worth a hand's breadth of rise; the
					# chasm-facing door wins a tie.
					var cost := point.distance_to(CAMP_NEAR) + spread * 4.0 + (0.0 if heading == CAMP_DOOR else 0.1)
					if cost < best_cost:
						best_cost = cost
						best = {"spot": point, "heading": heading}
			z += CAMP_STEP
		x += CAMP_STEP
	return best

## Ground spread across the pegs, the door and the first stride out of it, or
## INF where any of those is off the island or under water.
func _camp_spread(island: IslandBuilder, point: Vector2, heading: float) -> float:
	var door := Vector2(sin(heading), cos(heading))
	var low := INF
	var high := -INF
	for offset: Vector2 in [Vector2.ZERO, TENT_HALF, -TENT_HALF, Vector2(TENT_HALF.x, -TENT_HALF.y), Vector2(-TENT_HALF.x, TENT_HALF.y), door * 2.3, door * 3.3]:
		var at := point + offset
		var height: Variant = island.data.ground_height(at)
		if height == null or island.flooded_at(at):
			return INF
		low = minf(low, float(height))
		high = maxf(high, float(height))
	return high - low

## Metres along a route; INF for no route at all.
func _walk_length(route: PackedVector3Array) -> float:
	if route.is_empty():
		return INF
	var length := 0.0
	for i in range(1, route.size()):
		length += route[i - 1].distance_to(route[i])
	return length

func _clear_of_records(data: NativeTerrainData, point: Vector2, reach: float) -> bool:
	for item: Dictionary in data.objects:
		if item.asset in CAMP_SOFT:
			continue
		if Vector2(float(item.x), float(item.z)).distance_to(point) < reach + 0.5 * float(item.scale):
			return false
	return true

# ------------------------------------------------------------ the crossing

## Join the two grounds. Chunk one's end is the `CampsiteWorld` its own camps
## controller already holds, not a fresh copy: `CrossingRoute.other()` compares
## the objects, so there has to be exactly one of each.
func _wire_crossing() -> void:
	crossing = null
	chunk_world = camps.world if camps != null else null
	if island_camps == null or island_world == null or chunk_world == null: return
	crossing = CrossingRoute.link(chunk_world, island_world, bridge_anchors(), deck_surface)
	island_camps.crossing = crossing
	if camps != null: camps.crossing = crossing
	if crossing == null:
		push_warning("twin chunks: no bridge to cross")
		return
	print("TWIN CHUNKS crossing: %.1f m of deck joins chunk one to the island camp" % crossing.span())

## `X`: Bigfoot goes now, whatever the tent is doing.
func send_bigfoot_across() -> bool:
	if island_camps == null: return false
	var sent: bool = island_camps.send_bigfoot_across()
	print("TWIN CHUNKS Bigfoot crossing: %s" % ("on his way" if sent else "no route, or he is busy"))
	return sent

## `V`: a camper goes now.
func send_camper_across() -> bool:
	if island_camps == null: return false
	var sent: bool = island_camps.send_camper_across()
	print("TWIN CHUNKS camper crossing: %s" % ("on the way" if sent else "no route, or already away"))
	return sent

## The tent, from the clearest angle nearest the chasm side.
func frame_camp() -> void:
	if island_camps == null or camp_id < 0:
		return
	var record: Dictionary = second_chunk.data.object_by_id(camp_id)
	if record.is_empty():
		return
	var tent: Vector3 = global_transform.affine_inverse() * second_chunk.global_transform * second_chunk.data.object_position(record)
	target = tent + Vector3.UP * 0.9
	distance = CAMP_DISTANCE
	var trees: Array[Dictionary] = _obstacles(true)
	var best := INF
	for elevation: float in CAMP_POLARS:
		for i in range(CAMP_YAW_STEPS):
			var angle: float = CAMP_YAW + float(i) * TAU / float(CAMP_YAW_STEPS)
			var view := target + Vector3(sin(elevation) * sin(angle), cos(elevation), sin(elevation) * cos(angle)) * distance
			var score := 0.0
			# Every sample from the tent out to the eye must clear the ground,
			# and should not pass through a trunk or its canopy either.
			for sample in range(1, 25):
				var point := target.lerp(view, float(sample) / 24.0)
				var ground: Variant = ground_y_at(Vector2(point.x, point.z), true)
				if ground != null and float(ground) > point.y - 0.4:
					score += 10.0
				if ground != null and point.y < float(ground) + CAMP_CANOPY:
					for tree in trees:
						if Vector2(point.x, point.z).distance_to(tree.xz) < float(tree.radius) + 0.5:
							score += 3.0
							break
			score += absf(angle_difference(CAMP_YAW, angle)) * 0.5 + (1.1 - elevation)
			if score < best:
				best = score
				yaw = angle
				polar = elevation
	_auto_orbit = false
	_update_camera()

func _process(delta: float) -> void:
	# Before the base study's tick, not after: `fidelity_life._process` asks
	# chunk one's camps controller whether a camp owns Bigfoot, and on a frame
	# where the far camp has him walking the deck the answer has to be in
	# already -- otherwise the brain drives him off the bridge and the crossing
	# drives him back on, in the same frame.
	if island_camps != null and is_instance_valid(island_camps):
		_far_owns_bigfoot = island_camps.advance(delta)
	else:
		_far_owns_bigfoot = false
	if camps != null: camps.borrowed = _far_owns_bigfoot
	super._process(delta)

## Chunk one's grid calls his feet unsafe the moment he is on the deck or the
## far island, and a rebuild would snatch him home. `blast_airborne` is the
## existing "he is not standing on this ground right now" flag, so the rebuild
## happens and the walker is left alone.
func _refresh_habitat(budgeted := false) -> void:
	if not _far_owns_bigfoot or creature == null:
		super._refresh_habitat(budgeted)
		return
	var grounded := creature.blast_airborne
	creature.blast_airborne = true
	super._refresh_habitat(budgeted)
	creature.blast_airborne = grounded

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
		if event.keycode == KEY_C:
			frame_camp()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_X:
			send_bigfoot_across()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_V:
			send_camper_across()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)
