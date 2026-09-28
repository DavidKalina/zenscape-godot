extends SceneTree
## Headless check of the snow globe in the real diorama (studies/cozy_worlds.tscn):
## the real plate, earth block, precipitation and tremor. A firm shake is fed
## to scripts/snow_globe.gd as the rim grab would, and the probe prints what
## reaches the weather and the camera. The particles themselves need a GPU.
##   Godot --headless --path . --script res://tools/probe_snow_globe_scene.gd

var failures := 0

func _check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 60
	var scene: Node3D = (load("res://studies/cozy_worlds.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in range(30): await process_frame
	var globe: Node = scene.snow_globe
	_check(globe != null and globe.is_inside_tree(),"the scene has its snow globe")
	var terrain: Node3D = scene._chunk_editor.terrain
	var camera: Camera3D = scene.camera
	var block: AABB = globe._block()
	print("  earth block %s" % block)
	_check(block.size.x > 27.0 and block.position.y < -0.5,"the earth block is found under the plate")
	var edge: Variant = scene._chunk_editor.data.ground_height(Vector2(0.0,13.9))
	var wall := terrain.to_global(Vector3(0.0,block.position.y*0.5+float(edge)*0.5,14.2))
	var toward := camera.unproject_position(wall)
	var rim: Variant = globe.rim_at(toward)
	print("  camera %s, wall point on screen %s, rim %s" % [camera.global_position,toward,rim])
	_check(rim != null,"the earth block's wall holds the rim")
	var middle := camera.unproject_position(terrain.to_global(Vector3(0.0,float(scene._chunk_editor.data.ground_height(Vector2.ZERO)),0.0)))
	_check(globe.rim_at(middle) == null,"the middle of the land is not the rim")
	# Snow for sure: the world's cold decides, so make it winter-cold.
	scene._precipitation.surface_weather.cold = 1.0
	scene._precipitation.surface_weather.target_cold = 1.0
	var before: float = scene._precipitation.state.y
	globe.grab(toward)
	var height: float = globe._screen_height()
	var moved := 0.0
	var start := Time.get_ticks_msec()
	var i := 0
	while Time.get_ticks_msec()-start < 2500:
		var t := i/60.0
		globe.feed(Vector2(0.07*height*TAU*4.0*cos(TAU*4.0*t)/60.0,0.0),1.0/60.0)
		i += 1
		await process_frame
		moved = maxf(moved,Vector3(scene._tremor.jiggle).length())
	print("  after the shake: amount %.3f, state.y %.3f, snow instances %d, jiggle up to %.3f m, hand %s" % [globe.amount(),scene._precipitation.state.y,
		scene._precipitation._instances[1].visible_instance_count,moved,scene.god_hand.reach_gesture if scene.god_hand != null else "none"])
	_check(globe.decided,"a firm shake is a shake")
	_check(scene._precipitation.state.y > before+0.1,"it reaches the precipitation")
	_check(scene._precipitation._instances[1].visible_instance_count > 100,"as falling snow in the cold")
	_check(moved > 0.05,"the camera jiggles")
	_check(scene.god_hand == null or scene.god_hand.reach_gesture == "shake","the hand holds the rim")
	globe.release()
	start = Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 2000: await process_frame
	_check(Vector3(scene._tremor.jiggle).length() < 0.001,"the jiggle has rung down")
	_check(scene.god_hand == null or scene.god_hand.reach_gesture == "","the hand has let go")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
