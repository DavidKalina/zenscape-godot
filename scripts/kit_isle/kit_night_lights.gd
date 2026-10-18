extends Node3D
## A kit isle's lights after dark (night light round 1, docs/design/
## night-light/round1.md, round2.md): the ruins catching the moon, a few
## lanterns where people would have been, cool against warm.
##
## - The ruins' own light (round 2, docs/design/night-light/round2.md; the
##   round 1 rune carvings are gone): the ruins' stone (shaders/
##   ruin_stone.gdshader, ZS_NIGHT_STONE) catches and holds the moon, a
##   cool lift on the faces turned to it and on the tops, and takes a soft
##   warm bounce from every lantern within BOUNCE_REACH m (in the shader,
##   no light cast); a few broad, faint washes (WASHES, real OmniLights, no
##   shadows) lay soft pools of moonlit light over and round the
##   landmarks, so the stone and the turf about it read from the air.
## - Lanterns: the stone lamp (scripts/stone_lamp.gd's mesh, in the ruins'
##   own stone material, darkened to sit with it) at the spots the isle
##   gives (`setup`'s `spots`: by the parked plane, along the stairs and
##   paths, at the arch), each with the stone lamps' warm core and halo
##   (scripts/stone_lamp_lights.gd's look: its core bead, colour, glow and
##   shaders/stone_lamp_halo.gdshader). Only the MAX_LIGHTS nearest the eye
##   cast real light (OmniLight3D, no shadows), picked again every
##   PICK_SECONDS and eased over HANDOFF_SECONDS; the rest just glow.
##
## All of it comes up as the lamps do (StoneLampLights.night_for the sky's
## daylight, eased over FADE_SECONDS) and are gone by day.
## Flags: --no-night-lights (none of it), --no-ruin-light (the stone's
## catch, bounce and the washes), --no-lanterns.
const StoneLamp = preload("res://scripts/stone_lamp.gd")
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Flame = preload("res://scripts/flame.gd")
const WorldIslands = preload("res://scripts/world_islands.gd")
## How far a lantern's real flame draws (m); past it the halo is what is seen.
const FLAME_FAR := 60.0
const HALO_SHADER := preload("res://shaders/stone_lamp_halo.gdshader")

## The stone's night: how much of the moon it catches (on the ruins' stone
## material, shared by every kit isle's ruins), the lanterns' bounce on it
## (strength, reach m) and its colour.
const MOON_CATCH := 0.9
const BOUNCE := 1.6
const BOUNCE_REACH := 7.0
const BOUNCE_COLOUR := Color(1.0,0.66,0.38)
## The most lanterns the stone shader takes (its `night_lamps` array).
const MAX_BOUNCE_LAMPS := 16
## The washes: broad faint pools of cool light over the landmarks, each
## [the isle's spot (x, z, the height above the ground there, m), reach m,
## energy]; WASH_COLOUR their light.
const WASHES := [
	# The stone circle on its hill.
	[Vector3(61.0,7.0,0.0),18.0,0.8],
	# The aqueduct's arcade, over its middle.
	[Vector3(100.0,10.0,-24.0),20.0,0.8],
	# The gate on the far island.
	[Vector3(100.0,6.0,-62.5),14.0,0.7],
]
const WASH_COLOUR := Color(0.62,0.74,1.0)

## The lanterns: their scale (the stone lamp is about 1.05 m at 1), how much
## darker their stone than the lamp's own pale grey, their real lights
## (most, reach m, energy), and the halo (size m, strength).
const LAMP_SCALE := 1.0
const LAMP_STONE := Color(0.6,0.6,0.62)
const MAX_LIGHTS := 4
const LIGHT_RANGE := 7.5
const LIGHT_ENERGY := 1.4
const HALO_SIZE := 1.0
const HALO_STRENGTH := 0.5
const CORE_GLOW := 3.2
## The layer the lanterns' posts collide on (studies/kit_isle.gd PARKED_LAYER).
const WALKER_LAYER := 1 << 13

const FADE_SECONDS := StoneLampLights.FADE_SECONDS
const PICK_SECONDS := 0.25
const HANDOFF_SECONDS := 0.4

