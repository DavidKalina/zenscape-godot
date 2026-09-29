extends SceneTree
## Films live water (docs/scenic/water-flow.md) made the way a player would:
## a pinch raises a mountain, the thumb carves a groove down its flank to the
## plain, the palm presses a basin at the groove's foot, a drag from the sky
## brings a water ball to the groove's head and lets it go. It becomes a
## spring, runs down the groove and fills the basin into a pond; then a second
## thumb groove out of the pond fills from it. The water runs sped up
## (`LAPSE`) while it fills. The camera closes in on the groove and the pond
## once the ball is down, and the fog is thinned so the water reads.
## Synthesized input in the product scene, with a drawn pointer. Rendered
## (needs a window):
##   Godot --windowed --path . --resolution 1280x720 --write-movie /tmp/zs-film/flow.avi \
##     -s res://tools/film_water_flow.gd -- --modeless
## Headless it prints the same numbers, for a dry run. With --planned-water
## the ball's one-shot plan fills the basin instead, and the film stops on a
## still of it from the camera the live take's pond still uses, for A/B:
## /private/tmp/zs-film/pond_planned.png against pond_live.png.

var scene: Node3D
var reach: Node
var editor: NativeChunkEditor
var pointer := Vector2(640,120)
var dot := Control.new()
## Extra water steps a frame while it fills: the water runs LAPSE+1 times as fast.
const LAPSE := 3
var lapse := 0

const PEAK := Vector2(-7.0,-1.0)
const HEAD := Vector2(-4.6,-1.0)
const BASIN := Vector2(3.5,-1.0)

func _initialize() -> void: run.call_deferred()

## The water ball film's look (tools/film_water_ball.gd), so the ponds read
## as they do there, with fog and haze thinned and held against the weather
## easing them back.
const MOOD := "Alpine daylight"
var fog := 0.0
var haze := 0.0
## Where the ponds are framed, planned or live, for the A/B stills.
const POND := Vector2(2.2,-0.8)

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if lapse > 0 and editor != null and editor.flow != null: editor.flow.run(lapse)
		if scene != null and absf(scene._atmosphere.fog_amount-fog) > 0.01:
			scene._atmosphere.set_fog(fog)
			scene._atmosphere.set_haze(haze)

## Glide the orbit camera to look at plate point `at` from `distance` m, over
## `secs` seconds.
func frame_on(at: Vector2, distance: float, polar: float, yaw: float, secs: float) -> void:
	var from := {"target":scene.target,"distance":scene.distance,"polar":scene.polar,"yaw":scene.yaw}
	var goal := editor.terrain.to_global(Vector3(at.x,height(at),at.y))
	var count := maxi(1,int(secs*60.0))
	for i in range(count):
		var t := smoothstep(0.0,1.0,float(i+1)/count)
		scene.target = (from.target as Vector3).lerp(goal,t)
		scene.distance = lerpf(from.distance,distance,t)
		scene.polar = lerpf(from.polar,polar,t)
		scene.yaw = lerpf(from.yaw,yaw,t)
		await frames(1)

func seconds(value: float) -> void:
	await frames(int(value*60.0))

## Viewport units to the window pixels Input expects (2x on a Retina window).
func window(at: Vector2) -> Vector2:
	return root.get_final_transform()*at

func button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = window(at)
	event.global_position = window(at)
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func move(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = window(at)
	event.global_position = window(at)
	event.relative = window(at)-window(pointer)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer = at
	reach.pointer_override = at
	editor.pointer_override = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	dot.queue_redraw()

## The screen point over the plate point `p` (plate metres).
func screen(p: Vector2) -> Vector2:
	var h: Variant = editor.data.ground_height(p)
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,float(h) if h != null else 0.0,p.y)))

func height(p: Vector2) -> float:
	var h: Variant = editor.data.ground_height(p)
	return float(h) if h != null else 0.0

