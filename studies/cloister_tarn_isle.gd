extends "res://studies/kit_isle.gd"
## The cloister tarn: a hand-built sky-island motif, a kit isle (its look,
## light, air, presets, ground and rock, grass, life, sky, plane, rope
## bridges underfoot and lodestone are the kit isles' own: studies/
## kit_isle.gd, docs/scenic/kit-isle-shared.md; see docs/scenic/
## cloister-tarn.md).
##
## A crater-bowl mother isle rings a still tarn (studies/
## cloister_tarn_isle_art.gd): its rim rises to a tiered crag north-west and
## falls to a notch east, where the tarn spills under the cloister's water
## gate and off the edge as a wide curtain. Round the tarn stands a ruined
## cloister (scripts/ruin_kit_cloister.gd): four ranges of pointed arches on
## clustered piers carrying a wall-walk that runs round as a loop, its west
## range fallen in the middle (the cloister's gap: two snapped piers to hop,
## heaps at its ends to climb), a lavabo on a little isle in the tarn
## (stepping stones out to it), a slab bridge from the south terrace onto
## the walk. Round the mother, four satellite isles at different heights,
## tied to it by rope bridges on stone heads (scripts/rope_bridge.gd, the
## spring-sim bridges, walked as the game's walker walks them) and to each
## other by floating stones: a ring.
##
## The plane's line: in over the west saddle, through the cloister's gap
## (between the stubs on knife edge, or over them), skimming the tarn, out
## through the water gate and off over the fall.
##   R            back to the start (the cloister's south-east corner)
##   L / Shift+L  look presets · B gust · F (pad Y) the plane
##   F1 numbers · F2 feel · Esc mouse
##   ./run-cloister-tarn.command [--look=<preset id>]
## The kit isles' flags hold here: --no-flora, --no-life (and its
## parts), --no-sky (and its parts), --fly, --look=, --capture=, --at=,
## --place=, --no-lode, --carry, --stone-plane.
const TarnArt = preload("res://studies/cloister_tarn_isle_art.gd")
const TarnLife = preload("res://studies/cloister_tarn_isle_life.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Cloister = preload("res://scripts/ruin_kit_cloister.gd")

const TARN_SEED := 41
const WEATHERED := 0.45
## Where the walker starts: the cloister's south-east corner, looking along
## the south alley to the west.
const START_AT := Vector3(TarnArt.C.x+14.4,TarnArt.K,TarnArt.C.y+14.4)
const START_LOOK_AT := Vector2(-1.0,-0.35)
## The water's own layer: the plane skims it (as the turf), the pilot's
## rays never see it.
const WATER_LAYER := 1 << 12
## The lodestone rests on the north isle's altar stone.
const TARN_LODE := "north_altar"

var cloister: Dictionary = {}
var bridges: Array = []
var water: MeshInstance3D
var fall_node: Node3D

# --- Setting up -----------------------------------------------------------------------

## No pack here: the isle is built whole (`_build_room`).
func _load_pack() -> void:
	stations = []
	start = START_AT
	start_face = START_LOOK_AT.normalized()
	lost = TarnArt.W-45.0
	_last_stood = start
	_lode_at = TARN_LODE

func isle_name() -> String:
	return "cloister tarn"

## Placeholder name, line and finds until the isle is named.
func isle_card() -> Dictionary:
	return {"name":"Cloister of the Still Tarn","epithet":"A mirror kept for no one","finds":[["wildflower","Glyphs",3,5],["lamp","Lanterns",0,3],["bridge","Hidden ways",0,2]]}

func isle_top() -> float:
	return TarnArt.W

## The air's summit: the crag.
func isle_summit() -> Vector3:
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

func sky_script() -> Script:
	return TarnLife.TarnSky

func life_script() -> Script:
	return TarnLife

func capture_look() -> Vector3:
	return Vector3(TarnArt.C.x,TarnArt.K+2.0,TarnArt.C.y)

func _build_room() -> void:
	ground.pools.append_array(TarnArt.pools())
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var began := Time.get_ticks_msec()
	var mother := TarnArt.mother(TARN_SEED)
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
	_build_pieces(isles)
	_build_bridges()
	_build_water()
	for land: Node3D in [mother]+isles: add_turf(land)
	print("cloister tarn: %d triangles, built in %d ms (mother: %d ground points, %d cliff prisms)" % [triangles(art),Time.get_ticks_msec()-began,int(mother.get_meta("ground_points")),int(mother.get_meta("cliff_prisms"))])

## The kit's pieces on the satellites and the crag: a lancet window on the
## west isle framing the cloister through the saddle; a snapped pier and a
## carved chest on the south-west isle; a pointed arch on the north-east
## isle, a gateway in the sky; a fallen pier on the north isle by the
## lodestone's altar.
func _build_pieces(isles: Array) -> void:
	var place := func(id: String, seed_value: int, weathered: float, spec_name: String, off: Vector2, yaw: float) -> void:
		var spec: Array = TarnArt.satellite(spec_name)
		var at: Vector2 = TarnArt.world(spec[1])+off
		var piece: Node3D = RuinKit.piece(id,seed_value,weathered)
		piece.transform = Transform3D(Basis(Vector3.UP,yaw),Vector3(at.x,TarnArt.satellite_ground(spec,at.x,at.y),at.y))
		art.add_child(piece)
	place.call("lancet_wall",TARN_SEED+30,0.5,"west",Vector2(-1.2,0.0),PI*0.5)
	place.call("pier",TARN_SEED+31,0.75,"southwest",Vector2(0.8,-1.0),0.4)
	place.call("tomb_chest",TARN_SEED+32,0.5,"southwest",Vector2(-1.8,1.6),1.1)
	place.call("arch",TARN_SEED+33,0.45,"northeast",Vector2(0.6,-0.8),deg_to_rad(-47.0+90.0))
	place.call("fallen_pier",TARN_SEED+34,0.6,"north",Vector2(-1.6,-0.4),0.9)

## The rope bridges between the mother and the satellites: each the game's
## live rope bridge (scripts/footbridge.gd `build_mesh`, `live`: the
## spring sim) between two stone heads of the kit (scripts/
## ruin_kit_cloister.gd `abutment`), its ends at the heads' fronts.
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

## The tarn's water: the game's sky pond water (SkyIslets' pond material,
## the plate's still water steeped dark, a slate-blue tarn), a surface the
## plane skims (WATER_LAYER), the curtain fall off the lip.
func _build_water() -> void:
	var faces := TarnArt.water_faces()
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
	water = MeshInstance3D.new()
	water.name = "Tarn"
	water.mesh = mesh
	water.material_override = tarn_material()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

## The tarn's water: the sky islets' pond water (shaders/islet_pond.gdshader,
## as the islets' and the aqueduct's channel have it: a dark, glassy
## slate-blue tarn, the sky's pale blue at a glance, a slow ripple, a sharp
## glint; tinted by the look presets' water colour). The plate's still
## water was tried: off the plate its maps are missing and it read milky.
static var _tarn: Material
static func tarn_material() -> Material:
	if _tarn == null:
		var pond := ShaderMaterial.new()
		pond.shader = preload("res://shaders/islet_pond.gdshader")
		pond.set_shader_parameter("deep_color",Color(0.12,0.19,0.25))
		_tarn = pond
	return _tarn

## The lodestone on the north isle's altar.
func lode_rest_at() -> Vector3:
	var p: Dictionary = TarnArt.platform(_lode_at)
	if p.is_empty(): p = TarnArt.platform(TARN_LODE)
	return (p.at as Vector3)+Vector3.UP*LODE_HOVER

func lode_hint() -> String:
	return "A lodestone hums on the north isle: up the crag and out over the floating stones"

## The water is skimmed as the turf is.
func plane_ground(p: Vector3) -> Variant:
	if _ground_ray == null:
		_ground_ray = PhysicsRayQueryParameters3D.new()
		_ground_ray.collision_mask = TURF_LAYER|WATER_LAYER
	_ground_ray.from = p+Vector3.UP
	_ground_ray.to = p+Vector3.DOWN*60.0
	var hit := get_world_3d().direct_space_state.intersect_ray(_ground_ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.3: return null
	return float((hit.position as Vector3).y)

## Set down on dry turf, never in the tarn.
func _turf_top(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Vector3:
	var top := super._turf_top(space,x,z)
	if top != Vector3.INF and top.y < TarnArt.W+0.2: return Vector3.INF
	return top
