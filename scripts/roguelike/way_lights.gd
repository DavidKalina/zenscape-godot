extends Node3D
## The way on, lit in the world (docs/design/roguelike/stakes-experiment.md):
## no marks on the screen, only lanterns where a soul would have set them.
##
## - A stone lantern (scripts/stone_lamp.gd's mesh, its warm core and halo,
##   as the kit isles' night lanterns: scripts/kit_isle/kit_night_lights.gd)
##   beside the start of every crossing on the main line, the one from the
##   base to the exit chain (`main_line`): stones, bridges, the climbs, the
##   voussoirs, the gulf's ride (both its piers, near and far) and the
##   chain's first crossing; and over a gulf's near pier a light hung high
##   (the base's hill can hide the pier itself from its start). The side
##   crossings and the greed branch are
##   left dark, so a lit rim is the way on and an unlit one a wander.
## - Each further neighbourhood's highest point catches a light: a broad
##   faint halo and a warm light over it (`cluster_tops`), seen from the
##   cluster before.
## - The gate's own beam (scripts/roguelike/layer_stage.gd) marks the end.
##
## Lit by day too, softly (DAY_GLOW), fuller after dark. A lantern stands
## on what is under its spot; the motif isles stand a slice a frame, so a
## lantern waits (hidden) until the ground under it is there.
const Flame = preload("res://scripts/flame.gd")
## How far the real flame draws before the bead stands in (m).
const FLAME_FAR := 28.0
const StoneLamp = preload("res://scripts/stone_lamp.gd")
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
const HALO_SHADER := preload("res://shaders/stone_lamp_halo.gdshader")

## How lit by day (0..1 of the night's glow) and at night.
const DAY_GLOW := 0.45
## A lantern: beside its rim (m to the side, m back from the lip), how far
## off the rim's height its ground may stand (m), its scale, its light
## (reach m, energy) and halo (size m).
const SIDE := 1.5
const BACK := 0.9
const LEVEL := 1.2
const LAMP_SCALE := 1.1
const LIGHT_RANGE := 6.5
const LIGHT_ENERGY := 1.3
const HALO_SIZE := 1.2
## A cluster's top: how far over it the light hangs (m), its halo (m), its
## light's reach (m) and energy.
const TOP_OVER := 2.5
const TOP_HALO := 7.0
const TOP_RANGE := 26.0
const TOP_ENERGY := 2.2
## Over a gulf's near pier: how high (m), its halo (m), its reach (m).
const PIER_OVER := 9.0
const PIER_HALO := 3.5
const PIER_RANGE := 14.0
## The stone darkened to sit with the ruins (the night lanterns').
const LAMP_STONE := Color(0.6,0.6,0.62)
## The rays' layers: the ruins and the turf (studies/kit_isle.gd TURF_LAYER).
const GROUND_MASK := 1 | (1 << 11)

var study: Node3D
var plan: Dictionary
## The lanterns: {rim (Vector3), tries ([Vector3] spots, the first found
## wins), foot (Vector3 or INF while unfound), edge (index)}.
var lamps: Array[Dictionary] = []
## The cluster tops lit; the lights hung (cluster tops, gulf piers).
var tops: Array[Vector3] = []
var hung: Array[OmniLight3D] = []
var glow := DAY_GLOW
var _stone: Material
var _core: StandardMaterial3D
var _halo: ShaderMaterial
var _top_halo: ShaderMaterial
var _lamp_nodes: Array[Node3D] = []
var _settled_frames := 0

func _init() -> void:
	name = "WayLights"

