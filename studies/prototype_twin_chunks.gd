extends "res://studies/fidelity.gd"
## Throwaway prototype: does a second island across a gap read as a world?
##
## The playable world is one 28 m chunk. This study leaves that chunk exactly as
## it is and hangs a purely visual copy of it 36 m along +X -- an 8 m rim-to-rim
## gap -- turned 180 degrees about its own centre so it does not read as a mirror
## and dropped `SECOND_CHUNK_LIFT` metres so the crossing is not perfectly level.
## A placeholder plank bridge joins the two facing rims so the pair reads as
## connected today; the moment `res://scripts/suspension_bridge.gd` exists this
## study instantiates that instead and calls `setup(a, b)` with the same anchors.
##
## The copy is scenery and nothing else. It is not registered with the chunk
## editor, owns no terrain document, no collision and no picking, so brush and
## pick rays -- which run in the first terrain's local space through
## `data.ray_hit` -- cannot reach it. Saves, fire, weather and the creature all
## still believe in one chunk, which is the point: this answers a feel question
## and is meant to be deleted.
##
## Keys: `B` re-frames onto the bridge (it overrides the base study's "summon
## Bigfoot"), `R` returns to the establishing two-island shot.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus res://studies/prototype_twin_chunks.tscn
## Stills and a walk clip come from `tools/film_twin_chunks.gd`.

## Centre-to-centre spacing of the two chunks along +X. The chunk is 28 m across,
## so 36 leaves the 8 m gap the bridge spans.
const CHUNK_SPACING := 36.0
## The chunk's half extent in terrain-local XZ. Hard-coded throughout the engine
## scripts too (native_terrain_data.gd clamps to +/-14).
const CHUNK_HALF := 14.0
## How far inside each rim an anchor stands.
const ANCHOR_INSET := 0.5
## The second island sits this much lower, so the deck slopes. Within +/-1.5.
const SECOND_CHUNK_LIFT := -0.9
## Candidate Z offsets for the anchor pair. Chunk two is turned 180 degrees, so a
## candidate `z` on chunk one sits directly across from `-z` on chunk two.
const ANCHOR_CANDIDATES: Array[float] = [-6.0, -4.5, -3.0, -1.5, 0.0, 1.5, 3.0, 4.5, 6.0]
## Ground spread tolerated across a 1 m cross at an anchor before it counts as
## too steep to stand a bridge head on.
const ANCHOR_FLATNESS := 0.45
const DECK_WIDTH := 1.0
const DECK_THICKNESS := 0.1
const RAIL_SIDE := 0.07
const RAIL_HEIGHT := 0.55
const DECK_COLOR := Color("6b4f32")   ## Oiled wood.
const RAIL_COLOR := Color("a8915f")   ## Hemp rope.
## The establishing shot: both islands and the gap between them, from the side.
const WIDE_DISTANCE := 64.0
const WIDE_POLAR := 1.12
const BRIDGE_DISTANCE := 12.0
const BRIDGE_POLAR := 1.24

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
	_build_second_chunk()
	_place_bridge()
	_frame_wide()
	second_chunk_ready = true
	get_window().title = "ZenScape prototype · Twin chunks"

## Rebuild the copy. Worth a second call once `_chunk_editor.refresh_pending`
## has drained, because authored content and landmarks publish asynchronously
## and are empty in a freshly opened study.
func rebuild_second_chunk() -> void:
	_build_second_chunk()
	_place_bridge()

# --------------------------------------------------------------- the copy

