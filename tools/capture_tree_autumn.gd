extends SceneTree
## Stills of emerged stands through the autumn (emergence.gd `_stand_autumn`,
## zs_autumn_stand_paint). Opens the Genesis plain, wishes a forest over most
## of the plate, runs emergence to the end at once, then pins the season to
## summer, mid-autumn and late autumn and saves the same views of each.
## Rendered, so a window opens for the run (about a minute):
##   Godot --path . --script res://tools/capture_tree_autumn.gd \
##     -- --plain-seed 7 --stills=/private/tmp/zs-look/autumn-after
## Saves go to /private/tmp/zs-film, never the player's places.
const SEASONS := {"summer":0.35,"mid":0.60,"late":0.715}
## [name, target (terrain-local), distance, polar°, yaw°].
const VIEWS := [
	["overview",Vector3(0.0,0.5,0.0),30.0,52.0,-10.0],
	["grove",Vector3(-3.0,0.8,-1.0),15.0,55.0,-25.0],
]
var scene: Node3D
var editor: NativeChunkEditor
var stills_dir := "/private/tmp/zs-look/autumn"

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
	scene.places_path = "/private/tmp/zs-film/places-autumn-%d.json" % Time.get_ticks_usec()
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
	await editor.refresh(self)
	await frames(30)
	var trees := {}
	for item: Dictionary in data.objects:
		if item.get("source") == "emerged" and item.has("autumn"): trees[item.asset] = trees.get(item.asset,0)+1
	print("AUTUMN trees ",JSON.stringify(trees))
	for season: String in SEASONS:
		scene.world_clock.season_override = SEASONS[season]
		await frames(3)
		var surface: RefCounted = scene._precipitation.surface_weather
		surface.autumn = surface.target_autumn
		surface.cold = surface.target_cold
		await frames(20)
		surface.autumn = surface.target_autumn
		for view: Array in VIEWS:
			scene.target = editor.terrain.to_global(view[1])
			scene.distance = view[2]
			scene.polar = deg_to_rad(view[3])
			scene.yaw = deg_to_rad(view[4])
			for i in range(6):
				scene._update_camera()
				await process_frame
			save("%s_%s" % [season,view[0]],"autumn %.2f" % surface.autumn)
	scene.queue_free()
	await process_frame
	quit()

func save(name: String, note: String) -> void:
	var image := root.get_texture().get_image()
	if image == null: return
	image.save_jpg(stills_dir.path_join(name+".jpg"),0.9)
	print("STILL ",name," ",note)
