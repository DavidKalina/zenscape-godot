extends RefCounted
## One mountain range of the hidden land far below, risen so high it punches
## up through the cloud sea and towers over the sky islands
## (scripts/sky_peaks.gd places them). Not floating scenery like the islets:
## its foot is under the cloud, where the land is, and only its upper few
## hundred metres stand in the sky. One to three summits on a wandering
## crest, spurs running down off it, and a gorge cut clean through the range
## that the glide can dive into on one side and come out of on the other.
##
## The shape is a heightfield, height over the range's own (x, z), built the
## way real ranges are drawn and the plate's mountains weathered:
##   the skeleton: a crest along a wandering spine, high at the summits and
##     dipping at the saddles, and spurs running down off it to either side,
##     wandering and now and then branching. Each is a ridgeline the ground
##     falls away from on both sides, one side steeper (a ridge's own falls
##     are its faces); where two spurs' faces meet is the gully between
##     them. Spurs off a summit run on as its aretes;
##   erosion: the plate's own stream-power pass (scripts/terrain_erosion.gd
##     `erode`, ridged detail on the slopes, gullies cut down a drainage tree,
##     scree settling where the flow slackens), run in plate units on a grid
##     whose cells are the plate's 0.7 m scaled up;
##   crags and ledges: fine ridged noise on the steep ground, and the rock's
##     beds: gently tilted strata that step some steep faces into cliffs and
##     ledges;
##   the gorge: carved last, so nothing raises its floor or narrows it;
##     couloirs cut down its walls and its pinch's fins broken along their
##     tops, only ever lowering the rock, so the way stays open.
##
## Faces are flat and coloured per face as the islets' are (scripts/
## sky_islet.gd), for the plate's own ground material: the world's grass on
## gentle ground and ledges, an earth band under a ledge's lip, scree down
## the gullies, and on the steep faces the world's rock stepped through the
## granite core's beds, now and then a pale sand bed or a dark shale one
## (scripts/strata.gd's colours), so the range is layered as an island's
## side is and reads as cut from the same stuff. Grass and earth go by the
## ground's broad lie (`_calm`) as well as each face's, so they lie in
## patches. The material reads the plate's look LOOK_SCALE times larger
## (scripts/sky_peaks.gd). The flanks run on down past the sea to BASE;
## faces wholly below CUT are left out, and what does stand under the sea's
## top is never drawn: over the last metres the rock goes into the cloud's
## own light, lit as the sea's level top is, so the foot is soft cloud, not
## a ragged hem (reference_surface's `sea_cut`), wrapped in cloud puffs
## (`wraps`).
##
## The frame is the range's own: its spot on the islands' plane at the
## origin, x along the crest, heights the world's.

const SEA := -105.0
## Where the flanks end, far under the cloud; faces wholly below CUT are not
## built; the solid's underside, for the glide.
const BASE := -280.0
const CUT := SEA-45.0
const BOTTOM := -400.0
## The heightfield's half extents (m: along the crest, across it), the mesh
## grid's spacing, and the erosion grid's points a side.
const HALF := Vector2(830.0,760.0)
const STEP := 4.0
const ERODE_N := 193
## The plate's erosion cell (scripts/terrain_erosion.gd CELL): the erosion
## grid is the plate's, scaled up by its own cell over this.
const PLATE_CELL := 0.7
## The highest summit's height (m, over the islands' plane), and the others'.
## Nothing is ever lifted past MOST.
const TOP := Vector2(275.0,335.0)
const SECOND := Vector2(205.0,265.0)
const MOST := 345.0
## Summits: how many (weights for one, two, three); the next stands APART
## from the highest, a third THIRD the other way. Past them the gorge, then
## a lower shoulder (SHOULDER m high) for its far wall, GORGE_OFF and
## SHOULDER_OFF further on.
const COUNT_ODDS := [0.2,0.45,0.35]
const APART := Vector2(250.0,330.0)
const THIRD := Vector2(210.0,270.0)
const SHOULDER := Vector2(175.0,215.0)
const GORGE_OFF := Vector2(185.0,225.0)
const SHOULDER_OFF := Vector2(165.0,200.0)
## The crest's fall away from a summit: it drops FALL of the summit's height
## over FALL_RUN m (as a power FALL_POW); past the outer summits it falls
## under the sea within END_RUN m.
const FALL := Vector2(0.15,0.25)
const FALL_RUN := 200.0
const FALL_POW := 1.1
const END_RUN := Vector2(260.0,330.0)
## The spine's wander across (m) and wavelength (m), two waves; the crest's
## pieces (m) and its notches (m deep, wavelength m).
const WANDER := Vector2(25.0,55.0)
const WANDER_LONG := Vector2(380.0,620.0)
const CREST_PIECE := 24.0
const NOTCH := 38.0
const NOTCH_WAVE := 50.0
## The crest's faces (rise per metre out): the steep side and the other.
const NEAR_FACE := Vector2(1.55,1.95)
const FAR_FACE := Vector2(1.15,1.45)
## Spurs: how far apart along the crest (m), how far they turn off square
## (radians), their mean fall (rise per metre along), how concave they fall,
## their faces' steepness, how much they wander as they go (radians a
## piece), pieces each, and the odds and turn of a branch.
const SPUR_GAP := Vector2(80.0,190.0)
const SPUR_TURN := 0.5
const SPUR_FALL := Vector2(0.85,1.25)
const SPUR_CONCAVE := Vector2(1.15,1.5)
const SPUR_FACE := Vector2(1.1,1.65)
const SPUR_WANDER := 0.34
const SPUR_PIECES := 6
const BRANCH_ODDS := 0.6
const BRANCH_TURN := Vector2(0.5,0.95)
## Knobs along a spur's line (m) and how far the skeleton's ground is pushed
## about before it is read (m), so no line runs ruler-straight.
const KNOB := 14.0
const WARP := 22.0
## The plate's erosion, in plate metres (scripts/terrain_erosion.gd). Its
## own ridged detail is light, the most of it laid on unevenly beforehand (`_weather`), so
## the channels it cuts gather into couloirs of every size, not a fluting
## evenly spaced down every face. Only flow off a catchment of channel_area
## cells cuts, so fewer, bigger gullies merge.
const ERODE := {"detail":1.0,"frequency":0.16,"warp":1.3,"slope_ref":1.2,"iterations":40,"k":0.004,
	"channel_area":10.0,"jitter":0.6,"max_cut":7.0,"deposit":0.45,"deposit_slope":0.35,"deposit_cap":0.12}
