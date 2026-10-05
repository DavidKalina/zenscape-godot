extends Node3D
## Islets: small floating islands scattered through the open sky between the
## sky islands (scripts/sky_islands.gd), so a glide always has something
## passing by, to swing round, dip under or perch on. Each is scenery made
## the way the islands are, only small (scripts/sky_islet.gd): the plate's
## grid, an island's outline, its shore wall and hanging rock, its ground
## drawn in the plate's own terrain material, and the plate's own plants
## drawn from its catalog (`catalog`): meadows of flowers, groves of the
## world's tree species, hills, crags, springs whose fall pours off the rim,
## and beaches. Nothing on them is simulated and nothing is built on them.
##
## They stand in seeded cells of their own, finer than the islands' (CELL),
## in the same home coordinates (scripts/sky_cells.gd). This node stands at
## the cells' origin, so the swaps that move the world (SkyIslands `arrive`)
## carry the islets along. None stands within CLEAR of an island's spot.
## Within VIEW of the eye the cells' islets are built, nearest first, a few a
## frame (BUILDS); beyond FORGET they are let go. Each islet's shape and
## meshes are worked out on a worker (`_make`, MAKING at once), so a glide
## into fresh sky never stalls; only the nodes are made here (`_finish`). A cell always grows the same
## islet, so one flown back to is the one left. None stands on a mountain
## range risen through the sea (scripts/sky_peaks.gd `blocks`), in a
## towering cumulus (scripts/sky_towers.gd `blocks`) or by a forested isle
## (scripts/sky_forest_isles.gd).
##
## Each bobs gently on its own slow beat. The glide reads them as solids
## (`body`); touching down slowly on one perches the wanderer there
## (`islet_at`, scripts/wanderer_eye.gd), and the one perched on is never
## let go (`pinned`).

