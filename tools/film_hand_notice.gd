extends SceneTree
## Films the life noticing the hand and the wanderer (docs/scenic/life.md
## "Noticing"). A pond in the middle of the Genesis plain with a small wood on
## its east bank; the life clock runs fast until fish, frogs, a gull and
## fireflies have come, then at its own pace. One shot a run (--shot=):
## - a: a swipe through the sky at dusk sends a gust over the pond;
## - b: a tap on the water by the frogs, then the fish nosing at the rings;
## - c: a click in the sky snaps to night and the fireflies wake in a wave;
## - d: the wanderer walks the bank past the frogs and fish, then toward the
##   deer at the wood's edge (the figure is moved by the script, from outside).
## Gestures are real input through the hand. Rendered (needs a window):
##   Godot --windowed --resolution 1280x720 --path . --write-movie /tmp/zs-film/03-notice-a.avi \
##     -s res://tools/film_hand_notice.gd -- --no-title --shot=a
## Headless it prints the numbers, for a dry run.

const VoidSnap = preload("res://scripts/void_snap.gd")
const POND := Vector2(0.0,0.0)
## Where the pointer rests between gestures: the hand floats up in the corner.
const PARK := Vector2(24,24)

var scene: Node3D
var reach: Node
var editor: NativeChunkEditor
var life: Node3D
var pointer := Vector2(1240,700)
var dot := Control.new()
var shot := "a"
var bottom := 0.0

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func seconds(value: float) -> void:
	await frames(int(value*60.0))

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

func glide(to: Vector2, count: int, held := false) -> void:
	var from := pointer
	for i in range(count):
		move(from.lerp(to,smoothstep(0.0,1.0,float(i+1)/count)),held)
		await frames(1)

func world(p: Vector3) -> Vector3:
	return editor.terrain.to_global(p)

func screen(p: Vector3) -> Vector2:
	return scene.camera.unproject_position(world(p))

func ground(p: Vector2) -> float:
	var h: Variant = editor.data.ground_height(p)
	return float(h) if h != null else 0.0

func look(target: Vector3, distance: float, yaw: float, polar: float) -> void:
	scene.target = world(target)
	scene.distance = distance
	scene.yaw = yaw
	scene.polar = polar
	scene._update_camera()

func camera_to(target: Vector3, distance: float, yaw: float, polar: float, secs: float) -> void:
	var from := [scene.target,scene.distance,scene.yaw,scene.polar]
	var count := int(secs*60.0)
	for i in range(count):
		var t := smoothstep(0.0,1.0,float(i+1)/count)
		scene.target = from[0].lerp(world(target),t)
		scene.distance = lerpf(from[1],distance,t)
		scene.yaw = lerp_angle(from[2],yaw,t)
		scene.polar = lerpf(from[3],polar,t)
		scene._update_camera()
		await frames(1)

## The hour, held: the clock and the sky both.
func hour(phase: float) -> void:
	var clock: WorldClock = scene.world_clock
	clock.running = false
	clock.set_time(clock.day,WorldClock.hour_for_phase(phase))
	var mood: Node = scene.get("mood_look")
	if mood != null and mood.has_method("pin_hour"): mood.pin_hour(phase)
	scene._celestial.set_phase(phase)
	scene._celestial.update_rig()

## A screen point in the sky (void) near `want`, or Vector2.INF.
func sky_near(want: Vector2) -> Vector2:
	var best := Vector2.INF
	for y in range(20,340,20):
		for x in range(60,1240,40):
			var p := Vector2(x,y)
			if reach.void_at(p) and p.distance_to(want) < best.distance_to(want): best = p
	return best

func count(kind: String) -> int:
	return life.present(kind).size()

func stage() -> void:
	var data := editor.data
	data.begin_stroke()
	for _pass in range(6): data.brush(POND,4.2,0.3,"lower",0.0)
	bottom = data.ground_height(POND)
	data.add_pond(POND,bottom+0.75)
	for i in range(14):
		var angle := -1.2+float(i)*0.19
		var p := POND+Vector2.from_angle(angle)*(6.0+0.8*sin(float(i)*2.3))
		var id := data.place("broadleaf" if i%3 else "tree",p,float(i),0.9)
		if id >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	await editor.refresh(self)
	life.pace = 40.0
	for i in range(900):
		await frames(1)
		if count("fish") >= 4 and count("frog") >= 2 and count("bird") >= 1 and count("firefly") >= 30: break
	life.pace = 1.0
	print("FILM life fish=%d frog=%d bird=%d firefly=%d" % [count("fish"),count("frog"),count("bird"),count("firefly")])

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.trim_prefix("--shot=")
	Input.use_accumulated_input = false
	create_timer(400).timeout.connect(func() -> void: push_error("notice film timed out"); quit(2))
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-notice-%d/places.json" % Time.get_ticks_usec()
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
	life = scene.land_life
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	scene._auto_orbit = false
	# The camera's hover name and ring follow the real mouse, wherever it is
	# on the desktop; keep them off the film.
	RenderingServer.frame_pre_draw.connect(func() -> void:
		var rig: Variant = scene.get("camera_rig")
		if rig != null and rig.get("layer") != null: rig.layer.visible = false
		if shot == "d" and scene.get("god_hand") != null: scene.god_hand.visible = false)
	hour(0.75 if shot == "a" else (0.55 if shot == "c" else 0.3))
	look(Vector3(POND.x,bottom+0.75,POND.y),16.0,0.5,1.15)
	move(pointer,false)
	await stage()
	match shot:
		"a": await shot_gust()
		"b": await shot_poke()
		"c": await shot_night()
		"d": await shot_wanderer()
	print("FILM reactions ",life.notice.reactions)
	print("FILM done")
	quit(0)