## The weathering laid on before the erosion (`_weather`), on steep ground
## from WEATHER_STEEP (gradient) and fully by its y: broad ribs and hollows
## (m, wavelength m) that gather the flow; ridged rills (m, wavelength m),
## domain-warped (m); and how their strength wanders over the range
## (wavelength m), from none to RILL_MOST of it.
const WEATHER_STEEP := Vector2(0.35,1.2)
const HOLLOW := 16.0
const HOLLOW_WAVE := 150.0
const RILL := 15.0
const RILL_WAVE := Vector2(48.0,105.0)
const RILL_WARP := 30.0
const RILL_PATCH := 330.0
const RILL_MOST := 1.4
## Crags: height (m) on steep ground and wavelength (m).
const CRAG := 4.0
const CRAG_WAVE := 34.0
## Beds: a step's height (m), how hard each steps (share), their tilt (m a
## metre) and the steepness (gradient) they step from and fully at. Few and
## bold: a handful of cliff bands and ledges, calm rock between, and only
## where a broad noise allows (so whole faces stay unstepped).
const BED := Vector2(42.0,58.0)
const BED_SHARE := 0.6
const BED_SHARP := 4.0
const BED_TILT := Vector2(0.03,0.09)
const BED_STEEP := Vector2(0.5,1.25)
## How unevenly thick the beds run (BED_SWAY beds over BED_SWAY_RUN beds,
## under BED_SWAY_RUN/TAU, so the count only ever climbs), and the fold
## that bows them (m, wavelength m).
const BED_SWAY := 0.36
const BED_SWAY_RUN := 3.4
const BED_FOLD := 14.0
const BED_FOLD_WAVE := 300.0
## The gorge: its floor (m), half its floor's width (m), its walls' rise per
## metre out (lower walls, then upper), the height over the floor they ease
## from one to the other, and how far its line wanders (m) over what
## wavelength (m).
const GORGE_FLOOR := -135.0
const GORGE_HALF := 22.0
const GORGE_WALL := Vector2(4.5,5.5)
const GORGE_UPPER := 3.0
const GORGE_BREAK := 380.0
## Buttresses standing out of the gorge's walls: their height (m) over the
## wall, wavelength along the gorge (m), and the distance out (m) from its
## line they start at and are whole by, clear of the glide's way.
const BUTTRESS := 120.0
const BUTTRESS_WAVE := 52.0
const BUTTRESS_FROM := Vector2(30.0,50.0)
const GORGE_BEDS := 0.45
## Couloirs down the gorge's walls: how far (m) one cuts the wall back at
## its deepest, and how much tighter than the buttresses they lie along it.
const COULOIR := 12.0
const COULOIR_STRETCH := 1.6
## None are cut within COULOIR_SPARE m of a pinch's ends, so its walls stand.
const COULOIR_SPARE := 60.0
const GORGE_WANDER := Vector2(18.0,36.0)
const GORGE_LONG := Vector2(520.0,760.0)
## The gorge is roughed out this much (m) wider before the weathering.
const GORGE_ROUGH := 10.0
## The pinch some gorges have (`_pinch`): its odds, its middle along the
## gorge (m from where it crosses the crest), its length and the ramp at its ends (m), the
## slot's half width (m), the fins' top (m), and how far under it the jet
## runs down the slot (m).
const PINCH_ODDS := 0.65
const PINCH_AT := Vector2(-35.0,35.0)
const PINCH_LENGTH := Vector2(120.0,170.0)
const PINCH_RAMP := 40.0
const PINCH_HALF := 11.0
const PINCH_TOP := Vector2(-5.0,15.0)
const PINCH_JET_UNDER := 22.0
## How far (m) the fins' tops are broken down at most, away from the slot.
const FIN_TEETH := 18.0
## The glide's way through: its half width kept clear at glide heights (m)
## and the band of those heights (scripts/sky_glide.gd FLOOR to CEILING).
const CLEAR_HALF := 20.0
const GLIDE_BAND := Vector2(-55.0,95.0)
## Colours: grass on ground no steeper than GRASS_SLOPE (gradient) below
## GRASS_HIGH m, earth up to EARTH_SLOPE, rock above; the earth band under
## a ledge's lip is the top LIP share of a bed. Gullies (scree) are where the
## erosion laid down more than SCREE m.
const GRASS_SLOPE := 0.85
const EARTH_SLOPE := 1.25
const GRASS_HIGH := 240.0
const LIP := 0.2
const SCREE := 3.0
## The lie colours read: the slope (gradient) averaged CALM_REACH grid
## points round, and the steepest such lie a bed's tread still holds grass.
const CALM_REACH := 3
const LEDGE_CALM := 1.6
## How far a face's colour is nudged from its neighbours', and how far the
## beds' tones lighten and darken the rock.
const FACE_JITTER := 0.025
## The faces' normals are read over this many grid points each way.
const NORMAL_REACH := 2
const BED_TONE := 0.62
## The odds of a bed being a band of shale (x) or of sand (y), and how far
## such a band takes its own colour over the rock's.
const BANDS := Vector2(0.2,0.14)
const BAND_TONE := 0.5
## The beds' colours show from BAND_SLOPE.x (gradient) and fully on cliffs
## by its y; a gully cut (or a hollow) GULLY_CUT m deep breaks them; their
## edges wander BED_EDGE m.
const BAND_SLOPE := Vector2(0.75,1.9)
const GULLY_CUT := Vector2(3.0,11.0)
const BED_EDGE := 7.0
## Spruces on the gentle ground and ledges between LOW_TREES and HIGH_TREES
## m: tried every TREE_STEP m, kept where the slope is under TREE_SLOPE and
## the stands' noise is over TREE_PATCH, at most TREE_CAP; their heights (m)
## and the spruce variants (scripts/hero_trees.gd SPRUCE).
const TREE_STEP := 9.0
const TREE_SLOPE := 0.6
const TREE_PATCH := 0.05
const TREE_BAND := Vector2(-75.0,175.0)
const TREE_CAP := 520
const TREE_HEIGHT := Vector2(3.5,7.5)
const TREE_VARIANTS := [0,1,2,4]
## The cloud round the foot: puffs (x, y, z, radius) WRAP_APART m apart along
## the sea line, WRAP_SIZE m across.
const WRAP_APART := 38.0
const WRAP_SIZE := Vector2(28.0,78.0)
## Snow: the line stands SNOW_DEPTH m under the top, broken SNOW_RAG m
## either way by a noise, brought down SNOW_HOLLOW m a metre of hollow (and
## lifted on ridges); it holds on ground no steeper than SNOW_SLOPE (at the
## line, and well above it); below the line it lingers SNOW_LINGER m down on
## ledges and in hollows. Its colour is the world's snow
## (scripts/native_terrain_palette.gd), a touch blue in the hollows, each
## face nudged by SNOW_JITTER; the light makes it warm or cool by the hour.
const SNOW_DEPTH := Vector2(135.0,165.0)
## Placed scaled in height (scripts/sky_world.gd), a range holds no snow
## under SNOW_WORLD (m, the world's height): the low ones (foothills, the
## ridges' low stretches and cols) are bare rock going into the cloud, not
## white blankets (`snow_floor`).
const SNOW_WORLD := 140.0
const SNOW_RAG := 32.0
const SNOW_HOLLOW := 2.4
const SNOW_SLOPE := Vector2(1.3,2.8)
const SNOW_LINGER := 50.0
const SNOW_JITTER := 0.03
const SNOW_COLOUR := Color(0.9,0.93,0.96)
## The rock's cooling toward the far peaks' blue-grey, of its own lightness:
## half of COOL at the sea, all of it at the top; and that grey's hue.
const COOL := 0.3
const COOL_HUE := Vector3(0.9,0.97,1.16)
## The plate's own rock (scripts/native_terrain_palette.gd's first grey,
## linear): the world's rock over this tints the beds.
const ROCK_REF := Color(0.2664,0.2346,0.1845)
const Erosion = preload("res://scripts/terrain_erosion.gd")
const Strata = preload("res://scripts/strata.gd")

var seed := 0
## How tall it stands, as a share of its drawn summits (SkyPeaks `stature_of`).
var stature := 1.0
## Summits: (x, height, z) in the range's frame, as they stand.
var summits: Array[Vector3] = []
## The highest point.
var top := 0.0
## The mesh grid: points along x and z, heights row by row (z rows).
var nx := 0
var nz := 0
var heights := PackedFloat32Array()
## How much the erosion laid down (+) or cut (-), per mesh point (m), and
## how hard each point was stepped into beds (0 to 1).
var settled := PackedFloat32Array()
var stepped := PackedFloat32Array()
## The gorge: its line's x at z = 0, wander and wavelength, phase, walls.
var gorge := {}
## The gorge's pinch, if it has one: {z, length, top} (`_pinch`).
var pinch := {}
## The cloud round the foot: (x, y, z, radius).
var wraps := PackedVector4Array()
## The snow line's mean height (m).
var snowline := 1000.0
## Spruces: (x, z, height, variant), standing on the ground.
var trees: Array[Vector4] = []
## The steep side of the crest (+1 is +z).
var near_side := 1.0
## The beds' step and tilt (m a metre in x, z).
var bed := 18.0
var tilt := Vector2.ZERO
## The skeleton: ridgelines as pieces {a, b (x, z), ha, hb, left, right
## (the faces' rise per metre out on each side, left of a to b first)}.
var ridges: Array = []

var _rng := RandomNumberGenerator.new()
var _calm_field := PackedFloat32Array()
var _fold_noise: FastNoiseLite
var _bed_phase := 0.0
var _spine := PackedFloat32Array()
var _peaks: Array = []

## The range for `seed_value` (a hash of its spot).
## `stature` (at most 1) brings its summits down, never its shoulder.
static func make(seed_value: int, stature := 1.0, gorge_cut := true) -> RefCounted:
	var peak: RefCounted = new()
	peak.stature = stature
	peak.cut = gorge_cut
	peak._shape(seed_value)
	return peak

# --- Ring hooks (scripts/sky_world.gd, sky/world-ring) -----------------------------
## `cut` false leaves the gorge uncut (`make`'s `gorge_cut`): the ring keeps
## only a few gorges through it.
var cut := true

## Where the planned crest stands over `above` m (the range's own x, before
## the erosion and the crest's notches): Vector2(lowest x, highest x), or
## Vector2.ZERO if nowhere; from the plan alone, so cheap. The ring lays its
## ranges end to end by it.
## The snow line's floor in a range's own heights, placed scaled `height`
## in height about the sea (SNOW_WORLD in the world's).
static func snow_floor(height: float) -> float:
	return SEA+(SNOW_WORLD-SEA)/maxf(height,0.01)

static func crest_span(seed_value: int, stature := 1.0, above := 140.0) -> Vector2:
	var peak: RefCounted = new()
	peak.stature = stature
	peak.seed = seed_value
	peak._rng.seed = seed_value
	peak._plan()
	var lo := INF
	var hi := -INF
	var x := -HALF.x
	while x <= HALF.x:
		if peak.crest(x) > above:
			lo = minf(lo,x)
			hi = maxf(hi,x)
		x += 8.0
	return Vector2(lo,hi) if lo <= hi else Vector2.ZERO

