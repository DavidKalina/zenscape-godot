extends SceneTree
## A lower-world landform (scripts/landform_<name>.gd), rendered in the sky
## before the lower world stands it: the game stands a few of its islands
## near the home (--landform=<name>, scripts/landform_preview.gd), and the
## eye is held round each, at each hour asked for: from plane height
## (plane), low over the land toward the water (low), skimming the water
## itself (water), and from beside the island at its rim, where its fall
## pours (fall).
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_landform.gd \
##     -- --no-title --no-clusters --landform=lake --out=captures/landform-lake/try1 \
##     [--landform-across=40,65,90] [--landform-seed=7] [--hours=noon,golden] [--shots=plane,low]
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-landform"
var shots_wanted: Array = []
var hours_wanted: Array = ["noon","golden"]
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
	print("LANDFORM still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--shots="): shots_wanted = Array(argument.trim_prefix("--shots=").split(","))
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
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
	for i in range(900):
		if not islands.lands.has(null): break
		await frames(1)
	_islets = islands.islets
	_parent = scene.camera.get_parent()
	var stood: Array = []
	for key: String in _islets.built:
		if key.begins_with("landform:"): stood.append(_islets.built[key])
	stood.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.shape.radius) < float(b.shape.radius))
	if stood.is_empty(): print("LANDFORM none stood: pass --landform=<name>")
	for b: Dictionary in stood:
		var label := "%s-%s" % [str(b.node.name).trim_prefix("Landform_"),str(b.shape.recipe.get("flavour",""))]
		var shots := _shots(b)
		if not shots_wanted.is_empty(): shots = shots.filter(func(shot: Dictionary) -> bool: return shot.label in shots_wanted)
		for hour_name: String in hours_wanted:
			for shot: Dictionary in shots:
				await _hold_at(shot.eye,shot.look,hours[hour_name],60 if shot == shots[0] else 30)
				await still("%s-%s-%s" % [label,shot.label,hour_name])
	print("LANDFORM done")
	quit(0)

## The views round an island (islets' frame).
func _shots(b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var at: Vector3 = b.home
	var reach: float = shape.reach
	var level: float = shape.water_level
	var water: Dictionary = shape.water()
	var deep: Vector2 = shape.lake.get("deep",Vector2.ZERO) if not shape.lake.is_empty() else Vector2.ZERO
	var middle := at+Vector3(deep.x,level,deep.y)
	# Look in from the side away from the fall, so it is the far bank.
	var lip: Vector2 = water.get("lip",Vector2.RIGHT*reach)
	var away := -lip.normalized() if lip.length() > 0.1 else Vector2.RIGHT
	var back := Vector3(away.x,0.0,away.y)
	var side := Vector3(-back.z,0.0,back.x)
	var fall := at+Vector3(lip.x,level,lip.y)
	# The fall from out in the open, off the middle past the lip.
	var outward := Vector3(lip.x,0.0,lip.y).normalized() if lip.length() > 0.1 else Vector3.RIGHT
	return [{"label":"plane","eye":middle+back*reach*1.5+side*reach*0.4+Vector3.UP*reach*1.1,"look":middle},
		{"label":"low","eye":middle+back*(reach+6.0)+side*reach*0.2+Vector3.UP*7.0,"look":middle-back*reach*0.3},
		{"label":"water","eye":middle+back*reach*0.45+Vector3.UP*1.4,"look":middle-back*reach*0.5+Vector3.UP*0.6},
		{"label":"fall","eye":at+outward*(reach+22.0)+Vector3(-outward.z,0.0,outward.x)*reach*0.45+Vector3.DOWN*2.0,"look":fall+Vector3.DOWN*float(shape.depth)*0.3}]

func _view(local: Vector3) -> Vector3:
	return _parent.to_local(_islets.to_global(local))

## Holds the eye at `at` looking at `look` (islets' frame) for `count`
## frames at `hour`, advancing the sky and the islands as the glide would.
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
