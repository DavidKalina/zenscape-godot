extends RefCounted
## One forested isle floating in the sky (scripts/sky_forest_isles.gd places
## them): far bigger than the islets (scripts/sky_islet.gd), a long, ragged
## piece of the land below torn off and hung in the air, a few hundred
## metres from end to end. Not buildable, so not square: its outline wanders,
## lobed and pinched, longer one way than the other. On top, gentle rolling
## ground, a lake or two joined by a stream, the lower one spilling off the
## rim as a fall, and old forest: giant redwoods standing far apart, their
## crowns high, so the glide can slip in under the canopy and fly the lanes
## between the trunks, out over the water and up through a gap.
##
## Built the way the sky peaks are (scripts/sky_peak.gd), as heightfields
## over the isle's own (x, z), with the plate's own techniques:
##   the outline: a share field, 0 at the middle and 1 on the rim, from an
##     egg-shaped ellipse with seeded lobes, a promontory or two toward the
##     ends, bays bitten out, often a neck pinched in between two lobes,
##     its points pushed about by a slow warp so no edge runs true; and often
##     a small chunk broken off, hanging just off the rim;
##   the top: a low dome with rolling hills over it, weathered by the plate's
##     stream-power erosion (scripts/terrain_erosion.gd `erode`, run in plate
##     units on a grid whose cells are the plate's 0.7 m scaled up); then the
##     lakes' basins, their banks and the channels cut;
##   the underside: the rock hangs as an upside-down mountain, deepest under
##     the middle and tapering to the rim, with hanging spurs, the same
##     erosion run on its depth (so gullies flute its flanks from the keel to
##     the rim) and the rock's beds stepping the steepest faces a little.
##     It is drawn in the plate's own earth-sides material, so it shows the
##     chunks' own strata (scripts/strata.gd: topsoil, clay, sand, shale,
##     bedrock) as clean bands, scaled to the isle (ROCK_SCALE), misting
##     away toward the keel.
## The rim is the share field's contour, cut through the grid cells (each
## cell clipped to the inside), with a ragged wall down to the rock: turf
## hanging over by more or less, the earth slumping out here and there, its
## foot reaching unevenly down; roots hang from it and from the rock.
## The giants' heights are ragged too: stands of tall and lower, young ones
## low among them, a few emergents far over the rest, lower toward the rim
## and the shores.
##
## The frame is the isle's own: x along its length, y up, the top's plane at
## y 0 (the rim stands near it, the middle a few metres over it).
##
## The glide reads it as a solid (`solid`): the ground and the water over it,
## the rock under it, every trunk a column it is turned aside by, and every
## crown a solid with a top it can ride over and an underside it slides
## along, so under the canopy it flies the lanes, never through a crown.

const Erosion = preload("res://scripts/terrain_erosion.gd")
const Strata = preload("res://scripts/strata.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")

## The outline: its length (m), its width as a share of that (and the
## width's bounds, m), lobes [count round, share out], how much longer one
## end is, and the warp (m, over a wavelength of m).
const LENGTH := Vector2(280.0,420.0)
const BREADTH := Vector2(0.34,0.46)
const WIDE := Vector2(85.0,165.0)
const LOBES := [[2,0.07],[3,0.06],[5,0.04],[7,0.025]]
const EGG := 0.18
const WARP := 14.0
const WARP_WAVE := 130.0
## Promontories: [count range], how far out (share), how narrow (radians);
## they stand toward the ends, within PROM_ENDS of the long axis.
const PROMS := Vector2i(1,2)
const PROM_OUT := Vector2(0.2,0.32)
const PROM_WIDE := Vector2(0.09,0.16)
const PROM_ENDS := 0.7
## Bays bitten out of the rim: count, radius (share of the half width).
const BAYS := Vector2i(1,3)
const BAY_SIZE := Vector2(0.3,0.5)
## The neck between two lobes: the odds of one, how hard it pinches (share
## of the width taken), and its length (share of the half length).
const NECK_ODDS := 0.6
const NECK := Vector2(0.4,0.55)
const NECK_LONG := 0.13
## A small chunk broken off and hanging beside the rim: the odds, its
## radius (m), the gap to the rim (m) and its rock's depth (times its
## radius).
const CHUNK_ODDS := 0.65
const CHUNK := Vector2(13.0,22.0)
const CHUNK_GAP := Vector2(6.0,13.0)
const CHUNK_DEPTH := Vector2(1.4,2.2)
## The mesh grid's spacing (m) and the erosion grid's points a side.
const STEP := 4.0
const ERODE_N := 129
const PLATE_CELL := 0.7
## The top: the dome's rise (m), the hills' height (m) and wavelength (m),
## and how far the ground rounds down to the rim (m).
const DOME := Vector2(6.0,12.0)
const HILLS := Vector2(5.0,9.0)
const HILL_WAVE := 110.0
const ROUND := 2.5
## The plate's erosion, in plate metres: gentle on the top, harder on the
## rock underneath.
const ERODE_TOP := {"detail":0.25,"frequency":0.16,"warp":1.3,"slope_ref":1.2,"iterations":25,"k":0.004,
	"channel_area":5.0,"jitter":0.6,"max_cut":0.5,"deposit":0.5,"deposit_slope":0.35,"deposit_cap":0.08}
const ERODE_UNDER := {"detail":0.1,"frequency":0.18,"warp":1.3,"slope_ref":1.0,"iterations":35,"k":0.006,
	"channel_area":4.0,"jitter":0.7,"max_cut":0.9,"deposit":0.3,"deposit_slope":0.35,"deposit_cap":0.08}
## The side: the grass lip (m below the rim, m out) and the earth band's
## foot under the top's plane (m), where the rock begins.
const LIP := Vector2(1.2,0.7)
const FOOT := 5.0
## The earth band is ragged along the rim, over RAGGED_WAVE m: the turf hangs
## over by LIP times LIP_RANGE, the foot reaches FOOT times FOOT_RANGE down,
## and here and there the earth slumps out (m) at mid height.
const RAGGED_WAVE := 16.0
const LIP_RANGE := Vector2(0.5,2.4)
const FOOT_RANGE := Vector2(0.5,1.7)
const SLUMP := 2.2
## The rock: its depth under the foot at the middle (share of the width, and
## the most, m), how it tapers (the power of the share in from the rim), the
## cliff band under the rim (m), hanging spurs (count, share of the half
## extents, share of the depth), and crags (m, wavelength m).
const DEPTH := Vector2(0.48,0.62)
const DEPTH_MOST := 85.0
const TAPER := Vector2(0.95,1.3)
const WALL := 7.0
## How round the keel's tip is (share of the way out).
const KEEL_ROUND := 0.18
const SPURS := Vector2i(1,3)
const SPUR_SIZE := Vector2(0.25,0.45)
const SPUR_DEPTH := Vector2(0.55,0.85)
const CRAG := 0.0
const CRAG_WAVE := 40.0
## Beds: a step (m), how hard each steps, their tilt (m a metre), the
## steepness they step from and fully at.
const BED := Vector2(8.0,12.0)
const BED_SHARE := 0.15
const BED_SHARP := 2.0
const BED_TILT := Vector2(0.02,0.06)
const BED_STEEP := Vector2(0.6,1.4)
## Lakes: the odds of a second, the first's x radius (share of the length),
## how round (z over x), the deepest (m), how far in the outer bank must
## stay (share), the bed at the shore under the water (m), and how far the
## water stands under the lowest of its banks (m).
const LAKES_TWO := 0.7
const LAKE := Vector2(0.1,0.15)
const LAKE_ROUND := Vector2(0.55,0.85)
const LAKE_DEPTH := Vector2(3.0,6.0)
const LAKE_IN := 0.8
const SHORE_DROP := 0.5
const BANK := 0.7
## Channels (the stream between the lakes, the outflow to the rim): half
## width (m), depth (m), and the least step between the lakes' levels (m).
const CHANNEL := 3.2
const CHANNEL_DEPTH := 1.0
const STEP_UP := 2.0
## The water's sheet spacing (m) and the most fetch it counts (m).
const WATER_STEP := 2.5
const FETCH := 9.0
## The water's arrays carry the fetch as two float vec4s (SkyIslet).
const WATER_FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
## The giants: height (m), where the crown starts (share of the height; at
## the forest's edges lower), the crown's radius (share of its own length:
## the plate's redwood's, a little broadened, never squashed into a clump),
## the trunk's radius (m), how far
## apart trunks stand (m, give or take a share), and how far in from the rim
## (m). The forest leaves clearings where its noise is under CLEARING.
const GIANT := Vector2(42.0,66.0)
## The giants' stands: their heights follow a slow noise (wavelength m), so
## they grow in clusters of tall and lower; EMERGENT (a count) stand far
## over the rest (EMERGE times the tallest stand); toward the rim and the lakes they are lower
## (by as much as RIM_LOW and SHORE_LOW).
const STAND_WAVE := 75.0
const EMERGENT := Vector2i(3,6)
const EMERGE := Vector2(1.3,1.5)
## An emergent's crown spreads at most this many times its stand's, and it
## stands at most EMERGE_MOST m, so the glide still clears its top.
const EMERGE_WIDE := 1.25
const EMERGE_MOST := 88.0
## A share of the giants away from the aisles are young: lower (m), their
## crowns low as the edges' are.
const YOUNG := 0.3
const YOUNG_TALL := Vector2(20.0,32.0)
const RIM_LOW := 0.38
const SHORE_LOW := 0.3
const CROWN_FROM := Vector2(0.38,0.44)
const EDGE_FROM := Vector2(0.28,0.36)
const CROWN_WIDE := Vector2(0.27,0.31)
const TRUNK := Vector2(1.1,1.5)
const APART := 18.0
const APART_JITTER := 0.15
const RIM_IN := 8.0
const CLEARING := -0.4
## Lanes: aisles kept clear of trunks for AISLE_HALF m either side of their
## line, and the band over the ground the glide flies them at (m).
const AISLE_HALF := 10.0
## How far (m) a crown lining an aisle leans out over it, at most.
const LEAN := 5.5
const GLIDE_LANE := Vector2(8.0,15.0)
## Spruces: the understory's heights (m), the taller ones at the edges, how
## far apart, the crown's radius (share of the height), their variants
## (scripts/hero_trees.gd SPRUCE), and the patch noise they stand over.
const SPRUCE := Vector2(4.5,9.0)
const EDGE_SPRUCE := Vector2(9.0,15.0)
const SPRUCE_APART := 6.0
const SPRUCE_CROWN := 0.3
const SPRUCE_VARIANTS := [0,1,2,4]
const SPRUCE_PATCH := -0.15
const SPRUCE_CAP := 700
## Ferns on the forest floor under the giants' crowns: how many at most,
## their size (times the plate's fern) and the share of spots under a crown
## that get one.
const FERNS := 520
const FERN_SIZE := Vector2(2.4,4.0)
const FERN_ODDS := 0.45
## Trees are looked up in cells this big (m).
const TREE_CELL := 20.0
## Roots: one about every ROOT_APART m of rim, ROOT_LONG m long; and
## UNDER_ROOTS more from the rock under the rim.
const ROOT_APART := 3.2
const ROOT_LONG := Vector2(2.5,12.0)
const UNDER_ROOTS := 110
## A solid counts for a point this far under its underside (m), so the
## glide meets a crown's underside as a ceiling, not side on.
const CATCH := SkyGlide.CLEAR+3.0
## The forest floor's needle litter, and the lakes' dark bed (sRGB).
const LITTER := Color("5b4a35")
const LAKE_BED := Color("2b3236")
## The rock is drawn in the plate's own earth-sides material, whose strata
## are laid by the mesh's own height at the plate's scale (scripts/
## strata.gd FLOORS); its mesh is built this many times smaller and drawn
## this many times bigger, so the bands run as deep under the rim as the
## isle is big to the plate.
const ROCK_SCALE := 7.0

