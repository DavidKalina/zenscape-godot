extends Node3D
## The mountains of the land far below, where they rise so high they punch
## up through the cloud sea and tower over the sky islands (scripts/
## sky_islands.gd). Each range is a heightfield (scripts/sky_peak.gd): its
## foot under the cloud, wrapped in it, its summits a few hundred metres
## over the islands, and a gorge cut through it that the glide can dive into
## and come out of the far side of, a jet stream running down it.
##
## Ranges are rare: at most one to a CELL, seeded, and the cell the plate
## first stood in always holds HOME, the range within sight of the plate, its
## crest turned square to it, so its long face and the gorge's mouth look
## back at the plate. For now (the first range, a prototype) HOLDS is 0 and
## HOME is the only one; raising it scatters more through the far cells. Islands and islets never stand within KEEP of a range's middle
## (`blocks`, read by scripts/sky_cells.gd and scripts/sky_islets.gd), and
## the fixed slots are clear of HOME by as much.
##
## Within BUILD of the eye a range is made on a worker (shape, then its
## faces), a frame's work only to stand it up; beyond FORGET it is let go,
## and the same one comes back when flown back to. This node stands at the
## cells' origin, so the swaps that move the world carry the ranges along.
##
## Its faces are drawn with the plate's own ground material, laid OFF_MAP off
## so the plate's maps read nothing on them (as SkyIslets does). The glide
## reads each as a solid (`body`): giant stone, ridden only where it is no
## steeper than the glide can ride (SkyGlide `stone`). The haze reads their
## spots (`haze_spots`): a range is a landform, not scenery streamed in, so
## it stays in sight further off than the islands do.

const SkyPeak = preload("res://scripts/sky_peak.gd")

## The range in sight of the plate: its middle (home coordinates) and the
## way its crest runs (radians about y; local +x is the crest's way).
const HOME := Vector3(450.0,0.0,-900.0)
const HOME_TURN := -0.4636
## The cells: size (m), the share holding a range, how far its spot may sit
## from the cell's middle (share of the cell); the cell holding the plate's
## first home is (0, 0).
const CELL := 2600.0
const HOLDS := 0.0
const JITTER := 0.2
const SALT := 3000
## Nothing else stands within KEEP (m, plate plane) of a range's middle.
const KEEP := 720.0
## Made within BUILD of the eye, let go past FORGET.
const BUILD := 2300.0
const FORGET := 2800.0
const CHECK := 0.5
## Laid this far off so the plate's maps read nothing (SkyIslets OFF_MAP).
const OFF_MAP := Vector3(2000.0,0.0,2000.0)
## The jet down the gorge: its height (m).
const JET_Y := 15.0
## How far off the spruces still draw (m).
const TREE_RANGE := 650.0
## The haze: a range's spot reaches this far out (m) for the gentler curve.
const HAZE_REACH := 820.0
## The cloud wrapped round the foot: puffs, held still; and how the rock
## frays into the cloud (m) and goes pale over it (m).
const WRAP_STRENGTH := 0.85
const SEA_FRAY := Vector2(7.0,45.0)

## The cells' origin keeper (scripts/sky_cells.gd), and the currents for the
## gorges' jets.
var cells: RefCounted
var currents: Node3D
## The plate's ground material and palette (SkyIslands sets them), and
## Callable(variant) -> [trunk, crown] meshes of the islets' spruces
## (SkyIslets `_tree_parts`), if trees are wanted.
var ground_source: Material
var palette_source: RefCounted
var tree_parts := Callable()
var canopy_tint := Color.WHITE
## Built ranges by cell key: {node, shape, home, turn, cell}.
var built := {}
## Ranges being made on workers, by cell key: {task, cell, spot, out}.
var _making := {}
var _since := CHECK
var _material: Material
static var _puff_material: ShaderMaterial
static var _quad: QuadMesh

func _init() -> void:
	name = "SkyPeaks"

func _exit_tree() -> void:
	clear()
	_puff_material = null
	_quad = null

## Starts over on new cells: every range goes, and they are made again round
## the eye as the glide goes on.
func reset(new_cells: RefCounted, air: Node3D = null) -> void:
	clear()
	_material = null
	cells = new_cells
	currents = air
	_since = CHECK
	position = cells.origin

func clear() -> void:
	for key in _making: WorkerThreadPool.wait_for_task_completion(_making[key].task)
	_making.clear()
	for key in built:
		(built[key].node as Node3D).queue_free()
		if currents != null: currents.drop_thermals(_jet_key(key))
	built.clear()

func range_count() -> int:
	return built.size()

## Each frame of the glide: follow the origin; every CHECK seconds make the
## ranges within BUILD and let go of those past FORGET; stand up one the
## workers have finished.
func advance(delta: float, eye: Vector3) -> void:
	if cells == null: return
	position = cells.origin
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

## Waits for every range being made and stands it up (tests, probes,
## captures).
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
		if currents != null: currents.drop_thermals(_jet_key(key))
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

# --- Where they stand ------------------------------------------------------------

static func cell_of(home: Vector3) -> Vector2i:
	return Vector2i(floori(home.x/CELL+0.5),floori(home.z/CELL+0.5))

