extends Node3D
## Endless flight, round 1 (docs/design/endless-flight/round-1-handoff.md):
## the game's plane over endless streamed land. It starts in the air, in
## the plane the aqueduct isle flies (scripts/sky_plane.gd at the game's
## speed, the hand landing scripts/manual_landing.gd, the figure scripts/
## plane_figure.gd and its ground scale, the chase camera scripts/
## glide_camera.gd), flown by the same keys, mouse and pad. Under it the
## land streams in chunks round the camera (scripts/endless/land_stream.gd
## over scripts/endless/land_field.gd): rolling hills, a few mountains,
## coast and sea, and broad flat meadows to put it down on. Land on the
## turf as on the isle; stopped, Space (Boost) rolls it off again. (Getting
## out and walking was cut on 2026-10-24: docs/archive.md.)
##
## Keys: WASD or the left stick bank and pitch (W nose down), the mouse
## steers, Space boost, Shift brake, Q E held knife edge (twice quick a
## barrel roll, or click, or Z / the pad's south face on one press), F flaps in the air (pad Y), hold right mouse to
## look round, F1 the numbers, R back up into the air over where it is, Esc
## lets the mouse go. B (pad X) spends the near misses' meter on a surge; on a
## full meter the roll button (or B) is the surge roll (scripts/endless/surge_smash.gd).
##
## Near misses (the weighted presets; docs/design/endless-flight/
## near-miss-handoff.md): low and fast the plane settles toward the land
## (SkyPlane `low`), what it runs into is a scrape or a crash (scripts/
## endless/flight_contact.gd), and how close its body comes to the land, a
## tree or a ruin scores (scripts/endless/near_miss.gd), chained into the
## surge's meter; the HUD (scripts/endless/near_miss_hud.gd), the debris
## (scripts/endless/flight_debris.gd), a FOV punch and a shake show it.
## A spruce flown into is knocked down instead, at a scrape's cost (scripts/
## endless/tree_knock.gd; docs/design/endless-flight/tree-knockdown-handoff.md).
##
##   ./run-endless-flight.command [--seed=7]
##   godot --path . res://studies/endless_flight.tscn -- --no-title [--seed=7] [--at=x,z] [--heading=deg] [--alt=m]
##
## The main menu (docs/design/endless-flight/main-menu-handoff.md): without
## `--no-title` it opens on the plane parked in a meadow near the start
## (scripts/endless/menu_spot.gd), idling, the eye circling it, the ZENSCAPE
## inscription and Start over it (scripts/endless/main_menu.gd); Start
## swings the eye round behind it, runs it up and rolls it off into the
## flight (scripts/endless/menu_stage.gd). `--no-title` (the harness's, the
## captures') starts in the air as ever.
##
## The world: this script is the engine's (the plane and flight,
## streaming, the look, the dressing machinery, the HUD and harness hooks);
## what makes the world this world is its profile
## (scripts/endless/world/world_profile.gd, profiles/<id>.gd): --world=ID
## (regions, wilderness with the amberlands; wilderness, amberlands and
## overgrown alone; test_dry is a test profile). The profile sets the defaults;
## every flag below still wins (docs/design/endless-flight/world-profiles-handoff.md).
##
## Flags: --seed=N the land (1), --at=x,z where it starts (0,0), the land's shape
## (land_field.gd): --mountains=X, --peaks=X, --valleys=X, --no-valleys,
## --old-land (round one's land and ceiling), --ceiling=m over the sea (Field
## CEILING_OVER; under THIN_OVER the air thins from THIN_OVER_OLD), --climb=old
## the slow thin air from 215 m, as before,
## --heading=deg clockwise from -z (0; `sun` toward the sun), --alt=m over
## the ground (45), --numbers opens with F1's numbers shown, --uncapped
## turns vsync and the frame cap off (the fps is then the frame's cost),
## --max-fps=N caps the frame rate at N (0 none; vsync stays on), a rate the
## machine holds every frame so it never jumps between the screen's rate and
## half of it (77 or 120 on a 154 Hz screen).
## Split mountains (scripts/endless/split_sites.gd): --split-near-start starts
## 520 m out of the nearest one's lower mouth, heading in, 28 m up or more
## to clear the land on the way in (--alt wins); --splits=X their density, --no-splits none, --split-kind=K every
## one of kind K (slot, winding, gorge, grand) where it fits, --split-slot=X
## the slot kind's toy width (6: 12 m).
## The pirate ships (scripts/endless/pirate_ship.gd): --ship-start starts in the
## air off the first's beam, --full-meter with the meter full, and again each time
## a ship's plates come back or the plane leaves a sinking one; --ship-return=S the
## least seconds before a sunk ship returns; --no-ship leaves both out and --one-ship
## the second (for timing against them).
## Water (scripts/endless/water_contact.gd): --water-near-start starts 3 m
## over the sea off the nearest river's mouth, heading for it; --water-contact=0
## turns the cushion, spray, marks and wet screen off.
## The look (scripts/endless/endless_look.gd): --mood=ID one of its
## moods (alpine_morning), --hour=H the sun's hour, held (the mood's; the
## day cycle runs from it by default: --day=0 stops it, --day-length=S,
## --day-at=dawn|noon|dusk|blue), --plain-look round one's plain sky and
## colours; T sweeps to the next stop of the day (dawn, noon, dusk, blue
## hour), ] and [ run time faster and back (1, 8, 30, 120 times), L the next
## mood. The clouds (scripts/endless/
## endless_clouds.gd): --no-clouds, --cloud-cover=X (1), --cloud-field=old (the
## earlier near-grid of mushrooms), --cloud-half-res (the earlier march); C turns them off
## and on. The grass carpet (scripts/endless/endless_grass.gd): --no-grass,
## --grass=X (its density, 1), --grass-range=M (how far the tufts reach,
## 230), --grass-lod=x,y,z,w (its rings, 16,30,150,230), --no-flowers,
## --grass-fine=X (the near ring's fine tuft at X of the isle's density,
## 1.2; 0: the isle's own tuft), --grass-patches=X (how much of the ground's
## patches the tufts carry, 1), --grass-set= / --far-set= / --ground-set=
## name=value (a shader setting, for tuning by hand), --flower-drifts=X
## (how many flower drifts, 1; 0 or --no-drifts: round 4's), --grass-regions=X
## (how strongly the grass's colour regions show, 1; 0 or --no-regions:
## one palette), --grass-lead=X (how far its rings lead out ahead along the
## view, 0.45), --no-grass-lead, --grass-flat-up=M (the height its rings are
## measured along the ground to, 20), --grass-ring=3d (the old 3D rings),
## --grass-silver=X (the silvery undersides the gusts flip into view, 0.8;
## 0 or --no-grass-silver: off), --grass-cover=old (bare slopes and hills as
## before the bare-patches round), --grass-slope=a,b; G
## turns it off and on. The grass reacting (scripts/endless/grass_react.gd):
## --no-grass-react, --no-prop-wash, --no-grass-gusts, --no-grass-part,
## --prop-wash=X, --grass-gusts=X, --gust-every=S, --grass-bend=X. The arches (scripts/endless/land_arches.gd):
## --arches=X (how many, 1; 0 or --no-arches none), --rock-arches=X /
## --ruin-arches=X (each family's share, 1; 0 none). The free-standing rock
## shapes (scripts/endless/land_rocks.gd, every kind in scripts/endless/
## rocks/rock_plan.gd): --rocks=stacks,hoodoos (each at 1; kind:X, all),
## --stacks=X, --hoodoos=X, --no-rocks, --hoodoo-shape=squat|tall|mix|0..1,
## --rock-start=stacks|hoodoos (start by the nearest group of that kind,
## flying in), --no-rock-lod. The spruce forests
## (scripts/endless/land_trees.gd): --no-trees, --forest=X (their share, 1),
## --forest-meadows=X (how far onto the meadows, as groves, 1; 0 none).
## The birds (scripts/endless/endless_birds.gd): --birds=0 off, --birds=X,
## --bird-range=X, --bird-size=X, --bird-ride=S, --ambient-birds=X.
## Other planes (scripts/endless/endless_traffic.gd): --traffic=0 off,
## --traffic=N how many (3), --trails=0 no smoke trails.
## The plane's speed (SkyPlane FLIGHT_SPEED, use_flight_speed): --plane-speed=X
## (times the toy's 14 m/s cruise, 2.1; 1.15 the isles'), --plane-turn=X; the
## view widens with speed RUSH_FOV times the chase's own (--cam-speed-fov=X
## sets it), and past cruise the eye can buffet a little (--rush=X, 0 off by default).

