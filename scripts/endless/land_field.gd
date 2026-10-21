extends RefCounted
## The endless land's field: its height, its meadows and its colour at any
## world XZ point, from a seed alone, so the same seed always grows the same
## land (docs/design/endless-flight/round-1-handoff.md). Plain maths over
## FastNoiseLite; each worker builds its own field (`new(seed)`), so chunks
## are made off the main thread without sharing one.
##
## The land, in metres over the sea (`SEA_Y` world):
##   continents  CONTINENT, very broad: where land stands and where it
##               sinks under the sea, the coast between.
##   hills       HILLS, rolling, softer near the coast.
##   mountains   a few, where MOUNTAINS' mask rises: ridged, up to
##               MOUNTAIN_TALL, snow on top.
##   meadows     where MEADOWS' mask rises (none on the mountains): the hills
##               eased out into broad, near-flat turf, often enough that
##               there is always a flat in reach to land on (AGENTS.md).
## Every number is a knob here; `--seed=` picks the land.

## The sea's height in the world. The flight's band (scripts/sky_glide.gd
## FLOOR, CEILING) is fixed, so the sea sits under the isles' old ground
## and the peaks stay under the ceiling.
const SEA_Y := -40.0
## Continents: their scale (m), the height they swing (m) and the lift that
## sets how much is land (more is more land).
const CONTINENT := 3600.0
const CONTINENT_SWING := 70.0
const CONTINENT_LIFT := 14.0
const LOWLAND := 26.0
## Rolling hills: their scale and height (m).
const HILLS := 320.0
const HILL_TALL := 16.0
## Mountains: the mask's scale (m) and its band (where it starts and is
## full), the ridges' scale and their height (m).
const MOUNTAINS := 2600.0
const MOUNTAIN_BAND := Vector2(0.18,0.5)
const RIDGES := 900.0
const MOUNTAIN_TALL := 105.0
## Meadows: the mask's scale (m), its band, how flat the flats are (the
## share of the hills they keep) and the least they stand over the sea.
const MEADOWS := 650.0
const MEADOW_BAND := Vector2(-0.05,0.22)
const MEADOW_KEEP := 0.07
const MEADOW_ABOVE := 3.0
## The coast: the beach's height band over the sea (m).
const BEACH := 2.2
## Snow from SNOW m over the sea, on what is no steeper than SNOW_SLOPE.
const SNOW := 95.0

const SAND := Color(0.80,0.74,0.56)
const SEABED := Color(0.42,0.46,0.40)
const GRASS := Color(0.30,0.48,0.20)
const GRASS_DRY := Color(0.46,0.54,0.24)
const MEADOW := Color(0.52,0.64,0.28)
const ROCK := Color(0.47,0.44,0.40)
const SNOW_COLOUR := Color(0.93,0.94,0.97)

var seed := 0
var _continent := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _mask := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _meadows := FastNoiseLite.new()
var _tint := FastNoiseLite.new()

func _init(land_seed := 0) -> void:
	seed = land_seed
	_noise(_continent,1,CONTINENT,3,FastNoiseLite.FRACTAL_FBM)
	_noise(_hills,2,HILLS,4,FastNoiseLite.FRACTAL_FBM)
	_noise(_mask,3,MOUNTAINS,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_ridges,4,RIDGES,5,FastNoiseLite.FRACTAL_RIDGED)
	_noise(_meadows,5,MEADOWS,2,FastNoiseLite.FRACTAL_FBM)
	_noise(_tint,6,180.0,2,FastNoiseLite.FRACTAL_FBM)

func _noise(n: FastNoiseLite, salt: int, scale: float, octaves: int, kind: int) -> void:
	n.seed = seed*7919+salt*104729
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0/scale
	n.fractal_type = kind
	n.fractal_octaves = octaves

## Vector2(world height, meadow 0..1) at a world XZ point.
func sample(x: float, z: float) -> Vector2:
	var base := _continent.get_noise_2d(x,z)*CONTINENT_SWING*2.0+CONTINENT_LIFT
	# Inland the continents level off at LOWLAND m: the peaks come from
	# the mountains, not from the continents.
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
	# The coast: the land eases flat into the sea (a beach), not a step.
	if absf(h) < BEACH*2.0: h = h*lerpf(0.45,1.0,smoothstep(0.0,BEACH*2.0,absf(h)))
	return Vector2(SEA_Y+h,meadow)

## The world height at a world XZ point.
func height(x: float, z: float) -> float:
	return sample(x,z).x

## The ground's colour at a world point: its height over the sea, its
## slope (the normal's up) and its meadow.
func colour(x: float, z: float, y: float, up: float, meadow: float) -> Color:
	var over := y-SEA_Y
	if over < -0.5: return SEABED.lerp(SAND,clampf(1.0+over/6.0,0.0,1.0))
	var grass := GRASS.lerp(GRASS_DRY,clampf(_tint.get_noise_2d(x,z)*0.9+0.45,0.0,1.0))
	grass = grass.lerp(MEADOW,meadow)
	var c := SAND.lerp(grass,smoothstep(BEACH*0.6,BEACH*1.4,over))
	c = c.lerp(ROCK,smoothstep(0.86,0.72,up))
	if over > SNOW-12.0: c = c.lerp(SNOW_COLOUR,smoothstep(SNOW-12.0,SNOW+6.0,over)*smoothstep(0.62,0.8,up))
	return c
