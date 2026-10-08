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
const IsletLod = preload("res://scripts/islet_lod.gd")

## The cells (m), how far an island may stand off its cell's middle (share
## of the cell), and the share of cells holding one, from the sparse sounds
## to the crowded straits, over a field FIELD m across.
const CELL := 95.0
const JITTER := 0.08
const HOLDS := Vector2(0.7,1.0)
const FIELD := 840.0
const SALT := 5300
## In the crowded straits (where the field holds past SPLIT) a cell holds
## two smaller islands at these odds.
const SPLIT := 0.9
const SPLIT_ODDS := 0.6
## Open water kept between two islands' land at least (m), and how far an
## island's lobes reach past its radius at most (SkyIslet `reach` over
## `radius`). An island squeezed narrower than NARROWEST is left out.
const GAP := 6.0
const LOBE := 1.3
const NARROWEST := 18.0
## How high the rim stands over the water (m): a low bank, so the shore
## meets the sea in beaches and banks (a landform wanting cliffs sets its
## own SEA); the shelf's width (m, from a narrow island's to a broad
## one's) and the bed's depth at its end (m).
const FREEBOARD := Vector2(0.12,0.3)
const SHELF := Vector2(7.0,16.0)
const SHELF_DEPTH := 12.0
## The grid's step: the plate's (SkyIslet STEP) for a small island, coarser
## for a big one, so every island holds about as many points: its width
## over STEP_ACROSS, snapped down to one of STEPS (the hills landform's).
const STEP_ACROSS := 40.0
const STEPS := [SkyIslet.STEP,1.0,4.0/3.0,2.0]
## How far off an island's trees draw (m): nearer than the sky islets',
## for many islands stand in view at once.
const TREE_RANGE := 260.0
## Built within VIEW of the eye, let go past FORGET; MAKING on workers at
## once, the cells looked over every CHECK seconds; a new one fades in
## over FADE_IN. Down by the ocean the air (scripts/sky_haze.gd, thickest
## there) has taken all but a hundredth of an island by VIEW, so none is
## built that the haze would hide.
const VIEW := 680.0
const FORGET := 800.0
const MAKING := 3
const CHECK := 0.25
## Cells newly laid out a survey at most (`_cells_near`).
const PLANS := 30
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
## Each cell's slots, as worked out (`slots`).
var _slots := {}
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
	islets.tree_range = TREE_RANGE
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
	_slots.clear()
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
			_fade(b)
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
		var slot: Vector3i = _wanted.pop_front()
		if built.has(_key(slot)) or _making.has(_key(slot)): continue
		var p: Variant = plan(slot)
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
		_fade(built[key])

## Builds every island within `reach` of `eye` (global) now (tests,
## probes, captures).
func build_near(eye: Vector3, reach := VIEW) -> void:
	var home := eye-_origin
	for slot: Vector3i in _cells_near(home,reach):
		if built.has(_key(slot)) or _making.has(_key(slot)): continue
		var p: Variant = plan(slot)
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
	_wanted = _cells_near(home,VIEW,PLANS).filter(func(c: Vector3i) -> bool: return not built.has(_key(c)) and not _making.has(_key(c)))

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
		if not _slots.has(cell): _slots[cell] = slots(cell)
		for slot: Vector3i in _slots[cell]:
			if not _plans.has(_key(slot)):
				if budget <= 0: continue
				budget -= 1
			var p: Variant = plan(slot)
			if p == null: continue
			var d := _flat(p.home,home)
			if d <= reach: found.append([d,slot])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return found.map(func(f: Array) -> Vector3i: return f[1])

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

## A cell's islands' middles (home xz) before any is left out: none, one
## jittered in the cell, or in the crowded straits (where the field holds
## past SPLIT) now and then two, each in a half of the cell, so the islands
## there stand closer and smaller, coast to coast.
static func spots(cell: Vector2i) -> Array:
	if SkyCells.noise(cell,SALT) >= holds(cell): return []
	var middle := (Vector2(cell)+Vector2.ONE*0.5)*CELL
	var off := Vector2(SkyCells.noise(cell,SALT+1)-0.5,SkyCells.noise(cell,SALT+2)-0.5)*2.0*JITTER*CELL
	if holds(cell) < SPLIT or SkyCells.noise(cell,SALT+9) >= SPLIT_ODDS: return [middle+off]
	var axis := Vector2.from_angle(SkyCells.noise(cell,SALT+10)*PI)*CELL*0.25
	return [middle+axis+off*0.4,middle-axis-off*0.4]

## A cell's island slots (Vector3i: the cell, and which of its islands).
static func slots(cell: Vector2i) -> Array:
	var out := []
	for i in range(spots(cell).size()): out.append(Vector3i(cell.x,cell.y,i))
	return out

## A slot's island middle (home xz), or null.
static func raw(slot: Vector3i) -> Variant:
	var list := spots(Vector2i(slot.x,slot.y))
	return list[slot.z] if slot.z < list.size() else null

