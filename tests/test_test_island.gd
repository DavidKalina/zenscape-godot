extends SceneTree
## The pilot's test island (studies/test_island.tscn), headless: one small
## square island alone, no sky world made round it (no glide, no sky islands),
## mostly wheat in its rows, two to four trees and a pond of live water
## (scripts/water_flow.gd) to wade, the pilot standing on its land in walk
## mode at the wheat's edge, facing into it, his wake live. Its rim is a ledge: walked slowly off it he hangs from it,
## shimmies along it, climbs back up, and hanging again and pushed away lets go.
##   godot --headless --path . --script tests/test_test_island.gd
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
	create_timer(300.0).timeout.connect(func() -> void: push_error("test island test timed out"); quit(2))
	var began := Time.get_ticks_msec()
	var scene: Node3D = load("res://studies/test_island.tscn").instantiate()
	scene.places_path = OS.get_temp_dir().path_join("test-island-test-%d" % Time.get_ticks_usec()).path_join("places.json")
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not scene.walk_ready: await process_frame
	print("     walking %.2f s after the scene was added" % ((Time.get_ticks_msec()-began)/1000.0))
	for i in range(30): await process_frame
	var eye: Node = scene.wanderer
	var data: NativeTerrainData = scene._chunk_editor.data
	check(scene.places_path.begins_with(OS.get_temp_dir()),"Its places are kept in the temp dir")
	check(scene.first_steps == null and not scene.titled,"No title, no first steps")
	check(not eye.glide_enabled and eye.islands == null and eye.sky == null,"No glide and no sky world round it")
	# The island: a square, alone.
	var land := data.land_area()
	var half: float = scene.HALF
	check(absf(land-4.0*half*half) < 0.05*4.0*half*half,"A square island: %.0f m² of land" % land)
	check(data.has_land(Vector2(half-0.3,half-0.3)) and not data.has_land(Vector2(half+0.4,0.0)),"Its land reaches its square's corners and stops there")
	# Wheat, trees, tufts, on land.
	var counts := {}
	var off := 0
	for item: Dictionary in data.objects:
		counts[item.asset] = int(counts.get(item.asset,0))+1
		if not data.has_land(Vector2(item.x,item.z)): off += 1
	print("     objects: %s" % str(counts))
	var wheat := 0
	for kind: String in counts:
		if kind.contains("wheat"): wheat += int(counts[kind])
	var trees := 0
	for kind in TREES: trees += int(counts.get(kind,0))
	check(wheat > 1500,"Mostly wheat: %d" % wheat)
	check(trees >= 2 and trees <= 4,"A few trees: %d" % trees)
	check(counts.has("grass_tuft") and counts.has("fern"),"Grass tufts and ferns")
	check(off == 0,"Every object stands on the island's land (%d off)" % off)
	check(not scene._chunk_editor.content._batches.is_empty(),"The objects are drawn (%d batches)" % scene._chunk_editor.content._batches.size())
	# The pond.
	var pond: Vector2 = scene.POND
	check(float(scene.island.pond.get("volume",0.0)) > 1.0,"A pond is laid (%.1f m³)" % float(scene.island.pond.get("volume",0.0)))
	var depth: float = eye._depth(pond)
	check(depth > eye.WADE,"Live water in it, %.2f m deep in the middle" % depth)
	var shallow := false
	for i in range(40):
		var d: float = eye._depth(pond+Vector2.RIGHT.rotated(i*0.4)*(scene.POND_RADIUS*(0.4+0.015*i)))
		if d > 0.02 and d < eye.WADE: shallow = true
	check(shallow,"A shallow shelf round it to wade")
	var wet := data.objects.filter(func(item: Dictionary) -> bool: return eye._depth(Vector2(item.x,item.z)) > 0.02)
	check(wet.is_empty(),"Nothing grows in it (%d in the water)" % wet.size())
	# The walker.
	check(eye.active and not eye.flying,"Walking, not flying")
	check(eye.has_figure() and eye.figure.is_visible_in_tree() and eye.body != null and eye.body.is_visible_in_tree(),"The pilot is drawn")
	var wake: Node = eye.figure.get_node_or_null("Wake")
	var at: Vector3 = eye.figure.global_position
	check(wake != null and wake.published.size() > 0 and wake.published[0].z > 0.0 and Vector2(wake.published[0].x,wake.published[0].y).distance_to(Vector2(at.x,at.z)) < 0.05,"His wake parts the foliage at his feet")
	var feet: Vector3 = eye._feet
	check(data.has_land(Vector2(feet.x,feet.z)),"Standing on the island")
	check(absf(feet.y-float(data.ground_height(Vector2(feet.x,feet.z)))) < 0.2,"On its ground")
	check(PilotMotor.forward(eye.motor.facing).dot(scene.FACING) > 0.8,"Facing into the wheat")
	var ahead := 0
	for item: Dictionary in data.objects:
		var p := Vector2(item.x,item.z)-Vector2(feet.x,feet.z)
		if str(item.asset).contains("wheat") and p.length() < 4.0 and p.dot(scene.FACING) > 0.0: ahead += 1
	check(ahead > 30,"At the wheat's edge: %d heads within 4 m ahead" % ahead)
	await _ledge(scene,eye,data)
	check(eye._depth(pond) > eye.WADE,"The pond holds its water (%.2f m deep after the ledge)" % eye._depth(pond))
	print("PASS: test island" if failures == 0 else "FAIL: test island (%d)" % failures)
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
	var was := Vector2(motor.lip.x,motor.lip.z)
	for i in range(90):
		_push(eye,Vector2(motor.lip_out.y,-motor.lip_out.x),1.0)
		await process_frame
	var along: float = was.distance_to(Vector2(motor.lip.x,motor.lip.z))
	check(along > 0.3 and motor.hold == "hang","Shimmies along it (%.2f m)" % along)
	var up := false
	for i in range(150):
		_push(eye,-motor.lip_out,1.0)
		await process_frame
		if motor.grounded and not motor.on_ledge():
			up = true
			break
	check(up and data.has_land(Vector2(motor.feet.x,motor.feet.z)),"Climbs back up onto the land")
	_push(eye,Vector2.ZERO,0.0)
	for i in range(20): await process_frame
	off = await _walk_off(eye,spot)
	var let_go := false
	for i in range(60):
		_push(eye,motor.lip_out,1.0)
		await process_frame
		if not motor.on_ledge():
			let_go = true
			break
	_push(eye,Vector2.ZERO,0.0)
	for i in range(60): await process_frame
	check(off and let_go and not eye.flying,"Hanging again and pushed away, he lets go")
	check(data.has_land(Vector2(eye._feet.x,eye._feet.z)),"And is set back on the land (no sky to fall into)")

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