## The crossings from the base to the exit, in order (edge indices): the
## route back from the chain's first isle (or the exit's) to the base,
## then the chain's first crossing.
static func main_line(layer: Dictionary) -> Array:
	var edges: Array = layer.edges
	var chain: Array = layer.get("chain",[])
	var target: int = int(edges[chain[0]].from[0]) if not chain.is_empty() else int(layer.exit.get("isle",-1))
	var line: Array = []
	var guard := 0
	while target > 0 and guard < 64:
		guard += 1
		var found := -1
		for i in range(edges.size()):
			var e: Dictionary = edges[i]
			if e.branch == "route" and int(e.to[0]) == target:
				found = i
				break
		if found < 0: break
		line.push_front(found)
		target = int(edges[found].from[0])
	if not chain.is_empty(): line.append(chain[0])
	return line

## Each neighbourhood past the first: its highest point (over its route
## isles', the greed isle's left out).
static func cluster_tops(layer: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var hoods: Array = layer.hoods
	for h in range(1,hoods.size()):
		var best := Vector3(0.0,-INF,0.0)
		for i: int in hoods[h]:
			var isle: Dictionary = layer.isles[i]
			if isle.role == "greed" or not isle.has("occ"): continue
			var top := LayerSprawl._top_of(isle)
			if top.y > best.y: best = top
		if best.y > -INF: out.append(best)
	return out

func setup(scene: Node3D, layer: Dictionary) -> void:
	study = scene
	plan = layer
	_materials()
	for i: int in main_line(layer):
		var e: Dictionary = layer.edges[i]
		if e.has("from_rim") and int(e.from[0]) >= 0: _want(e.from_rim,i)
		# A gulf's far pier too: lit from across, it says where the ride goes;
		# and a light hung high over its near one, seen over the base's hill.
		if e.kind == "gulf" and e.has("to_rim"):
			_want(e.to_rim,i)
			_hang((e.from_rim.at as Vector3)+Vector3.UP*PIER_OVER,PIER_HALO,PIER_RANGE,"PierLight")
	for top in cluster_tops(layer):
		_hang(top+Vector3.UP*TOP_OVER,TOP_HALO,TOP_RANGE,"ClusterTop")
		tops.append(top)
	_resolve()

func _materials() -> void:
	_stone = (RuinKit.materials().stone as Material).duplicate()
	if _stone is ShaderMaterial: (_stone as ShaderMaterial).set_shader_parameter("albedo",LAMP_STONE)
	_core = StandardMaterial3D.new()
	_core.albedo_color = StoneLampLights.PAPER
	_core.roughness = 0.9
	_core.emission_enabled = true
	_core.emission = StoneLampLights.LIGHT_COLOR
	_halo = ShaderMaterial.new()
	_halo.shader = HALO_SHADER
	_halo.set_shader_parameter("tint",StoneLampLights.LIGHT_COLOR)
	_top_halo = ShaderMaterial.new()
	_top_halo.shader = HALO_SHADER
	_top_halo.set_shader_parameter("tint",Color(1.0,0.86,0.62))

## A lantern beside `rim` (a plan rim: at, face): to one side of the way
## out, a little back from the lip; else the other side; else straight back.
func _want(rim: Dictionary, edge: int) -> void:
	var at: Vector3 = rim.at
	var face: Vector3 = rim.face
	face.y = 0.0
	if face.length() < 0.01: return
	face = face.normalized()
	var side := face.cross(Vector3.UP)
	var back := at-face*BACK
	lamps.append({"rim":at,"face":face,"tries":[back+side*SIDE,back-side*SIDE,at-face*(BACK+SIDE)],"foot":Vector3.INF,"edge":edge})

## A light hung in the air at `at`: a broad faint halo, a warm light.
func _hang(at: Vector3, size: float, reach: float, label: String) -> void:
	var holder := Node3D.new()
	holder.name = "%s%d" % [label,hung.size()]
	holder.position = at
	add_child(holder)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*size
	halo.mesh = quad
	halo.material_override = _top_halo
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0,0.86,0.62)
	light.omni_range = reach
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.light_specular = 0.1
	holder.add_child(light)
	hung.append(light)