var seed := 0
## The outline: length and width (m), the half extents, the egg, lobes
## (count, share, phase) and the warp.
var length := 300.0
var width := 120.0
var half := Vector2(150.0,60.0)
var egg := 0.0
var lobes := PackedVector3Array()
var turn := 0.0
## Promontories (angle, share out, width), bays (x, z, radius, 0) in the
## warped frame, the neck (x, pinch, length), and the chunk (x, z, radius,
## depth), zero radius if none.
var proms := PackedVector3Array()
var bays := PackedVector4Array()
var neck := Vector3.ZERO
var chunk := Vector4.ZERO
var lake_side := 1.0
## The grid: its half extents (m), points along x and z, and per point the
## share, the top's height, the underside's and the erosion's cut (m).
var ext := Vector2.ZERO
var nx := 0
var nz := 0
var shares := PackedFloat32Array()
var heights := PackedFloat32Array()
var under := PackedFloat32Array()
## The rock: depth at the middle (m), taper, spurs (x, z, radius, depth).
var depth := 60.0
var taper := 1.0
var spurs := PackedVector4Array()
var bed := 10.0
var tilt := Vector2.ZERO
## Lakes: {middle, radii, turn, lobes, level, depth}, the lowest first is
## not promised; `lower` is the one the outflow leaves.
var lakes: Array = []
var lower := 0
## Channels: {points, levels, kind ("stream", "outflow")}.
var channels: Array = []
## The outflow's lip on the rim, the way out, and its level.
var lip := Vector2.ZERO
var lip_out := Vector2.ZERO
var lip_level := 0.0
## Aisles: lines kept clear of trunks.
var aisles: Array[PackedVector2Array] = []
## Trees: (x, z, ground, height); crowns (bottom, top, radius, trunk radius)
## in the isle's frame; kind -1 a giant, else a spruce variant.
var trees := PackedVector4Array()
var crowns := PackedVector4Array()
var kinds := PackedInt32Array()
## How far each crown's middle stands off its trunk (x, z), leaning out
## over an aisle.
var leans := PackedVector2Array()
## Ferns: (x, z, ground, size).
var ferns := PackedVector4Array()
## Roots: (x, y, z, length), hanging from the y given.
var roots := PackedVector4Array()
## The highest ground, the deepest rock, the highest crown (m).
var top := 0.0
var bottom := 0.0
var canopy := 0.0

## Per grid point, the level of the water nearest (lakes within their
## banks, channels within reach), or -INF.
var wet := PackedFloat32Array()

var _rng := RandomNumberGenerator.new()
var _warp: FastNoiseLite
var _rag: FastNoiseLite
var _bv := PackedVector3Array()
var _bn := PackedVector3Array()
var _bc := PackedColorArray()
var _rv := PackedVector3Array()
var _rn := PackedVector3Array()
var _shift := Vector3.ZERO
var _cells := {}
var _top_delta := {}

## The isle for `seed_value` (a hash of its spot).
static func make(seed_value: int) -> RefCounted:
	var isle: RefCounted = new()
	isle._shape(seed_value)
	return isle

func _shape(seed_value: int) -> void:
	seed = seed_value
	_rng.seed = seed_value
	_plan()
	_grid_shares()
	_erode_top()
	_lakes()
	_channels()
	_carve()
	_underside()
	_aisles()
	_plant()
	_roots()
	_measure()

# --- The plan -----------------------------------------------------------------------

func _plan() -> void:
	length = _rng.randf_range(LENGTH.x,LENGTH.y)
	width = clampf(length*_rng.randf_range(BREADTH.x,BREADTH.y),WIDE.x,WIDE.y)
	half = Vector2(length,width)*0.5/(1.0+EGG*0.5)
	egg = _rng.randf_range(-EGG,EGG)
	lobes = PackedVector3Array()
	for l: Array in LOBES: lobes.append(Vector3(float(l[0]),float(l[1])*_rng.randf_range(0.6,1.3),_rng.randf()*TAU))
	_warp = _noise(3,1.0/WARP_WAVE,2,FastNoiseLite.FRACTAL_FBM)
	_rag = _noise(7,1.0/RAGGED_WAVE,2,FastNoiseLite.FRACTAL_FBM)
	lake_side = 1.0 if _rng.randf() < 0.5 else -1.0
	proms = PackedVector3Array()
	for i in range(_rng.randi_range(PROMS.x,PROMS.y)):
		var a := (0.0 if _rng.randf() < 0.5 else PI)+_rng.randf_range(-PROM_ENDS,PROM_ENDS)
		proms.append(Vector3(a,_rng.randf_range(PROM_OUT.x,PROM_OUT.y),_rng.randf_range(PROM_WIDE.x,PROM_WIDE.y)))
	bays = PackedVector4Array()
	for i in range(_rng.randi_range(BAYS.x,BAYS.y)):
		var a := _rng.randf()*TAU
		var r := half.y*_rng.randf_range(BAY_SIZE.x,BAY_SIZE.y)
		var at := Vector2(cos(a)*half.x,sin(a)*half.y)*1.02
		bays.append(Vector4(at.x,at.y,r,0.0))
	neck = Vector3.ZERO
	# Between where the two lakes will lie (`_lakes`).
	if _rng.randf() < NECK_ODDS: neck = Vector3(-lake_side*half.x*_rng.randf_range(0.03,0.12),_rng.randf_range(NECK.x,NECK.y),half.x*NECK_LONG)
	ext = Vector2(half.x*(1.0+absf(egg))*(1.25+PROM_OUT.y)+WARP*1.5,half.y*1.45+WARP*1.5)
	ext = (ext/STEP).ceil()*STEP
	chunk = Vector4.ZERO
	if _rng.randf() < CHUNK_ODDS:
		var a := _rng.randf()*TAU
		var r := _rng.randf_range(CHUNK.x,CHUNK.y)
		var dir := Vector2.from_angle(a)
		var at := _main_rim(a)+dir*(_rng.randf_range(CHUNK_GAP.x,CHUNK_GAP.y)+r)
		if absf(at.x)+r < ext.x-STEP*2.0 and absf(at.y)+r < ext.y-STEP*2.0: chunk = Vector4(at.x,at.y,r,r*_rng.randf_range(CHUNK_DEPTH.x,CHUNK_DEPTH.y))
	nx = int(round(ext.x*2.0/STEP))+1
	nz = int(round(ext.y*2.0/STEP))+1
	depth = minf(width*_rng.randf_range(DEPTH.x,DEPTH.y),DEPTH_MOST)
	taper = _rng.randf_range(TAPER.x,TAPER.y)
	spurs = PackedVector4Array()
	for i in range(_rng.randi_range(SPURS.x,SPURS.y)):
		var at := Vector2(_rng.randf_range(-0.6,0.6)*half.x,_rng.randf_range(-0.4,0.4)*half.y)
		spurs.append(Vector4(at.x,at.y,half.y*_rng.randf_range(SPUR_SIZE.x,SPUR_SIZE.y)*1.6,depth*_rng.randf_range(SPUR_DEPTH.x,SPUR_DEPTH.y)))
	bed = _rng.randf_range(BED.x,BED.y)
	tilt = Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(BED_TILT.x,BED_TILT.y)

