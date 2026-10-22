extends RefCounted
## The endless land's field: its height, its meadows and its colour at any
## world XZ point, from a seed alone, so the same seed always grows the same
## land (docs/design/endless-flight/round-1-handoff.md,
## terrain-shape-handoff.md). Plain maths over FastNoiseLite; each worker
## builds its own field (`new(seed)`), so chunks are made off the main
## thread without sharing one.
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

const WorldScale = preload("res://scripts/world_scale.gd")

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

const SAND := Color(0.80,0.74,0.56)
const SEABED := Color(0.42,0.46,0.40)
const GRASS := Color(0.30,0.48,0.20)
const GRASS_DRY := Color(0.46,0.54,0.24)
const MEADOW := Color(0.52,0.64,0.28)
const ROCK := Color(0.47,0.44,0.40)
const SNOW_COLOUR := Color(0.93,0.94,0.97)

var seed := 0
## The flags (see the top).
var mountains := 1.0
var peaks := 1.0
var valleys := 1.0
var old_land := false
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
var _river_side := FastNoiseLite.new()
var _river_meander := FastNoiseLite.new()
var _river_wide := FastNoiseLite.new()

func _init(land_seed := 0) -> void:
	seed = land_seed
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--mountains="): mountains = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--peaks="): peaks = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--valleys="): valleys = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg == "--no-valleys": valleys = 0.0
		elif arg == "--old-land": old_land = true
		elif arg == "--no-carve": carve = 0.0
		elif arg.begins_with("--carve="): carve = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--carve-blocks="): carve_blocks = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--carve-ledges="): carve_ledges = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--carve-gullies="): carve_gullies = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg == "--no-rivers": rivers = 0.0
		elif arg.begins_with("--river-width="): river_width = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--river-drop="): river_drop = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--river-cut="): river_cut = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--river-fill="): river_fill = maxf(0.0,float(arg.get_slice("=",1)))
	_noise(_continent,1,CONTINENT,3,FastNoiseLite.FRACTAL_FBM)
	_noise(_hills,2,HILLS,4,FastNoiseLite.FRACTAL_FBM)
	_noise(_mask,3,MOUNTAINS if old_land else RANGE_MASK,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_ridges,4,900.0 if old_land else RIDGES,5,FastNoiseLite.FRACTAL_RIDGED)
	_noise(_meadows,5,MEADOWS,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_tint,6,180.0,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_warp,7,WARP,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_range,8,RANGES,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_peak,9,PEAK_SCALE,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_valley,10,VALLEYS,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_valley_warp,11,VALLEY_WARP,1,FastNoiseLite.FRACTAL_NONE)
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
	if carve > 0.0 and last_mountain > CARVE_MOUNTAIN.x and detail < CARVE_DETAIL_OFF:
		# The carve samples the broad land around; `shape` keeps this point's.
		var k_mountain := last_mountain
		var k_inland := last_inland
		var k_valley := last_valley
		var k_half := last_half
		var k_side := last_side
		var k_across := last_across
		s.x = _carve(x,z,s.x,s.y,k_mountain,_floor)
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
		var u := s/w
		cut = water-RIVER_BED*(1.0-u*u)
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
	var base := _continent.get_noise_2d(x,z)*CONTINENT_SWING*2.0+CONTINENT_LIFT
	# Inland the continents level off at LOWLAND m: the peaks come from
	# the ranges, not from the continents.
	if base > 0.0: base = LOWLAND*(1.0-exp(-base/LOWLAND))
	var inland := smoothstep(-6.0,18.0,base)
	var hills := _hills.get_noise_2d(x,z)*HILL_TALL*2.0*(0.35+0.65*inland)
	var h := base+hills
	# The ranges: the crest lines of a warped noise, where the mask allows.
	var mountain := 0.0
	last_valley = INF
	last_inland = inland
	_floor = -INF
	if inland > 0.0 and mountains > 0.0:
		var band := RANGE_BAND+Vector2.ONE*(1.0-mountains)*0.35
		var where := smoothstep(band.x,band.y,_mask.get_noise_2d(x,z))*inland
		if where > 0.0:
			var wx := x+_warp.get_noise_2d(x,z)*WARP_MOVE
			var wz := z+_warp.get_noise_2d(x+7919.0,z-3301.0)*WARP_MOVE
			var off := absf(_range.get_noise_2d(wx,wz))/RANGE_WIDTH
			if off < 1.0:
				var crest := 1.0-off
				crest = crest*crest*(3.0-2.0*crest)
				mountain = crest*where
				var tall := lerpf(PEAK_TALL.x,PEAK_TALL.y,clampf(_peak.get_noise_2d(x,z)*0.9+0.5,0.0,1.0))*peaks
				var ridge := _ridges.get_noise_2d(x,z)*0.5+0.5
				# A massif under the ridged crests; the ridges rise with it.
				h += tall*(0.4*pow(mountain,1.4)+0.75*ridge*ridge*mountain*mountain)
	var meadow := smoothstep(MEADOW_BAND.x,MEADOW_BAND.y,_meadows.get_noise_2d(x,z))*inland*(1.0-smoothstep(0.0,0.35,mountain))
	if meadow > 0.0:
		var flat := maxf(base+hills*MEADOW_KEEP,MEADOW_ABOVE)
		h = lerpf(h,flat,meadow)
	# The valleys: carved along the zero lines of a warped noise, their
	# distance read from the noise over its slope.
	last_river_r = INF
	last_river_w = 0.0
	last_river_y = -INF
	last_river_flow = Vector2.ZERO
	_river_top = -INF
	_river_k = 0.0
	if inland > 0.0 and valleys > 0.0:
		var vx := x+_valley_warp.get_noise_2d(x,z)*VALLEY_WARP_MOVE
		var vz := z+_valley_warp.get_noise_2d(x-4111.0,z+2027.0)*VALLEY_WARP_MOVE
		var v := _valley.get_noise_2d(vx,vz)
		var e := 6.0
		var gx := (_valley.get_noise_2d(vx+e,vz)-v)/e
		var gz := (_valley.get_noise_2d(vx,vz+e)-v)/e
		var d := absf(v)/maxf(sqrt(gx*gx+gz*gz),0.25/VALLEYS)
		var half := _floor_half*lerpf(VALLEY_SWING.x,VALLEY_SWING.y,clampf(_valley_wide.get_noise_2d(x,z)*0.8+0.5,0.0,1.0))
		var side := lerpf(VALLEY_SIDE.x,VALLEY_SIDE.y,smoothstep(0.0,0.6,mountain))*maxf(valleys,1.0)
		last_valley = d
		last_half = half
		last_side = side
		if gx*gx+gz*gz > 0.0: last_across = Vector2(gx,gz).normalized()
		if d < half+side:
			var floor_y := maxf(base+hills*VALLEY_KEEP,MEADOW_ABOVE)
			var fill := 0.0
			if rivers > 0.0:
				# The river down the floor: its line, width, banks and level,
				# worked out only within its reach of the floor (RIVER_REACH
				# past the floor's edge, more near a coast for the plain).
				var k := smoothstep(0.0,0.12,inland)*minf(valleys,1.0)*minf(rivers,1.0)
				var ds := v/maxf(sqrt(gx*gx+gz*gz),0.25/VALLEYS)
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
					last_river_w = (RIVER_WIDTH.x+RIVER_WIDTH.y)*0.25*river_width*k
					last_river_y = SEA_Y+maxf(base-RIVER_DROP.y*river_drop,0.0)
				else:
					var wide := clampf(_river_wide.get_noise_2d(x,z)*0.9+0.5,0.0,1.0)
					# Plus a closer swell and pinch, so no stretch runs even.
					var pinch := 1.0+RIVER_PINCH*_river_wide.get_noise_2d(x*RIVER_WIDE/RIVER_PINCH_SIZE+911.0,z*RIVER_WIDE/RIVER_PINCH_SIZE-377.0)
					var w := lerpf(RIVER_WIDTH.x,RIVER_WIDTH.y,wide)*river_width*0.5*k*pinch
					var drop := lerpf(RIVER_DROP.x,RIVER_DROP.y,wide)*river_drop
					# The floor is laid out in the warped noise's units (`d`); the
					# river's width is held in the world's: the world's slope of
					# the noise gives the scale between them (the warp's
					# stretch, the floor's clamped slope), so it keeps its width
					# round bends and stays on the floor.
					var gw := maxf(sqrt(gx*gx+gz*gz),0.25/VALLEYS)
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
					var top := maxf(base,MEADOW_ABOVE)
					var water := maxf(base-drop,0.0)
					# By the river the floor is the banks' top (the hills' bumps out).
					var near := (1.0-smoothstep(w+RIVER_BANK,w+RIVER_BANK+RIVER_RAMP,s))*k
					floor_y = lerpf(floor_y,top,near)
					last_river_r = r
					last_river_w = w
					last_river_y = SEA_Y+water
					_river_top = SEA_Y+top
					_river_k = k
					if s < w+RIVER_BANK+16.0 and water > 0.0:
						# The flow: downhill along the valley, as fast as the
						# level falls.
						var fall := (_lowland(x-along.x*30.0,z-along.y*30.0)-_lowland(x+along.x*30.0,z+along.y*30.0))/60.0
						var speed := RIVER_FLOW.x+sqrt(absf(fall))*RIVER_FLOW.y
						last_river_flow = along*clampf(fall/RIVER_STILL,-1.0,1.0)*speed
			_floor = SEA_Y+floor_y
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

