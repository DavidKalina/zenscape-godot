extends SceneTree
## Headless probe of the grass snake (scripts/life_snakes.gd, docs/scenic/life.md).
## Opens the product scene on the Genesis plain, digs a pond with a small wood
## and a few shrubs beside it, waits for the fish, then summons a snake and
## steps it at a fixed 30 fps through its whole visit: out of cover, coil, bask,
## hunt along the edge, swim across and leave. It measures how the rings meet
## the ground and water, their spacing, the head's speed, any sideways slip,
## per-frame acceleration, and the time each step takes. Last it runs the life
## clock fast and waits for a snake to come by itself.
##   godot --headless --path . -s res://tools/probe_snake.gd -- --dump=/tmp/zs-snake-previews/frames
## `--dump=DIR` writes the mesh, the ground and water, the plants and every
## frame's bone poses, ripples, fish and camera for
## tools/render_snake_probe.py (the first visit only). `--visits=N` runs N
## visits back to back, each choosing its own way, and adds their numbers up
## (`--dump-visit=N` dumps visit N instead of the first).
## `--approach=N` (default 1) brings the camera in during the first N visits'
## hunts, the way a player would: in from the default view to 4 m, round the
## snake, right in to 1.5 m (where it hisses), a while there, and out again.
## `--bask=S`, `--hunts=N` and `--no-swim` shape the visits.
const Snakes = preload("res://scripts/life_snakes.gd")
const DT := 1.0/30.0
var scene: Node3D
var life: Node3D
var snake: Node3D
var dump := ""
var bask := 8.0
var hunts := 3
var swim := true
var visits := 1
var approaches := 1
var dump_visit := 0
## Every measure, over every visit.
var m := {}
var worst_spacing := [1.0,0,0,""]
var worst_stretch := [1.0,0,0,""]
var fastest := [0.0,0,""]
var pops := []
var lo := Vector2(INF,INF)
var hi := Vector2(-INF,-INF)

func _initialize() -> void: run.call_deferred()

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	return {"n":sorted.size(),"median":snappedf(sorted[sorted.size()/2],0.0001),"p95":snappedf(sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],0.0001),"p99":snappedf(sorted[mini(sorted.size()-1,int(sorted.size()*0.99))],0.0001),"max":snappedf(sorted.back(),0.0001),"min":snappedf(sorted[0],0.0001)}

func ground(p: Vector2) -> float:
	var h: Variant = life.data.ground_height(p)
	return float(h) if h != null else NAN

