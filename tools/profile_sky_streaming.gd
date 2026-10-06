extends SceneTree
## The main thread's cost of the sky streaming in mid-flight: a scripted
## flight from the plate past the fixed islands, out into open sky till a
## fresh island turns up (scripts/sky_cells.gd), past it and the islets, and
## over a chunk, which is claimed as it is flown into (scripts/sky_islands.gd
## `claim`), and on. The frame rate is uncapped, so each frame's wall time is
## its work. Every part stood up mid-glide is timed (scripts/sky_commits.gd);
## the worst frames are printed with what stood up in them, and each kind's
## commits (an island's ground and sides, an islet, a range, a cumulus, the
## claim's steps).
##   Godot --headless --path . -s res://tools/profile_sky_streaming.gd -- \
##     [--speed=22] [--out=/private/tmp/zs-streaming.txt]
## Rendered when asked (a window; add --no-title):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/profile_sky_streaming.gd -- --no-title
## Headless runs measure the scripts only, never the GPU's uploads or
## pipeline builds.
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")

var speed := 22.0
var out := ""
var result := {}

func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--speed="): speed = float(a.trim_prefix("--speed="))
		elif a.begins_with("--out="): out = a.trim_prefix("--out=")
	run.call_deferred()

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: push_error("sky streaming profile timed out"); quit(2))
	result = await fly(root,self,speed)
	print(result.report)
	if out != "":
		var f := FileAccess.open(out,FileAccess.WRITE)
		f.store_string(result.report+"\n")
	quit(0)

## Opens the cozy world under `root`, flies the route and returns
## {frames, commits, claimed, fresh, report} (the test reads the same).
static func fly(root: Window, tree: SceneTree, pace: float, route_scale := 1.0) -> Dictionary:
	root.unfocusable = true
	var scene: Node3D = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-streaming-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	tree.current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await tree.process_frame
	while scene.places.busy or scene._chunk_editor.forming: await tree.process_frame
	var eye: Node = scene.wanderer
	var islands: Node3D = eye.islands
	# The sky made ahead as the loading veil makes it (scripts/sky_reveal.gd).
	var waited := 0
	while not islands.sky_ready() and waited < 6000:
		islands.make_ahead(1.0/60.0)
		waited += 1
		await tree.process_frame
	for i in range(30): await tree.process_frame
	scene.world_clock.running = false
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	for i in range(5): await tree.process_frame
	eye._launch(6.0,false)
	eye.set_process(false)
	eye._layer.visible = false
	for i in range(10): await tree.process_frame
	var route := _route(route_scale)
	var length := 0.0
	for k in range(route.size()-1): length += route[k].distance_to(route[k+1])
	var glide: RefCounted = eye.glide
	var fps_was := Engine.max_fps
	Engine.max_fps = 0
	SkyCommits.log.clear()
	SkyCommits.recording = true
	var frames: Array[float] = []
	var frame_ids: Array[int] = []
	var claiming: Array[bool] = []
	var travelled := 0.0
	var claimed := 0
	var copies_before: int = islands.copy_count()
	var fresh := 0
	var last := Time.get_ticks_usec()
	var first := Engine.get_process_frames()
	while travelled < length or islands.claiming:
		var now := Time.get_ticks_usec()
		var wall := (now-last)/1000.0
		last = now
		var delta := 1.0/60.0
		if not islands.claiming: travelled += pace*delta
		var home := _along(route,travelled)
		var ahead := _along(route,travelled+40.0)
		var at: Vector3 = home+islands.origin
		var way := (ahead-home).normalized()
		glide.position = at
		glide.heading = atan2(-way.x,-way.z)
		glide.pitch = 0.0
		glide.speed = pace
		glide.velocity = way*pace
		# As the flight's own frame does (WandererEye `_advance_flight`).
		if not islands.claiming:
			var under: int = islands.copy_under(at)
			if under >= 0:
				claimed += 1
				eye._claim(under)
		eye.sky.advance(delta,at,0.0)
		var count: int = islands.copy_count()
		islands.advance(delta,at,glide.heading,0.0)
		if islands.copy_count() > count: fresh += islands.copy_count()-count
		var o := at-way*30.0+Vector3.UP*6.0
		scene.target = at
		scene.distance = o.distance_to(at)
		var dir := (o-at).normalized()
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = acos(clampf(dir.y,-1.0,1.0))
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		if Engine.get_process_frames()-first > 3:
			frames.append(wall)
			# The wall time read now is the frame before this one's.
			frame_ids.append(Engine.get_process_frames()-1)
			claiming.append(islands.claiming)
		await tree.process_frame
	SkyCommits.recording = false
	Engine.max_fps = fps_was
	var commits: Array = SkyCommits.log.duplicate()
	var report := _report(frames,frame_ids,claiming,commits,claimed,fresh,length,pace)
	# The claimed plate's habitat, read again a slice a frame: finished.
	var navigation: Variant = scene.get("navigation")
	var habitat := {"settled":navigation != null and not bool(scene.get("_habitat_changed")) and not bool(navigation.get("rebuilding"))}
	var sides := _sides_match(islands)
	report += "\nhabitat settled after the claim: %s; island sides as the plate fits them: %s" % [habitat.settled,sides]
	scene.queue_free()
	await tree.process_frame
	return {"frames":frames,"frame_ids":frame_ids,"commits":commits,"claimed":claimed,"fresh":fresh,"report":report,"habitat":habitat,"sides_match":sides}

