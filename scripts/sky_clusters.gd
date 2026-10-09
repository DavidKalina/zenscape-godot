extends Node3D
## The sky's clusters: now and then, out in the open sky between the
## islands, a group of islets that reads as one place (a farmstead, a
## fishing hamlet, a lighthouse reef: scripts/cluster_motifs.gd), laid out
## from its motif and a seed (scripts/cluster_solver.gd) and furnished
## (scripts/cluster_dresser.gd). Rare by design: a find, not always in
## view. They stand one to a SPACING-square cell at most (HOLDS of the
## cells), jittered in it, the seeded islets' scatter (scripts/
## sky_islets.gd) kept KEEP clear round each so there is open sky round a
## cluster and lone islets in the gaps; none stands within ISLAND_CLEAR of
## an island's spot, or past the world's bounds (SkyPeaks `blocks`); and
## none where haze would hide it: WALL_CLEAR off the ranges, the walls and
## the band (the mist on their flanks), HAZE_CLEAR inside the band's haze
## curve, TOWER_CLEAR
## past a cumulus tower's keep (its body and the heaped foot round it), so
## a cluster stands in clear air and reads whole from an approach.
##
## SPACING is the density: the side of a cluster's cell (one at most a
## cell). At 850 m with HOLDS 0.8, after the keeps, the default world holds
## about six, each in clear air: one to every km² or so of the open sky
## left between the ranges and the cumulus.
##
## Streaming: within VIEW of the eye a cluster is planned and its members'
## meshes made on a worker, one cluster at a time, nearest first; then its
## members stand up one a frame within the sky's frame budget (scripts/
## sky_commits.gd), nearest member first, each furnished as it stands.
## Past FORGET it goes (never the one the pilot stands on). Each member is
## a fixed record in the islets' own `built` (so the glide reads it as a
## solid and perches on it) in its cluster's `group` (so the pilot on foot
## jumps from one member to the next), every member bobbing as one.
##
## --showcase adds the hand-laid farmstead at SHOWCASE_AT, the first
## showcase's members exactly, laid with the same solver. --no-clusters
## leaves the random ones out.
##
## To visit a motif in the game: --motif=<name> (or several, comma
## separated: --motif=lake,ravine) stands a cluster of that motif near the
## home island, and --motifs-near-home one of every motif (Motifs `names`),
## each on a ring round the home (NEAR_RING m out, wider for more, further
## out where the near rings are taken), NEAR_GAP apart, clear of the
## islands' spots (NEAR_ISLAND), the ranges, walls and band, and the
## cumulus towers, so each is in view soon after take-off.
## --motif-seed=N lays them from seed N (NEAR_SEED otherwise). The random
## clusters stand as ever, but none in a cell's half round a forced one;
## add --no-clusters for the forced ones alone. Their keys are
## "near:<motif>" (tools/capture_clusters.gd visits them). The motifs:
## farmstead, hamlet, reef, lake, falls, forest, stack, ravine, mountain.
##   godot --path . -- --no-title --motif=mountain
##   godot --path . -- --no-title --motifs-near-home --no-clusters
## The Sundered hall (--motif=sundered, `hall_spot`) is laid apart from the
## cells: see SPECIAL.

const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const Solver = preload("res://scripts/cluster_solver.gd")
const Motifs = preload("res://scripts/cluster_motifs.gd")
const Dresser = preload("res://scripts/cluster_dresser.gd")
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")
const Cabin = preload("res://scripts/cabin.gd")
const Sundered = preload("res://scripts/sundered_hall.gd")
const SunderedBuild = preload("res://scripts/sundered_build.gd")

