extends Node3D
## The mountains of the land far below, where they rise so high they punch
## up through the cloud sea and tower over the sky islands (scripts/
## sky_islands.gd). Each range is a heightfield (scripts/sky_peak.gd): its
## foot under the cloud, wrapped in it, its summits a few hundred metres
## over the islands, and a gorge cut through it that the glide can dive into
## and come out of the far side of, a jet stream running down it.
##
## Ranges are rare: at most one to a CELL (HOLDS of them), seeded, each its
## own height and spread; and the cell the plate first stood in always holds
## HOME, the range within sight of the plate, its crest turned square to it,
## so its long face and the gorge's mouth look back at the plate. Far off a
## range draws coarser faces (LOD_NEAR). Islands and islets never stand within KEEP of a range's middle
## (`blocks`, read by scripts/sky_cells.gd and scripts/sky_islets.gd), and
## the fixed slots are clear of HOME by as much.
##
## Within BUILD of the eye a range is made on a worker (shape, then its
## faces), a frame's work only to stand it up; beyond FORGET it is let go,
## and the same one comes back when flown back to. This node stands at the
## cells' origin, so the swaps that move the world carry the ranges along.
##
## Its faces are drawn with the plate's own ground material, laid OFF_MAP off
## so the plate's maps read nothing on them (as SkyIslets does), its look
## read LOOK_SCALE times larger and its foot gone into the cloud's light. The glide
## reads each as a solid (`body`): giant stone, ridden only where it is no
## steeper than the glide can ride (SkyGlide `stone`). The haze reads their
## spots (`haze_spots`): a range is a landform, not scenery streamed in, so
## it stays in sight further off than the islands do.
##
## The ring (scripts/sky_world.gd): with it on, the cells hold no scattered
## ranges; the world's ranges are HOME and those laid out once for the whole
## world (the band round its edge and the ridges dividing its middle), each
## scaled (`scale_of`: along its crest, in height about the sea, across) and
## only some keeping their gorge (`gorge_of`). Each streams in as a cell's
## does, keyed by its ring cell (`ring_cell`: a row no real cell reaches),
## within its reach (`build_reach`), a ridge's piece drawn coarser near
## (`detail_of`), and far off stands as a coarse skyline (scripts/
## sky_ring.gd), so the ring is in sight right across the world. Nothing
## scattered stands outside the world's bounds or on a ridge (`blocks`).
##
## No pop: a range is made ahead along the glide's way (`_survey`: within
## its reach of the eye, or of where the eye will be LEAD seconds on), its
## meshes made on the worker so standing it up is only adding nodes, one a
## frame; it comes in under its skyline, which fades out over it (SkyRing
## SWAP, `swap_of`), the cloud at its foot fading in with it; let go, the
## skyline fades back in over it before it goes (`_leaving`). The ranges
## within reach of the plate are made ahead as the world starts (`premake`,
## under the loading screen) and kept, so a glide starts among them whole.

const SkyPeak = preload("res://scripts/sky_peak.gd")
## Other landforms of the land below risen through the sea, kept with the
## ranges: each kind a node made the same way (`reset` (cells, currents,
## this node), `clear`, `advance`, `flush`, `body`, `haze_spots`, static
## `blocks`), standing as a child here at the cells' origin, so the ranges'
## readers read them too.
const KINDS := [preload("res://scripts/sky_pillars.gd")]
const SkyCurrentsScript = preload("res://scripts/sky_currents.gd")
## The table mountain within sight of the plate (scripts/sky_tepuis.gd): a
## landform of the same kind, held here so everything that reads the ranges
## (solids, `blocks`, the haze, the clouds' keep-out) reads it too.
const SkyTepuis = preload("res://scripts/sky_tepuis.gd")
## Where every wonder in sight of the plate stands (scripts/sky_homes.gd).
const SkyHomes = preload("res://scripts/sky_homes.gd")
## The world's seed, bounds and ring (scripts/sky_world.gd), and the ring's
## far skyline (scripts/sky_ring.gd).
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyRing = preload("res://scripts/sky_ring.gd")
## The ring's ranges stand in cells (RING_ROW, index): a row no real cell
## reaches (it would lie billions of metres off). Each is made within
## RING_BUILD of the eye and let go past RING_FORGET; past that its skyline
## stands in for it. A dividing ridge's piece, smaller and many together,
## within RIDGE_BUILD and past RIDGE_FORGET (`build_reach`).
const RING_ROW := 1000000
const RING_BUILD := 1800.0
const RING_FORGET := 2200.0
const RIDGE_BUILD := 1400.0
const RIDGE_FORGET := 1750.0
const RIDGE_STRIDE := 2
## Nothing scattered stands within INNER_CLEAR (m) of a dividing ridge's
## footprint (SkyWorld `box_distance`, RIDGE_CLEAR).
const INNER_CLEAR := SkyWorld.RIDGE_CLEAR

