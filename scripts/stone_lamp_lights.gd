extends Node3D
## The stone lamps' light (docs/scenic/stone-lamps.md). The lamps themselves
## are records on the land (asset "stone_lamp", drawn by GardenView from
## scripts/stone_lamp.gd); this follows them and lights them at night.
##
## Three layers, cheapest first:
## - a small faceted core in every fire box, one MultiMesh, one shared
##   material: by day a pale paper panel, at night glowing warm (emission);
## - a soft halo round every core, one MultiMesh of camera-facing quads added
##   to what is behind them, faded right out by day;
## - real light (OmniLight3D, no shadows) for at most MAX_LIGHTS lamps, the
##   ones nearest the camera, picked again every PICK_SECONDS. A light handed
##   to another lamp fades out and in again over HANDOFF_SECONDS, so moving
##   the camera along a row never pops.
##
## Night is read from the sky (studies/celestial.gd's published zs_daylight,
## the world clock's daylight when there is no rig): the lamps come up as the
## sun goes down (daylight NIGHT_FROM..NIGHT_TO) and go out at dawn, eased
## over FADE_SECONDS so a skip through the day still fades. Made and owned by
## NativeChunkEditor (`lamps`), so every native world has them.
##
## The pool is shared: other warm things set on the land (the campfires,
## scripts/campfire_fire.gd; the cabins' windows, scripts/cabin_lights.gd)
## join it as `guests`, each owner its own list (`set_guests`), and the nearest MAX_LIGHTS
## of lamps and guests together get the lights. Guests bring their own reach,
## colour and strength (`guest_energy`, which may flicker), and are picked by
## day too while their energy is above nothing.

const Lamp = preload("res://scripts/stone_lamp.gd")
const ASSET := "stone_lamp"
## Real lights, at most; the rest glow but cast nothing.
const MAX_LIGHTS := 8
## Their reach (m on the plate at lamp scale 1), strength and colour.
const LIGHT_RANGE := 3.4
const LIGHT_ENERGY := 1.6
const LIGHT_COLOR := Color("ffb36b")
## Daylight (0..1) at which the lamps start to glow and are fully lit.
const NIGHT_FROM := 0.55
const NIGHT_TO := 0.12
## Seconds for the glow to follow the sky, and for a light to change lamps.
const FADE_SECONDS := 2.5
const HANDOFF_SECONDS := 0.4
## Seconds between picking the nearest lamps, and between re-reading the
## records (ground moves under them without the records changing).
const PICK_SECONDS := 0.25
const READ_SECONDS := 0.5
## The core: paper by day, ember at night (emission energy at full night).
const PAPER := Color("e9d3a8")
const CORE_GLOW := 3.2
## The halo's width (m at lamp scale 1) and strength.
const HALO_SIZE := 1.1
const HALO_STRENGTH := 0.55

var editor: Node
## 0..1, how lit the lamps are now (eased), and what the sky asks for.
var glow := 0.0
var wanted := 0.0
## For probes: >= 0 holds the daylight read at this instead of the sky's.
var daylight_override := -1.0
## The lamps as last read: {"id", "at" (global, the core's middle), "scale"}.
var lamps: Array[Dictionary] = []
## The light slots: {"light", "id" (-1 free), "weight" 0..1, "leaving"}.
var slots: Array[Dictionary] = []
## Guests sharing the lights: {"id", "at" (global), "range", "color"}, set
## by their owner (`set_guests`); `guest_energy.call(id)` is a guest's light
## energy now, 0 for none.
var guests: Array[Dictionary] = []
var guest_energy := Callable()
## Each owner's guests and energy ({"list", "energy"}), and each guest's owner.
var _guest_lists := {}
var _guest_owner := {}
var cores: MultiMeshInstance3D
var halos: MultiMeshInstance3D
var _core_material: StandardMaterial3D
var _halo_material: ShaderMaterial
var _revision := -1
var _count := -1
var _read_in := 0.0
var _pick_in := 0.0
var _scale := 1.0