var scene: Node3D
## 0 by day .. 1 at night, eased.
var glow := 0.0
## For probes: >= 0 holds the daylight at this instead of the sky's.
var daylight_override := -1.0
## The lanterns: {"at" (the core's middle), "foot"}.
var lamps: Array[Dictionary] = []
## The washes' lights, as laid.
var washes: Array[OmniLight3D] = []
var _flames: Array[Node3D] = []
var _bodies: Array[StaticBody3D] = []
var lamp_mesh: MultiMeshInstance3D
var cores: MultiMeshInstance3D
var halos: MultiMeshInstance3D
var _stone: ShaderMaterial
var _core_material: StandardMaterial3D
var _halo_material: ShaderMaterial
var _slots: Array[Dictionary] = []
var _pick_in := 0.0
var _want_ruin_light := true
var _want_lamps := true
var _seed := 0
var _laid := false
var _wait_frames := 2

static func wanted(args: PackedStringArray) -> bool:
	return not args.has("--no-night-lights")

## `isle` the kit isle (its `art`, its `_celestial`); `spots` where the
## lanterns stand (world x, z as Vector2s, each put down on what is under
## it), or a Callable giving them when they are laid (the plane's parked
## spot is known only once the isle is up).
func setup(isle: Node3D, spots: Variant, seed_value := 1771) -> void:
	scene = isle
	name = "NightLights"
	_seed = seed_value
	var args := LaunchArgs.user_args()
	_want_ruin_light = not args.has("--no-ruin-light")
	_want_lamps = not args.has("--no-lanterns")
	if _want_ruin_light:
		_stone = RuinKit.materials().stone as ShaderMaterial
		_stone.set_shader_parameter("night_bounce_colour",BOUNCE_COLOUR)
		_stone.set_shader_parameter("night_bounce_reach",BOUNCE_REACH)
	_core_material = StandardMaterial3D.new()
	_core_material.albedo_color = StoneLampLights.PAPER
	_core_material.roughness = 0.9
	_core_material.emission_enabled = true
	_core_material.emission = StoneLampLights.LIGHT_COLOR
	_core_material.emission_energy_multiplier = 0.0
	_halo_material = ShaderMaterial.new()
	_halo_material.shader = HALO_SHADER
	_halo_material.set_shader_parameter("tint",StoneLampLights.LIGHT_COLOR)
	for i in range(MAX_LIGHTS):
		var light := OmniLight3D.new()
		light.name = "LanternLight%d" % i
		light.light_color = StoneLampLights.LIGHT_COLOR
		light.shadow_enabled = false
		light.light_specular = 0.2
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.4
		light.visible = false
		add_child(light)
		_slots.append({"light":light,"lamp":-1,"weight":0.0,"leaving":false})
	_spots = spots

var _spots: Variant = []

func _physics_process(_delta: float) -> void:
	if _laid: return
	# The isle's bodies are in the physics space a step after they are made.
	_wait_frames -= 1
	if _wait_frames > 0: return
	_laid = true
	var space := get_world_3d().direct_space_state
	if _want_lamps: _lay_lamps(space)
	if _want_ruin_light:
		_lay_washes(space)
		_tell_stone()
	print("night lights: %d lanterns, %d washes" % [lamps.size(),washes.size()])

# --- The ruins' own light ------------------------------------------------------

## The washes: a broad faint light over each landmark, its height taken
## from the ground under it.
func _lay_washes(space: PhysicsDirectSpaceState3D) -> void:
	var ray := PhysicsRayQueryParameters3D.new()
	for wash: Array in WASHES:
		var spot: Vector3 = wash[0]
		# Laid after an island moved (the layout file's): where it went.
		var xz := WorldIslands.carried(Vector2(spot.x,spot.z))
		ray.from = Vector3(xz.x,200.0,xz.y)
		ray.to = Vector3(xz.x,-60.0,xz.y)
		var hit := space.intersect_ray(ray)
		if hit.is_empty(): continue
		var light := OmniLight3D.new()
		light.name = "Wash%d" % washes.size()
		light.light_color = WASH_COLOUR
		light.shadow_enabled = false
		light.light_specular = 0.0
		light.omni_range = float(wash[1])
		light.omni_attenuation = 0.8
		light.set_meta("energy",float(wash[2]))
		light.visible = false
		light.top_level = true
		add_child(light)
		light.global_position = (hit.position as Vector3)+Vector3.UP*spot.y
		washes.append(light)

## The lanterns' places, for the stone's warm bounce.
func _tell_stone() -> void:
	var points := PackedVector4Array()
	for i in range(mini(lamps.size(),MAX_BOUNCE_LAMPS)):
		var at: Vector3 = lamps[i].at
		points.append(Vector4(at.x,at.y,at.z,1.0))
	while points.size() < MAX_BOUNCE_LAMPS: points.append(Vector4(0.0,-9999.0,0.0,0.0))
	_stone.set_shader_parameter("night_lamps",points)

