extends SceneTree
## A plane through a cloud, rendered (scripts/cloud_wakes.gd): the
## wanderer steps off into the glide, the plane is flown by hand straight
## through a drifting cloud near the plate, and stills are taken along the
## way, from two views of the same pass:
##   watch: a spectator off the cloud's side, as a CPU plane would be seen:
##     before, cutting in, the exit burst, and the tunnel healing after;
##   chase: the chase view behind the plane: going in, deep in, coming out.
## With --tower the pass is through the towering cumulus by the plate
## instead. Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_cloud_wake.gd \
##     -- --no-title --out=/private/tmp/zs-wake
## Options: --out=DIR, --hour=H, --only=watch|chase, --tower.
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-wake"
var hour := WorldClock.hour_for_phase(0.45)
var only := ""
var tower := false
const SPEED := 14.0

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
	print("WAKE still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--hour="): hour = float(argument.trim_prefix("--hour="))
		elif argument.begins_with("--only="): only = argument.trim_prefix("--only=")
		elif argument == "--tower": tower = true
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("cloud wake capture timed out"); quit(2))
	Engine.max_fps = 60
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
	if islands.traffic != null: islands.traffic.show(false)
	islands.towers.advance(0.6,Vector3.ZERO)
	islands.towers.flush()
	for view: String in ["watch","chase"]:
		if only != "" and view != only: continue
		islands.wakes.clear()
		await _pass(view)
	print("WAKE done")
	quit(0)

## The cloud to fly through: its middle (global, now) and size, and the
## way across it.
func _target() -> Dictionary:
	var islands: Node3D = eye.islands
	if tower:
		var b: Dictionary = islands.towers.built["0,0"]
		var shape: RefCounted = b.shape
		var axis: Vector2 = shape._axis(60.0)
		var heart: Vector3 = islands.towers.global_of(b,Vector3(axis.x,60.0,axis.y))
		return {"middle":heart,"size":90.0,"index":-1}
	var clouds: Node3D = islands.clouds
	var best := -1
	var gap := INF
	for i in range(clouds.clouds.size()):
		var c: Vector3 = clouds.centre(i,scene._motion_time)
		var size: float = clouds.clouds[i].w
		if size < 26.0: continue
		var d := Vector2(c.x,c.z).length()
		if d < gap:
			gap = d
			best = i
	return {"middle":clouds.centre(best,scene._motion_time),"size":clouds.clouds[best].w,"index":best}

## One pass through the cloud, seen from `view`, stills along the way.
func _pass(view: String) -> void:
	scene.world_clock.running = false
	scene.world_clock.set_time(scene.world_clock.day,hour)
	var target := _target()
	var size: float = target.size
	var middle: Vector3 = target.middle+Vector3.UP*size*0.12
	var across := Vector3(1.0,0.0,0.35).normalized()
	var start := middle-across*size*1.6
	var side := across.cross(Vector3.UP).normalized()
	var spectator := middle+side*size*2.3+Vector3.UP*size*0.25+across*size*0.9
	var glide: RefCounted = eye.glide
	glide.position = start
	glide.heading = atan2(-across.x,-across.z)
	glide.pitch = 0.0
	glide.bank = 0.0
	glide.speed = SPEED
	glide.velocity = across*SPEED
	eye.glider.visible = true
	eye.chase.first_person = false
	eye.chase.reset(glide,start-across*6.0+Vector3.UP*2.0)
	# Seconds into the pass for each still: through the cloud's span at
	# SPEED, then the burst and the healing after.
	var span := size*1.6/SPEED
	var shots := {}
	# When it leaves the cloud's far side (CloudWakes EXIT_TO).
	var exit := span
	while exit < span*3.0 and eye.islands.cloud_body(start+across*SPEED*exit) >= 0.1: exit += 0.05
	if view == "watch":
		shots = {span*0.6:"watch-1-before",span*1.0:"watch-2-cutting",exit:"watch-3-exit",exit+0.7:"watch-4-pulled",exit+2.0:"watch-5-after2s",
			exit+8.0:"watch-6-after8s",exit+18.0:"watch-7-after18s",exit+32.0:"watch-8-healed"}
	else:
		shots = {span*0.75:"chase-1-entering",span*0.95:"chase-2-in",span*1.15:"chase-3-deep",span*1.45:"chase-4-leaving",span*1.65:"chase-5-out"}
	if tower: for k in shots.keys(): shots[k] = "tower-"+shots[k]
	var times := shots.keys()
	times.sort()
	var t := 0.0
	var flying := true
	while not times.is_empty():
		var delta: float = clampf(root.get_process_delta_time(),1.0/240.0,1.0/20.0)
		scene.world_clock.running = false
		t += delta
		# Flown on past the cloud for a little, then held off out of sight
		# while the tunnel heals.
		if flying and t > span*3.0:
			flying = false
			eye.glider.visible = false
		if flying:
			glide.position += glide.velocity*delta
			eye.islands.wake(glide.position,glide.velocity,delta)
		eye.chase.step(delta,glide,0.0)
		eye.glider.update(delta,glide,0.0,eye._fly_ground,false)
		var view_eye: Vector3 = eye.chase.eye if view == "chase" else spectator
		var view_look: Vector3 = eye.chase.look if view == "chase" else middle+across*size*0.45
		eye.sky.advance(delta,view_eye,eye.islands.in_cloud(view_eye,scene._motion_time))
		eye.air.advance(delta,glide.velocity,0.0,0.0,0.0,eye.islands.cloud_body(view_eye))
		eye.islands.advance(delta,glide.position,glide.heading,0.0)
		var o := view_eye-view_look
		scene.target = view_look
		scene.distance = maxf(o.length(),0.01)
		var dir: Vector3 = o/maxf(o.length(),0.01)
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.05,PI-0.05)
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		eye.camera.fov = 70.0 if view == "chase" else 60.0
		await process_frame
		if t >= float(times[0]):
			await still(shots[times[0]])
			print("WAKE %s t=%.1f open=%d tufts=%d in=%.2f" % [shots[times[0]],t,eye.islands.wakes.open_count(scene._motion_time),eye.islands.wakes.tufts.size(),eye.islands.cloud_body(glide.position)])
			times.pop_front()
