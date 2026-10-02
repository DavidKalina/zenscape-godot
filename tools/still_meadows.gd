extends SceneTree
## Stills of the meadow types (docs/scenic/meadows.md): each meadow land
## formed in the cozy scene from a seed, as New world forms it, seen from the
## diorama overview and from a nearer, lower view across the meadow. Saves
## captures/meadows/<land>-<seed>-<view>.png. Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/still_meadows.gd -- --no-title [--lands=sunflowers,cosmos] [--seed=meadow-lark-2081] [--views=diorama,near] [--tag=name]
##   [--set=ground_calm:0] sets a ground uniform for A/B.
const Library = preload("res://scripts/world_library.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const OUT := "res://captures/meadows"
## View: [distance factor on the overview's own distance, polar, yaw offset, target lift].
const VIEWS := {"diorama":[1.0,0.82,0.0,0.0],"near":[0.5,1.05,0.4,0.6]}

var scene: Node3D

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	create_timer(600).timeout.connect(func() -> void: push_error("meadow stills timed out"); quit(2))
	var lands: Array = MeadowTypes.ORDER.map(func(id: String) -> String: return MeadowTypes.land_id(id))
	var seed_text := "meadow-lark-2081"
	var views: Array = VIEWS.keys()
	var tag := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lands="): lands = Array(arg.trim_prefix("--lands=").split(","))
		if arg.begins_with("--seed="): seed_text = arg.trim_prefix("--seed=")
		if arg.begins_with("--views="): views = Array(arg.trim_prefix("--views=").split(","))
		if arg.begins_with("--tag="): tag = "-"+arg.trim_prefix("--tag=")
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-meadows-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for land: String in lands:
		var started := Time.get_ticks_msec()
		await scene.places.open_land(land,Library.seed_value(seed_text))
		var formed := Time.get_ticks_msec()-started
		scene.world_clock.running = false
		for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
		# --set=ground_calm:0 and the like, on the ground's material, for A/B.
		for arg in OS.get_cmdline_user_args():
			if not arg.begins_with("--set="): continue
			var pair := arg.trim_prefix("--set=").split(":")
			var terrain: MeshInstance3D = scene._chunk_editor.terrain
			var material := terrain.material_override as ShaderMaterial
			if material == null: material = terrain.mesh.surface_get_material(0) as ShaderMaterial
			material.set_shader_parameter(pair[0],float(pair[1]))
			print("MEADOW set ",pair[0]," ",pair[1])
		await frames(90)
		var data: NativeTerrainData = scene._chunk_editor.data
		print("MEADOW %s formed %d ms, %d records, %s" % [land,formed,data.objects.size(),preload("res://scripts/biome_blend.gd").title(data._recipe_settings)])
		Input.warp_mouse(Vector2(4,4))
		scene._frame_diorama()
		var base := [scene.target,scene.distance,scene.polar,scene.yaw]
		for view: String in views:
			var v: Array = VIEWS[view]
			scene.target = base[0]+Vector3(0,float(v[3]),0)
			scene.distance = float(base[1])*float(v[0])
			scene.polar = float(v[1])
			scene.yaw = float(base[3])+float(v[2])
			scene._auto_orbit = false
			scene._update_camera()
			await frames(40)
			if DisplayServer.get_name() != "headless":
				var path := "%s/%s-%s-%s%s.png" % [ProjectSettings.globalize_path(OUT),land,seed_text,view,tag]
				root.get_texture().get_image().save_png(path)
				print("MEADOW still ",path)
	quit(0)
