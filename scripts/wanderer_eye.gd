extends Node
## The pilot on foot, seen from behind: V with the pointer on the land sets
## the pilot down there (or picks them up and moves them) and the camera
## swoops down behind; V with the pointer off the land steps out where they
## stand. The mouse is captured: it swings the camera round the pilot, WASD
## or the arrows run the way the camera looks (no sprint: a run is the pace;
## a light touch on the stick walks). The pilot
## (scripts/pilot_figure.gd) moves like a platformer's hero
## (scripts/pilot_motor.gd): turning to run the way asked, skidding on a
## hard reversal, jumping as high as Space is held, jumped again on landing
## the higher pump, jumped in a skid the side flip; crouched (Shift, C or
## LT) sliding to a stop, and from a crouch at a run the long jump; crouched
## on a slope (or on any too steep to stand on) boot-surfing down it, Space
## jumping out at its pace; X pressed in the air twirling; slowed
## running up steep ground; into a cliff in the air sliding down it, Space
## kicking off it. The camera eases round behind the
## run when the mouse is left alone. V or Esc steps back out to building,
## and the camera glides back to where it was; the pilot is hidden there
## and kept where you walked them. Each footfall sounds
## (scripts/wanderer_steps.gd): earth, a bridge's planks or a wade, as the
## drawn boot touches down; at a run it kicks up puffs of the ground behind,
## lands in a ring of them and sprays them ahead in a skid (scripts/
## pilot_puffs.gd). Through the pond's live water he wades, rings spreading
## from his legs (scripts/pilot_ripples.gd) and droplets off each wet
## footfall; deeper he swims, a V of rings opening behind him and a splash
## off each stroke; out of it he drips a while and his clothes dry
## (scripts/pilot_figure.gd `soak`).
##
## Like photo mode (scripts/photo_mode.gd) this runs before the scene each
## frame (process_priority) and writes the pose into the scene's own orbit
## (target, yaw, polar, distance), so the fog, reflections and look pass read
## the same camera they always do. The figure is not saved with the place.
##
## Walked off the plate's edge, the figure glides (scripts/sky_glide.gd): out
## over the cloud sea towards fresh flat chunks set in the sky
## (scripts/sky_islands.gd), with the air streaking past and the wind's sound
## (scripts/glide_air.gd). Touching down on land skims along it, and a
## slow skim lands, back to walking. Space again in a jump, on the way up
## or falling from high, opens the flight anywhere. Over the island the wind lifts it where it blows up a slope
## (ridge lift) and as a gust front passes, and tree crowns lift it over
## them like the ground. A prototype: `--no-glide` keeps the old plate clamp.
##
## It flies a little prop plane (scripts/sky_plane.gd, drawn by
## scripts/plane_figure.gd): always under power, Space or the pad's right
## trigger (or A) boosts, Shift or the left trigger brakes, left and right
## roll it into its turns, and Q and E (or a click, or the pad's shoulders)
## throw a barrel roll. The mouse (or the right stick) pans the camera round
## it rather than steering, and the pan holds PLANE_LINGER seconds before
## swinging back behind, for the view. In the air the camera chases it from
## behind (scripts/glide_camera.gd); C swaps to the view from the cockpit. It
## can dip under an island's slab. Near the ground a mark shows where it
## would touch down.
##
## F lands it (scripts/plane_landing.gd): the nearest island within
## LANDING_REACH is claimed if it is not the plate yet, a strip picked on
## its land (scripts/plane_strip.gd: the longest, flattest clear run, into
## the wind), and the plane lines up, glides down, flares, touches with a
## bounce and a puff, rolls to a stop, and the pilot hops out; the camera
## swoops down behind them beside it. Before the touch, Boost, a roll or F
## again flies on; after, F hops out at once. A slow touch anywhere on the
## land without F rolls it to a stop where it came down. The plane stays
## parked where it stopped, on its wheels and tail skid, out of the way of
## the editor's tools (not a record on the land; the walker steps round
## it). Walked up to, Space takes off from it: the pilot hops in, it turns
## to its longest clear run, rolls, lifts and flies. Flying any other way
## (off the edge, a held jump) brings it along: the parked one goes in a
## puff, so there is only ever the one plane, and it is always yours.
##
## The pad (docs/gamepad.md) runs with the left stick, as fast as it is
## pushed (a click of it runs faster until the stick comes back to rest),
## swings the camera with the right, jumps (or takes off by the plane, or
## again in the air flies) with A, and B or View steps out. Flying keeps the stick,
## triggers and shoulders, Y lands and R3 swaps the camera. Every read goes
## through scripts/pad.gd's named actions, the keys beside the pad's where
## they are polled; the hints name the pad's controls while it is in hand
## (scripts/pad_prompt.gd).
##
## The island's rim (and an islet's) is a ledge (scripts/pilot_ledge.gd,
## the motor's hold): stepping off it carefully (a walk, or the stick let
## go or pulled back) the pilot turns and lowers himself to hang from it
## (run off it and he flies, as ever); a step in the land too steep to walk
## is caught falling past it. Hanging, the stick along the lip shimmies,
## towards it or Space climbs up, away lets go (off the rim, into the
## flight).
##
## With `--glider` it glides under the old cloth wing instead
## (scripts/glider_figure.gd): a click (or E, or the pad's X) flaps for lift
## of its own, the right mouse button (or the right stick) looks round it,
## F comes in to land at the island's middle, and touching down slowly
## anywhere on the island lands, the camera swooping down behind the pilot.
##
## With `--below` (scripts/sky_below.gd) the cloud sea is a way down: dived
## through, it comes out over the lower world's ocean, its floor just over
## the water, and climbs back up through the cloud. Down there it claims no
## island and lands nowhere.

const Plate = preload("res://scripts/plate.gd")
const Pad = preload("res://scripts/pad.gd")
## The figure's height and the eye's height above the ground, in metres. The
## diorama is toy-scaled: trees stand about 3 to 5 m and photo mode's ground
## eye sits at 0.85 m.
const FIGURE_HEIGHT := 0.95
const EYE_HEIGHT := 0.85
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PilotLedge = preload("res://scripts/pilot_ledge.gd")
const SolidProps = preload("res://scripts/solid_props.gd")
## Jogging and running speed, in metres a second (the motor's).
const WALK := PilotMotor.WALK
const RUN := PilotMotor.RUN
## Radians of look per pixel of captured mouse movement.
const LOOK := 0.0025
## The camera's vertical field of view on foot, in degrees, eased in on
## stepping in and back on stepping out.
const FOV := 60.0
const EASE_FOV := 0.2
## The camera behind the pilot: how far back, how high over the feet it
## looks, its tilt at rest (up over the pilot, looking down on them and the
## ground round them, about 40 degrees: steeper and the horizon leaves the
## top of the frame), and the range of its tilt (polar from straight up:
## high over the pilot to low, looking up past them).
const CAM_DISTANCE := 7.0
const CAM_HEIGHT := 0.8
const CAM_POLAR := PI*0.5-0.7
const POLAR := Vector2(0.45,1.85)
## How the look point follows the feet up and down, on the ground and,
## lagging so a jump is not chased, in the air.
const EASE_CAM_Y := 0.08
const EASE_CAM_Y_AIR := 0.35
## Across the ground the look point follows the feet on a spring, CAM_FOLLOW
## Hz, critically damped: the pilot sets off and drifts ahead, the camera,
## slow to start, pans after and keeps a little behind a run (about a metre
## at a full one), and stopping, it eases in over them. Never more than
## CAM_LAG m behind.
const CAM_FOLLOW := 1.4
const CAM_LAG := 1.6
## Left alone LOOK_REST seconds, the camera swings round behind the run,
## at FOLLOW (an easing time, at a full run); never while running at it.
const LOOK_REST := 0.8
const FOLLOW := 0.9
## The camera keeps this far over the ground, drawing in to, and eases back
## out over EASE_CAM_OUT.
const CAM_CLEAR := 0.35
const CAM_NEAREST := 0.9
const EASE_CAM_OUT := 0.4
## The walk stays on the plate.
const PLATE_REACH := Plate.HALF-0.5
## How far inside the shore a walker is put back on an outlined island (m).
const SHORE_INSET := 0.1
## Seconds the glide back to the orbit takes.
const RETURN := 0.7
## The figure's own radius in the plate plane, with room for the eye's near
## plane, so trunks and rocks never fill the view.
const RADIUS := 0.28
## What stops the figure: trees, rocks, cabins and the other solid props.
## Only their geometry between STEP and HEAD above the feet counts, so a
## crown that sweeps low (a spruce) keeps the eye out of it, a broadleaf's
## high crown does not, and anything lower than STEP is stepped over. They
## have tops and heights (scripts/solid_props.gd, `solids`): a rock, log,
## stump, boulder or cabin is ground to stand on once the feet are within a
## step of its top, and trunks, tall rocks and cabin walls are walls to
## slide down and kick off.
const SOLID := ["tree","layered_tree","redwood","broadleaf","bigfoot_tree","snag","birch","willow","juniper","joshua","cactus",
	"rock","log","stump","boulder_1","boulder_2","boulder_3","boulder_4","cabin"]
