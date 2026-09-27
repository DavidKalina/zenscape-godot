extends SceneTree
## Film the water ball (scripts/water_ball.gd) close up on the Genesis plain,
## through the player's input path: press with water in hand, hold while the
## camera swings round the growing ball, drag it about, release, and watch it
## splash and the pond fill. Saves JPG frames for judging the look and motion;
## rendered, so a window opens for the run (about a minute):
##   Godot --path . --fixed-fps 30 --script res://tools/film_water_ball.gd \
##     -- --out=/private/tmp/zs-ball/a --every=3
##   ffmpeg -framerate 30 -i /private/tmp/zs-ball/a/f%04d.jpg ...  (with --every=1)
## Knobs: --at=x,z (terrain-local drop point), --hold=s (grow time before the
## drag), --phase=0.4 (sky), --distance=6.5, --only=hold (stop before release).
const FPS := 30.0
var scene: Node3D
var editor: NativeChunkEditor
var out := "/private/tmp/zs-ball/frames"
var every := 3
var at := Vector2(-3.0,2.0)
var hold_seconds := 5.0
var phase := -1.0
var distance := 9.0
var only := ""
var mood := "Alpine daylight"
var hide_ball := false
var weather := "clear"
var profile := false
var cursor := Vector2.ZERO
var frame := 0
var yaw := 20.0
var polar := 62.0
var lift := 2.2

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--every="): every = int(arg.trim_prefix("--every="))
		if arg.begins_with("--hold="): hold_seconds = float(arg.trim_prefix("--hold="))
		if arg.begins_with("--phase="): phase = float(arg.trim_prefix("--phase="))
		if arg.begins_with("--distance="): distance = float(arg.trim_prefix("--distance="))
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg.begins_with("--mood="): mood = arg.trim_prefix("--mood=")
		if arg == "--hide-ball": hide_ball = true
		if arg == "--profile": profile = true
		if arg.begins_with("--weather="): weather = arg.trim_prefix("--weather=")
		if arg.begins_with("--at="):
			var parts := arg.trim_prefix("--at=").split(",")
			at = Vector2(float(parts[0]),float(parts[1]))
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func push(event: InputEvent) -> void:
	event.position = root.get_final_transform()*cursor
	if event is InputEventMouse: event.global_position = event.position
	Input.parse_input_event(event)

func press(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	push(event)

func ground(p: Vector2) -> Vector3:
	return editor.terrain.to_global(Vector3(p.x,float(editor.data.ground_height(p)),p.y))

## One frame: camera on the ball's hover height over `look_at`, the pointer on
## `point`'s ground, then save every `every` frames.
func step(point: Vector2, look_at: Vector2, held: bool) -> void:
	var focus := ground(look_at)
	scene.target = focus+Vector3.UP*lift
	scene.distance = distance
	scene.polar = deg_to_rad(polar)
	scene.yaw = deg_to_rad(yaw)
	scene._update_camera()
	cursor = scene.camera.unproject_position(ground(point))
	editor.pointer_override = cursor
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	push(motion)
	if hide_ball and editor.ball != null: editor.ball.get_node("Ball").visible = false
	await process_frame
	if frame % every == 0: save("f%04d" % (frame/every))
	frame += 1

func save(name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null: return
	if image.get_width() > 1280: image.resize(1280,int(image.get_height()*1280.0/image.get_width()),Image.INTERPOLATE_BILINEAR)
	image.save_jpg(out.path_join(name+".jpg"),0.88)

func run() -> void:
	root.size = Vector2i(1600,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-ball-film-%d/places.json" % Time.get_ticks_usec()
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	while scene._growth.terrain < 0.995: await process_frame
	scene._notice.visible = false
	if scene.places.get("cover") != null: scene.places.cover.visible = false
	if scene.creation_palette != null: scene.creation_palette.visible = false
	if not mood.is_empty(): scene.apply_scene_mood(mood)
	if phase >= 0.0: scene._celestial.set_phase(phase)
	if not weather.is_empty(): scene._precipitation.set_weather(scene._precipitation.PRESET_NAMES.find(weather),true)
	scene.select_brush("water")
	# Clean frames: every overlay off (they would also block the pointer's pick).
	for layer: Node in scene.find_children("*","CanvasLayer",true,false): layer.visible = false
	editor.ball_settled.connect(func(outcome: Dictionary) -> void: print("FILM settled t=%.2f " % (frame/FPS),outcome))
	for i in range(int(FPS*1.0)): await step(at,at,false)
	print("FILM press t=%.2f" % (frame/FPS))
	press(true)
	# Grow while the camera swings a quarter round.
	var start_yaw := yaw
	var frames := int(hold_seconds*FPS)
	for i in range(frames):
		yaw = start_yaw+70.0*smoothstep(0.0,1.0,float(i)/frames)
		await step(at,at,true)
	print("FILM grown t=%.2f volume=%.2f radius=%.2f fish=%d" % [frame/FPS,editor.ball_volume,editor.ball.radius,editor.ball.carried().size()])
	# Drag it round a small loop and back.
	frames = int(2.4*FPS)
	for i in range(frames):
		var angle := TAU*float(i)/frames
		var point := at+Vector2(sin(angle)*1.6,(1.0-cos(angle))*0.9)
		await step(point,at,true)
	for i in range(int(0.6*FPS)): await step(at,at,true)
	if only == "hold":
		if profile: await _profile()
		quit()
		return
	print("FILM release t=%.2f volume=%.2f" % [frame/FPS,editor.ball_volume])
	press(false)
	for i in range(int(6.0*FPS)): await step(at,at,false)
	print("FILM end t=%.2f frames=%d" % [frame/FPS,frame])
	scene.queue_free()
	await process_frame
	quit()

## Wall-clock frame intervals (ms) with the held ball drawn, then hidden. Run
## without --fixed-fps; readings at the swapchain cap (8.3 ms windowed) mean
## both are under it.
func _profile() -> void:
	var results := {}
	for label in ["ball","hidden","bare","ball_again"]:
		var gaps := []
		var previous := Time.get_ticks_usec()
		for i in range(150):
			await step(at,at,true)
			editor.ball.get_node("Ball").visible = label not in ["hidden","bare"]
			editor.ball.get_node("Ground").visible = label != "bare"
			editor.ball.get_node("Beads").visible = label != "bare"
			var now := Time.get_ticks_usec()
			if i >= 20: gaps.append((now-previous)/1000.0)
			previous = now
		gaps.sort()
		results[label] = {"median":snappedf(gaps[gaps.size()/2],0.01),"p95":snappedf(gaps[int(gaps.size()*0.95)],0.01),"max":snappedf(gaps.back(),0.01)}
	print("PROFILE ",JSON.stringify(results))