## The cell's range: Vector4(x, y, z of its middle (home), turn), or null.
## The plate's cell always holds HOME.
static func spot(cell: Vector2i) -> Variant:
	if cell == Vector2i.ZERO: return Vector4(HOME.x,HOME.y,HOME.z,HOME_TURN)
	if noise(cell,SALT) >= HOLDS: return null
	var middle := Vector2(cell)*CELL
	var off := Vector2(noise(cell,SALT+1)-0.5,noise(cell,SALT+2)-0.5)*2.0*JITTER*CELL
	return Vector4(middle.x+off.x,0.0,middle.y+off.y,noise(cell,SALT+3)*TAU)

static func seed_of(cell: Vector2i) -> int:
	return int(noise(cell,SALT+4)*16777216.0)

## True if a home point lies within KEEP (plus `margin`) of a range's middle.
static func blocks(home: Vector3, margin := 0.0) -> bool:
	var c := cell_of(home)
	for dx in range(-1,2):
		for dz in range(-1,2):
			var s: Variant = spot(c+Vector2i(dx,dz))
			if s != null and Vector2(s.x-home.x,s.z-home.z).length() < KEEP+margin: return true
	return false

## A hash of a cell, 0 to 1, one per salt (as SkyCells `noise`).
static func noise(cell: Vector2i, salt: int) -> float:
	var h := cell.x*73856093^cell.y*19349663^salt*83492791^7*2654435761
	h = (h^(h >> 13))*1274126177
	h = (h^(h >> 16))*668265263
	h ^= h >> 15
	return float(h & 0xFFFFFF)/float(0x1000000)

# --- Making one --------------------------------------------------------------------

func _start(cell: Vector2i, s: Vector4) -> void:
	# The erosion's native kernel, if built, is found here on the main
	# thread, before a worker asks for it.
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	var out := {}
	var task := WorkerThreadPool.add_task(_make.bind(seed_of(cell),_palette("grass"),_palette("rock"),_gravel(),out),false,"Sky peak")
	_making[_key(cell)] = {"task":task,"cell":cell,"spot":s,"out":out}

static func _make(seed_value: int, grass: Array, rock: Array, gravel: Color, out: Dictionary) -> void:
	var shape: RefCounted = SkyPeak.make(seed_value)
	out.shape = shape
	out.body = shape.body_arrays(grass,rock,gravel,OFF_MAP)

## The worker's range, stood up as nodes: its faces, the cloud at its foot,
## and the jet down its gorge.
func _finish(cell: Vector2i, s: Vector4, out: Dictionary) -> void:
	var shape: RefCounted = out.shape
	var node := Node3D.new()
	node.name = "Peak_%d_%d" % [cell.x,cell.y]
	node.position = Vector3(s.x,s.y,s.z)
	node.rotation.y = s.w
	add_child(node)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = SkyPeak.mesh_from(out.body,_ground())
	body.position = -OFF_MAP
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(body)
	if not shape.wraps.is_empty(): node.add_child(_wrap(shape))
	if tree_parts.is_valid(): _plant(node,shape)
	var key := _key(cell)
	built[key] = {"node":node,"shape":shape,"home":Vector3(s.x,s.y,s.z),"turn":s.w,"cell":cell}
	_jet(key)

## The plate's ground material, cut at the cloud sea's top (reference_
## surface `sea_cut`): one copy a sky, made when the first range stands.
func _ground() -> Material:
	if _material != null: return _material
	var m: ShaderMaterial
	if ground_source is ShaderMaterial:
		m = ground_source.duplicate()
	else:
		m = ShaderMaterial.new()
		m.shader = preload("res://shaders/reference_surface.gdshader")
		m.set_shader_parameter("flat_faces",true)
		m.set_shader_parameter("palette_role",1)
		m.set_shader_parameter("base_color",Color.WHITE)
	m.set_shader_parameter("sea_cut",SkyPeak.SEA)
	m.set_shader_parameter("sea_fray",SEA_FRAY)
	_material = m
	return _material

## The cloud wrapped round the foot: the glide's own cloud puffs
## (shaders/sky_cloud_puff.gdshader), held still, softened where they meet
## the rock, and hazed as the range is (`haze_far`).
func _wrap(shape: RefCounted) -> MultiMeshInstance3D:
	if _puff_material == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
		_puff_material = ShaderMaterial.new()
		_puff_material.shader = preload("res://shaders/sky_cloud_puff.gdshader")
		_puff_material.set_shader_parameter("drift",Vector2.ZERO)
		_puff_material.set_shader_parameter("field",Vector4(-1e6,-1e6,2e6,2e6))
		_puff_material.set_shader_parameter("strength",WRAP_STRENGTH)
		_puff_material.set_shader_parameter("soft_depth",14.0)
		_puff_material.set_shader_parameter("haze_far",1.0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _quad
	multimesh.instance_count = shape.wraps.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = shape.seed*5+1
	for i in range(shape.wraps.size()):
		var w: Vector4 = shape.wraps[i]
		# Size 1: the offset only lights the puff (top lit, base shaded).
		multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.RIGHT*w.w,Vector3.UP,Vector3.BACK),Vector3(w.x,w.y,w.z)))
		multimesh.set_instance_custom_data(i,Color(rng.randf_range(-0.3,0.3),rng.randf_range(-0.1,0.35),rng.randf_range(-0.3,0.3),rng.randf()))
	var puffs := MultiMeshInstance3D.new()
	puffs.name = "Wrap"
	puffs.multimesh = multimesh
	puffs.material_override = _puff_material
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puffs.custom_aabb = AABB(Vector3(-SkyPeak.HALF.x-60.0,SkyPeak.SEA-60.0,-SkyPeak.HALF.y-60.0),Vector3(SkyPeak.HALF.x*2.0+120.0,120.0,SkyPeak.HALF.y*2.0+120.0))
	return puffs