## How far out toward the rim a point is: 0 at the middle, 1 on it; on
## the broken-off chunk, how far out from its own middle.
func share(p: Vector2) -> float:
	var s := main_share(p)
	if chunk.z > 0.0: s = minf(s,chunk_share(p))
	return s

## The main body's share: the lobed egg, its promontories, the neck pinched
## in, the bays bitten out.
func main_share(p: Vector2) -> float:
	var w := p+Vector2(_warp.get_noise_2d(p.x,p.y),_warp.get_noise_2d(p.x+911.0,p.y-337.0))*WARP
	var ax := half.x*(1.0+egg*clampf(w.x/half.x*3.0,-1.0,1.0))
	var q := Vector2(w.x/ax,w.y/half.y)
	if neck.y > 0.0: q.y /= 1.0-neck.y*exp(-pow((w.x-neck.x)/neck.z,2.0))
	var t := q.angle()
	var out := 1.0
	for l in lobes: out += l.y*sin(l.x*t+l.z)
	for pr in proms: out += pr.y*exp(-pow(angle_difference(t,pr.x)/pr.z,2.0))
	var s := q.length()/out
	for b in bays:
		var d := w.distance_to(Vector2(b.x,b.y))/b.z
		if d < 1.0: s = maxf(s,1.0+0.8*(1.0-d))
	return s

## The chunk's share: 1 on its own rim.
func chunk_share(p: Vector2) -> float:
	var o := p-Vector2(chunk.x,chunk.y)
	var t := o.angle()
	return o.length()/(chunk.z*(1.0+0.12*sin(3.0*t+chunk.x)+0.08*sin(5.0*t+chunk.y)))

## True on the chunk rather than the main body.
func on_chunk(p: Vector2) -> bool:
	return chunk.z > 0.0 and chunk_share(p) < main_share(p)

## The main body's rim along the way from the middle at angle `a`.
func _main_rim(a: float) -> Vector2:
	var dir := Vector2.from_angle(a)
	var d := 0.0
	while d < ext.x*1.5 and main_share(dir*d) <= 1.0: d += 2.0
	return dir*d

func inside(p: Vector2) -> bool:
	return share(p) <= 1.0

## The main body's rim along the way from the middle at angle `a`: the
## first way out, stepped then halved.
func rim_point(a: float) -> Vector2:
	var dir := Vector2.from_angle(a)
	var lo := 0.0
	while lo < ext.x*1.5 and main_share(dir*(lo+2.0)) <= 1.0: lo += 2.0
	var hi := lo+2.0
	for k in range(12):
		var m := (lo+hi)*0.5
		if main_share(dir*m) <= 1.0: lo = m
		else: hi = m
	return dir*lo

func point(i: int, j: int) -> Vector2:
	return Vector2(-ext.x+i*STEP,-ext.y+j*STEP)

func _grid_shares() -> void:
	shares.resize(nx*nz)
	for j in range(nz):
		for i in range(nx): shares[j*nx+i] = share(point(i,j))

# --- The top ---------------------------------------------------------------------------

## The top before the erosion: the dome, the hills, rounding down to the rim.
func _base(p: Vector2, s: float) -> float:
	var hills: FastNoiseLite = _top_delta.hills
	var c := minf(s,1.0)
	var dome: float = _top_delta.dome*(0.35 if chunk.z > 0.0 and chunk_share(p) < main_share(p) else 1.0)
	return dome*(1.0-c*c)+float(_top_delta.hill)*hills.get_noise_2d(p.x,p.y)-ROUND*pow(smoothstep(0.8,1.0,c),2.0)

## The plate's erosion over the top, on a square grid over the whole isle.
func _erode_top() -> void:
	_top_delta = {"dome":_rng.randf_range(DOME.x,DOME.y),"hill":_rng.randf_range(HILLS.x,HILLS.y),
		"hills":_noise(5,1.0/HILL_WAVE,3,FastNoiseLite.FRACTAL_FBM)}
	var grid := _coarse(func(p: Vector2, s: float) -> float: return _base(p,s),ERODE_TOP,11)
	_top_delta.merge(grid)

## The top before its water: the base and the erosion's cut.
func rough(p: Vector2) -> float:
	return _base(p,share(p))+SkyPeak._sample(_top_delta.delta,int(_top_delta.n),_top_delta.corner,float(_top_delta.cell),p)

## A field `field(p, share)` laid on the erosion grid and weathered in plate
## units: returns {delta (m), n, corner, cell}.
func _coarse(field: Callable, settings: Dictionary, salt: int) -> Dictionary:
	var n := ERODE_N
	var span := maxf(ext.x,ext.y)*2.0
	var cell := span/float(n-1)
	var corner := -Vector2.ONE*span*0.5
	var scale := cell/PLATE_CELL
	var plate := PackedFloat64Array()
	var fixed := PackedByteArray()
	plate.resize(n*n)
	fixed.resize(n*n)
	for j in range(n):
		for i in range(n):
			var p := corner+Vector2(i,j)*cell
			var s := share(p)
			plate[j*n+i] = float(field.call(p,s))/scale
			fixed[j*n+i] = 1 if s > 1.02 else 0
	var all := settings.duplicate()
	all.merge({"size":n,"cell":PLATE_CELL,"origin":-float(n-1)*0.5*PLATE_CELL,"seed":(seed*7+salt) & 0x7fffffff,
		"edge_inner":1.0e5,"edge_outer":1.0e5+1.0})
	var cut := Erosion.erode(plate,fixed,all)
	var delta := PackedFloat64Array()
	delta.resize(n*n)
	for c in range(n*n): delta[c] = cut[c]*scale if cut.size() == n*n else 0.0
	return {"delta":delta,"n":n,"corner":corner,"cell":cell}

# --- The water ---------------------------------------------------------------------------

## One lake, or two: the first on one side of the middle, the second on the
## other, smaller. Each stands BANK under the lowest of its banks.
func _lakes() -> void:
	lakes.clear()
	var side := lake_side
	var count := 2 if _rng.randf() < LAKES_TWO else 1
	for k in range(count):
		var rx := length*_rng.randf_range(LAKE.x,LAKE.y)*(1.0 if k == 0 else 0.7)
		var rz := minf(rx*_rng.randf_range(LAKE_ROUND.x,LAKE_ROUND.y),half.y*0.42)
		var out := _rng.randf_range(0.28,0.45) if k == 0 else _rng.randf_range(0.42,0.62)
		var middle := Vector2(side*(1.0 if k == 0 else -1.0)*half.x*out,half.y*_rng.randf_range(-0.2,0.2))
		var lake := {"middle":middle,"radii":Vector2(rx,rz),"turn":_rng.randf_range(-0.35,0.35),
			"lobes":Vector4(_rng.randf_range(0.04,0.1),_rng.randf()*TAU,_rng.randf_range(0.03,0.07),_rng.randf()*TAU),
			"depth":_rng.randf_range(LAKE_DEPTH.x,LAKE_DEPTH.y),"level":0.0}
		# Shrunk until its outer bank lies well inside the rim.
		for tries in range(12):
			var fits := true
			for a in range(24):
				if share(_lake_point(lake,TAU*a/24.0,1.5)) > LAKE_IN: fits = false
			if fits: break
			lake.radii = (lake.radii as Vector2)*0.88
			lake.middle = (lake.middle as Vector2)*0.95
		# A second keeps its banks clear of the first's: shrunk until they
		# are apart, or there is no second.
		if k == 1:
			var apart := false
			for tries in range(8):
				apart = true
				for a in range(24):
					if lake_share(lakes[0],_lake_point(lake,TAU*a/24.0,1.6)) < 1.6: apart = false
				if apart: break
				lake.radii = (lake.radii as Vector2)*0.85
			if not apart: break
		var low := INF
		for a in range(48): low = minf(low,rough(_lake_point(lake,TAU*a/48.0,1.15)))
		lake.level = low-BANK
		lakes.append(lake)
	lower = 0
	if lakes.size() == 2:
		# The upper one stands at least STEP_UP over the lower; its banks
		# are raised to hold it.
		lower = 0 if float(lakes[0].level) <= float(lakes[1].level) else 1
		var up: Dictionary = lakes[1-lower]
		up.level = maxf(float(up.level),float(lakes[lower].level)+STEP_UP)