## The range in sight of the plate: its middle (home coordinates) and the
## way its crest runs (radians about y; local +x is the crest's way).
const HOME := SkyHomes.RANGE
const HOME_TURN := SkyHomes.RANGE_TURN
## The cells: size (m), the share holding a range, how far its spot may sit
## from the cell's middle (share of the cell); the cell holding the plate's
## first home is (0, 0).
const CELL := 2600.0
const HOLDS := 0.3
## Away from HOME a range stands STATURE of its drawn height and spreads
## SPREAD wider (its frame scaled in x and z), seeded per cell.
const STATURE := Vector2(0.8,1.0)
const SPREAD := Vector2(1.0,1.3)
## Past LOD_NEAR m a range draws its faces at every LOD_STRIDE-th grid point.
const LOD_NEAR := 1300.0
const LOD_STRIDE := 2
const JITTER := 0.12
const SALT := 3000
## Nothing else stands within KEEP (m, plate plane, times its spread) of a
## range's middle.
const KEEP := SkyHomes.RANGE_KEEP
## Made within BUILD of the eye, let go past FORGET.
const BUILD := 2300.0
const FORGET := 2800.0
const CHECK := 0.5
## Laid this far off so the plate's maps read nothing (SkyIslets OFF_MAP).
const OFF_MAP := Vector3(2000.0,0.0,2000.0)
## The jet down the gorge: its height (m).
const JET_Y := 15.0
## A gorge with a pinch: its jet runs this much faster down the slot.
const PINCH_JET := 1.3
## How far off the spruces still draw (m).
const TREE_RANGE := 650.0
## The haze: a range's spot reaches this far out (m) for the gentler curve.
const HAZE_REACH := 820.0
## The cloud wrapped round the foot: puffs, held still; how far (m) the
## line the rock is cut at wanders up over the sea's top, and the height (m)
## over it the rock goes into the cloud's light (reference_surface
## `sea_fray`).
const WRAP_STRENGTH := 0.85
const SEA_FRAY := Vector2(18.0,30.0)
## The plate's look (its field's patches, its rock's strata) read this many
## times larger on a range (reference_surface `look_scale`): the plate's
## mountains are a few metres high, a range a few hundred.
const LOOK_SCALE := 30.0
## How far the rock's light leans to its broad lie from each small face's
## (reference_surface `facet_soft`).
const FACET_SOFT := 0.45

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
var kinds: Array[Node3D] = []
static var _puff_material: ShaderMaterial
static var _quad: QuadMesh
var tepuis: Node3D
## The ring's far skyline (scripts/sky_ring.gd).
var ring: Node3D
## Ahead along the glide's way: a range is made within its reach of where
## the eye will be LEAD seconds on (at most LEAD_MOST m ahead), and let go
## only once past its reach of both.
const LEAD := 12.0
const LEAD_MOST := 500.0
## The eye's way over the plate (home coordinates, m/s), and where it was.
var _way := Vector3.ZERO
var _last := Vector3.INF
## Ranges made in full let go but still fading under their skylines, by
## key: {node, at (msec)}.
var _leaving := {}
## Ranges within reach of the plate made ahead (`premake`) and kept, by
## key: the worker's out ({shape, body, far}), and those being made.
var premade := {}
var _premaking := {}
## Tasks making ranges ahead for a layout gone, waited for and dropped.
var _stale: Array[int] = []

func _init() -> void:
	name = "SkyPeaks"
	for kind: GDScript in KINDS:
		var node: Node3D = kind.new()
		kinds.append(node)
		add_child(node)
	tepuis = SkyTepuis.new()
	add_child(tepuis)
	ring = SkyRing.new()
	add_child(ring)

func _exit_tree() -> void:
	clear()
	_puff_material = null
	_quad = null

