extends "res://scripts/kit_isle/kit_motif.gd"
## The Stair to the Clouds as a motif (scripts/kit_isle/kit_motif.gd; docs/
## scenic/stair-clouds.md): the stepped mesa on its hanging rock, the grand
## stair winding round it in eight flights, the shrines on its landings and
## terraces, the gate and turret on the summit, the detached pinnacle and the
## rope bridge to it (studies/stair_clouds_isle_art.gd). Built here for its
## study (studies/stair_clouds_isle.gd) and for the aqueduct isle's sky alike.
const Stair = preload("res://studies/stair_clouds_isle_art.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")

const STAIR_SEED := 83

var mesa: Node3D
var stair: Node3D
var summit_group: Node3D
var shrine_group: Node3D
var pinnacle: Node3D
var bridge: MeshInstance3D
## The mesa's own build (ms).
var mesa_ms := 0

func id() -> String:
	return "stair_clouds"

func isle_name() -> String:
	return "stair to the clouds"

## Placeholder name and line until the isle is named; its finds are the
## ledger's (scripts/ledger/ledger.gd `card`).
func isle_card() -> Dictionary:
	return Ledger.shared().card(id(),{"name":"The Stair to the Clouds","epithet":"A hundred and ninety-two steps to an open gate"})

func top() -> float:
	return Stair.TOP

## The air's summit: the gate on the mesa's top.
func summit() -> Vector3:
	return Vector3(Stair.O.x,Stair.TOP+Stair.SUMMIT,Stair.O.y)

## The plants keep off the stair's way and the lawn's path to it.
func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(Stair.TOP,KitLand.wear_of(Stair.paths()))

func flora_seed() -> int:
	return 19

func life_script() -> Script:
	return preload("res://studies/stair_clouds_isle_life.gd")

func plane_tokens() -> Array:
	return Stair.plane_tokens()

func token_source() -> String:
	return "stair_clouds"

func warm() -> void:
	super.warm()
	Art.path_wear(Vector2.ZERO)

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	mesa = Stair.mesa(STAIR_SEED)
	mesa_ms = Time.get_ticks_msec()-began
	art.add_child(mesa)
	stair = Stair.stairs(STAIR_SEED+10)
	art.add_child(stair)
	shrine_group = Stair.shrines(STAIR_SEED+30)
	art.add_child(shrine_group)
	summit_group = Stair.summit(STAIR_SEED+60)
	art.add_child(summit_group)
	pinnacle = Stair.pinnacle(STAIR_SEED+70)
	art.add_child(pinnacle)
	art.add_child(Stair.anchors(STAIR_SEED+80))
	var ends := Stair.bridge_ends()
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	bridge = Footbridge.live(Footbridge.build_mesh(a,b,STAIR_SEED+90),a,b,STAIR_SEED+90)
	bridge.name = "RopeBridge"
	art.add_child(bridge)
	# The mesa's tops and the pinnacle's are turf (the mesa's one body).
	turf(mesa,null,false)
	turf(pinnacle)
	built_ms = Time.get_ticks_msec()-began

## Roughly how long `build` takes (ms, headless, this Mac): its sockets,
## footprint and height span are the bake's (scripts/kit_isle/kit_motif.gd).
func build_cost() -> int:
	return 2500
