extends SceneTree
## A played session with every frame timed (2026-09-30 performance audit):
## the cozy worlds scene driven by synthesized input through hand_reach, as a
## player would. Orbit; pinch two peaks and draw a groove with the Modeller;
## spring three ranges off the rim and keep them; drop water on the peaks and
## let it run into falls; sow seeds from the tray and watch them grow; orbit
## the finished world. Each frame records its wall interval and what was busy:
## the refresh stage, the handful's and the water's own timers, land life,
## object and instance counts, and the terrain's height cache (whose clears
## throw away the face probes).
##   godot --headless --path . -s res://tools/profile_play_session.gd -- --modeless --no-title [--out /tmp/zs-play.json]
## Rendered (a window opens; input goes in window pixels, 2x on Retina):
##   godot --windowed --resolution 1440x900 --path . -s res://tools/profile_play_session.gd -- --modeless --no-title
## `--smoke` stops after the pinched peaks, to check gestures land first.
## Headless, intervals are CPU main-loop time under the dummy renderer: GPU
## passes (fog, sky, shadows, reflections) are not in them. Frames are capped
## at 120 fps by the project, so 8.3 ms is idle.

var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var materials: Node
var spring: Node
var flip: Node
var phase := "load"
var output := "/tmp/zs-play-session.json"
var records: Array[Dictionary] = []
var events: Array[String] = []
var _previous := 0
var tracking := "--track-shaders" in OS.get_cmdline_user_args()
var recording := "--record-manifest" in OS.get_cmdline_user_args()
const Manifest = preload("res://scripts/pipeline_manifest.gd")
var _manifest := {}
var _stored := {}

## Every surface the main view draws, as pipeline entries (--record-manifest).
func _record() -> void:
	var world := root.find_world_3d()
	for node: Node in root.find_children("*","GeometryInstance3D",true,false):
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree() or g.get_world_3d() != world: continue
		if scene.get_node_or_null("PipelineWarmup") != null and scene.get_node("PipelineWarmup").is_ancestor_of(g): continue
		for entry: Dictionary in Manifest.describe(g,_store):
			var key := JSON.stringify(entry,"",true)
			if not _manifest.has(key): _manifest[key] = entry

func _store(material: Material) -> String:
	var stored: Array = Manifest.storable(material)
	var name: String = stored[1]+".tres"
	if not _stored.has(name):
		DirAccess.make_dir_recursive_absolute(Manifest.DIR.path_join("materials"))
		var error := ResourceSaver.save(stored[0],Manifest.DIR.path_join("materials").path_join(name))
		if error != OK:
			push_error("could not store %s: %s" % [name,error])
			return ""
		_stored[name] = true
	return name

func _write_manifest() -> void:
	DirAccess.make_dir_recursive_absolute(Manifest.DIR)
	var entries: Array = _manifest.values()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return JSON.stringify(a,"",true) < JSON.stringify(b,"",true))
	var file := FileAccess.open(Manifest.DIR.path_join(Manifest.FILE),FileAccess.WRITE)
	file.store_string(JSON.stringify(entries,"\t",true))
	print("PLAY manifest: %d entries, %d stored materials -> %s" % [entries.size(),_stored.size(),Manifest.DIR])
var _cache_size := 0
var _cache_clears := 0
var _last_inst := ""
var _life_worst := {}
var _inst_log: Array = []
var _stage_seen := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--out")
	if at >= 0 and at+1 < args.size(): output = args[at+1]
	# Measured at 120 fps whatever the platform ships (the Mac caps at 60), so
	# runs compare and a frame over 16.7 ms still reads as a hitch.
	# --keep-fps-cap measures the shipped cap instead.
	if not "--keep-fps-cap" in args: Engine.max_fps = 120
	run.call_deferred()

# --- Recording -------------------------------------------------------------------

func prop(object: Object, property: String, fallback: Variant = null) -> Variant:
	if object == null or not is_instance_valid(object): return fallback
	var value: Variant = object.get(property)
	return fallback if value == null else value

## One frame: its interval and what each suspect was doing in it.
func _sample() -> void:
	var now := Time.get_ticks_usec()
	var ms := float(now-_previous)/1000.0 if _previous > 0 else 0.0
	_previous = now
	if editor == null: return
	var data := editor.data
	var cache: int = data._locate_cache.size()
	var cleared := cache < _cache_size
	if cleared: _cache_clears += 1
	_cache_size = cache
	var handful: Object = editor.get("handful")
	var motes := 0
	if handful != null:
		for cloud: Dictionary in handful.clouds: motes += (cloud.get("motes",[]) as Array).size()
	var flow: Object = editor.flow
	var view: Object = editor.flow_view
	var life: Object = scene.get("land_life")
	var content: Object = editor.content
	var instances := 0
	for batch: Variant in prop(content,"_batches",[]):
		if batch is MultiMeshInstance3D and (batch as MultiMeshInstance3D).multimesh != null:
			instances += (batch as MultiMeshInstance3D).multimesh.instance_count
	var parts: Dictionary = prop(life,"survey_parts",{})
	for k: String in parts: _life_worst[k] = maxi(int(_life_worst.get(k,0)),int(parts[k]))
	var inst: Dictionary = prop(content,"last_instance_usec",{})
	if inst.has("swap") and str(inst) != _last_inst:
		_last_inst = str(inst)
		_inst_log.append([phase,inst.duplicate()])
	var refl: Object = prop(view,"reflection")
	records.append({
		"refl_us":prop(refl,"last_sync_usec",0),"refl_busy":prop(refl,"_setup_busy",false),
		"landmarks_us":int(editor.last_refresh_usec.get("landmarks_elapsed",0)),
		"phase":phase,"ms":ms,
		"stage":_stage_seen,"pending":editor.refresh_pending,
		"handful_us":prop(handful,"last_usec",0),"motes":motes,
		"flow_us":prop(flow,"last_step_usec",0),
		"flow_build_us":prop(view,"last_build_usec",0),
		"life_us":prop(life,"last_usec",0),
		"emerge_us":prop(editor,"last_emergence_usec",0),
		"objects":data.objects.size(),"instances":instances,
		"cache":cache,"cache_cleared":cleared,
		"compiles":_compiles(),"compile_kinds":_last_kinds,
		"draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"prims":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
		"vram_mb":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)/1048576.0,
	})
	if tracking: _track_shaders()
	if recording and scene != null: _record()
	# The stage a frame ends in is the one its work ran under next frame.
	_stage_seen = editor.refresh_stage if editor.refresh_pending > 0 else ""

