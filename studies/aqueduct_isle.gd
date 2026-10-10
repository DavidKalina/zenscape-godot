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
##   F (pad Y)    into the game's plane, already flying a little above and
##                ahead; in it, back on foot on safe ground nearby (and
##                skimming the turf braking slow sets him down there)
##   F5 F6 F7 F8  record, replay the station's recordings, older, all paths
##   F1 numbers · F2 feel · Esc mouse
##   ./run-aqueduct-isle.command [--look=first_snow]
##   godot --path . res://studies/aqueduct_isle.tscn -- --no-title [--look=<preset id>] [--stone=mass] [--capture=out.png --at=x,y,z --look=x,y,z]
## --no-flora leaves the grass and flowers out (to compare cost).
## Life (studies/aqueduct_isle_life.gd, docs/scenic/aqueduct-isle-life.md):
## undergrowth, butterflies, fireflies, songbirds on the stones, the wind
## made visible and seven on-foot tokens; --no-undergrowth, --no-butterflies,
## --no-fireflies, --no-birds, --no-wind-life, --no-tokens leave each out,
## --no-life all of it.
## --fly starts in the plane; --drift=<x> scales its knife-edge drift
## (scripts/sky_plane.gd). The plane: docs/scenic/aqueduct-isle-game-look.md.
## The lodestone (docs/design/isle-lodestone.md): a stone holding a world in
## miniature (scripts/lodestone.gd) hums on the floating stone past the heel
## stone (east_1); climb to it, E (pad A) picks it up and holds it up to
## look at (drag or the right stick turns it; E, Enter, pad A or B keeps
## it), and it rides at the pilot's side. With --stone-plane, boarding with
## it seats it in the stone plane (scripts/stone_plane_figure.gd; the wooden
## plane is the default), whose wing seams then point to a shard
## floating far off (--target=x,y,z). --carry starts with it; --lode-at=
## <platform name> rests it elsewhere; --no-lode leaves it out; --pickup
## picks it up at once if he stands by it (captures).
## The hall chain (docs/design/isle-hall-chain.md, studies/
## aqueduct_isle_chain.gd): near the shard an arch erupts quietly out of
## the cloud sea far below and climbs to stand past it; threading it, a
## held breath, a pulse through the plane (the nose arrow goes quiet), and
## the Sundered halls erupt from the sea one after another ahead.
## --no-chain leaves it out (the old shard-only arrival); --ring=x,y,z
## moves the ring, --ring-near=<m> how near it wakes (420),
## --ring-pause=<s> the breath (1.5), --chain-lead=<m> how far on the first
## hall's way in stands at the least (180), --arrive-spare=<s> how long
## before the plane gets to a gate it is still (2), --catch-up=<x> how much
## quicker a hall the plane outruns rises (1.6), --first-at=thread|pulse
## when the first hall starts (thread); --near-ring starts in the plane
## with the stone seated 260 m before the ring; the chain's own flags
## (--chain-at=, --chain-gap=, ...) and the rise's apply.
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
const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const StoneFigure = preload("res://scripts/stone_plane_figure.gd")
const NoseCompass = preload("res://scripts/nose_compass.gd")
const Lodestone = preload("res://scripts/lodestone.gd")
const MomentsHud = preload("res://scripts/moments_hud.gd")
const IsleSky = preload("res://studies/aqueduct_isle_sky.gd")
const Life = preload("res://studies/aqueduct_isle_life.gd")
const IsleChain = preload("res://studies/aqueduct_isle_chain.gd")
## The hall chain's halls collide on the ruins' layer (scripts/hall_rise.gd).
const RuinBump = preload("res://scripts/ruin_bump.gd")

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