const Field = preload("res://scripts/endless/land_field.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")
const GiantRuins = preload("res://scripts/endless/giant_ruins.gd")
const LandStream = preload("res://scripts/endless/land_stream.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const GraphicsPreset = preload("res://scripts/graphics_preset.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneGroundScale = preload("res://scripts/plane_ground_scale.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Pad = preload("res://scripts/pad.gd")
const PhotoMode = preload("res://scripts/endless/photo_mode.gd")
const EndlessLook = preload("res://scripts/endless/endless_look.gd")
const EndlessGrass = preload("res://scripts/endless/endless_grass.gd")
const GrassReact = preload("res://scripts/endless/grass_react.gd")
const EndlessEddies = preload("res://scripts/endless/endless_eddies.gd")
const EndlessMotes = preload("res://scripts/endless/endless_motes.gd")
const LandArches = preload("res://scripts/endless/land_arches.gd")
const LandRocks = preload("res://scripts/endless/land_rocks.gd")
const PeakTowers = preload("res://scripts/endless/rocks/peak_towers.gd")
const LandHalls = preload("res://scripts/endless/land_halls.gd")
const SplitSites = preload("res://scripts/endless/split_sites.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const LandTrees = preload("res://scripts/endless/land_trees.gd")
## The birds (scripts/endless/endless_birds.gd; --birds=0 off).
const EndlessBirds = preload("res://scripts/endless/endless_birds.gd")
## Fish leaping in the ponds (scripts/endless/endless_fish.gd; --fish=0 off).
const EndlessFish = preload("res://scripts/endless/endless_fish.gd")
## Other planes and their trails (--traffic=0 off).
const EndlessTraffic = preload("res://scripts/endless/endless_traffic.gd")
## The rival race against one of them (Tab / R3 held on a bracketed plane).
const RivalRace = preload("res://scripts/endless/rival_race.gd")
## The shops beside their strips (scripts/endless/shop_sites.gd; --shops=0 none).
const ShopSites = preload("res://scripts/endless/shop_sites.gd")
const RegionDoors = preload("res://scripts/endless/region_doors.gd")
const HallDoors = preload("res://scripts/endless/hall_doors.gd")
## The crown's spirals of cloud (scripts/endless/peak_spirals.gd; --spirals=0 none).
const PeakSpirals = preload("res://scripts/endless/peak_spirals.gd")
const PeakSpindrift = preload("res://scripts/endless/peak_spindrift.gd")
const BeatRoutes = preload("res://scripts/endless/beat_routes.gd")
## Place lines: standing routes with a timed record (--lines=0 none).
const PlaceLines = preload("res://scripts/endless/place_lines.gd")
const Finds = preload("res://scripts/endless/finds.gd")
const BurrowerFlight = preload("res://scripts/endless/burrower_flight.gd")
const Stomper = preload("res://scripts/endless/stomper.gd")
const SurgeSmash = preload("res://scripts/endless/surge_smash.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const AirLift = preload("res://scripts/endless/air_lift.gd")
## The Peak's ways up: the couloir's lift.
const PeakRoutes = preload("res://scripts/endless/peak_routes.gd")
const PeakStair = preload("res://scripts/endless/peak_stair.gd")
const PeakSnow = preload("res://scripts/endless/peak_snow.gd")
## The pad's rumble (scripts/endless/flight_rumble.gd).
const FlightRumble = preload("res://scripts/endless/flight_rumble.gd")
const FlightWeight = preload("res://scripts/flight_weight.gd")
const FlightPace = preload("res://scripts/flight_pace.gd")
const SpeedStreaks = preload("res://scripts/endless/speed_streaks.gd")
## The plane's and the air's sound (scripts/endless/flight_sound.gd; --sound=0 off).
const FlightSound = preload("res://scripts/endless/flight_sound.gd")
## Near misses, the land's contact, their HUD and debris (weighted presets).
const NearMiss = preload("res://scripts/endless/near_miss.gd")
const FlightContact = preload("res://scripts/endless/flight_contact.gd")
const KnifeGlance = preload("res://scripts/endless/knife_glance.gd")
const NearMissHud = preload("res://scripts/endless/near_miss_hud.gd")
const NearMissHudGlyph = preload("res://scripts/endless/near_miss_hud_glyph.gd")
const NearMissHudHandoff = preload("res://scripts/endless/near_miss_hud_handoff.gd")
const NearMissHudRing = preload("res://scripts/endless/near_miss_hud_ring.gd")
const FlightDebris = preload("res://scripts/endless/flight_debris.gd")
## Low over water: the cushion, the spray, the wake's marks, the wet screen.
const WaterContact = preload("res://scripts/endless/water_contact.gd")
## Spruces flown into are knocked down (weighted presets).
const TreeKnock = preload("res://scripts/endless/tree_knock.gd")
## The main menu: the parked plane's spot, the stage and the overlay.
const MenuSpot = preload("res://scripts/endless/menu_spot.gd")
const MenuStage = preload("res://scripts/endless/menu_stage.gd")
const MainMenu = preload("res://scripts/endless/main_menu.gd")

const FLY_LOOK := 0.0025
const STICK_LOOK := 2.4
const LOOK_LINGER := 2.5
## The sky and the haze: the fog thickens from FOG_BEGIN m to FOG_END m,
## inside the land's far edge (LandStream ROOT_REACH root chunks out).
const HORIZON := Color("cfdde6")
const FOG_BEGIN := 900.0
const FOG_END := 7000.0
const FOG_DENSITY := 0.00028
const SEA_COLOUR := Color("2f6f8f")
const SEA_SIZE := 40000.0
## The plane's start over the ground (m), and the eye's clearance over it.
const START_ALT := 45.0
const EYE_CLEAR := 0.6
## Speed's feel: the chase's speed widening times RUSH_FOV (GlideCamera
## FOV_FAST; at cruise about +6 degrees, at boost +12), and the wind's
## buffet on the eye, RUSH_SHAKE radians at most, coming in from
## RUSH_FROM of the cruise to Boost's speed, shaken at RUSH_HZ.
const RUSH_FOV := 1.8
const RUSH_SHAKE := 0.0045
const RUSH_FROM := 0.9
const RUSH_HZ := Vector3(7.3,11.9,17.1)
## Wingtip vapour (PlaneFigure `update`'s `near`): pulled off as the flight
## path turns faster than VAPOUR_TURN.x radians a second, full at .y (a
## hard turn or pull-up), the stronger the faster it flies; never on the
## wheels. Skimming for the rumble: within SKIM_LOW m of the land (times
## the plane's size) at cruise or more.
const VAPOUR_TURN := Vector2(0.7,1.5)
const SKIM_LOW := 4.0
## The near misses' feel: a scored moment widens the view PUNCH degrees by
## its closeness, eased in over PUNCH_IN s and dying over PUNCH_FADE s. The
## eye's shake is off by default (the camera stays smooth; the buffet is felt
## in the plane, the rumble and the sound): SHAKE times (`--shake=<x>`, 1 the
## near-miss round's amounts) a scored moment's NEAR_SHAKE radians by its
## closeness, a scrape's SCRAPE_SHAKE, and low and fast the air's LOW_SHAKE at
## the land (by SkyPlane `low` and the speed), dying over SHAKE_FADE s.
const PUNCH := 3.0
const PUNCH_IN := 0.12
const PUNCH_FADE := 0.4
const SHAKE := 0.0
const NEAR_SHAKE := 0.006
const SCRAPE_SHAKE := 0.012
const LOW_SHAKE := 0.0022
const SHAKE_FADE := 0.3
const SHAKE_HZ := Vector3(13.1,17.3,21.7)
## Spray trails off the water under SPRAY_SPANS wingspans, over SPRAY_FAST
## of cruise.
const SPRAY_SPANS := 0.8
const SPRAY_FAST := 0.7
## A crash: back CRASH_BACK m along the way it came, CRASH_UP m over the
## highest of what stands from there to CRASH_LOOK m on, the screen dipped
## dark and lifting over FADE_TIME s.
const CRASH_BACK := 45.0
const CRASH_UP := 14.0
const CRASH_LOOK := 140.0
## Into a tower's wall (`_off_tower`): how far out from the face it flies on,
## and the level part of the face's normal that makes it a wall, not its top.
const CRASH_OFF := 40.0
const CRASH_WALL := 0.6
const FADE_TIME := 0.7

## True once the land under the start stands and it flies (the harness
## waits on it: tools/harness/drive.gd `open`).
var walk_ready := false
var seed := 1
## The world profile in play (--world=; scripts/endless/world/world_profile.gd).
var world: RefCounted
var land: Node3D
var field: RefCounted
var camera: Camera3D
var plane: RefCounted
var plane_figure: Node3D
var chase: RefCounted
var hand_landing := ManualLanding.new()
## Lift (scripts/endless/air_lift.gd): rising air along the paths places
## add to it, still air elsewhere; `air` is the plane's air callable.
## `--lift=0`: none, and the plane gets no air callable, as before.
var air_lift: AirLift = AirLift.new() if AirLift.flag() else null
var air: Callable = Callable(air_lift,"air_at") if air_lift != null else Callable()
var ground_scale := PlaneGroundScale.new()
var flaps := false
var sea: MeshInstance3D
## The look (sky, light, haze, ground, sea), or null under --plain-look.
var look: Node3D
## The grass carpet round the eye (off at the start under --no-grass), or
## null under --plain-look.
var grass: Node3D
## The grass reacting to the wash and the gusts (scripts/endless/
## grass_react.gd), or null under --no-grass-react or --plain-look.
var react: Node
## The gusts as sweeping breeze ribbons (scripts/endless/endless_eddies.gd), or null under --gusts=rings.
var eddies: Node3D
## The pollen and the grass the wash kicks up (scripts/endless/endless_motes.gd).
var motes: Node3D
var snow: Node
## The arches over the land (scripts/endless/land_arches.gd).
var arches: Node3D
## The free-standing rock shapes, every kind (scripts/endless/land_rocks.gd).
var rocks: Node3D
## The Peak's hero towers (scripts/endless/rocks/peak_towers.gd; --towers=0 off).
var towers: Node3D
## --rock-start's pose and group ({at, heading, alt, spec}), or {}.
var rock_start := {}
## The slot halls in the ridges' cuts (scripts/endless/land_halls.gd).
var halls: Node3D
## The mountain tunnels' bores (scripts/endless/land_tunnels.gd).
var tunnels: Node3D
## The spruce forests (scripts/endless/land_trees.gd; off under --no-trees).
var trees: Node3D
## The birds flushed from the trees and the far flocks.
var birds: Node3D
var fish: Node3D
## Other planes in the sky, or null under --traffic=0.
var traffic: Node
## The rival race (scripts/endless/rival_race.gd), or null with no traffic.
var race: Node
## The shops (scripts/endless/shop_sites.gd).
var shops: Node
## The lighthouse and the pirate ships on the coast (scripts/endless/coast_sites.gd).
var coast: Node3D
var giants: Node3D
## Beat routes: starters in the land, the pan, one beat at a time (beat_routes.gd).
var beats: Node
## The place lines (scripts/endless/place_lines.gd), or null with --lines=0.
var lines: Node
## The Peak's ruined stair up the couloir (scripts/endless/peak_stair.gd), or
## null with no Peak or --stair=0.
var stair: Node3D
var spirals: Node3D
var spindrift: Node3D
## The burrower, woken by a chosen skim (scripts/endless/burrower_flight.gd;
## --no-burrower: none).
var burrower: Node
var stomper: Node3D
## The towers that lead from the start to the ruin and the isles (scripts/endless/way_towers.gd).
var way: Node3D
## The surge roll, the breaks and the cracked walls (scripts/endless/surge_smash.gd).
var smash: Node3D
var flown := 0.0
var _start := Vector2.ZERO
## The Peak's sky of its own hour stands over this band (m over the sea: up
## the wall, under the plateau and the lake), round a point COLLAR_AT m along
## the massif's axis, out to COLLAR_R. The collar, a disc of cloud on the same
## band, stands only with --collar=1 (the spirals took its place).
const COLLAR_AT := 40.0
const COLLAR_R := 520.0
const COLLAR_BAND := Vector2(755.0,855.0)
var _no_title := false
var _heading := 0.0
## A heading named by the world's spawn or --heading=: the start does not
## turn to face the Peak.
var _heading_given := false
var _face_sun := false
var _numbers := false
var _alt := START_ALT
var _alt_given := false
var _fly_look := Vector2.ZERO
var _roll_asked := 0.0
var _hud: Label
## The plane's ceiling over the sea (Field CEILING_OVER; --ceiling=).
var _ceiling_over := Field.CEILING_OVER
## The slow thin air from 215 m (--climb=old).
var _climb_old := false
var _hint: Label
## Over the hint, on the wheels: stopped, how to roll off and back up;
## backing up, how to stop (`_stop_note`).
var _stop_cue: Label
## A world of regions (--world=regions): the caption naming the region the
## eye crosses into, and --region-debug's line (region, cell, weights).
var _region_caption: Label
var _region_debug: Label
var _region_id := ""
var _region_shown := -100000
## The caption shows for REGION_HOLD ms, then fades over REGION_FADE.
const REGION_HOLD := 3500
## The plane's weight preset (scripts/flight_weight.gd; `--weight=`, else
## medium), cycled with V or the pad's d-pad up (`fly_weight`); the note
## that names it, held WEIGHT_HOLD ms and faded over WEIGHT_FADE ms.
var weight := FlightWeight.flag(FlightWeight.DEFAULT)
var _weight_note: Label
var _weight_shown := -100000
const WEIGHT_HOLD := 1400
const WEIGHT_FADE := 600
## The plane's pace preset (scripts/flight_pace.gd; `--pace=`, else brisk),
## cycled with P or the pad's d-pad right (`fly_pace`), named on the same
## note as the weight.
var pace := FlightPace.flag(FlightPace.DEFAULT)
## Selling the speed: the view widens WIDE_FOV degrees more from WIDE_SPEED.x
## to WIDE_SPEED.y m/s, and LOW_WIDE more low and fast over the land, eased
## over WIDE_EASE s; the eye comes in CLOSE_IN and down CLOSE_DOWN at speed
## (GlideCamera `close_in`, `close_down`); the streaks (scripts/endless/
## speed_streaks.gd) come in from STREAK_SPEED.x to .y m/s (to STREAK_TOP of
## full), low and fast over the land (within LOW_SPANS wingspans, from
## LOW_SPEED.x to .y m/s) by LOW_STREAK, with Boost by BOOST_STREAK and the
## surge by SURGE_STREAK; their dashes run at the speed over STREAK_FLOW.
## `--streaks=<x>` times them (0 off).
const WIDE_FOV := 3.0
const WIDE_SPEED := Vector2(46.0,92.0)
const LOW_WIDE := 1.5
const WIDE_EASE := 0.5
const CLOSE_IN := 0.12
const CLOSE_DOWN := 0.18
const STREAK_SPEED := Vector2(40.0,95.0)
const STREAK_TOP := 0.75
const LOW_SPANS := Vector2(1.0,4.0)
const LOW_SPEED := Vector2(25.0,45.0)
const LOW_STREAK := 0.55
const BOOST_STREAK := 0.25
const SURGE_STREAK := 0.45
const STREAK_FLOW := 30.0
var _streaks: ColorRect
var _streak_scale := 1.0
var _wide := 0.0
var _low_k := 0.0
## Sinking through a pull-out, for the rumble's thrum: the nose this far
## over the path (radians) while it sinks faster than SINK_DOWN m/s knocks
## once, and it is felt again once the nose is back within SINK_REARM.
const SINK_AOA := 0.14
const SINK_DOWN := 3.0
const SINK_REARM := 0.05
var _sink_felt := false
const REGION_FADE := 1500
## A region takes the caption once its weight under the eye passes this
## (so weaving along a border does not flicker it).
const REGION_TAKE := 0.7
## The buffet's strength (--rush=X; off by default, it read as jitter)
## and its clock.
var _rush := 0.0
var _rush_t := 0.0
var rumble := FlightRumble.new()
var sound := FlightSound.new()
## The near misses (scored, chained, the meter), the land's contact, their
## HUD and debris; the FOV punch (degrees), the shake (radians) and its
## clock, the crash's dark fade (s left), and crashes so far.
var near := NearMiss.new()
var contact := FlightContact.new()
## How far the stone is grown round the plane's middle this frame
## (`plane_ground`).
var solid_pad := WorldScale.span*0.5
## Where the padded middle is moved off the plane's own (level, m): only in a
## forgiving knife slot, toward its keel (KnifeGlance; WorldScale
## `reach_fitted`).
var solid_shift := Vector3.ZERO
## The forgiving knife slots' glances (scripts/endless/knife_glance.gd), and
## this frame's glance (a scrape) for the contact's events.
var glance := KnifeGlance.new()
var _glanced := {}
var debris: Node3D
var water: Node3D
## The trees knocked down and falling (scripts/endless/tree_knock.gd).
var knock: Node3D
var _near_hud: Control
var _fade: ColorRect
var _fade_left := 0.0
var _punch := 0.0
var _punch_want := 0.0
var _shake := 0.0
var _shake_scale := SHAKE
var _shake_t := 0.0
var crashes := 0
## The pilot's book (scripts/endless/pilot_book.gd): money, tallies, records,
## what was bought, kept between runs; its `flight` is this flight's own.
var book: PilotBook
## The overlay that holds the keys while it is up (the shop, the logbook,
## photo mode; null: none). One at a time: open one only when this is null.
var overlay: Object = null
## Photo mode (scripts/endless/photo_mode.gd): O; the flight held while up.
var photo: PhotoMode
## The book's counting hooks (scripts/endless/pilot_tallies.gd), stepped in
## `tick`; the landing summary and the logbook (J) over the HUD.
var tallies := PilotTallies.new()
var summary: Control
var logbook: Control
## This frame's events (the landing's and the near misses'), for the HUD.
var _events := {}
## The flight path's way last frame, for the vapour's pull, and the pull.
var _last_way := Vector3.ZERO
var _pull := 0.0
## The main menu's stage (scripts/endless/menu_stage.gd) until the takeoff
## is the player's, else null (`--no-title`); its overlay.
var stage: RefCounted
## The doors between the regions (--world=doors; scripts/endless/region_doors.gd).
var doors: Node3D
var finds: Node
var menu: Control

## The 3D at a Native draw (the player's render resolution, and the default
## on a discrete GPU): 75%, upscaled by FSR (scripts/render_resolution.gd
## native_scale). About 2.5 ms back at 1440p on an RTX 4070 SUPER, a little
## softer (docs/design/endless-flight/cloud-weather-slices-handoff.md).
## --render-scale=1 draws at the window's own; F2 still cycles SCALES.
const NATIVE_3D := 0.75

func _ready() -> void:
	# Which hands are on it, the pad's or the keyboard's (Pad `note`): the
	# rumble and the prompts follow it.
	get_tree().root.window_input.connect(Pad.note)
	book = PilotBook.open()
	photo = PhotoMode.new(self)
	add_child(sound)
	# The graphics preset first: its flags lie under the command line's for
	# everything below, its height under the render resolution.
	GraphicsPreset.begin()
	Engine.max_fps = GraphicsPreset.fps()
	var rr := preload("res://scripts/render_resolution.gd")
	rr.native_scale = NATIVE_3D
	rr.apply(get_tree().root,rr.load_cap())
	EndlessLook.reset_season_globals()
	# The world: its shader globals over the reset, its start under the flags.
	world = WorldProfile.current()
	world.apply_globals()
	_start = world.spawn.get("at",_start)
	_alt = float(world.spawn.get("alt",_alt))
	var spawn_heading := float(world.spawn.get("heading",0.0))
	if spawn_heading != 0.0:
		_heading = -deg_to_rad(spawn_heading)
		_heading_given = true
	Pad.ensure()
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--seed="): seed = int(arg.get_slice("=",1))
		elif arg.begins_with("--at="):
			var p := arg.get_slice("=",1).split(",")
			if p.size() >= 2: _start = Vector2(float(p[0]),float(p[1]))
		elif arg == "--heading=sun": _face_sun = true
		elif arg.begins_with("--heading="):
			_heading = -deg_to_rad(float(arg.get_slice("=",1)))
			_heading_given = true
		elif arg.begins_with("--alt="):
			_alt = float(arg.get_slice("=",1))
			_alt_given = true
		elif arg == "--numbers": _numbers = true
		elif arg.begins_with("--rush="): _rush = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--shake="): _shake_scale = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--streaks="): _streak_scale = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--ceiling="): _ceiling_over = float(arg.get_slice("=",1))
		elif arg == "--old-land": _ceiling_over = SkyPlane.CEILING-Field.SEA_Y
		elif arg == "--climb=old": _climb_old = true
		elif arg == "--no-title": _no_title = true
		elif arg == "--uncapped":
			# No vsync and no cap, so the numbers' fps is the frame's cost.
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
		elif arg.begins_with("--max-fps="):
			# A cap the machine holds every frame, under the screen's rate:
			# vsync stays on, so a frame waits for the screen's next refresh.
			Engine.max_fps = maxi(0,int(arg.get_slice("=",1)))
	FrameLog.begin(preload("res://scripts/launch_args.gd").user_args())
	# The layout file first: the slot halls' sites read its moves when
	# the land is first looked at (scripts/endless/hall_sites.gd).
	LayoutOverrides.begin("endless_flight")
	field = Field.new(seed,world)
	# --split-near-start: the start moved out of the nearest split
	# mountain's lower mouth, heading in (scripts/endless/split_sites.gd).
	if SplitSites.near_start_wanted():
		var s: PackedFloat32Array = field.split_near(_start)
		if s.is_empty(): push_warning("--split-near-start: no split mountain near the start")
		else:
			var pose: Dictionary = SplitSites.approach(s,field)
			_start = pose.at
			_heading = -deg_to_rad(float(pose.heading))
			if not _alt_given: _alt = float(pose.alt)
			print("split mountain (%s): %.0f m long, floor %.0f m at its narrowest, mouth at %s, exit at %s; start %s heading %.0f" % [SplitSites.kind_name(s),s[4]*2.0,s[5]*2.0,str(pose.mouth),str(pose.exit),str(_start),float(pose.heading)])
	# --ship-start: in the air off the pirate ship's beam, flying her way.
	if "--ship-start" in preload("res://scripts/launch_args.gd").user_args():
		var ship_pose: Dictionary = preload("res://scripts/endless/pirate_ship.gd").start_pose()
		_start = ship_pose.at
		_heading = float(ship_pose.heading)
		_heading_given = true
		if not _alt_given:
			_alt = float(ship_pose.alt)
			_alt_given = true
	if WaterContact.near_start_wanted():
		var w: Dictionary = WaterContact.near_start(field,_start)
		if w.is_empty(): push_warning("--water-near-start: no river mouth near the start")
		else:
			_start = w.at
			_heading = float(w.heading)
			if not _alt_given: _alt = float(w.alt)
			print("water near start: river mouth at %s; start %s heading %.0f" % [str(w.mouth),str(_start),-rad_to_deg(_heading)])
	# The main menu parks the plane on a meadow near the start; a split
	# mountain start goes straight into the air, as --no-title does.
	# --rock-start=K: the start moved back from the nearest group of rock
	# kind K, flying in (scripts/endless/land_rocks.gd).
	var rock_pose: Dictionary = LandRocks.start_pose(field,_start)
	rock_start = rock_pose
	if not rock_pose.is_empty():
		_start = rock_pose.at
		_heading = -deg_to_rad(float(rock_pose.heading))
		if not _alt_given: _alt = float(rock_pose.alt)
		var rs: Dictionary = rock_pose.spec
		print("rock start: %s (%s, %d pillars) at %s; start %s heading %.0f" % [rs.name,str(rs.get("form","")),(rs.pillars as Array).size(),str((rs.pos as Vector3).round()),str(_start.round()),float(rock_pose.heading)])
	# The Peak (scripts/endless/peak_massif.gd): the start faces its summit,
	# unless a heading was named or a start flag set its own; the menu's
	# meadow takes the clear heading nearest that.
	var own_start := SplitSites.near_start_wanted() or RivalRace.near_start_wanted() or WaterContact.near_start_wanted() or not rock_pose.is_empty()
	var peak: RefCounted = field.peak()
	var face_peak := peak != null and not _heading_given and not own_start
	if face_peak:
		var to: Vector3 = peak.summit()
		_heading = atan2(-(to.x-_start.x),-(to.z-_start.y))
	var spots: Array = [] if _no_title or own_start else _menu_spots(face_peak)
	if not spots.is_empty():
		_start = spots[0].at
		_heading = float(spots[0].heading)
	if EndlessLook.wanted():
		look = EndlessLook.new()
		add_child(look)
		look.setup(seed)
		sea = look.sea
		# The start meadow clear of valley fog (EndlessClouds FOG_CLEAR).
		if look.clouds != null: look.clouds.clear_fog_at(_start)
		var collar_at := Vector3.ZERO
		if peak != null:
			var cw: Vector2 = peak.world(COLLAR_AT,0.0)
			collar_at = Vector3(cw.x,0.0,cw.y)
		if peak != null and look.clouds != null and "--collar=1" in preload("res://scripts/launch_args.gd").user_args(): look.clouds.set_collar(collar_at,COLLAR_R,COLLAR_BAND.x,COLLAR_BAND.y,0.0)
		# The sky over it keeps its own hour (EndlessLook.set_collar_sky).
		if peak != null: look.set_collar_sky(collar_at,COLLAR_R,COLLAR_BAND.x,COLLAR_BAND.y)
		# The day's ring stands so the sun rakes the way in (EndlessLook.turn_ring_to).
		if peak != null: look.turn_ring_to((peak.world(0.0,0.0)-peak.world(1000.0,0.0)).normalized())
		# Its paint in the ground shader (snow line, granite, ice), set before
		# the rocks take their bare copy of the ground; --peak-paint=0 leaves
		# the land's own paint on it.
		if peak != null and look.ground != null and not ("--peak-paint=0" in preload("res://scripts/launch_args.gd").user_args()):
			var paint: Dictionary = peak.paint()
			for k: String in paint: look.ground.set_shader_parameter(k,paint[k])
			if PeakSnow.wanted(): PeakSnow.paint(look.ground,peak)
		# The tarn's look (shaders/peak_tarn.gdshaderinc; --peak-tarn=0 off).
		if peak != null and look.ground != null: PeakTarn.apply(peak,look.ground)
		_build_camera()
		if _face_sun:
			var s: Vector3 = look.celestial.state.zs_sun_direction
			_heading = atan2(-s.x,-s.z)
	else:
		_build_light()
		_build_sea()
	land = LandStream.new()
	land.name = "Land"
	add_child(land)
	land.setup(seed,look.ground if look != null else null)
	arches = LandArches.new()
	arches.name = "Arches"
	add_child(arches)
	arches.setup(seed,look.ground if look != null else null)
	rocks = LandRocks.new()
	rocks.name = "Rocks"
	add_child(rocks)
	rocks.setup(seed,look.ground if look != null else null,field.peak())
	arches.carve_rock = rocks.bare
	# The rocks' bare copy of the ground takes the haze each frame as it does.
	if look != null and rocks.bare is ShaderMaterial and rocks.bare != look.ground: look.ground_copies.append(rocks.bare)
	if peak != null and PeakTowers.wanted():
		towers = PeakTowers.new()
		towers.name = "Towers"
		add_child(towers)
		towers.setup(peak.crown(Callable(field,"height"),PeakTowers.entry),seed,rocks.bare,Field.new(seed,world),peak.centre)
		rocks.extra = towers
		if look != null: look.ground_copies.append(towers.far_material)
		if look != null and towers.rock_material is ShaderMaterial: look.ground_copies.append(towers.rock_material)
	halls = LandHalls.new()
	halls.name = "Halls"
	add_child(halls)
	halls.setup(seed)
	tunnels = LandTunnels.new()
	tunnels.name = "Tunnels"
	add_child(tunnels)
	tunnels.setup(field)
	if look != null: tunnels.clouds = look.clouds
	trees = LandTrees.new()
	trees.name = "Trees"
	add_child(trees)
	trees.setup(seed)
	if EndlessFish.wanted() and field.ponds > 0.0:
		fish = EndlessFish.new()
		fish.name = "Fish"
		add_child(fish)
		fish.setup(seed,field)
	birds = EndlessBirds.new()
	birds.name = "Birds"
	add_child(birds)
	birds.setup(seed,field,trees)
	if EndlessTraffic.wanted() > 0:
		traffic = EndlessTraffic.new()
		add_child(traffic)
		traffic.setup(seed,field,look,EndlessTraffic.wanted())
		race = RivalRace.new()
		add_child(race)
		race.setup(seed)
	if look != null:
		grass = EndlessGrass.new()
		grass.setup(seed,look.ground)
		add_child(grass)
		grass.set_enabled(EndlessGrass.wanted())
		if GrassReact.wanted():
			react = GrassReact.new()
			add_child(react)
			react.setup(seed)
			var gust_mode := EndlessEddies.mode()
			react.rings_on = gust_mode != "eddies"
			if gust_mode != "rings":
				eddies = EndlessEddies.new()
				add_child(eddies)
				eddies.setup(seed,Callable(field,"height"),react)
			if EndlessMotes.wanted():
				motes = EndlessMotes.new()
				add_child(motes)
				motes.setup(seed,Callable(field,"height"))
			if peak != null and PeakSnow.wanted() and not ("--peak-paint=0" in preload("res://scripts/launch_args.gd").user_args()):
				snow = PeakSnow.new()
				add_child(snow)
				snow.setup(seed,look.ground,peak,field)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	_build_ui()
	_hud.visible = _numbers
	# The land round the start first, so it starts over ground that stands.
	var eye := Vector3(_start.x,_start_height(),_start.y)
	camera.global_position = eye
	var took: float = land.prime(eye)
	arches.prime(eye)
	rocks.prime(eye)
	if towers != null: towers.prime(eye)
	halls.prime(eye)
	tunnels.prime(eye)
	trees.prime(eye)
	debris = FlightDebris.new()
	debris.name = "Debris"
	add_child(debris)
	if WaterContact.wanted():
		water = WaterContact.new()
		water.name = "Water"
		add_child(water)
		water.setup(self)
	if BeatRoutes.wanted():
		beats = BeatRoutes.new()
		add_child(beats)
		beats.setup(seed,self)
	if PlaceLines.wanted():
		lines = PlaceLines.new()
		add_child(lines)
		lines.setup(seed,self)
	# The Peak's lift up the rock gorge (scripts/endless/peak_routes.gd).
	if peak != null and air_lift != null:
		var lift := PeakRoutes.lift(peak,Callable(field,"height"))
		air_lift.add(str(lift.name),lift.points,float(lift.radius),float(lift.strength),bool(lift.one_way))
		var wisps: MultiMeshInstance3D = preload("res://scripts/endless/peak_lift_wisps.gd").new()
		add_child(wisps)
		wisps.setup(lift.points,float(lift.radius),seed,Callable(field,"height"))
	# Its ruined stair (scripts/endless/peak_stair.gd), the rock gorge's tell.
	if peak != null and not ("--stair=0" in preload("res://scripts/launch_args.gd").user_args()):
		stair = PeakStair.new()
		add_child(stair)
		stair.setup(peak,Callable(field,"height"),seed)
	# The climbers' flags (scripts/endless/peak_flags.gd).
	if peak != null and not ("--peak-flags=0" in preload("res://scripts/launch_args.gd").user_args()):
		var flags: Node3D = preload("res://scripts/endless/peak_flags.gd").new()
		add_child(flags)
		flags.setup(peak,Callable(field,"height"),seed,stair,towers)
	if BurrowerFlight.wanted():
		burrower = BurrowerFlight.new()
		add_child(burrower)
		burrower.setup(self)
	if Stomper.wanted(world):
		stomper = Stomper.new()
		add_child(stomper)
		stomper.setup(self)
	knock = TreeKnock.new()
	knock.name = "TreeKnock"
	add_child(knock)
	smash = SurgeSmash.new()
	add_child(smash)
	smash.setup(self)
	if spots.is_empty(): _launch(Vector3(_start.x,_start_height(),_start.y),_heading)
	else: _park_for_menu(spots)
	if race != null and RivalRace.near_start_wanted(): race.place_near_start(self)
	shops = ShopSites.new()
	shops.name = "Shops"
	add_child(shops)
	shops.setup(self)
	coast = preload("res://scripts/endless/coast_sites.gd").new()
	coast.name = "Coast"
	add_child(coast)
	coast.setup(self)
	if GiantRuins.wanted(world):
		giants = GiantRuins.new()
		giants.name = "GiantRuins"
		add_child(giants)
		giants.setup(self)
	# --full-meter: a surge roll ready at once; again whenever the ship's plates
	# come back (pirate_ship.gd `refill`).
	if "--full-meter" in preload("res://scripts/launch_args.gd").user_args(): near.meter = 1.0
	if RegionDoors.wanted(world):
		doors = HallDoors.new() if HallDoors.wanted_hall() else RegionDoors.new()
		add_child(doors)
		doors.setup(self,_start,_heading,seed)
	if Finds.wanted(seed):
		way = preload("res://scripts/endless/way_towers.gd").new()
		way.name = "WayTowers"
		add_child(way)
		way.setup(self)
		finds = Finds.new()
		add_child(finds)
		finds.setup(self)
		if smash != null: finds.listen(smash.walls.broken,"broken")
		if burrower != null: finds.listen(burrower.caught,"caught")
	if peak != null and PeakSpirals.wanted():
		spirals = PeakSpirals.new()
		spirals.name = "PeakSpirals"
		add_child(spirals)
		spirals.setup(self)
		spirals.set_axes(PeakSpirals.on_towers(towers.axes() if towers != null else [],peak.PLATEAU_Y+Field.SEA_Y+60.0))
	# Snow blowing off the crown's tips and high ridges (scripts/endless/peak_spindrift.gd).
	if peak != null and PeakSpindrift.wanted():
		spindrift = PeakSpindrift.new()
		add_child(spindrift)
		spindrift.setup(self,peak,Callable(field,"height"),towers,seed,Field.SEA_Y)
	if grass != null and grass.enabled: grass.prime(camera.global_position,-camera.global_basis.z)
	walk_ready = true
	print("endless flight: seed %d, the land stood in %.2f s (%d chunks)%s" % [seed,took,int(land.counts().standing),"" if world.id == WorldProfile.PLAYS else ", world "+str(world.id)])
	if stage == null and get_tree().current_scene == self and DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## The grass parted round the parked plane in the menu: out to PART_SPANS
## wingspans (round the eye EYE_PART_SPANS), PART_PUSH times a standing walker's push (GrassReact `part`).
const PART_SPANS := 0.8
const PART_PUSH := 1.6
const EYE_PART_SPANS := 1.3

## The main menu's meadows (MenuSpot `find`) round the start; facing the
## Peak (`peaked`), the nearest whose run heads within PEAK_SPREADS of
## MenuSpot's HEADINGS (tried in turn) of its summit, else the nearest at all.
const PEAK_SPREADS := [3,5]
func _menu_spots(peaked: bool) -> Array:
	if peaked:
		for n: int in PEAK_SPREADS:
			var got: Array = MenuSpot.find(field,_start,_heading,8,n)
			if not got.is_empty(): return got
	return MenuSpot.find(field,_start,_heading)

## The main menu: parked on the first of `spots` (MenuSpot `find`) that
## nothing standing on the land is in the way of (trees, arches, halls,
## tunnels primed there first), the stage and the overlay up.
func _park_for_menu(spots: Array) -> void:
	var spot: Dictionary = spots[0]
	for s: Dictionary in spots:
		var at: Vector2 = s.at
		var here := Vector3(at.x,field.height(at.x,at.y)+2.0,at.y)
		for part: Node3D in [arches,rocks,halls,tunnels,trees]: part.prime(here)
		if MenuSpot.clear(field,s,WorldScale.TOY_SPAN*ground_scale.ground_size()*MenuStage.ORBIT_R+2.0,Callable(self,"_blocked")):
			spot = s
			break
	_start = spot.at
	_heading = float(spot.heading)
	if look != null and look.clouds != null and spot != spots[0]: look.clouds.clear_fog_at(_start)
	_launch(Vector3(_start.x,field.height(_start.x,_start.y),_start.y),_heading,true)
	menu = MainMenu.new()
	menu.name = "MainMenu"
	_hint.get_parent().add_child(menu)
	menu.picked.connect(_menu_picked)
	stage = MenuStage.new()
	stage.begin(_heading,menu)
	_hint.visible = false

## The menu's pick: Start hands off into the takeoff, Quit quits.
func _menu_picked(what: String) -> void:
	if what == "quit":
		get_tree().quit()
		return
	if stage != null: stage.start()

func _start_height() -> float:
	# --tunnel-test: level with mouth A, to fly straight in.
	if not _alt_given and tunnels != null and not is_nan(tunnels.start_y()): return tunnels.start_y()
	return maxf(field.height(_start.x,_start.y),Field.SEA_Y)+_alt

# --- The world ------------------------------------------------------------------------

func _build_light() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("5d8fc4")
	sky.sky_horizon_color = HORIZON
	sky.ground_bottom_color = Color("6f8a99")
	sky.ground_horizon_color = HORIZON
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = HORIZON
	environment.fog_depth_begin = FOG_BEGIN
	environment.fog_depth_end = FOG_END
	environment.fog_depth_curve = 1.6
	# The Compatibility renderer has no depth fog: its exponential fog's
	# density, thin enough to read the far land.
	environment.fog_density = FOG_DENSITY
	environment.fog_aerial_perspective = 0.5
	environment.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0,-35.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)
	_build_camera()

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = GlideCamera.FOV
	camera.near = 0.1
	# With the look, the haze is all sky by its end: nothing past it shows,
	# and the aerial perspective reads the sharp sky there (Godot picks the
	# radiance's blur by depth over the far plane).
	camera.far = EndlessLook.FOG_END*LandStream.view()*1.04 if look != null else FOG_END*2.2
	add_child(camera)
	camera.current = true

## The sea: one wide sheet at sea level that follows the eye.
func _build_sea() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(SEA_SIZE,SEA_SIZE)
	var m := StandardMaterial3D.new()
	m.albedo_color = SEA_COLOUR
	m.roughness = 0.12
	m.metallic_specular = 0.7
	mesh.material = m
	sea = MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = mesh
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position.y = Field.SEA_Y
	add_child(sea)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16,12)
	_hud.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	_hud.add_theme_constant_override("outline_size",4)
	_hud.visible = false
	layer.add_child(_hud)
	_hint = Label.new()
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -40.0
	_hint.offset_left = 16.0
	_hint.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	_hint.add_theme_constant_override("outline_size",4)
	_hint.text = "A D bank  ·  W S pitch  ·  mouse steers  ·  Space boost  ·  Shift brake  ·  Z roll (full meter: surge roll)  ·  Q E knife edge  ·  F flaps  ·  J logbook  ·  O photo  ·  R up again  ·  B surge  ·  Tab (hold) race a plane  ·  V weight  ·  P pace  ·  C clouds  ·  G grass  ·  H score  ·  F1 numbers  ·  F2 3D scale  ·  F3 graphics"
	layer.add_child(_hint)
	_stop_cue = Label.new()
	_stop_cue.anchor_top = 1.0
	_stop_cue.anchor_bottom = 1.0
	_stop_cue.offset_top = -68.0
	_stop_cue.offset_left = 16.0
	_stop_cue.add_theme_color_override("font_color",Color(1.0,0.93,0.72))
	_stop_cue.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	_stop_cue.add_theme_constant_override("outline_size",4)
	_stop_cue.visible = false
	layer.add_child(_stop_cue)
	# The near misses' HUD: the ring by the plane (scripts/endless/near_miss_hud_ring.gd,
	# the Line HUD canvas's C2). --near-hud=tag (or handoff, handoff-tag) the design
	# handoff's tag before it (scripts/endless/near_miss_hud_handoff.gd, in the tag
	# or at the top as the player keeps it, H switches); --near-hud=glyph the earlier
	# trial (gilt numbers in a tag), --near-hud=classic the first plain text.
	var hud_args := preload("res://scripts/launch_args.gd").user_args()
	if "--near-hud=glyph" in hud_args: _near_hud = NearMissHudGlyph.new()
	elif "--near-hud=classic" in hud_args: _near_hud = NearMissHud.new()
	elif "--near-hud=tag" in hud_args or "--near-hud=handoff" in hud_args or "--near-hud=handoff-tag" in hud_args: _near_hud = NearMissHudHandoff.new()
	else: _near_hud = NearMissHudRing.new()
	_near_hud.visible = false
	layer.add_child(_near_hud)
	# The landing summary and the logbook (lane logbook, spec-wild-loop.md).
	summary = preload("res://scripts/endless/landing_summary.gd").new(self)
	layer.add_child(summary)
	logbook = preload("res://scripts/endless/logbook_view.gd").new(self)
	layer.add_child(logbook)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.03,0.03,0.04,0.0)
	layer.add_child(_fade)
	_streaks = SpeedStreaks.new()
	layer.add_child(_streaks)
	_weight_note = Label.new()
	_weight_note.anchor_left = 0.0
	_weight_note.anchor_right = 1.0
	_weight_note.offset_top = 124.0
	_weight_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weight_note.add_theme_font_size_override("font_size",24)
	_weight_note.add_theme_color_override("font_outline_color",Color(0,0,0,0.7))
	_weight_note.add_theme_constant_override("outline_size",5)
	_weight_note.modulate.a = 0.0
	layer.add_child(_weight_note)
	if not world.uniform:
		_region_caption = Label.new()
		_region_caption.anchor_left = 0.0
		_region_caption.anchor_right = 1.0
		_region_caption.offset_top = 72.0
		_region_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_region_caption.add_theme_font_size_override("font_size",30)
		_region_caption.add_theme_color_override("font_outline_color",Color(0,0,0,0.6))
		_region_caption.add_theme_constant_override("outline_size",6)
		_region_caption.modulate.a = 0.0
		layer.add_child(_region_caption)
		if "--region-debug" in preload("res://scripts/launch_args.gd").user_args():
			_region_debug = Label.new()
			_region_debug.anchor_top = 1.0
			_region_debug.anchor_bottom = 1.0
			_region_debug.offset_top = -70.0
			_region_debug.offset_left = 16.0
			_region_debug.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
			_region_debug.add_theme_constant_override("outline_size",4)
			layer.add_child(_region_debug)