## Pipeline compiles since the last frame, all kinds (a new shader, surface
## or specialisation the GPU had not built yet stalls the frame that needs it).
var _compiled := 0
var _compiled_kinds := {}
var _last_kinds := ""
const COMPILE_KINDS := {"canvas":RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,"mesh":RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,"surface":RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,"draw":RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,"spec":RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION}
func _compiles() -> int:
	var total := 0
	var kinds: Array[String] = []
	for kind: String in COMPILE_KINDS:
		var n: int = RenderingServer.get_rendering_info(COMPILE_KINDS[kind])
		if n > int(_compiled_kinds.get(kind,0)): kinds.append("%s+%d" % [kind,n-int(_compiled_kinds.get(kind,0))])
		_compiled_kinds[kind] = n
		total += n
	_last_kinds = " ".join(kinds)
	var fresh := total-_compiled
	_compiled = total
	return fresh

## First sightings of each shader on a visible geometry node (--track-shaders):
## frame index -> names, so a freeze can name what first drew near it.
var _shaders_seen := {}
var _nodes_seen := {}
static func _format(mesh: Mesh, surface: int) -> int:
	if mesh is ArrayMesh: return (mesh as ArrayMesh).surface_get_format(surface)
	return int(RenderingServer.mesh_get_surface(mesh.get_rid(),surface).get("format",-1))

## Combos present before play count as seen.
func _seed_combos(g: GeometryInstance3D) -> void:
	var mesh: Mesh = null
	var m: Material = g.material_override
	if g is MeshInstance3D: mesh = (g as MeshInstance3D).mesh
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null: mesh = (g as MultiMeshInstance3D).multimesh.mesh
	elif g is GPUParticles3D: mesh = (g as GPUParticles3D).draw_pass_1
	if mesh == null: return
	for i in range(mesh.get_surface_count()):
		var mat: Material = m if m != null else mesh.surface_get_material(i)
		var shader_key: Variant = (mat as ShaderMaterial).shader.get_rid() if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null else (mat.get_class() if mat != null else "none")
		_nodes_seen["%s|%s|%s|%s" % [shader_key,_format(mesh,i),g.get_class(),g.cast_shadow]] = true
var _first_seen := {}
func _track_shaders() -> void:
	var fresh: Array[String] = []
	for node: Node in root.find_children("*","GeometryInstance3D",true,false):
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree(): continue
		if phase == "load" or phase == "warm":
			_seed_combos(g)
		if phase != "load" and phase != "warm":
			var pairs: Array = []
			if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
				var mi := g as MeshInstance3D
				for i in range(mi.mesh.get_surface_count()):
					var m: Material = mi.material_override if mi.material_override != null else (mi.get_surface_override_material(i) if mi.get_surface_override_material(i) != null else mi.mesh.surface_get_material(i))
					pairs.append([mi.mesh,m,i])
			elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null and (g as MultiMeshInstance3D).multimesh.mesh != null:
				var mm := (g as MultiMeshInstance3D).multimesh
				for i in range(mm.mesh.get_surface_count()):
					pairs.append([mm.mesh,g.material_override if g.material_override != null else mm.mesh.surface_get_material(i),i])
			elif g is GPUParticles3D and (g as GPUParticles3D).draw_pass_1 != null:
				var dp := (g as GPUParticles3D).draw_pass_1
				pairs.append([dp,g.material_override if g.material_override != null else dp.surface_get_material(0),0])
			for pair: Array in pairs:
				var mesh: Mesh = pair[0]
				var m: Material = pair[1]
				var shader_key: Variant = (m as ShaderMaterial).shader.get_rid() if m is ShaderMaterial and (m as ShaderMaterial).shader != null else (m.get_class() if m != null else "none")
				var combo := "%s|%s|%s|%s" % [shader_key,_format(mesh,pair[2]),g.get_class(),g.cast_shadow]
				if _nodes_seen.has(combo): continue
				_nodes_seen[combo] = true
				var shader_name := "-"
				if m is ShaderMaterial and (m as ShaderMaterial).shader != null: shader_name = (m as ShaderMaterial).shader.resource_path if not (m as ShaderMaterial).shader.resource_path.is_empty() else "inline"
				elif m != null: shader_name = m.get_class()
				fresh.append("COMBO %s [%s, %s, %s fmt %d, shadow %d]" % [str(g.get_path()).trim_prefix("/root/ZenScapeCozyWorlds/"),g.get_class(),shader_name,mesh.get_class(),_format(mesh,pair[2]),g.cast_shadow])
		var mats: Array[Material] = []
		if g.material_override != null: mats.append(g.material_override)
		var mesh: Mesh = null
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
			for i in range((g as MeshInstance3D).get_surface_override_material_count()):
				var m := (g as MeshInstance3D).get_surface_override_material(i)
				if m != null: mats.append(m)
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
		if mesh != null:
			for i in range(mesh.get_surface_count()):
				var m := mesh.surface_get_material(i)
				if m != null: mats.append(m)
		for m: Material in mats:
			var key: Variant
			var label: String
			if m is ShaderMaterial:
				var shader := (m as ShaderMaterial).shader
				if shader == null: continue
				key = shader.get_rid()
				label = shader.resource_path if not shader.resource_path.is_empty() else "inline shader %s" % shader.get_rid()
			else:
				key = m.get_class()+str(m.get_rid())
				label = "%s %s" % [m.get_class(),m.resource_path]
			if not _shaders_seen.has(key):
				_shaders_seen[key] = true
				fresh.append("%s  <- %s" % [label,g.get_path()])
	if not fresh.is_empty(): _first_seen[records.size()] = fresh

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		_sample()

