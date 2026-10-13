extends SceneTree
## The generator's layer (studies/run_layer.tscn) measured rendered, at
## fixed camera spots worked out from its plan: the spawn, across the first
## gulf at the far neighbourhood, among the isles mid-layer, and from the
## gate at the next region's silhouette. First the streaming: every frame
## from the scene's start until the layer stands whole (wall frame time,
## its worst, how many ran past 33 and 50 ms), then per spot the means over
## --frames= frames of the wall frame time, the GPU's and the render
## thread's time for the main viewport, the process (scripts) and physics
## time, draw calls, primitives and objects drawn, as tab-separated BENCH
## lines; then a new layer asked for (N's way: planned on a worker and
## stood) and its frames measured as the first's. The pilot is ticked as in
## play (standing still); only the camera is held.
## Rendered only (needs a window); vsync off, uncapped:
##   Godot --windowed --path . --resolution 1920x1080 -s res://tools/bench_run_layer.gd \
##     -- --no-title --shape=sprawl --seed=2 [--out=/private/tmp/zs-bench]
## --caps=0,720,540:metalfx_temporal,... (each spot measured again at each
## cap, optionally with an upscaler, after the --cap one).
## --window=WxH (pixels, 1920x1080). --phase=P the time of day held (0.35).
## Options: --cap=LINES (the render resolution cap, scripts/
## render_resolution.gd; 0 native), --scaling=bilinear|fsr|fsr2|metalfx|
## metalfx_temporal (overrides the cap's upscaler), --frames=N (60),
## --only=spawn,gulf,... , --no-next (skip the second layer's streaming),
## --stills (a still of each spot into --out, <shape>-<seed>-<spot>.png),
## --parts=shadows,ssao,... (each view measured again without each part:
## shadows, ssao, glow, msaa, sea, clouds, fog, flora, next, life, sky_isles).
var scene: Node3D
var out := "/private/tmp/zs-bench"
var measure_frames := 60
var cap := -1
var scaling := ""
var only: Array = []
var stills := false
var do_next := true
var parts_wanted: Array = []
var census := false
var window := Vector2i(1920,1080)
var phase := 0.35
var caps: Array = []
var _modes := {"bilinear":Viewport.SCALING_3D_MODE_BILINEAR,"fsr":Viewport.SCALING_3D_MODE_FSR,"fsr2":Viewport.SCALING_3D_MODE_FSR2,
	"metalfx":Viewport.SCALING_3D_MODE_METALFX_SPATIAL,"metalfx_temporal":Viewport.SCALING_3D_MODE_METALFX_TEMPORAL}
