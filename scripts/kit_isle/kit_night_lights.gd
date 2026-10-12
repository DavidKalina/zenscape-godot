extends Node3D
## A kit isle's lights after dark (night light round 1, docs/design/
## night-light/round1.md): the ruins' runes and a few lanterns where people
## would have been, cool against warm.
##
## - Runes: a few carvings cut into the ruins' stones (some stones, never
##   every face), in the rune serpent's glyphs (shaders/rune_glyphs.
##   gdshaderinc, drawn by shaders/ruin_runes.gdshader), glowing faintly
##   cool at night, each breathing slowly on its own beat. They are laid
##   once, on the stones' own faces: a stone (one of the kit's block hulls,
##   its "Body" collision) is picked by a seeded hash, RUNE_SHARE of them
##   (more on the landmarks: LANDMARK_SHARE by name), at least RUNE_APART m
##   from another, at most MAX_RUNES; a ray cast in at it from outside finds
##   an upright face of that very block (a face hidden behind another block
##   is never hit), and a quad of one to three glyphs lies a hair off it.
##   One MultiMesh, no light cast.
## - Lanterns: the stone lamp (scripts/stone_lamp.gd's mesh, in the ruins'
##   own stone material, darkened to sit with it) at the spots the isle
##   gives (`setup`'s `spots`: by the parked plane, along the stairs and
##   paths, at the arch), each with the stone lamps' warm core and halo
##   (scripts/stone_lamp_lights.gd's look: its core bead, colour, glow and
##   shaders/stone_lamp_halo.gdshader). Only the MAX_LIGHTS nearest the eye
##   cast real light (OmniLight3D, no shadows), picked again every
##   PICK_SECONDS and eased over HANDOFF_SECONDS; the rest just glow.
##
## Both come up as the lamps do (StoneLampLights.night_for the sky's
## daylight, eased over FADE_SECONDS) and are gone by day.
## Flags: --no-night-lights (none of it), --no-runes, --no-lanterns.
const StoneLamp = preload("res://scripts/stone_lamp.gd")
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const RUNE_SHADER := preload("res://shaders/ruin_runes.gdshader")
const HALO_SHADER := preload("res://shaders/stone_lamp_halo.gdshader")

## The runes: their colour (a pale cool blue-teal, against the lanterns'
## warm), strength, the share of stones carved, more on the landmarks
## (by the piece's name), the least gap between two carvings (m), and the
## most of them.
const RUNE_COLOUR := Color(0.52,0.82,1.0)
const RUNE_ENERGY := 1.2
const RUNE_SHARE := 0.05
const LANDMARK_SHARE := {"circle":0.4,"heel":1.0,"arch":0.3,"castellum":0.12}
## Pieces never carved (by name): the land's own rock, the crag walls and
## the loose floating stones are not masonry.
const UNCARVED := ["island","islet","hillwalls","floating"]
const RUNE_APART := 3.5
const MAX_RUNES := 48
## A carving's glyph height (m) as a share of the stone's least size, and
## its least and most; how far off the face it lies (m).
const RUNE_HEIGHT := 0.3
const RUNE_HEIGHT_RANGE := Vector2(0.28,0.75)
const RUNE_LIFT := 0.025
## Stones smaller than this (m, their largest size) are passed over, and
## hulls larger than this are not stones.
const STONE_SIZE := Vector2(0.9,14.0)
## A face counts as upright under this much of up in its normal.
const UPRIGHT := 0.4

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
## The carvings laid: {"at", "normal", "size", "piece"}; the lanterns:
## {"at" (the core's middle), "foot"}.
var runes: Array[Dictionary] = []
var lamps: Array[Dictionary] = []
var rune_mesh: MultiMeshInstance3D
var lamp_mesh: MultiMeshInstance3D
var cores: MultiMeshInstance3D
var halos: MultiMeshInstance3D
var _rune_material: ShaderMaterial
var _core_material: StandardMaterial3D
var _halo_material: ShaderMaterial
var _slots: Array[Dictionary] = []
var _pick_in := 0.0
var _want_runes := true
var _want_lamps := true
var _rune_root: Node3D
var _seed := 0
var _laid := false
var _wait_frames := 2

static func wanted(args: PackedStringArray) -> bool:
	return not args.has("--no-night-lights")

## `isle` the kit isle (its `art`, its `_celestial`); `spots` where the
## lanterns stand (world x, z as Vector2s, each put down on what is under
## it), or a Callable giving them when they are laid (the plane's parked
## spot is known only once the isle is up);
## `rune_root` the ruins to carve (the isle's art).
func setup(isle: Node3D, spots: Variant, rune_root: Node3D, seed_value := 1771) -> void:
	scene = isle
	name = "NightLights"
	_seed = seed_value
	_rune_root = rune_root
	var args := LaunchArgs.user_args()
	_want_runes = not args.has("--no-runes")
	_want_lamps = not args.has("--no-lanterns")
	_rune_material = ShaderMaterial.new()
	_rune_material.shader = RUNE_SHADER
	_rune_material.set_shader_parameter("colour",RUNE_COLOUR)
	_rune_material.set_shader_parameter("energy",RUNE_ENERGY)
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
	if _want_runes and _rune_root != null: _lay_runes(space)

# --- The runes ------------------------------------------------------------------