## Wall seconds: the game runs at its own frame rate, so waits are timed.
func seconds(value: float) -> void:
	var until := Time.get_ticks_msec()+int(value*1000.0)
	while Time.get_ticks_msec() < until: await frames(1)

func mark(label: String) -> void:
	if editor != null: print("PLAY   state before %s: %s" % [label,_state()])
	phase = label
	events.append("%.2f s  %s" % [Time.get_ticks_msec()/1000.0,label])
	print("PLAY ",label)

## What the world holds, to confirm each verb did something.
func _state() -> String:
	var data := editor.data
	var top := -INF
	for h in data.heights: top = maxf(top,h)
	var flow: Object = editor.flow
	var volume: float = flow.volume() if flow != null and prop(flow,"ready",false) else 0.0
	var falls := 0
	var view: Object = editor.flow_view
	var edge: Object = prop(view,"edge_falls")
	if edge != null: falls = edge.shown_count()
	return "top %.2f m, sum %.0f, undo %d, springs %s, water %.1f m3, edge falls %d, objects %d, held %s" % [top,Array(data.heights).reduce(func(a,b): return a+b,0.0),data._undo.size(),str(prop(spring,"last_range",{}).get("peaks",[]).size()),volume,falls,data.objects.size(),prop(materials,"held","")]

# --- Input, as the probes drive it ------------------------------------------------

var pointer := Vector2(720,120)

func button(at: Vector2, pressed: bool) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = window(at)
	event.global_position = window(at)
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func move(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = window(at)
	event.global_position = window(at)
	event.relative = window(at)-window(pointer)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	point(at)
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## Viewport units to the window pixels Input expects (2x on a Retina window;
## identity headless).
func window(at: Vector2) -> Vector2:
	return root.get_final_transform()*at

func point(at: Vector2) -> void:
	pointer = at
	reach.pointer_override = at
	editor.pointer_override = at

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap_key(code: Key) -> void:
	key(code,true)
	await frames(1)
	key(code,false)
	await frames(1)

func glide(to: Vector2, count: int, held := false) -> void:
	var from := pointer
	for i in range(count):
		move(from.lerp(to,smoothstep(0.0,1.0,float(i+1)/count)),held)
		await frames(1)

func click(at: Vector2) -> void:
	await glide(at,10)
	button(at,true)
	await frames(2)
	button(at,false)
	await frames(2)

func height(p: Vector2) -> float:
	var h: Variant = editor.data.ground_height(p)
	return float(h) if h != null else 0.0

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

## Orbit by dragging, the way the camera input hears it.
func orbit(secs: float, speed: float) -> void:
	var until := Time.get_ticks_msec()+int(secs*1000.0)
	while Time.get_ticks_msec() < until:
		scene._orbiting = true
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-speed,0)
		scene._input(motion)
		await frames(1)
	scene._orbiting = false

# --- Verbs ------------------------------------------------------------------------

## The Modeller's pinch: press, hold a beat, pull the screen by `pixels`.
func pinch(p: Vector2, pixels: float) -> void:
	await glide(screen(p),20)
	button(pointer,true)
	await seconds(0.5)
	var from := pointer
	for i in range(60):
		move(from+Vector2(0,pixels*smoothstep(0.0,1.0,float(i+1)/60)),true)
		await frames(1)
	await seconds(0.3)
	button(pointer,false)
	await frames(1)

## A slow drag along plate points: the Modeller's groove.
func stroke(path: Array, secs_per_leg: float) -> void:
	var points: Array[Vector2] = []
	for p: Vector2 in path: points.append(screen(p))
	await glide(points[0],20)
	button(pointer,true)
	await frames(3)
	for i in range(points.size()-1):
		var until := Time.get_ticks_msec()+int(secs_per_leg*1000.0)
		var began := Time.get_ticks_msec()
		while Time.get_ticks_msec() < until:
			var t := float(Time.get_ticks_msec()-began)/(secs_per_leg*1000.0)
			move(points[i].lerp(points[i+1],clampf(t,0.0,1.0)),true)
			await frames(1)
	button(pointer,false)
	await frames(1)

