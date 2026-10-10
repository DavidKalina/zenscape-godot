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
## hold. Round it, on one axis (z 0): the aqueduct with the castellum at
## its head; to the west a hill rising in tiers of crag (the grand stair up
## onto the lower one, a way winding round it up a ramp and a ledge to the
## kit's stair into the crag), the stone circle crowning it, tilted with
## the summit, its sarsen over a bitten edge broken off and floating;
## floating stones and two islets round the isle (chains up, down and out);
## the heel stone out east; the gate on the far island. What stands
## collides as built (the kit's hulls), the ground as the game's terrain
## look. See docs/scenic/aqueduct-isle.md.
##
## The game's look (docs/scenic/aqueduct-isle-game-look.md): the turf grows
## the game's swaying shader grass and its meadow flowers (studies/
## aqueduct_isle_flora.gd), parted by the pilot's wake; the light, sky,
## air, weather and haze are the game's own rig (scripts/
## landscape_lighting.gd, studies/celestial.gd, studies/atmosphere.gd,
## studies/precipitation.gd, studies/display_fog.gd, scripts/look_pass.gd),
## dressed by the edit mode's look presets (scripts/scene_look_presets.gd,
## applied as the look editor applies them). Alpine morning to begin with.
##   R            back to the start (the rubble slope's foot)
##   L / Shift+L  next / previous look preset (its name shows a moment)
##   B            a strong gust front
##   F5 F6 F7 F8  record, replay the station's recordings, older, all paths
##   F1 numbers · F2 feel · Esc mouse
##   ./run-aqueduct-isle.command [--look=first_snow]
##   godot --path . res://studies/aqueduct_isle.tscn -- --no-title [--look=<preset id>] [--stone=mass] [--capture=out.png --at=x,y,z --look=x,y,z]
## --no-flora leaves the grass and flowers out (to compare cost).
## --look=<id> (or --preset=<id>) starts in that look preset; --look=x,y,z
## (three numbers) is the capture's look-at point. --capture waits for the
## sky to settle, saves the view (from --at looking at the point, else the
## walker's camera) and quits; --place=x,y,z[,turn] starts the pilot there
## instead (turn: degrees from facing -z, clockwise).
const Art = preload("res://studies/aqueduct_isle_art.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const LandscapeLighting = preload("res://scripts/landscape_lighting.gd")
const Celestial = preload("res://studies/celestial.gd")
const LookPass = preload("res://scripts/look_pass.gd")
const RuinGrowthPush = preload("res://scripts/ruin_growth_push.gd")
const Atmosphere = preload("res://studies/atmosphere.gd")
const Precipitation = preload("res://studies/precipitation.gd")
const DisplayFog = preload("res://studies/display_fog.gd")
const Flora = preload("res://studies/aqueduct_isle_flora.gd")
const PilotWake = preload("res://scripts/pilot_wake.gd")

## The station this is (its key in the pack).
const STATION := 2
## The look the isle opens in: the game's own for a new world
## (scripts/native_chunk_editor.gd forms one in Alpine morning).
const START_LOOK := "alpine_morning"
## How long a preset's name shows (s), and its fade.
const TOAST := 2.2
const TOAST_FADE := 0.6
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
const STEPS_SEED := 33
const LANDMARK_WEATHERED := 0.55
## The stair less ruined than the circle: a ceremonial way up, its cheeks
## standing (one torn low), no newel's cap fallen.
const STAIR_WEATHERED := 0.3
## The stepping stumps back from the far island (world x, z from, z to,
## top): an older arcade's piers broken off at the islands' height, their
## feet hanging in the sky; each collides as a clean box.
const STUMPS := [[92.0,-26.7,-28.7,30.4],[92.0,-30.6,-32.6,29.8],[92.0,-36.0,-38.4,30.2]]

var _environment: Environment
var _lighting: LandscapeLighting
var _source: Dictionary
## The game's look rig, as the game's scene has it (studies/fidelity.gd):
## the screen-space air (aerial haze, surface haze, light shafts), the
## weather (its surface weather: autumn, cold, snow cover, wet), the air
## (wind, breeze, gust fronts, mist and haze), the sky and its hour.
var _display_fog: CanvasLayer = null
var _precipitation: Node3D
var _atmosphere: Node3D
var _motion_time := 0.0
var _celestial: RefCounted
var _look: Node
## Rendered: the look pass, the screen-space air and the 1080p cap (not
## headless; the rig itself runs either way, so presets apply in tests).
var _looks := false
## The look preset on (scripts/scene_look_presets.gd), the order L steps
## through (the look editor's), and its name shown a moment on a change.
var look_id := START_LOOK
var _look_ids: Array = SceneLookPresets.PRESETS.keys()
var _look_toast: Label
var _toast_left := 0.0
## The grass and flowers (studies/aqueduct_isle_flora.gd), true once grown;
## the islands' ground bodies and outlines they grow on; the pilot's wake.
var flora: Node3D
var flora_ready := false
var _turf: Array = []
var _outlines: Array = []
var wake: Node
var _capture := ""
var _capture_at := Vector3.INF
var _capture_look := Vector3.INF
var _place := Vector4.INF
var art: Node3D
## The landmarks from the kit (their metadata drives the tests).
var stair: Node3D
var circle: Node3D
## The kit's stair up the crag from the upper tier's ledge.
var kit_stairs: Node3D

func _ready() -> void:
	pack = "ruins_archipelago"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): _capture = arg.get_slice("=",1)
		elif arg.begins_with("--at="): _capture_at = _vec(arg.get_slice("=",1))
		elif arg.begins_with("--look="):
			# Three numbers: the capture's look-at point; else a look preset.
			var value := arg.get_slice("=",1)
			if value.split(",").size() == 3: _capture_look = _vec(value)
			else: look_id = value
		elif arg.begins_with("--preset="): look_id = arg.get_slice("=",1)
		elif arg.begins_with("--stone="):
			# The ruin stone's look (scripts/ruin_stone_style.gd).
			var Style := preload("res://scripts/ruin_stone_style.gd")
			Style.use(arg.get_slice("=",1))
			Style.dress(RuinKit.materials().stone)
		elif arg.begins_with("--place="):
			var p := arg.get_slice("=",1).split(",")
			_place = Vector4(float(p[0]),float(p[1]),float(p[2]),float(p[3]) if p.size() > 3 else 0.0)
	if not SceneLookPresets.PRESETS.has(look_id):
		push_warning("aqueduct isle: no look preset '%s' (%s); %s instead" % [look_id,", ".join(_look_ids),START_LOOK])
		look_id = START_LOOK
	super._ready()
	await ready_to_walk
	_hud.visible = false
	if not OS.get_cmdline_user_args().has("--no-flora"): _grow()
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