func _lay_runes(space: PhysicsDirectSpaceState3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var bodies := _rune_root.find_children("*","StaticBody3D",true,false)
	var found: Array[Dictionary] = []
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collide_with_areas = false
	for b in bodies:
		var body := b as StaticBody3D
		var share := _share_for(body)
		for holder in body.get_children():
			if found.size() >= MAX_RUNES: break
			var shape_node := holder as CollisionShape3D
			if shape_node == null or not shape_node.shape is ConvexPolygonShape3D: continue
			# The dice are thrown for every stone, so the picks hold as the
			# stones before them are kept or not.
			var roll := rng.randf()
			var turn := rng.randf()*TAU
			var glyphs := 1+int(rng.randf()*2.99)
			var phase := rng.randf()
			if roll > share: continue
			var points: PackedVector3Array = (shape_node.shape as ConvexPolygonShape3D).points
			if points.size() < 4: continue
			var xf := shape_node.global_transform
			var box := AABB(xf*points[0],Vector3.ZERO)
			for p in points: box = box.expand(xf*p)
			var big := maxf(box.size.x,maxf(box.size.y,box.size.z))
			if big < STONE_SIZE.x or big > STONE_SIZE.y: continue
			var middle := box.get_center()
			var spot := _face(space,ray,body,shape_node,middle,box,turn)
			if spot.is_empty(): continue
			var clear := true
			for other in found:
				if (other.at as Vector3).distance_to(spot.at) < RUNE_APART:
					clear = false
					break
			if not clear: continue
			var least := minf(box.size.y,maxf(box.size.x,box.size.z))
			var height := clampf(least*RUNE_HEIGHT,RUNE_HEIGHT_RANGE.x,RUNE_HEIGHT_RANGE.y)
			spot["size"] = Vector2(height*0.62*glyphs,height)
			spot["glyphs"] = glyphs
			spot["phase"] = phase
			spot["seed"] = rng.randf()*97.0
			spot["piece"] = _piece_name(body)
			found.append(spot)
	runes = found
	_draw_runes()
	var by_piece := {}
	for r in runes: by_piece[r.piece] = int(by_piece.get(r.piece,0))+1
	print("night lights: %d runes on the ruins (%s), %d lanterns" % [runes.size(),by_piece,lamps.size()])

## How likely a stone of `body`'s piece is to be carved.
func _share_for(body: Node) -> float:
	var named := _piece_name(body).to_lower()
	for key: String in UNCARVED:
		if named.contains(key): return 0.0
	for key: String in LANDMARK_SHARE:
		if named.contains(key): return float(LANDMARK_SHARE[key])
	return RUNE_SHARE

## The piece a body belongs to: the nearest named ancestor under the root.
func _piece_name(body: Node) -> String:
	var node := body.get_parent()
	while node != null and node.get_parent() != _rune_root and node != _rune_root:
		node = node.get_parent()
	return str(node.name) if node != null else ""

## An upright face of the block `shape` (of `body`): rays in at its middle
## from four sides (starting at `turn`), the first that hits that very
## block on a face that stands. {"at", "normal"} or {}.
func _face(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D, body: StaticBody3D, shape: CollisionShape3D, middle: Vector3, box: AABB, turn: float) -> Dictionary:
	var reach := box.size.length()*0.5+1.5
	for k in range(4):
		var a := turn+k*PI*0.5
		var dir := Vector3(cos(a),0.0,sin(a))
		ray.from = middle+dir*reach
		ray.to = middle
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.collider != body: continue
		var owner_id: int = body.shape_find_owner(int(hit.shape))
		if body.shape_owner_get_owner(owner_id) != shape: continue
		var normal: Vector3 = hit.normal
		if absf(normal.y) > UPRIGHT: continue
		return {"at":hit.position,"normal":normal}
	return {}

func _draw_runes() -> void:
	if runes.is_empty(): return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad
	multi.instance_count = runes.size()
	for i in range(runes.size()):
		var r: Dictionary = runes[i]
		var normal: Vector3 = r.normal
		var side := Vector3.UP.cross(normal).normalized()
		var up := normal.cross(side).normalized()
		var size: Vector2 = r.size
		var basis := Basis(side*size.x,up*size.y,normal)
		multi.set_instance_transform(i,Transform3D(basis,(r.at as Vector3)+normal*RUNE_LIFT))
		multi.set_instance_custom_data(i,Color(float(r.seed),float(r.glyphs),float(r.phase),1.0))
	rune_mesh = MultiMeshInstance3D.new()
	rune_mesh.name = "Runes"
	rune_mesh.multimesh = multi
	rune_mesh.material_override = _rune_material
	rune_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rune_mesh.top_level = true
	rune_mesh.visible = false
	add_child(rune_mesh)

# --- The lanterns ---------------------------------------------------------------

func _lay_lamps(space: PhysicsDirectSpaceState3D) -> void:
	var ray := PhysicsRayQueryParameters3D.new()
	var spots: Array = _spots.call() if _spots is Callable else _spots
	for spot in spots:
		# A Vector3 spot gives the ray's top too (under an overhang).
		var xz: Vector2 = spot if spot is Vector2 else Vector2((spot as Vector3).x,(spot as Vector3).z)
		ray.from = Vector3(xz.x,200.0 if spot is Vector2 else (spot as Vector3).y,xz.y)
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
	_rune_material.set_shader_parameter("night",glow)
	if rune_mesh != null: rune_mesh.visible = glow > 0.001
	_core_material.emission_energy_multiplier = CORE_GLOW*glow*glow
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
