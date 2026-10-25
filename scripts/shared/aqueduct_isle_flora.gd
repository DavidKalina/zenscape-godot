extends RefCounted
## The aqueduct isle's grass and flowers: the kit isles' (scripts/kit_isle/
## kit_flora.gd, the game's shader grass tufts and meadow flowers grown as
## its sky islands grow them) over this isle's turf, its worn paths
## (Art `path_wear`) bare.
const Art = preload("res://scripts/shared/aqueduct_isle_art.gd")

## The kit's numbers (KitFlora), named here as the isle's tests read them.
const PATH_BARE := KitFlora.PATH_BARE
const PATH_THIN := KitFlora.PATH_THIN
const RIM := KitFlora.RIM
const STEEP_SHARE := KitFlora.STEEP_SHARE

## The grass as a carpet over all the turf (KitFlora Site `carpet`): this
## many tufts a square metre, drawn out this far (m). --grass-drifts grows
## the kit's drifts as before.
const CARPET_TUFTS := 7.8
const CARPET_RANGE := 220.0
## The carpet grows to the rim (m in), a little taller everywhere and wild
## (this much taller again) toward the rim and at what stands' feet.
const CARPET_RIM := 0.05
const CARPET_BUMP := 1.12
const CARPET_SHAG := 0.6
## More than one grass, darkened where it meets stone (KitFlora Site
## `variety`, `contact`); muted toward olive, tufts and turf, and a passing
## gust paling the blades more (shaders/reference_surface.gdshader
## `grass_mute`, `ground_mute`, `grass_wave_sheen`, 0.34).
const CARPET_CONTACT := 0.3
## The meadow's height rolls this much either way, the tufts lean up to
## this (radians; KitFlora Site `height_field`, `tilt`).
const CARPET_ROLL := 0.35
const CARPET_TILT := 0.25
const CARPET_MUTE := 0.7
const CARPET_GROUND_MUTE := 0.6
const CARPET_SHEEN := 0.55

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
	var graded := not "--grass-plain-look" in preload("res://scripts/launch_args.gd").user_args()
	if graded: ground.set_shader_parameter("ground_mute",CARPET_GROUND_MUTE)
	for batch: Node in flora.get_children():
		if batch is MultiMeshInstance3D and str(batch.get_meta("part","")).begins_with("grass"):
			var m := (batch as MultiMeshInstance3D).material_override as ShaderMaterial
			m.set_shader_parameter("grass_dry",CARPET_GRASS_DRY)
			if not graded: continue
			m.set_shader_parameter("grass_mute",CARPET_MUTE)
			m.set_shader_parameter("grass_wave_sheen",CARPET_SHEEN)

## The isle's ground as the growers read it.
static func site() -> KitFlora.Site:
	return carpeted(KitFlora.Site.new(Art.TOP,func(p: Vector2) -> float: return Art.path_wear(p)))

## `s` with the grass as the carpet (unless --grass-drifts): any isle's
## site may take it, and `calm` once its flora has grown.
static func carpeted(s: KitFlora.Site) -> KitFlora.Site:
	if carpet():
		s.carpet = true
		s.tufts = CARPET_TUFTS
		s.grass_range = CARPET_RANGE
		s.rim = CARPET_RIM
		s.tuft_bump = CARPET_BUMP
		s.shag = CARPET_SHAG
		s.variety = not "--grass-one-kind" in preload("res://scripts/launch_args.gd").user_args()
		s.contact = CARPET_CONTACT
		s.height_field = CARPET_ROLL
		s.tilt = CARPET_TILT
	return s

## The plants (KitFlora `grow`: meta records, counts, instances, triangles).
static func grow(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array) -> Node3D:
	return KitFlora.grow(seed_value,space,turf,outlines,site())