const STEP := 0.2
const HEAD := FIGURE_HEIGHT+0.2
## Bands each part's mesh is cut into for its footprint (`_profile`).
const BANDS := 24
## Push-out passes a step takes; each can move off one more obstacle.
const PASSES := 3
## Water: the figure wades in, slowed by the motor (scripts/pilot_motor.gd
## WADE_SLOW), and swims where live water stands deeper than WADE metres; it
## is never set down there.
const WADE := PilotMotor.SWIM_IN
## How far round `place` looks for a free spot, and the ring spacing.
const FREE_REACH := 4.0
const FREE_STEP := 0.2
## Creatures notice the figure (scripts/disturbance.gd, scripts/life_notice.gd):
## a disturbance each STRIDE metres walked, as strong as the pace (a run is
## 1), one every STILL_PING seconds while it stands in its eyes, at
## STILL_STRENGTH, and one when it is set down, at PLACE_STRENGTH.
const STRIDE := 0.7
const STILL_PING := 2.0
const STILL_STRENGTH := 0.15
const PLACE_STRENGTH := 0.6
## A landing kicks up a ring of puffs from this hard (m/s), at its fullest
## this much harder; a stick pushed at least SET_OFF sets off in a push of
## them.
const PUFF_LAND := 5.0
const PUFF_LAND_FULL := 10.0
const SET_OFF := 0.7
## Ground cover at least GRASSY sounds as grass; bare ground within SHORE m of
## water to wade sounds as sand.
const GRASSY := 0.4
const SHORE := 0.7
const WandererSteps = preload("res://scripts/wanderer_steps.gd")
const PilotPuffs = preload("res://scripts/pilot_puffs.gd")
const PilotWake = preload("res://scripts/pilot_wake.gd")
const PilotRipples = preload("res://scripts/pilot_ripples.gd")
const BiomeBlend = preload("res://scripts/biome_blend.gd")
const Shape = preload("res://scripts/native_formation_shape.gd")
const Presets = preload("res://scripts/native_landscape_presets.gd")
const Disturbance = preload("res://scripts/disturbance.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const RopeBridge = preload("res://scripts/rope_bridge.gd")
const HINT := "Mouse to look  ·  WASD or arrows to run  ·  Space to jump, again in the air to fly  ·  V or Esc to step out"
const PERCH_HINT := "Mouse to look  ·  WASD or arrows to run  ·  Space to jump  ·  Off the edge or Space again in the air to fly  ·  V or Esc to step out"
const GLIDER_HINT := "Mouse to look  ·  WASD or arrows to run  ·  Space to jump, again in the air to glide  ·  V or Esc to step out"
const GLIDER_PERCH_HINT := "Mouse to look  ·  WASD or arrows to run  ·  Space to jump  ·  Off the edge or Space again in the air to glide  ·  V or Esc to step out"
## Beside the parked plane, coming in to land, and rolling out.
const BOARD_HINT := "Space to take off  ·  WASD or arrows to run  ·  Mouse to look  ·  V or Esc to step out"
const LANDING_HINT := "Coming in to land  ·  Space, Q E or F to fly on"
const ROLLING_HINT := "F to hop out"
const NO_LANDING_HINT := "No island near enough to land on"
const LEDGE_HINT := "A D or the arrows along the lip to shimmy  ·  Towards it or Space to climb up  ·  Away to let go"
const PLANE_HINT := "A D to bank and turn  ·  W S to pitch  ·  Mouse to look round  ·  Space to boost  ·  Shift to brake  ·  Hold Q E to knife-edge, twice quick or click to barrel roll  ·  F to land  ·  X to eject  ·  C for the camera  ·  V or Esc to step out"
## Out of the plane (scripts/sky_dive.gd): falling, and under the canopy.
const DIVE_HINT := "X to open the canopy  ·  A D to turn  ·  W to track forward  ·  Space to tuck and dive  ·  Shift to spread and slow  ·  Mouse to look round"
const CANOPY_HINT := "A D to steer  ·  W for speed  ·  S or Shift to brake and float  ·  It flares by itself over the ground"
const PICKUP_HINT := "Your plane swoops in and picks you up"
## The hints' forms for the pad (scripts/pad_prompt.gd `alternates`).
const PAD_HINTS := {
	HINT:"{LS} run  ·  {RS} look  ·  {A} jump, again in the air to fly  ·  {B} step out",
	PERCH_HINT:"{LS} run  ·  {RS} look  ·  {A} jump  ·  Off the edge or {A} again in the air to fly  ·  {B} step out",
	GLIDER_HINT:"{LS} run  ·  {RS} look  ·  {A} jump, again in the air to glide  ·  {B} step out",
	GLIDER_PERCH_HINT:"{LS} run  ·  {RS} look  ·  {A} jump  ·  Off the edge or {A} again in the air to glide  ·  {B} step out",
	BOARD_HINT:"{A} take off  ·  {LS} run  ·  {RS} look  ·  {B} step out",
	LANDING_HINT:"Coming in to land  ·  {RT}, {LB} {RB} or {Y} to fly on",
	ROLLING_HINT:"{Y} to hop out",
	LEDGE_HINT:"{LS} along the lip to shimmy  ·  {LS} towards it or {A} to climb up  ·  {LS} away to let go",
	PLANE_HINT:"{LS} steer  ·  {RS} look round  ·  {RT} boost  ·  {LT} brake  ·  hold {LB} {RB} knife-edge, twice quick barrel roll  ·  {Y} land  ·  {X} eject  ·  {R3} camera  ·  {B} step out",
	DIVE_HINT:"{X} open the canopy  ·  {LS} turn and track  ·  {RT} tuck and dive  ·  {LT} spread and slow  ·  {RS} look round",
	CANOPY_HINT:"{LS} steer, forward for speed, back to brake  ·  {LT} brake and float  ·  It flares by itself over the ground",
	FLY_HINT:"{LS} turn and pitch  ·  {X} flap  ·  {LT} rise  ·  {RT} dive  ·  {Y} land  ·  {RS} look round  ·  {R3} camera  ·  {B} step out",
}
## The right stick's swing of the camera on foot, radians a second at full
## tilt, round and up and down.
const STICK_WALK_LOOK := Vector2(2.2,1.4)
## The plane's camera pan holds this many seconds after the mouse or the
## right stick last turned it, then swings back behind.
const PLANE_LINGER := 2.5
## Walked within BOARD_REACH m of the parked plane, Space takes off; the
## walker keeps PARKED_ROOM m from its middle.
const BOARD_REACH := 1.9
const PARKED_ROOM := 0.75
## Hopping out, the walker lands this far to the plane's left (m) and a
## little ahead, and hops this high (m).
const HOP_SIDE := 1.4
const HOP_AHEAD := 0.3
const HOP_HEIGHT := 0.55
## Anything standing taller than this over its ground (m) is in the wings'
## way on a strip.
const WING_LOW := 0.28
const FLY_HINT := "Mouse or A D to turn  ·  W S to pitch  ·  Click or E to flap  ·  Space to rise  ·  Shift to dive  ·  F to land  ·  Right mouse to look round  ·  C for the camera  ·  V or Esc to step out"
const SkyGlide = preload("res://scripts/sky_glide.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
## The world's ring (scripts/sky_world.gd): with it, the view reaches across
## the whole world (VIEW_FAR), so the ring stands as a skyline.
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
## Where the walker reaches a token from (scripts/collectible_lines.gd).
const CollectibleLines = preload("res://scripts/collectible_lines.gd")
const GlideAir = preload("res://scripts/glide_air.gd")
const SkyFlight = preload("res://scripts/sky_flight.gd")
const SkyBelow = preload("res://scripts/sky_below.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const GliderFigure = preload("res://scripts/glider_figure.gd")
const IslandFrame = preload("res://scripts/island_frame.gd")
const GlideVapour = preload("res://scripts/glide_vapour.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PlaneStrip = preload("res://scripts/plane_strip.gd")
const PlaneLanding = preload("res://scripts/plane_landing.gd")
const SkyDive = preload("res://scripts/sky_dive.gd")
const DiveCamera = preload("res://scripts/dive_camera.gd")
const CanopyFigure = preload("res://scripts/canopy_figure.gd")
## The plane left to itself after an eject circles the pilot ORBIT m out
## and ORBIT_OVER m over them, never under ORBIT_CLEAR m over the ground;
## further than ORBIT_FAR it is brought round near.
const ORBIT := 26.0
const ORBIT_OVER := 14.0
const ORBIT_CLEAR := 10.0
const ORBIT_FAR := 500.0
## `--skydive`: the plane starts SKYDIVE_HEIGHT m over the home island,
## SKYDIVE_BACK m short of its middle, flying towards it.
const SKYDIVE_HEIGHT := 110.0
const SKYDIVE_BACK := 50.0
## A fall into the cloud sea with no lower world under it is caught this
## far under the glide's floor.
const DIVE_CATCH := 4.0
const RuinBump = preload("res://scripts/ruin_bump.gd")
## The chase view's field of view at a cruise; the camera widens it with
## speed (GlideCamera `fov`).
const CHASE_FOV := GlideCamera.FOV
## Seconds the camera takes to swoop from the chase down behind the pilot
## on landing, or from the build view on stepping in.
const SWOOP := 0.9
## The right stick's free look, radians a second at full tilt.
const STICK_LOOK := 2.4
## A skim this slow for this long, not diving, lands.
const LAND_SPEED := 10.0
## The islands stand hundreds of metres apart; the view reaches FLY_FAR m
## while gliding.
const FLY_FAR := 3000.0
## Ridge lift: where the wind blows up a slope, the air rises by RIDGE_GAIN
## times the wind's speed times the slope (sampled RIDGE_STEP m either way
## along the wind), up to RIDGE_MAX m/s, fading out by RIDGE_REACH m over the
## ground. Gust fronts lift by GUST_LIFT and push by GUST_PUSH m/s per unit of
## their lean (studies/gust_fronts.gd `lean_at`).
const RIDGE_GAIN := 2.2
const RIDGE_STEP := 1.5
const RIDGE_MAX := 6.5
const RIDGE_REACH := 14.0
const GUST_LIFT := 9.0
const GUST_PUSH := 5.0
const LAND_TIME := 0.3
## F lands on the nearest island this near (m, in the plate plane).
const LANDING_REACH := 160.0

signal entered
signal left

var scene: Node3D
var editor: NativeChunkEditor
var camera: Camera3D
## True while the camera looks through the figure.
var active := false
## The figure, parented to the terrain so it turns with the world.
var figure: Node3D
## Terrain-local position of the figure's feet.
## The feet, in the plate's frame (on an islet, `_perch_feet` in its own).
var _feet := Vector3.ZERO
## The camera's yaw and tilt round the pilot (the scene's orbit's).
var _yaw := 0.0
var _polar := CAM_POLAR
## The run's velocity across the ground, metres a second (the motor's).
var _pace := Vector2.ZERO
var motor := PilotMotor.new()
## The drawn pilot, on the figure.
var body: Node3D
## The look point's height over the frame, the camera's reach, and seconds
## since the mouse or the stick last swung it.
var _cam_y := 0.0
## The look point across the ground (the motor's frame, x and z) and its
## pace, following the feet.
var cam_at := Vector2.ZERO
var _cam_pace := Vector2.ZERO
var _cam_distance := CAM_DISTANCE
var _look_rest := 0.0
var _before := {}
var _returning := 0.0
## The orbit camera's field of view before stepping in.
var _fov_before := 45.0
var _hint_time := 0.0
var _layer: CanvasLayer
var _hint: Label
## Obstacles in the plate plane: [Vector3(x, z, radius)], figure radius
## included, and what they were read from (`_obstacle_key`).
var _obstacles := PackedVector3Array()
## The same props with their heights, for the walk, the ground and the walls.
var solids := SolidProps.new(RADIUS,STEP,HEAD)
var _obstacle_key := []
## Live water depths, read once a frame while walking.
var _depths := PackedFloat32Array()
## Metres walked and seconds stood since the last disturbance.
var _stride := 0.0
var _still := 0.0
var steps: Node
## The puffs at the feet, on the figure; the stick's push this frame (0 to
## 1); skidding last frame.
var puffs: Node3D
## The rings on the water round him.
var ripples: Node3D
var _asked := 0.0
var _skid_was := false
## The glide (scripts/sky_glide.gd), the islands it flies between and the air
## round it; `flying` while it glides.
var glide := SkyGlide.new()
var islands: Node3D
var air: Node3D
## The sky's answer to the glide: the cloud sea and the vapour (scripts/sky_flight.gd).
var sky: Node
## The lower world under the cloud sea (`--below`, scripts/sky_below.gd), or null.
var lower: Node3D = null
var flying := false
var glide_enabled := "--no-glide" not in OS.get_cmdline_user_args()
## Flying the little plane (the default), or the old glider (`--glider`).
var plane := flies_plane(OS.get_cmdline_user_args())
## The plane's landing or takeoff under way (scripts/plane_landing.gd), and
## which; F pressed and waiting for its island to be claimed.
var landing: RefCounted = null
var _taking_off := false
var _landing_wait := false
## The skydive (scripts/sky_dive.gd): the dive under way, while `diving`
## (it is the eye's `glide` then; the plane's own flight is kept in
## `_plane_flight`), its camera and the canopy drawn. After an eject the
## plane flies itself (`drone`, drawn by `glider` without its pilot): it
## circles the pilot, and once they are down on the plate it comes in to
## land near them (`_drone_landing`, scripts/plane_landing.gd) and parks.
var dive: RefCounted = null
var diving := false
var dive_camera := DiveCamera.new()
var canopy: Node3D
var drone: RefCounted = null
var _drone_landing: RefCounted = null
var _plane_flight: RefCounted = null
var _open_asked := false
## The plane parked on the plate (a PlaneFigure under the terrain), where
## its flight position stands (plate XZ) and its heading (plate yaw).
var parked: Node3D = null
var _parked_at := Vector2.ZERO
var _parked_heading := 0.0
## Where the hop out lands (plate frame) and where it leaves from.
var _hop_to := Vector3.INF
var _hop_from := Vector3.ZERO
var _board_asked := false
var _near_plane := false
## Mouse look gathered for the glide's next step, and seconds of skim so far.
var _fly_look := Vector2.ZERO
var _skim_time := 0.0
## The chase camera, the figure drawn gliding, and how close it passes to
## rock, for the vapour off its wingtips.
var chase := GlideCamera.new()
var glider: Node3D
var vapour := GlideVapour.new()
## The landing's swoop into the eyes: seconds left, and the chase pose it
## leaves from.
var _swoop := 0.0
var _swoop_from := {}
## A flap asked for since the last glide step (click, E or the pad's X),
## and the glide's flaps when last heard.
var _flap_asked := false
var _flaps_heard := 0
## Seconds between two lean presses that make a barrel roll.
const DOUBLE_TAP := 0.3
## The plane's barrel roll asked for since the last step (-1 left, 1 right).
var _roll_asked := 0.0
## The last lean pressed (-1 left, 1 right) and when (ms), for a second
## press within DOUBLE_TAP to ask for a barrel roll.
var _tap_dir := 0.0
var _tap_at := -100000
var _far_before := 500.0
## Space held last frame, for its press.
var _jump_was := false
## Perched on an islet (scripts/sky_islets.gd): its record, empty when not;
## the feet in its frame.
var perch := {}
var _perch_feet := Vector3.ZERO
## Tree and rock crowns in the plate plane: (x, z, radius, top), terrain-local.
var _crowns := PackedVector4Array()
## Each island's land middle for F's landing (`_land_middle`), by land.
var _middles := {}
## Footprint profile of a mesh: [y0, band height, radius per band...].
static var _profiles := {}

## Whether a run with these command line arguments flies the plane: yes,
## unless `--glider` asks for the old glider.
static func flies_plane(args: PackedStringArray) -> bool:
	return "--glider" not in args

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	camera = scene.camera
	name = "WandererEye"
	Pad.ensure()
	# Before the scene's own _process (and with photo mode), so the scene
	# reads this frame's pose.
	process_priority = -10
	set_process(false)
	# A new world (`reset_flat`: the flip, a new plain, a regrow) has no
	# figure on it until the next V.
	editor.data.state_restored.connect(_world_restored)
	# The parked plane settles again on land shaped under it.
	editor.data.history_captured.connect(func(_state: Dictionary) -> void: _seat_parked.call_deferred())
	steps = WandererSteps.new()
	add_child(steps)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.visible = false
	add_child(_layer)
	_hint = preload("res://scripts/pad_prompt.gd").new()
	_hint.alternates = PAD_HINTS
	_hint.text = _walk_hint()
	_hint.add_theme_font_size_override("font_size",15)
	_hint.add_theme_color_override("font_color",Color("fbf6ea"))
	_hint.add_theme_color_override("font_shadow_color",Color(0,0,0,0.55))
	_hint.add_theme_constant_override("shadow_offset_y",1)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -56.0
	_hint.offset_bottom = -30.0
	_hint.offset_left = -640.0
	_hint.offset_right = 640.0
	_layer.add_child(_hint)
	if glide_enabled:
		if plane:
			glide = SkyPlane.new()
			_plane_flight = glide
			chase.linger = PLANE_LINGER
		islands = SkyIslands.new()
		islands.setup(scene)
		add_child(islands)
		# A mountain's rock is ridden only where it is no steeper than the
		# glide can ride, and an isle's trees turn it aside (SkyGlide
		# `stone`).
		glide.stone = Callable(islands,"stone")
		# A world loaded before the islands were made left its sky here.
		var places: Variant = scene.get("places")
		if places is Node: islands.load_state(places.sky_state)
		sky = SkyFlight.new()
		add_child(sky)
		sky.setup(scene)
		if SkyBelow.on():
			lower = SkyBelow.new()
			lower.scene = scene
			add_child(lower)
			islands.skip.append(lower)
			lower.attach(islands)
			sky.lower = lower
			glide.floor_y = SkyBelow.FLOOR
			glide.water = SkyBelow.OCEAN
		air = GlideAir.new()
		add_child(air)
		islands.skip.append(air)
		if plane: glider = PlaneFigure.new()
		else: glider = GliderFigure.new()
		glider.visible = false
		add_child(glider)
		islands.skip.append(glider)
		if plane:
			canopy = CanopyFigure.new()
			add_child(canopy)
			islands.skip.append(canopy)
			if skydive_start(OS.get_cmdline_user_args()) != "": _skydive_start.call_deferred(skydive_start(OS.get_cmdline_user_args()))
		# The mountains stand round the plate in the build view too
		# (SkyIslands `_process`): the view reaches them.
		if SkyWorld.ring_on(): camera.far = maxf(camera.far,SkyWorld.VIEW_FAR)

# --- The figure -------------------------------------------------------------------

## Where the pilot stands and faces: drawn (scripts/pilot_figure.gd) while
## on foot and hopping in and out of the plane, hidden while building and
## flying, and remembered for the next V.
func _build_figure() -> void:
	figure = Node3D.new()
	figure.name = "Wanderer"
	figure.visible = false
	editor.terrain.add_child(figure)
	body = PilotFigure.new()
	figure.add_child(body)
	puffs = PilotPuffs.new()
	figure.add_child(puffs)
	ripples = PilotRipples.new()
	figure.add_child(ripples)
	# The motor wades and swims in the plate's live water, and on an islet in
	# a lake it may swim (SkyIslet `swim_depth`).
	motor.water = func(p: Vector2) -> float: return _prop_depth(p) if perch.is_empty() else _perch_depth(p)
	# Walls: the props' trunks, rocks and cabin walls, else the ground's rise.
	motor.wall = _wall
	# The low foliage parts round him and springs back (scripts/pilot_wake.gd).
	var wake := PilotWake.new()
	wake.name = "Wake"
	wake.motor = motor
	figure.add_child(wake)
	if islands != null: islands.skip.append(figure)

func _world_restored(state: Dictionary) -> void:
	# A claimed island's plain is formed under the glide, not a new world.
	if state.is_empty() and not (islands != null and islands.claiming): forget()
	elif has_parked(): _seat_parked.call_deferred()

## The figure is gone, stepped out of first if the eye is in it; V sets a
## new one down.
func forget() -> void:
	if active: leave()
	_drop_drone()
	if has_figure(): figure.queue_free()
	figure = null
	_unpark(false)
	_feet = Vector3.ZERO
	_obstacle_key = []
	_obstacles = PackedVector3Array()
	_depths = PackedFloat32Array()

func has_figure() -> bool:
	return figure != null and is_instance_valid(figure)

## What a local point stands on: a footbridge's deck where there is one
## (scripts/footbridge.gd `deck_at`), else the terrain, or the point's own
## height off the map.
func _ground(local: Vector3) -> float:
	var at := Vector2(local.x,local.z)
	var h: Variant = editor.data.ground_height(at)
	var deck := _deck(at)
	if not deck.is_empty(): return maxf(float(deck.y),float(h) if h != null else -INF)
	return float(h) if h != null else local.y

## The footbridge deck under a plate point, or {}.
func _deck(point: Vector2) -> Dictionary:
	return Footbridge.deck_at(Footbridge.decks(editor.data),point)

func _clamped(local: Vector3) -> Vector3:
	local.x = clampf(local.x,-PLATE_REACH,PLATE_REACH)
	local.z = clampf(local.z,-PLATE_REACH,PLATE_REACH)
	# On an outlined island, the nearest land (a bridge's deck is footing too).
	if not _on_land(Vector2(local.x,local.z)):
		var land := editor.data.nearest_land(Vector2(local.x,local.z),SHORE_INSET)
		if land != Vector2.INF:
			local.x = land.x
			local.z = land.y
	local.y = _ground(local)
	return local

## Set the figure down at a terrain-local point, facing the way the camera
## looks: on the nearest free, shallow spot to it.
func place(local: Vector3) -> void:
	if not has_figure(): _build_figure()
	_read_obstacles(true)
	_read_depths()
	_feet = _clamped(_free_spot(_clamped(local)))
	_yaw = scene.yaw
	motor.reset(_feet,_yaw-_turn())
	_sync_figure()
	_disturb(PLACE_STRENGTH)

## The terrain's own turn; the world turn (scripts/world_turn.gd) turns the
## camera, so this is normally 0.
func _turn() -> float:
	return editor.terrain.global_basis.get_euler().y

## The figure where the motor's feet are, facing its way: in the terrain's
## frame on the plate, an islet's (the world's, never turned) perched.
func _sync_figure() -> void:
	if not has_figure(): return
	# On a ledge, where the motor draws the body (the climb's clip carries it).
	var drawn := motor.origin() if motor.on_ledge() else (_feet if perch.is_empty() else _perch_feet)
	if perch.is_empty():
		figure.position = drawn
		figure.rotation = Vector3(0.0,motor.facing,0.0)
	elif is_instance_valid(perch.node):
		# In the islet's own frame, which an airship's islet may turn
		# (scripts/sky_airship.gd): the pilot goes round with it.
		figure.global_transform = _islets().frame(perch)*Transform3D(Basis(Vector3.UP,motor.facing),drawn)

# --- Obstacles and water ------------------------------------------------------------

## Re-reads the solid props' footprints when the objects or their batches
## have changed (or always, with `force`). Each drawn part of a solid object
## becomes a circle round its origin, as wide as its mesh is between STEP
## and HEAD over the object's ground.
func _read_obstacles(force: bool) -> void:
	var content: Node = editor.content
	if content == null: return
	var batches: Array = content._batches
	var key := [editor.data.objects_revision,batches.size(),_parked_at if has_parked() else null]
	for batch in batches: key.append(batch.get_instance_id())
	if not force and key == _obstacle_key: return
	_obstacle_key = key
	_obstacles = PackedVector3Array()
	_crowns = PackedVector4Array()
	solids.clear()
	# The parked plane: the walker steps round it.
	if has_parked():
		_obstacles.append(Vector3(_parked_at.x,_parked_at.y,PARKED_ROOM+RADIUS))
		var under := _ground(Vector3(_parked_at.x,0.0,_parked_at.y))
		solids.add_column(_parked_at,under-1.0,1000.0,PARKED_ROOM)
	var to_plate: Transform3D = editor.terrain.global_transform.affine_inverse()
	for batch: MultiMeshInstance3D in batches:
		if not is_instance_valid(batch) or batch.multimesh == null or batch.multimesh.mesh == null: continue
		var sources: Array = content._sources.get(batch.get_meta("part"),[])
		for source: Dictionary in sources:
			var item: Variant = source.get("item")
			if item == null or not str(item.asset) in SOLID: continue
			var placed: Variant = content._instance_transform(source)
			if placed == null: continue
			var at: Transform3D = to_plate*batch.global_transform*(placed as Transform3D)
			_add_obstacle(batch.multimesh.mesh,at,item)
			solids.add_mesh(str(item.asset),str(batch.get_meta("part")),batch.multimesh.mesh,at,item.id)
	# The encounter tree is a landmark of its own, not a batch.
	var landmarks: Node = editor.get("landmarks")
	if landmarks == null: return
	for item: Dictionary in editor.data.objects:
		if item.asset != "bigfoot_tree": continue
		var node := landmarks.get_node_or_null("%s_%d" % [item.asset,item.id])
		if node == null: continue
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh == null: continue
			_add_obstacle(mesh.mesh,to_plate*mesh.global_transform,item)
			solids.add_mesh(str(item.asset),str(mesh.name),mesh.mesh,to_plate*mesh.global_transform,item.id)

func _add_obstacle(mesh: Mesh, placed: Transform3D, item: Dictionary) -> void:
	var profile := _profile(mesh)
	if profile.size() < 3: return
	var ground := _ground(Vector3(float(item.x),placed.origin.y,float(item.z)))
	var lift: float = placed.basis.y.y
	var scale := placed.basis.get_scale()
	var wide := maxf(scale.x,scale.z)
	var reach := 0.0
	for band in range(profile.size()-2):
		var low := placed.origin.y+lift*(profile[0]+profile[1]*band)
		var high := low+lift*profile[1]
		if high < ground+STEP or low > ground+HEAD: continue
		reach = maxf(reach,profile[band+2]*wide)
	if reach > 0.0: _obstacles.append(Vector3(placed.origin.x,placed.origin.z,reach+RADIUS))
	# The whole crown, for the glide to lift over.
	var crown := 0.0
	for band in range(profile.size()-2): crown = maxf(crown,profile[band+2]*wide)
	var top := placed.origin.y+lift*(profile[0]+profile[1]*(profile.size()-2))
	if crown > 0.0 and top > ground+STEP: _crowns.append(Vector4(placed.origin.x,placed.origin.z,crown,top))

## A mesh's footprint by height: [lowest y, band height, then the widest
## any vertex in each band stands from the mesh's vertical axis]. Built once.
static func _profile(mesh: Mesh) -> PackedFloat32Array:
	if _profiles.has(mesh): return _profiles[mesh]
	var box := mesh.get_aabb()
	var profile := PackedFloat32Array([box.position.y,maxf(box.size.y,0.001)/BANDS])
	profile.resize(BANDS+2)
	for s in range(mesh.get_surface_count()):
		var vertices: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in vertices:
			var band := clampi(int((v.y-profile[0])/profile[1]),0,BANDS-1)
			profile[band+2] = maxf(profile[band+2],Vector2(v.x,v.z).length())
	_profiles[mesh] = profile
	return profile

func _read_depths() -> void:
	var flow: RefCounted = editor.get("flow")
	_depths = flow.depths() if flow != null and flow.ready else PackedFloat32Array()

## Live water depth at a plate point, 0 without live water or on a bridge.
func _depth(point: Vector2) -> float:
	if _depths.is_empty() or not _deck(point).is_empty(): return 0.0
	var at: int = editor.flow.cell_at(point)
	return _depths[at] if at >= 0 and at < _depths.size() else 0.0

func _wet(point: Vector2) -> bool:
	return _depth(point) > WADE

## `point` pushed out of every obstacle it stands in, PASSES times over.
func _pushed_out(point: Vector2) -> Vector2:
	for i in range(PASSES):
		var moved := false
		for o in _obstacles:
			var away := point-Vector2(o.x,o.y)
			var gap := away.length()
			if gap >= o.z: continue
			point = Vector2(o.x,o.y)+(away/gap if gap > 0.0001 else Vector2.RIGHT)*o.z
			moved = true
		if not moved: break
	return point

func _blocked(point: Vector2) -> bool:
	for o in _obstacles:
		if point.distance_squared_to(Vector2(o.x,o.y)) < o.z*o.z-0.0001: return true
	return _wet(point)

## One step of the walk: into the props, then pushed back out along their
## normals (scripts/solid_props.gd `push`), which keeps the part of the step
## along them, so the figure slides round a trunk or along a cabin's wall.
## Walked square into a trunk it is turned a little aside, so it never stops
## dead. A prop whose top is within a step of the feet does not push: it is
## ground (`_motor_ground`), stepped or landed on. Deep water is no wall: he
## swims it.
func _walk(feet: Vector3, step: Vector2) -> Vector3:
	if step.length_squared() < 1e-10: return feet
	var from := Vector2(feet.x,feet.z)
	var to := solids.push(feet,step,motor.grounded)
	# A bridge with hand rails keeps the walker on it; one without lets them
	# step off its side, where the water allows.
	to = RopeBridge.hold(editor.terrain,feet,to)
	var deck := _deck(from)
	if not deck.is_empty() and deck.deck.rails and deck.deck.get("sim") == null and _deck(to).is_empty(): to = Footbridge.keep_on(deck.deck,to,RADIUS*0.5)
	return Vector3(to.x,feet.y,to.y)

## The free, shallow spot nearest `local` (on the plate), or `local` itself
## if nothing is free within FREE_REACH.
func _free_spot(local: Vector3) -> Vector3:
	var at := Vector2(local.x,local.z)
	if not _blocked(at) and _pushed_out(at) == at: return local
	# The push-out first: the nearest way out of the one it stands in.
	var out := _pushed_out(at)
	if _free(out): return Vector3(out.x,local.y,out.y)
	var ring := FREE_STEP
	while ring <= FREE_REACH:
		var best := Vector2.INF
		var count := maxi(8,int(TAU*ring/FREE_STEP))
		for i in range(count):
			var angle := TAU*i/count
			var p := at+Vector2(cos(angle),sin(angle))*ring
			if _free(p) and (best == Vector2.INF or p.distance_squared_to(at) < best.distance_squared_to(at)): best = p
		if best != Vector2.INF: return Vector3(best.x,local.y,best.y)
		ring += FREE_STEP
	return local

func _free(p: Vector2) -> bool:
	return absf(p.x) <= PLATE_REACH and absf(p.y) <= PLATE_REACH and _on_land(p) and not _blocked(p)

## Whether the island holds plate point `p` as ground to stand on: its land
## (the whole square if it has no outline), or a footbridge deck.
func _on_land(p: Vector2) -> bool:
	return editor.data.has_land(p) or not _deck(p).is_empty()

## Whether a walk to plate point `p` has gone off the island: past the
## square's reach, or past the shore of an outlined one.
func _off_plate(p: Vector2) -> bool:
	return absf(p.x) > PLATE_REACH or absf(p.y) > PLATE_REACH or not _on_land(p)

# --- Stepping in and out ------------------------------------------------------------

func can_enter() -> bool:
	if active or scene == null or not scene.get("shell_ready") or not scene._has_world: return false
	if scene._menu.visible or scene.crafting or editor.forming: return false
	var photo: Node = scene.get("photo")
	if photo != null and photo.active: return false
	var watch: Node = scene.get("watch")
	if watch != null and watch.active: return false
	var places: Node = scene.get("places")
	return places == null or not places.busy

## V from the world: set the figure down under the pointer (if the land is
## there) and look through it.
func summon(pointer: Vector2) -> void:
	if not can_enter(): return
	var hit: Variant = editor.pick(pointer)
	if hit != null: place(hit)
	elif not has_figure(): place(editor.terrain.to_local(scene.target))
	enter()

func enter() -> void:
	if not can_enter() or not has_figure(): return
	_before = {"looking":scene.looking,"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance,"auto":scene._auto_orbit}
	if _returning <= 0.0: _fov_before = camera.fov
	if not scene.looking:
		scene._set_looking_state(true)
		editor.set_active(false)
		scene._sync_creation_ui()
	active = true
	_returning = 0.0
	# The camera swoops down from the build view to behind the pilot.
	_swoop = SWOOP
	_swoop_from = {"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance}
	_pace = Vector2.ZERO
	# The mountain ring's skyline is worked out from here, so it stands
	# whole by the time the glide opens (scripts/sky_ring.gd).
	if islands != null: islands.warm_ring()
	_yaw = figure.rotation.y+_turn()
	_polar = CAM_POLAR
	_read_obstacles(true)
	_read_depths()
	_feet = _clamped(_free_spot(_clamped(_feet)))
	motor.reset(_feet,figure.rotation.y)
	_stand_camera()
	scene._orbiting = false
	scene._panning = false
	scene._auto_orbit = false
	figure.visible = true
	body.settle()
	_sync_figure()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_layer.visible = true
	_hint.modulate.a = 1.0
	_hint_time = 0.0
	set_process(true)
	entered.emit()

func leave() -> void:
	if not active: return
	# The orbit takes over where the camera is.
	var eye := camera.global_position
	# Out of a dive: the canopy packed, the plane parked if it can be.
	if diving:
		_end_dive()
		if canopy != null: canopy.reset()
	_settle_drone()
	if flying:
		var at := glide.position
		# On the ground, mid landing or takeoff, the plane stays parked
		# where it stands and the walker steps out beside it.
		var grounded: bool = landing != null and landing.on_ground()
		if grounded: _park_here()
		_end_flight()
		if grounded: _read_obstacles(true)
		_feet = _clamped(_free_spot(_clamped(editor.terrain.to_local(at))))
	_feet = _clamped(_feet)
	motor.reset(_feet,motor.facing)
	active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layer.visible = false
	figure.visible = false
	_sync_figure()
	if not bool(_before.looking): _brush_back()
	scene._auto_orbit = bool(_before.auto)
	# Re-express the eye as an orbit around a point ahead of it, then glide home.
	var reach := 6.0
	scene.target = eye-_offset(scene.yaw,scene.polar)*reach
	scene.distance = reach
	_returning = RETURN
	left.emit()

## The brush picked back up on leaving. The scene refuses it while the places
## are busy, as they are all through a claim (SkyIslands `claim`), and
## stepping out of a plane mid-claim would leave the build view with no brush
## and the editor off: the hand grips the land and nothing shapes it. So it
## waits for the places, unless the walk was taken up again meanwhile.
func _brush_back() -> void:
	var places: Node = scene.get("places")
	while places != null and is_instance_valid(places) and places.busy:
		await get_tree().process_frame
		if active: return
	scene.select_brush(scene.brush)

static func _offset(yaw: float, polar: float) -> Vector3:
	return Vector3(sin(polar)*sin(yaw),cos(polar),sin(polar)*cos(yaw))

## Where the pilot's eyes are: where a flight from here leaves from.
func _eye_global() -> Vector3:
	return editor.terrain.to_global(_feet+Vector3.UP*EYE_HEIGHT)

# --- Each frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	# A canopy landed on folds down whatever comes next.
	if canopy != null and canopy.collapsing(): canopy.update(delta,dive)
	if active: _advance_eye(delta)
	elif _returning > 0.0: _advance_return(delta)
	else: set_process(false)

func _ease(rate: float, delta: float) -> float:
	return 1.0-exp(-delta/rate)

func _advance_eye(delta: float) -> void:
	if not has_figure() or scene._menu.visible:
		leave()
		return
	if flying:
		_advance_flight(delta)
		return
	_fly_drone(delta)
	_read_obstacles(false)
	_read_depths()
	var top := _top()
	var jump := Input.is_action_pressed(&"walk_jump")
	var pressed := jump and not _jump_was
	_jump_was = jump
	# By the parked plane, Space climbs in rather than jumping.
	if pressed and motor.grounded and by_plane():
		_board()
		return
	var was := _feet
	var want := _want(_yaw-_turn(),delta)
	_asked = want.length()
	motor.crouch = Input.is_action_pressed(&"walk_crouch")
	motor.twirl = Input.is_action_pressed(&"walk_twirl")
	var events := motor.step(delta,want,top,jump,_motor_ground,_walk,_lip)
	if glide_enabled and events.has("fly"):
		_launch(motor.speed(),false)
		return
	if glide_enabled and not motor.on_ledge() and _off_plate(Vector2(motor.feet.x,motor.feet.z)):
		_launch(motor.speed())
		return
	_ledge_events(events)
	if not glide_enabled and not motor.on_ledge():
		var held := _clamped(motor.feet)
		motor.feet = Vector3(held.x,maxf(motor.feet.y,held.y),held.z)
	_feet = motor.feet
	_pace = Vector2(motor.velocity.x,motor.velocity.z)
	var moved := Vector2(_feet.x-was.x,_feet.z-was.z).length() if motor.grounded else 0.0
	_notice_step(moved,delta)
	_sync_figure()
	_motor_events(events)
	var drawn: Dictionary = body.drive(motor,delta)
	_tread(editor.terrain,events,drawn)
	_feet = motor.feet
	_body_events(drawn,delta)
	_water_events(events,drawn,delta)
	_frame_walker(delta,editor.terrain.global_transform,_turn(),func(p: Vector3) -> float:
		var h: Variant = editor.data.ground_height(Vector2(p.x,p.z))
		return float(h) if h != null else -INF)
	camera.fov = lerpf(camera.fov,FOV,_ease(EASE_FOV,delta))
	_hint_time += delta
	_hint_plane()
	_hint.modulate.a = clampf(1.0-(_hint_time-4.0)/1.5,0.0,1.0)

## The run's ask this frame, the way in the motor's frame (the camera's
## yaw `heading` in it): WASD, the arrows or the left stick, as far as it is
## pushed; the right stick swings the camera as the mouse does.
func _want(heading: float, delta: float) -> Vector2:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var look := Pad.curve(Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down"),1.6)
	if look != Vector2.ZERO:
		_yaw -= look.x*STICK_WALK_LOOK.x*delta
		_polar = clampf(_polar-look.y*STICK_WALK_LOOK.y*delta,POLAR.x,_polar_most())
		_look_rest = 0.0
	var forward := PilotMotor.forward(heading)
	var right := Vector2(-forward.y,forward.x)
	return right*stick.x+forward*-stick.y

## The pace a full stick asks: a run, always (there is no sprint); a light
## touch on the stick walks.
func _top() -> float:
	return RUN

## The ground under a plate point for the motor: a bridge's deck or the
## terrain, or level with the feet off the map.
func _ground_at(p: Vector2) -> float:
	return _ground(Vector3(p.x,motor.feet.y,p.y))

## The ground for the motor: as `_ground_at`, but none (-INF) off the
## island's land, so its rim is an edge to fall from or catch; and over a
## rock, log, stump, boulder or cabin its top (scripts/solid_props.gd
## `top`), so it is landed and stood on, stepped up onto when low, and its
## lip is a ledge to catch as the rim's is.
func _motor_ground(p: Vector2) -> float:
	var on := solids.top(p)
	if not _on_land(p): return on
	return maxf(_ground_at(p),on)

## The way off a wall for the motor (scripts/pilot_motor.gd `wall`): a
## prop's (scripts/solid_props.gd `wall`), else the ground's rise; perched
## on an islet, its ground's.
func _wall(feet: Vector3, way: Vector2, reach: float) -> Vector2:
	if not perch.is_empty(): return PilotMotor.heightfield_wall(func(p: Vector2) -> float: return _perch_ground(p),feet,way,reach)
	var off := solids.wall(feet,way,reach)
	return off if off != Vector2.ZERO else PilotMotor.heightfield_wall(_motor_ground,feet,way,reach)

## Live water depth over what is stood on: over a prop's top, less by its
## height over the ground.
func _prop_depth(p: Vector2) -> float:
	var deep := _depth(p)
	if deep <= 0.0: return deep
	var on := solids.top(p)
	return deep if not is_finite(on) else maxf(0.0,_ground_at(p)+deep-on)

## The lip near plate point `near` for the motor (scripts/pilot_ledge.gd):
## the island's rim, or a step too steep to walk.
func _lip(near: Vector2, y: float) -> Dictionary:
	return PilotLedge.find(_motor_ground,near,y)

## On a ledge: a grip and a climb sound as soft steps; hanging, the hint
## says how to shimmy, climb and let go, and back on top the walk's again.
func _ledge_events(events: Dictionary) -> void:
	if events.has("grabbed") or events.has("climbed"): steps.step(_surface(),0.4)
	if events.has("grabbed") and events.grabbed == "air": Pad.pulse(0.15,0.1,0.06)
	if events.has("grabbed") or events.has("hung"):
		if _hint.text != LEDGE_HINT:
			_hint.text = LEDGE_HINT
			_hint_time = 0.0
			_hint.modulate.a = 1.0
	if (events.has("climbed") or events.has("let_go")) and _hint.text == LEDGE_HINT:
		_hint.text = _walk_hint() if perch.is_empty() else (PERCH_HINT if plane else GLIDER_PERCH_HINT)

## The motor's jumps and landings: their sounds and puffs (the pump and the
## side flip push off in a ring of them, the long jump and the slide jump
## back off the heels, a wall kick off the wall; a landing hard enough comes
## down in one), and the figure's squash; taking hold of a wall slaps it,
## sliding down it scrapes and sprays; a twirl whirls a swirl of wisps round
## him; a surf down a slope scrapes as it starts and sprays the while.
func _motor_events(events: Dictionary) -> void:
	if events.has("jumped"):
		steps.step(_surface(),0.3+0.15*float(events.jumped))
		var at := _puff_at(figure.global_position)
		var way := _world_way(motor.velocity)
		if events.has("wall_jump"): puffs.burst(at+Vector3.UP*0.5-way*0.3,_surface(),0.35,way)
		elif events.has("long") or events.has("slide_jump"): puffs.burst(at,_surface(),0.3,-way)
		elif int(events.jumped) > 1 or events.has("side_flip"): puffs.burst(at,_surface(),0.45)
	if events.has("twirl"):
		steps.step(_surface(),0.25)
		puffs.swirl(figure.global_position+figure.global_transform.basis.y*0.55,1.0,0.8)
	if events.get("slide",false): steps.slide(_surface(),clampf(motor.speed()/RUN,0.4,1.0))
	if motor.move == "slide" and motor.speed() > 1.0:
		var travel := _world_way(motor.velocity)
		puffs.spray(_puff_at(figure.global_position+travel*0.2),travel,_surface(),clampf(motor.speed()/PilotMotor.SPRAY_FULL,0.3,1.0),get_process_delta_time())
	if events.get("wall",false):
		steps.step(_surface(),0.35)
		steps.slide(_surface(),0.3)
	if motor.move == "wall":
		var off := figure.global_transform.basis*Vector3(0.0,0.0,0.25)
		puffs.spray(figure.global_position-off+Vector3.UP*0.15,Vector3.UP,_surface(),0.35,get_process_delta_time())
	if events.has("landed"):
		var hard := float(events.landed)
		steps.step(_surface(),clampf(hard/8.0,0.3,1.0))
		body.land(hard)
		if hard > PUFF_LAND: puffs.burst(_puff_at(figure.global_position),_surface(),(hard-PUFF_LAND)/PUFF_LAND_FULL)
		if hard > 6.0: Pad.pulse(0.2,0.15,0.08)

## What the drawn body did (scripts/pilot_figure.gd `drive`): each boot's
## touchdown sounds a step and, at a run, kicks a puff back off its heel;
## setting off hard pushes a few back, and whipping round out of a skid a
## few more. Skidding, it scrapes once and sprays the ground ahead the while.
func _body_events(out: Dictionary, delta: float) -> void:
	var speed: float = motor.speed()
	var effort := clampf((speed-WALK)/(RUN-WALK),0.0,1.0)
	if out.has("footfall"):
		var side := int(out.footfall)
		steps.step(_surface(),effort,side)
		puffs.footfall(_puff_at(body.boot(side)),-_world_way(motor.velocity),_surface(),effort)
	if out.has("set_off") and _asked >= SET_OFF: puffs.burst(_puff_at(figure.global_position),_surface(),0.0,-_world_way(Vector3.ZERO))
	if out.has("turned"): puffs.burst(_puff_at(figure.global_position),_surface(),0.1,-_world_way(Vector3.ZERO))
	if motor.skidding:
		var travel := _world_way(motor.velocity)
		if not _skid_was: steps.slide(_surface(),speed/RUN)
		puffs.spray(_puff_at(figure.global_position+travel*0.15),travel,_surface(),clampf(speed/RUN,0.3,1.0),delta)
	_skid_was = motor.skidding

## The water round him: going in deep enough to swim, a splash (puffs of
## drops, rings, a wade's sound) as hard as he came in, and hopping out
## another; wading on, rings round the legs and one at each wet footfall;
## swimming, a ring let go at the chest every few strokes' worth (a V behind
## him), and each stroke throws a few drops and a ring off the mitt. Out of
## it, the drips off him (scripts/pilot_figure.gd `soak`) fall.
func _water_events(events: Dictionary, drawn: Dictionary, delta: float) -> void:
	for at in body.soak(motor,delta): puffs.drip(at,at.y-figure.global_position.y)
	if not is_finite(motor.surface):
		ripples.dry()
		return
	var top := figure.global_position+Vector3.UP*(motor.surface-motor.feet.y)
	if events.has("swam"):
		var hard := clampf(float(events.swam)/8.0,0.3,1.0)
		ripples.splash(top,hard)
		puffs.burst(top,"water",hard)
		steps.step("water",hard)
	if events.has("hopped"):
		ripples.splash(top,0.4)
		puffs.burst(top,"water",0.3)
	var ahead := _world_way(Vector3.ZERO)
	if motor.swimming:
		ripples.trail(top+ahead*0.15,true,0.16)
	elif motor.grounded and motor.wade > 0.04 and motor.speed() > 0.3:
		ripples.trail(top,false,0.18)
	else:
		ripples.dry()
	if drawn.has("footfall") and motor.wade > 0.04:
		var boot: Vector3 = body.boot(int(drawn.footfall))
		ripples.ring(Vector3(boot.x,top.y,boot.z),0.07,0.25)
	if drawn.has("stroke"):
		var mitt: Vector3 = body.mitt(int(drawn.stroke))
		var on := Vector3(mitt.x,top.y,mitt.z)
		var paddling := motor.speed() > 0.3
		ripples.ring(on,0.06,0.3 if paddling else 0.15)
		puffs.footfall(on,-ahead,"water",0.5 if paddling else 0.2)
		steps.step("water",0.2 if paddling else 0.1,int(drawn.stroke))

## A way in the motor's frame (`way`, its x and z) as a flat unit way in the
## world; none (too short) is the way the figure faces.
func _world_way(way: Vector3) -> Vector3:
	var flat := Vector3(way.x,0.0,way.z)
	if flat.length_squared() < 0.01: flat = Vector3(PilotMotor.forward(motor.facing).x,0.0,PilotMotor.forward(motor.facing).y)
	if perch.is_empty(): flat = editor.terrain.global_basis*flat
	else: flat = Basis(Vector3.UP,SkyIslets.yaw_of(perch))*flat
	flat.y = 0.0
	return flat.normalized()

## A world point at the feet, lifted to the water's top where it wades, for
## the puffs (a wade's droplets fly off the water).
func _puff_at(at: Vector3) -> Vector3:
	if perch.is_empty(): at.y += _depth(Vector2(_feet.x,_feet.z))
	else: at.y += _perch_depth(Vector2(_perch_feet.x,_perch_feet.z))
	return at

## Stood where the motor is: the look point at the pilot, the camera back
## at its reach.
func _stand_camera() -> void:
	_cam_y = motor.feet.y+CAM_HEIGHT
	cam_at = Vector2(motor.feet.x,motor.feet.z)
	_cam_pace = Vector2.ZERO
	_cam_distance = CAM_DISTANCE
	_look_rest = 0.0

## The camera behind the pilot, written into the scene's orbit: round a
## point over the feet that follows them across the ground on a spring
## (CAM_FOLLOW) and up and down (lagging in a jump), swung round behind the
## run when left alone, and drawn in where the
## ground behind would hide them. `frame` places the motor's frame in the
## world, `turn` is its turn about up, and `ground` gives the ground's
## height in the frame under a frame point (-INF for none).
func _frame_walker(delta: float, frame: Transform3D, turn: float, ground: Callable) -> void:
	var goal := motor.feet.y+CAM_HEIGHT
	_cam_y = lerpf(_cam_y,goal,_ease(EASE_CAM_Y if motor.grounded else EASE_CAM_Y_AIR,delta))
	# Never so far behind a fall that the pilot drops out of view.
	_cam_y = clampf(_cam_y,goal-1.2,goal+1.2)
	_look_rest += delta
	var speed: float = motor.speed()
	if speed > 0.3 and _look_rest > LOOK_REST:
		var behind: float = motor.facing+turn
		var at_camera := maxf(0.0,-PilotMotor.forward(_yaw).dot(PilotMotor.forward(behind)))
		_yaw = lerp_angle(_yaw,behind,_ease(FOLLOW,delta)*clampf(speed/RUN,0.0,1.0)*(1.0-at_camera))
	var feet := Vector2(motor.feet.x,motor.feet.z)
	var w := TAU*CAM_FOLLOW
	var left := minf(delta,0.25)
	while left > 0.0:
		var dt := minf(left,1.0/60.0)
		_cam_pace += (w*w*(feet-cam_at)-2.0*w*_cam_pace)*dt
		cam_at += _cam_pace*dt
		left -= dt
	if cam_at.distance_to(feet) > CAM_LAG: cam_at = feet+(cam_at-feet).normalized()*CAM_LAG
	var pivot := Vector3(cam_at.x,_cam_y,cam_at.y)
	# Drawn in until the camera is clear of the ground behind.
	var out := frame.basis.inverse()*_offset(_yaw,_polar)
	var reach := CAM_DISTANCE
	while reach > CAM_NEAREST:
		var at := pivot+out*reach
		if at.y > float(ground.call(at))+CAM_CLEAR: break
		reach -= 0.2
	_cam_distance = reach if reach < _cam_distance else lerpf(_cam_distance,reach,_ease(EASE_CAM_OUT,delta))
	scene.target = frame*pivot
	scene.yaw = _yaw
	scene.polar = _polar
	scene.distance = _cam_distance
	_swoop_in(delta)
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO

## Just landed from the chase: the camera swoops from where it was down
## into the eyes.
func _swoop_in(delta: float) -> void:
	if _swoop <= 0.0: return
	_swoop = maxf(0.0,_swoop-delta)
	var k := smoothstep(0.0,1.0,1.0-_swoop/SWOOP)
	scene.target = (_swoop_from.target as Vector3).lerp(scene.target,k)
	scene.yaw = lerp_angle(float(_swoop_from.yaw),scene.yaw,k)
	scene.polar = lerpf(float(_swoop_from.polar),scene.polar,k)
	scene.distance = lerpf(float(_swoop_from.distance),scene.distance,k)

# --- The glide --------------------------------------------------------------------

## Off the edge: the plate is copied out into the sky and the glide takes the eye.
## Off an islet the sky is already out, and the glide leaves from its top.
func _launch(pace: float, drop := true, start := Vector3.INF, towards := 0.0) -> void:
	# Out of a dive, or with the plane flying itself, it is the plane again
	# (there is only the one).
	if diving: _end_dive()
	_drop_drone()
	var from := _eye_global()
	var perched := not perch.is_empty()
	var perch_turn := 0.0
	if perched:
		from = _perch_eye_global()
		perch_turn = SkyIslets.yaw_of(perch)
		_unperch()
	# There is only the one plane: flying from anywhere but it brings it along.
	if start == Vector3.INF: _unpark(true)
	flying = true
	_fly_look = Vector2.ZERO
	_skim_time = 0.0
	if has_figure(): figure.visible = false
	# The sky stays as it was between glides.
	if not islands.built(): islands.build()
	if not perched: _far_before = camera.far
	camera.far = SkyWorld.VIEW_FAR if SkyWorld.ring_on() else FLY_FAR
	islands.show_air(true)
	if start != Vector3.INF:
		glide.launch(start,towards,pace,drop)
	else:
		# Off the way the pilot faces, level, a jump lifting the nose.
		var way: float = motor.facing+(perch_turn if perched else _turn())
		glide.launch(from,way,pace,drop)
		glide.pitch = clampf(motor.velocity.y*0.06,-0.3,0.3)
	_flap_asked = false
	_flaps_heard = 0
	_roll_asked = 0.0
	# The camera pulls back out of the eyes to chase.
	chase.reset(glide,from,camera.fov)
	vapour.reset()
	glider.visible = not chase.first_person
	glider.reset(glide)
	_swoop = 0.0
	if not perched:
		air.start()
		sky.start(glide.position)
	_hint.text = PLANE_HINT if plane else FLY_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0
	steps.step(_surface(),1.0)

func _end_flight() -> void:
	_unperch()
	flying = false
	landing = null
	_taking_off = false
	_landing_wait = false
	chase.cine = Vector3.ZERO
	scene.camera_roll = 0.0
	glider.visible = false
	if glider.has_method("show_pilot"): glider.show_pilot(true)
	camera.far = _far_before
	islands.show_air(false)
	sky.stop()
	air.stop()
	_hint.text = _walk_hint()

## The glide's input this frame: keys, the pad and the mouse, through
## scripts/pad.gd's actions.
func _fly_input() -> Dictionary:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var input := {
		"turn":stick.x,
		"pitch":stick.y,
		"rise":Input.get_action_strength(&"glide_rise"),
		"dive":Input.get_action_strength(&"glide_dive"),
		"look":_fly_look,
	}
	_fly_look = Vector2.ZERO
	input["flap"] = _flap_asked
	_flap_asked = false
	# The right stick looks round the glider.
	var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	var stick_held := right != Vector2.ZERO
	if stick_held: chase.turn(Vector2(-right.x,-right.y)*STICK_LOOK*get_process_delta_time())
	chase.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or stick_held
	if plane: _plane_input(input)
	return input

## The plane's own input over the glide's: Space or the pad's right trigger
## (or A) boosts and Shift or its left trigger brakes, in place of Rise and
## the dive; Q and E or the pad's shoulders held tip it on a knife edge,
## and pressed twice quick (or a click) ask for a barrel roll.
func _plane_input(input: Dictionary) -> void:
	input["boost"] = Input.get_action_strength(&"fly_boost")
	input["brake"] = Input.get_action_strength(&"fly_brake")
	input["rise"] = 0.0
	input["dive"] = 0.0
	input["flap"] = false
	var keys := (1.0 if Input.is_key_pressed(KEY_E) else 0.0)-(1.0 if Input.is_key_pressed(KEY_Q) else 0.0)
	input["lean"] = clampf(keys+Input.get_action_strength(&"fly_lean_right")-Input.get_action_strength(&"fly_lean_left"),-1.0,1.0)
	input["roll"] = _roll_asked
	if _roll_asked != 0.0: Pad.pulse(0.3,0.1,0.12)
	_roll_asked = 0.0

func _advance_flight(delta: float) -> void:
	if diving:
		_advance_dive(delta)
		return
	if not perch.is_empty():
		_advance_perch(delta)
		return
	if landing != null:
		_advance_sequence(delta)
		return
	var input := _fly_input()
	_read_obstacles(false)
	if glide.approach: glide.approach_target = _landing_spot()
	if _landing_wait and not below(): _wait_to_land(delta,input)
	var was: Vector3 = glide.position
	glide.step(delta,input,_fly_ground,_fly_air)
	# The ruins' stone (the Sundered hall, scripts/ruin_bump.gd): bump and
	# recover, never a crash.
	if plane and not below() and islands is Node3D: RuinBump.bump((islands as Node3D).get_world_3d().direct_space_state,glide,was,(islands as Node3D).global_transform)
	# The pierced isles' rock and ruins (scripts/sky_pierced.gd): bump and
	# recover.
	if not below() and islands.pierced != null and islands.pierced.bump(glide,islands.global_transform): Pad.pulse(0.5,0.2,0.12)
	RopeBridge.flown_by(islands.global_transform*glide.position,glide.velocity)
	# Tokens the plane flies through (scripts/sky_collectibles.gd).
	if islands.collectibles != null: islands.collectibles.touch_plane(islands.global_transform*glide.position)
	# Into another island's footprint, it becomes the plate (not from under
	# the cloud sea).
	if not islands.claiming and not below():
		var under: int = islands.copy_under(glide.position)
		if under >= 0: _claim(under)
	sky.advance(delta,glide.position,islands.in_cloud(glide.position,scene._motion_time))
	# Wandered off or fallen into the sea, an island turns up.
	islands.advance(delta,glide.position,glide.heading,sky.flight.w)
	vapour.step(delta,glide,_fly_ground)
	islands.wake(glide.position,glide.velocity,delta)
	air.advance(delta,glide.velocity,glide.hang,float(input.dive),vapour.near,islands.cloud_body(camera.global_position))
	if plane: air.engine(glide.speed,(glide as SkyPlane).throttle)
	if glide.flaps != _flaps_heard:
		_flaps_heard = glide.flaps
		air.flap()
	chase.step(delta,glide,float(input.dive),_solid)
	_write_chase()
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	camera.fov = chase.fov
	_hint_time += delta
	_hint.modulate.a = clampf(1.0-(_hint_time-6.0)/1.5,0.0,1.0)
	# Touching down slowly anywhere on the plate lands; on an islet's ground
	# (not its crowns or spire) it perches.
	# Under the cloud (--below) there is no plate, only the archipelago's
	# islands, perched on as islets are.
	var on_plate: bool = not below() and islands._height(glide.position) != null
	var islet: Dictionary = {} if on_plate else _islets().islet_at(glide.position)
	var on_islet := not islet.is_empty() and _islet_ground_near(islet,glide.position)
	var landable: bool = glide.speed < LAND_SPEED and float(input.dive) < 0.5 and (on_plate or on_islet)
	glider.update(delta,glide,float(input.dive),_fly_ground,landable,vapour.near,vapour.side)
	_skim_time = _skim_time+delta if glide.skimming and landable else 0.0
	if _skim_time >= LAND_TIME:
		if on_plate and plane: _roll_out()
		elif on_plate: _land()
		else: _perch(islet)

## Where F comes in to land: the middle of the nearest island's land within
## LANDING_REACH, or INF. An island's land need not sit in the middle of its
## plate, nor hold its own middle (scripts/island_frame.gd `middle`).
func _landing_spot() -> Vector3:
	if below(): return lower.landing_spot(glide.position,LANDING_REACH)
	var best := Vector3.INF
	var nearest := LANDING_REACH
	var middles: Array[Vector3] = [editor.terrain.global_position+_land_middle(editor.data)]
	for i in range(islands.offsets.size()): middles.append(editor.terrain.global_position+islands.offsets[i]+Vector3.DOWN*islands.sunk(i)+_land_middle(islands.lands[i]))
	for m in middles:
		var d := Vector2(m.x-glide.position.x,m.z-glide.position.z).length()
		if d < nearest:
			nearest = d
			best = m
	return best

## The offset of `land`'s middle from its plate's, level; none for a land
## still baking. Kept per land and outline: a ring search is not per frame.
func _land_middle(land: NativeTerrainData) -> Vector3:
	if land == null: return Vector3.ZERO
	var kept: Array = _middles.get(land.get_instance_id(),[])
	var bounds := land.land_rect()
	if kept.is_empty() or kept[0] != bounds:
		var at := IslandFrame.middle(land)
		kept = [bounds,Vector3(at.x,0.0,at.y)]
		if _middles.size() > 32: _middles.clear()
		_middles[land.get_instance_id()] = kept
	return kept[1]

## Claims an island (SkyIslands `claim`); once the plate is its land, the
## world has shifted, and everything that flies shifts with it.
func _claim(index: int) -> void:
	var shift: Vector3 = await islands.claim(index)
	if not flying or shift == Vector3.ZERO: return
	glide.position += shift
	if drone != null and drone != glide: drone.position += shift
	sky.move(shift)
	glider.shift(shift)
	chase.eye += shift
	chase.look += shift

## The chase camera's pose, written into the scene's orbit.
func _write_chase() -> void:
	var out := chase.eye-chase.look
	var reach := maxf(out.length(),0.01)
	var dir := out/reach
	scene.target = chase.look
	scene.distance = reach
	scene.yaw = atan2(dir.x,dir.z)
	scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.05,PI-0.05)
	scene.camera_roll = chase.roll

## True inside an island's rock or ground, for the camera to keep out of,
## or under the lower world's ocean.
func _solid(point: Vector3) -> bool:
	if lower != null and point.y < SkyBelow.OCEAN+0.3: return true
	if not below() and islands.pierced != null and islands.pierced.solid(point): return true
	var body: Variant = _fly_ground(point)
	if body == null: return false
	var b := body as Vector2
	return point.y < b.x+0.3 and point.y > b.y-0.3

## What the glide stands on: the islands as solids, Vector2(top, underside)
## (SkyIslands `body`), and over the plate the crowns of its trees and rocks.
func _fly_ground(point: Vector3) -> Variant:
	# Under the cloud only the lower world is solid.
	if below(): return lower.body(point)
	var body: Variant = islands.body(point)
	if body == null or islands._height(point) == null: return body
	var local := editor.terrain.to_local(point)
	var at := Vector2(local.x,local.z)
	var top: float = (body as Vector2).x
	for c in _crowns:
		if at.distance_squared_to(Vector2(c.x,c.y)) < c.z*c.z:
			top = maxf(top,editor.terrain.to_global(Vector3(c.x,c.w,c.y)).y)
	return Vector2(top,(body as Vector2).y)

## The air the glide flies in: the sky's currents, and over the island the
## breeze rising up its slopes and the gust fronts rolling across it.
func _fly_air(point: Vector3) -> Dictionary:
	var air: Dictionary = islands.air(point)
	var atmosphere: Node = scene.get("_atmosphere")
	if atmosphere == null: return air
	var angle: float = atmosphere._air_angle
	var way := Vector2(cos(angle),sin(angle))
	var breeze: float = 1.6+1.9*float(atmosphere._air_strength)
	var extra := Vector3.ZERO
	var h: Variant = islands._height(point)
	if h != null and point.y > float(h)-1.0:
		var ahead: Variant = islands._height(point+Vector3(way.x,0.0,way.y)*RIDGE_STEP)
		var behind: Variant = islands._height(point-Vector3(way.x,0.0,way.y)*RIDGE_STEP)
		if ahead != null and behind != null:
			var slope := (float(ahead)-float(behind))/(2.0*RIDGE_STEP)
			var near := 1.0-smoothstep(RIDGE_REACH*0.3,RIDGE_REACH,point.y-float(h))
			extra.y += clampf(slope*breeze*RIDGE_GAIN,0.0,RIDGE_MAX)*near
	var lean: float = atmosphere.fronts.lean_at(Vector2(point.x,point.z),way)
	if lean > 0.0: extra += Vector3(way.x*GUST_PUSH,GUST_LIFT,way.y*GUST_PUSH)*lean
	air.wind = (air.get("wind",Vector3.ZERO) as Vector3)+extra
	air["island"] = extra
	return air

# --- Perched on an islet ------------------------------------------------------------

## How far under the last ground stood on a jump between grouped islets
## falls before the flight opens (m).
const PERCH_FALL := 4.0
var _perch_floor := 0.0

## True when a point over an islet is down near its ground, not riding over
## a crown or the spire.
func _islet_ground_near(islet: Dictionary, point: Vector3) -> bool:
	var local: Vector3 = _islets().local_of(islet,point)
	return local.y-float(islet.shape.ground_at(Vector2(local.x,local.z))) < SkyGlide.SKIM+0.5

## Touched down on an islet: the glide stops and the pilot runs on over
## its top, still out in the sky. It is pinned so it is never let go while
## stood on.
func _perch(islet: Dictionary) -> void:
	_swoop = SWOOP
	_swoop_from = {"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance}
	perch = islet
	_islets().pinned = islet.node
	var local: Vector3 = _islets().local_of(islet,glide.position)
	var at := _perch_free(islet.shape,Vector2(local.x,local.z))
	_perch_feet = Vector3(at.x,islet.shape.ground_at(at),at.y)
	_perch_floor = _perch_feet.y
	_yaw = glide.heading
	_polar = CAM_POLAR
	glider.visible = false
	scene.camera_roll = 0.0
	# It lands at a run that eases off.
	_perch_turn = SkyIslets.yaw_of(islet)
	motor.reset(_perch_feet,glide.heading-_perch_turn,RUN*0.7)
	_stand_camera()
	figure.visible = true
	body.settle()
	body.land(4.0)
	_sync_figure()
	steps.step("grass",1.0)
	_hint.text = PERCH_HINT if plane else GLIDER_PERCH_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0

func _unperch() -> void:
	if perch.is_empty(): return
	perch = {}
	if islands != null: _islets().pinned = null

## The nearest point to `at` (islet frame) a walker can stand on: inside,
## clear of trunks, the spire and the water.
func _perch_free(shape: RefCounted, at: Vector2) -> Vector2:
	if shape.share(at) > 0.92: at *= 0.92/shape.share(at)
	if not SkyIslets.blocked(shape,at): return at
	for ring in range(1,12):
		for k in range(12):
			var p := at+Vector2.from_angle(TAU*k/12.0)*ring*0.3
			if shape.share(p) <= 0.92 and not SkyIslets.blocked(shape,p): return p
	return at

func _perch_eye_global() -> Vector3:
	return _islets().frame(perch)*(_perch_feet+Vector3.UP*EYE_HEIGHT)

## The perched islet's turn when last read: as it turns (an airship's islet
## let spin, scripts/sky_airship.gd) the camera turns with the pilot.
var _perch_turn := 0.0

## How far the camera may tilt up on foot: further on an airship's towed
## islet, to look up at the ship.
const POLAR_TOWED := 2.45
func _polar_most() -> float:
	return POLAR_TOWED if not perch.is_empty() and perch.get("towed",false) else POLAR.y

## Running over an islet's top as over the plate: the same keys, jumps and
## camera, round trunks and the pond; off the rim, or Space again in the
## air, the flight opens, as off the plate's edge.
func _advance_perch(delta: float) -> void:
	var node: Node3D = perch.node
	if not is_instance_valid(node):
		_launch(1.0)
		return
	_fly_drone(delta)
	var shape: RefCounted = perch.shape
	var jump := Input.is_action_pressed(&"walk_jump")
	_jump_was = jump
	# An islet may be turned (an airship's, let spin): the camera turns with
	# it, and the stick is read in its frame.
	var turn := SkyIslets.yaw_of(perch)
	_yaw += wrapf(turn-_perch_turn,-PI,PI)
	_perch_turn = turn
	var want := _want(_yaw-turn,delta)
	_asked = want.length()
	# A grouped islet (a cluster's, scripts/sky_clusters.gd) reads
	# its neighbours' ground too, so the pilot jumps from one to the next.
	var ground := func(p: Vector2) -> float: return _perch_ground(p)
	motor.crouch = Input.is_action_pressed(&"walk_crouch")
	motor.twirl = Input.is_action_pressed(&"walk_twirl")
	var events := motor.step(delta,want,_top(),jump,ground,
		func(feet: Vector3, step: Vector2) -> Vector3: return _perch_slide(shape,feet,step),
		func(near: Vector2, y: float) -> Dictionary: return PilotLedge.find(ground,near,y))
	var at := Vector2(motor.feet.x,motor.feet.z)
	if motor.grounded: _perch_floor = motor.feet.y
	if not events.has("fly") and not motor.on_ledge() and not shape.inside(at) and motor.grounded and motor.hold == "":
		var next := _perch_neighbour(at)
		if not next.is_empty(): _perch_move(next)
	shape = perch.shape
	at = Vector2(motor.feet.x,motor.feet.z)
	# Off the land the flight opens; in a group, only once fallen PERCH_FALL
	# under the last ground, so a jump between islets carries on.
	var off: bool = not motor.on_ledge() and _perch_ground(at) == -INF
	if off and perch.has("group") and motor.feet.y > _perch_floor-PERCH_FALL: off = false
	if events.has("fly") or off:
		_launch(maxf(motor.speed(),1.0),not events.has("fly"))
		return
	_ledge_events(events)
	_perch_feet = motor.feet
	_pace = Vector2(motor.velocity.x,motor.velocity.z)
	_sync_figure()
	_motor_events(events)
	var drawn: Dictionary = body.drive(motor,delta)
	_tread(perch.node,events,drawn)
	_perch_feet = motor.feet
	_body_events(drawn,delta)
	_water_events(events,drawn,delta)
	_frame_walker(delta,_islets().frame(perch),turn,func(p: Vector3) -> float: return _perch_ground(Vector2(p.x,p.z)))
	if not perch.get("towed",false) and _polar > POLAR.y: _polar = lerpf(_polar,POLAR.y,_ease(0.4,delta))
	camera.fov = lerpf(camera.fov,FOV,_ease(EASE_FOV,delta))
	# The sky goes on round it: the islets bob, the clouds drift, the wind
	# quietens.
	# Tokens the pilot walks through (scripts/sky_collectibles.gd).
	if islands.collectibles != null:
		islands.collectibles.touch_walker(islands.global_transform*(islands.islets.frame(perch)*(_perch_feet+Vector3.UP*CollectibleLines.WALKER_MIDDLE)))
	var eye := _perch_eye_global()
	sky.advance(delta,eye,islands.in_cloud(eye,scene._motion_time))
	islands.advance(delta,eye,motor.facing,sky.flight.w)
	air.advance(delta,Vector3.ZERO,0.0,0.0)
	_hint_time += delta
	_hint.modulate.a = clampf(1.0-(_hint_time-6.0)/1.5,0.0,1.0)

## The water's depth at `p` in the perched islet's frame: a swimmable
## lake's (SkyIslet `swim_depth`), else none.
func _perch_depth(p: Vector2) -> float:
	if perch.is_empty() or not perch.shape.has_method("swim_depth") or not perch.shape.inside(p): return 0.0
	return float(perch.shape.swim_depth(p))

## The ground under `p` in the perched islet's frame: its own, or, in a
## group, a neighbour's (in this frame), or -INF.
func _perch_ground(p: Vector2) -> float:
	var shape: RefCounted = perch.shape
	if shape.inside(p): return float(shape.ground_at(p))
	var next := _perch_neighbour(p)
	return float(next.ground) if not next.is_empty() else -INF

## The islet of the perched one's group whose land holds `p` (perched
## frame): {islet, off (its middle from the perched one's), ground (in the
## perched frame)}, or {}. Where several stand one over another (a
## cluster's stack), the highest whose ground is within a step over the
## feet, else the lowest.
func _perch_neighbour(p: Vector2) -> Dictionary:
	if not perch.has("group") or islands == null: return {}
	var here: Vector3 = _islets().place(perch)
	var best := {}
	for b: Dictionary in _islets().built.values():
		if b.get("group","") != perch.group or b.node == perch.node: continue
		var off: Vector3 = _islets().place(b)-here
		var q := p-Vector2(off.x,off.z)
		if not b.shape.inside(q): continue
		var hit := {"islet":b,"off":off,"ground":float(b.shape.ground_at(q))+off.y}
		var reach := motor.feet.y+PilotMotor.STEP_UP
		if best.is_empty() or (float(hit.ground) <= reach and (float(best.ground) > reach or float(hit.ground) > float(best.ground))) \
				or (float(hit.ground) > reach and float(best.ground) > reach and float(hit.ground) < float(best.ground)):
			best = hit
	return best

## Stood on a grouped neighbour: it becomes the perch, the feet carried
## into its frame.
func _perch_move(next: Dictionary) -> void:
	var off: Vector3 = next.off
	perch = next.islet
	_islets().pinned = perch.node
	motor.feet -= off
	motor.ground_y -= off.y
	_perch_floor -= off.y
	_perch_feet = motor.feet

## A rope bridge underfoot (scripts/rope_bridge.gd) takes the pilot's
## weight, footfalls and landings, and carries his feet with its sway.
func _tread(frame: Node3D, events: Dictionary, drawn: Dictionary) -> void:
	var effort := clampf((motor.speed()-WALK)/(RUN-WALK),0.0,1.0)
	var carry := RopeBridge.tread(frame,motor.feet,motor.grounded,events,drawn,effort)
	if carry != Vector3.ZERO: motor.feet += Vector3(carry.x,0.0,carry.z)

## A step over an islet: round what blocks the way, sliding along one axis
## or standing. Off its rim is let through, for the flight to open.
func _perch_slide(shape: RefCounted, feet: Vector3, step: Vector2) -> Vector3:
	var was := Vector2(feet.x,feet.z)
	var next := RopeBridge.hold(perch.node,feet,was+step)
	step = next-was
	if not shape.inside(next): return Vector3(next.x,feet.y,next.y)
	if SkyIslets.blocked(shape,next):
		next = was+Vector2(step.x,0.0)
		if SkyIslets.blocked(shape,next) or not shape.inside(next): next = was+Vector2(0.0,step.y)
		if SkyIslets.blocked(shape,next) or not shape.inside(next): next = was
	return Vector3(next.x,feet.y,next.y)

## Down on the plate: back on foot where the glide touched.
func _land() -> void:
	var at := glide.position
	_swoop = SWOOP
	_swoop_from = {"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance}
	_end_flight()
	_yaw = glide.heading
	_polar = CAM_POLAR
	_read_obstacles(true)
	_read_depths()
	_feet = _clamped(_free_spot(_clamped(editor.terrain.to_local(at))))
	# It lands at a run that eases off.
	motor.reset(_feet,glide.heading-_turn(),RUN*0.7)
	_stand_camera()
	figure.visible = true
	body.settle()
	body.land(4.0)
	steps.step(_surface(),1.0)
	_disturb(PLACE_STRENGTH)
	_sync_figure()

## A stride walked, or a while stood: the life round it hears.
func _notice_step(moved: float, delta: float) -> void:
	_stride += moved
	_still = 0.0 if moved > 0.001 else _still+delta
	if _stride >= STRIDE:
		_stride = 0.0
		_disturb(clampf(_pace.length()/RUN,STILL_STRENGTH,1.0))
	elif _still >= STILL_PING:
		_still = 0.0
		_disturb(STILL_STRENGTH)

## What the feet are on (scripts/wanderer_steps.gd SURFACES), read as the
## terrain shades its faces (NativeTerrainData `rebuild_mesh`): a bridge's
## planks; water to wade; snow over the snowline; stone where the land is
## steeper than its rock slope or near the snowline; sand on an arid world's
## bare ground and on a bare shore; grass where cover grows (GRASSY); else
## bare earth, as a worn path is.
func _surface() -> String:
	if not perch.is_empty(): return "water" if _perch_depth(Vector2(_perch_feet.x,_perch_feet.z)) >= Footbridge.WET else "grass"
	return _surface_at(Vector2(_feet.x,_feet.z))

## What stands at plate point `at`, as `_surface`.
func _surface_at(at: Vector2) -> String:
	if not _deck(at).is_empty(): return "wood"
	if _depth(at) >= Footbridge.WET: return "water"
	var data: NativeTerrainData = editor.data
	var h: Variant = data.ground_height(at)
	if h == null: return "earth"
	var settings: Dictionary = data._recipe_settings
	var snowline: float = BiomeBlend.snowline(settings,data._palette.snowline)
	var drawn: Dictionary = Shape.BIOMES.get(settings.get("biome",""),{})
	var rock_slope: float = float(drawn.get("rock_slope",data._palette.rock_slope))
	var slope: float = Presets._slope(data,at)
	if float(h) > snowline and slope < 2.4: return "snow"
	if slope > rock_slope or float(h) > snowline-1.8: return "stone"
	var cover := data.ground_coverage(at)
	if cover >= GRASSY: return "grass"
	if settings.get("biome","") == "arid": return "sand"
	for d: Vector2 in [Vector2(SHORE,0.0),Vector2(-SHORE,0.0),Vector2(0.0,SHORE),Vector2(0.0,-SHORE)]:
		if _depth(at+d) >= Footbridge.WET: return "sand"
	return "earth"

func _disturb(strength: float) -> void:
	Disturbance.raise(editor.terrain.to_global(_feet),RADIUS,strength,"figure")

func _advance_return(delta: float) -> void:
	_returning = maxf(0.0,_returning-delta)
	var k := _ease(0.18,delta) if _returning > 0.0 else 1.0
	camera.fov = lerpf(camera.fov,_fov_before,k)
	if scene._orbiting or scene._panning:
		camera.fov = _fov_before
		_returning = 0.0
		return
	scene.target = scene.target.lerp(_before.target,k)
	scene.yaw = lerp_angle(scene.yaw,_before.yaw,k)
	scene.polar = lerpf(scene.polar,_before.polar,k)
	scene.distance = lerpf(scene.distance,_before.distance,k)


# --- The plane: landing, parked, taking off ---------------------------------------

func _walk_hint() -> String:
	if not plane: return GLIDER_HINT
	return BOARD_HINT if _near_plane else HINT

## Walking: the hint offers the takeoff by the parked plane.
func _hint_plane() -> void:
	var near := by_plane()
	if near == _near_plane: return
	_near_plane = near
	_hint.text = _walk_hint()
	if near:
		_hint_time = 0.0
		_hint.modulate.a = 1.0

func has_parked() -> bool:
	return parked != null and is_instance_valid(parked)

## True with the walker within BOARD_REACH of the parked plane, walking.
func by_plane() -> bool:
	if not plane or not has_parked() or flying or not perch.is_empty(): return false
	return Vector2(_feet.x,_feet.z).distance_to(_parked_at) <= BOARD_REACH

## F in the plane: lands; mid line-up, flies on; rolling out, hops out now.
func _land_key() -> void:
	if below():
		_land_below()
		return
	if landing != null:
		if _taking_off: return
		if landing.can_cancel(): _fly_on()
		else: landing.skip()
		return
	if _landing_wait:
		_landing_wait = false
		_hint.text = PLANE_HINT
		return
	_landing_wait = true
	_hint.text = LANDING_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0

## True while the eye is under the cloud sea (`--below`).
func below() -> bool:
	return lower != null and lower.below

## The islets the eye perches on: the sky's (scripts/sky_islets.gd), or
## under the cloud the archipelago's (scripts/sky_archipelago.gd).
func _islets() -> Node3D:
	return lower.islets() if below() else islands.islets

## F under the cloud: the plane comes in to the nearest island within
## LANDING_REACH (SkyGlide `approach`: it turns to the island's middle,
## throttles back and glides down), and touching down slowly on its ground
## perches there; F again, boost or a roll flies on.
func _land_below() -> void:
	if glide.approach:
		glide.approach = false
		_hint.text = PLANE_HINT
	else:
		glide.approach_target = _landing_spot()
		glide.approach = glide.approach_target != Vector3.INF
		_hint.text = LANDING_HINT if glide.approach else NO_LANDING_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0

## Called off before the touch: back to flying from where it is.
func _fly_on() -> void:
	if landing == null or not landing.cancel(): return
	landing = null
	chase.cine = Vector3.ZERO
	_hint.text = PLANE_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0

## F pressed: the plane heads for the island to land on while it is
## claimed; once it is the plate, the strip is picked and the landing
## begins. Boost or a roll calls it off.
func _wait_to_land(delta: float, input: Dictionary) -> void:
	if float(input.get("boost",0.0)) > 0.0 or float(input.get("roll",0.0)) != 0.0:
		_landing_wait = false
		_hint.text = PLANE_HINT
		return
	# Turning towards it meanwhile, unless steered.
	glide.approach_target = _landing_spot()
	if glide.approach_target != Vector3.INF and is_zero_approx(float(input.get("turn",0.0))): glide.heading += glide._aim(delta)
	if islands.claiming: return
	var target := _landing_target()
	if target == -2:
		_landing_wait = false
		_hint.text = NO_LANDING_HINT
		_hint.modulate.a = 1.0
		_hint_time = 0.0
		return
	if target >= 0:
		# Claimed first, so the strip is read off the real land.
		if islands._rise[target] == Vector3.ZERO and islands.lands[target] != null: _claim(target)
		return
	# Under the island or below its land, it climbs out first, so the way
	# in never has to pass through its rock.
	var under: Variant = _fly_ground(glide.position)
	var middle: Variant = _fly_ground(glide.approach_target) if glide.approach_target != Vector3.INF else null
	var floor_y := maxf((under as Vector2).x if under != null else -INF,(middle as Vector2).x if middle != null else -INF)
	if glide.under_rock or glide.position.y < floor_y+2.0:
		if is_zero_approx(float(input.get("pitch",0.0))): input["pitch"] = 0.8
		return
	_begin_landing()

## Which island F lands on: -1 the plate, a copy's index, or -2 none
## within LANDING_REACH.
func _landing_target() -> int:
	var best := -2
	var nearest := LANDING_REACH
	var m := editor.terrain.global_position+_land_middle(editor.data)
	var d := Vector2(m.x-glide.position.x,m.z-glide.position.z).length()
	if d < nearest:
		nearest = d
		best = -1
	for i in range(islands.offsets.size()):
		m = editor.terrain.global_position+islands.offsets[i]+Vector3.DOWN*islands.sunk(i)+_land_middle(islands.lands[i])
		d = Vector2(m.x-glide.position.x,m.z-glide.position.z).length()
		if d < nearest:
			nearest = d
			best = i
	return best

## The plate's land as a strip survey (PlaneStrip `survey`): its heights,
## water and decks, and everything standing taller than the wings.
func _strip_map() -> Dictionary:
	_read_obstacles(true)
	_read_depths()
	var data: NativeTerrainData = editor.data
	var height := func(p: Vector2) -> Variant: return data.ground_height(p) if data.has_land(p) else null
	var wet := func(p: Vector2) -> bool: return _depth(p) > Footbridge.WET or not _deck(p).is_empty()
	return PlaneStrip.survey(data.land_rect(),height,wet,_strip_blockers())

## What stands taller than the wings on the plate: every placed thing's
## footprint above WING_LOW (trees, rocks, cabins, lamps, fences), and the
## walker's own obstacles but the parked plane.
func _strip_blockers() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(1 if has_parked() else 0,_obstacles.size()): out.append(_obstacles[i])
	var content: Node = editor.content
	if content == null: return out
	var to_plate: Transform3D = editor.terrain.global_transform.affine_inverse()
	for batch: MultiMeshInstance3D in content._batches:
		if not is_instance_valid(batch) or batch.multimesh == null or batch.multimesh.mesh == null: continue
		var profile := _profile(batch.multimesh.mesh)
		if profile.size() < 3: continue
		for source: Dictionary in content._sources.get(batch.get_meta("part"),[]):
			var item: Variant = source.get("item")
			if item == null: continue
			var placed: Variant = content._instance_transform(source)
			if placed == null: continue
			var at: Transform3D = to_plate*batch.global_transform*(placed as Transform3D)
			var ground := _ground(Vector3(float(item.x),at.origin.y,float(item.z)))
			var lift: float = at.basis.y.y
			var wide := maxf(at.basis.get_scale().x,at.basis.get_scale().z)
			var reach := 0.0
			for band in range(profile.size()-2):
				var high := at.origin.y+lift*(profile[0]+profile[1]*(band+1))
				if high > ground+WING_LOW: reach = maxf(reach,profile[band+2]*wide)
			if reach > 0.0: out.append(Vector3(at.origin.x,at.origin.z,reach))
	return out

## The wind's way over the plate (plate XZ), or none.
func _wind_way() -> Vector2:
	var atmosphere: Node = scene.get("_atmosphere")
	if atmosphere == null: return Vector2.ZERO
	var angle: float = atmosphere._air_angle
	var way := editor.terrain.global_basis.inverse()*Vector3(cos(angle),0.0,sin(angle))
	return Vector2(way.x,way.z)

## The ground's height under a global point's XZ, or NAN off the land.
func _floor_global(p: Vector2) -> float:
	var local := editor.terrain.to_local(Vector3(p.x,0.0,p.y))
	if not _on_land(Vector2(local.x,local.z)): return NAN
	return editor.terrain.to_global(Vector3(local.x,_ground(local),local.z)).y

## A strip in the plate's frame (PlaneStrip) made global.
func _strip_global(strip: Dictionary) -> Dictionary:
	var out := strip.duplicate()
	for key in ["touch","end"]:
		var at: Vector2 = strip[key]
		out[key] = editor.terrain.to_global(Vector3(at.x,_ground(Vector3(at.x,0.0,at.y)),at.y))
	var dir: Vector2 = strip.dir
	out.dir = (editor.terrain.global_basis*Vector3(dir.x,0.0,dir.y)).normalized()
	return out

## Picks the strip on the plate and starts the landing.
func _begin_landing() -> void:
	_landing_wait = false
	var map := _strip_map()
	var local := editor.terrain.to_local(glide.position)
	var way := editor.terrain.global_basis.inverse()*glide.forward()
	var strips := []
	for strip in PlaneStrip.candidates(map,_wind_way(),Vector2(local.x,local.z),Vector2(way.x,way.z)): strips.append(_strip_global(strip))
	var seq := PlaneLanding.new()
	var chosen: Dictionary = seq.choose(glide,strips,_fly_ground)
	seq.land(glide,chosen,_fly_ground,_floor_global)
	_start_sequence(seq,false)
	_hint.text = LANDING_HINT

func _start_sequence(seq: RefCounted, takeoff: bool) -> void:
	landing = seq
	_taking_off = takeoff
	_hop_to = Vector3.INF
	glide.approach = false

## A slow touch on the land without F: it rolls to a stop straight ahead,
## as far as the land is clear.
func _roll_out() -> void:
	var map := _strip_map()
	var local := editor.terrain.to_local(glide.position)
	var way3 := editor.terrain.global_basis.inverse()*glide.forward()
	var way := Vector2(way3.x,way3.z).normalized() if Vector2(way3.x,way3.z).length() > 0.01 else Vector2(0.0,-1.0)
	var at := Vector2(local.x,local.z)
	var ahead := PlaneStrip.clear_ahead(map,at,way,PlaneLanding.ROLL_LEN)
	var strip := _strip_global({"touch":at,"end":at+way*maxf(ahead,0.3),"dir":way,"length":maxf(ahead,0.3),"hop":true})
	var seq := PlaneLanding.new()
	seq.land(glide,strip,_fly_ground,_floor_global,true)
	_start_sequence(seq,false)
	_touchdown()
	_hint.text = ROLLING_HINT

## One frame of the landing or takeoff: the sequence flies the plane and
## the sky, the sound and the camera follow it.
func _advance_sequence(delta: float) -> void:
	var input := _fly_input()
	var seq := landing
	if seq.can_cancel() and (float(input.get("boost",0.0)) > 0.0 or float(input.get("roll",0.0)) != 0.0 or float(input.get("lean",0.0)) != 0.0):
		# Flying on from the next frame; a roll asked for still rolls.
		_fly_on()
		_roll_asked = float(input.get("roll",0.0))
		return
	seq.step(delta)
	glide.engine = seq.engine
	if seq.touched: _touchdown()
	if not _taking_off and seq.phase == PlaneLanding.HOP_OUT and _hop_to == Vector3.INF: _begin_hop_out()
	if seq.phase in [PlaneLanding.HOP_OUT,PlaneLanding.BOARD]: _hop_figure(seq.hop,delta)
	elif has_figure(): figure.visible = false
	if not _taking_off and seq.phase == PlaneLanding.TOUCHDOWN: _hint.text = ROLLING_HINT
	sky.advance(delta,glide.position,islands.in_cloud(glide.position,scene._motion_time))
	islands.advance(delta,glide.position,glide.heading,sky.flight.w)
	vapour.step(delta,glide,_fly_ground)
	air.advance(delta,glide.velocity,0.0,0.0,vapour.near,islands.towers.fade(glide.position))
	air.engine(glide.speed,seq.throttle,seq.engine)
	chase.cine = _framing(seq)
	chase.step(delta,glide,0.0,_solid)
	_write_chase()
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	camera.fov = chase.fov
	if not has_parked() or _taking_off: glider.update(delta,glide,0.0,_fly_ground,false,vapour.near,vapour.side)
	_hint_time += delta
	_hint.modulate.a = clampf(1.0-(_hint_time-6.0)/1.5,0.0,1.0)
	if not seq.done(): return
	landing = null
	if _taking_off:
		_taking_off = false
		chase.cine = Vector3.ZERO
		glider.show_pilot(true)
		_hint.text = PLANE_HINT
		_hint.modulate.a = 1.0
		_hint_time = 0.0
	else:
		_land_beside_plane()

## How the camera frames each part: a little wider lining up, wider and to
## the left on final, round low to the left side for the touch and the hop
## out (the pilot climbs out on the left), and from there for the takeoff.
func _framing(seq: RefCounted) -> Vector3:
	match seq.phase:
		PlaneLanding.LINE_UP: return Vector3(0.0,0.0,0.25)
		PlaneLanding.DESCENT: return Vector3(-0.8,0.02,0.45)
		PlaneLanding.FLARE,PlaneLanding.TOUCHDOWN,PlaneLanding.ROLLOUT: return Vector3(-1.25,0.0,0.3)
		PlaneLanding.BEAT,PlaneLanding.HOP_OUT: return Vector3(-1.35,-0.04,0.3)
		PlaneLanding.BOARD,PlaneLanding.TAXI: return Vector3(-1.2,-0.04,0.3)
		PlaneLanding.ROLL: return Vector3(-0.9,0.0,0.3)
	return Vector3.ZERO

## The wheels touch: a puff of grass or dust, a thump, a blip of throttle,
## and the life round it startles.
func _touchdown() -> void:
	var local := editor.terrain.to_local(glide.position)
	var surface := _surface_at(Vector2(local.x,local.z))
	var ground := _floor_global(Vector2(glide.position.x,glide.position.z))
	var at := Vector3(glide.position.x,ground if not is_nan(ground) else glide.position.y-0.6,glide.position.z)
	_puff(at,surface)
	steps.step(surface,1.0)
	air.blip()
	Pad.pulse(0.35,0.2,0.14)
	Disturbance.raise(at,RADIUS*4.0,0.8,"figure")

## A soft puff at a global point: grass-green and pale on grass, warm dust
## on earth and sand, snow on snow, spray on water; a few soft balls that
## swell, drift up and fade.
func _puff(at: Vector3, surface: String, size := 1.0) -> void:
	var tints := {"grass":Color("d6dcb4"),"snow":Color("f4f6f8"),"water":Color("e8f2f4"),"stone":Color("cfc8bc"),"wood":Color("d8c4a4")}
	var tint: Color = tints.get(surface,Color("d8c39c"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x*13.0+at.z*7.0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	for i in range(7):
		var ball := MeshInstance3D.new()
		ball.mesh = sphere
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(tint,0.38)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ball.material_override = material
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ball.name = "PlanePuff"
		add_child(ball)
		var side := Vector3(rng.randf_range(-1.0,1.0),0.0,rng.randf_range(-1.0,1.0))
		ball.global_position = at+side*0.25*size+Vector3.UP*0.1*size
		ball.scale = Vector3.ONE*0.18*size
		var tween := ball.create_tween().set_parallel(true)
		tween.tween_property(ball,"scale",Vector3.ONE*rng.randf_range(0.55,0.9)*size,1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(ball,"global_position",ball.global_position+(side*0.7+Vector3.UP*rng.randf_range(0.25,0.55))*size,1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(material,"albedo_color:a",0.0,1.1).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(ball.queue_free)

## Stopped: the plane is parked where it stands, and the walker's hop out
## is worked out: to the plane's left, a little ahead, on free ground.
func _begin_hop_out() -> void:
	_park_here()
	glider.visible = false
	_read_obstacles(true)
	_read_depths()
	var local := editor.terrain.to_local(glide.position)
	var heading := _parked_heading
	var forward := Vector3(-sin(heading),0.0,-cos(heading))
	var right := Vector3(cos(heading),0.0,-sin(heading))
	var spot := Vector3(local.x,0.0,local.z)-right*HOP_SIDE+forward*HOP_AHEAD
	_hop_to = _clamped(_free_spot(_clamped(spot)))
	_hop_from = Vector3(local.x,local.y+0.1,local.z)

## The pilot mid-hop: `k` 0 in the cockpit, 1 on the ground beside it,
## rising and falling through the jump's pose.
func _hop_figure(k: float, delta: float) -> void:
	if not has_figure() or _hop_to == Vector3.INF: return
	figure.visible = k > 0.02 and k < 0.999
	var at := _hop_from.lerp(_hop_to,smoothstep(0.0,1.0,k))
	at.y += HOP_HEIGHT*sin(PI*k)
	figure.position = at
	var way := _hop_to-_hop_from
	figure.rotation = Vector3(0.0,atan2(-way.x,-way.z),0.0)
	body.hop(cos(PI*k),delta)

## Down beside the parked plane: on foot, facing it, the camera swooping
## from the chase down behind the pilot.
func _land_beside_plane() -> void:
	if not has_parked(): _park_here()
	if _hop_to == Vector3.INF: _begin_hop_out()
	_swoop = SWOOP
	_swoop_from = {"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance}
	_end_flight()
	_feet = _hop_to
	var to := Vector2(_parked_at.x-_feet.x,_parked_at.y-_feet.z)
	_yaw = atan2(-to.x,-to.y)+_turn()
	_polar = CAM_POLAR
	_pace = Vector2.ZERO
	motor.reset(_feet,_yaw-_turn())
	_stand_camera()
	figure.visible = true
	body.settle()
	body.land(3.0)
	steps.step(_surface(),0.6)
	_disturb(PLACE_STRENGTH)
	_sync_figure()
	_near_plane = by_plane()
	_hint.text = _walk_hint()
	_hint.modulate.a = 1.0
	_hint_time = 0.0

## Parks the plane where the flight stands now.
func _park_here() -> void:
	var local := editor.terrain.to_local(glide.position)
	_park(Vector2(local.x,local.z),glide.heading-_turn())

## Stands the plane parked at plate point `at`, facing `heading` (plate yaw).
func _park(at: Vector2, heading: float) -> void:
	if not has_parked():
		parked = PlaneFigure.new()
		parked.name = "ParkedPlane"
		editor.terrain.add_child(parked)
		if islands != null: islands.skip.append(parked)
	_parked_at = at
	_parked_heading = heading
	_seat_parked()
	_obstacle_key = []

## Sits the parked plane on its wheels and skid on the ground under it.
func _seat_parked() -> void:
	if not has_parked(): return
	var r := PlaneStrip.rest(func(p: Vector2) -> float: return _ground(Vector3(p.x,0.0,p.y)),_parked_at,_parked_heading)
	parked.park(PlaneFigure.pose(Vector3(_parked_at.x,r.x,_parked_at.y),_parked_heading,r.y,r.z))

## The parked plane goes: with `puff`, in a puff where it stood.
func _unpark(puff: bool) -> void:
	if not has_parked():
		parked = null
		return
	if puff and is_inside_tree(): _puff(parked.global_position,"grass")
	if islands != null: islands.skip.erase(parked)
	parked.queue_free()
	parked = null
	_obstacle_key = []

## Space by the parked plane: the pilot hops in, and it turns to its
## longest clear run, rolls, lifts and flies.
func _board() -> void:
	if not has_parked(): return
	var map := _strip_map()
	var heading := _parked_heading
	var run := PlaneStrip.takeoff(map,_parked_at,Vector2(-sin(heading),-cos(heading)),_wind_way())
	var r := PlaneStrip.rest(func(p: Vector2) -> float: return _ground(Vector3(p.x,0.0,p.y)),_parked_at,heading)
	var start := editor.terrain.to_global(Vector3(_parked_at.x,r.x,_parked_at.y))
	_hop_to = _feet
	_hop_from = Vector3(_parked_at.x,r.x+0.1,_parked_at.y)
	_unpark(false)
	_launch(0.0,false,start,heading+_turn())
	glide.pitch = r.y
	glide.bank = r.z
	glider.reset(glide)
	glider.show_pilot(false)
	var dir: Vector2 = run.dir
	var global_run := {"dir":(editor.terrain.global_basis*Vector3(dir.x,0.0,dir.y)).normalized(),"length":run.length,"edge":run.edge}
	var seq := PlaneLanding.new()
	seq.take_off(glide,global_run,_floor_global)
	# Hopping in from where the walker stood.
	var hop_to := _hop_to
	_start_sequence(seq,true)
	_hop_to = hop_to
	_hint.text = PLANE_HINT

# --- The skydive -------------------------------------------------------------------

## The start `--skydive` asks for: "plane" (in the plane, high over home),
## "fall" (already out of it, falling), or "" (none).
static func skydive_start(args: PackedStringArray) -> String:
	for arg in args:
		if arg == "--skydive": return "plane"
		if arg.begins_with("--skydive="): return "fall" if arg.trim_prefix("--skydive=") == "fall" else "plane"
	return ""

## `--skydive`: once the world is up, into the eyes and up in the plane
## SKYDIVE_HEIGHT m over home, flying towards its middle; with `fall`,
## out of it at once.
func _skydive_start(how: String) -> void:
	while not can_enter(): await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	if not can_enter(): return
	if not has_figure(): place(Vector3.ZERO)
	enter()
	var middle := editor.terrain.global_position+_land_middle(editor.data)
	var floor_y := _floor_global(Vector2(middle.x,middle.z))
	if not is_nan(floor_y): middle.y = floor_y
	var heading := 0.0
	var forward := Vector3(-sin(heading),0.0,-cos(heading))
	var start := middle+Vector3.UP*SKYDIVE_HEIGHT-forward*SKYDIVE_BACK
	_launch(SkyPlane.CRUISE_SPEED,false,start,heading)
	chase.reset(glide,start-forward*6.0+Vector3.UP*2.0,camera.fov)
	if how == "fall":
		await get_tree().create_timer(0.6).timeout
		eject()

## X in the plane (the pad's X): the pilot pops out of the cockpit and
## falls; the plane flies on by itself. Not while a landing or takeoff has
## the controls, nor perched.
func eject() -> bool:
	if not flying or diving or not plane or not perch.is_empty() or landing != null or canopy == null: return false
	_landing_wait = false
	glide.approach = false
	_plane_flight = glide
	drone = glide
	_drone_landing = null
	var out := SkyDive.new()
	out.stone = glide.stone
	out.floor_y = glide.floor_y
	out.water = glide.water
	var cockpit: Vector3 = glide.position+Vector3.UP*0.3
	out.eject(cockpit,glide.velocity,glide.heading)
	dive = out
	glide = out
	diving = true
	_open_asked = false
	glider.show_pilot(false)
	glider.visible = true
	canopy.reset()
	chase.first_person = false
	dive_camera.reset(dive,camera.global_position,camera.fov)
	if has_figure():
		figure.visible = true
		body.settle()
		_pose_diver(0.0)
	_puff(cockpit,"snow",0.3)
	air.flap()
	Pad.pulse(0.4,0.25,0.15)
	_hint.text = DIVE_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0
	return true

## The dive's input this frame: the stick (or WASD) turns and tracks, or
## steers the canopy; Boost tucks and Brake spreads (or brakes the canopy);
## X opens it. The right stick (or the mouse) looks round.
func _dive_input() -> Dictionary:
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var input := {
		"turn":stick.x,
		"pitch":stick.y,
		"boost":Input.get_action_strength(&"fly_boost"),
		"brake":Input.get_action_strength(&"fly_brake"),
		"open":_open_asked,
	}
	_open_asked = false
	var right := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	if right != Vector2.ZERO: dive_camera.turn(Vector2(-right.x,-right.y)*STICK_LOOK*get_process_delta_time())
	dive_camera.free_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or right != Vector2.ZERO
	return input

## What the dive falls onto: the islands as solids, or under the cloud the
## lower world's. No tree crowns or stones: on the plate they are not in
## the islands' solid, and on an islet (or a lower world's island) its
## ground stands in for its solid top, so the pilot comes down beside a
## trunk, not on its crown.
func _dive_ground(point: Vector3) -> Variant:
	var body: Variant = lower.body(point) if below() else islands.body(point)
	if body == null: return null
	var islets := _islets()
	var islet: Dictionary = islets.islet_at(point)
	if islet.is_empty(): return body
	var local: Vector3 = islets.local_of(islet,point)
	var at := Vector2(local.x,local.z)
	var y: float = islets.place(islet).y
	var ground := Vector2(float(islet.shape.ground_at(at))+y,float(islet.shape.underside(at))+y)
	# Only where it is the islet that is the solid there.
	if absf((body as Vector2).y-ground.y) < 0.01: return ground
	return body

## One frame of the dive: falling or under the canopy, the sky and the
## sound following, the plane circling, the camera over the pilot; touched
## down, on foot (or swimming), or the plane picks the pilot up.
func _advance_dive(delta: float) -> void:
	var input := _dive_input()
	# Over another island, it becomes the plate before the touch (as the
	# plane's flight does), and the touch waits on the claim.
	if not islands.claiming and not below():
		var copy: int = islands.copy_under(dive.position)
		if copy >= 0: _claim(copy)
	var hold: bool = islands.claiming and dive.under_canopy() and dive.height < 4.0
	# Under the canopy, left alone, it drifts round towards the nearest land.
	dive.approach_target = _landing_spot() if dive.under_canopy() else Vector3.INF
	var was_falling: bool = dive.falling()
	var out: Dictionary = {} if hold else dive.fall(delta,input,_dive_ground,_fly_air)
	if was_falling and dive.under_canopy():
		air.flap()
		_hint.text = CANOPY_HINT
		_hint.modulate.a = 1.0
		_hint_time = 0.0
	if out.has("opened"):
		dive_camera.kick()
		air.flap()
		Pad.pulse(0.5,0.3,0.2)
	# Into the cloud sea with no world under it: the plane catches.
	if lower == null and dive.position.y < dive.floor_y-DIVE_CATCH:
		_pickup(false)
		return
	sky.advance(delta,dive.position,islands.in_cloud(dive.position,scene._motion_time))
	islands.advance(delta,dive.position,dive.heading,sky.flight.w)
	islands.wake(dive.position,dive.velocity,delta)
	if islands.collectibles != null: islands.collectibles.touch_plane(islands.global_transform*dive.position)
	air.advance(delta,dive.velocity,0.0,clampf(dive.posture,0.0,1.0),0.0,islands.cloud_body(camera.global_position))
	_fly_drone(delta)
	if drone != null:
		# The plane's hum, from as near as it is.
		var near: float = 1.0-clampf(dive.position.distance_to(drone.position)/80.0,0.0,1.0)
		air.engine(drone.speed,0.0,0.15+0.6*near)
	else:
		air.engine(0.0,0.0,0.0)
	_pose_diver(delta)
	canopy.update(delta,dive,_shoulders())
	dive_camera.step(delta,dive,_solid)
	chase.eye = dive_camera.eye
	chase.look = dive_camera.look
	chase.roll = dive_camera.roll
	_write_chase()
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	camera.fov = dive_camera.fov
	_hint_time += delta
	_hint.modulate.a = clampf(1.0-(_hint_time-6.0)/1.5,0.0,1.0)
	if out.has("touched"): _dive_down(out.touched)

## The pilot drawn where the dive is: turned onto the belly falling, on
## the lines under the canopy, the limbs posed (PilotFigure `dive`).
func _pose_diver(delta: float) -> void:
	if not has_figure(): return
	figure.visible = true
	var b: Basis = dive.body_basis()
	figure.global_transform = Transform3D(b,dive.position-b*Vector3(0.0,SkyDive.HIPS,0.0))
	var hanging: float = smoothstep(0.3,0.75,float(dive.open)) if dive.under_canopy() else 0.0
	var pop: float = 1.0-clampf(float(dive.time)/SkyDive.POP_TIME,0.0,1.0) if dive.phase == SkyDive.POP else 0.0
	body.dive(clampf(-float(dive.posture),0.0,1.0),clampf(float(dive.posture),0.0,1.0),hanging,float(dive.flare),pop,delta)

## The pilot's shoulders (global), where the canopy's lines come down.
func _shoulders() -> Vector3:
	if not has_figure(): return Vector3.INF
	return figure.global_transform*Vector3(0.0,0.72,0.0)

## Out of the dive: the plane's flight is the eye's again.
func _end_dive() -> void:
	diving = false
	if _plane_flight != null: glide = _plane_flight
	scene.camera_roll = 0.0

## Touched down: on the plate or an islet (or a lower world's island) on
## foot, or in its water swimming; on anything else (open sea, a mountain's
## rock, a forested isle), the plane picks the pilot up.
func _dive_down(touch: Dictionary) -> void:
	var feet: Vector3 = dive.position-Vector3.UP*SkyDive.HIPS
	canopy.collapse(feet.y)
	if bool(touch.get("water",false)):
		_pickup(true)
		return
	var on_plate: bool = not below() and islands._height(feet+Vector3.UP*0.5) != null
	var islet: Dictionary = {} if on_plate else _islets().islet_at(feet)
	if on_plate: _dive_land_plate(touch)
	elif not islet.is_empty() and _islet_ground_near(islet,feet): _dive_land_islet(islet,touch)
	else: _pickup(false)

## Down on the plate: on foot where the feet touched (round any trunk),
## the camera swooping in behind; in its water, swimming. Then the plane
## comes in to land near.
func _dive_land_plate(touch: Dictionary) -> void:
	var at: Vector3 = dive.position-Vector3.UP*SkyDive.HIPS
	var heading: float = dive.heading
	var across: float = Vector2(dive.velocity.x,dive.velocity.z).length()
	var hard: bool = touch.get("hard",false)
	_swoop = SWOOP
	_swoop_from = {"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance}
	_end_dive()
	_end_flight()
	_yaw = heading
	_polar = CAM_POLAR
	_read_obstacles(true)
	_read_depths()
	var local := editor.terrain.to_local(at)
	var spot := _pushed_out(Vector2(local.x,local.z))
	_feet = _clamped(Vector3(spot.x,local.y,spot.y))
	motor.reset(_feet,heading-_turn(),minf(across,RUN*0.6))
	_into_water(float(motor.water.call(Vector2(_feet.x,_feet.z))) if motor.water.is_valid() else 0.0)
	_down_on_foot(hard)
	_drone_come_in()

## Down on an islet (or one of the lower world's islands): on foot over its
## top, as a flight perches there; in its lake, swimming.
func _dive_land_islet(islet: Dictionary, touch: Dictionary) -> void:
	var at: Vector3 = dive.position
	var across: float = Vector2(dive.velocity.x,dive.velocity.z).length()
	var local: Vector3 = _islets().local_of(islet,at-Vector3.UP*SkyDive.HIPS)
	_perch(islet)
	_end_dive()
	var spot := Vector2(local.x,local.z)
	var deep: float = float(motor.water.call(spot)) if motor.water.is_valid() else 0.0
	if deep > PilotMotor.SWIM_IN:
		_perch_feet = Vector3(spot.x,islet.shape.ground_at(spot),spot.y)
	motor.reset(_perch_feet,motor.facing,minf(across,RUN*0.6))
	_into_water(deep)
	glider.visible = drone != null
	_down_on_foot(touch.get("hard",false))

## Landing in water deeper than a wade: the feet just over its top, so the
## motor's next step goes in with a splash and swims.
func _into_water(depth: float) -> void:
	if depth <= PilotMotor.SWIM_IN: return
	motor.feet.y += depth+0.25
	motor.ground_y = motor.feet.y-depth-0.25
	motor.grounded = false
	motor.velocity.y = -2.5

## On foot after the touch: the figure drawn, squashed as it came down
## (a bump if the canopy had not filled), its sound and puff, the walk's
## hint.
func _down_on_foot(hard: bool) -> void:
	_stand_camera()
	figure.visible = true
	body.settle()
	body.land(9.0 if hard else 3.0)
	if motor.grounded:
		steps.step(_surface(),1.0 if hard else 0.6)
		puffs.burst(_puff_at(figure.global_position),_surface(),0.6 if hard else 0.15)
	if hard: Pad.pulse(0.5,0.3,0.2)
	_disturb(PLACE_STRENGTH)
	_sync_figure()
	_hint.text = _walk_hint() if perch.is_empty() else PERCH_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0

## Nowhere to stand (open sea, a mountain's rock, the cloud sea with no
## world under it): the plane swoops in under the pilot and flies on with
## them aboard, nose up. Never a fall that ends badly.
func _pickup(wet: bool) -> void:
	var at: Vector3 = dive.position
	var heading: float = dive.heading
	if wet:
		_puff(at-Vector3.UP*SkyDive.HIPS,"water")
		steps.step("water",1.0)
	if canopy != null and not canopy.collapsing(): canopy.reset()
	_end_dive()
	drone = null
	_drone_landing = null
	if has_figure(): figure.visible = false
	glide.position = at+Vector3.UP*1.2
	glide.heading = heading
	glide.resume(SkyPlane.CRUISE_SPEED,0.35)
	glider.reset(glide)
	glider.show_pilot(true)
	glider.visible = not chase.first_person
	chase.reset(glide,camera.global_position,camera.fov)
	air.flap()
	Pad.pulse(0.35,0.2,0.14)
	_hint.text = PICKUP_HINT
	_hint.modulate.a = 1.0
	_hint_time = 0.0

## The plane flying itself after an eject: circling the pilot (falling,
## floating or on foot), or coming in to land near them on the plate and
## parking there.
func _fly_drone(delta: float) -> void:
	if drone == null or not glide_enabled: return
	if _drone_landing != null:
		_drone_landing.step(delta)
		drone.engine = _drone_landing.engine
		glider.update(delta,drone,0.0,_fly_ground,false)
		if _drone_landing.phase >= PlaneLanding.BEAT and _drone_landing.phase <= PlaneLanding.DONE:
			_park_here_from(drone)
			_drop_drone()
		return
	var centre := _pilot_global()
	var to := Vector2(centre.x-drone.position.x,centre.z-drone.position.z)
	var gap := to.length()
	if gap > ORBIT_FAR:
		# Brought round near, out of sight.
		drone.position = centre+Vector3(-to.x,0.0,-to.y).normalized()*ORBIT*2.0+Vector3.UP*ORBIT_OVER
		to = Vector2(centre.x-drone.position.x,centre.z-drone.position.z)
		gap = to.length()
	var radial := to/maxf(gap,0.001)
	var round_way := Vector2(-radial.y,radial.x)
	var want := (round_way+radial*clampf((gap-ORBIT)/ORBIT,-1.0,1.0)).normalized()
	var err := angle_difference(float(drone.heading),atan2(-want.x,-want.y))
	var height := centre.y+ORBIT_OVER
	var under: Variant = _fly_ground(drone.position)
	if under != null: height = maxf(height,(under as Vector2).x+ORBIT_CLEAR)
	var climb := clampf((height-drone.position.y)*0.06-float(drone.pitch)*0.8,-1.0,1.0)
	drone.step(delta,{"turn":clampf(-err*1.6,-1.0,1.0),"pitch":climb,"boost":1.0 if gap > ORBIT*3.0 else 0.0},_fly_ground,_fly_air)
	glider.update(delta,drone,0.0,_fly_ground,false)

## Where the pilot is, global: the dive's place, or the feet on foot.
func _pilot_global() -> Vector3:
	if diving and dive != null: return dive.position
	if has_figure(): return figure.global_position
	return drone.position

## The pilot down on the plate: the plane comes in to land on the best
## strip it finds near them (PlaneStrip, as F's landing picks one), drawn
## pilotless, and parks where it stops.
func _drone_come_in() -> void:
	if drone == null or below() or not has_figure(): return
	var map := _strip_map()
	var way: Vector3 = editor.terrain.global_basis.inverse()*drone.forward()
	var strips := []
	for strip in PlaneStrip.candidates(map,_wind_way(),Vector2(_feet.x,_feet.z),Vector2(way.x,way.z)): strips.append(_strip_global(strip))
	var seq := PlaneLanding.new()
	var chosen: Dictionary = seq.choose(drone,strips,_fly_ground)
	if chosen.is_empty():
		_settle_drone()
		return
	seq.land(drone,chosen,_fly_ground,_floor_global)
	_drone_landing = seq
	glider.visible = true

## Parks the plane where `flight` stands (on the plate).
func _park_here_from(flight: RefCounted) -> void:
	var local := editor.terrain.to_local(flight.position)
	_park(Vector2(local.x,local.z),float(flight.heading)-_turn())
	glider.visible = false
	_obstacle_key = []

## The plane flying itself is let go of now: parked on the plate near the
## pilot if they are on it (a puff where it sets down), else simply gone
## (the next flight brings it, as ever).
func _settle_drone() -> void:
	if drone == null: return
	if not diving and perch.is_empty() and has_figure() and not below() and not flying:
		var spot := _clamped(_free_spot(_clamped(_feet+Vector3(2.5,0.0,1.5))))
		_park(Vector2(spot.x,spot.z),motor.facing)
		if has_parked() and is_inside_tree(): _puff(parked.global_position,"grass")
	_drop_drone()

func _drop_drone() -> void:
	drone = null
	_drone_landing = null
	if glider != null and not flying: glider.visible = false

# --- Input ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if handle(event): get_viewport().set_input_as_handled()

## The eye's input. Returns true when the event was used. V from the world
## is taken here too, so the hand scheme's key filter never sees it.
func handle(event: InputEvent) -> bool:
	if not active:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V \
				and not (event.ctrl_pressed or event.meta_pressed or event.alt_pressed) and can_enter():
			summon(scene.get_viewport().get_mouse_position())
			return true
		return false
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and diving:
			dive_camera.turn(Vector2(-event.relative.x,-event.relative.y)*LOOK)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not perch.is_empty():
			_yaw -= event.relative.x*LOOK
			_polar = clampf(_polar-event.relative.y*LOOK,POLAR.x,_polar_most())
			_look_rest = 0.0
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and flying and (chase.free_held or plane):
			chase.turn(Vector2(-event.relative.x,-event.relative.y)*LOOK)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and flying:
			_fly_look += Vector2(event.relative.x,-event.relative.y)*LOOK
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= event.relative.x*LOOK
			_polar = clampf(_polar-event.relative.y*LOOK,POLAR.x,POLAR.y)
			_look_rest = 0.0
		return true
	if event is InputEventMouseButton:
		# A click takes the mouse back if the window let it go.
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if diving:
			if event.button_index == MOUSE_BUTTON_RIGHT: dive_camera.free_held = event.pressed
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT and flying: chase.free_held = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and flying and perch.is_empty() and plane:
			# A click rolls the way it is turning, or right flying straight.
			_roll_asked = -1.0 if glide.bank < -0.05 else 1.0
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and flying and perch.is_empty(): _flap_asked = true
		return true
	if event is InputEventMagnifyGesture or event is InputEventPanGesture:
		return true
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad_event(event)
		# Every pad event is the eye's: none moves a control's focus.
		return true
	if event is InputEventKey:
		if event.ctrl_pressed or event.meta_pressed: return false
		if event.pressed and not event.echo and event.keycode in [KEY_V,KEY_ESCAPE]:
			leave()
		elif diving:
			if event.pressed and not event.echo and event.keycode == KEY_X: _open_asked = true
		elif event.pressed and not event.echo and event.keycode == KEY_X and flying and perch.is_empty() and plane:
			eject()
		elif event.pressed and not event.echo and event.keycode in [KEY_Q,KEY_E] and flying and perch.is_empty() and plane:
			_lean_tapped(-1.0 if event.keycode == KEY_Q else 1.0)
		elif event.pressed and not event.echo and event.keycode == KEY_E and flying and perch.is_empty():
			_flap_asked = true
		elif event.pressed and not event.echo and event.keycode == KEY_F and flying and perch.is_empty() and plane:
			_land_key()
		elif event.pressed and not event.echo and event.keycode == KEY_F and flying and perch.is_empty():
			glide.approach = not glide.approach
		elif event.pressed and not event.echo and event.keycode == KEY_C and flying and perch.is_empty():
			chase.first_person = not chase.first_person
			glider.visible = not chase.first_person
		# Walking keys are read each frame; every plain key stays here.
		return true
	return false

## The pad's presses (its sticks and triggers are polled): B or View steps
## out, Y lands (or flies on, or hops out, as F), R3 swaps the camera, the
## shoulders roll the plane and X flaps the glider. Menu is the scene's
## (scripts/pad_input.gd).
func _pad_event(event: InputEvent) -> void:
	var airborne := flying and perch.is_empty() and not diving
	if Pad.pressed(event,&"eye_leave"): leave()
	elif diving and Pad.pressed(event,&"fly_eject"): _open_asked = true
	elif airborne and plane and Pad.pressed(event,&"fly_eject"): eject()
	elif airborne and Pad.pressed(event,&"fly_land"):
		if plane: _land_key()
		else: glide.approach = not glide.approach
	elif airborne and Pad.pressed(event,&"fly_camera"):
		chase.first_person = not chase.first_person
		glider.visible = not chase.first_person
	elif airborne and plane and Pad.pressed(event,&"fly_lean_left"): _lean_tapped(-1.0)
	elif airborne and plane and Pad.pressed(event,&"fly_lean_right"): _lean_tapped(1.0)
	elif airborne and not plane and Pad.pressed(event,&"glide_flap"): _flap_asked = true

## A lean pressed: the second press the same way within DOUBLE_TAP asks for
## a barrel roll that way.
func _lean_tapped(dir: float) -> void:
	var now := Time.get_ticks_msec()
	if dir == _tap_dir and now-_tap_at <= int(DOUBLE_TAP*1000.0):
		_roll_asked = dir
		_tap_dir = 0.0
	else:
		_tap_dir = dir
		_tap_at = now

func _notification(what: int) -> void:
	# Stepping out of the window lets the mouse go.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
