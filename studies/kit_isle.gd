extends "res://studies/character_study.gd"
## A kit isle (docs/scenic/kit-isle-shared.md): a hand-built sky island of
## the gothic ruin kit, in the game's real look, played on foot as the
## pilot and flown in the game's plane. The base every kit isle scene
## extends (studies/aqueduct_isle.gd and its motifs: bell_spires_isle.gd,
## cloister_tarn_isle.gd, sundered_gorge_isle.gd, colonnade_spine_isle.gd).
##
## What it gives every isle: the character study's pilot, camera, moves
## and recorder (this extends it), his wake through the grass; the game's
## look rig (its lighting and sky, the celestial rig, the air, the weather,
## the screen-space air and the look pass: scripts/landscape_lighting.gd,
## studies/celestial.gd, studies/atmosphere.gd, studies/precipitation.gd,
## studies/display_fog.gd, scripts/look_pass.gd) dressed by the edit
## mode's look presets (L, --look=); the plane (F) with its bump and
## set-down; the lodestone and its shard; the grass and flowers
## (scripts/kit_isle/kit_flora.gd), the sky round it and its life; the live
## rope bridges underfoot (scripts/kit_isle/deck_ground.gd: the deck, the
## hand ropes, the tread; the plane shudders them). The ground and rock are
## the kit isles' one look (scripts/kit_isle/kit_look.gd, kit_land.gd).
##
## An isle answers its hooks: `_build_art` (its land and ruins, registering
## its ground with `add_turf`), `isle_name`, `isle_top` (its datum: the
## rays down, the plane's cloud floor), `isle_summit` (the air's summit),
## `flora_site` and `flora_seed` (its ground for the plants), `lode_rest_at`
## and `lode_hint` (where the lodestone rests), `sky_script` and
## `life_script` (its sky and life, each extending the kit's), and its own
## start in `_load_pack`. It may also answer `plane_mask` (what the plane
## bumps off), `_fly_tick` (its own step each flown frame), `_shard_arch`
## (an arch on the shard or not) and `_start_in_plane` (how --fly starts).
##
##   R            back to the start
##   L / Shift+L  next / previous look preset (its name shows a moment)
##   B            a strong gust front
##   F (pad Y)    into the game's plane, already flying a little above and
##                ahead; in it, back on foot on safe ground nearby (and
##                skimming the turf braking slow sets him down there)
##   F1 numbers · F2 feel · Esc mouse
## --no-flora leaves the grass and flowers out (to compare cost).
## Life (scripts/kit_isle/kit_life.gd): undergrowth, butterflies, fireflies,
## songbirds on the stones, the wind made visible and the on-foot tokens;
## --no-undergrowth, --no-butterflies, --no-fireflies, --no-birds,
## --no-wind-life, --no-tokens leave each out, --no-life all of it. The sky
## (studies/aqueduct_isle_sky.gd): --no-sky and its parts.
## --fly starts in the plane; --drift=<x> scales its knife-edge drift
## (scripts/sky_plane.gd).
## In the plane, R3 (Tab) locks onto the isle when in reach: the plane flies
## itself round it on a ring (scripts/isle_lock.gd), the camera framing it,
## and the isle's card shows (scripts/isle_splash.gd, `isle_card`); A D draw
## the ring in and out, W S lower and raise it, R3 (Tab) lets go. Out of
## reach R3 is the camera reset still. --lock starts locked (with --fly);
## --card-hold keeps the card up (captures).
## The lodestone (docs/design/isle-lodestone.md): a stone holding a world in
## miniature (scripts/lodestone.gd) hums where the isle rests it (E, pad A
## picks it up); --stone-plane seats it in the stone plane, whose wing
## seams then point to a shard floating far off (--target=x,y,z). --carry
## starts with it; --lode-at=<platform name> rests it elsewhere; --no-lode
## leaves it out; --pickup picks it up at once if he stands by it.
## --look=<id> (or --preset=<id>) starts in that look preset; --look=x,y,z
## (three numbers) is the capture's look-at point. --capture waits for the
## sky to settle, saves the view (from --at looking at the point, else the
## walker's camera) and quits; --place=x,y,z[,turn] starts the pilot there
## instead (turn: degrees from facing -z, clockwise). Without --at it waits
## --capture-wait=<s> (4): flying, that many seconds flown (`flown`), so it
## is the same moment run to run however slow the first frames are.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const LandscapeLighting = preload("res://scripts/landscape_lighting.gd")
const Celestial = preload("res://studies/celestial.gd")
const LookPass = preload("res://scripts/look_pass.gd")
const RuinGrowthPush = preload("res://scripts/ruin_growth_push.gd")
const Atmosphere = preload("res://studies/atmosphere.gd")
const Precipitation = preload("res://studies/precipitation.gd")
const DisplayFog = preload("res://studies/display_fog.gd")
const PilotWake = preload("res://scripts/pilot_wake.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const StoneFigure = preload("res://scripts/stone_plane_figure.gd")
const NoseCompass = preload("res://scripts/nose_compass.gd")
const Lodestone = preload("res://scripts/lodestone.gd")
const MomentsHud = preload("res://scripts/moments_hud.gd")
const IsleSky = preload("res://studies/aqueduct_isle_sky.gd")
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const DeckGround = preload("res://scripts/kit_isle/deck_ground.gd")
const RopeBridge = preload("res://scripts/rope_bridge.gd")
const GlideAir = preload("res://scripts/glide_air.gd")
const IsleLock = preload("res://scripts/isle_lock.gd")
const IsleSplash = preload("res://scripts/isle_splash.gd")

## The look the isle opens in: the game's own for a new world
## (scripts/native_chunk_editor.gd forms one in Alpine morning).
const START_LOOK := "alpine_morning"
## How long a preset's name shows (s), and its fade.
const TOAST := 2.2
const TOAST_FADE := 0.6
## The kit isles' common datum (world y): their turf near it.
const TOP := 30.0

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
## A kit stair the isle stands (its tests read it), or null.
var kit_stairs: Node3D

## The plane (F): the islands' and islets' ground bodies also sit on
## TURF_LAYER, so the plane skims the turf as the game's plane skims its
## heightfield, and is bumped off everything else that stands (and the
## turf's sides and keels). Boarding puts it BOARD_AHEAD m ahead of the
## pilot along the view and BOARD_UP m up, flying at cruise. The cloud
## cushion lifts from FLOOR_BELOW m under the turf. The bump is the ruin
## kit gallery's (scripts/ruin_bump.gd): the plane's wing-wide body,
## turned with its bank and roll, BUMP_KEEP of its speed kept.
const TURF_LAYER := 1 << 11
const BOARD_AHEAD := 5.0
const BOARD_UP := 3.0
const FLOOR_BELOW := 50.0
const BUMP_BODY := Vector3(PlaneFigure.SPAN,0.3,1.2)
const BUMP_KEEP := 0.55
## A face whose normal points up past FLOOR_NORMAL is a top the plane rides
## over (lifted up to RIDE_LIFT m in RIDE_STEP m steps) rather than bumps.
const FLOOR_NORMAL := 0.6
const RIDE_LIFT := 1.2
const RIDE_STEP := 0.1
## The mouse's turn (radians a pixel, the game's LOOK), and the game's
## double tap for a barrel roll (scripts/wanderer_eye.gd DOUBLE_TAP).
const FLY_LOOK := 0.0025
const DOUBLE_TAP := 0.3
## The right stick's turn of the chase camera (radians a second at full
## push) and how long a look holds before it swings back behind the plane
## (s): the game's (scripts/wanderer_eye.gd STICK_LOOK, PLANE_LINGER).
const STICK_LOOK := 2.4
## Locked onto the isle, the camera framing it (_frame_isle): m out from
## the isle and up from the chase's eye, the share of its aim drawn to the
## isle's middle, and m over the isle's top it aims at.
const FRAME_OUT := 6.0
const FRAME_UP := 1.5
const FRAME_AIM := 0.5
const FRAME_AIM_UP := 6.0
## The hint's line while locked, and the offer to lock while in reach.
const LOCK_HINT := "Circling %s  ·  A D draw the ring in and out  ·  W S lower and raise it  ·  boost, brake, knife edge and rolls as ever  ·  R3 / Tab let go"
const LOCK_OFFER := "R3 / Tab  circle %s"
const LOOK_LINGER := 2.5
## Setting down: skimming the turf with Brake held under TOUCH_SPEED m/s
## for TOUCH_HOLD s puts the pilot on foot there. Getting out anywhere, he
## stands on the nearest open turf within SAFE_REACH m of the plane.
const TOUCH_SPEED := 9.5
const TOUCH_HOLD := 0.5
const TOUCH_GAP := 0.25
const SAFE_REACH := 40.0
const FOOT_HINT := "F (pad Y)  fly the plane from here  ·  R3 camera back behind"
const FLY_HINT := "Flying  ·  %.0f m/s  ·  bumps %d\nA D bank and turn  ·  W S pitch (W nose down)  ·  mouse steers  ·  Space boost  ·  Shift brake  ·  hold Q E (LB RB) knife edge, + A D to drift  ·  Q Q or E E quick, or click: barrel roll\nF (pad Y) back on foot nearby  ·  skim the turf braking to set down  ·  R start on foot  ·  L / Shift+L look  ·  B gust  ·  hold right mouse or the right stick to look round  ·  R3 camera back behind"
var flying := false
## The plane's flight (a SkyPlane), its figure, the chase camera, the
## bumps since boarding.
var plane: RefCounted
var plane_figure: Node3D
## The plane's sound, as the game's (scripts/glide_air.gd): the wind past
## it, the propeller's hum, a flap, a blip as it touches the turf.
var air: Node3D
var _flaps_heard := 0
var chase: RefCounted
var bumps := 0
var _fly_look := Vector2.ZERO
var _roll_asked := 0.0
var _tap_dir := 0.0
var _tap_at := -100000
var _touch := 0.0
var _off_ground := INF
var _turf_rids: Array[RID] = []
var _bump_query: PhysicsShapeQueryParameters3D
var _ground_ray: PhysicsRayQueryParameters3D
var _foot_hint: Label
var _switch_hint: Label
## Locking onto the isle from the plane (R3 / Tab, scripts/isle_lock.gd) and
## its card (scripts/isle_splash.gd).
var isle_lock: RefCounted = null
var splash: CanvasLayer = null
var _lock_stick := Vector2.ZERO

## The lodestone (docs/design/isle-lodestone.md). It rests LODE_HOVER m over
## the top of the floating stone LODE_PLATFORM (studies/aqueduct_isle_art.gd
## `platforms`), LODE_SCALE times its hand size so it is found; it hums from
## HUM_FAR m, fully at HUM_NEAR. Standing on that stone within PICK_REACH m
## (across), E or pad A picks it up: the pilot raises his mitts, it floats
## down into them over PICKUP s and the camera pushes in over PUSH s; kept,
## it rides at his side (CARRY_AT: right, up, forward, at CARRY_SCALE).
## Boarding with it seats it in the stone plane; its compass points at
## TARGET (a shard floating far off) and arriving within ARRIVE m chimes and
## flashes (again once he has been ARRIVE_AGAIN m away).
const LODE_MINI := "sundered"
const LODE_HOVER := 0.85
const LODE_SCALE := 1.5
const HUM_FAR := 9.0
const HUM_NEAR := 1.6
const PICK_REACH := 1.5
const PICKUP := 1.1
const PUSH := 1.8
const HOLD_UP := 0.42
const ARMS := Vector3(2.9,0.2,0.3)
const CARRY_AT := Vector3(0.36,0.82,0.02)
const CARRY_SCALE := 0.45
const TARGET := Vector3(250.0,TOP+24.0,-230.0)
const ARRIVE := 30.0
const ARRIVE_AGAIN := 90.0
const CAM_BACK := 0.5
## The game's wooden plane (the default) or the stone plane (--stone-plane).
var stone_plane := false
## The compass arrow on the wooden plane's nose while the stone is seated.
var _nose: Node3D = null
var lodestone: Node3D = null
## "resting" on its stone, "inspecting" (held up), "carried", "seated" in
## the plane.
var lode_state := "resting"
var lode_rest := Vector3.ZERO
var lode_target := TARGET
var arrived := false
var shard: Node3D
var _lode_at := ""
var _no_lode := false
var _carry := false
var _pick := 0.0
var _pick_from_cam := Transform3D.IDENTITY
var _cam_back := 0.0
var _cam_from := Transform3D.IDENTITY
var _arms_down := 0.0
var _moments: CanvasLayer
var _shard_flash: MeshInstance3D
var _shard_material: ShaderMaterial
var _flash_left := 0.0
## Captures: the eye in the plane's frame (--plane-eye=x,y,z), not the chase.
var _plane_eye := Vector3.INF
## A capture from the walker's (or chase) camera waits this long (s;
## --capture-wait=<s>).
var _capture_wait := 4.0
## Seconds flown (fly_step's deltas): a capture from the plane waits for
## this to reach --capture-wait, so it is the same moment run to run
## however slow the first frames are.
var flown := 0.0

func _ready() -> void:
	pack = "ruins_archipelago"
	for arg in preload("res://scripts/launch_args.gd").user_args():
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
		elif arg == "--wood-plane": stone_plane = false
		elif arg == "--stone-plane": stone_plane = true
		elif arg == "--no-lode": _no_lode = true
		elif arg == "--carry": _carry = true
		elif arg.begins_with("--lode-at="): _lode_at = arg.get_slice("=",1)
		elif arg.begins_with("--target="): lode_target = _vec(arg.get_slice("=",1))
		elif arg.begins_with("--plane-eye="): _plane_eye = _vec(arg.get_slice("=",1))
		elif arg.begins_with("--capture-wait="): _capture_wait = float(arg.get_slice("=",1))
		elif arg.begins_with("--place="):
			var p := arg.get_slice("=",1).split(",")
			_place = Vector4(float(p[0]),float(p[1]),float(p[2]),float(p[3]) if p.size() > 3 else 0.0)
	if not SceneLookPresets.PRESETS.has(look_id):
		push_warning("kit isle: no look preset '%s' (%s); %s instead" % [look_id,", ".join(_look_ids),START_LOOK])
		look_id = START_LOOK
	super._ready()
	await ready_to_walk
	_hud.visible = false
	if not preload("res://scripts/launch_args.gd").user_args().has("--no-flora"): _grow()
	if not _no_lode: _build_lode()
	_add_sky()
	_add_life()
	if _place != Vector4.INF:
		var turn := deg_to_rad(_place.w)
		start = Vector3(_place.x,_place.y,_place.z)
		start_face = Vector2(sin(turn),-cos(turn))
		respawn()
	_start_in_plane()
	if flying and preload("res://scripts/launch_args.gd").user_args().has("--lock"): toggle_lock()
	if preload("res://scripts/launch_args.gd").user_args().has("--pickup"):
		for i in range(30): tick(1.0/60.0)
		pick_up()
	if _capture != "": _take_capture()

## The start in the plane (--fly); an isle may start in the air elsewhere.
func _start_in_plane() -> void:
	if preload("res://scripts/launch_args.gd").user_args().has("--fly"): board()

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
				_foot_hint = child
				_switch_hint = Label.new()
				_switch_hint.name = "SwitchHint"
				_switch_hint.text = FOOT_HINT
				_switch_hint.add_theme_font_size_override("font_size",17)
				_switch_hint.add_theme_color_override("font_color",Color("fbf6ea"))
				_switch_hint.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
				_switch_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
				_switch_hint.offset_left = -760.0
				_switch_hint.offset_right = 760.0
				_switch_hint.offset_top = -170.0
				_switch_hint.offset_bottom = -40.0
				_switch_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_switch_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				layer.add_child(_switch_hint)
				return

## No pack: the isle is built whole (`_build_room`); an isle sets its
## start (and `lost`, the height a fall respawns from) in its own.
func _load_pack() -> void:
	stations = []
	_last_stood = start

## The character study's own pack load (its stations, its spawn), for an
## isle that is a pack's station.
func _load_station_pack() -> void:
	super._load_pack()

## The character study's recordings of the pack.
func _station_runs() -> PackedStringArray:
	return super._pack_runs()

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
	_atmosphere._ground_min = isle_top()
	_atmosphere._summit = isle_summit()
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
		if RenderingServer.get_current_rendering_method() == "forward_plus" and not preload("res://scripts/launch_args.gd").user_args().has("--no-fog"):
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

## The isle built whole.
func _build_room() -> void:
	_build_art()

# --- The isle's hooks --------------------------------------------------------------------

## The isle's land and ruins under `art` (a Node3D child named "Art"); each
## land's ground registered with `add_turf`.
func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)

