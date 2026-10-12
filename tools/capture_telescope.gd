extends SceneTree
## Stills of the telescope (scripts/telescope.gd, docs/design/telescope/
## round2.md) on the aqueduct isle with --watcher, for judging by eye: the
## watcher holding his spyglass up on the serpent, seen from beside him;
## then the pilot beside him with his own raised on the serpent's find, at
## mid zoom and at full zoom.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . -s res://tools/capture_telescope.gd -- --no-title [--out=DIR]
## Writes DIR/<moment>.png (default captures/telescope) and quits.
const DT := 1.0/60.0
const LaunchArgs = preload("res://scripts/launch_args.gd")

var out := "captures/telescope"
var study: Node3D
var watcher: Node3D

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(300.0).timeout.connect(func() -> void: push_error("telescope capture timed out"); quit(2))
	LaunchArgs.set_override(["--no-title","--watcher"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	study.chain_on = false
	root.size = Vector2i(1600,900)
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	await physics_frame
	study.sky.flush()
	watcher = study.watcher
	# The serpent where it starts, down at the dip, far off.
	# Beside him, a little in front, looking back at his face and the glass.
	study.place(watcher.global_position+Vector3(5.0,0.0,-0.5),Vector2(0.0,1.0))
	await _frames(1.0)
	for i in range(40):
		await _frames(DT)
		if watcher.up >= 1.0: break
	var eye: Vector3 = watcher.eye()
	var g: Vector3 = watcher.gaze()
	var side := Vector3(g.z,0.0,-g.x).normalized()
	var cam: Camera3D = study.camera
	cam.fov = 40.0
	cam.global_transform = Transform3D.IDENTITY.translated(eye+g*1.1+side*0.9+Vector3.UP*0.15).looking_at(eye+g*0.12,Vector3.UP)
	await _save("watcher_spyglass")
	# The pilot's own, raised on the find.
	var b: Node = study.telescope
	study.script_telescope = true
	for zoom in [6.0,12.0]:
		for i in range(40):
			var to: Vector3 = watcher.find.global_position-b.eye()
			b.yaw = atan2(-to.x,-to.z)
			b.pitch = atan2(to.y,Vector2(to.x,to.z).length())
			b.zoom = zoom
			await _frames(DT)
		print("find %.0f m off, %d glints" % [b.eye().distance_to(watcher.find.global_position),b.glints.size()])
		await _save("view_%dx" % int(zoom))
	study.script_telescope = false
	LaunchArgs.set_override(null)
	print("TELESCOPE captured ",out)
	quit(0)

func _frames(seconds: float) -> void:
	for i in range(maxi(1,int(round(seconds/DT)))):
		study.sky.serpent.advance(DT)
		watcher._process(DT)
		study.tick(DT)
		await process_frame

func _save(moment: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join(moment+".png")
	root.get_texture().get_image().save_png(path)
	print("saved ",path)
