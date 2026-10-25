extends RefCounted
## The endless land's field: its height, its meadows and its colour at any
## world XZ point, from a seed alone, so the same seed always grows the same
## land (docs/design/endless-flight/round-1-handoff.md,
## terrain-shape-handoff.md). Plain maths over FastNoiseLite; each worker
## builds its own field (`new(seed)`), so chunks are made off the main
## thread without sharing one. The maths runs natively (C++,
## native/terrain_kernels/land_field.h) when the library is built, else in
## GDScript (`GDField` below), the same land either way
## (native-land-handoff.md); --land-native=0 the GDScript field.
##
## The land, in metres over the sea (`SEA_Y` world):
##   continents  CONTINENT, very broad: where land stands and where it
##               sinks under the sea, the coast between.
##   hills       HILLS, rolling, softer near the coast.
##   ranges      long winding mountain ranges along the crest lines of a
##               warped noise (RANGES), standing where RANGE_MASK rises:
##               a massif under ridged crests (RIDGES), each stretch its own
##               height (PEAK_TALL), snow on top.
##   meadows     where MEADOWS' mask rises (none on the ranges): the hills
##               eased out into broad, near-flat turf.
##   valleys     carved along the zero lines of another warped noise
##               (VALLEYS): long and winding, a flat floor (a meadow) as
##               wide as WorldScale.opening(TOY_VALLEY), steep sides through
##               the ranges, gentle through the hills. With the meadows they
##               keep a flat to land on always in reach (AGENTS.md).
## Every number is a knob here; `--seed=` picks the land. Flags (read per
## field): --mountains=X how much land the ranges cover (1; 0 none),
## --peaks=X their height (1), --valleys=X how deep the valleys cut (1;
## over 1 their sides widen; 0 or --no-valleys none), --old-land round one's land exactly.
##   carve       erosion cut into the steep rock only (`_carve`, CARVE_*):
##               broken block planes, ledges, gullies down the fall line at
##               three sizes; never on meadows or valley floors.
##               --no-carve the land uncarved, --carve=X its strength,
##               --carve-blocks= / --carve-ledges= / --carve-gullies= each
##               form's share (rock-carve-handoff.md).
##   rivers      one down each valley (`_river`, RIVER_*): a channel along a
##               line near one edge of the floor, its water drawn by the
##               ground shader at `last_river_y`, the level falling with
##               the lowland to the sea. --no-rivers the land as before
##               (rivers-handoff.md).
##   ponds       still water in hollows on the meadows (land_ponds.gd), a
##               layer over the field cut in by LandField; they read as
##               still rivers. --ponds=X their density, 0 none
##               (ponds-handoff.md).

const WorldScale = preload("res://scripts/world_scale.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")

## The sea's height in the world. The endless flight raises the plane's
## ceiling to CEILING_OVER over the sea (SkyGlide `ceiling_y`), so the
## tallest peaks stand over it and into the cloud roof.
const SEA_Y := -40.0
## The plane's ceiling over the sea in the endless flight (m); the isles'
## fixed CEILING (95 world) is 135 over this sea.
const CEILING_OVER := 215.0
## Continents: their scale (m), the height they swing (m) and the lift that
## sets how much is land (more is more land).
const CONTINENT := 3600.0
const CONTINENT_SWING := 70.0
const CONTINENT_LIFT := 14.0
const LOWLAND := 26.0
## Rolling hills: their scale and height (m).
const HILLS := 320.0
const HILL_TALL := 16.0
## Round one's mountains (--old-land): the mask's scale (m) and its band,
## the ridges' scale and their height (m).
const MOUNTAINS := 2600.0
const MOUNTAIN_BAND := Vector2(0.18,0.5)
const MOUNTAIN_TALL := 105.0
## The ranges: the crest lines' scale (m) and how far either side of a crest
## (in noise) the range reaches; the mask that says where ranges stand, its
## scale and band (lower is more ranges); the warp that winds them (scale,
## m moved).
const RANGES := 2300.0
const RANGE_WIDTH := 0.36
const RANGE_MASK := 3400.0
const RANGE_BAND := Vector2(-0.50,-0.12)
const WARP := 1500.0
const WARP_MOVE := 520.0
## The ridges on the ranges (ridged noise): scale (m).
const RIDGES := 700.0
## How tall the ranges stand over the lowland (m): the low and high stretch,
## varying along a range over PEAK_SCALE m.
const PEAK_TALL := Vector2(95.0,215.0)
const PEAK_SCALE := 1700.0
## Meadows: the mask's scale (m), its band, how flat the flats are (the
## share of the hills they keep) and the least they stand over the sea.
const MEADOWS := 650.0
const MEADOW_BAND := Vector2(-0.05,0.22)
const MEADOW_KEEP := 0.07
const MEADOW_ABOVE := 3.0
## Valleys: the zero lines' scale (m) and warp; the floor's toy-era width
## (WorldScale.opening, ~100 m at the knobs) and how it swings (x); the
## sides' width (m) through hills and through ranges; the share of the
## hills the floor keeps.
const VALLEYS := 2100.0
const VALLEY_WARP := 1100.0
const VALLEY_WARP_MOVE := 380.0
const TOY_VALLEY := 50.0
const VALLEY_SWING := Vector2(0.75,1.7)
const VALLEY_SIDE := Vector2(300.0,150.0)
const VALLEY_KEEP := 0.08
## The built land's forms (overgrown-land-handoff.md), each off (0) unless a
## world's recipe turns it on, so a world without them grows bit for bit as
## before.
## Cut ridges: RIDGE_CRISP blends the ranges' rounded massif toward a gable
## (sharp crest, straight flanks, the ridged noise only a ripple on it); NOTCH
## the depth (share of the range's height) of clean flat-floored notches where
## the zero lines of a noise (NOTCH_SCALE m) cross a crest, NOTCH_WIDTH their
## floor and lip (|noise|).
const RIDGE_CRISP := 0.0
const NOTCH := 0.0
const NOTCH_SCALE := 1300.0
const NOTCH_WIDTH := Vector2(0.025,0.07)
## Terraces on the hills (and a range's lower flanks): TERRACE their strength,
## a tread every TERRACE_STEP m of height, TERRACE_FLAT of each step the tread
## (the rest the riser), where a mask noise (TERRACE_SCALE m) rises through
## TERRACE_BAND.
const TERRACE := 0.0
const TERRACE_STEP := 5.0
const TERRACE_FLAT := 0.65
const TERRACE_SCALE := 1500.0
const TERRACE_BAND := Vector2(-0.15,0.2)
## Mesas: tablelands MESA_TALL m over the lowland (MESA strength 0..1), where
## a noise (MESA_SCALE m) stands over MESA_LEVEL, their walls MESA_EDGE of the
## noise wide (sheer), in MESA_STEPS tiers MESA_GAP of the noise apart (a
## ledge between), their tops keeping MESA_KEEP of the hills; only where a
## broad mask (MESA_MASK m) rises through MESA_BAND, away from the ranges.
const MESA := 0.0
const MESA_TALL := 50.0
const MESA_SCALE := 800.0
const MESA_LEVEL := 0.3
const MESA_EDGE := 0.035
const MESA_STEPS := 2.0
const MESA_GAP := 0.12
const MESA_KEEP := 0.12
const MESA_MASK := 3800.0
const MESA_BAND := Vector2(-0.1,0.25)
## The coast: the beach's height band over the sea (m).
const BEACH := 2.2
## Snow from SNOW m over the sea, on what is no steeper than the shader's.
const SNOW := 125.0
## The carve (rock-carve-handoff.md): erosion cut into the steep rock only,
## all local maths, so a chunk, a collider and the plane's ground agree.
## The broad land's slope is read off a lattice of CARVE_GRID m (cached per
## field) and eased between its nodes. Carving rises in over the slope
## band CARVE_SLOPE (rise over run; the ground shader's rock starts near
## 0.75), only where a range stands (CARVE_MOUNTAIN) and never on a meadow
## or a valley floor (both flat, and the meadow mask fades it too).
const CARVE_GRID := 8.0
const CARVE_SLOPE := Vector2(0.38,0.9)
const CARVE_MOUNTAIN := Vector2(0.004,0.08)
## Blocks: Voronoi cells of FACET_CELL m, each a plane (the slope at its
## centre, tilted up to FACET_TILT of it, lifted up to FACET_STEP m), blended
## sharply (FACET_EDGE, 1/m^2) so a wall breaks into planes with notched
## edges; FACET_KEEP the share of the wall they take.
const FACET_CELL := 32.0
const FACET_TILT := 0.35
const FACET_STEP := 3.5
const FACET_EDGE := 0.010
const FACET_KEEP := 0.8
## Ledges: benches every BENCH m of height whose contours wander (BENCH_WARP
## of a step over BENCH_WANDER m), BENCH_FLAT of each step the bench, and
## only where a band noise (BENCH_BANDS m) allows.
const BENCH := 14.0
const BENCH_WARP := 1.4
const BENCH_WANDER := 70.0
const BENCH_FLAT := 0.42
const BENCH_BANDS := 220.0
## Gullies down the fall line, three sizes: (spacing m, depth m). Each is
## waves across the slope from a cell lattice of its spacing, every cell its
## own phase and spacing (GULLY_JITTER), so they fork and stop rather than
## run as stripes; GULLY_SHARP narrows the grooves between broad buttresses.
const GULLIES := [Vector2(36.0,10.0),Vector2(15.0,4.5),Vector2(6.0,1.0)]
const GULLY_JITTER := 0.45
const GULLY_SHARP := 1.7
const GULLY_SHADE := [1.0,0.75,0.4]
## The carve fades by the chunk's grid step (`detail`): a size under
## CARVE_FADE steps goes; at CARVE_DETAIL_OFF m steps there is no carve.
const CARVE_FADE := Vector2(3.0,5.0)
const CARVE_DETAIL_OFF := 16.0
## Rivers (rivers-handoff.md): one down each valley, along its line, not a
## drainage net. The water's full width (m) swings over RIVER_WIDE m; the
## banks stand RIVER_DROP m over it (wider rivers the deeper) and run
## RIVER_BANK m from the water's edge up to the floor; under the drawn
## water the bed dips RIVER_BED m more at the middle (the wheels' and the
## walker's ground; the ground shader draws the water flat). The river
## runs near one edge of the floor, at the foot of that side (RIVER_HUG of
## the floor's half-width off the valley's line; the side picked by a
## noise of RIVER_SIDE m, so it crosses the floor now and then) and
## meanders RIVER_SWAY of the half-width over RIVER_MEANDER m, leaving the
## floor's flat whole to land on. Its level follows the lowland under the
## valley (the continents, not the hills), RIVER_DROP under it and never
## under the sea, so it runs down to the coast and into the sea; where
## the hills dip under that level the valley's floor is filled up to it
## (the floor and its sides, as the valley's cut) and, by the river, a
## bank is raised (RIVER_RAMP m wide). --no-rivers the land as before,
## --river-width=X its width (1), --river-drop=X its banks' height (1).
const RIVER_WIDTH := Vector2(10.0,24.0)
const RIVER_WIDE := 820.0
## A closer swell and pinch of the width: its share (+-) and scale (m).
const RIVER_PINCH := 0.28
const RIVER_PINCH_SIZE := 150.0
const RIVER_DROP := Vector2(2.0,3.0)
const RIVER_BANK := 8.0
const RIVER_BED := 0.6
const RIVER_HUG := 0.9
const RIVER_SIDE := 1900.0
const RIVER_MEANDER := 470.0
const RIVER_SWAY := 0.12
const RIVER_RAMP := 40.0
## How far either side of its line the river's sums are worked out (m, in
## the valley noise's units; more near a coast, for the plain); past it a
## mean stands in.
const RIVER_REACH := 80.0
## The most the land by the river is eased down to the banks (m over
## them: all of it to .x, none past .y); the river ends where it is more.
const RIVER_PLAIN := Vector2(26.0,40.0)
## The plain widens RIVER_PLAIN_SPREAD m for each m it cuts down.
const RIVER_PLAIN_SPREAD := 6.0
## The flow: its speed (m/s) from the level's fall along the valley
## (sqrt of rise over run times RIVER_FLOW.y, plus .x), stilled where the
## fall is under RIVER_STILL (a level stretch reads as a pool).
const RIVER_FLOW := Vector2(0.35,9.0)
const RIVER_STILL := 0.0012
## Grass, flowers and ruins keep this far outside a river's water (m): its
## sand and pebble bank (the ground shader's `river_bank`).
const RIVER_CLEAR := 5.0
## With rivers, the valleys cut in fully by this `inland` (0..1, the
## continents' rise off the coast; without rivers the cut scales by it).
const RIVER_INLAND := 0.3
## That full cut runs this share of the sides' width up them (0..1).
const RIVER_CUT_SIDE := 0.5
## A hollow under the floor is filled out to this far past it (m).
const RIVER_FILL_SIDE := 110.0
## The mouth (river-mouths-handoff.md): over the last RIVER_MOUTH_RISE m of
## its fall to the sea the river opens out to 1+RIVER_FLARE times its width
## (wider the nearer the sea, a funnel), its bed deepens by RIVER_MOUTH_DEEP
## m (so the sea fills the channel past the drawn water, troughs and all),
## its current slows as it widens, and its level eases into the sea's over
## RIVER_MOUTH_EASE m (it meets it flat, not on a slope). In its channel the
## sea's swell is stilled (`sea_calm`, the sea's depth map's green).
## --river-mouth=0 the mouths as before.
const RIVER_MOUTH_RISE := 5.0
const RIVER_FLARE := 1.4
const RIVER_MOUTH_DEEP := 3.6
const RIVER_MOUTH_EASE := 1.2
## The ground shader draws the water sinking under the sea's over the last
## RIVER_MOUTH_SINK m of its level (by its bed's depth at the sea), so it
## meets the sea with no step; `river_drawn` mirrors it for the flight.
const RIVER_MOUTH_SINK := 1.5

