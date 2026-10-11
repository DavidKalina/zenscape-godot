extends SceneTree
## The unified cloud volume (scripts/cloud_volume.gd) against the near sea
## and towers it replaces, rendered in one run so the sky, season and
## weather match: at each spot a still with the volume, then with the old
## renderers (CloudVolume `set_enabled`), and each one's frame time (vsync
## off) and GPU render time. On by default (not with --old-clouds). Shots:
##   above: high over the sea, looking down across it, noon;
##   low_sun: skimming the heaps' tops toward the low sun, golden hour;
##   approach: the home tower from a few hundred metres, noon;
##   crown: under its shoulder looking up the column, noon;
##   inside: in its heart, noon;
##   glider: the chase view heading into it, noon;
##   fly_in: flying into its side at 45 m/s, noon;
##   sunset: the tower and the sea with the sun on the horizon;
##   night: over the sea under the moon.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_cloud_volume.gd \
##     -- --no-title --out=/private/tmp/zs-cloud-volume [--only=above,inside]
##     [--volume-only]
const GOLDEN_SUN := 0.1
const SUNSET_SUN := 0.01
var scene: Node3D
var eye: Node
var volume: Node3D
var out := "/private/tmp/zs-cloud-volume"
var only: Array = []
var volume_only := false
## --spans prints the frame's longest GPU spans at each still.
var dump_spans := "--spans" in OS.get_cmdline_user_args()
## --bare also times each spot with no near sea or towers drawn at all, so
## the volume's and the old renderers' costs show as the difference.
var bare := "--bare" in OS.get_cmdline_user_args()
## --size=WxH for the window (the stills are saved at 1280x720).
var window_size := Vector2i(1280,720)
var noon := WorldClock.hour_for_phase(0.5)
var golden := WorldClock.hour_for_phase(0.75-asin(clampf(GOLDEN_SUN/WorldClock.elevation_for_phase(0.5),-1.0,1.0))/TAU)
var sunset := WorldClock.hour_for_phase(0.75-asin(clampf(SUNSET_SUN/WorldClock.elevation_for_phase(0.5),-1.0,1.0))/TAU)
var night := WorldClock.hour_for_phase(0.0)

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label+".png")
	image.save_png(path)
	print("CLOUDVOL still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument == "--volume-only": volume_only = true
		elif argument.begins_with("--size="):
			var wh := argument.trim_prefix("--size=").split("x")
			window_size = Vector2i(int(wh[0]),int(wh[1]))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("cloud volume capture timed out"); quit(2))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(window_size)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	volume = scene.look_pass.cloud_volume
	if volume == null:
		push_error("no cloud volume: drop --old-clouds and run with a RenderingDevice")
		quit(1)
		return
	scene.world_clock.running = false
	eye = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	await frames(5)
	eye._launch(6.0,false)
	eye.set_process(false)
	eye._layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var islands: Node3D = eye.islands
	for i in range(900):
		if islands.built(): break
		await frames(1)
	islands.towers.advance(0.6,Vector3.ZERO)
	islands.towers.flush()
	if not islands.towers.built.has("0,0"):
		push_error("no sky tower was made")
		quit(1)
		return
	var b: Dictionary = islands.towers.built["0,0"]
	var first := true
	for shot: Dictionary in _shots(islands.towers,b):
		if not only.is_empty() and shot.label not in only: continue
		for mode: String in (["volume"] if volume_only else (["volume","old","none"] if bare else ["volume","old"])):
			var on := mode == "volume"
			volume.set_enabled(on)
			_bare(mode == "none")
			await _hold(shot,240 if first else 60)
			first = false
			# A moving shot is still moving when taken: no timing first.
			var timing := Vector2.ZERO if shot.has("move") else await _timing(60 if bare else 30)
			var tag := mode
			print("CLOUDVOL %s-%s frame %.2f ms, gpu %.2f ms, towers %d, wakes %d, runs %d" % [shot.label,tag,timing.x,timing.y,volume.tower_count,volume.wake_count,volume.effect.runs])
			if mode != "none": await still("%s-%s" % [shot.label,tag])
	_bare(false)
	volume.set_enabled(true)
	print("CLOUDVOL done")
	quit(0)

## With `none`, neither the volume nor the old sea and towers draw.
func _bare(none: bool) -> void:
	if not none: return
	scene.look_pass.sea.mesh = null
	for b: Dictionary in eye.islands.towers.built.values():
		var v := (b.node as Node3D).get_node_or_null("Volume") as Node3D
		if v != null: v.visible = false

