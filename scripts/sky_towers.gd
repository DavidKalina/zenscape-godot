extends Node3D
## Towering cumulus (scripts/sky_tower.gd): a few huge billowing columns of
## cloud rising out of the cloud sea, hundreds of metres over the sky
## islands, sunlit cauliflower crowns over soft shaded undersides. They are
## soft: the glide flies into one, the view goes into a glowing white (gold
## at golden hour) fog, the wind muffles, a thermal in its heart lifts it,
## and it bursts out the far side.
##
## Each is drawn as a raymarched volume in its box (shaders/sky_tower
## .gdshader): the box's inside faces only start the rays, so the eye can
## be anywhere, in it or out of it, with no geometry to clip or sort. The
## body is the shape's smooth heap of lobes baked into a coarse float 3D
## texture on a worker (SkyTower `bake`); its cauliflower and wisps are one
## small tiling noise volume made once a run (`_noise`), drifting up so the
## crown slowly boils. It draws before the other see-through things
## (RENDER_PRIORITY), so the glide's streaks and the current wisps near the
## eye stay over it when inside; the glide's small drifting clouds, which
## would then show through it, fade where a tower's column stands between
## them and the eye (`screens`, SkyClouds `screen`).
##
## Towers are rare: at most one to a CELL, a share HOLDS of the cells,
## seeded, and the cell the plate first stood in always holds HOME, in sight
## of the plate, clear of its islands and of the mountain range there
## (scripts/sky_peaks.gd). Islands, islets and the glide's small clouds never
## stand within KEEP of a tower's middle (`blocks`, read by scripts/
## sky_cells.gd, sky_islets.gd and sky_clouds.gd).
##
## Within BUILD of the eye one is made on a worker, beyond FORGET let go,
## the same one coming back when flown back to; it is far in the haze when
## it comes, and fades in over FADE_IN besides. The node stands at the
## cells' origin, so the swaps that move the world carry the towers along.
## `fade` says how far into one a point is (0 outside, 1 in its heart), for
## the vapour and the muffled wind (scripts/wanderer_eye.gd). Not a solid:
## nothing collides with a cloud.

const SkyCommits = preload("res://scripts/sky_commits.gd")
const SkyTower = preload("res://scripts/sky_tower.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")

## The tower in sight of the plate (home coordinates; y is its foot's
## middle, the sea at SkyTower.SEA under it).
const HOME := SkyHomes.TOWER
## The cells: size (m), the share holding a tower, how far its spot may sit
## from the cell's middle (share of the cell). The cell holding the plate's
## first home is (0, 0).
const CELL := 2000.0
const HOLDS := 0.16
const JITTER := 0.22
const SALT := 5010
## Nothing else stands within KEEP (m, plate plane) of a tower's middle,
## and a tower keeps REACH clear of a mountain range's.
const KEEP := SkyHomes.TOWER_KEEP
const REACH := 300.0
## Made within BUILD of the eye, let go past FORGET.
const BUILD := 2500.0
const FORGET := 2900.0
const CHECK := 0.5
const FADE_IN := 2.5
## The in-cloud amount: from EDGE metres out of the smooth body (the
## cauliflower swells past it) to DEEP metres in.
const EDGE := 12.0
const DEEP := 30.0
## How much of the glide's vapour (scripts/sky_flight.gd) comes on deep in
## a tower: the volume draws its own fog round the eye, the vapour only
## streams wisps past over it.
const VEIL := 0.0
## The thermals in its heart: how many, how far round the middle (m), how
## high their bases stand over the islands (m), and their key's prefix.
const THERMALS := 3
const THERMAL_RING := 30.0
const THERMAL_BASE := 15.0
## Drawn before the other see-through things (the streaks, the wisps).
const RENDER_PRIORITY := -1
## The column the small clouds hide behind: its radius, a share of the
## trunk's width.
const SCREEN := 0.42
## How far onto a landform's gentler haze (SkyHaze PEAK_REACH): a tower is
## a landmark, standing in the far haze as the ranges do.
const HAZE_FAR := 1.0
## The noise volumes' size (texels a side).
const NOISE := 64

