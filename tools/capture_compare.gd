extends SceneTree
## Capture the fidelity scene at a fixed physical size with one rendering
## variant applied, for side-by-side comparison against the Electron build.
##
##   Godot --path . --rendering-method forward_plus --script res://tools/capture_compare.gd \
##     -- --out=/tmp/godot.png --size=2880x1800 --variant=msaa4 --paused --phase=0.35 --cam=43,1.13,1.8893,0,3,0
##
## Arguments the fidelity scene already understands (--cam, --phase, --paused,
## --balanced, --no-fog ...) pass straight through to it. --variant applies one
## lever on top; several combine with "+": msaa4+fxaa, off+taa, balanced.
## The capture waits --settle frames (default 72) so the temporal fog history
## has converged, then saves the root viewport.
var scene: Node3D
var out := "/tmp/godot-capture.png"
var settle := 72
var frames := 0

func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size := Vector2i(2880, 1800)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.trim_prefix("--out=")
		if a.begins_with("--settle="): settle = int(a.trim_prefix("--settle="))
		if a.begins_with("--size="):
			var parts := a.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	# macOS reports window sizes in physical pixels on Retina displays.
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(Vector2i(0, 0))
	_start.call_deferred()

func _start() -> void:
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--variant="):
			for lever in a.trim_prefix("--variant=").split("+"):
				_apply(lever)
	var e: Environment = scene._environment
	print("CAPTURE root=%s window=%s msaa=%d ssaa=%d taa=%s ssao=%s glow=%s tonemap=%d exposure=%.3f white=%.1f" % [str(root.size), str(root.get_window().size), root.msaa_3d, root.screen_space_aa, root.use_taa, e.ssao_enabled, e.glow_enabled, e.tonemap_mode, e.tonemap_exposure, e.tonemap_white])
	process_frame.connect(_frame)

func _apply(lever: String) -> void:
	match lever:
		"msaa2": root.msaa_3d = Viewport.MSAA_2X
		"msaa4": root.msaa_3d = Viewport.MSAA_4X
		"msaa8": root.msaa_3d = Viewport.MSAA_8X
		"off": root.msaa_3d = Viewport.MSAA_DISABLED
		"fxaa": root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		"taa": root.use_taa = true
		"deband": root.use_debanding = true
		"balanced": scene._set_quality(1)
		"beauty": scene._set_quality(0)
		"ssao-off": scene._environment.ssao_enabled = false
		"glow-off": scene._environment.glow_enabled = false
		"shadows-off":
			for l in root.find_children("*", "DirectionalLight3D", true, false):
				l.shadow_enabled = false
		"soft-shadows":
			for l in root.find_children("*", "DirectionalLight3D", true, false):
				l.light_angular_distance = 0.6
		"baseline": pass
		_:
			if lever.begins_with("exposure="):
				scene._environment.tonemap_exposure = float(lever.trim_prefix("exposure="))
			elif lever.begins_with("white="):
				scene._environment.tonemap_white = float(lever.trim_prefix("white="))
			elif lever.begins_with("tonemap="):
				scene._environment.tonemap_mode = int(lever.trim_prefix("tonemap="))
			else:
				push_error("unknown variant lever: " + lever)

func _frame() -> void:
	frames += 1
	if frames < settle: return
	process_frame.disconnect(_frame)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(out)
	print("CAPTURE wrote %s %s result=%d" % [out, str(image.get_size()), result])
	quit()