## Where the gorge crosses the crest (the range's own x), from the plan
## alone: the dividing ridges keep their roots off a kept gorge's mouth.
static func gorge_at(seed_value: int, stature := 1.0) -> float:
	var peak: RefCounted = new()
	peak.stature = stature
	peak.seed = seed_value
	peak._rng.seed = seed_value
	peak._plan()
	return float(peak.gorge.x)
# --- End of ring hooks ---------------------------------------------------------------

func _shape(seed_value: int) -> void:
	seed = seed_value
	_rng.seed = seed_value
	_plan()
	if cut: _plan_pinch()
	_skeleton()
	var coarse := _coarse()
	_fine(coarse)
	_carve()
	_measure()
	# The snow line from a stream of its own, so the shape's draws stand.
	var snow_rng := RandomNumberGenerator.new()
	snow_rng.seed = seed*53+9
	snowline = top-snow_rng.randf_range(SNOW_DEPTH.x,SNOW_DEPTH.y)
	_wrap()
	_plant()

# --- The plan ----------------------------------------------------------------

## The seeded numbers: the spine, the summits and the shoulder, the gorge
## and the beds.
func _plan() -> void:
	near_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_spine = PackedFloat32Array([_rng.randf_range(WANDER.x,WANDER.y),TAU/_rng.randf_range(WANDER_LONG.x,WANDER_LONG.y),_rng.randf()*TAU,
		_rng.randf_range(6.0,14.0),TAU/_rng.randf_range(150.0,230.0),_rng.randf()*TAU])
	var roll := _rng.randf()
	var count := 1 if roll < COUNT_ODDS[0] else 2 if roll < COUNT_ODDS[0]+COUNT_ODDS[1] else 3
	# Along the crest, one way: maybe a third summit, the highest, maybe the
	# next, then the gorge, then a lower shoulder for its far wall. The
	# summits stand together as one massif; the gorge cuts off its end.
	var way := 1.0 if _rng.randf() < 0.5 else -1.0
	var xs := [0.0]
	var hs := [_rng.randf_range(TOP.x,TOP.y)]
	if count == 3:
		xs.append(-way*_rng.randf_range(THIRD.x,THIRD.y))
		hs.append(_rng.randf_range(SECOND.x,SECOND.y))
	var last := 0.0
	if count >= 2:
		last = way*_rng.randf_range(APART.x,APART.y)
		xs.insert(1,last)
		hs.insert(1,_rng.randf_range(SECOND.x,SECOND.y))
	var cut := last+way*_rng.randf_range(GORGE_OFF.x,GORGE_OFF.y)
	var shoulder := cut+way*_rng.randf_range(SHOULDER_OFF.x,SHOULDER_OFF.y)
	xs.append(shoulder)
	hs.append(_rng.randf_range(SHOULDER.x,SHOULDER.y))
	# The whole centred on the range's spot.
	var lo := INF
	var hi := -INF
	for x: float in xs:
		lo = minf(lo,x)
		hi = maxf(hi,x)
	var middle := (lo+hi)*0.5
	_peaks.clear()
	for i in range(xs.size()):
		_peaks.append({"x":float(xs[i])-middle,"h":float(hs[i])*(stature if i < xs.size()-1 else 1.0),"fall":Vector2(_rng.randf_range(FALL.x,FALL.y),_rng.randf_range(FALL.x,FALL.y))})
	# The ends of the crest fall faster.
	var first := 0
	var final := 0
	for i in range(_peaks.size()):
		if _peaks[i].x < _peaks[first].x: first = i
		if _peaks[i].x > _peaks[final].x: final = i
	var f: Vector2 = _peaks[first].fall
	_peaks[first].fall = Vector2(_end_fall(_peaks[first].h),f.y)
	f = _peaks[final].fall
	_peaks[final].fall = Vector2(f.x,_end_fall(_peaks[final].h))
	gorge = {"x":cut-middle,"wander":_rng.randf_range(GORGE_WANDER.x,GORGE_WANDER.y),"wave":TAU/_rng.randf_range(GORGE_LONG.x,GORGE_LONG.y),
		"phase":_rng.randf()*TAU,"wall":_rng.randf_range(GORGE_WALL.x,GORGE_WALL.y)}
	bed = _rng.randf_range(BED.x,BED.y)
	tilt = Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(BED_TILT.x,BED_TILT.y)
	# The beds' uneven count from a stream of its own, so the shape's draws
	# stand.
	var beds_rng := RandomNumberGenerator.new()
	beds_rng.seed = seed*67+11
	_bed_phase = beds_rng.randf()*TAU
	_fold_noise = _noise(53,1.0/BED_FOLD_WAVE,2,FastNoiseLite.FRACTAL_FBM)

## The fall past an outer summit `h` high that takes the crest under the
## sea END_RUN m on.
func _end_fall(h: float) -> float:
	return (1.0-(SEA-40.0)/h)/pow(_rng.randf_range(END_RUN.x,END_RUN.y)/FALL_RUN,FALL_POW)

## The spine's line: z of the crest at x.
func spine(x: float) -> float:
	return _spine[0]*sin(x*_spine[1]+_spine[2])+_spine[3]*sin(x*_spine[4]+_spine[5])

## The crest's height along the spine at x: the summits' falls, smoothly
## joined.
func crest(x: float) -> float:
	var h := -INF
	for p: Dictionary in _peaks:
		var d := x-float(p.x)
		var fall: float = p.fall.x if d < 0.0 else p.fall.y
		var c: float = float(p.h)*(1.0-fall*pow(absf(d)/FALL_RUN,FALL_POW))
		h = c if h == -INF else _smax(h,c,40.0)
	return h

## The gorge's line: its x at z, and its way (unit, in x, z).
func gorge_x(z: float) -> float:
	return float(gorge.x)+float(gorge.wander)*sin(z*float(gorge.wave)+float(gorge.phase))

func gorge_way(z: float) -> Vector2:
	var slope := float(gorge.wander)*float(gorge.wave)*cos(z*float(gorge.wave)+float(gorge.phase))
	return Vector2(slope,1.0).normalized()

## The height the gorge's walls stand to at distance `d` (m) out from its
## line: a narrow floor, sheer lower walls, then steep upper ones.
func gorge_wall(d: float) -> float:
	var out := maxf(0.0,absf(d)-GORGE_HALF)
	var wall := float(gorge.wall)
	var lower := GORGE_BREAK/wall
	if out <= lower: return GORGE_FLOOR+out*wall
	return GORGE_FLOOR+GORGE_BREAK+(out-lower)*GORGE_UPPER

## The walls with their buttresses at a point `d` (m) out from the line
## (`gorge_distance`), `z` along the range (`ribs`: the buttresses' noise).
## Out where the buttresses stand, the walls step a little at the beds too.
## Couloirs are cut down the walls (`ribs` read another way), only ever
## lowering them, so the way through stays as open as the plain walls leave
## it and no wall stands as one flat ramp.
func gorge_face(d: float, z: float, ribs: FastNoiseLite) -> float:
	var out := smoothstep(BUTTRESS_FROM.x,BUTTRESS_FROM.y,absf(d))
	var rib := maxf(0.0,ribs.get_noise_2d(z,absf(d)*0.3+signf(d)*400.0))
	var a := absf(d)
	var flute := maxf(0.0,ribs.get_noise_2d(z*COULOIR_STRETCH+911.0,a*0.12+signf(d)*733.0))
	if not pinch.is_empty(): flute *= smoothstep(0.0,COULOIR_SPARE,absf(z-float(pinch.z))-float(pinch.length)*0.5)
	a = maxf(minf(a,GORGE_HALF),a-COULOIR*flute*flute*smoothstep(GORGE_HALF,GORGE_HALF+COULOIR,a))
	var h := gorge_wall(a)+BUTTRESS*rib*out
	return lerpf(h,_terrace(h/bed)*bed,GORGE_BEDS*out)

## Distance (m) from the gorge's line, across it, at a point.
func gorge_distance(p: Vector2) -> float:
	return (p.x-gorge_x(p.y))*gorge_way(p.y).y

static func _smax(a: float, b: float, k: float) -> float:
	var h := maxf(k-absf(a-b),0.0)/k
	return maxf(a,b)+h*h*k*0.25

# --- The skeleton -----------------------------------------------------------------