## The game's look, set up as the game's scene sets it up (studies/
## fidelity.gd `_setup_environment` and `_ready`): its lighting and sky,
## the celestial rig on a still clock, the air and the weather; rendered,
## the look pass, the screen-space air and the 1080p cap. Then the look
## preset, applied as the look editor applies one.
func _build_light() -> void:
	_looks = DisplayServer.get_name() != "headless"
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.1
	camera.far = 4000.0
	add_child(camera)
	camera.current = true
	_source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	_lighting = LandscapeLighting.new()
	add_child(_lighting)
	_lighting.setup(_source)
	_environment = _lighting.environment
	for light in _lighting.lights: light.directional_shadow_max_distance = 140.0
	_celestial = Celestial.new()
	_celestial.setup(_lighting.lights)
	_celestial.cycling = false
	_celestial.look.changed.connect(_update_scene_look)
	# The air: no valley fog volume (that is the plate's, round the world's
	# middle); its ground the isle's, flat, so no summit cloud caps it.
	_atmosphere = Atmosphere.new()
	_atmosphere.name = "Atmosphere"
	add_child(_atmosphere)
	_atmosphere._environment = _environment
	_atmosphere._ground_min = Art.TOP
	_atmosphere._summit = Vector3(Art.HILL.x,Art.TOP,Art.HILL.y)
	# The weather: its surface weather and sky; its rain and snow fall on
	# the plate's ground map only, which has no ground here (see the doc).
	_precipitation = Precipitation.new()
	_precipitation.name = "Precipitation"
	add_child(_precipitation)
	var none := Node3D.new()
	_precipitation.setup(none,NoGround.new())
	none.free()
	_precipitation.leaves.visible = false
	_precipitation.weather_selected.connect(_atmosphere.set_weather_profile)
	if _looks:
		_look = LookPass.new()
		_look.setup(self)
		_look.apply_tier(_look.tier)
		preload("res://scripts/render_resolution.gd").attach(get_viewport())
		if RenderingServer.get_current_rendering_method() == "forward_plus" and not OS.get_cmdline_user_args().has("--no-fog"):
			_display_fog = DisplayFog.new()
			add_child(_display_fog)
			_display_fog.setup(_atmosphere,camera,_precipitation.ground_texture,_precipitation.stream_texture)
			# Its march is the plate's valley air (a box round the world's
			# middle); off the plate it marches nothing.
			_display_fog.material.set_shader_parameter("air_steps",0)
			_atmosphere.native_volume = false
			_environment.volumetric_fog_enabled = false
	_build_toast()
	apply_look(look_id,false)

## The plate's ground map with no ground on it (the isle stands off the
## plate): the weather's particles and the screen air's march stay off.
class NoGround extends RefCounted:
	func height_at(_x: float, _z: float) -> Variant: return null

