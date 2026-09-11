extends SceneTree
## Campers live on the far island of the twin-chunk study, on that island's own
## ground: the tent and its fallen branches are records in the island's
## document, the resident stands over the island and never over chunk one or
## the chasm, goes out for wood and brings it home, and Bigfoot is never taken by the
## far camp except by way of the bridge -- `tests/test_bridge_crossing.gd` owns
## the crossing itself.
##
## Instantiates the study, so it needs a real window and the native kernels.
## Never --headless: the fidelity scene hangs there.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tests/test_twin_campers.gd
const DT := 1.0 / 60.0
## Simulated frames allowed for one outing: the study caps a branch's route at
## 14 m, so at 0.7 m/s the walk is at most 40 s each way, plus the pick-up
## pause and the rests either side.
const OUTING_FRAMES := 7200
var failures := 0
var scene: Node3D

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
		push_error(message)

## A point under the island, in the study's own space, as `ground_y_at` asks.
func study_xz(island: Node3D, local: Vector3) -> Vector2:
	var at: Vector3 = scene.global_transform.affine_inverse() * island.global_transform * local
	return Vector2(at.x, at.z)

func run() -> void:
	create_timer(300).timeout.connect(func() -> void:
		print("FAIL: the study never finished")
		print("Failures: 1")
		quit(1))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(960, 600)
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	await scene.rebuild_second_chunk()
	# The study now opens with the bridge unbuilt; these want the finished deck.
	scene.set_bridge_built(true)
	# The test owns the clock from here.
	scene.set_process(false)

	# ------------------------------------------------------------ the camp
	var island: Node3D = scene.second_chunk
	check(island is IslandBuilder, "The far island is grown, so it owns a document to camp in")
	if not island is IslandBuilder:
		finish()
		return
	var data: NativeTerrainData = island.data
	check(scene.island_camps != null and scene.camp_id >= 0, "A tent stands on the far island")
	if scene.island_camps == null:
		finish()
		return
	var tent: Dictionary = data.object_by_id(scene.camp_id)
	check(tent.get("asset", "") == "campsite", "The tent is a campsite record in the island's own document")
	var branches := _branches(data)
	check(branches >= 1, "Fallen branches lie on the island to go out for: %d" % branches)
	var drawn: Node = island.landmarks.get_node_or_null("campsite_%d" % scene.camp_id)
	check(drawn != null, "The island's landmarks draw the tent")
	var parts_before: int = drawn.find_children("*", "MeshInstance3D", true, false).size() if drawn != null else 0
	var on_chunk_one := false
	for record in editor.data.objects:
		if record.asset in ["campsite", "fallen_branch"]:
			on_chunk_one = true
	check(not on_chunk_one, "Chunk one's document holds no tent and no branches")

	# ---------------------------------------------------------- the camper
	scene._process(DT)
	var camps: Node = scene.island_camps
	check(camps.camps.size() == 1, "One tent, one camper")
	if camps.camps.size() != 1:
		finish()
		return
	var entry: Dictionary = camps.camps[scene.camp_id]
	check(entry.home != null, "The tent door opens onto walkable ground")
	check(entry.actor.get_parent() == camps and camps.get_parent() == island, "The camper hangs off the island, in its frame")
	var feet := study_xz(island, entry.actor.position)
	check(scene.ground_y_at(feet, true) != null, "The camper stands over the far island's ground")
	check(scene.ground_y_at(feet, false) == null, "and not over chunk one")
	var him: Vector3 = scene.global_transform.affine_inverse() * scene.creature.global_position
	check(scene.ground_y_at(Vector2(him.x, him.z), false) != null, "Bigfoot stands on chunk one")

	# ---------------------------------------------------------- an outing
	var carried := false
	var delivered := false
	var strayed := false
	var frames := 0
	for frame in range(OUTING_FRAMES):
		scene._process(DT)
		frames = frame + 1
		if frame % 120 == 0:
			await process_frame
		if frame % 30 == 0 and scene.ground_y_at(study_xz(island, entry.actor.position), true) == null:
			strayed = true
		var record: Dictionary = data.object_by_id(scene.camp_id)
		if record.get("carrying", false):
			carried = true
		if int(record.get("wood", 0)) > 0:
			delivered = true
			break
	check(carried, "The camper picks up a fallen branch")
	check(delivered, "and carries it home to the pile, within %d frames" % frames)
	check(not strayed, "The camper never leaves the island")
	check(_branches(data) == branches - 1, "The gathered branch is gone from the island's document")
	drawn = island.landmarks.get_node_or_null("campsite_%d" % scene.camp_id)
	var parts_after: int = drawn.find_children("*", "MeshInstance3D", true, false).size() if drawn != null else 0
	check(parts_after > parts_before, "The island redraws the tent with wood on the pile (%d -> %d parts)" % [parts_before, parts_after])
	check(camps.bigfoot_activity.is_empty() or camps.bigfoot_home != null, "The far camp only ever takes Bigfoot by way of the bridge")
	check(camps.bigfoot_home == null, "and does not fetch him across during one outing")
	him = scene.global_transform.affine_inverse() * scene.creature.global_position
	check(scene.ground_y_at(Vector2(him.x, him.z), false) != null, "Bigfoot is still on chunk one")
	print("TWIN CAMPERS events: ", camps.events)
	finish()

func _branches(data: NativeTerrainData) -> int:
	var count := 0
	for record in data.objects:
		if record.asset == "fallen_branch":
			count += 1
	return count

func finish() -> void:
	print("Failures: %d" % failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
