extends "res://studies/kit_isle.gd"
## The cloister tarn: a hand-built sky-island motif, a kit isle (its look,
## light, air, presets, ground and rock, grass, life, sky, plane, rope
## bridges underfoot and lodestone are the kit isles' own: studies/
## kit_isle.gd, docs/scenic/kit-isle-shared.md; see docs/scenic/
## cloister-tarn.md).
##
## A crater-bowl mother isle rings a still tarn (studies/
## cloister_tarn_isle_art.gd): its rim rises to a tiered crag north-west and
## falls to a notch east, where the tarn spills under the cloister's water
## gate and off the edge as a wide curtain. Round the tarn stands a ruined
## cloister (scripts/ruin_kit_cloister.gd): four ranges of pointed arches on
## clustered piers carrying a wall-walk that runs round as a loop, its west
## range fallen in the middle (the cloister's gap: two snapped piers to hop,
## heaps at its ends to climb), a lavabo on a little isle in the tarn
## (stepping stones out to it), a slab bridge from the south terrace onto
## the walk. Round the mother, four satellite isles at different heights,
## tied to it by rope bridges on stone heads (scripts/rope_bridge.gd, the
## spring-sim bridges, walked as the game's walker walks them) and to each
## other by floating stones: a ring.
##
## The plane's line: in over the west saddle, through the cloister's gap
## (between the stubs on knife edge, or over them), skimming the tarn, out
## through the water gate and off over the fall.
##   R            back to the start (the cloister's south-east corner)
##   L / Shift+L  look presets · B gust · Space (pad A) by the parked plane
##   F1 numbers · F2 feel · Esc mouse
##   ./run-cloister-tarn.command [--look=<preset id>]
## The kit isles' flags hold here: --no-flora, --no-life (and its
## parts), --no-sky (and its parts), --fly, --look=, --capture=, --at=,
## --place=, --no-lode, --carry, --stone-plane.
const TarnArt = preload("res://studies/cloister_tarn_isle_art.gd")
const TarnLife = preload("res://studies/cloister_tarn_isle_life.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Cloister = preload("res://scripts/ruin_kit_cloister.gd")
## The isle itself (its art, turf and water), built here at the origin as
## the aqueduct isle's sky places it elsewhere (scripts/kit_isle/
## motif_cloister_tarn.gd).
const Motif = preload("res://scripts/kit_isle/motif_cloister_tarn.gd")

const TARN_SEED := Motif.TARN_SEED
const WEATHERED := Motif.WEATHERED
## Where the walker starts: the cloister's south-east corner, looking along
## the south alley to the west.
const START_AT := Vector3(TarnArt.C.x+14.4,TarnArt.K,TarnArt.C.y+14.4)
const START_LOOK_AT := Vector2(-1.0,-0.35)
## The water's own layer: the plane skims it (as the turf), the pilot's
## rays never see it.
const WATER_LAYER := Motif.WATER_LAYER
## The lodestone rests on the north isle's altar stone.
const TARN_LODE := "north_altar"

var motif := Motif.new()
var cloister: Dictionary = {}
var bridges: Array = []
var water: MeshInstance3D
var fall_node: Node3D

# --- Setting up -----------------------------------------------------------------------

## No pack here: the isle is built whole (`_build_room`).
func _load_pack() -> void:
	stations = []
	start = START_AT
	start_face = START_LOOK_AT.normalized()
	lost = TarnArt.W-45.0
	_last_stood = start
	_lode_at = TARN_LODE

func isle_name() -> String:
	return motif.isle_name()

func isle_card() -> Dictionary:
	return motif.isle_card()

func isle_top() -> float:
	return motif.top()

## The air's summit: the crag.
func isle_summit() -> Vector3:
	return motif.summit()

## The plants keep off the paths, the water and its edge, out of the water;
## their rays reach the tarn's bed (the motif's site).
func flora_site() -> KitFlora.Site:
	return motif.flora_site()

func flora_seed() -> int:
	return motif.flora_seed()

func sky_script() -> Script:
	return TarnLife.TarnSky

func life_script() -> Script:
	return TarnLife

func capture_look() -> Vector3:
	return Vector3(TarnArt.C.x,TarnArt.K+2.0,TarnArt.C.y)

func _build_room() -> void:
	ground.pools.append_array(motif.pools())
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var began := Time.get_ticks_msec()
	motif.build(art)
	cloister = motif.cloister
	bridges = motif.bridges
	water = motif.water
	fall_node = motif.fall_node
	kit_stairs = motif.kit_stairs
	for land: Array in motif.lands: add_turf(land[0],land[1],land[2])
	var mother: Node3D = motif.mother
	print("cloister tarn: %d triangles, built in %d ms (mother: %d ground points, %d cliff prisms)" % [triangles(art),Time.get_ticks_msec()-began,int(mother.get_meta("ground_points")),int(mother.get_meta("cliff_prisms"))])

## The old water's material (--old-water; the motif's).
static func tarn_material() -> Material:
	return Motif.tarn_material()

## The lodestone on the north isle's altar.
func lode_rest_at() -> Vector3:
	var p: Dictionary = TarnArt.platform(_lode_at)
	if p.is_empty(): p = TarnArt.platform(TARN_LODE)
	return (p.at as Vector3)+Vector3.UP*LODE_HOVER

func lode_hint() -> String:
	return "A lodestone hums on the north isle: up the crag and out over the floating stones"

## The water is skimmed as the turf is.
func plane_ground(p: Vector3) -> Variant:
	if _ground_ray == null:
		_ground_ray = PhysicsRayQueryParameters3D.new()
		_ground_ray.collision_mask = TURF_LAYER|WATER_LAYER
	_ground_ray.from = p+Vector3.UP
	_ground_ray.to = p+Vector3.DOWN*60.0
	var hit := get_world_3d().direct_space_state.intersect_ray(_ground_ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.3: return null
	return float((hit.position as Vector3).y)

## Set down on dry turf, never in the tarn.
func _turf_top(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Vector3:
	var top := super._turf_top(space,x,z)
	if top != Vector3.INF and top.y < TarnArt.W+0.2: return Vector3.INF
	return top
