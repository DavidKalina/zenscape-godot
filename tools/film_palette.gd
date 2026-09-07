extends SceneTree
## Film the palette in use: hover and drag tiles onto the ground, paint a stroke
## and let the drop reactions play. Frames land in /tmp for ffmpeg; the scene
## runs live, so the clip's frame rate is measured and written beside the frames.
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

func ground(x: float, z: float) -> Vector2:
	var point := editor.terrain.to_global(Vector3(x,editor.data.ground_height(Vector2(x,z)),z))
	return scene.camera.unproject_position(point)

func drag(id: String, x: float, z: float, settle: int) -> void:
	if editor.pick(ground(x,z)) == null:
		push_error("%s target (%s, %s) is not open terrain on screen" % [id,x,z])
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
	print(label," frame=",frame," objects=",editor.data.objects.size()," reactions=",editor.reactions.active_count()," revision=",editor.content.revision," paused=",scene._paused," ",scales)

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
	scene.target = editor.terrain.to_global(Vector3(0.8,1.6,-0.4))
	scene.distance = 15.0
	scene.polar = deg_to_rad(54.0)
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
	var seconds := (Time.get_ticks_msec()-started)/1000.0
	var fps := frame/seconds
	FileAccess.open(DIRECTORY.path_join("fps.txt"),FileAccess.WRITE).store_string("%.2f" % fps)
	print("Palette film: ",frame," frames over %.1f s (%.1f fps); objects " % [seconds,fps],editor.data.objects.size())
	scene.queue_free()
	await process_frame
	quit()
