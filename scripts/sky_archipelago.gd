extends Node3D
## The lower world's archipelago (`--below`, scripts/sky_below.gd): a sea
## under the cloud thick with islands, so flown low the land keeps
## streaming by underneath, with channels of open water between to fly
## down. Each island is framed as the islands above are, the title's chunk
## grown: a top of the plate's ground on its own outline, shore walls in the
## earth sides' rock, but standing in the sea (SkyIslet `sea_foot`), its
## wall going on down into the water and a shelf of bed round it that the
## water lies pale and clear over, deepening off it.
##
## What each island is comes from the landforms' registry (scripts/
## landforms.gd): a name drawn by weight, a width in its range narrowed
## where its neighbours stand close, and its recipe. They are built as the
## sky islets are, through SkyIslet and SkyIslets, into an islets node of
## their own (`islets`), so the glide reads them as solids, touches down and
## perches on them, and the pilot walks them, as on an islet above.
##
## The layout: one island at most a CELL-square cell, in the same home
## coordinates as the sky's cells (scripts/sky_cells.gd), from the world's
## seed (SkyWorld `noise`), so the same sea always holds the same islands.
## How many cells hold one rises and falls over the sea (`holds`, a slow
## field FIELD m across), so there are crowded straits and broader sounds.
## Each stands jittered in its cell; its land reaches no further than
## half the way to its nearest neighbour less GAP, so there is always water
## between; none stands in a range's rock (SkyPeaks `blocks`).
##
## Streaming as the islets: within VIEW of the eye the cells' islands are
## shaped and dressed on workers (MAKING at once, nearest first) and stood
## up one a frame within the sky's frame budget (scripts/sky_commits.gd),
## each fading in; past FORGET they go, never the one stood on. Only the xz
## of the islands' swaps (SkyIslands `origin`) moves them: the sea's height
## is the world's.
##
## `--landform=<name>[,<name>]` stands those landforms on the islands
## nearest ahead of where the plane comes out under the cloud
## (`arrive`), one after another along its way, so each is visited soon.

const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const Landforms = preload("res://scripts/landforms.gd")
const RockLooks = preload("res://scripts/rock_looks.gd")

## The cells (m), how far an island may stand off its cell's middle (share
## of the cell), and the share of cells holding one, from the sparse sounds
## to the crowded straits, over a field FIELD m across.
const CELL := 105.0
const JITTER := 0.3
const HOLDS := Vector2(0.6,0.97)
const FIELD := 840.0
const SALT := 5300
## Open water kept between two islands' land at least (m), and how far an
## island's lobes reach past its radius at most (SkyIslet `reach` over
## `radius`). An island squeezed narrower than NARROWEST is left out.
const GAP := 10.0
const LOBE := 1.3
const NARROWEST := 18.0
## How high the rim stands over the water (m), the shelf's width (m, from a
## narrow island's to a broad one's) and the bed's depth at its end (m).
const FREEBOARD := Vector2(1.4,3.4)
const SHELF := Vector2(7.0,16.0)
const SHELF_DEPTH := 12.0
## The grid's step: the plate's (SkyIslet STEP) for a small island, coarser
## for a big one, so every island holds about as many points: its width
## over STEP_ACROSS, snapped down to one of STEPS (the hills landform's).
const STEP_ACROSS := 40.0
const STEPS := [SkyIslet.STEP,1.0,4.0/3.0,2.0]
## Built within VIEW of the eye, let go past FORGET; MAKING on workers at
## once, the cells looked over every CHECK seconds; a new one fades in
## over FADE_IN.
const VIEW := 1000.0
const FORGET := 1200.0
const MAKING := 3
const CHECK := 0.25
## Cells newly laid out a survey at most (`_cells_near`).
const PLANS := 60
const FADE_IN := 1.4
## The forced landforms (`arrive`): the first this far ahead of the plane,
## each next one this much further on, looked for within NEAR_REACH.
const NEAR_AHEAD := 170.0
const NEAR_GAP := 150.0
const NEAR_REACH := 260.0

