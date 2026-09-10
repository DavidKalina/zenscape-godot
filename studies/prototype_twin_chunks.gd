extends "res://studies/fidelity.gd"
## Throwaway prototype: does a second island across a chasm read as a world?
##
## The playable world is one 28 m chunk. This study leaves that chunk exactly as
## it is and hangs a purely visual copy of it 128 m along +X -- a 100 m
## rim-to-rim chasm -- turned 180 degrees about its own centre so it does not
## read as a mirror. Both islands float at the same height, so the deck is level
## anchor to anchor apart from whatever the two rims' own ground does.
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
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus res://studies/prototype_twin_chunks.tscn
## Stills and a walk clip come from `tools/film_twin_chunks.gd`.

## Centre-to-centre spacing of the two chunks along +X. The chunk is 28 m across,
## so 128 leaves the 100 m chasm the bridge spans.
const CHUNK_SPACING := 128.0
## The chunk's half extent in terrain-local XZ. Hard-coded throughout the engine
## scripts too (native_terrain_data.gd clamps to +/-14).
const CHUNK_HALF := 14.0
## How far inside each rim an anchor stands.
const ANCHOR_INSET := 0.5
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
## The establishing shot: both islands and the chasm, from the side. Sized by
## looking at it -- the pair is 156 m wide, and 152 m fills the frame's width
## with a margin at either rim. Slack above and below is unavoidable: a 156 m
## strip on a 16:10 frame leaves the sky empty however far back the camera goes.
const WIDE_DISTANCE := 152.0
const WIDE_POLAR := 1.12
## Chosen by looking at it. Far enough back to see the deck leave the island and
## fall away, close enough that the island is not a speck -- 115 m framed the
## whole span but shrank the world to a postage stamp, which answers nothing.
const BRIDGE_DISTANCE := 60.0
const BRIDGE_POLAR := 1.24
## Standing on the deck: eye height over the planks. `N` sights straight at the
## far bridgehead rather than at a fixed pitch, because from the sagging midspan
## the deck *rises* toward both ends -- any downward tilt looks into the boards.
const CHASM_EYE := 2.0
const CHASM_REACH := 40.0
## Sun shadow range, pushed past the far island's far corner as seen from the
## establishing camera (about 184 m). See `_reach_shadows()`.
const SHADOW_REACH := 260.0
## `M`, the vertigo shot. The geometry rules out the literal version: at midspan
## the deck hangs 13 m below both rims, so the far island's skirt sits *above*
## this camera, and a 38-degree lens cannot hold something 7 degrees up and
## something 40 degrees down in one frame. A straight-down look gets empty air
## and a plank edge -- both earlier attempts proved it.
##
## So the shot stands off and above the mid-deck and sights a point four fifths
## of the way across. The deck then sweeps up out of the drop toward the far
## island's underside in the top of frame, and the bottom half is the void, which
## is what the drop is supposed to feel like.
const VOID_EYE := 10.0
const VOID_OFFSET := 8.0
const VOID_SIGHT := 0.82

var second_chunk: Node3D
var bridge: Node3D
var second_chunk_ready := false
## Terrain-local -> study-root pose for chunk one and for its copy.
var _base := Transform3D.IDENTITY
var _mirror := Transform3D.IDENTITY
## Placement of the copy relative to the original, about the original's centre.
var _placement := Transform3D.IDENTITY
var _anchors: Array[Transform3D] = []
var _copied: Array[String] = []
var _skipped: Array[String] = []

func _ready() -> void:
	super._ready()
	_base = global_transform.affine_inverse() * _chunk_editor.terrain.global_transform
	var centre := _base.origin
	var rotation := Basis(Vector3.UP, PI)
	var offset := Vector3(CHUNK_SPACING, SECOND_CHUNK_LIFT, 0.0)
	# Turn about the chunk's own centre, then carry it across the gap.
	_placement = Transform3D(rotation, centre + offset - rotation * centre)
	_mirror = _placement * _base
	rebuild_second_chunk()
	_reach_shadows()
	_frame_wide()
	second_chunk_ready = true
	get_window().title = "ZenScape prototype · Twin chunks"

## `landscape_lighting.gd` sets the sun's shadow range to 130 m, which is the
## right number for a world 28 m across: at the one-chunk framing everything is
## well inside it. Two islands 128 m apart are not -- from the establishing
## camera most of both of them fall past 130 m and lose their shadows entirely,
## which is why the wide shot came back flat. Pushed out here, in the study, on
## the live lights; the shared default is left alone because it is correct for
## the game. The cost is shadow resolution spread over four times the range.
func _reach_shadows() -> void:
	for light: DirectionalLight3D in _lights:
		light.directional_shadow_max_distance = SHADOW_REACH

## Rebuild the copy. Worth a second call once `_chunk_editor.refresh_pending`
## has drained, because authored content and landmarks publish asynchronously
## and are empty in a freshly opened study.
func rebuild_second_chunk() -> void:
	if second_chunk != null:
		remove_child(second_chunk)
		second_chunk.queue_free()
	second_chunk = _build_second_chunk()
	add_child(second_chunk)
	_anchors.clear()  ## A new island means a new rim to look for anchors on.
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
	var near_x := _base.origin.x + CHUNK_HALF - ANCHOR_INSET
	var far_x := second_chunk_centre().x - CHUNK_HALF + ANCHOR_INSET
	var best := {}
	# Three passes, each dropping one requirement, so a world whose whole rim is
	# steep or flooded still yields a crossing rather than nothing.
	for relaxation in range(3):
		for step_index in range(int(ANCHOR_SEARCH_REACH * 2.0 / ANCHOR_SEARCH_STEP) + 1):
			var z := _base.origin.z - ANCHOR_SEARCH_REACH + float(step_index) * ANCHOR_SEARCH_STEP
			var near := Vector2(near_x, z)
			var far := Vector2(far_x, z)
			var near_y: Variant = ground_y_at(near, false)
			var far_y: Variant = ground_y_at(far, true)
			if near_y == null or far_y == null:
				continue
			if relaxation < 2 and (_in_water(near, false) or _in_water(far, true)):
				continue
			var roughness := maxf(_roughness(near, false), _roughness(far, true))
			if relaxation < 1 and roughness > ANCHOR_FLATNESS:
				continue
			var a := Vector3(near.x, float(near_y), near.y)
			var b := Vector3(far.x, float(far_y), far.y)
			var step_up := absf(a.y - b.y)
			if best.is_empty() or step_up < float(best.step):
				best = {"a": a, "b": b, "z": z, "step": step_up, "roughness": roughness}
		if not best.is_empty():
			print("TWIN CHUNKS anchor search settled at relaxation %d" % relaxation)
			break
	if best.is_empty():
		push_error("twin chunks: no anchor pair on the facing rims")
		return _anchors
	var a: Vector3 = best.a
	var b: Vector3 = best.b
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
		bridge.setup(anchors[0], anchors[1], {"sag": DECK_SAG})
		print("TWIN CHUNKS bridge: %s, sag %.2f" % [REAL, DECK_SAG])
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

# -------------------------------------------------------------- the camera

## Both islands and the chasm, from the side so they spread across the frame.
func _frame_wide() -> void:
	var centre := _base.origin
	target = centre + Vector3(CHUNK_SPACING, SECOND_CHUNK_LIFT, 0.0) * 0.5
	distance = WIDE_DISTANCE
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
	distance = BRIDGE_DISTANCE
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
	var stand := deck_point(0.5) + Vector3.UP * VOID_EYE + anchors[0].basis.x * VOID_OFFSET
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
		# `N` stepped the hour. `M` was unbound.
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
	super._unhandled_input(event)