## The lodestone (docs/design/isle-lodestone.md). It rests LODE_HOVER m over
## the top of the floating stone LODE_PLATFORM (studies/aqueduct_isle_art.gd
## `platforms`), LODE_SCALE times its hand size so it is found; it hums from
## HUM_FAR m, fully at HUM_NEAR. Standing on that stone within PICK_REACH m
## (across), E or pad A picks it up: the pilot raises his mitts, it floats
## down into them over PICKUP s and the camera pushes in over PUSH s; kept,
## it rides at his side (CARRY_AT: right, up, forward, at CARRY_SCALE).
## Boarding with it seats it in the stone plane; its compass points at
## TARGET (a shard floating far off). With the hall chain (the default,
## docs/design/isle-hall-chain.md, studies/aqueduct_isle_chain.gd) a ring
## rises quietly past the shard as he nears it, and threading it starts the
## halls; with --no-chain the shard stands at SHARD_ONLY_TARGET and
## arriving within ARRIVE m chimes and flashes (again once he has been
## ARRIVE_AGAIN m away), as before.
const LODE_PLATFORM := "east_1"
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
## The shard with the chain: 380 m north-north-east of the start, out over
## the cloud sea and clear of the near isles, so the ring past it
## and the halls past that run into open sky (docs/design/
## isle-hall-chain.md). Without it (--no-chain), where it was.
const TARGET := Vector3(200.0,42.0,-380.0)
const SHARD_ONLY_TARGET := Vector3(250.0,Art.TOP+24.0,-230.0)
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
var _lode_at := LODE_PLATFORM
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
## The ring and the hall chain (studies/aqueduct_isle_chain.gd): on unless
## --no-chain (or a test sets it off before the scene is built).
## --near-ring starts in the plane with the stone seated NEAR_RING_OUT m
## before the ring, NEAR_RING_UP m over its middle, flying at it.
const NEAR_RING_OUT := 260.0
const NEAR_RING_UP := 3.0
## The pulse through the plane once the ring's pause is over: a soft flash
## round it (m across, s).
const PULSE_SIZE := 7.0
const PULSE_TIME := 1.2
var chain_on := true
var isle_chain: Node3D = null
var _target_given := false
var _near_ring := false
## A capture from the walker's (or chase) camera waits this long (s;
## --capture-wait=<s>).
var _capture_wait := 4.0
## Seconds flown (fly_step's deltas): a capture from the plane waits for
## this to reach --capture-wait, so it is the same moment run to run
## however slow the first frames are.
var flown := 0.0
var _plane_flash: MeshInstance3D = null
var _plane_flash_left := 0.0

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
		elif arg.begins_with("--target="):
			lode_target = _vec(arg.get_slice("=",1))
			_target_given = true
		elif arg == "--no-chain": chain_on = false
		elif arg.begins_with("--capture-wait="): _capture_wait = float(arg.get_slice("=",1))
		elif arg == "--near-ring":
			_near_ring = true
			_carry = true
		elif arg.begins_with("--plane-eye="): _plane_eye = _vec(arg.get_slice("=",1))
		elif arg.begins_with("--place="):
			var p := arg.get_slice("=",1).split(",")
			_place = Vector4(float(p[0]),float(p[1]),float(p[2]),float(p[3]) if p.size() > 3 else 0.0)
	if not _target_given: lode_target = TARGET if chain_on else SHARD_ONLY_TARGET
	if not SceneLookPresets.PRESETS.has(look_id):
		push_warning("aqueduct isle: no look preset '%s' (%s); %s instead" % [look_id,", ".join(_look_ids),START_LOOK])
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
	if preload("res://scripts/launch_args.gd").user_args().has("--fly") or _near_ring: board()
	if _near_ring and isle_chain != null:
		var ahead := Vector3(-sin(isle_chain.ring_heading),0.0,-cos(isle_chain.ring_heading))
		fly_from(isle_chain.ring_at-ahead*NEAR_RING_OUT+Vector3.UP*NEAR_RING_UP,isle_chain.ring_heading)
	if preload("res://scripts/launch_args.gd").user_args().has("--pickup"):
		for i in range(30): tick(1.0/60.0)
		pick_up()
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
		var turf: StaticBody3D = land.get_node("Body")
		turf.collision_layer |= TURF_LAYER
		_turf_rids.append(turf.get_rid())
		_turf.append(turf)
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
	if delta > 0.0:
		if not flying: super._process(delta)
		elif walk_ready and not scripted: fly_step(delta,_fly_input(delta))
	_advance_look(delta)
	_lode_frame(delta)
	# Flying, `fly_step` steps the ring and the chain; on foot, here.
	if isle_chain != null and not flying and delta > 0.0: isle_chain.step(delta,null,false,camera.global_position)
	_pulse_frame(delta)
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
		reset_camera()
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
	plane.floor_y = Art.TOP-FLOOR_BELOW
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
			# Back in the plane once the halls have begun, it stays quiet.
			if isle_chain != null and isle_chain.state == "started": _nose.quiet(true)
			_moments.pop("The lodestone wakes the compass",1.6)
	chase = GlideCamera.new()
	chase.reset(plane,camera.global_position,camera.fov)
	chase.linger = LOOK_LINGER
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
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x,Art.TOP+80.0,z),Vector3(x,Art.TOP-80.0,z),TURF_LAYER)
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
	if isle_chain != null: isle_chain.step(delta,plane,lode_state == "seated",camera.global_position)
	if stone_plane: plane_figure.target = lode_target
	plane_figure.update(delta,plane,0.0,ground,false)
	if _nose != null:
		_nose.target = lode_target
		_nose.step(delta)
	plane_figure._mark.visible = false
	_check_arrival()
	chase.step(delta,plane,0.0,_inside_stone)
	camera.global_position = chase.eye
	camera.look_at(chase.look,Vector3.UP)
	camera.rotate_object_local(Vector3.FORWARD,chase.roll)
	camera.fov = chase.fov
	if _plane_eye != Vector3.INF:
		camera.global_position = plane_figure.global_transform*_plane_eye
		camera.look_at(plane_figure.global_transform*Vector3(0.0,0.05,-0.05),plane_figure.global_basis.y)
	_show_fly_hint()
	# Riding a top lifts it clear only frames it touches, so a skim counts
	# on through TOUCH_GAP s off it.
	var braking := float(input.get("brake",0.0)) > 0.5
	_off_ground = 0.0 if plane.skimming else _off_ground+delta
	_touch = _touch+delta if _off_ground <= TOUCH_GAP and braking and float(plane.speed) < TOUCH_SPEED else 0.0
	if _touch >= TOUCH_HOLD: leave_plane()

