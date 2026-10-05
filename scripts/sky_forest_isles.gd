extends Node3D
## Forested isles: long, ragged pieces of the land below hung in the sky
## (scripts/sky_forest_isle.gd), far bigger than the islets, with a lake or
## two and old forest to glide in under: giant redwoods standing far apart,
## their crowns high, so the lanes between the trunks are open at glide
## height, and the water opens out among them.
##
## They are few: at most one to a CELL, seeded, none in the fixed
## archipelago's ring (within RING of the plate's first home, where the
## islands and their jet streams stand) but HOME, the one within sight of
## the plate, out past the archipelago's own currents with its long side to
## the plate. None stands on a mountain range risen through the sea
## (scripts/sky_peaks.gd `blocks`); islands, islets and clouds never stand
## within KEEP of one (`blocks`, read by scripts/sky_cells.gd,
## scripts/sky_islets.gd and scripts/sky_clouds.gd).
##
## Within BUILD of the eye an isle is made on a worker (its shape, its body
## and its water as plain arrays), and only its nodes are stood up here;
## beyond FORGET it is let go, and the same one comes back when flown back
## to. This node stands at the cells' origin, so the swaps that move the
## world carry the isles along.
##
## The top is drawn with the plate's own ground material, the water with
## its still water (SkyIslets `_pond_material`), both laid OFF_MAP off so
## the plate's maps read nothing on them; the rock with its earth sides'
## (the chunks' strata, scaled up). The forest is the plate's own
## trees, instanced: the giants are the plate's redwood (scripts/
## redwood_assets.gd behind scripts/hero_trees.gd), its trunk drawn up tall
## and bare and its crown lifted onto it, near; far off the source redwood's
## few faces stand in for them (TREE_NEAR, TREE_FAR). The understory is the
## islets' spruces and the plate's ferns. Roots hang from the rim and the rock under it, and the
## lower lake spills off the rim as the islets' falls do.
##
## The glide reads each as a solid (`body`); its trunks and crowns are wood
## (`stone`): turned aside by at their sides, ridden over on top, and a
## crown's underside a ceiling it slides along, so under the canopy it keeps
## to the lanes.