## The density: a cluster's cell (m), and the share of cells holding one.
const SPACING := 850.0
const HOLDS := 0.8
## Places tried in a cell for one clear of everything.
const TRIES := 32
## How far a cluster's middle may sit off its cell's (share of the cell),
## and its height band (m): high enough that a reef's tail and the deepest
## keels stay over the cloud sea's heaps.
const JITTER := 0.38
const BAND := Vector2(-8.0,30.0)
const SALT := 3100
## Kept clear (m): of an island's spot; of the ranges' and walls' boxes and
## the band, past their own keeps (SkyPeaks `blocks`); of the band's haze
## curve (HAZE_CLEAR); of a cumulus tower, past its keep (SkyTowers KEEP,
## about its body's reach); of the forested isles.
const ISLAND_CLEAR := 240.0
const WALL_CLEAR := 100.0
const TOWER_CLEAR := 200.0
const HAZE_CLEAR := 200.0
const WONDER_CLEAR := 50.0
## Seeded islets keep this far off a cluster's middle.
const KEEP := 120.0
## Planned within VIEW of the eye, let go past FORGET; checked every CHECK s.
const VIEW := 1250.0
const FORGET := 1450.0
const CHECK := 0.5
## The hand-laid showcase's middle (home coordinates).
const SHOWCASE_AT := Vector3(150.0,-6.0,60.0)
## The forced motifs' ring round the home (--motif, --motifs-near-home):
## its first radius (m), each wider try's step out, the least gap between
## two forced clusters' middles, how far each keeps off an island's spot,
## their height, and the seed they are laid from by default.
const NEAR_RING := 200.0
const NEAR_STEP := 40.0
## Rings tried out from NEAR_RING, and places tried round each.
const NEAR_STEPS := 14
const NEAR_TURNS := 48
const NEAR_GAP := 190.0
const NEAR_ISLAND := 170.0
const NEAR_Y := 2.0
const NEAR_SEED := 7
## The Sundered hall (scripts/sundered_hall.gd): a motif of its own, too
## long (about a kilometre of line) for a cell, so it never stands in one.
## At most one a world, and only in HALL_ODDS of worlds: tried at HALL_TRIES
## places HALL_RING m out from the home, each try's whole footprint (its
## islands' capsules) kept clear of the islands' spots, the ranges, walls
## and band, the haze and the cumulus (HALL_ISLAND, HALL_TOWER: closer
## than a cluster's middle keeps, since the hall is long and narrow). The random
## clusters and the seeded islets keep HALL_KEEP off its footprint.
## --motif=sundered stands it NEAR_HALL m out, heading away from the home.
const SPECIAL := ["sundered"]
const HALL_ODDS := 0.55
const HALL_TRIES := 48
const HALL_RING := Vector2(900.0,3400.0)
const HALL_KEEP := 140.0
const HALL_BAND := Vector2(-4.0,16.0)
const NEAR_HALL := Vector2(240.0,900.0)
const HALL_SALT := 3900
## The hall's headings tried at a place, and what its footprint keeps clear
## of (m past its islands' reach): an island's spot (the islands are 48 m
## plates; a hall is long, and the sky between the islands' 450 m cells is
## where it threads), a cumulus tower past its keep, the home's spot.
const HALL_TURNS := 12
const HALL_ISLAND := 75.0
const HALL_TOWER := 60.0
const HALL_HOME := 150.0
## The members' bob (the islets' BOB): one period for a cluster.
const PERIOD := Vector2(8.0,11.0)
## Sails turn (rad/s), beams sweep (rad/s).
const SAIL_SPIN := 0.55
const BEAM_SPIN := 0.45

static func showcase_enabled() -> bool:
	return "--showcase" in OS.get_cmdline_user_args()

static func random_enabled() -> bool:
	return not "--no-clusters" in OS.get_cmdline_user_args()

## The motifs forced near the home (--motif=a,b or --motifs-near-home),
## known names only, in order.
static func near_motifs() -> Array:
	var names: Array = Motifs.names()
	var out: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a == "--motifs-near-home":
			for n: String in names+SPECIAL:
				if not n in out: out.append(n)
		elif a.begins_with("--motif="):
			for n: String in a.trim_prefix("--motif=").split(",",false):
				if (n in names or n in SPECIAL) and not n in out: out.append(n)
				elif not (n in names or n in SPECIAL): push_warning("--motif: no motif %s (%s)" % [n,", ".join(names+SPECIAL)])
	return out