# --- The plane ------------------------------------------------------------------------

## Flying from `at` on `heading`, at cruise, the chase camera behind it;
## or, `parked`, stood still on its wheels on the land at `at` (the main
## menu's), the engine off.
func _launch(at: Vector3, heading: float, parked := false) -> void:
	plane = SkyPlane.new()
	plane.use_flight_speed()
	plane.use_pace(FlightPace.speed(pace))
	plane.use_weight(weight)
	_sink_felt = false
	plane.floor_y = Field.SEA_Y-15.0
	plane.water = Field.SEA_Y
	# The air thins over the mountain (Field THIN_OVER) and the climb fades
	# out at the top (Field CEILING_OVER, --ceiling=m over the sea).
	# --climb=old: from 215 m, slow work all the way up.
	var ceiling_over := _ceiling_over
	if _climb_old and is_equal_approx(ceiling_over,Field.CEILING_OVER): ceiling_over = Field.CEILING_OVER_OLD
	var thin_over := Field.THIN_OVER_OLD if _climb_old or ceiling_over <= Field.THIN_OVER else Field.THIN_OVER
	plane.ceiling_y = Field.SEA_Y+ceiling_over
	if ceiling_over > thin_over: plane.use_thin(Field.SEA_Y+thin_over,plane.ceiling_y,thin_over >= Field.THIN_OVER)
	# The land is a heightfield: it rides up what is no cliff, and a
	# cliff's face turns it aside (SkyGlide `stone`).
	plane.stone = func(_p: Vector3) -> bool: return true
	# In a tunnel's bore a soft guard eases it off the walls, roof and floor
	# before the rock stops it, and its walls are slippery (LandTunnels
	# `guide`, `keep`).
	if tunnels != null:
		plane.guide = Callable(tunnels,"guide")
		plane.keep = Callable(tunnels,"keep")
	# Past the sea round the land, the plane is eased home (`field` as it stands:
	# a door changes it).
	plane.fence = func(p: Vector3, h: float) -> Vector2: return field.fence(p,h)
	if parked:
		var rest := PlaneStrip.rest(func(p: Vector2) -> float: return field.height(p.x,p.y),Vector2(at.x,at.z),heading)
		plane.park(Vector3(at.x,rest.x,at.z),heading,rest.y,rest.z)
	else:
		plane.launch(at,heading,plane.cruise(),false)
		if stage != null: _menu_done()
	hand_landing.begin(plane,parked)
	hand_landing.land_most = FlightContact.LAND_MOST if plane.weighted else INF
	near.reset()
	contact.reset()
	if plane_figure == null:
		plane_figure = PlaneFigure.new()
		plane_figure.name = "Plane"
		add_child(plane_figure)
	plane_figure.reset(plane)
	_last_way = Vector3.ZERO
	ground_scale.reset(parked)
	ground_scale.apply(plane_figure)
	plane_figure._mark.visible = false
	flaps = false
	chase = GlideCamera.new()
	chase.framed = true
	chase.sight = _sight
	chase.floor_at = eye_floor
	chase.reset(plane,at+(-plane.forward()*GlideCamera.BACK.x+Vector3.UP*GlideCamera.UP.x)*ground_scale.size(),camera.fov)
	chase.linger = LOOK_LINGER
	chase.use_weight(FlightWeight.knobs(weight))
	chase.close_in = CLOSE_IN
	chase.close_down = CLOSE_DOWN
	if not _has_arg("--cam-speed-fov="): chase.speed_fov = RUSH_FOV
	_size_chase()
	_frame(0.0)

