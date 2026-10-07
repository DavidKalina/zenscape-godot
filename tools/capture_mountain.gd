extends SceneTree
## The floating mountain (scripts/cluster_mountain.gd), rendered: the
## world's nearest cluster spots made mountains (seeds from --seed), each
## seen from far off (its silhouette over the cloud), from high to one side
## (overview), low in passing (pass), on its trail looking up to the hut
## (trail), by the hut's ledge (hut), on foot in its meadow (foot) and from
## the cabin's islet at its feet (hold), at noon, golden hour and night.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_mountain.gd \
##     -- --no-title --out=captures/clusters/mountain [--count=2] [--seed=7] [--hours=noon,golden,night] [--shots=far,overview]
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-mountain"
var count := 2
var seed_base := 7
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
	print("MOUNTAIN still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--count="): count = int(argument.trim_prefix("--count="))
		elif argument.begins_with("--seed="): seed_base = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
		elif argument.begins_with("--shots="): shots_wanted = Array(argument.trim_prefix("--shots=").split(","))
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(1500).timeout.connect(func() -> void: push_error("mountain capture timed out"); quit(2))
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
	var randoms: Array = (field.spots as Array).filter(func(s: Dictionary) -> bool: return s.key != "showcase")
	randoms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.at.x,a.at.z).length() < Vector2(b.at.x,b.at.z).length())
	for k in range(mini(count,randoms.size())):
		var s: Dictionary = randoms[k]
		s.motif = "mountain"
		s.seed = seed_base*1000+k*37
		var label := "mountain-%d" % int(s.seed)
		await _hold_at(s.at+Vector3(0.0,40.0,0.0),s.at,hours.noon,5)
		field.plan_now(s.key)
		print("MOUNTAIN %s at %s: %s" % [label,s.at,str((field.members_of(s.key) as Dictionary).keys())])
		var shots := _shots(field,s)
		for hour_name: String in hours_wanted:
			for shot: Dictionary in shots:
				if not shots_wanted.is_empty() and not shot.label in shots_wanted: continue
				await _hold_at(shot.eye,shot.look,hours[hour_name],60 if shot == shots[0] else 35)
				await still("%s-%s-%s" % [label,shot.label,hour_name])
	print("MOUNTAIN done")
	quit(0)

## The views round a mountain (islets' frame).
func _shots(field: Node3D, s: Dictionary) -> Array:
	var stood: Dictionary = field.members_of(s.key)
	var centre := Vector3.ZERO
	var reach := 10.0
	for b: Dictionary in stood.values(): centre += b.home
	centre /= maxf(stood.size(),1)
	for b: Dictionary in stood.values(): reach = maxf(reach,Vector2(b.home.x-centre.x,b.home.z-centre.z).length()+float(b.shape.reach))
	var away := Vector2(centre.x,centre.z).normalized()
	if away == Vector2.ZERO: away = Vector2.RIGHT
	var toward_home := Vector3(-away.x,0.0,-away.y)
	var side := Vector3(-toward_home.z,0.0,toward_home.x)
	var peak: Dictionary = stood.get("peak",{})
	if peak.is_empty(): return []
	var spire: RefCounted = peak.shape.spire
	var home: Vector3 = peak.home
	var summit: Vector3 = home+spire.summit
	var mid := Vector3(summit.x,home.y+spire.height*0.45,summit.z)
	var hut := home+Vector3(spire.hut.x,spire.hut_y,spire.hut.y)
	var out := Vector3(spire.hut_out.x,0.0,spire.hut_out.y)
	var trail: PackedVector3Array = spire.trail
	var at: Vector3 = trail[trail.size()/3] if trail.size() > 3 else hut
	var on_trail := home+at
	var trail_out: Vector3 = Vector3(at.x-spire.centre.x,0.0,at.z-spire.centre.y).normalized()
	var foot_at: Vector3 = home+Vector3(spire.centre.x,0.0,spire.centre.y)+trail_out*(spire.foot*1.15)
	foot_at.y = home.y+peak.shape.ground_at(Vector2(foot_at.x-home.x,foot_at.z-home.z))
	var shots := [{"label":"far","eye":mid+(toward_home*1.0+side*0.35).normalized()*340.0+Vector3.UP*6.0,"look":mid},
		{"label":"overview","eye":centre+(toward_home*1.3+side*0.9)*reach+Vector3.UP*reach*0.9,"look":centre+Vector3.UP*6.0},
		{"label":"pass","eye":centre+(toward_home*0.9-side*0.9)*reach+Vector3.UP*8.0,"look":mid},
		{"label":"trail","eye":on_trail+trail_out*16.0+Vector3.UP*5.0,"look":hut},
		{"label":"hut","eye":hut+out*9.0+side*3.0+Vector3.UP*2.5,"look":hut+Vector3.UP*1.5-out*1.0},
		{"label":"foot","eye":foot_at+Vector3.UP*1.7,"look":mid+Vector3.UP*6.0}]
	if stood.has("hold"):
		var hold: Vector3 = stood.hold.home
		var hold_top := hold+Vector3.UP*(float(stood.hold.shape.ground_at(Vector2.ZERO))+1.7)
		var back := (hold_top-mid)
		back.y = 0.0
		var r: float = stood.hold.shape.radius
		shots.append({"label":"hold","eye":hold_top-back.normalized()*r*0.7+Vector3.UP*0.6,"look":mid+Vector3.UP*4.0})
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