## Dusk: the gull over the pond, the fish and the fireflies; a quick swipe
## across the sky blows a gust over them.
func shot_gust() -> void:
	var level := bottom+0.75
	look(Vector3(POND.x+1.0,level,POND.y),10.0,-1.3,1.12)
	await seconds(3.0)
	var from := sky_near(Vector2(360,90))
	var to := sky_near(Vector2(920,90))
	print("FILM swipe ",from," to ",to)
	if from == Vector2.INF or to == Vector2.INF:
		print("FILM no sky; gust sent directly")
		editor.gust_from_sky(Vector2(1.0,0.25),1.0)
	else:
		await glide(from,40)
		await seconds(0.4)
		button(pointer,true)
		await frames(2)
		await glide(to,8,true)
		button(pointer,false)
		await frames(1)
		await glide(PARK,60)
	print("FILM gusts ",reach.wind.gusts if reach.get("wind") != null else -1)
	await seconds(10.0)

## Midday: a tap on the water beside the frogs; they plop in, the fish
## scatter from the rings, then come back to nose at them.
func shot_poke() -> void:
	var frogs: Array = life.present("frog")
	var frog: Dictionary = frogs[0]
	var home: Vector3 = frog.home
	var landing: Vector3 = frog.landing
	var at := landing.lerp(home,0.25)
	look(at.lerp(Vector3(POND.x,at.y,POND.y),0.3),5.5,atan2(home.x-POND.x,home.z-POND.y)+PI+0.5,0.9)
	await seconds(3.0)
	var tap := screen(Vector3(at.x,ground(Vector2(at.x,at.z)),at.z))
	await glide(tap,40)
	await seconds(0.3)
	button(pointer,true)
	await frames(4)
	button(pointer,false)
	await frames(1)
	print("FILM tap at ",at," ",tap)
	await seconds(0.8)
	await glide(PARK,60)
	await seconds(12.0)

## Afternoon: a click in the sky snaps to night, and the fireflies wake in a
## wave across the damp ground.
func shot_night() -> void:
	look(Vector3(POND.x+1.5,bottom+0.75,POND.y),10.0,-1.3,1.1)
	await seconds(2.5)
	var sky := sky_near(Vector2(640,70))
	print("FILM snap at ",sky)
	if sky == Vector2.INF:
		reach.fire_snap(false)
	else:
		await glide(sky,40)
		await seconds(0.3)
		button(pointer,true)
		await frames(3)
		button(pointer,false)
		await frames(1)
	print("FILM night ",VoidSnap.is_night(scene.world_clock.phase)," wave ",life.notice._wave.size())
	await seconds(1.0)
	await glide(PARK,40)
	await seconds(10.0)

## Morning: the wanderer walks the bank past the frogs, the fish drift to its
## shadow, then it heads for the deer at the wood's edge.
func shot_wanderer() -> void:
	for i in range(20):
		if life.moments.showing().deer: break
		life.moments.force("deer")
		await frames(1)
	var wanderer: Node = scene.wanderer
	dot.visible = false
	# A path round the bank, just landward of each frog.
	var frogs: Array = life.present("frog")
	var points: Array[Vector2] = []
	for frog: Dictionary in frogs:
		var home: Vector3 = frog.home
		var landing: Vector3 = frog.landing
		var out := Vector2(home.x-landing.x,home.z-landing.z).normalized()
		points.append(Vector2(home.x,home.z)+out*0.7)
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return (a-POND).angle() < (b-POND).angle())
	var first := points[0]
	var start := POND+(first-POND).rotated(-0.9)
	var path: Array[Vector2] = [start]
	for p in points: path.append(p)
	path.append(POND+(points.back()-POND).rotated(0.6))
	var members: Array = life.moments._deer_state.get("members",[])
	var deer := Vector2(members[0].to) if not members.is_empty() else POND+Vector2(6,0)
	print("FILM path ",path," deer ",deer," showing ",life.moments.showing())
	wanderer.place(Vector3(start.x,ground(start),start.y))
	look(Vector3(start.x,ground(start),start.y),9.0,-1.4,1.0)
	await seconds(2.5)
	await walk(wanderer,path,1.1)
	await seconds(1.5)
	# Toward the deer, the camera following.
	var from: Vector2 = path.back()
	var near := deer+(from-deer).normalized()*1.5
	await walk(wanderer,[from,near],1.3)
	await seconds(6.0)

## Move the figure along `path` at `speed` m/s, raising its disturbances as
## its own walk does; the camera eases after it.
func walk(wanderer: Node, path: Array[Vector2], speed: float) -> void:
	wanderer._pace = Vector2(0.0,speed)
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i+1]
		var steps := maxi(1,int(a.distance_to(b)/speed*60.0))
		for k in range(steps):
			var p := a.lerp(b,float(k+1)/steps)
			var was: Vector3 = wanderer._feet
			wanderer._feet = Vector3(p.x,ground(p),p.y)
			wanderer._yaw = atan2(-(b.x-a.x),-(b.y-a.y))+editor.terrain.global_basis.get_euler().y
			wanderer._sync_figure()
			wanderer._notice_step(Vector2(p.x-was.x,p.y-was.z).length(),1.0/60.0)
			scene.target = scene.target.lerp(world(Vector3(p.x,ground(p)+0.5,p.y)),0.04)
			scene._update_camera()
			await frames(1)
	wanderer._pace = Vector2.ZERO
