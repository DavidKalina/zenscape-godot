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
## small tiling noise volume made once a run (scripts/cumulus_noise.gd), drifting up so the
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
## Each lives (`age_of`): it rests unseen over its thermals for REST, then
## climbs up out of the sea over GROW (SkyTower `lobes_at`, the foot heaping
## up first, then the column turret by turret, its crown boiling up faster
## while it rises), stands HOLD, and wanes away over WANE, from the foot up,
## going ragged and see-through, then rests and rises again. It never drifts: it stands
## over its thermals, as a thermal's tower does, and a drift fast enough to
## see would carry it out of its keep into the islands and their air. The
## lives are seeded, so the towers are never in step; the home tower's
## starts RISE_SOON into the glide's first sight of it. Its rising is baked
## in STAGES on a worker, two at a time, and the shader morphs between the
## pair (`morph`), the next pair baked while this one shows. `--tower-pace=N`
## runs the lives N times faster, `--tower-age=S` starts the home tower S
## seconds into its life, `--still-towers` holds them whole and still.
##
## Within BUILD of the eye one is made on a worker, beyond FORGET let go,
## the same one coming back when flown back to; it is far in the haze when
## it comes, and fades in over FADE_IN besides. A sky with its places laid
## by hand (the kit isles', scripts/kit_isle/kit_clouds.gd) gives its own
## spots instead (`fixed`): only those stand, the first rising RISE_SOON in
## as the home tower's does, and no cell, peak or ring layout is read. The node stands at the
## cells' origin, so the swaps that move the world carry the towers along.
## `fade` says how far into one a point is (0 outside, 1 in its heart), for
## the vapour and the muffled wind (scripts/wanderer_eye.gd). Not a solid:
## nothing collides with a cloud.

const SkyCommits = preload("res://scripts/sky_commits.gd")
const SkyTower = preload("res://scripts/sky_tower.gd")
const CumulusNoise = preload("res://scripts/cumulus_noise.gd")
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
## A life (s): resting, rising, standing, waning.
const REST := 120.0
const GROW := 300.0
const HOLD := 840.0
const WANE := 180.0
const LIFE := REST+GROW+HOLD+WANE
## The middle of its standing, where a held tower is kept.
const MATURE := REST+GROW+HOLD*0.5
## The home tower's life starts this long before its rising.
const RISE_SOON := 10.0
## Its rising's baked stages.
const STAGES := 40
## How fast (m/s) its bumps boil up the faster while it rises.
const RISE_BOIL := 2.5
## How far (m) its in-cloud amount recedes, whole waned: the drawn body
## shrinks less (shaders/sky_tower.gdshader ERODE) but goes ragged and
## see-through, so there is little to be in.
const ERODE := 110.0

var cells: RefCounted
var currents: Node3D
## Built towers by cell key: {node, shape, home, cell, material, age (its
## fade in), pair (the stage its texture starts at), baked (stage: bake),
## job (the pair being baked, or {}), ready (finished pairs by stage),
## grown and wane (as shown), heap (its lobes as shown), lift}.
var built := {}
var _making := {}
var _since := CHECK
## The lives' clock (s), how many times faster they run, and an age every
## tower is held at (below 0: none).
var clock := 0.0
var pace := 1.0
var pinned := -1.0
## Hand-laid towers (home coordinates, y 0), or none for the seeded cells'
## (`spot`). The spot at index i stands in for the cell (i, 0): its life
## and its shape are that cell's (the first's the home tower's), its key
## the same, so nothing else in a life changes.
var fixed: Array = []

func _init() -> void:
	name = "SkyTowers"
	for argument: String in preload("res://scripts/launch_args.gd").user_args():
		if argument.begins_with("--tower-pace="): pace = maxf(float(argument.trim_prefix("--tower-pace=")),0.0)
		elif argument.begins_with("--tower-age="): clock = float(argument.trim_prefix("--tower-age="))-phase(Vector2i.ZERO)
		elif argument == "--still-towers": pinned = MATURE

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
	_wait_all()

func _wait_all() -> void:
	for key in _making: WorkerThreadPool.wait_for_task_completion(_making[key].task)
	_making.clear()
	for key in built:
		var b: Dictionary = built[key]
		if not b.job.is_empty():
			WorkerThreadPool.wait_for_task_completion(b.job.task)
			b.job = {}

func clear() -> void:
	_wait_all()
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
	clock += delta*pace
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
	for key in built: _live(built[key],delta)
	for key in built:
		var b: Dictionary = built[key]
		if b.age >= FADE_IN: continue
		b.age = minf(b.age+delta,FADE_IN)
		(b.material as ShaderMaterial).set_shader_parameter("strength",smoothstep(0.0,1.0,b.age/FADE_IN))