func _shots(towers: Node3D, b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var g := func(local: Vector3) -> Vector3: return towers.global_of(b,local)
	var axis: Vector2 = shape._axis(20.0)
	var heart: Vector3 = g.call(Vector3(axis.x,20.0,axis.y))
	var middle: Vector3 = g.call(Vector3(shape._axis(80.0).x,80.0,shape._axis(80.0).y))
	var plate := Vector3(0.0,25.0,0.0)
	var toward := Vector3(heart.x-plate.x,0.0,heart.z-plate.z).normalized()
	var side := Vector3(-toward.z,0.0,toward.x)
	var near_side := heart
	while towers.depth(near_side) > 0.0: near_side -= toward*2.0
	var shots := []
	var away := plate-toward*200.0+side*300.0
	shots.append({"label":"above","hour":noon,"eye":away+Vector3.UP*90.0,"look":away+side*700.0+Vector3.DOWN*300.0})
	shots.append({"label":"low_sun","hour":golden,"eye":away+Vector3(0.0,-60.0-away.y,0.0),"look":Vector3.ZERO,"to_sun":true})
	shots.append({"label":"approach","hour":noon,"eye":heart-toward*520.0,"look":middle})
	shots.append({"label":"crown","hour":noon,"eye":near_side-toward*170.0+Vector3.DOWN*30.0,"look":g.call(Vector3(shape._axis(shape.top()).x,shape.top()-60.0,shape._axis(shape.top()).y))})
	shots.append({"label":"inside","hour":noon,"eye":heart,"look":heart+toward*100.0+Vector3.UP*4.0})
	shots.append({"label":"glider","hour":noon,"eye":near_side-toward*60.0,"look":heart,"chase":true})
	# Flying into the tower's side at speed, the still taken at its edge
	# (any smear of the temporal resolve shows here).
	shots.append({"label":"fly_in","hour":noon,"eye":near_side-toward*150.0,"look":heart,"move":toward*45.0})
	shots.append({"label":"sunset","hour":sunset,"eye":heart-toward*700.0+side*200.0+Vector3.UP*30.0,"look":middle})
	shots.append({"label":"night","hour":night,"eye":away+Vector3.UP*60.0,"look":away+side*700.0+Vector3.DOWN*250.0})
	return shots

## Mean frame time and the GPU's time for the whole frame (ms) over
## `count` frames, from the rendering device's timestamps (first to last);
## each GPU span of interest is printed too.
func _timing(count: int) -> Vector2:
	await RenderingServer.frame_post_draw
	var from := Time.get_ticks_usec()
	var gpu := 0.0
	var spans := {}
	var rd := RenderingServer.get_rendering_device()
	for i in range(count):
		await RenderingServer.frame_post_draw
		if rd == null: continue
		var n := rd.get_captured_timestamps_count()
		if n < 2: continue
		gpu += (rd.get_captured_timestamp_gpu_time(n-1)-rd.get_captured_timestamp_gpu_time(0))/1000.0
		for k in range(n-1):
			var key := rd.get_captured_timestamp_name(k)
			spans[key] = float(spans.get(key,0.0))+(rd.get_captured_timestamp_gpu_time(k+1)-rd.get_captured_timestamp_gpu_time(k))/1000.0
	if dump_spans:
		var keys := spans.keys()
		keys.sort_custom(func(a, b) -> bool: return spans[a] > spans[b])
		for key in keys.slice(0,14): print("CLOUDVOL   span %-40s %.3f ms" % [key,spans[key]/count])
	return Vector2(float(Time.get_ticks_usec()-from)/count/1000.0,gpu/count)

func _hold(shot: Dictionary, count: int) -> void:
	var hour: float = shot.hour
	var at: Vector3 = shot.eye
	var look: Vector3 = shot.look
	scene.world_clock.set_time(scene.world_clock.day,hour)
	await frames(2)
	if shot.get("to_sun",false):
		var sun: Vector3 = scene._celestial.state.get("zs_sun_direction",Vector3.UP)
		sun = eye.islands.global_basis.inverse()*sun
		look = at+Vector3(sun.x,0.0,sun.z).normalized()*500.0+Vector3.DOWN*20.0
	var way := (look-at).normalized()
	var glide: RefCounted = eye.glide
	glide.position = at
	glide.heading = atan2(-way.x,-way.z)
	glide.pitch = asin(clampf(way.y,-1.0,1.0))
	glide.bank = 0.0
	glide.speed = 8.0
	glide.velocity = glide.forward()*8.0
	var chase: bool = shot.get("chase",false)
	eye.glider.visible = chase
	if chase:
		eye.chase.first_person = false
		eye.chase.reset(glide,at-way*6.0+Vector3.UP*2.0)
	var move: Vector3 = shot.get("move",Vector3.ZERO)
	if move != Vector3.ZERO: at -= move*count/60.0
	for i in range(count):
		at += move/60.0
		look += move/60.0
		glide.position = at
		scene.world_clock.running = false
		scene.world_clock.set_time(scene.world_clock.day,hour)
		var delta := 1.0/60.0
		var view_eye := at
		var view_look := look
		if chase:
			eye.chase.step(delta,glide,0.0)
			eye.glider.update(delta,glide,0.0,eye._fly_ground,false)
			view_eye = eye.chase.eye
			view_look = eye.chase.look
		eye.sky.advance(delta,view_eye,eye.islands.in_cloud(view_eye,scene._motion_time))
		eye.islands.advance(delta,at,glide.heading,0.0)
		var o := view_eye-view_look
		scene.target = view_look
		scene.distance = maxf(o.length(),0.01)
		var dir: Vector3 = o/maxf(o.length(),0.01)
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.05,PI-0.05)
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		eye.camera.fov = 70.0 if chase else 64.0
		await process_frame
