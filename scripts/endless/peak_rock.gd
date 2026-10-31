extends RefCounted
## The Peak's rock: ridged, eroded relief on its walls, at the sizes the plane
## flies past (spec-crown.md step 4). The massif's shapes stop near 11 m of one
## soft noise; this moves a wall's contours along the fall line, so a wall comes
## out in buttresses, ribs and gullies, and a level stays a level: on flat ground
## a move along the ground changes nothing, whatever the noise says.
##
## PeakMassif._h asks `move` for how far to walk along the fall line before it
## reads its own shapes, then `ledge` for the strata on the height it got. Both
## are pure in (a, v, step), so a chunk, the collider and LandField.height agree.
## A wall moves by at most MOVE_MOST m. Down at a gorge's floor only the hollows
## stand (PeakMassif._h): they go back from the flown air, so gullies reach the
## floor and no wall comes nearer the plane. `step`, a chunk's quad: scales the
## mesh can't carry are left out, so the detail shrinks with distance. 0: all of
## them, as the finest chunks (the collider's) have them.
##
## `move`'s second number is the paint: a chunk bakes it into the carve's marks
## (CUSTOM0), the land's groove and crest, so a wall facing the sun keeps its ribs
## where its normals alone stay in one tone. Being a vertex's, it shrinks too.
##
## native/terrain_kernels/peak_massif.h mirrors this file: change both.
##
## --peak-rock=0: none of it, the massif as it was.

static var wanted := "--peak-rock=0" not in preload("res://scripts/launch_args.gd").user_args()

## The scales' plan sizes (m) and how far each moves a wall (m).
const BUTTRESS := Vector2(190.0,17.0)
const RIB := Vector2(68.0,11.0)
const GULLY := Vector2(24.0,5.0)
const CHIP := Vector2(8.5,1.6)
## How many sizes a scale spans in quads, to be kept.
const KEEP_QUADS := 3.5
## A buttress's plan: steps of the noise, so a face runs flat to a corner.
const BLOCKS := 3.0
const BLOCK_EDGE := 0.28
## Big quiet planes among the broken ground (size, m).
const PLANES := 330.0
## The most any wall moves.
const MOVE_MOST := 30.0
## How much a rib counts in the paint: the small scales are what a wall square
## to the sun has lost, the large ones would paint it in broad bands.
const PAINT_RIB := 0.3
## The strata's ledges: a band's height (m), how much of it is the riser, how
## hard it bites, the quad past which the mesh can't carry them.
const LEDGE := Vector2(30.0,0.42)
const LEDGE_BITE := 0.75
const LEDGE_QUAD := 4.0
## Their tilt: the folds of the ground shader's beds (`bed_p`), so the height's
## ledges lean with the paint's bands.
const FOLD_A := Vector3(0.0041,0.0029,46.0)
const FOLD_B := Vector3(-0.011,0.007,20.0)
const FOLD_C := Vector2(0.11,0.14)
## Patches of it: size (m).
const LEDGE_PATCH := 150.0

var _n := FastNoiseLite.new()

func _init(land_seed: int) -> void:
	_n.seed = hash([land_seed,"peak_rock"])&0x7fffffff
	_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_n.frequency = 1.0
	_n.fractal_type = FastNoiseLite.FRACTAL_NONE

## The noise's seed, for the native massif (ZenScapePeak `setup`).
func noise_seed() -> int:
	return _n.seed

## Sharp along its crests, -1 to 1.
func _ridged(x: float, y: float) -> float:
	return 1.0-2.8*absf(_n.get_noise_2d(x,y))

## Vector2(how far (m) to walk up the fall line at (a, v), the relief's paint in
## m: down a gully, up on a rib).
func move(a: float, v: float, step: float) -> Vector2:
	var c := step*KEEP_QUADS
	var quiet := smoothstep(-0.25,0.3,_n.get_noise_2d(a/PLANES+91.0,v/PLANES-37.0))
	var w := 0.0
	var paint := 0.0
	if BUTTRESS.x >= c:
		var r := clampf(_ridged(a/BUTTRESS.x,v/BUTTRESS.x)*0.5+0.5,0.0,1.0)*BLOCKS
		var k := floorf(r)
		w = (k+smoothstep(0.5-BLOCK_EDGE,0.5+BLOCK_EDGE,r-k))/BLOCKS*2.0-1.0
		w *= BUTTRESS.y
	if RIB.x >= c:
		var r := _ridged(a/RIB.x+13.0,v/RIB.x+5.0)*RIB.y*(0.45+0.55*quiet)
		w += r
		paint += r*PAINT_RIB
	if GULLY.x >= c:
		var g := _ridged(a/GULLY.x-31.0,v/GULLY.x+17.0)*GULLY.y*(0.4+0.6*quiet)
		w += g
		paint += g
	if CHIP.x >= c:
		var p := _ridged(a/CHIP.x+7.0,v/CHIP.x-23.0)*CHIP.y*(0.4+0.6*quiet)
		w += p
		paint += p
	return Vector2(clampf(w,-MOVE_MOST,MOVE_MOST),paint)

## The height `h` at world (x, z) with the strata's ledges bitten into it,
## under `keep` of them.
func ledge(h: float, x: float, z: float, a: float, v: float, keep: float, step: float) -> float:
	if step > LEDGE_QUAD: return h
	var on := smoothstep(-0.2,0.2,_n.get_noise_2d(a/LEDGE_PATCH-53.0,v/LEDGE_PATCH+71.0))*keep
	if on <= 0.001: return h
	var fold := FOLD_A.z*sin(x*FOLD_A.x+z*FOLD_A.y)+FOLD_B.z*sin(x*FOLD_B.x+z*FOLD_B.y+1.3)+x*FOLD_C.x+z*FOLD_C.y
	var s := (h+fold)/LEDGE.x
	var f := s-floorf(s)
	return h+(smoothstep(0.0,LEDGE.y,f)-f)*LEDGE.x*on*LEDGE_BITE
