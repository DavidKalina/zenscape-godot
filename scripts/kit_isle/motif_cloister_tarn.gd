extends "res://scripts/kit_isle/kit_motif.gd"
## The cloister tarn as a motif (scripts/kit_isle/kit_motif.gd; docs/scenic/
## cloister-tarn.md): the crater-bowl mother isle round its still tarn, the
## four satellites, the ruined cloister, the crag's stair, the floating
## stones, the kit's pieces on the satellites, the rope bridges on their
## stone heads, the tarn's water (a surface the plane skims, on WATER_LAYER)
## and its curtain fall (studies/cloister_tarn_isle_art.gd). Built here for
## its study (studies/cloister_tarn_isle.gd) and for the aqueduct isle's sky
## alike.
const TarnArt = preload("res://studies/cloister_tarn_isle_art.gd")
const Cloister = preload("res://scripts/ruin_kit_cloister.gd")

const TARN_SEED := 41
const WEATHERED := 0.45
## The water's own layer: the plane skims it (as the turf), the pilot's
## rays never see it.
const WATER_LAYER := 1 << 12

var mother: Node3D
var cloister: Dictionary = {}
var bridges: Array = []
var water: MeshInstance3D
var fall_node: Node3D
var kit_stairs: Node3D

func id() -> String:
	return "cloister_tarn"

func isle_name() -> String:
	return "cloister tarn"

## Placeholder name and line until the isle is named; its finds are the
## ledger's (scripts/ledger/ledger.gd `card`).
func isle_card() -> Dictionary:
	return Ledger.shared().card(id(),{"name":"Cloister of the Still Tarn","epithet":"A mirror kept for no one"})

func top() -> float:
	return TarnArt.W

## The air's summit: the crag.
func summit() -> Vector3:
	var crag := TarnArt.world(TarnArt.way(126.0)*TarnArt.RIM/TarnArt.sq(TarnArt.way(126.0)))
	return Vector3(crag.x,TarnArt.K+TarnArt.CRAG_TOP,crag.y)

## The plants keep off the paths, the water and its edge (TarnArt `bare`),
## out of the water (TarnArt `wet`); their rays reach the tarn's bed.
func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(TarnArt.W,func(p: Vector2) -> float: return TarnArt.bare(p),func(p: Vector2) -> bool: return TarnArt.wet(p))
	site.ray = Vector2(TarnArt.W+60.0,TarnArt.W-12.0)
	return site

func flora_seed() -> int:
	return TARN_SEED+6

## Loaded when asked, not preloaded: the life's script holds the tarn's sky
## (`TarnSky`, a studies/aqueduct_isle_sky.gd), which places this motif.
func life_script() -> Script:
	return load("res://studies/cloister_tarn_isle_life.gd")

func pools() -> Array:
	return TarnArt.pools()

func plane_tokens() -> Array:
	return tarn_tokens()

func token_source() -> String:
	return "cloister"

func warm() -> void:
	super.warm()
	TarnArt.platforms()
	TarnArt.bare(Vector2.ZERO)
	TarnArt.path_wear(Vector2.ZERO)

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	mother = TarnArt.mother(TARN_SEED)
	art.add_child(mother)
	var isles: Array = TarnArt.satellites(TARN_SEED+20)
	for isle: Node3D in isles: art.add_child(isle)
	cloister = TarnArt.cloister(TARN_SEED+1,WEATHERED)
	art.add_child(cloister.node)
	kit_stairs = RuinKit.stairs(TARN_SEED+3,0.3)
	kit_stairs.name = "CragStair"
	kit_stairs.transform = TarnArt.stairs_frame()
	art.add_child(kit_stairs)
	art.add_child(TarnArt.floating_stones(TARN_SEED+4))
	_build_pieces()
	_build_bridges()
	_build_water()
	for land: Node3D in [mother]+isles: turf(land)
	built_ms = Time.get_ticks_msec()-began

## The kit's pieces on the satellites and the crag: a lancet window on the
## west isle framing the cloister through the saddle; a snapped pier and a
## carved chest on the south-west isle; a pointed arch on the north-east
## isle, a gateway in the sky; a fallen pier on the north isle by the
## lodestone's altar.
func _build_pieces() -> void:
	var place := func(piece_id: String, seed_value: int, weathered: float, spec_name: String, off: Vector2, yaw: float) -> void:
		var spec: Array = TarnArt.satellite(spec_name)
		var at: Vector2 = TarnArt.world(spec[1])+off
		var piece: Node3D = RuinKit.piece(piece_id,seed_value,weathered)
		piece.transform = Transform3D(Basis(Vector3.UP,yaw),Vector3(at.x,TarnArt.satellite_ground(spec,at.x,at.y),at.y))
		art.add_child(piece)
	place.call("lancet_wall",TARN_SEED+30,0.5,"west",Vector2(-1.2,0.0),PI*0.5)
	place.call("pier",TARN_SEED+31,0.75,"southwest",Vector2(0.8,-1.0),0.4)
	place.call("tomb_chest",TARN_SEED+32,0.5,"southwest",Vector2(-1.8,1.6),1.1)
	place.call("arch",TARN_SEED+33,0.45,"northeast",Vector2(0.6,-0.8),deg_to_rad(-47.0+90.0))
	place.call("fallen_pier",TARN_SEED+34,0.6,"north",Vector2(-1.6,-0.4),0.9)

