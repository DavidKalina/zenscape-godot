extends Node3D
## The cabins' warm windows and chimney smoke (docs/scenic/cabin.md). The
## cabins themselves are records on the land (asset "cabin", drawn by
## GardenView from scripts/cabin.gd); this follows them. Soft things only:
##
## - **Windows**: a warm pane over each cabin's window glass, every cabin in
##   one MultiMesh on one emissive material, lit from dusk (the stone lamps'
##   eased `glow`, the same sky) and dark by day, when the baked glass shows.
## - **Light**: each window joins the stone lamps' pool of real lights as a
##   guest (scripts/stone_lamp_lights.gd `set_guests`, owner "cabin"), a
##   small warm light just outside the pane, only while it is dark. The
##   nearest MAX_LIGHTS of lamps, campfires and windows share the pool, so
##   many cabins never add a light.
## - **Smoke**: a thin wisp from the chimneys of the ACTIVE_CABINS cabins
##   nearest the camera, in one capped pool (SMOKE_CAP) on the wildfire's
##   smoke shader, as the campfire's smoke is; it leans downwind (the
##   breeze and the wind tool's gusts, PollenWind).
##
## Made and owned by NativeChunkEditor (`cabins`).

const Cabin = preload("res://scripts/cabin.gd")
const PollenWind = preload("res://scripts/pollen_wind.gd")
const ASSET := "cabin"
## The pane: its warm colour and emission at full night.
const PANE_COLOR := Color("ffb466")
const PANE_GLOW := 2.6
## The window's light: m outside the pane, reach (m), energy at full night.
const LIGHT_OUT := 0.45
const LIGHT_RANGE := 3.6
const LIGHT_ENERGY := 1.1
const LIGHT_COLOR := Color("ffb36b")
## Seconds between re-reading the records, and between picking the cabins
## that smoke.
const READ_SECONDS := 0.5
const PICK_SECONDS := 0.5
## Smoke: from this many cabins at most, puffs a second each, a puff's life
## (s), rise (m/s), size (m) and strength.
const ACTIVE_CABINS := 4
const SMOKE_CAP := 40
const SMOKE_RATE := 0.9
const SMOKE_LIFE := 6.0
const SMOKE_RISE := 0.4
const SMOKE_SIZE := 0.2
const SMOKE_STRENGTH := 0.12

var editor: Node
## The cabins as last read: {"id", "pane" (Transform3D, global), "light"
## (global), "flue" (global), "plate", "scale" (world)}.
var cabins: Array[Dictionary] = []
## 0..1: how dark it is (the lamps' eased glow).
var night := 0.0
var panes: MultiMeshInstance3D
var smoke: MultiMeshInstance3D
var puffs: Array[Dictionary] = []
## Indices into `cabins` of the ones that smoke.
var active: Array[int] = []
var _pane_material := StandardMaterial3D.new()
var _smoke_material := ShaderMaterial.new()
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _revision := -1
var _count := -1
var _read_in := 0.0
var _pick_in := 0.0
var _smoke_debt := 0.0
var _by_id := {}