static func near_seed() -> int:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--motif-seed="): return int(a.trim_prefix("--motif-seed="))
	return NEAR_SEED

## The islets (SkyIslets) the members stand in, and the scene (daylight).
var islets: Node3D
var scene: Node
var cells: SkyCells
## Every cluster's spot: {key, at (home), motif, seed}, laid out at `reset`.
var spots: Array = []
## Clusters planned or standing, by key: {spot, task, out, plan, waiting
## (members to stand, nearest first), stood (name -> built record), live
## ({sails, beams, lights}), group, phase, period}.
var clusters := {}
## For tests and probes: daylight override (0..1), or -1.
var daylight_override := -1.0
var night := 0.0
var with_random := true
var with_showcase := false
## The motifs stood near the home (`near_motifs`), and their seed.
var with_near: Array = []
var near_seed_value := NEAR_SEED
var _since := CHECK
var _clock := 0.0
var _palette := {}

func _init() -> void:
	name = "SkyClusters"
	with_random = random_enabled()
	with_showcase = showcase_enabled()
	with_near = near_motifs()
	near_seed_value = near_seed()

func _exit_tree() -> void:
	clear()
	Dresser.release()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE: _wait_all()

func _wait_all() -> void:
	for key in clusters:
		var c: Dictionary = clusters[key]
		if c.has("halls"): SunderedBuild.release(c.halls)
		if int(c.get("task",-1)) >= 0:
			WorkerThreadPool.wait_for_task_completion(c.task)
			c.task = -1

func clear() -> void:
	_wait_all()
	for key in clusters.keys(): _forget(key)
	clusters.clear()

## Lays out every cluster's spot over the cells (after the islets'
## `reset`), and keeps the seeded islets off them.
func reset(new_cells: SkyCells) -> void:
	clear()
	cells = new_cells
	spots.clear()
	_palette = islets.prepare_authored()
	# Read on this thread before any worker needs them.
	Cabin.info()
	Dresser._mats()
	SunderedBuild.RuinKit.materials()
	if with_showcase: spots.append({"key":"showcase","at":SHOWCASE_AT,"motif":"showcase","seed":1})
	# The hall first: its footprint is long, and the rest keep off it.
	var hall: Variant = null
	if "sundered" in with_near: hall = near_hall_spot(near_seed_value)
	elif with_random: hall = hall_spot()
	if hall != null: spots.append(hall)
	var forced: Array = spots.duplicate()
	forced.append_array(near_spots(with_near.filter(func(n: String) -> bool: return not n in SPECIAL),near_seed_value,forced))
	spots = forced.duplicate()
	if with_random:
		var reach := ceili(4400.0/SPACING)
		for x in range(-reach,reach+1):
			for z in range(-reach,reach+1):
				var s: Variant = spot_of(Vector2i(x,z))
				if s == null: continue
				if forced.any(func(f: Dictionary) -> bool: return f.get("motif","") != "sundered" and _flat(f.at,s.at) < SPACING*0.5): continue
				if hall_blocks(s.at,KEEP+HALL_KEEP): continue
				spots.append(s)
	var keep: Array[Vector3] = []
	for s: Dictionary in spots:
		if s.motif == "sundered":
			for f: Vector3 in s.footprint: keep.append(Vector3(s.at.x+f.x,s.at.z+f.y,f.z+HALL_KEEP))
		else: keep.append(Vector3(s.at.x,s.at.z,KEEP))
	islets.keep_clear.append_array(keep)
	_since = CHECK

