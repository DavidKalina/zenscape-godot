extends SceneTree
## The walk-test island (studies/walk_island.tscn), headless: it opens on one
## irregular sky island with mountains along it, trees and undergrowth on its
## land, and the pilot standing on its open ground in walk mode (not flying),
## drawn, facing the mountains, his wake through the foliage live.
##   godot --headless --path . --script tests/test_walk_island.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const TREES := ["tree","broadleaf","birch","juniper"]
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("walk island test timed out"); quit(2))
	var scene: Node3D = load("res://studies/walk_island.tscn").instantiate()
	scene.places_path = OS.get_temp_dir().path_join("walk-island-test-%d" % Time.get_ticks_usec()).path_join("places.json")
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not scene.walk_ready: await process_frame
	for i in range(30): await process_frame
	var eye: Node = scene.wanderer
	var data: NativeTerrainData = scene._chunk_editor.data
	check(scene.places_path.begins_with(OS.get_temp_dir()),"Its places are kept in the temp dir")
	check(not scene.has_meta("movie_capture") and scene.first_steps == null and not scene.titled,"No title, no first steps")
	# The island.
	check(not data.outline.is_empty() and data.outline.count(0) > 0,"The plate is an outlined island")
	var land := []
	for i in range(data.points.size()):
		if data.shore_distance[i] >= 0.0: land.append(data.heights[i])
	land.sort()
	var median: float = land[land.size()/2]
	var highest: float = land.back()
	check(data.land_area() > 700.0,"Room to walk: %.0f m² of land" % data.land_area())
	check(highest-median > 6.0,"Mountains: the highest ground %.1f m, the median %.1f m" % [highest,median])
	check((scene.island.summits as Array).size() == 3,"A ridge and two peaks raised along it")
	# Trees and undergrowth, on land.
	var counts := {}
	var off := 0
	for item: Dictionary in data.objects:
		counts[item.asset] = int(counts.get(item.asset,0))+1
		if not data.has_land(Vector2(item.x,item.z)): off += 1
	var trees := 0
	for kind in TREES: trees += int(counts.get(kind,0))
	var foliage: int = data.objects.size()-trees
	print("     objects: %s" % str(counts))
	check(trees >= 40,"Trees: %d" % trees)
	check(TREES.all(func(kind: String) -> bool: return counts.has(kind)),"Conifers, broadleaf, birch and juniper")
	check(foliage >= 150,"Undergrowth: %d" % foliage)
	check(["grass_tuft","fern","shrub","boulder_1"].all(func(kind: String) -> bool: return counts.has(kind)),"Grass, ferns, shrubs and boulders among it")
	check(counts.keys().any(func(kind: String) -> bool: return kind.ends_with("flower") or kind in ["buttercup","lupine"]),"And flowers")
	check(off == 0,"Every object stands on the island's land (%d off)" % off)
	check(not scene._chunk_editor.content._batches.is_empty(),"The objects are drawn (%d batches)" % scene._chunk_editor.content._batches.size())
	# The walker.
	check(eye.active and not eye.flying,"Walking, not flying")
	check(eye.has_figure() and eye.figure.is_visible_in_tree() and eye.body != null and eye.body.is_visible_in_tree(),"The pilot is drawn")
	# His wake through the undergrowth (scripts/pilot_wake.gd) is live at his feet.
	var wake: Node = eye.figure.get_node_or_null("Wake")
	var at: Vector3 = eye.figure.global_position
	check(wake != null and wake.published.size() > 0 and wake.published[0].z > 0.0 and Vector2(wake.published[0].x,wake.published[0].y).distance_to(Vector2(at.x,at.z)) < 0.05,"His wake parts the foliage at his feet")
	var feet: Vector3 = eye._feet
	check(data.has_land(Vector2(feet.x,feet.z)),"Standing on the island")
	check(absf(feet.y-float(data.ground_height(Vector2(feet.x,feet.z)))) < 0.2,"On its ground (%.2f m off)" % (feet.y-float(data.ground_height(Vector2(feet.x,feet.z)))))
	var toward: Vector2 = ((scene.island.spine as Vector2)-Vector2(feet.x,feet.z)).normalized()
	check(PilotMotor.forward(eye.motor.facing).dot(toward) > 0.8,"Facing the mountains")
	var start_h := float(data.ground_height(Vector2(feet.x,feet.z)))
	check(start_h < median+1.5,"On open low ground (%.1f m)" % start_h)
	print("PASS: walk island" if failures == 0 else "FAIL: walk island (%d)" % failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