func setup(owner_editor: Node) -> void:
	editor = owner_editor
	name = "Cabins"
	_rng.seed = 60417
	_pane_material.albedo_color = Cabin.GLASS
	_pane_material.roughness = 0.6
	_pane_material.emission_enabled = true
	_pane_material.emission = PANE_COLOR
	_pane_material.emission_energy_multiplier = 0.0
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	panes = _batch("Windows",box,_pane_material)
	_smoke_material.shader = preload("res://shaders/fire_smoke.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	smoke = _batch("ChimneySmoke",quad,_smoke_material)
	smoke.multimesh.use_custom_data = true
	smoke.multimesh.instance_count = SMOKE_CAP
	smoke.multimesh.visible_instance_count = 0

func _batch(label: String, mesh: Mesh, material: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	node.visible = false
	add_child(node)
	return node

## A window's light energy now: only while it is dark.
func energy(id: int) -> float:
	return LIGHT_ENERGY*night*night if _by_id.has(id) else 0.0

## The dark the windows answer to: the lamps' eased glow.
func _night() -> float:
	var lamps: Variant = editor.get("lamps")
	return float(lamps.glow) if lamps != null else 0.0

func _process(delta: float) -> void:
	if editor == null or editor.get("data") == null: return
	var data: NativeTerrainData = editor.data
	_read_in -= delta
	if data.objects_revision != _revision or data.objects.size() != _count or _read_in <= 0.0: _read(data)
	if cabins.is_empty() and puffs.is_empty(): return
	var dt := clampf(delta,0.0,0.1)
	_clock += dt
	night = _night()
	_pane_material.emission_energy_multiplier = PANE_GLOW*night
	panes.visible = night > 0.001 and not cabins.is_empty()
	_smoke_material.set_shader_parameter("time",_clock)
	_pick_in -= dt
	if _pick_in <= 0.0:
		_pick_in = PICK_SECONDS
		_pick()
	_smoke(dt)

## Reads the cabin records into world points, lays the panes and hands the
## windows to the lamps' light pool as guests.
func _read(data: NativeTerrainData) -> void:
	_revision = data.objects_revision
	_count = data.objects.size()
	_read_in = READ_SECONDS
	var terrain: Node3D = editor.terrain
	var world_scale := terrain.global_basis.get_scale().x
	var info := Cabin.info()
	var pane: AABB = info.pane
	var found: Array[Dictionary] = []
	_by_id = {}
	for item: Dictionary in data.objects:
		if str(item.asset) != ASSET: continue
		var size := float(item.scale)
		var local := Transform3D(Basis(Vector3.UP,float(item.angle)).scaled(Vector3.ONE*size),data.object_position(item))
		var pose: Transform3D = terrain.global_transform*local
		# The pane sits just proud of the glass (+X), behind the glazing bars.
		var pane_pose := pose*Transform3D(Basis.from_scale(pane.size+Vector3(0.004,0.0,0.0)),pane.get_center()+Vector3(0.002,0.0,0.0))
		var cabin := {"id":int(item.id),"pane":pane_pose,"light":pose*(pane.get_center()+Vector3(LIGHT_OUT,0.0,0.0)),
			"flue":pose*(info.smoke as Vector3),"plate":Vector2(float(item.x),float(item.z)),"scale":size*world_scale}
		found.append(cabin)
		_by_id[int(item.id)] = cabin
	cabins = found
	var guests: Array[Dictionary] = []
	for cabin in cabins: guests.append({"id":cabin.id,"at":cabin.light,"range":LIGHT_RANGE*float(cabin.scale),"color":LIGHT_COLOR})
	var lamps: Variant = editor.get("lamps")
	if lamps != null: lamps.set_guests(guests,ASSET,energy)
	panes.multimesh.instance_count = cabins.size()
	var bounds := AABB()
	for i in range(cabins.size()):
		panes.multimesh.set_instance_transform(i,cabins[i].pane)
		bounds = AABB(cabins[i].flue,Vector3.ZERO) if i == 0 else bounds.expand(cabins[i].flue)
	var room := bounds.grow(4.0*maxf(1.0,world_scale))
	room.size.y += 6.0*maxf(1.0,world_scale)
	smoke.custom_aabb = room if not cabins.is_empty() else AABB()
	if cabins.is_empty():
		panes.visible = false
		active.clear()
	_pick()

## The cabins nearest the camera, which smoke.
func _pick() -> void:
	active.clear()
	if cabins.is_empty(): return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var order := range(cabins.size())
	order.sort_custom(func(a: int, b: int) -> bool: return eye.distance_squared_to(cabins[a].flue) < eye.distance_squared_to(cabins[b].flue))
	var scene: Node = editor.get("scene")
	var terrain: Node3D = editor.terrain
	for k in range(mini(ACTIVE_CABINS,order.size())):
		var cabin: Dictionary = cabins[order[k]]
		var drift: Vector2 = PollenWind.at(scene,terrain,cabin.plate) if scene != null else Vector2.ZERO
		cabin.wind = terrain.global_basis*Vector3(drift.x,0.0,drift.y)
		active.append(int(order[k]))

## A thin wisp off the chimneys, leaning downwind as it climbs.
func _smoke(dt: float) -> void:
	_smoke_debt += float(active.size())*SMOKE_RATE*dt
	while _smoke_debt >= 1.0:
		_smoke_debt -= 1.0
		if puffs.size() >= SMOKE_CAP or active.is_empty(): continue
		var cabin: Dictionary = cabins[active[_rng.randi_range(0,active.size()-1)]]
		var s: float = cabin.scale
		puffs.append({"position":cabin.flue+Vector3(_rng.randf_range(-0.05,0.05)*s,0.05*s,_rng.randf_range(-0.05,0.05)*s),
			"wind":cabin.get("wind",Vector3.ZERO),"age":0.0,"life":SMOKE_LIFE*_rng.randf_range(0.8,1.2),"seed":_rng.randf(),
			"size":SMOKE_SIZE*s*_rng.randf_range(0.85,1.2),"rise":SMOKE_RISE*s*_rng.randf_range(0.8,1.2)})
	_smoke_debt = minf(_smoke_debt,3.0)
	var mesh := smoke.multimesh
	for i in range(puffs.size()-1,-1,-1):
		var puff: Dictionary = puffs[i]
		puff.age += dt
		if puff.age >= puff.life:
			puffs.remove_at(i)
			continue
		var u: float = puff.age/puff.life
		var wind: Vector3 = puff.wind
		puff.position += (Vector3.UP*float(puff.rise)+wind*0.6*smoothstep(0.0,0.4,u))*dt
	var count := 0
	for puff in puffs:
		var u: float = puff.age/puff.life
		var size: float = lerpf(puff.size,puff.size*3.2,sqrt(u))
		var alpha: float = SMOKE_STRENGTH*smoothstep(0.0,0.15,u)*(1.0-smoothstep(0.45,1.0,u))
		mesh.set_instance_transform(count,Transform3D(Basis.IDENTITY,puff.position))
		mesh.set_instance_custom_data(count,Color(puff.seed,size,alpha,0.35+0.65*u))
		count += 1
	mesh.visible_instance_count = count
	smoke.visible = count > 0
