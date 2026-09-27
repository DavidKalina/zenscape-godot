extends "res://tools/film_genesis.gd"
## Stills of the Genesis film for judging the look (land brush hills, mist over
## the pond, meadow, path, ferns, tree scale next to the deer). Runs the film's
## exact script (tools/film_genesis.gd) at a fixed 30 fps without Movie Maker,
## saves the frame at a few film moments, then closes in on each brush's work
## before quitting. Rendered, so a window opens for the run (about two minutes):
##   Godot --path . --fixed-fps 30 --script res://tools/capture_genesis_look.gd \
##     -- --plain-seed 7 --force-moments --stills=/private/tmp/zs-look/after
## Pairs of runs (before and after a change) give same-camera comparisons.
## Film seconds at which a still is saved, with its name.
const MOMENTS := {"land":13.0,"pond":24.5,"painted":52.0}
## Close views after the watch: [name, target (terrain-local), distance, polar°, yaw°].
const CLOSE := [
	["hill",Vector3(-4.0,1.5,4.0),13.0,58.0,-30.0],
	["pond",Vector3(3.0,0.0,2.2),11.0,48.0,10.0],
	["meadow",Vector3(7.0,0.3,4.5),10.0,50.0,40.0],
	["path",Vector3(-2.5,0.3,7.8),9.0,60.0,-5.0],
	["forest",Vector3(-4.0,0.8,-1.0),13.0,48.0,-20.0],
	["overview",Vector3(0.5,0.5,0.5),30.0,55.0,0.0],
]
var stills_dir := ""
var watch_start := -1

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stills="): stills_dir = arg.trim_prefix("--stills=")
	if stills_dir.is_empty(): stills_dir = "/private/tmp/zs-look/stills"
	DirAccess.make_dir_recursive_absolute(stills_dir)
	super()

func save(name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null: return
	if image.get_width() > 1600:
		image.resize(1600,int(image.get_height()*1600.0/image.get_width()),Image.INTERPOLATE_BILINEAR)
	image.save_jpg(stills_dir.path_join(name+".jpg"),0.9)
	print("STILL ",name," t=%.1f" % seconds())

func look(label: String) -> void:
	super(label)
	if label == "watch" and watch_start < 0: watch_start = frame-1

func step(held := 0) -> void:
	await super(held)
	for name: String in MOMENTS:
		if frame == int(MOMENTS[name]*30.0): save(name)
	if watch_start >= 0 and frame == watch_start+int(WATCH_SECONDS*30.0)-1:
		await _close_views()

func _close_views() -> void:
	save("watch_end")
	var deer: Variant = null
	if life != null and not life.moments._deer_state.is_empty():
		deer = life.moments._deer_state.members[0].p
	var views := CLOSE.duplicate()
	if deer != null:
		var p: Vector2 = deer
		views.append(["deer",Vector3(p.x,editor.data.ground_height(p) if editor.data.ground_height(p) != null else 0.5,p.y),9.0,50.0,20.0])
	for view: Array in views:
		scene.target = editor.terrain.to_global(view[1])
		scene.distance = view[2]
		scene.polar = deg_to_rad(view[3])
		scene.yaw = deg_to_rad(view[4])
		for i in range(4):
			scene._update_camera()
			await process_frame
		save("close_"+view[0])
