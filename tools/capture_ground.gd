extends SceneTree
## The ground, rendered: one world seen where its ground colour matters most,
## so a ground look pass can be judged before and after. Shots: the overview
## and a low look across the land by day, a close meadow under the densest
## grove, a lake shore (when the world has water), golden hour, and the
## close meadow again under a mood (--mood=, default golden_meadow), in
## autumn and in winter.
##
## World: --resume with --places=PATH (a COPY: the world saves into it) opens
## a saved world; else --seed N grows a generated one in a temporary folder.
## Options: --out=DIR, --weather=clear ("" leaves the world's), --hour=11, --golden=17.5, --only=NAME; --save keeps
## the world in its places file before the shots; --pond=DEPTH fills the
## deepest hollow with a still pond, and --lake sinks a small lake into
## the most open grass, for the shore shot (neither is saved); --diorama
## lays the same small test scene on a new world's plain every run (to resume it next time);
## --classic-form turns the round-five ground terms off on every surface for
## a before/after on the same world (docs/scenic/grass-look.md).
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_ground.gd \
##     -- --no-title --still-weather --resume --places=/private/tmp/zs-ground/places.json \
##     --out=/private/tmp/zs-ground/after
const TREES := ["tree","layered_tree","redwood","broadleaf","bigfoot_tree","birch","willow","juniper"]
var scene: Node3D
var out := "/private/tmp/zs-ground/out"
var hour := 11.0
var golden := 17.5
var mood := "golden_meadow"
var only := ""
var weather := "clear"
var classic_form := false
## The made lake's middle and radius (--lake), the shore shot's aim.
var lake := Vector3.ZERO
## --set=uniform:value pairs laid on every reference_surface material.
var overrides := {}
const FORM_UNIFORMS := ["ground_hue","ground_hollow","ground_crest","ground_steep","ground_shade"]

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func hold(at: float, count: int) -> void:
	for i in range(count):
		scene.world_clock.running = false
		scene.world_clock.set_time(scene.world_clock.day, at)
		await process_frame

func still(label: String) -> void:
	if classic_form or not overrides.is_empty():
		_classic(scene)
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280, 720): image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label + ".png")
	image.save_png(path)
	print("GROUND still ", path)

## Every reference_surface material in the scene with the round-five terms off.
func _classic(node: Node) -> void:
	if node is GeometryInstance3D:
		var materials: Array = [node.material_override]
		var mesh: Mesh = null
		if node is MeshInstance3D: mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null: mesh = node.multimesh.mesh
		if mesh != null:
			for i in range(mesh.get_surface_count()): materials.append(mesh.surface_get_material(i))
		if node is MeshInstance3D:
			for i in range(node.get_surface_override_material_count()): materials.append(node.get_surface_override_material(i))
		for material in materials:
			if material is ShaderMaterial and material.shader != null and material.shader.resource_path.ends_with("reference_surface.gdshader"):
				if classic_form:
					for key in FORM_UNIFORMS: material.set_shader_parameter(key, 0.0)
				for key in overrides: material.set_shader_parameter(key, overrides[key])
	for child in node.get_children(): _classic(child)

## Fills the plate's deepest hollow `depth` m with a still pond (a dry
## crater becomes a lake), so the shore shot has one. Not saved.
func _pond(editor: Node, depth: float) -> void:
	var data = editor.data
	var low := Vector2.ZERO
	var lowest := INF
	for z in range(-26, 27):
		for x in range(-26, 27):
			var p := Vector2(x, z) * 0.5
			var h: Variant = data.height_at(p.x, p.y)
			if h != null and float(h) < lowest:
				lowest = float(h)
				low = p
	print("GROUND pond at %s level %.2f: %s" % [low, lowest + depth, data.add_pond(low, lowest + depth)])
	editor.force_refresh()
	await frames(120)

