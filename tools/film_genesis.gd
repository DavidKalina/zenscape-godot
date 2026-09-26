extends SceneTree
## Film the Genesis slice: launch onto the misty plain, raise land with the
## land brush through real mouse events, then watch the world answer (tremor,
## fog parting, wind, weathering, grass creeping in, shrubs and trees). Run with
## Movie Maker so game time is fixed and the clip plays at true speed:
##   Godot --path . --write-movie /private/tmp/zs-film/genesis.avi --fixed-fps 30 \
##     --script res://tools/film_genesis.gd -- --plain-seed 7
## Saves go to /private/tmp/zs-film, never the player's places.
const FILM_DIR := "/private/tmp/zs-film"
const WATCH_SECONDS := 45.0
var scene: Node3D
var editor: NativeChunkEditor
var cursor := Vector2.ZERO
var pointer := ColorRect.new()
var _orbit := 0.0

func _initialize() -> void:
	run.call_deferred()

func push(event: InputEvent, point: Vector2) -> void:
	event.position = root.get_final_transform()*point
	if event is InputEventMouse:
		event.global_position = event.position
	# Through Input so is_mouse_button_pressed sees the held button, as the
	# stroke loop checks it every frame.
	Input.parse_input_event(event)

func press(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	push(event,cursor)

func motion(held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	push(event,cursor)

func step(held := false) -> void:
	pointer.position = cursor-pointer.size*0.5
	motion(held)
	await process_frame

func hold(seconds: float, held := false) -> void:
	for i in range(int(seconds*30.0)):
		await step(held)

## Ease the pointer through ground points (terrain-local x, z) over some seconds.
func glide(points: Array, seconds: float, held: bool) -> void:
	var frames := maxi(1,int(seconds*30.0))
	var screen: Array[Vector2] = [cursor]
	for xz: Vector2 in points: screen.append(ground(xz.x,xz.y))
	for i in range(1,frames+1):
		var t := float(i)/frames*(screen.size()-1)
		var at := mini(int(t),screen.size()-2)
		var f := t-at
		cursor = screen[at].lerp(screen[at+1],f*f*(3.0-2.0*f))
		await step(held)

func ground(x: float, z: float) -> Vector2:
	var point := editor.terrain.to_global(Vector3(x,editor.data.ground_height(Vector2(x,z)),z))
	return scene.camera.unproject_position(point)

func stroke(points: Array, seconds: float) -> void:
	await glide([points[0]],0.6,false)
	press(true)
	await hold(0.1,true)
	await glide(points.slice(1),seconds,true)
	await hold(0.4,true)
	press(false)
	await hold(0.1)

func look(label: String) -> void:
	print("%s t=%.1f objects=%d peak=%.2f" % [label,Time.get_ticks_msec()/1000.0,editor.data.objects.size(),Array(editor.data.heights).max()])

func run() -> void:
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(FILM_DIR)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = FILM_DIR.path_join("places.json")
	root.add_child(scene)
	while not scene.places_ready:
		await process_frame
	editor = scene._chunk_editor
	while scene._growth.terrain < 0.995:
		await process_frame
	for child in scene._ui.get_children():
		if child is Control: child.visible = false
	scene.target = editor.terrain.to_global(Vector3(0.0,0.8,0.0))
	scene.distance = 26.0
	scene.polar = deg_to_rad(58.0)
	scene.yaw = deg_to_rad(-20.0)
	scene._update_camera()
	pointer.size = Vector2(12,12)
	pointer.color = Color(1,1,1,0.8)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.rotation = PI*0.25
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	overlay.add_child(pointer)
	root.add_child(overlay)
	cursor = root.get_visible_rect().size*Vector2(0.5,0.3)
	await hold(1.0)
	look("plain")
	# A long ridge swept across the back, then worked over again for height.
	await stroke([Vector2(-7.0,-3.0),Vector2(-2.0,-5.0),Vector2(3.0,-4.5),Vector2(7.0,-2.0)],3.2)
	await stroke([Vector2(-4.0,-4.0),Vector2(0.5,-5.0),Vector2(4.5,-3.5)],2.4)
	await hold(2.0)
	look("ridge")
	# A rounded hill in front, built with a slow circling motion.
	await stroke([Vector2(-3.5,3.0),Vector2(-2.0,4.0),Vector2(-4.5,4.5),Vector2(-3.0,2.5),Vector2(-3.5,3.8)],3.0)
	await hold(2.5)
	look("hill")
	# Then let go and watch the world answer while the camera drifts round.
	cursor = Vector2(-40,-40)
	var frames := int(WATCH_SECONDS*30.0)
	for i in range(frames):
		scene.yaw += deg_to_rad(28.0)/frames
		await step()
		if i % 300 == 0: look("watch")
	look("end")
	scene.queue_free()
	await process_frame
	quit()
