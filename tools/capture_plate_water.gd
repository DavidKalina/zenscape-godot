extends SceneTree
## Stills of the plate's own still water, the reference the kit isles' water
## is matched to (docs/scenic/kit-isle-water.md): the test island's live pond
## (studies/test_island.tscn; scripts/water_flow_view.gd, its planar view),
## in the kit isles' opening look (Alpine morning; --look=<preset id>), from
## where a walker stands at the
## shore and from where the plane skims over, each looking toward the sun
## and away from it. The walker's eye is held still and the scene's orbit
## set on each view (studies/fidelity.gd `_update_camera`).
## Rendered (needs a window):
##   Godot --windowed --resolution 1440x900 --path . -s res://tools/capture_plate_water.gd -- --no-title [--out=DIR] [--look=<preset id>] [--no-live-reflection]
## Writes DIR/<view>.png (default captures/kit-isle-water/plate) and quits.
var out := "captures/kit-isle-water/plate"
var look := "alpine_morning"
var scene: Node3D

## Each view: the eye and the point looked at, off the pond's middle and
## level, in metres along the sun's way over the ground (x), up (y) and
## across it (z).
const VIEWS := {
	"shore_sun":[Vector3(-5.2,1.65,1.0),Vector3(2.0,-0.25,0.0)],
	"shore_away":[Vector3(5.2,1.65,1.0),Vector3(-2.0,-0.25,0.0)],
	"skim_sun":[Vector3(-16.0,5.5,3.0),Vector3(1.0,0.0,0.0)],
	"skim_away":[Vector3(16.0,5.5,3.0),Vector3(-1.0,0.0,0.0)],
	"above":[Vector3(-4.0,9.0,5.0),Vector3(0.5,0.0,0.0)],
}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--look="): look = arg.trim_prefix("--look=")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(300.0).timeout.connect(func() -> void: push_error("plate water capture timed out"); quit(2))
	scene = load("res://studies/test_island.tscn").instantiate()
	scene.places_path = OS.get_temp_dir().path_join("plate-water-capture-%d" % Time.get_ticks_usec()).path_join("places.json")
	root.size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not scene.walk_ready: await process_frame
	preload("res://scripts/scene_look_presets.gd").apply(scene,look)
	for i in range(240): await process_frame
	# The walker's eye writes its pose into the scene's orbit each frame:
	# held still, the orbit is ours.
	var eye: Node = scene.wanderer
	eye.set_process(false)
	eye.set_physics_process(false)
	var pond: Vector2 = scene.POND
	var level := float(scene.island.pond.get("level",0.0))
	var sun: Vector3 = scene._celestial.state.zs_sun_direction
	var along := Vector3(sun.x,0.0,sun.z).normalized()
	var across := along.cross(Vector3.UP)
	print("plate water: pond at %s, level %.2f, sun %s" % [pond,level,sun])
	var middle := Vector3(pond.x,level,pond.y)
	var frame := func(v: Vector3) -> Vector3: return middle+along*v.x+Vector3.UP*v.y+across*v.z
	for view: String in VIEWS:
		var at: Vector3 = frame.call(VIEWS[view][1])
		var offset: Vector3 = frame.call(VIEWS[view][0])-at
		scene.target = at
		scene.distance = offset.length()
		scene.polar = acos(offset.y/offset.length())
		scene.yaw = atan2(offset.x,offset.z)
		for i in range(90): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(view+".png"))
		print("plate water: saved %s (%d draw calls)" % [out.path_join(view+".png"),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit(0)
