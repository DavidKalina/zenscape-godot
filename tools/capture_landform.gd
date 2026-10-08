extends SceneTree
## The lower world's landforms as the sky preview stands them (scripts/
## landform_preview.gd: --landform=<name>, passed on), rendered: the
## wanderer steps off into the glide and the eye is held round the row of
## islands the preview stands near the home, at each hour asked for.
## Every landform's island is seen from a plane's height off to one side
## (plane), from low over its ground looking across it (low) and from just
## over its shore looking up its slopes (shore); each landform adds its own:
##   cliffs: along the highest face (face), skimming beside it (skim), from
##     the sea past a stack (stack), through the arch (arch), into the cove
##     (cove);
##   forest: skimming the canopy (skim), down into the clearing (clearing),
##     along the stream's valley (stream), the row from far off where the
##     trees are their stand-ins (far);
##   lake: skimming the water (water), beside the rim where the fall pours
##     (fall);
##   mountains: from far off (far), through the pass (pass), into the
##     corrie (corrie), by the hut (hut, lit at night), from its green foot
##     (foot).
## And the whole row from high to one side (row). For the lower world
## itself, under the cloud, see tools/capture_lower_world.gd.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_landform.gd \
##     -- --no-title --landform=hills --out=captures/landform/hills [--hours=noon,golden,night]
##     [--only=0,2] [--shots=plane,low] [--landform-seed=7]
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-landform"
var hours_wanted: Array = ["noon","golden"]
var only: Array = []
var shots_wanted: Array = []
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
		push_error("no landform preview: pass --landform=<name> (and not --below)")
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
			if not only.is_empty() and not k % 3 in only: continue
			var record: Dictionary = preview.stood[keys[k]]
			var b: Dictionary = _islets.built[keys[k]]
			var label := "%s-%.0fm" % [record.landform,float(record.across)]
			var shots := _shots(b,along,outward)
			match str(record.landform):
				"cliffs": shots.append_array(_cliff_shots(b))
				"forest": shots.append_array(_forest_shots(b,k % 3 == 0,centre))
				"lake": shots.append_array(_lake_shots(b))
				"mountains": shots.append_array(_mountain_shots(b))
			for shot: Dictionary in shots:
				if not shots_wanted.is_empty() and not shot.label in shots_wanted: continue
				await _hold_at(shot.eye,shot.look,hours[hour_name],45)
				await still("%s-%s-%s" % [label,shot.label,hour_name])
	print("LANDFORM done")
	quit(0)

## Every island's views (islets' frame): plane, low, shore.
func _shots(b: Dictionary, along: Vector3, outward: Vector3) -> Array:
	var shape: RefCounted = b.shape
	var home: Vector3 = b.home
	var r: float = shape.radius
	var top := home+Vector3.UP*float(shape.ground_at(Vector2.ZERO))
	var side := along.cross(Vector3.UP).normalized()
	return [
		{"label":"plane","eye":home-outward*(r*1.6+30.0)+along*r*0.6+Vector3.UP*(r*0.55+22.0),"look":top},
		{"label":"low","eye":home-outward*(r*1.05)+side*r*0.3+Vector3.UP*(_highest(shape)+5.0),"look":home+outward*r*0.8+Vector3.UP*2.0},
		{"label":"shore","eye":home+outward*(r*1.7+6.0)-along*r*0.4+Vector3.UP*3.5,"look":top+Vector3.UP*1.0},
	]

