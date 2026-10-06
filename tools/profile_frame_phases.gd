extends SceneTree
## Single-process frame profiler: cycles render configurations in place and
## samples wall fps and main-thread time per phase. Usage:
##   Godot --path . --rendering-method forward_plus --disable-vsync --script res://tools/profile_frame_phases.gd -- --maximize --paused --phases=baseline,x3d-4,x3d-8,x3d-4+msaa-off,x3d-8+msaa-off
## Switches: --maximize, --fullscreen, --paused, --hold=<s>, --repeat=<n>.
## A phase that prints exactly 6.90 ms hit the macOS presentation cap; discard it.
## Below that cap only slopes are trustworthy: `x3d-K` renders the world K extra
## times, `xfog-K` marches the air K extra times, `xblend-K` composites K extra
## times, and `+` combines phases, so (t(x3d-8) - t(x3d-4)) / 4 is one 3D pass.
var scene: Node3D
var phases := ["baseline","empty","baseline"]
var hold := 4000000
var phase := -1
var t0 := 0
var frames := 0
var proc_us := 0
var gap_us := 0
var last_end := 0
var settle := true
var gpu_us := 0.0
var rcpu_us := 0.0
var fog_gpu_us := 0.0
var _env_bg := 0
var _sky: Sky
func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phases="): phases = Array(a.trim_prefix("--phases=").split(","))
		if a.begins_with("--hold="): hold = int(a.trim_prefix("--hold=")) * 1000000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--repeat="):
			var once := phases.duplicate()
			for i in range(int(a.trim_prefix("--repeat=")) - 1): phases.append_array(once)
	_start.call_deferred()
func _start() -> void:
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	root.get_window().content_scale_factor = 1.0
	scene.set_process(false)
	_kids = scene.get_children()
	for a in OS.get_cmdline_user_args():
		if a == "--no-scene-process": _no_process = true
		if a == "--maximize": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		if a == "--fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(scene._display_fog.buffer.get_viewport_rid(), true)
	for a in OS.get_cmdline_user_args():
		if a == "--paused": scene._paused = true
	_env_bg = scene._environment.background_mode
	_sky = scene._environment.sky
	await create_timer(3.0).timeout
	var e: Environment = scene._environment
	print("PHASE viewport: ssaa=%d taa=%s deband=%s msaa=%d scaling=%d/%0.2f hdr2d=%s | env: ssao=%s ssil=%s ssr=%s sdfgi=%s glow=%s fog=%s vol=%s adj=%s tonemap=%d bg=%d | world_env=%s" % [root.screen_space_aa, root.use_taa, root.use_debanding, root.msaa_3d, root.scaling_3d_mode, root.scaling_3d_scale, root.use_hdr_2d, e.ssao_enabled, e.ssil_enabled, e.ssr_enabled, e.sdfgi_enabled, e.glow_enabled, e.fog_enabled, e.volumetric_fog_enabled, e.adjustment_enabled, e.tonemap_mode, e.background_mode, str(scene.get_node_or_null("WorldEnvironment"))])
	process_frame.connect(_frame)
	_next()