## Sinks a small lake into the most open stretch of grass (furthest from
## any object, off the slopes) and fills it, so the shore shot has a meadow
## shore. Not saved.
func _lake(editor: Node) -> void:
	var data = editor.data
	var best := Vector2.ZERO
	var room := -1.0
	for z in range(-20, 21):
		for x in range(-20, 21):
			var p := Vector2(x, z) * 0.5
			var h: Variant = data.height_at(p.x, p.y)
			if h == null: continue
			var flat := true
			for d in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
				var o: Variant = data.height_at(p.x + d.x, p.y + d.y)
				if o == null or absf(float(o) - float(h)) > 0.4: flat = false
			if not flat: continue
			var near := INF
			for item: Dictionary in data.objects: near = minf(near, p.distance_to(Vector2(item.x, item.z)))
			if near > room:
				room = near
				best = p
	var radius := clampf(room * 0.9, 2.5, 4.5)
	var rim := float(data.height_at(best.x, best.y))
	data.begin_stroke()
	for i in range(8): data.brush(best, radius, 0.22, "lower", 0.0)
	data.end_stroke()
	lake = Vector3(best.x, best.y, radius)
	print("GROUND lake at %s radius %.1f (room %.1f): %s" % [best, radius, room, data.add_pond(best, rim - 0.25)])
	editor.force_refresh()
	await frames(150)

## A small test diorama on the open plain, the same every run: a hill (a
## crest and its slopes), a lake in a sunk bowl (a hollow and a shore), a
## mixed grove, a few lone trees, so each ground term has its place.
func _diorama(editor: Node) -> void:
	var data = editor.data
	data.begin_stroke()
	for i in range(10): data.brush(Vector2(-6.0, -5.0), 6.5, 0.32, "raise", 0.0)
	for i in range(4): data.brush(Vector2(-1.0, -9.0), 4.0, 0.3, "raise", 0.0)
	for i in range(9): data.brush(Vector2(5.0, 4.0), 5.0, 0.26, "lower", 0.0)
	var grove := [["broadleaf", -3.0, 6.0, 1.5], ["broadleaf", -5.2, 7.4, 1.3], ["tree", -1.4, 8.0, 1.0], ["tree", -4.0, 9.2, 0.9], ["birch", -6.6, 5.4, 1.1], ["tree", -2.2, 10.2, 1.1], ["broadleaf", -7.4, 8.6, 1.4], ["tree", -0.4, 6.2, 0.8],
		["layered_tree", 9.0, -6.0, 0.5], ["birch", 2.0, -2.0, 1.0], ["tree", 10.5, 9.5, 1.0], ["willow", 8.6, 6.8, 1.0]]
	for t: Array in grove: data.place(t[0], Vector2(t[1], t[2]), float(t[1]) * 1.7, t[3])
	data.end_stroke()
	var rim := INF
	for a in range(16):
		var p := Vector2(5.0, 4.0) + Vector2.from_angle(a * TAU / 16.0) * 4.6
		rim = minf(rim, float(data.height_at(p.x, p.y)))
	print("GROUND diorama lake level %.2f: %s" % [rim - 0.2, data.add_pond(Vector2(5.0, 4.0), rim - 0.2)])
	lake = Vector3(5.0, 4.0, 4.0)
	editor.force_refresh()
	await frames(240)

func view(target: Vector3, distance: float, yaw: float, polar: float) -> void:
	scene.target = target
	scene.distance = distance
	scene.yaw = yaw
	scene.polar = polar
	scene._update_camera()

func wanted(label: String) -> bool:
	if only == "": return true
	for part in only.split(","):
		if label.begins_with(part): return true
	return false

## The plate point (local x, z) at the heart of the densest grove.
func grove(data) -> Vector2:
	var best := Vector2.ZERO
	var most := -1
	for item: Dictionary in data.objects:
		if str(item.asset) not in TREES: continue
		var at := Vector2(item.x, item.z)
		var count := 0
		for other: Dictionary in data.objects:
			if str(other.asset) in TREES and Vector2(other.x, other.z).distance_to(at) < 4.0: count += 1
		if count > most:
			most = count
			best = at
	return best

## A plate point on dry ground beside the most open water, or null.
func shore(texture: Texture2D) -> Variant:
	if texture == null: return null
	var image := texture.get_image()
	var best: Variant = null
	var most := 0
	for z in range(8, 120, 2):
		for x in range(8, 120, 2):
			var here := image.get_pixel(x, z)
			if here.g < -100.0 or (here.a > -100.0 and here.a > here.g): continue
			var wet := 0
			for dz in range(-8, 9, 2):
				for dx in range(-8, 9, 2):
					var other := image.get_pixel(x + dx, z + dz)
					if other.a > -100.0 and other.a > other.g + 0.05: wet += 1
			if wet > most and wet < 50:
				most = wet
				best = Vector2(x + 0.5, z + 0.5) / 4.0 - Vector2.ONE * 16.0
	return best