func _size_chase() -> void:
	chase.size = ground_scale.size()
	chase.lift = ground_scale.lift()
	var span := WorldScale.TOY_SPAN*ground_scale.size()
	chase.near = span*GlideCamera.NEAR_SPANS
	chase.extent = span*0.5
	# Today's cruise, so the view widens with the speed itself at any pace.
	chase.cruise = plane.cruise()/float(plane.pace_scale)
	var view := get_viewport().get_visible_rect().size
	if view.y > 0.0: chase.aspect = view.x/view.y

## The land's height under a point, for the flight (SkyGlide `step`).
## The arches stand on it (LandArches `ground`): a leg raises it, a span
## over it is a solid the plane slides under. So do the rock shapes, every
## kind (LandRocks `ground`): a pillar raises it, a cap's overhang is an
## underside.
##
## The stone (arches, rocks, halls, bores) is grown by `pad` m round `p`:
## by default `solid_pad`, the plane's reach off its middle as it is rolled
## now (WorldScale `reach_rolled`); 0 for a point on the plane's own edge
## (NearMiss's body points), which is in the stone only where it truly is.
func plane_ground(p: Vector3, pad := -1.0) -> Variant:
	if pad < 0.0:
		pad = solid_pad
		p += solid_shift
	var g: Variant = tunnels.ground(p,halls.ground(p,trees.ground(p,rocks.ground(p,arches.ground(p,field.height(p.x,p.z),pad),pad)),pad),pad)
	if coast != null: g = coast.ground(p,g,pad)
	if giants != null: g = giants.ground(p,g,pad)
	# The Peak's stair raises it over its flights (PeakStair `ground`).
	if stair != null: g = stair.ground(p,g,pad)
	if stomper != null: g = stomper.solid.ground(p,g,pad)
	return g if doors == null else doors.ground(p,g,pad)