var _saved := {}
var _kids: Array = []
var _per_frame := Callable()
var _post := Callable()
var _no_process := false
var _extra_views: Array = []
var _extra_rects: Array = []
func _apply(name: String, on: bool) -> void:
	if "+" in name and not name.begins_with("hide-mist+") and not name.begins_with("freeze+"):
		for part in name.split("+"):
			_apply(part, on)
		return
	var e: Environment = scene._environment
	if name.begins_with("x3d-"):
		# K extra full 3D renders of the same world from the same camera, so the
		# frame lands above the presentation cap; (t(2K) - t(K)) / K is one pass.
		if on:
			for i in int(name.trim_prefix("x3d-")):
				var vp := SubViewport.new()
				vp.world_3d = root.world_3d
				vp.size = root.size
				vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				var cam := Camera3D.new()
				vp.add_child(cam)
				cam.make_current()
				root.add_child(vp)
				_extra_views.append(vp)
		else:
			for vp in _extra_views: vp.queue_free()
			_extra_views.clear()
		return
	if name.begins_with("xblend-"):
		# K extra copies of the full-window composite (screen texture read + air blend).
		var fog = scene._display_fog
		if on:
			for i in int(name.trim_prefix("xblend-")):
				var r := ColorRect.new()
				r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				r.mouse_filter = Control.MOUSE_FILTER_IGNORE
				r.material = fog.blend
				fog.add_child(r)
				_extra_rects.append(r)
		else:
			for r in _extra_rects: r.queue_free()
			_extra_rects.clear()
		return
	if name.begins_with("xfog-"):
		# K extra copies of the air march inside the march target.
		var buf: SubViewport = scene._display_fog.march
		if on:
			for i in int(name.trim_prefix("xfog-")):
				var r := ColorRect.new()
				r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				r.mouse_filter = Control.MOUSE_FILTER_IGNORE
				r.material = scene._display_fog.material
				buf.add_child(r)
				_extra_rects.append(r)
		else:
			for r in _extra_rects: r.queue_free()
			_extra_rects.clear()
		return
	if name == "factor2":
		root.get_window().content_scale_factor = 2.0 if on else 1.0
		if on:
			await create_timer(0.5).timeout
			print("PHASE   factor2 texture.get_size=%s image=%s window=%s" % [str(root.get_texture().get_size()), str(root.get_texture().get_image().get_size()), str(root.get_window().size)])
		return
	if name == "hide-mist":
		_post = (func(): scene.get_node("WaterfallSpray").visible = false) if on else Callable()
		return
	if name == "hide-mist+air16":
		_post = (func(): scene.get_node("WaterfallSpray").visible = false) if on else Callable()
		scene._display_fog.material.set_shader_parameter("air_steps", 16)
		return
	if name == "hide-mist+air16+nofog":
		_post = (func(): scene.get_node("WaterfallSpray").visible = false; scene._display_fog.visible = false; scene._display_fog.buffer.render_target_update_mode = SubViewport.UPDATE_DISABLED) if on else Callable()
		if not on: scene._display_fog.visible = true; scene._display_fog.buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		return
	if name.begins_with("p-"):
		var key := name.trim_prefix("p-")
		if not on:
			_per_frame = Callable()
			return
		var sc = scene
		match key:
			"growth": _per_frame = func(): sc._growth.advance(1.0/60.0, false, sc._tremor)
			"inversion": _per_frame = func(): sc._atmosphere.set_inversion(sc._celestial.state.zs_inversion.x)
			"motion": _per_frame = func(): sc._motion_time += 1.0/60.0; RenderingServer.global_shader_parameter_set("zs_motion_time", sc._motion_time)
			"birds": _per_frame = func(): sc._bird_flight.advance(1.0/60.0, false, sc._atmosphere._air_strength, Vector2(cos(sc._atmosphere._air_angle),sin(sc._atmosphere._air_angle)))
			"fireflies": _per_frame = func(): sc._fireflies.update_conditions(sc._celestial.state.get("zs_daylight",1.0), sc._precipitation.state.x, sc._precipitation.surface_weather.cold, 1.0)
			"foam": _per_frame = func(): sc._fall_foam.advance(sc._motion_time, false, 0.0, 1.0, true)
			"tremor": _per_frame = func(): sc._tremor.advance(1.0/60.0, false); sc.camera.transform = sc._tremor.apply(sc.camera.transform)
			"camera": _per_frame = func(): sc._update_camera(); RenderingServer.global_shader_parameter_set("zs_camera_position", sc.camera.global_position)
			"displayfog": _per_frame = func(): sc._environment.volumetric_fog_enabled = false; sc._display_fog.update_view()
			"spray": _per_frame = func(): sc.get_node("WaterfallSpray").update_view(sc.camera, sc._display_fog.depth)
			"labels": _per_frame = func(): sc._time_label.text = "Time of day · %02d:%02d" % [randi()%24, randi()%60]; sc._terrain_slider.set_value_no_signal(sc._growth.terrain)
			"visibility": _per_frame = func(): sc._chunk_editor.sync_visibility(); sc.get_node("WaterfallSpray").visible = true
		return
	if name.begins_with("free-"):
		if on:
			var idx := int(name.trim_prefix("free-"))
			var c: Node = _kids[idx]
			if is_instance_valid(c):
				print("PHASE   freeing %s (%s) script=%s" % [c.name, c.get_class(), c.get_script().resource_path if c.get_script() else "-"])
				c.free()
		return
	if name == "empty-hold":
		root.disable_3d = true
		for c in scene.get_children():
			if c is CanvasLayer: c.visible = false
		return
	if name.begins_with("fsr2-") or name.begins_with("bilinear-"):
		var fsr := name.begins_with("fsr2-")
		root.scaling_3d_mode = (Viewport.SCALING_3D_MODE_FSR2 if fsr else Viewport.SCALING_3D_MODE_BILINEAR) if on else Viewport.SCALING_3D_MODE_BILINEAR
		root.scaling_3d_scale = float(name.get_slice("-", 1)) if on else 1.0
		return
	if name.begins_with("air-s"):
		var parts := name.trim_prefix("air-s").split("-n")
		var fog = scene._display_fog
		fog.buffer_scale = float(parts[0]) if on else 0.5
		fog.material.set_shader_parameter("air_steps", int(parts[1]) if on else 16)
		return
	match name:
		"env-min":
			if on:
				_saved = {"ssao":e.ssao_enabled,"ssil":e.ssil_enabled,"ssr":e.ssr_enabled,"sdfgi":e.sdfgi_enabled,"glow":e.glow_enabled,"fog":e.fog_enabled,"adj":e.adjustment_enabled,"vol":e.volumetric_fog_enabled}
				e.ssao_enabled=false; e.ssil_enabled=false; e.ssr_enabled=false; e.sdfgi_enabled=false; e.glow_enabled=false; e.fog_enabled=false; e.adjustment_enabled=false; e.volumetric_fog_enabled=false
			else:
				e.ssao_enabled=_saved.ssao; e.ssil_enabled=_saved.ssil; e.ssr_enabled=_saved.ssr; e.sdfgi_enabled=_saved.sdfgi; e.glow_enabled=_saved.glow; e.fog_enabled=_saved.fog; e.adjustment_enabled=_saved.adj; e.volumetric_fog_enabled=_saved.vol
		"no-env":
			scene.get_node("WorldEnvironment").environment = null if on else e
		"disable3d":
			root.disable_3d = on
		"empty":
			root.disable_3d = on
			for c in scene.get_children():
				if c is CanvasLayer: c.visible = not on
		"fsr2-0.5":
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if on else Viewport.SCALING_3D_MODE_BILINEAR
			root.scaling_3d_scale = 0.5 if on else 1.0
		"bilinear-0.5":
			root.scaling_3d_scale = 0.5 if on else 1.0
		"tiny-window":
			if on:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_size(Vector2i(756, 426))
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		"vsync-on":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)
	match name:
		"freeze","freeze+nocomp":
			scene.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	match name:
		"nocomp","freeze+nocomp":
			if on: scene.camera.compositor = null
			else: scene.get_node("WaterfallSpray").fallback_depth = null
	match name:
		"hide3d":
			for c in scene.get_children():
				if c is Node3D: c.visible = not on
		"sky-off":
			scene._environment.background_mode = Environment.BG_COLOR if on else _env_bg
			scene._environment.sky = null if on else _sky
		"msaa-off":
			root.msaa_3d = Viewport.MSAA_DISABLED if on else Viewport.MSAA_2X
		"msaa-4":
			root.msaa_3d = Viewport.MSAA_4X if on else Viewport.MSAA_2X
		"fxaa":
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if on else Viewport.SCREEN_SPACE_AA_DISABLED
		"taa":
			root.use_taa = on
		"sky-inc":
			_sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL if on else Sky.PROCESS_MODE_REALTIME
		"ssao-off":
			e.ssao_enabled = not on
		"glow-off":
			e.glow_enabled = not on
		"shadows-off":
			for l in scene.find_children("*", "DirectionalLight3D", true, false): l.shadow_enabled = not on
		"half-window":
			if on:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_size(Vector2i(1512, 853))
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
func _next() -> void:
	if phase >= 0:
		_apply(phases[phase], false)
	phase += 1
	if phase >= phases.size():
		quit()
		return
	_apply(phases[phase], true)
	settle = true
	t0 = Time.get_ticks_usec()
	frames = 0; proc_us = 0; gap_us = 0; gpu_us = 0.0; rcpu_us = 0.0; fog_gpu_us = 0.0
