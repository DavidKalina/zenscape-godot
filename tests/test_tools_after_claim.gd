extends SceneTree
## The tools after flying to another island, in the live scene, headless:
##   - flown into, an island is claimed over several frames (scripts/
##     sky_islands.gd `claim`, the places busy throughout); stepped out of
##     the plane before the claim is done, the build view still gets its
##     brush back once it is, so the editor is active and the Mountain and the
##     Ravine shape the new plate (the brush pick-up used to be refused while
##     the places were busy, leaving the hand gripping land it could not work);
##   - landed on with F, the same.
##   godot --headless --path . --script tests/test_tools_after_claim.gd
var failures := 0
var scene: Node3D
var eye: Node

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func frames(n: int) -> void:
	for i in range(n): await process_frame

func run() -> void:
	create_timer(600.0).timeout.connect(func() -> void: push_error("tools after claim test timed out"); quit(2))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/tools-claim-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not (scene.places_ready and scene.shell_ready): await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await frames(20)
	eye = scene.wanderer
	check(await _both_shape(),"At the start the Mountain and the Ravine shape the land")
	# Stepped out mid-claim.
	if await _fly_in(false):
		await frames(240)
		check(scene._chunk_editor.active and not scene.looking,"Stepped out mid-claim, the brush comes back once the claim is done")
		check(await _both_shape(),"And the Mountain and the Ravine shape the new island")
	# Landed on with F.
	if await _fly_in(true):
		await frames(240)
		check(scene._chunk_editor.active and not scene.looking,"Landed on with F, the brush comes back")
		check(await _both_shape(),"And the Mountain and the Ravine shape it")
	print("PASS: tools after claim" if failures == 0 else "FAIL: tools after claim (%d)" % failures)
	quit(1 if failures else 0)

## Off the edge, then into the nearest baked island: over it, so it is
## claimed as it is flown into, and out a few frames later while the claim
## runs; or by it and F, waiting for the walk.
func _fly_in(land: bool) -> bool:
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	eye._yaw = atan2(-1.0,0.0)+eye._turn()
	eye.motor.facing = eye._yaw-eye._turn()
	eye._polar = PI*0.5
	eye._launch(1.0)
	await frames(2)
	var islands: Node3D = eye.islands
	var index := -1
	var began := Time.get_ticks_msec()
	while index < 0 and Time.get_ticks_msec()-began < 120000:
		for i in range(islands.offsets.size()):
			if islands.lands[i] != null and islands._rise[i] == Vector3.ZERO:
				index = i
				break
		await process_frame
	check(index >= 0,"Another island stands baked in the sky")
	if index < 0: return false
	var origin: Vector3 = islands.origin
	var home: Vector3 = islands.offsets[index]+eye.editor.terrain.global_position
	if land:
		eye.glide.position = home+Vector3(-90.0,30.0,0.0)
		eye.glide.heading = -PI*0.5
		eye.chase.reset(eye.glide,eye.glide.position+Vector3(-5.0,2.0,0.0))
		await frames(2)
		var f := InputEventKey.new()
		f.keycode = KEY_F
		f.physical_keycode = KEY_F
		f.pressed = true
		eye.handle(f)
		began = Time.get_ticks_msec()
		while eye.flying and Time.get_ticks_msec()-began < 60000: await process_frame
	else:
		eye.glide.position = home+Vector3(0.0,25.0,0.0)
		eye.chase.reset(eye.glide,eye.glide.position+Vector3(-5.0,2.0,0.0))
		began = Time.get_ticks_msec()
		while not islands.claiming and Time.get_ticks_msec()-began < 5000: await process_frame
		await frames(3)
		check(islands.claiming,"Flown into, the island is being claimed as the pilot steps out")
	eye.leave()
	while islands.claiming: await process_frame
	check(islands.origin != origin,"The island is claimed")
	return islands.origin != origin

func _heights() -> float:
	var sum := 0.0
	for h in scene._chunk_editor.data.heights: sum += h
	return sum

func _mouse(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event

## The Ravine, then the Mountain beside where it cut (a tall one would hide
## the next spot), each through the tool roll.
func _both_shape() -> bool:
	var cut := await _shapes("wire",Vector2(-4.0,-3.0))
	var raised := await _shapes("mountain",Vector2(3.0,2.0))
	return cut and raised

## A drag up the land at plate point `p` with tool `id` in hand, through the
## viewport's input; true when the land's heights change.
func _shapes(id: String, p: Vector2) -> bool:
	scene.hand_reach.materials.select_tool(id,true)
	var editor: Node = scene._chunk_editor
	var hit: Variant = editor.data.ray_hit(Vector3(p.x,200.0,p.y),Vector3.DOWN)
	var at: Vector3 = editor.terrain.to_global(hit if hit != null else Vector3(p.x,0.0,p.y))
	var screen: Vector2 = scene.camera.unproject_position(at)
	var before := _heights()
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	root.push_input(motion)
	await process_frame
	root.push_input(_mouse(screen,true))
	for i in range(20):
		var drag := InputEventMouseMotion.new()
		drag.position = screen+Vector2(0.0,-4.0*(i+1))
		drag.global_position = drag.position
		drag.relative = Vector2(0.0,-4.0)
		root.push_input(drag)
		await process_frame
	root.push_input(_mouse(screen+Vector2(0.0,-80.0),false))
	await frames(120)
	scene.hand_reach.materials.select_tool("hand",true)
	return absf(_heights()-before) > 0.01
