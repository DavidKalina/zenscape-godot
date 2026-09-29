extends SceneTree
## Everything together (2026-09-29): the clay, the edge spring's amplify,
## springs, sim-driven falls and a fall off the chunk into the void, all by
## a player's gestures. Two peaks are pinched up, a thumb stream runs from the
## west peak into a palm-pressed lake, and a groove runs from the east peak out
## through the rim. A hard pull on the rim springs the whole sculpt up taller.
## Springs from the sky feed both grooves; the water runs as a time lapse; the
## camera tours the lake and the peak's fall, then comes down beside the edge
## fall and orbits. Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 --write-movie /tmp/zs-film/everything.avi \
##     -s res://tools/film_everything.gd -- --modeless
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
		root.get_texture().get_image().save_png("/private/tmp/zs-film/everything.png")
	var from: float = scene.yaw
	var count := 16*60
	for i in range(count):
		scene.yaw = from-1.5*smoothstep(0.0,1.0,float(i+1)/count)
		scene._update_camera()
		await frames(1)
	await seconds(1.0)

var spring: Node

const PEAK_W := Vector2(-7.0,-5.0)
const STREAM_W := [Vector2(-5.2,-3.6),Vector2(-4.0,-1.8),Vector2(-2.6,-0.4),Vector2(-1.2,1.0)]
const LAKE := Vector2(0.5,2.5)

## A point on the near lip the hand reads as rim, in the view's middle band.
func lip_point() -> Vector2:
	var terrain: Node3D = editor.terrain
	var best := Vector2.ZERO
	for side in range(4):
		for i in range(7):
			var f := -6.0+12.0*i/6.0
			var edge: Vector2 = [Vector2(f,-13.7),Vector2(13.7,f),Vector2(f,13.7),Vector2(-13.7,f)][side]
			var h: Variant = editor.data.ground_height(edge)
			if h == null: continue
			var world := terrain.to_global(Vector3(edge.x,float(h),edge.y))
			if scene.camera.is_position_behind(world): continue
			var at: Vector2 = scene.camera.unproject_position(world)
			if reach.reach_at(at) != "rim": continue
			var tall := root.get_visible_rect().size.y
			if at.y > best.y and at.y < tall*0.58 and at.y > tall*0.46: best = at
	return best

## Pull the rim down `pixels` and let go, as a hand would.
func edge_pull(pixels: float) -> void:
	var from := lip_point()
	print("ALL rim grab at ",from," (",reach.reach_at(from),")")
	await glide(from,30)
	button(pointer,true)
	await frames(2)
	for i in range(40):
		move(from+Vector2(0.0,pixels*smoothstep(0.0,1.0,float(i+1)/40)),true)
		await frames(1)
	await seconds(0.4)
	button(pointer,false)
	await frames(1)

func settle_land() -> void:
	var quiet := 0
	while quiet < 30:
		await frames(1)
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0
		quiet = 0 if busy else quiet+1

func run() -> void:
	Input.use_accumulated_input = false
	create_timer(420).timeout.connect(func() -> void: push_error("everything film timed out"); quit(2))
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-all-%d/places.json" % Time.get_ticks_usec()
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

	spring = scene.get("edge_spring")
	print("ALL peaks")
	await pinch(PEAK_W,-80.0)
	await pinch(PEAK,-55.0)
	print("ALL lake")
	await pinch(LAKE,90.0)
	await pinch(LAKE+Vector2(2.0,1.0),80.0)
	shift(true)
	var ring: Array = [LAKE]
	for k in range(25):
		var a := k*0.9
		ring.append(LAKE+Vector2(1.0,0.5)+Vector2(cos(a),sin(a))*(0.4+2.6*float(k)/24.0))
	await stroke(ring,6.0)
	shift(false)
	print("ALL grooves")
	await stroke(STREAM_W,3.0)
	await stroke(GROOVE,3.0)
	var clay: Node = scene.get("land_clay")
	if clay != null: print("ALL notches ",clay.notches)
	print("ALL before pull: west %.2f east %.2f lake %.2f" % [height(PEAK_W),height(PEAK),height(LAKE)])
	await seconds(0.8)
	print("ALL edge pull")
	await edge_pull(210.0)
	await settle_land()
	await seconds(1.0)
	print("ALL after pull: west %.2f east %.2f lake %.2f" % [height(PEAK_W),height(PEAK),height(LAKE)])

	print("ALL springs")
	print("ALL spring W ",await spring_at(STREAM_W[0],3.5))
	print("ALL spring E ",await spring_at(GROOVE[0],3.5))
	await glide(Vector2(1240,700),40)
	lapse = 6
	for k in range(5):
		await seconds(3.0)
		print("ALL run %d: lake %.1f m³, all %.1f m³" % [k,water_near(LAKE+Vector2(1,0.5),4.0),editor.flow.volume()])
		falls_report()
	lapse = 1
	dot.visible = false
	var hand: Node3D = scene.get("god_hand") as Node3D
	if hand != null: hand.visible = false
	print("ALL tour")
	await camera_to(editor.terrain.to_global(Vector3(-2.0,1.5,-1.0)),22.0,scene.yaw+0.6,1.05,5.0)
	await camera_to(editor.terrain.to_global(Vector3(-4.0,2.0,-2.0)),16.0,scene.yaw+0.5,1.12,5.0)
	await side_view()
	print("ALL done")
	quit(0)
