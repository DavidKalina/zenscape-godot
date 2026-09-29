extends SceneTree
## Headless: from a low camera, hover, turn and flip by the block's side wall
## (docs/scenic/modeless.md). The wall is rim: the hand shows at the pointer,
## a sideways drag turns the world with the grabbed wall point kept under the
## pointer, and an upward drag decides the flip. The hand lays its palm on the
## wall ("wall", its Wall clips facing into the wall) on hover and while it
## holds and turns, and the lip keeps the rim grip.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_wall_grab.gd -- --modeless
var scene: Node3D
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event)

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: push_error("wall grab probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-wallgrab-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	var editor: Node = scene._chunk_editor
	var reach: Node = scene.hand_reach
	var rig: Node = scene.camera_rig
	var hand: Node3D = scene.god_hand
	var terrain: Node3D = editor.terrain
	scene.world_clock.running = false
	# Low and close, facing the +z wall, as in a player's close look at the side.
	scene._overview()
	await frames(30)
	rig.glide_to(Vector3(0,-1.0,8.0),0.0,1.42,16.0)
	await frames(150)
	var camera: Camera3D = scene.camera
	print("camera ",camera.global_position," polar ",rig._view.y)
	var wall_local := Vector3(2.0,-2.4,14.0)
	var at: Vector2 = camera.unproject_position(terrain.to_global(wall_local))
	print("wall point on screen ",at)
	check("the wall mid-height is rim",reach.reach_at(at) == "rim",reach.reach_at(at))
	var rim: Variant = reach._rim_at(at)
	check("it reaches the point under the pointer, not the lip",rim != null and absf(float(rim.y)-wall_local.y) < 0.4,rim)
	# Hover: the pointer there, no buttons.
	# Headless has no real pointer: hover by hand, then drive the hand once.
	reach._hover_key = []
	reach._hover(at)
	reach._drive_hand_modeless()
	check("hover lays the palm on the wall",hand.reach_gesture == "wall",hand.reach_gesture)
	check("the palm faces into the wall",hand.reach_facing != null and Vector3(hand.reach_facing).distance_to(Vector3(0,0,-1)) < 0.001,hand.reach_facing)
	var shown: Variant = hand.reach_point
	var face: float = reach._wall_face(Vector3(rim),Vector3(0,0,1))
	print("earth side's face ",face," m out from the plate there")
	check("the hand stands on the earth side's face at the pointer",shown != null and face > 0.0 and face < 0.6 and absf(float(shown.z)-14.0-face) < 0.001 and absf(float(shown.y)-wall_local.y) < 0.4,shown)
	var model: AnimationPlayer = hand.player
	check("the Wall clips are in the model",model.has_animation("WallIn") and model.has_animation("WallHold") and model.has_animation("WallOut"),"")
	check("the palm faces the wall with its reach",absf(angle_difference(float(hand._facing()),atan2(0.0,-1.0))) < 0.001,hand._facing())
	# The lip, just over the wall's top on screen: still the rim grip, facing the camera.
	var lip_local := Vector3(2.0,reach._rim_height(Vector2(2.0,14.0)),14.0)
	var lip: Vector2 = camera.unproject_position(terrain.to_global(lip_local))+Vector2(0,-4)
	reach._hover_key = []
	reach._hover(lip)
	reach._drive_hand_modeless()
	check("the lip keeps the rim grip",hand.reach_gesture == "rim" and hand.reach_facing == null,[hand.reach_gesture,hand.reach_facing,reach._rim_at(lip)])
	# Held on the wall without moving: the palm stays laid on it and its clips play.
	# (Headless has no real pointer, so a hold keeps the pose over frames.)
	button(at,true)
	await frames(90)
	check("a wall hold keeps the palm on the wall",reach.holding == "rim" and hand.reach_gesture == "wall" and hand.reach_facing != null,[reach.holding,hand.reach_gesture])
	check("WallIn has run into WallHold",hand.gesture == "wall" and String(model.current_animation) == "WallHold",model.current_animation)
	var palm: Vector3 = hand._bone_at(hand.skeleton.find_bone("Palm"))
	# The earth side's outermost face there: the hand keeps WALL_GAP past it.
	var surface := 14.0+face-float(reach.WALL_GAP)
	check("the palm lies on the earth side, not in it (m past its face)",palm.z > surface-0.02 and palm.z < surface+0.3,palm.z-surface)
	button(at,false)
	await frames(2)
	reach._hover_key = []
	reach._hover(Vector2(4,4))
	reach._drive_hand_modeless()
	check("letting go and moving off clears the palm's facing",hand.reach_gesture == "" and hand.reach_facing == null,[hand.reach_gesture,hand.reach_facing])
	await frames(10)
	# Turn: sideways drag along the wall.
	var yaw0: float = rig._view.x
	button(at,true)
	await frames(1)
	var p := at
	var worst := 0.0
	var grabbed: Vector3 = reach._press_edge
	for i in range(24):
		p += Vector2(-6,0)
		motion(p,Vector2(-6,0))
		await frames(1)
		if i > 2:
			var seen := camera.unproject_position(terrain.to_global(grabbed))
			worst = maxf(worst,absf(seen.x-p.x))
	check("a sideways wall drag decides the turn",reach.rim_intent == "turn",reach.rim_intent)
	check("the palm stays on the wall while it turns",hand.reach_gesture == "wall" and hand.reach_facing != null,hand.reach_gesture)
	check("the world turned",absf(angle_difference(yaw0,rig._view.x)) > 0.05,rig._view.x-yaw0)
	check("the grabbed wall point stays under the pointer (px)",worst < 25.0,worst)
	button(p,false)
	await frames(60)
	rig.turn.stop()
	await frames(10)
	# Flip: an upward drag from the wall, back where it started.
	rig.glide_to(Vector3(0,-1.0,8.0),0.0,1.42,16.0)
	await frames(150)
	at = camera.unproject_position(terrain.to_global(wall_local))
	print("camera ",camera.global_position," wall point on screen ",at)
	var flipped := [false]
	reach.flip_began.connect(func(_s: Vector2) -> void: flipped[0] = true)
	var what: String = reach.reach_at(at)
	button(at,true)
	await frames(1)
	p = at
	for i in range(8):
		p += Vector2(0,-12)
		motion(p,Vector2(0,-12))
		await frames(1)
	check("an upward wall drag decides the flip",what == "rim" and reach.rim_intent == "flip" and flipped[0],[what,reach.rim_intent])
	button(p,false)
	await frames(5)
	print("FAILURES: ",failures)
	quit(1 if not failures.is_empty() else 0)