## The isle's name, for its log lines.
func isle_name() -> String:
	return "kit isle"

## The isle's card as the plane locks onto it (scripts/isle_splash.gd):
## its name, a line of what it is, and what there is to find on it with
## how much has been found. Placeholders until the isles are named.
func isle_card() -> Dictionary:
	return {"name":isle_name().capitalize(),"epithet":"An isle adrift over the cloud sea",
		"finds":[["wildflower","Glyphs",0,7],["crystal","Lodestones",0,1],["bridge","Hidden ways",0,3]]}

## The isle's datum (world y): the turf near it; the rays down read from
## over it, the plane's cloud floor hangs FLOOR_BELOW under it.
func isle_top() -> float:
	return TOP

## The air's summit (studies/atmosphere.gd): the isle's high point.
func isle_summit() -> Vector3:
	return Vector3(0.0,isle_top(),0.0)

## The isle's ground as the plants read it (its worn paths, its water).
func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(isle_top())

## The grass and flowers' seed.
func flora_seed() -> int:
	return 15

## Where the lodestone rests (world: its middle), or INF for none.
func lode_rest_at() -> Vector3:
	return Vector3.INF

## The on-foot hint's line while the lodestone rests out of reach.
func lode_hint() -> String:
	return "A lodestone hums somewhere on the isle: find it"