func _build_second_chunk() -> void:
	if second_chunk != null:
		remove_child(second_chunk)
		second_chunk.queue_free()
	_copied.clear()
	_skipped.clear()
	second_chunk = Node3D.new()
	second_chunk.name = "SecondChunk"
	# A marker so anything walking the tree can tell this is scenery, not world.
	second_chunk.set_meta("prototype_scenery", true)
	add_child(second_chunk)
	second_chunk.transform = _placement
	for node in $Reference.get_children():
		_copy_leaf(node)
	for node in _chunk_editor.content.get_children():
		_copy_leaf(node)
	for node in _chunk_editor.falls.get_children():
		_copy_leaf(node)
	# Landmarks are Node3D wrappers with a mesh subtree, so they copy whole.
	for node in _chunk_editor.landmarks.get_children():
		_copy_subtree(node)
	print("TWIN CHUNKS copied %d nodes, %d visual instances: %s" % [
		_copied.size(), visual_instance_count(), ", ".join(_copied)])
	print("TWIN CHUNKS skipped: %s" % ("nothing" if _skipped.is_empty() else ", ".join(_skipped)))

## One flat visual node: copied with its resources shared, its children dropped.
## The reference geometry's children are leaf meshes; the only child anyone adds
## is the editor's pond preview under `terrain`, which belongs to the real world.
func _copy_leaf(node: Node) -> void:
	if not _wanted(node):
		return
	var copy: Node3D = node.duplicate(0)
	for child in copy.get_children():
		copy.remove_child(child)
		child.queue_free()
	_adopt(copy, node)

## A wrapper node kept with its mesh subtree, for landmarks.
func _copy_subtree(node: Node) -> void:
	if node is not Node3D:
		_skipped.append("%s (not a Node3D)" % node.name)
		return
	if node.find_children("*", "VisualInstance3D", true, false).is_empty():
		_skipped.append("%s (no visuals)" % node.name)
		return
	_adopt(node.duplicate(0), node)

## `duplicate(0)` shares mesh and material resources rather than copying them, so
## the copy cannot drift in look from the original -- and costs no extra memory.
func _adopt(copy: Node3D, source: Node3D) -> void:
	copy.name = "Twin_" + source.name
	second_chunk.add_child(copy)
	# The copy's local pose is the source's pose in study-root space; SecondChunk's
	# own transform then carries it across the gap and turns it.
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
## +Z axes pointing at one another across the gap. Because the copy is turned
## 180 degrees, a candidate at terrain-local `z` faces the candidate at `-z`, so
## the pair is one search over `ANCHOR_CANDIDATES` for the smallest step up or
## down onto the far deck.
func bridge_anchors() -> Array[Transform3D]:
	if not _anchors.is_empty():
		return _anchors
	var inset := CHUNK_HALF - ANCHOR_INSET
	var best := {}
	# Three passes, each dropping one requirement, so a world whose whole rim is
	# steep or flooded still yields a crossing rather than nothing.
	for relaxation in range(3):
		for z: float in ANCHOR_CANDIDATES:
			var near := Vector2(inset, z)
			var far := Vector2(inset, -z)
			var near_y: Variant = _chunk_editor.data.ground_height(near)
			var far_y: Variant = _chunk_editor.data.ground_height(far)
			if near_y == null or far_y == null:
				continue
			if relaxation < 2 and (_in_water(near) or _in_water(far)):
				continue
			var roughness := maxf(_roughness(near), _roughness(far))
			if relaxation < 1 and roughness > ANCHOR_FLATNESS:
				continue
			var a := _base * Vector3(inset, float(near_y), z)
			var b := _mirror * Vector3(inset, float(far_y), -z)
			var step := absf(a.y - b.y)
			if best.is_empty() or step < float(best.step):
				best = {"a": a, "b": b, "z": z, "step": step, "roughness": roughness}
		if not best.is_empty():
			print("TWIN CHUNKS anchor search settled at relaxation %d" % relaxation)
			break
	if best.is_empty():
		push_error("twin chunks: no anchor pair on the facing rims")
		return _anchors
	var a: Vector3 = best.a
	var b: Vector3 = best.b
	_anchors = [Transform3D(_facing(b - a), a), Transform3D(_facing(a - b), b)]
	print("TWIN CHUNKS anchors at local z %+.1f: A (%.2f, %.2f, %.2f) -> B (%.2f, %.2f, %.2f); span %.2f m, horizontal %.2f m, step %.2f m, roughness %.2f" % [
		float(best.z), a.x, a.y, a.z, b.x, b.y, b.z, a.distance_to(b),
		Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)), float(best.step), float(best.roughness)])
	return _anchors