## A cell's cluster ({key, at, motif, seed}), or null: a share of cells
## hold one, jittered, at a height in the band, clear of what must be.
func spot_of(cell: Vector2i) -> Variant:
	if SkyCells.noise(cell,SALT) >= HOLDS: return null
	var middle := (Vector2(cell)+Vector2.ONE*0.5)*SPACING
	# A few seeded places in the cell are tried, the first clear one taken.
	var at: Variant = null
	for k in range(TRIES):
		var off := Vector2(SkyCells.noise(cell,SALT+10+k*2)-0.5,SkyCells.noise(cell,SALT+11+k*2)-0.5)*2.0*JITTER*SPACING
		var here := Vector3(middle.x+off.x,lerpf(BAND.x,BAND.y,SkyCells.noise(cell,SALT+3)),middle.y+off.y)
		if Vector2(here.x,here.z).length() < ISLAND_CLEAR: continue
		if cells != null and not cells.spots_near(here,ISLAND_CLEAR).is_empty(): continue
		if SkyPeaks.blocks(here,WALL_CLEAR) or SkyTowers.blocks(here,TOWER_CLEAR) or SkyForestIsles.blocks(here,WONDER_CLEAR): continue
		if in_haze(here): continue
		at = here
		break
	if at == null: return null
	var names: Array = Motifs.names()
	var motif: String = names[mini(int(SkyCells.noise(cell,SALT+4)*names.size()),names.size()-1)]
	return {"key":"%d,%d" % [cell.x,cell.y],"at":at,"motif":motif,"seed":int(SkyCells.noise(cell,SALT+5)*16777216.0)}

## The spots ({key, at, motif, seed}) of `names` stood near the home: each
## tried round a ring from its own share of the turn, then further either
## way all round, then a ring further out, until one is clear of the islands' spots,
## the ranges and walls, the towers and the haze, and NEAR_GAP off every
## spot in `taken` and those already laid.
func near_spots(names: Array, seed_value: int, taken: Array) -> Array:
	var out: Array = []
	if names.is_empty(): return out
	var ring := maxf(NEAR_RING,NEAR_GAP*names.size()/TAU)
	for i in range(names.size()):
		var at: Variant = null
		for step in range(NEAR_STEPS):
			for k in range(NEAR_TURNS):
				# Its own share of the turn first, then further either way.
				var turn := TAU*float(i)/names.size()+0.35+(TAU/NEAR_TURNS*ceilf(k/2.0)*(1.0 if k % 2 == 0 else -1.0))
				var here := Vector3(cos(turn),0.0,sin(turn))*(ring+step*NEAR_STEP)+Vector3.UP*NEAR_Y
				if (taken+out).any(func(f: Dictionary) -> bool: return f.get("motif","") != "sundered" and _flat(f.at,here) < NEAR_GAP): continue
				if hall_blocks(here,NEAR_GAP*0.5+HALL_KEEP*0.5): continue
				if cells != null and not cells.spots_near(here,NEAR_ISLAND).is_empty(): continue
				if SkyPeaks.blocks(here,WALL_CLEAR) or SkyTowers.blocks(here,TOWER_CLEAR) or SkyForestIsles.blocks(here,WONDER_CLEAR): continue
				if in_haze(here): continue
				at = here
				break
			if at != null: break
		if at == null:
			push_warning("--motif: no clear room near the home for %s" % names[i])
			continue
		out.append({"key":"near:%s" % names[i],"at":at,"motif":names[i],"seed":seed_value})
	return out

