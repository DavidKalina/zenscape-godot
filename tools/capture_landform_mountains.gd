extends SceneTree
## Mountains, the lower world's landform (scripts/landform_mountains.gd),
## rendered in the sky until the lower world stands it in the sea: the
## world's nearest cluster spots each given a mountain island instead of
## their cluster (seeds from --seed, widths from --across), stood as the
## islets stand theirs (scripts/sky_islets.gd `make`, `stand`), each seen
## from far off (far), from high to one side (overview), flying through its
## pass (pass), into its corrie (corrie), by the hut (hut) and from its
## green foot (foot), at noon, golden hour and night. With --fly it stands
## the first and hands the glide back to you at its foot instead.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_landform_mountains.gd \
##     -- --no-title --out=captures/landforms/mountains [--count=2] [--seed=7] [--across=100,70]
##     [--hours=noon,golden,night] [--shots=far,pass] [--fly]
const Landform = preload("res://scripts/landform_mountains.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-landform-mountains"
var count := 2
var seed_base := 7
var widths: Array = [100.0,70.0]
var fly := false
var hours_wanted: Array = ["noon","golden","night"]
var shots_wanted: Array = []
var hours := {"noon": WorldClock.hour_for_phase(0.5), "golden": WorldClock.hour_for_phase(0.72), "night": WorldClock.hour_for_phase(0.02)}
var _islets: Node3D
var _parent: Node3D

func _initialize() -> void:
	run.call_deferred()

func frames(n: int) -> void:
	for i in range(n): await process_frame

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
		elif argument.begins_with("--count="): count = int(argument.trim_prefix("--count="))
		elif argument.begins_with("--seed="): seed_base = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--across="): widths = Array(argument.trim_prefix("--across=").split(",")).map(func(w: String) -> float: return float(w))
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
		elif argument.begins_with("--shots="): shots_wanted = Array(argument.trim_prefix("--shots=").split(","))
		elif argument == "--fly": fly = true
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	if not fly: create_timer(1500).timeout.connect(func() -> void: push_error("landform capture timed out"); quit(2))
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
	var field: Node3D = islands.clusters
	_islets = islands.islets
	_parent = scene.camera.get_parent()
	var palette: Dictionary = _islets.prepare_authored()
	var randoms: Array = (field.spots as Array).filter(func(s: Dictionary) -> bool: return s.key != "showcase")
	randoms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.at.x,a.at.z).length() < Vector2(b.at.x,b.at.z).length())
	for k in range(mini(1 if fly else count,randoms.size())):
		var s: Dictionary = randoms[k]
		# Its cluster let go, and its spot taken out so none comes back there
		# (its room kept clear of the islets, for the mountain).
		if field.clusters.has(s.key): field._forget(s.key)
		(field.spots as Array).erase(s)
		var seed_value := seed_base*1000+k*37
		var across: float = widths[k%widths.size()]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var recipe := Landform.recipe(rng,across)
		var home: Vector3 = s.at
		var began := Time.get_ticks_usec()
		var made := SkyIslets.make(seed_value,recipe,palette,home.y)
		var usec := Time.get_ticks_usec()-began
		var b: Dictionary = _islets.stand("Landform_mountains_%d" % k,home,made)
		b.fixed = true
		_islets.built["landform:mountains:%d" % k] = b
		var label := "mountains-%d-%dm" % [seed_value,across]
		print("LANDFORM %s at %s: made in %.2f s, summit %.1f m" % [label,home,usec/1.0e6,float(b.shape.spire.summit_tops(b.shape)[0])])
		var shots := _shots(b)
		if fly:
			var start: Dictionary = shots[shots.size()-1]
			await _hold_at(start.eye,start.look,hours.noon,30)
			scene.world_clock.running = true
			eye.set_process(true)
			eye._layer.visible = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			print("LANDFORM flying: the mountain stands at ",home)
			return
		for hour_name: String in hours_wanted:
			for shot: Dictionary in shots:
				if not shots_wanted.is_empty() and not shot.label in shots_wanted: continue
				await _hold_at(shot.eye,shot.look,hours[hour_name],60 if shot == shots[0] else 35)
				await still("%s-%s-%s" % [label,shot.label,hour_name])
	print("LANDFORM done")
	quit(0)

## The views round a mountain island `b` (islets' frame).
func _shots(b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var massif: RefCounted = shape.spire
	var home: Vector3 = b.home
	var reach: float = shape.reach
	var away := Vector2(home.x,home.z).normalized()
	if away == Vector2.ZERO: away = Vector2.RIGHT
	var toward_home := Vector3(-away.x,0.0,-away.y)
	var side := Vector3(-toward_home.z,0.0,toward_home.x)
	var main: Vector3 = massif.summits[0]
	var summit := home+Vector3(main.x,shape.ground_at(Vector2(main.x,main.y)),main.y)
	var mid := Vector3(summit.x,home.y+massif.height*0.45,summit.z)
	var centre := home+Vector3(0.0,massif.height*0.35,0.0)
	var col: Vector3 = massif.col
	var col_at := home+Vector3(col.x,shape.ground_at(Vector2(col.x,col.y)),col.y)
	var across := Vector3(massif.across.x,0.0,massif.across.y)
	var corrie: Vector3 = massif.corrie
	var corrie_at := home+Vector3(corrie.x,shape.ground_at(Vector2(corrie.x,corrie.y)),corrie.y)
	var glen := Vector3(massif.glen.x,0.0,massif.glen.y)
	var shots := [{"label":"far","eye":mid+(toward_home*1.0+side*0.35).normalized()*420.0+Vector3.UP*10.0,"look":mid},
		{"label":"overview","eye":centre+(toward_home*1.2+side*0.9)*reach*1.6+Vector3.UP*massif.height*0.9,"look":centre},
		{"label":"pass","eye":col_at+across*reach*0.9+Vector3.UP*9.0,"look":col_at-across*reach*0.5+Vector3.UP*6.0},
		{"label":"corrie","eye":corrie_at+glen*(massif.glen_length+20.0)+Vector3.UP*14.0,"look":corrie_at+Vector3.UP*massif.height*0.25}]
	if massif.with_trail:
		var hut := home+Vector3(massif.hut.x,massif.hut_y,massif.hut.y)
		var out := Vector3(massif.hut_out.x,0.0,massif.hut_out.y)
		shots.append({"label":"hut","eye":hut+out*14.0+side*4.0+Vector3.UP*4.0,"look":hut+Vector3.UP*1.5})
	var foot := home+Vector3(-glen.x,0.0,-glen.z)*reach*0.85
	foot.y = home.y+shape.ground_at(Vector2(foot.x-home.x,foot.z-home.z))
	shots.append({"label":"foot","eye":foot+Vector3.UP*1.8,"look":mid+Vector3.UP*massif.height*0.2})
	return shots

func _view(local: Vector3) -> Vector3:
	return _parent.to_local(_islets.to_global(local))

## Holds the eye at `at` looking at `look` (islets' frame) for `n` frames at
## `hour`, advancing the sky, the haze and the islands as the glide would.
func _hold_at(at_home: Vector3, look_home: Vector3, hour: float, n: int) -> void:
	var glide: RefCounted = eye.glide
	eye.glider.visible = false
	for i in range(n):
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