var cells: RefCounted
var currents: Node3D
## Built towers by cell key: {node, shape, home, cell, material, age}.
var built := {}
var _making := {}
var _since := CHECK
static var _cauliflower: ImageTexture3D

func _init() -> void:
	name = "SkyTowers"

func _exit_tree() -> void:
	clear()

func reset(new_cells: RefCounted, air: Node3D = null) -> void:
	clear()
	cells = new_cells
	currents = air
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
	for key in built:
		(built[key].node as Node3D).queue_free()
		if currents != null: currents.drop_thermals(_thermal_key(key))
	built.clear()

func tower_count() -> int:
	return built.size()

## Each frame of the glide: follow the origin; every CHECK seconds make the
## towers within BUILD and let go of those past FORGET; stand up one the
## workers have finished; fade the new ones in.
func advance(delta: float, eye: Vector3) -> void:
	if cells == null: return
	position = cells.origin
	_since += delta
	if _since >= CHECK:
		_since = 0.0
		_survey(eye-cells.origin)
	for key in _making.keys():
		# One a frame, while the frame's share for the sky lasts
		# (scripts/sky_commits.gd).
		if not SkyCommits.open(): break
		var m: Dictionary = _making[key]
		if not WorkerThreadPool.is_task_completed(m.task): continue
		WorkerThreadPool.wait_for_task_completion(m.task)
		_making.erase(key)
		var began := Time.get_ticks_usec()
		_finish(m.cell,m.spot,m.out)
		SkyCommits.spend("cumulus",Time.get_ticks_usec()-began)
		break
	for key in built:
		var b: Dictionary = built[key]
		if b.age >= FADE_IN: continue
		b.age = minf(b.age+delta,FADE_IN)
		(b.material as ShaderMaterial).set_shader_parameter("strength",smoothstep(0.0,1.0,b.age/FADE_IN))

## Waits for every tower being made and stands it up, whole at once
## (tests, probes, captures).
func flush() -> void:
	for key in _making.keys():
		var m: Dictionary = _making[key]
		WorkerThreadPool.wait_for_task_completion(m.task)
		_finish(m.cell,m.spot,m.out)
	_making.clear()
	for key in built:
		built[key].age = FADE_IN
		(built[key].material as ShaderMaterial).set_shader_parameter("strength",1.0)

func _survey(home: Vector3) -> void:
	var gone := []
	for key in built:
		if _flat(built[key].home,home) > FORGET: gone.append(key)
	for key in gone:
		(built[key].node as Node3D).queue_free()
		if currents != null: currents.drop_thermals(_thermal_key(key))
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

## The cell's tower: its middle (home coordinates), or null. The plate's
## cell always holds HOME; another holds one if its hash says so and it is
## clear of every mountain range and kind kept with them (SkyPeaks
## `blocks`) and of every wonder in sight of the plate (SkyHomes `blocks`).
## In the bounded world (SkyWorld `ring_on`) none is scattered: each region
## the ridges cut has its own, laid out with them (SkyWorld `layout`
## towers, one to a cell).
static func spot(cell: Vector2i) -> Variant:
	if cell == Vector2i.ZERO: return HOME
	if SkyWorld.ring_on():
		for at: Vector3 in SkyWorld.layout().towers:
			if cell_of(at) == cell: return at
		return null
	if SkyPeaks.noise(cell,SALT) >= HOLDS: return null
	var middle := Vector2(cell)*CELL
	var off := Vector2(SkyPeaks.noise(cell,SALT+1)-0.5,SkyPeaks.noise(cell,SALT+2)-0.5)*2.0*JITTER*CELL
	var at := Vector3(middle.x+off.x,0.0,middle.y+off.y)
	# Its whole keep clear of every other kind's (REACH is within it).
	if SkyPeaks.blocks(at,KEEP) or SkyHomes.blocks(at,KEEP): return null
	return at

