extends SceneTree
## The lower world under the cloud sea (scripts/sky_below.gd) and its
## archipelago (scripts/sky_archipelago.gd), rendered: stills at noon from
## a few places under the cloud, each with its frame and GPU time. Shots:
##   emerge: just come out under the cloud, looking out over the islands;
##   cruise: the chase view flying low over the archipelago;
##   skim: a few metres over the water by an island's shore;
##   shelf: looking down on an island's shelf and its shallows;
##   up: from low over the water, looking up at the cloud's underside;
##   island: on foot on an island's top, looking out to sea;
##   golden: the cruise at golden hour;
##   night: the cruise at night;
##   open: low over open water, away from the islands, looking downwind;
##   high: plane height (60 m) over a shelf, looking along the coast.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_lower_world.gd \
##     -- --no-title --below --out=/private/tmp/zs-lower-world [--only=emerge,cruise] [--no-ocean] [--no-mirror]
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-lower-world"
var only: Array = []
var noon := WorldClock.hour_for_phase(0.5)
var golden := WorldClock.hour_for_phase(0.72)
var night := WorldClock.hour_for_phase(0.02)

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
	print("LOWER still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("lower world capture timed out"); quit(2))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
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
	scene.world_clock.running = false
	eye = scene.wanderer
	if eye.lower == null:
		push_error("no lower world: pass --below")
		quit(1)
		return
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	await frames(5)
	eye._launch(6.0,false)
	eye.set_process(false)
	eye._layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var islands: Node3D = eye.islands
	for i in range(900):
		if not islands.lands.has(null): break
		await frames(1)
	# First, above: the home island from the air, for the look to match.
	if only.is_empty() or "above" in only:
		await _hold({"hour":noon,"eye":Vector3(-60.0,25.0,40.0),"look":Vector3(0.0,0.0,0.0)},240)
		await still("above")
	# Down under the cloud, a little way out over the sea.
	var start := Vector3(260.0,-200.0,-180.0)
	await _hold({"hour":noon,"eye":start,"look":start+Vector3(100.0,-20.0,0.0)},30)
	var arch: Node3D = eye.lower.archipelago
	arch.build_near(start,1100.0)
	print("LOWER islands built: %d" % arch.island_count())
	var b: Dictionary = arch.nearest(start+Vector3(150.0,0.0,0.0),600.0)
	var middle: Vector3 = arch.islets.place(b)
	var ground: float = middle.y+float(b.shape.ground_at(Vector2.ZERO))
	var water: float = eye.lower.OCEAN
	var r: float = b.shape.reach
	var away := (Vector3(middle.x-start.x,0.0,middle.z-start.z)).normalized()
	var side := Vector3(-away.z,0.0,away.x)
	var shots := [
		{"label":"emerge","hour":noon,"eye":Vector3(start.x,-165.0,start.z),"look":middle+away*300.0+Vector3.DOWN*30.0},
		{"label":"cruise","hour":noon,"eye":middle-away*(r+90.0)+Vector3.UP*(water-middle.y+28.0),"look":middle+away*200.0+Vector3.DOWN*(middle.y-water),"chase":true},
		{"label":"skim","hour":noon,"eye":middle-away*(r+30.0)+side*10.0+Vector3.UP*(water-middle.y+4.0),"look":middle+Vector3.UP*2.0},
		{"label":"shelf","hour":noon,"eye":middle-away*(r+20.0)+Vector3.UP*(water-middle.y+35.0),"look":middle-away*(r*0.8)+Vector3.DOWN*(middle.y-water)},
		{"label":"up","hour":noon,"eye":middle-away*(r+60.0)+Vector3.UP*(water-middle.y+12.0),"look":middle-away*(r+60.0)+away*120.0+Vector3.UP*(-60.0-middle.y)},
		{"label":"island","hour":noon,"eye":Vector3(middle.x,ground+1.6,middle.z),"look":middle+away*200.0+Vector3.DOWN*(middle.y-water-4.0)},
		{"label":"golden","hour":golden,"eye":middle-away*(r+90.0)+Vector3.UP*(water-middle.y+28.0),"look":middle+away*200.0+Vector3.DOWN*(middle.y-water),"chase":true},
		{"label":"night","hour":night,"eye":middle-away*(r+90.0)+Vector3.UP*(water-middle.y+28.0),"look":middle+away*200.0+Vector3.DOWN*(middle.y-water),"chase":true},
		{"label":"open","hour":noon,"eye":middle-away*(r+260.0)+Vector3.UP*(water-middle.y+9.0),"look":middle-away*(r+600.0)+side*80.0+Vector3.DOWN*(middle.y-water+30.0)},
		{"label":"high","hour":noon,"eye":middle-away*(r+70.0)+side*40.0+Vector3.UP*(water-middle.y+60.0),"look":middle+side*(r*1.5)+Vector3.DOWN*(middle.y-water)},
	]
	var first := true
	for shot: Dictionary in shots:
		if not only.is_empty() and shot.label not in only: continue
		await _hold(shot,240 if first else 90)
		if "--no-ocean" in OS.get_cmdline_user_args(): eye.lower.ocean.visible = false
		if "--no-mirror" in OS.get_cmdline_user_args(): eye.lower.water.set_shader_parameter("mirror_steps",0)
		if "--red-sky" in OS.get_cmdline_user_args():
			scene._environment.background_mode = Environment.BG_COLOR
			scene._environment.background_color = Color.RED
		first = false
		var timing := await _timing(30)
		print("LOWER %s frame %.2f ms, gpu %.2f ms, below %s" % [shot.label,timing.x,timing.y,str(eye.below())])
		await still(shot.label)
	print("LOWER done")
	quit(0)

func _timing(count: int) -> Vector2:
	await RenderingServer.frame_post_draw
	var from := Time.get_ticks_usec()
	var gpu := 0.0
	var rd := RenderingServer.get_rendering_device()
	for i in range(count):
		await RenderingServer.frame_post_draw
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		if rd == null: continue
		var n := rd.get_captured_timestamps_count()
		if n < 2: continue
		gpu += (rd.get_captured_timestamp_gpu_time(n-1)-rd.get_captured_timestamp_gpu_time(0))/1000.0
	return Vector2(float(Time.get_ticks_usec()-from)/count/1000.0,gpu/count)

func _hold(shot: Dictionary, count: int) -> void:
	var hour: float = shot.hour
	var at: Vector3 = shot.eye
	var look: Vector3 = shot.look
	var way := (look-at).normalized()
	var glide: RefCounted = eye.glide
	glide.position = at
	glide.heading = atan2(-way.x,-way.z)
	glide.pitch = asin(clampf(way.y,-1.0,1.0))*0.3
	glide.bank = 0.0
	glide.speed = 14.0
	glide.velocity = glide.forward()*14.0
	var chase: bool = shot.get("chase",false)
	eye.glider.visible = chase
	if chase:
		eye.chase.first_person = false
		eye.chase.reset(glide,at-way*8.0+Vector3.UP*2.5)
	for i in range(count):
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