## The Sundered hall's spot for this world ({key, at, motif, seed, yaw,
## footprint}), or null: in HALL_ODDS of worlds, the first of HALL_TRIES
## places round the home (each tried at HALL_TURNS headings) whose whole
## footprint is clear.
func hall_spot() -> Variant:
	var cell := Vector2i(17,-23)
	if SkyCells.noise(cell,HALL_SALT) >= HALL_ODDS: return null
	var seed_value := int(SkyCells.noise(cell,HALL_SALT+1)*16777216.0)
	var flat := _hall_footprint(seed_value)
	if flat.is_empty(): return null
	for k in range(HALL_TRIES):
		var turn := SkyCells.noise(cell,HALL_SALT+10+k*3)*TAU
		var ring := lerpf(HALL_RING.x,HALL_RING.y,SkyCells.noise(cell,HALL_SALT+11+k*3))
		var yaw0 := SkyCells.noise(cell,HALL_SALT+12+k*3)*TAU
		var at := Vector3(cos(turn)*ring,lerpf(HALL_BAND.x,HALL_BAND.y,SkyCells.noise(cell,HALL_SALT+2)),sin(turn)*ring)
		for j in range(HALL_TURNS):
			var s: Variant = _hall_at("sundered",at,seed_value,yaw0+TAU*j/HALL_TURNS,flat)
			if s != null: return s
	return null

## The hall stood near the home (--motif=sundered): its gate NEAR_HALL out,
## heading away from the home if it can, else any way round, the first
## clear one.
func near_hall_spot(seed_value: int) -> Variant:
	var flat := _hall_footprint(seed_value)
	for step in range(NEAR_STEPS):
		var ring := lerpf(NEAR_HALL.x,NEAR_HALL.y,float(step)/maxf(NEAR_STEPS-1,1))
		for k in range(NEAR_TURNS):
			var turn := 0.35+TAU/NEAR_TURNS*ceilf(k/2.0)*(1.0 if k % 2 == 0 else -1.0)
			var way := Vector3(cos(turn),0.0,sin(turn))
			var out := atan2(-way.z,way.x)
			for j in range(HALL_TURNS):
				var yaw := out+TAU*ceilf(j/2.0)/HALL_TURNS*(1.0 if j % 2 == 0 else -1.0)
				var s: Variant = _hall_at("near:sundered",way*ring+Vector3.UP*NEAR_Y,seed_value,yaw,flat)
				if s != null:
					print("Sundered hall: its gate %.0f m from the home toward %s (home coordinates), seed %d" % [ring,str((way*ring).snapped(Vector3.ONE)),seed_value])
					return s
	push_warning("--motif: no clear room near the home for sundered")
	return null

## The hall's footprint laid at heading 0 (Sundered `footprint`): a hall
## laid at another heading is the same turned (the layout turns with it).
static func _hall_footprint(seed_value: int) -> Array:
	var layout := Sundered.layout(seed_value,0.0)
	if not Sundered.validate(layout).is_empty(): return []
	return Sundered.footprint(layout)

## The hall laid at `at` heading `yaw`, if its whole footprint (`flat`, at
## heading 0) is clear: of the islands' spots (HALL_ISLAND), the ranges,
## walls and band, the cumulus (HALL_TOWER), the forested isles, the haze
## and the home.
func _hall_at(key: String, at: Vector3, seed_value: int, yaw: float, flat: Array) -> Variant:
	var footprint: Array = []
	for f: Vector3 in flat:
		var p := Vector2(f.x,f.y).rotated(-yaw)
		footprint.append(Vector3(p.x,p.y,f.z))
		var here := at+Vector3(p.x,0.0,p.y)
		if Vector2(here.x,here.z).length() < HALL_HOME+f.z: return null
		if cells != null and not cells.spots_near(here,HALL_ISLAND+f.z).is_empty(): return null
		if SkyPeaks.blocks(here,WALL_CLEAR+f.z) or SkyTowers.blocks(here,HALL_TOWER+f.z) or SkyForestIsles.blocks(here,WONDER_CLEAR+f.z): return null
		if in_haze(here): return null
	return {"key":key,"at":at,"motif":"sundered","seed":seed_value,"yaw":yaw,"footprint":footprint}