var procs := false
var _timed: Array = []
var _proc_ms := {}
var _tick_ms := 0.0
var _viewport: RID
var _eye := Transform3D()
var _holding := false
var _tag := ""

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--frames="): measure_frames = int(argument.trim_prefix("--frames="))
		elif argument.begins_with("--cap="): cap = int(argument.trim_prefix("--cap="))
		elif argument.begins_with("--scaling="): scaling = argument.trim_prefix("--scaling=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument.begins_with("--parts="): parts_wanted = Array(argument.trim_prefix("--parts=").split(","))
		elif argument == "--stills": stills = true
		elif argument == "--no-next": do_next = false
		elif argument == "--census": census = true
		elif argument.begins_with("--phase="): phase = float(argument.trim_prefix("--phase="))
		elif argument.begins_with("--window="): window = Vector2i(int(argument.trim_prefix("--window=").get_slice("x",0)),int(argument.trim_prefix("--window=").get_slice("x",1)))
		elif argument.begins_with("--caps="): caps = Array(argument.trim_prefix("--caps=").split(","))
		elif argument == "--procs": procs = true
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("bench timed out"); quit(2))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# The window at a fixed size in pixels (a 1080p screen's by default).
	root.mode = Window.MODE_WINDOWED
	root.size = window
	_viewport = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport,true)
	process_frame.connect(_hold_eye)
	var began := Time.get_ticks_msec()
	scene = load("res://studies/run_layer.tscn").instantiate()
	scene.set_meta("no_title",true)
	preload("res://scripts/sky_commits.gd").recording = true
	var stream := _Frames.new()
	process_frame.connect(stream.tick)
	root.add_child(scene)
	current_scene = scene
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	while scene.layer.is_empty() or scene.stage == null or int(scene.layer_up_ms) < 0:
		await process_frame
	process_frame.disconnect(stream.tick)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var plan: Dictionary = scene.layer
	_tag = "%s-%d" % [preload("res://scripts/roguelike/layer_shapes.gd").shape_of(plan),int(plan.seed)]
	var RenderResolution = preload("res://scripts/render_resolution.gd")
	if cap >= 0: RenderResolution.apply(root,cap)
	if scaling != "": root.scaling_3d_mode = _modes[scaling]
	print("BENCH %s window %s, 3D scale %.3f mode %d, driver %s, adapter %s, kept cap %d, ready in %d ms" % [_tag,root.size,root.scaling_3d_scale,root.scaling_3d_mode,
		RenderingServer.get_current_rendering_driver_name(),RenderingServer.get_video_adapter_name(),RenderResolution.load_cap(),Time.get_ticks_msec()-began])
	_print_stream("stream-first",stream)
	# What else comes up after the isles (the next region, life, plants).
	await _frames(240)
	# The next region is laid on a worker once the layer stands (sprawl).
	for i in range(1200):
		if scene.layer.has("next"): break
		if not preload("res://scripts/roguelike/layer_shapes.gd").RUN.has(preload("res://scripts/roguelike/layer_shapes.gd").shape_of(scene.layer)): break
		await process_frame
	# The time of day held (the same light run to run).
	scene._celestial.cycling = false
	scene._celestial.phase = phase
	await _frames(30)
	plan = scene.layer
	if census: _census()
	print("BENCH\tlayer\tview\tpart\twall_median_ms\twall_mean_ms\tgpu_ms\tphysics_etc_ms\tprocess_ms\tdraw_ms\trender_cpu_ms\tdraws\tprimitives\tobjects")
	_holding = true
	for view: Dictionary in _views(plan):
		if not only.is_empty() and view.label not in only: continue
		_eye = Transform3D(Basis.looking_at((view.look as Vector3)-(view.eye as Vector3)),view.eye)
		await _frames(45)
		var whole := await _measure(Callable())
		_print(view.label,"whole",whole)
		for other: String in caps:
			# The same spot at other render resolutions / upscalers: cap[:mode].
			var c := int(other.get_slice(":",0))
			RenderResolution.apply(root,c)
			if other.contains(":"): root.scaling_3d_mode = _modes[other.get_slice(":",1)]
			await _frames(20)
			_print(view.label,"cap%s(%.2f)" % [other,root.scaling_3d_scale],await _measure(Callable()))
		if not caps.is_empty():
			if cap >= 0: RenderResolution.apply(root,cap)
			if scaling != "": root.scaling_3d_mode = _modes[scaling]
			await _frames(20)
		if stills:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("%s-%s.png" % [_tag,view.label]))
		for part: Array in _parts():
			if not parts_wanted.is_empty() and part[0] not in parts_wanted: continue
			var without := await _measure(part[1])
			part[2].call()
			await _frames(8)
			_print(view.label,"-"+str(part[0]),without,whole)
	if procs:
		_eye = Transform3D(Basis.looking_at((_views(plan)[0].look as Vector3)-(_views(plan)[0].eye as Vector3)),_views(plan)[0].eye)
		await _profile_procs()
	_holding = false
	if do_next:
		var next_frames := _Frames.new()
		process_frame.connect(next_frames.tick)
		var was: int = int(scene.layers)
		scene.request_layer(int(plan.seed)+1,"",str(plan.get("shape","")))
		while int(scene.layers) == was or int(scene.layer_up_ms) < 0: await process_frame
		process_frame.disconnect(next_frames.tick)
		_print_stream("stream-next",next_frames)
	print("BENCH done")
	quit(0)