## The widest an island at `slot` may be (m): its lobes reach no further
## than half way to the nearest neighbour less GAP.
static func room(slot: Vector3i) -> float:
	var at: Variant = raw(slot)
	if at == null: return 0.0
	var nearest := INF
	for dx in range(-1,2):
		for dz in range(-1,2):
			var others := spots(Vector2i(slot.x+dx,slot.y+dz))
			for k in range(others.size()):
				if dx == 0 and dz == 0 and k == slot.z: continue
				nearest = minf(nearest,(at as Vector2).distance_to(others[k]))
	if nearest == INF: nearest = CELL*2.0
	return maxf(nearest*0.5-GAP*0.5,0.0)/LOBE*2.0

## The slot's own hash, 0 to 1, one per salt.
static func _noise(slot: Vector3i, salt: int) -> float:
	return SkyCells.noise(Vector2i(slot.x,slot.y),salt+slot.z*97)

## A slot's island: {cell, slot, key, landform, width, level (the sea's height
## in its frame), seed, home
## (home coordinates, its middle's height in the world)}, or null. The
## same cell always gives the same one, unless a landform is forced on it.
func plan(slot: Vector3i) -> Variant:
	var key := _key(slot)
	if _plans.has(key): return _plans[key]
	var made: Variant = _plan(slot,forced.get(key,""))
	_plans[key] = made
	return made

func _plan(slot: Vector3i, landform: String) -> Variant:
	var at: Variant = raw(slot)
	if at == null: return null
	var widest := room(slot)
	var home := Vector3(at.x,0.0,at.y)
	if SkyPeaks.blocks(home,widest*0.5*LOBE+GAP): return null
	if landform == "": landform = Landforms.pick(_noise(slot,SALT+5))
	var across := Landforms.across(landform)
	# Most islands broad, as broad as their neighbours leave room for, so
	# coasts nearly touch across the channels.
	var broad := 1.0-pow(1.0-_noise(slot,SALT+6),2.0)
	var width := minf(lerpf(across.x,across.y,broad),widest)
	if width < NARROWEST and not forced.has(_key(slot)): return null
	width = maxf(width,minf(NARROWEST,across.x))
	# The sea meets the landform's own SEA, or its rim stands a seeded
	# freeboard over the water.
	var level := Landforms.sea_level(landform)
	if is_nan(level): level = SkyIslet.RIM_HEIGHT-lerpf(FREEBOARD.x,FREEBOARD.y,_noise(slot,SALT+7))
	home.y = ocean-level
	return {"cell":Vector2i(slot.x,slot.y),"slot":slot,"key":_key(slot),"landform":landform,"width":width,"level":level,
		"seed":int(_noise(slot,SALT+8)*16777216.0),"home":home}

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
	# Far trees as stand-ins (scripts/far_trees.gd) past where the islets
	# draw their own (TREE_RANGE), unless the landform sets its own range
	# (the forest's, nearer).
	if not spec.has("far_trees"): spec.far_trees = TREE_RANGE
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
		# Its coarse top, for far off (scripts/islet_lod.gd).
		made.coarse = IsletLod.coarse(made.top,float(spec.step)*IsletLod.COARSE,IsletLod.levels_of(made.shape))
		made.usec = Time.get_ticks_usec()-began
		out.merge(made),false,"Lower island")
	_making[p.key] = {"task":task,"plan":p,"out":out}

func _stand(p: Dictionary, out: Dictionary) -> void:
	if _home != Vector3.INF and _flat(p.home,_home) > FORGET: return
	var b: Dictionary = islets.stand("Island_%s_%s" % [str(p.key).replace(",","_"),p.landform],p.home,out)
	b.fixed = true
	b.cell = p.cell
	b.landform = p.landform
	b.age = 0.0
	# Drawn by distance: a coarse top far off, each plant kind to a range
	# by its size, trees by their stand-ins past theirs (scripts/islet_lod.gd).
	IsletLod.range_plants(b.node,out.plants,SkyIslets.catalog(),float(out.shape.reach))
	IsletLod.stand_top(b.node,b.node.get_node("Body"),out.get("coarse",[]))
	islets.built[p.key] = b
	built[p.key] = b
	_fade(b)

## A new island's faces fade in (SkyIslets `_fade`), its coarse top too.
func _fade(b: Dictionary) -> void:
	islets._fade(b)
	var far := (b.node as Node3D).get_node_or_null("BodyFar") as GeometryInstance3D
	var body := (b.node as Node3D).get_node_or_null("Body") as GeometryInstance3D
	if far != null and body != null: far.transparency = body.transparency

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
				for slot: Vector3i in slots(Vector2i(x,z)):
					if taken.has(_key(slot)): continue
					var at: Vector2 = raw(slot)
					if SkyPeaks.blocks(Vector3(at.x,0.0,at.y),room(slot)*0.5*LOBE+GAP): continue
					var d := at.distance_to(target)
					if d < best_d:
						best_d = d
						best = slot
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

func _key(slot: Vector3i) -> String:
	return "%d,%d,%d" % [slot.x,slot.y,slot.z]

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
