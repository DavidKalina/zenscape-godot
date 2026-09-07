extends SceneTree
## Single-process frame profiler: cycles render configurations in place and
## samples wall fps and main-thread time per phase. Usage:
##   Godot --path . --rendering-method forward_plus --disable-vsync --script res://tools/profile_frame_phases.gd -- --phases=baseline,hide-mist,half-window
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
var _env_bg := 0
var _sky: Sky
func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phases="): phases = Array(a.trim_prefix("--phases=").split(","))
		if a.begins_with("--hold="): hold = int(a.trim_prefix("--hold=")) * 1000000
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
func _apply(name: String, on: bool) -> void:
	var e: Environment = scene._environment
	if name == "hide-mist":
		_post = (func(): scene.get_node("WaterfallSpray").visible = false) if on else Callable()
		return
	if name == "hide-mist+air16":
		_post = (func(): scene.get_node("WaterfallSpray").visible = false) if on else Callable()
		scene._display_fog.material.set_shader_parameter("air_steps", 16 if on else 64)
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
			"bigfoot": _per_frame = func(): sc._bigfoot.advance(1.0/60.0, false, sc.camera.global_position, sc.camera, 1.0, sc._atmosphere.fog_amount)
			"foam": _per_frame = func(): sc._fall_foam.advance(sc._motion_time, false, 0.0, 1.0, true)
			"tremor": _per_frame = func(): sc._tremor.advance(1.0/60.0, false); sc.camera.transform = sc._tremor.apply(sc.camera.transform)
			"camera": _per_frame = func(): sc._update_camera(); RenderingServer.global_shader_parameter_set("zs_camera_position", sc.camera.global_position)
			"displayfog": _per_frame = func(): sc._environment.volumetric_fog_enabled = false; sc._display_fog.update_view()
			"spray": _per_frame = func(): sc.get_node("WaterfallSpray").update_view(sc.camera, sc._display_fog.depth)
			"labels": _per_frame = func(): sc._time_label.text = "Time of day · %02d:%02d" % [randi()%24, randi()%60]; sc._terrain_slider.set_value_no_signal(sc._growth.terrain)
			"visibility": _per_frame = func(): sc._chunk_editor.sync_visibility(); sc.get_node("WaterfallSpray").visible = true; sc._bigfoot.visible = true
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
	if name.begins_with("air-s"):
		var parts := name.trim_prefix("air-s").split("-n")
		var fog = scene._display_fog
		fog.buffer_scale = float(parts[0]) if on else 0.5
		fog.material.set_shader_parameter("air_steps", int(parts[1]) if on else 64)
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
	frames = 0; proc_us = 0; gap_us = 0
func _frame() -> void:
	var now := Time.get_ticks_usec()
	if settle:
		if now - t0 > 1500000:
			settle = false
			t0 = now; frames = 0; proc_us = 0; gap_us = 0
		last_end = now
		return
	frames += 1
	gap_us += now - last_end
	if _per_frame.is_valid(): _per_frame.call()
	if scene.process_mode != Node.PROCESS_MODE_DISABLED and not _no_process:
		var s := Time.get_ticks_usec()
		scene._process(1.0/60.0)
		proc_us += Time.get_ticks_usec() - s
	if _post.is_valid(): _post.call()
	last_end = Time.get_ticks_usec()
	if now - t0 > hold:
		var sec := float(now - t0) / 1e6
		print("PHASE %-14s fps=%6.1f frame=%6.2fms  fidelity._process=%5.2fms  rest(render+present+other)=%6.2fms  target=%s draws=%d" % [phases[phase], frames/sec, 1000.0*sec/frames, proc_us/1000.0/frames, gap_us/1000.0/frames, str(root.get_texture().get_size()), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		_next()