## In the way of the rolling plane: an arch's leg or pier, a rock, a tree.
func _blocked(p: Vector3) -> bool:
	if doors != null and doors.holds(p): return false
	return arches.inside(p) or rocks.inside(p) or trees.inside(p) or halls.inside(p) or tunnels.inside(p) or (coast != null and coast.inside(p)) or (giants != null and giants.inside(p)) or (stomper != null and stomper.solid.wheels(p))

## The turf under the wheels at a world XZ point; NAN over the sea and a
## river's water (the land field's `last_river`, from the same sample).
func floor_at(p: Vector2) -> float:
	if doors != null and plane != null and doors.holds(Vector3(p.x,plane.position.y,p.y)): return doors.hall_floor()
	var h: float = field.height(p.x,p.y)
	if h < Field.SEA_Y+0.2 or _on_river(): return NAN
	# In a tunnel's bore, its floor (read at the plane's height).
	return tunnels.land_y(Vector3(p.x,plane.position.y if plane != null else h,p.y),h)

## Whether the field's last sample was on a river's water (not the sea's
## mouth, which the sea takes).
func _on_river() -> bool:
	return field.last_river < 0.0 and field.river_drawn() > Field.SEA_Y+0.05

## The water under a point: the sea's swell, or a river's level over it.
func water_at(p: Vector3) -> float:
	var level := Field.SEA_Y+sea_height(p)
	var river: float = field.river_y(p.x,p.z)
	return level if is_nan(river) else maxf(level,river)

## The top of the land, a river's water or the sea's swell under `p` (a
## bore's floor in its tube), for the camera to keep over (GlideCamera
## `floor_at`).
func eye_floor(p: Vector3) -> float:
	if doors != null and doors.holds(p): return doors.hall_floor()
	var h: float = field.height(p.x,p.z)
	if _on_river(): h = maxf(h,field.river_drawn())
	h = tunnels.land_y(p,h)
	return maxf(h,Field.SEA_Y+sea_height(p))

## Inside the land or the sea, for the camera to keep out of.
func _solid(p: Vector3) -> bool:
	if doors != null and doors.holds(p): return p.y < doors.hall_floor()+EYE_CLEAR*0.5
	return p.y < eye_floor(p)+EYE_CLEAR*0.5 or arches.inside(p) or rocks.inside(p) or halls.inside(p) or tunnels.inside(p) or (coast != null and coast.in_wreck(p,0.4)) or (stomper != null and stomper.solid.inside(p))

## The sea's swell over its rest level at `p` (EndlessSea `height_at`; 0 on
## the flat sea), looked up only near the water.
func sea_height(p: Vector3) -> float:
	if look == null or look.water == null or p.y > Field.SEA_Y+12.0: return 0.0
	# Land well over the sea has none, and low land sits inside the 12 m: every
	# probe of a low flight would march the waves.
	if field.height(p.x,p.z) > Field.SEA_Y+preload("res://scripts/burrower/game_land.gd").SWELL_ROOM: return 0.0
	# Up a river's mouth the sea lies still, as the sea shader draws it.
	return look.water.height_at(p.x,p.z)*(1.0-field.sea_calm(p.x,p.z))

## The share of the way from `from` to `to` clear of the land and the water
## by EYE_CLEAR's half, as `_solid` (GlideCamera `sight`), marched over the
## field; in a bore, finer (LandTunnels `sight`).
func _sight(from: Vector3, to: Vector3) -> float:
	const STEPS := 10
	if doors != null and doors.holds(from): return 1.0
	var bore: float = tunnels.sight(from,to)
	if tunnels.sight_whole: return bore
	for i in range(1,STEPS+1):
		var t := float(i)/STEPS
		if t > bore: break
		var p := from.lerp(to,t)
		# In a bore's tube the fine march has answered.
		if tunnels.tube(p) >= 0: continue
		if p.y < eye_floor(p)+EYE_CLEAR*0.5 or arches.inside(p) or rocks.inside(p) or halls.inside(p) or tunnels.inside(p): return float(i-1)/STEPS
	return bore

func _process(delta: float) -> void:
	if not walk_ready: return
	if photo.active:
		photo.step(minf(delta,1.0/20.0))
		return
	tick(minf(delta,1.0/20.0))

