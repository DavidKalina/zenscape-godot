extends SceneTree
## Stills of a painted wheat field (docs/scenic/wheat.md): a flattened patch
## of the plain, a 6 m by 4 m field painted through the wheat slot's brush,
## in Alpine daylight with fog and haze thinned. Saves
## captures/wheat/<tag>-<view>.png. Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/still_wheat.gd -- --modeless --no-title [--tag=name] [--views=close,mid] [--mood=name]

const FlowerPaint = preload("res://scripts/flower_paint.gd")
const FlowerSowing = preload("res://scripts/flower_sowing.gd")
var scene: Node3D
var editor: NativeChunkEditor
const CENTRE := Vector2(2.0,-1.0)
## distance, polar, yaw
const VIEWS := {"close":Vector3(2.6,1.2,0.6),"backlit":Vector3(3.2,1.2,3.74),"mid":Vector3(7.5,1.0,0.6),"diorama":Vector3(20.0,0.95,0.6)}
var only := PackedStringArray()
var mood := "Alpine daylight"

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if absf(scene._atmosphere.fog_amount-0.04) > 0.01:
			scene._atmosphere.set_fog(0.04)
			scene._atmosphere.set_haze(0.06)

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("wheat still timed out"); quit(2))
	var tag := "now"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--views="): only = arg.trim_prefix("--views=").split(",")
		if arg.begins_with("--mood="): mood = arg.trim_prefix("--mood=")
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-wheat-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size = Vector2i(1280,720)
	editor = scene._chunk_editor
	scene.world_clock.running = false
	scene.apply_scene_mood(mood)
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
	# Clear what stands on the patch, then paint the field in passes.
	data.begin_stroke()
	data.objects = data.objects.filter(func(item: Dictionary) -> bool: return Vector2(item.x,item.z).distance_to(CENTRE) > 6.5)
	data.end_stroke()
	data.begin_stroke()
	var stroke = FlowerPaint.new(FlowerSowing.new(data,"wheat",4242),1.6,false,1)
	stroke.press(CENTRE+Vector2(-3.0,-2.0))
	for k in range(9):
		var z := -2.0+k*0.5
		var a := CENTRE+Vector2(-3.0 if k%2 == 0 else 3.0,z)
		var b := CENTRE+Vector2(3.0 if k%2 == 0 else -3.0,z)
		for f in range(1,121): stroke.stroke(a.lerp(b,f/120.0),1.0/60.0)
	stroke.finish()
	data.end_stroke()
	print("WHEAT clumps ",data.objects.filter(func(item: Dictionary) -> bool: return item.asset == "wheat").size())
	await editor.refresh(self)
	await frames(60)
	Input.warp_mouse(Vector2(4,4))
	var out := ProjectSettings.globalize_path("res://captures/wheat")
	DirAccess.make_dir_recursive_absolute(out)
	for view: String in VIEWS:
		if not only.is_empty() and not view in only: continue
		var v: Vector3 = VIEWS[view]
		var look := Vector3(CENTRE.x,level+0.35,CENTRE.y)
		scene.camera_rig.glide_to(editor.terrain.to_global(look),v.z,v.y,v.x)
		await frames(150)
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png(out.path_join("%s-%s.png" % [tag,view]))
			print("WHEAT still ",tag,"-",view)
	quit(0)
