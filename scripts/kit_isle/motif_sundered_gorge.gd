extends "res://scripts/kit_isle/kit_motif.gd"
## The Sundered gorge as a motif (scripts/kit_isle/kit_motif.gd; docs/
## scenic/sundered-gorge.md): the two drifted halves, the snapped bridge's
## halves with the rope bridge slung across the break, the gatehouse and its
## leaning tower, the chapel, the tor's pier, the kit's flights down the
## west wall, the fragments in the gap, the fallen crown, the floating
## stones, the split pillar, boulders, the spring pool and its curtain
## (studies/sundered_gorge_isle_art.gd). Built here for its study (studies/
## sundered_gorge_isle.gd) and for the aqueduct isle's sky alike.
const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")

const GORGE_SEED := 23

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

func id() -> String:
	return "sundered_gorge"

func isle_name() -> String:
	return "sundered gorge"

## Placeholder name, line and finds until the isle is named.
func isle_card() -> Dictionary:
	return {"name":"The Sundered Gorge","epithet":"Split by a word no one remembers","finds":[["wildflower","Glyphs",1,6],["snow","Echoes",0,3],["bridge","Hidden ways",0,3]]}

func top() -> float:
	return Gorge.TOP

## The air's summit: the west tor.
func summit() -> Vector3:
	return Vector3(Gorge.WEST_TOR[0].x,Gorge.plane_w(Gorge.WEST_TOR[0].x)+float(Gorge.WEST_TOR[1]),Gorge.WEST_TOR[0].y)

## The plants keep off the paths and the pool (Gorge `path_wear`); their
## rays reach the ledges and fragments far down the gorge; a sparser sowing
## for its larger land.
func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(Gorge.TOP,func(p: Vector2) -> float: return Gorge.path_wear(p))
	site.ray = load("res://studies/sundered_gorge_isle_life.gd").ray_span()
	site.tufts = 3.0
	return site

func flora_seed() -> int:
	return GORGE_SEED+4

func life_script() -> Script:
	return load("res://studies/sundered_gorge_isle_life.gd")

func pools() -> Array:
	return Gorge.pools()

func plane_tokens() -> Array:
	return load("res://studies/sundered_gorge_isle_sky.gd").GORGE_TOKENS

func warm() -> void:
	super.warm()
	Gorge.fragments()
	Gorge.platforms()
	Gorge.path_wear(Vector2.ZERO)

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	west_half = Gorge.west_half(GORGE_SEED)
	art.add_child(west_half)
	east_half = Gorge.east_half(GORGE_SEED+1)
	art.add_child(east_half)
	# The bridge: its two halves, the rope bridge between their anchors.
	west_bridge = Gorge.half_bridge(GORGE_SEED+20,Gorge.WEST_BREAK,0.55)
	west_bridge.name = "WestBridge"
	west_bridge.transform = Gorge.west_bridge_frame()
	art.add_child(west_bridge)
	east_bridge = Gorge.half_bridge(GORGE_SEED+24,Gorge.EAST_BREAK,0.6)
	east_bridge.name = "EastBridge"
	east_bridge.transform = Gorge.east_bridge_frame()
	art.add_child(east_bridge)
	rope = Gorge.rope_bridge(GORGE_SEED+22,rope_deck)
	art.add_child(rope)
	# The gatehouse: the gate arch over the road, the tower by the lip.
	gate = RuinKit.piece("arch",Gorge.GATE_SEED,0.5)
	gate.name = "Gate"
	gate.transform = Gorge.gate_frame()
	art.add_child(gate)
	var tower: Dictionary = Gorge.tower(GORGE_SEED+30)
	gate_tower = tower.node
	gate_tower.transform = Gorge.tower_frame()
	art.add_child(gate_tower)
	for part: Array in tower.parts: solid_box(part[0],part[1],part[2],Gorge.tower_frame())
	# The chapel on the east.
	for spec: Array in Gorge.CHAPEL:
		var piece: Node3D = RuinKit.piece(spec[0],spec[1],spec[2])
		var x: float = spec[3]
		var z: float = spec[4]
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(spec[5]))),Vector3(x,Gorge.ground_e(x,z),z))
		art.add_child(piece)
		chapel.append(piece)
	# The broken pier on the west tor.
	var pier: Node3D = RuinKit.piece("pier",61,0.7)
	pier.transform = Gorge.frame_w(Gorge.TOR_PIER.x,Gorge.TOR_PIER.y,float(Gorge.WEST_TOR[1]))
	art.add_child(pier)
	# The kit's flights down the west wall.
	for spec: Array in Gorge.FLIGHTS:
		var flight: Node3D = RuinKit.stairs(GORGE_SEED+35+flights.size(),0.35)
		flight.name = str(spec[0])
		flight.transform = Gorge.flight_frame(spec)
		art.add_child(flight)
		flights.append(flight)
	# The fragments in the gap, the fallen crown, the floating stones, the
	# chimney, boulders, the pool and its fall.
	fragments = Gorge.fragment_islets(GORGE_SEED+40)
	for f: Node3D in fragments: art.add_child(f)
	art.add_child(Gorge.fallen_crown(GORGE_SEED+50))
	art.add_child(Gorge.floating_stones(GORGE_SEED+51))
	var slabs: Dictionary = Gorge.chimney_slabs(GORGE_SEED+52)
	art.add_child(slabs.node)
	for part: Array in slabs.parts: solid_box(part[0],part[1],part[2])
	art.add_child(Gorge.boulders(GORGE_SEED+53))
	water = Gorge.water(GORGE_SEED+54)
	art.add_child(water)
	# The turf the grass grows on and the plane skims.
	for land: Node3D in [west_half,east_half]+fragments: turf(land)
	built_ms = Time.get_ticks_msec()-began