const SkyIslet = preload("res://scripts/sky_islet.gd")
const IslandShore = preload("res://scripts/island_shore.gd")
const Strata = preload("res://scripts/strata.gd")
const Emergence = preload("res://scripts/emergence.gd")
const MeadowFlowers = preload("res://scripts/meadow_flower_mesh.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const HeroTrees = preload("res://scripts/hero_trees.gd")
const FlowFalls = preload("res://scripts/flow_falls.gd")
const WaterFlowView = preload("res://scripts/water_flow_view.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const SkyFallThread = preload("res://scripts/sky_fall_thread.gd")

## The cells: size (m), the share holding an islet, how far its spot may sit
## from the cell's middle (share of the cell), and the height band (m).
const CELL := 170.0
const HOLDS := 0.5
const JITTER := 0.3
const BAND := Vector2(-40.0,45.0)
## A salt for the islets' hashes, apart from the islands'.
const SALT := 1000
## No islet within this far (plate plane) of an island's spot.
const CLEAR := 95.0
## Built within VIEW of the eye, let go beyond FORGET; BUILDS a frame at
## most, the cells looked over every CHECK seconds.
const VIEW := 900.0
const FORGET := 1050.0
const BUILDS := 1
const MAKING := 2
const CHECK := 0.25
## How far away the trees, the stones, the small plants and the fall's
## droplets still draw (m).
const TREE_RANGE := 420.0
const STONE_RANGE := 320.0
const PLANT_RANGE := 170.0
const SPRAY_RANGE := 260.0
## The earth sides' mist takes over this far over the rock's tip (m), and
## the islets share a few strata (scripts/strata.gd), by seed.
const MIST := 0.6
const STRATA_SEEDS := 8
## The bob: metres up and down, and its period (s, min to max).
const BOB := 0.35
const BOB_PERIOD := Vector2(7.0,11.0)
## The fall: its rings (the waterfalls' strand, shaders/flow_fall.gdshader),
## how far it falls before breaking up (share of the stone's depth, plus m),
## the water's speed off the lip (m/s), and its strength (0 to 1).
const FALL_RINGS := 24
const FALL_DROP := Vector2(0.5,7.0)
const FALL_TAIL := 9.0
const FALL_SPEED := 1.4
const FALL_STRENGTH := 0.55
const DROPS := 36
const FOAM := Color("f2f7f8")
## The plate's ground and still water read maps laid over the plate's own
## 32 m (zs_water_map: heights, water, shade), in their mesh's local x, z.
## An islet's meshes are laid this far off its middle, and their nodes set
## back by as much, so those reads fall off the maps and come to nothing,
## instead of picking up the plate's ponds and slopes under the islet.
const OFF_MAP := Vector3(200.0,0.0,200.0)
## Walking on one: a trunk's footprint (m) and how far in from the rim the
## feet stop when not stepping off.
const TRUNK := 0.35

## The cells (scripts/sky_cells.gd), for the islands' spots and the origin.
var cells: SkyCells
## Built islets by cell key: {node, shape, home, cell, phase, period}.
var built := {}
## Each cell's spot (home) or null, as worked out.
var _spots := {}
## The islet perched on, never let go.
var pinned: Node3D
## The plate's live terrain and still-water materials, drawn with as they
## are (SkyIslands sets them); without them, stand-ins.
var ground_source: Material
var water_source: Material
## The plate's earth-sides material (the skirt's), for the shore wall and
## the rock; and the plate's garden view (GardenView), whose catalog the
## plants are drawn from. Without them, stand-ins and an offline catalog.
var side_source: Material
var flora_source: Node
## The sides' materials made so far, by strata seed and depth.
var _sides := {}
var _water: Material
var _since := CHECK
var _clock := 0.0
var _wanted: Array = []
## Islets being worked out on workers, by cell key: {task, cell, home, out}.
var _making := {}

static var _ground_material: ShaderMaterial
static var _water_material: ShaderMaterial
static var _tree_meshes := {}
static var _canopy_tint := Color.WHITE
static var _ring_mesh: ArrayMesh
static var _drop_mesh: SphereMesh
static var _drop_material: ParticleProcessMaterial
## The plate's plant catalog (`catalog`), and each part's material made safe
## for the sky (`_plant_material`).
static var _catalog := {}
static var _plant_materials := {}

func _init() -> void:
	name = "SkyIslets"

## The shared pieces are static, so they would outlive the scene and show as
## leaks at exit; they go with the islets and are made again if wanted.
func _exit_tree() -> void:
	clear()
	_water = null
	_ground_material = null
	_water_material = null
	_tree_meshes.clear()
	_catalog = {}
	_plant_materials.clear()
	SkyIslet.forget_grids()
	_ring_mesh = null
	_drop_mesh = null
	_drop_material = null

## Starts over on new cells: every islet goes, and they grow again round the
## eye as the glide goes on.
func reset(new_cells: SkyCells) -> void:
	clear()
	_prepare()
	if _tree_meshes.is_empty(): _grow_trees()
	if _catalog.is_empty(): catalog(flora_source)
	_water = null
	_sides.clear()
	_pond_material()
	cells = new_cells
	_spots.clear()
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
	_wanted.clear()
	pinned = null

func islet_count() -> int:
	return built.size()

## Each frame of the glide: follow the origin, bob, and every CHECK seconds
## see which cells round the eye want an islet; build a few of those.
func advance(delta: float, eye: Vector3) -> void:
	if cells == null: return
	position = cells.origin
	_clock += delta
	for key in built:
		var b: Dictionary = built[key]
		(b.node as Node3D).position = (b.home as Vector3)+Vector3.UP*BOB*sin(_clock*TAU/float(b.period)+float(b.phase))
	_since += delta
	if _since >= CHECK:
		_since = 0.0
		_survey(eye-cells.origin)
	# Islets the workers have finished stand up, BUILDS a frame.
	var made := 0
	for key in _making.keys():
		if made >= BUILDS: break
		var m: Dictionary = _making[key]
		if not WorkerThreadPool.is_task_completed(m.task): continue
		WorkerThreadPool.wait_for_task_completion(m.task)
		_making.erase(key)
		_finish(m.cell,m.home,m.out)
		made += 1
	while _making.size() < MAKING and not _wanted.is_empty():
		var cell: Vector2i = _wanted.pop_front()
		if built.has(_key(cell)) or _making.has(_key(cell)): continue
		var home: Variant = spot(cell)
		if home == null: continue
		_start(cell,home)

## Waits for every islet being made and stands it up (tests, probes).
func flush() -> void:
	for key in _making.keys():
		var m: Dictionary = _making[key]
		WorkerThreadPool.wait_for_task_completion(m.task)
		_finish(m.cell,m.home,m.out)
	_making.clear()

## The cells within VIEW of `home` (the eye in home coordinates) without an
## islet yet, nearest first; and built ones beyond FORGET let go.
func _survey(home: Vector3) -> void:
	var gone := []
	for key in built:
		var b: Dictionary = built[key]
		if b.node == pinned: continue
		if _flat(b.home,home) > FORGET: gone.append(key)
	for key in gone:
		(built[key].node as Node3D).queue_free()
		built.erase(key)
	var lo := Vector2i(floori((home.x-VIEW)/CELL),floori((home.z-VIEW)/CELL))
	var hi := Vector2i(floori((home.x+VIEW)/CELL),floori((home.z+VIEW)/CELL))
	var wanted := []
	for x in range(lo.x,hi.x+1):
		for z in range(lo.y,hi.y+1):
			var cell := Vector2i(x,z)
			if built.has(_key(cell)) or _making.has(_key(cell)): continue
			var s: Variant = spot(cell)
			if s == null or _flat(s,home) > VIEW: continue
			wanted.append([_flat(s,home),cell])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_wanted = wanted.map(func(w: Array) -> Vector2i: return w[1])

## The cell's islet spot (home), or null: a share of cells hold one, jittered
## in the cell, at a height in the band, unless an island's spot is too near.
func spot(cell: Vector2i) -> Variant:
	var key := _key(cell)
	if _spots.has(key): return _spots[key]
	var here: Variant = raw(cell)
	if here != null and cells != null and not cells.spots_near(here,CLEAR).is_empty(): here = null
	if here != null and (SkyPeaks.blocks(here) or SkyTowers.blocks(here)): here = null
	if here != null and SkyForestIsles.blocks(here,CLEAR*0.3): here = null
	_spots[key] = here
	return here

static func raw(cell: Vector2i) -> Variant:
	if SkyCells.noise(cell,SALT) >= HOLDS: return null
	var middle := (Vector2(cell)+Vector2.ONE*0.5)*CELL
	var off := Vector2(SkyCells.noise(cell,SALT+1)-0.5,SkyCells.noise(cell,SALT+2)-0.5)*2.0*JITTER*CELL
	return Vector3(middle.x+off.x,lerpf(BAND.x,BAND.y,SkyCells.noise(cell,SALT+3)),middle.y+off.y)

static func seed_of(cell: Vector2i) -> int:
	return int(SkyCells.noise(cell,SALT+4)*16777216.0)

# --- Building one -------------------------------------------------------------

func _build(cell: Vector2i, home: Vector3) -> void:
	_start(cell,home)
	flush()

## Sets a worker making the islet for `cell`: its shape, the arrays of its
## top, sides and pond, its plants' buffers and its fall's rings, all plain
## data.
func _start(cell: Vector2i, home: Vector3) -> void:
	_prepare()
	if _catalog.is_empty(): catalog(flora_source)
	var out := {}
	var task := WorkerThreadPool.add_task(_make.bind(seed_of(cell),_ground_palette(),_catalog.data,out),false,"Sky islet")
	_making[_key(cell)] = {"task":task,"cell":cell,"home":home,"out":out}

static func _make(seed_value: int, palette: Dictionary, plants: Dictionary, out: Dictionary) -> void:
	var began := Time.get_ticks_usec()
	var shape: RefCounted = SkyIslet.make(seed_value)
	out.shape = shape
	out.top = shape.top_arrays(palette,OFF_MAP)
	out.sides = shape.side_arrays()
	out.water = shape.water_arrays(WaterFlowView.TINT.mid.srgb_to_linear(),OFF_MAP)
	out.plants = shape.flora(plants)
	if not (out.water as Array).is_empty(): out.fall = _fall_rings(shape)
	out.usec = Time.get_ticks_usec()-began

## The worker's islet, stood up as nodes.
func _finish(cell: Vector2i, home: Vector3, out: Dictionary) -> void:
	var shape: RefCounted = out.shape
	var node := Node3D.new()
	node.name = "Islet_%d_%d" % [cell.x,cell.y]
	node.position = home
	add_child(node)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = SkyIslet.mesh_from(out.top,ground_source if ground_source != null else _ground_material)
	body.position = -OFF_MAP
	node.add_child(body)
	var sides := MeshInstance3D.new()
	sides.name = "Sides"
	sides.mesh = SkyIslet.mesh_from(out.sides,_side_material(shape))
	node.add_child(sides)
	if not (out.water as Array).is_empty():
		var pond := MeshInstance3D.new()
		pond.name = "Pond"
		pond.mesh = SkyIslet.mesh_from(out.water,_pond_material(),SkyIslet.WATER_FORMAT)
		pond.position = -OFF_MAP
		pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pond.set_meta("skip_reflection",true)
		node.add_child(pond)
		_fall(node,shape,out.fall)
	_plant(node,out.plants)
	var rng := RandomNumberGenerator.new()
	rng.seed = shape.seed
	built[_key(cell)] = {"node":node,"shape":shape,"home":home,"cell":cell,"usec":out.get("usec",0),
		"phase":rng.randf()*TAU,"period":rng.randf_range(BOB_PERIOD.x,BOB_PERIOD.y)}

## The plants: one batch a catalog part standing on this islet, drawn with
## the plate's own mesh and its material made safe for the sky. Trees draw
## far, stones a little less, the small plants only near.
func _plant(node: Node3D, plants: Dictionary) -> void:
	var meshes: Dictionary = _catalog.meshes
	for key: String in plants:
		if not meshes.has(key): continue
		var batch := MultiMeshInstance3D.new()
		batch.name = key.replace(":","_")
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = meshes[key]
		multimesh.instance_count = int(plants[key].count)
		multimesh.buffer = plants[key].buffer
		batch.multimesh = multimesh
		batch.material_override = _plant_material(key)
		var role: String = _catalog.roles.get(key,"plant")
		batch.visibility_range_end = TREE_RANGE if role == "tree" else (STONE_RANGE if role == "stone" else PLANT_RANGE)
		batch.visibility_range_end_margin = 30.0
		batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# Small plants cast no shadow worth drawing out here, but the tall
		# sunflowers.
		if role == "plant" and MeadowFlowers.kind_of_part(key) != "sunflower":
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(batch)

## The plate's plant catalog, read once from its garden view (`source`, the
## live GardenView) or, without one, from an offline one: per part key its
## mesh, its material, its box and its role (tree, stone or plant), and the
## plain data a worker plants with (`data`: parts, poses, tints, the world's
## variety and the boxes; GardenInstanceSamples `add_item`).
static func catalog(source: Node = null) -> Dictionary:
	if not _catalog.is_empty(): return _catalog
	var view: Node = source if source != null and source.get("_meshes") is Dictionary and not (source.get("_meshes") as Dictionary).is_empty() else null
	var own: Node = null
	if view == null:
		own = GardenView.new()
		own._ready()
		view = own
	var meshes: Dictionary = (view.get("_meshes") as Dictionary).duplicate()
	var materials: Dictionary = (view.get("_materials") as Dictionary).duplicate()
	var parts: Dictionary = (view.get("_catalog_parts") as Dictionary).duplicate(true)
	var poses: Dictionary = (view.get("_catalog_poses") as Dictionary).duplicate(true)
	var tints: Dictionary = (view.get("_tints") as Dictionary).duplicate(true)
	if own != null: own.free()
	var boxes := {}
	for key: String in meshes:
		if meshes[key] is Mesh: boxes[key] = (meshes[key] as Mesh).get_aabb()
	var roles := {}
	for tree: String in Emergence.TREES:
		for key: String in parts.get(tree,[]): roles[key] = "tree"
	for group in ["tree_variants","layered_variants"]:
		for key: String in parts.get(group,[]): roles[key] = "tree"
	for key in ["trunk","canopy"]: roles[key] = "tree"
	for stone: String in SkyIslet.BOULDERS+["rock_variants"]:
		for key: String in parts.get(stone,[]): roles[key] = "stone"
	roles["rock"] = "stone"
	_catalog = {"meshes":meshes,"materials":materials,"roles":roles,
		"data":{"parts":parts,"poses":poses,"tints":tints,"boxes":boxes,"world":Variety.world({})}}
	return _catalog

## A catalog part's material for the sky: as the plate draws it, swaying in
## the breeze, but with nothing tied to the plate's own garden: no growth
## wave or births read at the origin, no fire, no tread, no seed clock.
static func _plant_material(key: String) -> Material:
	if _plant_materials.has(key): return _plant_materials[key]
	var source: Variant = (_catalog.materials as Dictionary).get(key)
	var material: Material = (source as Material).duplicate() if source is Material else null
	if material is ShaderMaterial:
		for flag in ["instance_birth_enabled","instance_fire_enabled","tree_tread","plant_growth","flower_cycle","cozy_prop_growth"]:
			(material as ShaderMaterial).set_shader_parameter(flag,false)
	_plant_materials[key] = material
	return material

## The world's ground colours for the top (SkyIslet `top_arrays`), from the
## plate's palette (scripts/native_terrain_palette.gd), linear.
func _ground_palette() -> Dictionary:
	var palette := SkyIslet.plain_palette()
	if palette_source == null: return palette
	for key in ["grass","rock"]:
		var list: Variant = palette_source.get(key)
		if list is Array and not (list as Array).is_empty(): palette[key] = (list as Array).duplicate()
	for key in ["sand","gravel"]:
		if palette_source.get(key) is Color: palette[key] = palette_source.get(key)
	var slope: Variant = palette_source.get("rock_slope")
	if slope is float and slope > 0.0: palette.rock_slope = slope
	return palette

## The shore wall's and rock's material: the plate's earth sides (SkyIslands
## sets `side_source`), its strata in the islet's own frame (one of a few
## seeds), the mist taking over only at the rock's tip. Shared by islets of
## one strata seed and about one depth (`_sides`).
func _side_material(shape: RefCounted) -> Material:
	var strata := posmod(int(shape.seed),STRATA_SEEDS)
	var key := Vector2i(strata,roundi(float(shape.depth)*2.0))
	if _sides.has(key): return _sides[key]
	var m: ShaderMaterial
	if side_source is ShaderMaterial: m = side_source.duplicate()
	else:
		m = ShaderMaterial.new()
		m.shader = preload("res://shaders/reference_surface.gdshader")
		m.set_shader_parameter("flat_faces",true)
		m.set_shader_parameter("base_color",Color.WHITE)
	m.set_shader_parameter("earth_sides",true)
	m.set_shader_parameter("earth_sides_top",SkyIslet.RIM_HEIGHT)
	m.set_shader_parameter("earth_sides_base",-float(key.y)*0.5+MIST)
	Strata.for_seed(strata).apply(m,Vector3.ZERO)
	_sides[key] = m
	return m

## The fall off a spring islet's lip: the waterfalls' strand on a course
## of its own, arcing off the rim and falling free until it breaks into
## strands and droplets, as an edge fall does past the plate's foot; from
## there a soft thread carries it on down to the cloud sea (`_fall`).
## The lip is where the spring's channel leaves the rim (SkyIslet `water`),
## at the water's level; `out` the shore's outward normal there; the wall's
## facet ring stands at most RING_OUT.y past the rim.
static func _fall_rings(shape: RefCounted) -> Dictionary:
	var water: Dictionary = shape.water()
	var lip := Vector3(water.lip.x,water.level,water.lip.y)
	var out := Vector3(water.out.x,0.0,water.out.y)
	var overhang := IslandShore.RING_OUT.y+0.05
	return curtain(lip,out,shape.depth*FALL_DROP.x+FALL_DROP.y,FALL_TAIL,SkyIslet.CHANNEL*0.6,overhang,FALL_STRENGTH)

func _fall(node: Node3D, shape: RefCounted, rings: Dictionary) -> void:
	var water: Dictionary = shape.water()
	var out := Vector3(water.out.x,0.0,water.out.y)
	var curtain_node := MeshInstance3D.new()
	curtain_node.name = "Fall"
	curtain_node.mesh = _ring_mesh
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
	curtain_node.material_override = material
	curtain_node.custom_aabb = rings.bounds
	curtain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curtain_node.set_meta("skip_reflection",true)
	node.add_child(curtain_node)
	var drops := GPUParticles3D.new()
	drops.name = "FallDrops"
	drops.process_material = _drop_material
	drops.amount = DROPS
	drops.lifetime = 1.6
	drops.randomness = 0.5
	drops.local_coords = true
	drops.visibility_aabb = AABB(Vector3(-4,-16,-4),Vector3(8,18,8))
	drops.draw_pass_1 = _drop_mesh
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drops.visibility_range_end = SPRAY_RANGE
	var across: Vector3 = rings.across_axis
	drops.transform = Transform3D(Basis(across,Vector3.UP,out),(rings.bottom_point as Vector3)+Vector3.DOWN*0.3)
	node.add_child(drops)
	# On down to the cloud sea as a soft thread, taking over where the
	# strand breaks up (scripts/sky_fall_thread.gd).
	var lip := Vector3(water.lip.x,water.level,water.lip.y)
	var overhang := IslandShore.RING_OUT.y+0.05
	node.add_child(SkyFallThread.build(lip,out,float(rings.half),SkyFallThread.SEA-node.position.y,shape.seed,float(rings.face_drop),FALL_SPEED,overhang+0.2))

## A fall's rings for shaders/flow_fall.gdshader, in the islet's frame: off
## `lip` (on the rim, at the water's level) out along `out`, clearing the
## grass lip's `overhang`, falling `drop` m as a sheet and `tail` m more as
## it breaks up. As scripts/edge_falls.gd `_rings`, with no face to hug.
static func curtain(lip: Vector3, out: Vector3, drop: float, tail: float, half: float, overhang: float, strength: float) -> Dictionary:
	var bend_rings := 4
	var face_rings := 12
	var bend := [0.0,0.06,0.2,0.45]
	var drops := PackedFloat32Array()
	for r in range(FALL_RINGS):
		if r < bend_rings: drops.append(bend[r])
		elif r < bend_rings+face_rings: drops.append(lerpf(drops[bend_rings-1],drop,float(r-bend_rings+1)/face_rings))
		else: drops.append(drop+tail*float(r-bend_rings-face_rings+1)/(FALL_RINGS-bend_rings-face_rings))
	var last_face := bend_rings+face_rings-1
	var thick := PackedFloat32Array()
	for r in range(FALL_RINGS):
		var below := clampf((drops[r]-drop)/tail,0.0,1.0)
		thick.append(minf((0.035+0.1*strength)*(0.3+0.7*smoothstep(0.0,3.0,float(r)))*(1.0+0.6*below),half*0.5))
	var points := PackedVector3Array()
	for r in range(FALL_RINGS):
		var y := lip.y-drops[r]
		var away := -0.1
		if r > 0:
			var thrown := FALL_SPEED*sqrt(2.0*drops[r]/9.81)
			# Clear of the grass lip that juts past the rim.
			away = maxf(thrown,overhang+thick[r]+0.1)
		points.append(lip+out*away+Vector3.UP*(y-lip.y))
	var across_axis := out.cross(Vector3.UP).normalized()
	var steep := PackedFloat32Array()
	var outward := PackedVector3Array()
	for r in range(FALL_RINGS):
		var tangent := (points[mini(r+1,FALL_RINGS-1)]-points[maxi(r-1,0)]).normalized()
		outward.append(across_axis.cross(tangent).normalized())
		steep.append(clampf(-tangent.y,0.0,1.0))
	var tau := PackedFloat32Array([0.0])
	var travel := PackedFloat32Array([0.0])
	for r in range(1,FALL_RINGS):
		var step := points[r].distance_to(points[r-1])
		tau.append(tau[r-1]+step/(1.0+3.0*steep[r]))
		travel.append(travel[r-1]+step)
	var centers := PackedVector4Array()
	var axis_a := PackedVector4Array()
	var axis_b := PackedVector4Array()
	var aer_steep := PackedVector2Array()
	var travels := PackedFloat32Array()
	for list in [centers,axis_a,axis_b,aer_steep,travels]: list.resize(32)
	var air := 0.0
	var low := Vector3(INF,INF,INF)
	var high := -low
	var widest := 0.0
	for r in range(FALL_RINGS):
		var dt := tau[r]-tau[r-1] if r > 0 else 0.0
		air = minf(1.0,air*pow(0.5,dt)+steep[r]*dt*1.15*(1.0+strength))
		var below := clampf((drops[r]-drop)/tail,0.0,1.0)
		var neck := 0.7 if r == 0 else (0.88 if r < bend_rings else 1.0)
		var width := half*neck*(1.0+0.25*air)*(1.0+0.7*below)
		centers[r] = Vector4(points[r].x,points[r].y,points[r].z,tau[r])
		axis_a[r] = Vector4(across_axis.x,across_axis.y,across_axis.z,width)
		axis_b[r] = Vector4(outward[r].x,outward[r].y,outward[r].z,thick[r])
		aer_steep[r] = Vector2(air,steep[r])
		travels[r] = travel[r]
		low = low.min(points[r])
		high = high.max(points[r])
		widest = maxf(widest,width)
	return {"centers":centers,"across":axis_a,"outward":axis_b,"aer_steep":aer_steep,"travel":travels,
		"bounds":AABB(low,high-low).grow(widest+0.8),"break_from":travel[last_face],
		"break_length":maxf(travel[FALL_RINGS-1]-travel[last_face],0.5),"bottom_point":points[last_face],
		"points":points,"half":half,"across_axis":across_axis,"face_drop":drop}

## The shared pieces, made once: the ground and pond materials, the
## spruces, the fall's ring mesh and its droplets.
static func _prepare() -> void:
	if _ground_material != null: return
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = preload("res://shaders/reference_surface.gdshader")
	_ground_material.set_shader_parameter("flat_faces",true)
	# The ground's palette: green to the grass, earthy to the earth, grey to
	# the rock, so the islets turn with the world's season and biome.
	_ground_material.set_shader_parameter("palette_role",1)
	_ground_material.set_shader_parameter("base_color",Color.WHITE)
	_water_material = ShaderMaterial.new()
	_water_material.shader = preload("res://shaders/islet_pond.gdshader")
	_ring_mesh = FlowFalls._build_ring_mesh(FALL_RINGS)
	_drop_mesh = SphereMesh.new()
	_drop_mesh.radius = 0.035
	_drop_mesh.height = 0.08
	_drop_mesh.radial_segments = 8
	_drop_mesh.rings = 4
	var bead := ShaderMaterial.new()
	bead.shader = preload("res://shaders/water_bead.gdshader")
	bead.render_priority = FlowFalls.SPRAY_PRIORITY
	_drop_mesh.material = bead
	_drop_material = ParticleProcessMaterial.new()
	_drop_material.direction = Vector3(0,-1,0.25)
	_drop_material.spread = 16.0
	_drop_material.initial_velocity_min = 1.0
	_drop_material.initial_velocity_max = 2.6
	_drop_material.gravity = Vector3(0,-9.8,0)
	_drop_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_drop_material.emission_box_extents = Vector3(0.4,0.3,0.06)
	_drop_material.scale_min = 0.5
	_drop_material.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0,Color(FOAM,0.9))
	fade.set_color(1,Color(FOAM,0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	_drop_material.color_ramp = ramp

## A spruce variant's [trunk, crown] in the plate's pine materials, swaying
## as the plate's do but never growing in: the growth wave and births are
## the plate's, read at the origin. The source pine with `--classic-trees`.
static func _tree_parts(variant: int) -> Array:
	if _tree_meshes.is_empty(): _grow_trees()
	return _tree_meshes[variant]

## Every spruce variant's parts at once, from one read of the source
## geometry: done at take-off (`reset`), never mid-glide.
static func _grow_trees() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var materials := []
	var originals := []
	for node_name in ["mesh-8","mesh-9"]:
		var original: MultiMeshInstance3D = source.get_node(node_name)
		var material: ShaderMaterial = original.multimesh.mesh.surface_get_material(0).duplicate()
		material.set_shader_parameter("conifer_sway",true)
		material.set_shader_parameter("plant_growth",false)
		material.set_shader_parameter("instance_birth_enabled",false)
		material.set_shader_parameter("instance_fire_enabled",false)
		material.set_shader_parameter("tree_tread",false)
		materials.append(material)
		originals.append(original.multimesh.mesh)
		if node_name == "mesh-9" and original.multimesh.use_colors and original.multimesh.instance_count > 0:
			_canopy_tint = original.multimesh.get_instance_color(0)
	source.free()
	for variant in range(HeroTrees.SPRUCE.size()):
		var parts: Array
		if HeroTrees.enabled():
			parts = [HeroTrees.spruce_mesh(variant,false,materials[0]),HeroTrees.spruce_mesh(variant,true,materials[1])]
		else:
			parts = []
			for i in range(2):
				var mesh: Mesh = (originals[i] as Mesh).duplicate()
				mesh.surface_set_material(0,materials[i])
				parts.append(mesh)
		_tree_meshes[variant] = parts

## The pond's water: the plate's still water as the live ponds draw it
## (scripts/water_flow_view.gd), with everything tied to the plate's own
## ponds let go: the planar mirror (its plane is the plate's water level),
## the tea map, the falls' churn, the level fade and the algae film. Its sky reflection,
## chop, glints and depth tint stay. Made once per sky (`reset`).
func _pond_material() -> Material:
	if _water != null: return _water
	if water_source == null:
		_water = _water_material
		return _water
	var water: ShaderMaterial = water_source.duplicate()
	water.set_shader_parameter("planar_enabled",false)
	water.set_shader_parameter("hide_pool_surface",false)
	water.set_shader_parameter("planar_levels",Vector2(-1000000.0,-1000000.0))
	water.set_shader_parameter("tea_rect",Vector4.ZERO)
	water.set_shader_parameter("fall_foam_count",0)
	# The plate's algae film is drawn by world position, so out here it lay
	# as blotches unrelated to anything floating; the sky's water is clear.
	water.set_shader_parameter("lake_algae_amount",0.0)
	water.set_shader_parameter("live_level",false)
	water.set_shader_parameter("live_flow_map",false)
	water.set_shader_parameter("flow_edge_fade",false)
	water.set_shader_parameter("shore_distance",true)
	water.set_shader_parameter("depth_tint",true)
	water.set_shader_parameter("tint_shallow",WaterFlowView.TINT.shallow)
	water.set_shader_parameter("tint_mid",WaterFlowView.TINT.mid)
	water.set_shader_parameter("tint_deep",WaterFlowView.TINT.deep)
	water.set_shader_parameter("bed_absorb",WaterFlowView.BED_ABSORB)
	_water = water
	return _water

## The plate's palette (scripts/native_terrain_palette.gd), for the ground.
var palette_source: RefCounted

# --- Reading them -------------------------------------------------------------

## Where a built islet's middle stands now, bob and all, in the frame the
## islands are read in (SkyIslands' own, which is the world's).
func place(b: Dictionary) -> Vector3:
	return position+(b.node as Node3D).position

## The islet whose top holds a global point (plate plane), as its built
## record, or {}.
func islet_at(point: Vector3) -> Dictionary:
	for key in built:
		var b: Dictionary = built[key]
		var local := point-place(b)
		var shape: RefCounted = b.shape
		if absf(local.x) > shape.reach+0.5 or absf(local.z) > shape.reach+0.5: continue
		if shape.inside(Vector2(local.x,local.z)): return b
	return {}

## The islet under a global point as a solid, Vector2(top, underside) in
## global metres (the crowns and the stones count as top), or null.
func body(point: Vector3) -> Variant:
	var b := islet_at(point)
	if b.is_empty(): return null
	var shape: RefCounted = b.shape
	var origin := place(b)
	var local := point-origin
	var at := Vector2(local.x,local.z)
	var y := origin.y
	return Vector2(shape.solid_top(at)+y,shape.underside(at)+y)

## The ground a walker stands on, at a point in the islet's frame, or null
## off it.
static func ground(shape: RefCounted, at: Vector2) -> Variant:
	if not shape.inside(at): return null
	return shape.ground_at(at)

## True where a walker can't step: a trunk, a stone, the pond's water.
static func blocked(shape: RefCounted, at: Vector2) -> bool:
	return shape.blocked(at)

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x,cell.y]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