## The camera held at the spot, before the scene's frame (so its look, sea
## and fog follow it); the pilot ticked as in play, standing.
func _hold_eye() -> void:
	if not _holding or scene == null: return
	scene.scripted = true
	var t0 := Time.get_ticks_usec()
	scene.tick(1.0/60.0)
	_tick_ms += (Time.get_ticks_usec()-t0)/1000.0
	(scene.camera as Camera3D).global_transform = _eye
	for node: Node in _timed:
		if not is_instance_valid(node): continue
		var t := Time.get_ticks_usec()
		if node == scene.sky.motifs:
			# Its parts: each isle's advance by motif, the rest after.
			for isle: Node3D in node.isles:
				if isle.life != null and isle.is_up(): _life_parts(isle.life,(isle.motif.get_script() as Script).resource_path.get_file().get_basename())
				var ti := Time.get_ticks_usec()
				isle.advance(1.0/60.0,(scene.camera as Camera3D).global_position)
				var k: String = "  isle " + (isle.motif.get_script() as Script).resource_path.get_file()
				_proc_ms[k] = float(_proc_ms.get(k,0.0))+(Time.get_ticks_usec()-ti)/1000.0
		elif node == scene:
			if scene.life != null: _life_parts(scene.life,"base")
			for part: Array in [["  _advance_look",func() -> void: scene._advance_look(1.0/60.0)],["  life.advance",func() -> void: if scene.life != null: scene.life.advance(1.0/60.0)],
					["  _lode_frame",func() -> void: scene._lode_frame(1.0/60.0)],["  _update_card",func() -> void: scene._update_card()],
					["  all_stood",func() -> void: scene.sky.motifs.all_stood()]]:
				var ti := Time.get_ticks_usec()
				part[1].call()
				_proc_ms[part[0]] = float(_proc_ms.get(part[0],0.0))+(Time.get_ticks_usec()-ti)/1000.0
			t = Time.get_ticks_usec()
		node._process(1.0/60.0)
		var key: String = node.get_script().resource_path.get_file() if node.get_script() != null else node.get_class()
		_proc_ms[key] = float(_proc_ms.get(key,0.0))+(Time.get_ticks_usec()-t)/1000.0

func _frames(count: int) -> void:
	for i in range(count): await process_frame

## The spots, from the plan: [label, eye, look].
func _views(plan: Dictionary) -> Array:
	const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
	var mids: Array = []
	for isle: Dictionary in plan.isles:
		var c := LayerPlan._rect(isle).get_center()
		mids.append(Vector3(c.x,LayerPlan._span(isle).y,c.y))
	var hood_mid := func(h: int) -> Vector3:
		var sum := Vector3.ZERO
		for i: int in plan.hoods[h]: sum += mids[i]
		return sum/maxf((plan.hoods[h] as Array).size(),1.0)
	var flat := func(v: Vector3) -> Vector3: return Vector3(v.x,0.0,v.z).normalized()
	var views: Array = []
	var spawn: Vector3 = plan.spawn.at
	var face: Vector3 = plan.spawn.face
	views.append({"label":"spawn","eye":spawn-face*5.0+Vector3.UP*2.8,"look":spawn+face*40.0+Vector3.UP*2.0})
	var hoods: Array = plan.hoods
	if hoods.size() >= 2:
		var far: Vector3 = hood_mid.call(hoods.size()-1)
		# From the first neighbourhood's isle nearest the far one, at its rim.
		var best := -1
		for i: int in hoods[0]:
			if best < 0 or (mids[i] as Vector3).distance_to(far) < (mids[best] as Vector3).distance_to(far): best = i
		var from: Vector3 = mids[best]
		var r := LayerPlan._rect(plan.isles[best]).size.length()*0.3
		var eye: Vector3 = from+flat.call(far-from)*r+Vector3.UP*4.0
		views.append({"label":"gulf","eye":eye,"look":far})
		var mid: Vector3 = hood_mid.call(1 if hoods.size() > 2 else 0).lerp(far,0.5)
		var back: Vector3 = hood_mid.call(0)
		views.append({"label":"mid","eye":mid+Vector3.UP*12.0,"look":back+Vector3.UP*-10.0})
	var next: Variant = plan.get("next")
	if next is Dictionary and not (plan.exit as Dictionary).is_empty():
		var aim: Vector3 = plan.get("next_aim",((next as Dictionary).xform as Transform3D).origin)
		var gate: Vector3 = plan.exit.at
		views.append({"label":"next","eye":gate-flat.call(aim-gate)*6.0+Vector3.UP*3.0,"look":aim})
	return views

