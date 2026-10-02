extends SceneTree
## Rendered film, stills and frame times of flowers painted by hand
## (scripts/flower_paint.gd, docs/scenic/handful.md "Flower seed") on a plain
## world with the default hand controls, through the real input path (the
## materials bar, a press, a drag, a release).
##
## First a timed stroke, nothing saved per frame: a poppy stroke across the
## meadow at the middle pip, its frame times while painting and over the
## settle after the release, printed as "PAINT TIMES" (then undone). Then the
## film: poppies painted across the near meadow and gone over again, cosmos
## beside them, a sunflower stand with the wide brush, a Shift pass thinning
## the poppies' end, and a tap. Frames go to /private/tmp/zs-hand-paint/,
## encoded with ffmpeg to captures/hand-paint/paint-poppies-cosmos-sunflowers.mp4;
## stills go beside it.
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/film_hand_flowers.gd -- --no-title [--seed=hand-flowers-7] [--land=plain] [--times-only]
const Library = preload("res://scripts/world_library.gd")
const OUT := "/Users/davidkalina/Documents/Projects/zenscape-godot/captures/hand-paint"
const FRAMES := "/private/tmp/zs-hand-paint"
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
	print("PAINT still ",path)

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func point(at: Vector2) -> void:
	reach.pointer_override = at
	editor.pointer_override = at
	materials.tray.pointer_override = at

func button(at: Vector2, pressed: bool, shift := false) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.shift_pressed = shift
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

## Paint with what is in hand along plate points `path` over `count`
## frames (Shift held when `shift`), a still `still` frames in when given.
## Each frame's time (ms) goes to `times` while painting.
var times: Array = []
func sweep(path: Array, count: int, shift := false, still := "", at_frame := -1) -> void:
	var start := screen(path[0])
	await glide(reach.pointer_override,start,24,false)
	await frames(10)
	button(start,true,shift)
	await frames(1)
	print("PAINT pressed at ",path[0],": held ",materials.held," reach holding ",reach.holding," painting ",editor.flower_paint != null)
	var was := start
	var last := Time.get_ticks_usec()
	for i in range(count):
		var t := float(i+1)/count
		var k := t*(path.size()-1)
		var j := mini(int(k),path.size()-2)
		var at := screen(Vector2(path[j]).lerp(path[j+1],k-j))
		motion(at,at-was,true)
		was = at
		await frames(1)
		var now := Time.get_ticks_usec()
		times.append((now-last)/1000.0)
		last = now
		if i == at_frame and not still.is_empty(): await shot(still)
	button(was,false,shift)
	await frames(2)

## Frame times (ms) of `count` frames from now; the editor's refresh stage
## after each goes to `stages`.
var stages: Array = []
func frame_times(count: int) -> Array:
	var out := []
	stages = []
	var last := Time.get_ticks_usec()
	for i in range(count):
		await process_frame
		var now := Time.get_ticks_usec()
		out.append((now-last)/1000.0)
		stages.append("%s/%.1f" % [editor.refresh_stage,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0])
		last = now
	return out

static func stats(values: Array) -> String:
	if values.is_empty(): return "none"
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted: total += float(v)
	return "n %d, mean %.1f, median %.1f, p95 %.1f, worst %.1f ms" % [sorted.size(),total/sorted.size(),float(sorted[sorted.size()/2]),float(sorted[mini(int(sorted.size()*0.95),sorted.size()-1)]),float(sorted.back())]