## The sea's height in the world (SkyBelow OCEAN).
var ocean := -300.0
## The islands, built as sky islets are, in their own islets node; their
## materials are the sky islets' (`take_materials`).
var islets: Node3D
## The sky islets' ground these islands' was made from (`take_materials`).
var taken_from: Material
## Built islands by cell key: the islets' built records, each with its
## `landform` and `cell`.
var built := {}
## The landforms forced onto cells (`arrive`), by cell key.
var forced := {}
## Each cell's plan or null, as worked out (`plan`).
var _plans := {}
var _making := {}
var _wanted: Array = []
var _since := CHECK
var _palette := {}
var _origin := Vector3.ZERO
## The eye's home when last surveyed: an island made for a cell since left
## behind past FORGET is not stood up.
var _home := Vector3.INF
## The main thread's microseconds in the last `advance`: its survey and its
## standing up (tests, probes).
var spent := {"survey":0,"stand":0}
## The landforms --landform asks for, in order.
var asked: Array = []

func _init() -> void:
	name = "SkyArchipelago"
	islets = SkyIslets.new()
	islets.name = "LowerIslets"
	islets.owns_shared = false
	add_child(islets)
	asked = forced_names()

func _exit_tree() -> void:
	clear()

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	for key in _making: WorkerThreadPool.wait_for_task_completion(_making[key].task)
	_making.clear()

## The landforms `--landform=a,b` asks for, known names only.
static func forced_names() -> Array:
	var out: Array = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--landform="): continue
		for n: String in a.trim_prefix("--landform=").split(",",false):
			if Landforms.has(n) and not n in out: out.append(n)
			elif not Landforms.has(n): push_warning("--landform: no landform %s (%s)" % [n,", ".join(Landforms.names())])
	return out

## The sky islets' materials, palette and catalog, for these islands' look
## to be theirs (once the sky is built: SkyIslands `build`). The ground is
## the plate's, its world-placed looks (the field's patches, the land's
## form, the seasons' paint, all read by height too) taken from the ocean's
## height (`look_shift`), so three hundred metres down it reads as the
## islands above do. True when taken anew.
func take_materials(source: Node3D) -> bool:
	if source == null or source.ground_source == null or source.ground_source == taken_from: return false
	taken_from = source.ground_source
	var ground: Material = source.ground_source.duplicate()
	if ground is ShaderMaterial: (ground as ShaderMaterial).set_shader_parameter("look_shift",Vector3(0.0,ocean,0.0))
	islets.ground_source = ground
	islets.water_source = source.water_source
	islets.side_source = source.side_source
	islets.flora_source = source.flora_source
	islets.palette_source = source.palette_source
	return true

## Every island goes; they grow again round the eye.
func clear() -> void:
	for key in _making: WorkerThreadPool.wait_for_task_completion(_making[key].task)
	_making.clear()
	for key in built:
		var node: Node3D = built[key].node
		if is_instance_valid(node): node.queue_free()
	built.clear()
	islets.built.clear()
	_wanted.clear()
	_plans.clear()
	islets.pinned = null

func island_count() -> int:
	return built.size()

## Each frame the eye is under the cloud or on its way there: follow the
## swaps (`origin`, SkyIslands' added up), fade in the new, and every CHECK
## seconds see which cells round `eye` (global) want an island; stand up
## what the workers have made, one a frame.
func advance(delta: float, eye: Vector3, origin: Vector3) -> void:
	_follow(origin)
	for key in built:
		var b: Dictionary = built[key]
		if float(b.get("age",FADE_IN)) < FADE_IN:
			b.age = float(b.age)+delta
			islets._fade(b)
	_since += delta
	spent.survey = 0
	spent.stand = 0
	if _since >= CHECK:
		_since = 0.0
		var t := Time.get_ticks_usec()
		_survey(eye-_origin)
		spent.survey = Time.get_ticks_usec()-t
	var made := 0
	for key in _making.keys():
		if made >= 1 or not SkyCommits.open(): break
		var m: Dictionary = _making[key]
		if not WorkerThreadPool.is_task_completed(m.task): continue
		WorkerThreadPool.wait_for_task_completion(m.task)
		_making.erase(key)
		var began := Time.get_ticks_usec()
		_stand(m.plan,m.out)
		spent.stand = Time.get_ticks_usec()-began
		SkyCommits.spend("archipelago",spent.stand)
		made += 1
	while _making.size() < MAKING and not _wanted.is_empty():
		var cell: Vector2i = _wanted.pop_front()
		if built.has(_key(cell)) or _making.has(_key(cell)): continue
		var p: Variant = plan(cell)
		if p != null: _start(p)