## The look preset `id`, applied as the look editor's preset buttons apply
## one (SceneLookPresets.apply: the scene look's colours, the weather, the
## hour, the air's wind, mist, haze and rays, the sky's cloud, the
## surface weather), its name shown a moment when `show`.
func apply_look(id: String, show := true) -> void:
	if not SceneLookPresets.PRESETS.has(id): return
	look_id = id
	SceneLookPresets.apply(self,id)
	if _display_fog != null: _display_fog.forget()
	if show: _show_toast(str(SceneLookPresets.PRESETS[id].title))

## The next (or previous) preset in the look editor's order.
func step_look(by: int) -> void:
	var i := _look_ids.find(look_id)
	apply_look(_look_ids[posmod(i+by,_look_ids.size())])

## The scene look's exposure, as the game sets it on a change (studies/
## fidelity.gd `_update_scene_look`).
func _update_scene_look() -> void:
	_celestial.update_rig()
	var exposure: float = float(_source.exposure)/1.08*float(_celestial.look.settings.exposure)
	_environment.tonemap_exposure = exposure
	RenderingServer.global_shader_parameter_set("zs_exposure",exposure)

## SceneLookPresets.apply syncs the game's settings panel; there is none here.
func _sync_saved_controls() -> void:
	pass

func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LookToast"
	layer.layer = 6
	add_child(layer)
	_look_toast = Label.new()
	_look_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_look_toast.offset_top = 48.0
	_look_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_look_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_look_toast.add_theme_font_size_override("font_size",30)
	_look_toast.add_theme_color_override("font_outline_color",Color(0.0,0.0,0.0,0.55))
	_look_toast.add_theme_constant_override("outline_size",8)
	_look_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look_toast.modulate.a = 0.0
	layer.add_child(_look_toast)

func _show_toast(text: String) -> void:
	if _look_toast == null: return
	var description: String = ""
	for id: String in SceneLookPresets.PRESETS:
		if SceneLookPresets.PRESETS[id].title == text: description = SceneLookPresets.PRESETS[id].description
	_look_toast.text = text+("\n"+description if description != "" else "")
	_toast_left = TOAST+TOAST_FADE

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
	var near := Art.island(Art.NEAR,30.0,SEED,Art.ground,Art.TOP,true)
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
	# The hill: its walls and kerbs, the grand stair up its east face onto
	# the lower tier, the kit's stair up into the crag, the stone circle
	# crowning it (tilted with the summit, its sarsen over the bite gone);
	# the floating stones and islets round the isle; the heel stone out
	# east on the axis.
	art.add_child(Art.hill_walls(SEED+7))
	stair = RuinKit.grand_stair(STAIR_SEED,STAIR_WEATHERED)
	stair.transform = Transform3D(Basis(Vector3.UP,PI*0.5),Art.STAIR_AT)
	art.add_child(stair)
	kit_stairs = RuinKit.stairs(STEPS_SEED,STAIR_WEATHERED)
	kit_stairs.transform = Art.stairs_frame()
	art.add_child(kit_stairs)
	circle = RuinKit.stone_circle(CIRCLE_SEED,LANDMARK_WEATHERED,[Art.MISSING])
	circle.transform = Art.circle_transform()
	art.add_child(circle)
	art.add_child(Art.floating_stones(SEED+10))
	var islets: Array = Art.islets(SEED+11)
	for islet: Node3D in islets: art.add_child(islet)
	art.add_child(Art.heel_stone(SEED+8))
	for spec: Array in PIECES:
		var piece: Node3D = RuinKit.piece(spec[0],spec[1],spec[2])
		var x: float = spec[3]
		var z: float = spec[4]
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(spec[5]))),Vector3(x,Art.ground(x,z),z))
		art.add_child(piece)
	art.add_child(_stumps())
	# The turf the grass and flowers grow on (`_grow`, once it all stands
	# in the physics space): the islands' and islets' ground.
	for land: Node3D in [near,far]+islets:
		_turf.append(land.get_node("Body"))
		_outlines.append(land.get_meta("outline"))
	print("aqueduct isle: %d triangles" % triangles(art))

## The game's grass and flowers over the turf (studies/
## aqueduct_isle_flora.gd), once the ruins stand in the physics space
## (they grow round what stands).
func _grow() -> void:
	var began := Time.get_ticks_msec()
	flora = Flora.grow(SEED+4,get_world_3d().direct_space_state,_turf,_outlines)
	art.add_child(flora)
	flora_ready = true
	print("aqueduct isle: flora %s, %d instanced triangles, %d multimeshes, grown in %d ms" % [flora.get_meta("counts"),int(flora.get_meta("triangles")),flora.get_child_count(),Time.get_ticks_msec()-began])

