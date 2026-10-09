extends SceneTree
## The Sundered hall (scripts/sundered_hall.gd), rendered: the game with
## the hall near the home, every piece's near detail built and stood, then
## stills from its real positions: an overview, the approach to the gate,
## inside each piece along the line, across each torn gap, the aqueduct's
## arch, the roof from above, a torn end from outside, the apse.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sundered.gd \
##     -- --no-title --motif=sundered --no-clusters --out=captures/sundered/try1 [--hours=noon,golden] [--only=gate,inside]
const Sundered = preload("res://scripts/sundered_hall.gd")
const SunderedBuild = preload("res://scripts/sundered_build.gd")
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-sundered"
var only: Array = []
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
	print("SUNDERED still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(1500).timeout.connect(func() -> void: push_error("sundered capture timed out"); quit(2))
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
	var spot: Dictionary = {}
	for s: Dictionary in field.spots:
		if s.motif == "sundered": spot = s
	if spot.is_empty():
		push_error("no sundered hall in this world (pass --motif=sundered)")
		quit(1)
		return
	field.plan_now(spot.key)
	var c: Dictionary = field.clusters[spot.key]
	var plan: Dictionary = c.plan
	plan.keep_near = true
	# Every piece's near detail stood, and shown (as if flown near).
	for live: Dictionary in c.halls:
		SunderedBuild.build_now(live,plan)
		(live.near as Node3D).visible = true
		(live.far as Node3D).visible = false
	print("SUNDERED stood %d pieces at %s, line %.0f m" % [(c.halls as Array).size(),spot.at,plan.length])
	var at: Vector3 = spot.at
	var stood: Dictionary = field.members_of(spot.key)
	var any: Dictionary = stood.values()[0]
	var home := func(p: Vector3) -> Vector3: return at+p+((any.node as Node3D).position-(any.home as Vector3))
	var line := Sundered.line(plan,1.0)
	var shots := _shots(plan,line,home)
	for hour_name: String in hours_wanted:
		var first := true
		for shot: Dictionary in shots:
			if not only.is_empty() and not str(shot.label).get_slice("-",0) in only: continue
			# Keep the near detail shown however far the eye stands.
			for live: Dictionary in c.halls:
				if live.near != null:
					(live.near as Node3D).visible = true
					(live.far as Node3D).visible = false
			await _hold_at(shot.eye,shot.look,hours[hour_name],60 if first else 30,c.halls)
			first = false
			await still("%s-%s" % [shot.label,hour_name])
	print("SUNDERED done")
	quit(0)

## The views (islets' frame, home coordinates).
func _shots(plan: Dictionary, line: Array, home: Callable) -> Array:
	var out: Array = []
	var pieces: Array = plan.pieces
	var first: Dictionary = pieces[0]
	var last: Dictionary = pieces[pieces.size()-1]
	var a: Vector3 = home.call(Sundered.lane_point(first,0.0))
	var b: Vector3 = home.call(Sundered.lane_point(last,float(last.length)))
	var mid := (a+b)*0.5
	var span := a.distance_to(b)
	var way := (b-a).normalized()
	var side := way.cross(Vector3.UP).normalized()
	out.append({"label":"overview","eye":mid+side*span*0.55+Vector3.UP*span*0.35,"look":mid})
	out.append({"label":"overview-end","eye":b+way*120.0+side*60.0+Vector3.UP*70.0,"look":mid})
	var by_s := func(s: float) -> Dictionary:
		for e: Dictionary in line:
			if float(e.s) >= s: return e
		return line[line.size()-1]
	# The approach to the gate.
	var gate: Dictionary = by_s.call(Sundered.LEAD-40.0)
	out.append({"label":"gate","eye":(home.call(gate.at) as Vector3)+Vector3.UP*1.5,"look":home.call((by_s.call(Sundered.LEAD+20.0) as Dictionary).at)})
	# Inside each piece, along the line.
	for piece: Dictionary in pieces:
		for share: float in [0.3,0.7]:
			var s := float(piece.s0)+float(piece.length)*share
			var e: Dictionary = by_s.call(s)
			out.append({"label":"inside-%d-%s-%d" % [piece.index,piece.act,int(share*10)],"eye":home.call(e.at),"look":home.call((by_s.call(s+22.0) as Dictionary).at)})
	# Across each gap from just inside the torn end.
	for gap: Dictionary in plan.gaps:
		var e: Dictionary = by_s.call(float(gap.s0)-6.0)
		out.append({"label":"gap-%d-%s" % [gap.index,gap.kind],"eye":(home.call(e.at) as Vector3)+Vector3.UP*0.5,"look":home.call((by_s.call(float(gap.s0)+float(gap.span)+10.0) as Dictionary).at)})
		# The torn end from outside, off to the side.
		var end: Vector3 = home.call(Sundered.lane_point(pieces[gap.from],float(pieces[gap.from].length)))
		var w: Vector3 = Sundered.lane_way(pieces[gap.from],float(pieces[gap.from].length))
		var sd := w.cross(Vector3.UP).normalized()
		if gap.index % 3 == 0: out.append({"label":"torn-%d" % gap.index,"eye":end+w*18.0+sd*34.0+Vector3.DOWN*4.0,"look":end+Vector3.DOWN*3.0})
	# The roof from above, a nave piece.
	for piece: Dictionary in pieces:
		if piece.act == "nave":
			var m: Vector3 = home.call(Sundered.lane_point(piece,float(piece.length)*0.5))
			out.append({"label":"roof-%d" % piece.index,"eye":m+Sundered.lane_way(piece,float(piece.length)*0.5).cross(Vector3.UP)*40.0+Vector3.UP*38.0,"look":m})
			break
	# The apse and the release, looking back.
	var r: Dictionary = by_s.call(float(plan.length)-10.0)
	out.append({"label":"apse","eye":(home.call(r.at) as Vector3)+Vector3.UP*4.0,"look":home.call(Sundered.lane_point(last,float(last.length)-20.0))})
	return out

func _view(local: Vector3) -> Vector3:
	return _parent.to_local(_islets.to_global(local))

func _hold_at(at_home: Vector3, look_home: Vector3, hour: float, count: int, halls: Array) -> void:
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
		for live: Dictionary in halls:
			if live.near != null:
				(live.near as Node3D).visible = true
				(live.far as Node3D).visible = false
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
