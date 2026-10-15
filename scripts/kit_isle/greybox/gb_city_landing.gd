extends "res://scripts/kit_isle/motif_greybox.gd"
## The City Landing (docs/design/roguelike/layer-round14-city-layers.md):
## where every underground layer of the run begins, in place of the aqueduct
## isle. One basalt pillar-isle of the city kit (scripts/city_kit.gd
## `pillar`): a paved hex crown with a stepped dais in the middle, two
## collar courses down its flanks, lit crown cressets at its six corners
## (the only light on it, lit since ever: they draw no Olmec), and the
## makers' streets round the dais where he arrives. No head on it, no trap:
## the run's first breath. Six rims, one on each face, any of them a way
## out (the generator picks).
##
## Not drawn into a layer's pool (registry WORLD "base"): LayerPlan
## `_base_isle` stands it as the base of an underground layer, its crown's
## middle at LayerPlan MIDDLE. In the yard: `--motif=city_landing`.
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const CityFires = preload("res://scripts/city_kit_fires.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Underground = preload("res://scripts/underground/underground.gd")

const SEED := 9100
const COURSE := CityKit.COURSE
## The crown's apothem (m): five cells, 44 m flat to flat; its collar
## courses; the shaft's foot (m under the crown) into the haze.
const APOTHEM := 5.0*CityKit.CELL
const COURSES := 2
const FLOOR := -64.0
## A rim stands this far in from its face (on the paving, clear of the
## lip); its run-up back toward the dais.
const IN := 2.0
## The dais (CityKit `pillar` "paved"): its tiers' apothems as shares of
## the crown's, a set-off each.
const DAIS := [0.42,0.26]
## The crown cressets: this far in from a corner (m, CityKit's mounts).
const CORNER_IN := 3.0

func slug() -> String:
	return "city_landing"

func isle_name() -> String:
	return "The Landing"

func epithet() -> String:
	return "The makers kept these fires for whoever came up out of the deep. Someone still does."

func brief() -> String:
	return "The way up: the gate's light, high off past the city. Every fire you see is a way on."

func start() -> Vector3:
	return Vector3(0.0,0.0,APOTHEM-8.0)

func role() -> String:
	return "filler"

## Six rims, one a face, every one a way in or out.
func rims() -> Array:
	var out: Array = []
	var dais := APOTHEM*float(DAIS[0])
	for f in 6:
		var d := CityKit.hex_dir(f)
		out.append({"name":"face%d" % f,"at":d*(APOTHEM-IN),"face":d,"run_up":APOTHEM-IN-dais-1.0,"lip":IN,"way":""})
	return out

func spots() -> Array:
	var out: Array = []
	var r := (APOTHEM-CORNER_IN-4.0)/cos(PI/6.0)
	for f in 6:
		var c := (CityKit.hex_dir(f)+CityKit.hex_dir(f+1)).normalized()
		out.append({"kind":"perch","name":"corner%d" % f,"at":c*r,"room":3.0})
		var d := CityKit.hex_dir(f)
		out.append({"kind":"arena","name":"street%d" % f,"at":d*APOTHEM*0.62,"room":5.0})
	out.append({"kind":"perch","name":"dais","at":Vector3.UP*2.0*CityKit.SET_OFF,"room":3.0})
	return out

## The crown cressets' places (the pillar's own mounts).
static func corners() -> Array:
	var out: Array = []
	for f in 6:
		out.append((CityKit.hex_dir(f)+CityKit.hex_dir(f+1)).normalized()*(APOTHEM-CORNER_IN)/cos(PI/6.0))
	return out

## The occupancy's solids: the crown and each collar ring as hex strips
## down to the floor, the dais' tiers.
func parts() -> Array:
	var out: Array = []
	for k in range(COURSES,-1,-1):
		_hex_strips(out,APOTHEM+k*CityKit.LEDGE,FLOOR,-k*COURSE)
	for t in DAIS.size():
		_hex_strips(out,APOTHEM*float(DAIS[t]),0.0,(t+1)*CityKit.SET_OFF)
	return out

## A hex of apothem `a` (faces to +-z) as axis boxes in bands of a cell.
static func _hex_strips(out: Array, a: float, bottom: float, top: float) -> void:
	var band := CityKit.CELL
	var z := -a
	while z < a-0.01:
		var z1 := minf(z+band,a)
		var zm := maxf(absf(z),absf(z1))
		var hw := (a-0.5*zm)/cos(PI/6.0)
		if hw > 0.0: out.append(["box",Rect2(-hw,z,hw*2.0,z1-z),bottom,top,"grey"])
		z = z1

func life_script() -> Script:
	return null

func warm() -> void:
	CityStone.warm()
	for k: String in CityStone.WEAR: CityStone.wear(k)
	GiantStone.warm()
	_computed()

func build_cost() -> int:
	return 150

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "CityLanding"
	into.add_child(root)
	var p := CityKit.pillar(SEED+1,0.55,{"apothem":APOTHEM,"courses":COURSES,"climb":0,"crown":"paved","depth":-FLOOR})
	p.name = "Pillar"
	root.add_child(p)
	root.set_meta("triangles",int(p.get_meta("triangles",0)))
	built_ms = Time.get_ticks_msec()-began

## The crown cressets, lit since ever (the arrival's light; a lit one draws
## no one).
func live(g: Node) -> void:
	var fires := Node3D.new()
	fires.name = "Fires"
	g.add_child(fires)
	var k := 0
	for at: Vector3 in corners():
		CityFires.cresset(fires,Transform3D(Basis.IDENTITY,g.w(at)),{"size":"crown","seed":SEED+20+k,"name":"Lamp%d" % k,"lit":true,"draw":1.0,"barge":false})
		k += 1