# --- The lanterns ---------------------------------------------------------------

func _lay_lamps(space: PhysicsDirectSpaceState3D) -> void:
	var ray := PhysicsRayQueryParameters3D.new()
	var spots: Array = _spots.call() if _spots is Callable else _spots
	for spot in spots:
		# A Vector3 spot gives the ray's top too (under an overhang).
		var xz: Vector2 = spot if spot is Vector2 else Vector2((spot as Vector3).x,(spot as Vector3).z)
		var top := 200.0 if spot is Vector2 else (spot as Vector3).y
		# Laid after an island moved (the layout file's): where it went.
		var went := WorldIslands.carried3(Vector3(xz.x,top,xz.y))
		if spot is Vector2: went.y = top
		xz = Vector2(went.x,went.z)
		ray.from = Vector3(xz.x,went.y,xz.y)
		ray.to = Vector3(xz.x,-60.0,xz.y)
		var hit := space.intersect_ray(ray)
		if hit.is_empty(): continue
		var foot: Vector3 = hit.position
		lamps.append({"foot":foot,"at":foot+Vector3.UP*StoneLamp.GLOW_HEIGHT*LAMP_SCALE,"turn":fposmod(xz.x*0.37+xz.y*0.11,PI*0.5)})
	if lamps.is_empty(): return
	var stone: Material = (RuinKit.materials().stone as Material).duplicate()
	if stone is ShaderMaterial: (stone as ShaderMaterial).set_shader_parameter("albedo",LAMP_STONE)
	lamp_mesh = _batch("Lanterns",StoneLamp.mesh(),stone,lamps.size())
	lamp_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var bead := SphereMesh.new()
	bead.radius = StoneLamp.GLOW_RADIUS
	bead.height = StoneLamp.GLOW_RADIUS*2.4
	bead.radial_segments = 6
	bead.rings = 3
	cores = _batch("Cores",bead,_core_material,lamps.size())
	# The real flame stands in the fire box (scripts/flame.gd); the glowing
	# beads (cores) are no longer drawn, the halos carry the far read.
	cores.visible = false
	var flames_holder := Node3D.new()
	flames_holder.name = "Flames"
	flames_holder.top_level = true
	add_child(flames_holder)
	for lamp: Dictionary in lamps:
		_flames.append(Flame.in_lantern(flames_holder,(lamp.foot as Vector3)+Vector3.UP*StoneLamp.BOX_LOW*StoneLamp.UNIT*LAMP_SCALE,FLAME_FAR))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	halos = _batch("Halos",quad,_halo_material,lamps.size())
	halos.visible = false
	for i in range(lamps.size()):
		var lamp: Dictionary = lamps[i]
		var turn := Basis(Vector3.UP,float(lamp.turn))
		lamp_mesh.multimesh.set_instance_transform(i,Transform3D(turn.scaled(Vector3.ONE*LAMP_SCALE),lamp.foot))
		cores.multimesh.set_instance_transform(i,Transform3D(turn.scaled(Vector3.ONE*LAMP_SCALE),lamp.at))
		halos.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*HALO_SIZE*LAMP_SCALE),lamp.at))
		# Solid to the walker only (the parked plane's layer, kit_isle.gd
		# PARKED_LAYER): a post to walk round, which the plane, the ground
		# surveys and the growth never see.
		var body := StaticBody3D.new()
		body.collision_layer = WALKER_LAYER
		body.collision_mask = 0
		body.name = "LanternBody%d" % i
		var hull := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.36,0.95,0.36)*LAMP_SCALE*StoneLamp.UNIT
		hull.shape = box
		hull.position = Vector3.UP*box.size.y*0.5
		body.add_child(hull)
		body.top_level = true
		add_child(body)
		body.global_position = lamp.foot
		_bodies.append(body)