## Starts over on new cells: every range goes, and they are made again round
## the eye as the glide goes on.
func reset(new_cells: RefCounted, air: Node3D = null) -> void:
	clear()
	_material = null
	_last = Vector3.INF
	# None stand while the ranges and the stone wonders are off (SkyHomes
	# `peaks`, `stone`).
	if not (SkyHomes.peaks or SkyHomes.stone):
		cells = null
		ring.reset(self)
		return
	cells = new_cells
	currents = air
	_since = CHECK
	position = cells.origin
	# The pillar forests and the tepui only with the other stone wonders.
	if SkyHomes.stone:
		for kind in kinds: kind.reset(new_cells,air,self)
		tepuis.reset(new_cells,air,self)
	ring.reset(self)

## Freed without leaving a tree (made and dropped outside one, as tests
## and probes do), `_exit_tree` never runs: its workers are still waited
## for, since a task never waited on outlives the scripts and crashes the
## engine's exit.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	_wait_all()
	_making.clear()
	for key in _premaking: WorkerThreadPool.wait_for_task_completion(_premaking[key].task)
	_premaking.clear()
	for task in _stale: WorkerThreadPool.wait_for_task_completion(task)
	_stale.clear()

## Waits for every range being made (a premade one, task -1, has none).
func _wait_all() -> void:
	for key in _making:
		if int(_making[key].task) >= 0: WorkerThreadPool.wait_for_task_completion(_making[key].task)

func _drop_leaving() -> void:
	for key in _leaving: (_leaving[key].node as Node3D).queue_free()
	_leaving.clear()

func clear() -> void:
	for kind in kinds: kind.clear()
	_wait_all()
	_making.clear()
	_drop_leaving()
	for key in built:
		(built[key].node as Node3D).queue_free()
		if currents != null: currents.drop_thermals(_jet_key(key))
	built.clear()
	if tepuis != null: tepuis.clear()

func range_count() -> int:
	return built.size()

## Each frame of the glide: follow the origin; every CHECK seconds make the
## ranges within BUILD and let go of those past FORGET; stand up one the
## workers have finished.
func advance(delta: float, eye: Vector3) -> void:
	if cells == null: return
	position = cells.origin
	tepuis.advance(delta,eye)
	var home: Vector3 = eye-cells.origin
	# The eye's way, steadied; a jump (a claim, a new glide) starts it over.
	if _last != Vector3.INF and delta > 0.0 and _last.distance_to(home) < 200.0:
		_way = _way.lerp((home-_last)/delta,clampf(delta*2.0,0.0,1.0))
	else: _way = Vector3.ZERO
	_last = home
	_since += delta
	if _since >= CHECK:
		_since = 0.0
		_survey(home)
	for key in _making.keys():
		var m: Dictionary = _making[key]
		if int(m.task) >= 0:
			if not WorkerThreadPool.is_task_completed(m.task): continue
			WorkerThreadPool.wait_for_task_completion(m.task)
		_making.erase(key)
		_finish(m.cell,m.spot,m.out)
		break
	_fade_leaving()
	for kind in kinds: kind.advance(delta,eye)
	ring.advance()

## The build view (no glide): the ranges stand round the plate as their
## skylines (scripts/sky_ring.gd: the range in sight of the plate's finer),
## warmed on workers as the world starts, none made in full; the world's
## middle at `origin` (global: SkyIslands `origin`). Nothing here waits on
## a worker.
func overview(origin: Vector3) -> void:
	position = origin
	if ring.lines.is_empty() and ring._making.is_empty(): ring.warm(self)
	ring.advance()
	_take_premade()

## Every range made in full let go, its skyline back (the glide over: the
## build view stands on the skylines alone).
func let_go() -> void:
	_wait_all()
	_making.clear()
	_drop_leaving()
	_last = Vector3.INF
	for key in built:
		(built[key].node as Node3D).queue_free()
		if currents != null: currents.drop_thermals(_jet_key(key))
	built.clear()
	_since = CHECK

## Waits for every range being made and stands it up (tests, probes,
## captures).
func flush() -> void:
	for key in _making.keys():
		var m: Dictionary = _making[key]
		if int(m.task) >= 0: WorkerThreadPool.wait_for_task_completion(m.task)
		_finish(m.cell,m.spot,m.out)
	_making.clear()
	# Every swap settled: the skylines gone over the ranges made, back over
	# those let go.
	for key in built: built[key].at = -int(ring.SWAP*1000.0)-1
	_drop_leaving()
	for kind in kinds: kind.flush()
	tepuis.flush()
	ring.flush()
	_fade_leaving()