## Waits for every island being made and stands it up, whole (tests,
## probes, captures).
func flush() -> void:
	for key in _making.keys():
		var m: Dictionary = _making[key]
		WorkerThreadPool.wait_for_task_completion(m.task)
		_stand(m.plan,m.out)
	_making.clear()
	for key in built:
		built[key].age = FADE_IN
		islets._fade(built[key])

## Builds every island within `reach` of `eye` (global) now (tests,
## probes, captures).
func build_near(eye: Vector3, reach := VIEW) -> void:
	var home := eye-_origin
	for cell: Vector2i in _cells_near(home,reach):
		if built.has(_key(cell)) or _making.has(_key(cell)): continue
		var p: Variant = plan(cell)
		if p != null: _start(p)
	flush()

func _follow(origin: Vector3) -> void:
	_origin = Vector3(origin.x,0.0,origin.z)
	islets.position = _origin

## The cells within VIEW of `home` without an island, nearest first; built
## ones past FORGET let go.
func _survey(home: Vector3) -> void:
	_home = home
	var gone := []
	for key in built:
		var b: Dictionary = built[key]
		if b.node == islets.pinned: continue
		if _flat(b.home,home) > FORGET: gone.append(key)
	for key in gone: _forget(key)
	_wanted = _cells_near(home,VIEW,PLANS).filter(func(c: Vector2i) -> bool: return not built.has(_key(c)) and not _making.has(_key(c)))

## Cells whose plan stands within `reach` of `home`, nearest first. At
## most `budget` cells not planned before are planned now, nearest cells
## first, so a fresh stretch of sea is laid out over a few surveys rather
## than in one long frame.
func _cells_near(home: Vector3, reach: float, budget := 1000000) -> Array:
	var lo := Vector2i(floori((home.x-reach)/CELL),floori((home.z-reach)/CELL))
	var hi := Vector2i(floori((home.x+reach)/CELL),floori((home.z+reach)/CELL))
	var cells := []
	for x in range(lo.x,hi.x+1):
		for z in range(lo.y,hi.y+1):
			var middle := (Vector2(x,z)+Vector2.ONE*0.5)*CELL
			cells.append([middle.distance_squared_to(Vector2(home.x,home.z)),Vector2i(x,z)])
	cells.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var found := []
	for entry: Array in cells:
		var cell: Vector2i = entry[1]
		if not _plans.has(_key(cell)):
			if budget <= 0: continue
			budget -= 1
		var p: Variant = plan(cell)
		if p == null: continue
		var d := _flat(p.home,home)
		if d <= reach: found.append([d,cell])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return found.map(func(f: Array) -> Vector2i: return f[1])

# --- The layout -------------------------------------------------------------------

## The share of cells holding an island round `cell`: a smooth field over
## the sea, FIELD m across, between HOLDS.x and HOLDS.y.
static func holds(cell: Vector2i) -> float:
	var at := Vector2(cell)*CELL/FIELD
	var c := Vector2i(floori(at.x),floori(at.y))
	var f := at-Vector2(c)
	f = f*f*(Vector2(3.0,3.0)-2.0*f)
	var a := SkyCells.noise(c,SALT+20)
	var b := SkyCells.noise(c+Vector2i(1,0),SALT+20)
	var d := SkyCells.noise(c+Vector2i(0,1),SALT+20)
	var e := SkyCells.noise(c+Vector2i(1,1),SALT+20)
	var v := lerpf(lerpf(a,b,f.x),lerpf(d,e,f.x),f.y)
	return lerpf(HOLDS.x,HOLDS.y,smoothstep(0.2,0.8,v))

