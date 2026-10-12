extends "res://scripts/kit_isle/kit_motif.gd"
## The drowned nave as a motif (scripts/kit_isle/kit_motif.gd; docs/scenic/
## drowned-nave.md): a larger isle with a wide shallow basin of still water
## over most of its top and a long gothic nave half drowned in it, a rocky
## apse at its far end with the rose gable, a causeway of fallen stones
## down the nave, the spill and its curtain fall (studies/
## drowned_nave_isle_art.gd). Built here for its study (studies/
## drowned_nave_isle.gd) and for the aqueduct isle's sky alike.
const NaveArt = preload("res://studies/drowned_nave_isle_art.gd")

const NAVE_SEED := 53
const WEATHERED := 0.6
## The water's own layer (the same the cloister tarn's is): the plane skims
## it as the turf, the pilot's rays never see it.
const WATER_LAYER := 1 << 12

var isle_node: Node3D
var nave: Dictionary = {}
var apse: Dictionary = {}
var water: MeshInstance3D
var fall_node: Node3D

func id() -> String:
	return "drowned_nave"

func isle_name() -> String:
	return "drowned nave"

func isle_card() -> Dictionary:
	return {"name":"The Drowned Nave","epithet":"Where the roof went, the sky came in","finds":[["wildflower","Glyphs",3,5],["lamp","Lanterns",0,3],["bridge","Hidden ways",0,2]]}

func top() -> float:
	return NaveArt.W

## The air's summit: the rose gable's peak.
func summit() -> Vector3:
	var g := NaveArt.world(Vector2(NaveArt.GABLE_X,0.0))
	return Vector3(g.x,NaveArt.plateau_top()+RuinKit.GABLE.z,g.y)

## The plants keep off the paths and the water (and its edge); their rays
## reach the basin's bed.
func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(NaveArt.W,func(p: Vector2) -> float: return NaveArt.bare(p),func(p: Vector2) -> bool: return NaveArt.wet(p))
	site.ray = Vector2(NaveArt.W+60.0,NaveArt.W-12.0)
	return site

func flora_seed() -> int:
	return NAVE_SEED+6

func life_script() -> Script:
	return load("res://studies/drowned_nave_isle_life.gd")

func pools() -> Array:
	return NaveArt.pools()

func plane_tokens() -> Array:
	return nave_tokens()

func token_source() -> String:
	return "nave"

func warm() -> void:
	super.warm()
	NaveArt.platforms()
	NaveArt.paths()
	NaveArt.lip()
	NaveArt.bare(Vector2.ZERO)

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	isle_node = NaveArt.isle(NAVE_SEED)
	art.add_child(isle_node)
	nave = NaveArt.nave(NAVE_SEED+1,WEATHERED)
	art.add_child(nave.node)
	apse = NaveArt.apse(NAVE_SEED+10,WEATHERED)
	art.add_child(apse.node)
	art.add_child(NaveArt.shore(NAVE_SEED+20))
	art.add_child(NaveArt.stones(NAVE_SEED+40))
	_build_water()
	turf(isle_node)
	built_ms = Time.get_ticks_msec()-began

## The basin's water: the edit chunks' own still water (kit_water.gd),
## down the channel to the lip; a surface the plane skims (WATER_LAYER); the
## curtain fall off the lip.
func _build_water() -> void:
	var faces := NaveArt.water_faces()
	water = NaveArt.water()
	art.add_child(water)
	var body := StaticBody3D.new()
	body.name = "NaveSurface"
	body.collision_layer = WATER_LAYER
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	water.add_child(body)
	fall_node = NaveArt.fall(NAVE_SEED+5)
	art.add_child(fall_node)

## The plane's tokens: in over the beach, skimming the nave's axis, out
## through the south row's gap at the crossing, back across and out through
## the north row's great arch facing it, up through the broken vault, down
## the fall.
static func nave_tokens() -> Array:
	var c := NaveArt.C
	var w := NaveArt.W
	var lip := NaveArt.lip()
	var row := NaveArt.ROW_Z
	return [
		["dn:skim","air","skim",[Vector3(c.x-30.0,w+1.1,c.y),Vector3(c.x-22.0,w+1.1,c.y),Vector3(c.x-14.0,w+1.1,c.y),Vector3(c.x-6.0,w+1.1,c.y)]],
		["dn:gap","air","thread",[Vector3(c.x+NaveArt.cross_mid(),w+1.5,c.y+row)]],
		["dn:bay","air","thread",[Vector3(c.x+NaveArt.cross_mid(),w+1.8,c.y-row)]],
		["dn:vault","air","thread",[Vector3(c.x+18.0,w+2.6,c.y),Vector3(c.x+25.0,w+6.8,c.y)]],
		["dn:fall","air","dive",[Vector3(lip.x,w-5.0,lip.z-3.0),Vector3(lip.x,w-12.0,lip.z-5.0)]],
		["dn:keel","under","keel",[Vector3(c.x,w-NaveArt.KEEL-4.0,c.y)]],
	]