## Whether every standing island's earth sides, made on its worker, are the
## ones the plate's own fitting gives its land (NativeChunkEditor
## `skirt_mesh_for`), vertex for vertex.
static func _sides_match(islands: Node3D) -> bool:
	var editor: NativeChunkEditor = islands.editor
	var compared := 0
	for i in range(islands.copy_count()):
		var land: NativeTerrainData = islands.lands[i]
		var island: Node3D = islands._copies[i]
		if land == null or island.get_child_count() < 2: continue
		var made: Mesh = (island.get_child(1) as MeshInstance3D).mesh
		var fitted: Mesh = editor.skirt_mesh_for(land)
		if made == null or fitted == null or made.get_surface_count() != fitted.get_surface_count(): return false
		if made.get_surface_count() == 0: continue
		var a: Array = made.surface_get_arrays(0)
		var b: Array = fitted.surface_get_arrays(0)
		if (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty(): return false
		for k in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV]:
			if a[k] != b[k]: return false
		if made.surface_get_material(0) != fitted.surface_get_material(0): return false
		compared += 1
	return compared > 0

static func _report(frames: Array[float], ids: Array[int], claiming: Array[bool], commits: Array, claimed: int, fresh: int, length: float, pace: float) -> String:
	var by_frame := {}
	for c: Array in commits:
		if not by_frame.has(c[0]): by_frame[c[0]] = []
		by_frame[c[0]].append("%s %.1f" % [c[1],c[2]/1000.0])
	var lines: Array[String] = []
	lines.append("STREAMING route %.0f m at %.0f m/s; %d fresh islands turned up, %d claims" % [length,pace,fresh,claimed])
	lines.append(summary("frame (uncapped wall)",frames))
	var worst := []
	for k in range(frames.size()): worst.append(k)
	worst.sort_custom(func(a: int, b: int) -> bool: return frames[a] > frames[b])
	lines.append("worst frames (wall ms: what stood up):")
	for k: int in worst.slice(0,15):
		lines.append("  %.1f ms @%d%s: %s" % [frames[k],ids[k]," claiming" if claiming[k] else "",", ".join(by_frame.get(ids[k],[]))])
	var kinds := {}
	for c: Array in commits:
		if not kinds.has(c[1]): kinds[c[1]] = [] as Array[float]
		(kinds[c[1]] as Array[float]).append(c[2]/1000.0)
	lines.append("commits by kind (ms):")
	var names := kinds.keys()
	names.sort()
	for kind: String in names: lines.append("  "+summary(kind,kinds[kind]))
	var per_frame: Array[float] = []
	var totals := {}
	for c: Array in commits: totals[c[0]] = float(totals.get(c[0],0.0))+c[2]/1000.0
	for f in totals: per_frame.append(totals[f])
	lines.append(summary("commits per frame that had any",per_frame))
	return "\n".join(lines)

static func summary(label: String, values: Array[float]) -> String:
	if values.is_empty(): return "%s: none" % label
	var sorted := values.duplicate()
	sorted.sort()
	var pick := func(q: float) -> float: return sorted[clampi(int(q*(sorted.size()-1)),0,sorted.size()-1)]
	var total := 0.0
	for v in values: total += v
	return "%s: n %d, p50 %.2f, p95 %.2f, p99 %.2f, max %.2f, total %.0f" % [label,values.size(),pick.call(0.5),pick.call(0.95),pick.call(0.99),sorted[-1],total]

## In home coordinates, 50 m over the plate's first home: out past the first
## fixed island, on into open sky (far enough from every island for long
## enough for a fresh one to turn up ahead, SkyCells WANDER_*), round, and
## in over the last fixed island's middle, which claims it, and on past it.
static func _route(scale: float) -> Array[Vector3]:
	var up := Vector3.UP*50.0
	var offsets: Array = SkyIslands.OFFSETS
	var a: Vector3 = offsets[0]
	var b: Vector3 = offsets[4]
	var route: Array[Vector3] = [up]
	route.append(Vector3(a.x,0.0,a.z+120.0)+up)
	route.append(Vector3(a.x+700.0*scale,0.0,a.z-500.0*scale)+up)
	route.append(Vector3(a.x+1300.0*scale,0.0,a.z-300.0*scale)+up)
	route.append(Vector3(b.x+500.0,0.0,b.z)+up)
	route.append(Vector3(b.x,b.y+30.0,b.z))
	route.append(Vector3(b.x-300.0,b.y+30.0,b.z+250.0))
	return route

static func _along(route: Array[Vector3], d: float) -> Vector3:
	for k in range(route.size()-1):
		var seg := route[k].distance_to(route[k+1])
		if d <= seg: return route[k].lerp(route[k+1],d/maxf(seg,0.001))
		d -= seg
	return route[-1]
