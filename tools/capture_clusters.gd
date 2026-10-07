extends SceneTree
## The sky clusters (scripts/sky_clusters.gd), rendered: the wanderer steps
## off into the glide and the eye is held round a few clusters, at noon and
## at night: the hand-laid showcase from its old spots (approach, overview,
## stones, field, point), and PER motif random clusters of each motif (the
## world's cluster spots re-dealt to the motifs, seeds from --seed), each
## from high to one side (overview), low in passing (pass) and close by a
## member's rock (rock), from 220 m off (far) and by a cabin from behind
## (cabin); then --lone=N of the seeded islets between them,
## each from its side (lone), by day.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_clusters.gd \
##     -- --no-title --showcase --out=captures/clusters/try1 [--per=2] [--seed=7] [--hours=noon,night] [--only=showcase] [--lone=3]
const Motifs = preload("res://scripts/cluster_motifs.gd")
const RavineShots = preload("res://tools/ravine_shots.gd")
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-clusters"
var per := 2
var seed_base := 7
var only := ""
var lone := 0
var hours_wanted: Array = ["noon","night"]
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
	print("CLUSTERS still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--per="): per = int(argument.trim_prefix("--per="))
		elif argument.begins_with("--seed="): seed_base = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--only="): only = argument.trim_prefix("--only=")
		elif argument.begins_with("--lone="): lone = int(argument.trim_prefix("--lone="))
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(1500).timeout.connect(func() -> void: push_error("clusters capture timed out"); quit(2))
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
	# The clusters to visit: the showcase, then the world's spots dealt out
	# to the motifs in turn.
	var visits: Array = []
	var randoms: Array = (field.spots as Array).filter(func(s: Dictionary) -> bool: return s.key != "showcase")
	randoms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.at.x,a.at.z).length() < Vector2(b.at.x,b.at.z).length())
	for s: Dictionary in field.spots:
		if s.key == "showcase": visits.append(s)
	var names: Array = Motifs.names()
	var k := 0
	for motif: String in names:
		for n in range(per):
			if k >= randoms.size(): break
			var s: Dictionary = randoms[k]
			s.motif = motif
			s.seed = seed_base*1000+k*37
			visits.append(s)
			k += 1
	for s: Dictionary in visits:
		if only != "" and s.motif != only: continue
		var label: String = "showcase" if s.key == "showcase" else "%s-%d" % [s.motif,int(s.seed)]
		await _hold_at(s.at+Vector3(0.0,40.0,0.0),s.at,hours.noon,5)
		field.plan_now(s.key)
		print("CLUSTERS %s at %s: %s" % [label,s.at,str((field.members_of(s.key) as Dictionary).keys())])
		var shots := _shots(field,s)
		for hour_name: String in hours_wanted:
			for shot: Dictionary in shots:
				await _hold_at(shot.eye,shot.look,hours[hour_name],60 if shot == shots[0] else 35)
				await still("%s-%s-%s" % [label,shot.label,hour_name])
	await _lone_islets(lone)
	print("CLUSTERS done")
	quit(0)

## The views round a cluster (islets' frame).
func _shots(field: Node3D, s: Dictionary) -> Array:
	var stood: Dictionary = field.members_of(s.key)
	var at: Vector3 = s.at
	var centre := Vector3.ZERO
	var reach := 10.0
	for b: Dictionary in stood.values(): centre += b.home
	centre /= maxf(stood.size(),1)
	for b: Dictionary in stood.values(): reach = maxf(reach,Vector2(b.home.x-centre.x,b.home.z-centre.z).length()+float(b.shape.reach))
	var away := Vector2(centre.x,centre.z).normalized()
	if away == Vector2.ZERO: away = Vector2.RIGHT
	var toward_home := Vector3(-away.x,0.0,-away.y)
	var side := Vector3(-toward_home.z,0.0,toward_home.x)
	if s.key == "showcase":
		var home := func(n: String) -> Vector3: return stood[n].home if stood.has(n) else centre
		var lead: Vector3 = home.call("lead")
		var dock: Vector3 = home.call("dock")
		var light: Vector3 = home.call("light")
		var mill: Vector3 = home.call("mill")
		return [{"label":"approach","eye":centre+Vector3(-115.0,18.0,-25.0),"look":centre+Vector3(0.0,2.0,0.0)},
			{"label":"overview","eye":centre+Vector3(-55.0,48.0,75.0),"look":centre+Vector3(0.0,-2.0,-4.0)},
			{"label":"stones","eye":dock+Vector3(-14.0,3.0,13.0),"look":lead+Vector3(0.0,2.0,0.0)},
			{"label":"point","eye":light+Vector3(26.0,6.0,18.0),"look":(light+mill)*0.5+Vector3(-6.0,2.0,0.0)},
			{"label":"field","eye":lead+Vector3(14.0,4.5,-16.0),"look":lead+Vector3(-2.0,1.5,4.0)}]
	# The rock: the biggest member's side, from a little under its rim.
	var big: Dictionary = {}
	for b: Dictionary in stood.values():
		if big.is_empty() or float(b.shape.radius) > float(big.shape.radius): big = b
	var to_eye := Vector2(toward_home.x,toward_home.z).rotated(0.6)
	var rock_eye: Vector3 = big.home+Vector3(to_eye.x,0.0,to_eye.y)*(float(big.shape.reach)+16.0)+Vector3.DOWN*3.0
	# A cabin from behind and to one side (its door faces +Z), to see it lit
	# from the side away from its door.
	var shots: Array = []
	for b: Dictionary in stood.values():
		var plan_member: Dictionary = {}
		for pm: Dictionary in field.clusters[s.key].plan.members:
			if pm.name == b.member: plan_member = pm
		for f: Dictionary in plan_member.get("features",[]):
			if f.type != "cabin" or not shots.is_empty(): continue
			var door: Vector3 = b.home+Vector3(f.at.x,b.shape.ground_at(f.at),f.at.y)
			var back := Vector3(0.0,0.0,-1.0).rotated(Vector3.UP,float(f.angle)+0.7)
			shots.append({"label":"cabin","eye":door+back*9.0+Vector3.UP*2.5,"look":door+Vector3.UP*1.0})
	var out: Array = [{"label":"overview","eye":centre+(toward_home*1.3+side*0.9)*reach+Vector3.UP*reach*0.9,"look":centre+Vector3.DOWN*2.0},
		{"label":"pass","eye":centre+(toward_home*0.9-side*0.9)*reach+Vector3.UP*4.0,"look":centre+Vector3.UP*2.0},
		{"label":"rock","eye":rock_eye,"look":big.home+Vector3.DOWN*float(big.shape.depth)*0.35},
		{"label":"far","eye":centre+(toward_home*0.9-side*0.9).normalized()*220.0+Vector3.UP*25.0,"look":centre}]+shots
	if s.motif == "falls": out.append_array(_falls_shots(field,s,stood))
	var plan: Dictionary = field.clusters.get(s.key,{}).get("plan",{})
	if plan.has("cleft"): out.append_array(RavineShots.shots(plan,at))
	return out