const SkyForestIsle = preload("res://scripts/sky_forest_isle.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const HeroTrees = preload("res://scripts/hero_trees.gd")
const RedwoodAssets = preload("res://scripts/redwood_assets.gd")
const FlowFalls = preload("res://scripts/flow_falls.gd")
const Strata = preload("res://scripts/strata.gd")

## The isle within sight of the plate: its middle (home coordinates) and
## its turn (radians about y; local +x, its length, runs square to the
## plate). Out past the archipelago's own currents, clear of its islands.
const HOME := SkyHomes.ISLE
const HOME_TURN := SkyHomes.ISLE_TURN
## The cells: size (m), the share holding an isle, how far its spot may sit
## from the cell's middle (share of the cell), the height band (m) and the
## ring round the plate's first home that only HOME stands in.
const CELL := 2400.0
const HOLDS := 0.45
const JITTER := 0.22
const BAND := Vector2(-22.0,6.0)
const RING := 1500.0
const SALT := 4000
## Nothing else stands within KEEP (m, plate plane) of an isle's middle:
## past the furthest any rim reaches.
const KEEP := SkyHomes.ISLE_KEEP
## Made within BUILD of the eye, let go past FORGET.
const BUILD := 2200.0
const FORGET := 2700.0
const CHECK := 0.5
## Laid this far off so the plate's maps read nothing (SkyIslets OFF_MAP).
const OFF_MAP := Vector3(3000.0,0.0,3000.0)
## The giants' near meshes draw out to TREE_NEAR (m), the far stand-ins from
## there to TREE_FAR; spruces and roots to SMALL_RANGE, ferns to FERN_RANGE.
const TREE_NEAR := 560.0
const TREE_FAR := 2600.0
const SMALL_RANGE := 520.0
const FERN_RANGE := 320.0
## The haze: an isle's spot reaches this far past its rim (m), and how far
## onto a landform's gentler curve it takes the haze (0 to 1).
const HAZE_MARGIN := 160.0
const HAZE_FAR := 0.65
## The fall off the outflow's lip: its rings (SkyIslets FALL_RINGS), its
## sheet's drop (share of the rock's depth, plus m), its tail (m), the
## water's speed off the lip and its strength.
const FALL_RINGS := 24
const FALL_DROP := Vector2(0.45,10.0)
const FALL_TAIL := 26.0
const FALL_STRENGTH := 0.85
## How far over the keel's tip (in the rock mesh's own metres, ROCK_SCALE
## times small) the earth sides' mist begins to take the rock.
const MIST := 1.2
## The rock's beds undulate this much (in its own small metres) and this
## many times as often as the plate's.
const STRATA_WARP := 0.85
const STRATA_WAVE := 2.5
## Roots: their thickness at the top (m), their colour (sRGB).
const ROOT_THICK := Vector2(0.12,0.32)
const ROOT_COLOR := Color("4d3a2c")

## The cells' origin keeper (scripts/sky_cells.gd).
var cells: RefCounted
## The plate's ground and earth-sides materials and palette (SkyIslands
## sets them), the
## islets (for their pond water and fall curve), and Callable(variant) ->
## [trunk, crown] meshes of the islets' spruces, if wanted.
var ground_source: Material
var side_source: Material
var palette_source: RefCounted
var islets: Node3D
var tree_parts := Callable()
var canopy_tint := Color.WHITE
## Built isles by cell key: {node, shape, home, turn, cell, reach}.
var built := {}
var _making := {}
var _since := CHECK
var _water: Material
static var _giants := {}
static var _root_mesh: ArrayMesh
static var _fern_mesh: Mesh
static var _ring_mesh: ArrayMesh

func _init() -> void:
	name = "SkyForestIsles"

func _exit_tree() -> void:
	clear()
	_giants.clear()
	_root_mesh = null
	_fern_mesh = null
	_ring_mesh = null

## Starts over on new cells: every isle goes, and they are made again round
## the eye as the glide goes on.
func reset(new_cells: RefCounted) -> void:
	clear()
	_water = null
	# None stand while the isles are off (SkyHomes `isles`).
	if not SkyHomes.isles:
		cells = null
		return
	cells = new_cells
	_since = CHECK
	position = cells.origin

## Freed without leaving a tree (made and dropped outside one, as tests
## and probes do), `_exit_tree` never runs: its workers are still waited
## for, since a task never waited on outlives the scripts and crashes the
## engine's exit.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	for key in _making: WorkerThreadPool.wait_for_task_completion(_making[key].task)
	_making.clear()

func clear() -> void:
	for key in _making: WorkerThreadPool.wait_for_task_completion(_making[key].task)
	_making.clear()
	for key in built: (built[key].node as Node3D).queue_free()
	built.clear()

func isle_count() -> int:
	return built.size()

## Each frame of the glide: follow the origin; every CHECK seconds make the
## isles within BUILD and let go of those past FORGET; stand up one the
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

## Waits for every isle being made and stands it up (tests, captures).
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

## The cell's isle: Vector4(x, y, z of its middle (home), turn), or null.
## The plate's cell holds HOME and only it; elsewhere a share of cells hold
## one, outside RING, off the ranges (and the kinds kept with them), off
## the towers and off every wonder in sight of the plate (SkyHomes).
static func spot(cell: Vector2i) -> Variant:
	if not SkyHomes.isles: return null
	if cell == Vector2i.ZERO: return Vector4(HOME.x,HOME.y,HOME.z,HOME_TURN)
	if noise(cell,SALT) >= HOLDS: return null
	var middle := Vector2(cell)*CELL
	var off := Vector2(noise(cell,SALT+1)-0.5,noise(cell,SALT+2)-0.5)*2.0*JITTER*CELL
	var at := Vector3(middle.x+off.x,lerpf(BAND.x,BAND.y,noise(cell,SALT+3)),middle.y+off.y)
	if Vector2(at.x,at.z).length() < RING or SkyPeaks.blocks(at,KEEP) or SkyTowers.blocks(at,KEEP) or SkyHomes.blocks(at,KEEP): return null
	return Vector4(at.x,at.y,at.z,noise(cell,SALT+5)*TAU)

static func seed_of(cell: Vector2i) -> int:
	return int(noise(cell,SALT+4)*16777216.0)

## True if a home point lies within KEEP (plus `margin`) of an isle's middle.
static func blocks(home: Vector3, margin := 0.0) -> bool:
	var c := cell_of(home)
	for dx in range(-1,2):
		for dz in range(-1,2):
			var s: Variant = spot(c+Vector2i(dx,dz))
			if s != null and Vector2(s.x-home.x,s.z-home.z).length() < KEEP+margin: return true
	return false

## A hash of a cell, 0 to 1, one per salt (as SkyCells `noise`).
static func noise(cell: Vector2i, salt: int) -> float:
	return SkyWorld.noise(cell,salt)

# --- Making one --------------------------------------------------------------------

func _start(cell: Vector2i, s: Vector4) -> void:
	# The erosion's native kernel, if built, is found here on the main
	# thread, before a worker asks for it.
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	var out := {}
	var task := WorkerThreadPool.add_task(_make.bind(seed_of(cell),_palette("grass"),_gravel(),_bank(),out),false,"Sky forest isle")
	_making[_key(cell)] = {"task":task,"cell":cell,"spot":s,"out":out}

static func _make(seed_value: int, grass: Array, gravel: Color, bank: Color, out: Dictionary) -> void:
	var shape: RefCounted = SkyForestIsle.make(seed_value)
	out.shape = shape
	out.body = shape.body_arrays(grass,gravel,bank,OFF_MAP)
	out.water = shape.water_arrays(Color(0.16,0.25,0.32),OFF_MAP)

## The worker's isle, stood up as nodes: its body, its water and fall, its
## forest and its roots.
func _finish(cell: Vector2i, s: Vector4, out: Dictionary) -> void:
	var shape: RefCounted = out.shape
	var node := Node3D.new()
	node.name = "ForestIsle_%d_%d" % [cell.x,cell.y]
	node.position = Vector3(s.x,s.y,s.z)
	node.rotation.y = s.w
	add_child(node)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = SkyForestIsle.mesh_from(out.body.top,ground_source if ground_source != null else _stand_in_ground())
	body.position = -OFF_MAP
	node.add_child(body)
	var rock := MeshInstance3D.new()
	rock.name = "Rock"
	rock.mesh = SkyForestIsle.mesh_from(out.body.rock,_rock_material(shape))
	rock.scale = Vector3.ONE*SkyForestIsle.ROCK_SCALE
	node.add_child(rock)
	if not (out.water as Array).is_empty():
		var water := MeshInstance3D.new()
		water.name = "Water"
		water.mesh = SkyForestIsle.mesh_from(out.water,_water_material(),SkyForestIsle.WATER_FORMAT)
		water.position = -OFF_MAP
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.set_meta("skip_reflection",true)
		node.add_child(water)
		_fall(node,shape)
	_forest(node,shape)
	_hang_roots(node,shape)
	built[_key(cell)] = {"node":node,"shape":shape,"home":Vector3(s.x,s.y,s.z),"turn":s.w,"cell":cell,"reach":shape.reach()}

## The still water, as the islets' ponds draw it; a stand-in without them.
func _water_material() -> Material:
	if _water != null: return _water
	if islets != null and islets.has_method("_pond_material"): _water = islets._pond_material()
	if _water == null:
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/islet_pond.gdshader")
		_water = m
	return _water

## The plate's earth-sides material (SkyIslands sets `side_source`), its
## strata laid in the rock mesh's own small space, the mist taking over only
## at the keel.
func _rock_material(shape: RefCounted) -> Material:
	var m: ShaderMaterial
	if side_source is ShaderMaterial: m = side_source.duplicate()
	else:
		m = ShaderMaterial.new()
		m.shader = preload("res://shaders/reference_surface.gdshader")
		m.set_shader_parameter("flat_faces",true)
		m.set_shader_parameter("base_color",Color.WHITE)
	m.set_shader_parameter("earth_sides",true)
	m.set_shader_parameter("earth_sides_base",float(shape.bottom)/SkyForestIsle.ROCK_SCALE+MIST)
	Strata.for_seed(shape.seed).apply(m,Vector3.ZERO)
	# The beds undulate far more than the plate's, so no band runs ruler
	# straight round the rock like a cake's layer.
	for key in ["strata_wave_a","strata_wave_b"]:
		var w: Vector4 = m.get_shader_parameter(key)
		m.set_shader_parameter(key,Vector4(w.x*STRATA_WAVE,w.y*STRATA_WAVE,w.z,STRATA_WARP if key == "strata_wave_a" else w.w))
	return m

func _stand_in_ground() -> Material:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/reference_surface.gdshader")
	m.set_shader_parameter("flat_faces",true)
	m.set_shader_parameter("palette_role",1)
	m.set_shader_parameter("base_color",Color.WHITE)
	return m

## The forest: the giants as two pairs of batches (near, far), the spruces
## one pair per variant.
func _forest(node: Node3D, shape: RefCounted) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape.seed*7+3
	var giants := []
	var spruces := {}
	for index in range(shape.trees.size()):
		var k: int = shape.kinds[index]
		if k == -1: giants.append(index)
		else:
			if not spruces.has(k): spruces[k] = []
			spruces[k].append(index)
	for lod in ["near","far"]:
		var parts := _giant_parts(lod)
		var poses := [[],[]]
		var tints := []
		var r := RandomNumberGenerator.new()
		r.seed = shape.seed*11+1
		for index: int in giants:
			var pose := _giant_pose(shape,index,parts,r.randf()*TAU)
			poses[0].append(pose[0])
			poses[1].append(pose[1])
			tints.append(Color.WHITE*r.randf_range(0.86,1.06))
		for part in range(2):
			var batch := _batch(parts.meshes[part],poses[part],tints if part == 1 else [])
			batch.name = "Giant%s%s" % [lod.capitalize(),"Crown" if part == 1 else "Trunk"]
			if lod == "near":
				batch.visibility_range_end = TREE_NEAR
				batch.visibility_range_end_margin = 40.0
			else:
				batch.visibility_range_begin = TREE_NEAR
				batch.visibility_range_begin_margin = 40.0
				batch.visibility_range_end = TREE_FAR
				batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(batch)
	_plant_ferns(node,shape)
	if not tree_parts.is_valid(): return
	for v: int in spruces:
		var parts: Array = tree_parts.call(v)
		var tall := maxf((parts[1] as Mesh).get_aabb().end.y,0.1)
		var poses := []
		var tints := []
		for index: int in spruces[v]:
			var t: Vector4 = shape.trees[index]
			poses.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*t.w/tall),Vector3(t.x,t.z-0.1,t.y)))
			tints.append(canopy_tint*rng.randf_range(0.86,1.04))
		for part in range(2):
			var batch := _batch(parts[part],poses,tints if part == 1 else [])
			batch.name = "Spruce%d%s" % [v,"Crown" if part == 1 else "Trunk"]
			batch.visibility_range_end = SMALL_RANGE
			batch.visibility_range_end_margin = 40.0
			batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			node.add_child(batch)