## The view a capture looks at when only --at is given.
func capture_look() -> Vector3:
	return Vector3(100.0,34.0,-20.0)

## The sky round the isle (studies/aqueduct_isle_sky.gd or its subclass).
func sky_script() -> Script:
	return IsleSky

## The isle's life (scripts/kit_isle/kit_life.gd or its subclass).
func life_script() -> Script:
	return KitLife

## Registers `land` (a KitLand island, turf, spire top...: its "Body" and
## any bodies holding its cliffs' prisms) as turf: the plants grow on it,
## the plane skims it, the pilot is set down on it; `outline` its (x, z)
## polygon (its meta "outline" if not given). `cliffs` false: only its
## "Body" (the prisms under its crags stay stone the plane bumps off).
func add_turf(land: Node3D, outline: Variant = null, cliffs := true) -> void:
	for turf: StaticBody3D in (KitLand.turf_bodies(land) if cliffs else [land.get_node("Body")]):
		turf.collision_layer |= TURF_LAYER
		_turf_rids.append(turf.get_rid())
		_turf.append(turf)
	_outlines.append(outline if outline != null else land.get_meta("outline"))

## The game's grass and flowers over the turf (scripts/kit_isle/
## kit_flora.gd), once the ruins stand in the physics space (they grow
## round what stands).
func _grow() -> void:
	var began := Time.get_ticks_msec()
	flora = KitFlora.grow(flora_seed(),get_world_3d().direct_space_state,_turf,_outlines,flora_site())
	art.add_child(flora)
	flora_ready = true
	print("%s: flora %s, %d instanced triangles, %d multimeshes, grown in %d ms" % [isle_name(),flora.get_meta("counts"),int(flora.get_meta("triangles")),flora.get_child_count(),Time.get_ticks_msec()-began])

## The study's pilot, with his wake through the grass and flowers (as the
## game's walker has it, scripts/wanderer_eye.gd).
## His ground reads the physics space and the live rope bridges' decks
## (scripts/kit_isle/deck_ground.gd), his steps kept between their hand
## ropes.
func _build_pilot() -> void:
	super._build_pilot()
	wake = PilotWake.new()
	wake.name = "Wake"
	wake.motor = motor
	figure.add_child(wake)
	var decks := DeckGround.new(get_world_3d().direct_space_state,motor)
	decks.frame = self
	decks.pools = ground.pools
	ground = decks
	motor.water = ground.water_callable()
	motor.wall = ground.wall_callable()

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
	if delta > 0.0:
		if not flying: super._process(delta)
		elif walk_ready and not scripted: fly_step(delta,_fly_input(delta))
	_advance_look(delta)
	_lode_frame(delta)
	if life != null: life.advance(delta)
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
	if flying and delta > 0.0: RuinGrowthPush.stir(&"plane",plane_figure.global_position,delta)
	elif figure != null and delta > 0.0: RuinGrowthPush.stir(&"pilot",figure.global_position+Vector3.UP*1.1,delta)

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
	if Pad.pressed(event,&"camera_reset"):
		if not (flying and toggle_lock()): reset_camera()
		return
	if lode_state == "inspecting":
		_inspect_event(event)
		return
	if not flying and can_pick() and ((event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_E) or Pad.pressed(event,&"walk_jump")):
		pick_up()
		Input.action_release(&"walk_jump")
		return
	if flying:
		_fly_event(event)
		return
	if (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F) or Pad.pressed(event,&"fly_land"):
		if not _name_panel.visible and not _tune.visible: board()
		return
	super._unhandled_input(event)