## Hover to screen point `to` in `count` frames.
func glide(to: Vector2, count: int, held := false) -> void:
	var from := pointer
	for i in range(count):
		move(from.lerp(to,smoothstep(0.0,1.0,float(i+1)/count)),held)
		await frames(1)

## Press and draw along plate points `path` at `speed` metres a second. The
## screen path is fixed at the press, as a hand's would be.
func stroke(path: Array, speed: float) -> void:
	var points: Array[Vector2] = []
	for p: Vector2 in path: points.append(screen(p))
	await glide(points[0],30)
	button(pointer,true)
	await frames(3)
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i+1]
		var steps := maxi(1,int(a.distance_to(b)/speed*60.0))
		for k in range(steps):
			move(points[i].lerp(points[i+1],float(k+1)/steps),true)
			await frames(1)
	await frames(2)
	button(pointer,false)
	await frames(1)

## Press, hold still a beat, then pull the screen by `pixels` (up is negative).
func pinch(p: Vector2, pixels: float) -> void:
	await glide(screen(p),30)
	button(pointer,true)
	await seconds(0.5)
	var from := pointer
	for i in range(80):
		move(from+Vector2(0,pixels*smoothstep(0.0,1.0,float(i+1)/80)),true)
		await frames(1)
	await seconds(0.3)
	button(pointer,false)
	await frames(1)

func water_near(center: Vector2, radius: float) -> float:
	var flow: RefCounted = editor.flow
	var depths: PackedFloat32Array = flow.depths()
	var total := 0.0
	for j in range(flow.height):
		for i in range(flow.width):
			if (flow.origin+Vector2(i+0.5,j+0.5)*flow.cell).distance_to(center) < radius: total += depths[j*flow.width+i]
	return total*flow.cell*flow.cell

