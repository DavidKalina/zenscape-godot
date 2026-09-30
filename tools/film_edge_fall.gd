extends SceneTree
## A waterfall off the chunk itself (docs/scenic/water-flow.md "Edge falls",
## 2026-09-29): a peak pinched up near the +x side, a thumb groove from its
## flank out through the rim (the groove is carried to the lip and notches
## it), a spring from the sky at the groove's head, the water run as a time
## lapse, and then the camera comes down to a low side view where the fall
## pours off the block into the void, and slowly orbits. Every shape is a
## player's gesture (pinch, thumb, sky drag). Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 --write-movie /tmp/zs-film/edge_fall.avi \
##     -s res://tools/film_edge_fall.gd -- --modeless
## It saves /private/tmp/zs-film/edge_fall.png from the side view.
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


const PEAK := Vector2(8.0,-3.0)
const GROOVE := [Vector2(9.4,-3.0),Vector2(11.2,-3.0),Vector2(13.1,-3.0)]

## The edge falls standing (scripts/edge_falls.gd), and what they cost.
func falls_report() -> void:
	var falls: Node = editor.flow_view.edge_falls if editor.flow_view != null else null
	if falls == null: return
	for fall: Dictionary in falls.describe():
		print("EDGE fall %d: side %d lip %s, %.3f m³/s, %.2f m wide, face %.2f m, in all %.2f m, presence %.2f" % [fall.id,fall.side,fall.lip,fall.flux,fall.width,fall.face_drop,fall.drop,fall.presence])
	var s: Dictionary = editor.flow.stats()
	print("EDGE falls %d, read %d us, frame %d us (worst %d); water %.2f m³, off the edge %.4f m³/s, drained %.1f m³" % [falls.shown_count(),falls.last_read_usec,falls.last_update_usec,falls.worst_update_usec,s.volume,s.edge_flux,s.drained])

## The low side view: the camera comes down beside the fall, holds, saves
## the still, and slowly orbits round it.
func side_view() -> void:
	var falls: Node = editor.flow_view.edge_falls if editor.flow_view != null else null
	var lip := Vector3(14.0,0.0,-2.5)
	if falls != null and not falls.describe().is_empty(): lip = falls.describe()[0].lip
	var target: Vector3 = editor.terrain.to_global(Vector3(lip.x+0.6,lip.y-3.2,lip.z))
	print("EDGE side view on ",lip)
	var hand: Node3D = scene.get("god_hand") as Node3D
	if hand != null: hand.visible = false
	await camera_to(target,13.0,PI*0.5+0.75,1.36,6.0)
	await seconds(1.5)
	falls_report()
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("/private/tmp/zs-film")
		root.get_texture().get_image().save_png("/private/tmp/zs-film/edge_fall.png")
	var from: float = scene.yaw
	var count := 16*60
	for i in range(count):
		scene.yaw = from-1.5*smoothstep(0.0,1.0,float(i+1)/count)
		scene._update_camera()
		await frames(1)
	await seconds(1.0)

func run() -> void:
	Input.use_accumulated_input = false
	create_timer(300).timeout.connect(func() -> void: push_error("edge fall film timed out"); quit(2))
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-edge-%d/places.json" % Time.get_ticks_usec()
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
	# Clean frames: the scene's overlays off (before any mist layer exists),
	# the drawn pointer kept.
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	scene._overview()
	scene.distance *= 0.85
	scene._update_camera()
	scene.world_clock.running = false
	scene._celestial.set_phase(0.3)
	for i in range(120):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	print("EDGE flow ready ",editor.flow != null and editor.flow.ready)
	await seconds(1.0)

	print("EDGE peak")
	await pinch(PEAK,-55.0)
	print("EDGE peak height %.1f" % height(PEAK))
	print("EDGE groove")
	await stroke(GROOVE,3.0)
	var clay: Node = scene.get("land_clay")
	if clay != null: print("EDGE notches %d, last %s, heading %s, breach %s, last point %s" % [clay.notches,clay.last_notch,clay.heading,clay.hand._breach,clay.last_plate])
	var line := ""
	for z in [-5.0,-4.0,-3.0,-2.0,-1.0,0.0]: line += " %.2f" % height(Vector2(13.99,z))
	print("EDGE rim heights z -5..0:",line)
	line = ""
	for x in [9.5,10.5,11.5,12.5,13.0,13.5,13.99]: line += " %.2f" % height(Vector2(x,-3.0))
	print("EDGE groove bed along z -3, x 9.5..14:",line)
	if "--groove-only" in OS.get_cmdline_user_args(): quit(0)
	await seconds(0.6)

	print("EDGE spring ",await spring_at(GROOVE[0],3.5))
	await glide(Vector2(1240,700),40)
	print("EDGE run")
	lapse = 6
	for k in range(4):
		await seconds(3.0)
		falls_report()
	lapse = 1
	dot.visible = false
	await side_view()
	print("EDGE done")
	quit(0)