func add(key: String, value: float) -> void:
	if not m.has(key): m[key] = []
	m[key].append(value)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dump="): dump = arg.trim_prefix("--dump=")
		if arg.begins_with("--bask="): bask = float(arg.trim_prefix("--bask="))
		if arg.begins_with("--hunts="): hunts = int(arg.trim_prefix("--hunts="))
		if arg.begins_with("--visits="): visits = int(arg.trim_prefix("--visits="))
		if arg.begins_with("--approach="): approaches = int(arg.trim_prefix("--approach="))
		if arg.begins_with("--dump-visit="): dump_visit = int(arg.trim_prefix("--dump-visit="))
		if arg == "--no-swim": swim = false
	create_timer(170+120*visits).timeout.connect(func() -> void: push_error("Snake probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-snake-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	life = scene.land_life
	snake = life.snakes
	var editor: NativeChunkEditor = scene._chunk_editor
	var data := editor.data
	editor.set_process_input(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene._celestial.set_phase(0.34)
	await create_timer(1.0).timeout
	# A basin with a pond, a small wood on its east bank and shrubs on the west.
	var basin := Vector2(-3.0,2.0)
	data.begin_stroke()
	for _pass in range(6): data.brush(basin,4.2,0.3,"lower",0.0)
	var bottom: float = data.ground_height(basin)
	var added := data.add_pond(basin,bottom+0.75)
	for i in range(14):
		var angle := -1.2+float(i)*0.19
		var p := basin+Vector2.from_angle(angle)*(6.0+0.8*sin(float(i)*2.3))
		var id := data.place("broadleaf" if i%3 else "tree",p,float(i),0.9)
		if id >= 0: data.objects.back()["source"] = "emerged"
	for i in range(7):
		var p := basin+Vector2.from_angle(2.2+float(i)*0.28)*(5.2+0.5*sin(float(i)*1.9))
		var id := data.place("fern" if i%2 else "shrub",p,float(i),1.0)
		if id >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	await editor.refresh(self)
	life.pace = 6.0
	var waiting := Time.get_ticks_msec()
	while Time.get_ticks_msec()-waiting < 20000 and (life.survey == null or life.present("fish").size() < 2):
		await process_frame
	await create_timer(0.5).timeout
	print("SNAKE world pond=%s fish=%d spawn=%d frogs=%d daylight=%.2f phase=%.2f" % [added,life.present("fish").size(),life.present("spawn").size(),life.present("frog").size(),life._daylight(),scene._celestial.phase])
	# From here the probe steps the snake itself, at exactly 30 fps.
	life.set_process(false)
	if not dump.is_empty(): DirAccess.make_dir_recursive_absolute(dump)
	for visit in range(visits):
		if not run_visit(visit,dump if visit == dump_visit else ""): break
	var keys := m.keys()
	keys.sort()
	for key in keys: print("SNAKE %s %s" % [key,JSON.stringify(stats(m[key]))])
	print("SNAKE worst_us=",snake.worst_usec," hisses=",snake.hisses)
	print("SNAKE pops ",pops.size()," ",JSON.stringify(pops.slice(0,24)))
	print("SNAKE extremes squeeze=",worst_spacing," stretch=",worst_stretch," fastest=",fastest)
	if not dump.is_empty(): write_scene(dump)
	# Now the life clock runs fast and the snake should come by itself.
	snake._next = 0.0
	life.set_process(true)
	life.pace = 12.0
	var natural := -1.0
	var since := Time.get_ticks_usec()
	while Time.get_ticks_usec()-since < 25000000:
		await process_frame
		if snake.showing() != "":
			natural = life.clock
			break
	print("SNAKE natural arrival clock=%.1f phase=%s visits=%d" % [natural,snake.showing(),snake.visits])
	var forced: bool = life.force("snake")
	print("SNAKE force while present=%s" % forced)
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit()

## One visit, start to finish, measured frame by frame. False when no snake came.
func run_visit(visit: int, dir: String) -> bool:
	var began := Time.get_ticks_usec()
	var summoned: bool = snake.force({"swim":swim,"bask":bask,"hunts":hunts})
	print("SNAKE visit=%d forced=%s arrive_ms=%.2f" % [visit,summoned,(Time.get_ticks_usec()-began)/1000.0])
	if not summoned: return false
	var first_entry: int = snake.journal.size()
	var arcs: PackedFloat32Array = snake.stations()
	var radii: PackedFloat32Array = snake.radii()
	var neck: int = snake._neck_count
	var rings: int = arcs.size()
	var frame_file: FileAccess = FileAccess.open(dir+"/frames.jsonl",FileAccess.WRITE) if not dir.is_empty() else null
	var timeline := []
	var last_phase := ""
	var previous: Array = []
	var before: Array = []
	# The snout over the last four frames, for acceleration and jerk.
	var snouts: Array[Vector3] = []
	# The simulated player camera: far off until the hunt, then in, round,
	# right in, and out.
	var camera: Camera3D = scene.camera
	var far := life.to_local(camera.global_position)
	var approach := visit < approaches
	var cam_t := -1.0
	var held := 0.0
	var az0 := 0.0
	var seen := Vector3.ZERO
	var hisses_before: int = snake.hisses
	var frame := 0
	while frame < 30*240:
		var head_now: Vector3 = snake._head_pos
		seen = head_now if frame == 0 else seen.lerp(head_now,1.0-exp(-DT*1.2))
		if approach and cam_t < 0.0:
			# At a hunt stop with stops still to come, so it is on land a while.
			held = held+DT if snake.showing() == "hunt" and not snake._going and int(snake._state.get("hunts",0)) >= 1 else 0.0
			if held > 0.6:
				cam_t = 0.0
				az0 = snake._head_fwd.angle()+0.9
		var cam_local := far
		if cam_t >= 0.0:
			cam_t += DT
			cam_local = camera_path(cam_t,seen,az0,far)
			# Like the game's camera, it never goes into the ground.
			var under := ground(Vector2(cam_local.x,cam_local.z))
			if not is_nan(under): cam_local.y = maxf(cam_local.y,under+0.45)
		camera.global_position = life.to_global(cam_local)
		var t0 := Time.get_ticks_usec()
		snake.advance(DT)
		add("cost_us",float(Time.get_ticks_usec()-t0))
		# The pond's own life moves too, on the same clock.
		life.clock += DT
		life._animate(DT)
		frame += 1
		var phase: String = snake.showing()
		if phase != last_phase:
			timeline.append([snappedf(frame*DT,0.01),phase])
			last_phase = phase
		if phase == "": break
		var poses: Array = snake.poses()
		var centers: Array[Vector3] = []
		for k in range(rings): centers.append((poses[k] as Transform3D).origin)
		var head_pose: Transform3D = poses[rings]
		var snout := head_pose.origin+head_pose.basis.z.normalized()*Snakes.HEAD
		# Contact: each full-size ring's flat belly on the ground, or its centre
		# at the water's level, or its belly on the body under it.
		for k in range(rings):
			var pose: Transform3D = poses[k]
			if pose.basis.y.length() < 0.9 or radii[k] < 0.004: continue
			var c := pose.origin
			lo = lo.min(Vector2(c.x,c.z))
			hi = hi.max(Vector2(c.x,c.z))
			var r := radii[k]
			var belly := c-pose.basis.y*(Snakes.BELLY*r)
			var g := ground(Vector2(belly.x,belly.z))
			if is_nan(g): continue
			var level: float = snake._water_est(Vector2(c.x,c.z))
			var floating := level-0.1*r > g+Snakes.BELLY*r
			if k < neck and (snake._pose_w > 0.02 or snake._lift > 0.004): continue
			var over := -1
			for j in range(rings):
				if absi(j-k) < 7: continue
				if Vector2(centers[j].x-c.x,centers[j].z-c.z).length() < r*1.2: over = j
			if over >= 0:
				var top := centers[over]+(poses[over] as Transform3D).basis.y*(Snakes.BELLY*radii[over])
				if belly.y > g+0.01: add("contact_on_body_m",belly.y-top.y)
				continue
			if floating:
				add("contact_water_m",absf(c.y-(level-0.1*r)))
				continue
			add("contact_land_m",absf(belly.y-g))
			for side: float in [-1.0,1.0]:
				var edge := belly+pose.basis.x*(side*0.5*r)
				var ge := ground(Vector2(edge.x,edge.z))
				if not is_nan(ge): add("belly_edge_over_ground_m",edge.y-ge)
		for k in range(rings-1):
			if (poses[k] as Transform3D).basis.y.length() < 0.9 or (poses[k+1] as Transform3D).basis.y.length() < 0.9: continue
			var ratio := centers[k].distance_to(centers[k+1])/(arcs[k+1]-arcs[k])
			add("spacing_neck_ratio" if k < neck else "spacing_body_ratio",ratio)
			if k >= neck and ratio < worst_spacing[0]: worst_spacing = [snappedf(ratio,0.001),visit,frame,k,phase]
			if k >= neck and ratio > worst_stretch[0]: worst_stretch = [snappedf(ratio,0.001),visit,frame,k,phase]
		if not previous.is_empty():
			var prev_snout: Vector3 = previous[rings]
			var speed := Vector2(snout.x-prev_snout.x,snout.z-prev_snout.z).length()/DT
			add("head_speed_mps",speed)
			if speed > fastest[0]: fastest = [snappedf(speed,0.001),visit,frame,phase]
			for k in range(neck,rings-1):
				if (poses[k] as Transform3D).basis.y.length() < 0.9: continue
				var v: Vector3 = (centers[k]-(previous[k] as Vector3))/DT
				var along := Vector2(centers[k-1].x-centers[k+1].x,centers[k-1].z-centers[k+1].z).normalized()
				add("slip_mps",absf(Vector2(v.x,v.z).dot(Vector2(-along.y,along.x))))
		if not before.is_empty():
			var worst := 0.0
			var worst_k := -1
			for k in range(rings):
				if (poses[k] as Transform3D).basis.y.length() < 0.9: continue
				var a := ((centers[k]-2.0*(previous[k] as Vector3)+(before[k] as Vector3))/(DT*DT)).length()
				if k >= neck: add("accel_body_mps2",a)
				if a > worst:
					worst = a
					worst_k = k
			var ha := ((snout-2.0*(previous[rings] as Vector3)+(before[rings] as Vector3))/(DT*DT)).length()
			add("accel_head_mps2",ha)
			if ha > 3.5: add("head_spikes_over_3_5",1.0)
			if worst > 6.0 or ha > 3.5: pops.append([visit,frame,phase,snappedf(worst,0.1),worst_k,snappedf(ha,0.1)])
		snouts.append(snout)
		if snouts.size() > 4: snouts.remove_at(0)
		if snouts.size() == 4:
			add("jerk_head_mps3",((snouts[3]-3.0*snouts[2]+3.0*snouts[1]-snouts[0])/(DT*DT*DT)).length())
		# How closely the head follows what it watches, while it holds and
		# looks (not winding up to move, not hissing).
		var watch: Array = snake.watching()
		if not snake._going and snake._pose_w > 0.9 and snake._hiss_t < 0.0 and not snake._hold.is_empty() and snake._hold_age < float(snake._hold.time)-Snakes.ANTICIPATION:
			var to: Vector3 = (watch[1] as Vector3)-head_pose.origin
			var ahead := Vector2(head_pose.basis.z.x,head_pose.basis.z.z)
			var want := Vector2(to.x,to.z)
			if want.length() > 0.05 and ahead.length() > 0.01:
				var err := rad_to_deg(absf(ahead.angle_to(want)))
				add("track_err_camera_deg" if watch[0] == "camera" else "track_err_other_deg",err)
		if snake._hiss_t >= 0.0: add("jaw_rad",(poses[rings+2] as Transform3D).basis.z.normalized().angle_to(head_pose.basis.z.normalized()))
		before = previous
		previous = centers.duplicate()
		previous.append(snout)
		if frame_file != null:
			var bones := []
			for pose: Transform3D in poses:
				bones.append_array([pose.basis.x.x,pose.basis.x.y,pose.basis.x.z,pose.basis.y.x,pose.basis.y.y,pose.basis.y.z,pose.basis.z.x,pose.basis.z.y,pose.basis.z.z,pose.origin.x,pose.origin.y,pose.origin.z])
			var ripples := []
			for ring: Dictionary in life._ring_state:
				if float(ring.age) < 4.0: ripples.append([ring.p.x,ring.p.y,ring.p.z,ring.age,ring.size])
			var fish := []
			# The fish sites' own places (the headless renderer keeps no
			# instance transforms); the renderer turns each along its motion.
			for site: Dictionary in life.present("fish"):
				var at: Vector3 = site.p
				fish.append([int(site.slot),at.x,at.y,at.z,float(site.size)])
			var aim: Vector3 = watch[1]
			frame_file.store_line(JSON.stringify({"f":frame,"phase":phase,"bones":bones.map(func(v: float) -> float: return snappedf(v,0.00001)),"rings":ripples,"cam":[cam_local.x,cam_local.y,cam_local.z],"look":[seen.x,seen.y,seen.z],"fish":fish,"aim":[watch[0],aim.x,aim.y,aim.z],"hiss":snake._hiss_t}))
	if frame_file != null: frame_file.close()
	add("visit_seconds",frame*DT)
	add("hisses_per_visit",float(snake.hisses-hisses_before))
	camera.global_position = life.to_global(far)
	print("SNAKE visit=%d timeline %s" % [visit,JSON.stringify(timeline)])
	var legs := []
	for entry: Array in snake.journal.slice(first_entry):
		if entry[1] == "leg": legs.append(entry.slice(2))
	print("SNAKE visit=%d legs [metres, left to goal, usec] %s" % [visit,JSON.stringify(legs)])
	for leg: Array in legs:
		if float(leg[1]) > 0.3: add("legs_short_of_goal",1.0)
	return true

## The player's camera: in from `far` to 4.2 m off the snake over 5 s, round
## it 90 degrees, right in to 1.5 m, 7.5 s there, and back out.
func camera_path(t: float, head: Vector3, az0: float, far: Vector3) -> Vector3:
	var orbit := func(az: float, distance: float, rise: float) -> Vector3:
		return head+Vector3(cos(az)*cos(rise),sin(rise),sin(az)*cos(rise))*distance
	if t < 5.0: return far.lerp(orbit.call(az0,4.2,0.5),ease_in_out(t/5.0))
	if t < 11.0:
		var u := ease_in_out((t-5.0)/6.0)
		return orbit.call(az0+1.6*u,lerpf(4.2,3.6,u),0.5)
	if t < 13.5:
		var u := ease_in_out((t-11.0)/2.5)
		return orbit.call(az0+1.6,lerpf(3.6,1.5,u),lerpf(0.5,0.62,u))
	if t < 21.0: return orbit.call(az0+1.6+0.25*ease_in_out((t-13.5)/7.5),1.5,0.62)
	if t < 26.0: return (orbit.call(az0+1.85,1.5,0.62) as Vector3).lerp(far,ease_in_out((t-21.0)/5.0))
	return far

static func ease_in_out(x: float) -> float:
	x = clampf(x,0.0,1.0)
	return x*x*x*(x*(6.0*x-15.0)+10.0)

## The mesh, the ground and water round the visit, and the plants.
func write_scene(dir: String) -> void:
	var mesh: ArrayMesh = snake.body_mesh()
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var flat := []
	var paint := []
	var owner := []
	for i in range(vertices.size()):
		flat.append_array([vertices[i].x,vertices[i].y,vertices[i].z])
		paint.append_array([colors[i].r,colors[i].g,colors[i].b])
		owner.append(bones[i*4])
	var file := FileAccess.open(dir+"/mesh.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"vertices":flat,"colors":paint,"bones":owner}))
	file.close()
	print("SNAKE mesh triangles=%d bones=%d" % [vertices.size()/3,Snakes.STATIONS+3])
	var pond: PackedVector3Array = scene._chunk_editor.content.pond_vertices
	var low := (lo.min(Vector2(-7.5,-2.5))-Vector2(2.5,2.5)).max(Vector2(-13.9,-13.9))
	var high := (hi.max(Vector2(1.5,6.5))+Vector2(2.5,2.5)).min(Vector2(13.9,13.9))
	var step := 0.1
	var nx := int((high.x-low.x)/step)+1
	var nz := int((high.y-low.y)/step)+1
	var heights := []
	for z in range(nz):
		for x in range(nx):
			var h := ground(low+Vector2(x,z)*step)
			heights.append(snappedf(h if not is_nan(h) else 0.0,0.0001))
	var water := []
	for v in pond: water.append_array([v.x,v.y,v.z])
	var plants := []
	for item: Dictionary in life.data.objects:
		var p := Vector2(float(item.x),float(item.z))
		if p.x < low.x or p.y < low.y or p.x > high.x or p.y > high.y: continue
		plants.append([str(item.asset),p.x,ground(p),p.y,float(item.get("scale",1.0))])
	file = FileAccess.open(dir+"/scene.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"origin":[low.x,low.y],"step":step,"nx":nx,"nz":nz,"heights":heights,"water":water,"plants":plants}))
	file.close()
	print("SNAKE dump ",dir," grid=",nx,"x",nz)
