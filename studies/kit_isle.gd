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
## studies/display_fog.gd, scripts/look_pass.gd) under a live sky (the day
## turning, the year, the weather drifting, the storm's lightning:
## scripts/kit_isle/kit_weather.gd) that the edit mode's look presets hold
## (L, --look=; L's "Live sky" gives it back); the plane (F) with its bump and
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
## (an arch on the shard or not), `_start_in_plane` (how --fly starts) and
## `plane_home` (where its plane stands parked to begin with).
##
##   R            back to the start
##   L / Shift+L  next / previous look preset (its name shows a moment)
##   F9 · F10 · F11 · F12  the next quarter day · weather (Shift: drift
##                on or off) · season · a lightning strike
##   B            a strong gust front
##   Space (pad A) by the parked plane: climb in and take off
##   F (pad Y)    in the air the flaps down or up; stopped, get out
##   F1 numbers · F2 feel · Esc mouse
## The plane lands by hand, as the game's does (scripts/manual_landing.gd,
## docs/design/manual-landing.md "Kit isles" and "Round 3"): no F to land
## it, a flown touch on the turf sticks (a greaser slow, shallow and level;
## else a thump, a dust burst, a shake, a pad pulse), then brake or drift
## it to a stop like a kart, the stick steering the slide's line
## (scripts/wheel_spray.gd's grit off the wheels); slid off the edge it
## flies on. A dive flown straight into the turf bounces back up instead
## ("Too steep!"), and low over the turf the hint says what a touch now
## would get (scripts/landing_readout.gd; F1 in the plane, the numbers).
## Stopped, Shift held backs it up and Shift, Space and a turn pivot it, so
## a plane nosed into stone gets free. Stopped, F gets out and the plane stays parked where it
## stopped, solid to walk round; nothing summons it: walk back and Space by
## it to take off (scripts/plane_landing.gd's takeoff). Walked or knocked
## off the isle he stays on foot, falling, and Space (pad A) opens the
## pocket sail (scripts/pocket_sail.gd; nothing opens by itself); down on
## something near the edge he walks on, else he is stranded a moment and
## back beside the plane. An isle that starts on foot has its plane parked
## near the start (`plane_home`). An isle with the plane's arc (`plane_arc`,
## scripts/plane_arc/plane_arc.gd) has it broken until its six parts are
## fitted: Space by it fits what he carries, else the engine won't catch.
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
## is the same moment run to run however slow the first frames are; with
## --at it holds too (its settling frames count as the first 4 s).
## --capture-seq=<count>,<s> saves that many, that far apart (out_0.png...),
## to judge motion across frames. --capture-stick=<turn>,<pitch> holds that
## stick (-1..1 each) while a flying capture flies (a hard turn's framing);
## --fly-at=x,y,z,deg starts it flying there (heading deg clockwise from -z).
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
const Underground = preload("res://scripts/underground/underground.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
## The toy plane's span and the game's sizes (scripts/world_scale.gd).
const WorldScale = preload("res://scripts/world_scale.gd")
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
const FootLock = preload("res://scripts/lock_on/foot_lock.gd")
const GustShot = preload("res://scripts/lock_on/gust_shot.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const LandingReadout = preload("res://scripts/landing_readout.gd")
const PlaneLanding = preload("res://scripts/plane_landing.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")
const WheelSpray = preload("res://scripts/wheel_spray.gd")
const KitWeather = preload("res://scripts/kit_isle/kit_weather.gd")
const KitAudio = preload("res://scripts/kit_isle/kit_audio.gd")

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
## The day, the year, the drifting weather and the storm
## (scripts/kit_isle/kit_weather.gd), and its lightning, which the look
## pass hands the cloud volume.
var weather: Node
var _lightning: Node3D
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

## The plane: the islands' and islets' ground bodies also sit on
## TURF_LAYER, so the plane skims (and lands on) the turf as the game's
## plane does its heightfield, and is bumped off everything else that
## stands (and the turf's sides and keels). `board` (--fly, a test) puts it
## BOARD_AHEAD m ahead of the pilot along the view and BOARD_UP m up,
## flying at cruise. The cloud cushion lifts from FLOOR_BELOW m under the
## turf. The bump is the ruin kit gallery's (scripts/ruin_bump.gd): the
## plane's wing-wide body, turned with its bank and roll, BUMP_KEEP of its
## speed kept.
const TURF_LAYER := 1 << 11
const BOARD_AHEAD := 5.0
const BOARD_UP := 3.0
const FLOOR_BELOW := 50.0
const BUMP_BODY := Vector3(WorldScale.TOY_SPAN,0.3,1.2)
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
## A wheel's blip on coming down onto a top after TOUCH_GAP*2 s off it.
## Out of the plane in the air (R, a test), the pilot stands on the nearest
## open turf within SAFE_REACH m of it, and the plane goes back to its home.
const TOUCH_GAP := 0.25
const SAFE_REACH := 40.0
## The hand landing (scripts/manual_landing.gd) reads the turf under the
## wheels from FLOOR_UP m over the plane down to FLOOR_DOWN m under it: a
## rise past that is no ground (the wheels are stopped by it: `roll_blocked`),
## a drop past it is the edge (off it, flying). A rise of the turf into the
## fuselage's box (WHEEL_BOX m, FUSELAGE wide) or stone in the wing-wide
## bump body stops a roll with a thump.
const FLOOR_UP := 1.5
const FLOOR_DOWN := 2.0
const FUSELAGE := 0.6
## The parked plane: Space within BOARD_REACH m of its middle climbs in; the
## walker keeps PARKED_ROOM m from its middle (a column PARKED_TALL m up on
## PARKED_LAYER, which only the walker and his ground probes see, as the
## game's walker keeps off its parked plane). Hopping out, the pilot
## lands HOP_SIDE m to its left and HOP_AHEAD m ahead, HOP_HEIGHT m up at
## the top of the hop. Its home (`plane_home`, an isle starting on foot) is
## open level turf HOME_NEAR to HOME_FAR m from the start.
const BOARD_REACH := 1.9
const PARKED_ROOM := 0.75
const PARKED_TALL := 6.0
const PARKED_LAYER := 1 << 13
const HOP_SIDE := 1.4
const HOP_AHEAD := 0.3
const HOP_HEIGHT := 0.55
const HOME_NEAR := 8.0
const HOME_FAR := 40.0
## The touch's shake (s, m at a full hit) and the grit's tint off the turf
## (the game's grass puff).
const SHAKE_TIME := 0.4
const SHAKE := 0.3
const GRIT_TINT := Color("d6dcb4")
## How long a touch's word leads the hint (s).
const SAY_TIME := 2.2
## Walked, jumped or knocked off the isle: falling STEP_OFF_DROP m under
## where he last stood with nothing under him for STEP_OFF_CLEAR m, he is
## off the edge. He stays on foot: the motor's own fall, and Space (pad A)
## opens the pocket sail (scripts/pocket_sail.gd); nothing opens by itself.
## Down on anything within STRAND_BELOW m of the edge he walks on; past
## that, or down in water, he is stranded STRANDED_WAIT s and then back
## beside the parked plane (the game's rule; scripts/wanderer_eye.gd
## `_strand`), the never-death net.
const STEP_OFF_DROP := 4.0
const STEP_OFF_CLEAR := 12.0
const STRAND_BELOW := 20.0
const STRANDED_WAIT := 3.0
const FOOT_HINT := "Walk to your plane and Space (pad A) by it to fly  ·  Space (pad A) again in the air: the sail, again: fold  ·  Q (RB) with flow: the updraft  ·  Shift or C (LT) high in the air: the slam  ·  hold right mouse (LB): telescope  ·  R3 camera back behind"
const LOOK_HINT := "Telescope  ·  mouse (right stick) look  ·  wheel (LT RT) zoom  ·  hold on an isle for its card  ·  let go to lower"
const BOARD_LINE := "Space (pad A)  climb in and take off"
const FLY_HINT := "Flying  ·  %.0f m/s  ·  bumps %d\nA D bank and turn  ·  W S pitch (W nose down)  ·  mouse steers  ·  Space boost  ·  Shift brake  ·  hold Q E (LB RB) knife edge, + A D to drift  ·  Q Q or E E quick, or click: barrel roll\nF (pad Y) flaps %s  ·  put it down on the turf, then brake or drift to a stop  ·  R start on foot  ·  L / Shift+L look  ·  B gust  ·  hold right mouse or the right stick to look round  ·  R3 camera back behind"
const ROLL_HINT := "On the wheels  ·  %.0f m/s\nShift brake  ·  steer hard, or Q E and steer, to drift  ·  Shift and steer, a blip of Space, to power-slide  ·  in a slide ease or counter the stick to widen, Q E to tighten  ·  roll off the edge to fly"
const STOPPED_HINT := "On the wheels\nSpace roll, A D steer, off the isle's edge to fly  ·  F (pad Y) get out  ·  hold Shift (LT) to back up  ·  Shift, Space and steer to turn on the spot"
const REVERSE_HINT := "Backing up  ·  %.1f m/s\nsteer: the tail goes that way  ·  let go of Shift (LT) to stop  ·  Space roll forwards"
const TAKEOFF_HINT := "Climbing in"
const DIP_HINT := "Off the edge  ·  dropping until it has the speed to fly: nose down, Space for power"
const FALL_HINT := "Off the edge  ·  Space (pad A) open the sail  ·  WASD (left stick) steer"
const SAIL_HINT := "Under the sail  ·  WASD (left stick) steer  ·  Shift or C (LT) float  ·  Space (pad A) fold it and drop"
const STRANDED_HINT := "Stranded: back to your plane in a moment"
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
var _sight_ray: PhysicsRayQueryParameters3D
var bumps := 0
var _fly_look := Vector2.ZERO
var _roll_asked := 0.0
var _tap_dir := 0.0
var _tap_at := -100000
var _off_ground := INF
## The hand landing (scripts/manual_landing.gd) over the plane while in it,
## the takeoff from the parked plane (scripts/plane_landing.gd, null when
## not taking off), the grit off the wheels, the flaps, Exit asked, the
## touch's word on the hint and its seconds left, the shake left (s, and
## its size).
var hand_landing := ManualLanding.new()
## The plane drawn bigger on its wheels (scripts/plane_ground_scale.gd,
## --plane-ground-scale=x; 1 off), exactly its size in flight.
var ground_scale := PlaneGroundScale.new()
## The air the plane flies in (SkyCurrents `air_at`: `wind`, and a gust's
## `shove`), or none: still air. The aqueduct isle's dragon sets its blast
## here (scripts/dragon_gale.gd `plane_gust`).
var plane_air := Callable()
var takeoff: PlaneLanding = null
## The isle's sound (scripts/kit_isle/kit_audio.gd): the air, the plane,
## the body's extra foley and the place's ambience.
var audio: KitAudio = null
var spray: WheelSpray = null
var flaps := false
var _exit_asked := false
var _said := ""
var _said_left := 0.0
var _shake := 0.0
var _shake_size := 1.0
## The plane parked (the pilot out): its figure stands where it stopped, on
## its wheels; `parked_at` the ground under its middle, its heading; the
## column the walker keeps off; the hop out's (or in's) ends.
var parked := false
var parked_at := Vector3.ZERO
var parked_heading := 0.0
var _park_body: StaticBody3D = null
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.INF
## Off the edge (still on foot, the motor falling or under its sail), the
## edge's height, and the seconds left stranded (-1 not).
var off_edge := false
var _off_y := 0.0
var _stranded_left := -1.0
var _jump_was := false
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
## The stick a flying capture holds (--capture-stick=<turn>,<pitch>).
var _capture_stick := Vector2.ZERO
## A capture saves this many frames, this many seconds apart
## (--capture-seq=<count>,<s>).
var _capture_count := 1
var _capture_every := 0.5
## Seconds flown (fly_step's deltas): a capture from the plane waits for
## this to reach --capture-wait, so it is the same moment run to run
## however slow the first frames are.
var flown := 0.0
## The whole isle is up (its flora, lodestone, sky and life built, the plane
## parked or flown): the end of `_ready`, which waits on `ready_to_walk`
## first. The front door (scripts/kit_isle/front_door.gd) lifts its veil on
## it.
signal isle_ready
var isle_up := false

## The ring and painted-sky flags (scripts/sky_homes.gd) to hand back when the isle leaves.
var _ring_was: Array = []

## The plane's arc (scripts/plane_arc/plane_arc.gd: broken until its six
## parts are found, carried and fitted), or null for an isle without it.
## An isle that has it makes it in `_add_life`; `board_parked` asks it
## first, `tick` steps it, `_make_plane_figure` dresses the plane as it has
## it, the foot hint shows its line.
var plane_arc: Node3D = null

func _exit_tree() -> void:
	if _ring_was.is_empty(): return
	var World := preload("res://scripts/sky_homes.gd")
	World.ring = _ring_was[0]
	World.painted_sky = _ring_was[1]
	_ring_was = []

func _ready() -> void:
	pack = "ruins_archipelago"
	# The peak ring is not part of the kit: off, so no SkyWorld layout runs
	# for it. The painted sky stays as it was with the ring's ranges "up".
	var World := preload("res://scripts/sky_homes.gd")
	World.read_flags()
	_ring_was = [World.ring,World.painted_sky]
	World.ring = false
	World.painted_sky = false
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
		elif arg.begins_with("--capture-stick="):
			var held := arg.get_slice("=",1).split(",")
			_capture_stick = Vector2(float(held[0]),float(held[1]) if held.size() > 1 else 0.0)
		elif arg.begins_with("--capture-seq="):
			var seq := arg.get_slice("=",1).split(",")
			_capture_count = maxi(int(seq[0]),1)
			if seq.size() > 1: _capture_every = float(seq[1])
		elif arg.begins_with("--place="):
			var p := arg.get_slice("=",1).split(",")
			_place = Vector4(float(p[0]),float(p[1]),float(p[2]),float(p[3]) if p.size() > 3 else 0.0)
	if not SceneLookPresets.PRESETS.has(look_id) and look_id != KitWeather.LIVE:
		push_warning("kit isle: no look preset '%s' (%s); %s instead" % [look_id,", ".join(_look_ids),START_LOOK])
		look_id = START_LOOK
	super._ready()
	await ready_to_walk
	_hud.visible = false
	if not preload("res://scripts/launch_args.gd").user_args().has("--no-flora"): _grow()
	if not _no_lode: _build_lode()
	_add_sky()
	# --underground: the abyss, the torch and the murk over the day (scripts/underground/underground.gd).
	Underground.attach(self)
	_add_life()
	# The isle's sound (docs/design/sound-round1.md).
	audio = KitAudio.new()
	audio.isle = self
	add_child(audio)
	# The wind gauge: the updraft's charge in three segments (scripts/wind_gauge.gd).
	if updraft != null: updraft.segmented = SEGMENTED_CHARGE
	if updraft != null and WIND_GAUGE_ON:
		wind_gauge = WindGauge.new()
		wind_gauge.name = "WindGauge"
		wind_gauge.setup(updraft,wind_gauge_shown)
		add_child(wind_gauge)
		updraft.empty_press.connect(wind_gauge.empty_cue)
		updraft.gifted.connect(wind_gauge.gift)
	if _place != Vector4.INF:
		var turn := deg_to_rad(_place.w)
		start = Vector3(_place.x,_place.y,_place.z)
		start_face = Vector2(sin(turn),-cos(turn))
		respawn()
	_start_in_plane()
	# On foot to begin with, the plane stands parked near the start.
	if not flying and not parked: park_home()
	if flying and preload("res://scripts/launch_args.gd").user_args().has("--lock"): toggle_lock()
	if preload("res://scripts/launch_args.gd").user_args().has("--pickup"):
		for i in range(30): tick(1.0/60.0)
		pick_up()
	isle_up = true
	isle_ready.emit()
	if _capture != "": _take_capture()

## The start in the plane (--fly); an isle may start in the air elsewhere.
func _start_in_plane() -> void:
	if preload("res://scripts/launch_args.gd").user_args().has("--fly"): board()
	# --fly-at=x,y,z,deg (captures): flying there, heading deg clockwise from -z.
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if not arg.begins_with("--fly-at="): continue
		var p := arg.get_slice("=",1).split(",")
		if p.size() < 4: continue
		board()
		fly_from(Vector3(float(p[0]),float(p[1]),float(p[2])),-deg_to_rad(float(p[3])))

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
## the celestial rig on the world clock, the air and the weather, the live
## sky over them (scripts/kit_isle/kit_weather.gd); rendered,
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
	# The pocket sail (scripts/pocket_sail.gd) rides its breeze and gusts.
	motor.air = func(p: Vector3) -> Dictionary: return PocketSail.atmosphere_air(_atmosphere,p)
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
	# The live sky; the look presets hold it (L's first entry gives it back).
	weather = KitWeather.new()
	add_child(weather)
	weather.setup(self)
	_look_ids.push_front(KitWeather.LIVE)
	look_id = weather.start_look
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
## A preset holds the live sky; KitWeather.LIVE gives it back (KitWeather
## `show_look`).
func apply_look(id: String, show := true) -> void:
	if not weather.show_look(id): return
	look_id = id
	if _display_fog != null: _display_fog.forget()
	if show: _show_toast(KitWeather.LIVE_TITLE if id == KitWeather.LIVE else str(SceneLookPresets.PRESETS[id].title))

## The next (or previous) preset in the look editor's order.
func step_look(by: int) -> void:
	# --underground: the look key flips its presets (scripts/underground/underground.gd).
	var under := get_node_or_null("Underground")
	if under != null and under.has_method("cycle"):
		under.cycle()
		return
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
	if text == KitWeather.LIVE_TITLE: description = KitWeather.LIVE_LINE
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

## What the player has done, kept across runs (scripts/ledger/ledger.gd).
const Ledger = preload("res://scripts/ledger/ledger.gd")

## The isle's card as the plane locks onto it (scripts/isle_splash.gd):
## its name, a line of what it is, and what there is to find on it with
## how much has been found, from the ledger (`card`; no rows for an isle it
## doesn't list). Placeholders until the isles are named.
func isle_card() -> Dictionary:
	return Ledger.shared().card(Ledger.isle_id_of(self),{"name":isle_name().capitalize(),"epithet":"An isle adrift over the cloud sea"})

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
	# The parked plane's column stands in his way too.
	decks.see(decks.mask|PARKED_LAYER|WalkerOnly.LAYER)
	decks.frame = self
	decks.pools = ground.pools
	# His body's collider is sized with him (scripts/world_scale.gd
	# WANDERER, 1 in the game: the full-size radius 0.28, head 1.12), as
	# the character study's is.
	decks.scale_body(wanderer_scale)
	ground = decks
	motor.water = ground.water_callable()
	motor.wall = ground.wall_callable()
	# Moving and soft ground ride the ground in use too.
	if ground.has_method("mover_callable"): motor.mover = ground.mover_callable()
	if ground.has_method("soft_callable"): motor.soft = ground.soft_callable()

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
	if foot_lock != null and delta > 0.0: foot_lock.step(delta,motor.feet,camera,foot_lock_allowed())
	_advance_look(delta)
	_lode_frame(delta)
	# Not while it is put away (the run's city layers hide the aqueduct
	# isle's life): ~1 ms a frame of litter, chaff and birds no one sees.
	if life != null and life.is_visible_in_tree(): life.advance(delta,_life_gap())
	if _toast_left > 0.0 and _look_toast != null:
		_toast_left = maxf(_toast_left-delta,0.0)
		_look_toast.modulate.a = clampf(_toast_left/TOAST_FADE,0.0,1.0)

## One frame of the game's look, in the game's order (studies/fidelity.gd
## `_process`): the weather and its surface weather, the air (round the
## camera, as the kit gallery bounds its gust fronts), the sky, the
## screen-space air and the look pass; the pilot parting the ruin growth.
func _advance_look(delta: float) -> void:
	weather.step(delta)
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
	var changed: String = weather.key(event)
	if changed != "":
		_show_toast(changed+"\n"+weather.label())
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_B:
				_send_gust()
				return
			KEY_L:
				step_look(-1 if (event as InputEventKey).shift_pressed else 1)
				return
	if Pad.pressed(event,&"camera_reset"):
		if flying:
			if not toggle_lock(): reset_camera()
		elif not toggle_foot_lock(): reset_camera()
		return
	if not flying and ((event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_TAB) 			or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE)):
		toggle_foot_lock()
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
	# Space (pad A) by the parked plane climbs in; F (pad Y) on foot flies
	# nothing (nothing summons the plane).
	var space_key: bool = event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_SPACE
	if (space_key or Pad.pressed(event,&"walk_jump")) and by_plane() and not _name_panel.visible and not _tune.visible:
		board_parked()
		Input.action_release(&"walk_jump")
		return
	if (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F) or Pad.pressed(event,&"fly_land"):
		if not by_plane(): _word("Walk back to your plane")
		return
	super._unhandled_input(event)

# --- The plane ----------------------------------------------------------------------

## Into the game's plane (scripts/sky_plane.gd) in the air, on no key: the
## --fly start, a set piece's and the tests'. It is already flying at
## cruise, BOARD_AHEAD m ahead of the pilot along the view and BOARD_UP m
## up (higher if that is in stone), under the game's chase camera
## (scripts/glide_camera.gd), the pilot in its cockpit, the hand landing
## watching its wheels. A parked plane is the one taken: there is only
## ever one.
func board() -> void:
	if flying or not walk_ready: return
	if off_edge: _end_fall()
	if not _replay.is_empty(): _end_replay()
	var way := PilotMotor.forward(_yaw)
	var at := motor.feet+Vector3(way.x,0.0,way.y)*BOARD_AHEAD+Vector3.UP*BOARD_UP
	_unpark()
	plane = SkyPlane.new()
	plane.use_game_speed()
	plane.floor_y = isle_top()-FLOOR_BELOW
	plane.launch(at,_yaw,plane.cruise(),false)
	for i in range(12):
		if not _in_stone(): break
		plane.position += Vector3.UP*2.0
	takeoff = null
	hand_landing.begin(plane)
	_into_plane()
	_show_fly_hint()

## Space (pad A) by the parked plane: the pilot hops in (scripts/
## plane_landing.gd's takeoff, its BOARD only), then the hand landing has
## it stopped on its wheels: the pilot taxis it, steering, and takes off
## by rolling it off the isle's edge (it dips, then the wings catch).
func board_parked() -> void:
	if flying or not parked or not walk_ready: return
	# Broken, Space fits what he carries or the engine won't catch
	# (scripts/plane_arc/plane_arc.gd `at_plane`).
	if plane_arc != null and plane_arc.at_plane(): return
	if not _replay.is_empty(): _end_replay()
	var at := parked_at
	var heading := parked_heading
	var feet := motor.feet
	_unpark()
	plane = SkyPlane.new()
	plane.use_game_speed()
	plane.floor_y = isle_top()-FLOOR_BELOW
	var r := PlaneStrip.rest(_floor_from(at.y),Vector2(at.x,at.z),heading)
	plane.park(Vector3(at.x,r.x,at.z),heading,r.y,r.z)
	takeoff = PlaneLanding.new()
	takeoff.take_off(plane,takeoff_run(Vector2(at.x,at.z),heading,at.y),Callable(self,"floor_at"))
	hand_landing.begin(plane,true)
	_into_plane()
	# Hopping in from where he stood (the hop run backwards: `hop` 1 out,
	# 0 in).
	_hop_from = ground_scale.point(plane_figure,plane.position+Vector3.UP*0.1)
	_hop_to = feet
	plane_figure.show_pilot(false)
	figure.visible = true
	_show_fly_hint()

## In the plane (`board`, `board_parked`): its figure (made the first time,
## kept parked after) reset onto it, the lodestone seated if carried, the
## chase camera behind, the plane's sound, the walker hidden.
func _into_plane() -> void:
	if plane_figure == null: _make_plane_figure()
	plane_figure.show_pilot(true)
	if stone_plane: plane_figure.target = lode_target
	plane_figure.reset(plane)
	ground_scale.reset(takeoff != null or hand_landing.on_ground())
	ground_scale.apply(plane_figure)
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
	_new_chase(camera.global_position)
	if air == null:
		air = GlideAir.new()
		air.voiced = false
		add_child(air)
	air.start()
	_flaps_heard = int(plane.flaps)
	figure.visible = false
	flying = true
	bumps = 0
	flaps = false
	_exit_asked = false
	_off_ground = INF
	_fly_look = Vector2.ZERO
	_roll_asked = 0.0
	_hop_to = Vector3.INF
	_shake = 0.0
	if _foot_hint != null: _foot_hint.visible = false

func _make_plane_figure() -> void:
	plane_figure = StoneFigure.new() if stone_plane else PlaneFigure.new()
	plane_figure.name = "Plane"
	add_child(plane_figure)
	if plane_arc != null: plane_arc.dress(plane_figure)

## Out of the plane. On its wheels (stopped and got out, or taxiing) it
## stays parked where it stands, and the pilot is beside it (or at `at`),
## facing it. In the air (R, a test) it goes back to its home
## (`plane_home`), and he stands on the nearest open turf to where it flew
## (or at `at`), facing the way it flew.
func leave_plane(at := Vector3.INF) -> void:
	if not flying: return
	var on_wheels := not hand_landing.flying() if takeoff == null else takeoff.phase in [PlaneLanding.BOARD,PlaneLanding.TAXI]
	# (A plane moved off the turf from outside is in the air, whatever.)
	if is_nan(floor_at(Vector2(plane.position.x,plane.position.z))): on_wheels = false
	var spot := at
	var face := Vector2(-sin(float(plane.heading)),-cos(float(plane.heading)))
	takeoff = null
	flying = false
	release_lock()
	if lode_state == "seated":
		# He takes the stone with him.
		if stone_plane and plane_figure.stone != null:
			var lode: Node3D = plane_figure.unseat()
			add_child(lode)
		lodestone.visible = true
		lode_state = "carried"
	if _nose != null: _nose.queue_free()
	_nose = null
	if air != null: air.stop()
	if spray != null: spray.update(0.0,plane.position,Vector3.ZERO,0.0,GRIT_TINT)
	if on_wheels:
		var under := floor_at(Vector2(plane.position.x,plane.position.z))
		_park(Vector3(plane.position.x,under,plane.position.z),float(plane.heading))
		if spot == Vector3.INF: spot = _hop_spot(parked_at,parked_heading)
		var to := Vector2(parked_at.x-spot.x,parked_at.z-spot.z)
		if to.length() > 0.01: face = to.normalized()
	else:
		if spot == Vector3.INF: spot = safe_ground(plane.position)
		park_home()
	figure.visible = true
	camera.fov = FOV
	if _foot_hint != null: _foot_hint.visible = true
	place(spot,face)
	_last_stood = spot
	_hop_to = Vector3.INF
	if _switch_hint != null: _switch_hint.text = _foot_text()

# --- Parked ------------------------------------------------------------------------

## Stands the plane parked on the turf at `at` (the ground under its
## middle), facing `heading`: its figure sat on its wheels and tail skid
## (PlaneStrip `rest`), the engine off, no pilot; and the column round its
## middle the walker keeps off (PARKED_ROOM m, as the game's walker keeps
## off its parked plane).
func _park(at: Vector3, heading: float) -> void:
	if plane_figure == null: _make_plane_figure()
	parked = true
	parked_at = at
	parked_heading = heading
	var r := PlaneStrip.rest(_floor_from(at.y),Vector2(at.x,at.z),heading)
	plane_figure.park(plane_figure.pose(Vector3(at.x,r.x,at.z),heading,r.y,r.z))
	ground_scale.k = ground_scale.factor
	ground_scale.apply(plane_figure)
	if _park_body == null:
		_park_body = StaticBody3D.new()
		_park_body.name = "ParkedPlaneRoom"
		_park_body.collision_layer = PARKED_LAYER
		_park_body.collision_mask = 0
		var column := CylinderShape3D.new()
		column.radius = PARKED_ROOM*sqrt(ground_scale.ground_size())
		column.height = PARKED_TALL
		var collider := CollisionShape3D.new()
		collider.shape = column
		collider.position = Vector3.UP*PARKED_TALL*0.5
		_park_body.add_child(collider)
		add_child(_park_body)
	_park_body.global_position = at

## The parked plane taken (boarded or flown from elsewhere): its column
## goes at once, so the plane is clear of it.
func _unpark() -> void:
	parked = false
	if _park_body != null:
		_park_body.free()
		_park_body = null

## Parks the plane at its home (`plane_home`).
func park_home() -> void:
	var home := plane_home()
	_park(Vector3(home.x,home.y,home.z),home.w)

## Where the plane stands parked to begin with: (x, y, z) the turf under
## its middle, w its heading. The nearest ring HOME_NEAR to HOME_FAR m round
## the start with a spot on open, level turf with room for its wings and a
## run to take off along (to an edge, or LIFT_RUN m clear), the best run's
## spot, facing along it; failing all, the nearest open turf to the start.
## An isle may answer its own.
var _home := Vector4.INF

func plane_home() -> Vector4:
	if _home != Vector4.INF: return _home
	var space := get_world_3d().direct_space_state
	var best := {}
	var r := HOME_NEAR
	while r <= HOME_FAR and best.is_empty():
		for i in range(16):
			var a := TAU*float(i)/16.0+r*0.37
			var top := _turf_top(space,start.x+cos(a)*r,start.z+sin(a)*r)
			if top == Vector3.INF or absf(top.y-start.y) > 6.0 or not _level(top): continue
			var run := takeoff_run(Vector2(top.x,top.z),0.0,top.y)
			if run.is_empty() or not (bool(run.edge) or float(run.length) >= PlaneStrip.LIFT_RUN): continue
			var dir: Vector3 = run.dir
			var heading := atan2(-dir.x,-dir.z)
			if not _room_for_plane(top,heading): continue
			if best.is_empty() or float(run.score) > float(best.score): best = {"at":top,"heading":heading,"score":float(run.score)}
		r += 4.0
	if best.is_empty():
		# No run: the nearest level spot with room for it, off the start (the
		# walker starts there, and the column round it would stand him on it).
		var spot := Vector3.INF
		r = HOME_NEAR
		while r <= HOME_FAR and spot == Vector3.INF:
			for i in range(16):
				var a := TAU*float(i)/16.0+r*0.37
				var top := _turf_top(space,start.x+cos(a)*r,start.z+sin(a)*r)
				if top == Vector3.INF or absf(top.y-start.y) > 6.0 or not _level(top): continue
				if _room_for_plane(top,PilotMotor.facing_of(start_face)):
					spot = top
					break
			r += 4.0
		var at := safe_ground(start) if spot == Vector3.INF else spot
		_home = Vector4(at.x,at.y,at.z,PilotMotor.facing_of(start_face))
	else:
		var at: Vector3 = best.at
		_home = Vector4(at.x,at.y,at.z,float(best.heading))
	return _home

## Level enough to park on: the turf 1.5 m round `top` within 0.4 m of it.
func _level(top: Vector3) -> bool:
	for d: Vector2 in [Vector2(1.5,0.0),Vector2(-1.5,0.0),Vector2(0.0,1.5),Vector2(0.0,-1.5)]:
		var h := _turf_near(Vector2(top.x,top.z)+d,top.y)
		if is_nan(h) or absf(h-top.y) > 0.4: return false
	return true

## Room for the parked plane's wings and length on `top` facing `heading`:
## nothing but turf where it would stand.
func _room_for_plane(top: Vector3, heading: float) -> bool:
	var box := BoxShape3D.new()
	# Its drawn size stood on its wheels: the span as drawn (WorldScale.span,
	# the plane's own scale) times the ground cheat (1 at the knobs).
	var f := ground_scale.ground_size()
	box.size = Vector3(WorldScale.span*ground_scale.factor+0.4,1.2*f,maxf(3.0,1.6*f))
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = plane_mask()
	query.exclude = _turf_rids
	query.transform = Transform3D(Basis(Vector3.UP,heading),top+Vector3.UP*(0.3+0.6*f))
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

## True walking within BOARD_REACH m (across) of the parked plane's middle.
func by_plane() -> bool:
	if flying or off_edge or not parked or not walk_ready: return false
	var feet := motor.feet
	return Vector2(feet.x-parked_at.x,feet.z-parked_at.z).length() <= BOARD_REACH*sqrt(ground_scale.ground_size()) and absf(feet.y-parked_at.y) < 1.5

## Where the hop out of a plane standing at `at` (the turf under its
## middle) facing `heading` lands: HOP_SIDE m to its left and HOP_AHEAD m
## ahead on open turf; else to its right; else the nearest open turf.
func _hop_spot(at: Vector3, heading: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var forward := Vector3(-sin(heading),0.0,-cos(heading))
	var right := Vector3(cos(heading),0.0,-sin(heading))
	var hop := ground_scale.hop_offset(HOP_SIDE,HOP_AHEAD)
	for side: float in [-1.0,1.0]:
		var p := at+right*hop.x*side+forward*hop.y
		var top := _turf_near(Vector2(p.x,p.z),at.y)
		if is_nan(top): continue
		var spot := Vector3(p.x,top,p.z)
		if _room_for_pilot(space,spot): return spot
	return safe_ground(at-right*HOP_SIDE)

## The pilot mid-hop: `k` 0 in the cockpit, 1 on the turf beside it,
## rising and falling through the jump's pose.
func _hop_figure(k: float, delta: float) -> void:
	if _hop_to == Vector3.INF: return
	figure.visible = k > 0.02
	var at := _hop_from.lerp(_hop_to,smoothstep(0.0,1.0,k))
	at.y += HOP_HEIGHT*sqrt(ground_scale.ground_size())*sin(PI*k)
	figure.position = at
	body.hop(cos(PI*k),delta)

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

## Lock-on on foot (scripts/lock_on/foot_lock.gd): R3 / Tab / the middle
## mouse lock onto a target stone in range and in view, or let go. False
## if there was nothing to lock onto (R3 then resets the camera as before).
var foot_lock: Node3D = null
## How hard the locked camera swings round to frame him and the target
## (s, the ease's time constant), its pitch over the default (rad) and how
## far its gaze leans from him toward the target (0 him .. 1 the target).
const FOOT_LOCK_TURN := 0.35
const FOOT_LOCK_PITCH := 0.08
const FOOT_LOCK_LEAN := 0.35
const FOOT_LOCK_LEAN_MOST := 8.0

func toggle_foot_lock() -> bool:
	if not foot_lock_allowed(): return false
	if foot_lock == null:
		foot_lock = FootLock.new()
		foot_lock.name = "FootLock"
		foot_lock.sight_mask = 0xFFFFFFFF & ~PARKED_LAYER
		add_child(foot_lock)
	if foot_lock.locked():
		foot_lock.release()
		return true
	return foot_lock.acquire(motor.feet,camera)

## The gust shot (scripts/lock_on/gust_shot.gd): on foot, X (pad X) with
## the updraft charge at its release threshold or more spends it on a ball
## of air: at the locked target, else along the camera's flat heading.
## Without the charge X is the twirl, as ever; the press that shot holds
## the twirl off until X is let go.
var gust_shot: Node3D = null

func _gust_input() -> void:
	if not Input.is_action_pressed(&"walk_twirl"): twirl_held_off = false
	if not Input.is_action_just_pressed(&"walk_twirl") or _tuning(): return
	if updraft == null or not foot_lock_allowed(): return
	if telescope != null and telescope.busy(): return
	if not updraft.can_spend(): return
	if updraft.parry != null and updraft.parry.call("holds"): return
	var target: Node3D = null
	if foot_lock != null and foot_lock.locked(): target = foot_lock.target
	var heading := -camera.global_transform.basis.z
	if target != null: heading = target.global_position-motor.feet
	var spent: float = updraft.spend(motor,-Vector3(heading.x,0.0,heading.z).normalized()*1.5)
	if spent <= 0.0: return
	if gust_shot == null:
		gust_shot = GustShot.new()
		add_child(gust_shot)
	gust_shot.fire(motor.feet,heading,target,spent)
	twirl_held_off = true

## The updraft's charge in segments (scripts/updraft.gd SEG*): each unleash
## spends one at a fixed strength. Off: all of it at once, as before.
const SEGMENTED_CHARGE := true
## The wind gauge (scripts/wind_gauge.gd); off: no gauge, as before.
const WIND_GAUGE_ON := true
const WindGauge = preload("res://scripts/wind_gauge.gd")
var wind_gauge: CanvasLayer = null

## Whether the wind gauge may show: on foot (not in the plane, or held off
## while a capture runs).
func wind_gauge_shown() -> bool:
	return walk_ready and not flying and _capture == ""

## On foot, walking (not flying, stranded, off the edge or holding the stone up).
func foot_lock_allowed() -> bool:
	return walk_ready and not flying and not off_edge and _stranded_left < 0.0 and lode_state != "inspecting"

## The on-foot camera; locked on, it first swings behind him toward the
## target (the stick and mouse still nudge it, the pull takes it back), and
## after, leans its gaze from him toward the target.
func _frame(delta: float) -> void:
	var w: float = foot_lock.weight if foot_lock != null else 0.0
	if w > 0.0 and foot_lock.locked() and delta > 0.0:
		var aim: Vector3 = foot_lock.target.call("aim_point")
		var d := aim-motor.feet
		if Vector2(d.x,d.z).length() > 0.5:
			_yaw = lerp_angle(_yaw,atan2(-d.x,-d.z),_ease(FOOT_LOCK_TURN,delta)*w)
		_polar = lerpf(_polar,CAM_POLAR+FOOT_LOCK_PITCH,_ease(FOOT_LOCK_TURN*2.0,delta)*w)
		_look_rest = 0.0
	super._frame(delta)
	if w > 0.0 and foot_lock._last != null and is_instance_valid(foot_lock._last):
		var pivot := Vector3(_cam_at.x,_cam_y,_cam_at.y)
		var toward: Vector3 = foot_lock._last.call("aim_point")-pivot
		var gaze := pivot+toward.limit_length(FOOT_LOCK_LEAN_MOST)*FOOT_LOCK_LEAN*w
		if camera.global_position.distance_to(gaze) > 0.1: camera.look_at(gaze)

## Locks onto the isle if the plane is in reach of it, or lets go if
## locked (R3 / Tab in the plane); false if neither (out of reach). Locking
## puts the chase camera's free look back and shows the isle's card.
func toggle_lock() -> bool:
	if not flying or takeoff != null or not hand_landing.flying(): return false
	if isle_lock == null: isle_lock = IsleLock.new()
	if isle_lock.locked:
		release_lock()
		return true
	var target := lock_target(plane.position)
	isle_lock.set_isle(target.middle,target.radius,target.top)
	if not isle_lock.in_reach(plane.position): return false
	_lock_card = target.card
	isle_lock.lock(plane.position,plane.velocity)
	chase.set(&"free",Vector2.ZERO)
	if splash == null:
		splash = IsleSplash.new()
		splash.name = "IsleSplash"
		add_child(splash)
	if preload("res://scripts/launch_args.gd").user_args().has("--card-hold"): splash.hold = 3600.0
	splash.show_card(_lock_card)
	_show_fly_hint()
	return true

## The card of the isle locked onto.
var _lock_card := {}

## The isle the plane at `at` would lock onto: {middle (x, z), radius, top,
## card}. This isle; one with others in its sky answers the nearest in
## reach (studies/aqueduct_isle.gd: its motif isles).
func lock_target(_at: Vector3) -> Dictionary:
	var circle := isle_circle()
	return {"middle":Vector3(circle.x,0.0,circle.y),"radius":circle.z,"top":isle_top(),"card":isle_card()}

## The isles the telescope aims at (scripts/telescope.gd `pick`), as
## `lock_target` sees them: this one; with others in its sky, those too.
func sight_isles() -> Array:
	var circle := isle_circle()
	return [{"middle":Vector3(circle.x,0.0,circle.y),"radius":circle.z,"top":isle_top(),"isle":self}]

## On foot only, and not off the edge, stranded or holding the lodestone up.
func telescope_allowed() -> bool:
	return not flying and not off_edge and _stranded_left < 0.0 and lode_state != "inspecting" and super.telescope_allowed()

## Whether the plane at `at` is in the lock's reach of `target`.
static func lock_reaches(target: Dictionary, at: Vector3) -> bool:
	var probe: RefCounted = IsleLock.new()
	probe.set_isle(target.middle,target.radius,target.top)
	return probe.in_reach(at)

## Lets go of the isle (the camera eases back behind, the card fades).
func release_lock() -> void:
	if isle_lock == null or not isle_lock.locked: return
	isle_lock.release()
	if splash != null: splash.fade()
	if chase != null: chase.set(&"free",Vector2.ZERO)

## How far the eye is from the isle's edge (m, 0 on it): the life's
## small things hold still past their reach (scripts/kit_isle/kit_life.gd
## `advance`). The circle kept till the outlines change.
var _gap_circle := Vector3.INF
var _gap_outlines := -1
func _life_gap() -> float:
	if camera == null: return 0.0
	if _gap_outlines != _outlines.size():
		_gap_outlines = _outlines.size()
		_gap_circle = isle_circle()
	var eye := camera.global_position
	return maxf(Vector2(eye.x-_gap_circle.x,eye.z-_gap_circle.y).length()-_gap_circle.z,0.0)

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
	if _capture != "" and _capture_stick != Vector2.ZERO:
		input.turn = _capture_stick.x
		input.pitch = _capture_stick.y
	_lock_stick = stick
	if isle_lock != null and isle_lock.locked: return isle_lock.steer(input,plane)
	return input

## One frame in the plane. Taking off, the takeoff flies it
## (`_takeoff_step`). Else the hand landing steps it (scripts/
## manual_landing.gd, the game's rules): in the air the plane over the turf
## (`plane_ground`), bumped off what stands; on the wheels its roll, slide
## and stop over the turf (`floor_at`), stopped short by what stands in the
## way (`roll_blocked`); what the wheels did felt (`_wheel_events`). It is
## drawn, the chase camera behind it. `input` is the plane's (SkyPlane
## `step`), and may hold `flaps` (else the F key's) and `exit` (true asks
## to get out, as F does on the wheels).
func fly_step(delta: float, input: Dictionary) -> void:
	flown += delta
	_said_left = maxf(_said_left-delta,0.0)
	if takeoff != null:
		_takeoff_step(delta)
		return
	var was: Vector3 = plane.position
	var ground := Callable(self,"plane_ground")
	var floor := Callable(self,"floor_at")
	var asked := input.duplicate()
	asked["flaps"] = float(input.get("flaps",1.0 if flaps else 0.0))
	asked["exit"] = bool(input.get("exit",false)) or _exit_asked
	_exit_asked = false
	var out := hand_landing.step(delta,asked,ground,floor,plane_air,Callable(self,"roll_blocked"))
	plane.engine = hand_landing.engine
	if hand_landing.flying(): _bump(was)
	elif isle_lock != null and isle_lock.locked: release_lock()
	_fly_tick(delta)
	if stone_plane: plane_figure.target = lode_target
	plane_figure.update(delta,plane,0.0,ground,hand_landing.would_grease(floor))
	ground_scale.step(delta,hand_landing.on_ground(),hand_landing.dipping(),plane)
	ground_scale.apply(plane_figure)
	_size_chase()
	if _nose != null:
		_nose.target = lode_target
		_nose.step(delta)
	plane_figure._mark.visible = false
	_check_arrival()
	# The wind muffled in a cloud's body round the eye, as in the game.
	var host := cloud_host()
	air.advance(delta,plane.velocity,float(plane.hang),0.0,0.0,host.cloud_body(camera.global_position) if host != null else 0.0)
	air.engine(float(plane.speed),hand_landing.throttle,hand_landing.engine)
	if int(plane.flaps) != _flaps_heard:
		_flaps_heard = int(plane.flaps)
		air.flap()
	chase.cine = Vector3(-1.25,0.0,0.3) if hand_landing.on_ground() else Vector3.ZERO
	_frame_plane(delta)
	_wheel_events(out,delta)
	if not flying: return
	_show_plane_hud()
	if hand_landing.flying():
		# Coming down onto a top (a stone's, ridden over) after a while off
		# it, the wheels' blip; riding one lifts it clear only frames it
		# touches, so a skim counts on through TOUCH_GAP s off it.
		if plane.skimming and _off_ground > TOUCH_GAP*2.0 and _off_ground != INF: air.blip()
		_off_ground = 0.0 if plane.skimming else _off_ground+delta
		RopeBridge.flown_by(plane.position,plane.velocity)
	else:
		_off_ground = INF
	_show_fly_hint()

## A new chase camera behind the plane, from `from` (the eye it takes
## over), framed for the plane (docs/design/flight-camera.md): it sees the
## plane past stone and turf by ray (`_sight`). `--cam-old` keeps the
## camera as it was before (no framing; it stops short of stone), to A/B.
func _new_chase(from: Vector3) -> void:
	chase = GlideCamera.new()
	if not preload("res://scripts/launch_args.gd").user_args().has("--cam-old"):
		chase.framed = true
		chase.sight = _sight
	chase.reset(plane,from,camera.fov)
	chase.linger = LOOK_LINGER
	_size_chase()

## The chase camera stands back and frames higher as the plane grows on
## its wheels (scripts/plane_ground_scale.gd); the least it comes in to,
## the plane's reach round its middle and the speed it reads against
## follow the plane.
func _size_chase() -> void:
	if chase == null: return
	chase.size = ground_scale.size()
	chase.lift = ground_scale.lift()
	var span := WorldScale.TOY_SPAN*ground_scale.size()
	chase.near = span*GlideCamera.NEAR_SPANS
	chase.extent = span*0.5
	if plane != null: chase.cruise = plane.cruise()
	var view := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	if view.y > 0.0: chase.aspect = view.x/view.y

## The chase camera behind the plane (shaken by a hard touch), framing the
## isle while locked onto it; a capture's plane eye over all.
func _frame_plane(delta: float) -> void:
	chase.step(delta,plane,0.0,_inside_stone)
	camera.global_position = chase.eye+_shaken(delta)
	camera.look_at(chase.look,Vector3.UP)
	_frame_isle(delta)
	camera.rotate_object_local(Vector3.FORWARD,chase.roll)
	camera.fov = chase.fov
	if _plane_eye != Vector3.INF:
		camera.global_position = plane_figure.global_transform*_plane_eye
		camera.look_at(plane_figure.global_transform*Vector3(0.0,0.05,-0.05),plane_figure.global_basis.y)

## One frame of the pilot hopping into the parked plane (scripts/
## plane_landing.gd `take_off`'s BOARD), no controls; in, the hand landing
## has it stopped on its wheels and the controls are given back.
func _takeoff_step(delta: float) -> void:
	takeoff.step(delta)
	plane.engine = takeoff.engine
	if takeoff.phase == PlaneLanding.BOARD: _hop_figure(takeoff.hop,delta)
	elif figure.visible:
		figure.visible = false
		plane_figure.show_pilot(true)
	var ground := Callable(self,"plane_ground")
	plane_figure.update(delta,plane,0.0,ground,false)
	ground_scale.step(delta,true,false,plane)
	ground_scale.apply(plane_figure)
	_size_chase()
	plane_figure._mark.visible = false
	if _nose != null: _nose.step(delta)
	air.advance(delta,plane.velocity,0.0,0.0)
	air.engine(float(plane.speed),takeoff.throttle,takeoff.engine)
	chase.cine = Vector3(-1.2,-0.04,0.3) if takeoff.phase != PlaneLanding.LIFT else Vector3.ZERO
	_frame_plane(delta)
	if takeoff.phase != PlaneLanding.BOARD:
		takeoff = null
		_hop_to = Vector3.INF
		figure.visible = false
		plane_figure.show_pilot(true)
		hand_landing.begin(plane,true)
	_show_fly_hint()

## What the wheels did this step (ManualLanding `step`), felt as the game
## feels them (scripts/wanderer_eye.gd `_hand_events`): a hop thumps,
## shakes and pulses; a greaser blips softly; a hot or hard touch thumps,
## throws a burst of dust (scripts/wheel_spray.gd), shakes by its hit and
## pulses; sliding, the wheels throw grit and hiss; stopped, the hint offers
## the way out; getting out, the pilot hops down beside the plane, which
## stays parked where it stopped.
func _wheel_events(out: Dictionary, delta: float) -> void:
	if spray == null and (out.has("settled") or out.has("bounce")):
		spray = WheelSpray.new()
		spray.name = "WheelSpray"
		add_child(spray)
	var wheels := _wheels()
	if out.has("bounce"):
		_thump(1.0)
		Pad.pulse(0.6,0.5,0.2)
		_shake = SHAKE_TIME
		_shake_size = 1.0
		var reason := str(out.bounce.reason)
		_word("Too steep! Bounced: pull up and come round" if reason == "slam" else "Hopped: %s" % LandingReadout.hop_word(reason))
	elif out.has("settled"):
		var k := float(out.settled.k)
		_thump(k)
		if out.has("greaser"):
			Pad.pulse(0.2,0.1,0.1)
			_word("Greaser!")
		else:
			# Hot or hard: it takes the hit and sticks.
			spray.burst(wheels,k,GRIT_TINT)
			Pad.pulse(0.35+0.4*k,0.2+0.4*k,0.14+0.1*k)
			_shake = SHAKE_TIME
			_shake_size = 0.3+0.7*k
			_word({"hot":"Hot! Drift it to a stop","hard":"Stuck it!","wingtip":"Wingtip! Stuck it"}.get(str(out.settled.grade),"Down"))
		_hop_to = Vector3.INF
	if spray != null: spray.update(delta,wheels,plane.velocity,hand_landing.grit if hand_landing.phase == ManualLanding.ROLL else 0.0,GRIT_TINT)
	if out.has("stopped"): _word("Stopped")
	if out.has("off_edge"): _word("Off the edge")
	if out.has("not_yet"): _word("Stop first  ·  Shift to brake")
	if out.has("wings"): _word("Lift!")
	if out.has("reverse"): _word("Backing up")
	if out.has("edge_behind"): _word("The edge is right behind you")
	if out.has("hit"):
		_thump(0.6)
		Pad.pulse(0.5,0.4,0.15)
		_shake = SHAKE_TIME*0.6
		_shake_size = 1.0
	if hand_landing.phase == ManualLanding.EXIT:
		if _hop_to == Vector3.INF:
			_hop_from = ground_scale.point(plane_figure,plane.position+Vector3.UP*0.1)
			_hop_to = _hop_spot(wheels,float(plane.heading))
			plane_figure.show_pilot(false)
		_hop_figure(hand_landing.hop,delta)
	if out.has("out"): leave_plane(_hop_to)

## The wheels' touch, thump or knock: the wheels' blip and a heavy step on
## the turf, by `k` (0 to 1).
func _thump(k: float) -> void:
	if air != null: air.blip()
	if audio != null: audio.thump(k)
	steps.step("grass",0.4+0.6*k)

## Where the wheels meet the turf now (global).
func _wheels() -> Vector3:
	var p: Vector3 = plane.position
	var under := floor_at(Vector2(p.x,p.z))
	return Vector3(p.x,under if not is_nan(under) else p.y-PlaneStrip.contact(float(plane.pitch)),p.z)

## A word (a touch's grade, a stop, an edge) leading the hint a moment.
func _word(text: String) -> void:
	_said = text
	_said_left = SAY_TIME
	if not flying and _switch_hint != null: _switch_hint.text = _foot_text()

## The touch's shake on the camera, dying away.
func _shaken(delta: float) -> Vector3:
	if _shake <= 0.0: return Vector3.ZERO
	_shake = maxf(0.0,_shake-delta)
	var k := _shake/SHAKE_TIME
	var t := Time.get_ticks_msec()*0.001
	return Vector3(sin(t*71.0),sin(t*53.0+1.3),sin(t*61.0+2.1))*SHAKE*_shake_size*k*k

## F (pad Y) in the plane: in the air the flaps go down or up; on the
## wheels it asks to get out (only stopped does it: ManualLanding `step`
## says "not yet" rolling); taking off, nothing.
func land_key() -> void:
	if not flying or takeoff != null: return
	if hand_landing.flying():
		flaps = not flaps
		_word("Flaps %s" % ("down" if flaps else "up"))
	else:
		_exit_asked = true

## The isle's own step each flown frame, after the plane's step and bump
## (none here).
func _fly_tick(_delta: float) -> void:
	pass

## Puts the plane (flying) at `at` on `heading`, at cruise, the chase camera
## behind it (the quick tests' starts, the tests).
func fly_from(at: Vector3, heading: float) -> void:
	if not flying: return
	takeoff = null
	plane.launch(at,heading,plane.cruise(),false)
	hand_landing.begin(plane)
	plane_figure.reset(plane)
	figure.visible = false
	_new_chase(at+(-plane.forward()*GlideCamera.BACK.x+Vector3.UP*GlideCamera.UP.x)*ground_scale.size())

func _show_fly_hint() -> void:
	if _switch_hint == null or plane == null: return
	var text := ""
	var aloft := takeoff == null and hand_landing.flying()
	if takeoff != null: text = TAKEOFF_HINT
	elif hand_landing.phase == ManualLanding.ROLL and hand_landing.reversing: text = REVERSE_HINT % hand_landing.roll_speed()
	elif hand_landing.phase == ManualLanding.ROLL: text = ROLL_HINT % hand_landing.roll_speed()
	elif not aloft: text = STOPPED_HINT
	elif hand_landing.dipping(): text = DIP_HINT
	else: text = FLY_HINT % [float(plane.speed),bumps,"up" if flaps else "down"]
	if aloft:
		# Low over the turf, what a touch now would get (a slam: too steep).
		var now := LandingReadout.hint_now(hand_landing.grade_now(Callable(self,"floor_at")),_over_turf())
		if now != "": text = now+"  ·  "+text
	if _said_left > 0.0: text = _said+"  ·  "+text
	if aloft:
		if isle_lock != null and isle_lock.locked: text += "\n"+LOCK_HINT % str(_lock_card.get("name",""))
		else:
			var target := lock_target(plane.position)
			if isle_lock == null or lock_reaches(target,plane.position): text += "\n"+LOCK_OFFER % str(target.card.name)
	if stone_plane and lodestone != null:
		if lode_state == "seated":
			text += "\nThe lodestone points the way (%.0f m): turn toward the brighter wing seam (both even and faint: on course)  ·  top or bottom fin lit: climb or dive  ·  tail lit: it is behind you  ·  prow runes flare: dead ahead" % plane.position.distance_to(lode_target)
		else: text += "\nThe stone plane sleeps: find the lodestone on foot and board with it to wake it"
	elif lodestone != null and lode_state == "seated":
		text += "\nThe nose arrow points to the place in the stone (%.0f m): it glows brighter when you are dead on course" % plane.position.distance_to(lode_target)
	_switch_hint.text = text

## How high the plane flies over what is under it (m, the flight's ground;
## NAN over open sky).
func _over_turf() -> float:
	var under: Variant = plane_ground(plane.position)
	return NAN if under == null else float(plane.position.y)-float(under)-SkyPlane.SKIM

## The landing's live numbers for F1 in the plane (scripts/
## landing_readout.gd): what a touch now would get and the dive against
## the slam's limits, or on the wheels how it rolls.
func _show_plane_hud() -> void:
	if _hud == null or not _hud.visible or plane == null: return
	var lines := PackedStringArray(["plane     %s · %.1f m/s · %s m over the turf" % [ManualLanding.NAMES[hand_landing.phase],float(plane.speed),
		"-" if is_nan(_over_turf()) else "%.1f" % _over_turf()]])
	if hand_landing.flying():
		lines.append("touch now %s" % LandingReadout.touch_now(hand_landing.grade_now(Callable(self,"floor_at"))))
		lines.append(LandingReadout.dive_line(hand_landing))
	else:
		lines.append(LandingReadout.wheels_line(hand_landing))
	var s: Dictionary = hand_landing.stats
	lines.append("touches %d · hops %d %s · go-arounds %d · last %s" % [(s.touches as Array).size(),int(s.bounces),str(s.bounce_reasons),int(s.go_arounds),hand_landing.last_touch if hand_landing.last_touch != "" else "-"])
	_hud.text = "\n".join(lines)

## The turf's height under the wheels at a global XZ point (NAN off it:
## past its edge, or rising past what they reach): read from FLOOR_UP m
## over the plane down to FLOOR_DOWN m under it, the turf only, upward faces
## only. The hand landing's `floor_at` (scripts/manual_landing.gd `step`),
## as the game's is its heightfield.
func floor_at(p: Vector2) -> float:
	return _turf_near(p,float(plane.position.y) if plane != null else isle_top())

## The turf's top at `p` from FLOOR_UP m over `y` down to FLOOR_DOWN m under
## it (NAN none).
func _turf_near(p: Vector2, y: float) -> float:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,y+FLOOR_UP,p.y),Vector3(p.x,y-FLOOR_DOWN,p.y),TURF_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.3: return NAN
	return float((hit.position as Vector3).y)

## `_turf_near` round a fixed height, for a pose sat on the turf at `y`
## (PlaneStrip `rest`): where none, `y` itself.
func _floor_from(y: float) -> Callable:
	return func(p: Vector2) -> float:
		var h := _turf_near(p,y)
		return y if is_nan(h) else h

## Whether something stands in the rolling wheels' way at `point` (global,
## the plane's middle there; ManualLanding `step`'s `blocked`): stone in
## the wing-wide bump body, or the turf rising into the fuselage's box (a
## step up the wheels can't climb, a crag's face).
func roll_blocked(point: Vector3) -> bool:
	var turn := Basis(Vector3.UP,float(plane.heading) if plane != null else 0.0)
	if _stone_at(point,turn): return true
	if _fuselage_query == null:
		_fuselage_query = PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(FUSELAGE,BUMP_BODY.y,BUMP_BODY.z)*ground_scale.plane_scale
		_fuselage_query.shape = box
		_fuselage_query.collision_mask = TURF_LAYER
	_fuselage_query.transform = Transform3D(turn,point+turn*ground_scale.middle_shift())
	return not get_world_3d().direct_space_state.intersect_shape(_fuselage_query,1).is_empty()

## Stone (with `with_turf`, the turf too) in the plane's wing-wide body
## (BUMP_BODY) at `point`, turned by `turn`.
var _stone_query: PhysicsShapeQueryParameters3D
var _fuselage_query: PhysicsShapeQueryParameters3D
var _no_rids: Array[RID] = []

func _stone_at(point: Vector3, turn: Basis, with_turf := false) -> bool:
	if _stone_query == null:
		_stone_query = PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = BUMP_BODY*ground_scale.plane_scale
		_stone_query.shape = box
		_stone_query.collision_mask = plane_mask()
	_stone_query.exclude = _no_rids if with_turf else _turf_rids
	_stone_query.transform = Transform3D(turn,point+turn*ground_scale.middle_shift())
	return not get_world_3d().direct_space_state.intersect_shape(_stone_query,1).is_empty()

## The longest straight run of clear turf over `outline` (world x, z;
## its turf about height `y`), for the world view's landing-strip warning
## (scripts/layout_edit.gd): from points on a RUN_GRID m grid inside it,
## 8 ways, each followed both sides in 1 m steps until the turf ends,
## steps more than RUN_STEP m, stone stands in the wings' way, or turf or
## stone hangs within RUN_ROOM m over it (an island moved over). Stops
## looking once a run reaches `cap` m.
const RUN_GRID := 6.0
const RUN_STEP := 0.4
const RUN_ROOM := 4.0

func longest_run(outline: PackedVector2Array, y: float, cap := 40.0) -> float:
	if outline.size() < 3: return 0.0
	var rect := Rect2(outline[0],Vector2.ZERO)
	for p: Vector2 in outline: rect = rect.expand(p)
	var best := 0.0
	var gx := rect.position.x+fmod(rect.size.x,RUN_GRID)*0.5
	while gx <= rect.end.x:
		var gz := rect.position.y+fmod(rect.size.y,RUN_GRID)*0.5
		while gz <= rect.end.y:
			var p := Vector2(gx,gz)
			gz += RUN_GRID
			if not Geometry2D.is_point_in_polygon(p,outline): continue
			var h := _turf_near(p,y)
			if is_nan(h): continue
			for k in range(8):
				var dir := Vector2.from_angle(PI*k/8.0)
				var turn := Basis(Vector3.UP,atan2(-dir.x,-dir.y))
				var run := _run_way(p,dir,h,turn,cap)+_run_way(p,-dir,h,turn,cap)
				if run > best: best = run
				if best >= cap: return cap
		gx += RUN_GRID
	return best

func _run_way(p: Vector2, dir: Vector2, h: float, turn: Basis, cap: float) -> float:
	var space := get_world_3d().direct_space_state
	var t := 1.0
	while t <= cap:
		var q := p+dir*t
		var n := _turf_near(q,h)
		if is_nan(n) or absf(n-h) > RUN_STEP: break
		if _stone_at(Vector3(q.x,n+PlaneStrip.contact(PlaneStrip.REST_PITCH),q.y),turn): break
		# Room over it: no turf or stone (another island's keel) overhead.
		var up := PhysicsRayQueryParameters3D.create(Vector3(q.x,n+0.3,q.y),Vector3(q.x,n+RUN_ROOM,q.y),TURF_LAYER|plane_mask())
		if not space.intersect_ray(up).is_empty(): break
		h = n
		t += 1.0
	return t-1.0

## The best run to take off along from `at` (global XZ, the turf there at
## height `y`) facing `heading`, as PlaneStrip `takeoff` reads the plate
## (and the landing study its fields): each of 24 ways followed in 0.5 m
## steps up to RUN_LOOK m, until the turf ends (an edge: it flies off it),
## rises or drops past the wheels, or stone stands in the wings' way; a run
## whose climb out meets stone counts as short. {dir (Vector3, level),
## length, edge, score}.
const RUN_LOOK := 14.0

func takeoff_run(at: Vector2, heading: float, y: float) -> Dictionary:
	var best := {}
	var facing := Vector2(-sin(heading),-cos(heading))
	var space := get_world_3d().direct_space_state
	for k in range(24):
		var dir := Vector2.from_angle(TAU*k/24.0)
		var turn := Basis(Vector3.UP,atan2(-dir.x,-dir.y))
		var t := 0.5
		var h := y
		var edge := false
		while t <= RUN_LOOK:
			var p := at+dir*t
			var next := _turf_near(p,h)
			if is_nan(next):
				# Past the edge if nothing stands over the run's height there.
				var over := PhysicsRayQueryParameters3D.create(Vector3(p.x,h+20.0,p.y),Vector3(p.x,h,p.y),TURF_LAYER)
				edge = space.intersect_ray(over).is_empty()
				break
			if _stone_at(Vector3(p.x,next+PlaneStrip.contact(PlaneStrip.REST_PITCH),p.y),turn): break
			h = next
			t += 0.5
		var length := t-0.5
		# The climb out: on along the run and up, clear of stone.
		var climb := 1.0
		var from := Vector3(at.x+dir.x*length,h,at.y+dir.y*length)
		for s in range(1,4):
			var q := from+Vector3(dir.x,0.0,dir.y)*4.0*s+Vector3.UP*(1.0+1.2*s)
			if _stone_at(q,turn,true): climb = 0.0
		var score := minf(PlaneStrip.LIFT_RUN if edge else length,PlaneStrip.LIFT_RUN)*2.0*(0.5+0.5*climb)+(1.5 if edge else 0.0)+PlaneStrip.ON_WAY*dir.dot(facing)
		if best.is_empty() or score > float(best.score): best = {"dir":Vector3(dir.x,0.0,dir.y),"length":length,"edge":edge,"score":score}
	return best

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
		box.size = BUMP_BODY*ground_scale.plane_scale
		_bump_query.shape = box
		_bump_query.collision_mask = plane_mask()
	var turn := PlaneFigure.pose(Vector3.ZERO,float(plane.heading),float(plane.pitch),float(plane.bank)+float(plane.spin)).basis
	_bump_query.transform = Transform3D(turn,plane.position+turn*ground_scale.middle_shift())
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
	plane.glance(normal,BUMP_KEEP,SkyPlane.SLOW)
	# Turned, its wings may reach into the face again: out along it.
	for i in range(10):
		if space.get_rest_info(_plane_query()).is_empty(): break
		plane.position += normal*0.1
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

## The share of the way from `from` to `to` clear of stone and turf (the
## chase camera's sight of the plane), 1 clear.
func _sight(from: Vector3, to: Vector3) -> float:
	if _sight_ray == null:
		_sight_ray = PhysicsRayQueryParameters3D.new()
		_sight_ray.collision_mask = plane_mask()
		_sight_ray.hit_back_faces = true
	_sight_ray.from = from
	_sight_ray.to = to
	var hit := get_world_3d().direct_space_state.intersect_ray(_sight_ray)
	if hit.is_empty(): return 1.0
	return from.distance_to(hit.position)/maxf(from.distance_to(to),0.001)

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

## The plane's keys, mouse and pad: F or Y the flaps in the air and out
## once stopped (`land_key`), R on foot at the start, Q E knife edge (twice quick a roll), the mouse steers, a click
## rolls, the right button held looks round, Esc frees the mouse.
func _fly_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): chase.turn(Vector2(-event.relative.x,-event.relative.y)*FLY_LOOK)
		else: _fly_look += Vector2(event.relative.x,-event.relative.y)*FLY_LOOK
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else: _roll_asked = -1.0 if float(plane.bank) < -0.05 else 1.0
	elif Pad.pressed(event,&"fly_land"): land_key()
	elif Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
	elif Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F: land_key()
			KEY_F1: _hud.visible = not _hud.visible
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

