extends "res://studies/character_study.gd"
## The aqueduct isle: the ruins archipelago's aqueduct station (studies/
## island_packs/ruins_archipelago.gd, station 2) on its own, dressed in the
## gothic ruin kit and the game's real look, played on foot as the pilot.
## Two floating islands of faceted turf over hanging rock keels in the open
## sky at the game's noon (its sky, sun, grade and the cumulus sea far
## below: scripts/landscape_lighting.gd, studies/celestial.gd, scripts/
## look_pass.gd, as the ruin kit gallery has them); the aqueduct striding
## from its head on the near island over 16 m of sky to the far one, its
## channel still carrying water that spills through the fallen span.
##
## The pilot, camera, moves, recorder and replays are the character
## study's (this extends it): the station's own boxes collide, invisible,
## under the stone (studies/aqueduct_isle_art.gd), so its proven routes
## hold. Round it, three landmarks on one axis (z 0): the aqueduct with
## the castellum at its head, the henge to the west (the kit's stone circle
## on a walled terrace, the kit's grand stair up its east face) and the
## heel stone out east; the gate on the far island. What stands collides
## as built (the kit's hulls). See docs/scenic/aqueduct-isle.md.
##   R            back to the start (the rubble slope's foot)
##   F5 F6 F7 F8  record, replay the station's recordings, older, all paths
##   F1 numbers · F2 feel · Esc mouse
##   ./run-aqueduct-isle.command
##   godot --path . res://studies/aqueduct_isle.tscn -- --no-title [--capture=out.png --at=x,y,z --look=x,y,z]
## --capture waits for the sky to settle, saves the view (from --at
## looking at --look, else the walker's camera) and quits; --place=x,y,z[,turn]
## starts the pilot there instead (turn: degrees from facing -z, clockwise).
const Art = preload("res://studies/aqueduct_isle_art.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const LandscapeLighting = preload("res://scripts/landscape_lighting.gd")
const Celestial = preload("res://studies/celestial.gd")
const LookPass = preload("res://scripts/look_pass.gd")
const Gallery = preload("res://studies/ruin_kit_gallery.gd")

## The station this is (its key in the pack).
const STATION := 2
const SEED := 11
## What stands round the aqueduct besides the landmarks: [kit piece,
## seed, weathered, world x, z, yaw (degrees)], each standing on the ground
## there and colliding as the kit built it. Only the gate on the far
## island, where the aqueduct came down, and its paving.
const PIECES := [
	["arch",20,0.35,100.0,-62.5,0.0],
	["floor",23,0.6,94.5,-58.5,15.0],
]
## The landmarks from the kit: the grand stair up the henge's terrace and
## the stone circle on it, both facing east along the isle's axis.
const STAIR_SEED := 31
const CIRCLE_SEED := 32
const LANDMARK_WEATHERED := 0.55
## The stepping stumps back from the far island (world x, z from, z to,
## top): an older arcade's piers broken off at the islands' height, their
## feet hanging in the sky; each collides as a clean box.
const STUMPS := [[92.0,-26.7,-28.7,30.4],[92.0,-30.6,-32.6,29.8],[92.0,-36.0,-38.4,30.2]]

var _environment: Environment
var _lighting: LandscapeLighting
var _display_fog: CanvasLayer = null
var _precipitation := {"ground_texture":null}
var _motion_time := 0.0
var _celestial: RefCounted
var _look: Node
var _looks := false
var _capture := ""
var _capture_at := Vector3.INF
var _capture_look := Vector3.INF
var _place := Vector4.INF
var art: Node3D
## The landmarks from the kit (their metadata drives the tests).
var stair: Node3D
var circle: Node3D

func _ready() -> void:
	pack = "ruins_archipelago"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): _capture = arg.get_slice("=",1)
		elif arg.begins_with("--at="): _capture_at = _vec(arg.get_slice("=",1))
		elif arg.begins_with("--look="): _capture_look = _vec(arg.get_slice("=",1))
		elif arg.begins_with("--place="):
			var p := arg.get_slice("=",1).split(",")
			_place = Vector4(float(p[0]),float(p[1]),float(p[2]),float(p[3]) if p.size() > 3 else 0.0)
	super._ready()
	await ready_to_walk
	_hud.visible = false
	if _place != Vector4.INF:
		var turn := deg_to_rad(_place.w)
		start = Vector3(_place.x,_place.y,_place.z)
		start_face = Vector2(sin(turn),-cos(turn))
		respawn()
	if _capture != "": _take_capture()

static func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]),float(p[1]),float(p[2]))

