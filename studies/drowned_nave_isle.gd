extends "res://studies/kit_isle.gd"
## The drowned nave: a hand-built sky-island motif, a kit isle (its look,
## light, air, presets, ground and rock, grass, life, sky, plane and
## lodestone are the kit isles' own: studies/kit_isle.gd, docs/scenic/
## kit-isle-shared.md; see docs/scenic/drowned-nave.md).
##
## A larger isle with a wide shallow basin of still water over most of its
## top (studies/drowned_nave_isle_art.gd) and a long gothic nave half
## drowned in it: two rows of piers and pointed arches rising out of the
## water, each fallen in a run, their wall-walks overhead; a causeway of
## fallen stones down the nave; at the far end a rocky apse with a grand
## stair up to the rose gable; on the beach to the west a lancet window the
## plane comes in through; the basin spills over the north lip as a fall.
##
## The plane's line: in over the beach, skimming the nave's axis, out
## through the south row's gap, back through a standing bay, up through the
## broken vault at the chancel, down the fall.
##   R            back to the start (the beach)
##   L / Shift+L  look presets · B gust · Space (pad A) by the parked plane
##   F1 numbers · F2 feel · Esc mouse
##   ./run-drowned-nave.command [--look=<preset id>]
## The kit isles' flags hold here: --no-flora, --no-life (and its
## parts), --no-sky (and its parts), --fly, --look=, --capture=, --at=,
## --place=, --no-lode, --carry, --stone-plane.
const NaveArt = preload("res://studies/drowned_nave_isle_art.gd")
const NaveLife = preload("res://studies/drowned_nave_isle_life.gd")
## The isle itself, built here at the origin as the aqueduct isle's sky
## places it elsewhere (scripts/kit_isle/motif_drowned_nave.gd).
const Motif = preload("res://scripts/kit_isle/motif_drowned_nave.gd")

const NAVE_SEED := Motif.NAVE_SEED
## Where the walker starts: on the beach, looking east down the nave.
const START_LOCAL := Vector2(-38.0,3.0)
const START_LOOK_AT := Vector2(1.0,0.0)
const WATER_LAYER := Motif.WATER_LAYER
## The lodestone rests on a block on the apse's plateau.
const NAVE_LODE := "lode"

var motif := Motif.new()
var water: MeshInstance3D
var fall_node: Node3D

# --- Setting up -----------------------------------------------------------------------

func _load_pack() -> void:
	stations = []
	var s := NaveArt.world(START_LOCAL)
	start = Vector3(s.x,NaveArt.ground(s.x,s.y),s.y)
	start_face = START_LOOK_AT.normalized()
	lost = NaveArt.W-45.0
	_last_stood = start
	_lode_at = NAVE_LODE

func isle_name() -> String:
	return motif.isle_name()

func isle_card() -> Dictionary:
	return motif.isle_card()

func isle_top() -> float:
	return motif.top()

func isle_summit() -> Vector3:
	return motif.summit()

func flora_site() -> KitFlora.Site:
	return motif.flora_site()

func flora_seed() -> int:
	return motif.flora_seed()

func sky_script() -> Script:
	return NaveLife.NaveSky

func life_script() -> Script:
	return NaveLife

func capture_look() -> Vector3:
	return Vector3(NaveArt.C.x,NaveArt.W+2.0,NaveArt.C.y)

func _build_room() -> void:
	ground.pools.append_array(motif.pools())
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var began := Time.get_ticks_msec()
	motif.build(art)
	water = motif.water
	fall_node = motif.fall_node
	for land: Array in motif.lands: add_turf(land[0],land[1],land[2])
	var isle: Node3D = motif.isle_node
	print("drowned nave: %d triangles, built in %d ms (isle: %d ground points, %d cliff prisms; water %d triangles)" % [triangles(art),Time.get_ticks_msec()-began,int(isle.get_meta("ground_points")),int(isle.get_meta("cliff_prisms")),int(water.get_meta("triangles",0))])

## The lodestone on the plateau's block.
func lode_rest_at() -> Vector3:
	var p: Dictionary = NaveArt.platform(_lode_at)
	if p.is_empty(): p = NaveArt.platform(NAVE_LODE)
	return (p.at as Vector3)+Vector3.UP*LODE_HOVER

func lode_hint() -> String:
	return "A lodestone hums on the apse: up the grand stair to the rose gable"

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

## Set down on dry turf, never in the water.
func _turf_top(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Vector3:
	var top := super._turf_top(space,x,z)
	if top != Vector3.INF and top.y < NaveArt.W+0.2: return Vector3.INF
	return top
