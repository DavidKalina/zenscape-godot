extends "res://studies/kit_isle.gd"
## The Hollow Keel (docs/scenic/hollow-keel.md): a medium sky isle that looks
## modest from above, turf and a broken chapel with a shaft in its floor, and
## hides a vaulted undercroft in its underside: the colossus hall hung under
## the plate, open at both mouths and breached along its sides, to fly
## through under the isle's edge, weaving the columns, and out the other
## end. The shaft drops from the chapel to the hall's floor by three grand
## stairs; the hall's east mouth comes out on a stone porch in the keel with
## a rope bridge to a small hanging islet where the lodestone rests.
## Art: studies/hollow_keel_isle_art.gd.
##
## Everything else is the kit isles' (studies/kit_isle.gd, docs/scenic/
## kit-isle-shared.md): the character study's pilot and moves, the rope
## bridge underfoot, the game's look rig and presets (L / Shift+L,
## --look=<id>), the ground and rock, the plane (Space by it), the
## lodestone, the grass and flowers, the life (studies/
## hollow_keel_isle_life.gd) and the sky round it (studies/
## hollow_keel_isle_sky.gd), with the same opt-out flags (--no-flora,
## --no-life, --no-undergrowth, --no-butterflies, --no-fireflies,
## --no-birds, --no-wind-life, --no-tokens, --no-sky, --no-far-isles,
## --no-clusters, --no-pierced, --no-airships, --no-traffic, --no-sky-life,
## --no-motes, --no-sky-tokens, --no-lode), --fly.
##   ./run-hollow-keel.command [--look=rosewater_dusk] [--fly]
##   godot --path . res://studies/hollow_keel_isle.tscn -- --no-title [--capture=out.png --at=x,y,z --look=x,y,z] [--place=x,y,z[,turn]]
const Keel = preload("res://studies/hollow_keel_isle_art.gd")
const KeelLife = preload("res://studies/hollow_keel_isle_life.gd")
const KeelSky = preload("res://studies/hollow_keel_isle_sky.gd")
## The isle itself (its art and turf), built here at the origin as the
## aqueduct isle's sky places it elsewhere (scripts/kit_isle/
## motif_hollow_keel.gd).
const Motif = preload("res://scripts/kit_isle/motif_hollow_keel.gd")

## Falling past this (world y) he is set back at the start: under the keel.
const LOST_Y := Keel.YF-24.0

var motif := Motif.new()
## The pieces built (their metadata drives the tests).
var plate: Node3D
var hall: Node3D
var keel: Node3D
var islet: Node3D
var stairs: Array[Node3D] = []
var chapel: Array[Node3D] = []
var bridges: Array[MeshInstance3D] = []

## No pack station: the isle's own start, in front of the chapel's arch.
func _load_pack() -> void:
	start = Vector3(Keel.stair_x(0),Keel.TOP,Keel.MID.y-20.0)
	start_face = Vector2(0.0,1.0)
	stations = []
	lost = LOST_Y
	_last_stood = start

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
	return KeelSky

func life_script() -> Script:
	return KeelLife

func _build_room() -> void:
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var began := Time.get_ticks_msec()
	motif.build(art)
	plate = motif.plate
	hall = motif.hall
	keel = motif.keel
	islet = motif.islet
	stairs = motif.stairs
	chapel = motif.chapel
	bridges = motif.bridges
	for land: Array in motif.lands: add_turf(land[0],land[1],land[2])
	print("hollow keel: %d triangles; built in %d ms" % [triangles(art),Time.get_ticks_msec()-began])

# --- The lodestone ------------------------------------------------------------------

## The lodestone rests on the hanging islet, over the rope bridge.
func lode_rest_at() -> Vector3:
	return Vector3(Keel.ISLET.x+1.5,Keel.ISLET.w+LODE_HOVER+0.25,Keel.ISLET.y)

func can_pick() -> bool:
	if lodestone == null or lode_state != "resting" or flying or not walk_ready: return false
	var feet := motor.feet
	return Vector2(feet.x-lode_rest.x,feet.z-lode_rest.z).length() < PICK_REACH+0.4 and absf(feet.y+LODE_HOVER+0.25-lode_rest.y) < 0.6

func lode_hint() -> String:
	return "A lodestone hums on the hanging islet at the hall's far porch: down the shaft, through the undercroft, over the rope bridge"