# --- The plane (F) ----------------------------------------------------------------

## Into the game's plane (scripts/sky_plane.gd) from on foot: it is already
## flying at cruise, BOARD_AHEAD m ahead of the pilot along the view and
## BOARD_UP m up (higher if that is in stone), under the game's chase
## camera (scripts/glide_camera.gd), the pilot in its cockpit.
func board() -> void:
	if flying or not walk_ready: return
	if not _replay.is_empty(): _end_replay()
	var way := PilotMotor.forward(_yaw)
	var at := motor.feet+Vector3(way.x,0.0,way.y)*BOARD_AHEAD+Vector3.UP*BOARD_UP
	plane = SkyPlane.new()
	plane.floor_y = isle_top()-FLOOR_BELOW
	plane.launch(at,_yaw,SkyPlane.CRUISE_SPEED,false)
	for i in range(12):
		if not _in_stone(): break
		plane.position += Vector3.UP*2.0
	plane.velocity = plane.forward()*float(plane.speed)
	plane_figure = StoneFigure.new() if stone_plane else PlaneFigure.new()
	plane_figure.name = "Plane"
	add_child(plane_figure)
	plane_figure.show_pilot(true)
	if stone_plane: plane_figure.target = lode_target
	plane_figure.reset(plane)
	plane_figure._mark.visible = false
	if lode_state == "carried":
		lode_state = "seated"
		if stone_plane:
			plane_figure.seat(lodestone)
			_moments.pop("The lodestone seats in the plane",1.6)
		else:
			lodestone.visible = false
			_nose = NoseCompass.new()
			_nose.target = lode_target
			plane_figure.add_child(_nose)
			_moments.pop("The lodestone wakes the compass",1.6)
	chase = GlideCamera.new()
	chase.reset(plane,camera.global_position,camera.fov)
	chase.linger = LOOK_LINGER
	if air == null:
		air = GlideAir.new()
		add_child(air)
	air.start()
	_flaps_heard = int(plane.flaps)
	figure.visible = false
	flying = true
	bumps = 0
	_touch = 0.0
	_off_ground = INF
	_fly_look = Vector2.ZERO
	_roll_asked = 0.0
	if _foot_hint != null: _foot_hint.visible = false
	_show_fly_hint()

## Out of the plane, on foot on the nearest open turf to it (`at`, if
## given, instead), facing the way it flew.
func leave_plane(at := Vector3.INF) -> void:
	if not flying: return
	var spot := safe_ground(plane.position) if at == Vector3.INF else at
	var face := Vector2(-sin(float(plane.heading)),-cos(float(plane.heading)))
	flying = false
	release_lock()
	if lode_state == "seated":
		# He takes the stone with him.
		if stone_plane and plane_figure.stone != null:
			var lode: Node3D = plane_figure.unseat()
			add_child(lode)
		lodestone.visible = true
		lode_state = "carried"
	plane_figure.queue_free()
	plane_figure = null
	_nose = null
	if air != null: air.stop()
	figure.visible = true
	camera.fov = FOV
	if _foot_hint != null: _foot_hint.visible = true
	if _switch_hint != null: _switch_hint.text = _foot_text()
	place(spot,face)
	_last_stood = spot

## Where the pilot can stand nearest `near`: open turf (not steep, room
## for him over it), the nearest ring of points round `near` first, the
## top nearest its height in a ring; failing all, where he last stood.
func safe_ground(near: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	for ring in range(int(SAFE_REACH/2.0)+1):
		var r := ring*2.0
		var n := 1 if ring == 0 else 8+ring*4
		var best := Vector3.INF
		for i in range(n):
			var a := TAU*float(i)/float(n)
			var top := _turf_top(space,near.x+cos(a)*r,near.z+sin(a)*r)
			if top == Vector3.INF or not _room_for_pilot(space,top): continue
			if best == Vector3.INF or absf(top.y-near.y) < absf(best.y-near.y): best = top
		if best != Vector3.INF: return best
	return _last_stood

## The turf's walkable top at (x, z), or INF.
func _turf_top(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x,isle_top()+80.0,z),Vector3(x,isle_top()-80.0,z),TURF_LAYER)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.75: return Vector3.INF
	return hit.position

func _room_for_pilot(space: PhysicsDirectSpaceState3D, feet: Vector3) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = 0.35
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	for up: float in [0.9,1.6]:
		query.transform = Transform3D(Basis.IDENTITY,feet+Vector3.UP*up)
		if not space.intersect_shape(query,1).is_empty(): return false
	return true

## The camera back to its default (R3): on foot behind the pilot at the
## default pitch (the distance springs back out by itself); in the plane
## the chase camera's free look let go, so it swings back behind.
func reset_camera() -> void:
	if flying:
		# Its `free` is set by name: `chase.free =` parses as Object.free.
		chase.set(&"free",Vector2.ZERO)
		return
	_yaw = motor.facing
	_polar = CAM_POLAR
	_look_rest = 0.0

## Locks onto the isle if the plane is in reach of it, or lets go if
## locked (R3 / Tab in the plane); false if neither (out of reach). Locking
## puts the chase camera's free look back and shows the isle's card.
func toggle_lock() -> bool:
	if not flying: return false
	if isle_lock == null:
		isle_lock = IsleLock.new()
		var circle := isle_circle()
		isle_lock.set_isle(Vector3(circle.x,0.0,circle.y),circle.z,isle_top())
	if isle_lock.locked:
		release_lock()
		return true
	if not isle_lock.in_reach(plane.position): return false
	isle_lock.lock(plane.position,plane.velocity)
	chase.set(&"free",Vector2.ZERO)
	if splash == null:
		splash = IsleSplash.new()
		splash.name = "IsleSplash"
		add_child(splash)
	if preload("res://scripts/launch_args.gd").user_args().has("--card-hold"): splash.hold = 3600.0
	splash.show_card(isle_card())
	_show_fly_hint()
	return true

## Lets go of the isle (the camera eases back behind, the card fades).
func release_lock() -> void:
	if isle_lock == null or not isle_lock.locked: return
	isle_lock.release()
	if splash != null: splash.fade()
	if chase != null: chase.set(&"free",Vector2.ZERO)

