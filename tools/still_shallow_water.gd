extends SceneTree
## Stills of live water's shallows (docs/scenic/water-flow.md "Clear
## shallows"): a flattened patch of the plain with a pond 0.8 m deep at its
## core inside a broad shelf 0-5 cm deep, the water set directly and held
## still (the sim paused), in the water films' look (Alpine daylight, fog and
## haze thinned). Saves /private/tmp/zs-shallows/<tag>-<view>.png for an
## oblique, a low grazing and a high view. Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/still_shallow_water.gd -- --modeless --no-title --no-rain-runoff [--tag=name]

var scene: Node3D
var editor: NativeChunkEditor
const CENTRE := Vector2(2.0,-1.0)
const MOOD := "Alpine daylight"
const VIEWS := {"oblique":Vector3(11.0,0.95,0.6),"low":Vector3(9.0,1.3,0.6),"high":Vector3(10.0,0.45,0.6)}
## Only these views (--views=oblique,low), for quick looks.
var only := PackedStringArray()

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if absf(scene._atmosphere.fog_amount-0.04) > 0.01:
			scene._atmosphere.set_fog(0.04)
			scene._atmosphere.set_haze(0.06)

## The basin's ground below the patch's level at `r` m from its centre.
static func basin(r: float) -> float:
	return -0.8*(1.0-smoothstep(1.0,2.0,r))-0.06*(1.0-smoothstep(2.0,4.5,r))

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("shallows still timed out"); quit(2))
	var tag := "now"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--views="): only = arg.trim_prefix("--views=").split(",")
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-shallows-%d/places.json" % Time.get_ticks_usec()
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
	for i in range(240):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	var data := editor.data
	# The patch's level: the plain's median height within 6 m of the centre.
	var near := PackedFloat32Array()
	for i in range(data.points.size()):
		if data.points[i].distance_to(CENTRE) < 6.0: near.append(data.heights[i])
	near.sort()
	var level: float = near[near.size()/2]
	data.begin_stroke()
	var heights := data.heights.duplicate()
	for i in range(data.points.size()):
		var r := data.points[i].distance_to(CENTRE)
		var flat := 1.0-smoothstep(5.0,7.0,r)
		heights[i] = lerpf(heights[i],level+basin(r),flat)
	data.heights = heights
	data.end_stroke()
	await editor.refresh(self)
	await frames(30)
	# Water to 1 cm under the patch's level: the shelf stands 0-5 cm deep.
	var flow: RefCounted = editor.flow
	flow.paused = true
	flow.kernel.step(data.heights,PackedFloat32Array(),0,flow.dt)
	var grounds: PackedFloat32Array = flow.grounds()
	var depths := PackedFloat32Array()
	depths.resize(grounds.size())
	for c in range(grounds.size()):
		var at: Vector2 = flow.origin+Vector2(c%flow.width+0.5,c/flow.width+0.5)*flow.cell
		depths[c] = maxf(0.0,level-0.01-grounds[c]) if at.distance_to(CENTRE) < 5.0 else 0.0
	flow.kernel.set_depth(depths)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shallow-clear="): editor.flow_view.still.material_override.set_shader_parameter("shallow_clear",float(arg.trim_prefix("--shallow-clear=")))
	editor.flow_view.publish()
	# The reflection view stands once the editor's pool read sees the pond.
	await frames(150)
	print("SHALLOWS level %.2f, pools %s, reflection %s" % [level,str(flow.pools().map(func(p: Dictionary) -> String: return "%.1f m²" % p.area)),"on" if editor.flow_view.reflection != null and editor.flow_view.reflection.get("level") != null else "off"])
	# The pointer off the land, so no brush ring or tool stands in the frame.
	Input.warp_mouse(Vector2(4,4))
	DirAccess.make_dir_recursive_absolute("/private/tmp/zs-shallows")
	for view: String in VIEWS:
		if not only.is_empty() and not view in only: continue
		var v: Vector3 = VIEWS[view]
		scene.target = editor.terrain.to_global(Vector3(CENTRE.x,level,CENTRE.y))
		scene.distance = v.x
		scene.polar = v.y
		scene.yaw = v.z
		await frames(45)
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png("/private/tmp/zs-shallows/%s-%s.png" % [tag,view])
			print("SHALLOWS still ",tag,"-",view)
	quit(0)