## The timed stroke: nothing saved per frame, so the times are the game's.
func time_stroke() -> void:
	await take("poppy")
	materials.set_size(1)
	var path := [Vector2(-7.0,5.0),Vector2(-2.0,3.5),Vector2(2.0,4.5),Vector2(7.0,3.0)]
	var idle := await frame_times(60)
	times = []
	await sweep(path,150)
	var painting := times.duplicate()
	var after := await frame_times(90)
	var work: Array = editor.paint_usec.map(func(u: int) -> float: return u/1000.0)
	var summary: Dictionary = editor.last_paint
	print("PAINT TIMES idle: ",stats(idle))
	print("PAINT TIMES painting (%d flowers %s): %s" % [summary.get("placed",[]).size(),str(summary.get("kinds",{})),stats(painting)])
	print("PAINT TIMES paint work on the main thread a frame: ",stats(work))
	print("PAINT TIMES the 90 frames after release (the settle): ",stats(after))
	print("PAINT TIMES settle stages (us): refresh ",editor.last_refresh_usec," instances ",editor.content.last_instance_usec)
	print("PAINT TIMES painting frames over 30 ms: ",range(painting.size()).filter(func(i: int) -> bool: return painting[i] > 30.0).map(func(i: int) -> String: return "%d (%.1f ms)" % [i,painting[i]]))
	var slow := range(after.size()).filter(func(i: int) -> bool: return after[i] > 30.0)
	print("PAINT TIMES release (us): wash ",summary.get("finish_usec",0)," end_stroke ",summary.get("end_stroke_usec",0)," settle call ",summary.get("settle_call_usec",0),"; frames after release over 30 ms: ",slow.map(func(i: int) -> String: return "%d (%.1f ms, stage/process %s)" % [i,after[i],stages[i]]))
	editor.undo()
	await frame_times(60)
	materials.put_back()
	await frames(20)

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: print("PAINT timed out"); quit(2))
	var seed_text := "hand-flowers-7"
	var land := "plain"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wind="): wind = float(arg.trim_prefix("--wind="))
		if arg.begins_with("--seed="): seed_text = arg.trim_prefix("--seed=")
		if arg.begins_with("--land="): land = arg.trim_prefix("--land=")
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
	await scene.places.open_land(land,Library.seed_value(seed_text))
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
	print("PAINT world %s %s, %d records, editor active %s, wind %.2f" % [land,seed_text,editor.data.objects.size(),editor.active,wind])
	await time_stroke()
	if "--times-only" in OS.get_cmdline_user_args():
		quit(0)
		return
	await shot("00-plain")
	filming = true
	await take("poppy")
	materials.set_size(1)
	await shot("01-poppy-in-hand")
	var poppies := [Vector2(-6.5,3.5),Vector2(-3.0,1.5),Vector2(0.5,2.6),Vector2(3.5,1.0)]
	await sweep(poppies,110,false,"02-painting-poppies",70)
	await frames(20)
	await shot("03-one-pass")
	# Over it again: it thickens toward a full drift's core.
	await sweep([poppies[1],poppies[2],poppies[1]],80)
	await frames(30)
	await shot("04-two-passes")
	await take("cosmos")
	await sweep([Vector2(-5.0,-1.5),Vector2(-1.0,-2.6),Vector2(3.0,-1.4),Vector2(-1.0,-2.4)],120)
	# A sunflower stand: the wide brush, held a moment at the end.
	await take("sunflower")
	materials.set_size(2)
	await sweep([Vector2(4.5,-5.0),Vector2(6.5,-3.0),Vector2(6.6,-2.8)],70)
	materials.set_size(1)
	# Shift thins the poppies' far end.
	await take("poppy")
	await sweep([Vector2(2.0,2.0),Vector2(3.6,1.0)],40,true)
	# A tap of dandelions.
	await take("dandelion")
	var tap := screen(Vector2(-6.0,-4.5))
	await glide(reach.pointer_override,tap,24,false)
	button(tap,true)
	await frames(4)
	button(tap,false)
	await frames(30)
	materials.put_back()
	await glide(reach.pointer_override,Vector2(640,24),20,false)
	await frames(90)
	filming = false
	var kinds := {}
	for item: Dictionary in editor.data.objects:
		if item.get("source") == "hand": kinds[item.asset] = int(kinds.get(item.asset,0))+1
	print("PAINT hand-painted records ",kinds)
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	await frames(10)
	await shot("05-painted")
	var base := [scene.target,scene.distance,scene.polar,scene.yaw]
	scene.distance = float(base[1])*0.7
	scene._update_camera()
	await frames(30)
	await shot("06-painted-70")
	scene.distance = float(base[1])*0.5
	scene.polar = 1.12
	scene.yaw = float(base[3])+0.25
	scene.target = Vector3(base[0])+Vector3(-0.6,0.2,0.4)
	scene._update_camera()
	await frames(40)
	await shot("07-painted-near")
	scene.distance = float(base[1])*0.45
	scene.polar = 1.05
	scene.yaw = float(base[3])-0.35
	scene.target = editor.terrain.to_global(Vector3(5.5,height(Vector2(5.5,-4.0)),-4.0))
	scene._update_camera()
	await frames(40)
	await shot("08-sunflower-stand")
	scene._frame_diorama()
	scene._auto_orbit = false
	scene._update_camera()
	await frames(40)
	await shot("09-diorama")
	var mp4 := "%s/paint-poppies-cosmos-sunflowers.mp4" % OUT
	var out := []
	var code := OS.execute("/opt/homebrew/bin/ffmpeg",["-y","-loglevel","error","-framerate","30","-i","%s/f%%05d.png" % FRAMES,"-vf","scale=1280:-2","-c:v","libx264","-pix_fmt","yuv420p","-crf","20",mp4],out,true)
	print("PAINT film ",mp4," frames ",frame," ffmpeg ",code," ",out)
	quit(0)