## The circle round the isle's outlines: (x, z) its middle, z its radius.
func isle_circle() -> Vector3:
	var lo := Vector2(INF,INF)
	var hi := -lo
	for outline: PackedVector2Array in _outlines:
		for p in outline:
			lo = lo.min(p)
			hi = hi.max(p)
	if lo.x == INF: return Vector3(isle_summit().x,isle_summit().z,40.0)
	var mid := (lo+hi)*0.5
	var reach := 0.0
	for outline: PackedVector2Array in _outlines:
		for p in outline: reach = maxf(reach,p.distance_to(mid))
	return Vector3(mid.x,mid.y,reach)

## The lock's step, and the camera framing the isle while locked: eased
## out FRAME_OUT m and up FRAME_UP m from the chase's eye, its aim drawn
## FRAME_AIM of the way to the isle's middle (FRAME_AIM_UP m over its top),
## so the plane rides the near side of the view with the isle turning past.
func _frame_isle(delta: float) -> void:
	if isle_lock == null: return
	var was: bool = isle_lock.locked
	isle_lock.advance(delta,plane.position,_lock_stick)
	_lock_stick = Vector2.ZERO
	if was and not isle_lock.locked:
		if splash != null: splash.fade()
		chase.set(&"free",Vector2.ZERO)
	var f := smoothstep(0.0,1.0,float(isle_lock.framing))
	if f <= 0.0: return
	var out: Vector3 = plane.position-isle_lock.centre
	out.y = 0.0
	out = out.normalized()
	camera.global_position = chase.eye+(out*FRAME_OUT+Vector3.UP*FRAME_UP)*f
	var mid: Vector3 = isle_lock.centre+Vector3.UP*FRAME_AIM_UP
	# Aimed no lower than halfway down to the plane's height, so the plane
	# stays in the view's lower part rather than off its foot.
	mid.y = maxf(mid.y,lerpf(mid.y,float(plane.position.y),0.6))
	camera.look_at(chase.look.lerp(mid,FRAME_AIM*f),Vector3.UP)

