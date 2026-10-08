extends SceneTree
## What a frame in the lower world (`--below`, scripts/sky_below.gd) costs,
## rendered: a fixed set of views held still, and for each the renderer's
## counts (primitives, draw calls, objects, each for the visible pass and
## the shadow pass), the video memory, and the CPU's frame and process
## times, then where the primitives and draw calls go: each kind of thing
## hidden in turn (the islands' tops, sides, ponds and massifs, their near
## trees, far trees, stones and small plants, the ocean, the ceiling, the
## air, the ranges, the clouds) and what the counts drop by.
## Views (as tools/capture_lower_world.gd's, with the forest and the
## mountains laid ahead by --landform):
##   cruise: the chase view flying low over the archipelago;
##   skim: a few metres over the water by an island's shore;
##   high: plane height (60 m) over a shelf, along the coast;
##   level: cruise height out over open water to the horizon;
##   forest: plane height over a forest island, looking across it;
##   mountains: plane height off a mountain island;
##   golden: the cruise at golden hour.
## Rendered only when asked for (needs a window; this Mac gives no GPU
## time, so the counts stand in for it):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/probe_lower_frame.gd \
##     -- --no-title --below --landform=forest,mountains [--only=cruise,forest] [--no-split] [--shots=/private/tmp/dir]
var scene: Node3D
var eye: Node
var only: Array = []
var shots := ""
var noon := WorldClock.hour_for_phase(0.5)
var golden := WorldClock.hour_for_phase(0.72)
const KINDS := ["isl_top","isl_sides","isl_pond","isl_massif","isl_other","trees","far_trees","stones","plants","ocean","ceiling","air","ranges","clouds","other"]

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument.begins_with("--shots="): shots = argument.trim_prefix("--shots=")
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)
	create_timer(900).timeout.connect(func() -> void: push_error("lower frame probe timed out"); quit(2))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	var places := "/private/tmp/zs-lower-frame/places-%d/places.json" % Time.get_ticks_usec()
	scene.places_path = places
	DirAccess.make_dir_recursive_absolute(places.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	scene.world_clock.running = false
	eye = scene.wanderer
	if eye.lower == null:
		push_error("no lower world: pass --below")
		quit(1)
		return
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
	var start := Vector3(260.0,-200.0,-180.0)
	await _hold({"hour":noon,"eye":start,"look":start+Vector3(100.0,-20.0,0.0)},30)
	var arch: Node3D = eye.lower.archipelago
	if not arch.asked.is_empty() and arch.forced.size() < arch.asked.size():
		for k in range(16):
			arch.arrive(start,Vector2.from_angle(TAU*k/16.0))
			if arch.forced.size() == arch.asked.size(): break
	arch.build_near(start,1100.0)
	var b: Dictionary = arch.nearest(start+Vector3(150.0,0.0,0.0),600.0)
	var middle: Vector3 = arch.islets.place(b)
	var water: float = eye.lower.OCEAN
	var r: float = b.shape.reach
	var away := (Vector3(middle.x-start.x,0.0,middle.z-start.z)).normalized()
	var side := Vector3(-away.z,0.0,away.x)
	var views := [
		{"label":"cruise","hour":noon,"eye":middle-away*(r+90.0)+Vector3.UP*(water-middle.y+28.0),"look":middle+away*200.0+Vector3.DOWN*(middle.y-water),"chase":true},
		{"label":"skim","hour":noon,"eye":middle-away*(r+30.0)+side*10.0+Vector3.UP*(water-middle.y+4.0),"look":middle+Vector3.UP*2.0},
		{"label":"high","hour":noon,"eye":middle-away*(r+70.0)+side*40.0+Vector3.UP*(water-middle.y+60.0),"look":middle+side*(r*1.5)+Vector3.DOWN*(middle.y-water)},
		{"label":"level","hour":noon,"eye":Vector3(start.x,water+30.0,start.z),"look":Vector3(start.x,water+30.0,start.z)-away*1000.0+Vector3.DOWN*25.0},
		{"label":"golden","hour":golden,"eye":middle-away*(r+90.0)+Vector3.UP*(water-middle.y+28.0),"look":middle+away*200.0+Vector3.DOWN*(middle.y-water),"chase":true},
	]
	for landform: String in ["forest","mountains"]:
		var lf: Dictionary = arch.forced_island(landform)
		if lf.is_empty():
			print("PROBE no %s island built" % landform)
			continue
		var at: Vector3 = arch.islets.place(lf)
		var lr: float = lf.shape.reach
		var to := Vector3(at.x-start.x,0.0,at.z-start.z).normalized()
		var across := Vector3(-to.z,0.0,to.x)
		var sea := water-at.y
		if landform == "forest":
			views.append({"label":"forest","hour":noon,"eye":at-to*(lr*0.6)+Vector3.UP*(sea+40.0),"look":at+to*(lr+150.0)+Vector3.UP*sea})
		else:
			views.append({"label":"mountains","hour":noon,"eye":at-to*(lr+80.0)+across*30.0+Vector3.UP*(sea+55.0),"look":at+Vector3.UP*(sea+20.0)})
	var info := RenderingServer.get_rendering_device() != null
	print("PROBE islands %d, uptime %s" % [arch.island_count(),_uptime()])
	print("PROBE view        prims(vis/shadow)        draws(vis/shadow)   objs(vis/shadow)  vram MB  frame ms  process ms")
	var first := true
	for v: Dictionary in views:
		if not only.is_empty() and v.label not in only: continue
		await _hold(v,240 if first else 120)
		first = false
		var m := await _measure(40)
		print("PROBE %-10s %9d (%8d/%8d) %6d (%5d/%5d) %6d (%5d/%5d) %7.0f %8.2f %8.2f" % [v.label,m.prims,m.prims_vis,m.prims_shadow,m.draws,m.draws_vis,m.draws_shadow,m.objects,m.objects_vis,m.objects_shadow,m.vram,m.frame,m.process])
		if shots != "":
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png(shots.path_join(v.label+".png"))
		if "--no-split" in OS.get_cmdline_user_args(): continue
		for kind: String in KINDS:
			var hidden := _nodes(kind)
			if hidden.is_empty(): continue
			for g: Node3D in hidden: g.visible = false
			var h := await _measure(4)
			for g: Node3D in hidden: g.visible = true
			if m.prims-h.prims < 1000 and m.draws-h.draws < 5: continue
			print("PROBE   %-10s %-11s prims %8d (shadow %8d) draws %5d (shadow %4d) nodes %d" % [v.label,kind,m.prims-h.prims,m.prims_shadow-h.prims_shadow,m.draws-h.draws,m.draws_shadow-h.draws_shadow,hidden.size()])
		await frames(4)
	print("PROBE done, uptime %s" % _uptime())
	quit(0)

func _uptime() -> String:
	var out := []
	OS.execute("uptime",[],out)
	return str(out[0]).strip_edges().get_slice("load averages:",1).strip_edges() if not out.is_empty() else "?"

## The counts over `count` frames, averaged.
func _measure(count: int) -> Dictionary:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var vp := root.get_viewport_rid()
	var sum := {"prims":0.0,"prims_vis":0.0,"prims_shadow":0.0,"draws":0.0,"draws_vis":0.0,"draws_shadow":0.0,
		"objects":0.0,"objects_vis":0.0,"objects_shadow":0.0,"vram":0.0,"process":0.0}
	var from := Time.get_ticks_usec()
	for i in range(count):
		await RenderingServer.frame_post_draw
		sum.prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		sum.draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sum.objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		sum.vram += Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0
		sum.process += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		for pair in [["vis",RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE],["shadow",RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW]]:
			sum["prims_"+pair[0]] += RenderingServer.viewport_get_render_info(vp,pair[1],RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			sum["draws_"+pair[0]] += RenderingServer.viewport_get_render_info(vp,pair[1],RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			sum["objects_"+pair[0]] += RenderingServer.viewport_get_render_info(vp,pair[1],RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	var out := {}
	for k in sum: out[k] = sum[k]/count
	out.frame = float(Time.get_ticks_usec()-from)/count/1000.0
	return out

## The visible nodes of a kind (see KINDS), to hide.
func _nodes(kind: String) -> Array:
	var out := []
	var lower: Node3D = eye.lower
	match kind:
		"ocean": out = [lower.ocean]
		"ceiling": out = [lower.ceiling]
		"air": out = [lower.air]
		"ranges":
			if lower.peaks != null: out = [lower.peaks]
		"clouds":
			if lower.cloud_volume != null: out = [lower.cloud_volume]
		"other":
			return []
		_:
			var roles: Dictionary = lower.archipelago.islets._catalog.get("roles",{})
			var named := {}
			for key: String in roles: named[key.replace(":","_")] = roles[key]
			for island: Node in lower.archipelago.islets.get_children():
				for child: Node in island.get_children():
					if not child is GeometryInstance3D or not (child as Node3D).visible: continue
					var n := String(child.name)
					var k := "isl_other"
					if n == "Body" or n == "BodyFar": k = "isl_top"
					elif n == "Sides": k = "isl_sides"
					elif n == "Pond": k = "isl_pond"
					elif n == "Massif": k = "isl_massif"
					elif n.begins_with("Far_"): k = "far_trees"
					elif child is MultiMeshInstance3D:
						var role: String = named.get(n,"plant")
						k = "trees" if role in ["tree","build"] else ("stones" if role == "stone" else "plants")
					if k == kind: out.append(child)
	return out.filter(func(n: Variant) -> bool: return n is Node3D and is_instance_valid(n) and (n as Node3D).visible)

func _hold(shot: Dictionary, count: int) -> void:
	var hour: float = shot.hour
	var at: Vector3 = shot.eye
	var look: Vector3 = shot.look
	var way := (look-at).normalized()
	var glide: RefCounted = eye.glide
	glide.position = at
	glide.heading = atan2(-way.x,-way.z)
	glide.pitch = asin(clampf(way.y,-1.0,1.0))*0.3
	glide.bank = 0.0
	glide.speed = 14.0
	glide.velocity = glide.forward()*14.0
	var chase: bool = shot.get("chase",false)
	eye.glider.visible = chase
	if chase:
		eye.chase.first_person = false
		eye.chase.reset(glide,at-way*8.0+Vector3.UP*2.5)
	for i in range(count):
		glide.position = at
		scene.world_clock.running = false
		scene.world_clock.set_time(scene.world_clock.day,hour)
		var delta := 1.0/60.0
		var view_eye := at
		var view_look := look
		if chase:
			eye.chase.step(delta,glide,0.0)
			eye.glider.update(delta,glide,0.0,eye._fly_ground,false)
			view_eye = eye.chase.eye
			view_look = eye.chase.look
		eye.sky.advance(delta,view_eye,eye.islands.in_cloud(view_eye,scene._motion_time))
		eye.islands.advance(delta,at,glide.heading,0.0)
		var o := view_eye-view_look
		scene.target = view_look
		scene.distance = maxf(o.length(),0.01)
		var dir: Vector3 = o/maxf(o.length(),0.01)
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.05,PI-0.05)
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		eye.camera.fov = 70.0 if chase else 64.0
		await process_frame
