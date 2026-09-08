extends SceneTree
## Film the palette in use: hover and drag tiles onto the ground, paint a stroke,
## let the drop reactions play, carry a mountain in by its ghost and change the
## sky from its tab. Frames land in /tmp for ffmpeg; the scene runs live, so the
## clip's frame rate is measured and written beside the frames. Encode with
## ffmpeg -y -framerate $(cat /private/tmp/palette-film-frames/fps.txt) \
##   -i /private/tmp/palette-film-frames/%04d.jpg -vf "scale=1280:-2,fps=30" \
##   -c:v libx264 -pix_fmt yuv420p -crf 20 docs/garden/palette-demo.mp4
const DIRECTORY := "/private/tmp/palette-film-frames"
var frame := 0
var scene: Node3D
var editor: NativeChunkEditor
var palette: NativeBuildPalette
var cursor := Vector2.ZERO
var pointer := ColorRect.new()

func _initialize() -> void:
	run.call_deferred()

func push(event: InputEvent, point: Vector2) -> void:
	event.position = root.get_final_transform()*point
	if event is InputEventMouse:
		event.global_position = event.position
	root.push_input(event)

func press(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	push(event,cursor)

func motion() -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	push(event,cursor)

func shoot() -> void:
	pointer.position = cursor-pointer.size*0.5
	RenderingServer.force_draw(false)
	await process_frame
	root.get_texture().get_image().save_jpg(DIRECTORY.path_join("%04d.jpg" % frame),0.92)
	frame += 1

func hold(frames: int) -> void:
	for i in range(frames):
		motion()
		await shoot()

## Ease the pointer to a point over a number of frames, sending motion each frame.
func glide(target: Vector2, frames: int) -> void:
	var from := cursor
	for i in range(1,frames+1):
		var t := float(i)/frames
		t = t*t*(3.0-2.0*t)
		cursor = from.lerp(target,t)
		motion()
		await shoot()

func tile(id: String) -> Vector2:
	return palette.tile_for(id).get_global_rect().get_center()

func tab(name: String) -> Vector2:
	return palette._tabs_by_name[name].get_global_rect().get_center()

func swatch(id: String) -> Vector2:
	return palette.sky_tile_for(id).get_global_rect().get_center()

## Click whatever sits under the pointer after gliding to it.
func click(target: Vector2, glide_frames := 14, settle := 8) -> void:
	await glide(target,glide_frames)
	press(true)
	await hold(2)
	press(false)
	await hold(settle)

## The first of several ground spots that is open terrain on screen, so the
## film survives a camera or bar change without aiming at the palette.
func spot(candidates: Array) -> Vector2:
	for xz: Vector2 in candidates:
		if editor.pick(ground(xz.x,xz.y)) != null:
			return xz
	push_error("no open ground among %s" % [candidates])
	return candidates[0]

func ground(x: float, z: float) -> Vector2:
	var point := editor.terrain.to_global(Vector3(x,editor.data.ground_height(Vector2(x,z)),z))
	return scene.camera.unproject_position(point)

func drag(id: String, x: float, z: float, settle: int) -> void:
	if editor.pick(ground(x,z)) == null:
		push_error("%s target (%s, %s) is not open terrain on screen" % [id,x,z])
		return
	await glide(tile(id),16)
	await hold(8)
	press(true)
	await hold(3)
	await glide(ground(x,z),26)
	await hold(4)
	press(false)
	state("%s dropped" % id)
	await hold(settle)
	state("%s settled" % id)

func state(label: String) -> void:
	var scales := []
	for node in editor.content.find_children("*","MultiMeshInstance3D",true,false):
		if node.multimesh != null and node.multimesh.instance_count > 0:
			scales.append("%s:%.2f" % [node.name,node.multimesh.get_instance_transform(0).basis.get_scale().x])
	print(label," frame=",frame," objects=",editor.data.objects.size()," reactions=",editor.reactions.active_count()," revision=",editor.content.revision," peak=%.2f" % Array(editor.data.heights).max()," ",scales)

func run() -> void:
	root.size = Vector2i(1600,1000)
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	editor = scene._chunk_editor
	palette = scene._build_palette
	editor.set_active(true)
	editor.start_flat()
	editor.data.begin_stroke()
	editor.data.grass.fill(0.8)
	editor.data.end_stroke()
	editor.refresh()
	for child in scene._ui.get_children():
		if child is Control and child != palette:
			child.visible = false
	# The bar covers the bottom two fifths of the frame, so the orbit target
	# sits nearer the camera than the action and the ground reads above it.
	scene.target = editor.terrain.to_global(Vector3(0.8,1.6,3.4))
	scene.distance = 16.0
	scene.polar = deg_to_rad(52.0)
	scene.yaw = deg_to_rad(-12.0)
	scene._update_camera()
	pointer.size = Vector2(14,14)
	pointer.color = Color(1,1,1,0.85)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.pivot_offset = pointer.size*0.5
	pointer.rotation = PI*0.25
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	overlay.add_child(pointer)
	root.add_child(overlay)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	palette._show_category("Place")
	cursor = root.get_visible_rect().size*Vector2(0.5,0.35)
	for i in range(6):
		await process_frame
	var started := Time.get_ticks_msec()
	await hold(12)
	await drag("tree",-2.4,-0.6,30)
	await drag("rock",1.2,1.4,26)
	await drag("flower",-2.4,-2.2,20)
	await glide(tab("Cover"),14)
	press(true)
	await hold(2)
	press(false)
	await hold(8)
	await glide(tile("paint"),12)
	press(true)
	await hold(2)
	press(false)
	await hold(8)
	editor.paint_color = Color("c0663f")
	editor.set_setting("paint_amount",0.7)
	editor.set_setting("radius",2.0)
	await glide(ground(2.6,-1.6),14)
	press(true)
	await glide(ground(4.0,0.6),18)
	await glide(ground(2.8,2.4),14)
	press(false)
	await hold(10)
	await glide(tab("Place"),14)
	press(true)
	await hold(2)
	press(false)
	await hold(6)
	await drag("bigfoot_tree",6.5,-7.5,44)
	# A mountain rides in on its ghost, sized down so it reads inside the frame.
	await click(tab("Landscape"))
	editor.set_setting("mountain_radius",3.0)
	editor.set_setting("mountain_peak",4.5)
	var peak := spot([Vector2(-6.5,3.0),Vector2(-6.0,0.5),Vector2(5.0,3.0),Vector2(-4.5,-6.0)])
	await drag("mountain",peak.x,peak.y,26)
	# Then the sky: snow from a swatch, the time of day from its slider.
	await click(tab("Sky"))
	await click(swatch("weather_snow"),14,36)
	var time: Control = palette.sky_row("time").control
	var slot := time.get_global_rect()
	await glide(Vector2(slot.position.x+slot.size.x*0.36,slot.get_center().y),14)
	press(true)
	await hold(2)
	await glide(Vector2(slot.position.x+slot.size.x*0.70,slot.get_center().y),30)
	press(false)
	await hold(24)
	await click(swatch("mood_0"),14,30)
	var seconds := (Time.get_ticks_msec()-started)/1000.0
	var fps := frame/seconds
	FileAccess.open(DIRECTORY.path_join("fps.txt"),FileAccess.WRITE).store_string("%.2f" % fps)
	print("Palette film: ",frame," frames over %.1f s (%.1f fps); objects " % [seconds,fps],editor.data.objects.size())
	scene.queue_free()
	await process_frame
	quit()
