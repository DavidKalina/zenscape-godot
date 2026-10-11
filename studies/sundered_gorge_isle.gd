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

const GORGE_SEED := 23
## Fallen under this (world y) he is set back at the start: nothing stands
## under it but the keels' points.
const GORGE_LOST := 9.0

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
	return "sundered gorge"

## Placeholder name, line and finds until the isle is named.
func isle_card() -> Dictionary:
	return {"name":"The Sundered Gorge","epithet":"Split by a word no one remembers","finds":[["wildflower","Glyphs",1,6],["snow","Echoes",0,3],["bridge","Hidden ways",0,3]]}

func isle_top() -> float:
	return Gorge.TOP

## The air's summit: the west tor.
func isle_summit() -> Vector3:
	return Vector3(Gorge.WEST_TOR[0].x,Gorge.plane_w(Gorge.WEST_TOR[0].x)+float(Gorge.WEST_TOR[1]),Gorge.WEST_TOR[0].y)

## The plants keep off the paths and the pool (Gorge `path_wear`); their
## rays reach the ledges and fragments far down the gorge; a sparser sowing
## for its larger land.
func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(Gorge.TOP,func(p: Vector2) -> float: return Gorge.path_wear(p))
	site.ray = GorgeLife.ray_span()
	site.tufts = 3.0
	return site

func flora_seed() -> int:
	return GORGE_SEED+4

func sky_script() -> Script:
	return GorgeSky

func life_script() -> Script:
	return GorgeLife

func _build_room() -> void:
	ground.pools.append_array(Gorge.pools())
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
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
	for part: Array in tower.parts: _frame_box(Gorge.tower_frame(),part[0],part[1],part[2])
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
	for part: Array in slabs.parts: _part(["box",part[0],part[1],part[2],"lip"])
	art.add_child(Gorge.boulders(GORGE_SEED+53))
	water = Gorge.water(GORGE_SEED+54)
	art.add_child(water)
	# The turf the grass grows on and the plane skims.
	for land: Node3D in [west_half,east_half]+fragments: add_turf(land)
	print("sundered gorge: %d triangles" % triangles(art))

## A clean, invisible box in `frame` over `rect` (x, z) from `bottom` to
## `top` (as the station's boxes are: the stone over it drawn only).
func _frame_box(frame: Transform3D, rect: Rect2, bottom: float, top: float) -> void:
	var solid := StaticBody3D.new()
	solid.transform = frame*Transform3D(Basis.IDENTITY,Vector3(rect.get_center().x,(top+bottom)*0.5,rect.get_center().y))
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x,top-bottom,rect.size.y)
	collider.shape = box
	solid.add_child(collider)
	add_child(solid)

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