## The spruces: one batch pair (trunk, crown) per variant, as the islets
## plant theirs, drawn out to TREE_RANGE.
func _plant(node: Node3D, shape: RefCounted) -> void:
	var by_variant := {}
	for t: Vector4 in shape.trees:
		var v := int(t.w)
		if not by_variant.has(v): by_variant[v] = []
		by_variant[v].append(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = shape.seed*7+3
	for v in by_variant:
		var parts: Array = tree_parts.call(v)
		var tall := maxf((parts[1] as Mesh).get_aabb().end.y,0.1)
		var poses := []
		for t: Vector4 in by_variant[v]:
			var at := Vector3(t.x,float(shape.height_at(Vector2(t.x,t.y)))-0.1,t.y)
			poses.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*t.z/tall),at))
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
				multimesh.set_instance_color(i,canopy_tint*rng.randf_range(0.86,1.04) if part == 1 else Color.WHITE)
			batch.multimesh = multimesh
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_end = TREE_RANGE
			batch.visibility_range_end_margin = 60.0
			batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(batch)

## The jet down the gorge, from the mouth facing the plate's first home to
## the far one, at glide height (SkyCurrents `add_jet`).
func _jet(key: String) -> void:
	if currents == null or not currents.has_method("add_jet"): return
	var b: Dictionary = built[key]
	var shape: RefCounted = b.shape
	var points := PackedVector3Array()
	for p: Vector3 in shape.gorge_line(JET_Y,48): points.append(global_of(b,p))
	# Downstream away from the plate.
	if points[0].distance_squared_to(cells.origin) > points[points.size()-1].distance_squared_to(cells.origin): points.reverse()
	currents.add_jet(points,_jet_key(key))

func _jet_key(key: String) -> String:
	return "peak:"+key

# --- Reading them ------------------------------------------------------------------

## A point in a range's own frame from a global one, and back.
func local_of(b: Dictionary, point: Vector3) -> Vector3:
	var at := point-position-(b.home as Vector3)
	return at.rotated(Vector3.UP,-float(b.turn))

func global_of(b: Dictionary, local: Vector3) -> Vector3:
	return position+(b.home as Vector3)+local.rotated(Vector3.UP,float(b.turn))

## The range under a global point as a solid, Vector2(its ground's height,
## its underside far under the cloud) in global metres, or null.
func body(point: Vector3) -> Variant:
	for key in built:
		var b: Dictionary = built[key]
		var local := local_of(b,point)
		var h: Variant = b.shape.height_at(Vector2(local.x,local.z))
		if h == null: continue
		var y := position.y+float(b.home.y)
		return Vector2(float(h)+y,SkyPeak.BOTTOM+y)
	return null

## The ground's height under a global point, or null.
func ground(point: Vector3) -> Variant:
	var b: Variant = body(point)
	return (b as Vector2).x if b != null else null

## True where the solid at a global point is a range's rock (the glide's
## `stone`).
func solid(point: Vector3) -> bool:
	return body(point) != null

## Each standing range's spot for the haze, nearest `eye` first:
## Vector4(global x, global z, reach, 1).
func haze_spots(eye := Vector3.ZERO) -> Array:
	var out := []
	for key in built:
		var b: Dictionary = built[key]
		var at := position+(b.home as Vector3)
		out.append(Vector4(at.x,at.z,HAZE_REACH,1.0))
	out.sort_custom(func(a: Vector4, c: Vector4) -> bool: return Vector2(a.x-eye.x,a.y-eye.z).length() < Vector2(c.x-eye.x,c.y-eye.z).length())
	return out

## A few colours of the world's own ground (linear), as SkyIslets reads them.
func _palette(which: String) -> Array:
	var found: Array = []
	if palette_source != null:
		var list: Array = palette_source.get(which)
		for c in list: found.append(c)
	if found.is_empty():
		found = [Color("5d9e53").srgb_to_linear(),Color("7fb069").srgb_to_linear(),Color("4a8548").srgb_to_linear()] if which == "grass" \
			else [Color("8d8577").srgb_to_linear(),Color("6f6a5f").srgb_to_linear()]
	return found

func _gravel() -> Color:
	if palette_source != null and palette_source.get("gravel") is Color: return palette_source.gravel
	return Color("a8a08c").srgb_to_linear()

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x,cell.y]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
