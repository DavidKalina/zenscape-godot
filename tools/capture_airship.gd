extends SceneTree
## The airship towing an islet (scripts/sky_airship.gd), rendered: the
## wanderer steps off into the glide, an event is started on the lone islet
## nearest the eye, and the eye is held round it through the event: the
## approach, the hook-up, the tear, a wide shot mid-tow, and then the pilot
## perched on the towed islet, riding it (the wanderer's own perch camera).
## Each hour asked for runs the event again from the start.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_airship.gd \
##     -- --no-title --out=captures/airship/try1 [--hours=noon,night] [--only=tear]
## With --airship-now --only=now it checks the flag's own start instead.
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-airship"
var only := ""
var hours_wanted: Array = ["noon","night"]
var hours := {"noon": WorldClock.hour_for_phase(0.5), "golden": WorldClock.hour_for_phase(0.72), "night": WorldClock.hour_for_phase(0.02)}
var islands: Node3D
var ship: Node3D
var _islets: Node3D
var _parent: Node3D

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
	print("AIRSHIP still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = argument.trim_prefix("--only=")
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(1500).timeout.connect(func() -> void: push_error("airship capture timed out"); quit(2))
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
	eye = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	await frames(5)
	eye._launch(6.0,false)
	eye.set_process(false)
	eye._layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	islands = eye.islands
	for i in range(900):
		if not islands.lands.has(null): break
		await frames(1)
	_islets = islands.islets
	ship = islands.airship
	if only == "now":
		await _flag_now()
		quit(0)
		return
	ship.set_process(false)
	ship.enabled = false
	ship.now = false
	_parent = scene.camera.get_parent()
	# Let the islets stream in round the launch.
	var launch: Vector3 = _islets.to_local(eye.glide.position)
	for i in range(120):
		await _hold_at(launch+Vector3(0,10,0),launch+Vector3(0,0,-50),hours.noon,1)
		_islets.flush()
	for hour_name: String in hours_wanted:
		await _event(hour_name)
	print("AIRSHIP done")
	quit(0)

## One event from the start at `hour_name`, its shots taken as it goes.
func _event(hour_name: String) -> void:
	var hour: float = hours[hour_name]
	var start: Vector3 = _islets.to_local(eye.glide.position)
	ship.eye_override = start
	var key: String = ship.pick(start,true)
	if key == "" or not ship.start_on(key,start,ship.SPAWN):
		print("AIRSHIP no islet to tow near ",start)
		return
	var b: Dictionary = ship.towed()
	print("AIRSHIP towing %s from %s to %s (away %s)" % [key,b.home,ship.event.dest,ship.event.away])
	var islet_home: Vector3 = b.home
	var way: Vector3 = ship.event.way
	var side := Vector3(-way.z,0.0,way.x)
	# The approach: the ship a little way out, coming in over the islet.
	_run_until(func() -> bool: return (ship.event.hover-ship.event.pos).length() < 70.0)
	if _wants("approach"):
		await _shoot("approach-"+hour_name,func() -> Array: return [islet_home+side*34.0-way*8.0+Vector3.UP*4.0,(islet_home+ship.event.pos)*0.5],hour,40)
	# The hook-up: the grapples bitten in, the lines slack.
	_run_until(func() -> bool: return ship.event.phase == "bite" and ship.event.t > 0.6)
	if _wants("hookup"):
		await _shoot("hookup-"+hour_name,func() -> Array: return [islet_home+side*24.0+way*6.0+Vector3.UP*5.0,islet_home+Vector3.UP*7.0],hour,30)
	# The tear: torn free, dust and pebbles off it.
	_run_until(func() -> bool: return ship.event.phase == "tear")
	if _wants("tear"):
		await _shoot("tear-"+hour_name,func() -> Array: return [islet_home+side*30.0+way*4.0+Vector3.UP*2.0,islet_home+Vector3.UP*5.0],hour,int(1.0*60),true)
	# Mid-tow, wide.
	_run_until(func() -> bool: return ship.event.phase == "tow" and ship.event.t > 35.0)
	if _wants("tow"):
		await _shoot("tow-wide-"+hour_name,func() -> Array: return [ship.event.islet+side*85.0-way*30.0+Vector3.UP*18.0,ship.event.islet+Vector3.UP*8.0],hour,40,true)
		await _shoot("tow-close-"+hour_name,func() -> Array: return [ship.event.islet-way*26.0+side*14.0+Vector3.DOWN*2.0,ship.event.islet+Vector3.UP*6.0],hour,40,true)
	# Stood on it: the pilot perched on the towed islet, the wanderer's own
	# camera following, the ship pulling on ahead.
	if _wants("perch"):
		await _perch_shots(b,hour,hour_name)
	_run_until(func() -> bool: return ship.event.is_empty() or ship.event.phase == "release")
	if _wants("moored") and not ship.event.is_empty():
		await _shoot("release-"+hour_name,func() -> Array: return [ship.event.rest+side*30.0-way*20.0+Vector3.UP*6.0,ship.event.rest+Vector3.UP*7.0],hour,30,true)
	_run_until(func() -> bool: return ship.event.is_empty(),3000)
	print("AIRSHIP phases ",ship.phases)

## --only=now (run with --airship-now): the event left to start itself off
## the flag on the first flight, the glide flying on as it would, a still
## once the ship has come in.
func _flag_now() -> void:
	eye.set_process(true)
	for i in range(60*45):
		if ship.busy() and ship.event.phase != "come": break
		await process_frame
	print("AIRSHIP flag now: busy %s phases %s" % [ship.busy(),ship.phases])
	await still("flag-now")

func _wants(label: String) -> bool:
	return only == "" or label in only.split(",")

## Steps the event on (no frames drawn) until `done` holds.
func _run_until(done: Callable, most := 6000) -> void:
	for i in range(most):
		if ship.event.is_empty() or done.call(): return
		ship.advance(1.0/30.0)

## Holds the eye where `pose` says ([eye, look], islets' frame) for `count`
## frames, the event going on at its own pace when `live`, then a still.
func _shoot(label: String, pose: Callable, hour: float, count: int, live := false) -> void:
	for i in range(count):
		var p: Array = pose.call()
		if live and not ship.event.is_empty():
			ship.eye_override = p[0]
			ship.advance(1.0/60.0)
		await _hold_at(p[0],p[1],hour,1)
	await still(label)

## The pilot set down on the towed islet and left to stand on it as it is
## towed, through the wanderer's own perch: shots from its camera.
func _perch_shots(b: Dictionary, hour: float, hour_name: String) -> void:
	var glide: RefCounted = eye.glide
	glide.position = _islets.to_global(b.node.position)+Vector3(0.0,float(b.shape.ground_at(Vector2.ZERO))+0.4,0.0)
	glide.heading = ship.event.heading+PI
	eye._perch(b)
	eye.set_process(true)
	ship.set_process(true)
	ship.eye_override = Vector3.INF
	var start_feet: Vector3 = eye._perch_feet
	var start_home: Vector3 = b.home
	for i in range(150):
		scene.world_clock.set_time(scene.world_clock.day,hour)
		eye._yaw = ship.event.heading+PI*0.15
		await process_frame
	await still("perch-"+hour_name)
	for i in range(90):
		scene.world_clock.set_time(scene.world_clock.day,hour)
		eye._yaw = ship.event.heading+PI*0.9
		eye._polar = 1.15
		await process_frame
	await still("perch-ship-"+hour_name)
	print("AIRSHIP perched: islet moved %.1f m, feet drifted %.3f m, still perched %s" % [(b.home-start_home).length(),(eye._perch_feet-start_feet).length(),not eye.perch.is_empty()])
	eye._launch(4.0,false)
	await frames(10)
	print("AIRSHIP took off: flying %s, perch empty %s" % [eye.flying,eye.perch.is_empty()])
	eye.set_process(false)
	ship.set_process(false)

func _view(local: Vector3) -> Vector3:
	return _parent.to_local(_islets.to_global(local))

## Holds the eye at `at` looking at `look` (islets' frame) for `count`
## frames at `hour`, advancing the sky, the haze and the islands as the
## glide would.
func _hold_at(at_home: Vector3, look_home: Vector3, hour: float, count: int) -> void:
	var glide: RefCounted = eye.glide
	eye.glider.visible = false
	for i in range(count):
		var at := _view(at_home)
		var look := _view(look_home)
		var way := (look-at).normalized()
		glide.position = at
		glide.heading = atan2(-way.x,-way.z)
		glide.pitch = asin(clampf(way.y,-1.0,1.0))
		glide.bank = 0.0
		glide.speed = 8.0
		glide.velocity = glide.forward()*8.0
		scene.world_clock.running = false
		scene.world_clock.set_time(scene.world_clock.day,hour)
		var delta := 1.0/60.0
		eye.sky.advance(delta,at,eye.islands.in_cloud(at,scene._motion_time))
		eye.islands.advance(delta,at,glide.heading,0.0)
		var o := at-look
		scene.target = look
		scene.distance = maxf(o.length(),0.01)
		var dir: Vector3 = o/maxf(o.length(),0.01)
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.05,PI-0.05)
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		eye.camera.fov = 64.0
		await process_frame