const SAND := Color(0.80,0.74,0.56)
const SEABED := Color(0.42,0.46,0.40)
const GRASS := Color(0.30,0.48,0.20)
const GRASS_DRY := Color(0.46,0.54,0.24)
const MEADOW := Color(0.52,0.64,0.28)
const ROCK := Color(0.47,0.44,0.40)
const SNOW_COLOUR := Color(0.93,0.94,0.97)

## The land recipe's numbers as a world profile's `land` table keys them
## (scripts/endless/world/world_profile.gd): these constants, wilderness's.
## LandField hands a profile's own to the field (and the native field's
## `configure`); keys left out are these.
static func recipe_defaults() -> Dictionary:
	return {
		"continent_scale":CONTINENT,
		"continent_swing":CONTINENT_SWING,
		"continent_lift":CONTINENT_LIFT,
		"lowland":LOWLAND,
		"hill_scale":HILLS,
		"hill_tall":HILL_TALL,
		"range_scale":RANGES,
		"range_width":RANGE_WIDTH,
		"range_mask_scale":RANGE_MASK,
		"range_band":RANGE_BAND,
		"warp_scale":WARP,
		"warp_move":WARP_MOVE,
		"ridge_scale":RIDGES,
		"peak_tall":PEAK_TALL,
		"peak_scale":PEAK_SCALE,
		"meadow_scale":MEADOWS,
		"meadow_band":MEADOW_BAND,
		"meadow_keep":MEADOW_KEEP,
		"meadow_above":MEADOW_ABOVE,
		"valley_scale":VALLEYS,
		"valley_warp_scale":VALLEY_WARP,
		"valley_warp_move":VALLEY_WARP_MOVE,
		"valley_swing":VALLEY_SWING,
		"valley_side":VALLEY_SIDE,
		"valley_keep":VALLEY_KEEP,
		"snow":SNOW,
		"ridge_crisp":RIDGE_CRISP,
		"notch":NOTCH,
		"notch_scale":NOTCH_SCALE,
		"notch_width":NOTCH_WIDTH,
		"terrace":TERRACE,
		"terrace_step":TERRACE_STEP,
		"terrace_flat":TERRACE_FLAT,
		"terrace_scale":TERRACE_SCALE,
		"terrace_band":TERRACE_BAND,
		"mesa":MESA,
		"mesa_tall":MESA_TALL,
		"mesa_scale":MESA_SCALE,
		"mesa_level":MESA_LEVEL,
		"mesa_edge":MESA_EDGE,
		"mesa_steps":MESA_STEPS,
		"mesa_gap":MESA_GAP,
		"mesa_keep":MESA_KEEP,
		"mesa_mask_scale":MESA_MASK,
		"mesa_band":MESA_BAND}

## --- The field --------------------------------------------------------------
## LandField is the public face: the same members and methods as ever, each
## handed to the field that does the work, the native one
## (native/terrain_kernels/land_field.h, ZenScapeLandField) when the library
## is built, else the GDScript one below (`GDField`), which is the reference
## the native one matches (docs/design/endless-flight/native-land-handoff.md).
## --land-native=0 (or --gdscript-kernels) runs the GDScript field;
## --land-libm the native one on the C library's exp/pow/sin/cos (as
## GDScript), to check the two match bit for bit on one machine.

## The native field's version this script calls (ZenScapeLandField `version`):
## 2 takes the world's land recipe in `configure`; 1 (a library not yet
## rebuilt) is still used for the stock recipe (`native_available`).
## 3 also takes the built land's forms (V3_KEYS); a version-2 library still
## grows a recipe that leaves them off.
const NATIVE_VERSION := 3
const V3_KEYS := ["ridge_crisp","notch","notch_scale","notch_width","terrace","terrace_step","terrace_flat","terrace_scale","terrace_band",
	"mesa","mesa_tall","mesa_scale","mesa_level","mesa_edge","mesa_steps","mesa_gap","mesa_keep","mesa_mask_scale","mesa_band"]
## The recipe's sharp forms (gable crests, notches, terraces, mesas): their
## walls stand near-vertical at any height, so blended in at a low weight they
## would make thin steps (a 22 m mesa wall at weight 0.1 is a 2 m sheer
## step). In the regions world a recipe with any of them on also grows a soft
## twin with them off, and its band eases the sharp forms in by a steeper
## weight than the rest (land_blend.gd `sharp_share`).
const SHARP_KEYS := ["ridge_crisp","notch","terrace","mesa"]
const NATIVE_CLASS := &"ZenScapeLandField"
static var _native_state := -1
static var _native_lock := Mutex.new()

var seed := 0
## The world profile whose `land` this field grows (world_profile.gd).
var world: RefCounted
## The field doing the work (ZenScapeLandField or GDField).
var _impl: Object
var _native := false
## Whether `_impl` is the regions world's blend (land_blend.gd).
var _blend := false
const Blend = preload("res://scripts/endless/land_blend.gd")

## The flags (see the top), read and set through to the field.
var mountains: float:
	get: return _impl.mountains
	set(v): _impl.mountains = v
var peaks: float:
	get: return _impl.peaks
	set(v): _impl.peaks = v
var valleys: float:
	get: return _impl.valleys
	set(v): _impl.valleys = v
var old_land: bool:
	get: return _impl.old_land
	set(v): _impl.old_land = v
var carve: float:
	get: return _impl.carve
	set(v): _impl.carve = v
var carve_blocks: float:
	get: return _impl.carve_blocks
	set(v): _impl.carve_blocks = v
var carve_ledges: float:
	get: return _impl.carve_ledges
	set(v): _impl.carve_ledges = v
var carve_gullies: float:
	get: return _impl.carve_gullies
	set(v): _impl.carve_gullies = v
## The grid step (m) the caller samples at (land_stream sets its chunk's; 0
## is full detail).
var detail: float:
	get: return _impl.detail
	set(v): _impl.detail = v
var rivers: float:
	get: return _impl.rivers
	set(v): _impl.rivers = v
var river_width: float:
	get: return _impl.river_width
	set(v): _impl.river_width = v
var river_drop: float:
	get: return _impl.river_drop
	set(v): _impl.river_drop = v
var river_cut: float:
	get: return _impl.river_cut
	set(v): _impl.river_cut = v
var river_fill: float:
	get: return _impl.river_fill
	set(v): _impl.river_fill = v
var river_mouth: float:
	get: return _impl.river_mouth
	set(v): _impl.river_mouth = v
var river_flare: float:
	get: return _impl.river_flare
	set(v): _impl.river_flare = v
## What the last `sample` found (see GDField's for each).
var last_mountain: float:
	get: return _impl.last_mountain
var last_inland: float:
	get: return _impl.last_inland
var last_valley: float:
	get: return _impl.last_valley
var last_half: float:
	get: return _impl.last_half
var last_side: float:
	get: return _impl.last_side
var last_across: Vector2:
	get: return _impl.last_across
var last_floor: float:
	get: return _impl.last_floor
var last_cavity: float:
	get: return _impl.last_cavity
var last_ridge: float:
	get: return _impl.last_ridge
## (By a pond, the pond's: it reads as a still river; land_ponds.gd.)
var last_river: float:
	get: return 1000.0 if _t_on else (_p_out if _p_on else _impl.last_river)
var last_river_r: float:
	get: return 1000.0 if _t_on else (_p_r if _p_on else _impl.last_river_r)
var last_river_w: float:
	get: return _p_w if _p_on else _impl.last_river_w
var last_river_y: float:
	get: return _p_y if _p_on else _impl.last_river_y
var last_river_flow: Vector2:
	get: return Vector2.ZERO if _p_on else _impl.last_river_flow

## Ponds (scripts/endless/land_ponds.gd): a layer over either field, cut
## in here after it. `ponds` their density (--ponds=X; 0 none).
const Ponds = preload("res://scripts/endless/land_ponds.gd")
var ponds := 1.0
var _pond_local := {}
## The square the last sample asked about, and its pond.
var _pond_cell := Vector2i(1 << 30,0)
var _pond_here := PackedFloat32Array()
## The last sample's pond, when it was within the pond's reach and nearer
## than any river: distance outside its edge, from its centre, its radius
## that way, its level.
var _p_on := false
var _p_out := INF
var _p_r := 0.0
var _p_w := 0.0
var _p_y := 0.0

## Slot halls (scripts/endless/hall_sites.gd): a cut through the ridges, a
## layer over either field as the ponds are, cut in after them. `halls`
## their density (the world's `halls` layer, --halls=X; 0 none).
const Sites = preload("res://scripts/endless/hall_sites.gd")
var halls := 0.0
var _hall_local := {}
var _hall_cell := Vector2i(1 << 30,0)
var _hall_here := PackedFloat32Array()

## Mountain tunnels (scripts/endless/tunnel_sites.gd): a massif raised over
## a winding bore and its mouths' trenches cut, a layer over either field
## after the ponds and before the slot halls' cut (a hall keeps out of a
## tunnel's box). `tunnels` their density (the world's `tunnels` layer,
## --tunnels=X; 0 none): at most one per Tunnels.CELL square, from the seed
## and the square alone, its box inside the square so a point asks only its
## own square. `--tunnel-test`: the one tunnel ahead of the start instead
## (`_tunnel_sites`, `_tunnel_test`). `_t_on`: the last sample's land was
## lifted (no river there).
const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
var tunnels := 0.0
var _tunnel_sites: Array = []
var _tunnel_test := false
var _tunnel_local := {}
var _tunnel_cell := Vector2i(1 << 30,0)
var _tunnel_here: Array = []
var _t_on := false

func _init(land_seed := 0, profile: RefCounted = null) -> void:
	seed = land_seed
	# The world's recipe and knobs first (the profile `--world=` names unless
	# one is given), then the flags over them.
	world = profile if profile != null else WorldProfile.current()
	var k := _knobs(world.land)
	var want_native := _want_native()
	ponds = 0.0 if k.get("old_land",false) else Ponds.wanted(float(k.get("ponds",1.0)))
	halls = 0.0 if k.get("old_land",false) else Sites.wanted(float(world.layer("halls",0.0)))
	if not world.uniform and world.get("regions") != null:
		_impl = _blend_of(land_seed,want_native)
		_blend = true
	elif want_native and native_available(_need(k)):
		_impl = ClassDB.instantiate(NATIVE_CLASS)
		_impl.configure(land_seed,float(k.floor_half),k)
		_native = true
	else:
		_impl = GDField.new(land_seed,k)
	tunnels = 0.0 if k.get("old_land",false) else Tunnels.wanted(float(world.layer("tunnels",0.0)))
	if tunnels > 0.0 and Tunnels.test_wanted():
		_tunnel_sites = [Tunnels.test_site(_impl,land_seed,world)]
		_tunnel_test = true

