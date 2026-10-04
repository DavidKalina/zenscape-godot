extends SceneTree
## Stills of the fallen leaves (scripts/leaf_litter_mesh.gd, drifted by
## scripts/wind_leaf_litter.gd) at the foot of a broadleaf on plain grass, in
## Alpine daylight, with a placed leaf bed beside it. Saves
## captures/leaves/<tag>-<view>.png: a top-down view (drifts and shapes), a
## close three-quarter view (fold, curl, soft light) and a mid view (scatter
## against the open meadow). Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/still_leaves.gd -- --modeless --no-title [--tag=name] [--views=top,close,mid]

var scene: Node3D
var editor: NativeChunkEditor
const CENTRE := Vector2(2.0,-1.0)
const MOOD := "Alpine daylight"
## distance, polar, yaw
const VIEWS := {"top":Vector3(3.0,0.12,0.6),"close":Vector3(2.4,1.0,0.6),"mid":Vector3(7.0,0.95,0.6)}
var only := PackedStringArray()

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if absf(scene._atmosphere.fog_amount-0.04) > 0.01:
			scene._atmosphere.set_fog(0.04)
			scene._atmosphere.set_haze(0.06)

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("leaves still timed out"); quit(2))
	var tag := "now"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--views="): only = arg.trim_prefix("--views=").split(",")
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-leaves-%d/places.json" % Time.get_ticks_usec()
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
	# A broadleaf stands at the centre, two more further off, and a leaf bed.
	data.place("broadleaf",CENTRE,0.3,1.0)
	data.place("broadleaf",CENTRE+Vector2(-4.5,2.5),1.7,1.1)
	data.place("broadleaf",CENTRE+Vector2(3.5,3.5),2.4,0.9)
	data.place("leaf_bed",CENTRE+Vector2(1.6,-1.8),0.8,1.0)
	data.end_stroke()
	await editor.refresh(self)
	# --set=ground_calm:0 and the like, on the ground's material, for A/B.
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--set="): continue
		var pair := arg.trim_prefix("--set=").split(":")
		var material := editor.terrain.mesh.surface_get_material(0) as ShaderMaterial
		if editor.terrain.material_override is ShaderMaterial: material = editor.terrain.material_override
		material.set_shader_parameter(pair[0],float(pair[1]))
		print("LEAVES set ",pair[0]," ",pair[1])
	await frames(60)
	Input.warp_mouse(Vector2(4,4))
	var out := ProjectSettings.globalize_path("res://captures/leaves")
	DirAccess.make_dir_recursive_absolute(out)
	for view: String in VIEWS:
		if not only.is_empty() and not view in only: continue
		var v: Vector3 = VIEWS[view]
		var target := CENTRE
		var look := Vector3(target.x,level+0.1,target.y)
		scene.camera_rig.glide_to(editor.terrain.to_global(look),v.z,v.y,v.x)
		await frames(150)
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png(out.path_join("%s-%s.png" % [tag,view]))
			print("LEAVES still ",tag,"-",view)
	quit(0)