## The ferns under the giants: the plate's own fern (scripts/
## redwood_assets.gd), grown big, swaying in the breeze, one batch.
func _plant_ferns(node: Node3D, shape: RefCounted) -> void:
	if shape.ferns.is_empty(): return
	if _fern_mesh == null:
		_fern_mesh = RedwoodAssets.mesh("redwood-fern").duplicate()
		var material: ShaderMaterial = (_fern_mesh.surface_get_material(0) as ShaderMaterial).duplicate()
		material.set_shader_parameter("plant_growth",false)
		_fern_mesh.surface_set_material(0,material)
	var rng := RandomNumberGenerator.new()
	rng.seed = shape.seed*13+5
	var poses := []
	var tints := []
	for f: Vector4 in shape.ferns:
		poses.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*f.w),Vector3(f.x,f.z-0.05,f.y)))
		tints.append(Color.WHITE*rng.randf_range(0.8,1.05))
	var batch := _batch(_fern_mesh,poses,tints)
	batch.name = "Ferns"
	batch.visibility_range_end = FERN_RANGE
	batch.visibility_range_end_margin = 30.0
	batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(batch)

func _batch(mesh: Mesh, poses: Array, tints: Array) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = poses.size()
	for i in range(poses.size()):
		multimesh.set_instance_transform(i,poses[i])
		multimesh.set_instance_color(i,tints[i] if not tints.is_empty() else Color.WHITE)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multimesh
	return batch