## A cell's island middle (home xz) before any is left out, or null.
static func raw(cell: Vector2i) -> Variant:
	if SkyCells.noise(cell,SALT) >= holds(cell): return null
	var middle := (Vector2(cell)+Vector2.ONE*0.5)*CELL
	return middle+Vector2(SkyCells.noise(cell,SALT+1)-0.5,SkyCells.noise(cell,SALT+2)-0.5)*2.0*JITTER*CELL

## The widest an island at `cell` may be (m): its lobes reach no further
## than half way to the nearest neighbour less GAP.
static func room(cell: Vector2i) -> float:
	var at: Variant = raw(cell)
	if at == null: return 0.0
	var nearest := INF
	for dx in range(-1,2):
		for dz in range(-1,2):
			if dx == 0 and dz == 0: continue
			var other: Variant = raw(cell+Vector2i(dx,dz))
			if other != null: nearest = minf(nearest,(at as Vector2).distance_to(other))
	if nearest == INF: nearest = CELL*2.0
	return maxf(nearest*0.5-GAP*0.5,0.0)/LOBE*2.0

## A cell's island: {cell, key, landform, width, level (the sea's height
## in its frame), seed, home
## (home coordinates, its middle's height in the world)}, or null. The
## same cell always gives the same one, unless a landform is forced on it.
func plan(cell: Vector2i) -> Variant:
	var key := _key(cell)
	if _plans.has(key): return _plans[key]
	var made: Variant = _plan(cell,forced.get(key,""))
	_plans[key] = made
	return made

func _plan(cell: Vector2i, landform: String) -> Variant:
	var at: Variant = raw(cell)
	if at == null: return null
	var widest := room(cell)
	var home := Vector3(at.x,0.0,at.y)
	if SkyPeaks.blocks(home,widest*0.5*LOBE+GAP): return null
	if landform == "": landform = Landforms.pick(SkyCells.noise(cell,SALT+5))
	var across := Landforms.across(landform)
	var width := minf(lerpf(across.x,across.y,SkyCells.noise(cell,SALT+6)),widest)
	if width < NARROWEST and not forced.has(_key(cell)): return null
	width = maxf(width,minf(NARROWEST,across.x))
	# The sea meets the landform's own SEA, or its rim stands a seeded
	# freeboard over the water.
	var level := Landforms.sea_level(landform)
	if is_nan(level): level = SkyIslet.RIM_HEIGHT-lerpf(FREEBOARD.x,FREEBOARD.y,SkyCells.noise(cell,SALT+7))
	home.y = ocean-level
	return {"cell":cell,"key":_key(cell),"landform":landform,"width":width,"level":level,
		"seed":int(SkyCells.noise(cell,SALT+8)*16777216.0),"home":home}

## What makes a landform's recipe an island in the sea, unless it sets them
## itself: its radius, the sea foot (the water at `level` in its frame, the
## shelf by its width), the grid's step by its width, and a rock look by
## its seed.
static func dress_spec(spec: Dictionary, width: float, level: float, seed_value: int) -> void:
	if not spec.has("radius"): spec.radius = width*0.5
	if not spec.has("sea_foot"):
		var t := clampf((width-25.0)/65.0,0.0,1.0)
		spec.sea_foot = {"level":level,"shelf":lerpf(SHELF.x,SHELF.y,t),"depth":SHELF_DEPTH}
	if not spec.has("step"): spec.step = step_for(width)
	if not spec.has("rock"):
		var looks := RockLooks.seeded(seed_value)
		spec.rock = looks.get("rock",looks)

## The grid's step for an island `width` m across: about width over
## STEP_ACROSS, snapped to the steps the landforms share (STEPS), so islands
## of a size share their grids.
static func step_for(width: float) -> float:
	var want := width/STEP_ACROSS
	var best: float = STEPS[0]
	for s: float in STEPS:
		if s <= want+0.001: best = s
	return best

# --- Building -----------------------------------------------------------------------

