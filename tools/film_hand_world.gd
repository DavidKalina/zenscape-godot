extends SceneTree
## A world built by hand, for fun (2026-09-28): two peaks and a shoulder on
## the far side, a thumb stream down each peak into a lake pressed into the
## middle of the plain, and an outflow groove from the lake down to a little
## pond by the near corner. Springs from the sky feed both streams. Every
## shape is a player's gesture (pinch, thumb, palm, sky drag); then the camera
## comes down and circles while the water runs. Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 --write-movie /tmp/zs-film/world.avi \
##     -s res://tools/film_hand_world.gd -- --modeless
## It ends closing on the tallest waterfall (saving /private/tmp/zs-film/
## fall_close.png); --falls-only skips the tour before that.
## Headless it prints the numbers, for a dry run.

var scene: Node3D
var reach: Node
var editor: NativeChunkEditor
var pointer := Vector2(640,120)
var dot := Control.new()
## Extra water steps a frame while it fills: the water runs LAPSE+1 times as fast.
const LAPSE := 3
var lapse := 0


func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if lapse > 0 and editor != null and editor.flow != null: editor.flow.run(lapse)

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

const PEAK_A := Vector2(-7.5,-6.0)
const PEAK_B := Vector2(-2.5,-9.5)
const PEAK_C := Vector2(7.0,-7.5)
const LAKE := [Vector2(0.0,1.5),Vector2(2.2,2.8),Vector2(-1.8,2.8)]
const POND := Vector2(8.0,8.5)
const STREAM_A := [Vector2(-5.6,-4.6),Vector2(-4.4,-2.6),Vector2(-3.6,-1.2),Vector2(-2.2,0.2),Vector2(-1.2,1.2)]
const STREAM_C := [Vector2(5.4,-6.0),Vector2(4.8,-3.8),Vector2(3.4,-2.0),Vector2(2.6,-0.2),Vector2(1.6,1.2)]
const OUTFLOW := [Vector2(2.6,4.4),Vector2(4.0,5.6),Vector2(5.2,6.2),Vector2(6.6,7.2),Vector2(8.0,8.5)]

func palm(center: Vector2, reach: float) -> void:
	var ring: Array = [center]
	for i in range(25):
		var a := i*0.9
		ring.append(center+Vector2(cos(a),sin(a))*(0.4+reach*float(i)/24.0))
	shift(true)
	await stroke(ring,6.0)
	shift(false)
	await seconds(0.4)

func spring_at(p: Vector2, hold: float) -> Dictionary:
	var outcome := {}
	var got := func(o: Dictionary) -> void: outcome.merge(o)
	editor.ball_settled.connect(got)
	var sky := Vector2(640,24)
	for candidate in [Vector2(640,24),Vector2(200,24),Vector2(1080,24),Vector2(640,60)]:
		if reach.void_at(candidate):
			sky = candidate
			break
	await glide(sky,30)
	button(pointer,true)
	await frames(2)
	await glide(screen(p),50,true)
	await seconds(hold)
	button(pointer,false)
	for i in range(240):
		await frames(1)
		if not outcome.is_empty(): break
	editor.ball_settled.disconnect(got)
	return outcome

## The waterfalls standing (scripts/flow_falls.gd), and what they cost.
func falls_report() -> void:
	var falls: Node = editor.flow_view.falls if editor.flow_view != null else null
	if falls == null: return
	for fall: Dictionary in falls.describe():
		print("WORLD fall %d: lip %s plunge %s, %.3f m³/s over %.2f m, %.2f m wide, presence %.2f" % [fall.id,fall.lip,fall.plunge,fall.flux,fall.drop,fall.width,fall.presence])
	print("WORLD falls %d, read %d us, frame %d us (worst %d)" % [falls.shown_count(),falls.last_read_usec,falls.last_update_usec,falls.worst_update_usec])
