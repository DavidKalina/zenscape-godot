extends Node3D
## The pillar forests of the land far below, risen through the cloud sea
## (scripts/sky_pillar.gd): one in sight of the plate, HOME, its face and its
## thread turned toward the plate. A kind kept by the ranges (scripts/
## sky_peaks.gd `KINDS`), standing as their child at the cells' origin and
## made, read and let go along with them, the same way: shape and faces made
## on a worker within BUILD of the eye, let go past FORGET, the same forest
## back when flown back to.
##
## Forests are rare: at most one to a CELL, seeded; for now (the first, a
## prototype) HOLDS is 0 and HOME is the only one. Islands, islets and the
## glide's clouds never stand within KEEP of a forest's middle (`blocks`,
## read through SkyPeaks `blocks`).
##
## Its faces are drawn with the ranges' own ground material (cut at the
## sea's top), its feet wrapped in their cloud puffs (SkyPeaks `_wrap`), its
## tops and ledges planted with the islets' spruces. The glide reads it as
## giant stone (`body`, SkyGlide `stone`): a pillar is solid from far under
## the cloud to its cap, its cap ridden only if come down onto, its sides
## turning the glide aside; the bridge is a slab with air under it. Down the
## thread a jet runs, through the slot and under the bridge, and a thermal
## rises off the hidden meadow (SkyCurrents `add_jet`, `add_thermal`).

const SkyPillar = preload("res://scripts/sky_pillar.gd")

## The forest in sight of the plate: its middle (home coordinates) and turn
## (radians about y), local +z out toward the plate.
const HOME := Vector3(-760.0,0.0,-560.0)
const HOME_TURN := 0.9358
## The cells: size (m), the share holding a forest, the jitter (share of the
## cell), a salt apart from the ranges'.
const CELL := 2600.0
const HOLDS := 0.0
const JITTER := 0.2
const SALT := 5000
## Nothing else stands within KEEP (m, plate plane) of a forest's middle.
const KEEP := 470.0
const BUILD := 2300.0
const FORGET := 2800.0
const CHECK := 0.5
## Laid off the plate's maps (SkyPeaks OFF_MAP).
const OFF_MAP := Vector3(2000.0,0.0,2000.0)
## How far off the spruces still draw (m), and the haze's reach (m).
const TREE_RANGE := 700.0
const HAZE_REACH := 480.0
## The feet's fray into the cloud (m): ragged over the first, pale over the
## second (reference_surface `sea_fray`).
const SEA_FRAY := Vector2(3.0,5.0)
## The puffs at the feet, fainter than the ranges' wrap.
const WRAP_STRENGTH := 0.55

var cells: RefCounted
var currents: Node3D
## The ranges' node (scripts/sky_peaks.gd): its ground material, palette,
## cloud puffs and spruces.
var host: Node3D
## Built forests by cell key: {node, shape, home, turn, cell}.
var built := {}
var _making := {}
var _since := CHECK
var _material: Material
var _puffs: ShaderMaterial
static var _wisp_material: ShaderMaterial
static var _wisp_quad: QuadMesh

func _init() -> void:
	name = "SkyPillars"

func _exit_tree() -> void:
	clear()
	_wisp_material = null
	_wisp_quad = null

func reset(new_cells: RefCounted, air: Node3D = null, owner_node: Node3D = null) -> void:
	clear()
	cells = new_cells
	currents = air
	host = owner_node
	_material = null
	_puffs = null
	_since = CHECK

func clear() -> void:
	for key in _making: WorkerThreadPool.wait_for_task_completion(_making[key].task)
	_making.clear()
	for key in built:
		(built[key].node as Node3D).queue_free()
		_drop_air(key)
	built.clear()

func forest_count() -> int:
	return built.size()

## Each frame of the glide (the ranges' own `advance` calls it).
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
		_finish(m.cell,m.spot,m.out)
		break