## A giant's [trunk, crown] poses: the trunk drawn up from under the ground
## into the crown, as wide as the trunk's radius; the crown's mesh fitted to
## the crown's box, leaning as the crown does, turned by `spin`.
static func _giant_pose(shape: RefCounted, index: int, parts: Dictionary, spin: float) -> Array:
	var t: Vector4 = shape.trees[index]
	var c: Vector4 = shape.crowns[index]
	var at := Vector3(t.x,0.0,t.y)
	var trunk: AABB = parts.trunk_box
	var foot := t.z-0.8
	var head := c.x+(c.y-c.x)*0.45
	var sy := (head-foot)/trunk.size.y
	var sx := c.w/float(parts.trunk_radius)
	var turn := Basis(Vector3.UP,spin)
	var trunk_pose := Transform3D(turn*Basis.from_scale(Vector3(sx,sy,sx)),at+Vector3.UP*(foot-trunk.position.y*sy))
	var crown: AABB = parts.crown_box
	var cy := (c.y-c.x)/crown.size.y
	var cx := c.z/float(parts.crown_radius)
	var lean: Vector2 = shape.leans[index]
	var crown_pose := Transform3D(turn*Basis.from_scale(Vector3(cx,cy,cx)),at+Vector3(lean.x,c.x-crown.position.y*cy,lean.y))
	return [trunk_pose,crown_pose]