func lip_point() -> Vector2:
	var best := Vector2.ZERO
	for side in range(4):
		for i in range(7):
			var f := -6.0+12.0*i/6.0
			var edge: Vector2 = [Vector2(f,-13.7),Vector2(13.7,f),Vector2(f,13.7),Vector2(-13.7,f)][side]
			var h: Variant = editor.data.ground_height(edge)
			if h == null: continue
			var world: Vector3 = editor.terrain.to_global(Vector3(edge.x,float(h),edge.y))
			if scene.camera.is_position_behind(world): continue
			var at: Vector2 = scene.camera.unproject_position(world)
			if reach.reach_at(at) != "rim": continue
			if at.y > best.y and at.y < root.size.y-300 and at.y > 330: best = at
	return best

## Pull the rim down and let go: the range springs. Waits for it to land.
func rim_spring(pixels: float) -> void:
	var lip := lip_point()
	if lip == Vector2.ZERO:
		print("PLAY no rim point in view; spring skipped")
		return
	await glide(lip,20)
	button(lip,true)
	await frames(1)
	for i in range(24):
		move(lip+Vector2(0.0,pixels*float(i+1)/24),true)
		await frames(1)
	await frames(10)
	button(pointer,false)
	await settle(8.0)

## Until land, flip and refreshes have gone quiet (or `limit` seconds).
func settle(limit: float) -> void:
	var until := Time.get_ticks_msec()+int(limit*1000.0)
	var quiet := 0
	while quiet < 30 and Time.get_ticks_msec() < until:
		await frames(1)
		var busy: bool = editor.refresh_pending > 0 or (flip != null and flip.active()) or int(prop(spring,"state",0)) != 0
		quiet = 0 if busy else quiet+1

func take(id: String) -> void:
	for i in range(120):
		if materials.tray.shown > 0.99: break
		await frames(1)
	await click(materials.tray.specimen_centre(id))
	print("PLAY in hand: ",materials.held)

## Drop the held water on plate point `p`: press to form the ball, let go.
func pour(p: Vector2, hold: float) -> void:
	await glide(screen(p),20)
	button(pointer,true)
	await seconds(hold)
	button(pointer,false)
	await seconds(1.5)

## Sow the held seeds in a sweep across plate points `a` to `b`.
func sow(a: Vector2, b: Vector2, secs: float) -> void:
	await glide(screen(a),20)
	button(pointer,true)
	var from := screen(a)
	var to := screen(b)
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < int(secs*1000.0):
		move(from.lerp(to,float(Time.get_ticks_msec()-began)/(secs*1000.0)),true)
		await frames(1)
	button(pointer,false)
	await frames(2)

# --- The session ------------------------------------------------------------------

func run() -> void:
	Input.use_accumulated_input = false
	create_timer(600).timeout.connect(func() -> void: push_error("play session timed out"); _report(); quit(2))
	root.size = Vector2i(1440,900)
	var load_began := Time.get_ticks_usec()
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-play-session-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	print("PLAY loaded in %.2f s" % ((Time.get_ticks_usec()-load_began)/1e6))
	editor = scene._chunk_editor
	reach = scene.hand_reach
	materials = reach.get("materials")
	spring = scene.get("edge_spring")
	flip = scene.get("flip")
	scene.world_clock.running = false
	scene._overview()
	mark("warm")
	await seconds(3.0)
	var points: int = editor.data.points.size()
	print("PLAY terrain points %d, objects %d" % [points,editor.data.objects.size()])

	mark("idle")
	await seconds(3.0)
	mark("orbit_start")
	await orbit(4.0,3.0)

	mark("clay_peaks")
	await pinch(Vector2(-6,-4),-80.0)
	await pinch(Vector2(6,-3),-60.0)
	if "--gpu-phases" in OS.get_cmdline_user_args():
		await gpu_phases("two pinched peaks")
		quit(0)
		return
	if "--sky-capture" in OS.get_cmdline_user_args():
		await sky_capture("bare")
		quit(0)
		return
	if "--gpu-slopes-early" in OS.get_cmdline_user_args():
		await gpu_slopes("two pinched peaks")
		quit(0)
		return
	if "--smoke" in OS.get_cmdline_user_args():
		mark("smoke_end")
		_report()
		quit(0)
		return
	mark("clay_groove")
	await stroke([Vector2(-4.5,-2.5),Vector2(-2.5,0.0),Vector2(0.0,2.0)],1.2)
	await settle(6.0)

	if spring != null:
		for k in range(3):
			mark("spring_%d" % (k+1))
			await rim_spring(260.0)
	mark("after_springs")
	await seconds(3.0)

	if materials != null:
		mark("water_take")
		await take("water")
		mark("water_pour")
		await pour(Vector2(-6,-4),1.2)
		await pour(Vector2(6,-3),1.2)
		await pour(Vector2(0,-6),1.2)
		mark("water_runs")
		await seconds(8.0)
		await tap_key(KEY_ESCAPE)

		if "--rewarm-before-sow" in OS.get_cmdline_user_args():
			mark("rewarm")
			var again: Node3D = preload("res://scripts/pipeline_warmup.gd").new()
			scene.add_child(again)
			await again.warm(scene)
			again.queue_free()
			print("PLAY rewarm ",again.last_usec)
		mark("seed_take")
		await take("wildflower")
		mark("sow_1")
		await sow(Vector2(-5,3),Vector2(4,4),2.0)
		await take("oak")
		mark("sow_2")
		await sow(Vector2(-4,-1),Vector2(5,1),2.0)
		await take("dandelion")
		mark("sow_3")
		await sow(Vector2(-6,6),Vector2(6,5),2.0)
		await tap_key(KEY_ESCAPE)
	mark("growing")
	await seconds(20.0)
	mark("orbit_grown")
	await orbit(6.0,3.0)
	mark("fast_orbit_grown")
	await orbit(3.0,24.0)
	mark("end")
	if recording: _write_manifest()
	_report()
	if "--gpu-after" in OS.get_cmdline_user_args(): await gpu_phases("grown world")
	if "--gpu-slopes" in OS.get_cmdline_user_args(): await gpu_slopes("grown world")
	if "--sky-capture-grown" in OS.get_cmdline_user_args(): await sky_capture("grown")
	scene.queue_free()
	await process_frame
	quit(0)

