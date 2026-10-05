extends Node3D
## The table mountain risen through the cloud sea within sight of the plate
## (scripts/sky_tepui.gd's shape), stood up as the sky peaks' ranges are
## (scripts/sky_peaks.gd, which holds this node and passes on to it): made
## on a worker within BUILD of the eye, let go past FORGET, the same one
## back when flown back to. Its rock is drawn with the peaks' own ground
## material (cut at the sea's top) and wrapped in their cloud; its pools and
## streams with the islets' pond water.
##
## Its falls are soft, glowing things (shaders/sky_tepui_fall.gdshader): a
## ribbon down each fall's course, turned about its line to face the eye,
## streaked and running, glassy at the lip and white below, breaking into
## clumps and ragged edges as it falls; round it a wider veil of spray that
## thickens down the fall; and mist (shaders/sky_tepui_mist.gdshader),
## puffs that roll out of the spray and billow up from the foot of the fall
## where it goes into the cloud sea, each on its own beat. None of it is
## solid: behind the great fall's curtain there is a gap the glide can
## thread (SkyTepui `gap`).
##
## Beside the great fall an updraft rises off the wall past the plateau's
## height (SkyCurrents `add_thermal`), so the glide can ride up and skim the
## plateau. The glide reads the rock as giant stone (`body`, SkyGlide
## `stone`): it rides the plateau and the ledges, and the walls turn it
## aside.

