extends Node3D
## Where a layer begins (docs/design/roguelike/stakes-experiment.md): a
## small arrival spot on the base's turf at the layer's spawn, built from
## the ruin kit. A worn stone landing (RuinKit `floor_slabs`) under the
## pilot's feet; behind him the two broken piers of an arch long fallen
## (RuinKit `pier`, weathered), the way he came in (through the gate, on
## layers after the first), the camera looking out between them; a stone
## lantern lit at the landing's front corner, the warm thing to start from.
##
## He faces along the route: toward its first crossing on the main line
## (scripts/roguelike/way_lights.gd `main_line`), turned toward the next
## neighbourhood's highest point as far as both stay in the first frame
## (`face_for`). The spawn's place is the plan's (scripts/roguelike/
## layer_sprawl.gd chose it to see the next region); only the way he faces
## and the stones round him are this file's.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const StoneLamp = preload("res://scripts/stone_lamp.gd")
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")
const WayLights = preload("res://scripts/roguelike/way_lights.gd")
const Flame = preload("res://scripts/flame.gd")
## How far the real flame draws before the bead stands in (m).
const FLAME_FAR := 28.0
const HALO_SHADER := preload("res://shaders/stone_lamp_halo.gdshader")

## The ground's rays: the ruins and the turf (studies/kit_isle.gd).
const GROUND_MASK := 1 | (1 << 11)
## The landing: the kit's floor (RuinKit FLOOR, 4.2 m) at these scales,
## the first whose corners lie within FLAT of each other; its middle this
## far behind his feet (m).
const LANDING_SCALES := [1.0,0.75,0.55]
const FLAT := 0.4
const LANDING_BACK := 0.6
## The piers: to each side and behind (m, his frame), how far off his
## ground theirs may stand (m), and their weathering.
const PIER_AT := Vector2(2.8,2.8)
const PIER_LEVEL := 1.0
const PIER_WORN := 0.65
## The lantern: at the landing's front corner (m), scaled, its light.
const LAMP_AT := Vector2(1.9,-1.3)
const LAMP_SCALE := 1.35
const LAMP_RANGE := 9.0
const LAMP_ENERGY := 1.6
const DAY_GLOW := 0.5
## The first frame: the widest the first crossing and the next cluster may
## stand apart (degrees) and still both be faced; past it, the crossing
## held this far off his straight ahead toward the cluster.
const BOTH_MOST := 100.0
const LEAN_OFF := 45.0

var study: Node3D
## Where he stands (on the landing) and faces (flat, unit).
var start := Vector3.ZERO
var face := Vector3.FORWARD
## What was built: "landing", "pier_l", "pier_r", "lamp".
var parts: Array[String] = []
var _core: StandardMaterial3D
var _halo: ShaderMaterial
var _light: OmniLight3D
var _flame: Node3D

func _init() -> void:
	name = "StartSpot"

## The way to face from `at`: the first crossing's start (`first`), turned
## toward `cluster` (the next neighbourhood's top) as far as both stay in
## view; `fallback` with neither.
static func face_for(at: Vector3, first: Vector3, cluster: Vector3, fallback: Vector3) -> Vector3:
	var c := Vector2(first.x-at.x,first.z-at.z)
	var n := Vector2(cluster.x-at.x,cluster.z-at.z)
	if c.length() < 0.5 and n.length() < 0.5: return fallback
	if c.length() < 0.5: c = n
	if n.length() < 0.5: n = c
	c = c.normalized()
	n = n.normalized()
	var apart := c.angle_to(n)
	var turn := apart*0.5 if absf(rad_to_deg(apart)) <= BOTH_MOST else signf(apart)*deg_to_rad(LEAN_OFF)
	var way := c.rotated(turn)
	return Vector3(way.x,0.0,way.y).normalized()

## Built at `layer`'s spawn on `scene`'s base; `start` and `face` set.
## In the tree (its rays need the world) before it is called.
func setup(scene: Node3D, layer: Dictionary) -> void:
	study = scene
	var spawn: Vector3 = layer.spawn.at
	var line: Array = WayLights.main_line(layer)
	var tops: Array[Vector3] = WayLights.cluster_tops(layer)
	var first: Vector3 = (layer.edges[line[0]].a as Vector3) if not line.is_empty() else spawn
	var cluster: Vector3 = tops[0] if not tops.is_empty() else (layer.exit.get("at",spawn) as Vector3)
	face = face_for(spawn,first,cluster,layer.spawn.face)
	var frame := Basis.looking_at(face,Vector3.UP)
	var space := get_world_3d().direct_space_state
	var ground := _ground(space,spawn,1.5)
	if ground == INF: ground = spawn.y-0.2
	start = Vector3(spawn.x,ground,spawn.z)
	# A city layer's base is the landing itself (its paving and its lit
	# fires): none of the ruin kit's stones round him (layer-round14-city-
	# layers.md).
	if preload("res://scripts/roguelike/layer_worlds.gd").city(layer.get("knobs",{})):
		start.y += 0.05
		return
	# The landing: the biggest that lies flat enough.
	for scale: float in LANDING_SCALES:
		var half := RuinKit.FLOOR.x*0.5*scale
		var mid := spawn+frame*Vector3(0.0,0.0,LANDING_BACK)
		var lows := []
		for k in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1),Vector2.ZERO]:
			lows.append(_ground(space,mid+frame*Vector3(k.x*half*0.9,0.0,k.y*half*0.9),1.5))
		if lows.has(INF): continue
		var low: float = lows.min()
		if float(lows.max())-low > FLAT: continue
		var slab := RuinKit.floor_slabs(int(absf(spawn.x*13.0+spawn.z*7.0))%9973+11,0.55)
		slab.name = "Landing"
		add_child(slab)
		# Bedded a little into the turf at its lowest corner.
		slab.global_transform = Transform3D(frame.scaled(Vector3.ONE*scale),Vector3(mid.x,low-0.04,mid.z))
		start.y = maxf(start.y,low-0.04+RuinKit.FLOOR.z*scale)
		parts.append("landing")
		break
	start.y += 0.05
	# The fallen arch's piers, behind and to each side.
	for side: float in [-1.0,1.0]:
		var at := spawn+frame*Vector3(side*PIER_AT.x,0.0,PIER_AT.y)
		var y := _ground(space,at,PIER_LEVEL+1.0)
		if y == INF or absf(y-ground) > PIER_LEVEL: continue
		if _crowded(space,Vector3(at.x,y,at.z)): continue
		var pier := RuinKit.pier(int(absf(at.x*7.0+at.z*3.0))%9973+int(side > 0.0),PIER_WORN)
		pier.name = "Pier%s" % ("R" if side > 0.0 else "L")
		add_child(pier)
		pier.global_transform = Transform3D(frame,Vector3(at.x,y-0.1,at.z))
		parts.append("pier_r" if side > 0.0 else "pier_l")
	_lamp(space,spawn,frame,ground)