# --- GPU phases -------------------------------------------------------------------

## Subtractive GPU pricing, one process: each feature is switched off for a
## few seconds (re-applied every frame, since the scene re-publishes some of
## them) and the median frame compared with the baseline either side. Only
## meaningful above the 120 fps cap, where the frame waits on the GPU.
func gpu_phases(label: String) -> void:
	var viewport := root.get_viewport()
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
	var world := viewport.find_world_3d()
	var env: Environment = world.environment if world != null else null
	for w: Node in root.find_children("*","WorldEnvironment",true,false):
		if (w as WorldEnvironment).environment != null: env = (w as WorldEnvironment).environment
	var camera: Camera3D = viewport.get_camera_3d()
	var lights: Array = root.find_children("*","Light3D",true,false).filter(func(l: Light3D) -> bool: return l.shadow_enabled)
	var views: Array = root.find_children("*","SubViewport",true,false).filter(func(v: SubViewport) -> bool: return v.render_target_update_mode in [SubViewport.UPDATE_ALWAYS,SubViewport.UPDATE_WHEN_VISIBLE])
	var passes: Array = root.find_children("*","CanvasItem",true,false).filter(func(c: CanvasItem) -> bool:
		return c.visible and c.material is ShaderMaterial and c is Control and (c as Control).size.x >= viewport.get_visible_rect().size.x*0.9)
	print("PLAY gpu phases (%s): env %s, shadowed lights %d, live subviewports %d %s, full-screen shader passes %d %s, compositor %s" % [label,env != null,lights.size(),views.size(),views.map(func(v: SubViewport) -> String: return "%s(%dx%d)" % [v.name,v.size.x,v.size.y]),passes.size(),passes.map(func(c: Node) -> String: return str(c.name)),camera != null and camera.compositor != null])
	var saved := {}
	var toggles := {
		"volumetric_fog":func(off: bool) -> void:
			if env != null: env.volumetric_fog_enabled = saved.get("vf",env.volumetric_fog_enabled) if not off else false,
		"sky":func(off: bool) -> void:
			if env != null: env.background_mode = Environment.BG_COLOR if off else saved.bg,
		"shadows":func(off: bool) -> void:
			for l: Light3D in lights: l.shadow_enabled = not off,
		"subviewports":func(off: bool) -> void:
			for v: SubViewport in views:
				if v.render_target_update_mode == SubViewport.UPDATE_ALWAYS or v.render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE or saved.has(v):
					v.render_target_update_mode = SubViewport.UPDATE_DISABLED if off else saved[v],
		"screen_passes":func(off: bool) -> void:
			for c: CanvasItem in passes: c.visible = not off,
		"compositor":func(off: bool) -> void:
			if camera != null: camera.compositor = null if off else saved.comp,
		"ssao_glow_ssr":func(off: bool) -> void:
			if env != null:
				env.ssao_enabled = false if off else saved.ssao
				env.glow_enabled = false if off else saved.glow
				env.ssr_enabled = false if off else saved.ssr
				env.ssil_enabled = false if off else saved.ssil,
		"msaa":func(off: bool) -> void:
			var want: Viewport.MSAA = Viewport.MSAA_DISABLED if off else saved.msaa
			if viewport.msaa_3d != want: viewport.msaa_3d = want,
		"half_res_3d":func(off: bool) -> void:
			var want: float = 0.5 if off else saved.scale
			if viewport.scaling_3d_scale != want: viewport.scaling_3d_scale = want,
	}
	if env != null:
		saved.vf = env.volumetric_fog_enabled
		saved.bg = env.background_mode
		saved.ssao = env.ssao_enabled
		saved.glow = env.glow_enabled
		saved.ssr = env.ssr_enabled
		saved.ssil = env.ssil_enabled
	for v: SubViewport in views: saved[v] = v.render_target_update_mode
	saved.comp = camera.compositor if camera != null else null
	saved.msaa = viewport.msaa_3d
	saved.scale = viewport.scaling_3d_scale
	var names: Array = toggles.keys()
	names.append("everything")
	var results := {}
	var base_runs: Array[float] = []
	base_runs.append(await _gpu_median(Callable()))
	for name: String in names:
		var apply: Callable
		if name == "everything":
			apply = func(off: bool) -> void:
				for t: Callable in toggles.values(): t.call(off)
		else: apply = toggles[name]
		results[name] = await _gpu_median(apply)
		base_runs.append(await _gpu_median(Callable()))
	var base := _percentile(base_runs,0.5)
	print("PLAY gpu phases (%s): baseline median %.2f ms (runs %s)" % [label,base,base_runs.map(func(v: float) -> String: return "%.1f" % v)])
	for name: String in names:
		print("PLAY   off %-16s %6.2f ms  saves %6.2f ms" % [name,results[name],base-results[name]])