## `count` seeded islets (the nearest to the home with their cells' spots),
## each from its side a little under its rim, at noon.
func _lone_islets(count: int) -> void:
	if count <= 0: return
	var found: Array = []
	for x in range(-6,7):
		for z in range(-6,7):
			var at: Variant = _islets.spot(Vector2i(x,z))
			if at != null and Vector2(at.x,at.z).length() > 300.0: found.append(at)
	found.sort_custom(func(a: Vector3, b: Vector3) -> bool: return Vector2(a.x,a.z).length() < Vector2(b.x,b.z).length())
	print("CLUSTERS %d lone islet spots" % found.size())
	for k in range(mini(count,found.size())):
		var at: Vector3 = found[k]
		var b: Dictionary = {}
		for wait in range(12):
			await _hold_at(at+Vector3(30.0,10.0,30.0),at,hours.noon,30)
			for key: String in _islets.built:
				if not key.begins_with("cluster:") and (_islets.built[key].home as Vector3).distance_to(at) < 1.0: b = _islets.built[key]
			if not b.is_empty(): break
		if b.is_empty():
			print("CLUSTERS lone islet at %s not built" % at)
			continue
		var reach: float = b.shape.reach
		var eye_at: Vector3 = at+Vector3(1.0,0.0,0.6).normalized()*(reach*1.6+14.0)+Vector3.DOWN*2.0
		await _hold_at(eye_at,at+Vector3.DOWN*float(b.shape.depth)*0.35,hours.noon,40)
		await still("lone-%d-%s" % [k,b.shape.kind])

## The waterfall terraces close: beside the first fall, over the paddies,
## and from a pool's bank up at the fall pouring into it.
func _falls_shots(field: Node3D, s: Dictionary, stood: Dictionary) -> Array:
	var plan: Dictionary = field.clusters[s.key].plan
	var out: Array = []
	for f: Dictionary in plan.get("falls",[]):
		if not stood.has(f.from) or not stood.has(f.to): continue
		var to: Dictionary = stood[f.from].shape.recipe.fall_to
		var lip: Vector3 = stood[f.from].home+to.lip
		var pool: Vector3 = stood[f.from].home+to.pool
		var way := Vector3(to.out.x,0.0,to.out.z)
		var across := way.cross(Vector3.UP).normalized()
		var mid := (lip+pool)*0.5
		out.append({"label":"cascade","eye":mid+across*11.0+way*2.0+Vector3.UP*1.5,"look":mid})
		out.append({"label":"pool","eye":pool+way*4.2-across*1.6+Vector3.UP*1.7,"look":lip+Vector3.DOWN*1.0})
		break
	for m: Dictionary in plan.members:
		for f: Dictionary in m.features:
			if f.type != "paddies" or not stood.has(m.name): continue
			var pads: Array = f.pads
			var a: Rect2 = pads[0].rect
			var b: Rect2 = pads[pads.size()-1].rect
			var home: Vector3 = stood[m.name].home
			var middle := home+Vector3((a.get_center().x+b.get_center().x)*0.5,float(pads[0].y),(a.get_center().y+b.get_center().y)*0.5)
			var along := Vector3(b.get_center().x-a.get_center().x,0.0,b.get_center().y-a.get_center().y).normalized()
			out.append({"label":"paddies","eye":middle+along*9.0+along.cross(Vector3.UP)*4.0+Vector3.UP*5.0,"look":middle})
	return out

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