## How far out from a lake's middle a point is: 1 on its shore line.
func lake_share(lake: Dictionary, p: Vector2) -> float:
	var r: Vector2 = lake.radii
	var o := (p-(lake.middle as Vector2)).rotated(-float(lake.turn))
	var q := Vector2(o.x/r.x,o.y/r.y)
	var l: Vector4 = lake.lobes
	var t := q.angle()
	return q.length()/(1.0+l.x*sin(2.0*t+l.y)+l.z*sin(3.0*t+l.w))

func _lake_point(lake: Dictionary, a: float, s: float) -> Vector2:
	var r: Vector2 = lake.radii
	var l: Vector4 = lake.lobes
	var q := Vector2.from_angle(a)*s*(1.0+l.x*sin(2.0*a+l.y)+l.z*sin(3.0*a+l.w))
	return (lake.middle as Vector2)+Vector2(q.x*r.x,q.y*r.y).rotated(float(lake.turn))

## The stream from the upper lake to the lower, and the outflow from the
## lower to the nearest point of the rim, where it falls.
func _channels() -> void:
	channels.clear()
	var low: Dictionary = lakes[lower]
	if lakes.size() == 2:
		var up: Dictionary = lakes[1-lower]
		var a: Vector2 = up.middle
		var b: Vector2 = low.middle
		var points := _wander(a,b,_rng.randf_range(6.0,12.0),4.0)
		var levels := PackedFloat32Array()
		for k in range(points.size()):
			var t := float(k)/maxf(points.size()-1,1)
			levels.append(lerpf(float(up.level),float(low.level),smoothstep(0.2,0.8,t)))
		channels.append({"points":points,"levels":levels,"kind":"stream","bounds":_box(points)})
	# The outflow: the nearest way out to the rim from the lower lake.
	var middle: Vector2 = low.middle
	var best := INF
	var way := Vector2.UP
	for k in range(32):
		var a := TAU*k/32.0
		var dir := Vector2.from_angle(a)
		var d := 0.0
		while d < ext.x and share(middle+dir*d) <= 1.0: d += 2.0
		# Out into open air, not across a bay to land again.
		var open := true
		for step in range(2,16):
			if share(middle+dir*(d+step*2.0)) <= 1.0: open = false
		if not open: continue
		# Away from the other lake.
		if lakes.size() == 2 and dir.dot(((lakes[1-lower].middle as Vector2)-middle).normalized()) > 0.3: continue
		if d < best:
			best = d
			way = dir
	var lo := 0.0
	var hi := best
	for k in range(20):
		var m := (lo+hi)*0.5
		if share(middle+way*m) <= 1.0: lo = m
		else: hi = m
	lip = middle+way*lo
	lip_out = way
	lip_level = float(low.level)
	var out := _wander(middle,lip+way*1.0,_rng.randf_range(3.0,6.0),4.0)
	var flat := PackedFloat32Array()
	flat.resize(out.size())
	flat.fill(lip_level)
	channels.append({"points":out,"levels":flat,"kind":"outflow","bounds":_box(out)})

## A line's box, grown by as far as a channel's banks reach.
static func _box(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0],Vector2.ZERO)
	for p in points: box = box.expand(p)
	return box.grow(CHANNEL+12.0)

## A line from a to b in pieces about `piece` m long, wandering `sway` m
## to either side, its ends fixed.
func _wander(a: Vector2, b: Vector2, sway: float, piece: float) -> PackedVector2Array:
	var count := maxi(int(ceil(a.distance_to(b)/piece)),2)
	var side := (b-a).normalized().orthogonal()
	var phase := _rng.randf()*TAU
	var waves := _rng.randf_range(1.0,2.0)
	var out := PackedVector2Array()
	for k in range(count+1):
		var t := float(k)/count
		out.append(a.lerp(b,t)+side*sway*sin(t*PI)*sin(t*TAU*waves*0.5+phase))
	return out

## Distance (m) from a channel's line at a point and how far along (0 to 1),
## with the water's level there: Vector3(distance, along, level).
func along(channel: Dictionary, p: Vector2) -> Vector3:
	var points: PackedVector2Array = channel.points
	var levels: PackedFloat32Array = channel.levels
	var best := Vector3(INF,0.0,float(levels[0]))
	if not (channel.bounds as Rect2).has_point(p): return best
	for k in range(points.size()-1):
		var a := points[k]
		var ab := points[k+1]-a
		var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
		var d := p.distance_to(a+ab*t)
		if d < best.x: best = Vector3(d,(k+t)/(points.size()-1),lerpf(levels[k],levels[k+1],t))
	return best

## The top as carved: the rough ground, the lakes' basins and banks, the
## channels' beds and banks.
func carved(p: Vector2) -> float:
	var h := rough(p)
	for lake: Dictionary in lakes: h = _lake_ground(lake,p,h)
	var in_lake := false
	for lake: Dictionary in lakes:
		if lake_share(lake,p) < 1.05: in_lake = true
	if in_lake: return h
	for channel: Dictionary in channels:
		var a := along(channel,p)
		if a.x < CHANNEL:
			h = a.z-CHANNEL_DEPTH*(1.0-pow(a.x/CHANNEL,2.0))-0.15
		elif a.x < CHANNEL+8.0:
			var floor := a.z+0.35+(a.x-CHANNEL)*0.12
			h = lerpf(maxf(h,floor),h,smoothstep(CHANNEL+5.0,CHANNEL+8.0,a.x))
	return h

## A lake's bed inside its shore, and its bank rising round it, at least a
## little over the water, then easing back into the ground.
func _lake_ground(lake: Dictionary, p: Vector2, h: float) -> float:
	var ls := lake_share(lake,p)
	var level: float = lake.level
	if ls < 1.0: return minf(h,level-SHORE_DROP-float(lake.depth)*(1.0-ls*ls))
	if ls > 2.0: return h
	var reach: float = ((lake.radii as Vector2).x+(lake.radii as Vector2).y)*0.5
	var floor := level-SHORE_DROP+(SHORE_DROP+0.35)*smoothstep(1.0,1.15,ls)+maxf(ls-1.15,0.0)*reach*0.07
	return lerpf(floor,maxf(h,floor),smoothstep(1.1,1.4,ls))

func _carve() -> void:
	heights.resize(nx*nz)
	wet.resize(nx*nz)
	for j in range(nz):
		for i in range(nx):
			var p := point(i,j)
			heights[j*nx+i] = carved(p)
			var water := -INF
			for lake: Dictionary in lakes:
				if lake_share(lake,p) < 1.6: water = maxf(water,float(lake.level))
			for channel: Dictionary in channels:
				var a := along(channel,p)
				if a.x < CHANNEL+3.0: water = maxf(water,a.z)
			wet[j*nx+i] = water

## The water's level over a point, or -INF where there is none.
func water_at(p: Vector2) -> float:
	var g := ground_at(p)
	for lake: Dictionary in lakes:
		if lake_share(lake,p) < 1.3 and g < float(lake.level): return float(lake.level)
	for channel: Dictionary in channels:
		var a := along(channel,p)
		if a.x < CHANNEL and g < a.z: return a.z
	return -INF

# --- The rock underneath ----------------------------------------------------------------

## The rock's depth under the foot before the erosion: the upside-down
## mountain, the cliff band under the rim, the spurs, the crags.
func _depth(p: Vector2, s: float) -> float:
	if s >= 1.0: return 0.0
	# The keel's tip rounded off, not drawn to a point.
	var round_s := sqrt(s*s+KEEL_ROUND*KEEL_ROUND)-KEEL_ROUND
	if on_chunk(p): return chunk.w*pow(1.0-round_s,1.1)+WALL*0.5*smoothstep(1.0,0.9,s)
	var d := depth*pow(1.0-round_s,taper)
	var rim := 1.0-smoothstep(0.82,1.0,s)
	for sp in spurs:
		var k := 1.0-p.distance_to(Vector2(sp.x,sp.y))/sp.z
		if k > 0.0: d = maxf(d,sp.w*pow(k,1.3)*rim)
	d += WALL*smoothstep(1.0,0.93,s)
	var crags: FastNoiseLite = _top_delta.crags
	d += CRAG*rim*(crags.get_noise_2d(p.x,p.y)*0.5+0.5)
	return d