## How far a range's skyline has faded out over it (SkyRing `_show`): 0
## shown, 1 gone; going over a range just made in full, coming back over
## one let go.
func swap_of(key: String) -> float:
	var swap := 0.0
	if built.has(key): swap = (Time.get_ticks_msec()-int(built[key].get("at",0)))/(ring.SWAP*1000.0)
	elif _leaving.has(key): swap = 1.0-(Time.get_ticks_msec()-int(_leaving[key].at))/(ring.SWAP*1000.0)
	return clampf(swap,0.0,1.0)

## The cloud round each range's foot fades with it (`swap_of`), and a
## range let go goes once its skyline is back over it.
func _fade_leaving() -> void:
	for key in built:
		var wrap: Node = (built[key].node as Node3D).get_node_or_null("Wrap")
		if wrap != null: (wrap as GeometryInstance3D).set_instance_shader_parameter("batch_fade",swap_of(key))
	for key in _leaving.keys():
		var wrap: Node = (_leaving[key].node as Node3D).get_node_or_null("Wrap")
		if wrap != null: (wrap as GeometryInstance3D).set_instance_shader_parameter("batch_fade",swap_of(key))
		if Time.get_ticks_msec()-int(_leaving[key].at) >= ring.SWAP*1000.0:
			(_leaving[key].node as Node3D).queue_free()
			_leaving.erase(key)

## Lets a range made in full go: out of the solids at once; its nodes stay
## under its skyline till that is back over them (a ring range's), or go at
## once.
func _let_go_of(key: String) -> void:
	var b: Dictionary = built[key]
	if currents != null: currents.drop_thermals(_jet_key(key))
	# Still coming in: it goes back out from as far as it had come.
	var shown := swap_of(key)
	built.erase(key)
	if ring.lines.has(key) and ring.lines[key].node != null and ring.whole:
		_leaving[key] = {"node":b.node,"at":Time.get_ticks_msec()-int((1.0-shown)*ring.SWAP*1000.0)}
	else: (b.node as Node3D).queue_free()

# --- Made ahead as the world starts ----------------------------------------------------

## Sets workers making, ahead, every range within its reach of the plate's
## home `home` (home coordinates), so a glide starts among them whole; those
## made for a plate stood elsewhere and now out of reach are let go. None
## with the ranges off; nothing waits on them.
func premake(home: Vector3) -> void:
	if not (SkyHomes.peaks or SkyHomes.stone): return
	if SkyWorld.ring_on() and not SkyWorld.ready(): return
	var wanted := _near(home)
	var stamp := _stamp()
	_take_premade()
	for key in premade.keys():
		if not wanted.has(key) or premade[key].stamp != stamp: premade.erase(key)
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	for key in wanted:
		if premade.has(key) or (_premaking.has(key) and _premaking[key].out.stamp == stamp): continue
		var cell: Vector2i = wanted[key]
		var out := {"stamp":stamp}
		var task := WorkerThreadPool.add_task(_make.bind(seed_of(cell),stature_of(cell),_palette("grass"),_palette("rock"),_gravel(),_snow(),out,gorge_of(cell),detail_of(cell),scale_of(cell).y),false,"Sky peak ahead")
		# One being made for another layout or palette is let finish, and
		# dropped (`_take_premade`).
		if _premaking.has(key): _stale.append(_premaking[key].task)
		_premaking[key] = {"task":task,"out":out}

## What a range made ahead was made for: the layout and the world's
## palette baked into its colours. One made for another is not used.
func _stamp() -> String:
	return "%s|%s|%s|%s|%s" % [SkyWorld._layout_key if SkyWorld.ring_on() else "",str(_palette("grass")),str(_palette("rock")),str(_gravel()),str(_snow())]

## Every range within its reach of a home point, by key: cell.
func _near(home: Vector3) -> Dictionary:
	var out := {}
	var c := cell_of(home)
	for dx in range(-1,2):
		for dz in range(-1,2):
			var cell := c+Vector2i(dx,dz)
			var s: Variant = spot(cell)
			if s != null and Vector2(s.x-home.x,s.z-home.z).length() <= BUILD: out[_key(cell)] = cell
	for cell in ring_cells():
		var s: Vector4 = spot(cell)
		if Vector2(s.x-home.x,s.z-home.z).length() <= build_reach(cell).x: out[_key(cell)] = cell
	return out

