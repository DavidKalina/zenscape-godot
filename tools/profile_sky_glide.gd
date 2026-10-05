extends SceneTree
## Frame times along a scripted glide through the sky world (scripts/
## sky_world.gd): the wanderer steps off into the glide, then the eye is
## carried along a fixed route at SPEED (out from the plate, through a
## wall's pass, along the band and back by the range in sight of the
## plate), the sky, haze and islands advanced as the glide would, so the
## ranges, islets, islands and cumulus stream in and out as they do in
## play. Each frame's wall time and the islands' advance (the streaming's
## main-thread share) are recorded; prints percentiles, the frames over
## 25 and 33 ms, and the worst frames with what stood up in them.
## Rendered when asked (a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/profile_sky_glide.gd \
##     -- --no-title [--speed=40] [--out=/private/tmp/zs-glide.txt]
## Headless runs measure the scripts only.
const SkyWorld = preload("res://scripts/sky_world.gd")
var scene: Node3D
var eye: Node
var speed := 40.0
var out := ""

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--speed="): speed = float(a.trim_prefix("--speed="))
		elif a.begins_with("--out="): out = a.trim_prefix("--out=")
	create_timer(1200).timeout.connect(func() -> void: push_error("sky glide profile timed out"); quit(2))
	root.unfocusable = true
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-glide-profile-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	eye = scene.wanderer
	var islands: Node3D = eye.islands
	var peaks: Node3D = islands.peaks
	# The sky's skylines stood whole first, as the loading screen would.
	while not (SkyWorld.ready() and peaks.ring.whole): await process_frame
	await create_timer(2.0).timeout
	scene.world_clock.running = false
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	for i in range(5): await process_frame
	eye._launch(6.0,false)
	eye.set_process(false)
	eye._layer.visible = false
	var route := _route()
	var length := 0.0
	for k in range(route.size()-1): length += route[k].distance_to(route[k+1])
	print("GLIDE route %.0f m at %.0f m/s (%.0f s); premade ahead: %d" % [length,speed,length/speed,(peaks.get("premade") as Dictionary).size() if peaks.get("premade") != null else -1])
	var frames: Array[float] = []
	var advances: Array[float] = []
	var events: Array = []
	var travelled := 0.0
	var last := Time.get_ticks_usec()
	var glide: RefCounted = eye.glide
	var built_before: int = peaks.range_count()
	while travelled < length:
		var now := Time.get_ticks_usec()
		var wall := (now-last)/1000.0
		last = now
		var delta := 1.0/60.0
		travelled += speed*delta
		var at := _along(route,travelled)
		var ahead := _along(route,travelled+40.0)
		var way := (ahead-at).normalized()
		glide.position = at
		glide.heading = atan2(-way.x,-way.z)
		glide.pitch = 0.0
		glide.speed = speed
		glide.velocity = way*speed
		eye.sky.advance(delta,at,0.0)
		var t0 := Time.get_ticks_usec()
		var count_before: int = peaks.range_count()+islands.islets.islet_count()+islands.copy_count()+islands.towers.built.size()
		islands.advance(delta,at,glide.heading,0.0)
		var spent := (Time.get_ticks_usec()-t0)/1000.0
		var count_after: int = peaks.range_count()+islands.islets.islet_count()+islands.copy_count()+islands.towers.built.size()
		var o := at-way*40.0+Vector3.UP*8.0
		scene.target = at
		scene.distance = o.distance_to(at)
		var dir := (o-at).normalized()
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = acos(clampf(dir.y,-1.0,1.0))
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		if frames.size() > 0 or travelled > speed*delta*2.0:
			frames.append(wall)
			advances.append(spent)
			if count_after != count_before or spent > 4.0: events.append([frames.size(),wall,spent,count_after-count_before,peaks.range_count()])
		await process_frame
	var report := _summary("frame",frames)+"\n"+_summary("islands.advance",advances)
	var worst := []
	for k in range(frames.size()): worst.append([frames[k],advances[k],k])
	worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	report += "\nworst frames (wall ms, advance ms, frame): %s" % str(worst.slice(0,10).map(func(w: Array) -> String: return "%.1f/%.1f@%d" % [w[0],w[1],w[2]]))
	var stands := events.filter(func(e: Array) -> bool: return e[3] != 0)
	var stand_ms: Array[float] = []
	for e: Array in stands: stand_ms.append(e[2])
	report += "\n"+_summary("advance on frames something stood up or went (%d)" % stands.size(),stand_ms)
	report += "\nranges made in full on the way: %d standing at the end (%d at the start)" % [peaks.range_count(),built_before]
	print(report)
	if out != "":
		var f := FileAccess.open(out,FileAccess.WRITE)
		f.store_string(report+"\n")
	quit(0)

func _summary(label: String, values: Array[float]) -> String:
	if values.is_empty(): return "%s: none" % label
	var sorted := values.duplicate()
	sorted.sort()
	var pick := func(q: float) -> float: return sorted[clampi(int(q*(sorted.size()-1)),0,sorted.size()-1)]
	var over25 := values.filter(func(v: float) -> bool: return v > 25.0).size()
	var over33 := values.filter(func(v: float) -> bool: return v > 33.4).size()
	return "%s ms: n %d, p50 %.2f, p95 %.2f, p99 %.2f, max %.2f; over 25 ms %d, over 33 ms %d" % [label,values.size(),pick.call(0.5),pick.call(0.95),pick.call(0.99),sorted[-1],over25,over33]

## Out from the plate down its region to a wall's pass, through it, toward
## a range of the band, round along it, and back in by the range in sight
## of the plate.
func _route() -> Array[Vector3]:
	var layout := SkyWorld.layout()
	var up := Vector3.UP*60.0
	var route: Array[Vector3] = [up]
	var outer: Array = layout.passes.filter(func(p: Dictionary) -> bool: return int(p.get("chord",1)) != 0)
	var p: Dictionary = outer[0] if not outer.is_empty() else layout.passes[0]
	var at: Vector3 = p.at
	route.append(Vector3(at.x,0.0,at.z)*0.6+up)
	route.append(Vector3(at.x,0.0,at.z)+up)
	route.append(Vector3(at.x,0.0,at.z)*1.35+up)
	var angle := atan2(at.z,at.x)
	for k in range(1,5):
		var a := angle+k*0.35
		route.append(Vector3(cos(a),0.0,sin(a))*2100.0+up)
	route.append(Vector3(preload("res://scripts/sky_homes.gd").RANGE.x,0.0,preload("res://scripts/sky_homes.gd").RANGE.z)*0.55+up)
	route.append(up)
	return route

func _along(route: Array[Vector3], d: float) -> Vector3:
	for k in range(route.size()-1):
		var seg := route[k].distance_to(route[k+1])
		if d <= seg: return route[k].lerp(route[k+1],d/maxf(seg,0.001))
		d -= seg
	return route[-1]
