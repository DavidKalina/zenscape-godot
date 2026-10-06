extends SceneTree
## The look tour, rendered: the same stills every time, so a change to the
## look can be judged against the one before. The world as a player has it
## (no wonders turned on); the eye is set by hand at each spot, the glide's
## own stepping paused, the clock held:
##   overview: the builder's view of the plate, as the game opens;
##   out-N/E/S/W: off the plate's edge at glide height, looking out level
##     across the islands to the ring and the sky, four ways round;
##   sea-low: just over the cloud sea, the heaps and their gaps ahead;
##   sea-down: high over the sea, looking steeply down through the gaps;
##   keel: under an island's edge, its rock going down to the cloud;
##   chase: the chase view behind the plane, heading out over the sea.
## At noon, at golden hour and at night (night only for some). Each still's
## frame time is printed (vsync off), a rough measure of what it costs.
## Rendered only (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_look_tour.gd \
##     -- --no-title --out=/private/tmp/zs-tour
## Options: --out=DIR, --only=overview,sea-low,..., --hours=noon,golden,night
const GOLDEN_SUN := 0.1
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-tour"
var hours := {"noon":WorldClock.hour_for_phase(0.5),
	"golden":WorldClock.hour_for_phase(0.75-asin(clampf(GOLDEN_SUN/WorldClock.elevation_for_phase(0.5),-1.0,1.0))/TAU),
	"night":WorldClock.hour_for_phase(0.0)}
var only: Array = []
var want_hours: Array = ["noon","golden","night"]

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
	print("TOUR still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument.begins_with("--hours="): want_hours = Array(argument.trim_prefix("--hours=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("look tour timed out"); quit(2))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
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
	# The builder's view first, as the game opens.
	if _wanted("overview"):
		for tag: String in want_hours:
			scene.world_clock.set_time(scene.world_clock.day,hours[tag])
			await frames(60)
			print("TOUR overview-%s frame %.2f ms" % [tag,await _frame_ms(30)])
			await still("overview-"+tag)
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
		if not islands.lands.has(null): break
		await frames(1)
	var shots := _shots()
	for tag: String in want_hours:
		for shot: Dictionary in shots:
			if not _wanted(shot.label): continue
			if tag == "night" and not shot.get("night",false): continue
			await _hold(shot,hours[tag],90 if shot == shots[0] else 60)
			print("TOUR %s-%s frame %.2f ms" % [shot.label,tag,await _frame_ms(30)])
			if shot == shots[0]: print("TOUR %s hour %.2f sun %.3f weather %s cloud %s" % [tag,hours[tag],scene._celestial.sun_height,scene._celestial.state.get("zs_cloud"),scene._celestial.state.get("zs_cloud_sun")])
			await still("%s-%s" % [shot.label,tag])
	print("TOUR done")
	quit(0)

func _wanted(label: String) -> bool:
	return only.is_empty() or label in only

func _shots() -> Array:
	var sea: float = preload("res://scripts/sky_peak.gd").SEA
	var reach: float = eye.PLATE_REACH
	var shots := []
	for way: Array in [["N",Vector3(0,0,-1)],["E",Vector3(1,0,0)],["S",Vector3(0,0,1)],["W",Vector3(-1,0,0)]]:
		var d: Vector3 = way[1]
		shots.append({"label":"out-"+way[0],"eye":d*(reach+40.0)+Vector3.UP*30.0,"look":d*2000.0+Vector3.UP*20.0,"night":way[0] == "N"})
	shots.append({"label":"sea-low","eye":Vector3(reach+260.0,sea+35.0,60.0),"look":Vector3(reach+900.0,sea+5.0,300.0),"night":true})
	shots.append({"label":"sea-down","eye":Vector3(reach+200.0,60.0,-200.0),"look":Vector3(reach+420.0,sea,-60.0)})
	shots.append({"label":"keel","eye":Vector3(reach+90.0,-40.0,30.0),"look":Vector3(reach-20.0,sea+10.0,0.0)})
	shots.append({"label":"chase","eye":Vector3(reach+60.0,20.0,0.0),"look":Vector3(reach+600.0,sea+40.0,120.0),"chase":true,"night":true})
	return shots

## The mean frame time (ms) over `count` frames, the view held.
func _frame_ms(count: int) -> float:
	await RenderingServer.frame_post_draw
	var from := Time.get_ticks_usec()
	for i in range(count): await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec()-from)/count/1000.0

## Holds the eye at a shot for `count` frames at `hour`, advancing the sky,
## the haze and the islands as the glide would (tools/capture_sky_cumulus.gd).
func _hold(shot: Dictionary, hour: float, count: int) -> void:
	var at: Vector3 = shot.eye
	var look: Vector3 = shot.look
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
	for i in range(count):
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