## A kit life's parts timed (scripts/kit_isle/kit_life.gd `advance`).
func _life_parts(life: Object, who: String) -> void:
	var atmosphere: Node = scene._atmosphere
	var d := 1.0/60.0
	var parts: Array = [["flies",func() -> void:
		for m: Node3D in life.meadows: m.flies.advance(d)],
		["leaf_litter",func() -> void: if life.leaf_litter != null: life.leaf_litter.advance(d,false,atmosphere)],
		["grass_chaff",func() -> void: if life.grass_chaff != null: life.grass_chaff.advance(d,false,atmosphere)],
		["kicked_blades",func() -> void: if life.kicked_blades != null: life.kicked_blades.advance(d,false,atmosphere.wind_trails,atmosphere)],
		["birds",func() -> void: if life.birds != null: life.birds.advance(d)]]
	for part: Array in parts:
		var t := Time.get_ticks_usec()
		part[1].call()
		var k := "    life %s %s" % [who,part[0]]
		_proc_ms[k] = float(_proc_ms.get(k,0.0))+(Time.get_ticks_usec()-t)/1000.0

## Every node's _process timed by hand (each stopped and called from here
## in the frame's start, the scene's own too), over 120 frames.
func _profile_procs() -> void:
	_timed = []
	for node: Node in [scene]+scene.find_children("*","",true,false):
		if node.is_processing() and node.get_script() != null and node.has_method("_process"):
			node.set_process(false)
			_timed.append(node)
	_proc_ms = {}
	_tick_ms = 0.0
	var counts := {}
	for node: Node in _timed:
		var key: String = node.get_script().resource_path.get_file()
		counts[key] = int(counts.get(key,0))+1
	await _frames(120)
	for node: Node in _timed: if is_instance_valid(node): node.set_process(true)
	_timed = []
	var keys := _proc_ms.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _proc_ms[a] > _proc_ms[b])
	print("PROCS tick (pilot, stage) %.3f ms a frame" % (_tick_ms/120.0))
	for k: String in keys.slice(0,40): print("PROCS\t%s\t%d nodes\t%.3f ms a frame" % [k,counts.get(k,0),_proc_ms[k]/120.0])