## The crest along the spine, notched, from where it rises out of the deep
## to where it sinks back; and the spurs down off it on both sides.
func _skeleton() -> void:
	ridges.clear()
	var notch := _noise(7,1.0/NOTCH_WAVE,2,FastNoiseLite.FRACTAL_RIDGED)
	var near_face := _rng.randf_range(NEAR_FACE.x,NEAR_FACE.y)
	var far_face := _rng.randf_range(FAR_FACE.x,FAR_FACE.y)
	var lo := INF
	var hi := -INF
	for p: Dictionary in _peaks:
		lo = minf(lo,float(p.x))
		hi = maxf(hi,float(p.x))
	# The crest runs on past the outer summits until it is under BASE+.
	var x0 := lo
	while x0 > -HALF.x+40.0 and crest(x0) > SEA-60.0: x0 -= CREST_PIECE
	var x1 := hi
	while x1 < HALF.x-40.0 and crest(x1) > SEA-60.0: x1 += CREST_PIECE
	var line: Array[Vector3] = []
	var x := x0
	while x <= x1+0.01:
		# Notches down from the line, deepest away from the summits.
		var c := crest(x)
		var dip := NOTCH*(notch.get_noise_1d(x)*0.5+0.5)*(1.0-0.6*_near_summit(x))
		line.append(Vector3(x,c-dip,spine(x)))
		x += CREST_PIECE
	# Left of the crest's way (+x) is +z.
	var left := near_face if near_side > 0.0 else far_face
	var right := far_face if near_side > 0.0 else near_face
	for i in range(line.size()-1):
		_ridge(Vector2(line[i].x,line[i].z),Vector2(line[i+1].x,line[i+1].z),line[i].y,line[i+1].y,left,right)
	# Spurs off both sides, a gap apart; off the ends they fan out round.
	for side in [1.0,-1.0]:
		var s := x0+_rng.randf_range(0.0,SPUR_GAP.x)
		while s < x1:
			var c := crest(s)
			if c > SEA-20.0:
				var t := (s-x0)/maxf(x1-x0,1.0)
				# Square off the crest, turned outward toward the ends.
				var fan := (t-0.5)*2.0
				var a: float = atan2(side,0.0)-side*fan*absf(fan)*1.1+_rng.randf_range(-SPUR_TURN,SPUR_TURN)
				_spur(Vector2(s,spine(s)),c-_rng.randf_range(10.0,60.0),a,true)
			s += _rng.randf_range(SPUR_GAP.x,SPUR_GAP.y)
	# Off each summit, an arete down either face: with the crest's two ways,
	# a horn's four.
	for p: Dictionary in _peaks:
		var px: float = p.x
		for side in [1.0,-1.0]:
			_spur(Vector2(px,spine(px)),crest(px)-2.0,atan2(side,0.0)+_rng.randf_range(-0.45,0.45),false)
	# Past the ends, a spur straight on.
	_spur(Vector2(x0,spine(x0)),crest(x0),PI+_rng.randf_range(-0.3,0.3),false)
	_spur(Vector2(x1,spine(x1)),crest(x1),_rng.randf_range(-0.3,0.3),false)

## How near x is to a summit along the crest (1 at one, 0 a way off).
func _near_summit(x: float) -> float:
	var n := 0.0
	for p: Dictionary in _peaks: n = maxf(n,1.0-smoothstep(20.0,90.0,absf(x-float(p.x))))
	return n

## A spur from `from` (on the crest, `h` high) heading `angle` (radians,
## from +x toward +z), falling concave to BASE, wandering; maybe branching.
func _spur(from: Vector2, h: float, angle: float, branches: bool) -> void:
	var fall := _rng.randf_range(SPUR_FALL.x,SPUR_FALL.y)
	var concave := _rng.randf_range(SPUR_CONCAVE.x,SPUR_CONCAVE.y)
	var length := (h-BASE)/fall
	var face := _rng.randf_range(SPUR_FACE.x,SPUR_FACE.y)
	var lean := _rng.randf_range(0.8,1.25)
	var at := from
	var heading := angle
	var piece := length/SPUR_PIECES
	var branch_at := _rng.randi_range(1,2) if branches and _rng.randf() < BRANCH_ODDS else -1
	for k in range(SPUR_PIECES):
		var t0 := float(k)/SPUR_PIECES
		var t1 := float(k+1)/SPUR_PIECES
		var h0 := BASE+(h-BASE)*pow(1.0-t0,concave)+(_rng.randf_range(-KNOB,KNOB) if k > 0 else 0.0)
		var h1 := BASE+(h-BASE)*pow(1.0-t1,concave)+(_rng.randf_range(-KNOB,KNOB) if k < SPUR_PIECES-1 else 0.0)
		heading += _rng.randf_range(-SPUR_WANDER,SPUR_WANDER)
		var next := at+Vector2.from_angle(heading)*piece
		_ridge(at,next,h0,h1,face*lean,face/lean)
		if k == branch_at:
			var turn := _rng.randf_range(BRANCH_TURN.x,BRANCH_TURN.y)*(1.0 if _rng.randf() < 0.5 else -1.0)
			_spur(next,h1-_rng.randf_range(3.0,12.0),heading+turn,false)
		at = next

func _ridge(a: Vector2, b: Vector2, ha: float, hb: float, left: float, right: float) -> void:
	ridges.append({"a":a,"b":b,"ha":ha,"hb":hb,"left":left,"right":right})

