extends SceneTree
## Films the land as clay (docs/scenic/modeless.md "Land as clay"): taps, the
## thumb's slow grooves, a groove gone over again, a pinch raised and one
## sunk, and a fast rub that smooths part of a groove. Synthesized input in
## the product scene, with a drawn pointer. Rendered (needs a window):
##   Godot --path . --resolution 1280x720 --write-movie /tmp/zs-film/clay.avi \
##     -s res://tools/film_land_clay.gd -- --modeless

var scene: Node3D
var reach: Node
var editor: NativeChunkEditor
var pointer := Vector2(640,120)
var dot := Control.new()

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func seconds(value: float) -> void:
	await frames(int(value*60.0))

func button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event,true)

func move(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at-pointer
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer = at
	reach.pointer_override = at
	root.push_input(event,true)
	dot.queue_redraw()

## The screen point over the plate point `p` (plate metres).
func screen(p: Vector2) -> Vector2:
	var h: Variant = editor.data.ground_height(p)
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,float(h) if h != null else 0.0,p.y)))

## Hover over to plate point `p` in `count` frames.
func glide_to(p: Vector2, count: int) -> void:
	var from := pointer
	var to := screen(p)
	for i in range(count):
		move(from.lerp(to,smoothstep(0.0,1.0,float(i+1)/count)),false)
		await frames(1)

## Press and draw along plate points `path` at `speed` metres a second.
func stroke(path: Array, speed: float, hold := 0.0) -> void:
	await glide_to(path[0],30)
	button(pointer,true)
	await seconds(hold if hold > 0.0 else 0.05)
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i+1]
		var steps := maxi(1,int(a.distance_to(b)/speed*60.0))
		for k in range(steps):
			move(screen(a.lerp(b,float(k+1)/steps)),true)
			await frames(1)
	await frames(2)
	button(pointer,false)
	await frames(1)

func tap(p: Vector2) -> void:
	await glide_to(p,24)
	button(pointer,true)
	await frames(4)
	button(pointer,false)
	await seconds(0.7)

## Press, hold still a beat, then pull the screen by `pixels` (up is negative).
func pinch(p: Vector2, pixels: float) -> void:
	await glide_to(p,30)
	button(pointer,true)
	await seconds(0.5)
	var from := pointer
	for i in range(70):
		move(from+Vector2(0,pixels*smoothstep(0.0,1.0,float(i+1)/70)),true)
		await frames(1)
	await seconds(0.3)
	button(pointer,false)
	await frames(1)

func run() -> void:
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-clay-%d/places.json" % Time.get_ticks_usec()
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
	scene._overview()
	# Closer than the overview, under a low morning sun so the grooves shade.
	scene.distance *= 0.72
	scene.world_clock.running = false
	scene._celestial.set_phase(0.3)
	await seconds(2.0)

	print("FILM taps")
	for p in [Vector2(-4,2),Vector2(3,-3),Vector2(0,5)]: await tap(p)

	print("FILM grooves")
	# A winding slow stroke: the thumb digs a groove.
	var winding: Array = []
	for i in range(13):
		var t := float(i)/12.0
		winding.append(Vector2(lerpf(-10.0,10.0,t),sin(t*TAU*1.1)*4.0-2.0))
	await stroke(winding,4.5)
	await seconds(1.0)
	# A second groove across it, and the first half gone over again (deeper).
	await stroke([Vector2(-3,-9),Vector2(-1,-3),Vector2(2,3),Vector2(3,9)],4.0)
	await seconds(0.8)
	await stroke(winding.slice(0,6),4.5)
	await seconds(1.5)

	print("FILM pinch")
	await pinch(Vector2(6,6),-160.0)
	await seconds(1.0)
	await pinch(Vector2(-6,7),120.0)
	await seconds(1.2)

	print("FILM rub")
	# A fast back-and-forth rub over the end of the winding groove smooths it.
	var rub: Array = []
	for i in range(10): rub.append(Vector2(7.0+(2.5 if i%2 == 0 else -2.5),-1.0+i*0.35))
	await stroke(rub,70.0)
	await glide_to(Vector2(0,-12),50)
	await seconds(2.5)
	print("FILM done")
	quit(0)