## The rope bridges between the mother and the satellites: each the game's
## live rope bridge (scripts/footbridge.gd `build_mesh`, `live`: the
## spring sim) between two stone heads of the kit, its ends at the heads'
## fronts.
func _build_bridges() -> void:
	var k := 0
	for spec: Dictionary in TarnArt.bridges():
		for head: Array in spec.heads:
			var at: Vector3 = head[0]
			# The kit's anchor on a coursed head block the deck comes onto.
			var stone: Node3D = RuinKit.bridge_anchor(TARN_SEED+50+k,0.4,Footbridge.WIDTH,
				{"head":Vector3(Cloister.ABUTMENT.x,2.4,Cloister.ABUTMENT.z),"post_x":Cloister.ABUTMENT.x*0.5-0.3,"post_z":Cloister.ABUTMENT.z*0.5-0.3})
			stone.transform = Transform3D(Basis(Vector3.UP,float(head[1])),at)
			art.add_child(stone)
			k += 1
		var mesh: ArrayMesh = Footbridge.build_mesh(spec.a,spec.b,TARN_SEED+k)
		var bridge: MeshInstance3D = Footbridge.live(mesh,spec.a,spec.b,TARN_SEED+k)
		bridge.name = spec.name
		art.add_child(bridge)
		bridges.append(bridge)

## The tarn's water: the edit chunks' own still water (studies/
## cloister_tarn_isle_art.gd `water`, scripts/kit_isle/kit_water.gd),
## steeped to a dark slate-blue tarn, down the channel to the lip; a
## surface the plane skims (WATER_LAYER); the curtain fall off the lip.
## --old-water draws the islets' pond water on a coarse fan, as before.
func _build_water() -> void:
	var faces := TarnArt.water_faces()
	water = old_water(faces) if KitWater.old_water() else TarnArt.water()
	art.add_child(water)
	var body := StaticBody3D.new()
	body.name = "TarnSurface"
	body.collision_layer = WATER_LAYER
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	water.add_child(body)
	fall_node = TarnArt.fall(TARN_SEED+5)
	art.add_child(fall_node)

## The water as it was (--old-water): the disc and channel's faces flat in
## the islets' pond water.
static func old_water(faces: PackedVector3Array) -> MeshInstance3D:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for p in faces:
		v.append(p)
		n.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var sheet := MeshInstance3D.new()
	sheet.name = "Tarn"
	sheet.mesh = mesh
	sheet.material_override = tarn_material()
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sheet

## The old water's material (--old-water): the sky islets' pond water
## (shaders/islet_pond.gdshader: a dark slate-blue, the sky's pale blue at a
## glance, a slow ripple, a sharp glint). The plate's still material on that
## fan had read milky: the fan carries none of its data (depth, fetch, shore).
static var _tarn: Material
static func tarn_material() -> Material:
	if _tarn == null:
		var pond := ShaderMaterial.new()
		pond.shader = preload("res://shaders/islet_pond.gdshader")
		pond.set_shader_parameter("deep_color",Color(0.12,0.19,0.25))
		_tarn = pond
	return _tarn

## The plane's tokens: in over the west saddle, through the cloister's gap
## between the stubs, skimming the tarn, through the water gate, down the
## fall: [line id, category, kind, points (its frame)].
static func tarn_tokens() -> Array:
	var c := TarnArt.C
	var lip := TarnArt.lip()
	return [
		["ct:gap","air","thread",[Vector3(c.x-TarnArt.ARC-6.0,TarnArt.K+2.2,c.y),Vector3(c.x-TarnArt.ARC,TarnArt.K+1.4,c.y)]],
		["ct:skim","air","skim",[Vector3(c.x-5.0,TarnArt.W+1.0,c.y+1.5),Vector3(c.x+4.0,TarnArt.W+1.0,c.y+1.0)]],
		["ct:gate","air","thread",[Vector3(c.x+TarnArt.ARC,TarnArt.W+1.2,c.y)]],
		["ct:fall","air","dive",[Vector3(lip.x+3.0,TarnArt.W-5.0,lip.z),Vector3(lip.x+5.0,TarnArt.W-12.0,lip.z)]],
		["ct:keel","under","keel",[Vector3(c.x,TarnArt.W-TarnArt.KEEL-4.0,c.y)]],
	]
