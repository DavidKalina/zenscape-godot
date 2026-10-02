extends SceneTree
## Stills of the meadow flower kit (docs/scenic/flowers.md): a flattened
## patch of the plain with a drift of each kind in a ring of grass tufts,
## in Alpine daylight with fog and haze thinned. Saves
## captures/flowers/<tag>-<view>.png for a close, a close backlit and a
## diorama-distance view. Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/still_meadow_flowers.gd -- --modeless --no-title [--tag=name] [--views=close,diorama] [--wind=1.2] [--chalk]

const Kit := preload("res://scripts/meadow_flower_mesh.gd")
var scene: Node3D
var editor: NativeChunkEditor
const CENTRE := Vector2(2.0,-1.0)
const MOOD := "Alpine daylight"
## distance, polar, yaw
const VIEWS := {"close":Vector3(3.0,1.12,0.6),"backlit":Vector3(3.0,1.15,3.74),"sunflower":Vector3(3.2,1.3,0.6),"mid":Vector3(9.0,1.0,0.6),"diorama":Vector3(23.0,0.95,0.6)}
## The sunflowers stand here (the sixth drift); their view looks up at them.
const SUNFLOWERS := 5
var only := PackedStringArray()
## Air strength to hold (--wind=1.2), or negative to leave the weather be.
var wind := -1.0
## The Chalk & turquoise grass ratio (--chalk), to see petals keep their hue
## on a muted family (docs/scenic/grass-look.md "Round two").
var chalk := false

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if wind >= 0.0: scene._atmosphere._air_strength = wind
		if chalk: RenderingServer.global_shader_parameter_set("zs_palette_grass",Vector3(2.63,0.97,1.94))
		if absf(scene._atmosphere.fog_amount-0.04) > 0.01:
			scene._atmosphere.set_fog(0.04)
			scene._atmosphere.set_haze(0.06)

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("flower still timed out"); quit(2))
	var tag := "now"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
		if arg.begins_with("--views="): only = arg.trim_prefix("--views=").split(",")
		if arg.begins_with("--wind="): wind = float(arg.trim_prefix("--wind="))
		if arg == "--chalk": chalk = true
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-flowers-%d/places.json" % Time.get_ticks_usec()
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
	# A drift of each kind round the centre, grass tufts between.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	data.begin_stroke()
	for k in range(Kit.KINDS.size()):
		var kind: String = Kit.KINDS[k]
		var at := CENTRE+Vector2.from_angle(TAU*k/Kit.KINDS.size())*(1.6 if kind != "sunflower" else 2.6)
		var count := 4 if kind == "sunflower" else 9
		for n in range(count):
			var p := at+Vector2(rng.randf_range(-0.55,0.55),rng.randf_range(-0.55,0.55))
			data.place(kind,p,rng.randf()*TAU,rng.randf_range(0.85,1.1))
	for n in range(70):
		var p := CENTRE+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.3,4.0)
		data.place("grass_tuft",p,rng.randf()*TAU,rng.randf_range(0.7,1.1))
	data.end_stroke()
	await editor.refresh(self)
	await frames(60)
	Input.warp_mouse(Vector2(4,4))
	var out := ProjectSettings.globalize_path("res://captures/flowers")
	DirAccess.make_dir_recursive_absolute(out)
	for view: String in VIEWS:
		if not only.is_empty() and not view in only: continue
		var v: Vector3 = VIEWS[view]
		# The rig eases toward its goal; glide there and hold.
		var look := Vector3(CENTRE.x,level+0.25,CENTRE.y)
		if view == "sunflower":
			var at := CENTRE+Vector2.from_angle(TAU*SUNFLOWERS/Kit.KINDS.size())*2.6
			look = Vector3(at.x,level+1.45,at.y)
		scene.camera_rig.glide_to(editor.terrain.to_global(look),v.z,v.y,v.x)
		await frames(150)
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png(out.path_join("%s-%s.png" % [tag,view]))
			print("FLOWERS still ",tag,"-",view)
	quit(0)
