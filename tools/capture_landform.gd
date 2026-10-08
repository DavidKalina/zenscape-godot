extends SceneTree
## The lower world's landforms as --landform= stands them near the home
## (scripts/landform_preview.gd), rendered: the wanderer steps off into the
## glide and the eye is held round each island of the group, at the hours
## asked for: from plane height a little off (plane), low alongside its
## highest cliff looking along the face (face), from the sea past a stack
## back at the cliff (stack), out on the arch's line looking through it
## (arch), from the sea into the cove (cove), and the whole group from afar
## (group). Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_landform.gd \
##     -- --no-title --no-clusters --landform=cliffs --out=captures/landform/cliffs [--hours=noon,golden]
##     [--only=0,2] [--shots=plane,face] [--landform-seed=7]
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-landform"
var only: Array = []
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
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
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
	var keys: Array = (_islets.built.keys() as Array).filter(func(k: String) -> bool: return k.begins_with("landform:"))
	keys.sort()
	if keys.is_empty():
		push_error("no landform stood: pass --landform=<name>")
		quit(1)
		return
	var group: Array = keys.map(func(k: String) -> Dictionary: return _islets.built[k])
	for hour_name: String in hours_wanted:
		var middle := Vector3.ZERO
		for b: Dictionary in group: middle += b.home
		middle /= group.size()
		if shots_wanted.is_empty() or "group" in shots_wanted:
			await _hold_at(middle+Vector3(-40.0,70.0,190.0),middle+Vector3(0.0,6.0,0.0),hours[hour_name],60)
			await still("group-%s" % hour_name)
		for key: String in keys:
			var k := key.get_slice(":",2)
			if not only.is_empty() and not k in only: continue
			var b: Dictionary = _islets.built[key]
			var label := "%s-%s" % [key.get_slice(":",1),k]
			for shot: Dictionary in _shots(b):
				if not shots_wanted.is_empty() and not shot.label in shots_wanted: continue
				await _hold_at(shot.eye,shot.look,hours[hour_name],40)
				await still("%s-%s-%s" % [label,shot.label,hour_name])
	print("LANDFORM done")
	quit(0)

## The views round one island (islets' frame).
func _shots(b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var home: Vector3 = b.home
	var cliffs: RefCounted = shape.get("cliffs")
	var reach: float = shape.reach
	var shots: Array = []
	var tilt := Vector2.RIGHT
	var high := 20.0
	if cliffs != null:
		tilt = cliffs.tilt
		high = cliffs.high
	var side := Vector2(-tilt.y,tilt.x)
	shots.append({"label":"plane","eye":home+_flat(-tilt*0.4+side)*(reach+45.0)+Vector3.UP*(high+28.0),"look":home+Vector3.UP*high*0.5})
	# Along the highest cliff: out to sea from its rim, looking along the
	# face (face), and skimming close beside it as a pilot would (skim).
	var outward: Dictionary = preload("res://scripts/island_shore.gd")._outward(shape.points,shape.shore_edges)
	var best := -1
	for i: int in outward:
		if cliffs != null and int(cliffs.part[i]) != 1: continue
		if best < 0 or float(shape.heights[i]) > float(shape.heights[best]): best = i
	var rim: Vector2 = shape.points[best]
	var out: Vector2 = outward[best]
	var along := out.orthogonal()
	var face := home+Vector3(rim.x,0.0,rim.y)
	var top: float = shape.heights[best]
	shots.append({"label":"face","eye":face+_flat(out)*55.0-_flat(along)*35.0+Vector3.UP*top*0.4,"look":face+_flat(along)*20.0+Vector3.UP*top*0.4})
	shots.append({"label":"skim","eye":face+_flat(out)*11.0-_flat(along)*30.0+Vector3.UP*top*0.55,"look":face+_flat(out)*6.0+_flat(along)*25.0+Vector3.UP*top*0.45})
	if cliffs == null: return shots
	if not (cliffs.stacks as Array).is_empty():
		var s: Vector4 = cliffs.stacks[cliffs.stacks.size()-1]
		var at := home+Vector3(s.x,0.0,s.y)
		var way := Vector2(s.x,s.y).normalized()
		shots.append({"label":"stack","eye":at+_flat(way.rotated(0.5))*(s.z+26.0)+Vector3.UP*high*0.3,"look":home+Vector3(s.x,0.0,s.y)*0.6+Vector3.UP*high*0.4})
	if not (cliffs.arch as Dictionary).is_empty():
		var arch: Dictionary = cliffs.arch
		var mid: Vector2 = (arch.from as Vector2)+(arch.out as Vector2)*float(arch.span)*0.5
		var across := (arch.out as Vector2).orthogonal()
		var at := home+Vector3(mid.x,0.0,mid.y)
		shots.append({"label":"arch","eye":at+_flat(across)*34.0+_flat(arch.out)*6.0+Vector3.UP*float(arch.crown)*0.45,"look":at+Vector3.UP*float(arch.crown)*0.5})
	if float(cliffs.cove_reach) > 0.0:
		var c: Vector2 = cliffs.cove
		var at := home+Vector3(c.x,0.0,c.y)
		shots.append({"label":"cove","eye":at+_flat(cliffs.cove_out)*40.0+Vector3.UP*9.0,"look":at-_flat(cliffs.cove_out)*12.0+Vector3.UP*3.0})
	return shots

static func _flat(v: Vector2) -> Vector3:
	return Vector3(v.x,0.0,v.y)

func _view(local: Vector3) -> Vector3:
	return _parent.to_local(_islets.to_global(local))

## Holds the eye at `at_home` looking at `look_home` (islets' frame) for
## `count` frames at `hour`, advancing the sky and the islands as the glide
## would.
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