## The study's pilot, with his wake through the grass and flowers (as the
## game's walker has it, scripts/wanderer_eye.gd).
func _build_pilot() -> void:
	super._build_pilot()
	wake = PilotWake.new()
	wake.name = "Wake"
	wake.motor = motor
	figure.add_child(wake)

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
	# SceneLookPresets.apply steps the scene once with no time: the look
	# only, never the pilot.
	if delta > 0.0: super._process(delta)
	_advance_look(delta)
	if _toast_left > 0.0 and _look_toast != null:
		_toast_left = maxf(_toast_left-delta,0.0)
		_look_toast.modulate.a = clampf(_toast_left/TOAST_FADE,0.0,1.0)

## One frame of the game's look, in the game's order (studies/fidelity.gd
## `_process`): the weather and its surface weather, the air (round the
## camera, as the kit gallery bounds its gust fronts), the sky, the
## screen-space air and the look pass; the pilot parting the ruin growth.
func _advance_look(delta: float) -> void:
	_motion_time += delta
	RenderingServer.global_shader_parameter_set("zs_motion_time",_motion_time)
	_precipitation.wind = _atmosphere.strength
	_celestial.shroud = _atmosphere.shroud
	_precipitation.advance(delta,false,_celestial)
	_atmosphere.cloud = _celestial.cloud
	_atmosphere.rain = maxf(_precipitation.state.x,_precipitation.state.y)
	_atmosphere.sun_height = _celestial.sun_height
	_atmosphere.sun_setting = fposmod(_celestial.phase,1.0) >= 0.5
	_atmosphere.cold = _celestial.cold
	var focus := camera.global_position
	_atmosphere.fronts.set_bounds(Vector2(focus.x,focus.z),36.0)
	_atmosphere.advance(delta,false)
	_celestial.wind = _atmosphere._air_strength
	_celestial.advance(delta,false)
	_atmosphere.set_inversion(_celestial.state.zs_inversion.x)
	_celestial.sample_sky_motion(_motion_time)
	RenderingServer.global_shader_parameter_set("zs_camera_position",focus)
	if _display_fog != null:
		_environment.volumetric_fog_enabled = false
		_display_fog.blend.set_shader_parameter("surface_fog_color",_celestial.surface_fog_color)
		_display_fog.blend.set_shader_parameter("aerial_sun_color",_celestial.aerial_sun_color)
		_display_fog.material.set_shader_parameter("fog_display",_celestial.fog_display)
		_display_fog.update_view()
	if _look != null: _look.update(camera,_celestial)
	if figure != null and delta > 0.0: RuinGrowthPush.stir(&"pilot",figure.global_position+Vector3.UP*1.1,delta)

## A strong gust front now, across what the camera looks at (B), in the
## air's own way.
func _send_gust() -> void:
	var focus := camera.global_position+(-camera.global_basis.z)*20.0
	var fronts: RefCounted = _atmosphere.fronts
	fronts.set_bounds(Vector2(focus.x,focus.z),24.0)
	for i in range(fronts.fronts.size()): fronts.fronts[i] = {}
	var way := Vector2(cos(_atmosphere._air_angle),sin(_atmosphere._air_angle))
	fronts.send(way,0.9,Atmosphere.breeze_air(_atmosphere._air_strength),1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_B:
				_send_gust()
				return
			KEY_L:
				step_look(-1 if (event as InputEventKey).shift_pressed else 1)
				return
	super._unhandled_input(event)

## Only the station's recordings replay here.
func _pack_runs() -> PackedStringArray:
	var found := PackedStringArray()
	for path in super._pack_runs():
		if int(Recording.read(path).get("station",0)) == STATION: found.append(path)
	return found

func _take_capture() -> void:
	for child in get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer in [5,6]: (child as CanvasLayer).visible = false
	if _capture_at != Vector3.INF:
		set_process(false)
		var look := _capture_look if _capture_look != Vector3.INF else Vector3(100.0,34.0,-20.0)
		camera.look_at_from_position(_capture_at,look)
		for i in range(240):
			_advance_look(1.0/60.0)
			await get_tree().process_frame
	else:
		await get_tree().create_timer(4.0).timeout
	# The frame's cost, measured over a second before the save.
	# The frame's cost: wall-clock frames with vsync off, over 120 frames.
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await RenderingServer.frame_post_draw
	var began := Time.get_ticks_usec()
	for i in range(120): await RenderingServer.frame_post_draw
	var frame_ms := (Time.get_ticks_usec()-began)/120000.0
	DisplayServer.window_set_vsync_mode(vsync)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_capture)
	print("aqueduct isle: saved %s (%s; %.2f ms a frame, vsync off; %d draw calls, %d primitives)" % [_capture,look_id,frame_ms,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()