func _frame() -> void:
	var now := Time.get_ticks_usec()
	if settle:
		if now - t0 > 1500000:
			settle = false
			t0 = now; frames = 0; proc_us = 0; gap_us = 0; gpu_us = 0.0; rcpu_us = 0.0; fog_gpu_us = 0.0
		last_end = now
		return
	frames += 1
	gap_us += now - last_end
	for vp in _extra_views:
		var cam: Camera3D = vp.get_child(0)
		cam.global_transform = scene.camera.global_transform
		cam.fov = scene.camera.fov; cam.near = scene.camera.near; cam.far = scene.camera.far
		vp.msaa_3d = root.msaa_3d; vp.scaling_3d_mode = root.scaling_3d_mode; vp.scaling_3d_scale = root.scaling_3d_scale
		vp.screen_space_aa = root.screen_space_aa; vp.use_taa = root.use_taa
	gpu_us += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()) * 1000.0
	rcpu_us += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) * 1000.0
	fog_gpu_us += RenderingServer.viewport_get_measured_render_time_gpu(scene._display_fog.buffer.get_viewport_rid()) * 1000.0
	if _per_frame.is_valid(): _per_frame.call()
	if scene.process_mode != Node.PROCESS_MODE_DISABLED and not _no_process:
		var s := Time.get_ticks_usec()
		scene._process(1.0/60.0)
		proc_us += Time.get_ticks_usec() - s
	if _post.is_valid(): _post.call()
	last_end = Time.get_ticks_usec()
	if now - t0 > hold:
		var sec := float(now - t0) / 1e6
		print("PHASE %-14s fps=%6.1f frame=%6.2fms  gpu=%6.2fms (fog %5.2f)  render_cpu=%5.2fms  fidelity._process=%5.2fms  rest=%6.2fms  target=%s draws=%d" % [phases[phase], frames/sec, 1000.0*sec/frames, gpu_us/1000.0/frames, fog_gpu_us/1000.0/frames, rcpu_us/1000.0/frames, proc_us/1000.0/frames, gap_us/1000.0/frames, str(root.get_texture().get_size()), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		_next()