## Every drawn mesh in the scene, grouped: by its place in the tree (the
## sky's isles by isle) and by node name, triangles (instances counted),
## nodes, shadow casters, ones with a visibility range, with mesh LODs.
func _census() -> void:
	var by_place := {}
	var by_name := {}
	var totals := {"tris":0,"nodes":0,"shadow":0,"ranged":0,"lods":0,"mm_instances":0}
	for node: Node in scene.find_children("*","GeometryInstance3D",true,false):
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree(): continue
		var mesh: Mesh = null
		var count := 1
		if g is MeshInstance3D: mesh = (g as MeshInstance3D).mesh
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			var mm := (g as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			count = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			totals.mm_instances += count
		if mesh == null: continue
		var tris := 0
		var lods := false
		for s in range(mesh.get_surface_count()):
			var info: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(),s)
			var n: int = info.get("index_count",0)
			tris += (n if n > 0 else int(info.get("vertex_count",0)))/3
			if not (info.get("lods",[]) as Array).is_empty(): lods = true
		tris *= count
		var path := str(scene.get_path_to(g)).split("/")
		var place := "/".join(path.slice(0,mini(3,path.size()-1)))
		var name := str(g.name).rstrip("0123456789@").get_slice("@",0)
		var shadow := g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for pair: Array in [[by_place,place],[by_name,"%s:%s" % [g.get_class(),name]]]:
			var d: Dictionary = pair[0]
			if not d.has(pair[1]): d[pair[1]] = {"tris":0,"nodes":0,"shadow":0,"ranged":0,"lods":0}
			var e: Dictionary = d[pair[1]]
			e.tris += tris
			e.nodes += 1
			e.shadow += 1 if shadow else 0
			e.ranged += 1 if g.visibility_range_end > 0.0 else 0
			e.lods += 1 if lods else 0
		totals.tris += tris
		totals.nodes += 1
		totals.shadow += 1 if shadow else 0
		totals.ranged += 1 if g.visibility_range_end > 0.0 else 0
		totals.lods += 1 if lods else 0
	print("CENSUS total %s" % totals)
	for d: Dictionary in [by_place,by_name]:
		var keys := d.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return d[a].tris > d[b].tris)
		for k in range(mini(40,keys.size())): print("CENSUS tris\t%s\t%s" % [keys[k],d[keys[k]]])
		keys.sort_custom(func(a: String, b: String) -> bool: return d[a].nodes > d[b].nodes)
		for k in range(mini(25,keys.size())): print("CENSUS nodes\t%s\t%s" % [keys[k],d[keys[k]]])