## The lanterns whose ground is there now set on it.
func _resolve() -> void:
	if not is_inside_tree(): return
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = GROUND_MASK
	for lamp: Dictionary in lamps:
		if lamp.foot != Vector3.INF: continue
		for spot: Vector3 in lamp.tries:
			ray.from = spot+Vector3.UP*3.0
			ray.to = spot+Vector3.DOWN*3.0
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or absf((hit.position as Vector3).y-(lamp.rim as Vector3).y) > LEVEL: continue
			lamp.foot = hit.position
			_stand(lamp)
			break

func _stand(lamp: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "WayLamp%d" % _lamp_nodes.size()
	var foot: Vector3 = lamp.foot
	# Turned square to the way out.
	holder.transform = Transform3D(Basis.looking_at(lamp.face,Vector3.UP).scaled(Vector3.ONE*LAMP_SCALE),foot)
	add_child(holder)
	var body := MeshInstance3D.new()
	body.mesh = StoneLamp.mesh()
	body.material_override = _stone
	holder.add_child(body)
	# The real flame in the fire box (child 1); past FLAME_FAR the old glowing
	# bead (added after the light, so child 3 stays the light) stands in.
	Flame.in_lantern(holder,Vector3.UP*StoneLamp.BOX_LOW*StoneLamp.UNIT,FLAME_FAR)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*HALO_SIZE
	halo.mesh = quad
	halo.material_override = _halo
	halo.position = Vector3.UP*StoneLamp.GLOW_HEIGHT
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = StoneLampLights.LIGHT_COLOR
	light.omni_range = LIGHT_RANGE
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.light_specular = 0.2
	light.position = Vector3.UP*(StoneLamp.GLOW_HEIGHT+0.2)
	holder.add_child(light)
	var bead := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = StoneLamp.GLOW_RADIUS
	sphere.height = StoneLamp.GLOW_RADIUS*2.4
	sphere.radial_segments = 6
	sphere.rings = 3
	bead.mesh = sphere
	bead.material_override = _core
	bead.position = Vector3.UP*StoneLamp.GLOW_HEIGHT
	bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bead.visibility_range_begin = FLAME_FAR
	bead.visibility_range_begin_margin = FLAME_FAR*0.1
	holder.add_child(bead)
	lamp.node = holder
	_lamp_nodes.append(holder)

## How many lanterns stand (found their ground).
func standing() -> int:
	return _lamp_nodes.size()

func daylight() -> float:
	var celestial: Variant = study.get("_celestial") if study != null else null
	if celestial != null and celestial.get("state") is Dictionary and celestial.state.has("zs_daylight"):
		return float(celestial.state.zs_daylight)
	return 1.0

func _physics_process(_delta: float) -> void:
	if _lamp_nodes.size() == lamps.size(): return
	# Until the sky's isles all stand (and a step after, their bodies in
	# the space) a missing ground may just not be there yet.
	var sky: Variant = study.get("sky") if study != null else null
	var stood: bool = sky == null or sky.motifs == null or sky.motifs.all_stood()
	_resolve()
	if stood:
		_settled_frames += 1
		if _settled_frames > 3:
			for lamp: Dictionary in lamps:
				if lamp.foot == Vector3.INF: lamp.foot = Vector3(INF,0.0,0.0)
			set_physics_process(false)

func _process(_delta: float) -> void:
	glow = maxf(DAY_GLOW,StoneLampLights.night_for(daylight()))
	_core.emission_energy_multiplier = StoneLampLights.CORE_GLOW*glow*glow
	_halo.set_shader_parameter("glow",glow*0.55)
	_top_halo.set_shader_parameter("glow",glow*0.35)
	for holder in _lamp_nodes:
		var light := holder.get_child(3) as OmniLight3D
		light.light_energy = LIGHT_ENERGY*glow
		(holder.get_child(1) as Flame).burn = 0.55+0.45*glow
	for light in hung: light.light_energy = TOP_ENERGY*glow
