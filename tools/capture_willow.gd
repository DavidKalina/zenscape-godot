extends SceneTree
## Stills of the hero willow in game (tools/blender_trees/willow.py). Opens the
## Genesis plain, wishes a forest over most of the plate, runs emergence to the
## end at once, turns the emerged trees nearest the middle into willows (so they
## appear every run, whatever the emergence salt), pins summer and saves views
## from the diorama angles and one low look.
## Rendered, so a window opens for the run (about a minute):
##   Godot --path . --script res://tools/capture_willow.gd \
##     -- --plain-seed 7 --stills=/private/tmp/zs-look/willow
## Saves go to /private/tmp/zs-film, never the player's places.
const WILLOWS := 5
const WILLOW_TINTS := ["86a050","7b9a58","93a95e","6f8f5f"]
## [name, distance, polar°, yaw°] around the willows' middle.
const VIEWS := [
	["diorama45",13.0,45.0,-15.0],
	["diorama60",13.0,60.0,20.0],
	["close",7.0,50.0,-40.0],
	["low",8.0,78.0,10.0],
	["overview",30.0,55.0,0.0],
]
var scene: Node3D
var editor: NativeChunkEditor
var stills_dir := "/private/tmp/zs-look/willow"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stills="): stills_dir = arg.trim_prefix("--stills=")
	DirAccess.make_dir_recursive_absolute(stills_dir)
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute("/private/tmp/zs-film")
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film/places-willow-%d.json" % Time.get_ticks_usec()
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready:
		await process_frame
	editor = scene._chunk_editor
	while scene._growth.terrain < 0.995:
		await process_frame
	scene._notice.visible = false
	if scene.places.get("cover") != null: scene.places.cover.visible = false
	scene.set_looking(true)
	scene.world_clock.running = false
	scene._celestial.set_phase(0.36)
	scene.season_glide = false
	scene.world_clock.season_override = 0.35
	var emergence: RefCounted = editor.emergence
	emergence.plan_on_worker = false
	var data: RefCounted = editor.data
	for z in range(data.MEADOW_CELLS):
		for x in range(data.MEADOW_CELLS):
			if data.meadow_position(x,z).length() < 11.0:
				emergence.intent.forest[z*data.MEADOW_CELLS+x] = 1.0
	emergence.intent.revision += 1
	emergence.on_region_changed(Rect2(-12,-12,24,24))
	for n in range(480): emergence.advance(0.25)
	var trees := []
	for item: Dictionary in data.objects:
		if item.get("source") == "emerged" and item.asset in ["broadleaf","birch","layered_tree","willow"]:
			trees.append(item)
	trees.sort_custom(func(a,b): return Vector2(a.x,a.z).length() < Vector2(b.x,b.z).length())
	var middle := Vector2.ZERO
	var count := mini(WILLOWS,trees.size())
	var sizes: Dictionary = preload("res://scripts/emergence.gd").KIND_SIZE
	for n in range(count):
		var item: Dictionary = trees[n]
		item.scale = float(item.scale)/float(sizes.get(item.asset,1.0))*float(sizes.willow)
		item.asset = "willow"
		item.tint = NativeObjectPose.encode_tint(Color(WILLOW_TINTS[n % WILLOW_TINTS.size()]).srgb_to_linear())
		middle += Vector2(item.x,item.z)/count
	var kinds := {}
	for item: Dictionary in data.objects:
		if item.get("source") == "emerged": kinds[item.asset] = kinds.get(item.asset,0)+1
	print("WILLOW trees ",JSON.stringify(kinds)," middle ",middle)
	await editor.refresh(self)
	await frames(30)
	var ground: Variant = data.ground_height(middle)
	var target := Vector3(middle.x,(float(ground) if ground != null else 0.3)+0.8,middle.y)
	for view: Array in VIEWS:
		scene.target = editor.terrain.to_global(target if view[0] != "overview" else Vector3(0.5,0.5,0.5))
		scene.distance = view[1]
		scene.polar = deg_to_rad(view[2])
		scene.yaw = deg_to_rad(view[3])
		for i in range(6):
			scene._update_camera()
			await process_frame
		save(view[0])
	scene.queue_free()
	await process_frame
	quit()

func save(name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null: return
	image.save_jpg(stills_dir.path_join(name+".jpg"),0.9)
	print("STILL ",name)