func _underside() -> void:
	_top_delta.crags = _noise(17,1.0/CRAG_WAVE,2,FastNoiseLite.FRACTAL_RIDGED)
	var grid := _coarse(func(p: Vector2, s: float) -> float: return _depth(p,s),ERODE_UNDER,29)
	var depths := PackedFloat32Array()
	depths.resize(nx*nz)
	for j in range(nz):
		for i in range(nx):
			var p := point(i,j)
			var s := shares[j*nx+i]
			var d := _depth(p,s)
			if s < 1.0: d = maxf(0.0,d+SkyPeak._sample(grid.delta,int(grid.n),grid.corner,float(grid.cell),p))
			depths[j*nx+i] = d
	# The beds: tilted, wobbling; stepped only on the steep faces, and not
	# everywhere.
	var mask := _noise(41,1.0/150.0,2,FastNoiseLite.FRACTAL_FBM)
	var wobble := _noise(53,1.0/120.0,2,FastNoiseLite.FRACTAL_FBM)
	under.resize(nx*nz)
	for j in range(nz):
		for i in range(nx):
			var c := j*nx+i
			var p := point(i,j)
			var d := depths[c]
			if d > 0.0:
				var l := depths[j*nx+maxi(i-1,0)]
				var r := depths[j*nx+mini(i+1,nx-1)]
				var u := depths[maxi(j-1,0)*nx+i]
				var w := depths[mini(j+1,nz-1)*nx+i]
				var slope := Vector2(r-l,w-u).length()/(2.0*STEP)
				var lift := tilt.dot(p)+wobble.get_noise_2d(p.x,p.y)*4.0
				var k := BED_SHARE*smoothstep(BED_STEEP.x,BED_STEEP.y,slope)*smoothstep(-0.45,0.1,mask.get_noise_2d(p.x,p.y))
				d = maxf(0.0,lerpf(d,_terrace((d+lift)/bed)*bed-lift,k))
			under[c] = minf(heights[c],0.0)-foot(p)-d

## How far down the earth band reaches under the top's plane at a point
## along the rim (m): ragged, never even.
func foot(p: Vector2) -> float:
	return FOOT*lerpf(FOOT_RANGE.x,FOOT_RANGE.y,_rag.get_noise_2d(p.x,p.y)*0.5+0.5)

## The rim's outward way at a point: down the share field's slope.
func outward(p: Vector2) -> Vector2:
	var e := 0.5
	var g := Vector2(share(p+Vector2(e,0.0))-share(p-Vector2(e,0.0)),share(p+Vector2(0.0,e))-share(p-Vector2(0.0,e)))
	return g.normalized() if g.length() > 1e-6 else p.normalized()

static func _terrace(x: float) -> float:
	var f := x-floorf(x)
	return floorf(x)+pow(f,BED_SHARP)

# --- The forest ------------------------------------------------------------------------

## The lanes: from the rim at an end to the first lake, from it out to the
## rim at a side, and on a long isle from the far end to the other lake (or
## the middle).
func _aisles() -> void:
	aisles.clear()
	var first: Vector2 = lakes[0].middle
	var end_a := rim_point(0.0 if first.x < 0.0 else PI)
	aisles.append(_wander(end_a*1.05,first,_rng.randf_range(6.0,12.0),6.0))
	var side := rim_point(PI*0.5 if _rng.randf() < 0.5 else -PI*0.5)
	aisles.append(_wander(first,side*1.05,_rng.randf_range(5.0,10.0),6.0))
	var other: Vector2 = lakes[1].middle if lakes.size() > 1 else Vector2(-first.x*0.6,-first.y)
	var end_b := rim_point(PI if first.x < 0.0 else 0.0)
	if length > 340.0 and end_b.distance_to(other) > 30.0: aisles.append(_wander(end_b*1.05,other,_rng.randf_range(6.0,12.0),6.0))

## Distance (m) from the nearest aisle's line.
func aisle_distance(p: Vector2) -> float:
	var best := INF
	for line in aisles:
		for k in range(line.size()-1):
			var a := line[k]
			var ab := line[k+1]-a
			var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
			best = minf(best,p.distance_to(a+ab*t))
	return best

## The giants: first lining the aisles, then darted in at random, APART
## from each other, off the water, the channels and the aisles, in from the
## rim, out of the clearings (`_giant`); then
## spruces under and between them in patches, and taller ones at the edges;
## then ferns in the giants' shade.
func _plant() -> void:
	trees = PackedVector4Array()
	crowns = PackedVector4Array()
	kinds = PackedInt32Array()
	leans = PackedVector2Array()
	_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*17+5
	var forest := _noise(83,1.0/90.0,2,FastNoiseLite.FRACTAL_FBM)
	_top_delta.stands = _noise(97,1.0/STAND_WAVE,2,FastNoiseLite.FRACTAL_FBM)
	var patches := _noise(89,1.0/45.0,2,FastNoiseLite.FRACTAL_FBM)
	var spots := []
	var z := -ext.y
	while z < ext.y:
		var x := -ext.x
		while x < ext.x:
			spots.append(Vector2(x,z)+Vector2(rng.randf(),rng.randf())*5.0)
			x += 5.0
		z += 5.0
	_shuffle(spots,rng)
	# First the aisles' colonnades: giants lining both sides, their crowns
	# leaning in over the lane so it runs under a vault of green.
	for line in aisles:
		for side: float in [1.0,-1.0]:
			var along := rng.randf_range(0.0,APART)
			var walked := 0.0
			for k in range(line.size()-1):
				var a := line[k]
				var b := line[k+1]
				var piece := a.distance_to(b)
				while along < walked+piece:
					var t := (along-walked)/piece
					var trunk := rng.randf_range(TRUNK.x,TRUNK.y)
					var normal := (b-a).normalized().orthogonal()*side
					var p := a.lerp(b,t)+normal*(AISLE_HALF+trunk+rng.randf_range(0.4,2.5))
					_giant(p,trunk,-normal,rng,forest)
					along += APART*rng.randf_range(1.02,1.2)
				walked += piece
	for p: Vector2 in spots: _giant(p,rng.randf_range(TRUNK.x,TRUNK.y),Vector2.ZERO,rng,forest)
	_emerge(rng)
	var spruces := 0
	for p: Vector2 in spots:
		if spruces >= SPRUCE_CAP: break
		var s := share(p)
		if s > 0.94: continue
		var edge := s > 0.8 or _near_lake(p,1.7)
		if patches.get_noise_2d(p.x,p.y) < (SPRUCE_PATCH-0.25 if edge else SPRUCE_PATCH): continue
		if not _dry(p,1.18,CHANNEL+2.0) or aisle_distance(p) < AISLE_HALF+2.0: continue
		if _crowded(p,SPRUCE_APART,false): continue
		var size := EDGE_SPRUCE if edge else SPRUCE
		var tall := rng.randf_range(size.x,size.y)
		var ground := ground_at(p)
		_add(p,ground,tall,Vector4(ground+0.3,ground+tall,tall*SPRUCE_CROWN,maxf(0.25,tall*0.035)),SPRUCE_VARIANTS[rng.randi() % SPRUCE_VARIANTS.size()])
		spruces += 1
	ferns = PackedVector4Array()
	for p: Vector2 in spots:
		if ferns.size() >= FERNS: break
		if rng.randf() > FERN_ODDS or share(p) > 0.95 or not _dry(p,1.12,CHANNEL+1.0): continue
		var shaded := false
		var clear := true
		for index in near(p):
			var t := trees[index]
			var d := p.distance_to(Vector2(t.x,t.y))
			if kinds[index] == -1 and d < crowns[index].z*1.1: shaded = true
			if d < crowns[index].w+1.5 or (kinds[index] != -1 and d < 1.5): clear = false
		if shaded and clear: ferns.append(Vector4(p.x,p.y,ground_at(p),rng.randf_range(FERN_SIZE.x,FERN_SIZE.y)))

## A giant at p, if there is room: in from the rim, out of the clearings,
## off the water, the channels and the aisles, APART from the others. One
## lining an aisle (`lean`, the way to it) leans its crown out over it. Its
## crown is always high enough over every bit of ground under it that the
## glide's lane band stays open under it.
func _giant(p: Vector2, trunk: float, lean: Vector2, rng: RandomNumberGenerator, forest: FastNoiseLite) -> void:
	var s := share(p)
	if s > 1.0-RIM_IN/half.y: return
	if forest.get_noise_2d(p.x,p.y) < CLEARING and lean == Vector2.ZERO: return
	if not _dry(p,1.25,CHANNEL+5.0) or aisle_distance(p) < AISLE_HALF+trunk: return
	if _crowded(p,APART*(1.0+rng.randf_range(0.0,APART_JITTER)),true): return
	# Heights in stands: a slow noise sets each stand's, a few emergents
	# tower over them, and toward the rim and the shores they come down.
	var stand := float(_top_delta.stands.get_noise_2d(p.x,p.y))*0.5+0.5
	var tall := lerpf(GIANT.x,GIANT.y,smoothstep(0.3,0.7,stand))*rng.randf_range(0.9,1.1)
	if lean == Vector2.ZERO:
		tall *= 1.0-RIM_LOW*smoothstep(1.0-(RIM_IN+45.0)/half.y,1.0-RIM_IN/half.y,s)
		var shore := INF
		for l: Dictionary in lakes: shore = minf(shore,lake_share(l,p))
		tall *= 1.0-SHORE_LOW*(1.0-smoothstep(1.25,2.3,shore))
	else:
		# The colonnade stands tall, to vault the aisle.
		tall = maxf(tall,GIANT.x+8.0)
	var ground := ground_at(p)
	# At the forest's edges (the rim, the shores) the crowns reach lower,
	# as they do where light comes in from the side; never by an aisle.
	var young := lean == Vector2.ZERO and rng.randf() < YOUNG
	if young: tall = rng.randf_range(YOUNG_TALL.x,YOUNG_TALL.y)
	var edge := lean == Vector2.ZERO and (young or s > 1.0-(RIM_IN+16.0)/half.y or _near_lake(p,1.6))
	var from := ground+tall*(rng.randf_range(EDGE_FROM.x,EDGE_FROM.y) if edge else rng.randf_range(CROWN_FROM.x,CROWN_FROM.y))
	var radius := (ground+tall-from)*(CROWN_WIDE.y if lean != Vector2.ZERO else rng.randf_range(CROWN_WIDE.x,CROWN_WIDE.y))
	if edge and aisle_distance(p) < AISLE_HALF+radius+2.0:
		edge = false
		from = ground+tall*rng.randf_range(CROWN_FROM.x,CROWN_FROM.y)
		radius = (ground+tall-from)*rng.randf_range(CROWN_WIDE.x,CROWN_WIDE.y)
	var shift := lean*minf(LEAN,radius-trunk-1.0)
	if not edge:
		var middle := p+shift
		for o: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			from = maxf(from,ground_at(middle+o*radius)+GLIDE_LANE.y+SkyGlide.CLEAR+2.0)
		# Never a crown squeezed to nothing over the lane.
		if ground+tall < from+tall*0.5:
			tall = (from-ground)/0.5
			radius = tall*0.5*(CROWN_WIDE.y if lean != Vector2.ZERO else CROWN_WIDE.x)
	_add(p,ground,tall,Vector4(from,ground+tall,radius,trunk),-1,shift)

