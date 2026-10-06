extends SceneTree
## Where the look tour's frames go, rendered: at a few of the tour's spots
## (tools/capture_look_tour.gd) the frame is measured whole, then again with
## each part of the look taken away in turn, so each part's cost is the
## difference. Per spot and per part it prints the wall frame time, the GPU's
## and the render thread's CPU time for the main viewport
## (RenderingServer.viewport_get_measured_render_time_gpu/_cpu), the process
## time (scripts) and the draw calls, as tab-separated PROFILE lines.
## Rendered only (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/profile_look_tour.gd \
##     -- --no-title --out=/private/tmp/zs-profile
## Options: --out=DIR (a still of each spot whole goes there), --only=overview,sea-low,...,
## --parts=sky,near_sea,... (default all), --frames=N (measured frames, 40),
## --cap=LINES (the render resolution cap for the run, scripts/render_resolution.gd;
## the player's kept one otherwise), --freeze=T (hold the shaders' motion time
## at T, so stills of one spot match but for what is taken away),
## --stills=unbaked,... (a still of each spot with these parts taken away,
## <spot>-without-<part>.png, beside its whole <spot>.png).
const GOLDEN_SUN := 0.1
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-profile"
var noon := WorldClock.hour_for_phase(0.5)
var only: Array = []
var parts_wanted: Array = []
var measure_frames := 40
var cap := -1
var freeze := -1.0
var still_parts: Array = []
var _viewport: RID

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	image.save_png(out.path_join(label+".png"))

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument.begins_with("--parts="): parts_wanted = Array(argument.trim_prefix("--parts=").split(","))
		elif argument.begins_with("--frames="): measure_frames = int(argument.trim_prefix("--frames="))
		elif argument.begins_with("--cap="): cap = int(argument.trim_prefix("--cap="))
		elif argument.begins_with("--freeze="): freeze = float(argument.trim_prefix("--freeze="))
		elif argument.begins_with("--stills="): still_parts = Array(argument.trim_prefix("--stills=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(1800).timeout.connect(func() -> void: push_error("profile timed out"); quit(2))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	_viewport = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport,true)
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
	scene.world_clock.set_time(scene.world_clock.day,noon)
	var RenderResolution = preload("res://scripts/render_resolution.gd")
	print("PROFILE kept cap %d" % RenderResolution.load_cap())
	if cap >= 0: RenderResolution.apply(root,cap)
	if freeze >= 0.0: RenderingServer.frame_pre_draw.connect(func() -> void:
		scene._motion_time = freeze
		RenderingServer.global_shader_parameter_set("zs_motion_time",freeze))
	print("PROFILE\tspot\tpart\twall_ms\tgpu_ms\trender_cpu_ms\tprocess_ms\tdraws\tprimitives")
	print("PROFILE render scale %.3f, window %s, driver %s" % [root.scaling_3d_scale,root.size,RenderingServer.get_current_rendering_driver_name()])
	if _wanted("overview"):
		await frames(90)
		await still("overview")
		await _profile("overview")
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
	for shot: Dictionary in _shots():
		if not _wanted(shot.label): continue
		await _hold(shot,noon,90)
		await still(shot.label)
		await _profile(shot.label,shot)
	print("PROFILE done")
	quit(0)

func _wanted(label: String) -> bool:
	return only.is_empty() or label in only

func _shots() -> Array:
	var sea: float = preload("res://scripts/sky_peak.gd").SEA
	var reach: float = eye.PLATE_REACH
	return [
		{"label":"out-N","eye":Vector3(0,0,-1)*(reach+40.0)+Vector3.UP*30.0,"look":Vector3(0,0,-1)*2000.0+Vector3.UP*20.0},
		{"label":"sea-low","eye":Vector3(reach+260.0,sea+35.0,60.0),"look":Vector3(reach+900.0,sea+5.0,300.0)},
		{"label":"sea-down","eye":Vector3(reach+200.0,60.0,-200.0),"look":Vector3(reach+420.0,sea,-60.0)},
		{"label":"chase","eye":Vector3(reach+60.0,20.0,0.0),"look":Vector3(reach+600.0,sea+40.0,120.0),"chase":true},
	]

## Each part of the look, as [name, take away, put back]. Taking away is
## re-applied just before every measured frame is drawn, so parts the game
## re-publishes each frame stay away.
func _parts() -> Array:
	var lighting = scene._lighting
	var env: Environment = scene._environment
	var sky_material: ShaderMaterial = env.sky.sky_material
	var look = scene.look_pass
	var islands = eye.islands if eye != null else null
	var parts := []
	parts.append(["sky_plain",func() -> void: env.background_mode = Environment.BG_COLOR,func() -> void: env.background_mode = Environment.BG_SKY])
	parts.append(["dome_sea",func() -> void: sky_material.set_shader_parameter("cloud_sea",0.0),func() -> void: look._update_cloud_sea(look.cloud_sea) if look.has_method("_update_cloud_sea") else null])
	parts.append(["dome_clouds_min_steps",func() -> void: sky_material.set_shader_parameter("cloud_steps",12),func() -> void: sky_material.set_shader_parameter("cloud_steps",16)])
	parts.append(["radiance",func() -> void: env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED,func() -> void: env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY])
	var sky: Sky = env.sky
	parts.append(["radiance_32",func() -> void: sky.radiance_size = Sky.RADIANCE_SIZE_32,func() -> void: sky.radiance_size = Sky.RADIANCE_SIZE_256])
	if look.sea != null:
		parts.append(["near_sea",func() -> void: look.sea.visible = false,func() -> void: look.sea.visible = true])
		var sea_material: ShaderMaterial = look.sea.material
		var sea: Node = look.sea
		# Negative: what one bake of the envelope costs, baked every frame.
		parts.append(["rebake",func() -> void: sea._baked_middle = Vector2.INF,func() -> void: pass])
		parts.append(["unbaked",func() -> void:
			var at: Vector4 = sea_material.get_shader_parameter("envelope_at")
			sea_material.set_shader_parameter("envelope_at",Vector4(at.x,at.y,at.z,0.0)),func() -> void:
			var at: Vector4 = sea_material.get_shader_parameter("envelope_at")
			sea_material.set_shader_parameter("envelope_at",Vector4(at.x,at.y,at.z,1.0))])
	if islands != null:
		for key: String in ["towers","peaks","clouds","islets","currents","folk","ambient"]:
			var node = islands.get(key)
			if node is Node3D: parts.append([key,func() -> void: node.visible = false,func() -> void: node.visible = true])
		if islands.peaks != null:
			var puffs: Array = islands.peaks.find_children("*","MultiMeshInstance3D",true,false)
			parts.append(["peak_puffs(%d)" % puffs.size(),func() -> void:
				for p: Node3D in puffs: p.visible = false,func() -> void:
				for p: Node3D in puffs: p.visible = true])
		if islands.traffic != null:
			var traffic: Node = islands.traffic
			parts.append(["traffic",func() -> void: traffic.process_mode = Node.PROCESS_MODE_DISABLED; if traffic is Node3D: traffic.visible = false,
				func() -> void: traffic.process_mode = Node.PROCESS_MODE_INHERIT; if traffic is Node3D: traffic.visible = true])
	var fog: CanvasLayer = scene.get("_display_fog")
	if fog != null:
		parts.append(["display_fog",func() -> void:
			fog.visible = false
			fog.buffer.render_target_update_mode = SubViewport.UPDATE_DISABLED
			fog.march.render_target_update_mode = SubViewport.UPDATE_DISABLED,func() -> void:
			fog.visible = true
			fog.buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			fog.march.render_target_update_mode = SubViewport.UPDATE_ALWAYS])
	parts.append(["ssao",func() -> void: env.ssao_enabled = false,func() -> void: env.ssao_enabled = true])
	parts.append(["glow",func() -> void: env.glow_enabled = false,func() -> void: env.glow_enabled = true])
	parts.append(["shadows",func() -> void:
		for light: DirectionalLight3D in lighting.lights: light.shadow_enabled = false,func() -> void:
		for light: DirectionalLight3D in lighting.lights: light.shadow_enabled = true])
	var msaa := root.msaa_3d
	parts.append(["msaa",func() -> void: root.msaa_3d = Viewport.MSAA_DISABLED,func() -> void: root.msaa_3d = msaa])
	parts.append(["scripts",func() -> void: scene.process_mode = Node.PROCESS_MODE_DISABLED,func() -> void: scene.process_mode = Node.PROCESS_MODE_INHERIT])
	parts.append(["all_3d",func() -> void: RenderingServer.viewport_set_disable_3d(_viewport,true),func() -> void: RenderingServer.viewport_set_disable_3d(_viewport,false)])
	return parts

func _profile(spot: String, shot := {}) -> void:
	var whole := await _measure(Callable())
	_print(spot,"whole",whole)
	for part: Array in _parts():
		var name: String = part[0]
		if not parts_wanted.is_empty() and name.get_slice("(",0) not in parts_wanted: continue
		var without := await _measure(part[1])
		if name in still_parts:
			RenderingServer.frame_pre_draw.connect(part[1])
			await frames(4)
			await still("%s-without-%s" % [spot,name])
			RenderingServer.frame_pre_draw.disconnect(part[1])
		part[2].call()
		await frames(8)
		_print(spot,"-"+name,without,whole)
	# Whole again, to see the drift between the start and the end.
	_print(spot,"whole_again",await _measure(Callable()))

## The means over measure_frames frames, `take_away` applied before each
## is drawn (after the game's own processing, which may put it back).
func _measure(take_away: Callable) -> Dictionary:
	if take_away.is_valid():
		take_away.call()
		RenderingServer.frame_pre_draw.connect(take_away)
	for i in range(12):
		await RenderingServer.frame_post_draw
	var sum := {"wall":0.0,"gpu":0.0,"cpu":0.0,"process":0.0,"draws":0.0,"primitives":0.0}
	var from := Time.get_ticks_usec()
	for i in range(measure_frames):
		await RenderingServer.frame_post_draw
		sum.gpu += RenderingServer.viewport_get_measured_render_time_gpu(_viewport)
		sum.cpu += RenderingServer.viewport_get_measured_render_time_cpu(_viewport)
		sum.process += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		sum.draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sum.primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	sum.wall = float(Time.get_ticks_usec()-from)/1000.0
	if take_away.is_valid(): RenderingServer.frame_pre_draw.disconnect(take_away)
	for key: String in sum: sum[key] /= measure_frames
	return sum

func _print(spot: String, part: String, m: Dictionary, whole := {}) -> void:
	var line := "PROFILE\t%s\t%s\t%.2f\t%.2f\t%.2f\t%.2f\t%d\t%d" % [spot,part,m.wall,m.gpu,m.cpu,m.process,m.draws,m.primitives]
	if not whole.is_empty(): line += "\tsaves wall %.2f gpu %.2f" % [whole.wall-m.wall,whole.gpu-m.gpu]
	print(line)

## Holds the eye at a shot for `count` frames at `hour` (tools/capture_look_tour.gd).
func _hold(shot: Dictionary, hour: float, count: int) -> void:
	var at: Vector3 = shot.eye
	var look: Vector3 = shot.look
	var way := (look-at).normalized()
	var glide: RefCounted = eye.glide
	glide.position = at
	glide.heading = atan2(-way.x,-way.z)
	glide.pitch = asin(clampf(way.y,-1.0,1.0))
	glide.bank = 0.0
	glide.speed = 8.0
	glide.velocity = glide.forward()*8.0
	var chase: bool = shot.get("chase",false)
	eye.glider.visible = chase
	if chase:
		eye.chase.first_person = false
		eye.chase.reset(glide,at-way*6.0+Vector3.UP*2.0)
	for i in range(count):
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
