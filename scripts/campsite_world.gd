class_name CampsiteWorld
extends RefCounted
## The ground a campsite stands on, as the campsite controller sees it.
##
## `campsite_life.gd` needs a terrain document to keep its records in, a
## navigation grid to walk, the planted geometry to test sightlines against,
## and -- where he lives -- the resident Bigfoot. On the playable chunk all of
## that hangs off the fidelity scene and its chunk editor. A generated island
## (`island_builder.gd`) carries its own document, content and landmarks and
## no editor, resident or undo history. This object is the one shape both
## take, so the controller never asks which it is standing on.
##
## Every position the controller handles is in the document's own frame: the
## terrain-local space of `data`. `frame` carries that into world space, which
## is only ever needed to bring scene nodes (lamps, batches) back into it.

var data: NativeTerrainData
## `creature_navigation.gd`, built over `data`. Untyped: it declares no class_name.
var navigation: RefCounted
## The planted batches and the placed landmarks, for sightlines.
var content: GardenView
var landmarks: NativeGardenLandmarks
## The imported reference trunks on chunk one. Null on an island, whose every
## tree is a record in `data`.
var reference: Node3D
## Document-local -> world.
var frame := Transform3D.IDENTITY
## The scene that owns Bigfoot (`creature`, `routine`, `brain`,
## `resident_enabled`), or null where he does not live. Campers on ground with
## no resident gather wood and explore, and never see anything.
var resident: Node
## -> bool. Held still and keep whatever the controller owns.
var paused: Callable
## -> bool. The ground is being rebuilt; wait for it.
var busy: Callable
## -> bool. Flashlights and lantern on.
var night: Callable
## Republish the visuals after a record changed (a branch picked up, wood
## stacked, a snack taken).
var refresh: Callable
## The clearance the island's navigation was built from; chunk one keeps its
## own in the scene.
var habitat: RefCounted

## The playable chunk: the fidelity scene's editor, navigation and resident.
static func for_scene(scene: Node) -> CampsiteWorld:
	var world := CampsiteWorld.new()
	var editor: NativeChunkEditor = scene._chunk_editor
	world.data = editor.data
	world.navigation = scene.navigation
	world.content = editor.content
	world.landmarks = editor.landmarks
	world.reference = scene.get_node_or_null("Reference")
	world.frame = editor.terrain.global_transform
	world.resident = scene
	world.paused = func() -> bool: return scene._paused or editor.active
	world.busy = func() -> bool: return scene.navigation.rebuilding or scene._habitat_changed or editor.forming
	world.night = func() -> bool: return scene._celestial.daylight < 0.2
	world.refresh = func() -> void: editor.refresh()
	return world

## A generated island: its own document and a navigation grid built here over
## it, the scene borrowed only for the clock and the pause. No resident.
## `island` must already be in the tree, so its frame is known.
static func for_island(island: IslandBuilder, scene: Node) -> CampsiteWorld:
	var world := CampsiteWorld.new()
	world.data = island.data
	world.content = island.content
	world.landmarks = island.landmarks
	world.frame = island.global_transform
	world.navigation = preload("res://scripts/creature_navigation.gd").new()
	world.habitat = preload("res://scripts/fidelity_habitat.gd").new()
	world.rebuild_navigation()
	var editor: NativeChunkEditor = scene._chunk_editor
	world.paused = func() -> bool: return scene._paused or editor.active
	world.busy = func() -> bool: return world.navigation.rebuilding
	world.night = func() -> bool: return scene._celestial.daylight < 0.2
	world.refresh = func() -> void: island.landmarks.rebuild(island.data)
	return world

## Rebuild an island's grid over its current records: the tent is a solid a
## walker goes round. Synchronous; an island is formed once, not brushed.
## (Chunk one's grid belongs to the scene and is rebuilt there, budgeted.)
func rebuild_navigation() -> void:
	if habitat == null: return
	# A preset island's document is `blank`, so the habitat reads only the
	# records and never touches reference geometry.
	habitat.setup(null, data)
	navigation.rebuild(habitat, habitat.clear_at, 0.35, 0.3)

## ------------------------------------------------------------- the frame
## Everything the controller handles is document-local; everything shared with
## another ground -- a bridge, a creature that walks off this one -- is world
## space. These two are the only conversion in the seam.
func to_world(point: Vector3) -> Vector3:
	return frame * point

func to_local(point: Vector3) -> Vector3:
	return frame.affine_inverse() * point

## The heightfield of this ground, asked and answered in world space, which is
## the shape `creature_actor.gd` wants for `_ground_probe`. Height only: safety
## is the navigation grid's business and a walker stepping off a bridge is
## already on ground the anchor search proved.
func ground_probe() -> Callable:
	return func(at: Vector3) -> Variant:
		if navigation == null: return null
		var grounded: Variant = navigation._ground(to_local(at))
		return to_world(grounded) if grounded is Vector3 else null

## Where Bigfoot stands, in this ground's own frame. He may be standing on a
## different island from the one that is asking, so his own `position` -- which
## is whatever his scene's frame says -- is never the answer.
func resident_point() -> Vector3:
	return to_local(resident.creature.global_position) if resident != null and resident.creature != null else Vector3.ZERO

func resident_active() -> bool:
	return resident != null and resident.resident_enabled

## Player ownership of Bigfoot (carried, thrown) outranks any camp outing.
func resident_owned() -> bool:
	return resident != null and resident.has_method("resident_activity_owned") and resident.resident_activity_owned()