static func seed_of(cell: Vector2i) -> int:
	return int(SkyPeaks.noise(cell,SALT+4)*16777216.0)

## True if a home point lies within KEEP (plus `margin`) of a tower's middle.
static func blocks(home: Vector3, margin := 0.0) -> bool:
	var c := cell_of(home)
	for dx in range(-1,2):
		for dz in range(-1,2):
			var s: Variant = spot(c+Vector2i(dx,dz))
			if s != null and Vector2(s.x-home.x,s.z-home.z).length() < KEEP+margin: return true
	return false

# --- Making one --------------------------------------------------------------------

func _start(cell: Vector2i, s: Vector3) -> void:
	var out := {}
	var task := WorkerThreadPool.add_task(_make.bind(seed_of(cell),out),false,"Sky tower")
	_making[_key(cell)] = {"task":task,"cell":cell,"spot":s,"out":out}

static func _make(seed_value: int, out: Dictionary) -> void:
	var shape: RefCounted = SkyTower.make(seed_value)
	out.shape = shape
	out.baked = shape.bake()
	# The volume's slices, and the shared noise's the first time: only the
	# textures are made on the main thread (`_finish`).
	out.slices = SkyTower.slices_of(out.baked)
	_noise_slices()

## The worker's tower, stood up: its box, drawn by the volume, and the
## thermals in its heart.
func _finish(cell: Vector2i, s: Vector3, out: Dictionary) -> void:
	var shape: RefCounted = out.shape
	var box: AABB = shape.box
	var node := Node3D.new()
	node.name = "Tower_%d_%d" % [cell.x,cell.y]
	node.position = s
	add_child(node)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/sky_tower.gdshader")
	material.render_priority = RENDER_PRIORITY
	material.set_shader_parameter("body",SkyTower.texture_of(out.baked,out.get("slices",[] as Array[Image])))
	material.set_shader_parameter("cauliflower",_noise())
	material.set_shader_parameter("box_mid",box.get_center())
	material.set_shader_parameter("box_half",box.size*0.5)
	material.set_shader_parameter("sea",SkyTower.SEA)
	material.set_shader_parameter("top",shape.top())
	material.set_shader_parameter("haze_far",HAZE_FAR)
	material.set_shader_parameter("strength",0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = shape.seed*3+1
	material.set_shader_parameter("noise_shift",Vector3(rng.randf(),rng.randf(),rng.randf())*500.0)
	var volume := MeshInstance3D.new()
	volume.name = "Volume"
	var mesh := BoxMesh.new()
	mesh.size = box.size
	volume.mesh = mesh
	volume.position = box.get_center()
	volume.material_override = material
	volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(volume)
	var key := _key(cell)
	built[key] = {"node":node,"shape":shape,"home":s,"cell":cell,"material":material,"age":0.0}
	_thermals(key)

## Thermals in the tower's heart, so flying in lifts the glide up through
## it (SkyCurrents `add_thermal`).
func _thermals(key: String) -> void:
	if currents == null or not currents.has_method("add_thermal"): return
	var b: Dictionary = built[key]
	var turn := float(b.shape.seed%360)
	for i in range(THERMALS):
		var a := deg_to_rad(turn)+TAU*i/THERMALS
		var lean: Vector2 = b.shape._axis(THERMAL_BASE)
		var at := Vector3(lean.x+cos(a)*THERMAL_RING,THERMAL_BASE,lean.y+sin(a)*THERMAL_RING)
		currents.add_thermal(position+(b.home as Vector3)+at,_thermal_key(key))

func _thermal_key(key: String) -> String:
	return "tower:"+key

## The tiling noise volume, made once a run: in red the cauliflower's
## round bumps (cellular, inverted so each cell is a dome, two octaves), in
## green the soft wisps (fbm). One texture, so a step reads both at once.
static func _noise() -> ImageTexture3D:
	if _cauliflower != null: return _cauliflower
	_cauliflower = ImageTexture3D.new()
	_cauliflower.create(Image.FORMAT_RG8,NOISE,NOISE,NOISE,false,_noise_slices())
	return _cauliflower

## The noise volume's slices, worked out once a run, on whichever thread
## asks first (a tower's worker, `_make`); the rest wait for them.
static func _noise_slices() -> Array[Image]:
	_noise_lock.lock()
	if _noise_made.is_empty(): _noise_made = _make_noise_slices()
	var made := _noise_made
	_noise_lock.unlock()
	return made

static var _noise_lock := Mutex.new()
static var _noise_made: Array[Image] = []

static func _make_noise_slices() -> Array[Image]:
	var bumps := FastNoiseLite.new()
	bumps.seed = 31
	bumps.noise_type = FastNoiseLite.TYPE_CELLULAR
	bumps.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	bumps.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	bumps.frequency = 5.0/NOISE
	bumps.fractal_type = FastNoiseLite.FRACTAL_FBM
	bumps.fractal_octaves = 2
	bumps.fractal_lacunarity = 3.0
	bumps.fractal_gain = 0.32
	var wisps := FastNoiseLite.new()
	wisps.seed = 57
	wisps.noise_type = FastNoiseLite.TYPE_PERLIN
	wisps.frequency = 7.0/NOISE
	wisps.fractal_type = FastNoiseLite.FRACTAL_FBM
	wisps.fractal_octaves = 3
	var red: Array[Image] = bumps.get_seamless_image_3d(NOISE,NOISE,NOISE,true,0.15,true)
	var green: Array[Image] = wisps.get_seamless_image_3d(NOISE,NOISE,NOISE,false,0.15,true)
	var slices: Array[Image] = []
	for z in range(NOISE):
		var r := red[z].get_data()
		var g := green[z].get_data()
		var both := PackedByteArray()
		both.resize(r.size()*2)
		for i in range(r.size()):
			both[i*2] = r[i]
			both[i*2+1] = g[i]
		slices.append(Image.create_from_data(NOISE,NOISE,false,Image.FORMAT_RG8,both))
	return slices

# --- Reading them ------------------------------------------------------------------

## A global point in a built tower's own frame.
func local_of(b: Dictionary, point: Vector3) -> Vector3:
	return point-position-(b.home as Vector3)

func global_of(b: Dictionary, local: Vector3) -> Vector3:
	return position+(b.home as Vector3)+local

## How deep (m) a global point is in the nearest built tower's smooth body:
## below 0 outside, -INF with none near.
func depth(point: Vector3) -> float:
	var deepest := -INF
	for key in built:
		var b: Dictionary = built[key]
		var local := local_of(b,point)
		if not (b.shape.box as AABB).grow(EDGE).has_point(local): continue
		deepest = maxf(deepest,b.shape.depth(local))
	return deepest

## How far into a tower a global point is: 0 outside it (EDGE clear of
## its body), rising to 1 DEEP inside.
func fade(point: Vector3) -> float:
	var d := depth(point)
	if d == -INF: return 0.0
	return smoothstep(-EDGE,DEEP,d)

## The built towers nearest `eye` as columns the glide's small clouds must
## not show through (SkyClouds `screen`): [Vector4(global x, z, radius, 1),
## Vector2(lowest, highest y)], the column round the trunk's middle.
func screens(eye: Vector3) -> Array:
	var out := []
	for key in built:
		var b: Dictionary = built[key]
		var shape: RefCounted = b.shape
		var mid: Vector2 = shape._axis(SkyTower.SEA+shape.tall*0.5)
		var at := global_of(b,Vector3(mid.x,0.0,mid.y))
		out.append([Vector4(at.x,at.z,shape.wide*SCREEN,1.0),Vector2(position.y+SkyTower.SEA,position.y+shape.top()-shape.wide*0.15)])
	out.sort_custom(func(a: Array, c: Array) -> bool: return Vector2(a[0].x-eye.x,a[0].y-eye.z).length() < Vector2(c[0].x-eye.x,c[0].y-eye.z).length())
	return out.slice(0,4)

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x,cell.y]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