## The giant redwood's parts for `lod`, made once: near, the plate's own
## (the hero redwood unless `--classic-trees`); far, the source redwood's
## few faces. Each in the plate's redwood materials, its crown swaying, the
## trunk still, never growing in. With the trunk's radius a fifth of the way
## up and the crown's widest reach, for fitting them to each giant.
static func _giant_parts(lod: String) -> Dictionary:
	if _giants.has(lod): return _giants[lod]
	var meshes := []
	for part in ["redwood-trunk","redwood-canopies"]:
		var source: Mesh = RedwoodAssets.mesh(part)
		var mesh: Mesh = HeroTrees.swap(part,source) if lod == "near" else source
		mesh = mesh.duplicate()
		var material: ShaderMaterial = (mesh.surface_get_material(0) as ShaderMaterial).duplicate() if mesh.surface_get_material(0) is ShaderMaterial else (source.surface_get_material(0) as ShaderMaterial).duplicate()
		material.set_shader_parameter("plant_growth",false)
		material.set_shader_parameter("instance_birth_enabled",false)
		material.set_shader_parameter("instance_fire_enabled",false)
		material.set_shader_parameter("tree_tread",false)
		material.set_shader_parameter("conifer_sway",part == "redwood-canopies")
		mesh.surface_set_material(0,material)
		meshes.append(mesh)
	var trunk_box: AABB = (meshes[0] as Mesh).get_aabb()
	var crown_box: AABB = (meshes[1] as Mesh).get_aabb()
	var out := {"meshes":meshes,"trunk_box":trunk_box,"crown_box":crown_box,
		"trunk_radius":_radius(meshes[0],trunk_box.position.y+trunk_box.size.y*0.12,trunk_box.position.y+trunk_box.size.y*0.25,0.5),
		"crown_radius":_radius(meshes[1],-INF,INF,0.9)}
	_giants[lod] = out
	return out

## How far out from the mesh's axis its vertices between heights lo and hi
## reach: the `share` quantile of their distances.
static func _radius(mesh: Mesh, lo: float, hi: float, share: float) -> float:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var box := mesh.get_aabb()
	var middle := Vector2(box.get_center().x,box.get_center().z)
	var reach := []
	for v in vertices:
		if v.y >= lo and v.y <= hi: reach.append(Vector2(v.x,v.z).distance_to(middle))
	if reach.is_empty(): return maxf(box.size.x,box.size.z)*0.5
	reach.sort()
	return maxf(float(reach[mini(int(reach.size()*share),reach.size()-1)]),0.05)

