extends SceneTree
## Stills of the pilot on the walk-test island's rim (studies/
## walk_island.tscn, the ledge in scripts/pilot_motor.gd), for judging the
## hang, shimmy and climb by eye: walked gently off the rim near the start,
## turning and lowering over it, hanging, shimmying along, climbing back up.
## The camera is swung round off the island to look back at the rim.
## Rendered only when asked for (needs a window):
##   Godot --windowed --fixed-fps 60 --path . -s res://tools/capture_pilot_ledge.gd -- --no-title [--out=DIR]
## Writes DIR/<moment>.png (default /tmp/pilot_ledge) and quits.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotLedge = preload("res://scripts/pilot_ledge.gd")
const MOVES := [&"move_left",&"move_right",&"move_forward",&"move_back"]

var out := "/tmp/pilot_ledge"
var scene: Node3D

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(300.0).timeout.connect(func() -> void: push_error("pilot ledge capture timed out"); quit(2))
	scene = load("res://studies/walk_island.tscn").instantiate()
	scene.places_path = OS.get_temp_dir().path_join("pilot-ledge-capture-%d" % Time.get_ticks_usec()).path_join("places.json")
	root.size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not scene.walk_ready: await process_frame
	for i in range(60): await process_frame
	var eye: Node = scene.wanderer
	var data: NativeTerrainData = scene._chunk_editor.data
	var spot := _rim_spot(eye,data,scene.island.start)
	if spot.is_empty():
		push_error("no rim spot")
		quit(1)
		return
	var at: Vector2 = spot.at
	eye.place(Vector3(at.x,0.0,at.y))
	# The camera off the island looking back in at the rim, a little to the side.
	eye._yaw = PilotMotor.facing_of(-(spot.out as Vector2).rotated(0.5))+eye._turn()
	for i in range(30): await process_frame
	await _save("stand")
	var frame := 0
	while frame < 400 and not eye.motor.on_ledge():
		_push(eye,spot.out,0.4)
		await process_frame
		frame += 1
	_push(eye,Vector2.ZERO,0.0)
	for k in range(4):
		for i in range(5): await process_frame
		await _save("lower_%d" % k)
	for i in range(40): await process_frame
	await _save("hang")
	for i in range(60):
		eye._look_rest = 0.0
		_push(eye,Vector2(eye.motor.lip_out.y,-eye.motor.lip_out.x),1.0)
		await process_frame
		if i%20 == 10: await _save("shimmy_%d" % (i/20))
	_push(eye,Vector2.ZERO,0.0)
	for i in range(20): await process_frame
	var k := 0
	for i in range(90):
		_push(eye,-eye.motor.lip_out,1.0)
		await process_frame
		if eye.motor.hold == "climb" and i%6 == 0:
			await _save("climb_%d" % k)
			k += 1
	_push(eye,Vector2.ZERO,0.0)
	for i in range(20): await process_frame
	await _save("top")
	print("PILOT LEDGE captured ",out)
	quit(0)

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
		var o: Vector2 = found.out
		var edge := Vector2(found.at.x,found.at.z)
		var clear := true
		for k in range(12):
			var q := edge-o*(0.1*k)
			if eye._blocked(q) or not data.has_land(q): clear = false
		if not clear: continue
		best = {"at":edge-o*1.0,"out":o}
		best_d = p.distance_to(near)
	return best

func _push(eye: Node, way: Vector2, strength: float) -> void:
	for move in MOVES: Input.action_release(move)
	if strength <= 0.0: return
	var forward := PilotMotor.forward(eye._yaw-eye._turn())
	var right := Vector2(-forward.y,forward.x)
	var x := way.normalized().dot(right)*strength
	var y := way.normalized().dot(forward)*strength
	if absf(x) > 0.01: Input.action_press(&"move_right" if x > 0.0 else &"move_left",absf(x))
	if absf(y) > 0.01: Input.action_press(&"move_forward" if y > 0.0 else &"move_back",absf(y))

func _save(moment: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(moment+".png"))
