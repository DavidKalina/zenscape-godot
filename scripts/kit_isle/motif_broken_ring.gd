extends "res://scripts/kit_isle/kit_motif.gd"
## The Broken Ring as a motif (scripts/kit_isle/kit_motif.gd; docs/scenic/
## broken-ring.md): a central isle with a standing stone circle (two stones
## missing) round a broken turret, and round it a loose spiral of eight small
## isles climbing 21 m, each with one small ruin note, tied by rope bridges
## and floating stones (studies/broken_ring_isle_art.gd). Built here for its
## study (studies/broken_ring_isle.gd) and for the aqueduct isle's sky alike.
const Ring = preload("res://studies/broken_ring_isle_art.gd")

const RING_SEED := 81
const CIRCLE_SEED := 82
const TURRET_SEED := 62
const BRIDGE_SEED := 130
const WEATHERED := 0.5

var central: Node3D
var circle: Node3D
var turret: Node3D
var isles: Array = []
var bridges: Array[MeshInstance3D] = []

func id() -> String:
	return "broken_ring"

func isle_name() -> String:
	return "broken ring"

func isle_card() -> Dictionary:
	return {"name":"The Broken Ring","epithet":"A circle, taken apart a stone at a time","finds":[["wildflower","Glyphs",0,7],["bridge","Hidden ways",0,3]]}

func top() -> float:
	return Ring.W

## The air's summit: the highest isle.
func summit() -> Vector3:
	var s: Dictionary = Ring.sat(Ring.SATS.size()-1)
	return Vector3(s.c.x,Ring.summit_y(),s.c.y)

func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(Ring.W,func(p: Vector2) -> float: return Ring.path_wear(p))
	site.ray = Vector2(Ring.summit_y()+60.0,Ring.W-8.0)
	return site

func flora_seed() -> int:
	return RING_SEED+6

func life_script() -> Script:
	return preload("res://studies/broken_ring_isle_life.gd")

func plane_tokens() -> Array:
	return Ring.plane_tokens()

func token_source() -> String:
	return "broken_ring"

## Its isles are small (6-13 m in radius): no run to land the plane on
## (tests/test_motif_sky.gd sets the pilot down on its turf instead).
func landing_run() -> bool:
	return false

func warm() -> void:
	super.warm()
	Ring.sats()
	Ring.platforms()
	Ring.path_wear(Vector2.ZERO)

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	central = Ring.central(RING_SEED)
	art.add_child(central)
	isles = Ring.satellites(RING_SEED+20)
	for isle: Node3D in isles: art.add_child(isle)
	circle = RuinKit.stone_circle(CIRCLE_SEED,WEATHERED,Ring.MISSING)
	circle.transform = Ring.circle_transform()
	art.add_child(circle)
	turret = RuinKit.turret(TURRET_SEED,0.45)
	turret.transform = Ring.turret_transform()
	art.add_child(turret)
	for note: Array in Ring.notes():
		var piece: Node3D = RuinKit.piece(note[0],note[1],note[2])
		piece.transform = note[3]
		art.add_child(piece)
	art.add_child(Ring.floating_stones(RING_SEED+4))
	_build_bridges()
	for land: Node3D in [central]+isles: turf(land)
	built_ms = Time.get_ticks_msec()-began

## The rope bridges: the footbridge's live rope bridge (its sag, bounce,
## sway and shudder) between the stone anchors at each end (the bell spires'
## own: a sill out of a coursed plinth).
func _build_bridges() -> void:
	var holder := Node3D.new()
	holder.name = "Bridges"
	art.add_child(holder)
	var k := 0
	for br: Dictionary in Ring.bridges():
		var a: Vector3 = br.a
		var b: Vector3 = br.b
		var seed_value := BRIDGE_SEED+k
		var live: MeshInstance3D = Footbridge.live(Footbridge.build_mesh(a,b,seed_value),a,b,seed_value)
		live.name = "Bridge_"+str(br.name)
		holder.add_child(live)
		bridges.append(live)
		for end: Array in [[a,b],[b,a]]:
			var anchor := RuinKit.bridge_anchor(seed_value*3+int(end[0] == b),0.45,Footbridge.WIDTH,
				{"post_x":Footbridge.WIDTH*0.5+0.33,"post_z":0.0,"sill":Vector3(0.75,0.11,0.55),"sill_at":Vector3(0.0,-0.11,0.15),
				"plinth":Vector3(1.15,1.4,0.375),"plinth_z":0.2})
			var way: Vector3 = (end[1] as Vector3)-(end[0] as Vector3)
			way.y = 0.0
			anchor.transform = Transform3D(Basis.looking_at(way.normalized(),Vector3.UP),end[0])
			holder.add_child(anchor)
		k += 1