## The stick, mouse, throttle, knife edge and roll asked this frame, as
## the game's plane reads them (the ruin kit gallery's fly mode). The
## right stick (or the mouse with the right button held) swings the chase
## camera round the plane, as the game's does (scripts/wanderer_eye.gd).
func _fly_input(delta: float) -> Dictionary:
	var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	if right != Vector2.ZERO: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*delta)
	chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var lean := clampf(keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left"),-1.0,1.0)
	var input := {"turn":stick.x,"pitch":stick.y,"look":_fly_look,"lean":lean,
		"boost":Input.get_action_strength(&"fly_boost"),"brake":Input.get_action_strength(&"fly_brake"),"roll":_roll_asked}
	_fly_look = Vector2.ZERO
	_roll_asked = 0.0
	_lock_stick = stick
	if isle_lock != null and isle_lock.locked: return isle_lock.steer(input,plane)
	return input

## One frame of flight: the plane stepped over the turf, bumped off what
## stands, drawn, the chase camera behind it; skimming the turf braking
## slow for TOUCH_HOLD s sets the pilot down there.
func fly_step(delta: float, input: Dictionary) -> void:
	flown += delta
	var was: Vector3 = plane.position
	var ground := Callable(self,"plane_ground")
	plane.step(delta,input,ground)
	_bump(was)
	_fly_tick(delta)
	if stone_plane: plane_figure.target = lode_target
	plane_figure.update(delta,plane,0.0,ground,false)
	if _nose != null:
		_nose.target = lode_target
		_nose.step(delta)
	plane_figure._mark.visible = false
	_check_arrival()
	air.advance(delta,plane.velocity,float(plane.hang),0.0)
	air.engine(float(plane.speed),float(plane.throttle))
	if int(plane.flaps) != _flaps_heard:
		_flaps_heard = int(plane.flaps)
		air.flap()
	chase.step(delta,plane,0.0,_inside_stone)
	camera.global_position = chase.eye
	camera.look_at(chase.look,Vector3.UP)
	_frame_isle(delta)
	camera.rotate_object_local(Vector3.FORWARD,chase.roll)
	camera.fov = chase.fov
	if _plane_eye != Vector3.INF:
		camera.global_position = plane_figure.global_transform*_plane_eye
		camera.look_at(plane_figure.global_transform*Vector3(0.0,0.05,-0.05),plane_figure.global_basis.y)
	_show_fly_hint()
	# Riding a top lifts it clear only frames it touches, so a skim counts
	# on through TOUCH_GAP s off it.
	var braking := float(input.get("brake",0.0)) > 0.5
	# Coming down onto a top after a while off it, the wheels' blip.
	if plane.skimming and _off_ground > TOUCH_GAP*2.0 and _off_ground != INF: air.blip()
	_off_ground = 0.0 if plane.skimming else _off_ground+delta
	_touch = _touch+delta if _off_ground <= TOUCH_GAP and braking and float(plane.speed) < TOUCH_SPEED else 0.0
	if _touch >= TOUCH_HOLD: leave_plane()
	elif flying: RopeBridge.flown_by(plane.position,plane.velocity)

## The isle's own step each flown frame, after the plane's step and bump
## (none here).
func _fly_tick(_delta: float) -> void:
	pass

## Puts the plane (flying) at `at` on `heading`, at cruise, the chase camera
## behind it (the quick tests' starts, the tests).
func fly_from(at: Vector3, heading: float) -> void:
	if not flying: return
	plane.launch(at,heading,SkyPlane.CRUISE_SPEED,false)
	plane.velocity = plane.forward()*float(plane.speed)
	plane_figure.reset(plane)
	chase = GlideCamera.new()
	chase.reset(plane,at-plane.forward()*7.0+Vector3.UP*2.0,camera.fov)
	chase.linger = LOOK_LINGER

func _show_fly_hint() -> void:
	if _switch_hint == null or plane == null: return
	var text := FLY_HINT % [float(plane.speed),bumps]
	if isle_lock != null and isle_lock.locked: text += "\n"+LOCK_HINT % str(isle_card().name)
	elif isle_lock == null or isle_lock.in_reach(plane.position): text += "\n"+LOCK_OFFER % str(isle_card().name)
	if stone_plane and lodestone != null:
		if lode_state == "seated":
			text += "\nThe lodestone points the way (%.0f m): turn toward the brighter wing seam (both even and faint: on course)  ·  top or bottom fin lit: climb or dive  ·  tail lit: it is behind you  ·  prow runes flare: dead ahead" % plane.position.distance_to(lode_target)
		else: text += "\nThe stone plane sleeps: find the lodestone on foot and board with it to wake it"
	elif lodestone != null and lode_state == "seated":
		text += "\nThe nose arrow points to the place in the stone (%.0f m): it glows brighter when you are dead on course" % plane.position.distance_to(lode_target)
	_switch_hint.text = text

## The turf's top under a point, as the game's plane reads its heightfield:
## a ray down from a metre over it onto the turf only, upward faces only
## (inside an island's side or under its keel there is none; the bump
## turns it off those).
func plane_ground(p: Vector3) -> Variant:
	if _ground_ray == null:
		_ground_ray = PhysicsRayQueryParameters3D.new()
		_ground_ray.collision_mask = TURF_LAYER
	_ground_ray.from = p+Vector3.UP
	_ground_ray.to = p+Vector3.DOWN*60.0
	var hit := get_world_3d().direct_space_state.intersect_ray(_ground_ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.3: return null
	return float((hit.position as Vector3).y)

## The plane's body (BUMP_BODY, turned with its heading, pitch, bank and
## roll) where it is now.
func _plane_query() -> PhysicsShapeQueryParameters3D:
	if _bump_query == null:
		_bump_query = PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = BUMP_BODY
		_bump_query.shape = box
		_bump_query.collision_mask = plane_mask()
	var turn := PlaneFigure.pose(Vector3.ZERO,float(plane.heading),float(plane.pitch),float(plane.bank)+float(plane.spin)).basis
	_bump_query.transform = Transform3D(turn,plane.position)
	return _bump_query

func _in_stone() -> bool:
	return not get_world_3d().direct_space_state.intersect_shape(_plane_query(),1).is_empty()

## Bump and recover (the ruin kit gallery's, scripts/ruin_bump.gd): the
## plane's body in stone, or in the turf's side or keel, is put back out
## along the face it hit (the way it came, failing that), its heading
## turned along the face and its pitch eased level, BUMP_KEEP of its speed
## kept. Never a crash. On the turf's top it is only lifted clear.
func _bump(was: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var rest := space.get_rest_info(_plane_query())
	if rest.is_empty(): return false
	var normal: Vector3 = rest.get("normal",Vector3.ZERO)
	if normal.y > FLOOR_NORMAL and _ride_top(space): return false
	bumps += 1
	if normal.length() < 0.5: normal = (was-plane.position).normalized()
	plane.position = was+normal*0.15
	if not space.get_rest_info(_plane_query()).is_empty(): plane.position = was+normal*0.6
	# Failing both (a corner), back where it was, clear last frame.
	if not space.get_rest_info(_plane_query()).is_empty(): plane.position = was
	var way: Vector3 = plane.forward()
	var along := way-normal*way.dot(normal)
	if along.length() > 0.05:
		along = along.normalized()
		var flat := Vector2(along.x,along.z)
		if flat.length() > 0.05: plane.heading = atan2(-flat.x,-flat.y)
		plane.pitch = clampf(asin(clampf(along.y,-1.0,1.0)),-0.6,0.6)
	# Turned, its wings may reach into the face again: out along it.
	for i in range(10):
		if space.get_rest_info(_plane_query()).is_empty(): break
		plane.position += normal*0.1
	plane.speed = maxf(SkyPlane.SLOW,float(plane.speed)*BUMP_KEEP)
	plane.velocity = plane.forward()*float(plane.speed)
	return true

## On a top (a face whose normal is up past FLOOR_NORMAL: a ramp, a
## stair, the rubble, a wall's or the channel's top, the turf), lifted
## clear in RIDE_STEP m steps, up to RIDE_LIFT m, and ridden as the glide
## rides ground: the fall stopped, a dipped nose eased level, the ground's
## drag. True if it came clear.
func _ride_top(space: PhysicsDirectSpaceState3D) -> bool:
	var from: Vector3 = plane.position
	for i in range(int(RIDE_LIFT/RIDE_STEP)):
		plane.position = from+Vector3.UP*RIDE_STEP*float(i+1)
		if space.get_rest_info(_plane_query()).is_empty():
			if plane.velocity.y < 0.0: plane.velocity.y = 0.0
			if plane.pitch < 0.0: plane.pitch = lerpf(float(plane.pitch),0.0,0.15)
			plane.speed = maxf(SkyPlane.SLOW,float(plane.speed)-SkyPlane.SKIM_DRAG/60.0)
			plane.skimming = true
			return true
	plane.position = from
	return false

## Whether a point is inside stone (the chase camera stays out of it).
func _inside_stone(p: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = p
	query.collision_mask = plane_mask()
	return not get_world_3d().direct_space_state.intersect_point(query,1).is_empty()

## The layers the plane bumps off and the chase camera stays out of: the
## stone and the turf.
func plane_mask() -> int:
	return 1|TURF_LAYER

## A lean pressed: the second press the same way within DOUBLE_TAP asks
## for a barrel roll that way.
func _lean_tapped(dir: float) -> void:
	var now := Time.get_ticks_msec()
	if dir == _tap_dir and now-_tap_at <= int(DOUBLE_TAP*1000.0):
		_roll_asked = dir
		_tap_dir = 0.0
	else:
		_tap_dir = dir
		_tap_at = now

## The plane's keys, mouse and pad: F or Y back on foot, R on foot at the
## start, Q E knife edge (twice quick a roll), the mouse steers, a click
## rolls, the right button held looks round, Esc frees the mouse.
func _fly_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): chase.turn(Vector2(-event.relative.x,-event.relative.y)*FLY_LOOK)
		else: _fly_look += Vector2(event.relative.x,-event.relative.y)*FLY_LOOK
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else: _roll_asked = -1.0 if float(plane.bank) < -0.05 else 1.0
	elif Pad.pressed(event,&"fly_land"): leave_plane()
	elif Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
	elif Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F: leave_plane()
			KEY_TAB: toggle_lock()
			KEY_R:
				leave_plane(start)
				respawn()
			KEY_Q: _lean_tapped(-1.0)
			KEY_E: _lean_tapped(1.0)
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## No pack recordings (an isle with a station replays its own).
func _pack_runs() -> PackedStringArray:
	return PackedStringArray()

## A flying capture's last word on the eye, once the wait is flown (a
## scene may move the camera; the chase camera's by default).
func _capture_flying() -> void:
	pass

func _take_capture() -> void:
	for child in get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer in [5,6]: (child as CanvasLayer).visible = false
	if _capture_at != Vector3.INF:
		set_process(false)
		var look := _capture_look if _capture_look != Vector3.INF else capture_look()
		camera.look_at_from_position(_capture_at,look)
		for i in range(240):
			_advance_look(1.0/60.0)
			if life != null: life.advance(1.0/60.0)
			await get_tree().process_frame
	else:
		if flying:
			while flown < _capture_wait: await get_tree().process_frame
			_capture_flying()
		else: await get_tree().create_timer(_capture_wait).timeout
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
	print("%s: saved %s (%s; %.2f ms a frame, vsync off; %d draw calls, %d primitives)" % [isle_name(),_capture,look_id,frame_ms,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()

# --- The sky round it ----------------------------------------------------------------

## The sky round the isle lived in (studies/aqueduct_isle_sky.gd): far isles,
## airships, the CPU planes, open-air life, motes and a few tokens for the
## plane; each with its own --no-... flag. A capture waits for it whole.
var sky: Node3D

func _add_sky() -> void:
	sky = sky_script().new()
	add_child(sky)
	sky.setup(self)
	if _capture != "": sky.flush()

# --- The lodestone ------------------------------------------------------------------

## The lodestone on its floating stone, the HUD's pops and chime, and the
## shard it points to (docs/design/isle-lodestone.md).
func _build_lode() -> void:
	lode_rest = lode_rest_at()
	if lode_rest == Vector3.INF: return
	lodestone = Lodestone.new()
	lodestone.set_miniature(LODE_MINI)
	lodestone.position = lode_rest
	lodestone.scale = Vector3.ONE*LODE_SCALE
	add_child(lodestone)
	_moments = MomentsHud.new()
	add_child(_moments)
	_build_target()
	if _carry:
		lode_state = "carried"
		lodestone.scale = Vector3.ONE*CARRY_SCALE
		lodestone.show_light(false)
		_carry_step(0.0)
	if _switch_hint != null: _switch_hint.text = _foot_text()

## The place the stone points to: a shard of island floating far off, its
## keel veined with the lode as the stone's is (scripts/lodestone.gd
## `keel_mesh` at island scale), a broken arch and a pier of the gothic kit
## on it; it collides (the plane is bumped off it, as off the ruins).
func _build_target() -> void:
	shard = Node3D.new()
	shard.name = "TargetShard"
	shard.position = lode_target
	add_child(shard)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var outline := PackedVector2Array()
	for i in range(11):
		var a := -TAU*i/11.0
		var r := 7.0*rng.randf_range(0.75,1.15)
		outline.append(Vector2(cos(a)*r*1.3,sin(a)*r))
	var mesh: ArrayMesh = Lodestone.keel_mesh(outline,14.0,91,true)
	var rock := MeshInstance3D.new()
	rock.name = "Rock"
	rock.mesh = mesh
	_shard_material = ShaderMaterial.new()
	_shard_material.shader = Lodestone.STONE_SHADER
	_shard_material.set_shader_parameter("hum",0.35)
	rock.material_override = _shard_material
	shard.add_child(rock)
	var body_static := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = mesh.get_faces()
	collider.shape = hull
	body_static.add_child(collider)
	shard.add_child(body_static)
	if _shard_arch():
		var arch: Node3D = RuinKit.piece("arch",44,0.5)
		arch.transform = Transform3D(Basis(Vector3.UP,0.3),Vector3(-1.5,0.0,0.5))
		shard.add_child(arch)
	var pier: Node3D = RuinKit.piece("pier",45,0.6)
	pier.position = Vector3(4.0,0.0,-2.0)
	shard.add_child(pier)
	_shard_flash = MeshInstance3D.new()
	_shard_flash.name = "Flash"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*46.0
	_shard_flash.mesh = quad
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow.albedo_texture = preload("res://scripts/glider_figure.gd")._soft_ring()
	glow.albedo_color = Color(1.0,0.86,0.6,0.0)
	glow.disable_fog = true
	_shard_flash.material_override = glow
	_shard_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shard_flash.position = Vector3(0.0,4.0,0.0)
	_shard_flash.visible = false
	shard.add_child(_shard_flash)

## Whether the shard bears its broken arch (an isle whose ring stands past
## the shard leaves it out: one arch, not two to choose between).
func _shard_arch() -> bool:
	return true

## On foot: the stone's step after the pilot's (or, held up, instead).
func tick(delta: float) -> void:
	if lode_state == "inspecting":
		_inspect_step(delta)
		return
	var was_grounded := motor.grounded
	var falling := motor.velocity.y
	super.tick(delta)
	_lode_step(delta)
	if life != null: life.step_pilot()
	if not flying: _tread(delta,was_grounded,falling)

## The live rope bridges under him (scripts/rope_bridge.gd `tread`): the
## deck takes his weight, his landings (their speed, m/s) and footfalls
## (one a stride, STRIDE m, as the game's walker steps), and carries him
## with its sway.
const STRIDE := 0.75
var _stride := 0.0
var _foot := 0
var _fall_speed := 0.0

func _tread(delta: float, was_grounded: bool, falling: float) -> void:
	if RopeBridge._live.is_empty(): return
	var events := {}
	if motor.grounded and not was_grounded: events["landed"] = maxf(-minf(falling,_fall_speed),0.0)
	_fall_speed = 0.0 if motor.grounded else minf(_fall_speed,motor.velocity.y)
	var pace := Vector2(motor.velocity.x,motor.velocity.z).length()
	var drawn := {}
	if motor.grounded and pace > 0.6:
		_stride += delta*pace/STRIDE
		if _stride >= 1.0:
			_stride -= 1.0
			_foot = 1-_foot
			drawn["footfall"] = _foot
	var carry := RopeBridge.tread(self,motor.feet,motor.grounded,events,drawn,clampf(pace/PilotMotor.RUN,0.0,1.0))
	if carry != Vector3.ZERO: motor.feet += carry

func _lode_step(delta: float) -> void:
	if lodestone == null: return
	if lode_state == "resting":
		var near := lode_rest.distance_to(motor.feet+Vector3.UP*0.9)
		lodestone.hum_goal = clampf(inverse_lerp(HUM_FAR,HUM_NEAR,near),0.0,1.0)
	elif lode_state == "carried": _carry_step(delta)
	if _arms_down > 0.0:
		_raise_arms(smoothstep(0.0,1.0,_arms_down))
		_arms_down = maxf(_arms_down-delta/0.35,0.0)
	if _cam_back > 0.0:
		_cam_back = maxf(_cam_back-delta,0.0)
		camera.global_transform = _cam_from.interpolate_with(camera.global_transform,1.0-_cam_back/CAM_BACK)
	if _switch_hint != null and not flying:
		var text := _foot_text()
		if _switch_hint.text != text: _switch_hint.text = text

## Each frame, walking or flying: the resting stone bobs, the shard's lode
## breathes, the arrival's flash fades.
func _lode_frame(delta: float) -> void:
	if lodestone == null: return
	if lode_state == "resting": lodestone.position = lode_rest+Vector3.UP*sin(_motion_time*0.9)*0.03
	if _shard_material != null: _shard_material.set_shader_parameter("clock",_motion_time)
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left-delta,0.0)
		var t := _flash_left/1.4
		_shard_flash.visible = _flash_left > 0.0
		(_shard_flash.material_override as StandardMaterial3D).albedo_color.a = sin(t*PI)*0.9
		_shard_flash.scale = Vector3.ONE*lerpf(1.6,0.5,t)
		_shard_material.set_shader_parameter("hum",0.35+0.65*sin(t*PI))

## Beside the stone, on its floating stone, it can be picked up.
func can_pick() -> bool:
	if lodestone == null or lode_state != "resting" or flying or not walk_ready: return false
	var feet := motor.feet
	var across := Vector2(feet.x-lode_rest.x,feet.z-lode_rest.z).length()
	return across < PICK_REACH and absf(feet.y+LODE_HOVER-lode_rest.y) < 0.5

## Picked up (E, pad A): he stops, raises his mitts and it floats down
## into them, the camera pushing in to look at it (`_inspect_step`).
func pick_up() -> void:
	if not can_pick(): return
	_pick_from_cam = camera.global_transform
	motor.velocity = Vector3.ZERO
	lode_state = "inspecting"
	_pick = 0.0
	lodestone.reset_turn()
	lodestone.idle_turn = true
	_moments.blip(0)
	if _switch_hint != null: _switch_hint.text = _foot_text()

## Kept (E, Enter, pad A or B): it rides at his side; the camera eases back
## behind him.
func keep_stone() -> void:
	if lode_state != "inspecting": return
	lode_state = "carried"
	_cam_from = camera.global_transform
	_cam_back = CAM_BACK
	_arms_down = 1.0
	lodestone.idle_turn = true
	lodestone.show_light(false)
	_moments.blip(2)
	_moments.pop("The lodestone is yours: board the plane (F, pad Y) and it will point the way",2.6)
	if _switch_hint != null: _switch_hint.text = _foot_text()

## The pickup, as the lodestone study's (studies/lodestone_study.gd
## `_step_inspect`): the mitts raised, the stone floating down off its rest
## into the air over them on an arc, the camera pushing in from where it
## was to a close shot of it before his face; the right stick turns it.
func _inspect_step(delta: float) -> void:
	_pick += delta
	motor.velocity = Vector3.ZERO
	body.drive(motor,delta)
	_raise_arms(smoothstep(0.0,0.6,_pick))
	var hold: Vector3 = (body.mitt(0)+body.mitt(1))*0.5+Vector3.UP*HOLD_UP
	var t := smoothstep(0.15,PICKUP,_pick)
	lodestone.position = lode_rest.lerp(hold,t)+Vector3.UP*sin(t*PI)*0.35
	lodestone.scale = Vector3.ONE*lerpf(LODE_SCALE,1.0,t)
	lodestone.hum_goal = 1.0
	var way := PilotMotor.forward(motor.facing)
	var ahead := Vector3(way.x,0.0,way.y)
	var right := Vector3(-way.y,0.0,way.x)
	var close := Transform3D(Basis.IDENTITY,hold+ahead*0.82+right*0.22+Vector3.UP*0.07).looking_at(hold+Vector3(0.0,-0.02,0.0))
	camera.global_transform = _pick_from_cam.interpolate_with(close,smoothstep(PICKUP*0.4,PICKUP+PUSH,_pick))
	var stick := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	if stick != Vector2.ZERO:
		lodestone.idle_turn = false
		lodestone.turn_by(stick*delta*1.8)

func _inspect_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		lodestone.idle_turn = false
		lodestone.turn_by(Vector2(event.relative.x*0.008,event.relative.y*0.006))
		return
	var done: bool = Pad.pressed(event,&"walk_jump") or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B)
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in [KEY_E,KEY_ENTER,KEY_KP_ENTER]: done = true
	if done and _pick > 0.4:
		keep_stone()
		Input.action_release(&"walk_jump")

## Carried: a small glow riding at his right side, a little behind his
## step.
func _carry_step(delta: float) -> void:
	var way := PilotMotor.forward(motor.facing)
	var ahead := Vector3(way.x,0.0,way.y)
	var right := Vector3(-way.y,0.0,way.x)
	var goal := figure.global_position+right*CARRY_AT.x+Vector3.UP*(CARRY_AT.y+sin(_motion_time*1.6)*0.03)+ahead*CARRY_AT.z
	lodestone.position = lodestone.position.lerp(goal,1.0-exp(-delta/0.08)) if delta > 0.0 else goal
	lodestone.scale = Vector3.ONE*move_toward(lodestone.scale.x,CARRY_SCALE,delta*1.5)
	lodestone.hum_goal = 0.4

## Bends the pilot's arms up over the clips' pose (`amount` 0 hanging to 1
## raised), as the lodestone study does.
func _raise_arms(amount: float) -> void:
	if amount <= 0.0: return
	var arms: Array[int] = body._upper_arms
	var forearms: Array[int] = body._forearms
	if arms.has(-1): return
	body._turn_bone(arms[0],Vector3.BACK,-ARMS.x*amount)
	body._turn_bone(arms[1],Vector3.BACK,ARMS.x*amount)
	body._turn_bone(arms[0],Vector3.RIGHT,ARMS.y*amount)
	body._turn_bone(arms[1],Vector3.RIGHT,ARMS.y*amount)
	if not forearms.has(-1):
		body._turn_bone(forearms[0],Vector3.BACK,ARMS.z*amount)
		body._turn_bone(forearms[1],Vector3.BACK,-ARMS.z*amount)

## The on-foot hint with the stone's line.
func _foot_text() -> String:
	if lodestone == null: return FOOT_HINT
	var line := ""
	match lode_state:
		"resting": line = "E (pad A): pick up the lodestone" if can_pick() else lode_hint()
		"inspecting": line = "Drag or right stick: turn the lodestone  ·  E or Enter (pad A or B): keep it"
		"carried": line = "Carrying the lodestone: F (pad Y) to board, and it seats in the plane"
	return FOOT_HINT+"\n"+line

## Near the shard with the stone seated: a chime, a pop and a flash.
func _check_arrival() -> void:
	if lode_state != "seated" or (stone_plane and not plane_figure.seated): return
	var d: float = plane.position.distance_to(lode_target)
	if not arrived and d < ARRIVE:
		arrived = true
		_moments.pop("Arrived: the place in the stone",2.6)
		_moments.flourish()
		if stone_plane: plane_figure.flash()
		_flash_left = 1.4
	elif arrived and d > ARRIVE_AGAIN: arrived = false

# --- Life on the isle ------------------------------------------------------------------

## The isle's life (`life_script`, scripts/kit_isle/kit_life.gd):
## undergrowth, butterflies, fireflies, songbirds on the stones, the wind
## made visible, a few on-foot tokens. Each has its opt-out flag; --no-life
## leaves it all out.
var life: Node3D = null

func _add_life() -> void:
	var args: PackedStringArray = preload("res://scripts/launch_args.gd").user_args()
	if args.has("--no-life"): return
	var began := Time.get_ticks_msec()
	life = life_script().new()
	add_child(life)
	life.setup(self,args)
	# One readout for the foot tokens and the sky's: the life's own goes,
	# its pickups show on the sky collectibles' HUD.
	var sky_tokens = sky.get("collectibles") if sky != null else null
	if life.tokens != null and sky_tokens != null and sky_tokens.get("hud") != null:
		life.tokens.hud.queue_free()
		life.tokens.hud = sky_tokens.get("hud")
	print("%s: life %s in %d ms %s" % [isle_name(),life.flags,Time.get_ticks_msec()-began,life.timings])