## One frame: the plane flown, drawn and followed, the land streamed round
## the eye, the sea under it.
func tick(delta: float) -> void:
	FrameLog.start()
	var tick_from := Time.get_ticks_usec()
	flown += delta
	var input := _fly_input(delta)
	if stage != null: input = stage.input(delta,input,hand_landing,plane_figure)
	if doors != null: input = doors.input(input)
	# The roll button on a full meter is the surge roll (scripts/endless/surge_smash.gd).
	if coast != null: coast.before(delta)
	if smash != null: smash.before(delta,input)
	# The plane skims the swell as drawn, not the sea's rest level, and a
	# river's water as it skims the sea.
	plane.water = water_at(plane.position)
	if doors != null and doors.holds(plane.position): plane.water = -INF
	FrameLog.mark(&"t_input")
	if water != null: water.feel(delta)
	FrameLog.mark(&"t_feel")
	input["flaps"] = 1.0 if flaps else 0.0
	# In a bore's tube the low zone lets be (SkyPlane `roofed`).
	plane.roofed = (tunnels != null and int(tunnels.tube(plane.position)) == 0) or (doors != null and doors.holds(plane.position))
	# Rolling, the arches' legs and piers stand in the way (LandArches `inside`).
	# The trees the coming move meets are knocked down first, so it flies on through.
	FrameLog.mark(&"t_roofed")
	var knocked: Dictionary = knock.before(delta,self)
	FrameLog.mark(&"knock_before")
	solid_pad = WorldScale.reach_rolled(float(plane.bank)+float(plane.spin))
	# In a forgiving knife slot: the reach fitted, a jamb glanced off.
	solid_shift = Vector3.ZERO
	_glanced = glance.before(delta,self)
	# A limb come over the plane (scripts/endless/stomper_solid.gd).
	if stomper != null and _glanced.is_empty(): _glanced = stomper.solid.before(delta,self)
	FrameLog.mark(&"glance")
	# A beat route's preview pan holds the flight (beat_routes.gd).
	var held: bool = beats != null and beats.holding()
	var events: Dictionary = {} if held else hand_landing.step(delta,input,Callable(self,"plane_ground"),Callable(self,"floor_at"),air,Callable(self,"_blocked"))
	FrameLog.mark(&"landing")
	if events.has("lifted"): book.new_flight()
	book.flight.t = float(book.flight.t)+delta
	book.step(delta)
	FrameLog.mark(&"book")
	if not knocked.is_empty(): _knocked(events,knocked)
	plane.engine = hand_landing.engine*float(plane.sputter)*(float(stage.engine) if stage != null else 1.0)
	if coast != null: coast.after(delta,events)
	_near_misses(delta,events)
	FrameLog.mark(&"near")
	if water != null: water.step(delta,events)
	FrameLog.mark(&"water")
	var ground := Callable(self,"plane_ground")
	_pull = _pull_of(delta)
	if smash != null: _pull = maxf(_pull,smash.vapour)
	plane_figure.update(delta,plane,0.0,ground,hand_landing.would_grease(Callable(self,"floor_at")),_pull,float(plane.bank))
	FrameLog.mark(&"figure")
	_events = events
	tallies.step(delta,self,events)
	FrameLog.mark(&"tallies")
	summary.step(delta)
	FrameLog.mark(&"summary")
	_feel_sink(events)
	_rumble(delta,events,float(input.get("boost",0.0)))
	FrameLog.mark(&"rumble")
	sound.step(delta,self,events,float(input.get("boost",0.0)))
	FrameLog.mark(&"sound")
	ground_scale.step(delta,hand_landing.on_ground(),hand_landing.dipping(),plane)
	ground_scale.apply(plane_figure)
	ground_scale.hold_spin(plane_figure,plane)
	if water != null: water.shake_figure(plane_figure)
	plane_figure._mark.visible = false
	_size_chase()
	# On the wheels the chase stands off to the side, but not on the menu's
	# takeoff: it comes round behind the plane and stays there.
	chase.cine = Vector3(-1.25,0.0,0.3) if hand_landing.on_ground() and stage == null else Vector3.ZERO
	chase.ground = hand_landing.on_ground()
	_stop_note()
	FrameLog.mark(&"ground_scale")
	# A door flown into carries the plane to the other side (region_doors.gd).
	if doors != null: doors.step(delta)
	FrameLog.mark(&"doors")
	_frame(delta)
	FrameLog.mark(&"camera")
	if stage != null:
		stage.frame(delta,camera,plane.position+ground_scale.lift(),ground_scale.size(),Callable(field,"height"))
		if not stage.running(): _menu_done()
	if beats != null: beats.step(delta,self)
	if lines != null: lines.step(delta,self)
	FrameLog.mark(&"lines")
	if burrower != null: burrower.step(delta,self)
	FrameLog.mark(&"burrower")
	if stomper != null: stomper.step(delta)
	FrameLog.mark(&"stomper")
	land.lead_with(plane.velocity)
	land.step(camera.global_position)
	FrameLog.mark(&"land")
	arches.step(camera.global_position)
	FrameLog.mark(&"arches")
	rocks.step(camera.global_position)
	FrameLog.mark(&"rocks")
	if towers != null: towers.step(camera.global_position)
	FrameLog.mark(&"towers")
	halls.step(camera.global_position)
	FrameLog.mark(&"halls")
	tunnels.step(camera.global_position)
	FrameLog.mark(&"tunnels")
	if doors != null: doors.late(camera.global_position)
	FrameLog.mark(&"doors_late")
	trees.step(camera.global_position,plane.position)
	FrameLog.mark(&"trees")
	knock.step(delta,self)
	FrameLog.mark(&"knock")
	birds.step(delta,camera.global_position,plane)
	FrameLog.mark(&"birds")
	if fish != null: fish.step(delta,camera.global_position,plane.position,plane.velocity,false)
	FrameLog.mark(&"fish")
	if traffic != null: traffic.step(delta,camera.global_position,-camera.global_basis.z,plane.position,Vector3(-sin(plane.heading),0.0,-cos(plane.heading)),float(plane.speed))
	FrameLog.mark(&"traffic")
	if race != null: race.step(delta,self)
	FrameLog.mark(&"race")
	if shops != null: shops.step(delta,self)
	FrameLog.mark(&"shops")
	if finds != null: finds.step(delta,self)
	FrameLog.mark(&"finds")
	if coast != null: coast.step(delta,self)
	FrameLog.mark(&"coast")
	if way != null: way.step(camera.global_position)
	FrameLog.mark(&"way")
	if grass != null:
		var view := get_viewport().get_camera_3d()
		var eye: Camera3D = view if view != null else camera
		grass.lead_with(plane.velocity)
		grass.step(eye.global_position,-eye.global_basis.z)
		FrameLog.mark(&"grass")
	if look != null: look.plane_at = plane.position
	# The day's clock waits while the menu holds the flight: a flight starts
	# at its opening hour.
	if look != null: look.cycle.held = stage != null and stage.holding()
	if look != null: look.step(delta,camera.global_position,-camera.global_basis.z,camera)
	FrameLog.mark(&"look")
	if react != null: _react(delta)
	else: sea.position = Vector3(snappedf(camera.global_position.x,64.0),Field.SEA_Y,snappedf(camera.global_position.z,64.0))
	FrameLog.mark(&"react")
	_show_hud()
	FrameLog.mark(&"hud")
	if FrameLog.on: FrameLog.end((Time.get_ticks_usec()-tick_from)/1000.0,plane.position,float(plane.speed))

## How hard the vapour pulls off the wingtips (0 to 1): the flight path's
## turn rate over VAPOUR_TURN, more past cruise.
func _pull_of(delta: float) -> float:
	var v: Vector3 = plane.velocity
	var way := v.normalized()
	var turn := 0.0
	if delta > 0.0 and _last_way != Vector3.ZERO and v.length() > 1.0: turn = _last_way.angle_to(way)/delta
	_last_way = way
	if hand_landing.on_ground(): return 0.0
	var fast := smoothstep(plane.cruise()*0.8,plane.boost_speed(),v.length())
	return smoothstep(VAPOUR_TURN.x,VAPOUR_TURN.y,turn)*lerpf(0.6,1.0,fast)

## The pad's rumble: the landing's `events` knock, the wheels, Boost
## (`boost` held, in the air), the pull and skimming low hum.
func _rumble(delta: float, events: Dictionary, boost: float) -> void:
	var rolling := hand_landing.on_ground()
	var skim := 0.0
	if not rolling:
		var p: Vector3 = plane.position
		var h: float = field.height(p.x,p.z)
		var low := SKIM_LOW*ground_scale.size()
		var fast := smoothstep(plane.cruise()*0.8,plane.cruise(),float(plane.speed))
		if h > Field.SEA_Y: skim = (1.0-smoothstep(low*0.4,low,p.y-h))*fast
	rumble.step(delta,events,{"roll":hand_landing.roll_speed() if rolling else 0.0,"grit":hand_landing.grit,
		"boost":0.0 if rolling else boost,"pull":_pull,"skim":skim,"spray":water.hum() if water != null and not rolling else 0.0,
		"strain":0.0 if rolling else smoothstep(1.3,6.5,float(plane.g_load)),
		"low":0.0 if rolling else float(plane.low)*clampf(float(plane.speed)/plane.cruise(),0.5,1.5)})

## The near misses and the land's contact (weighted presets, flying):
## measured round the body, a touch graded (a scrape, or a crash and back
## up), the moments scored and the surge spent (`fly_surge` held); the
## frame's `events` get "near", "banked", "scrape", "crash", "lost", "surge"
## for the rumble, the sound and the HUD, and the punch, shake and debris
## fire off them.
func _near_misses(delta: float, events: Dictionary) -> void:
	_fade_left = maxf(0.0,_fade_left-delta)
	if not plane.weighted or not hand_landing.flying():
		plane.surge = 0.0
		near.surge = 0.0
		debris.spray(false,Vector3.ZERO,Vector3.ZERO)
		# A limb come down on it on the ground (StomperSolid `before`).
		if _glanced.has("crash"): _crashed(events,_glanced.crash)
		_glanced = {}
		return
	near.measure(delta,self)
	if smash != null: smash.touch(near)
	var hit := contact.step(delta,self,near.touching)
	if hit.is_empty() and not _glanced.is_empty(): hit = _glanced
	_glanced = {}
	if hit.has("knock"): _knocked(events,hit.knock)
	if hit.has("crash"):
		_crashed(events,hit.crash)
		return
	if hit.has("scrape"):
		var s: Dictionary = hit.scrape
		events["scrape"] = s
		var lost := near.lose()
		if lost > 0.0: events["lost"] = {"points":lost}
		if water != null and str(s.what) == "water": water.splash(s.at,0.5+clampf(float(s.get("into",0.0))/7.0,0.0,1.0)*0.5,events)
		else: debris.hit(str(s.what),s.at,s.normal)
		_shake = maxf(_shake,SCRAPE_SHAKE*_shake_scale)
	events.merge(near.score(delta,self,Input.is_action_pressed(&"fly_surge") or (smash != null and smash.hot)))
	if events.has("near"):
		var m: Dictionary = events.near
		var k := float(m.k)
		_punch_want = maxf(_punch_want,PUNCH*k)
		_shake = maxf(_shake,NEAR_SHAKE*k*_shake_scale)
		var at: Vector3 = m.at
		if m.surface == "tree": debris.burst("leaves",at,Vector3.UP)
		elif m.surface == "water" and water == null: debris.burst("spray",Vector3(at.x,water_at(at),at.z),Vector3.UP)
	var p: Vector3 = plane.position
	var wet: bool = near.ground_surface == "water" and near.ground_clear < WorldScale.span*SPRAY_SPANS and float(plane.speed) > plane.cruise()*SPRAY_FAST
	debris.spray(wet and water == null,Vector3(p.x,water_at(p),p.z),plane.velocity)

## The crash `c` (FlightContact): `events` gets it, the chain lost with it.
func _crashed(events: Dictionary, c: Dictionary) -> void:
	events["crash"] = c
	events["lost"] = {"points":near.lose()}
	if water != null and str(c.what) == "water": water.splash(c.at,1.5,events)
	else: debris.hit(str(c.what),c.at,c.normal,true)
	crash(c)

## Trees knocked down this frame (TreeKnock `before`, `at_hit`): `events`
## gets "knock" (more than one in a frame add up) and, with TreeKnock
## LOSES_CHAIN, the unbanked chain's "lost"; the shake a scrape's.
func _knocked(events: Dictionary, k: Dictionary) -> void:
	var was: Variant = events.get("knock")
	if was is Dictionary:
		k = k.duplicate()
		k.count = int(k.count)+int((was as Dictionary).count)
		k.heft = maxf(float(k.heft),float((was as Dictionary).heft))
	events["knock"] = k
	if TreeKnock.LOSES_CHAIN:
		var lost := near.lose()
		if lost > 0.0: events["lost"] = {"points":lost}
	_shake = maxf(_shake,SCRAPE_SHAKE*_shake_scale)

## A hit felt: the view's shake raised to `shake` (rad) and its punch to
## `punch` degrees, whatever `--shake=` says (the surge roll's).
func feel_hit(shake: float, punch: float) -> void:
	_shake = maxf(_shake,shake)
	_punch_want = maxf(_punch_want,punch)

## Water on the screen (0 to 1; WaterContact `douse`): a splash in the
## sound and the air muffled a moment. For anything that douses the eye.
func wet(amount: float) -> void:
	if water != null: water.douse(amount)