## True within `margin` of a laid hall's footprint.
func hall_blocks(home: Vector3, margin: float) -> bool:
	for s: Dictionary in spots:
		if s.motif != "sundered": continue
		for f: Vector3 in s.footprint:
			if Vector2(home.x-s.at.x-f.x,home.z-s.at.z-f.y).length() < f.z+margin: return true
	return false

## True if a home point is on or within HAZE_CLEAR of the band's haze
## curve (SkyWorld `haze_share`), where the band's mist would veil it.
static func in_haze(home: Vector3) -> bool:
	var flat := Vector2(home.x,home.z)
	if flat.length() < 1.0: return false
	return SkyWorld.haze_share(flat*(1.0+HAZE_CLEAR/flat.length())) > 0.0

## Each frame of the glide (the eye in the islets' frame, as the islets'
## `advance` takes it): plan the near, stand what is made, let the far go,
## and turn and light what does.
func advance(delta: float, eye: Vector3) -> void:
	if cells == null: return
	_clock += delta
	var home := eye-cells.origin
	_since += delta
	if _since >= CHECK:
		_since = 0.0
		_survey(home)
	_stand_some(home)
	for key in clusters:
		var c: Dictionary = clusters[key]
		if c.has("halls") and c.has("plan"): SunderedBuild.advance(c.halls,c.plan,home)
	_animate(delta)

func _survey(home: Vector3) -> void:
	for key in clusters.keys():
		var c: Dictionary = clusters[key]
		if _flat(c.spot.at,home) > FORGET and not _holds_perch(c): _forget(key)
	var making := false
	for key in clusters:
		if int(clusters[key].get("task",-1)) >= 0: making = true
	if making: return
	var nearest: Variant = null
	var best := INF
	for s: Dictionary in spots:
		if clusters.has(s.key): continue
		var d := _flat(s.at,home)
		if d < VIEW and d < best:
			best = d
			nearest = s
	if nearest != null: _plan(nearest)

## Plans a cluster on a worker: the solver's plan, each member's meshes and
## its own feature meshes.
func _plan(s: Dictionary) -> void:
	var out := {}
	var palette := _palette
	var task := WorkerThreadPool.add_task(func() -> void:
		var hall: bool = s.motif == "sundered"
		var plan := SunderedBuild.solve(int(s.seed),float(s.yaw)) if hall else Solver.solve(s.motif,int(s.seed))
		var made := {}
		for m: Dictionary in plan.members:
			var dressed := SkyIslets.dress(m.shape,palette,(s.at as Vector3).y+(m.offset as Vector3).y)
			dressed.extra = SunderedBuild.prepare(m,plan) if hall else Dresser.prepare(m,plan)
			made[m.name] = dressed
		out.plan = plan
		out.made = made,false,"Sky cluster")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.seed)
	clusters[s.key] = {"spot":s,"task":task,"out":out,"stood":{},"waiting":[],"group":"cluster:"+str(s.key),
		"phase":rng.randf()*TAU,"period":rng.randf_range(PERIOD.x,PERIOD.y),"live":{"sails":[],"beams":[],"lights":[]}}

## Stands made members, one a frame while the frame's share lasts, nearest
## first.
func _stand_some(home: Vector3) -> void:
	for key in clusters:
		var c: Dictionary = clusters[key]
		if int(c.task) >= 0:
			if not WorkerThreadPool.is_task_completed(c.task): continue
			WorkerThreadPool.wait_for_task_completion(c.task)
			c.task = -1
			c.plan = c.out.plan
			var waiting: Array = (c.plan.members as Array).duplicate()
			var at: Vector3 = c.spot.at
			waiting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _flat(at+a.offset,home) < _flat(at+b.offset,home))
			c.waiting = waiting
		if (c.waiting as Array).is_empty() or not SkyCommits.open(): continue
		var began := Time.get_ticks_usec()
		_stand(c,(c.waiting as Array).pop_front())
		SkyCommits.spend("cluster",Time.get_ticks_usec()-began)
		return