## A land recipe with the field's floor and the flags over it.
static func _knobs(land: Dictionary) -> Dictionary:
	var k: Dictionary = land.duplicate()
	k.floor_half = WorldScale.opening(TOY_VALLEY)*0.5
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--mountains="): k.mountains = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--peaks="): k.peaks = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--valleys="): k.valleys = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg == "--no-valleys": k.valleys = 0.0
		elif arg == "--old-land": k.old_land = true
		elif arg == "--no-carve": k.carve = 0.0
		elif arg.begins_with("--carve="): k.carve = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--carve-blocks="): k.carve_blocks = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--carve-ledges="): k.carve_ledges = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--carve-gullies="): k.carve_gullies = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg == "--no-rivers": k.rivers = 0.0
		elif arg.begins_with("--river-width="): k.river_width = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--river-drop="): k.river_drop = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--river-cut="): k.river_cut = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--river-fill="): k.river_fill = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--river-mouth="): k.river_mouth = clampf(float(arg.get_slice("=",1)),0.0,1.0)
		elif arg.begins_with("--river-flare="): k.river_flare = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg == "--land-libm": k.libm = true
	return k

## Whether the flags allow the native field (--land-native=0 or
## --gdscript-kernels: the GDScript one).
static func _want_native() -> bool:
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--land-native=0" or arg == "--gdscript-kernels": return false
	return true

## The regions world's land (land_blend.gd): one field per region's recipe
## (native where built), blended by the region map's weights; a recipe with
## sharp forms (SHARP_KEYS) also grows its soft twin for the band.
func _blend_of(land_seed: int, want_native: bool) -> Object:
	var fields: Array = []
	var natives: Array = []
	var softs: Array = []
	var soft_natives: Array = []
	for p: RefCounted in world.regions:
		var k := _knobs(p.land)
		var f := _field_of(land_seed,k,want_native)
		fields.append(f[0])
		natives.append(f[1])
		var sk := soft_knobs(k)
		if sk.is_empty():
			softs.append(null)
			soft_natives.append(false)
		else:
			f = _field_of(land_seed,sk,want_native)
			softs.append(f[0])
			soft_natives.append(f[1])
	var b: Object = Blend.new(fields,natives,world.map,int(world.start_region),softs,soft_natives)
	# The regions' own layers: a hall or tunnel stands only wholly inside a
	# region whose profile grows it (LandBlend `site_ok`); `--halls=X` /
	# `--tunnels=X` (X > 0) grow them in every region.
	var flagged := {&"halls":Sites.wanted(-1.0) > 0.0,&"tunnels":Tunnels.wanted(-1.0) > 0.0}
	for layer: StringName in flagged:
		var on := PackedByteArray()
		for p: RefCounted in world.regions:
			on.append(1 if bool(flagged[layer]) or float(p.layers.get(String(layer),0.0)) > 0.0 else 0)
		b.layer_on[layer] = on
	return b

## [field, native] for the knobs `k`: the native field where built, else GDField.
static func _field_of(land_seed: int, k: Dictionary, want_native: bool) -> Array:
	if want_native and native_available(_need(k)):
		var f: Object = ClassDB.instantiate(NATIVE_CLASS)
		f.configure(land_seed,float(k.floor_half),k)
		return [f,true]
	return [GDField.new(land_seed,k),false]

## The knobs `k` with the sharp forms (SHARP_KEYS) off, or {} when none is on.
static func soft_knobs(k: Dictionary) -> Dictionary:
	var on := false
	for key: String in SHARP_KEYS:
		if float(k.get(key,0.0)) > 0.0: on = true
	if not on: return {}
	var soft := k.duplicate()
	for key: String in SHARP_KEYS: soft[key] = 0.0
	return soft

## Whether the knobs `k` grow the stock recipe (every recipe key at its
## constant), which a version-1 native library still grows right.
static func _stock(k: Dictionary) -> bool:
	var d := recipe_defaults()
	for key: String in d:
		if k.has(key) and k[key] != d[key]: return false
	return true

## The native library version the knobs `k` need: 1 the stock recipe, 2 a
## recipe of its own, 3 one with the built land's forms (V3_KEYS).
static func _need(k: Dictionary) -> int:
	if _stock(k): return 1
	var d := recipe_defaults()
	for key: String in V3_KEYS:
		if k.has(key) and k[key] != d[key]: return 3
	return 2

## Whether the native field is built and at least version `need` (checked
## once): version 2 takes the world's recipe in `configure`; a version-1
## library (a dylib not yet rebuilt) still grows the stock recipe.
static func native_available(need := 1) -> bool:
	if _native_state >= 0: return _native_state >= need
	_native_lock.lock()
	if _native_state < 0:
		var path := "res://native/terrain_kernels/zenscape_kernels.gdextension"
		if not ClassDB.class_exists(NATIVE_CLASS) and FileAccess.file_exists(path):
			GDExtensionManager.load_extension(path)
		var ok := false
		if ClassDB.class_exists(NATIVE_CLASS):
			var probe: Object = ClassDB.instantiate(NATIVE_CLASS)
			var v := int(probe.version()) if probe.has_method("version") else 0
			ok = v >= 1 and v <= NATIVE_VERSION
			if v < NATIVE_VERSION: push_warning("ZenScapeLandField is version %d, not %d: rebuild it (tools/build_native_kernels.py); %s" % [v,NATIVE_VERSION,"a world with its own land recipe is grown in GDScript" if ok else "the land is grown in GDScript"])
			if ok: _native_state = v
		if _native_state < 0: _native_state = 0
	_native_lock.unlock()
	return _native_state >= need

## Whether this field is the native one.
func native_on() -> bool:
	return _native

## The native field doing the work (ZenScapeLandField), or null: for other
## native kernels that read it directly (ZenScapeTrees, land_trees.gd).
func native_impl() -> Object:
	return _impl if _native else null

## The native field that grows the box (x0, z0)..(x1, z1), or null: in the
## regions world, the region's own where the box lies wholly in one.
func native_impl_in(x0: float, z0: float, x1: float, z1: float) -> Object:
	if not _blend: return native_impl()
	var one: int = _impl.one_in(x0,z0,x1,z1)
	return _impl.kids[one] if one >= 0 and _impl.kid_native[one] else null

## The regions' weights at (x, z) as the land blends them (by region index),
## or empty in a one-region world.
func region_weights(x: float, z: float) -> PackedFloat32Array:
	return _impl.weights(x,z) if _blend else PackedFloat32Array()

## The one region the box (x0, z0)..(x1, z1) lies wholly in (by index), or
## -1 where it reaches the band; 0 in a one-region world.
func region_in(x0: float, z0: float, x1: float, z1: float) -> int:
	return _impl.one_in(x0,z0,x1,z1) if _blend else 0

## Region `r`'s own native field (ZenScapeLandField), or null (GDScript).
func region_impl(r: int) -> Object:
	if not _blend: return native_impl()
	return _impl.kids[r] if _impl.kid_native[r] else null

## The region a dither `u` (0..1) picks at (x, z): the region whose share of
## the land's weights there holds u (so over the band each region's share of
## the picks is its weight); 0 in a one-region world.
func region_pick(x: float, z: float, u: float) -> int:
	if not _blend: return 0
	var w: PackedFloat32Array = _impl.weights(x,z)
	var acc := 0.0
	var last := 0
	for r in w.size():
		if w[r] <= 0.0: continue
		last = r
		acc += w[r]
		if u < acc: return r
	return last

## Vector2(world height, meadow 0..1) at a world XZ point.
func sample(x: float, z: float) -> Vector2:
	_p_on = false
	_t_on = false
	if ponds <= 0.0 and halls <= 0.0 and tunnels <= 0.0: return _impl.sample(x,z)
	# (The square's pond, tunnel and hall first: finding them samples the field.)
	var p := _pond_for(x,z) if ponds > 0.0 else PackedFloat32Array()
	var ts := _tunnels_for(x,z) if tunnels > 0.0 else _NONE
	var s := _hall_for(x,z) if halls > 0.0 else PackedFloat32Array()
	var got: Vector2 = _impl.sample(x,z)
	if not p.is_empty(): got.x = _pond(p,x,z,got.x,float(_impl.last_river))
	if not ts.is_empty(): got = _tunnel(ts,got,x,z)
	if not s.is_empty(): got.x = Sites.carve(s,got.x,x,z)
	return got

## Vector2(height, meadow) `got` with the tunnels' massifs and trenches at
## (x, z): the meadow fades with the lift; `_t_on` where it was lifted.
func _tunnel(ts: Array, got: Vector2, x: float, z: float) -> Vector2:
	for t: RefCounted in ts:
		var ym: Vector2 = Tunnels.carve_m(t,got.x,x,z)
		var y := ym.x
		var d := y-got.x
		if d == 0.0: continue
		got.y = maxf(got.y*Tunnels._meadow_keep(d),Tunnels.SHELF_MEADOW*ym.y)
		if d > 1.0: _t_on = true
		got.x = y
	return got

## The tunnels whose massif or trenches meet the box (x0, z0)..(x1, z1)
## (tunnel_sites.gd's Site).
func tunnels_in(x0: float, z0: float, x1: float, z1: float) -> Array:
	if tunnels <= 0.0: return []
	if _tunnel_test: return Tunnels.sites_in(_tunnel_sites,x0,z0,x1,z1)
	var all: Array = []
	for cj in range(floori(z0/Tunnels.CELL),floori(z1/Tunnels.CELL)+1):
		for ci in range(floori(x0/Tunnels.CELL),floori(x1/Tunnels.CELL)+1):
			all.append_array(Tunnels.cell_sites(_impl,seed,tunnels,Vector2i(ci,cj),_tunnel_local))
	return Tunnels.sites_in(all,x0,z0,x1,z1)

## The tunnels that may touch (x, z): its square's (the last square's
## kept), or the test tunnel.
func _tunnels_for(x: float, z: float) -> Array:
	if _tunnel_test: return _tunnel_sites
	var key := Tunnels.cell_of(x,z)
	if key != _tunnel_cell:
		_tunnel_here = Tunnels.cell_sites(_impl,seed,tunnels,key,_tunnel_local)
		_tunnel_cell = key
	return _tunnel_here

const _NONE: Array = []

## The fixed tunnels this field knows: the --tunnel-test one (streamed ones
## come from `tunnels_in`).
func tunnel_sites() -> Array:
	return _tunnel_sites

## Whether the tunnels are the --tunnel-test one alone.
func tunnel_test() -> bool:
	return _tunnel_test

## The hall site of the square holding (x, z) (the last square's kept).
func _hall_for(x: float, z: float) -> PackedFloat32Array:
	var cx := floori(x/Sites.CELL)
	var cz := floori(z/Sites.CELL)
	if cx != _hall_cell.x or cz != _hall_cell.y:
		_hall_here = Sites.cell_site(_impl,seed,halls,ponds,x,z,_hall_local)
		if tunnels > 0.0 and Tunnels.blocks_hall(_tunnels_for(x,z),_hall_here): _hall_here = PackedFloat32Array()
		_hall_cell = Vector2i(cx,cz)
	return _hall_here

## The hall sites whose cut meets the box (x0, z0)..(x1, z1) (hall_sites.gd's
## arrays).
func halls_in(x0: float, z0: float, x1: float, z1: float) -> Array:
	if halls <= 0.0: return []
	var got := Sites.sites_in(_impl,seed,halls,ponds,x0,z0,x1,z1,_hall_local)
	if tunnels <= 0.0: return got
	return got.filter(func(s: PackedFloat32Array) -> bool: return not Tunnels.blocks_hall(_tunnels_for(s[0],s[1]),s))

## A square's hall for the builder (hall_sites.gd `site_info`), or empty.
func hall_info(key: Vector2i) -> Dictionary:
	if halls <= 0.0: return {}
	var got := Sites.site_info(_impl,seed,halls,ponds,key)
	if not got.is_empty() and tunnels > 0.0 and Tunnels.blocks_hall(_tunnels_for(got.site[0],got.site[1]),got.site): return {}
	return got

## The hall site whose cut holds (x, z) (or comes within `margin` m), or
## an empty array.
func hall_at(x: float, z: float, margin := 0.0) -> PackedFloat32Array:
	if halls <= 0.0: return PackedFloat32Array()
	var s := _hall_for(x,z)
	if s.is_empty() or not Sites.on_cut(s,x,z,margin): return PackedFloat32Array()
	return s

## The pond of the square holding (x, z) (the last square's kept).
func _pond_for(x: float, z: float) -> PackedFloat32Array:
	var cx := floori(x/Ponds.CELL)
	var cz := floori(z/Ponds.CELL)
	if cx != _pond_cell.x or cz != _pond_cell.y:
		_pond_here = Ponds.cell_pond(_impl,seed,ponds,x,z,_pond_local)
		_pond_cell = Vector2i(cx,cz)
	return _pond_here

