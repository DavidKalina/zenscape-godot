extends SceneTree
## Launch check for `--atlas` (scripts/chunk_atlas_controller.gd), headless:
## opens the cozy flow with a throwaway atlas, grows a chunk east, drags the
## land brush across the shared border through the editor, walks back, then
## relaunches from the saved atlas. Reports seams and build times.
## Run: godot --headless --path . --script tools/probe_chunk_atlas.gd -- --atlas
var failures := 0
var folder := ""

func check(ok: bool, message: String) -> void:
	print(("ok   " if ok else "FAIL ")+message)
	if not ok: failures += 1

func _initialize() -> void: run.call_deferred()

func open_scene() -> Node:
	var scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	scene.places_path = folder+"/places.json"
	scene.atlas_path = folder+"/atlas.json"
	root.add_child(scene)
	var began := Time.get_ticks_msec()
	while not scene.shell_ready and Time.get_ticks_msec()-began < 90000: await process_frame
	return scene

func settle(scene: Node) -> void:
	var editor: NativeChunkEditor = scene._chunk_editor
	for i in range(240):
		await process_frame
		if editor.refresh_pending == 0 and not editor.water_settling and not scene.atlas.busy and i > 10: break

func drag(scene: Node, from: Vector2, to: Vector2) -> void:
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.select_brush("land")
	editor.creation_brush().prepare(editor.data,editor.land_seed)
	editor.creation_brush().begin()
	editor.data.begin_stroke()
	for step in range(40):
		editor.land_dab(from.lerp(to,step/39.0),editor.brush_strength()/10.0)
		await editor.refresh()
	editor.data.end_stroke()
	await editor.refresh(self)

func seam(scene: Node) -> float:
	var atlas = scene.atlas.atlas
	return atlas.seam_delta(atlas.live,scene._chunk_editor.data.heights,scene._chunk_editor.data.points)

func run() -> void:
	root.size = Vector2i(1280,800)
	create_timer(300).timeout.connect(func() -> void:
		print("probe timed out")
		quit(2))
	check("--atlas" in OS.get_cmdline_user_args(),"launched with --atlas")
	folder = "/private/tmp/zs-atlas-probe-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var scene = await open_scene()
	check(scene.atlas != null and not scene.atlas.busy,"the atlas controller is up")
	var controller = scene.atlas
	check(controller.atlas.live == Vector2i.ZERO and controller.views.is_empty(),"a new atlas starts at (0,0) alone")
	await settle(scene)
	await drag(scene,Vector2(8,-10),Vector2(12,10))
	await settle(scene)
	var began := Time.get_ticks_usec()
	check(await controller.move(Vector2i(1,0)),"grow a chunk east")
	print("grow east: %.1f ms (views %.1f ms)" % [(Time.get_ticks_usec()-began)/1000.0,controller.last_build_usec/1000.0])
	await settle(scene)
	check(controller.atlas.live == Vector2i(1,0) and controller.views.has(Vector2i.ZERO),"the first chunk is drawn west of the live one")
	check(controller.views[Vector2i.ZERO].position.is_equal_approx(Vector3(-28,0,0)),"at x = -28")
	check(scene._chunk_editor.open_sides.keys() == ["w"],"the live skirt opens on the west only, got %s" % [scene._chunk_editor.open_sides.keys()])
	print("seam on a fresh plain: %.6f" % seam(scene))
	await drag(scene,Vector2(-8,-12),Vector2(-13.8,12))
	await settle(scene)
	var after := seam(scene)
	print("seam after a land stroke across the border: %.6f" % after)
	check(after < 1e-3,"seam stays shut after a stroke (%.6f)" % after)
	var pin_began := Time.get_ticks_usec()
	scene._chunk_editor.border_pin.apply(scene._chunk_editor.data)
	print("pin apply with nothing to close: %.3f ms" % ((Time.get_ticks_usec()-pin_began)/1000.0))
	var west: int = preload("res://scripts/chunk_atlas.gd").edge_ids(scene._chunk_editor.data.points).w[22]
	scene._chunk_editor.data.heights[west] += 0.3
	pin_began = Time.get_ticks_usec()
	var closed: float = scene._chunk_editor.border_pin.apply(scene._chunk_editor.data)
	print("pin apply closing a %.2f m offset across the band: %.3f ms" % [closed,(Time.get_ticks_usec()-pin_began)/1000.0])
	check(seam(scene) < 1e-3,"the pin closes a raised border vertex")
	began = Time.get_ticks_usec()
	check(await controller.move(Vector2i(-1,0)),"walk back west onto the stored chunk")
	print("walk back: %.1f ms (views %.1f ms)" % [(Time.get_ticks_usec()-began)/1000.0,controller.last_build_usec/1000.0])
	await settle(scene)
	check(controller.atlas.live == Vector2i.ZERO and controller.views.has(Vector2i(1,0)),"the east chunk is now the frozen one")
	check(seam(scene) < 1e-3,"the reopened chunk still meets its neighbour (%.6f)" % seam(scene))
	check(scene.save_current(),"save")
	check(FileAccess.file_exists(folder+"/atlas.json"),"atlas.json written to the probe folder")
	scene.queue_free()
	await process_frame
	await process_frame
	var again = await open_scene()
	await settle(again)
	check(again.atlas.atlas.slots.size() == 2 and again.atlas.views.size() == 1,"relaunch restores both chunks, one drawn frozen")
	check(seam(again) < 1e-3,"relaunched seam %.6f" % seam(again))
	again.queue_free()
	await process_frame
	print("probe_chunk_atlas: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