## The study's hint, without its station keys (one scene here).
func _build_ui() -> void:
	super._build_ui()
	for layer in get_children():
		if not layer is CanvasLayer: continue
		for child in layer.get_children():
			if child is Label and (child as Label).text.contains(" stations"):
				(child as Label).text = (child as Label).text.replace(" · 1-9 0 - = [ ] \\ stations","")

## The pack's station 2 alone: its spawn the start.
func _load_pack() -> void:
	super._load_pack()
	var kept: Array = []
	for station: Dictionary in stations:
		if station.key == STATION: kept.append(station)
	stations = kept
	start = kept[0].spawn
	start_face = kept[0].face
	_last_stood = start

## The game's look: its sky, sun and grade at noon, the cloud sea under the
## islands; headless, a plain sun (nothing to see, the routes the same).
func _build_light() -> void:
	_looks = DisplayServer.get_name() != "headless"
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.1
	camera.far = 4000.0
	add_child(camera)
	camera.current = true
	if not _looks:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-52.0,-35.0,0.0)
		add_child(sun)
		return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	_lighting = LandscapeLighting.new()
	add_child(_lighting)
	_lighting.setup(source)
	_environment = _lighting.environment
	for light in _lighting.lights: light.directional_shadow_max_distance = 140.0
	_celestial = Celestial.new()
	_celestial.setup(_lighting.lights)
	_celestial.cycling = false
	_celestial.cloud = Gallery.CLOUD
	_celestial.look.restore(Gallery.GAME_LOOK)
	var exposure: float = float(source.exposure)/1.08*float(_celestial.look.settings.exposure)
	_environment.tonemap_exposure = exposure
	RenderingServer.global_shader_parameter_set("zs_exposure",exposure)
	_look = LookPass.new()
	_look.setup(self)
	_look.apply_tier(_look.tier)
	preload("res://scripts/render_resolution.gd").attach(get_viewport())
	_celestial.set_phase(Gallery.DAY)

## The station's parts as clean, invisible collision (the islands' slabs
## and the moss pad left out: the islands are built), then the art.
func _build_room() -> void:
	for station: Dictionary in stations:
		for part: Array in station.parts:
			if part[0] == "box" and float(part[3]) <= Art.TOP+0.11: continue
			if part[0] == "label": continue
			_part(part)
	ground.pools.append_array(Art.pools())
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var near := Art.island(Art.NEAR,30.0,SEED,Art.base)
	near.name = "NearIsland"
	art.add_child(near)
	var far := Art.island(Art.FAR,20.0,SEED+1,Art.base)
	far.name = "FarIsland"
	art.add_child(far)
	var built: Dictionary = Art.aqueduct(SEED)
	art.add_child(built.node)
	for part: Array in built.parts: _part(part)
	var castellum: Dictionary = Art.castellum(SEED+2)
	art.add_child(castellum.node)
	for part: Array in castellum.parts: _part(part)
	art.add_child(Art.buttress(SEED+3))
	art.add_child(Art.rubble_heap(SEED+6))
	var avoid: Array[Rect2] = [Rect2(97.0,-56.0,6.0,66.0),Rect2(92.5,-3.5,5.0,8.5),Rect2(103.3,-12.5,2.0,7.0)]
	# The henge: its terrace, the grand stair up its east face, the stone
	# circle on top, the heel stone out east on the axis.
	var terrace: Dictionary = Art.terrace(SEED+7)
	art.add_child(terrace.node)
	for part: Array in terrace.parts: _part(part)
	stair = RuinKit.grand_stair(STAIR_SEED,LANDMARK_WEATHERED)
	stair.transform = Transform3D(Basis(Vector3.UP,PI*0.5),Art.STAIR_AT)
	art.add_child(stair)
	circle = RuinKit.stone_circle(CIRCLE_SEED,LANDMARK_WEATHERED)
	circle.transform = Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(Art.HENGE.x,Art.TOP+Art.TERRACE_TOP,Art.HENGE.y))
	art.add_child(circle)
	art.add_child(Art.heel_stone(SEED+8))
	var reach := Art.TERRACE_R+Art.TERRACE_WALL+2.4
	avoid.append(Rect2(Art.HENGE.x-reach,Art.HENGE.y-reach,reach*2.0,reach*2.0))
	avoid.append(Rect2(Art.STAIR_AT.x-5.6,-3.4,11.4,6.8))
	avoid.append(Rect2(Art.HEEL.x-1.0,Art.HEEL.y-0.7,2.0,1.4))
	for spec: Array in PIECES:
		var piece: Node3D = RuinKit.piece(spec[0],spec[1],spec[2])
		var x: float = spec[3]
		var z: float = spec[4]
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(spec[5]))),Vector3(x,Art.ground(x,z),z))
		art.add_child(piece)
		var box: AABB = piece.transform*(piece.get_node("Mesh") as MeshInstance3D).mesh.get_aabb()
		avoid.append(Rect2(box.position.x,box.position.z,box.size.x,box.size.z).grow(-0.3))
	art.add_child(_stumps())
	art.add_child(Art.growth(SEED+4,[near.get_meta("outline"),far.get_meta("outline")],avoid))
	var stones: Array[Rect2] = []
	art.add_child(Art.growth(SEED+9,[Art.terrace_outline(Art.TERRACE_R-0.8)],stones))
	print("aqueduct isle: %d triangles" % triangles(art))

