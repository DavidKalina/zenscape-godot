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
## an island's spot, by the ranges, the cumulus or the forested isles, or
## past the world's bounds (SkyPeaks `blocks`).
##
## SPACING is the density: the side of a cluster's cell (one at most a
## cell). At 850 m with HOLDS 0.8, after the keeps, the default world holds
## about ten: one to every 0.7 km² or so of the open sky left between the
## ranges, a flight passing near one every 800 m or so.
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

const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const Solver = preload("res://scripts/cluster_solver.gd")
const Motifs = preload("res://scripts/cluster_motifs.gd")
const Dresser = preload("res://scripts/cluster_dresser.gd")
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")
const Cabin = preload("res://scripts/cabin.gd")

## The density: a cluster's cell (m), and the share of cells holding one.
const SPACING := 850.0
const HOLDS := 0.8
## Places tried in a cell for one clear of everything.
const TRIES := 8
## How far a cluster's middle may sit off its cell's (share of the cell),
## and its height band (m).
const JITTER := 0.38
const BAND := Vector2(-25.0,25.0)
const SALT := 3100
## Kept clear: of an island's spot, of the ranges, cumulus and isles (m).
const ISLAND_CLEAR := 240.0
const WONDER_CLEAR := 50.0
## Seeded islets keep this far off a cluster's middle.
const KEEP := 120.0
## Planned within VIEW of the eye, let go past FORGET; checked every CHECK s.
const VIEW := 1250.0
const FORGET := 1450.0
const CHECK := 0.5
## The hand-laid showcase's middle (home coordinates).
const SHOWCASE_AT := Vector3(150.0,-6.0,60.0)
## The members' bob (the islets' BOB): one period for a cluster.
const PERIOD := Vector2(8.0,11.0)
## Sails turn (rad/s), beams sweep (rad/s).
const SAIL_SPIN := 0.55
const BEAM_SPIN := 0.45

static func showcase_enabled() -> bool:
	return "--showcase" in OS.get_cmdline_user_args()

static func random_enabled() -> bool:
	return not "--no-clusters" in OS.get_cmdline_user_args()

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
var _since := CHECK
var _clock := 0.0
var _palette := {}

func _init() -> void:
	name = "SkyClusters"
	with_random = random_enabled()
	with_showcase = showcase_enabled()

func _exit_tree() -> void:
	clear()
	Dresser.release()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE: _wait_all()

func _wait_all() -> void:
	for key in clusters:
		var c: Dictionary = clusters[key]
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
	if with_showcase: spots.append({"key":"showcase","at":SHOWCASE_AT,"motif":"showcase","seed":1})
	if with_random:
		var reach := ceili(4400.0/SPACING)
		for x in range(-reach,reach+1):
			for z in range(-reach,reach+1):
				var s: Variant = spot_of(Vector2i(x,z))
				if s == null: continue
				if with_showcase and Vector2(s.at.x-SHOWCASE_AT.x,s.at.z-SHOWCASE_AT.z).length() < SPACING*0.5: continue
				spots.append(s)
	var keep: Array[Vector3] = []
	for s: Dictionary in spots: keep.append(Vector3(s.at.x,s.at.z,KEEP))
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
		if SkyPeaks.blocks(here,WONDER_CLEAR) or SkyTowers.blocks(here,WONDER_CLEAR) or SkyForestIsles.blocks(here,WONDER_CLEAR): continue
		at = here
		break
	if at == null: return null
	var names: Array = Motifs.names()
	var motif: String = names[mini(int(SkyCells.noise(cell,SALT+4)*names.size()),names.size()-1)]
	return {"key":"%d,%d" % [cell.x,cell.y],"at":at,"motif":motif,"seed":int(SkyCells.noise(cell,SALT+5)*16777216.0)}

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
		var plan := Solver.solve(s.motif,int(s.seed))
		var made := {}
		for m: Dictionary in plan.members:
			var dressed := SkyIslets.dress(m.shape,palette,(s.at as Vector3).y+(m.offset as Vector3).y)
			dressed.extra = Dresser.prepare(m,plan)
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
	var b: Dictionary = islets.stand("Cluster_%s_%s" % [str(c.spot.key).replace(",","_"),m.name],home,made)
	b.fixed = true
	b.group = c.group
	b.phase = c.phase
	b.period = c.period
	b.age = 0.0
	b.member = m.name
	b.cluster = c.spot.key
	islets.built["cluster:%s:%s" % [c.spot.key,m.name]] = b
	c.stood[m.name] = b
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
