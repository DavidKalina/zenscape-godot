extends SceneTree
## Stills of the pilot in the test island's pond (studies/test_island.tscn;
## the water in scripts/pilot_motor.gd, pilot_figure.gd, pilot_ripples.gd),
## for judging by eye: wading in over the shelf, swimming out over the
## deep, treading water, swimming back, and dripping on the bank. The camera
## looks at him from ahead and to the side.
## Rendered only when asked for (needs a window):
##   Godot --windowed --fixed-fps 60 --path . -s res://tools/capture_pilot_water.gd -- --no-title [--out=DIR]
## Writes DIR/<moment>.png (default /tmp/pilot_water) and quits.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const MOVES := [&"move_left",&"move_right",&"move_forward",&"move_back"]

var out := "/tmp/pilot_water"
var scene: Node3D
var eye: Node

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(300.0).timeout.connect(func() -> void: push_error("pilot water capture timed out"); quit(2))
	scene = load("res://studies/test_island.tscn").instantiate()
	scene.places_path = OS.get_temp_dir().path_join("pilot-water-capture-%d" % Time.get_ticks_usec()).path_join("places.json")
	root.size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not scene.walk_ready: await process_frame
	for i in range(60): await process_frame
	eye = scene.wanderer
	var pond: Vector2 = scene.POND
	var into := Vector2(1.0,0.0)
	var start := pond-into*(float(scene.POND_RADIUS)+0.6)
	eye.place(Vector3(start.x,0.0,start.y))
	_aim(into,0.7)
	for i in range(30): await process_frame
	await _save("bank")
	# Wading in at a walk, then on over the shelf.
	var k := 0
	for i in range(400):
		_push(into,0.5)
		await process_frame
		if eye.motor.swimming: break
		if eye.motor.wade > 0.08 and i%14 == 0 and k < 6:
			await _save("wade_%d" % k)
			k += 1
	k = 0
	for i in range(150):
		_push(into,1.0)
		await process_frame
		if i%25 == 12:
			await _save("swim_%d" % k)
			k += 1
	_push(Vector2.ZERO,0.0)
	for i in range(100): await process_frame
	await _save("tread_0")
	_aim(-into,-0.5)
	for i in range(50): await process_frame
	await _save("tread_1")
	# Back to the bank and out.
	k = 0
	for i in range(600):
		_push(-into,1.0)
		await process_frame
		if eye.motor.wade <= 0.0 and not eye.motor.swimming and eye.motor.feet.x < start.x+0.4: break
		if i%30 == 15 and k < 4:
			await _save("back_%d" % k)
			k += 1
	_push(Vector2.ZERO,0.0)
	_aim(-into,0.9)
	for i in range(8): await process_frame
	for t in range(5):
		await _save("drip_%d" % t)
		for i in range(20): await process_frame
	for i in range(240): await process_frame
	await _save("drying")
	print("PILOT WATER captured ",out)
	quit(0)

## The camera looking along `way` turned `turn` radians, held there.
func _aim(way: Vector2, turn: float) -> void:
	eye._yaw = PilotMotor.facing_of(-way.rotated(turn))+eye._turn()
	eye._look_rest = 0.0

func _push(way: Vector2, strength: float) -> void:
	eye._look_rest = 0.0
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