## The stepping stumps (STUMPS): an older arcade's piers, coursed solid
## to their tops, mossed and tufted there, their feet broken off under the
## islands; collided as clean boxes.
func _stumps() -> Node3D:
	var b := RuinKit.Build.new(SEED+5,0.6,"Stumps")
	b.settle = Aqueduct.SETTLE
	for s: Array in STUMPS:
		var x: float = s[0]
		var z0: float = s[1]
		var z1: float = s[2]
		var high: float = float(s[3])-Art.TOP
		var foot := -7.0-absf(z0)*0.1
		var pose := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(x,Art.TOP,(z0+z1)*0.5))
		var line := func(_x: float) -> float: return high
		RuinKit._courses(b,pose,-absf(z1-z0)*0.5,absf(z1-z0)*0.5,foot,line,1.2,Callable(),0.55)
		b.frame = pose
		Art._broken_foot(b,0.0,foot)
		b.frame = Transform3D.IDENTITY
		for i in range(5):
			Art._tuft(b,Vector3(x+b.rng.randf_range(-0.9,0.9),Art.TOP+high,b.rng.randf_range(z1,z0)),0.3,4)
		_part(["box",Rect2(x-1.2,minf(z0,z1),2.4,absf(z1-z0)),Art.TOP+foot,float(s[3]),"lip"])
	var node := b.finish()
	node.get_node("Body").free()
	return node

## The triangles drawn under `node`.
static func triangles(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for s in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			count += (idx.size() if idx != null and idx is PackedInt32Array and idx.size() > 0 else v.size())/3
	for child in node.get_children(): count += triangles(child)
	return count

# --- Invisible station boxes ------------------------------------------------------

## A solid's collider only: the station's boxes stand under the stone.
func _solid(mesh: Mesh, shape: Shape3D, place: Transform3D, colour: String) -> StaticBody3D:
	var solid := StaticBody3D.new()
	solid.transform = place
	var collider := CollisionShape3D.new()
	collider.shape = shape
	solid.add_child(collider)
	add_child(solid)
	return solid

func _cap(at: Vector3, size: Vector3, radius: float) -> void:
	pass

func _label(at: Vector3, text: String, size: int) -> void:
	pass

# --- The look, each frame ---------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	_motion_time += delta
	if not _looks: return
	_celestial.advance(delta,true)
	RenderingServer.global_shader_parameter_set("zs_camera_position",camera.global_position)
	RenderingServer.global_shader_parameter_set("zs_motion_time",_motion_time)
	RenderingServer.global_shader_parameter_set("zs_flow_time",_motion_time)
	_look.update(camera,_celestial)
	RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(_celestial.cloud,0.0,Gallery.DECK.x,Gallery.DECK.y))

## Only the station's recordings replay here.
func _pack_runs() -> PackedStringArray:
	var found := PackedStringArray()
	for path in super._pack_runs():
		if int(Recording.read(path).get("station",0)) == STATION: found.append(path)
	return found

func _take_capture() -> void:
	for child in get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == 5: (child as CanvasLayer).visible = false
	if _capture_at != Vector3.INF:
		set_process(false)
		var look := _capture_look if _capture_look != Vector3.INF else Vector3(100.0,34.0,-20.0)
		camera.look_at_from_position(_capture_at,look)
		for i in range(240):
			_motion_time += 1.0/60.0
			_celestial.advance(1.0/60.0,true)
			RenderingServer.global_shader_parameter_set("zs_camera_position",camera.global_position)
			_look.update(camera,_celestial)
			RenderingServer.global_shader_parameter_set("zs_cloud",Vector4(_celestial.cloud,0.0,Gallery.DECK.x,Gallery.DECK.y))
			await get_tree().process_frame
	else:
		await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_capture)
	print("aqueduct isle: saved %s" % _capture)
	get_tree().quit()