func flush() -> void:
	for key in _making.keys():
		var m: Dictionary = _making[key]
		WorkerThreadPool.wait_for_task_completion(m.task)
		_finish(m.cell,m.spot,m.out)
	_making.clear()

func _survey(home: Vector3) -> void:
	var gone := []
	for key in built:
		if _flat(built[key].home,home) > FORGET: gone.append(key)
	for key in gone:
		(built[key].node as Node3D).queue_free()
		_drop_air(key)
		built.erase(key)
	var c := cell_of(home)
	for dx in range(-1,2):
		for dz in range(-1,2):
			var cell := c+Vector2i(dx,dz)
			var key := _key(cell)
			if built.has(key) or _making.has(key): continue
			var s: Variant = spot(cell)
			if s == null or Vector2(s.x-home.x,s.z-home.z).length() > BUILD: continue
			_start(cell,s)

# --- Where they stand -------------------------------------------------------------

static func cell_of(home: Vector3) -> Vector2i:
	return Vector2i(floori(home.x/CELL+0.5),floori(home.z/CELL+0.5))

## The cell's forest: Vector4(x, y, z of its middle (home), turn), or null.
static func spot(cell: Vector2i) -> Variant:
	if cell == Vector2i.ZERO: return Vector4(HOME.x,HOME.y,HOME.z,HOME_TURN)
	if noise(cell,SALT) >= HOLDS: return null
	var middle := Vector2(cell)*CELL
	var off := Vector2(noise(cell,SALT+1)-0.5,noise(cell,SALT+2)-0.5)*2.0*JITTER*CELL
	return Vector4(middle.x+off.x,0.0,middle.y+off.y,noise(cell,SALT+3)*TAU)

static func seed_of(cell: Vector2i) -> int:
	return int(noise(cell,SALT+4)*16777216.0)

## True if a home point lies within KEEP (plus `margin`) of a forest.
static func blocks(home: Vector3, margin := 0.0) -> bool:
	var c := cell_of(home)
	for dx in range(-1,2):
		for dz in range(-1,2):
			var s: Variant = spot(c+Vector2i(dx,dz))
			if s != null and Vector2(s.x-home.x,s.z-home.z).length() < KEEP+margin: return true
	return false

## A hash of a cell, 0 to 1, one per salt (as SkyPeaks `noise`).
static func noise(cell: Vector2i, salt: int) -> float:
	var h := cell.x*73856093^cell.y*19349663^salt*83492791^7*2654435761
	h = (h^(h >> 13))*1274126177
	h = (h^(h >> 16))*668265263
	h ^= h >> 15
	return float(h & 0xFFFFFF)/float(0x1000000)

# --- Making one -------------------------------------------------------------------

func _start(cell: Vector2i, s: Vector4) -> void:
	var out := {}
	var task := WorkerThreadPool.add_task(_make.bind(seed_of(cell),_palette("grass"),_palette("rock"),_gravel(),out),false,"Sky pillars")
	_making[_key(cell)] = {"task":task,"cell":cell,"spot":s,"out":out}

static func _make(seed_value: int, grass: Array, rock: Array, gravel: Color, out: Dictionary) -> void:
	var shape: RefCounted = SkyPillar.make(seed_value)
	out.shape = shape
	out.body = shape.body_arrays(grass,rock,gravel,OFF_MAP)

## The worker's forest, stood up: its faces, the mist, the spruces, and the
## thread's jet and the meadow's thermal.
func _finish(cell: Vector2i, s: Vector4, out: Dictionary) -> void:
	var shape: RefCounted = out.shape
	var node := Node3D.new()
	node.name = "Pillars_%d_%d" % [cell.x,cell.y]
	node.position = Vector3(s.x,s.y,s.z)
	node.rotation.y = s.w
	add_child(node)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = preload("res://scripts/sky_peak.gd").mesh_from(out.body,_ground())
	body.position = -OFF_MAP
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(body)
	if host != null and host.has_method("_wrap") and not shape.wraps.is_empty():
		var wrap: MultiMeshInstance3D = host._wrap(shape)
		# Fainter than the ranges' wrap: a soft edge to each foot, never a
		# white pedestal.
		if _puffs == null:
			_puffs = (wrap.material_override as ShaderMaterial).duplicate()
			_puffs.set_shader_parameter("strength",WRAP_STRENGTH)
		wrap.material_override = _puffs
		node.add_child(wrap)
	if not shape.wisps.is_empty(): node.add_child(_wisps(shape))
	var parts: Variant = host.get("tree_parts") if host != null else null
	if parts is Callable and (parts as Callable).is_valid(): _plant(node,shape,parts)
	var key := _key(cell)
	built[key] = {"node":node,"shape":shape,"home":Vector3(s.x,s.y,s.z),"turn":s.w,"cell":cell}
	_air(key)

