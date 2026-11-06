extends RefCounted
## The railroad's tunnels' cross-section and portals (spec-railroad.md, lane
## line), read by the land round them (rail_bed.gd: the cover over the bore,
## the wider cut at a mouth, the hole in the land at a portal) and by the
## bore itself (rail_bore.gd: the tube, the portal blocks, the flight's
## answers). Static: no state.
##
## A double-track bore: a flat floor at the bed's top, walls straight up
## SPRING m, then a half-ellipse vault. Sized from the trains and the plane
## (AGENTS.md Sizes): past each track's car (RailLine CAR_WIDTH, the tracks
## RailLine.track_gap() apart) an opening of TOY_WALL to the wall, and over
## the tallest car (CAR_TALL) an opening of TOY_OVER under the vault at the
## car's outer edge, so the plane flies beside a train or over it, in the
## dark, with the other train coming.
##
## Each mouth stands in a portal block: a mass of dressed stone across the
## line, FACE_HALF m either side of it, from a little in front of the
## tunnel's first metre (FACE_OUT) BLOCK_IN m into it, its top PARAPET m
## over the land's cover. The land under the block is holed (HOLE_*) and
## the block hides the hole's edges.

const RailLine = preload("res://scripts/endless/rail_line.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The toy-era widths (WorldScale.opening) past a car to the wall, and over
## the tallest car to the vault (7 m each at the defaults).
const TOY_WALL := 3.5
const TOY_OVER := 3.5
## The tallest car the line is laid for, over the bed (the train lane's box
## cars: rail_train.gd CARS, 9 m).
const CAR_TALL := 9.0
## The walls' straight height over the floor, where the vault springs.
const SPRING := 6.0
## Land over the vault's crown, at least (the cover the land is raised to,
## rail_bed.gd), out to COVER_PAST m past the walls, then falling as a bank.
const COVER := 6.0
const COVER_PAST := 6.0
## The portal block: its half width, its front this far in front of the
## tunnel's first metre, its back this far in, its top this far over the
## cover. The land's cover starts COVER_FROM m in (inside the block), the
## cut's flat running to it; beside the block (past its half width) the
## cover starts at its face, so the hill stands up beside it. The land
## holed under it: HOLE_PAST m past the walls each side, from HOLE_FROM to
## HOLE_IN m in, so the land's step up to the cover, inside, falls in the
## hole, and what is left at the hole's front lies flat on the bed.
const FACE_HALF_PAST := 8.0
const FACE_OUT := 1.0
const BLOCK_IN := 12.0
const PARAPET := 2.0
const COVER_FROM := 6.0
const HOLE_PAST := 2.0
const HOLE_FROM := -0.5
const HOLE_IN := 9.0
## The cut in front of a mouth runs wider than the bed (rail_bed.gd HALF):
## flat to MOUTH_PAST m past the bore's walls, for MOUTH_FLAT m out from
## the face, eased back to the bed's width over MOUTH_EASE m more.
const MOUTH_PAST := 4.0
const MOUTH_FLAT := 30.0
const MOUTH_EASE := 60.0

static var _half := NAN
static var _rise := NAN

## The bore's half width at the floor (m).
static func half() -> float:
	if is_nan(_half): _size()
	return _half

## The vault's rise over SPRING: high enough that over a car's outer top
## edge there is TOY_OVER's opening.
static func rise() -> float:
	if is_nan(_rise): _size()
	return _rise

static func _size() -> void:
	var line: RefCounted = RailLine.shared()
	var outer := float(line.track_gap())*0.5+RailLine.CAR_WIDTH*0.5
	var h := outer+WorldScale.opening(TOY_WALL)
	var k := sqrt(maxf(1.0-(outer/h)*(outer/h),0.05))
	_rise = maxf((CAR_TALL+WorldScale.opening(TOY_OVER)-SPRING)/k,2.0)
	_half = h

## The vault's crown over the floor.
static func crown() -> float:
	return SPRING+rise()

## The roof's height over the floor at `d` m off the centre line (either
## side), NAN at or past the walls.
static func roof_over(d: float) -> float:
	var h := half()
	var a := absf(d)
	if a >= h: return NAN
	return SPRING+rise()*sqrt(1.0-(a/h)*(a/h))

## The wall's half width `y` m over the floor (0 over the crown).
static func half_at(y: float) -> float:
	if y <= SPRING: return half()
	var r := rise()
	if y >= SPRING+r: return 0.0
	var t := (y-SPRING)/r
	return half()*sqrt(1.0-t*t)

## The cover's top over the floor, `d` m off the centre line.
static func cover_over(d: float) -> float:
	return crown()+COVER-maxf(absf(d)-half()-COVER_PAST,0.0)*0.7

## The portal block's half width and top over the floor.
static func face_half() -> float:
	return half()+FACE_HALF_PAST

static func block_top() -> float:
	return crown()+COVER+PARAPET