## Laid over a grid of `n` a side from `corner` at `cell` spacing: the
## skeleton's ground, each ridge's faces drawn out until they reach BASE,
## the highest kept; read at points pushed about by WARP.
func _lay(n: int, corner: Vector2, cell: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(n*n)
	out.fill(BASE)
	var push := _noise(11,1.0/260.0,2,FastNoiseLite.FRACTAL_FBM)
	var at := PackedVector2Array()
	at.resize(n*n)
	for j in range(n):
		for i in range(n):
			var p := corner+Vector2(i,j)*cell
			at[j*n+i] = p+Vector2(push.get_noise_2d(p.x,p.y),push.get_noise_2d(p.x+517.0,p.y-211.0))*WARP
	for r: Dictionary in ridges:
		var a: Vector2 = r.a
		var b: Vector2 = r.b
		var ha: float = r.ha
		var hb: float = r.hb
		var top_h := maxf(ha,hb)
		if top_h < BASE: continue
		var soft := minf(float(r.left),float(r.right))
		# Out to where its faces have fallen to BASE, so it never stops short.
		var reach := (top_h-BASE)/soft+WARP
		var box := Rect2(a,Vector2.ZERO).expand(b).grow(reach)
		var i0 := maxi(0,int(floor((box.position.x-corner.x)/cell)))
		var i1 := mini(n-1,int(ceil((box.end.x-corner.x)/cell)))
		var j0 := maxi(0,int(floor((box.position.y-corner.y)/cell)))
		var j1 := mini(n-1,int(ceil((box.end.y-corner.y)/cell)))
		var ab := b-a
		var length2 := maxf(ab.length_squared(),1e-6)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var c := j*n+i
				var p := at[c]
				var t := clampf((p-a).dot(ab)/length2,0.0,1.0)
				var off := p-(a+ab*t)
				var d := off.length()
				var face: float = r.left if ab.cross(off) > 0.0 else r.right
				var h := lerpf(ha,hb,t)-face*d
				if h > out[c]: out[c] = h
	return out

# --- The coarse grid: the skeleton, the plate's erosion ----------------------------

## The erosion grid: the skeleton's ground, then the plate's erosion over it
## in plate units. Returns the heights, what the erosion laid down or cut,
## and the grid (n, corner, cell).
func _coarse() -> Dictionary:
	var n := ERODE_N
	var span := maxf(HALF.x,HALF.y)*2.0
	var cell := span/float(n-1)
	var corner := -Vector2.ONE*span*0.5
	var base := _lay(n,corner,cell)
	# The gorge roughed out first, a little wide, so its walls weather with
	# the rest; it is cut true at the end (`_carve`).
	var ribs := _ribs()
	for j in range(n):
		for i in range(n):
			var p := corner+Vector2(i,j)*cell
			var d := gorge_distance(p)
			if cut: base[j*n+i] = minf(base[j*n+i],gorge_face(signf(d)*maxf(0.0,absf(d)-GORGE_ROUGH),p.y,ribs))
	base = _weather(base,n,corner,cell)
	# The plate's erosion, in plate units: this grid's cell is the plate's.
	var scale := cell/PLATE_CELL
	var plate := PackedFloat64Array()
	plate.resize(n*n)
	for c in range(n*n): plate[c] = base[c]/scale
	var fixed := PackedByteArray()
	fixed.resize(n*n)
	var settings := ERODE.duplicate()
	settings.merge({"size":n,"cell":PLATE_CELL,"origin":-float(n-1)*0.5*PLATE_CELL,"seed":seed & 0x7fffffff,
		"edge_inner":1.0e5,"edge_outer":1.0e5+1.0})
	var delta := Erosion.erode(plate,fixed,settings)
	var out := PackedFloat64Array()
	out.resize(n*n)
	var laid := PackedFloat64Array()
	laid.resize(n*n)
	for c in range(n*n):
		var d := delta[c]*scale if delta.size() == n*n else 0.0
		# Its cuts ease off under the sea, where nothing shows and a deep
		# one would only hole the foot.
		if d < 0.0: d *= smoothstep(SEA-70.0,SEA+10.0,base[c])
		out[c] = base[c]+d
		laid[c] = d
	return {"h":out,"laid":laid,"n":n,"corner":corner,"cell":cell}

## The faces' weathering, laid on the steep ground before the erosion, so
## it has something uneven to work: broad ribs and hollows that gather the
## flow into the bigger couloirs, and ridged rills at two wavelengths, warped,
## whose strength wanders from bare smooth slabs to deeply fretted rock.
func _weather(base: PackedFloat64Array, n: int, corner: Vector2, cell: float) -> PackedFloat64Array:
	var hollows := _noise(91,1.0/HOLLOW_WAVE,3,FastNoiseLite.FRACTAL_FBM)
	var fine := _noise(97,1.0/RILL_WAVE.x,2,FastNoiseLite.FRACTAL_RIDGED)
	var broad := _noise(98,1.0/RILL_WAVE.y,2,FastNoiseLite.FRACTAL_RIDGED)
	var push := _noise(99,1.0/(RILL_WAVE.y*1.6),2,FastNoiseLite.FRACTAL_FBM)
	var patch := _noise(101,1.0/RILL_PATCH,2,FastNoiseLite.FRACTAL_FBM)
	var mix_wave := _noise(103,1.0/(RILL_PATCH*0.6),1,FastNoiseLite.FRACTAL_NONE)
	var out := base.duplicate()
	for j in range(n):
		for i in range(n):
			var c := j*n+i
			var h := base[c]
			if h < CUT-60.0: continue
			var gx := (base[j*n+mini(i+1,n-1)]-base[j*n+maxi(i-1,0)])/(2.0*cell)
			var gz := (base[mini(j+1,n-1)*n+i]-base[maxi(j-1,0)*n+i])/(2.0*cell)
			# None near and under the sea, where nothing shows and a deep
			# cut would only hole the foot.
			var steep := smoothstep(WEATHER_STEEP.x,WEATHER_STEEP.y,Vector2(gx,gz).length())*smoothstep(SEA-20.0,SEA+40.0,h)
			if steep <= 0.0: continue
			var p := corner+Vector2(i,j)*cell
			var q := p+Vector2(push.get_noise_2d(p.x,p.y),push.get_noise_2d(p.x+733.0,p.y-419.0))*RILL_WARP
			var which := mix_wave.get_noise_2d(p.x,p.y)*0.5+0.5
			var rill := lerpf(fine.get_noise_2d(q.x,q.y),broad.get_noise_2d(q.x,q.y),smoothstep(0.3,0.7,which))
			var strength := RILL_MOST*smoothstep(-0.35,0.45,patch.get_noise_2d(p.x,p.y))
			out[c] = h+steep*(HOLLOW*hollows.get_noise_2d(p.x,p.y)+RILL*strength*(rill-0.2))
	return out

## Catmull-Rom read of a coarse grid at a point, so its cells leave no
## creases.
static func _sample(grid: PackedFloat64Array, n: int, corner: Vector2, cell: float, p: Vector2) -> float:
	var fi := clampf((p.x-corner.x)/cell,0.0,n-1.0)
	var fj := clampf((p.y-corner.y)/cell,0.0,n-1.0)
	var i := mini(n-2,int(fi))
	var j := mini(n-2,int(fj))
	var u := fi-i
	var v := fj-j
	var i0 := maxi(i-1,0)
	var i3 := mini(i+2,n-1)
	var r0 := maxi(j-1,0)*n
	var r1 := j*n
	var r2 := r1+n
	var r3 := mini(j+2,n-1)*n
	return _spline(_spline(grid[r0+i0],grid[r0+i],grid[r0+i+1],grid[r0+i3],u),
		_spline(grid[r1+i0],grid[r1+i],grid[r1+i+1],grid[r1+i3],u),
		_spline(grid[r2+i0],grid[r2+i],grid[r2+i+1],grid[r2+i3],u),
		_spline(grid[r3+i0],grid[r3+i],grid[r3+i+1],grid[r3+i3],u),v)

static func _spline(a: float, b: float, c: float, d: float, t: float) -> float:
	return b+0.5*t*(c-a+t*(2.0*a-5.0*b+4.0*c-d+t*(3.0*(b-c)+d-a)))

# --- The mesh grid: crags, beds, the gorge ------------------------------------------

## The mesh grid from the coarse one: crags on the steep ground and the
## beds stepping it into cliffs and ledges; then the highest summit is set
## to its height.
func _fine(coarse: Dictionary) -> void:
	nx = int(round(HALF.x*2.0/STEP))+1
	nz = int(round(HALF.y*2.0/STEP))+1
	heights.resize(nx*nz)
	settled.resize(nx*nz)
	var grid: PackedFloat64Array = coarse.h
	var laid: PackedFloat64Array = coarse.laid
	var n: int = coarse.n
	var corner: Vector2 = coarse.corner
	var cell: float = coarse.cell
	for j in range(nz):
		for i in range(nx):
			var p := point(i,j)
			heights[j*nx+i] = _sample(grid,n,corner,cell,p)
			settled[j*nx+i] = _sample(laid,n,corner,cell,p)
	var crag := _noise(29,1.0/CRAG_WAVE,2,FastNoiseLite.FRACTAL_RIDGED)
	var mask := _noise(41,1.0/260.0,2,FastNoiseLite.FRACTAL_FBM)
	var hi := -INF
	for h in heights: hi = maxf(hi,h)
	var out := heights.duplicate()
	stepped.resize(nx*nz)
	stepped.fill(0.0)
	for j in range(nz):
		for i in range(nx):
			var c := j*nx+i
			var h := heights[c]
			if h < CUT-30.0: continue
			var p := point(i,j)
			var slope := _gradient(heights,i,j).length()
			var steep := smoothstep(BED_STEEP.x,BED_STEEP.y,slope)
			var e := clampf((h-SEA)/(hi-SEA),0.0,1.0)
			h += CRAG*steep*(0.4+0.6*e)*(crag.get_noise_2d(p.x,p.y)-0.2)
			# The beds (`bed_at`): stepped only on steep ground, and not
			# everywhere.
			var share := BED_SHARE*steep*smoothstep(0.0,0.3,mask.get_noise_2d(p.x,p.y))
			stepped[c] = share/BED_SHARE
			out[c] = lerpf(h,bed_height(_terrace(bed_at(h,p)),p),share)
	heights = out
	# The flanks run down to BASE at the edge.
	for j in range(nz):
		for i in range(nx):
			var p := point(i,j)
			var edge := minf(HALF.x-absf(p.x),HALF.y-absf(p.y))
			heights[j*nx+i] = minf(heights[j*nx+i],BASE+edge*1.6)

## Where height `y` at `p` lies among the beds, in beds from their datum:
## its integer part the bed, the rest how far up it. The beds dip by `tilt`
## and fold over BED_FOLD_WAVE m (BED_FOLD m), and are not all one
## thickness: the count runs on unevenly (BED_SWAY over BED_SWAY_RUN beds),
## so some beds are thin and some several times as thick.
func bed_at(y: float, p: Vector2) -> float:
	var t := (y+tilt.dot(p)+_fold().get_noise_2d(p.x,p.y)*BED_FOLD)/bed
	return t+BED_SWAY*sin(t*TAU/BED_SWAY_RUN+_bed_phase)

## The height at `p` that lies `u` beds up (`bed_at`'s inverse).
func bed_height(u: float, p: Vector2) -> float:
	var t := u
	var w := TAU/BED_SWAY_RUN
	for k in range(5): t -= (t+BED_SWAY*sin(t*w+_bed_phase)-u)/(1.0+BED_SWAY*w*cos(t*w+_bed_phase))
	return t*bed-tilt.dot(p)-_fold().get_noise_2d(p.x,p.y)*BED_FOLD

func _fold() -> FastNoiseLite:
	if _fold_noise == null: _fold_noise = _noise(53,1.0/BED_FOLD_WAVE,2,FastNoiseLite.FRACTAL_FBM)
	return _fold_noise

## A bed's step: flat most of the way, then a cliff (only ever lower).
static func _terrace(x: float) -> float:
	var f := x-floorf(x)
	return floorf(x)+pow(f,BED_SHARP)

## The gorge, carved last: nothing stands over its walls. Then if anything
## stands past MOST, the whole is brought down (about BASE) to it.
func _carve() -> void:
	var peak := -INF
	var ribs := _ribs()
	for j in range(nz):
		for i in range(nx):
			var c := j*nx+i
			var p := point(i,j)
			if cut: heights[c] = minf(heights[c],gorge_face(gorge_distance(p),p.y,ribs))
			peak = maxf(peak,heights[c])
	if peak > MOST:
		var k := (MOST-BASE)/(peak-BASE)
		for c in range(nx*nz):
			heights[c] = BASE+(heights[c]-BASE)*k
	# An uncut range has no gorge, so no pinch, planned or not.
	if cut: _pinch(ribs)
	else: pinch = {}

## Some gorges narrow: for a stretch, two fins of rock jut in from the walls
## up to `pinch.top`, leaving a slot PINCH_HALF*2 m wide down the middle (the
## tight line, where the jet runs) and the wide way open above the fins.
## Drawn from a stream of its own; with none, `pinch` stays empty.
func _pinch(ribs: FastNoiseLite) -> void:
	if pinch.is_empty(): return
	# The fins reach out to where the walls stand over their tops, and only
	# where both walls do: never out over the open flanks.
	var reach := GORGE_HALF
	while gorge_wall(reach) < float(pinch.top)+30.0: reach += 2.0
	var walled := {}
	var before := heights.duplicate()
	for j in range(nz):
		for i in range(nx):
			var p := point(i,j)
			var d := gorge_distance(p)
			if absf(d) > reach: continue
			var fin := pinch_fin(d,p.y,ribs)
			if fin == -INF: continue
			var row := int(round(p.y/STEP))
			if not walled.has(row):
				var way := gorge_way(p.y)
				var across := Vector2(way.y,-way.x)
				var line := Vector2(gorge_x(p.y),p.y)
				var ok := true
				for side in [1.0,-1.0]:
					var c := cell_of(line+across*side*(reach+16.0))
					if before[c.y*nx+c.x] < float(pinch.top)+10.0: ok = false
				walled[row] = ok
			if not walled[row]: continue
			var c := j*nx+i
			heights[c] = maxf(heights[c],fin)
	# Where the walls don't stand the whole of its middle, no pinch.
	var z := float(pinch.z)-float(pinch.length)*0.5
	while z < float(pinch.z)+float(pinch.length)*0.5:
		if pinch_share(z) >= 0.999 and not walled.get(int(round(z/STEP)),false):
			heights = before
			pinch = {}
			return
		z += STEP

## Where the pinch would stand, if the gorge has one (`_pinch` keeps it
## only if the walls stand round it): drawn before the carving, so the
## couloirs spare its walls.
func _plan_pinch() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*61+3
	pinch = {}
	if rng.randf() >= PINCH_ODDS: return
	pinch = {"z":spine(float(gorge.x))+rng.randf_range(PINCH_AT.x,PINCH_AT.y),"length":rng.randf_range(PINCH_LENGTH.x,PINCH_LENGTH.y),"top":rng.randf_range(PINCH_TOP.x,PINCH_TOP.y)}

## How far into the pinch's stretch `z` is (0 outside, 1 in its middle).
func pinch_share(z: float) -> float:
	if pinch.is_empty(): return 0.0
	var off := absf(z-float(pinch.z))
	var half := float(pinch.length)*0.5
	return 1.0-smoothstep(half-PINCH_RAMP,half,off)

## The fin's top at `d` m out from the gorge's line, `z` along it, or -INF
## where there is none; never over `pinch.top`, crags only taking from it.
func pinch_fin(d: float, z: float, ribs: FastNoiseLite) -> float:
	var share := pinch_share(z)
	if share <= 0.0 or absf(d) < PINCH_HALF: return -INF
	var rise := smoothstep(PINCH_HALF,PINCH_HALF+3.0,absf(d))
	# Broken along their tops, as teeth, not a slab: deepest away from the
	# slot's lips, which stand nearly whole.
	var crag := maxf(0.0,ribs.get_noise_2d(z*2.0,d))*8.0
	var teeth := maxf(0.0,ribs.get_noise_2d(z*2.6+517.0,absf(d)*0.6+signf(d)*271.0))
	crag += FIN_TEETH*teeth*smoothstep(PINCH_HALF+2.0,PINCH_HALF+14.0,absf(d))
	var top := float(pinch.top)-crag
	return lerpf(GORGE_FLOOR,top,share*rise)

## The jet's height down the gorge at `z`: dipping into the pinch's slot.
func jet_height(z: float, high: float) -> float:
	if pinch.is_empty(): return high
	return lerpf(high,float(pinch.top)-PINCH_JET_UNDER,pinch_share(z))

func _measure() -> void:
	top = -INF
	for h in heights: top = maxf(top,h)
	summits.clear()
	for k: Dictionary in _peaks:
		var at := Vector2(k.x,spine(k.x))
		var best := Vector3(at.x,-INF,at.y)
		var reach := 70.0
		var lo := cell_of(at-Vector2.ONE*reach)
		var hi := cell_of(at+Vector2.ONE*reach)
		for j in range(lo.y,hi.y+1):
			for i in range(lo.x,hi.x+1):
				var h := heights[j*nx+i]
				if h > best.y:
					var p := point(i,j)
					best = Vector3(p.x,h,p.y)
		summits.append(best)

## The cloud round the foot: puffs along the line where the flanks go into
## the sea, WRAP_APART apart, set a little out down the slope, and a few
## along the gorge's floor.
func _wrap() -> void:
	wraps = PackedVector4Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*7+3
	var line := SEA+6.0
	var spots := []
	for j in range(1,nz-1,2):
		for i in range(1,nx-1,2):
			var h := heights[j*nx+i]
			var right := heights[j*nx+i+2] if i+2 < nx else h
			var down := heights[(j+2)*nx+i] if j+2 < nz else h
			if (h-line)*(right-line) < 0.0 or (h-line)*(down-line) < 0.0: spots.append(Vector2i(i,j))
	# A fixed order from the seed, then kept if apart from those kept.
	var order := range(spots.size())
	for k in range(order.size()-1,0,-1):
		var m := rng.randi_range(0,k)
		var t: int = order[k]
		order[k] = order[m]
		order[m] = t
	var kept: Array[Vector2] = []
	for k: int in order:
		var s: Vector2i = spots[k]
		var p := point(s.x,s.y)
		var ok := true
		for q in kept:
			if q.distance_to(p) < WRAP_APART:
				ok = false
				break
		if not ok: continue
		kept.append(p)
		var g := _gradient(heights,s.x,s.y)
		var down_way := -g.normalized() if g.length() > 0.001 else Vector2.ZERO
		var size := rng.randf_range(WRAP_SIZE.x,WRAP_SIZE.y)
		var at := p+down_way*size*0.15
		wraps.append(Vector4(at.x,SEA+rng.randf_range(-4.0,6.0)+size*rng.randf_range(0.0,0.3),at.y,size))
	# Along the gorge's floor, where its walls stand over the sea.
	var z := -HALF.y if cut else HALF.y
	while z < HALF.y:
		var p := Vector2(gorge_x(z),z)
		var wall: Variant = height_at(p+Vector2(GORGE_HALF*3.0,0.0))
		var other: Variant = height_at(p-Vector2(GORGE_HALF*3.0,0.0))
		if wall != null and other != null and minf(float(wall),float(other)) > SEA:
			wraps.append(Vector4(p.x+rng.randf_range(-8.0,8.0),SEA+rng.randf_range(0.0,10.0),p.y,rng.randf_range(WRAP_SIZE.x,WRAP_SIZE.y)))
		z += WRAP_APART*0.8

## Spruces in stands on the gentle ground and the ledges, clear of the
## gorge's floor, a little scattered off the grid.
func _plant() -> void:
	trees.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*17+5
	var stands := _noise(83,1.0/110.0,2,FastNoiseLite.FRACTAL_FBM)
	var z := -HALF.y+TREE_STEP
	while z < HALF.y-TREE_STEP:
		var x := -HALF.x+TREE_STEP
		while x < HALF.x-TREE_STEP:
			var p := Vector2(x,z)+Vector2(rng.randf_range(-0.45,0.45),rng.randf_range(-0.45,0.45))*TREE_STEP
			x += TREE_STEP
			if stands.get_noise_2d(p.x,p.y) < TREE_PATCH or (cut and absf(gorge_distance(p)) < GORGE_HALF*2.5): continue
			var h: Variant = height_at(p)
			if h == null or float(h) < TREE_BAND.x or float(h) > minf(TREE_BAND.y,snowline-SNOW_LINGER): continue
			var c := cell_of(p)
			if _gradient(heights,c.x,c.y).length() > TREE_SLOPE: continue
			trees.append(Vector4(p.x,p.y,rng.randf_range(TREE_HEIGHT.x,TREE_HEIGHT.y),TREE_VARIANTS[rng.randi() % TREE_VARIANTS.size()]))
			if trees.size() >= TREE_CAP: return
		z += TREE_STEP

# --- Reading it -------------------------------------------------------------------

## A mesh grid point's place (x, z).
func point(i: int, j: int) -> Vector2:
	return Vector2(-HALF.x+i*STEP,-HALF.y+j*STEP)

## The cell holding a point, clamped to the grid.
func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor((p.x+HALF.x)/STEP)),0,nx-1),clampi(int(floor((p.y+HALF.y)/STEP)),0,nz-1))

