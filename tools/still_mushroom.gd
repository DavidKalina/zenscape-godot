extends SceneTree
## Stills of the redesigned mushroom (scripts/mushroom_mesh.gd) on plain
## grass: a flattened patch with a few clusters among tufts and ferns, in Alpine
## daylight. Saves captures/mushroom/<tag>-<view>.png for a top-down view
## (each cluster reads as a huddle of caps), a close three-quarter
## view and a mid view. Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/still_mushroom.gd -- --modeless --no-title [--tag=name] [--views=top,close,mid]

var scene: Node3D
var editor: NativeChunkEditor
const CENTRE := Vector2(2.0,-1.0)
const MOOD := "Alpine daylight"
## distance, polar, yaw
const VIEWS := {"top":Vector3(1.6,0.12,0.6),"close":Vector3(0.9,1.1,0.6),"mid":Vector3(5.0,0.95,0.6)}
var only := PackedStringArray()

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if absf(scene._atmosphere.fog_amount-0.04) > 0.01:
			scene._atmosphere.set_fog(0.04)
			scene._atmosphere.set_haze(0.06)

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("mushroom still timed out"); quit(2))
	var tag := "now"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--views="): only = arg.trim_prefix("--views=").split(",")
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-mushroom-%d/places.json" % Time.get_ticks_usec()
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
	rng.seed = 7
	data.begin_stroke()
	for n in range(30):
		var p := CENTRE+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.8,4.0)
		data.place("grass_tuft",p,rng.randf()*TAU,rng.randf_range(0.7,1.1))
	# A cluster stands clear at the centre, with a fern beside it, then a few more.
	data.place("mushroom",CENTRE+Vector2(-0.3,0.0),0.3,1.0)
	data.place("mushroom",CENTRE+Vector2(0.5,0.3),2.1,0.8)
	data.place("fern",CENTRE+Vector2(0.9,-0.6),0.3,0.9)
	for n in range(6):
		data.place("mushroom",CENTRE+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(1.2,3.5),rng.randf()*TAU,rng.randf_range(0.6,1.3))
	for n in range(3):
		data.place("fern",CENTRE+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(2.0,3.5),rng.randf()*TAU,rng.randf_range(0.7,1.2))
	data.end_stroke()
	await editor.refresh(self)
	# --set=ground_calm:0 and the like, on the ground's material, for A/B.
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--set="): continue
		var pair := arg.trim_prefix("--set=").split(":")
		var material := editor.terrain.mesh.surface_get_material(0) as ShaderMaterial
		if editor.terrain.material_override is ShaderMaterial: material = editor.terrain.material_override
		material.set_shader_parameter(pair[0],float(pair[1]))
		print("MUSHROOM set ",pair[0]," ",pair[1])
	await frames(60)
	Input.warp_mouse(Vector2(4,4))
	var out := ProjectSettings.globalize_path("res://captures/mushroom")
	DirAccess.make_dir_recursive_absolute(out)
	for view: String in VIEWS:
		if not only.is_empty() and not view in only: continue
		var v: Vector3 = VIEWS[view]
		var target := CENTRE
		var look := Vector3(target.x,level+0.08,target.y)
		scene.camera_rig.glide_to(editor.terrain.to_global(look),v.z,v.y,v.x)
		await frames(150)
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png(out.path_join("%s-%s.png" % [tag,view]))
			print("MUSHROOM still ",tag,"-",view)
	quit(0)