## A capture from a fixed eye (--at) stops `_process`; an isle steps what
## else should move meanwhile here.
func _capture_tick(_delta: float) -> void:
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
			_capture_tick(1.0/60.0)
			await get_tree().process_frame
		if _capture_wait > 4.0: await get_tree().create_timer(_capture_wait-4.0).timeout
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
	for n in range(_capture_count):
		if n > 0:
			await get_tree().create_timer(_capture_every).timeout
			await RenderingServer.frame_post_draw
		var path := _capture if _capture_count == 1 else "%s_%d.png" % [_capture.get_basename(),n]
		get_viewport().get_texture().get_image().save_png(path)
		print("%s: saved %s (%s; %.2f ms a frame, vsync off; %d draw calls, %d primitives)" % [isle_name(),path,look_id,frame_ms,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()

# --- The sky round it ----------------------------------------------------------------

## The sky round the isle lived in (studies/aqueduct_isle_sky.gd): far isles,
## airships, the CPU planes, open-air life, motes and a few tokens for the
## plane; each with its own --no-... flag. A capture waits for it whole.
var sky: Node3D

## The scene's cloud host (scripts/cloud_host.gd), the sky's: what the look
## pass hands the cloud volume. Null without one.
func cloud_host() -> Node:
	return sky.get("clouds") if sky != null else null

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
	_said_left = maxf(_said_left-delta,0.0)
	if _stranded_left >= 0.0:
		_stranded_left -= delta
		if _stranded_left < 0.0:
			_return_to_plane()
			return
	if lode_state == "inspecting":
		_inspect_step(delta)
		return
	var was_grounded := motor.grounded
	var falling := motor.velocity.y
	# Off the edge the stranding rule is the net, not the study's `lost`.
	var keep := lost
	if off_edge: lost = -INF
	if not scripted: _gust_input()
	super.tick(delta)
	lost = keep
	if gust_shot != null and delta > 0.0: gust_shot.step(delta,motor.feet,get_world_3d().direct_space_state)
	_lode_step(delta)
	if life != null: life.step_pilot()
	if plane_arc != null: plane_arc.step_pilot(delta)
	if not flying:
		_tread(delta,was_grounded,falling)
		_check_step_off()
		_watch_off_edge()
		_show_foot_hint()

## What the feet are on, as the isle's sound reads it (stone, grass, a
## bridge's planks, water), for the steps and puffs.
func _surface() -> String:
	return audio.surface(motor) if audio != null else super._surface()

## The study's jumps, landings and moves, and the isle's sound over them.
func _motor_events(events: Dictionary) -> void:
	super._motor_events(events)
	if audio != null: audio.body(events)

func _show_foot_hint() -> void:
	if _switch_hint == null or flying: return
	var text := _foot_text()
	if _switch_hint.text != text: _switch_hint.text = text

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
	body.drive(motor.pose(),delta)
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
	var board: String = plane_arc.board_line() if plane_arc != null else ""
	var text: String = (board if board != "" else BOARD_LINE)+"  ·  R3 camera back behind" if by_plane() else FOOT_HINT
	var arc_line: String = plane_arc.hint() if plane_arc != null else ""
	if arc_line != "": text += "\n"+arc_line
	if _stranded_left >= 0.0: text = STRANDED_HINT
	elif motor.move == "sail": text = SAIL_HINT
	elif off_edge: text = FALL_HINT
	if _said_left > 0.0: text = _said+"  ·  "+text
	if telescope != null and telescope.busy(): text = LOOK_HINT
	if lodestone == null: return text
	var line := ""
	match lode_state:
		"resting": line = "E (pad A): pick up the lodestone" if can_pick() else lode_hint()
		"inspecting": line = "Drag or right stick: turn the lodestone  ·  E or Enter (pad A or B): keep it"
		"carried": line = "Carrying the lodestone: Space (pad A) by your plane to board, and it seats in the plane"
	return text+"\n"+line

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

# --- Off the edge: the pocket sail ---------------------------------------------------

## Walked, jumped or knocked off the isle: falling STEP_OFF_DROP m under
## where he last stood with nothing under him for STEP_OFF_CLEAR m, he is
## off the edge. A jump between stones, or a drop onto a lower tier, has
## ground under it and stays an ordinary fall.
func _check_step_off() -> void:
	if flying or off_edge or not walk_ready or not _replay.is_empty(): return
	if motor.grounded or motor.on_ledge() or motor.swimming or motor.velocity.y >= 0.0: return
	if motor.feet.y > _last_stood.y-STEP_OFF_DROP: return
	var ray := PhysicsRayQueryParameters3D.create(motor.feet,motor.feet+Vector3.DOWN*STEP_OFF_CLEAR,1|TURF_LAYER)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return
	_step_off()

## Off the edge: he stays on foot, the motor's fall and its sail (Space,
## pad A) his to use; nothing opens by itself. The plane stays parked.
func _step_off() -> void:
	off_edge = true
	_off_y = _last_stood.y
	_stranded_left = -1.0
	_show_foot_hint()

## Off the edge, each step: down on ground or a ledge within STRAND_BELOW m
## of the edge, he walks (or climbs) back; once STRAND_BELOW m under the
## edge, or down in water, stranded.
func _watch_off_edge() -> void:
	if not off_edge or _stranded_left >= 0.0: return
	if motor.swimming or motor.feet.y < _off_y-STRAND_BELOW:
		_strand()
		return
	if motor.grounded or motor.on_ledge(): off_edge = false

func _strand() -> void:
	_stranded_left = STRANDED_WAIT
	_show_foot_hint()

## Back on foot beside the parked plane (to its left, as a hop out of it
## lands), facing it; with none parked, at the start.
func _return_to_plane() -> void:
	_end_fall()
	if not parked:
		respawn()
		return
	var spot := _hop_spot(parked_at,parked_heading)
	var to := Vector2(parked_at.x-spot.x,parked_at.z-spot.z)
	place(spot,to.normalized() if to.length() > 0.01 else start_face)
	_last_stood = spot

## No longer off the edge nor stranded.
func _end_fall() -> void:
	off_edge = false
	_stranded_left = -1.0

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