## True if a point lies over the built mesh.
func covers(p: Vector2) -> bool:
	return height_at(p) != null

## The ground's height at a point (the faces as built), or null off the
## grid or where the faces were left out under the sea.
func height_at(p: Vector2) -> Variant:
	var fx := (p.x+HALF.x)/STEP
	var fz := (p.y+HALF.y)/STEP
	if fx < 0.0 or fz < 0.0 or fx >= nx-1 or fz >= nz-1: return null
	var i := int(fx)
	var j := int(fz)
	var u := fx-i
	var v := fz-j
	var h00 := heights[j*nx+i]
	var h10 := heights[j*nx+i+1]
	var h01 := heights[(j+1)*nx+i]
	var h11 := heights[(j+1)*nx+i+1]
	if maxf(maxf(h00,h10),maxf(h01,h11)) < CUT: return null
	if _split(h00,h10,h01,h11):
		# Split along (0,0)-(1,1).
		if u >= v: return h00+(h10-h00)*u+(h11-h10)*v
		return h00+(h11-h01)*u+(h01-h00)*v
	# Split along (1,0)-(0,1).
	if u+v <= 1.0: return h00+(h10-h00)*u+(h01-h00)*v
	return h11+(h01-h11)*(1.0-u)+(h10-h11)*(1.0-v)