func _take_premade() -> void:
	for key in _premaking.keys():
		if not WorkerThreadPool.is_task_completed(_premaking[key].task): continue
		WorkerThreadPool.wait_for_task_completion(_premaking[key].task)
		premade[key] = _premaking[key].out
		_premaking.erase(key)
	for task: int in _stale.duplicate():
		if not WorkerThreadPool.is_task_completed(task): continue
		WorkerThreadPool.wait_for_task_completion(task)
		_stale.erase(task)

## True once every range within reach of `home` is made ahead.
func premade_whole(home: Vector3) -> bool:
	return premade_progress(home) >= 1.0

## The share of the ranges within reach of `home` made ahead (0 to 1).
func premade_progress(home: Vector3) -> float:
	_take_premade()
	if not (SkyHomes.peaks or SkyHomes.stone): return 1.0
	if SkyWorld.ring_on() and not SkyWorld.ready(): return 0.0
	var wanted := _near(home)
	if wanted.is_empty(): return 1.0
	var n := 0
	var stamp := _stamp()
	for key in wanted:
		if premade.has(key) and premade[key].stamp == stamp: n += 1
	return float(n)/float(wanted.size())

func _survey(home: Vector3) -> void:
	# Where the eye will be: along its way, LEAD seconds on.
	var ahead := Vector3(_way.x,0.0,_way.z)*LEAD
	if ahead.length() > LEAD_MOST: ahead = ahead.normalized()*LEAD_MOST
	var lead := home+ahead
	var gone := []
	for key in built:
		var forget: float = build_reach(built[key].cell).y if is_ring(built[key].cell) else FORGET
		if minf(_flat(built[key].home,home),_flat(built[key].home,lead)) > forget: gone.append(key)
	for key in gone: _let_go_of(key)
	# Nearest first, by the nearer of the eye and where it will be.
	var starts := []
	var seen := {}
	for at: Vector3 in [home,lead]:
		var c := cell_of(at)
		for dx in range(-1,2):
			for dz in range(-1,2):
				var cell := c+Vector2i(dx,dz)
				if seen.has(cell): continue
				seen[cell] = true
				var s: Variant = spot(cell)
				if s == null: continue
				var d := minf(Vector2(s.x-home.x,s.z-home.z).length(),Vector2(s.x-lead.x,s.z-lead.z).length())
				if d <= BUILD: starts.append([d,cell,s])
	# The ring's ranges near the eye or ahead of it.
	for cell in ring_cells():
		var s: Vector4 = spot(cell)
		var d := minf(Vector2(s.x-home.x,s.z-home.z).length(),Vector2(s.x-lead.x,s.z-lead.z).length())
		if d <= build_reach(cell).x: starts.append([d,cell,s])
	starts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for st: Array in starts:
		var key := _key(st[1])
		if built.has(key) or _making.has(key): continue
		_start(st[1],st[2])

# --- Where they stand ------------------------------------------------------------

static func cell_of(home: Vector3) -> Vector2i:
	return Vector2i(floori(home.x/CELL+0.5),floori(home.z/CELL+0.5))

## The cell's range: Vector4(x, y, z of its middle (home), turn), or null.
## The plate's cell always holds HOME; a ring cell its ring range; with the
## ring on, no other; elsewhere none stands where its frame would reach into
## the keep of a wonder in sight of the plate (SkyHomes `blocks`) or of one
## of the other kinds kept here.
static func spot(cell: Vector2i) -> Variant:
	if not (SkyHomes.peaks or SkyHomes.stone): return null
	if cell == Vector2i.ZERO: return Vector4(HOME.x,HOME.y,HOME.z,HOME_TURN)
	if is_ring(cell):
		var r: Variant = _ring_range(cell)
		return null if r == null else Vector4(r.at.x,0.0,r.at.z,r.turn)
	if SkyWorld.ring_on(): return null
	if noise(cell,SALT) >= HOLDS: return null
	var middle := Vector2(cell)*CELL
	var off := Vector2(noise(cell,SALT+1)-0.5,noise(cell,SALT+2)-0.5)*2.0*JITTER*CELL
	var at := Vector3(middle.x+off.x,0.0,middle.y+off.y)
	# Its whole frame, spread, clear: no rock stands past it.
	var room := maxf(KEEP,SkyPeak.HALF.length())*spread_of(cell)
	if SkyHomes.blocks(at,room) or (SkyHomes.stone and SkyTepuis.blocks(at,room)): return null
	if SkyHomes.stone:
		for kind: GDScript in KINDS:
			if kind.blocks(at,room): return null
	return Vector4(at.x,0.0,at.z,noise(cell,SALT+3)*TAU)