func setup(owner_editor: Node) -> void:
	editor = owner_editor
	name = "StoneLamps"
	_core_material = StandardMaterial3D.new()
	_core_material.albedo_color = PAPER
	_core_material.roughness = 0.9
	_core_material.emission_enabled = true
	_core_material.emission = LIGHT_COLOR
	_core_material.emission_energy_multiplier = 0.0
	cores = _batch("Cores",_core_mesh(),_core_material)
	_halo_material = ShaderMaterial.new()
	_halo_material.shader = preload("res://shaders/stone_lamp_halo.gdshader")
	_halo_material.set_shader_parameter("tint",LIGHT_COLOR)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	halos = _batch("Halos",quad,_halo_material)
	halos.visible = false
	for i in range(MAX_LIGHTS):
		var light := OmniLight3D.new()
		light.name = "LampLight%d" % i
		light.light_color = LIGHT_COLOR
		light.shadow_enabled = false
		light.light_specular = 0.2
		light.omni_attenuation = 1.6
		light.visible = false
		add_child(light)
		slots.append({"light":light,"id":-1,"weight":0.0,"leaving":false,"guest":false})

func _batch(label: String, mesh: Mesh, material: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	add_child(node)
	return node

## A faceted bead for the core, like the hand's stones (7 sides, 4 rings).
static func _core_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = Lamp.GLOW_RADIUS
	mesh.height = Lamp.GLOW_RADIUS*2.4
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh

## The daylight the lamps answer to, 0 (night) .. 1 (day).
func daylight() -> float:
	if daylight_override >= 0.0: return daylight_override
	var scene: Variant = editor.get("scene") if editor != null else null
	if scene == null: return 1.0
	var celestial: Variant = scene.get("_celestial")
	if celestial != null and celestial.get("state") is Dictionary and celestial.state.has("zs_daylight"):
		return float(celestial.state.zs_daylight)
	var clock: Variant = scene.get("world_clock")
	return float(clock.daylight) if clock != null else 1.0

## How lit the lamps want to be at `light` daylight.
static func night_for(light: float) -> float:
	return 1.0-smoothstep(NIGHT_TO,NIGHT_FROM,light)

## The lamps that have a real light now, and how strong (for probes).
func lit() -> Dictionary:
	var out := {}
	for slot in slots:
		var light: OmniLight3D = slot.light
		if int(slot.id) >= 0 and light.visible and light.light_energy > 0.0: out[int(slot.id)] = light.light_energy
	return out

func _process(delta: float) -> void:
	if editor == null or editor.get("data") == null: return
	var data: NativeTerrainData = editor.data
	_read_in -= delta
	if data.objects_revision != _revision or data.objects.size() != _count or _read_in <= 0.0: _read(data)
	wanted = night_for(daylight())
	glow = move_toward(glow,wanted,delta/FADE_SECONDS)
	_core_material.emission_energy_multiplier = CORE_GLOW*glow*glow
	_halo_material.set_shader_parameter("glow",glow*HALO_STRENGTH)
	halos.visible = glow > 0.001 and not lamps.is_empty()
	_pick_in -= delta
	if _pick_in <= 0.0:
		_pick_in = PICK_SECONDS
		_pick()
	_shine(delta)

## Reads the lamp records into world points, and lays the cores and halos.
func _read(data: NativeTerrainData) -> void:
	_revision = data.objects_revision
	_count = data.objects.size()
	_read_in = READ_SECONDS
	var terrain: Node3D = editor.terrain
	_scale = terrain.global_basis.get_scale().x
	var found: Array[Dictionary] = []
	for item: Dictionary in data.objects:
		if str(item.asset) != ASSET: continue
		var size := float(item.scale)
		var foot: Vector3 = data.object_position(item)
		var at := terrain.to_global(foot+Vector3.UP*Lamp.GLOW_HEIGHT*size)
		found.append({"id":int(item.id),"at":at,"scale":size*_scale,"angle":float(item.angle)})
	lamps = found
	_lay()

## The guests of `owner` now (see `guests`), and how strong each one's light
## is (`energy.call(id)`; without one, `guest_energy`). Each owner (the
## campfires, the cabins) keeps its own list; a light whose guest is gone
## lets go.
func set_guests(list: Array[Dictionary], owner := "", energy := Callable()) -> void:
	_guest_lists[owner] = {"list":list,"energy":energy}
	var all: Array[Dictionary] = []
	_guest_owner.clear()
	for key in _guest_lists:
		for guest: Dictionary in _guest_lists[key].list:
			all.append(guest)
			_guest_owner[int(guest.id)] = key
	guests = all
	_release_missing()

## A guest's energy now.
func _guest_energy(id: int) -> float:
	var owner: Variant = _guest_owner.get(id)
	var energy: Callable = _guest_lists[owner].energy if owner != null else Callable()
	if not energy.is_valid(): energy = guest_energy
	return float(energy.call(id)) if energy.is_valid() else 0.0

## Lays the cores and halos on the lamps as read, and lets go of lights whose
## lamp has gone.
func _lay() -> void:
	cores.multimesh.instance_count = lamps.size()
	halos.multimesh.instance_count = lamps.size()
	for i in range(lamps.size()):
		var lamp: Dictionary = lamps[i]
		var s: float = lamp.scale
		cores.multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,float(lamp.angle)).scaled(Vector3.ONE*s),lamp.at))
		halos.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*s*HALO_SIZE),lamp.at))
	_release_missing()