## The ground's height under `at` within `reach` of it (m), INF for none.
func _ground(space: PhysicsDirectSpaceState3D, at: Vector3, reach: float) -> float:
	var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*reach,at+Vector3.DOWN*reach,GROUND_MASK)
	var hit := space.intersect_ray(ray)
	return INF if hit.is_empty() else (hit.position as Vector3).y

## Whether a pier at `foot` would stand in something already there.
func _crowded(space: PhysicsDirectSpaceState3D, foot: Vector3) -> bool:
	var box := BoxShape3D.new()
	box.size = Vector3(1.6,2.6,1.6)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.collision_mask = GROUND_MASK
	q.transform = Transform3D(Basis.IDENTITY,foot+Vector3.UP*(0.5+box.size.y*0.5))
	return not space.intersect_shape(q,1).is_empty()

## The lit lantern at the landing's front corner: drawn only (nothing to
## bump; it stands off his way out).
func _lamp(space: PhysicsDirectSpaceState3D, spawn: Vector3, frame: Basis, ground: float) -> void:
	var at := spawn+frame*Vector3(LAMP_AT.x,0.0,LAMP_AT.y)
	var y := _ground(space,at,1.5)
	if y == INF or absf(y-ground) > 1.0: y = ground
	var holder := Node3D.new()
	holder.name = "Lantern"
	add_child(holder)
	holder.global_transform = Transform3D(frame.scaled(Vector3.ONE*LAMP_SCALE),Vector3(at.x,maxf(y,start.y-0.05),at.z))
	var stone: Material = (RuinKit.materials().stone as Material).duplicate()
	if stone is ShaderMaterial: (stone as ShaderMaterial).set_shader_parameter("albedo",WayLights.LAMP_STONE)
	var body := MeshInstance3D.new()
	body.mesh = StoneLamp.mesh()
	body.material_override = stone
	holder.add_child(body)
	_core = StandardMaterial3D.new()
	_core.albedo_color = StoneLampLights.PAPER
	_core.emission_enabled = true
	_core.emission = StoneLampLights.LIGHT_COLOR
	_flame = Flame.in_lantern(holder,Vector3.UP*StoneLamp.BOX_LOW*StoneLamp.UNIT,FLAME_FAR)
	var bead := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = StoneLamp.GLOW_RADIUS
	sphere.height = StoneLamp.GLOW_RADIUS*2.4
	bead.mesh = sphere
	bead.material_override = _core
	bead.position = Vector3.UP*StoneLamp.GLOW_HEIGHT
	bead.visibility_range_begin = FLAME_FAR
	bead.visibility_range_begin_margin = FLAME_FAR*0.1
	holder.add_child(bead)
	_halo = ShaderMaterial.new()
	_halo.shader = HALO_SHADER
	_halo.set_shader_parameter("tint",StoneLampLights.LIGHT_COLOR)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*1.6
	halo.mesh = quad
	halo.material_override = _halo
	halo.position = Vector3.UP*StoneLamp.GLOW_HEIGHT
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(halo)
	_light = OmniLight3D.new()
	_light.light_color = StoneLampLights.LIGHT_COLOR
	_light.omni_range = LAMP_RANGE
	_light.omni_attenuation = 1.3
	_light.shadow_enabled = true
	_light.position = Vector3.UP*(StoneLamp.GLOW_HEIGHT+0.25)
	holder.add_child(_light)
	parts.append("lamp")

func _process(_delta: float) -> void:
	if _core == null: return
	var light := 1.0
	var celestial: Variant = study.get("_celestial") if study != null else null
	if celestial != null and celestial.get("state") is Dictionary and celestial.state.has("zs_daylight"): light = float(celestial.state.zs_daylight)
	var glow := maxf(DAY_GLOW,StoneLampLights.night_for(light))
	_core.emission_energy_multiplier = StoneLampLights.CORE_GLOW*glow
	_halo.set_shader_parameter("glow",glow*0.6)
	_light.light_energy = LAMP_ENERGY*glow
	if _flame != null: _flame.set("burn",0.55+0.45*glow)