## Pond `p` cut into `base` at (x, z); its reads set (`_p_*`) where it is
## nearer than the river (`river`, the field's `last_river`).
func _pond(p: PackedFloat32Array, x: float, z: float, base: float, river: float) -> float:
	var e := Ponds.at(p,x,z)
	if e.x >= Ponds.REACH: return base
	if e.x < river:
		_p_on = true
		_p_out = e.x
		_p_r = e.y
		_p_w = e.z
		_p_y = p[3]
	return Ponds.carve(p,base,e) if e.x < Ponds.LIP.y else base

## The ponds whose reach meets the box (x0, z0)..(x1, z1) (land_ponds.gd's
## arrays), for the fish (EndlessFish).
func ponds_in(x0: float, z0: float, x1: float, z1: float) -> Array:
	if ponds <= 0.0: return []
	return Ponds.ponds_in(_impl,seed,ponds,x0,z0,x1,z1,_pond_local)

## The land's shape at a world XZ point: {height, meadow, mountain, inland,
## valley, half, side, across, river, river_r, river_w, river_y}.
func shape(x: float, z: float) -> Dictionary:
	_p_on = false
	_t_on = false
	if ponds <= 0.0 and halls <= 0.0 and tunnels <= 0.0: return _impl.shape(x,z)
	var p := _pond_for(x,z) if ponds > 0.0 else PackedFloat32Array()
	var ts := _tunnels_for(x,z) if tunnels > 0.0 else _NONE
	var h := _hall_for(x,z) if halls > 0.0 else PackedFloat32Array()
	var s: Dictionary = _impl.shape(x,z)
	if not p.is_empty():
		s.height = _pond(p,x,z,float(s.height),float(s.river))
		if _p_on:
			s.river = _p_out
			s.river_r = _p_r
			s.river_w = _p_w
			s.river_y = _p_y
	if not ts.is_empty():
		var got := _tunnel(ts,Vector2(float(s.height),float(s.meadow)),x,z)
		s.height = got.x
		s.meadow = got.y
		if _t_on:
			s.river = 1000.0
			s.river_r = 1000.0
	if not h.is_empty(): s.height = Sites.carve(h,float(s.height),x,z)
	return s

## The river's water level (world y) where a point is on a river's water,
## else NAN.
func river_y(x: float, z: float) -> float:
	if tunnels > 0.0:
		sample(x,z)
		if _t_on: return NAN
	if ponds > 0.0:
		sample(x,z)
		if _p_on: return _p_y if _p_out < 0.0 else NAN
	return _impl.river_y(x,z)

## The river's water as the ground shader draws it, from the last `sample`.
func river_drawn() -> float:
	return _p_y if _p_on else _impl.river_drawn()

## How still the sea's swell lies at the point the last `sample` read.
func calm_here() -> float:
	return _impl.calm_here()

## `calm_here` at a world XZ point.
func sea_calm(x: float, z: float) -> float:
	return _impl.sea_calm(x,z)

## The world height at a world XZ point.
func height(x: float, z: float) -> float:
	if ponds > 0.0 or halls > 0.0 or tunnels > 0.0: return sample(x,z).x
	return _impl.height(x,z)

## The snow line over the sea for this land (round one's under --old-land).
func snow_line() -> float:
	return _impl.snow_line()

## The ground's colour at a world point: its height over the sea, its
## slope (the normal's up) and its meadow.
func colour(x: float, z: float, y: float, up: float, meadow: float) -> Color:
	return _impl.colour(x,z,y,up,meadow)

## land_stream `_build`'s arrays in one call (native, or the same loops in
## GDScript): {verts, normals, colours, carved, river, heights} for
## the chunk at (x0, z0), `cells` quads of `step` m a side, its skirt dropped
## `skirt_drop` m, the river's flow packed at +-flow_max m/s. Sets `detail`
## to `step`.
func build_chunk(x0: float, z0: float, step: float, cells: int, skirt_drop: float, flow_max: float) -> Dictionary:
	var ps: Array = ponds_in(x0,z0,x0+cells*step,z0+cells*step)
	var hs: Array = halls_in(x0,z0,x0+cells*step,z0+cells*step)
	var ts: Array = tunnels_in(x0,z0,x0+cells*step,z0+cells*step)
	var made := _build_chunk(x0,z0,step,cells,skirt_drop,flow_max)
	if not ps.is_empty(): Ponds.apply_chunk(self,_impl,made,ps,x0,z0,step,cells,skirt_drop)
	if not ts.is_empty(): Tunnels.apply_chunk(self,_impl,made,ts,x0,z0,step,cells,skirt_drop)
	if not hs.is_empty(): Sites.apply_chunk(self,_impl,made,hs,x0,z0,step,cells,skirt_drop)
	return made

func _build_chunk(x0: float, z0: float, step: float, cells: int, skirt_drop: float, flow_max: float) -> Dictionary:
	if _native: return _impl.build_chunk(x0,z0,step,cells,skirt_drop,flow_max)
	# The field the loop reads: the GDScript field, or in the regions world the
	# blend, or the region's own where the chunk (and its normals' rim) lies
	# wholly in one (natively when it can).
	var g: Object = _impl
	if _blend:
		var one: int = _impl.one_in(x0-step,z0-step,x0+(cells+1)*step,z0+(cells+1)*step,Blend.lattice_k(step))
		if one >= 0:
			g = _impl.kids[one]
			if _impl.kid_native[one]: return g.build_chunk(x0,z0,step,cells,skirt_drop,flow_max)
		elif _impl.all_native(): return _impl.build_chunk(x0,z0,step,cells,skirt_drop,flow_max)
	g.detail = step
	var n := cells+1
	var w := n+2
	var hs := PackedFloat32Array()
	var ms := PackedFloat32Array()
	var cv := PackedByteArray()
	# The river (last_river_*): signed distance from its line,
	# water half-width, level and flow, per grid point.
	var rv := PackedFloat32Array()
	hs.resize(w*w)
	ms.resize(w*w)
	cv.resize(w*w*2)
	rv.resize(w*w*5)
	for j in w:
		for i in w:
			var got: Vector2 = g.sample(x0+(i-1)*step,z0+(j-1)*step)
			hs[j*w+i] = got.x
			ms[j*w+i] = got.y
			cv[(j*w+i)*2] = int(clampf(g.last_cavity,0.0,1.0)*255.0)
			cv[(j*w+i)*2+1] = int(clampf(g.last_ridge,0.0,1.0)*255.0)
			var q := (j*w+i)*5
			rv[q] = clampf(g.last_river_r,-1000.0,1000.0)
			rv[q+1] = g.last_river_w
			rv[q+2] = g.last_river_y if g.last_river_y > -INF else SEA_Y-100.0
			rv[q+3] = g.last_river_flow.x
			rv[q+4] = g.last_river_flow.y
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var carved := PackedByteArray()
	var river := PackedFloat32Array()
	var heights := PackedFloat32Array()
	verts.resize(n*n+4*n)
	normals.resize(n*n+4*n)
	colours.resize(n*n+4*n)
	carved.resize((n*n+4*n)*4)
	river.resize((n*n+4*n)*3)
	heights.resize(n*n)
	for j in n:
		for i in n:
			var k := (j+1)*w+i+1
			var y := hs[k]
			var nx := hs[k-1]-hs[k+1]
			var nz := hs[k-w]-hs[k+w]
			var normal := Vector3(nx,2.0*step,nz).normalized()
			var v := j*n+i
			verts[v] = Vector3(i*step,y,j*step)
			normals[v] = normal
			# Its alpha the meadow, for the look's ground shader.
			var c: Color = g.colour(x0+i*step,z0+j*step,y,normal.y,ms[k])
			c.a = ms[k]
			colours[v] = c
			# The carve's groove and crest, for the rock (CUSTOM0.xy).
			carved[v*4] = cv[k*2]
			carved[v*4+1] = cv[k*2+1]
			# The flow for the water's ripples (CUSTOM0.zw, flow_max m/s
			# at the ends), and the river (CUSTOM1, floats): its signed
			# distance, half-width (the skirt's negative, so the shader never
			# lifts it to the water) and level.
			carved[v*4+2] = int(clampf(rv[k*5+3]/flow_max*0.5+0.5,0.0,1.0)*255.0)
			carved[v*4+3] = int(clampf(rv[k*5+4]/flow_max*0.5+0.5,0.0,1.0)*255.0)
			river[v*3] = rv[k*5]
			river[v*3+1] = rv[k*5+1]
			river[v*3+2] = rv[k*5+2]
			heights[v] = y
	# The skirt: each edge's vertices again, dropped.
	var drop := skirt_drop
	var edges := [[],[],[],[]]
	for t in n:
		edges[0].append(t)
		edges[1].append(t*n+cells)
		edges[2].append(cells*n+t)
		edges[3].append(t*n)
	for e in 4:
		for t in n:
			var from: int = edges[e][t]
			var v := n*n+e*n+t
			verts[v] = verts[from]-Vector3(0.0,drop,0.0)
			normals[v] = normals[from]
			colours[v] = colours[from]
			carved[v*4] = carved[from*4]
			carved[v*4+1] = carved[from*4+1]
			carved[v*4+2] = carved[from*4+2]
			carved[v*4+3] = carved[from*4+3]
			river[v*3] = river[from*3]
			river[v*3+1] = -river[from*3+1]
			river[v*3+2] = river[from*3+2]
	return {"verts":verts,"normals":normals,"colours":colours,"carved":carved,"river":river,"heights":heights}

## The field over an nx by nz grid of `step` m from (x0, z0), `pad` samples
## before it each way (x = x0+(i-pad)*step): {heights, meadows, river}
## (PackedFloat32Arrays row by row; river is `last_river` at each sample).
func grid(x0: float, z0: float, step: float, nx: int, nz: int, pad := 0) -> Dictionary:
	var ps: Array = ponds_in(x0-pad*step,z0-pad*step,x0+(nx-pad)*step,z0+(nz-pad)*step)
	var hs: Array = halls_in(x0-pad*step,z0-pad*step,x0+(nx-pad)*step,z0+(nz-pad)*step)
	var ts: Array = tunnels_in(x0-pad*step,z0-pad*step,x0+(nx-pad)*step,z0+(nz-pad)*step)
	var got := _grid(x0,z0,step,nx,nz,pad)
	if not ps.is_empty(): Ponds.apply_grid(got,ps,x0,z0,step,nx,nz,pad)
	if not ts.is_empty(): Tunnels.apply_grid(got,ts,x0,z0,step,nx,nz,pad)
	if not hs.is_empty(): Sites.apply_grid(got,hs,x0,z0,step,nx,nz,pad)
	return got

func _grid(x0: float, z0: float, step: float, nx: int, nz: int, pad := 0) -> Dictionary:
	if _native: return _impl.grid(x0,z0,step,nx,nz,pad)
	var g: Object = _impl
	if _blend:
		var one: int = _impl.one_in(x0-pad*step,z0-pad*step,x0+(nx-pad)*step,z0+(nz-pad)*step)
		if one >= 0:
			g = _impl.kids[one]
			if _impl.kid_native[one]: return g.grid(x0,z0,step,nx,nz,pad)
	var hs := PackedFloat32Array()
	var ms := PackedFloat32Array()
	var rs := PackedFloat32Array()
	hs.resize(nx*nz)
	ms.resize(nx*nz)
	rs.resize(nx*nz)
	for j in nz:
		for i in nx:
			var got: Vector2 = g.sample(x0+(i-pad)*step,z0+(j-pad)*step)
			hs[j*nx+i] = got.x
			ms[j*nx+i] = got.y
			rs[j*nx+i] = g.last_river
	return {"heights":hs,"meadows":ms,"river":rs}

