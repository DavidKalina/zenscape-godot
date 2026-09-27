extends SceneTree
## Photo mode, rendered: enter it from the palette, take a photo from the
## orbit and one from the ground eye with depth of field on a clicked tree,
## then go back. Writes the photos and three raw stills (strip showing, the
## inspect label, the shell after leaving) and prints main-thread timings and
## the worst frames around entering, capturing and leaving. The shell's first
## Look is timed on its own first: parking the editor the first time costs
## one ~26 ms frame on the Mac, whichever of Tab or P does it. Rendered only when
## asked for; keep runs short:
##   Godot --path . --windowed --resolution 1280x800 --script res://tools/capture_photo_mode.gd \
##     -- --seed 184 --photo-dir=/private/tmp/zs-photo/out
## Saves go to a temporary places folder, never the player's.
const OUT := "/private/tmp/zs-photo/out"
var scene: Node3D
var photo: Node
var _last := 0
var _worst := 0.0

func _initialize() -> void:
	run.call_deferred()

## Wait `count` frames; returns the worst frame in milliseconds.
func frames(count: int) -> float:
	var worst := 0.0
	for i in range(count):
		await process_frame
		var now := Time.get_ticks_usec()
		if _last > 0: worst = maxf(worst,(now-_last)/1000.0)
		_last = now
	return worst

## Each frame's time over `count` frames, in milliseconds.
func frame_list(count: int) -> Array:
	var times := []
	for i in range(count):
		await process_frame
		var now := Time.get_ticks_usec()
		if _last > 0: times.append(snappedf((now-_last)/1000.0,0.1))
		_last = now
	return times

func still(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image != null: image.save_png(OUT.path_join(name))
	print("PHOTO still ",OUT.path_join(name))

func take(label: String) -> String:
	photo.capture()
	var path: String = await photo.saved
	var t: Dictionary = photo.timings
	print("PHOTO %s -> %s  hide %.2f ms, readback %.2f ms, main-thread total %.2f ms" % [label,path,t.hide/1000.0,t.readback/1000.0,t.capture/1000.0])
	if not path.is_empty():
		var image := Image.load_from_file(path)
		var sum := 0.0
		var sum2 := 0.0
		var n := 0
		for y in range(0,image.get_height(),17):
			for x in range(0,image.get_width(),17):
				var l := image.get_pixel(x,y).get_luminance()
				sum += l
				sum2 += l*l
				n += 1
		var mean := sum/n
		print("PHOTO %s size %dx%d  luminance mean %.3f sd %.3f" % [label,image.get_width(),image.get_height(),mean,sqrt(maxf(sum2/n-mean*mean,0.0))])
	return path

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# A modest window, not the project's full screen.
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600,1000)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = OUT.path_join("places-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready:
		await process_frame
	root.mode = Window.MODE_WINDOWED
	await frames(30)
	root.size = Vector2i(1600,1000)
	# --seed regrows on the next frame; wait for the new world to settle.
	while scene._growth.terrain < 0.995 or scene.places.busy or scene._chunk_editor.forming:
		await process_frame
	photo = scene.photo
	print("PHOTO viewport ",root.get_texture().get_size()," window ",root.size)
	await frames(150)
	# Enter and leave once first, and time each frame, to tell a first-time
	# cost from a per-entry one.
	await frames(5)
	# Look (Tab) first, so its own first-time cost is not counted as photo mode's.
	scene.set_looking(true)
	print("PHOTO first Look frames ",await frame_list(8))
	scene.select_brush(scene.brush)
	print("PHOTO brush again frames ",await frame_list(8))
	scene.creation_palette.photo_button.pressed.emit()
	print("PHOTO first entry frames ",await frame_list(8))
	photo.leave()
	print("PHOTO first leave frames ",await frame_list(8))
	await frames(60)
	var before := await frames(30)
	scene.creation_palette.photo_button.pressed.emit()
	if not photo.active:
		print("PHOTO could not enter: menu %s crafting %s busy %s has_world %s" % [scene._menu.visible,scene.crafting,scene.places.busy,scene._has_world])
		quit(1)
		return
	var entering := await frames(10)
	print("PHOTO second entry done")
	print("PHOTO enter main-thread %.2f ms (Look %.2f ms of it); worst frame before %.1f ms, entering %.1f ms" % [photo.timings.enter/1000.0,photo.timings.look/1000.0,before,entering])
	print("PHOTO pose target %s yaw %.2f polar %.2f distance %.1f fov %.1f" % [scene.target,scene.yaw,scene.polar,scene.distance,scene.camera.fov])
	# Orbit a little lower and closer, as a player composing would.
	photo._goal.polar = 1.2
	photo._goal.distance = photo._goal.distance*0.7
	photo._goal.yaw += 0.5
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_visible_rect().size*Vector2(0.5,0.6)
	Input.parse_input_event(motion)
	await frames(60)
	print("PHOTO composed target %s yaw %.2f polar %.2f distance %.1f" % [scene.target,scene.yaw,scene.polar,scene.distance])
	await still("still-strip.png")
	_last = 0
	await frames(5)
	var path := await take("orbit")
	_last = Time.get_ticks_usec()
	var capturing := await frames(10)
	print("PHOTO worst frame around the orbit capture %.1f ms" % capturing)
	# Down to the ground, focus on the nearest tree ahead and name it.
	photo.set_ground(true)
	await frames(150)
	photo.set_focus(true)
	var clicked := Vector2.ZERO
	var nearest := INF
	var editor: NativeChunkEditor = scene._chunk_editor
	var size := root.get_visible_rect().size
	for item: Dictionary in editor.data.objects:
		var h: Variant = editor.data.ground_height(Vector2(float(item.x),float(item.z)))
		if h == null: continue
		var p := editor.terrain.to_global(Vector3(float(item.x),float(h)+0.5,float(item.z)))
		if scene.camera.is_position_behind(p): continue
		var at: Vector2 = scene.camera.unproject_position(p)
		if not Rect2(size*0.2,size*0.6).has_point(at): continue
		var d: float = scene.camera.global_position.distance_to(p)
		if d > 2.0 and d < nearest:
			nearest = d
			clicked = at
	if nearest < INF:
		var t0 := Time.get_ticks_usec()
		var found: Dictionary = photo.inspect(clicked)
		print("PHOTO inspect %.2f ms at %s -> %s" % [(Time.get_ticks_usec()-t0)/1000.0,clicked,found.get("title","nothing")+" · "+str(found.get("detail",""))])
		photo.click(clicked)
	await frames(60)
	await still("still-ground-label.png")
	_last = 0
	await frames(5)
	await take("ground")
	_last = Time.get_ticks_usec()
	var after_ground := await frames(10)
	print("PHOTO worst frame after the ground capture %.1f ms" % after_ground)
	await frames(20)
	var leaving_before := await frames(5)
	var key := InputEventKey.new()
	key.keycode = KEY_P
	key.pressed = true
	photo.handle(key)
	var leaving := await frames(45)
	print("PHOTO leave main-thread %.2f ms; worst frame leaving %.1f ms (before %.1f)" % [photo.timings.leave/1000.0,leaving,leaving_before])
	await still("still-after.png")
	print("PHOTO done ",path)
	scene.queue_free()
	await process_frame
	quit()
