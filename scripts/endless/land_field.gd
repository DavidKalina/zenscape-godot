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

func _init(land_seed := 0) -> void:
	seed = land_seed
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--mountains="): mountains = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--peaks="): peaks = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg.begins_with("--valleys="): valleys = maxf(0.0,float(arg.get_slice("=",1)))
		elif arg == "--no-valleys": valleys = 0.0
		elif arg == "--old-land": old_land = true
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

func _noise(n: FastNoiseLite, salt: int, scale: float, octaves: int, kind: int) -> void:
	n.seed = seed*7919+salt*104729
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0/scale
	n.fractal_type = kind
	n.fractal_octaves = octaves

## Vector2(world height, meadow 0..1) at a world XZ point.
func sample(x: float, z: float) -> Vector2:
	if old_land: return _old_sample(x,z)
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
			var t := clampf((d-half)/side,0.0,1.0)
			# U-shaped: flat floor, the sides steepening up off it.
			var keep := t*t*(3.0-2.0*t)
			keep = lerpf(1.0,keep,minf(valleys,1.0)*inland)
			if h > floor_y: h = floor_y+(h-floor_y)*keep
			var floor_meadow := (1.0-smoothstep(half*0.7,half+side*0.2,d))*inland*minf(valleys,1.0)
			meadow = maxf(meadow,floor_meadow)
	# The coast: the land eases flat into the sea (a beach), not a step.
	if absf(h) < BEACH*2.0: h = h*lerpf(0.45,1.0,smoothstep(0.0,BEACH*2.0,absf(h)))
	last_mountain = mountain
	return Vector2(SEA_Y+h,meadow)

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
	return {"height":s.x,"meadow":s.y,"mountain":last_mountain,"inland":last_inland,"valley":last_valley,"half":last_half,"side":last_side,"across":last_across}

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
