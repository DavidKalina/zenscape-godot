extends SceneTree
## The showcase cluster (scripts/sky_showcase.gd), rendered: the wanderer
## steps off into the glide and the eye is held at a row of spots round the
## cluster, the clock at noon, golden hour and night:
##   approach: from the plate's side, the way it is first flown up to;
##   overview: high and to one side, the whole cluster as a stack;
##   stones: low by the dock, up the stepping stones to the farm;
##   bridge: under the footbridge, the forest and the crag over it;
##   point: by the lighthouse, the mill and the field beyond;
##   field: low over the wheat toward the cabin.
## Rendered only when asked for (needs a window); --showcase is required:
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_showcase.gd \
##     -- --no-title --showcase --out=captures/showcase/try1 [--only=approach,overview] [--hours=noon,night]
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-showcase"
var only: Array = []
var hours_wanted: Array = ["noon","golden","night"]
var hours := {"noon": WorldClock.hour_for_phase(0.5), "golden": WorldClock.hour_for_phase(0.72), "night": WorldClock.hour_for_phase(0.02)}
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
	print("SHOWCASE still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("showcase capture timed out"); quit(2))
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
	var islands: Node3D = eye.islands
	for i in range(900):
		if not islands.lands.has(null): break
		await frames(1)
	if islands.showcase == null:
		push_error("no showcase: pass --showcase")
		quit(2)
		return
	islands.showcase.flush()
	_islets = islands.islets
	_parent = scene.camera.get_parent()
	var shots := _shots(islands.showcase)
	for hour_name: String in hours_wanted:
		for shot: Dictionary in shots:
			if not only.is_empty() and shot.label not in only: continue
			await _hold(shot,hours[hour_name],90 if shot == shots[0] else 45)
			await still("%s-%s" % [shot.label,hour_name])
	print("SHOWCASE done")
	quit(0)

## The spots, in the islets' frame (home coordinates).
func _shots(show: Node3D) -> Array:
	var b: Dictionary = show.built
	var home := func(n: String) -> Vector3: return b[n].home
	var c: Vector3 = home.call("lead")
	var mid: Vector3 = (c+home.call("forest")+home.call("crag")+home.call("light")+home.call("dock"))/5.0
	var dock: Vector3 = home.call("dock")
	var forest: Vector3 = home.call("forest")
	var light: Vector3 = home.call("light")
	var mill: Vector3 = home.call("mill")
	var shots := []
	shots.append({"label":"approach","eye":mid+Vector3(-115.0,18.0,-25.0),"look":mid+Vector3(0.0,2.0,0.0)})
	shots.append({"label":"overview","eye":mid+Vector3(-55.0,48.0,75.0),"look":mid+Vector3(0.0,-2.0,-4.0)})
	shots.append({"label":"stones","eye":dock+Vector3(-14.0,3.0,13.0),"look":c+Vector3(0.0,2.0,0.0)})
	var bridge_mid := (c+forest)*0.5
	shots.append({"label":"bridge","eye":bridge_mid+Vector3(-14.0,-4.0,16.0),"look":bridge_mid+Vector3(0.0,4.0,-6.0)})
	shots.append({"label":"point","eye":light+Vector3(26.0,6.0,18.0),"look":(light+mill)*0.5+Vector3(-6.0,2.0,0.0)})
	shots.append({"label":"field","eye":c+Vector3(14.0,4.5,-16.0),"look":c+Vector3(-2.0,1.5,4.0)})
	return shots

func _view(local: Vector3) -> Vector3:
	return _parent.to_local(_islets.to_global(local))

## Holds the eye at a shot for `count` frames at `hour`, advancing the sky,
## the haze and the islands as the glide would.
func _hold(shot: Dictionary, hour: float, count: int) -> void:
	var glide: RefCounted = eye.glide
	eye.glider.visible = false
	for i in range(count):
		var at := _view(shot.eye)
		var look := _view(shot.look)
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