## GPU pricing by multiplication (the zenscape-frame-profiling method): K
## extra full-size views of the same world from the same camera, so one main
## 3D pass costs (t(3)-t(1))/2 whatever the cap and the fixed costs. Each
## variant is applied everywhere and its pass cost compared with the
## baseline's. `--slopes=a,b` picks variants.
func gpu_slopes(label: String) -> void:
	var viewport := root.get_viewport()
	var env: Environment = null
	for w: Node in root.find_children("*","WorldEnvironment",true,false):
		if (w as WorldEnvironment).environment != null and (w as WorldEnvironment).get_viewport() == viewport: env = (w as WorldEnvironment).environment
	var camera: Camera3D = viewport.get_camera_3d()
	var lights: Array = root.find_children("*","DirectionalLight3D",true,false).filter(func(l: Light3D) -> bool: return l.shadow_enabled and l.get_viewport() == viewport)
	var filter_quality: int = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality",2)
	var shadow_size: int = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size",4096)
	var shadow_16: bool = ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits",true)
	var distances: Array = lights.map(func(l: DirectionalLight3D) -> float: return l.directional_shadow_max_distance)
	var terrain: Node3D = editor.terrain if editor != null else null
	var content: Node3D = editor.content if editor != null else null
	# Server-wide settings change only on a change: re-setting them every frame
	# could rebuild the atlas each time.
	var server := {"size":shadow_size,"filter":filter_quality}
	var set_size := func(value: int) -> void:
		if server.size != value:
			server.size = value
			RenderingServer.directional_shadow_atlas_set_size(value,shadow_16)
	var set_filter := func(value: int) -> void:
		if server.filter != value:
			server.filter = value
			RenderingServer.directional_soft_shadow_filter_set_quality(value)
	var sky_material: ShaderMaterial = env.sky.sky_material as ShaderMaterial if env != null and env.sky != null else null
	var saved_steps := [sky_material.get_shader_parameter("cloud_steps") if sky_material != null else 16]
	if saved_steps[0] == null: saved_steps[0] = 16
	var variants := {
		"base":func(_on: bool) -> void: pass,
		"shadows_off":func(on: bool) -> void:
			for l: Light3D in lights: l.shadow_enabled = not on,
		"filter_low":func(on: bool) -> void:
			set_filter.call(RenderingServer.SHADOW_QUALITY_SOFT_LOW if on else filter_quality),
		"filter_hard":func(on: bool) -> void:
			set_filter.call(RenderingServer.SHADOW_QUALITY_HARD if on else filter_quality),
		"shadow_2048":func(on: bool) -> void:
			set_size.call(2048 if on else shadow_size),
		"shadow_dist_60":func(on: bool) -> void:
			for i in range(lights.size()): lights[i].directional_shadow_max_distance = 60.0 if on else distances[i],
		"shadow_4096_fit":func(on: bool) -> void:
			set_size.call(4096 if on else shadow_size)
			for i in range(lights.size()): lights[i].directional_shadow_max_distance = float(scene.distance)+20.0 if on else distances[i],
		"ssao_off":func(on: bool) -> void:
			if env != null: env.ssao_enabled = not on,
		"glow_off":func(on: bool) -> void:
			if env != null: env.glow_enabled = not on,
		"sky_off":func(on: bool) -> void:
			if env != null: env.background_mode = Environment.BG_COLOR if on else Environment.BG_SKY,
		"msaa_off":func(on: bool) -> void:
			viewport.msaa_3d = Viewport.MSAA_DISABLED if on else ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d",0),
		"terrain_off":func(on: bool) -> void:
			if terrain != null: terrain.visible = not on,
		"plants_off":func(on: bool) -> void:
			if content != null:
				for b: Node in content.get_children():
					if b is MultiMeshInstance3D: b.visible = not on,
		# No coverage, no march. The weather republishes the deck every frame,
		# so a few unpaused frames after this variant put it back.
		"clouds_off":func(on: bool) -> void:
			if on: RenderingServer.global_shader_parameter_set("zs_cloud",Vector4.ZERO),
		"cloud_steps_12":func(on: bool) -> void:
			if sky_material != null: sky_material.set_shader_parameter("cloud_steps",12 if on else saved_steps[0]),
		"full_res_clouds":func(on: bool) -> void:
			for lighting: Node in root.find_children("*","LandscapeLighting",true,false): lighting.set_process(not on)
			if sky_material != null: sky_material.set_shader_parameter("half_res_clouds",not on),
		"half_res":func(on: bool) -> void:
			viewport.scaling_3d_scale = 0.5 if on else 1.0,
	}
	var picked: Array = variants.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--slopes="): picked = Array(a.trim_prefix("--slopes=").split(","))
	if not "base" in picked: picked.push_front("base")
	var size := Vector2i(root.size)
	var extra: Array[SubViewport] = []
	for i in range(3):
		var view := SubViewport.new()
		view.size = size
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var eye := Camera3D.new()
		view.add_child(eye)
		root.add_child(view)
		eye.current = true
		extra.append(view)
	# A holder, since lambdas capture locals by value.
	var current := {"variant":Callable()}
	var follow := func(on: bool) -> void:
		# Re-applied every frame: the scene re-publishes some of these.
		if (current.variant as Callable).is_valid(): current.variant.call(on)
		for view: SubViewport in extra:
			view.msaa_3d = viewport.msaa_3d
			view.scaling_3d_scale = viewport.scaling_3d_scale
			var eye: Camera3D = view.get_child(0)
			eye.global_transform = camera.global_transform
			eye.fov = camera.fov
			eye.near = camera.near
			eye.far = camera.far
			eye.attributes = camera.attributes
			eye.cull_mask = camera.cull_mask
	var views_on := func(count: int) -> void:
		for i in range(extra.size()):
			extra[i].render_target_update_mode = SubViewport.UPDATE_ALWAYS if i < count else SubViewport.UPDATE_DISABLED
	print("PLAY gpu slopes (%s): views %dx%d, msaa %d, camera distance %.1f, env %s, shadowed lights %d at %s m, filter %d, shadow map %d, cloud steps %s, volumetric fog %s, fog %s, half-res clouds %s, variants %s" % [label,size.x,size.y,viewport.msaa_3d,float(scene.distance),env != null,lights.size(),distances,filter_quality,shadow_size,saved_steps[0],env.volumetric_fog_enabled if env != null else null,env.fog_enabled if env != null else null,sky_material.get_shader_parameter("half_res_clouds") if sky_material != null else null,picked])
	# The world holds still while priced: water, life and growth would
	# otherwise change the work between readings. Rendering goes on.
	paused = true
	var rows := []
	var rounds := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--slope-rounds="): rounds = int(a.trim_prefix("--slope-rounds="))
	for round in range(rounds):
		for name: String in picked:
			if not variants.has(name): continue
			var apply: Callable = variants[name]
			# Each variant beside a fresh baseline, so drift cancels in the pair.
			if name != "base":
				views_on.call(1)
				var b1 := await _gpu_median_drawn(follow)
				views_on.call(3)
				var b3 := await _gpu_median_drawn(follow)
				views_on.call(0)
				rows.append(["base",b1,b3,(b3-b1)/2.0,name])
			current.variant = apply
			var t := {}
			for count in [1,3]:
				views_on.call(count)
				t[count] = await _gpu_median_drawn(follow)
			views_on.call(0)
			current.variant = Callable()
			apply.call(false)
			if name == "clouds_off":
				paused = false
				for i in range(5): await process_frame
				paused = true
			await process_frame
			rows.append([name,t[1],t[3],(t[3]-t[1])/2.0,name])
			var paired: Array = rows[rows.size()-2] if name != "base" else rows[-1]
			print("PLAY   slope %-15s t1 %6.2f  t3 %6.2f  pass %6.2f ms  (paired base %6.2f, saves %6.2f)" % [name,t[1],t[3],(t[3]-t[1])/2.0,paired[3],paired[3]-(t[3]-t[1])/2.0])
	var base := _percentile(rows.filter(func(r: Array) -> bool: return r[0] == "base").map(func(r: Array) -> float: return r[3]),0.5)
	print("PLAY gpu slopes (%s): one main pass %.2f ms (median of base rows)" % [label,base])
	for name: String in picked:
		if name == "base": continue
		var saves := []
		for i in range(rows.size()):
			if rows[i][0] == name and i > 0 and rows[i-1][0] == "base" and rows[i-1][4] == name: saves.append(rows[i-1][3]-rows[i][3])
		if saves.is_empty(): continue
		print("PLAY   %-15s saves %6.2f ms per pass, median of paired rounds %s" % [name,_percentile(saves,0.5),saves.map(func(v: float) -> String: return "%.2f" % v)])
	paused = false
	for view in extra: view.queue_free()