## Parts taken away to price them: [name, take away, put back].
func _parts() -> Array:
	var env: Environment = scene._environment
	var parts: Array = []
	var lights: Array = scene.find_children("*","DirectionalLight3D",true,false).filter(func(l: Light3D) -> bool: return l.shadow_enabled)
	parts.append(["shadows",func() -> void:
		for l: Light3D in lights: l.shadow_enabled = false,func() -> void:
		for l: Light3D in lights: l.shadow_enabled = true])
	parts.append(["ssao",func() -> void: env.ssao_enabled = false,func() -> void: env.ssao_enabled = true])
	parts.append(["glow",func() -> void: env.glow_enabled = false,func() -> void: env.glow_enabled = true])
	var msaa := root.msaa_3d
	parts.append(["msaa",func() -> void: root.msaa_3d = Viewport.MSAA_DISABLED,func() -> void: root.msaa_3d = msaa])
	var look: Variant = scene.get("_look")
	if look != null and look.get("sea") != null:
		var sea: Node3D = look.sea
		parts.append(["sea",func() -> void: sea.visible = false,func() -> void: sea.visible = true])
	var fog: Variant = scene.get("_display_fog")
	if fog is CanvasLayer:
		parts.append(["fog",func() -> void: (fog as CanvasLayer).visible = false,func() -> void: (fog as CanvasLayer).visible = true])
	var sky: Node3D = scene.sky
	if sky != null and sky.get("clouds") is Node3D:
		var clouds: Node3D = sky.clouds
		parts.append(["clouds",func() -> void: clouds.visible = false,func() -> void: clouds.visible = true])
	if sky != null and sky.get("motifs") is Node3D:
		parts.append(["sky_isles",func() -> void: sky.motifs.visible = false,func() -> void: sky.motifs.visible = true])
	var flora: Array = scene.find_children("*","MultiMeshInstance3D",true,false)
	parts.append(["multimesh",func() -> void:
		for f: Node3D in flora: f.visible = false,func() -> void:
		for f: Node3D in flora: if is_instance_valid(f): f.visible = true])
	var next: Array = scene.find_children("NextRegion","MeshInstance3D",true,false)
	if not next.is_empty():
		parts.append(["next",func() -> void: next[0].visible = false,func() -> void: next[0].visible = true])
	if scene.get("life") is Node3D:
		var life: Node3D = scene.life
		parts.append(["life",func() -> void: life.visible = false,func() -> void: life.visible = true])
	# The kit's stone (every ruin piece's "Mesh"), drawn and as shadow casters.
	var kit: Array = scene.find_children("Mesh","MeshInstance3D",true,false)
	parts.append(["kit",func() -> void:
		for m: Node3D in kit: if is_instance_valid(m): m.visible = false,func() -> void:
		for m: Node3D in kit: if is_instance_valid(m): m.visible = true])
	parts.append(["kit_shadows",func() -> void:
		for m: GeometryInstance3D in kit: if is_instance_valid(m): m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,func() -> void:
		for m: GeometryInstance3D in kit: if is_instance_valid(m): m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON])
	# The stone alone and the growth alone (scripts/ruin_growth.gd: its own
	# surface on the kit's meshes): each mesh swapped for one of the other
	# surface only.
	if "growth" in parts_wanted or "stone" in parts_wanted:
		var swaps := {"growth":[],"stone":[]}
		var growth_material: Material = preload("res://scripts/ruin_growth.gd").material()
		for m: MeshInstance3D in kit:
			if m.mesh == null or m.mesh.get_surface_count() < 2: continue
			var keep_stone := ArrayMesh.new()
			var keep_growth := ArrayMesh.new()
			for i in range(m.mesh.get_surface_count()):
				var into := keep_growth if m.mesh.surface_get_material(i) == growth_material else keep_stone
				into.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,m.mesh.surface_get_arrays(i),[],{},preload("res://scripts/ruin_growth.gd").FORMAT if into == keep_growth else 0)
				into.surface_set_material(into.get_surface_count()-1,m.mesh.surface_get_material(i))
			swaps.growth.append([m,m.mesh,keep_stone])
			swaps.stone.append([m,m.mesh,keep_growth])
		for key: String in swaps:
			var list: Array = swaps[key]
			parts.append([key,func() -> void:
				for e: Array in list: if is_instance_valid(e[0]) and e[0].mesh != e[2]: e[0].mesh = e[2],func() -> void:
				for e: Array in list: if is_instance_valid(e[0]): e[0].mesh = e[1]])
	var grass: Array = flora.filter(func(f: Node) -> bool: return str(f.name).begins_with("grass"))
	parts.append(["grass",func() -> void:
		for f: Node3D in grass: if is_instance_valid(f): f.visible = false,func() -> void:
		for f: Node3D in grass: if is_instance_valid(f): f.visible = true])
	var lod := root.mesh_lod_threshold
	parts.append(["lod_off",func() -> void: root.mesh_lod_threshold = 0.0,func() -> void: root.mesh_lod_threshold = lod])
	parts.append(["lod_x4",func() -> void: root.mesh_lod_threshold = lod*4.0,func() -> void: root.mesh_lod_threshold = lod])
	parts.append(["all_3d",func() -> void: RenderingServer.viewport_set_disable_3d(_viewport,true),func() -> void: RenderingServer.viewport_set_disable_3d(_viewport,false)])
	return parts