## The ranges' ground material (cut at the sea), or the plate's reference
## surface if standing alone; the pillars' feet fray into the cloud without
## the ranges' pale band over it (SEA_FRAY), the mist doing that work.
func _ground() -> Material:
	if _material != null: return _material
	var m: ShaderMaterial
	if host != null and host.has_method("_ground"):
		m = (host._ground() as ShaderMaterial).duplicate()
	else:
		m = ShaderMaterial.new()
		m.shader = preload("res://shaders/reference_surface.gdshader")
		m.set_shader_parameter("flat_faces",true)
		m.set_shader_parameter("palette_role",1)
		m.set_shader_parameter("base_color",Color.WHITE)
		m.set_shader_parameter("sea_cut",SkyPillar.SEA)
	m.set_shader_parameter("sea_fray",SEA_FRAY)
	_material = m
	return _material

## The thin mist (shaders/sky_mist_wisp.gdshader): each wisp a soft streak
## drawn out along the air, drifting a little on its own slow beat.
func _wisps(shape: RefCounted) -> MultiMeshInstance3D:
	if _wisp_material == null:
		_wisp_quad = QuadMesh.new()
		_wisp_quad.size = Vector2.ONE
		_wisp_material = ShaderMaterial.new()
		_wisp_material.shader = preload("res://shaders/sky_mist_wisp.gdshader")
	var wisps: PackedVector4Array = shape.wisps
	var looks: PackedVector3Array = shape.wisp_looks
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _wisp_quad
	multimesh.instance_count = wisps.size()
	for i in range(wisps.size()):
		var w := wisps[i]
		var look := looks[i]
		multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.RIGHT*w.w,Vector3.UP*look.x,Vector3.BACK),Vector3(w.x,w.y,w.z)))
		multimesh.set_instance_custom_data(i,Color(look.y,look.z,0.0,0.0))
	var batch := MultiMeshInstance3D.new()
	batch.name = "Wisps"
	batch.multimesh = multimesh
	batch.material_override = _wisp_material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := SkyPillar.REACH+Vector2(150.0,150.0)
	batch.custom_aabb = AABB(Vector3(-reach.y,SkyPillar.SEA-60.0,-reach.y),Vector3(reach.y*2.0,240.0,reach.y*2.0))
	return batch

## The spruces, a batch pair (trunk, crown) per variant, as the ranges'.
func _plant(node: Node3D, shape: RefCounted, tree_parts: Callable) -> void:
	var by_variant := {}
	var trees: PackedVector4Array = shape.trees
	var variants: PackedInt32Array = shape.tree_variants
	var leans: PackedVector3Array = shape.tree_leans
	for i in range(trees.size()):
		if not by_variant.has(variants[i]): by_variant[variants[i]] = []
		by_variant[variants[i]].append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = shape.seed*7+3
	var tint: Color = host.get("canopy_tint") if host != null and host.get("canopy_tint") is Color else Color.WHITE
	for v in by_variant:
		var parts: Array = tree_parts.call(v)
		var tall := maxf((parts[1] as Mesh).get_aabb().end.y,0.1)
		var poses := []
		for i: int in by_variant[v]:
			var t := trees[i]
			# Those clinging to a face lean out over the drop.
			var lean := leans[i]
			var tilt := Basis(lean.normalized(),lean.length()) if lean.length() > 0.001 else Basis.IDENTITY
			poses.append(Transform3D(tilt*Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*t.w/tall),Vector3(t.x,t.y,t.z)))
		for part in range(2):
			var batch := MultiMeshInstance3D.new()
			batch.name = "Spruce%d%s" % [v,"Crown" if part == 1 else "Trunk"]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.mesh = parts[part]
			multimesh.instance_count = poses.size()
			for i in range(poses.size()):
				multimesh.set_instance_transform(i,poses[i])
				multimesh.set_instance_color(i,tint*rng.randf_range(0.82,1.04) if part == 1 else Color.WHITE)
			batch.multimesh = multimesh
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_end = TREE_RANGE
			batch.visibility_range_end_margin = 60.0
			batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(batch)

