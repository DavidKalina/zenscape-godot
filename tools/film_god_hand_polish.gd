extends SceneTree
## Films the 2026-09-28 polish pass on screen: the snap (and its sound), a
## fast spin's time glide, and the flip onto a blank plain. Synthesized input
## in the product scene, with a drawn pointer. Rendered (needs a window):
##   Godot --path . --resolution 1280x720 --write-movie /tmp/zs-film/polish.avi \
##     -s res://tools/film_god_hand_polish.gd -- --modeless

var scene: Node3D
var reach: Node
var editor: NativeChunkEditor
var pointer := Vector2(640,200)
var dot := Control.new()

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func seconds(value: float) -> void:
	await frames(int(value*60.0))

func button(at: Vector2, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event,true)

## Move the pointer to `to` over `count` frames, eased, holding the button
## when `held`.
func glide(to: Vector2, count: int, held := false) -> void:
	var from := pointer
	for i in range(count):
		var t := smoothstep(0.0,1.0,float(i+1)/count)
		var at := from.lerp(to,t)
		var event := InputEventMouseMotion.new()
		event.position = at
		event.global_position = at
		event.relative = at-pointer
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
		pointer = at
		reach.pointer_override = at
		root.push_input(event,true)
		dot.queue_redraw()
		await frames(1)

func click(shift := false) -> void:
	button(pointer,true,shift)
	await frames(6)
	button(pointer,false,shift)
	await frames(1)

func sky_point() -> Vector2:
	for y in range(40,300,10):
		for x in [640,900,380]:
			if reach.void_at(Vector2(x,y)): return Vector2(x,y)
	return Vector2(640,60)

func rim_point() -> Vector2:
	var best := Vector2.ZERO
	for side in range(4):
		for i in range(9):
			var f := -8.0+16.0*i/8.0
			var edge: Vector2 = [Vector2(f,-14.1),Vector2(14.1,f),Vector2(f,14.1),Vector2(-14.1,f)][side]
			var top: float = float(editor.data.ground_height(edge.clamp(Vector2.ONE*-13.9,Vector2.ONE*13.9)))
			var world := editor.terrain.to_global(Vector3(edge.x,top-0.3,edge.y))
			if scene.camera.is_position_behind(world): continue
			var at: Vector2 = scene.camera.unproject_position(world)
			if reach.reach_at(at) == "rim" and at.y > best.y and absf(at.x-640.0) < 300.0: best = at
	return best

func run() -> void:
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-polish-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	var layer := CanvasLayer.new()
	layer.layer = 120
	root.add_child(layer)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	dot.draw.connect(func() -> void:
		dot.draw_circle(pointer,7.0,Color(1,1,1,0.9))
		dot.draw_arc(pointer,7.0,0.0,TAU,24,Color(0,0,0,0.6),1.5))
	layer.add_child(dot)
	while not scene.places_ready or not scene.shell_ready: await process_frame
	reach = scene.hand_reach
	editor = scene._chunk_editor
	# Some relief, so the old world differs from the plain that replaces it.
	editor.data.begin_stroke()
	for _pass in range(14): editor.data.brush(Vector2(5.0,-4.0),4.5,0.5,"raise",0.0)
	for _pass in range(9): editor.data.brush(Vector2(-6.0,5.0),3.5,0.5,"raise",0.0)
	editor.data.end_stroke()
	await editor.refresh(self)
	scene._overview()
	scene.world_clock.running = false
	scene._celestial.set_phase(0.42)
	await seconds(2.0)

	# 1. The snap: day to night and back, then Shift steps.
	print("FILM snap")
	await glide(sky_point(),50)
	await seconds(1.2)
	await click()
	await seconds(2.2)
	await click()
	await seconds(2.2)
	for i in range(2):
		await click(true)
		await seconds(1.6)

	# 2. A fast spin: the time glides in.
	print("FILM spin")
	var rim := rim_point()
	await glide(rim,50)
	await seconds(0.6)
	button(pointer,true)
	await frames(1)
	for i in range(9):
		var to := pointer+Vector2(80,0)
		var event := InputEventMouseMotion.new()
		event.position = to
		event.global_position = to
		event.relative = Vector2(80,0)
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		pointer = to
		reach.pointer_override = to
		root.push_input(event,true)
		dot.queue_redraw()
		await frames(1)
	print("FILM spin rim ",rim," intent ",reach.rim_intent," holding ",reach.holding," spin ",scene.camera_rig.turn.spin)
	button(pointer,false)
	await glide(Vector2(640,160),40)
	for i in range(900):
		await frames(1)
		if i > 120 and not scene.camera_rig.turn.spinning() and not scene.spin_time.gliding(): break
	await seconds(1.5)

	# 3. The flip: up and over onto a blank plain.
	print("FILM flip")
	scene._overview()
	await seconds(1.0)
	rim = rim_point()
	await glide(rim,50)
	await seconds(0.6)
	button(pointer,true)
	await frames(1)
	await glide(pointer+Vector2(0,-150),40,true)
	await seconds(0.3)
	await glide(pointer+Vector2(0,-300),14,true)
	print("FILM flip rim ",rim," intent ",reach.rim_intent," holding ",reach.holding," phase ",scene.flip.phase," angle ",scene.flip.angle)
	button(pointer,false)
	await glide(Vector2(640,120),60)
	for i in range(600):
		await frames(1)
		if i > 60 and scene.flip.phase == scene.flip.Phase.IDLE: break
	await seconds(2.5)
	print("FILM done")
	quit(0)
