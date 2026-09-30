extends SceneTree
## Film the rare variants (docs/scenic/life.md, "Rare variants") on the Genesis
## plain: a golden koi in a koi pond, an albino and a blue frog beside a common
## one, the white stag then a doe at a forest edge at dawn, and a double
## rainbow. The odds are forced by patching the constants in the loaded scripts
## before the world opens (film only); the life clock runs --pace times faster.
##   Godot --windowed --resolution 1280x720 --path . --write-movie /tmp/zs-film/04-variants-koi.avi \
##     -s res://tools/film_variants.gd -- --shot=koi|frogs|stag|bow [--pace=10] [--warm=40] [--hold=20]
## Headless it prints what the shot would find. The clip starts with --warm
## seconds of waiting for arrivals; trim them with ffmpeg -ss.
var shot := "koi"
var pace := 10.0
var warm := 40.0
var hold := 20.0
var scene: Node3D
var life: Node3D
var editor: NativeChunkEditor
var frame := 0
var yaw := 0.6
var polar := 1.0
var distance := 3.0
var focus := Vector3.ZERO
var lift := 0.15
var bow_camera := false
var bow_position := Vector3.ZERO
var bow_look := Vector3.ZERO

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.trim_prefix("--shot=")
		if arg.begins_with("--pace="): pace = float(arg.trim_prefix("--pace="))
		if arg.begins_with("--warm="): warm = float(arg.trim_prefix("--warm="))
		if arg.begins_with("--hold="): hold = float(arg.trim_prefix("--hold="))
	run.call_deferred()

## Rewrite a script's source and recompile it, so the world built next uses it.
func patch(path: String, pairs: Array) -> void:
	var script: GDScript = load(path)
	var code := script.source_code
	for pair: Array in pairs:
		assert(code.contains(pair[0]),"patch target missing: "+pair[0])
		code = code.replace(pair[0],pair[1])
	script.source_code = code
	script.reload()