func _show_fly_hint() -> void:
	if _switch_hint == null or plane == null: return
	var text := FLY_HINT % [float(plane.speed),bumps]
	if stone_plane and lodestone != null:
		if lode_state == "seated":
			text += "\nThe lodestone points the way (%.0f m): turn toward the brighter wing seam (both even and faint: on course)  ·  top or bottom fin lit: climb or dive  ·  tail lit: it is behind you  ·  prow runes flare: dead ahead" % plane.position.distance_to(lode_target)
		else: text += "\nThe stone plane sleeps: find the lodestone on foot and board with it to wake it"
	elif lodestone != null and lode_state == "seated":
		text += "\nThe nose arrow points to the place in the stone (%.0f m): it glows brighter when you are dead on course" % plane.position.distance_to(lode_target)
	if isle_chain != null and isle_chain.state == "started": text += "\nThe halls rise out of the cloud ahead: fly on through them"
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
		_bump_query.collision_mask = 1|TURF_LAYER|RuinBump.LAYER
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
	query.collision_mask = 1|TURF_LAYER|RuinBump.LAYER
	return not get_world_3d().direct_space_state.intersect_point(query,1).is_empty()

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
			KEY_R:
				leave_plane(start)
				respawn()
			KEY_Q: _lean_tapped(-1.0)
			KEY_E: _lean_tapped(1.0)
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
			if life != null: life.advance(1.0/60.0)
			await get_tree().process_frame
	else:
		if flying:
			while flown < _capture_wait: await get_tree().process_frame
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
	print("aqueduct isle: saved %s (%s; %.2f ms a frame, vsync off; %d draw calls, %d primitives)" % [_capture,look_id,frame_ms,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()

# --- The sky round it ----------------------------------------------------------------

## The sky round the isle lived in (studies/aqueduct_isle_sky.gd): far isles,
## airships, the CPU planes, open-air life, motes and a few tokens for the
## plane; each with its own --no-... flag. A capture waits for it whole.
var sky: Node3D

func _add_sky() -> void:
	sky = IsleSky.new()
	add_child(sky)
	sky.setup(self)
	if _capture != "": sky.flush()

# --- The lodestone ------------------------------------------------------------------

## The lodestone on its floating stone, the HUD's pops and chime, and the
## shard it points to (docs/design/isle-lodestone.md).
func _build_lode() -> void:
	var p: Dictionary = Art.platform(_lode_at)
	if p.is_empty():
		push_warning("aqueduct isle: no platform '%s'; %s instead" % [_lode_at,LODE_PLATFORM])
		p = Art.platform(LODE_PLATFORM)
	lode_rest = (p.at as Vector3)+Vector3.UP*LODE_HOVER
	lodestone = Lodestone.new()
	lodestone.set_miniature(LODE_MINI)
	lodestone.position = lode_rest
	lodestone.scale = Vector3.ONE*LODE_SCALE
	add_child(lodestone)
	_moments = MomentsHud.new()
	add_child(_moments)
	_build_target()
	if chain_on: _build_chain()
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
	# With the chain the arch is the ring past the shard (one arch, not two
	# to choose between); the pier stays.
	if not chain_on:
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

## On foot: the stone's step after the pilot's (or, held up, instead).
func tick(delta: float) -> void:
	if lode_state == "inspecting":
		_inspect_step(delta)
		return
	super.tick(delta)
	_lode_step(delta)
	if life != null: life.step_pilot()

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
		"resting": line = "E (pad A): pick up the lodestone" if can_pick() else "A lodestone hums on a floating stone east, past the heel stone: climb up to it"
		"inspecting": line = "Drag or right stick: turn the lodestone  ·  E or Enter (pad A or B): keep it"
		"carried": line = "Carrying the lodestone: F (pad Y) to board, and it seats in the plane"
	return FOOT_HINT+"\n"+line

## Near the shard with the stone seated: a chime, a pop and a flash.
func _check_arrival() -> void:
	# With the chain, nothing happens by being near: only threading the ring.
	if isle_chain != null: return
	if lode_state != "seated" or (stone_plane and not plane_figure.seated): return
	var d: float = plane.position.distance_to(lode_target)
	if not arrived and d < ARRIVE:
		arrived = true
		_moments.pop("Arrived: the place in the stone",2.6)
		_moments.flourish()
		if stone_plane: plane_figure.flash()
		_flash_left = 1.4
	elif arrived and d > ARRIVE_AGAIN: arrived = false

# --- The ring and the hall chain ---------------------------------------------------------

## The ring past the shard, the chain's cloud sea and the chain (studies/
## aqueduct_isle_chain.gd, docs/design/isle-hall-chain.md).
func _build_chain() -> void:
	isle_chain = IsleChain.new()
	add_child(isle_chain)
	isle_chain.setup(lode_target,preload("res://scripts/launch_args.gd").user_args())
	isle_chain.chain.plane_box = _chain_plane_box
	isle_chain.started.connect(_ring_pulse)
	_plane_flash = MeshInstance3D.new()
	_plane_flash.name = "PlaneFlash"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*PULSE_SIZE
	_plane_flash.mesh = quad
	var glow := (_shard_flash.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	glow.albedo_color.a = 0.0
	_plane_flash.material_override = glow
	_plane_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plane_flash.visible = false
	add_child(_plane_flash)

## The plane's box (world) for the halls' rise, which waits for it to be
## clear before a chunk turns solid; none on foot.
func _chain_plane_box() -> AABB:
	if not flying or plane == null: return AABB()
	var half := Vector3.ONE*(PlaneFigure.SPAN*0.5+0.3)
	return AABB((plane.position as Vector3)-half,half*2.0)

## The ring's pause over: the arrival's chime, a soft flash round the plane,
## the nose arrow's flare (the stone plane's sync pulse), no words.
func _ring_pulse() -> void:
	_moments.flourish()
	_plane_flash_left = PULSE_TIME
	if _nose != null:
		_nose.pulse()
		_nose.quiet()
	if stone_plane and flying and plane_figure != null: plane_figure.flash()

func _pulse_frame(delta: float) -> void:
	if _plane_flash == null: return
	_plane_flash.visible = _plane_flash_left > 0.0 and flying
	if _plane_flash_left <= 0.0: return
	_plane_flash_left = maxf(_plane_flash_left-delta,0.0)
	var t := _plane_flash_left/PULSE_TIME
	if flying: _plane_flash.global_position = plane.position
	(_plane_flash.material_override as StandardMaterial3D).albedo_color.a = sin(t*PI)*0.7
	_plane_flash.scale = Vector3.ONE*lerpf(1.5,0.4,t)

## Puts the plane (flying) at `at` on `heading`, at cruise, the chase camera
## behind it (the quick test's start, the tests).
func fly_from(at: Vector3, heading: float) -> void:
	if not flying: return
	plane.launch(at,heading,SkyPlane.CRUISE_SPEED,false)
	plane.velocity = plane.forward()*float(plane.speed)
	plane_figure.reset(plane)
	chase = GlideCamera.new()
	chase.reset(plane,at-plane.forward()*7.0+Vector3.UP*2.0,camera.fov)
	chase.linger = LOOK_LINGER
	if isle_chain != null: isle_chain.forget()

# --- Life on the isle ------------------------------------------------------------------

## The isle's life (studies/aqueduct_isle_life.gd, docs/scenic/
## aqueduct-isle-life.md): undergrowth, butterflies, fireflies, songbirds on
## the stones, the wind made visible, a few on-foot tokens. Each has its
## opt-out flag; --no-life leaves it all out.
var life: Node3D = null

func _add_life() -> void:
	var args: PackedStringArray = preload("res://scripts/launch_args.gd").user_args()
	if args.has("--no-life"): return
	var began := Time.get_ticks_msec()
	life = Life.new()
	add_child(life)
	life.setup(self,args)
	# One readout for the foot tokens and the sky's: the life's own goes,
	# its pickups show on the sky collectibles' HUD.
	var sky_tokens = sky.get("collectibles") if sky != null else null
	if life.tokens != null and sky_tokens != null and sky_tokens.get("hud") != null:
		life.tokens.hud.queue_free()
		life.tokens.hud = sky_tokens.get("hud")
	print("aqueduct isle: life %s in %d ms %s" % [life.flags,Time.get_ticks_msec()-began,life.timings])