## Waits for every tower being made and stands it up, whole at once and
## held there, its life no longer running, unless already held at another
## age (tests, probes, captures).
func flush() -> void:
	if pinned < 0.0: pinned = MATURE
	for key in _making.keys():
		var m: Dictionary = _making[key]
		WorkerThreadPool.wait_for_task_completion(m.task)
		_finish(m.cell,m.spot,m.out)
	_making.clear()
	for key in built:
		var b: Dictionary = built[key]
		b.age = FADE_IN
		(b.material as ShaderMaterial).set_shader_parameter("strength",1.0)
		if not b.job.is_empty():
			WorkerThreadPool.wait_for_task_completion(b.job.task)
			b.ready[b.job.k] = b.job.out
			b.job = {}
		var k := _stage(grown_of(age_of(b.cell)))
		if b.pair != k:
			var out := {}
			_bake_pair(b.shape,k,b.baked,out)
			b.ready[k] = out
		_live(b,0.0,true)

# --- Its life ----------------------------------------------------------------------

## Where a cell's tower is in its life (s, 0 to LIFE).
func age_of(cell: Vector2i) -> float:
	if pinned >= 0.0: return pinned
	return fposmod(clock+phase(cell),LIFE)

## The cell's life's start against the clock: the home tower's comes to
## its rising RISE_SOON in, the others' are seeded.
static func phase(cell: Vector2i) -> float:
	if cell == Vector2i.ZERO: return REST-RISE_SOON
	return SkyPeaks.noise(cell,SALT+5)*LIFE

## How far through its rising (0 to 1) and its waning (0 to 1) at an age.
static func grown_of(age: float) -> float:
	return clampf((age-REST)/GROW,0.0,1.0)

static func wane_of(age: float) -> float:
	return clampf((age-REST-GROW-HOLD)/WANE,0.0,1.0)

## The pair of stages a grown amount shows, the first of the two.
static func _stage(grown: float) -> int:
	return clampi(floori(grown*STAGES),0,STAGES-1)

## A frame of a tower's life: stand up the pair of stages its rising has
## come to once baked, bake the next ahead, and set its morph, waning and
## boil. A pair later than wanted (a new life starting) keeps it
## hidden till the right one is baked. `now` stands up a ready pair
## whatever the frame's share.
func _live(b: Dictionary, delta: float, now := false) -> void:
	var age := age_of(b.cell)
	var grown := grown_of(age)
	var k := _stage(grown)
	if not b.job.is_empty() and WorkerThreadPool.is_task_completed(b.job.task):
		WorkerThreadPool.wait_for_task_completion(b.job.task)
		b.ready[b.job.k] = b.job.out
		b.job = {}
	var material: ShaderMaterial = b.material
	if b.pair != k and b.ready.has(k) and (now or SkyCommits.open()):
		var began := Time.get_ticks_usec()
		var out: Dictionary = b.ready[k]
		b.baked = {k:out.a,k+1:out.b}
		material.set_shader_parameter("body",SkyTower.pair_texture(out.a,out.slices))
		b.pair = k
		SkyCommits.spend("cumulus",Time.get_ticks_usec()-began)
	for stage: int in b.ready.keys():
		if stage < k or (stage > k+1 and stage != 0): b.ready.erase(stage)
	# Bake the pair wanted, else the next ahead while it rises.
	if b.job.is_empty():
		var want := -1
		if b.pair != k and not b.ready.has(k): want = k
		elif grown < 1.0 and k+1 < STAGES and not b.ready.has(k+1): want = k+1
		elif grown >= 1.0 and wane_of(age) > 0.5 and not b.ready.has(0): want = 0
		if want >= 0:
			var out := {}
			b.job = {"k":want,"out":out,"task":WorkerThreadPool.add_task(_bake_pair.bind(b.shape,want,b.baked.duplicate(),out),false,"Sky tower stage")}
	var morph := clampf(grown*STAGES-b.pair,0.0,1.0)
	b.grown = (b.pair+morph)/STAGES
	b.wane = wane_of(age) if b.pair <= k else 1.0
	b.heap = (b.shape as RefCounted).lobes_at(b.grown)
	if grown > 0.0 and grown < 1.0: b.lift += RISE_BOIL*delta*pace
	material.set_shader_parameter("morph",morph)
	material.set_shader_parameter("wane",b.wane)
	material.set_shader_parameter("lift",b.lift)
	material.set_shader_parameter("top",minf(b.shape.front(b.grown),b.shape.top()))

## Bakes a pair of stages (k and k+1) of a tower's rising, reusing those in
## `have`, and their two-channel slices: {a, b, slices}. Safe on a worker.
static func _bake_pair(shape: RefCounted, k: int, have: Dictionary, out: Dictionary) -> void:
	out.a = have[k] if have.has(k) else shape.bake(float(k)/STAGES)
	out.b = have[k+1] if have.has(k+1) else shape.bake(float(k+1)/STAGES)
	out.slices = SkyTower.pair_slices(out.a,out.b)