## Crashed: flying on from a little behind and above where it was, on the
## way it was going, at cruise (CRASH_BACK, CRASH_UP over what stands to
## CRASH_LOOK on), the screen dipped dark and lifting. `hit` is what it hit
## (FlightContact): against a tower's wall it stays at its height, off the face
## (`_off_tower`), since what stands ahead there is 400 m of rock.
func crash(hit := {}) -> void:
	var p: Vector3 = plane.position
	var way := Vector2(plane.velocity.x,plane.velocity.z)
	if way.length() < 0.5: way = Vector2(-sin(float(plane.heading)),-cos(float(plane.heading)))
	way = way.normalized()
	var off := _off_tower(hit,way)
	if not off.is_empty():
		crashes += 1
		_launch(off.at,off.heading)
		_fade_left = FADE_TIME
		return
	var back := Vector2(p.x,p.z)-way*CRASH_BACK
	var top := Field.SEA_Y
	for i in range(9):
		var q := back+way*(CRASH_BACK+CRASH_LOOK)*i/8.0
		var h: float = field.height(q.x,q.y)
		var under: Variant = plane_ground(Vector3(q.x,h+300.0,q.y))
		top = maxf(top,(under as Vector2).x if under is Vector2 else (float(under) if under != null else h))
	crashes += 1
	_launch(Vector3(back.x,top+CRASH_UP,back.y),atan2(-way.x,-way.y))
	_fade_left = FADE_TIME

## Where a crash into a tower's wall flies on from: {at, heading}, CRASH_OFF m
## or more out from the face at the plane's height (over the land, if that rises),
## turned along the face the way it was nearer going, with CRASH_LOOK m clear
## ahead. {} for any other hit, on a tower's top, or with nowhere clear.
func _off_tower(hit: Dictionary, way: Vector2) -> Dictionary:
	if not bool(hit.get("tower",false)): return {}
	var n: Vector3 = hit.normal
	var out := Vector2(n.x,n.z)
	if out.length() < CRASH_WALL: return {}
	out = out.normalized()
	var along := out.orthogonal()
	if along.dot(way) < 0.0: along = -along
	var p: Vector3 = plane.position
	for d: float in [CRASH_OFF,CRASH_OFF*2.0,CRASH_OFF*4.0]:
		for side: Vector2 in [along,-along]:
			var from := Vector2(p.x,p.z)+out*d
			var y := p.y
			for i in range(9):
				var q := from+side*CRASH_LOOK*i/8.0
				y = maxf(y,float(field.height(q.x,q.y))+CRASH_UP)
			var clear := true
			for i in range(9):
				var q := from+side*CRASH_LOOK*i/8.0
				var under: Variant = plane_ground(Vector3(q.x,y,q.y),CRASH_UP)
				var top := (under as Vector2).x if under is Vector2 else (float(under) if under != null else -INF)
				if y < top: clear = false
			if clear: return {"at":Vector3(from.x,y,from.y),"heading":atan2(-side.x,-side.y)}
	return {}

## A hard pull-out sinking through (the weight's path under the nose):
## `events` gets a "sink" knock for the rumble, once per pull-out.
func _feel_sink(events: Dictionary) -> void:
	if not plane.weighted or not hand_landing.flying():
		_sink_felt = false
		return
	var aoa := float(plane.aoa)
	if aoa < SINK_REARM: _sink_felt = false
	elif not _sink_felt and aoa > SINK_AOA and float(plane.velocity.y) < -SINK_DOWN:
		_sink_felt = true
		events["sink"] = {"k":clampf((aoa-SINK_AOA)/0.25,0.0,1.0)}

## The next weight preset (V, the pad's d-pad up), mid-flight, named on
## screen.
func _next_weight() -> void:
	weight = FlightWeight.next(weight)
	plane.use_weight(weight)
	chase.use_weight(FlightWeight.knobs(weight))
	hand_landing.land_most = FlightContact.LAND_MOST if plane.weighted else INF
	if not plane.weighted: near.reset()
	_weight_note.text = "Weight: %s" % weight
	_weight_shown = Time.get_ticks_msec()

## H: the near misses' HUD in the tag by the plane or at the top, kept.
func _next_near_layout() -> void:
	if not _near_hud.has_method("set_tag"): return
	var tag := not bool(_near_hud.get("tag"))
	_near_hud.call("set_tag",tag)
	_weight_note.text = "Score: %s" % ("by the plane" if tag else "at the top")
	_weight_shown = Time.get_ticks_msec()

## The next pace preset (P, the pad's d-pad right), mid-flight, named on
## screen with its cruise and Boost.
func _next_pace() -> void:
	pace = FlightPace.next(pace)
	plane.use_pace(FlightPace.speed(pace))
	_weight_note.text = "Pace: %s  ·  cruise %d, Boost %d m/s" % [pace,roundi(plane.cruise()),roundi(plane.boost_speed())]
	_weight_shown = Time.get_ticks_msec()

## The grass reacting: the plane's wash (by its height and thrust) and the
## look's breeze for the gusts (GrassReact `step`).
func _react(delta: float) -> void:
	FrameLog.mark(&"react_pre")
	var p: Vector3 = plane.position
	var h: float = field.height(p.x,p.z)
	var over := p.y-h if h > Field.SEA_Y+0.2 and not _on_river() else NAN
	var thrust := 0.0
	if hand_landing.on_ground(): thrust = hand_landing.engine*(0.3+0.7*maxf(hand_landing.throttle,0.0))
	else: thrust = float(plane.engine)*clampf(0.6+0.4*float(plane.throttle),0.35,1.0)
	var facing := -camera.global_basis.z
	if eddies != null:
		eddies.step(delta,camera.global_position,Vector2(facing.x,facing.z),look.wind_direction,1.0,Callable(self,"_grass_at"))
	FrameLog.mark(&"r_eddies")
	react.step(delta,camera.global_position,
		{"position": p, "forward": plane.forward(), "over": over, "thrust": thrust, "size": ground_scale.size()},
		{"way": look.wind_direction, "travel": look._gust, "facing": Vector2(facing.x,facing.z)},
		Callable(self,"_grass_at"))
	FrameLog.mark(&"r_grass")
	# Parked in the menu, the grass lies parted round the wheels.
	# And round the eye circling it, so the blades at its feet lean out of
	# its way rather than across the view.
	if stage != null and stage.holding():
		var span := WorldScale.TOY_SPAN*ground_scale.size()
		react.part(Vector2(p.x,p.z),span*PART_SPANS,PART_PUSH)
		var e := camera.global_position
		react.part(Vector2(e.x,e.z),span*EYE_PART_SPANS,PART_PUSH,1)
	# Parked in the menu the idling wash stirs the grass but kicks none up.
	var wash: Dictionary = {} if stage != null and stage.holding() else react.wash_spot
	# On the Peak's snow the wash throws powder and cuts a furrow, not grass.
	if snow != null: wash = snow.step(delta,p,wash,look.wind_direction,camera.global_position)
	FrameLog.mark(&"r_snow")
	if motes != null:
		var skims: Array = eddies.ribbons.ribbons if eddies != null else []
		if snow != null: skims = snow.off_snow(skims)
		motes.step(delta,camera.global_position,look.wind_direction,look._gust,wash,skims,Callable(self,"_grass_at"))

## The land's height where grass grows (open turf over the beach), else NAN.
func _grass_at(x: float, z: float) -> float:
	var h: float = field.height(x,z)
	return h if h > Field.SEA_Y+3.0 and field.last_river > Field.RIVER_CLEAR else NAN

## The stop's cue over the hint: stopped, Boost rolls it off and Brake
## pressed again backs it up (ManualLanding `_stopped`); backing up,
## letting go stops it. Not in the menu, nor while a race counts down
## (its tag says hold still).
func _stop_note() -> void:
	var words := ""
	if hand_landing.phase == ManualLanding.STOPPED: words = "stopped  ·  Space boost to roll  ·  Shift again to back up"
	elif hand_landing.phase == ManualLanding.ROLL and hand_landing.reversing: words = "backing up  ·  let go of Shift to stop"
	if race != null and race.phase == "count": words = ""
	_stop_cue.text = words
	_stop_cue.visible = words != "" and _hint.visible and stage == null

func _frame(delta: float) -> void:
	var right := Vector2.ZERO if stage != null and stage.holding() else Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	if right != Vector2.ZERO: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*delta)
	chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
	if coast != null: coast.watch(chase)
	chase.tight = tunnels.near(plane.position) or (doors != null and doors.holds(plane.position))
	chase.step(delta,plane,0.0,_solid)
	camera.global_position = chase.eye
	var way: Vector3 = chase.look-chase.eye
	if way.length() < 0.01: way = plane.forward()
	camera.look_at(camera.global_position+way,Vector3.UP)
	camera.rotate_object_local(Vector3.FORWARD,chase.roll)
	_buffet(delta)
	_shake_eye(delta)
	_streak_step(delta)
	_punch_want *= exp(-delta/PUNCH_FADE)
	_punch = lerpf(_punch,_punch_want,1.0-exp(-delta/PUNCH_IN)) if delta > 0.0 else _punch_want
	camera.fov = chase.fov+_punch+_speed_wide(delta)

## How low and fast it is over the land (0 to 1): within LOW_SPANS
## wingspans of what is under it (the near misses' ground clearance when
## weighted, else the land's), from LOW_SPEED.x to .y m/s; none on the wheels.
func _low_fast() -> float:
	if hand_landing.on_ground(): return 0.0
	var p: Vector3 = plane.position
	var clear := p.y-maxf(float(field.height(p.x,p.z)),Field.SEA_Y)
	if plane.weighted and near.ground_clear < INF: clear = minf(clear,float(near.ground_clear))
	var span := WorldScale.span
	return (1.0-smoothstep(LOW_SPANS.x*span,LOW_SPANS.y*span,clear))*smoothstep(LOW_SPEED.x,LOW_SPEED.y,float(plane.velocity.length()))

## The view's extra widening with the speed and low over the land (degrees,
## eased over WIDE_EASE s).
func _speed_wide(delta: float) -> float:
	var v: float = plane.velocity.length()
	var want := 0.0 if hand_landing.on_ground() else WIDE_FOV*smoothstep(WIDE_SPEED.x,WIDE_SPEED.y,v)+LOW_WIDE*_low_k
	_wide = lerpf(_wide,want,1.0-exp(-delta/WIDE_EASE)) if delta > 0.0 else want
	return _wide

## The streaks this frame: by the speed, low over the land, Boost and the
## surge, running out from where it is going on screen.
func _streak_step(delta: float) -> void:
	_low_k = _low_fast()
	if _streaks == null: return
	var v: float = plane.velocity.length()
	var want := 0.0
	var centre := Vector2(0.5,0.5)
	if not hand_landing.on_ground() and _streak_scale > 0.0:
		var boost := Input.get_action_strength(&"fly_boost")*smoothstep(30.0,50.0,v)
		want = (STREAK_TOP*smoothstep(STREAK_SPEED.x,STREAK_SPEED.y,v)+LOW_STREAK*_low_k+BOOST_STREAK*boost+SURGE_STREAK*float(plane.surge))*_streak_scale
		var ahead: Vector3 = camera.global_position+plane.velocity.normalized()*200.0
		if not camera.is_position_behind(ahead):
			var view := get_viewport().get_visible_rect().size
			if view.x > 0.0 and view.y > 0.0: centre = (camera.unproject_position(ahead)/view).clamp(Vector2(0.2,0.2),Vector2(0.8,0.8))
	_streaks.show_state(delta,want,v/STREAK_FLOW,centre,_low_k)

## The wind's buffet past cruise: a small shake of the eye's aim, three
## sines out of step, growing to RUSH_SHAKE at Boost's speed. None on the
## wheels.
func _buffet(delta: float) -> void:
	if _rush <= 0.0 or hand_landing.on_ground(): return
	_rush_t += delta
	var v: float = plane.velocity.length()
	var k := smoothstep(plane.cruise()*RUSH_FROM,plane.boost_speed(),v)*RUSH_SHAKE*_rush
	if k <= 0.0: return
	var t := _rush_t*TAU
	var yaw := sin(t*RUSH_HZ.x)*0.6+sin(t*RUSH_HZ.z+1.7)*0.4
	var nod := sin(t*RUSH_HZ.y+0.9)*0.6+sin(t*RUSH_HZ.x*1.31+2.3)*0.4
	camera.rotate_object_local(Vector3.UP,yaw*k)
	camera.rotate_object_local(Vector3.RIGHT,nod*k*0.7)