## A few emergents: giants well in from the rim, off the aisles, drawn up
## far over the tallest stand, their crowns growing with them.
func _emerge(rng: RandomNumberGenerator) -> void:
	var tallest := 0.0
	var picks := []
	for i in range(trees.size()):
		if kinds[i] != -1: continue
		tallest = maxf(tallest,trees[i].w)
		var at := Vector2(trees[i].x,trees[i].y)
		if share(at) < 0.7 and leans[i] == Vector2.ZERO and crowns[i].x-trees[i].z > trees[i].w*0.3 \
			and aisle_distance(at) > AISLE_HALF+crowns[i].z*EMERGE_WIDE+2.0: picks.append(i)
	_shuffle(picks,rng)
	for i: int in picks.slice(0,rng.randi_range(EMERGENT.x,EMERGENT.y)):
		var t := trees[i]
		var c := crowns[i]
		var tall := minf(tallest*rng.randf_range(EMERGE.x,EMERGE.y),EMERGE_MOST)
		trees[i] = Vector4(t.x,t.y,t.z,tall)
		crowns[i] = Vector4(c.x,t.z+tall,minf((t.z+tall-c.x)*CROWN_WIDE.x,c.z*EMERGE_WIDE),c.w)

func _add(p: Vector2, ground: float, tall: float, crown: Vector4, kind: int, shift := Vector2.ZERO) -> void:
	var index := trees.size()
	trees.append(Vector4(p.x,p.y,ground,tall))
	crowns.append(crown)
	kinds.append(kind)
	leans.append(shift)
	var cell := Vector2i(floori(p.x/TREE_CELL),floori(p.y/TREE_CELL))
	var list: PackedInt32Array = _cells.get(cell,PackedInt32Array())
	list.append(index)
	_cells[cell] = list

## True if a tree stands within `apart` of p: giants keep apart from giants
## and every spruce; spruces from everything, and clear of a giant's trunk.
func _crowded(p: Vector2, apart: float, giant: bool) -> bool:
	for index in near(p):
		var t := trees[index]
		var d := p.distance_to(Vector2(t.x,t.y))
		if giant and kinds[index] == -1 and d < apart: return true
		if giant and kinds[index] != -1 and d < 6.0: return true
		if not giant and d < (crowns[index].w+4.0 if kinds[index] == -1 else apart): return true
	return false

## True if p is clear of every lake by `lake` of its shore share and of
## every channel by `channel` m.
func _dry(p: Vector2, lake: float, channel: float) -> bool:
	for l: Dictionary in lakes:
		if lake_share(l,p) < lake: return false
	for c: Dictionary in channels:
		if along(c,p).x < channel: return false
	return true

func _near_lake(p: Vector2, reach: float) -> bool:
	for l: Dictionary in lakes:
		if lake_share(l,p) < reach: return true
	return false