func run() -> void:
	var places := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--places="): places = argument.trim_prefix("--places=")
		elif argument.begins_with("--hour="): hour = float(argument.trim_prefix("--hour="))
		elif argument.begins_with("--golden="): golden = float(argument.trim_prefix("--golden="))
		elif argument.begins_with("--mood="): mood = argument.trim_prefix("--mood=")
		elif argument.begins_with("--only="): only = argument.trim_prefix("--only=")
		elif argument == "--classic-form": classic_form = true
		elif argument.begins_with("--weather="): weather = argument.trim_prefix("--weather=")
		elif argument.begins_with("--set="):
			var pair := argument.trim_prefix("--set=").split(":")
			overrides[pair[0]] = float(pair[1])
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(840).timeout.connect(func() -> void: push_error("ground capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture", true)
	scene.set_meta("no_title", true)
	if places.is_empty():
		scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
		DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	else:
		scene.places_path = places
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	await frames(30)
	while true:
		while scene.places.busy or scene._chunk_editor.forming or scene._growth.terrain < 0.995: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	if "--save" in OS.get_cmdline_user_args():
		print("GROUND saved ", scene.places.save_places(), " ", scene.places_path)
	if weather != "":
		scene.mood_look.pin("weather", weather, false)
		await frames(10)
	var editor: Node = scene._chunk_editor
	var terrain: Node3D = editor.terrain
	var data = editor.data
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pond="): await _pond(editor, float(argument.trim_prefix("--pond=")))
		if argument == "--lake": await _lake(editor)
		if argument == "--diorama": await _diorama(editor)
	var at := func(p: Vector2) -> Vector3:
		var h: Variant = data.height_at(p.x, p.y)
		return terrain.to_global(Vector3(p.x, float(h) if h != null else 0.0, p.y))
	scene._overview()
	scene._update_camera()
	var top := [scene.target, scene.distance, scene.yaw, scene.polar]
	var trees: Vector2 = grove(data)
	var water: Variant = shore(scene._precipitation.ground_texture)
	if lake.z > 0.0: water = Vector2(lake.x, lake.y)
	print("GROUND grove %s shore %s scale %s" % [trees, water, terrain.global_basis.get_scale()])
	var shade: Node = editor.get("ground_shade")
	if shade != null:
		var most := 0.0
		for value in shade.field: most = maxf(most, value)
		print("GROUND shade: %d trees, %d bakes, last %.2f ms, deepest %.2f" % [shade._trees.size() / 3, shade.bakes, shade.last_bake_usec / 1000.0, most])
	await hold(hour, 240)
	if wanted("overview"):
		view(top[0], top[1], top[2], top[3])
		await hold(hour, 90)
		await still("overview")
	if wanted("low"):
		view(top[0], top[1] * 0.62, top[2], 1.30)
		await hold(hour, 90)
		await still("low")
	if wanted("grove"):
		view(at.call(trees), 11.0, top[2] + 0.5, 1.05)
		await hold(hour, 90)
		await still("grove")
	if water != null and wanted("shore"):
		view(at.call(water), 9.0, top[2] - 0.4, 1.0)
		await hold(hour, 90)
		await still("shore")
	if wanted("golden"):
		view(top[0], top[1], top[2], top[3])
		await hold(golden, 150)
		await still("golden-overview")
		view(top[0], top[1] * 0.62, top[2], 1.30)
		await hold(golden, 90)
		await still("golden-low")
	if wanted("mood") and mood != "":
		scene.mood_look.choose(mood, false)
		await frames(20)
		view(top[0], top[1], top[2], top[3])
		await frames(150)
		await still("mood-overview")
		view(at.call(trees), 11.0, top[2] + 0.5, 1.05)
		await frames(90)
		await still("mood-grove")
	for season in ["autumn", "winter"]:
		if not wanted(season): continue
		scene.mood_look.pin("season", season, false)
		await frames(30)
		view(top[0], top[1], top[2], top[3])
		await frames(200)
		await still(season + "-overview")
		view(at.call(trees), 11.0, top[2] + 0.5, 1.05)
		await frames(90)
		await still(season + "-grove")
	print("GROUND done")
	quit(0)