func run() -> void:
	patch("res://scripts/land_life.gd",[
		["var company: Array = Models.FISH_PONDS[int(_pond_hash(site)*Models.FISH_PONDS.size())]","var company: Array = Models.FISH_PONDS[0]"],
		["const KOI_GOLDEN_CHANCE := 0.015","const KOI_GOLDEN_CHANCE := 0.3"],
		["const FROG_ALBINO_CHANCE := 0.015","const FROG_ALBINO_CHANCE := 0.3"],
		["const FROG_BLUE_CHANCE := 0.01","const FROG_BLUE_CHANCE := 0.3"],
		["var roll := _hash(site,22)","var roll := float(site.slot%3)*0.4+0.05"],
	])
	patch("res://scripts/life_moments.gd",[
		["life._rng.randf() < DEER_STAG_CHANCE","Engine.get_meta(\"film_stag\",false)"],
		["const DEER_STAY := Vector2(25.0,45.0)","const DEER_STAY := Vector2(7.0,9.0)"],
		["const BOW_DOUBLE_CHANCE := 0.08","const BOW_DOUBLE_CHANCE := 1.0"],
	])
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-variants-film-%d/places.json" % Time.get_ticks_usec()
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	while scene._growth.terrain < 0.995: await process_frame
	scene._notice.visible = false
	if scene.places.get("cover") != null: scene.places.cover.visible = false
	if scene.creation_palette != null: scene.creation_palette.visible = false
	scene.apply_scene_mood("Alpine daylight")
	scene._precipitation.set_weather(scene._precipitation.PRESET_NAMES.find("clear"),true)
	for layer: Node in scene.find_children("*","CanvasLayer",true,false): layer.visible = false
	life = scene.land_life
	clean()
	editor.set_process_input(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene._celestial.set_phase(0.28 if shot == "stag" else (0.31 if shot == "bow" else 0.42))
	life.pace = pace
	await build_world()
	match shot:
		"koi": await film_koi()
		"frogs": await film_frogs()
		"stag": await film_stag()
		"bow": await film_bow()
	print("FILM end frames=",frame)
	scene.queue_free()
	await process_frame
	quit()

func build_world() -> void:
	var data := editor.data
	data.begin_stroke()
	# The frogs shot keeps one pond, so its three frogs are slots 0 to 2.
	for basin: Vector2 in ([Vector2(-3.0,2.0)] if shot == "frogs" else [Vector2(-3.0,2.0),Vector2(4.0,-6.0)]):
		for _pass in range(6): data.brush(basin,4.2,0.3,"lower",0.0)
		data.add_pond(basin,float(data.ground_height(basin))+0.75)
	var basin := Vector2(-3.0,2.0)
	for i in range(14):
		var angle := -1.2+float(i)*0.19
		var p := basin+Vector2.from_angle(angle)*(6.0+0.8*sin(float(i)*2.3))
		var id := data.place("broadleaf" if i%3 else "tree",p,float(i),0.9)
		if id >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	await editor.refresh(self)

## Hide the UI and the God Hand so only the world shows.
func clean() -> void:
	for layer: Node in scene.find_children("*","CanvasLayer",true,false): layer.visible = false
	for control: Node in scene.find_children("*","Control",true,false):
		if is_instance_valid(control): (control as Control).visible = false
	for node: Node in scene.find_children("*","Node3D",true,false):
		if not is_instance_valid(node): continue
		var script: Script = node.get_script()
		if script != null and script.resource_path.ends_with("god_hand.gd"):
			(node as Node3D).visible = false
			node.set_process(false)

## One frame: orbit the camera round `focus`, then let the frame render.
func step() -> void:
	scene.target = focus+Vector3.UP*lift
	scene.distance = distance
	scene.polar = polar
	scene.yaw = yaw
	scene._update_camera()
	if frame%30 == 0: clean()
	await process_frame
	frame += 1

func wait_for(what: Callable, limit: float) -> bool:
	var frames := int(limit*30.0)
	for i in range(frames):
		if what.call(): return true
		await step()
	return false

func variant_fish() -> Array:
	return life.present("fish").filter(func(s: Dictionary) -> bool: return str(s.look).begins_with("golden"))

func film_koi() -> void:
	var found: bool = await wait_for(func() -> bool: return not variant_fish().is_empty(),warm)
	print("FILM koi golden=%d fish=%d found=%s" % [variant_fish().size(),life.present("fish").size(),found])
	for i in range(int(hold*30.0)):
		var golden := variant_fish()
		if not golden.is_empty(): focus = life.to_global((golden[0] as Dictionary).p)
		yaw += 0.004
		distance = 2.2
		polar = 0.95
		await step()

func frogs_with_kinds() -> Dictionary:
	var kinds := {}
	for site: Dictionary in life.present("frog"): kinds[site.species] = true
	return kinds

## The blue frog's pond: the blue frog and every frog within FROG_CLUSTER m.
const FROG_CLUSTER := 4.5
func frog_cluster() -> Array:
	var frogs: Array = life.present("frog")
	var blue: Array = frogs.filter(func(s: Dictionary) -> bool: return s.species == "blue")
	if blue.is_empty(): return []
	var anchor: Vector3 = life.to_global((blue[0] as Dictionary).p)
	return frogs.filter(func(s: Dictionary) -> bool: return life.to_global(s.p).distance_to(anchor) < FROG_CLUSTER)

## Blue, albino and an ordinary frog in one pond.
func frogs_ready() -> bool:
	var kinds := {}
	for site: Dictionary in frog_cluster(): kinds[site.species] = true
	return kinds.has("blue") and kinds.has("albino") and kinds.size() >= 3

func film_frogs() -> void:
	var found: bool = await wait_for(frogs_ready,warm)
	print("FILM frogs ready at frame %d found=%s" % [frame,found])
	for site: Dictionary in frog_cluster(): print("FILM frog ",site.species," ",life.to_global(site.p))
	for i in range(int(hold*30.0)):
		var sum := Vector3.ZERO
		var cluster := frog_cluster()
		for site: Dictionary in cluster: sum += life.to_global(site.p)
		if not cluster.is_empty(): focus = focus.lerp(sum/cluster.size(),0.04) if i > 0 else sum/cluster.size()
		yaw += 0.003
		distance = 4.5
		polar = 1.05
		await step()

func deer_root() -> Node3D:
	return life.moments._deer[0].root

func film_stag() -> void:
	var edges_ready: bool = await wait_for(func() -> bool: return life.survey != null and not life.survey.forest_edges.is_empty(),warm)
	print("FILM stag edges=",edges_ready)
	life.pace = 1.0
	var open_side := 0.0
	for white in [true,false]:
		Engine.set_meta("film_stag",white)
		print("FILM deer forced=",life.moments.force("deer")," white=",white)
		var seen := 0
		# Camera on the open side of the edge, a little round to the front.
		var into: Vector2 = life.moments._deer_state.into
		open_side = atan2(-into.x,-into.y)+0.6
		while life.moments.showing().deer and seen < 4000:
			focus = deer_root().global_position
			yaw = open_side
			distance = 4.2
			polar = 1.3
			lift = 0.6
			await step()
			seen += 1
		for i in range(45): await step()

func film_bow() -> void:
	var pond: Vector3 = editor.terrain.to_global(Vector3(-3.0,float(editor.data.ground_height(Vector2(-3.0,2.0))),2.0))
	await wait_for(func() -> bool: return life.survey != null,warm)
	life.pace = 1.0
	print("FILM bow forced=",life.moments.force("rainbow"))
	var sun: Vector3 = scene._celestial.state.get("zs_sun_direction",Vector3.UP)
	var away := Vector3(-sun.x,0.0,-sun.z).normalized()
	print("FILM bow sun=",sun," away=",away)
	# The camera sits over the pond looking away from the sun, tilted up: the
	# orbit's target is ahead of it and the polar angle is past level.
	var look := (away*cos(BOW_PITCH)+Vector3.UP*sin(BOW_PITCH)).normalized()
	focus = pond+Vector3(0,1.6,0)+look*10.0
	lift = 0.0
	distance = 10.0
	polar = acos(-look.y)
	yaw = atan2(-look.x,-look.z)
	for i in range(BOW_FRAMES): await step()

const BOW_PITCH := 0.21
const BOW_FRAMES := 2700
