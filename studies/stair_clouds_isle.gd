extends "res://studies/kit_isle.gd"
## The Stair to the Clouds: a small round isle, the tallest in the sky, a
## stepped mesa of dark faceted rock over a low lawn. A ceremonial grand stair
## winds once round it from the lawn to the summit in eight flights, a landing
## with its shrine at each turn; four broad terraces climb round it as wedges;
## a lone gate stands on the summit's south rim, a rope bridge reaching from it
## to a detached pinnacle that hangs over the lawn. See docs/scenic/
## stair-clouds.md and studies/stair_clouds_isle_art.gd.
##
## Everything else is the kit isles' (studies/kit_isle.gd, docs/scenic/
## kit-isle-shared.md): the pilot and his moves, the rope bridge underfoot,
## the ground and rock, the game's grass and flowers, its light, sky, air,
## weather and the look presets (L / Shift+L, --look=<id>), the plane (F), the
## lodestone, the sky round it (its tokens here this isle's own: studies/
## stair_clouds_isle_sky.gd) and the life on it (studies/
## stair_clouds_isle_life.gd). The same opt-outs: --no-flora, --no-life,
## --no-sky, --no-lode, --fly.
##   R            back to the start (the lawn, by the stair's foot)
##   L / Shift+L  next / previous look preset
##   B            a strong gust front
##   Space (pad A) by the parked plane: into it; land by hand, F (pad Y) out once stopped
##   ./run-stair-clouds.command [--look=first_snow]
##   godot --path . res://studies/stair_clouds_isle.tscn -- --no-title [--capture=out.png --at=x,y,z --look=x,y,z] [--place=x,y,z[,turn]]
const Stair = preload("res://studies/stair_clouds_isle_art.gd")
const StairSky = preload("res://studies/stair_clouds_isle_sky.gd")
const StairLife = preload("res://studies/stair_clouds_isle_life.gd")
## The isle itself (its art and turf), built here at its own frame as the
## aqueduct isle's sky places it elsewhere (scripts/kit_isle/
## motif_stair_clouds.gd).
const Motif = preload("res://scripts/kit_isle/motif_stair_clouds.gd")

## Falling past this (world y) he is set back where he last stood's nearest
## safe place: the start.
const LOST_Y := Stair.TOP-30.0

var motif := Motif.new()
var mesa: Node3D
var stair: Node3D
var pinnacle: Node3D
var bridge: MeshInstance3D

func _ready() -> void:
	super._ready()

## No station: the isle is its own. He starts on the lawn, by leg 1's foot,
## looking up the stair.
func _load_pack() -> void:
	stations = []
	var foot := Stair.side_at(0,-Stair.RUN*0.5-2.5,Stair.MID)
	start = Vector3(foot.x,Stair.TOP,foot.y)
	var way := Stair.tangent_of(0)
	start_face = way
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

func sky_script() -> Script:
	return StairSky

func life_script() -> Script:
	return StairLife

func _build_room() -> void:
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var began := Time.get_ticks_msec()
	motif.build(art)
	mesa = motif.mesa
	stair = motif.stair
	pinnacle = motif.pinnacle
	bridge = motif.bridge
	for land: Array in motif.lands: add_turf(land[0],land[1],land[2])
	# The on-foot pieces: balustrades down the top flights, bobbing slabs.
	preload("res://scripts/interactables/stair_clouds_foot_route.gd").build(self,Vector3.ZERO)
	print("stair to the clouds: %d triangles, the mesa built in %d ms, the rest in %d ms" % [triangles(art),motif.mesa_ms,Time.get_ticks_msec()-began-motif.mesa_ms])

# --- The lodestone ------------------------------------------------------------------

## The lodestone rests on the summit, by the gate.
func lode_rest_at() -> Vector3:
	var p := Stair.side_at(Stair.SIDES-1,3.2,-10.0)
	return Vector3(p.x,Stair.TOP+Stair.SUMMIT+LODE_HOVER+0.25,p.y)

func lode_hint() -> String:
	return "A lodestone hums on the summit, by the gate: climb the stair"