## The near misses' shake (a scored moment's, a scrape's, dying away) and
## the buffet low and fast over the land: three sines out of step.
func _shake_eye(delta: float) -> void:
	_shake *= exp(-delta/SHAKE_FADE)
	var k := _shake
	if plane.weighted and not hand_landing.on_ground(): k += LOW_SHAKE*_shake_scale*float(plane.low)*clampf(float(plane.speed)/plane.cruise(),0.5,1.5)
	if k < 0.0002: return
	_shake_t += delta
	var t := _shake_t*TAU
	camera.rotate_object_local(Vector3.UP,(sin(t*SHAKE_HZ.x)*0.6+sin(t*SHAKE_HZ.z+1.1)*0.4)*k)
	camera.rotate_object_local(Vector3.RIGHT,(sin(t*SHAKE_HZ.y+0.4)*0.6+sin(t*SHAKE_HZ.x*1.37+2.0)*0.4)*k)

static func _has_arg(prefix: String) -> bool:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with(prefix): return true
	return false

## The plane's input, as the isle reads it (studies/kit_isle.gd `_fly_input`).
func _fly_input(_delta: float) -> Dictionary:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var lean := clampf(keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left"),-1.0,1.0)
	var input := {"turn":stick.x,"pitch":stick.y,"look":_fly_look,"lean":lean,
		"boost":Input.get_action_strength(&"fly_boost"),"brake":Input.get_action_strength(&"fly_brake"),"roll":_roll_asked}
	_fly_look = Vector2.ZERO
	_roll_asked = 0.0
	return input

## Rolls asked for by the roll button (for drivers).
var rolls_asked := 0

## Z / the pad's south face (`fly_roll`): a barrel roll on one press, toward
## the side leant to (Q E, the shoulders), else the way banked, else the way
## the stick turns, else right (as the burrower study's Space).
func roll_button() -> void:
	_roll_asked = roll_side()
	rolls_asked += 1

## The way a roll goes now: see `roll_button` (the surge roll's too).
func roll_side() -> float:
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	var lean := keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left")
	var turn := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back").x
	var bank := float(plane.bank)
	if absf(lean) > 0.2: return signf(lean)
	if absf(bank) > 0.05: return signf(bank)
	if absf(turn) > 0.2: return signf(turn)
	return 1.0

## The takeoff is the player's: the stage gone, the mouse taken, the hints
## back.
func _menu_done() -> void:
	if stage != null and stage.running(): stage.finish(plane_figure)
	stage = null
	if camera.attributes != null: camera.attributes = null
	_hint.visible = true
	if get_tree().current_scene == self and DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Back up into the air over where it is, on the heading it had.
func respawn() -> void:
	var at: Vector3 = plane.position
	_start = Vector2(at.x,at.z)
	_launch(Vector3(at.x,_start_height(),at.z),float(plane.heading))

func _unhandled_input(event: InputEvent) -> void:
	if not walk_ready: return
	# The menu holds the flight: none of its keys while it is up.
	if stage != null and stage.holding(): return
	# Photo mode: O opens it while no overlay is up, and it takes them all.
	if photo.handle(event): return
	# An overlay (the shop, the logbook, photo mode) takes the keys while up.
	if overlay != null: return
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): chase.turn(Vector2(-event.relative.x,-event.relative.y)*FLY_LOOK)
		else: _fly_look += Vector2(event.relative.x,-event.relative.y)*FLY_LOOK
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else: _roll_asked = -1.0 if float(plane.bank) < -0.05 else 1.0
	elif Pad.pressed(event,&"fly_land"): _land_key()
	elif Pad.pressed(event,&"fly_weight"): _next_weight()
	elif Pad.pressed(event,&"fly_pace"): _next_pace()
	elif event.is_action_pressed(&"fly_roll") and not event.is_echo(): roll_button()
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F: _land_key()
			KEY_F1: _hud.visible = not _hud.visible
			KEY_F2: _next_scale()
			KEY_F3: _next_preset()
			KEY_R: respawn()
			KEY_V: _next_weight()
			KEY_P: _next_pace()
			KEY_T:
				if look != null: look.next_hour()
			KEY_L:
				if look != null: look.next_mood()
			KEY_BRACKETRIGHT:
				if look != null: look.faster()
			KEY_BRACKETLEFT:
				if look != null: look.slower()
			KEY_C:
				if look != null and look.clouds != null: look.clouds.set_enabled(not look.clouds.enabled)
			KEY_G:
				if grass != null: grass.set_enabled(not grass.enabled)
			KEY_H: _next_near_layout()
			KEY_J: logbook.open_book()
			KEY_K:
				if look != null and look.land_shade != null: look.land_shade.toggle()
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	tallies.finish()
	if book != null: book.save()
	if get_tree().root.window_input.is_connected(Pad.note): get_tree().root.window_input.disconnect(Pad.note)
	var rr := preload("res://scripts/render_resolution.gd")
	rr.native_scale = 1.0
	rr.apply(get_tree().root,rr.load_cap())

## F2: the 3D's resolution through SCALES (the window's own, then upscaled
## by FSR), to judge sharpness against the frame rate; shown on the hint
## line and the numbers.
const SCALES := [1.0,0.85,0.75,0.67]
func _next_scale() -> void:
	var rr := preload("res://scripts/render_resolution.gd")
	var now := get_viewport().scaling_3d_scale
	var i := 0
	for k in SCALES.size():
		if absf(SCALES[k]-now) < 0.01: i = k
	rr.scale_override = SCALES[(i+1)%SCALES.size()]
	rr.apply(get_tree().root,rr.load_cap())
	_hint.text = _hint.text.get_slice("  ·  3D at",0)+"  ·  3D at %d%%" % roundi(rr.scale_override*100.0)

## F3: the next graphics preset, kept, and the flight again on it.
func _next_preset() -> void:
	_hint.text = "graphics: %s ..." % GraphicsPreset.PRESETS[GraphicsPreset.step()].title
	GraphicsPreset.restart(get_tree(),scene_file_path)

func _cloud_note() -> String:
	if look.clouds == null: return "  ·  no clouds"
	if not look.clouds.enabled: return "  ·  clouds off (C)"
	return "  ·  in cloud" if look.clouds.in_cloud(camera.global_position) else ""

## The numbers (F1) are written HUD_EVERY ms apart: walking the land's and
## the grass's counts and laying the label out every frame cost about 4 ms.
const HUD_EVERY := 250
var _hud_at := -HUD_EVERY

## The region under the eye (a world of regions): its caption when the eye
## crosses into it, faded out after a few seconds, and --region-debug's line.
func _show_region() -> void:
	if _region_caption == null: return
	var eye := camera.global_position
	# The paint (ground, far ring, sea, globals, mood and hour) by the eye's weights.
	if world.paint_eye(eye.x,eye.z) and look != null: look.blend_moods(world.moods_at_eye())
	var now := Time.get_ticks_msec()
	# Not over the title: its caption comes up as the takeoff ends.
	if stage != null:
		_region_shown = now
		_region_caption.modulate.a = 0.0
		return
	var w: Dictionary = world.weights_at(eye.x,eye.z)
	for r: RefCounted in w:
		if str(r.id) != _region_id and (float(w[r]) >= REGION_TAKE or _region_id == ""):
			_region_id = str(r.id)
			_region_caption.text = str(r.title)
			_region_shown = now
	var age := now-_region_shown
	_region_caption.modulate.a = clampf(age/400.0,0.0,1.0)*clampf(1.0-float(age-REGION_HOLD)/REGION_FADE,0.0,1.0)
	if _region_debug != null: _region_debug.text = world.describe(eye.x,eye.z)

func _show_hud() -> void:
	_show_region()
	_near_hud.key_name = "X" if Pad.using_pad() else "B"
	if "plane_at" in _near_hud: _near_hud.plane_at = plane_figure.global_position
	_near_hud.show_state(get_process_delta_time(),near,bool(plane.weighted) and not hand_landing.on_ground(),_events)
	_fade.color.a = 0.85*smoothstep(0.0,FADE_TIME,_fade_left)
	var since := Time.get_ticks_msec()-_weight_shown
	_weight_note.modulate.a = clampf(1.0-float(since-WEIGHT_HOLD)/WEIGHT_FADE,0.0,1.0)
	if not _hud.visible or Time.get_ticks_msec()-_hud_at < HUD_EVERY: return
	_hud_at = Time.get_ticks_msec()
	var p: Vector3 = plane.position
	var c: Dictionary = land.counts()
	var s: Dictionary = land.stats
	# The GPU's own time, where the driver reports it (not on Metal).
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	_hud.text = "seed %d  ·  %s  ·  %.1f m/s  ·  %.0f m over the ground  ·  flaps %s\nat %.0f, %.0f  ·  %d fps (%.1f ms)%s%s%s\nland: %d drawn, %d standing, %d wanted, %d building, %d queued, %d colliders\nbuilt %d (%.1f ms each on a worker), slowest commit %.2f ms%s" % [
		seed,ManualLanding.NAMES[hand_landing.phase],float(plane.speed),p.y-maxf(field.height(p.x,p.z),Field.SEA_Y),"down" if flaps else "up",
		p.x,p.z,Engine.get_frames_per_second(),1000.0/maxf(Engine.get_frames_per_second(),1.0),
		("  ·  gpu %.2f ms" % gpu) if gpu > 0.0 else "",
		"  ·  3D at %d%%  ·  %s (F3)" % [roundi(get_viewport().scaling_3d_scale*100.0),GraphicsPreset.title()],
		("  ·  %s, %05.2f h (%s)%s" % [look.mood_title(),look.hour(),look.time_note(),_cloud_note()]) if look != null else "",
		int(c.drawn),int(c.standing),int(c.wanted),int(c.in_flight),int(c.queued),int(c.colliders),
		int(s.built),float(s.build_ms)/maxf(float(s.built),1.0),float(s.slowest_commit_ms),_grass_note()+_react_note()+_arch_note()+_rock_note()+_hall_note()+trees.note()+knock.note()+birds.note()+(fish.note() if fish != null else "")+(traffic.note() if traffic != null else "")]
	_hud.text += "
weight %s  ·  pace %s (cruise %.1f, Boost %.1f)  ·  %.1f g  ·  nose over path %.0f°  ·  soft %.2f  ·  streaks %.2f, fov %.1f" % [weight,pace,plane.cruise(),plane.boost_speed(),float(plane.g_load),rad_to_deg(float(plane.aoa)),float(plane.soft),_streaks.strength,camera.fov]
	if plane.weighted: _hud.text += "\nnear: ground %.1f m (%s)  ·  stone %.1f m  ·  gap %.2f m  ·  low %.2f  ·  chain %d x%.1f  ·  meter %.2f  ·  total %d  ·  scrapes %d, crashes %d" % [
		near.ground_clear,near.ground_surface,near.stone_clear,near.gap,float(plane.low),near.chain_count,near.multiplier(),near.meter,roundi(near.total),contact.scrapes,crashes]
	if water != null: _hud.text += "
"+water.note()

func _react_note() -> String:
	if react == null: return ""
	return "\ngrass react: %d stamps, wash %.2f, %d gusts" % [int(react.stats.stamps),float(react.stats.wash),int(react.stats.gusts)]

func _arch_note() -> String:
	if arches.density <= 0.0: return "\nno arches"
	var a: Dictionary = arches.stats
	return "\narches: %d standing in %d cells  ·  slowest build %.0f ms on a worker, slowest commit %.2f ms" % [int(a.arches),int(a.cells),float(a.slowest_build_ms),float(a.slowest_commit_ms)]

func _rock_note() -> String:
	return "" if not rocks.on else "
"+rocks.note()

func _hall_note() -> String:
	var out: String = "" if halls.density <= 0.0 else "\n"+halls.note()
	if tunnels != null and int(tunnels.stats.tunnels) > 0: out += "\n"+tunnels.note()
	return out

func _grass_note() -> String:
	if grass == null: return ""
	if not grass.enabled: return "\ngrass off (G)"
	var g: Dictionary = grass.counts()
	var gs: Dictionary = grass.stats
	return "\ngrass: %d cells, %d building, %d queued, %dk plants  ·  %.0f ms a cell on a worker, slowest stand %.2f ms" % [
		int(g.cells),int(g.building),int(g.queued),int(g.instances)/1000,float(gs.grow_ms)/maxf(float(gs.grown),1.0),float(gs.slowest_stand_ms)]

## F (pad Y) in the air: the flaps go down or up.
func _land_key() -> void:
	if hand_landing.flying(): flaps = not flaps
