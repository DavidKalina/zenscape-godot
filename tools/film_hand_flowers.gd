extends SceneTree
## Rendered film and stills of flower seed sown by hand (scripts/flower_sowing.gd,
## docs/scenic/handful.md "Flower seed") on a plain world with the default
## hand controls: poppies swept across the near meadow, then cosmos beside
## them, in a light breeze, through the real input path (the materials bar,
## a press, a drag, a release). Frames go to /private/tmp/zs-hand-flowers/,
## encoded with ffmpeg to captures/hand-flowers/sow-poppies-cosmos.mp4; stills
## of the bar, the veil in the air and the grown drifts go beside it.
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/film_hand_flowers.gd -- --no-title [--wind=0.35] [--seed=hand-flowers-7]
const Library = preload("res://scripts/world_library.gd")
const OUT := "/Users/davidkalina/Documents/Projects/zenscape-godot/captures/hand-flowers"
const FRAMES := "/private/tmp/zs-hand-flowers"
var scene: Node3D
var editor: Node
var reach: Node
var materials: Node
var filming := false
var frame := 0
var wind := 0.35

func _initialize() -> void: run.call_deferred()

## The film's camera pose [target, distance, polar, yaw], held each frame
## while filming (the scene's own camera ease would take it back).
var pose: Array = []

func frames(count: int) -> void:
	for i in range(count):
		if filming and not pose.is_empty():
			scene.target = pose[0]
			scene.distance = pose[1]
			scene.polar = pose[2]
			scene.yaw = pose[3]
			scene._auto_orbit = false
			scene._update_camera()
		await process_frame
		if filming:
			root.get_texture().get_image().save_png("%s/f%05d.png" % [FRAMES,frame])
			frame += 1

func shot(name: String) -> void:
	await frames(2)
	if DisplayServer.get_name() == "headless": return
	var path := "%s/%s.png" % [OUT,name]
	root.get_texture().get_image().save_png(path)
	print("FLOWERS still ",path)

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func point(at: Vector2) -> void:
	reach.pointer_override = at
	editor.pointer_override = at
	materials.tray.pointer_override = at

func button(at: Vector2, pressed: bool) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	# Window pixels: a Retina window draws the 1280x720 view at its own scale.
	event.position = root.get_final_transform()*at
	event.global_position = event.position
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2, held := true) -> void:
	point(at)
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform()*at
	event.global_position = event.position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## Glide the pointer from `a` to `b` (viewport) over `count` frames.
func glide(a: Vector2, b: Vector2, count: int, held: bool) -> void:
	var was := a
	for i in range(count):
		var t := float(i+1)/count
		var at := a.lerp(b,t*t*(3.0-2.0*t))
		motion(at,at-was,held)
		was = at
		await frames(1)

## Take `id` from the bar: reach down to it, press it.
func take(id: String) -> void:
	var from: Vector2 = reach.pointer_override if reach.pointer_override != null else Vector2(640,400)
	await glide(from,materials.tray.specimen_centre(id)+Vector2(0,-30),20,false)
	await glide(materials.tray.specimen_centre(id)+Vector2(0,-30),materials.tray.specimen_centre(id),10,false)
	await frames(8)
	var at: Vector2 = materials.tray.specimen_centre(id)
	button(at,true)
	await frames(2)
	button(at,false)
	await frames(4)
	# A window's own controls can take a synthetic click first: the slot's
	# press, as the hand takes it (hand_materials `press`), if it did not land.
	if materials.held != id: materials.take(id)
	await frames(6)

## Sweep what is in hand along plate points `path` over `count` frames.
func sweep(path: Array, count: int) -> void:
	var start := screen(path[0])
	await glide(reach.pointer_override,start,24,false)
	await frames(10)
	print("FLOWERS sweep from ",path[0]," at ",start," land ",reach._land(start)," zone ",reach.reach_at(start)," held ",materials.held)
	button(start,true)
	await frames(4)
	print("FLOWERS pressed: held ",materials.held," reach holding ",reach.holding," handful holding ",editor._handful_holding)
	var was := start
	for i in range(count):
		var t := float(i+1)/count
		var k := t*(path.size()-1)
		var j := mini(int(k),path.size()-2)
		var at := screen(Vector2(path[j]).lerp(path[j+1],k-j))
		motion(at,at-was,true)
		was = at
		await frames(1)
	button(was,false)
	await frames(2)