## The thread's jet, from out past the face in toward the meadow, and the
## meadow's thermal.
func _air(key: String) -> void:
	if currents == null or not currents.has_method("add_jet"): return
	var b: Dictionary = built[key]
	var shape: RefCounted = b.shape
	var points := PackedVector3Array()
	for p: Vector3 in shape.thread_line(SkyPillar.THREAD_Y,48): points.append(global_of(b,p))
	currents.add_jet(points,_air_key(key))
	currents.add_thermal(global_of(b,shape.thermal_base()),_air_key(key))

func _drop_air(key: String) -> void:
	if currents != null and currents.has_method("drop_thermals"): currents.drop_thermals(_air_key(key))

func _air_key(key: String) -> String:
	return "pillars:"+key

# --- Reading them -----------------------------------------------------------------

## The offset of this node's frame in the frame the ranges are read in (the
## cells' origin: the ranges' node stands there, this one at its middle).
func _origin() -> Vector3:
	var parent := get_parent() as Node3D
	return position+(parent.position if parent != null else Vector3.ZERO)

func local_of(b: Dictionary, point: Vector3) -> Vector3:
	return (point-_origin()-(b.home as Vector3)).rotated(Vector3.UP,-float(b.turn))

func global_of(b: Dictionary, local: Vector3) -> Vector3:
	return _origin()+(b.home as Vector3)+local.rotated(Vector3.UP,float(b.turn))

## The rock at a global point as a solid, Vector2(its top, its underside) in
## global metres, or null in open air.
func body(point: Vector3) -> Variant:
	for key in built:
		var b: Dictionary = built[key]
		var local := local_of(b,point)
		if Vector2(local.x,local.z).length() > SkyPillar.REACH.y+120.0: continue
		var s: Variant = b.shape.solid_at(local)
		if s == null: continue
		var y := _origin().y+float(b.home.y)
		return (s as Vector2)+Vector2(y,y)
	return null

func solid(point: Vector3) -> bool:
	return body(point) != null

## Each forest's spot for the haze: Vector4(global x, global z, reach, 1).
func haze_spots() -> Array:
	var out := []
	for key in built:
		var at := _origin()+(built[key].home as Vector3)
		out.append(Vector4(at.x,at.z,HAZE_REACH,1.0))
	return out

## Each forest's keep-out for the drifting clouds: Vector4(global x,
## global z, 0, KEEP).
func keep_spots() -> Array:
	var out := []
	for key in built:
		var at := _origin()+(built[key].home as Vector3)
		out.append(Vector4(at.x,at.z,0.0,KEEP))
	return out

func _palette(which: String) -> Array:
	if host != null and host.has_method("_palette"): return host._palette(which)
	return [Color("5d9e53").srgb_to_linear(),Color("7fb069").srgb_to_linear(),Color("4a8548").srgb_to_linear()] if which == "grass" \
		else [Color("8d8577").srgb_to_linear(),Color("6f6a5f").srgb_to_linear()]

func _gravel() -> Color:
	if host != null and host.has_method("_gravel"): return host._gravel()
	return Color("a8a08c").srgb_to_linear()

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x,cell.y]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