## Roots hanging from the rim and the rock under it: a strand bent a little
## out and down, one batch.
func _hang_roots(node: Node3D, shape: RefCounted) -> void:
	if shape.roots.is_empty(): return
	if _root_mesh == null: _root_mesh = _make_root()
	var rng := RandomNumberGenerator.new()
	rng.seed = shape.seed*29+3
	var poses := []
	var tints := []
	for r: Vector4 in shape.roots:
		var thick := rng.randf_range(ROOT_THICK.x,ROOT_THICK.y)*clampf(r.w/8.0,0.5,1.3)
		var away := Vector2(r.x,r.z).normalized()
		var basis := Basis(Vector3.UP,atan2(away.x,away.y)+rng.randf_range(-0.6,0.6)).scaled(Vector3(thick,r.w,thick))
		poses.append(Transform3D(basis,Vector3(r.x,r.y,r.z)))
		tints.append(Color.WHITE*rng.randf_range(0.75,1.1))
	var batch := _batch(_root_mesh,poses,tints)
	batch.name = "Roots"
	batch.visibility_range_end = SMALL_RANGE
	batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(batch)

## A root strand: one metre long down from its top, a unit thick there,
## tapering to a thread, faceted, wandering out (+z) and back as it hangs.
static func _make_root() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 7
	var sides := 5
	var colour := ROOT_COLOR.srgb_to_linear()
	var ring := func(k: int) -> Array:
		var t := float(k)/rings
		var middle := Vector3(0.0,-t,0.18*sin(t*PI*0.8)+0.05*sin(t*7.0))
		var r := 0.5*pow(1.0-t,1.3)+0.04
		var out := []
		for s in range(sides): out.append(middle+Vector3(cos(TAU*s/sides)*r,0.0,sin(TAU*s/sides)*r))
		return out
	var rows := []
	for k in range(rings+1): rows.append(ring.call(k))
	for k in range(rings):
		for s in range(sides):
			var a: Vector3 = rows[k][s]
			var b: Vector3 = rows[k][(s+1)%sides]
			var c: Vector3 = rows[k+1][(s+1)%sides]
			var d: Vector3 = rows[k+1][s]
			var tone := colour*(0.85+0.15*float((k+s)%2))
			for v in [a,c,b,a,d,c]:
				st.set_color(tone)
				st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("flat_faces",true)
	material.set_shader_parameter("base_color",Color.WHITE)
	material.set_shader_parameter("palette_role",3)
	mesh.surface_set_material(0,material)
	return mesh

## The fall off the outflow's lip: the waterfalls' strand (shaders/
## flow_fall.gdshader) on a course of its own off the rim, falling free down
## past the rock until it breaks up, as an islet's does, only far longer.
func _fall(node: Node3D, shape: RefCounted) -> void:
	if islets == null or not islets.has_method("curtain"): return
	if _ring_mesh == null: _ring_mesh = FlowFalls._build_ring_mesh(FALL_RINGS)
	var lip := Vector3(shape.lip.x,shape.lip_level,shape.lip.y)
	var out := Vector3(shape.lip_out.x,0.0,shape.lip_out.y)
	var rings: Dictionary = islets.curtain(lip,out,shape.depth*FALL_DROP.x+FALL_DROP.y,FALL_TAIL,SkyForestIsle.CHANNEL*0.85,SkyForestIsle.LIP.y,FALL_STRENGTH)
	var curtain := MeshInstance3D.new()
	curtain.name = "Fall"
	curtain.mesh = _ring_mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/flow_fall.gdshader")
	material.render_priority = FlowFalls.CURTAIN_PRIORITY
	material.set_shader_parameter("fall_seed",float(shape.seed % 997)*0.37+3.0)
	var white := PackedFloat32Array()
	for s in range(12): white.append(fposmod(sin(float(s*23+shape.seed % 1000)*12.9898)*43758.5453,1.0))
	material.set_shader_parameter("section_white",white)
	material.set_shader_parameter("ring_count",FALL_RINGS)
	material.set_shader_parameter("centers_tau",rings.centers)
	material.set_shader_parameter("axis_a_width",rings.across)
	material.set_shader_parameter("axis_b_thick",rings.outward)
	material.set_shader_parameter("aer_steep",rings.aer_steep)
	material.set_shader_parameter("ring_travel",rings.travel)
	material.set_shader_parameter("body_white",0.3*(1.0-smoothstep(0.15,0.8,float(rings.half))))
	material.set_shader_parameter("veil",1.0-smoothstep(0.15,0.85,FALL_STRENGTH))
	material.set_shader_parameter("streak_speed",clampf(0.6*sqrt(2.0*9.81*float(rings.face_drop)),2.5,7.0))
	material.set_shader_parameter("break_from",rings.break_from)
	material.set_shader_parameter("break_length",rings.break_length)
	curtain.material_override = material
	curtain.custom_aabb = rings.bounds
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curtain.set_meta("skip_reflection",true)
	node.add_child(curtain)