## The continents' level (m over the sea) at a point, as `_broad` starts.
func _lowland(x: float, z: float) -> float:
	var b := _continent.get_noise_2d(x,z)*CONTINENT_SWING*2.0+CONTINENT_LIFT
	if b > 0.0: b = LOWLAND*(1.0-exp(-b/LOWLAND))
	return b

## The valley noise at a world point, through its warp (as `_broad` reads it).
func _valley_at(x: float, z: float) -> float:
	var vx := x+_valley_warp.get_noise_2d(x,z)*VALLEY_WARP_MOVE
	var vz := z+_valley_warp.get_noise_2d(x-4111.0,z+2027.0)*VALLEY_WARP_MOVE
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
	var base := _continent.get_noise_2d(x,z)*CONTINENT_SWING*2.0+CONTINENT_LIFT
	if base > 0.0: base = LOWLAND*(1.0-exp(-base/LOWLAND))
	var inland := smoothstep(-6.0,18.0,base)
	var h := base+_hills.get_noise_2d(x,z)*HILL_TALL*2.0*(0.35+0.65*inland)
	var mountain := smoothstep(MOUNTAIN_BAND.x,MOUNTAIN_BAND.y,_mask.get_noise_2d(x,z))*inland
	if mountain > 0.0:
		var ridge := _ridges.get_noise_2d(x,z)*0.5+0.5
		h += ridge*ridge*MOUNTAIN_TALL*mountain
	var meadow := smoothstep(MEADOW_BAND.x,MEADOW_BAND.y,_meadows.get_noise_2d(x,z))*inland*(1.0-mountain)
	if meadow > 0.0:
		var flat := maxf(base+(h-base)*MEADOW_KEEP,MEADOW_ABOVE)
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
	if last_river < 0.0 and last_river_y > SEA_Y+0.05: return last_river_y
	return NAN

## The world height at a world XZ point.
func height(x: float, z: float) -> float:
	return sample(x,z).x

## The snow line over the sea for this land (round one's under --old-land).
func snow_line() -> float:
	return 95.0 if old_land else SNOW

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