## A cliff island's own views: the highest face, a stack, the arch, the cove.
func _cliff_shots(b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var home: Vector3 = b.home
	var cliffs: RefCounted = shape.get("cliffs")
	var shots: Array = []
	if cliffs == null: return shots
	var high: float = cliffs.high
	var outward: Dictionary = preload("res://scripts/island_shore.gd")._outward(shape.points,shape.shore_edges)
	var best := -1
	for i: int in outward:
		if int(cliffs.part[i]) != 1: continue
		if best < 0 or float(shape.heights[i]) > float(shape.heights[best]): best = i
	if best >= 0:
		var rim: Vector2 = shape.points[best]
		var out: Vector2 = outward[best]
		var way := out.orthogonal()
		var face := home+Vector3(rim.x,0.0,rim.y)
		var top: float = shape.heights[best]
		shots.append({"label":"face","eye":face+_flat(out)*55.0-_flat(way)*35.0+Vector3.UP*top*0.4,"look":face+_flat(way)*20.0+Vector3.UP*top*0.4})
		shots.append({"label":"skim","eye":face+_flat(out)*11.0-_flat(way)*30.0+Vector3.UP*top*0.55,"look":face+_flat(out)*6.0+_flat(way)*25.0+Vector3.UP*top*0.45})
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

## A forest island's own views: over the canopy, the clearing, the stream,
## and (`first` of its row) the row from far off, `centre` its middle.
func _forest_shots(b: Dictionary, first: bool, centre: Vector3) -> Array:
	var shape: RefCounted = b.shape
	var home: Vector3 = b.home
	var reach: float = shape.reach
	var tops := 0.0
	for c: Vector4 in shape.crowns: tops = maxf(tops,c.z+shape.ground_at(Vector2(c.x,c.y)))
	var canopy := minf(tops,14.0+shape.ground_at(Vector2.ZERO))
	var out := Vector2(home.x,home.z).normalized()
	var side := Vector2(-out.y,out.x)
	var at := func(p: Vector2, up: float) -> Vector3: return home+Vector3(p.x,up,p.y)
	var shots: Array = [{"label":"skim","eye":at.call(-out*reach*1.05+side*reach*0.3,canopy+5.0),"look":at.call(out*reach*0.6,canopy*0.4)}]
	var clearing: Vector3 = shape.get_meta("clearing",Vector3.ZERO)
	if clearing.z > 0.0:
		var c := Vector2(clearing.x,clearing.y)
		var from := c-(c.normalized() if c.length() > 1.0 else out)*(clearing.z*0.6)
		shots.append({"label":"clearing","eye":at.call(from,shape.ground_at(c)+canopy+14.0),"look":at.call(c,shape.ground_at(c))})
	if not (shape.stream as Dictionary).is_empty():
		var course: PackedVector2Array = shape.stream.course
		var mouth := course[course.size()-1]
		var mid := course[course.size()/2]
		var back := (mouth-mid).normalized()
		shots.append({"label":"stream","eye":at.call(mouth+back*14.0,canopy+3.0),"look":at.call(mid,shape.ground_at(mid))})
	if first:
		var away := Vector2(centre.x,centre.z).normalized()
		shots.append({"label":"far","eye":centre+Vector3(away.x,0.0,away.y)*420.0+Vector3(side.x,0.0,side.y)*120.0+Vector3.UP*60.0,"look":centre})
	return shots

## A lake island's own views: skimming its water, and its fall.
func _lake_shots(b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	if (shape.lake as Dictionary).is_empty(): return []
	var at: Vector3 = b.home
	var reach: float = shape.reach
	var level: float = shape.water_level
	var water: Dictionary = shape.water()
	var deep: Vector2 = shape.lake.get("deep",Vector2.ZERO)
	var middle := at+Vector3(deep.x,level,deep.y)
	# Looked at from the side away from the fall, so it is the far bank.
	var lip: Vector2 = water.get("lip",Vector2.RIGHT*reach)
	var away := -lip.normalized() if lip.length() > 0.1 else Vector2.RIGHT
	var back := Vector3(away.x,0.0,away.y)
	var fall := at+Vector3(lip.x,level,lip.y)
	var outward := Vector3(lip.x,0.0,lip.y).normalized() if lip.length() > 0.1 else Vector3.RIGHT
	return [{"label":"water","eye":middle+back*reach*0.45+Vector3.UP*1.4,"look":middle-back*reach*0.5+Vector3.UP*0.6},
		{"label":"fall","eye":at+outward*(reach+22.0)+Vector3(-outward.z,0.0,outward.x)*reach*0.45+Vector3.UP*2.0,"look":fall+Vector3.DOWN*0.5}]

## A mountain island's own views: far off, the pass, the corrie, the hut,
## its foot.
func _mountain_shots(b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var massif: RefCounted = shape.spire
	if massif == null or not massif.has_method("bare"): return []
	var home: Vector3 = b.home
	var reach: float = shape.reach
	var away := Vector2(home.x,home.z).normalized()
	if away == Vector2.ZERO: away = Vector2.RIGHT
	var toward_home := Vector3(-away.x,0.0,-away.y)
	var side := Vector3(-toward_home.z,0.0,toward_home.x)
	var main: Vector3 = massif.summits[0]
	var summit := home+Vector3(main.x,shape.ground_at(Vector2(main.x,main.y)),main.y)
	var mid := Vector3(summit.x,home.y+massif.height*0.45,summit.z)
	var col: Vector3 = massif.col
	var col_at := home+Vector3(col.x,shape.ground_at(Vector2(col.x,col.y)),col.y)
	var across := Vector3(massif.across.x,0.0,massif.across.y)
	var corrie: Vector3 = massif.corrie
	var corrie_at := home+Vector3(corrie.x,shape.ground_at(Vector2(corrie.x,corrie.y)),corrie.y)
	var glen := Vector3(massif.glen.x,0.0,massif.glen.y)
	var shots := [{"label":"far","eye":mid+(toward_home*1.0+side*0.35).normalized()*420.0+Vector3.UP*10.0,"look":mid},
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

static func _flat(v: Vector2) -> Vector3:
	return Vector3(v.x,0.0,v.y)

func _highest(shape: RefCounted) -> float:
	var h := 0.0
	for i in range(shape.points.size()):
		if shape.shore_distance[i] >= 0.0: h = maxf(h,shape.heights[i])
	return h

func _view(local: Vector3) -> Vector3:
	return _parent.to_local(_islets.to_global(local))

## Holds the eye at `at_home` looking at `look_home` (islets' frame) for
## `count` frames at `hour`, advancing the sky, the haze and the islands as
## the glide would (as tools/capture_clusters.gd).
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