## +Z down `direction`, which is what a bridge head faces.
func _facing(direction: Vector3) -> Basis:
	var z := direction.normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, z.cross(x), z)

## Study-root Y of the ground under a world point, on either island. Null when
## the point is off that chunk. The test and the film tool aim with this.
func ground_y_at(point: Vector3, second := false) -> Variant:
	var pose := _mirror if second else _base
	var local := pose.affine_inverse() * point
	var height: Variant = _chunk_editor.data.ground_height(Vector2(local.x, local.z))
	if height == null:
		return null
	return (pose * Vector3(local.x, float(height), local.z)).y

## Height spread over the patch a bridge head actually stands on: the deck's
## width along the rim, and half a metre inland. Deliberately not sampled
## outward, because every island rim falls away there -- measuring the drop the
## bridge is there to cross would reject the whole rim.
func _roughness(point: Vector2) -> float:
	var low := INF
	var high := -INF
	var footprint: Array[Vector2] = [
		Vector2.ZERO, Vector2(-0.5, 0.0),
		Vector2(0.0, DECK_WIDTH * 0.5), Vector2(0.0, -DECK_WIDTH * 0.5),
		Vector2(-0.5, DECK_WIDTH * 0.5), Vector2(-0.5, -DECK_WIDTH * 0.5)]
	for offset: Vector2 in footprint:
		var probe := (point + offset).clamp(Vector2(-CHUNK_HALF, -CHUNK_HALF), Vector2(CHUNK_HALF, CHUNK_HALF))
		var height: Variant = _chunk_editor.data.ground_height(probe)
		if height == null:
			continue
		low = minf(low, float(height))
		high = maxf(high, float(height))
	return 0.0 if low > high else high - low

## The repo has no single water predicate; this is the idiom the water course,
## the falls and the navigation all use.
func _in_water(point: Vector2) -> bool:
	for pond: Dictionary in _chunk_editor.data.ponds:
		if GardenWater.covers(_chunk_editor.data.pond_surface(pond), point):
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
		bridge.setup(anchors[0], anchors[1])
		print("TWIN CHUNKS bridge: %s" % REAL)
		return
	bridge = _placeholder_bridge(anchors[0].origin, anchors[1].origin)
	add_child(bridge)
	print("TWIN CHUNKS bridge: placeholder deck, %.2f m long (no %s yet)" % [
		anchors[0].origin.distance_to(anchors[1].origin), REAL])

## A deck and two rails, enough that the eye reads the pair as joined.
func _placeholder_bridge(a: Vector3, b: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = "Bridge"
	var span := a.distance_to(b)
	node.transform = Transform3D(_facing(b - a), (a + b) * 0.5)
	node.add_child(_slab("Deck", Vector3(DECK_WIDTH, DECK_THICKNESS, span), Vector3(0.0, -DECK_THICKNESS * 0.5, 0.0), DECK_COLOR))
	for side: float in [-1.0, 1.0]:
		var rail := _slab("Rail%s" % ("L" if side < 0.0 else "R"),
			Vector3(RAIL_SIDE, RAIL_SIDE, span),
			Vector3(side * DECK_WIDTH * 0.5, RAIL_HEIGHT, 0.0), RAIL_COLOR)
		node.add_child(rail)
	return node

func _slab(slab_name: String, size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = slab_name
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = offset
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	node.material_override = material
	return node

# -------------------------------------------------------------- the camera

## Both islands and the gap, looked at from the side so they spread across frame.
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

## Centre of the copy, for a shot that shows it is a whole island.
func second_chunk_centre() -> Vector3:
	return _mirror.origin

func _reset_camera(reference_pose := false) -> void:
	# The base framing search walks only the real chunk, so `R` would snap back
	# to one island. Keep the two-island establishing shot instead.
	if reference_pose or not second_chunk_ready:
		super._reset_camera(reference_pose)
		return
	_frame_wide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		# Overrides the base study's summon-Bigfoot binding on purpose.
		frame_bridge()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
