extends SceneTree
## The 3D render resolution cap (scripts/render_resolution.gd): a tall window
## is drawn at the cap's lines and scaled up, a short one at its own; Native
## never scales; the choice is kept, and an unknown one falls back to 1080p.
const RenderResolution = preload("res://scripts/render_resolution.gd")
const PATH := "user://test_render_resolution.cfg"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(2880,1800)
	root.add_child(view)
	await process_frame
	RenderResolution.apply(view,1080)
	check(is_equal_approx(view.scaling_3d_scale,0.6), "A Retina 1800-line window draws its 3D at 1080 lines (%s)" % view.scaling_3d_scale)
	check(view.scaling_3d_mode in [Viewport.SCALING_3D_MODE_FSR,Viewport.SCALING_3D_MODE_METALFX_SPATIAL], "It scales up spatially, never temporally")
	RenderResolution.apply(view,0)
	check(view.scaling_3d_scale == 1.0, "Native draws at the window's own resolution")
	view.size = Vector2i(1280,720)
	RenderResolution.apply(view,1080)
	check(view.scaling_3d_scale == 1.0, "A window under the cap is never scaled")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	check(RenderResolution.load_cap(PATH) == 1080, "With nothing kept the cap is 1080p")
	RenderResolution.save_cap(720,PATH)
	check(RenderResolution.load_cap(PATH) == 720, "The choice is kept")
	RenderResolution.save_cap(333,PATH)
	check(RenderResolution.load_cap(PATH) == 1080, "An unknown kept cap falls back to 1080p")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	view.queue_free()
	await process_frame
	print("PASS: render resolution" if failures == 0 else "FAIL: render resolution (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