const SkyTepui = preload("res://scripts/sky_tepui.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const WaterFlowView = preload("res://scripts/water_flow_view.gd")

## The tepui in sight of the plate: its middle (home coordinates) and its
## turn (radians about y; its great fall pours toward local +z, turned
## a little off the plate so it is seen three-quarter on).
const HOME := Vector3(-1100.0,0.0,-700.0)
const HOME_TURN := 1.22
const SEED := 731
## Nothing else stands within KEEP (m, plate plane) of its middle.
const KEEP := 580.0
const BUILD := 2300.0
const FORGET := 2800.0
const CHECK := 0.5
const OFF_MAP := Vector3(2000.0,0.0,2000.0)
## The haze: its spot's reach (m).
const HAZE_REACH := 640.0
## The falls: rows down each ribbon, the veil's width over the core's, the
## streaks' speed (m/s) for the great fall and the small.
const ROWS := 56
const VEIL := 1.9
const SPEED := Vector2(16.0,10.0)
## The mist: puffs rolling out of the spray down each fall and billowing up
## from its foot (great, small).
const SPRAY := Vector2i(30,12)
const PLUME := Vector2i(28,10)
## How far off the falls' spray still draws (m), and the updraft's lift
## (m/s).
const MIST_RANGE := 2600.0
const LIFT := 8.0

var cells: RefCounted
var currents: Node3D
## The peaks node, for its ground material, cloud and spruces.
var peaks: Node3D
var built := {}
var _making := {}
var _since := CHECK
static var _quad: QuadMesh

func _init() -> void:
	name = "SkyTepuis"

func _exit_tree() -> void:
	clear()
	_quad = null

func reset(new_cells: RefCounted, air: Node3D, owner_peaks: Node3D) -> void:
	clear()
	cells = new_cells
	currents = air
	peaks = owner_peaks
	_since = CHECK

func clear() -> void:
	for key in _making: WorkerThreadPool.wait_for_task_completion(_making[key].task)
	_making.clear()
	for key in built:
		(built[key].node as Node3D).queue_free()
		if currents != null: currents.drop_thermals(_lift_key(key))
	built.clear()

func tepui_count() -> int:
	return built.size()

## Every CHECK seconds: made within BUILD of the eye (global), let go past
## FORGET; a finished worker's tepui stood up.
func advance(delta: float, eye: Vector3) -> void:
	if cells == null: return
	_since += delta
	if _since >= CHECK:
		_since = 0.0
		_survey(eye-cells.origin)
	for key in _making.keys():
		var m: Dictionary = _making[key]
		if not WorkerThreadPool.is_task_completed(m.task): continue
		WorkerThreadPool.wait_for_task_completion(m.task)
		_making.erase(key)
		_finish(key,m.spot,m.out)
		break

func flush() -> void:
	for key in _making.keys():
		var m: Dictionary = _making[key]
		WorkerThreadPool.wait_for_task_completion(m.task)
		_finish(key,m.spot,m.out)
	_making.clear()

func _survey(home: Vector3) -> void:
	var gone := []
	for key in built:
		if _flat(built[key].home,home) > FORGET: gone.append(key)
	for key in gone:
		(built[key].node as Node3D).queue_free()
		if currents != null: currents.drop_thermals(_lift_key(key))
		built.erase(key)
	for s: Vector4 in spots():
		var key := "%d,%d" % [int(s.x),int(s.z)]
		if built.has(key) or _making.has(key) or Vector2(s.x-home.x,s.z-home.z).length() > BUILD: continue
		_start(key,s)

## The tepuis' spots: Vector4(x, y, z of the middle (home), turn).
static func spots() -> Array:
	return [Vector4(HOME.x,HOME.y,HOME.z,HOME_TURN)]

## True if a home point lies within KEEP (plus `margin`) of a tepui's middle.
static func blocks(home: Vector3, margin := 0.0) -> bool:
	for s: Vector4 in spots():
		if Vector2(s.x-home.x,s.z-home.z).length() < KEEP+margin: return true
	return false

# --- Making one -------------------------------------------------------------------

func _start(key: String, s: Vector4) -> void:
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	var out := {}
	var grass: Array = peaks._palette("grass") if peaks != null else []
	var rock: Array = peaks._palette("rock") if peaks != null else []
	var gravel: Color = peaks._gravel() if peaks != null else Color("a8a08c").srgb_to_linear()
	if grass.is_empty(): grass = [Color("5d9e53").srgb_to_linear()]
	if rock.is_empty(): rock = [Color("8d8577").srgb_to_linear()]
	var task := WorkerThreadPool.add_task(_make.bind(SEED,grass,rock,gravel,out),false,"Sky tepui")
	_making[key] = {"task":task,"spot":s,"out":out}

static func _make(seed_value: int, grass: Array, rock: Array, gravel: Color, out: Dictionary) -> void:
	var shape: RefCounted = SkyTepui.make(seed_value)
	out.shape = shape
	out.body = shape.body_arrays(grass,rock,gravel,OFF_MAP)
	out.water = shape.water_arrays(WaterFlowView.TINT.mid.srgb_to_linear(),OFF_MAP)
	out.falls = []
	for f: Dictionary in shape.falls: out.falls.append([SkyTepui.fall_arrays(f,ROWS,1.0),SkyTepui.fall_arrays(f,ROWS,VEIL)])

func _finish(key: String, s: Vector4, out: Dictionary) -> void:
	var shape: RefCounted = out.shape
	var node := Node3D.new()
	node.name = "Tepui"
	node.position = Vector3(s.x,s.y,s.z)
	node.rotation.y = s.w
	add_child(node)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = SkyTepui.SkyPeak.mesh_from(out.body,peaks._ground() if peaks != null else null)
	body.position = -OFF_MAP
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(body)
	if not (out.water as Array).is_empty():
		var pond := MeshInstance3D.new()
		pond.name = "Water"
		pond.mesh = SkyIslet.mesh_from(out.water,_water_material(),SkyIslet.WATER_FORMAT)
		pond.position = -OFF_MAP
		pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pond.set_meta("skip_reflection",true)
		node.add_child(pond)
	if peaks != null:
		if not shape.wraps.is_empty(): node.add_child(peaks._wrap(shape))
		if peaks.tree_parts.is_valid(): peaks._plant(node,shape)
	for i in range(shape.falls.size()): _fall(node,shape,i,out.falls[i])
	built[key] = {"node":node,"shape":shape,"home":Vector3(s.x,s.y,s.z),"turn":s.w}
	if currents != null and currents.has_method("add_thermal"):
		currents.add_thermal(global_of(built[key],shape.updraft),_lift_key(key),shape.updraft_top,SkyTepui.UPDRAFT_RADIUS,LIFT)

## A fall: its ribbon and veil, and the mist rolling off it.
func _fall(node: Node3D, shape: RefCounted, index: int, arrays: Array) -> void:
	var f: Dictionary = shape.falls[index]
	var main: bool = f.main
	var way: Vector2 = f.out
	var across := Vector3(way.y,0.0,-way.x)
	var low := SkyTepui.fall_point(f,float(f.drop))
	var lip: Vector3 = f.lip
	var bounds := AABB(Vector3(minf(lip.x,low.x),low.y,minf(lip.z,low.z)),Vector3(absf(low.x-lip.x),lip.y-low.y,absf(low.z-lip.z))).grow(SkyTepui.fall_half(f,float(f.drop))*VEIL+20.0)
	for layer in range(2):
		var ribbon := MeshInstance3D.new()
		ribbon.name = "Fall%d%s" % [index,"Veil" if layer == 1 else ""]
		ribbon.mesh = SkyTepui.SkyPeak.mesh_from(arrays[layer],null)
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/sky_tepui_fall.gdshader")
		m.render_priority = 1+layer
		m.set_shader_parameter("layer",float(layer))
		m.set_shader_parameter("speed",SPEED.x if main else SPEED.y)
		m.set_shader_parameter("seed",float(shape.seed % 97)+index*13.0)
		m.set_shader_parameter("across_axis",across.rotated(Vector3.UP,node.rotation.y))
		m.set_shader_parameter("strength",1.0 if main else 0.8)
		ribbon.material_override = m
		ribbon.custom_aabb = bounds
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbon.set_meta("skip_reflection",true)
		node.add_child(ribbon)
	node.add_child(_mist(shape,f,index,bounds))

## The mist off a fall: spray puffs rolling out of its lower course (to
## either side and a little toward the wall, never filling the gap behind
## it) and a plume billowing up from its foot in the cloud sea.
func _mist(shape: RefCounted, f: Dictionary, index: int, bounds: AABB) -> MultiMeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var main: bool = f.main
	var rng := RandomNumberGenerator.new()
	rng.seed = shape.seed*19+index
	var way: Vector2 = f.out
	var out3 := Vector3(way.x,0.0,way.y)
	var across := Vector3(way.y,0.0,-way.x)
	var drop := float(f.drop)
	var poses := []
	var data := []
	var spray := SPRAY.x if main else SPRAY.y
	var plume := PLUME.x if main else PLUME.y
	var scale := 1.0 if main else 0.6
	for k in range(spray):
		var d := drop*lerpf(0.5,0.97,pow(rng.randf(),0.6))
		var at := SkyTepui.fall_point(f,d)+across*rng.randf_range(-1.0,1.0)*SkyTepui.fall_half(f,d)*0.8
		var toward := rng.randf_range(-0.35,1.0)
		var travel := out3*toward*rng.randf_range(14.0,30.0)*scale+across*rng.randf_range(-18.0,18.0)*scale+Vector3.DOWN*rng.randf_range(15.0,45.0)
		var r := rng.randf_range(4.0,10.0)*scale*(0.7+0.6*d/drop)
		poses.append(Transform3D(Basis(Vector3.RIGHT*r,travel,Vector3.BACK),at))
		data.append(Color(rng.randf(),rng.randf(),rng.randf_range(7.0,13.0),0.6))
	var foot := SkyTepui.fall_point(f,drop)
	for k in range(plume):
		var at := foot+across*rng.randf_range(-1.2,1.2)*SkyTepui.fall_half(f,drop)+out3*rng.randf_range(-10.0,18.0)*scale+Vector3.UP*rng.randf_range(-4.0,6.0)
		var travel := Vector3.UP*rng.randf_range(45.0,110.0)*scale+out3*rng.randf_range(5.0,30.0)*scale+across*rng.randf_range(-20.0,20.0)*scale
		var r := rng.randf_range(14.0,28.0)*scale
		poses.append(Transform3D(Basis(Vector3.RIGHT*r,travel,Vector3.BACK),at))
		data.append(Color(rng.randf(),rng.randf(),rng.randf_range(14.0,24.0),1.0))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _quad
	multimesh.instance_count = poses.size()
	for i in range(poses.size()):
		multimesh.set_instance_transform(i,poses[i])
		multimesh.set_instance_custom_data(i,data[i])
	var puffs := MultiMeshInstance3D.new()
	puffs.name = "Mist%d" % index
	puffs.multimesh = multimesh
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/sky_tepui_mist.gdshader")
	m.render_priority = 3
	puffs.material_override = m
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puffs.custom_aabb = bounds.grow(130.0)
	puffs.visibility_range_end = MIST_RANGE
	return puffs

## The islets' pond water (SkyIslets `_pond_material`), found through the
## islands that hold the peaks; the islets' own fallback otherwise.
func _water_material() -> Material:
	var islands: Node = peaks.get_parent() if peaks != null else null
	var islets: Variant = islands.get("islets") if islands != null else null
	if islets != null and islets.has_method("_pond_material"): return islets._pond_material()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/islet_pond.gdshader")
	return m

func _lift_key(key: String) -> String:
	return "tepui:"+key

# --- Reading them ----------------------------------------------------------------

func local_of(b: Dictionary, point: Vector3) -> Vector3:
	var at: Vector3 = point-cells.origin-(b.home as Vector3)
	return at.rotated(Vector3.UP,-float(b.turn))

func global_of(b: Dictionary, local: Vector3) -> Vector3:
	return cells.origin+(b.home as Vector3)+local.rotated(Vector3.UP,float(b.turn))

## The tepui under a global point as a solid, Vector2(its ground's height,
## its underside far under the cloud), or null.
func body(point: Vector3) -> Variant:
	for key in built:
		var b: Dictionary = built[key]
		var local := local_of(b,point)
		var h: Variant = b.shape.height_at(Vector2(local.x,local.z))
		if h == null: continue
		var y: float = cells.origin.y+float(b.home.y)
		return Vector2(float(h)+y,SkyTepui.BOTTOM+y)
	return null

func solid(point: Vector3) -> bool:
	return body(point) != null

## Each standing tepui's spot for the haze: Vector4(global x, global z,
## reach, 1).
func haze_spots() -> Array:
	var out := []
	for key in built:
		var at: Vector3 = cells.origin+(built[key].home as Vector3)
		out.append(Vector4(at.x,at.z,HAZE_REACH,1.0))
	return out

## Each standing tepui's keep-out for the drifting clouds: Vector4(global
## x, global z, 0, KEEP).
func keep_spots() -> Array:
	var out := []
	for key in built:
		var at: Vector3 = cells.origin+(built[key].home as Vector3)
		out.append(Vector4(at.x,at.z,0.0,KEEP))
	return out

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