static func seed_of(cell: Vector2i) -> int:
	if is_ring(cell): return int(_ring_range(cell).seed)
	return int(noise(cell,SALT+4)*16777216.0)

static func stature_of(cell: Vector2i) -> float:
	if is_ring(cell): return float(_ring_range(cell).stature)
	return 1.0 if cell == Vector2i.ZERO else lerpf(STATURE.x,STATURE.y,noise(cell,SALT+5))

static func spread_of(cell: Vector2i) -> float:
	if is_ring(cell):
		var s: Vector3 = _ring_range(cell).scale
		return maxf(s.x,s.z)
	return 1.0 if cell == Vector2i.ZERO else lerpf(SPREAD.x,SPREAD.y,noise(cell,SALT+6))

## A laid range's scale (SkyWorld `layout`: along its crest, in height,
## across), its height about the cloud sea's top; a cell's range spread
## evenly, its height its own.
static func scale_of(cell: Vector2i) -> Vector3:
	if is_ring(cell): return _ring_range(cell).scale
	var spread := spread_of(cell)
	return Vector3(spread,1.0,spread)

## Whether a range keeps its gorge: every cell's does; of the laid ones,
## those the layout keeps (SkyWorld `layout` gorge).
static func gorge_of(cell: Vector2i) -> bool:
	return bool(_ring_range(cell).gorge) if is_ring(cell) else true

## Whether a laid range's far skyline is drawn coarser (SkyRing
## STRIDE_LOW): the band's foothills and far row, the ridges' low stretches
## and spurs.
static func coarse_of(cell: Vector2i) -> bool:
	if not is_ring(cell): return false
	var r: Dictionary = _ring_range(cell)
	return bool(r.get("coarse",r.kind in ["foot","far"]))

## Every how many grid points a range's near faces are drawn (its far ones
## LOD_STRIDE times more): a dividing ridge's piece, squeezed along its
## crest, every RIDGE_STRIDE-th, so its faces are about the band's size.
static func detail_of(cell: Vector2i) -> int:
	return RIDGE_STRIDE if is_ring(cell) and not SkyWorld.in_band(kind_of(cell)) else 1

## How near the eye a laid range is made in full, and how far off it is
## let go (m): a dividing ridge's piece nearer than the band's.
static func build_reach(cell: Vector2i) -> Vector2:
	if SkyWorld.in_band(kind_of(cell)): return Vector2(RING_BUILD,RING_FORGET)
	return Vector2(RIDGE_BUILD,RIDGE_FORGET)

## A laid range's kind (SkyWorld `layout`), or "" for a cell's.
static func kind_of(cell: Vector2i) -> String:
	return str(_ring_range(cell).kind) if is_ring(cell) else ""

## How far a range scaled `height` in height stands raised (m), so its
## heights scale about the cloud sea's top and its foot stays in the sea.
static func lift(height: float) -> float:
	return SkyPeak.SEA*(1.0-height)

## The ring's ranges' cells (SkyWorld `layout`), none with the ring off.
static func ring_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not SkyWorld.ring_on(): return out
	for r: Dictionary in SkyWorld.layout().ranges: out.append(Vector2i(RING_ROW,int(r.index)))
	return out

static func is_ring(cell: Vector2i) -> bool:
	return cell.x == RING_ROW

## A ring cell's range in the layout (SkyWorld `layout`), or null.
static func _ring_range(cell: Vector2i) -> Variant:
	if not SkyWorld.ring_on(): return null
	for r: Dictionary in SkyWorld.layout().ranges:
		if int(r.index) == cell.y: return r
	return null

## True if a home point lies within KEEP (plus `margin`) of a range's middle,
## or (`margin` in) outside the world's bounds (SkyWorld `inside`): where
## nothing scattered may stand. The ring's ranges stand well outside the
## bounds (tests/test_sky_world.gd), so they need no keep of their own here.
static func blocks(home: Vector3, margin := 0.0) -> bool:
	if not SkyWorld.inside(home,margin): return true
	if not (SkyHomes.peaks or SkyHomes.stone): return false
	# The dividing ridges laid through the middle: their whole footprint,
	# and INNER_CLEAR past it.
	if SkyWorld.ring_on():
		for r: Dictionary in SkyWorld.layout().ranges:
			if not SkyWorld.in_band(r.kind) and SkyWorld.box_distance(r,Vector2(home.x,home.z)) < INNER_CLEAR+margin: return true
	var c := cell_of(home)
	for dx in range(-1,2):
		for dz in range(-1,2):
			var s: Variant = spot(c+Vector2i(dx,dz))
			if s != null and Vector2(s.x-home.x,s.z-home.z).length() < KEEP*spread_of(c+Vector2i(dx,dz))+margin: return true
	if not SkyHomes.stone: return false
	for kind: GDScript in KINDS:
		if kind.blocks(home,margin): return true
	return SkyTepuis.blocks(home,margin)