## Which way a cell is split: along the diagonal whose ends are nearer in
## height, so ridges and gullies follow the grid's faces, not zigzag.
static func _split(h00: float, h10: float, h01: float, h11: float) -> bool:
	return absf(h00-h11) <= absf(h10-h01)

## The slope (gradient) at each mesh point averaged over CALM_REACH points
## each way (a box, run along x then z): the ground's broad lie. Made once,
## for the near faces and the far alike.
func _calm() -> PackedFloat32Array:
	if _calm_field.size() == nx*nz: return _calm_field
	var field := PackedFloat32Array()
	field.resize(nx*nz)
	for j in range(nz):
		for i in range(nx): field[j*nx+i] = _gradient(heights,i,j).length()
	field = _box(field,1,nx,nz)
	_calm_field = _box(field,nx,nz,nx)
	return _calm_field

## A running box mean of CALM_REACH each way down lines `stride` apart
## within a line, `count` long, `lines` of them (the other axis).
static func _box(field: PackedFloat32Array, stride: int, count: int, lines: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(field.size())
	var step := 1 if stride != 1 else count
	for line in range(lines):
		var first := line*step
		var sum := 0.0
		for k in range(mini(CALM_REACH,count-1)+1): sum += field[first+k*stride]
		var lo := 0
		var hi := mini(CALM_REACH,count-1)
		for k in range(count):
			out[first+k*stride] = sum/float(hi-lo+1)
			if k+CALM_REACH+1 < count:
				hi += 1
				sum += field[first+hi*stride]
			if k-CALM_REACH >= 0:
				sum -= field[first+lo*stride]
				lo += 1
	return out

## How much each mesh point lies in a hollow (m): its neighbours' mean
## height two points out over its own; under 0 on a ridge.
func _hollows() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(nx*nz)
	for j in range(nz):
		for i in range(nx):
			var around := heights[j*nx+maxi(i-2,0)]+heights[j*nx+mini(i+2,nx-1)]+heights[maxi(j-2,0)*nx+i]+heights[mini(j+2,nz-1)*nx+i]
			out[j*nx+i] = around*0.25-heights[j*nx+i]
	return out

## The rise (per metre) at a mesh grid point, over `reach` points each way.
func _gradient_over(field: PackedFloat32Array, i: int, j: int, reach: int) -> Vector2:
	var i0 := maxi(i-reach,0)
	var i1 := mini(i+reach,nx-1)
	var j0 := maxi(j-reach,0)
	var j1 := mini(j+reach,nz-1)
	return Vector2((field[j*nx+i1]-field[j*nx+i0])/(maxf(i1-i0,1)*STEP),(field[j1*nx+i]-field[j0*nx+i])/(maxf(j1-j0,1)*STEP))

## The rise (per metre, in x and z) at a mesh grid point.
func _gradient(field: PackedFloat32Array, i: int, j: int) -> Vector2:
	var l := field[j*nx+maxi(i-1,0)]
	var r := field[j*nx+mini(i+1,nx-1)]
	var d := field[maxi(j-1,0)*nx+i]
	var u := field[mini(j+1,nz-1)*nx+i]
	return Vector2((r-l)/(2.0*STEP),(u-d)/(2.0*STEP))

## The way through the gorge at glide height: points (x, y, z) along its
## line from one side of the range to the other.
func gorge_line(y: float, count := 64) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in range(count):
		var z := lerpf(-HALF.y,HALF.y,float(k)/(count-1))
		out.append(Vector3(gorge_x(z),y,z))
	return out

## The range's reach from its middle over the sea's top (m), for keeping
## other things clear and for the haze.
func reach() -> float:
	var r := 0.0
	for j in range(0,nz,3):
		for i in range(0,nx,3):
			if heights[j*nx+i] > SEA: r = maxf(r,point(i,j).length())
	return r

## The gorge's buttresses: ridged noise, ribs running out from the walls.
func _ribs() -> FastNoiseLite:
	return _noise(71,1.0/BUTTRESS_WAVE,2,FastNoiseLite.FRACTAL_RIDGED)

func _noise(salt: int, frequency: float, octaves: int, fractal: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed*13+salt
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_type = fractal
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.1
	n.fractal_gain = 0.5
	if fractal == FastNoiseLite.FRACTAL_RIDGED: n.fractal_weighted_strength = 0.5
	return n

# --- The mesh -----------------------------------------------------------------------

## The range's faces as surface arrays for the plate's ground material,
## coloured per face from the world's `grass` and `rock` (linear) and its
## `gravel`, every vertex laid `shift` off (SkyIslets OFF_MAP). Safe on a
## worker.
func body_arrays(grass: Array, rock: Array, gravel: Color, shift := Vector3.ZERO, stride := 1, snow := SNOW_COLOUR) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*31+7
	var fields := [_noise(67,1.0/90.0,3,FastNoiseLite.FRACTAL_FBM),_noise(73,1.0/150.0,2,FastNoiseLite.FRACTAL_FBM),_noise(79,1.0/70.0,2,FastNoiseLite.FRACTAL_FBM)]
	# The ground's lie at each point, for the colours; and over NORMAL_REACH
	# points each way for the light, which leans on that broader lie
	# (reference_surface `facet_soft`) so the grid's small steps don't each
	# catch it.
	var normals := PackedVector3Array()
	normals.resize(nx*nz)
	var broad := PackedVector3Array()
	broad.resize(nx*nz)
	for j in range(nz):
		for i in range(nx):
			var g := _gradient(heights,i,j)
			normals[j*nx+i] = Vector3(-g.x,1.0,-g.y).normalized()
			g = _gradient_over(heights,i,j,NORMAL_REACH)
			broad[j*nx+i] = Vector3(-g.x,1.0,-g.y).normalized()
	var hollows := _hollows()
	var calm := _calm()
	var colours := _strata_colours()
	colours["snow"] = snow
	var vertices := PackedVector3Array()
	var normal_list := PackedVector3Array()
	var colour_list := PackedColorArray()
	for j in range(0,nz-stride,stride):
		for i in range(0,nx-stride,stride):
			var c00 := j*nx+i
			var c10 := c00+stride
			var c01 := c00+nx*stride
			var c11 := c01+stride
			var h00 := heights[c00]
			var h10 := heights[c10]
			var h01 := heights[c01]
			var h11 := heights[c11]
			if maxf(maxf(h00,h10),maxf(h01,h11)) < CUT: continue
			var p00 := _v(i,j,h00)
			var p10 := _v(i+stride,j,h10)
			var p01 := _v(i,j+stride,h01)
			var p11 := _v(i+stride,j+stride,h11)
			var tris: Array
			if _split(h00,h10,h01,h11): tris = [[p00,p11,p10,c00,c11,c10],[p00,p01,p11,c00,c01,c11]]
			else: tris = [[p00,p01,p10,c00,c01,c10],[p10,p01,p11,c10,c01,c11]]
			for t: Array in tris:
				var a: Vector3 = t[0]
				var b: Vector3 = t[1]
				var d: Vector3 = t[2]
				var ib: int = t[4]
				var id: int = t[5]
				var n := (b-a).cross(d-a).normalized()
				if n.y < 0.0:
					var swap := b
					b = d
					d = swap
					var turn := ib
					ib = id
					id = turn
					n = -n
				# The colour reads the ground's smoothed lie more than the
				# face's own, so it lies in patches, not face by face.
				var lie := (normals[t[3]]+normals[ib]+normals[id]+n*1.2).normalized()
				var ledge := (stepped[t[3]]+stepped[ib]+stepped[id])/3.0
				var hollow := (hollows[t[3]]+hollows[ib]+hollows[id])/3.0
				var soft := (calm[t[3]]+calm[ib]+calm[id])/3.0
				var tone := _tone((a+b+d)/3.0,lie,soft,(settled[t[3]]+settled[ib]+settled[id])/3.0,ledge,hollow,grass,rock,gravel,colours,fields,rng)
				# Godot's front faces wind clockwise seen from outside.
				for q in [[a,t[3]],[d,id],[b,ib]]:
					vertices.append((q[0] as Vector3)+shift)
					normal_list.append(broad[q[1]])
					colour_list.append(tone)
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	uv.resize(vertices.size())
	uv2.resize(vertices.size())
	uv.fill(Vector2(0.0,1.0))
	for k in range(vertices.size()): uv2[k] = Vector2(0.5,vertices[k].y)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normal_list
	arrays[Mesh.ARRAY_COLOR] = colour_list
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	return arrays

## A one-surface mesh from surface arrays, with its material.
static func mesh_from(arrays: Array, material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if material != null: mesh.surface_set_material(0,material)
	return mesh

func _v(i: int, j: int, h: float) -> Vector3:
	var p := point(i,j)
	return Vector3(p.x,h,p.y)

## The strata's colours (linear): topsoil, clay, the granite core's three
## beds and the two shales.
static func _strata_colours() -> Dictionary:
	var out := {}
	for key: String in Strata.COLORS: out[key] = Color(Strata.COLORS[key]).srgb_to_linear()
	return out

## A face's colour, from fields that change over tens of metres so the
## colours lie in patches and bands, not speckled face by face; each face is
## only nudged (FACE_JITTER), so the facets still read. Grass on gentle
## ground below GRASS_HIGH and on the beds' ledges; earth where the ground
## steepens and under a stepped ledge's lip; scree down the gullies the
## erosion filled; and on the steep faces the world's rock, a little lighter
## or darker bed by bed (the granite core's three tones) with now and then a
## band of shale.
func _tone(at: Vector3, n: Vector3, calm: float, laid: float, ledge: float, hollow: float, grass: Array, rock: Array, gravel: Color, strata: Dictionary, fields: Array, rng: RandomNumberGenerator) -> Color:
	var slope := sqrt(maxf(0.0,1.0-n.y*n.y))/maxf(n.y,0.001)
	var p := Vector2(at.x,at.z)
	var patch: float = (fields[0] as FastNoiseLite).get_noise_2d(p.x,p.y)
	var mix_rock: float = (fields[1] as FastNoiseLite).get_noise_2d(p.x,p.y)*0.5+0.5
	var mix_green: float = (fields[2] as FastNoiseLite).get_noise_2d(p.x,p.y)*0.5+0.5
	var high := at.y+patch*45.0
	var jitter := 1.0+rng.randf_range(-FACE_JITTER,FACE_JITTER)
	var stone := (rock[0] as Color).lerp(rock[rock.size()-1],smoothstep(0.3,0.7,mix_rock))
	var green := (grass[0] as Color).lerp(grass[2 if grass.size() > 2 else 0],smoothstep(0.25,0.75,mix_green))
	# The rock cools toward the blue-grey of the far peaks over the sea
	# (shaders/sky_cloud_sea_opal.gdshaderinc), the more the higher, so the
	# range and the backdrop read as one family.
	var grey := (stone.r+stone.g+stone.b)/3.0
	stone = stone.lerp(Color(grey*COOL_HUE.x,grey*COOL_HUE.y,grey*COOL_HUE.z),COOL*(0.5+0.5*smoothstep(SEA,top,at.y)))
	# The beds, their edges wandering a little across each face.
	var u := bed_at(at.y+(fields[0] as FastNoiseLite).get_noise_2d(p.x*2.3+71.0,p.y*2.3-13.0)*BED_EDGE,p)
	var phase := fposmod(u,1.0)
	var index := floori(u)
	# Snow above a ragged line: lower down the hollows and gullies, higher
	# on the wind-scoured ridges; up high it holds on steeper ground. Below
	# the line it lingers on the beds' treads and in the deeper hollows.
	var line := snowline+patch*SNOW_RAG-clampf(hollow,-10.0,25.0)*SNOW_HOLLOW
	var deep := smoothstep(line-20.0,line+60.0,at.y)
	var snowy := at.y > line and slope < lerpf(SNOW_SLOPE.x,SNOW_SLOPE.y,deep)
	snowy = snowy or (ledge > 0.5 and phase < 0.5 and slope < 1.3 and at.y > line-SNOW_LINGER)
	snowy = snowy or (hollow > 5.0 and slope < 1.1 and at.y > line-SNOW_LINGER*1.3)
	if snowy:
		var white: Color = strata.snow
		var blue := clampf(hollow/18.0,0.0,1.0)
		return Color(white.r*lerpf(1.0,0.93,blue),white.g*lerpf(1.0,0.965,blue),white.b,1.0)*(1.0+rng.randf_range(-SNOW_JITTER,SNOW_JITTER))
	# Grass and earth by the ground's lie over CALM_REACH m as well as the
	# face's own, so they lie in whole patches, never a lone green facet on
	# a cliff.
	if slope < GRASS_SLOPE*1.5 and calm < GRASS_SLOPE+patch*0.3 and high < GRASS_HIGH:
		if laid > SCREE and slope > 0.35: return gravel.lerp(stone,0.3)*jitter
		# Thinner and drier up high.
		return green.lerp(stone,smoothstep(GRASS_HIGH-140.0,GRASS_HIGH+20.0,high)*0.45)*jitter
	var earthy: Color = (strata.topsoil as Color).lerp(strata.clay,smoothstep(0.35,0.65,mix_green)*0.6)
	if slope < EARTH_SLOPE*1.5 and calm < EARTH_SLOPE+patch*0.25 and high < GRASS_HIGH+30.0:
		if laid > SCREE*0.6: return gravel.lerp(stone,0.45)*jitter
		return earthy.lerp(stone,0.72+0.2*mix_rock)*jitter
	# A stepped bed's tread holds grass; under its lip, the earth band.
	if ledge > 0.5 and phase < 0.5 and slope < 1.4 and calm < LEDGE_CALM and high < GRASS_HIGH+40.0:
		return green.lerp(stone,0.3)*jitter
	if ledge > 0.6 and phase > 1.0-LIP and high < GRASS_HIGH+60.0:
		return earthy.lerp(stone,0.5)*jitter
	# The beds: the granite core's three tones, and now and then a band of
	# the islands' own sides (scripts/strata.gd): a pale sand bed or a dark
	# shale one, in the world's rock as the granite is, so the range is
	# layered as an island's side is, only a hundredfold.
	# They show on the cliffs, hardly on the easier rock, and a gully's
	# scree and fresh-cut rock run down across them.
	var show := smoothstep(BAND_SLOPE.x,BAND_SLOPE.y,slope)
	show *= 1.0-maxf(smoothstep(GULLY_CUT.x,GULLY_CUT.y,-laid),smoothstep(GULLY_CUT.x,GULLY_CUT.y,hollow))
	var core_a: Color = strata.core_a
	var key := _bed_kind(index)
	var tone: Color = strata[key]
	var own := Color(stone.r/core_a.r,stone.g/core_a.g,stone.b/core_a.b)
	if key == "sand" or key == "shale_dark":
		return (tone*own).lerp(stone,1.0-BAND_TONE*show)*jitter
	var shade := (tone.r+tone.g+tone.b)/(core_a.r+core_a.g+core_a.b)
	return stone*lerpf(1.0,shade,BED_TONE*show)*jitter

## What a bed is, by its index up the range: mostly the granite's three
## tones, with BANDS' odds of a sand or a shale band, seeded per range.
func _bed_kind(index: int) -> String:
	var h := absi(hash([seed,index,"bed"])) % 1000/1000.0
	if h < BANDS.x: return "shale_dark"
	if h < BANDS.x+BANDS.y: return "sand"
	return ["core_a","core_b","core_c"][posmod(index,3)]