func run() -> void:
	Input.use_accumulated_input = false
	create_timer(240).timeout.connect(func() -> void: push_error("water film timed out"); quit(2))
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-flow-%d/places.json" % Time.get_ticks_usec()
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
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	# The product maximizes its window; the film wants a fixed 1280x720 frame.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size = Vector2i(1280,720)
	await process_frame
	await process_frame
	reach = scene.hand_reach
	editor = scene._chunk_editor
	scene._overview()
	scene.distance *= 0.8
	scene.world_clock.running = false
	scene.apply_scene_mood(MOOD)
	# Its light, with the fog and haze thinned so the water is not veiled.
	fog = 0.04
	haze = 0.06
	# Clean frames: the scene's overlays off, the drawn pointer kept.
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	for i in range(120):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	print("FILM flow ready ",editor.flow != null and editor.flow.ready," native ",editor.flow.native if editor.flow != null else false)
	await seconds(1.5)

	print("FILM mountain")
	await pinch(PEAK,-170.0)
	await seconds(1.5)
	print("FILM peak %.2f m, head %.2f m" % [height(PEAK),height(HEAD)])
	if "--pinch-only" in OS.get_cmdline_user_args():
		quit(0)
		return

	print("FILM groove")
	var groove: Array = []
	for i in range(9): groove.append(HEAD.lerp(BASIN,float(i)/8.0))
	await stroke(groove,3.0)
	await seconds(1.0)

	print("FILM palm")
	shift(true)
	var ring: Array = [BASIN]
	for i in range(25):
		var a := i*0.9
		ring.append(BASIN+Vector2(cos(a),sin(a))*(0.4+1.4*float(i)/24.0))
	await stroke(ring,5.0)
	shift(false)
	await seconds(1.0)
	await stroke(ring,5.0)
	await seconds(1.0)
	print("FILM ground: head %.2f, mid %.2f, basin %.2f" % [height(HEAD),height(HEAD.lerp(BASIN,0.5)),height(BASIN)])

	print("FILM ball")
	var outcome := {}
	editor.ball_settled.connect(func(o: Dictionary) -> void: outcome.merge(o))
	var sky := Vector2(640,24)
	for candidate in [Vector2(640,24),Vector2(200,24),Vector2(1080,24),Vector2(640,60)]:
		if reach.void_at(candidate):
			sky = candidate
			break
	await glide(sky,30)
	button(pointer,true)
	await frames(2)
	await glide(screen(HEAD),50,true)
	await seconds(2.5)
	button(pointer,false)
	for i in range(240):
		await frames(1)
		if not outcome.is_empty(): break
	print("FILM ball settled ",outcome)
	await glide(Vector2(1180,660),60)

	if editor.flow == null:
		print("FILM planned water")
		await seconds(6.0)
		await frame_on(POND,13.0,0.95,0.35,2.5)
		await seconds(4.0)
		await still("pond_planned")
		print("FILM done")
		quit(0)
		return

	print("FILM fill")
	lapse = LAPSE
	# Close on the groove as the water runs down it, then on the pond.
	await frame_on(HEAD.lerp(BASIN,0.45),18.0,0.95,0.3,2.5)
	for k in range(3):
		await seconds(3.0)
		print("FILM +%d s film: basin %.2f m³ of %.2f, level %.2f, reflection %s" % [(k+1)*3,water_near(BASIN,3.0),editor.flow.volume(),pond_level(),reflection_note()])
	await frame_on(POND,13.0,0.95,0.35,2.5)
	# The second groove is cut once the pond stands up to its rim, so the
	# water visibly runs into it.
	for k in range(20):
		if pond_level() >= height(BASIN+Vector2(2.2,1.3))-0.05: break
		await seconds(1.0)
		print("FILM level %.2f, reflection %s" % [pond_level(),reflection_note()])
	print("FILM pond level %.2f, rim %.2f, basin %.2f m³" % [pond_level(),height(BASIN+Vector2(2.2,1.3)),water_near(BASIN,3.0)])
	await still("pond_live")
	# The groove is cut facing the camera, from the pond towards the viewer.
	await frame_on(BASIN+Vector2(3.0,1.8),14.0,0.9,0.75,2.0)

	print("FILM second groove")
	var out: Array = []
	var from := BASIN+Vector2(0.9,0.5)
	var to := BASIN+Vector2(6.5,4.2)
	for i in range(6): out.append(from.lerp(to,float(i)/5.0))
	var before := water_near(BASIN+Vector2(4.5,2.9),2.0)
	await stroke(out,2.5)
	var line := PackedStringArray()
	for i in range(6): line.append("%.2f" % height(from.lerp(to,float(i)/5.0)))
	print("FILM second groove ground ",", ".join(line))
	await glide(Vector2(1180,660),50)
	for k in range(4):
		await seconds(2.0)
		print("FILM second groove water %.2f → %.2f m³, reflection %s" % [before,water_near(BASIN+Vector2(4.5,2.9),2.0),reflection_note()])
	# A slow turn round the pond, so its reflection moves.
	lapse = 0
	await frame_on(POND,12.0,0.82,-0.5,6.0)
	print("FILM stats ",editor.flow.stats())
	if editor.flow_view.reflection != null: print("FILM reflection level %.2f, sync %d µs" % [editor.flow_view.reflection.level,editor.flow_view.reflection.last_sync_usec])
	print("FILM done")
	quit(0)

## Saves the frame as /private/tmp/zs-film/`name`.png (rendered runs only).
func still(name: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless": return
	root.get_texture().get_image().save_png("/private/tmp/zs-film/%s.png" % name)
	print("FILM still ",name)

func reflection_note() -> String:
	var reflection: Node3D = editor.flow_view.reflection
	if reflection == null: return "off"
	return "%.2f (%s, %d µs)" % [reflection.level,"shown" if reflection.visible and not reflection.views.is_empty() else "hidden",reflection.last_sync_usec]

## The surface level of the largest standing water, or -INF.
func pond_level() -> float:
	var best := {}
	for pool: Dictionary in editor.flow.pools():
		if best.is_empty() or float(pool.area) > float(best.area): best = pool
	return float(best.level) if not best.is_empty() else -INF