func run() -> void:
	create_timer(400).timeout.connect(func() -> void: print("FLOWERS timed out"); quit(2))
	var seed_text := "hand-flowers-7"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wind="): wind = float(arg.trim_prefix("--wind="))
		if arg.begins_with("--seed="): seed_text = arg.trim_prefix("--seed=")
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(FRAMES)
	for file in DirAccess.get_files_at(FRAMES): DirAccess.remove_absolute(FRAMES.path_join(file))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-hand-flowers-film-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size = Vector2i(1280,720)
	editor = scene._chunk_editor
	await scene.places.open_land("plain",Library.seed_value(seed_text))
	while scene.places.busy or editor.forming: await process_frame
	var waited := Time.get_ticks_msec()
	while scene._growth.terrain < 0.995 and Time.get_ticks_msec()-waited < 30000: await process_frame
	if not editor.active: scene.set_building(false)
	scene.world_clock.running = false
	reach = scene.hand_reach
	materials = reach.get("materials")
	var air = scene._atmosphere
	air.strength = wind
	air._air_strength = wind
	air.direction_angle = 20.0
	air._air_angle = deg_to_rad(20.0)
	point(Vector2(640,380))
	await frames(90)
	# A closer, lower view than the diorama's, the near meadow filling the frame.
	pose = [scene.target+Vector3(0.0,0.3,0.0),26.0,0.98,float(scene.yaw)]
	# The shell's camera rig owns the pose while the world is live: glide it.
	var rig: Node = scene.get("camera_rig")
	if rig != null:
		print("FLOWERS rig live ",rig.live," places busy ",scene.places.busy," distance ",scene.distance," goal ",pose[1])
		rig.glide_to(pose[0],pose[3],pose[2],pose[1])
		pose = []
	await frames(90)
	print("FLOWERS after glide distance ",scene.distance," camera ",scene.camera.global_position)
	print("FLOWERS window transform ",root.get_final_transform()," window ",DisplayServer.window_get_size())
	print("FLOWERS world %s, %d records, editor active %s, wind %.2f" % [seed_text,editor.data.objects.size(),editor.active,wind])
	await shot("00-plain")
	filming = true
	await take("poppy")
	print("FLOWERS held ",materials.held)
	await shot("01-poppy-in-hand")
	await sweep([Vector2(-6.5,3.5),Vector2(-3.0,1.5),Vector2(0.5,2.6),Vector2(3.5,1.0)],110)
	await frames(40)
	await shot("02-poppy-veil-in-the-air")
	await frames(60)
	await take("cosmos")
	await sweep([Vector2(-5.0,-1.5),Vector2(-1.0,-2.6),Vector2(3.0,-1.4)],90)
	# A tap of sunflowers off to one side: a small handful.
	await take("sunflower")
	var tap := screen(Vector2(5.5,-3.5))
	await glide(reach.pointer_override,tap,24,false)
	button(tap,true)
	await frames(6)
	button(tap,false)
	await frames(30)
	materials.put_back()
	await glide(reach.pointer_override,Vector2(640,200),20,false)
	# Down, written and blooming.
	var began := Time.get_ticks_msec()
	while (editor.handful != null and editor.handful.active()) and Time.get_ticks_msec()-began < 20000: await frames(1)
	await frames(150)
	filming = false
	var grown: Dictionary = editor.last_sowing.get("flowers",{})
	print("FLOWERS last sowing ",grown.get("kinds",{}))
	var kinds := {}
	for item: Dictionary in editor.data.objects:
		if item.get("source") == "hand": kinds[item.asset] = int(kinds.get(item.asset,0))+1
	print("FLOWERS hand-sown records ",kinds)
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	await frames(10)
	await shot("03-grown")
	var base := [scene.target,scene.distance,scene.polar,scene.yaw]
	for k: float in [0.85,0.7]:
		scene.distance = float(base[1])*k
		scene._update_camera()
		await frames(30)
		await shot("03-grown-%d" % roundi(k*100))
	scene.distance = float(base[1])*0.55
	scene.polar = 1.12
	scene.yaw = float(base[3])+0.25
	scene.target = Vector3(base[0])+Vector3(-0.6,0.2,0.4)
	scene._update_camera()
	await frames(40)
	await shot("04-grown-near")
	scene._frame_diorama()
	scene._auto_orbit = false
	scene._update_camera()
	await frames(40)
	await shot("05-grown-diorama")
	var mp4 := "%s/sow-poppies-cosmos.mp4" % OUT
	var out := []
	var code := OS.execute("/opt/homebrew/bin/ffmpeg",["-y","-loglevel","error","-framerate","30","-i","%s/f%%05d.png" % FRAMES,"-vf","scale=1280:-2","-c:v","libx264","-pix_fmt","yuv420p","-crf","20",mp4],out,true)
	print("FLOWERS film ",mp4," frames ",frame," ffmpeg ",code," ",out)
	quit(0)
