extends SceneTree
## Real-engine stills, responsive checks, and a frozen-world miniature reel.
## Run with --film for 96 deterministic frames under /private/tmp/nursery-frames.
const OUTPUT := "res://docs/design/nursery"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in range(6): await process_frame
	RenderingServer.force_draw(false)

func snap(file: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(OUTPUT.path_join(file)) == OK,"Save "+file)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1800,1200)
	var scene: Node3D = load("res://studies/nursery_preview.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	var palette: NativeBuildPalette = scene._build_palette
	await snap("miniatures.png")
	check(root.get_visible_rect().encloses(palette.get_global_rect()),"Dock fits the large window")
	var arch: Node3D = palette._portraits.arch.pivot
	var before := arch.rotation.y
	await settle()
	check(arch.rotation.y > before,"Visible miniatures rotate")
	var hidden: Node3D = palette._portraits.mountain.pivot
	before = hidden.rotation.y
	await settle()
	check(is_equal_approx(hidden.rotation.y,before),"Other categories do no animation work")
	palette.visible = false
	before = arch.rotation.y
	await settle()
	check(is_equal_approx(arch.rotation.y,before),"Hidden dock stops rotating")
	palette.visible = true
	palette._tune.button_pressed = true
	scene._chunk_editor.select_tool("tree")
	await snap("tune.png")
	check(palette.strip_fits(),"Tree controls fit the popover")
	palette._tune.button_pressed = false
	scene._chunk_editor.select_tool("meadow")
	await snap("plant.png")
	palette._show_category("Sky")
	await snap("sky.png")
	root.size = Vector2i(960,640)
	scene._chunk_editor.select_tool("arch")
	await snap("compact.png")
	check(root.get_visible_rect().encloses(palette._bar.get_global_rect()),"Dock fits minimum window")
	for tab in palette._tabs.get_children():
		if tab is Control and tab.visible:
			check(palette._bar.get_global_rect().encloses(tab.get_global_rect()),"Tab fits: "+str(tab.name))
	palette._tune.button_pressed = true
	await snap("compact-tune.png")
	check(root.get_visible_rect().encloses(palette._details.get_global_rect()),"Popover fits minimum window")
	palette._tune.button_pressed = false
	root.size = Vector2i(1800,1200)
	await settle()
	if "--film" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("/private/tmp/nursery-frames")
		palette.set_process(false)
		# A static first frame is the control; only miniature transforms advance.
		for frame in range(96):
			palette._animate_portraits(1.0/24.0)
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_jpg("/private/tmp/nursery-frames/%04d.jpg" % frame,0.92)
	print("Nursery visual checks: ",failures," failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
