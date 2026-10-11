extends RefCounted
## The aqueduct isle's grass and flowers: the kit isles' (scripts/kit_isle/
## kit_flora.gd, the game's shader grass tufts and meadow flowers grown as
## its sky islands grow them) over this isle's turf, its worn paths
## (Art `path_wear`) bare.
const Art = preload("res://studies/aqueduct_isle_art.gd")

## The kit's numbers (KitFlora), named here as the isle's tests read them.
const PATH_BARE := KitFlora.PATH_BARE
const PATH_THIN := KitFlora.PATH_THIN
const RIM := KitFlora.RIM
const STEEP_SHARE := KitFlora.STEEP_SHARE

## The isle's ground as the growers read it.
static func site() -> KitFlora.Site:
	return KitFlora.Site.new(Art.TOP,func(p: Vector2) -> float: return Art.path_wear(p))

## The plants (KitFlora `grow`: meta records, counts, instances, triangles).
static func grow(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array) -> Node3D:
	return KitFlora.grow(seed_value,space,turf,outlines,site())