## The trees whose cell or a neighbour's holds p (crowns reach no further).
func near(p: Vector2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c := Vector2i(floori(p.x/TREE_CELL),floori(p.y/TREE_CELL))
	for dx in range(-1,2):
		for dz in range(-1,2):
			var key := c+Vector2i(dx,dz)
			if _cells.has(key): out.append_array(_cells[key])
	return out

static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for k in range(list.size()-1,0,-1):
		var m := rng.randi_range(0,k)
		var t: Variant = list[k]
		list[k] = list[m]
		list[m] = t

## Roots hanging from the earth band all round the rim, and from the rock
## under it, longest where the forest stands over them.
func _roots() -> void:
	roots = PackedVector4Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*23+9
	var perimeter := 0.0
	var last := rim_point(0.0)
	var steps := 360
	for k in range(1,steps+1):
		var p := rim_point(TAU*k/steps)
		perimeter += p.distance_to(last)
		last = p
	var count := int(perimeter/ROOT_APART)
	for k in range(count):
		var a := TAU*(k+rng.randf()*0.8)/count
		var p := rim_point(a)
		if p.distance_to(lip) < CHANNEL*2.0: continue
		p -= p.normalized()*rng.randf_range(0.2,0.6)
		var y := minf(ground_at(p),0.0)-LIP.x-rng.randf_range(0.3,FOOT-1.0)
		roots.append(Vector4(p.x,y,p.y,rng.randf_range(ROOT_LONG.x,ROOT_LONG.y)*rng.randf_range(0.4,1.0)))
	var tries := 0
	var under_count := 0
	while under_count < UNDER_ROOTS and tries < UNDER_ROOTS*20:
		tries += 1
		var p := Vector2(rng.randf_range(-ext.x,ext.x),rng.randf_range(-ext.y,ext.y))
		var s := share(p)
		if s < 0.78 or s > 0.97: continue
		roots.append(Vector4(p.x,underside_at(p)+0.4,p.y,rng.randf_range(ROOT_LONG.x,ROOT_LONG.y*1.4)))
		under_count += 1

func _measure() -> void:
	top = -INF
	bottom = INF
	canopy = -INF
	for c in range(nx*nz):
		if shares[c] > 1.0: continue
		top = maxf(top,heights[c])
		bottom = minf(bottom,under[c])
	for crown in crowns: canopy = maxf(canopy,crown.y)

# --- Reading it ----------------------------------------------------------------------------

## The ground's height at a point (the faces as built), the grid's edge
## height off it.
func ground_at(p: Vector2) -> float:
	return _read(heights,p)

func underside_at(p: Vector2) -> float:
	return _read(under,p)

func _read(field: PackedFloat32Array, p: Vector2) -> float:
	var fx := clampf((p.x+ext.x)/STEP,0.0,nx-1.001)
	var fz := clampf((p.y+ext.y)/STEP,0.0,nz-1.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx-i
	var v := fz-j
	var h00 := field[j*nx+i]
	var h10 := field[j*nx+i+1]
	var h01 := field[(j+1)*nx+i]
	var h11 := field[(j+1)*nx+i+1]
	if SkyPeak._split(heights[j*nx+i],heights[j*nx+i+1],heights[(j+1)*nx+i],heights[(j+1)*nx+i+1]):
		if u >= v: return h00+(h10-h00)*u+(h11-h10)*v
		return h00+(h11-h01)*u+(h01-h00)*v
	if u+v <= 1.0: return h00+(h10-h00)*u+(h01-h00)*v
	return h11+(h01-h11)*(1.0-u)+(h10-h11)*(1.0-v)

## The isle as a solid at a point in its frame, as the glide reads it:
## Vector3(top, underside, 1 if it is wood the glide is turned aside by),
## or null off the rim. Over open ground the top is the ground or the water
## over it and the underside the rock's. A trunk is a column from the rock
## to the tree's top; a crown, a solid from its flat underside to its crest,
## sloping from the top down to its rim. Of those the point is no further
## than CATCH under, the one standing highest is the solid there: under the
## canopy that is the ground (or a trunk), just under a crown or in it, the
## crown.
func solid(p: Vector3) -> Variant:
	var at := Vector2(p.x,p.z)
	if share(at) > 1.0: return null
	var u := underside_at(at)
	var best := Vector3(maxf(ground_at(at),water_at(at)),u,0.0)
	for index in near(at):
		var t := trees[index]
		var c := crowns[index]
		var d := at.distance_to(Vector2(t.x,t.y))
		var dc := at.distance_to(Vector2(t.x,t.y)+leans[index])
		var here: Vector3
		if d < c.w: here = Vector3(c.y,u,1.0)
		elif dc < c.z: here = Vector3(c.y-(c.y-c.x)*0.85*dc/c.z,c.x,1.0)
		else: continue
		if p.y < here.y-CATCH and here.y > u: continue
		if here.x > best.x: best = here
	return best

## The way through an aisle at the glide's lane height: points (x, y, z)
## along it, `over` m over the ground.
func lane(index: int, over: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var line: PackedVector2Array = aisles[index]
	for k in range(line.size()-1):
		for f in range(4):
			var p := line[k].lerp(line[k+1],f/4.0)
			if share(p) <= 0.97: out.append(Vector3(p.x,ground_at(p)+over,p.y))
	return out

## The isle's reach from its middle (m): the furthest point of the rim.
func reach() -> float:
	var r := 0.0
	for k in range(72): r = maxf(r,rim_point(TAU*k/72.0).length())
	return r

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

# --- The meshes ------------------------------------------------------------------------------

## The isle's body as surface arrays: {top, rock}. The top for the plate's
## own ground material, coloured per face from the world's `grass`, its
## `gravel` and the lakes' `bank`, with the ground's smoothed normals and the
## rim's grass lip, every vertex laid `shift` off (SkyIslets OFF_MAP). The
## rock (the earth band under the lip and everything under it, faceted) for
## the plate's earth-sides material, built ROCK_SCALE times small. Safe on
## a worker.
func body_arrays(grass: Array, gravel: Color, bank: Color, shift := Vector3.ZERO) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed*31+7
	var fields := [_noise(67,1.0/60.0,3,FastNoiseLite.FRACTAL_FBM),_noise(73,1.0/110.0,2,FastNoiseLite.FRACTAL_FBM)]
	var strata := {"topsoil":Color(Strata.COLORS.topsoil).srgb_to_linear(),"clay":Color(Strata.COLORS.clay).srgb_to_linear()}
	var normals := PackedVector3Array()
	normals.resize(nx*nz)
	for j in range(nz):
		for i in range(nx):
			var l := heights[j*nx+maxi(i-1,0)]
			var r := heights[j*nx+mini(i+1,nx-1)]
			var d := heights[maxi(j-1,0)*nx+i]
			var w := heights[mini(j+1,nz-1)*nx+i]
			normals[j*nx+i] = Vector3(-(r-l)/(2.0*STEP),1.0,-(w-d)/(2.0*STEP)).normalized()
	_bv = PackedVector3Array()
	_bn = PackedVector3Array()
	_bc = PackedColorArray()
	_rv = PackedVector3Array()
	_rn = PackedVector3Array()
	_shift = shift
	var shade := _floor_shade()
	for j in range(nz-1):
		for i in range(nx-1):
			var ids := [j*nx+i,j*nx+i+1,(j+1)*nx+i+1,(j+1)*nx+i]
			var outside := 0
			for c: int in ids:
				if shares[c] > 1.0: outside += 1
			if outside == 4: continue
			# The cell clipped to the inside: corners and crossings, round.
			var poly := []
			for k in range(4):
				var a: int = ids[k]
				var b: int = ids[(k+1)%4]
				var fa := 1.0-shares[a]
				var fb := 1.0-shares[b]
				if fa >= 0.0: poly.append(_corner(a,b,0.0,0,normals))
				if (fa >= 0.0) != (fb >= 0.0): poly.append(_corner(a,b,fa/(fa-fb),1 if fa >= 0.0 else 2,normals))
			if poly.size() < 3: continue
			var tris := []
			if outside == 0:
				tris = [[0,2,1],[0,3,2]] if SkyPeak._split(heights[ids[0]],heights[ids[1]],heights[ids[3]],heights[ids[2]]) else [[0,3,1],[1,3,2]]
			else:
				for k in range(1,poly.size()-1): tris.append([0,k,k+1])
			for t: Array in tris:
				var a: Dictionary = poly[t[0]]
				var b: Dictionary = poly[t[1]]
				var c: Dictionary = poly[t[2]]
				var mid := ((a.p as Vector2)+(b.p as Vector2)+(c.p as Vector2))/3.0
				var lie := ((a.n as Vector3)+(b.n as Vector3)+(c.n as Vector3)).normalized()
				var low := minf(float(a.h),minf(float(b.h),float(c.h)))
				var tone := _top_tone(mid,low,lie,grass,gravel,bank,strata,fields,shade,rng)
				_tri(_up(a),_up(b),_up(c),[a.n,b.n,c.n],tone,Vector3.UP)
				var ua := _down(a)
				var ub := _down(b)
				var uc := _down(c)
				_rock_tri(ua,ub,uc,Vector3.DOWN)
			# The rim through this cell: the grass lip and the earth band.
			for k in range(poly.size()):
				var e: Dictionary = poly[k]
				var f: Dictionary = poly[(k+1)%poly.size()]
				if int(e.kind) != 1 or int(f.kind) != 2: continue
				var pe: Vector2 = e.p
				var pf: Vector2 = f.p
				var out_e := outward(pe)
				var out_f := outward(pf)
				var o3 := Vector3(out_e.x+out_f.x,0.0,out_e.y+out_f.y).normalized()
				var te := _up(e)
				var tf := _up(f)
				var we := _wall(pe,out_e,te,_down(e))
				var wf := _wall(pf,out_f,tf,_down(f))
				var green: Color = grass[rng.randi() % grass.size()]
				_quad(te,we[0],wf[0],tf,green*0.8,o3)
				# The earth: turf's underside, then the slump, then down to the
				# rock, darker where it hangs in shadow.
				for band in range(2):
					var tone: Color = (strata.topsoil as Color)*rng.randf_range(0.78,1.05)*(0.85 if band == 1 else 1.0)
					if rng.randf() < 0.25: tone = tone.lerp(strata.clay,0.4)
					_quad(we[band],we[band+1],wf[band+1],wf[band],tone,o3)
	var top_arrays := _surface(_bv,_bn,_bc,true)
	var rock_arrays := _surface(_rv,_rn,PackedColorArray(),false)
	_bv = PackedVector3Array()
	_bn = PackedVector3Array()
	_bc = PackedColorArray()
	_rv = PackedVector3Array()
	_rn = PackedVector3Array()
	return {"top":top_arrays,"rock":rock_arrays}

## Surface arrays from built vertices, every vertex fully grown (UV.y 1)
## and, if `grown`, its height in UV2.y (reference_surface `terrain_
## growth`: where the grown ground stands); with no colours, white.
static func _surface(vertices: PackedVector3Array, normals: PackedVector3Array, colours: PackedColorArray, grown: bool) -> Array:
	var count := vertices.size()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	uv.resize(count)
	uv2.resize(count)
	uv.fill(Vector2(0.0,1.0))
	for k in range(count): uv2[k] = Vector2(0.5,vertices[k].y if grown else 0.0)
	if colours.is_empty():
		colours.resize(count)
		colours.fill(Color.WHITE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	return arrays

## The rim's ragged wall at a rim point p (outward way `out`) from the top
## `t` down to the rock's edge `d`: [the turf's lip, hanging over and down,
## the earth's slump at mid height, the foot on the rock].
func _wall(p: Vector2, out: Vector2, t: Vector3, d: Vector3) -> Array:
	var o := Vector3(out.x,0.0,out.y)
	var n := _rag.get_noise_2d(p.x*1.7+300.0,p.y*1.7)*0.5+0.5
	var m := _rag.get_noise_2d(p.x+700.0,p.y-200.0)*0.5+0.5
	var lip := t+o*LIP.y*lerpf(LIP_RANGE.x,LIP_RANGE.y,n)+Vector3.DOWN*LIP.x*lerpf(0.6,1.8,m)
	d.y = minf(d.y,lip.y-0.5)
	var slump := maxf(0.0,_rag.get_noise_2d(p.x-500.0,p.y+90.0)*1.6-0.1)*SLUMP
	var mid := Vector3(p.x,lerpf(lip.y,d.y,0.5),p.y)+o*slump
	return [lip,mid,d]

## A clipped cell's point: along the edge a to b by t, with the top, the
## underside and the top's normal there; kind 0 a corner, 1 leaving the
## inside, 2 coming back in.
func _corner(a: int, b: int, t: float, kind: int, normals: PackedVector3Array) -> Dictionary:
	var pa := point(a % nx,a/nx)
	var pb := point(b % nx,b/nx)
	return {"p":pa.lerp(pb,t),"h":lerpf(heights[a],heights[b],t),"u":lerpf(under[a],under[b],t),
		"n":normals[a].lerp(normals[b],t).normalized(),"kind":kind}

static func _up(c: Dictionary) -> Vector3:
	return Vector3((c.p as Vector2).x,float(c.h),(c.p as Vector2).y)

static func _down(c: Dictionary) -> Vector3:
	return Vector3((c.p as Vector2).x,float(c.u),(c.p as Vector2).y)

## How shaded the forest floor is at a point: 1 under a giant's crown, 0 in
## the open, on a grid the same as the mesh's.
func _floor_shade() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(nx*nz)
	for index in range(trees.size()):
		var t := trees[index]
		var reach: float = crowns[index].z*(1.6 if kinds[index] == -1 else 0.9)
		var lo := Vector2i(maxi(0,int((t.x-reach+ext.x)/STEP)),maxi(0,int((t.y-reach+ext.y)/STEP)))
		var hi := Vector2i(mini(nx-1,int((t.x+reach+ext.x)/STEP)+1),mini(nz-1,int((t.y+reach+ext.y)/STEP)+1))
		for j in range(lo.y,hi.y+1):
			for i in range(lo.x,hi.x+1):
				var d := point(i,j).distance_to(Vector2(t.x,t.y))/reach
				if d < 1.0: out[j*nx+i] = maxf(out[j*nx+i],(1.0-d*d)*(1.0 if kinds[index] == -1 else 0.6))
	return out

## A top face's colour: the lakes' beds and shores, the forest floor's
## litter under the crowns, earth on the steep, meadow greens in patches.
func _top_tone(p: Vector2, low: float, n: Vector3, grass: Array, gravel: Color, bank: Color, strata: Dictionary, fields: Array, shade: PackedFloat32Array, rng: RandomNumberGenerator) -> Color:
	var jitter := 1.0+rng.randf_range(-0.045,0.045)
	var i := clampi(int(round((p.x+ext.x)/STEP)),0,nx-1)
	var j := clampi(int(round((p.y+ext.y)/STEP)),0,nz-1)
	var water := wet[j*nx+i]
	# Under the water, a dark bed going darker with depth, even, so the
	# glassy water over it is not seen as a patchwork of facets.
	if water > -INF and low < water-0.05: return bank.lerp(LAKE_BED.srgb_to_linear(),smoothstep(0.0,1.2,water-low))
	if water > -INF and low < water+0.7: return bank.lerp(gravel,0.4)*jitter
	var patch: float = (fields[0] as FastNoiseLite).get_noise_2d(p.x,p.y)*0.5+0.5
	var mix_green: float = (fields[1] as FastNoiseLite).get_noise_2d(p.x,p.y)*0.5+0.5
	var green := (grass[0] as Color).lerp(grass[2 if grass.size() > 2 else 0],smoothstep(0.25,0.75,mix_green))
	var slope := sqrt(maxf(0.0,1.0-n.y*n.y))/maxf(n.y,0.001)
	if slope > 0.9: return (strata.topsoil as Color).lerp(green,0.3)*jitter
	var under_trees := shade[j*nx+i]
	var moss: Color = grass[grass.size()-1]
	var floor := moss.lerp(LITTER.srgb_to_linear(),0.35+0.35*patch)*0.62
	return green.lerp(floor,smoothstep(0.05,0.55,under_trees))*jitter

## Adds a rock triangle facing `outward`, ROCK_SCALE times small, with the
## face's own normal; its strata come from the material.
func _rock_tri(a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var n := (b-a).cross(c-a)
	if n.length_squared() < 1e-8: return
	if n.dot(outward) < 0.0:
		var swap := b
		b = c
		c = swap
		n = -n
	var k := 1.0/ROCK_SCALE
	_rv.append(a*k)
	_rv.append(c*k)
	_rv.append(b*k)
	var face := n.normalized()
	for i in range(3): _rn.append(face)

## Adds a triangle to the body being built, facing the side `outward`
## points to (Godot's front faces wind clockwise seen from outside), with its
## corners' `normals` (a, b, c order) or, if none, the face's own.
func _tri(a: Vector3, b: Vector3, c: Vector3, normals: Array, tone: Color, outward: Vector3) -> void:
	var n := (b-a).cross(c-a)
	if n.length_squared() < 1e-8: return
	var na: Vector3 = normals[0] if not normals.is_empty() else Vector3.ZERO
	var nb: Vector3 = normals[1] if not normals.is_empty() else Vector3.ZERO
	var nc: Vector3 = normals[2] if not normals.is_empty() else Vector3.ZERO
	if n.dot(outward) < 0.0:
		var swap := b
		b = c
		c = swap
		var turn_n := nb
		nb = nc
		nc = turn_n
		n = -n
	if normals.is_empty():
		na = n.normalized()
		nb = na
		nc = na
	tone.a = 1.0
	_bv.append(a+_shift)
	_bv.append(c+_shift)
	_bv.append(b+_shift)
	_bn.append(na)
	_bn.append(nc)
	_bn.append(nb)
	_bc.append(tone)
	_bc.append(tone)
	_bc.append(tone)

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, tone: Color, outward: Vector3) -> void:
	_tri(a,b,c,[],tone,outward)
	_tri(a,c,d,[],tone,outward)

## The lakes' and channels' water for the plate's own still-water material
## (reference_water_body), as SkyIslet `water_arrays`: a sheet WATER_STEP
## apart over each lake where the bed is under its level, and a strip down
## each channel, each vertex carrying its depth over the bed (UV2.x), the
## run to the bank (UV.x) and the fetch in eight directions (CUSTOM0,
## CUSTOM1). Laid `shift` off. Safe on a worker.
func water_arrays(color: Color, shift := Vector3.ZERO) -> Array:
	var faces := []
	for lake: Dictionary in lakes:
		var level: float = lake.level
		var r: Vector2 = lake.radii
		var reach := maxf(r.x,r.y)*1.45
		var middle: Vector2 = lake.middle
		var steps := int(ceil(reach*2.0/WATER_STEP))
		var corner := middle-Vector2.ONE*reach
		for j in range(steps):
			for i in range(steps):
				var q := [corner+Vector2(i,j)*WATER_STEP,corner+Vector2(i+1,j)*WATER_STEP,corner+Vector2(i+1,j+1)*WATER_STEP,corner+Vector2(i,j+1)*WATER_STEP]
				var wet := false
				for p: Vector2 in q:
					if lake_share(lake,p) < 1.3 and ground_at(p) < level+0.05: wet = true
				if not wet: continue
				faces.append([Vector3(q[0].x,level,q[0].y),Vector3(q[1].x,level,q[1].y),Vector3(q[2].x,level,q[2].y)])
				faces.append([Vector3(q[0].x,level,q[0].y),Vector3(q[2].x,level,q[2].y),Vector3(q[3].x,level,q[3].y)])
	for channel: Dictionary in channels:
		var points: PackedVector2Array = channel.points
		var levels: PackedFloat32Array = channel.levels
		for k in range(points.size()-1):
			var a := points[k]
			var b := points[k+1]
			var side_a := (points[mini(k+1,points.size()-1)]-points[maxi(k-1,0)]).normalized().orthogonal()*CHANNEL*0.9
			var side_b := (points[mini(k+2,points.size()-1)]-points[k]).normalized().orthogonal()*CHANNEL*0.9
			var dry := true
			for lake: Dictionary in lakes:
				if lake_share(lake,a) < 0.95 and lake_share(lake,b) < 0.95: dry = false
			if not dry: continue
			var pa := [a-side_a,a+side_a]
			var pb := [b-side_b,b+side_b]
			var la := levels[k]
			var lb := levels[k+1]
			faces.append([Vector3(pa[0].x,la,pa[0].y),Vector3(pa[1].x,la,pa[1].y),Vector3(pb[1].x,lb,pb[1].y)])
			faces.append([Vector3(pa[0].x,la,pa[0].y),Vector3(pb[1].x,lb,pb[1].y),Vector3(pb[0].x,lb,pb[0].y)])
	if faces.is_empty(): return []
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var fetch_a := PackedFloat32Array()
	var fetch_b := PackedFloat32Array()
	var dirs := []
	for i in range(8): dirs.append(Vector2.from_angle(TAU*i/8.0))
	var order := [dirs[0],dirs[1],dirs[2],dirs[3],-dirs[0],-dirs[1],-dirs[2],-dirs[3]]
	var runs_at := {}
	for f: Array in faces:
		# Wound clockwise seen from above.
		for v: Vector3 in [f[0],f[2],f[1]]:
			var p := Vector2(v.x,v.z)
			var bed_depth := maxf(v.y-ground_at(p),0.0)
			vertices.append(v+shift)
			normals.append(Vector3.UP)
			colors.append(color)
			uv.append(Vector2(bed_depth*2.5,0.0))
			uv2.append(Vector2(bed_depth,0.0))
			var key := Vector2i(roundi(p.x*4.0),roundi(p.y*4.0))
			if not runs_at.has(key):
				var runs := []
				for d: Vector2 in order:
					var run := 0.0
					while run < FETCH and ground_at(p+d*(run+1.0)) < v.y: run += 1.0
					runs.append(run)
				runs_at[key] = runs
			var r: Array = runs_at[key]
			fetch_a.append_array([r[0],r[1],r[2],r[3]])
			fetch_b.append_array([r[4],r[5],r[6],r[7]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = fetch_a
	arrays[Mesh.ARRAY_CUSTOM1] = fetch_b
	return arrays

## A one-surface mesh from surface arrays, with its material.
static func mesh_from(arrays: Array, material: Material, format := 0) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},format)
	if material != null: mesh.surface_set_material(0,material)
	return mesh