func _start(p: Dictionary) -> void:
	if _palette.is_empty():
		_palette = islets.prepare_authored()
		Landforms.prepare()
	var out := {}
	var palette := _palette
	var task := WorkerThreadPool.add_task(func() -> void:
		var began := Time.get_ticks_usec()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(p.seed)
		var spec := Landforms.recipe(p.landform,rng,float(p.width))
		dress_spec(spec,float(p.width),float(p.level),int(p.seed))
		var made: Dictionary = SkyIslets.make(int(p.seed),spec,palette,(p.home as Vector3).y)
		made.usec = Time.get_ticks_usec()-began
		out.merge(made),false,"Lower island")
	_making[p.key] = {"task":task,"plan":p,"out":out}

func _stand(p: Dictionary, out: Dictionary) -> void:
	if _home != Vector3.INF and _flat(p.home,_home) > FORGET: return
	var b: Dictionary = islets.stand("Island_%d_%d_%s" % [p.cell.x,p.cell.y,p.landform],p.home,out)
	b.fixed = true
	b.cell = p.cell
	b.landform = p.landform
	b.age = 0.0
	islets.built[p.key] = b
	built[p.key] = b
	islets._fade(b)

func _forget(key: String) -> void:
	var b: Dictionary = built.get(key,{})
	if not b.is_empty() and is_instance_valid(b.node): (b.node as Node3D).queue_free()
	built.erase(key)
	islets.built.erase(key)

# --- Forced landforms ----------------------------------------------------------------

## The plane is on its way down at `eye` (global), heading `way` (xz):
## the landforms --landform asks for are laid on the nearest held cells
## ahead, NEAR_GAP apart along its way, replacing whatever stood there
## (rebuilt if built).
func arrive(eye: Vector3, way: Vector2) -> void:
	if asked.is_empty(): return
	var home := eye-_origin
	way = way.normalized() if way.length() > 0.01 else Vector2(0.0,-1.0)
	var taken := {}
	var laid := {}
	for i in range(asked.size()):
		var target := Vector2(home.x,home.z)+way*(NEAR_AHEAD+NEAR_GAP*i)
		var best: Variant = null
		var best_d := NEAR_REACH
		var lo := Vector2i(floori((target.x-NEAR_REACH)/CELL),floori((target.y-NEAR_REACH)/CELL))
		var hi := Vector2i(floori((target.x+NEAR_REACH)/CELL),floori((target.y+NEAR_REACH)/CELL))
		for x in range(lo.x,hi.x+1):
			for z in range(lo.y,hi.y+1):
				var cell := Vector2i(x,z)
				if taken.has(_key(cell)): continue
				var at: Variant = raw(cell)
				if at == null or SkyPeaks.blocks(Vector3(at.x,0.0,at.y),room(cell)*0.5*LOBE+GAP): continue
				var d := (at as Vector2).distance_to(target)
				if d < best_d:
					best_d = d
					best = cell
		if best == null:
			push_warning("--landform: no island near the way down for %s" % asked[i])
			continue
		taken[_key(best)] = true
		laid[_key(best)] = asked[i]
	# Cells no longer forced, or forced to something else, are planned again.
	for key in forced.keys()+laid.keys():
		if forced.get(key,"") == laid.get(key,""): continue
		_plans.erase(key)
		if built.has(key): _forget(key)
		if _making.has(key):
			WorkerThreadPool.wait_for_task_completion(_making[key].task)
			_making.erase(key)
	forced = laid

## The island built for a forced landform, or {}.
func forced_island(landform: String) -> Dictionary:
	for key in forced:
		if forced[key] == landform and built.has(key): return built[key]
	return {}

# --- Reading them ---------------------------------------------------------------------

## The island under a global point as a solid, Vector2(top, underside), or
## null (SkyIslets `body`).
func body(point: Vector3) -> Variant:
	return islets.body(point)

## The built island whose middle is nearest `point` (global, level) within
## `reach`, or {}.
func nearest(point: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for key in built:
		var b: Dictionary = built[key]
		var d := _flat(islets.place(b),point)
		if d < best_d:
			best_d = d
			best = b
	return best

func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x,cell.y]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