## Closes on the tallest standing waterfall from a three-quarter view
## downstream of it, holds, and saves fall_close.png.
func close_on_fall() -> void:
	var falls: Node = editor.flow_view.falls if editor.flow_view != null else null
	if falls == null or falls.describe().is_empty(): return
	var tallest: Dictionary = {}
	for fall: Dictionary in falls.describe():
		if tallest.is_empty() or fall.drop > tallest.drop: tallest = fall
	var lip: Vector3 = tallest.lip
	var plunge: Vector3 = tallest.plunge
	var run := Vector2(plunge.x-lip.x,plunge.z-lip.z).normalized()
	var middle: Vector3 = editor.terrain.to_global(lip.lerp(plunge,0.55))
	print("WORLD close on fall %d" % tallest.id)
	await camera_to(middle,6.5,atan2(run.x,run.y)+0.55,1.18,5.0)
	await seconds(2.0)
	falls_report()
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("/private/tmp/zs-film")
		root.get_texture().get_image().save_png("/private/tmp/zs-film/fall_close.png")
	await camera_to(middle,6.5,atan2(run.x,run.y)+1.1,1.12,5.0)
	await seconds(1.0)

func lake_water() -> float:
	return water_near(Vector2(0.2,2.4),4.5)

func camera_to(target: Vector3, distance: float, yaw: float, polar: float, secs: float) -> void:
	var from := [scene.target,scene.distance,scene.yaw,scene.polar]
	var count := int(secs*60.0)
	for i in range(count):
		var t := smoothstep(0.0,1.0,float(i+1)/count)
		scene.target = from[0].lerp(target,t)
		scene.distance = lerpf(from[1],distance,t)
		scene.yaw = lerpf(from[2],yaw,t)
		scene.polar = lerpf(from[3],polar,t)
		scene._update_camera()
		await frames(1)

func run() -> void:
	Input.use_accumulated_input = false
	create_timer(300).timeout.connect(func() -> void: push_error("world film timed out"); quit(2))
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-world-%d/places.json" % Time.get_ticks_usec()
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
	reach = scene.hand_reach
	editor = scene._chunk_editor
	scene._overview()
	scene.distance *= 0.85
	scene._update_camera()
	scene.world_clock.running = false
	scene._celestial.set_phase(0.3)
	for i in range(120):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	print("WORLD flow ready ",editor.flow != null and editor.flow.ready)
	await seconds(1.0)

	print("WORLD peaks")
	await pinch(PEAK_A,-210.0)
	await pinch(PEAK_B,-45.0)
	await pinch(PEAK_C,-80.0)
	print("WORLD heights A %.1f B %.1f C %.1f" % [height(PEAK_A),height(PEAK_B),height(PEAK_C)])

	print("WORLD lake")
	for p: Vector2 in LAKE: await pinch(p,90.0)
	await palm(Vector2(0.2,2.4),2.6)
	await pinch(POND,70.0)
	print("WORLD lake floor %.2f, pond floor %.2f" % [height(Vector2(0.2,2.4)),height(POND)])

	print("WORLD streams")
	await stroke(STREAM_A,3.0)
	await stroke(STREAM_C,3.0)
	await stroke(OUTFLOW,3.0)
	var line := ""
	for p: Vector2 in OUTFLOW: line += " %.2f" % height(p)
	print("WORLD outflow bed",line)
	await seconds(0.6)

	print("WORLD springs")
	print("WORLD spring A ",await spring_at(STREAM_A[0],3.5))
	print("WORLD spring C ",await spring_at(STREAM_C[0],3.0))
	await glide(Vector2(1240,700),40)

	print("WORLD fill")
	lapse = 6
	for k in range(5):
		await seconds(3.0)
		print("WORLD fill %d: lake %.1f m³, pond %.1f m³, all %.1f m³" % [k,lake_water(),water_near(POND,2.8),editor.flow.volume()])
		falls_report()
	lapse = 2
	dot.visible = false
	if not "--falls-only" in OS.get_cmdline_user_args():
		print("WORLD tour")
		await camera_to(Vector3(0,0.5,0),27.0,scene.yaw+0.5,1.02,4.0)
		await camera_to(Vector3(-2,1.0,-2),22.0,scene.yaw+1.1,1.08,7.0)
		await camera_to(Vector3(1,0.0,3),20.0,scene.yaw+0.9,0.98,6.0)
		print("WORLD end: lake %.1f m³, pond %.1f m³, all %.1f m³" % [lake_water(),water_near(POND,2.8),editor.flow.volume()])
		await seconds(1.0)
	await close_on_fall()
	print("WORLD done")
	quit(0)