## What stands over `outline` (x, z; an island's, scripts/world_islands.gd
## `grab`) carried with it: a Callable(step: Transform3D, a world move)
## that moves its lanterns (their stone, flame, halo, post and light) and
## its washes, and tells the stone where its lanterns went.
func carrier(outline: PackedVector2Array) -> Callable:
	var over := func(p: Vector3) -> bool: return Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),outline)
	var ids: Array[int] = []
	for k in range(lamps.size()):
		if over.call(lamps[k].foot): ids.append(k)
	var lights: Array[OmniLight3D] = []
	for light in washes:
		if over.call(light.global_position): lights.append(light)
	return func(step: Transform3D) -> void:
		for k: int in ids:
			var lamp: Dictionary = lamps[k]
			lamp.foot = step*(lamp.foot as Vector3)
			lamp.at = step*(lamp.at as Vector3)
			var yaw := step.basis.get_euler().y
			lamp.turn = float(lamp.turn)+yaw
			if lamp_mesh != null: lamp_mesh.multimesh.set_instance_transform(k,step*lamp_mesh.multimesh.get_instance_transform(k))
			if cores != null: cores.multimesh.set_instance_transform(k,step*cores.multimesh.get_instance_transform(k))
			if halos != null:
				var h := halos.multimesh.get_instance_transform(k)
				halos.multimesh.set_instance_transform(k,Transform3D(h.basis,lamp.at))
			if k < _flames.size() and is_instance_valid(_flames[k]): _flames[k].global_transform = step*_flames[k].global_transform
			if k < _bodies.size(): _bodies[k].global_transform = step*_bodies[k].global_transform
			for slot in _slots:
				if int(slot.lamp) == k: (slot.light as OmniLight3D).global_position = lamp.at
		for light in lights: light.global_transform = step*light.global_transform
		if _stone != null and not ids.is_empty(): _tell_stone()

func _batch(label: String, mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = count
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	add_child(node)
	return node

# --- Each frame -----------------------------------------------------------------

func daylight() -> float:
	if daylight_override >= 0.0: return daylight_override
	var celestial: Variant = scene.get("_celestial") if scene != null else null
	if celestial != null and celestial.get("state") is Dictionary and celestial.state.has("zs_daylight"):
		return float(celestial.state.zs_daylight)
	return 1.0

func _process(delta: float) -> void:
	var goal := StoneLampLights.night_for(daylight())
	glow = goal if daylight_override >= 0.0 else move_toward(glow,goal,delta/FADE_SECONDS)
	if _stone != null:
		_stone.set_shader_parameter("night_catch",MOON_CATCH*glow)
		_stone.set_shader_parameter("night_bounce",BOUNCE*glow*glow)
	for light in washes:
		light.light_energy = float(light.get_meta("energy"))*glow
		light.visible = light.light_energy > 0.001
	_core_material.emission_energy_multiplier = CORE_GLOW*glow*glow
	for f in _flames: f.set("burn",glow)
	_halo_material.set_shader_parameter("glow",glow*HALO_STRENGTH)
	if halos != null: halos.visible = glow > 0.001
	_pick_in -= delta
	if _pick_in <= 0.0:
		_pick_in = PICK_SECONDS
		_pick()
	_shine(delta)

## The MAX_LIGHTS lanterns nearest the eye keep or get a light while it is
## dark; a light leaving fades out before it is handed on.
func _pick() -> void:
	if glow <= 0.0 or lamps.is_empty():
		for slot in _slots: slot.leaving = int(slot.lamp) >= 0
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var order := range(lamps.size())
	order.sort_custom(func(a: int, b: int) -> bool: return eye.distance_squared_to(lamps[a].at) < eye.distance_squared_to(lamps[b].at))
	var near := {}
	for k in range(mini(MAX_LIGHTS,order.size())): near[int(order[k])] = true
	var held := {}
	for slot in _slots:
		var id := int(slot.lamp)
		if id < 0: continue
		slot.leaving = not near.has(id)
		held[id] = true
	for id: int in near:
		if held.has(id): continue
		for slot in _slots:
			if int(slot.lamp) < 0:
				slot.lamp = id
				slot.weight = 0.0
				slot.leaving = false
				(slot.light as OmniLight3D).global_position = lamps[id].at
				break

func _shine(delta: float) -> void:
	for slot in _slots:
		var light: OmniLight3D = slot.light
		if int(slot.lamp) < 0:
			light.visible = false
			continue
		slot.weight = move_toward(float(slot.weight),0.0 if slot.leaving else 1.0,delta/HANDOFF_SECONDS)
		if slot.leaving and float(slot.weight) <= 0.0:
			slot.lamp = -1
			slot.leaving = false
			light.visible = false
			continue
		light.light_energy = LIGHT_ENERGY*glow*float(slot.weight)
		light.visible = light.light_energy > 0.001
