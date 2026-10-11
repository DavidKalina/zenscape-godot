extends "res://scripts/kit_isle/kit_motif.gd"
## The Hollow Keel as a motif (scripts/kit_isle/kit_motif.gd; docs/scenic/
## hollow-keel.md): the plate with its broken chapel and the shaft cut in its
## floor, the colossus hall hung under it (the undercroft the plane flies
## through), the three grand stairs switching back down the shaft, the crags
## hanging from the plate and the hull under the hall, the roots over the
## mouths, the porch with its rope bridge to the hanging islet
## (studies/hollow_keel_isle_art.gd). Built here for its study (studies/
## hollow_keel_isle.gd) and for the aqueduct isle's sky alike.
const Keel = preload("res://studies/hollow_keel_isle_art.gd")

const KEEL_SEED := Keel.SEED
## The grand stairs a little ruined.
const STAIR_WEATHERED := 0.3

var plate: Node3D
var hall: Node3D
var keel: Node3D
var islet: Node3D
var stairs: Array[Node3D] = []
var chapel: Array[Node3D] = []
var bridges: Array[MeshInstance3D] = []

func id() -> String:
	return "hollow_keel"

func isle_name() -> String:
	return "hollow keel"

## Placeholder name, line and finds until the isle is named.
func isle_card() -> Dictionary:
	return {"name":"The Hollow Keel","epithet":"Under the grass, a hall that was never told it flew","finds":[["wildflower","Glyphs",0,6],["snow","Echoes",0,3],["bridge","Hidden ways",0,1]]}

func top() -> float:
	return Keel.TOP

## The air's summit: the chapel's rose gable.
func summit() -> Vector3:
	return Vector3(Keel.HALL_X+33.7,Keel.TOP,Keel.MID.y+12.5)

## The plants keep off the worn way to the shaft.
func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(Keel.TOP,func(p: Vector2) -> float: return Keel.path_wear(p))

func flora_seed() -> int:
	return KEEL_SEED+3

func life_script() -> Script:
	return preload("res://studies/hollow_keel_isle_life.gd")

func plane_tokens() -> Array:
	return Keel.plane_tokens()

func token_source() -> String:
	return "hollow_keel"

func warm() -> void:
	super.warm()
	Keel.warm()
	Keel.plans()

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	plate = Keel.plate(KEEL_SEED)
	art.add_child(plate)
	keel = Keel.keel(KEEL_SEED+1)
	art.add_child(keel)
	hall = Keel.hall(Keel.HALL_SEED)
	hall.transform = Keel.hall_frame()
	art.add_child(hall)
	var roots := Keel.roots(KEEL_SEED+2)
	roots.transform = Keel.hall_frame()
	art.add_child(roots)
	for k in range(3):
		var s: Node3D = RuinKit.grand_stair(KEEL_SEED+10+k,STAIR_WEATHERED)
		s.name = "Stair%d" % k
		s.transform = Keel.stair_frame(k)
		art.add_child(s)
		stairs.append(s)
	art.add_child(Keel.turn_slab(KEEL_SEED+16))
	for spec: Array in Keel.CHAPEL:
		var piece: Node3D = RuinKit.piece(spec[0],spec[1],spec[2])
		var x: float = Keel.HALL_X+float(spec[3])
		var z: float = Keel.MID.y+float(spec[4])
		piece.name = str(spec[0])
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(spec[5]))),Vector3(x,Keel.ground(x,z),z))
		art.add_child(piece)
		chapel.append(piece)
	islet = Keel.islet(KEEL_SEED+20)
	art.add_child(islet)
	art.add_child(Keel.anchors(KEEL_SEED+30))
	var k := 0
	for ends: Array in Keel.bridge_ends():
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		var bridge: MeshInstance3D = Footbridge.live(Footbridge.build_mesh(a,b,KEEL_SEED+40+k),a,b,KEEL_SEED+40+k)
		bridge.name = "RopeBridge%d" % k
		art.add_child(bridge)
		bridges.append(bridge)
		k += 1
	# The turf the grass grows on and the plane skims: the plate and the islet.
	turf(plate)
	turf(islet)
	built_ms = Time.get_ticks_msec()-began
