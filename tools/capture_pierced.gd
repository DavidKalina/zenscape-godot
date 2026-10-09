extends SceneTree
## The pierced isle (scripts/sky_pierced.gd, scripts/pierced_isle.gd),
## rendered in the real game: the wanderer steps off into the glide, the
## isle stood near the home (--pierced) is planned and stood at once, and
## the eye is held round it: from afar (far), level with the arch at plane
## height (arch), through the arch (through), over the top (top), down the
## skylight (skylight), in the cavern (cavern), in a window looking out
## (window), at the gate (gate, when it has one), under the keel at the eye
## (eye). --shots=a,b keeps those; --hours=noon,golden,night (noon).
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_pierced.gd \
##     -- --no-title --pierced [--pierced-seed=3] --out=captures/pierced/try1 [--shots=far,cavern]
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-pierced"
var shots_wanted: Array = []
var hours_wanted: Array = ["noon"]
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
	print("PIERCED still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--shots="): shots_wanted = Array(argument.trim_prefix("--shots=").split(","))
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("pierced capture timed out"); quit(2))
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
	var field: Node3D = islands.pierced
	_islets = islands.islets
	_parent = scene.camera.get_parent()
	if field.spots.is_empty():
		print("PIERCED no isle laid (pass --pierced)")
		quit(1)
		return
	var s: Dictionary = field.spots[0]
	await _hold_at(s.at+Vector3(0.0,60.0,300.0),s.at,hours.noon,5)
	var began := Time.get_ticks_usec()
	print("PIERCED planning %s at %s" % [s.key,s.at])
	field.plan_now(s.key)
	# Shoot only once it stands: its lid among the islets, its rock and
	# ruins under it; framed from where it really stands.
	var standing: Dictionary = field.standing()
	if not standing.has(s.key) or not is_instance_valid(standing[s.key].b.node) or standing[s.key].get("rock") == null:
		print("PIERCED the isle did not stand; no stills")
		quit(1)
		return
	var stood: Dictionary = standing[s.key]
	s = s.duplicate()
	s.at = stood.b.home
	var plan: RefCounted = stood.plan
	print("PIERCED seed %d draw %d at %s, %.1f s; holes %s; problems %s; stats %s" % [int(s.seed),plan.draw,s.at,(Time.get_ticks_usec()-began)/1.0e6,str(plan.summary()),str(plan.problems),str(stood.out.get("stats",{}))])
	var shots := _shots(plan,s.at)
	if not shots_wanted.is_empty(): shots = shots.filter(func(shot: Dictionary) -> bool: return shot.label in shots_wanted)
	for hour_name: String in hours_wanted:
		for shot: Dictionary in shots:
			await _hold_at(shot.eye,shot.look,hours[hour_name],60 if shot == shots[0] else 30)
			await still("%s-%s" % [shot.label,hour_name])
	print("PIERCED done")
	quit(0)

## The views round the isle (home coordinates).
func _shots(plan: RefCounted, at: Vector3) -> Array:
	var shots: Array = []
	var box: AABB = plan.bounds()
	var middle := at+Vector3(0.0,(box.position.y+box.end.y)*0.5,0.0)
	var toward := -Vector3(at.x,0.0,at.z).normalized()
	if toward == Vector3.ZERO: toward = Vector3.BACK
	var side := Vector3(-toward.z,0.0,toward.x)
	shots.append({"label":"far","eye":middle+toward*420.0+side*120.0+Vector3.UP*30.0,"look":middle})
	var arch: Dictionary = plan.hole("arch")
	if not arch.is_empty():
		var p: PackedVector3Array = arch.points
		var along := (p[1]-p[0]).normalized()
		var mid := (p[0]+p[1])*0.5
		var off := Vector3(-along.z,0.0,along.x)
		shots.append({"label":"far-arch","eye":at+mid-along*360.0+off*30.0+Vector3.UP*20.0,"look":at+Vector3(0.0,mid.y*0.6,0.0)})
		shots.append({"label":"arch","eye":at+mid-along*90.0+off*14.0+Vector3.UP*5.0,"look":at+mid})
		shots.append({"label":"through","eye":at+p[0]-along*24.0,"look":at+p[1]})
	shots.append({"label":"top","eye":at+toward*150.0+Vector3.UP*70.0,"look":at+Vector3.UP*5.0})
	var shaft: Dictionary = plan.hole("shaft")
	if not shaft.is_empty():
		var sp: PackedVector3Array = shaft.points
		var top := sp[0]
		shots.append({"label":"skylight","eye":at+Vector3(top.x,plan.lid_top(top.x,top.z)+16.0,top.z)+toward*20.0,"look":at+sp[1]})
	var cav: Dictionary = plan.hole("cavern")
	if not cav.is_empty():
		var cp: PackedVector3Array = cav.points
		var mid := (cp[0]+cp[1])*0.5
		var along := (cp[1]-cp[0]).normalized()
		shots.append({"label":"cavern","eye":at+mid-along*(float(cav.r)*0.9)+Vector3.UP*3.0,"look":at+mid+along*10.0})
		for h: Dictionary in plan.holes:
			if h.kind != "window": continue
			var wp: PackedVector3Array = h.points
			var dir: Vector3 = h.dir
			var label := "gate" if bool(h.get("tight",false)) else "window"
			if shots.any(func(sh: Dictionary) -> bool: return sh.label == label): continue
			shots.append({"label":label,"eye":at+wp[0]+dir*(float(cav.r)*0.6),"look":at+wp[1]+dir*20.0})
			shots.append({"label":label+"-out","eye":at+wp[1]+dir*36.0+Vector3.UP*5.0,"look":at+wp[1]-dir*6.0})
	# The ruins.
	for r: Dictionary in plan.ruins:
		var f: Transform3D = r.at
		match str(r.kind):
			"feed":
				var length := 6.4*int(r.spans)
				shots.append({"label":"feed","eye":at+f*Vector3(length*0.35,6.0,22.0),"look":at+f*Vector3(length*0.6,7.0,0.0)})
				shots.append({"label":"spill","eye":at+f*Vector3(length+16.0,-14.0,10.0),"look":at+f*Vector3(length+2.0,-10.0,0.0)})
			"hall":
				var length := 8.0*int(r.bays)
				shots.append({"label":"hall","eye":at+f*Vector3(-26.0,7.0,-20.0),"look":at+f*Vector3(length*0.5,4.0,0.0)})
				shots.append({"label":"hall-lane","eye":at+f*Vector3(-10.0,2.4,6.0),"look":at+f*Vector3(length,2.4,6.0)})
			"run":
				shots.append({"label":"run","eye":at+f*Vector3(-6.0,9.0,9.0),"look":at+f*Vector3(16.0,6.0,0.0)})
			"gate":
				shots.append({"label":"gate-front","eye":at+f*Vector3(2.0,4.0,22.0),"look":at+f*Vector3(0.0,3.4,0.0)})
	var eye_hole: Dictionary = plan.hole("eye")
	if not eye_hole.is_empty():
		var p: PackedVector3Array = eye_hole.points
		var along := (p[1]-p[0]).normalized()
		var mid := (p[0]+p[1])*0.5
		shots.append({"label":"eye","eye":at+p[0]-along*60.0+Vector3.DOWN*6.0,"look":at+mid})
	return shots

func _view(local: Vector3) -> Vector3:
	return _parent.to_local(_islets.to_global(local))

## Holds the eye at `at` looking at `look` (home coordinates) for `count`
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