## Per frame: wall (post_draw to post_draw), the main thread's phases
## (physics and the rest before the scene's process: post_draw to
## process_frame; process: to pre_draw; the render thread's submit and any
## wait on the GPU: pre_draw to post_draw), GPU time when the driver gives it.
func _measure(take_away: Callable) -> Dictionary:
	if take_away.is_valid():
		take_away.call()
		RenderingServer.frame_pre_draw.connect(take_away)
	for i in range(30): await RenderingServer.frame_post_draw
	var marks := {"process":0,"pre":0}
	var on_process := func() -> void: marks.process = Time.get_ticks_usec()
	var on_pre := func() -> void: marks.pre = Time.get_ticks_usec()
	process_frame.connect(on_process)
	RenderingServer.frame_pre_draw.connect(on_pre)
	var walls: Array = []
	var sum := {"gpu":0.0,"cpu":0.0,"before":0.0,"process":0.0,"draw":0.0,"physics":0.0,"draws":0.0,"primitives":0.0,"objects":0.0}
	await RenderingServer.frame_post_draw
	var last := Time.get_ticks_usec()
	for i in range(measure_frames):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		walls.append((now-last)/1000.0)
		sum.before += (marks.process-last)/1000.0
		sum.process += (marks.pre-marks.process)/1000.0
		sum.draw += (now-marks.pre)/1000.0
		last = now
		sum.gpu += RenderingServer.viewport_get_measured_render_time_gpu(_viewport)
		sum.cpu += RenderingServer.viewport_get_measured_render_time_cpu(_viewport)
		sum.physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		sum.draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		sum.primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		sum.objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	process_frame.disconnect(on_process)
	RenderingServer.frame_pre_draw.disconnect(on_pre)
	if take_away.is_valid(): RenderingServer.frame_pre_draw.disconnect(take_away)
	for key: String in sum: sum[key] /= measure_frames
	walls.sort()
	sum.wall = walls[walls.size()/2]
	sum.mean = walls.reduce(func(a: float, b: float) -> float: return a+b,0.0)/walls.size()
	return sum

func _print(view: String, part: String, m: Dictionary, whole := {}) -> void:
	var line := "BENCH\t%s\t%s\t%s\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%d\t%d\t%d" % [_tag,view,part,m.wall,m.mean,m.gpu,m.before,m.process,m.draw,m.cpu,m.draws,m.primitives,m.objects]
	if not whole.is_empty(): line += "\tsaves wall %.2f process %.2f draw %.2f" % [whole.wall-m.wall,whole.process-m.process,whole.draw-m.draw]
	print(line)

func _print_stream(label: String, f: _Frames) -> void:
	var sorted := f.times.duplicate()
	sorted.sort()
	var p99: float = sorted[int(sorted.size()*0.99)] if not sorted.is_empty() else 0.0
	var median: float = sorted[sorted.size()/2] if not sorted.is_empty() else 0.0
	var worst := PackedStringArray()
	var order := range(f.times.size())
	order.sort_custom(func(a: int, b: int) -> bool: return f.times[a] > f.times[b])
	for k in range(mini(8,order.size())): worst.append("%.0f@%d" % [f.times[order[k]],order[k]])
	print("BENCH %s %s: %d frames over %.1f s, median %.1f ms, p99 %.1f ms, worst %s; >33 ms %d, >50 ms %d, >100 ms %d" % [_tag if _tag != "" else "?",label,f.times.size(),f.total/1000.0,median,p99,
		", ".join(worst),f.over(33.0),f.over(50.0),f.over(100.0)])
	# What the sky's budget spent in the worst frames (scripts/sky_commits.gd).
	var log: Array = preload("res://scripts/sky_commits.gd").log
	for k in range(mini(12,order.size())):
		var fr: int = f.frames[order[k]]
		var spent := PackedStringArray()
		for e: Array in log:
			if int(e[0]) == fr-1 or int(e[0]) == fr: spent.append("%s %.1fms" % [e[1],int(e[2])/1000.0])
		print("BENCH   worst %.0f ms (frame %d): %s" % [f.times[order[k]],fr,"; ".join(spent) if not spent.is_empty() else "(no sky commit)"])
	log.clear()

## Wall time between frames.
class _Frames:
	var times: Array = []
	var frames: Array = []
	var total := 0.0
	var _last := -1
	func tick() -> void:
		var now := Time.get_ticks_usec()
		if _last >= 0:
			var ms := (now-_last)/1000.0
			times.append(ms)
			frames.append(Engine.get_process_frames())
			total += ms
		_last = now
	func over(ms: float) -> int:
		return times.filter(func(t: float) -> bool: return t > ms).size()
