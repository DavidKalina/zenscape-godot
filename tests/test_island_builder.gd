extends SceneTree
## `scripts/island_builder.gd` grows whole islands beside the real chunk without
## disturbing it.
##
## Runs against the live fidelity scene rather than a stub, because the two
## claims worth testing are both about that scene: that an island comes out in
## the first chunk's own footprint with the first chunk's own ground material,
## and that building three of them leaves the first chunk's heights byte for
## byte where they were. A stub could not fail either way.
##
## Never --headless: the fidelity scene hangs there.
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tests/test_island_builder.gd
var failures := 0

## Small enough to open fast, large enough that the viewport and its buffers are
## real. Nothing here reads a pixel.
const FRAME_SIZE := Vector2i(960, 600)
## The chunk is 28 m across in both horizontal axes, exactly.
const FOOTPRINT := 28.0
const FOOTPRINT_TOLERANCE := 0.001
## Two islands on different seeds must be different landscapes, not reshuffled
## detail: a third of the chunk's shared vertices have to sit at a different height.
const DIVERGENCE := 0.30
## The imported chunk welds to this many unique XZ columns; both islands and the
## first chunk edit exactly these, which is why their height arrays compare.
const CHUNK_VERTICES := 2025
## Below this, two heights are the same cell as far as the eye is concerned.
const SAME_HEIGHT := 0.01

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(85).timeout.connect(func() -> void:
		print("FAIL: test timed out before it finished")
		quit(1))
	root.size = FRAME_SIZE
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	# The baseline the whole "the first chunk is untouched" claim rests on, taken
	# before any island exists. `duplicate()` because `heights` is a packed array
	# the editor goes on mutating in place.
	var before: PackedFloat32Array = editor.data.heights.duplicate()
	var before_recipe: Dictionary = editor.data._recipe_settings.duplicate(true)
	var before_objects: int = editor.data.objects.size()
	check(before.size() == CHUNK_VERTICES, "The first chunk starts with a full height field (%d vertices)" % before.size())

	# ------------------------------------------------------------ two islands
	var valley: Node3D = await IslandBuilder.build(scene, {"seed": 214, "preset": "valley"})
	var canyon: Node3D = await IslandBuilder.build(scene, {"seed": 408, "preset": "canyon"})
	for island: Node3D in [valley, canyon]:
		var label: String = island.describe()
		print("BUILD %s: %.0f ms · %s" % [label, island.build_usec / 1000.0, island.build_stage_usec])
		check(island.get_parent() == null, "%s comes back detached, for the caller to place" % label)

		var mesh: Mesh = island.terrain.mesh
		check(mesh != null, "%s has a terrain mesh" % label)
		var bounds: AABB = mesh.get_aabb()
		check(absf(bounds.size.x - FOOTPRINT) < FOOTPRINT_TOLERANCE
			and absf(bounds.size.z - FOOTPRINT) < FOOTPRINT_TOLERANCE,
			"%s keeps the chunk's 28 m footprint (%.3f x %.3f)" % [label, bounds.size.x, bounds.size.z])
		check(mesh.surface_get_material(0) == editor.data.source_mesh.surface_get_material(0),
			"%s draws its ground with the first chunk's own material, not a copy" % label)

		check(island.skirt != null and island.skirt.mesh != null, "%s has earth sides under it" % label)
		check(island.skirt.mesh.get_aabb().size.x > FOOTPRINT,
			"%s earth sides overhang the terrain rim (%.2f m)" % [label, island.skirt.mesh.get_aabb().size.x])

		var instances := _instances(island)
		check(island.data.objects.size() >= 40,
			"%s plants at least 40 props and plants (%d records)" % [label, island.data.objects.size()])
		check(instances >= 40,
			"%s renders those records as instances (%d)" % [label, instances])

		check(island.ground_height_at(Vector2.ZERO) != null,
			"%s reports ground at its own centre" % label)
		check(island.ground_height_at(Vector2(13.5, -13.5)) != null,
			"%s reports ground just inside its rim" % label)
		check(island.ground_height_at(Vector2(20.0, 0.0)) == null,
			"%s reports nothing off its edge" % label)
		check(island.ground_height_at(Vector2(0.0, 400.0)) == null,
			"%s reports nothing far away" % label)

	# ------------------------------------------------ two different landscapes
	var a: PackedFloat32Array = valley.data.heights
	var b: PackedFloat32Array = canyon.data.heights
	check(a.size() == b.size(), "Both islands share the chunk's triangulation (%d vs %d)" % [a.size(), b.size()])
	var moved := 0
	for i in range(mini(a.size(), b.size())):
		if absf(a[i] - b[i]) > SAME_HEIGHT:
			moved += 1
	var share := float(moved) / float(maxi(a.size(), 1))
	check(share >= DIVERGENCE,
		"Two seeds are two places, not one reshuffled: %.0f%% of cells differ (want %.0f%%)" % [
			share * 100.0, DIVERGENCE * 100.0])

	# ------------------------------------------ an island placed in the world
	valley.transform = Transform3D(Basis(Vector3.UP, 0.55), Vector3(40.0, -0.6, 0.0))
	scene.add_child(valley)
	var placed: Variant = valley.ground_height_at(Vector2(40.0, 0.0))
	check(placed != null, "A placed island reads its ground in world space")
	check(placed != null and absf(float(placed) + 0.6 - float(valley.data.ground_height(Vector2.ZERO))) < 0.001,
		"That world height is the local height carried by the island's own pose")
	check(valley.ground_height_at(Vector2.ZERO) == null,
		"A placed island reports nothing over the first chunk")

	# ---------------------------------------------- the first chunk is intact
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	check(editor.data.heights == before, "Building islands leaves the first chunk's heights byte-identical")
	check(editor.data._recipe_settings == before_recipe, "...and its terrain recipe untouched")
	check(editor.data.objects.size() == before_objects, "...and its own records unplaced (%d)" % before_objects)
	check(editor.data._undo.is_empty(), "...and no undo step pushed onto its history")

	canyon.free()
	scene.queue_free()
	await process_frame
	print("Failures: %d" % failures)
	quit(failures)

## Every instance the island actually draws: one per MultiMesh instance, one per
## standalone mesh. This is what the eye counts, which the record list is not --
## a tree is several parts and a meadow batch is hundreds of blades.
func _instances(island: Node3D) -> int:
	var total := 0
	for node: VisualInstance3D in island.find_children("*", "VisualInstance3D", true, false):
		if node is MultiMeshInstance3D:
			total += node.multimesh.instance_count if node.multimesh != null else 0
		elif node is MeshInstance3D and node.mesh != null and node != island.terrain and node != island.skirt:
			total += 1
	return total

func check(passed: bool, label: String) -> void:
	if passed:
		print("PASS: ", label)
		return
	failures += 1
	print("FAIL: ", label)