func _survey(home: Vector3) -> void:
	var gone := []
	for key in built:
		if _flat(built[key].home,home) > FORGET: gone.append(key)
	for key in gone:
		if not built[key].job.is_empty(): WorkerThreadPool.wait_for_task_completion(built[key].job.task)
		(built[key].node as Node3D).queue_free()
		if currents != null: currents.drop_thermals(_thermal_key(key))
		built.erase(key)
	for pair: Array in _near(home):
		var cell: Vector2i = pair[0]
		var key := _key(cell)
		if built.has(key) or _making.has(key): continue
		var s: Vector3 = pair[1]
		if Vector2(s.x-home.x,s.z-home.z).length() > BUILD: continue
		_start(cell,s)

## The towers that may stand round a home point: [cell, spot] for the
## fixed spots, else for the 3x3 cells round it that hold one.
func _near(home: Vector3) -> Array:
	var out := []
	if not fixed.is_empty():
		for i in range(fixed.size()): out.append([Vector2i(i,0),fixed[i] as Vector3])
		return out
	var c := cell_of(home)
	for dx in range(-1,2):
		for dz in range(-1,2):
			var s: Variant = spot(c+Vector2i(dx,dz))
			if s != null: out.append([c+Vector2i(dx,dz),s])
	return out

## True if a home point lies within KEEP (plus `margin`) of one of these
## towers' middles: the fixed spots', else the cells' (`blocks`).
func keeps(home: Vector3, margin := 0.0) -> bool:
	if fixed.is_empty(): return blocks(home,margin)
	for s: Vector3 in fixed:
		if Vector2(s.x-home.x,s.z-home.z).length() < KEEP+margin: return true
	return false

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
	var k := _stage(grown_of(age_of(cell)))
	var task := WorkerThreadPool.add_task(_make.bind(seed_of(cell),k,out),false,"Sky tower")
	_making[_key(cell)] = {"task":task,"cell":cell,"spot":s,"out":out}

## The tower and the pair of stages (k, k+1) its life has come to.
static func _make(seed_value: int, k: int, out: Dictionary) -> void:
	var shape: RefCounted = SkyTower.make(seed_value)
	out.shape = shape
	out.k = k
	# The volume's slices, and the shared noise's the first time: only the
	# textures are made on the main thread (`_finish`).
	out.pair = {}
	_bake_pair(shape,k,{},out.pair)
	CumulusNoise.slices()

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
	var pair: Dictionary = out.pair
	material.set_shader_parameter("body",SkyTower.pair_texture(pair.a,pair.slices))
	material.set_shader_parameter("cauliflower",CumulusNoise.texture())
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
	built[key] = {"node":node,"shape":shape,"home":s,"cell":cell,"material":material,"age":0.0,
		"pair":int(out.k),"baked":{int(out.k):pair.a,int(out.k)+1:pair.b},"job":{},"ready":{},
		"grown":0.0,"wane":0.0,"heap":PackedVector4Array(),"lift":0.0}
	_live(built[key],0.0)
	_thermals(key)

## Thermals in the tower's heart, so flying in lifts the glide up through
## it (SkyCurrents `add_thermal`); they rise all its life, before it does.
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

# --- Reading them ------------------------------------------------------------------

## A global point in a built tower's own frame.
func local_of(b: Dictionary, point: Vector3) -> Vector3:
	return point-position-(b.home as Vector3)

func global_of(b: Dictionary, local: Vector3) -> Vector3:
	return position+(b.home as Vector3)+local

## How deep (m) a global point is in the nearest built tower's smooth body
## as it stands now (risen and waned so far): below 0 outside, -INF with
## none near or standing.
func depth(point: Vector3) -> float:
	var deepest := -INF
	for key in built:
		var b: Dictionary = built[key]
		if b.wane >= 1.0 or (b.heap as PackedVector4Array).is_empty(): continue
		var local := local_of(b,point)
		if not (b.shape.box as AABB).grow(EDGE).has_point(local): continue
		deepest = maxf(deepest,-b.shape._distance(local,b.heap)-b.wane*ERODE)
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
		if b.wane > 0.5: continue
		var shape: RefCounted = b.shape
		var high: float = minf(shape.top(),shape.front(b.grown))-shape.wide*0.15
		if high <= SkyTower.SEA: continue
		var mid: Vector2 = shape._axis(SkyTower.SEA+shape.tall*0.5)
		var at := global_of(b,Vector3(mid.x,0.0,mid.y))
		out.append([Vector4(at.x,at.z,shape.wide*SCREEN,1.0),Vector2(position.y+SkyTower.SEA,position.y+high)])
	out.sort_custom(func(a: Array, c: Array) -> bool: return Vector2(a[0].x-eye.x,a[0].y-eye.z).length() < Vector2(c[0].x-eye.x,c[0].y-eye.z).length())
	return out.slice(0,4)

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x,cell.y]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