# --- Reading them ------------------------------------------------------------------

## A point in an isle's own frame from a global one, and back.
func local_of(b: Dictionary, point: Vector3) -> Vector3:
	var at := point-position-(b.home as Vector3)
	return at.rotated(Vector3.UP,-float(b.turn))

func global_of(b: Dictionary, local: Vector3) -> Vector3:
	return position+(b.home as Vector3)+local.rotated(Vector3.UP,float(b.turn))

## The isle and its solid at a global point (SkyForestIsle `solid`, in
## global metres): [record, Vector3(top, underside, wood)], or [].
func _at(point: Vector3) -> Array:
	for key in built:
		var b: Dictionary = built[key]
		var local := local_of(b,point)
		var shape: RefCounted = b.shape
		if Vector2(local.x,local.z).length() > float(b.reach)+1.0: continue
		var s: Variant = shape.solid(local)
		if s == null: continue
		var y := position.y+float(b.home.y)
		return [b,Vector3((s as Vector3).x+y,(s as Vector3).y+y,(s as Vector3).z)]
	return []

## The isle under a global point as a solid, Vector2(top, underside) in
## global metres, or null.
func body(point: Vector3) -> Variant:
	var hit := _at(point)
	if hit.is_empty(): return null
	return Vector2(hit[1].x,hit[1].y)

func ground(point: Vector3) -> Variant:
	var b: Variant = body(point)
	return (b as Vector2).x if b != null else null

## True where the solid at a global point is a trunk or a crown (the
## glide's `stone`).
func stone(point: Vector3) -> bool:
	var hit := _at(point)
	return not hit.is_empty() and float(hit[1].z) > 0.5

## Each standing isle's spot for the haze, nearest `eye` first:
## Vector4(global x, global z, reach, far).
func haze_spots(eye := Vector3.ZERO) -> Array:
	var out := []
	for key in built:
		var b: Dictionary = built[key]
		var at := position+(b.home as Vector3)
		out.append(Vector4(at.x,at.z,float(b.reach)+HAZE_MARGIN,HAZE_FAR))
	out.sort_custom(func(a: Vector4, c: Vector4) -> bool: return Vector2(a.x-eye.x,a.y-eye.z).length() < Vector2(c.x-eye.x,c.y-eye.z).length())
	return out

## Each standing isle's keep-out for the drifting clouds (SkyClouds
## `keep_off`), nearest `eye` first: Vector4(global x, global z, 0, reach).
func keep_spots(eye := Vector3.ZERO) -> Array:
	var out := []
	for key in built:
		var b: Dictionary = built[key]
		var at := position+(b.home as Vector3)
		out.append(Vector4(at.x,at.z,0.0,float(b.reach)+40.0))
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

func _bank() -> Color:
	if palette_source != null and palette_source.get("sand") is Color: return palette_source.sand
	return Color("c9b57e").srgb_to_linear()

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x,cell.y]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
