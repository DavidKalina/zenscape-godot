extends "res://scripts/kit_isle/kit_motif.gd"
## The colonnade spine as a motif (scripts/kit_isle/kit_motif.gd; docs/
## scenic/colonnade-spine.md): the knife-edge ridge, the processional
## colonnade along its crest, the terraces' step walls and stairs, the
## temple gate on its head, the tail's fragments, the stepping stones, the
## anchors and the live rope bridges (studies/colonnade_spine_isle_art.gd).
## The ridge's ground is turf, the prisms under its flanks stone. Built
## here for its study (studies/colonnade_spine_isle.gd) and for the
## aqueduct isle's sky alike.
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")

const SPINE_SEED := 61
## The kit stairs a little ruined: a ceremonial way up.
const STAIR_WEATHERED := 0.3

var colonnade: Node3D
var temple: Node3D
var spine: Node3D
var bridges: Array[MeshInstance3D] = []
## The ridge's own build (ms).
var spine_ms := 0

func id() -> String:
	return "colonnade_spine"

func isle_name() -> String:
	return "colonnade spine"

## Placeholder name and line until the isle is named; its finds are the
## ledger's (scripts/ledger/ledger.gd `card`).
func isle_card() -> Dictionary:
	return Ledger.shared().card(id(),{"name":"The Long Colonnade","epithet":"The bones of a road to nowhere"})

func top() -> float:
	return Spine.TOP

## The plants keep off the way, the north shelf and the south bench.
func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(Spine.TOP,KitLand.wear_of(Spine.paths()))

func life_script() -> Script:
	return preload("res://studies/colonnade_spine_isle_life.gd")

func plane_tokens() -> Array:
	return Spine.plane_tokens()

func token_source() -> String:
	return "colonnade"

func warm() -> void:
	super.warm()
	Spine._rock(0.0,0.0)
	Spine.platforms()

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	spine = Spine.spine_island(SPINE_SEED)
	spine_ms = Time.get_ticks_msec()-began
	art.add_child(spine)
	colonnade = Spine.colonnade(SPINE_SEED+1)
	art.add_child(colonnade)
	art.add_child(Spine.step_walls(SPINE_SEED+2))
	for k in range(Spine.STEPS.size()):
		var s: Node3D = RuinKit.grand_stair(SPINE_SEED+3,STAIR_WEATHERED) if Spine.STEPS[k][3] == "grand" else RuinKit.stairs(SPINE_SEED+4+k,STAIR_WEATHERED)
		s.name = "Stair%d" % k
		s.transform = Spine.stair_frame(k)
		art.add_child(s)
	temple = Spine.temple(SPINE_SEED+10)
	art.add_child(temple)
	var lands: Array = [spine]
	for land: Node3D in Spine.lands(SPINE_SEED+20):
		art.add_child(land)
		lands.append(land)
	art.add_child(Art.floating_stones(SPINE_SEED+30,Spine.platforms()))
	art.add_child(Spine.anchors(SPINE_SEED+40))
	var k := 0
	for ends: Array in Spine.bridge_ends():
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		var bridge: MeshInstance3D = Footbridge.live(Footbridge.build_mesh(a,b,SPINE_SEED+50+k),a,b,SPINE_SEED+50+k)
		bridge.name = "RopeBridge%d" % k
		art.add_child(bridge)
		bridges.append(bridge)
		k += 1
	# The ridge's ground is turf, the prisms under its flanks stone.
	for land: Node3D in lands: turf(land,null,false)
	built_ms = Time.get_ticks_msec()-began