## The GDScript field: the land's maths as it always was, the reference the
## native field (native/terrain_kernels/land_field.h) mirrors line for line.
## A change here is a change there (and the other way round).
class GDField extends RefCounted:
	var seed := 0
	## The flags (see the top).
	var mountains := 1.0
	var peaks := 1.0
	var valleys := 1.0
	var old_land := false
	## The land recipe (LandField.recipe_defaults(); the world profile's `land`).
	var r_continent: float = CONTINENT
	var r_continent_swing: float = CONTINENT_SWING
	var r_continent_lift: float = CONTINENT_LIFT
	var r_lowland: float = LOWLAND
	var r_hills: float = HILLS
	var r_hill_tall: float = HILL_TALL
	var r_ranges: float = RANGES
	var r_range_width: float = RANGE_WIDTH
	var r_range_mask: float = RANGE_MASK
	var r_range_band: Vector2 = RANGE_BAND
	var r_warp: float = WARP
	var r_warp_move: float = WARP_MOVE
	var r_ridges: float = RIDGES
	var r_peak_tall: Vector2 = PEAK_TALL
	var r_peak_scale: float = PEAK_SCALE
	var r_meadows: float = MEADOWS
	var r_meadow_band: Vector2 = MEADOW_BAND
	var r_meadow_keep: float = MEADOW_KEEP
	var r_meadow_above: float = MEADOW_ABOVE
	var r_valleys: float = VALLEYS
	var r_valley_warp: float = VALLEY_WARP
	var r_valley_warp_move: float = VALLEY_WARP_MOVE
	var r_valley_swing: Vector2 = VALLEY_SWING
	var r_valley_side: Vector2 = VALLEY_SIDE
	var r_valley_keep: float = VALLEY_KEEP
	var r_snow: float = SNOW
	var r_ridge_crisp: float = RIDGE_CRISP
	var r_notch: float = NOTCH
	var r_notch_scale: float = NOTCH_SCALE
	var r_notch_width: Vector2 = NOTCH_WIDTH
	var r_terrace: float = TERRACE
	var r_terrace_step: float = TERRACE_STEP
	var r_terrace_flat: float = TERRACE_FLAT
	var r_terrace_scale: float = TERRACE_SCALE
	var r_terrace_band: Vector2 = TERRACE_BAND
	var r_mesa: float = MESA
	var r_mesa_tall: float = MESA_TALL
	var r_mesa_scale: float = MESA_SCALE
	var r_mesa_level: float = MESA_LEVEL
	var r_mesa_edge: float = MESA_EDGE
	var r_mesa_steps: float = MESA_STEPS
	var r_mesa_gap: float = MESA_GAP
	var r_mesa_keep: float = MESA_KEEP
	var r_mesa_mask: float = MESA_MASK
	var r_mesa_band: Vector2 = MESA_BAND
	var _notch := FastNoiseLite.new()
	var _terrace := FastNoiseLite.new()
	var _mesa := FastNoiseLite.new()
	var _mesa_mask := FastNoiseLite.new()
	## How much of a mesa stands at the last `_broad` point (0..1), which
	## the carve reads as rock as it reads a range (`_rock`, the larger).
	var _rock := 0.0
	var _continent := FastNoiseLite.new()
	var _hills := FastNoiseLite.new()
	var _mask := FastNoiseLite.new()
	var _ridges := FastNoiseLite.new()
	var _meadows := FastNoiseLite.new()
	var _tint := FastNoiseLite.new()
	var _warp := FastNoiseLite.new()
	var _range := FastNoiseLite.new()
	var _peak := FastNoiseLite.new()
	var _valley := FastNoiseLite.new()
	var _valley_warp := FastNoiseLite.new()
	var _valley_wide := FastNoiseLite.new()
	var _floor_half := WorldScale.opening(TOY_VALLEY)*0.5
	## What the last `sample` found (read by `shape`, for placing things such as
	## the arches, scripts/endless/arch_plan.gd): how much of a range stands
	## there (0..1), how inland it is, the distance to the nearest valley's line
	## (INF where none reaches), that valley's floor half-width and side width,
	## and the way across the valley (XZ, unit).
	var last_mountain := 0.0
	var last_inland := 0.0
	var last_valley := INF
	var last_half := 0.0
	var last_side := 0.0
	var last_across := Vector2.RIGHT
	## The nearest valley's floor (world y; INF where none reaches), read by the
	## valley fog's map (scripts/endless/endless_clouds.gd `fog_image`).
	var last_floor := INF
	## The carve's strength (--carve=X, 1; --no-carve 0) and the grid step (m)
	## the caller samples at (land_stream sets its chunk's; 0 is full detail).
	var carve := 1.0
	## Each form's share (--carve-blocks=, --carve-ledges=, --carve-gullies=; 1).
	var carve_blocks := 1.0
	var carve_ledges := 1.0
	var carve_gullies := 1.0
	var detail := 0.0
	## What the last `sample` carved, for the ground shader (land_stream's
	## CUSTOM0): how deep in a groove or a ledge's inner corner (0..1) and how
	## much on a buttress's crest or a ledge's lip (0..1).
	var last_cavity := 0.0
	var last_ridge := 0.0
	var _floor := -INF
	# The carve's memos (samples come in rows, so neighbours share cells).
	var _bs_key := Vector2i(1<<30,0)
	var _bs_00 := Vector3.ZERO
	var _bs_10 := Vector3.ZERO
	var _bs_01 := Vector3.ZERO
	var _bs_11 := Vector3.ZERO
	var _fc_key := Vector2i(1<<30,0)
	var _fc := PackedFloat32Array()
	var _gc_key: Array[Vector2i] = [Vector2i(1<<30,0),Vector2i(1<<30,0),Vector2i(1<<30,0)]
	var _gc: Array[PackedFloat32Array] = [PackedFloat32Array([0,0,0,0,0,0,0,0]),PackedFloat32Array([0,0,0,0,0,0,0,0]),PackedFloat32Array([0,0,0,0,0,0,0,0])]
	const LAT_SLOTS := 128
	var _node_key := PackedInt64Array()
	var _node_set := PackedByteArray()
	var _node_v := PackedFloat64Array()
	var _h_key := PackedInt64Array()
	var _h_set := PackedByteArray()
	var _h_v := PackedFloat64Array()
	var _bench_warp := FastNoiseLite.new()
	var _bench_band := FastNoiseLite.new()
	var _gully_amp := FastNoiseLite.new()
	## Rivers (see RIVER_*): on (1) or off (--no-rivers 0), and the width and
	## bank knobs.
	var rivers := 1.0
	var river_width := 1.0
	var river_drop := 1.0
	## The floor's full cut and the hollows' fill (1 on, 0 off: the valleys as
	## they were), for the flats check (scratch) and --river-cut= / --river-fill=.
	var river_cut := 1.0
	var river_fill := 1.0
	## The mouths' opening out, deepening and easing (RIVER_MOUTH_*; 1 on, 0 the
	## mouths as before, between a share of it: --river-mouth=X), and the
	## funnel's width (RIVER_FLARE times --river-flare=X, 1).
	var river_mouth := 1.0
	var river_flare := 1.0
	## What the last `sample` found of the river (read by land_stream for the
	## ground shader, the grass, the arches and the flight): the signed
	## distance from the river's middle line (m, INF where no river reaches),
	## the water's half-width (0: no river), the water's level (world y), the
	## distance outside the water's edge (negative in the water, INF none) and
	## the flow (XZ, m/s, downhill along the valley).
	var last_river := INF
	var last_river_r := INF
	var last_river_w := 0.0
	var last_river_y := -INF
	var last_river_flow := Vector2.ZERO
	# The river's bank top (world y) and its strength, for the cut in `sample`.
	var _river_top := -INF
	var _river_k := 0.0
	# The mouth's share (0 upstream, 1 at the sea) and the bed's depth under
	# the water at the middle (RIVER_BED, more at a mouth), for `_river`.
	var _river_mouth := 0.0
	var _river_bed := RIVER_BED
	var _river_side := FastNoiseLite.new()
	var _river_meander := FastNoiseLite.new()
	var _river_wide := FastNoiseLite.new()

	func _init(land_seed: int, k: Dictionary) -> void:
		seed = land_seed
		_floor_half = float(k.get("floor_half",_floor_half))
		mountains = float(k.get("mountains",1.0))
		peaks = float(k.get("peaks",1.0))
		valleys = float(k.get("valleys",1.0))
		old_land = bool(k.get("old_land",false))
		carve = float(k.get("carve",1.0))
		carve_blocks = float(k.get("carve_blocks",1.0))
		carve_ledges = float(k.get("carve_ledges",1.0))
		carve_gullies = float(k.get("carve_gullies",1.0))
		rivers = float(k.get("rivers",1.0))
		river_width = float(k.get("river_width",1.0))
		river_drop = float(k.get("river_drop",1.0))
		river_cut = float(k.get("river_cut",1.0))
		river_fill = float(k.get("river_fill",1.0))
		river_mouth = float(k.get("river_mouth",1.0))
		river_flare = float(k.get("river_flare",1.0))
		r_continent = float(k.get("continent_scale",r_continent))
		r_continent_swing = float(k.get("continent_swing",r_continent_swing))
		r_continent_lift = float(k.get("continent_lift",r_continent_lift))
		r_lowland = float(k.get("lowland",r_lowland))
		r_hills = float(k.get("hill_scale",r_hills))
		r_hill_tall = float(k.get("hill_tall",r_hill_tall))
		r_ranges = float(k.get("range_scale",r_ranges))
		r_range_width = float(k.get("range_width",r_range_width))
		r_range_mask = float(k.get("range_mask_scale",r_range_mask))
		r_range_band = Vector2(k.get("range_band",r_range_band))
		r_warp = float(k.get("warp_scale",r_warp))
		r_warp_move = float(k.get("warp_move",r_warp_move))
		r_ridges = float(k.get("ridge_scale",r_ridges))
		r_peak_tall = Vector2(k.get("peak_tall",r_peak_tall))
		r_peak_scale = float(k.get("peak_scale",r_peak_scale))
		r_meadows = float(k.get("meadow_scale",r_meadows))
		r_meadow_band = Vector2(k.get("meadow_band",r_meadow_band))
		r_meadow_keep = float(k.get("meadow_keep",r_meadow_keep))
		r_meadow_above = float(k.get("meadow_above",r_meadow_above))
		r_valleys = float(k.get("valley_scale",r_valleys))
		r_valley_warp = float(k.get("valley_warp_scale",r_valley_warp))
		r_valley_warp_move = float(k.get("valley_warp_move",r_valley_warp_move))
		r_valley_swing = Vector2(k.get("valley_swing",r_valley_swing))
		r_valley_side = Vector2(k.get("valley_side",r_valley_side))
		r_valley_keep = float(k.get("valley_keep",r_valley_keep))
		r_snow = float(k.get("snow",r_snow))
		r_ridge_crisp = float(k.get("ridge_crisp",r_ridge_crisp))
		r_notch = float(k.get("notch",r_notch))
		r_notch_scale = float(k.get("notch_scale",r_notch_scale))
		r_notch_width = Vector2(k.get("notch_width",r_notch_width))
		r_terrace = float(k.get("terrace",r_terrace))
		r_terrace_step = float(k.get("terrace_step",r_terrace_step))
		r_terrace_flat = float(k.get("terrace_flat",r_terrace_flat))
		r_terrace_scale = float(k.get("terrace_scale",r_terrace_scale))
		r_terrace_band = Vector2(k.get("terrace_band",r_terrace_band))
		r_mesa = float(k.get("mesa",r_mesa))
		r_mesa_tall = float(k.get("mesa_tall",r_mesa_tall))
		r_mesa_scale = float(k.get("mesa_scale",r_mesa_scale))
		r_mesa_level = float(k.get("mesa_level",r_mesa_level))
		r_mesa_edge = float(k.get("mesa_edge",r_mesa_edge))
		r_mesa_steps = float(k.get("mesa_steps",r_mesa_steps))
		r_mesa_gap = float(k.get("mesa_gap",r_mesa_gap))
		r_mesa_keep = float(k.get("mesa_keep",r_mesa_keep))
		r_mesa_mask = float(k.get("mesa_mask_scale",r_mesa_mask))
		r_mesa_band = Vector2(k.get("mesa_band",r_mesa_band))
		_noise(_notch,19,r_notch_scale,1,FastNoiseLite.FRACTAL_NONE)
		_noise(_terrace,20,r_terrace_scale,2,FastNoiseLite.FRACTAL_FBM)
		_noise(_mesa,21,r_mesa_scale,2,FastNoiseLite.FRACTAL_FBM)
		_noise(_mesa_mask,22,r_mesa_mask,1,FastNoiseLite.FRACTAL_NONE)
		_noise(_continent,1,r_continent,3,FastNoiseLite.FRACTAL_FBM)
		_noise(_hills,2,r_hills,4,FastNoiseLite.FRACTAL_FBM)
		_noise(_mask,3,MOUNTAINS if old_land else r_range_mask,2,FastNoiseLite.FRACTAL_FBM)
		_noise(_ridges,4,900.0 if old_land else r_ridges,5,FastNoiseLite.FRACTAL_RIDGED)
		_noise(_meadows,5,r_meadows,2,FastNoiseLite.FRACTAL_FBM)
		_noise(_tint,6,180.0,2,FastNoiseLite.FRACTAL_FBM)
		_noise(_warp,7,r_warp,2,FastNoiseLite.FRACTAL_FBM)
		_noise(_range,8,r_ranges,2,FastNoiseLite.FRACTAL_FBM)
		_noise(_peak,9,r_peak_scale,2,FastNoiseLite.FRACTAL_FBM)
		_noise(_valley,10,r_valleys,2,FastNoiseLite.FRACTAL_FBM)
		_noise(_valley_warp,11,r_valley_warp,1,FastNoiseLite.FRACTAL_NONE)
		_noise(_valley_wide,12,900.0,1,FastNoiseLite.FRACTAL_NONE)
		_noise(_bench_warp,13,BENCH_WANDER,2,FastNoiseLite.FRACTAL_FBM)
		_noise(_bench_band,14,BENCH_BANDS,1,FastNoiseLite.FRACTAL_NONE)
		_noise(_gully_amp,15,1.0,1,FastNoiseLite.FRACTAL_NONE)
		_noise(_river_side,16,RIVER_SIDE,1,FastNoiseLite.FRACTAL_NONE)
		_noise(_river_meander,17,RIVER_MEANDER,1,FastNoiseLite.FRACTAL_NONE)
		_noise(_river_wide,18,RIVER_WIDE,1,FastNoiseLite.FRACTAL_NONE)

	func _noise(n: FastNoiseLite, salt: int, scale: float, octaves: int, kind: int) -> void:
		n.seed = seed*7919+salt*104729
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 1.0/scale
		n.fractal_type = kind
		n.fractal_octaves = octaves

	## Vector2(world height, meadow 0..1) at a world XZ point: the land's
	## broad shape (`_broad`), then the erosion carved into its steep rock
	## (`_carve`).
	func sample(x: float, z: float) -> Vector2:
		if old_land:
			last_river = INF
			last_river_w = 0.0
			return _old_sample(x,z)
		var s := _broad(x,z)
		last_cavity = 0.0
		last_ridge = 0.0
		# The river's, kept through the carve (it samples the broad land round).
		var rr := last_river_r
		var rw := last_river_w
		var ry := last_river_y
		var rf := last_river_flow
		var rtop := _river_top
		var rk := _river_k
		var rm := _river_mouth
		var rb := _river_bed
		# A mesa's walls are carved as a range's are (`_rock`; 0 without mesas).
		var rock := maxf(last_mountain,_rock)
		if carve > 0.0 and rock > CARVE_MOUNTAIN.x and detail < CARVE_DETAIL_OFF:
			# The carve samples the broad land around; `shape` keeps this point's.
			var k_mountain := last_mountain
			var k_inland := last_inland
			var k_valley := last_valley
			var k_half := last_half
			var k_side := last_side
			var k_across := last_across
			s.x = _carve(x,z,s.x,s.y,rock,_floor)
			last_mountain = k_mountain
			last_inland = k_inland
			last_valley = k_valley
			last_half = k_half
			last_side = k_side
			last_across = k_across
		last_river_r = rr
		last_river_w = rw
		last_river_y = ry
		last_river_flow = rf
		_river_top = rtop
		_river_k = rk
		_river_mouth = rm
		_river_bed = rb
		last_river = INF
		if rk > 0.0:
			var reach := rw+RIVER_BANK+RIVER_RAMP+(RIVER_PLAIN.y*RIVER_PLAIN_SPREAD if last_inland < 0.95 else 0.0)
			if absf(rr) < reach: s.x = _river(s.x)
			else: last_river = absf(rr)-rw
		return s

	## The river's channel at a point whose land (after the carve) is `h`
	## (world), from what `_broad` left in last_river_*: by the river the land
	## is raised to the banks' top where a hollow dips under it, then the
	## channel cut: soft banks down to the water, the bed under it. Where the
	## land still falls away under the water (a lake, the coast) the river
	## goes (its half-width to 0), so it ends plainly. Sets `last_river`.
	func _river(h: float) -> float:
		var w := last_river_w
		var s := absf(last_river_r)
		var water := last_river_y
		var top := _river_top
		var drop := top-water
		var core := w+RIVER_BANK
		if s > core+RIVER_RAMP+RIVER_PLAIN.y*RIVER_PLAIN_SPREAD:
			last_river = s-w
			return h
		# The bank raised through a hollow (not at the coast, where the sea takes it).
		var raise := (1.0-smoothstep(core,core+RIVER_RAMP,s))*smoothstep(0.5,3.0,water-SEA_Y)*_river_k
		if h < top and raise > 0.0: h = lerpf(h,top,raise)
		# Land standing over the banks' top by the river (where the valley cuts
		# little, near the coast) is eased down to it, a flood plain; where it
		# stands higher than RIVER_PLAIN the river ends.
		var over := h-top
		if over > 0.0:
			var plain := (1.0-smoothstep(core,core+RIVER_RAMP+over*RIVER_PLAIN_SPREAD,s))*_river_k*(1.0-smoothstep(RIVER_PLAIN.x,RIVER_PLAIN.y,over))*(1.0-smoothstep(0.0,0.15,last_mountain))*(1.0-smoothstep(0.55,0.95,last_inland))
			h -= over*plain
		# Where the land is still under the water, or over the plain, no river.
		var banked := smoothstep(water-2.5,water-0.4,h)*(1.0-smoothstep(RIVER_PLAIN.x*0.6,RIVER_PLAIN.x,h-top))
		w *= banked
		last_river_w = w
		last_river = s-w
		if w <= 0.0: return h
		core = w+RIVER_BANK
		# The cut: the bed under the water, soft banks up to the floor and on
		# up (steeper) where higher land stands by the river.
		var cut: float
		if s < w:
			# At a mouth the bed is deeper and flatter across (the sea fills it).
			var u := s/w
			cut = water-_river_bed*(1.0-pow(u,2.0+2.0*_river_mouth))
		elif s < core:
			var u := (s-w)/RIVER_BANK
			cut = water+drop*u*u*(3.0-2.0*u)
		else:
			var o := s-core
			cut = water+drop+o*(1.0+o*0.04)
		# A coarse chunk's grid can't hold the channel: it fades out there (the
		# ground shader still draws the water, per pixel).
		var keep := 1.0
		if detail > 1.0: keep = smoothstep(2.5,4.5,(core*2.0)/detail)
		if cut < h: h -= (h-cut)*keep*banked
		return h

	## The land before the carve: continents, hills, ranges, meadows, valleys.
	func _broad(x: float, z: float) -> Vector2:
		var base := _continent.get_noise_2d(x,z)*r_continent_swing*2.0+r_continent_lift
		# Inland the continents level off at r_lowland m: the peaks come from
		# the ranges, not from the continents.
		if base > 0.0: base = r_lowland*(1.0-exp(-base/r_lowland))
		var inland := smoothstep(-6.0,18.0,base)
		var hills := _hills.get_noise_2d(x,z)*r_hill_tall*2.0*(0.35+0.65*inland)
		var h := base+hills
		# The ranges: the crest lines of a warped noise, where the mask allows.
		var mountain := 0.0
		last_valley = INF
		last_floor = INF
		last_inland = inland
		_floor = -INF
		if inland > 0.0 and mountains > 0.0:
			var band := r_range_band+Vector2.ONE*(1.0-mountains)*0.35
			var where := smoothstep(band.x,band.y,_mask.get_noise_2d(x,z))*inland
			if where > 0.0:
				var wx := x+_warp.get_noise_2d(x,z)*r_warp_move
				var wz := z+_warp.get_noise_2d(x+7919.0,z-3301.0)*r_warp_move
				var rn := _range.get_noise_2d(wx,wz)
				var off := absf(rn)/r_range_width
				if off < 1.0:
					var crest := 1.0-off
					crest = crest*crest*(3.0-2.0*crest)
					mountain = crest*where
					var tall := lerpf(r_peak_tall.x,r_peak_tall.y,clampf(_peak.get_noise_2d(x,z)*0.9+0.5,0.0,1.0))*peaks
					var ridge := _ridges.get_noise_2d(x,z)*0.5+0.5
					# A massif under the ridged crests; the ridges rise with it.
					var add := tall*(0.4*pow(mountain,1.4)+0.75*ridge*ridge*mountain*mountain)
					if r_ridge_crisp > 0.0:
						# A gable: straight flanks up to a sharp crest (the
						# crest line's own V), the foot eased, the ridges a ripple.
						var a := 1.0-off
						var gable := tall*where*a*smoothstep(0.0,0.35,a)*(0.8+0.35*ridge)
						add = lerpf(add,gable,minf(r_ridge_crisp,1.0))
					if r_notch > 0.0:
						# A notch where a zero line crosses the crest: a flat floor
						# and steep sides; none where the line runs along the crest
						# (the two noises' slopes near parallel).
						var ns := _notch.get_noise_2d(x,z)
						var nn := absf(ns)
						if nn < r_notch_width.y:
							var e := 8.0
							var ngx := _notch.get_noise_2d(x+e,z)-ns
							var ngz := _notch.get_noise_2d(x,z+e)-ns
							var rgx := _range.get_noise_2d(wx+e,wz)-rn
							var rgz := _range.get_noise_2d(wx,wz+e)-rn
							var dn := sqrt((ngx*ngx+ngz*ngz)*(rgx*rgx+rgz*rgz))
							var along := absf(ngx*rgx+ngz*rgz)/dn if dn > 0.0 else 1.0
							add *= 1.0-minf(r_notch,1.0)*(1.0-smoothstep(r_notch_width.x,r_notch_width.y,nn))*(1.0-smoothstep(0.45,0.8,along))
					h += add
		if r_terrace > 0.0 and inland > 0.0:
			# Terraces: treads every r_terrace_step m of height, short risers.
			var tm := smoothstep(r_terrace_band.x,r_terrace_band.y,_terrace.get_noise_2d(x,z))*inland*(1.0-smoothstep(0.3,0.8,mountain))*minf(r_terrace,1.0)
			if tm > 0.0:
				var ty := h/r_terrace_step
				var tf := ty-floorf(ty)
				var stepped := (floorf(ty)+smoothstep(r_terrace_flat,1.0,tf))*r_terrace_step
				h = lerpf(h,stepped,tm)
		var meadow := smoothstep(r_meadow_band.x,r_meadow_band.y,_meadows.get_noise_2d(x,z))*inland*(1.0-smoothstep(0.0,0.35,mountain))
		if meadow > 0.0:
			var flat := maxf(base+hills*r_meadow_keep,r_meadow_above)
			h = lerpf(h,flat,meadow)
		# Mesas: flat tops r_mesa_tall m over the lowland, sheer walls in tiers.
		var mesa := 0.0
		if r_mesa > 0.0 and inland > 0.0:
			var region := smoothstep(r_mesa_band.x,r_mesa_band.y,_mesa_mask.get_noise_2d(x,z))*smoothstep(0.0,0.25,inland)*(1.0-smoothstep(0.05,0.3,mountain))*minf(r_mesa,1.0)
			if region > 0.0:
				# Out of the region they shrink to nothing rather than sink.
				var lv := r_mesa_level+(1.0-region)*1.2
				var mn := _mesa.get_noise_2d(x,z)
				if mn > lv:
					var tiers := maxf(floorf(r_mesa_steps),1.0)
					var wall := 0.0
					for t in int(tiers):
						var at := lv+t*r_mesa_gap
						var st := smoothstep(at,at+r_mesa_edge,mn)
						mesa += st/tiers
						wall = maxf(wall,1.0-absf(2.0*st-1.0))
					var top := base+hills*r_mesa_keep+r_mesa_tall*mesa
					h = lerpf(h,maxf(top,r_meadow_above),minf(mesa*tiers,1.0))
					# The walls bare (no turf), the tops a meadow to land on.
					meadow = maxf(meadow*(1.0-smoothstep(0.0,0.3,wall)),smoothstep(0.9,1.0,mesa)*inland)
		_rock = mesa
		# The valleys: carved along the zero lines of a warped noise, their
		# distance read from the noise over its slope.
		last_river_r = INF
		last_river_w = 0.0
		last_river_y = -INF
		last_river_flow = Vector2.ZERO
		_river_top = -INF
		_river_k = 0.0
		_river_mouth = 0.0
		_river_bed = RIVER_BED
		if inland > 0.0 and valleys > 0.0:
			var vx := x+_valley_warp.get_noise_2d(x,z)*r_valley_warp_move
			var vz := z+_valley_warp.get_noise_2d(x-4111.0,z+2027.0)*r_valley_warp_move
			var v := _valley.get_noise_2d(vx,vz)
			var e := 6.0
			var gx := (_valley.get_noise_2d(vx+e,vz)-v)/e
			var gz := (_valley.get_noise_2d(vx,vz+e)-v)/e
			var d := absf(v)/maxf(sqrt(gx*gx+gz*gz),0.25/r_valleys)
			var half := _floor_half*lerpf(r_valley_swing.x,r_valley_swing.y,clampf(_valley_wide.get_noise_2d(x,z)*0.8+0.5,0.0,1.0))
			# (Through a mesa as steep as through a range: a canyon.)
			var side := lerpf(r_valley_side.x,r_valley_side.y,smoothstep(0.0,0.6,maxf(mountain,mesa)))*maxf(valleys,1.0)
			last_valley = d
			last_half = half
			last_side = side
			if gx*gx+gz*gz > 0.0: last_across = Vector2(gx,gz).normalized()
			var floor_y := maxf(base+hills*r_valley_keep,r_meadow_above)
			last_floor = SEA_Y+floor_y
			if d < half+side:
				var fill := 0.0
				if rivers > 0.0:
					# The river down the floor: its line, width, banks and level,
					# worked out only within its reach of the floor (RIVER_REACH
					# past the floor's edge, more near a coast for the plain).
					var k := smoothstep(0.0,0.12,inland)*minf(valleys,1.0)*minf(rivers,1.0)
					var ds := v/maxf(sqrt(gx*gx+gz*gz),0.25/r_valleys)
					fill = smoothstep(0.5,3.0,base-RIVER_DROP.y*river_drop)*k
					# To one side: its middle near the floor's edge, at the foot of
					# that side (RIVER_HUG of the half-width), so the floor's flat
					# stays whole to land on; it meanders RIVER_SWAY of it and
					# crosses the floor where the side noise turns.
					var reach_r := RIVER_REACH+(RIVER_PLAIN.y*RIVER_PLAIN_SPREAD if inland < 0.95 else 0.0)
					var off := signf(ds)*half*RIVER_HUG
					var far := k <= 0.0 or d > half*(RIVER_HUG+2.0*RIVER_SWAY)+reach_r
					if not far:
						var pick := _river_side.get_noise_2d(x,z)*4.0
						pick = pick/sqrt(1.0+pick*pick)
						off = half*(pick*RIVER_HUG+_river_meander.get_noise_2d(x,z)*2.0*RIVER_SWAY*absf(pick))
						far = absf(ds-off) > reach_r
					if far:
						# Past its reach: the way to it in the noise's units, a mean
						# width and the level, so a coarse chunk's triangles
						# spanning out to here still draw the river where it is.
						last_river_r = ds-off
						var mean_mouth := _mouth(base-RIVER_DROP.y*river_drop)
						last_river_w = (RIVER_WIDTH.x+RIVER_WIDTH.y)*0.25*river_width*k*(1.0+RIVER_FLARE*river_flare*mean_mouth*mean_mouth*minf(river_mouth,1.0))
						last_river_y = SEA_Y+_mouth_level(base-RIVER_DROP.y*river_drop)
					else:
						var wide := clampf(_river_wide.get_noise_2d(x,z)*0.9+0.5,0.0,1.0)
						# Plus a closer swell and pinch, so no stretch runs even.
						var pinch := 1.0+RIVER_PINCH*_river_wide.get_noise_2d(x*RIVER_WIDE/RIVER_PINCH_SIZE+911.0,z*RIVER_WIDE/RIVER_PINCH_SIZE-377.0)
						var w := lerpf(RIVER_WIDTH.x,RIVER_WIDTH.y,wide)*river_width*0.5*k*pinch
						var drop := lerpf(RIVER_DROP.x,RIVER_DROP.y,wide)*river_drop
						# Near the sea it opens out (a funnel, widest at the sea).
						var mouth := _mouth(base-drop)
						var flare := 1.0+RIVER_FLARE*river_flare*mouth*mouth*minf(river_mouth,1.0)
						w *= flare
						# The floor is laid out in the warped noise's units (`d`); the
						# river's width is held in the world's: the world's slope of
						# the noise gives the scale between them (the warp's
						# stretch, the floor's clamped slope), so it keeps its width
						# round bends and stays on the floor.
						var gw := maxf(sqrt(gx*gx+gz*gz),0.25/r_valleys)
						var scale := 1.0
						var along := Vector2(-gz,gx)/gw
						var wg := Vector2(_valley_at(x+4.0,z)-v,_valley_at(x,z+4.0)-v)*0.25
						var wl := wg.length()
						if wl > 1e-7:
							scale = clampf(gw/wl,0.25,4.0)
							along = Vector2(-wg.y,wg.x)/wl
						# The signed distance from its line, in world metres.
						var r := (ds-off)*scale
						var s := absf(r)
						# The level: the lowland's under the valley, never under the sea.
						var top := maxf(base,r_meadow_above)
						var water := _mouth_level(base-drop)
						# By the river the floor is the banks' top (the hills' bumps out).
						var near := (1.0-smoothstep(w+RIVER_BANK,w+RIVER_BANK+RIVER_RAMP,s))*k
						floor_y = lerpf(floor_y,top,near)
						last_river_r = r
						last_river_w = w
						last_river_y = SEA_Y+water
						_river_top = SEA_Y+top
						_river_k = k
						_river_mouth = mouth
						_river_bed = RIVER_BED+RIVER_MOUTH_DEEP*mouth*minf(river_mouth,1.0)
						if s < w+RIVER_BANK+16.0 and water > 0.0:
							# The flow: downhill along the valley, as fast as the
							# level falls.
							var fall := (_lowland(x-along.x*30.0,z-along.y*30.0)-_lowland(x+along.x*30.0,z+along.y*30.0))/60.0
							var speed := (RIVER_FLOW.x+sqrt(absf(fall))*RIVER_FLOW.y)/flare
							last_river_flow = along*clampf(fall/RIVER_STILL,-1.0,1.0)*speed
				_floor = SEA_Y+floor_y
				last_floor = _floor
				var t := clampf((d-half)/side,0.0,1.0)
				# U-shaped: flat floor, the sides steepening up off it.
				var keep := t*t*(3.0-2.0*t)
				# With rivers the floor's cut comes in fully by a lower `inland`
				# (RIVER_INLAND), so the floor a river runs on is the floor's
				# level everywhere, not the ranges' foot left standing near a
				# coast (it would hold the river under walls and run it uphill);
				# up the sides it goes back to the cut as it was by
				# RIVER_CUT_SIDE of their width.
				var cut_in := inland
				if rivers > 0.0 and river_cut > 0.0:
					var tc := clampf((d-half)/(side*RIVER_CUT_SIDE),0.0,1.0)
					cut_in = lerpf(inland,lerpf(smoothstep(0.0,RIVER_INLAND,inland),inland,tc*tc*(3.0-2.0*tc)),minf(river_cut,1.0))
				keep = lerpf(1.0,keep,minf(valleys,1.0)*cut_in)
				if h > floor_y: h = floor_y+(h-floor_y)*keep
				elif fill > 0.0 and river_fill > 0.0:
					# A hollow under the floor filled up to it, out to
					# RIVER_FILL_SIDE m past the floor.
					var tf := clampf((d-half)/RIVER_FILL_SIDE,0.0,1.0)
					var keep_f := lerpf(1.0,tf*tf*(3.0-2.0*tf),minf(valleys,1.0)*cut_in)
					h = lerpf(h,floor_y+(h-floor_y)*keep_f,fill*minf(river_fill,1.0))
				var floor_meadow := (1.0-smoothstep(half*0.7,half+side*0.2,d))*inland*minf(valleys,1.0)
				meadow = maxf(meadow,floor_meadow)
		# The coast: the land eases flat into the sea (a beach), not a step.
		if absf(h) < BEACH*2.0: h = h*lerpf(0.45,1.0,smoothstep(0.0,BEACH*2.0,absf(h)))
		last_mountain = mountain
		return Vector2(SEA_Y+h,meadow)

	## How far into its mouth a river is whose level, unclamped, stands `lv` m
	## over the sea: 0 upstream, 1 at the sea and past it (RIVER_MOUTH_RISE).
	func _mouth(lv: float) -> float:
		if river_mouth <= 0.0: return 0.0
		return 1.0-smoothstep(0.0,RIVER_MOUTH_RISE,lv)

	## A river's level (m over the sea) from its unclamped `lv`: never under
	## the sea, and at a mouth easing into it flat (RIVER_MOUTH_EASE; a soft
	## floor, the same as `maxf(lv,0)` past the ease either side).
	func _mouth_level(lv: float) -> float:
		if river_mouth <= 0.0: return maxf(lv,0.0)
		var e := RIVER_MOUTH_EASE
		if lv >= e: return lv
		if lv <= -e: return 0.0
		return (lv+e)*(lv+e)/(4.0*e)

	## The continents' level (m over the sea) at a point, as `_broad` starts.
	func _lowland(x: float, z: float) -> float:
		var b := _continent.get_noise_2d(x,z)*r_continent_swing*2.0+r_continent_lift
		if b > 0.0: b = r_lowland*(1.0-exp(-b/r_lowland))
		return b

	## The valley noise at a world point, through its warp (as `_broad` reads it).
	func _valley_at(x: float, z: float) -> float:
		var vx := x+_valley_warp.get_noise_2d(x,z)*r_valley_warp_move
		var vz := z+_valley_warp.get_noise_2d(x-4111.0,z+2027.0)*r_valley_warp_move
		return _valley.get_noise_2d(vx,vz)

	## --- The carve -------------------------------------------------------------

	## The broad land's height and slope at lattice node (i, j), cached:
	## Vector3(world height, d/dx, d/dz). The caches are direct-mapped on
	## LAT_SLOTS^2 slots (a chunk spans fewer nodes, so it never evicts its own).
	func _node(i: int, j: int) -> Vector3:
		var slot := (i&(LAT_SLOTS-1))+(j&(LAT_SLOTS-1))*LAT_SLOTS
		var key := (i<<32)^(j&0xFFFFFFFF)
		if _node_key[slot] == key and _node_set[slot] == 1:
			return Vector3(_node_v[slot*3],_node_v[slot*3+1],_node_v[slot*3+2])
		var g := CARVE_GRID
		var hx0 := _lat_h(i-1,j)
		var hx1 := _lat_h(i+1,j)
		var hz0 := _lat_h(i,j-1)
		var hz1 := _lat_h(i,j+1)
		var v := Vector3(_lat_h(i,j),(hx1-hx0)/(2.0*g),(hz1-hz0)/(2.0*g))
		_node_key[slot] = key
		_node_set[slot] = 1
		_node_v[slot*3] = v.x
		_node_v[slot*3+1] = v.y
		_node_v[slot*3+2] = v.z
		return v

	func _lat_h(i: int, j: int) -> float:
		var slot := (i&(LAT_SLOTS-1))+(j&(LAT_SLOTS-1))*LAT_SLOTS
		var key := (i<<32)^(j&0xFFFFFFFF)
		if _h_key[slot] == key and _h_set[slot] == 1: return _h_v[slot]
		var h := _broad(i*CARVE_GRID,j*CARVE_GRID).x
		_h_key[slot] = key
		_h_set[slot] = 1
		_h_v[slot] = h
		return h

	## The broad land's height and slope at any point, eased between the
	## lattice's nodes: Vector3(height, d/dx, d/dz).
	func _broad_slope(x: float, z: float) -> Vector3:
		if _h_set.is_empty():
			var slots := LAT_SLOTS*LAT_SLOTS
			_node_key.resize(slots)
			_node_set.resize(slots)
			_node_v.resize(slots*3)
			_h_key.resize(slots)
			_h_set.resize(slots)
			_h_v.resize(slots)
		var fx := x/CARVE_GRID
		var fz := z/CARVE_GRID
		var i := floori(fx)
		var j := floori(fz)
		var u := fx-i
		var v := fz-j
		if i != _bs_key.x or j != _bs_key.y:
			_bs_key = Vector2i(i,j)
			_bs_00 = _node(i,j)
			_bs_10 = _node(i+1,j)
			_bs_01 = _node(i,j+1)
			_bs_11 = _node(i+1,j+1)
		return _bs_00.lerp(_bs_10,u).lerp(_bs_01.lerp(_bs_11,u),v)

	## The 3x3 block cells round cell (ci, cj), each (x, z, height, slope x,
	## slope z, lift), kept while the samples stay in that cell.
	func _facet_cells(ci: int, cj: int, salt: int) -> PackedFloat32Array:
		if ci == _fc_key.x and cj == _fc_key.y: return _fc
		_fc_key = Vector2i(ci,cj)
		_fc.resize(54)
		var n := 0
		for dj in range(-1,2):
			for di in range(-1,2):
				var hh := _hash(ci+di,cj+dj,salt)
				var cx := (ci+di+0.1+0.8*_rand(hh,1))*FACET_CELL
				var cz := (cj+dj+0.1+0.8*_rand(hh,2))*FACET_CELL
				var c := _broad_slope(cx,cz)
				var cg := Vector2(c.y,c.z)
				var cl := cg.length()
				cg += Vector2(_rand(hh,3)-0.5,_rand(hh,4)-0.5)*2.0*FACET_TILT*cl
				_fc[n] = cx
				_fc[n+1] = cz
				_fc[n+2] = c.x
				_fc[n+3] = cg.x
				_fc[n+4] = cg.y
				_fc[n+5] = (_rand(hh,5)-0.5)*2.0*FACET_STEP*smoothstep(0.2,0.8,cl)
				n += 6
		return _fc

	## Gully size `o`'s four lattice corners round (i, j), each (wave number,
	## phase), kept while the samples stay in that cell.
	func _gully_cells(o: int, i: int, j: int, salt: int) -> PackedFloat32Array:
		var got: PackedFloat32Array = _gc[o]
		if _gc_key[o] == Vector2i(i,j): return got
		_gc_key[o] = Vector2i(i,j)
		var size: float = GULLIES[o].x
		for c in 4:
			var hh := _hash(i+(c&1),j+(c>>1),salt+o*1013)
			got[c*2] = TAU/(size*(1.0+(_rand(hh,1)-0.5)*2.0*GULLY_JITTER))
			got[c*2+1] = _rand(hh,2)*TAU
		return got

	static func _hash(i: int, j: int, salt: int) -> int:
		var h := (i*73856093)^(j*19349663)^(salt*83492791)
		h = (h^(h>>13))*1274126177
		h = (h^(h>>16))*1103515245
		return (h^(h>>15))&0xFFFFFF

	static func _rand(h: int, k: int) -> float:
		return float(((h*(k*2654435761+1))>>7)&0xFFFF)/65535.0

	## How much of a size (m) the chunk's grid can show.
	func _keep(size: float) -> float:
		if detail <= 1.0: return 1.0
		return smoothstep(CARVE_FADE.x,CARVE_FADE.y,size/detail)

	## The carved height at a point whose broad height is `h` (world).
	func _carve(x: float, z: float, h: float, meadow: float, mountain: float, floor_y: float) -> float:
		var bs := _broad_slope(x,z)
		var slope := Vector2(bs.y,bs.z)
		var steep := slope.length()
		var mask := smoothstep(CARVE_SLOPE.x,CARVE_SLOPE.y,steep)*smoothstep(CARVE_MOUNTAIN.x,CARVE_MOUNTAIN.y,mountain)*(1.0-smoothstep(0.2,0.5,meadow))*minf(carve,2.0)
		if mask <= 0.0: return h
		var salt := seed*31+7
		# Blocks: each Voronoi cell's own plane.
		var fk := _keep(FACET_CELL)*FACET_KEEP*minf(mask,1.0)*minf(carve_blocks,1.0/FACET_KEEP)
		var g := slope
		if fk > 0.0:
			var cells := _facet_cells(floori(x/FACET_CELL),floori(z/FACET_CELL),salt)
			var sum := 0.0
			var plane := 0.0
			var gsx := 0.0
			var gsz := 0.0
			for n in range(0,54,6):
				var dx := x-cells[n]
				var dz := z-cells[n+1]
				var w := exp(-FACET_EDGE*(dx*dx+dz*dz))
				if w < 1e-3: continue
				plane += w*(cells[n+2]+cells[n+3]*dx+cells[n+4]*dz+cells[n+5])
				gsx += w*cells[n+3]
				gsz += w*cells[n+4]
				sum += w
			var gsum := Vector2(gsx,gsz)
			if sum > 0.0:
				h = lerpf(h,plane/sum,fk)
				g = g.lerp(gsum/sum,fk)
		# Ledges: benches cut back into the face where the band allows.
		var bk := minf(_keep(BENCH)*mask*smoothstep(0.2,0.55,_bench_band.get_noise_2d(x,z))*carve_ledges,1.0)
		if bk > 0.0:
			var warp := _bench_warp.get_noise_2d(x,z)*BENCH*BENCH_WARP
			var y := (h-SEA_Y+warp)/BENCH
			var f := y-floorf(y)
			var stepped := (floorf(y)+smoothstep(BENCH_FLAT,1.0,f))*BENCH-warp+SEA_Y
			h = lerpf(h,stepped,bk)
			# The inner corner under the riser, the lip over the one below.
			last_cavity = maxf(last_cavity,bk*(1.0-smoothstep(0.0,0.18,absf(f-BENCH_FLAT-0.04))))
			last_ridge = maxf(last_ridge,bk*(1.0-smoothstep(0.0,0.1,minf(f,1.0-f)))*0.8)
		# Gullies down the fall line, biggest first; each size follows the
		# slope the last one left.
		for o in GULLIES.size():
			var gl: Vector2 = GULLIES[o]
			var gk := _keep(gl.x)*mask*carve_gullies
			if gk <= 0.0: continue
			var glen := g.length()
			if glen < 1e-4: break
			var down := g/glen
			var across := Vector2(-down.y,down.x)
			var lx := x/gl.x
			var lz := z/gl.x
			var i := floori(lx)
			var j := floori(lz)
			var u := lx-i
			var v := lz-j
			u = u*u*u*(u*(u*6.0-15.0)+10.0)
			v = v*v*v*(v*(v*6.0-15.0)+10.0)
			# The four corners' waves, unrolled (the hot loop of a chunk build).
			var corner := _gully_cells(o,i,j,salt)
			var sz := gl.x
			var base := x*across.x+z*across.y-sz*(i*across.x+j*across.y)
			var a0 := base*corner[0]+corner[1]
			var a1 := (base-sz*across.x)*corner[2]+corner[3]
			var a2 := (base-sz*across.y)*corner[4]+corner[5]
			var a3 := (base-sz*(across.x+across.y))*corner[6]+corner[7]
			var w0 := (1.0-u)*(1.0-v)
			var w1 := u*(1.0-v)
			var w2 := (1.0-u)*v
			var w3 := u*v
			var wave := w0*cos(a0)+w1*cos(a1)+w2*cos(a2)+w3*cos(a3)
			var dwave := -(w0*sin(a0)*corner[0]+w1*sin(a1)*corner[2]+w2*sin(a2)*corner[4]+w3*sin(a3)*corner[6])
			# Gullies start and stop along their run.
			var amp := smoothstep(-0.25,0.35,_gully_amp.get_noise_2d(x/sz*0.35+o*97.0,z/sz*0.35-o*61.0))
			if amp <= 0.0: continue
			var groove := clampf((1.0-wave)*0.5,0.0,1.0)
			var gp1 := pow(groove,GULLY_SHARP-1.0)
			var gp := gp1*groove
			var depth := gl.y*gk*amp*clampf(steep,0.6,1.6)
			var weight: float = GULLY_SHADE[o]*gk*amp
			var rim := 1.0-groove
			last_cavity = maxf(last_cavity,weight*gp)
			last_ridge = maxf(last_ridge,weight*rim*rim*rim)
			h -= depth*gp
			g += across*(depth*GULLY_SHARP*gp1*0.5*dwave)
		if floor_y > -INF: h = maxf(h,floor_y)
		return h

	## Round one's land (--old-land), exactly.
	func _old_sample(x: float, z: float) -> Vector2:
		var base := _continent.get_noise_2d(x,z)*r_continent_swing*2.0+r_continent_lift
		if base > 0.0: base = r_lowland*(1.0-exp(-base/r_lowland))
		var inland := smoothstep(-6.0,18.0,base)
		var h := base+_hills.get_noise_2d(x,z)*r_hill_tall*2.0*(0.35+0.65*inland)
		var mountain := smoothstep(MOUNTAIN_BAND.x,MOUNTAIN_BAND.y,_mask.get_noise_2d(x,z))*inland
		if mountain > 0.0:
			var ridge := _ridges.get_noise_2d(x,z)*0.5+0.5
			h += ridge*ridge*MOUNTAIN_TALL*mountain
		var meadow := smoothstep(r_meadow_band.x,r_meadow_band.y,_meadows.get_noise_2d(x,z))*inland*(1.0-mountain)
		if meadow > 0.0:
			var flat := maxf(base+(h-base)*r_meadow_keep,r_meadow_above)
			h = lerpf(h,flat,meadow)
		if absf(h) < BEACH*2.0: h = h*lerpf(0.45,1.0,smoothstep(0.0,BEACH*2.0,absf(h)))
		return Vector2(SEA_Y+h,meadow)

	## The land's shape at a world XZ point: {height, meadow, mountain, inland,
	## valley (distance to a valley's line, INF where none reaches), half, side,
	## across} (see `last_mountain`). Round one's land has no ranges or valleys.
	func shape(x: float, z: float) -> Dictionary:
		last_mountain = 0.0
		last_valley = INF
		last_inland = 0.0
		var s := sample(x,z)
		return {"height":s.x,"meadow":s.y,"mountain":last_mountain,"inland":last_inland,"valley":last_valley,"half":last_half,"side":last_side,"across":last_across,
			"river":last_river,"river_r":last_river_r,"river_w":last_river_w,"river_y":last_river_y}

	## The river's water level (world y) where a point is on a river's water,
	## else NAN (the sea is not a river: the estuary's level is the sea's).
	func river_y(x: float, z: float) -> float:
		sample(x,z)
		if last_river < 0.0 and river_drawn() > SEA_Y+0.05: return river_drawn()
		return NAN

	## The river's water as the ground shader draws it, from the last `sample`
	## (world y): its level, sunk under the sea's at a mouth (RIVER_MOUTH_SINK).
	func river_drawn() -> float:
		if river_mouth <= 0.0 or last_river_y == -INF: return last_river_y
		var over := last_river_y-SEA_Y
		return last_river_y-(RIVER_BED+RIVER_MOUTH_DEEP)*minf(river_mouth,1.0)*(1.0-smoothstep(0.0,RIVER_MOUTH_SINK,over))

	## How still the sea's swell lies at the point the last `sample` read: 1 in
	## a river's channel and just past its edge (the sea reaching up a mouth
	## lies calm there), 0 off it or with --river-mouth=0. The sea's depth map
	## carries it (EndlessSea), and the flight's skim reads it (`sea_calm`).
	func calm_here() -> float:
		if river_mouth <= 0.0 or rivers <= 0.0 or last_river_w <= 0.0: return 0.0
		return smoothstep(0.5,3.0,last_river_w)*(1.0-smoothstep(2.0,12.0,last_river))

	## `calm_here` at a world XZ point.
	func sea_calm(x: float, z: float) -> float:
		sample(x,z)
		return calm_here()

	## The world height at a world XZ point.
	func height(x: float, z: float) -> float:
		return sample(x,z).x

	## The snow line over the sea for this land (round one's under --old-land).
	func snow_line() -> float:
		return 95.0 if old_land else r_snow

	## The ground's colour at a world point: its height over the sea, its
	## slope (the normal's up) and its meadow.
	func colour(x: float, z: float, y: float, up: float, meadow: float) -> Color:
		var over := y-SEA_Y
		if over < -0.5: return SEABED.lerp(SAND,clampf(1.0+over/6.0,0.0,1.0))
		var grass := GRASS.lerp(GRASS_DRY,clampf(_tint.get_noise_2d(x,z)*0.9+0.45,0.0,1.0))
		grass = grass.lerp(MEADOW,meadow)
		var c := SAND.lerp(grass,smoothstep(BEACH*0.6,BEACH*1.4,over))
		c = c.lerp(ROCK,smoothstep(0.86,0.72,up))
		var snow := snow_line()
		if over > snow-12.0: c = c.lerp(SNOW_COLOUR,smoothstep(snow-12.0,snow+6.0,over)*smoothstep(0.62,0.8,up))
		return c