## A hash of a cell, 0 to 1, one per salt (as SkyCells `noise`).
static func noise(cell: Vector2i, salt: int) -> float:
	return SkyWorld.noise(cell,salt)

# --- Making one --------------------------------------------------------------------

func _start(cell: Vector2i, s: Vector4) -> void:
	# Made ahead (`premake`): stood up from the next frame, one a frame.
	var key := _key(cell)
	_take_premade()
	if premade.has(key) and premade[key].stamp == _stamp():
		_making[key] = {"task":-1,"cell":cell,"spot":s,"out":premade[key]}
		return
	# The erosion's native kernel, if built, is found here on the main
	# thread, before a worker asks for it.
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	var out := {}
	var task := WorkerThreadPool.add_task(_make.bind(seed_of(cell),stature_of(cell),_palette("grass"),_palette("rock"),_gravel(),_snow(),out,gorge_of(cell),detail_of(cell),scale_of(cell).y),false,"Sky peak")
	_making[key] = {"task":task,"cell":cell,"spot":s,"out":out}

static func _make(seed_value: int, stature: float, grass: Array, rock: Array, gravel: Color, snow: Color, out: Dictionary, gorge := true, stride := 1, height := 1.0) -> void:
	var shape: RefCounted = SkyPeak.make(seed_value,stature,gorge)
	shape.snowline = maxf(shape.snowline,SkyPeak.snow_floor(height))
	out.shape = shape
	# The meshes made here, so standing the range up is only adding nodes
	# (their material given then).
	out.body = SkyPeak.mesh_from(shape.body_arrays(grass,rock,gravel,OFF_MAP,stride,snow),null)
	out.far = SkyPeak.mesh_from(shape.body_arrays(grass,rock,gravel,OFF_MAP,stride*LOD_STRIDE,snow),null)

## The worker's range, stood up as nodes: its faces, the cloud at its foot,
## and the jet down its gorge.
func _finish(cell: Vector2i, s: Vector4, out: Dictionary) -> void:
	var shape: RefCounted = out.shape
	var node := Node3D.new()
	node.name = "Peak_%d_%d" % [cell.x,cell.y]
	var scale := scale_of(cell)
	node.position = Vector3(s.x,s.y+lift(scale.y),s.z)
	node.rotation.y = s.w
	node.scale = scale
	add_child(node)
	# Near, every face; far, the coarse faces, crossfading between.
	for far in [false,true]:
		var body := MeshInstance3D.new()
		body.name = "BodyFar" if far else "Body"
		var mesh: ArrayMesh = out.far if far else out.body
		mesh.surface_set_material(0,_ground())
		body.mesh = mesh
		body.position = -OFF_MAP
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if far: body.visibility_range_begin = LOD_NEAR
		else: body.visibility_range_end = LOD_NEAR
		body.visibility_range_begin_margin = 80.0
		body.visibility_range_end_margin = 80.0
		body.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# Kilometres off: never in the plate's water's mirror.
		body.set_meta("skip_reflection",true)
		node.add_child(body)
	if not shape.wraps.is_empty(): node.add_child(_wrap(shape))
	if tree_parts.is_valid(): _plant(node,shape)
	var key := _key(cell)
	# One let go and still fading out under its skyline goes now.
	if _leaving.has(key):
		(_leaving[key].node as Node3D).queue_free()
		_leaving.erase(key)
	# A range with its skyline showing comes in under it as that fades out
	# (`swap_of`); one with none showing (the skyline not yet whole, a
	# cell's range) comes in at once.
	var under: bool = ring.showing(key) and ring.whole
	built[key] = {"node":node,"shape":shape,"home":Vector3(s.x,s.y,s.z),"turn":s.w,"cell":cell,"spread":spread_of(cell),"scale":scale,"at":Time.get_ticks_msec() if under else -int(ring.SWAP*1000.0)-1}
	if gorge_of(cell): _jet(key)

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
	m.set_shader_parameter("look_scale",LOOK_SCALE)
	m.set_shader_parameter("facet_soft",FACET_SOFT)
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
	puffs.set_meta("skip_reflection",true)
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
			# Upright and round however the range is scaled.
			var spread := node.scale
			poses.append(Transform3D(Basis.from_scale(Vector3(1.0/spread.x,1.0/spread.y,1.0/spread.z))*Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*t.z/tall),at))
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
			batch.set_meta("skip_reflection",true)
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
	for p: Vector3 in shape.gorge_line(JET_Y,96): points.append(global_of(b,Vector3(p.x,shape.jet_height(p.z,JET_Y),p.z)))
	# Downstream away from the plate; through a range of the band, in toward
	# the world's middle, so a gorge brings a glide back in, never out.
	var away := points[0].distance_squared_to(cells.origin) > points[points.size()-1].distance_squared_to(cells.origin)
	var inward := kind_of(b.cell) != "" and SkyWorld.in_band(kind_of(b.cell))
	if away != inward: points.reverse()
	# Strongest where it threads a pinch's slot.
	currents.add_jet(points,_jet_key(key),SkyCurrentsScript.JET*(PINCH_JET if not shape.pinch.is_empty() else 1.0))

