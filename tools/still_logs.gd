extends SceneTree
## Stills of the redesigned fallen log (scripts/log_mesh.gd) on plain grass: a
## flattened patch with a clear centre log, a few more of different size among
## tufts, in Alpine daylight. Saves captures/logs/<tag>-<view>.png for a top-down
## view (moss strip and stubs), a close three-quarter view (bark facets, the
## end grain, the splintered end) and a mid view. Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/still_logs.gd -- --modeless --no-title [--tag=name] [--views=top,close,mid]

var scene: Node3D
var editor: NativeChunkEditor
const CENTRE := Vector2(2.0,-1.0)
const MOOD := "Alpine daylight"
## distance, polar, yaw
const VIEWS := {"top":Vector3(3.2,0.12,0.6),"close":Vector3(2.0,1.0,0.6),"mid":Vector3(7.0,0.95,0.6)}
var only := PackedStringArray()

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if absf(scene._atmosphere.fog_amount-0.04) > 0.01:
			scene._atmosphere.set_fog(0.04)
			scene._atmosphere.set_haze(0.06)

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("log still timed out"); quit(2))
	var tag := "now"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--views="): only = arg.trim_prefix("--views=").split(",")
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-logs-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size = Vector2i(1280,720)
	editor = scene._chunk_editor
	scene.world_clock.running = false
	scene.apply_scene_mood(MOOD)
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	var data := editor.data
	var near := PackedFloat32Array()
	for i in range(data.points.size()):
		if data.points[i].distance_to(CENTRE) < 6.0: near.append(data.heights[i])
	near.sort()
	var level: float = near[near.size()/2]
	data.begin_stroke()
	var heights := data.heights.duplicate()
	for i in range(data.points.size()):
		var r := data.points[i].distance_to(CENTRE)
		heights[i] = lerpf(heights[i],level,1.0-smoothstep(6.0,8.0,r))
	data.heights = heights
	data.end_stroke()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	data.begin_stroke()
	for n in range(30):
		var p := CENTRE+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.8,4.0)
		data.place("grass_tuft",p,rng.randf()*TAU,rng.randf_range(0.7,1.1))
	# A log lies clear at the centre, then a few more of other sizes.
	data.place("log",CENTRE,0.35,1.0)
	for n in range(4):
		data.place("log",CENTRE+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(2.2,3.6),rng.randf()*TAU,rng.randf_range(0.7,1.3))
	data.end_stroke()
	await editor.refresh(self)
	await frames(60)
	Input.warp_mouse(Vector2(4,4))
	var out := ProjectSettings.globalize_path("res://captures/logs")
	DirAccess.make_dir_recursive_absolute(out)
	for view: String in VIEWS:
		if not only.is_empty() and not view in only: continue
		var v: Vector3 = VIEWS[view]
		var look := Vector3(CENTRE.x,level+0.1,CENTRE.y)
		scene.camera_rig.glide_to(editor.terrain.to_global(look),v.z,v.y,v.x)
		await frames(150)
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png(out.path_join("%s-%s.png" % [tag,view]))
			print("LOGS still ",tag,"-",view)
	quit(0)