## Every light source now, by id: the lamps and the guests.
func _sources() -> Dictionary:
	var ids := {}
	for lamp in lamps: ids[int(lamp.id)] = lamp
	for guest in guests: ids[int(guest.id)] = guest
	return ids

## A light whose lamp or guest is gone lets go at once; the rest follow theirs.
func _release_missing() -> void:
	var ids := _sources()
	for slot in slots:
		if int(slot.id) >= 0 and not ids.has(int(slot.id)):
			slot.id = -1
			slot.weight = 0.0
			slot.leaving = false
			(slot.light as OmniLight3D).visible = false
		elif int(slot.id) >= 0:
			_place(slot,ids[int(slot.id)])

## The nearest MAX_LIGHTS lamps to the camera keep or get a light; a light on
## a lamp no longer among them fades out before it is handed on.
func _pick() -> void:
	# What may shine: the lamps while it is dark, guests while they burn.
	var shining: Array[Dictionary] = []
	if glow > 0.0: shining.append_array(lamps)
	for guest in guests:
		if _guest_energy(int(guest.id)) > 0.0: shining.append(guest)
	if shining.is_empty():
		for slot in slots: slot.leaving = int(slot.id) >= 0
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var order := range(shining.size())
	order.sort_custom(func(a: int, b: int) -> bool: return eye.distance_squared_to(shining[a].at) < eye.distance_squared_to(shining[b].at))
	var near := {}
	for k in range(mini(MAX_LIGHTS,order.size())): near[int(shining[order[k]].id)] = order[k]
	var held := {}
	for slot in slots:
		var id := int(slot.id)
		if id < 0: continue
		slot.leaving = not near.has(id)
		held[id] = true
	for id: int in near:
		if held.has(id): continue
		for slot in slots:
			if int(slot.id) < 0:
				slot.id = id
				slot.weight = 0.0
				slot.leaving = false
				_place(slot,shining[near[id]])
				break

## Puts `slot`'s light on `source`, a lamp or a guest.
func _place(slot: Dictionary, source: Dictionary) -> void:
	var light: OmniLight3D = slot.light
	slot.guest = source.has("range")
	light.global_position = source.at
	light.omni_range = float(source.range) if slot.guest else LIGHT_RANGE*float(source.scale)
	light.light_color = source.get("color",LIGHT_COLOR)

## Each light eases toward its weight times the night's glow.
func _shine(delta: float) -> void:
	for slot in slots:
		var light: OmniLight3D = slot.light
		if int(slot.id) < 0:
			light.visible = false
			continue
		slot.weight = move_toward(float(slot.weight),0.0 if slot.leaving else 1.0,delta/HANDOFF_SECONDS)
		if slot.leaving and float(slot.weight) <= 0.0:
			slot.id = -1
			slot.leaving = false
			light.visible = false
			continue
		var energy: float = _guest_energy(int(slot.id)) if slot.guest else LIGHT_ENERGY*glow
		light.light_energy = energy*float(slot.weight)
		light.visible = light.light_energy > 0.001