func _stand(c: Dictionary, m: Dictionary) -> void:
	var made: Dictionary = c.out.made[m.name]
	var home: Vector3 = (c.spot.at as Vector3)+(m.offset as Vector3)
	var b: Dictionary = islets.stand("Cluster_%s_%s" % [str(c.spot.key).replace(",","_").replace(":","_"),m.name],home,made)
	b.fixed = true
	b.group = c.group
	b.phase = c.phase
	b.period = c.period
	b.age = 0.0
	b.member = m.name
	b.cluster = c.spot.key
	islets.built["cluster:%s:%s" % [c.spot.key,m.name]] = b
	c.stood[m.name] = b
	if m.has("yaw"): SkyIslets.turn(b,float(m.yaw))
	if c.plan.get("motif","") == "sundered":
		(c.get_or_add("halls",[]) as Array).append(SunderedBuild.furnish(b.node,m,c.plan,made.extra,(c.spot.at as Vector3).y))
		return
	var live := Dresser.furnish(b.node,m,c.plan,made.extra)
	for k in ["sails","beams","lights"]: (c.live[k] as Array).append_array(live[k])

## Stands every planned member of every cluster at once (tests, probes,
## captures).
func flush(home := Vector3.ZERO) -> void:
	for key in clusters:
		var c: Dictionary = clusters[key]
		if int(c.task) >= 0:
			WorkerThreadPool.wait_for_task_completion(c.task)
			c.task = -1
			c.plan = c.out.plan
			c.waiting = (c.plan.members as Array).duplicate()
		while not (c.waiting as Array).is_empty(): _stand(c,(c.waiting as Array).pop_front())
	islets.flush()

## Plans (now, on this thread's wait) the cluster at `key` (tests, probes,
## captures).
func plan_now(key: String) -> void:
	for s: Dictionary in spots:
		if s.key == key and not clusters.has(key): _plan(s)
	flush()

func _forget(key: String) -> void:
	var c: Dictionary = clusters[key]
	if int(c.get("task",-1)) >= 0: WorkerThreadPool.wait_for_task_completion(c.task)
	if c.has("halls"): SunderedBuild.release(c.halls)
	for name_: String in c.stood:
		var b: Dictionary = c.stood[name_]
		if is_instance_valid(b.node): (b.node as Node3D).queue_free()
		islets.built.erase("cluster:%s:%s" % [c.spot.key,name_])
	clusters.erase(key)

func _holds_perch(c: Dictionary) -> bool:
	if islets.pinned == null: return false
	for b: Dictionary in c.stood.values():
		if b.node == islets.pinned: return true
	return false

# --- Night and motion ----------------------------------------------------------------

func daylight() -> float:
	if daylight_override >= 0.0: return daylight_override
	var celestial: Variant = scene.get("_celestial") if scene != null else null
	if celestial != null and celestial.get("state") is Dictionary and celestial.state.has("zs_daylight"):
		return float(celestial.state.zs_daylight)
	return 1.0

func _animate(delta: float) -> void:
	night = move_toward(night,StoneLampLights.night_for(daylight()),delta/2.0)
	Dresser.set_night(night)
	for key in clusters:
		var live: Dictionary = clusters[key].live
		for hub: Node3D in live.sails:
			if is_instance_valid(hub): hub.rotate_object_local(Vector3.BACK,-SAIL_SPIN*delta)
		for beams: Node3D in live.beams:
			if not is_instance_valid(beams): continue
			beams.visible = night > 0.05
			beams.rotate_y(BEAM_SPIN*delta)
		for entry: Array in live.lights:
			var light: OmniLight3D = entry[0]
			if not is_instance_valid(light): continue
			light.visible = night > 0.01
			light.light_energy = float(entry[1])*night

## The members standing, as built records (tests).
func members_of(key: String) -> Dictionary:
	return clusters.get(key,{}).get("stood",{})

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()
