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

## The grass as a carpet over all the turf (KitFlora Site `carpet`): this
## many tufts a square metre, drawn out this far (m). --grass-drifts grows
## the kit's drifts as before.
const CARPET_TUFTS := 7.0
const CARPET_RANGE := 220.0

## Under the carpet the dry patches calm (shaders/ground_look.gdshaderinc
## `ground_dry`, 0.45, and its light patches `ground_patch`, 1.3; the
## tufts' `grass_dry`, 0.25), so the turf reads one meadow from the plane.
const CARPET_GROUND_DRY := 0.12
const CARPET_GROUND_PATCH := 0.7
const CARPET_GRASS_DRY := 0.06

static func carpet() -> bool:
	return not "--grass-drifts" in preload("res://scripts/launch_args.gd").user_args()

## The carpet's calmer ground and tufts, once `flora` has grown.
static func calm(flora: Node3D) -> void:
	if not carpet(): return
	var ground := KitLook.ground_material()
	ground.set_shader_parameter("ground_dry",CARPET_GROUND_DRY)
	ground.set_shader_parameter("ground_patch",CARPET_GROUND_PATCH)
	for batch: Node in flora.get_children():
		if batch is MultiMeshInstance3D and str(batch.get_meta("part","")).begins_with("grass"):
			((batch as MultiMeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("grass_dry",CARPET_GRASS_DRY)

## The isle's ground as the growers read it.
static func site() -> KitFlora.Site:
	var s := KitFlora.Site.new(Art.TOP,func(p: Vector2) -> float: return Art.path_wear(p))
	if carpet():
		s.carpet = true
		s.tufts = CARPET_TUFTS
		s.grass_range = CARPET_RANGE
	return s

## The plants (KitFlora `grow`: meta records, counts, instances, triangles).
static func grow(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array) -> Node3D:
	return KitFlora.grow(seed_value,space,turf,outlines,site())
