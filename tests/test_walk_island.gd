extends SceneTree
## The walk-test island (studies/walk_island.tscn), headless: it opens on one
## irregular sky island with mountains along it, trees and undergrowth on its
## land, and the pilot standing on its open ground in walk mode (not flying),
## drawn, facing the mountains. Its rim is a ledge: walked slowly off it the
## pilot hangs from it (not flying), shimmies along it, climbs back up onto
## the land, and hanging again and pushed away lets go.
##   godot --headless --path . --script tests/test_walk_island.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotLedge = preload("res://scripts/pilot_ledge.gd")
const MOVES := [&"move_left",&"move_right",&"move_forward",&"move_back"]
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
	var feet: Vector3 = eye._feet
	check(data.has_land(Vector2(feet.x,feet.z)),"Standing on the island")
	check(absf(feet.y-float(data.ground_height(Vector2(feet.x,feet.z)))) < 0.2,"On its ground (%.2f m off)" % (feet.y-float(data.ground_height(Vector2(feet.x,feet.z)))))
	var toward: Vector2 = ((scene.island.spine as Vector2)-Vector2(feet.x,feet.z)).normalized()
	check(PilotMotor.forward(eye.motor.facing).dot(toward) > 0.8,"Facing the mountains")
	var start_h := float(data.ground_height(Vector2(feet.x,feet.z)))
	check(start_h < median+1.5,"On open low ground (%.1f m)" % start_h)
	await _ledge(scene,eye,data)
	print("PASS: walk island" if failures == 0 else "FAIL: walk island (%d)" % failures)
	scene.queue_free()
	for i in range(10): await process_frame
	quit(1 if failures else 0)

## The rim as a ledge, driven through the walker's own input.
func _ledge(scene: Node3D, eye: Node, data: NativeTerrainData) -> void:
	var motor: RefCounted = eye.motor
	var spot := _rim_spot(eye,data,(scene.island.start as Vector2))
	check(not spot.is_empty(),"A clear stretch of rim near the start")
	if spot.is_empty(): return
	var off := await _walk_off(eye,spot)
	check(off and motor.hold == "hang" and not eye.flying,"Walked slowly off the rim, the pilot hangs from it")
	if not off: return
	check(absf(motor.lip.y-float(data.ground_height(Vector2(motor.lip.x,motor.lip.z)+motor.lip_out*-0.05))) < 0.1,"From the rim's own height (%.2f m)" % motor.lip.y)
	var was := Vector2(motor.lip.x,motor.lip.z)
	for i in range(90):
		_push(eye,Vector2(motor.lip_out.y,-motor.lip_out.x),1.0)
		await process_frame
	var along: float = was.distance_to(Vector2(motor.lip.x,motor.lip.z))
	check(along > 0.3 and motor.hold == "hang" and not eye.flying,"Shimmies along it (%.2f m)" % along)
	var up := false
	for i in range(150):
		_push(eye,-motor.lip_out,1.0)
		await process_frame
		if motor.grounded and not motor.on_ledge():
			up = true
			break
	check(up and data.has_land(Vector2(motor.feet.x,motor.feet.z)) and not eye.flying,"Climbs back up onto the land")
	_push(eye,Vector2.ZERO,0.0)
	for i in range(20): await process_frame
	# Let go (the flight it would open is the plane's own business, so the
	# old plate clamp stands in for it here and sets him back on the land).
	off = await _walk_off(eye,spot)
	eye.glide_enabled = false
	var let_go := false
	for i in range(60):
		_push(eye,motor.lip_out,1.0)
		await process_frame
		if not motor.on_ledge():
			let_go = true
			break
	check(off and let_go and not eye.flying,"Hanging again and pushed away, he lets go")
	_push(eye,Vector2.ZERO,0.0)
	eye.glide_enabled = true

## A point a metre in from the rim near `near`, the lip found square off it
## and nothing standing between: {"at", "out"}, or {}.
func _rim_spot(eye: Node, data: NativeTerrainData, near: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for i in range(data.points.size()):
		var d := data.shore_distance[i]
		if d < 0.1 or d > 0.35 or data.ground_height(data.points[i]) == null: continue
		var p := data.points[i]
		if p.distance_to(near) >= best_d: continue
		var found := PilotLedge.find(eye._motor_ground,p,float(data.ground_height(p)))
		if found.is_empty(): continue
		var out: Vector2 = found.out
		var edge := Vector2(found.at.x,found.at.z)
		var clear := true
		for k in range(12):
			var q := edge-out*(0.1*k)
			if eye._blocked(q) or not data.has_land(q): clear = false
		if not clear: continue
		best = {"at":edge-out*1.0,"out":out}
		best_d = p.distance_to(near)
	return best

## Set down at `spot` and walked gently out over the rim: whether he came to
## hang from it.
func _walk_off(eye: Node, spot: Dictionary) -> bool:
	var at: Vector2 = spot.at
	eye.place(Vector3(at.x,0.0,at.y))
	for i in range(5): await process_frame
	for i in range(300):
		_push(eye,spot.out,0.4)
		await process_frame
		if eye.motor.on_ledge() or eye.flying: break
	_push(eye,Vector2.ZERO,0.0)
	for i in range(90):
		await process_frame
		if eye.motor.hold == "hang" or eye.flying: break
	return eye.motor.hold == "hang"

## The stick pushed `strength` the world way `way` (x, z), through the
## walker's own reading of it against the camera.
func _push(eye: Node, way: Vector2, strength: float) -> void:
	for move in MOVES: Input.action_release(move)
	if strength <= 0.0: return
	var forward := PilotMotor.forward(eye._yaw-eye._turn())
	var right := Vector2(-forward.y,forward.x)
	var x := way.normalized().dot(right)*strength
	var y := way.normalized().dot(forward)*strength
	if absf(x) > 0.01: Input.action_press(&"move_right" if x > 0.0 else &"move_left",absf(x))
	if absf(y) > 0.01: Input.action_press(&"move_forward" if y > 0.0 else &"move_back",absf(y))
