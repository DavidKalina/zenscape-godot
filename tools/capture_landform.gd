extends SceneTree
## The lower world's landforms (scripts/landform_preview.gd), rendered: the
## game is started with --landform=<name> (passed on), the wanderer steps
## off into the glide and the eye is held round the islands the preview
## stands near the home: the row from high to one side (row), then each
## island from a plane's height off to one side (plane), from low over its
## ground looking across it (low), and from just over its shore looking up
## its slopes (shore), at noon and in the golden hour.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_landform.gd \
##     -- --no-title --landform=hills --out=captures/landform/hills [--hours=noon,golden] [--only=0,2] [--shots=plane,low]
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-landform"
var hours_wanted: Array = ["noon","golden"]
var only: Array = []
var shots_wanted: Array = []
var hours := {"noon": WorldClock.hour_for_phase(0.5), "golden": WorldClock.hour_for_phase(0.72)}
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
	print("LANDFORM still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(",")).map(func(s: String) -> int: return int(s))
		elif argument.begins_with("--shots="): shots_wanted = Array(argument.trim_prefix("--shots=").split(","))
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("landform capture timed out"); quit(2))
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
	_islets = islands.islets
	_parent = scene.camera.get_parent()
	var preview: Node = islands.get_node_or_null("LandformPreview")
	if preview == null:
		push_error("no landform preview: pass --landform=<name>")
		quit(1)
		return
	for i in range(600):
		if not preview.stood.is_empty(): break
		await frames(1)
	var keys: Array = preview.stood.keys()
	var centre := Vector3.ZERO
	for key: String in keys: centre += preview.stood[key].home
	centre /= maxf(keys.size(),1)
	var first: Vector3 = preview.stood[keys[0]].home
	var last: Vector3 = preview.stood[keys[keys.size()-1]].home
	var along := (last-first).normalized()
	var outward := Vector3(centre.x,0.0,centre.z).normalized()
	for hour_name: String in hours_wanted:
		if shots_wanted.is_empty() or "row" in shots_wanted:
			await _hold_at(centre-outward*first.distance_to(last)*0.9+Vector3.UP*first.distance_to(last)*0.45,centre,hours[hour_name],60)
			await still("row-%s" % hour_name)
		for k in range(keys.size()):
			if not only.is_empty() and not k in only: continue
			var b: Dictionary = _islets.built[keys[k]]
			var shape: RefCounted = b.shape
			var home: Vector3 = b.home
			var label := "%s-%.0fm" % [preview.stood[keys[k]].landform,float(preview.stood[keys[k]].across)]
			var r: float = shape.radius
			var top := home+Vector3.UP*float(shape.ground_at(Vector2.ZERO))
			var side := along.cross(Vector3.UP).normalized()
			var shots := [
				{"label":"plane","eye":home-outward*(r*1.6+30.0)+along*r*0.6+Vector3.UP*(r*0.55+22.0),"look":top},
				{"label":"low","eye":home-outward*(r*1.05)+side*r*0.3+Vector3.UP*(_highest(shape)+5.0),"look":home+outward*r*0.8+Vector3.UP*2.0},
				{"label":"shore","eye":home+outward*(r*1.7+6.0)-along*r*0.4+Vector3.UP*3.5,"look":top+Vector3.UP*1.0},
			]
			for shot: Dictionary in shots:
				if not shots_wanted.is_empty() and not shot.label in shots_wanted: continue
				await _hold_at(shot.eye,shot.look,hours[hour_name],45)
				await still("%s-%s-%s" % [label,shot.label,hour_name])
	print("LANDFORM done")
	quit(0)

func _highest(shape: RefCounted) -> float:
	var h := 0.0
	for i in range(shape.points.size()):
		if shape.shore_distance[i] >= 0.0: h = maxf(h,shape.heights[i])
	return h

func _view(local: Vector3) -> Vector3:
	return _parent.to_local(_islets.to_global(local))

## Holds the eye at `at` looking at `look` (islets' frame) for `count`
## frames at `hour`, advancing the sky, the haze and the islands as the
## glide would (as tools/capture_clusters.gd).
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