func _jet_key(key: String) -> String:
	return "peak:"+key

# --- Reading them ------------------------------------------------------------------

## A point in a range's own frame from a global one, and back.
func local_of(b: Dictionary, point: Vector3) -> Vector3:
	var scale: Vector3 = b.get("scale",Vector3.ONE)
	var at := (point-position-(b.home as Vector3)-Vector3.UP*lift(scale.y)).rotated(Vector3.UP,-float(b.turn))
	return at/scale

func global_of(b: Dictionary, local: Vector3) -> Vector3:
	var scale: Vector3 = b.get("scale",Vector3.ONE)
	return position+(b.home as Vector3)+Vector3.UP*lift(scale.y)+(local*scale).rotated(Vector3.UP,float(b.turn))

## The range under a global point as a solid, Vector2(its ground's height,
## its underside far under the cloud) in global metres, or null.
func body(point: Vector3) -> Variant:
	# Where two ranges overlap (the ring's meet end to end), the higher.
	var found: Variant = null
	for key in built:
		var b: Dictionary = built[key]
		var local := local_of(b,point)
		var h: Variant = b.shape.height_at(Vector2(local.x,local.z))
		if h == null: continue
		var scale: Vector3 = b.get("scale",Vector3.ONE)
		var y := position.y+float(b.home.y)+lift(scale.y)
		if found == null or float(h)*scale.y+y > (found as Vector2).x: found = Vector2(float(h)*scale.y+y,SkyPeak.BOTTOM*scale.y+y)
	if found != null: return found
	for kind in kinds:
		var b: Variant = kind.body(point)
		if b != null: return b
	return tepuis.body(point)

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
		# The band's take the band's own haze (SkyWorld HAZE_REACH).
		if is_ring(b.cell) and SkyWorld.in_band(kind_of(b.cell)): continue
		var at := position+(b.home as Vector3)
		out.append(Vector4(at.x,at.z,HAZE_REACH*float(b.get("spread",1.0)),1.0))
	for kind in kinds: out.append_array(kind.haze_spots())
	out.append_array(tepuis.haze_spots())
	out.sort_custom(func(a: Vector4, c: Vector4) -> bool: return Vector2(a.x-eye.x,a.y-eye.z).length() < Vector2(c.x-eye.x,c.y-eye.z).length())
	return out

## Each standing range's keep-out for the drifting clouds, nearest `eye`
## first: Vector4(global x, global z, 0, KEEP times its spread).
func keep_spots(eye := Vector3.ZERO) -> Array:
	var out := []
	for key in built:
		var b: Dictionary = built[key]
		var at := position+(b.home as Vector3)
		out.append(Vector4(at.x,at.z,0.0,KEEP*float(b.get("spread",1.0))))
	for kind in kinds: out.append_array(kind.keep_spots())
	out.append_array(tepuis.keep_spots())
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

func _snow() -> Color:
	if palette_source != null and palette_source.get("snow") is Color: return palette_source.snow
	return SkyPeak.SNOW_COLOUR

func _gravel() -> Color:
	if palette_source != null and palette_source.get("gravel") is Color: return palette_source.gravel
	return Color("a8a08c").srgb_to_linear()

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x,cell.y]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
