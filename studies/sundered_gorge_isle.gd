extends "res://studies/kit_isle.gd"
## The Sundered gorge isle (docs/scenic/sundered-gorge.md): a hand-built sky
## island motif in the aqueduct isle's universe. One big isle torn in two by
## a gorge, the halves drifted apart: the west lower and tilted toward the
## gap, the east level and higher; sheer, warm-lit walls with ledges cut
## along them; the hanging rock of both keels under the split. A great stone
## bridge that spanned it on one arch has snapped at its crown: each half
## keeps its half-arch, and a live rope bridge (scripts/rope_bridge.gd) is
## slung across the break between stone anchors; the crown's stones hang in
## the gap beside it, the rest of it lies on a fragment caught deep below.
## The west has the gatehouse (the kit's gate arch and a leaning tower over
## the lip), a tor and a spring pool spilling into the gorge as a wide
## curtain; the east a roofless chapel facing the bridge, and a crag. A
## lower crossing (the kit's stairs down the west wall, two fragments caught
## in the gap, a ramp up the east wall) makes a loop; a split pillar by it is
## a wall-kick chimney. The plane's line: into the gorge from the north, past
## the curtain, under the lower crossing and the broken bridge, out south.
## Art: studies/sundered_gorge_isle_art.gd.
##
## Everything else is the kit isles' (studies/kit_isle.gd, docs/scenic/
## kit-isle-shared.md): the character study's pilot and moves, the rope
## bridge underfoot, the game's look rig and presets (L / Shift+L,
## --look=<id>), the ground and rock, the plane (F), the lodestone (here on
## the fallen crown deep in the gorge: drop to it from the break, pick it
## up, board the plane to fly out), the grass and flowers (on this isle's
## ground: `flora_site`), the life (studies/
## sundered_gorge_isle_life.gd) and the sky round it (studies/
## sundered_gorge_isle_sky.gd), with the same opt-out flags (--no-flora,
## --no-life, --no-undergrowth, --no-butterflies, --no-fireflies, --no-birds,
## --no-wind-life, --no-tokens, --no-sky, --no-far-isles, --no-airships,
## --no-traffic, --no-sky-life, --no-motes, --no-sky-tokens, --no-lode).
##   ./run-sundered-gorge.command [--look=rosewater_dusk] [--fly]
##   godot --path . res://studies/sundered_gorge_isle.tscn -- --no-title [--capture=out.png --at=x,y,z --look=x,y,z] [--place=x,y,z[,turn]]
const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")
const GorgeLife = preload("res://studies/sundered_gorge_isle_life.gd")
const GorgeSky = preload("res://studies/sundered_gorge_isle_sky.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
## The isle itself (its art and turf), built here at the origin as the
## aqueduct isle's sky places it elsewhere (scripts/kit_isle/
## motif_sundered_gorge.gd).
const Motif = preload("res://scripts/kit_isle/motif_sundered_gorge.gd")

const GORGE_SEED := Motif.GORGE_SEED
## Fallen under this (world y) he is set back at the start: nothing stands
## under it but the keels' points.
const GORGE_LOST := 9.0

var motif := Motif.new()
## The pieces built (their metadata drives the tests).
var west_half: Node3D
var east_half: Node3D
var west_bridge: Node3D
var east_bridge: Node3D
var gate: Node3D
var gate_tower: Node3D
var chapel: Array[Node3D] = []
var flights: Array[Node3D] = []
var fragments: Array = []
var water: Node3D
## The rope bridge and the deck the walker reads ({a, b, span, sim}).
var rope: MeshInstance3D
var rope_deck := {}

# --- Set up ----------------------------------------------------------------------

## No pack station: the isle's own start, one station there (the fall's
## respawn).
func _load_pack() -> void:
	start = Gorge.start()
	start_face = Vector2(1.0,0.0)
	stations = [{"key":1,"name":"Sundered gorge","spawn":start,"face":start_face,"parts":[]}]
	lost = GORGE_LOST
	_last_stood = start

func isle_name() -> String:
	return motif.isle_name()

func isle_card() -> Dictionary:
	return motif.isle_card()

func isle_top() -> float:
	return motif.top()

## The air's summit: the west tor.
func isle_summit() -> Vector3:
	return motif.summit()

## The plants keep off the paths and the pool; their rays reach the ledges
## and fragments far down the gorge; a sparser sowing (the motif's site).
func flora_site() -> KitFlora.Site:
	return motif.flora_site()

func flora_seed() -> int:
	return motif.flora_seed()

func sky_script() -> Script:
	return GorgeSky

func life_script() -> Script:
	return GorgeLife

func _build_room() -> void:
	ground.pools.append_array(motif.pools())
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	motif.build(art)
	west_half = motif.west_half
	east_half = motif.east_half
	west_bridge = motif.west_bridge
	east_bridge = motif.east_bridge
	gate = motif.gate
	gate_tower = motif.gate_tower
	chapel = motif.chapel
	flights = motif.flights
	fragments = motif.fragments
	water = motif.water
	rope = motif.rope
	rope_deck = motif.rope_deck
	for land: Array in motif.lands: add_turf(land[0],land[1],land[2])
	print("sundered gorge: %d triangles" % triangles(art))

# --- The lodestone ----------------------------------------------------------------

## The lodestone on the fallen crown (or on a floating stone named by
## --lode-at=), the shard it points to.
func lode_rest_at() -> Vector3:
	var p: Dictionary = Gorge.platform(_lode_at)
	if p.is_empty():
		var f: Array = Gorge.fragment("crown")
		return Vector3((f[1] as Vector2).x,float(f[3]),(f[1] as Vector2).y)+Gorge.CROWN_LODE+Vector3.UP*LODE_HOVER
	return (p.at as Vector3)+Vector3.UP*LODE_HOVER

func lode_hint() -> String:
	return "A lodestone hums deep in the gorge, on the bridge's fallen crown: drop to it from the break"