## Half- against full-resolution cloud march, from the play view and from low
## down looking up into the deck (20-32 m), in light and heavy cover, as
## /tmp/zs-sky-<label>-<view>-<cover>-<half|full>.png for the eye and a diff.
func sky_capture(label: String) -> void:
	var env: Environment = null
	for w: Node in root.find_children("*","WorldEnvironment",true,false):
		if (w as WorldEnvironment).environment != null and (w as WorldEnvironment).get_viewport() == root.get_viewport(): env = (w as WorldEnvironment).environment
	var sky_material := env.sky.sky_material as ShaderMaterial
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture-weather="):
			var weather := a.trim_prefix("--capture-weather=")
			scene._precipitation.set_weather(scene._precipitation.PRESET_NAMES.find(weather),true)
			label += "-"+weather
			await seconds(5.0)
	print("PLAY sky capture (%s): volumetric fog %s (density %.3f, sky affect %.2f), fog %s" % [label,env.volumetric_fog_enabled,env.volumetric_fog_density,env.volumetric_fog_sky_affect,env.fog_enabled])
	paused = true
	# The paused rig leaves the camera where it is put.
	var camera := root.get_viewport().get_camera_3d()
	var kept := camera.global_transform
	var lighting: Array[Node] = root.find_children("*","LandscapeLighting",true,false)
	for node in lighting: node.set_process(false)
	var views := {"play":kept,"up":Transform3D(Basis(),Vector3(0,6,30)).looking_at(Vector3(0,34,-40),Vector3.UP)}
	for view: String in views:
		camera.global_transform = views[view]
		for coverage in [0.06,0.6]:
			RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(coverage,0.0,20.0,12.0))
			for half in [true,false]:
				sky_material.set_shader_parameter("half_res_clouds",half)
				for i in range(8): await process_frame
				await RenderingServer.frame_post_draw
				var path := "/tmp/zs-sky-%s-%s-%s-%s.png" % [label,view,"clear" if coverage < 0.1 else "cloudy","half" if half else "full"]
				root.get_texture().get_image().save_png(path)
				print("PLAY sky capture ",path)
	camera.global_transform = kept
	for node in lighting: node.set_process(true)
	paused = false

## A reading with the extra views on that sits at the 120 fps cap means the
## window was hidden and nothing drew: wait for it to show again and retake.
func _gpu_median_drawn(apply: Callable) -> float:
	for attempt in range(20):
		var ms := await _gpu_median(apply)
		if ms > 9.5: return ms
		print("PLAY   reading at the cap (%.2f ms): window hidden? retaking" % ms)
		await create_timer(3.0).timeout
	return NAN

## Median frame over 3 s after 1 s to settle, with `apply` switching off each
## frame (and back on after).
func _gpu_median(apply: Callable) -> float:
	var ms: Array[float] = []
	var began := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec()-began < 4000:
		if apply.is_valid(): apply.call(true)
		await process_frame
		var now := Time.get_ticks_usec()
		if Time.get_ticks_msec()-began > 1000: ms.append(float(now-last)/1000.0)
		last = now
	if apply.is_valid(): apply.call(false)
	await process_frame
	return _percentile(ms,0.5)

# --- Report -----------------------------------------------------------------------

func _percentile(values: Array, p: float) -> float:
	if values.is_empty(): return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size()-1,int(p*(sorted.size()-1)))])

func _report() -> void:
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"events":events,"frames":records}))
	var order: Array[String] = []
	var by_phase := {}
	for r: Dictionary in records:
		if not by_phase.has(r.phase):
			by_phase[r.phase] = []
			order.append(r.phase)
		by_phase[r.phase].append(r.ms)
	var draws := {}
	for r: Dictionary in records:
		if not draws.has(r.phase): draws[r.phase] = [[],[],0]
		draws[r.phase][0].append(r.draws)
		draws[r.phase][1].append(r.render_cpu_ms)
		draws[r.phase][2] += int(r.compiles)
	print("\nPLAY phase             frames   p50    p95    p99    max   >16.7 >33.3 ms   draws p50  render-cpu p50  compiles")
	for name in order:
		var ms: Array = by_phase[name]
		var over16 := ms.filter(func(v: float) -> bool: return v > 16.7).size()
		var over33 := ms.filter(func(v: float) -> bool: return v > 33.3).size()
		print("PLAY %-18s %6d %6.1f %6.1f %6.1f %6.1f %5d %5d   %9d  %14.2f  %8d" % [name,ms.size(),_percentile(ms,0.5),_percentile(ms,0.95),_percentile(ms,0.99),_percentile(ms,1.0),over16,over33,_percentile(draws[name][0],0.5),_percentile(draws[name][1],0.5),draws[name][2]])
	var worst := records.duplicate()
	worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ms > b.ms)
	print("\nPLAY worst frames: ms, phase, refresh stage, handful/flow/view/life us, motes, objects, instances, cache, pipeline compiles, draws, render cpu ms")
	for r: Dictionary in worst.slice(0,30):
		print("PLAY %7.1f  %-16s %-14s R%6d%s e%6d h%6d f%6d v%6d l%6d  m%5d o%5d i%6d c%7d  pc%3d d%5d rc%5.1f%s" % [r.ms,r.phase,r.stage,r.refl_us,"*" if r.refl_busy else " ",r.emerge_us,r.handful_us,r.flow_us,r.flow_build_us,r.life_us,r.motes,r.objects,r.instances,r.cache,r.compiles,r.draws,r.render_cpu_ms," CLEARED" if r.cache_cleared else ""])
	var hitches := records.filter(func(r: Dictionary) -> bool: return r.ms > 16.7)
	var compiling := hitches.filter(func(r: Dictionary) -> bool: return r.compiles > 0)
	var compiled: int = records.reduce(func(a: int, r: Dictionary) -> int: return a+int(r.compiles),0)
	for i in range(records.size()):
		var r: Dictionary = records[i]
		if r.phase == "warm" or (r.compiles == 0 and r.ms < 100.0): continue
		print("PLAY %s %.1f ms in %s: compiles %s" % ["freeze" if r.ms >= 100.0 else "compile",r.ms,r.phase,r.compile_kinds])
		for k in range(maxi(0,i-4),i+1):
			for line: String in _first_seen.get(k,[]): print("PLAY     first drawn f%d: %s" % [k-i,line])
	var in_play: int = records.filter(func(r: Dictionary) -> bool: return r.phase != "warm" and r.phase != "load").reduce(func(a: int, r: Dictionary) -> int: return a+int(r.compiles),0)
	print("PLAY pipeline compiles during play (after warm): %d" % in_play)
	print("PLAY pipeline compiles after load: %d; hitches over 16.7 ms: %d, of which %d compiled a pipeline" % [compiled,hitches.size(),compiling.size()])
	var by_stage := {}
	for r: Dictionary in records:
		if r.stage == "": continue
		if not by_stage.has(r.stage): by_stage[r.stage] = [0,0.0,0.0]
		by_stage[r.stage][0] += 1
		by_stage[r.stage][1] += r.ms
		by_stage[r.stage][2] = maxf(by_stage[r.stage][2],r.ms)
	print("\nPLAY refresh stages: frames, total ms, worst ms")
	for s in by_stage: print("PLAY   %-18s %5d %9.1f %7.1f" % [s,by_stage[s][0],by_stage[s][1],by_stage[s][2]])
	var life_node: Object = scene.get("land_life") if scene != null else null
	if life_node != null: print("PLAY land life last survey parts (us): %s, survey worst step %d" % [life_node.survey_parts,life_node.survey_worst_usec])
	var worst_inst := {}
	for entry: Array in _inst_log:
		for k: String in entry[1]:
			worst_inst[k] = maxi(int(worst_inst.get(k,0)),int(entry[1][k]))
	print("PLAY land life worst parts (us): %s" % [_life_worst])
	print("PLAY instance rebuilds %d; worst per stage (us): %s" % [_inst_log.size(),worst_inst])
	print("PLAY height cache clears: %d (final size %d)" % [_cache_clears,_cache_size])
	print("PLAY frames written to ",output)
