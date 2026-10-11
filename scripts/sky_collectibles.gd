extends Node3D
## The sky's collectible tokens, after the i-points of an island flyover:
## the HUD's glyphs as faceted tokens (scripts/glyph_pickup.gd) littered
## through the sky in short lines, rare enough that each find is a find,
## laid by rule against what they belong to (scripts/collectible_lines.gd):
## along rope bridges and footbridges (bridge), under islets' and islands'
## hanging rock (under), out in the open on a good flying line between
## islands, through a cluster's gaps, under its bridges and round a floating
## mountain's peak (air), and where only the pilot on foot gets to them:
## stepping stones, stairs, docks, perches, ledges, under the trees (foot:
## the walker's alone, the plane passes through them; they turn slower and
## bob gentler in a warmer, wider halo, so they read as worth a landing).
## The same world seed always lays the same ones.
##
## A source is a set of lines and the node they ride with (`add_source`):
## an islet, a cluster's anchor member (its members bob as one), an
## island's copy; or this node, standing at the cells' origin as the islets
## do, for lines laid in home coordinates (the swoops between islands, the
## plate's own). The sky's sources are found as their hosts stand
## (`_survey`, every CHECK s): the islets' and the clusters' laid on a
## worker, one at a time, nearest first (their plane checks are many);
## the islands' here, once their land is baked. Another world layer adds
## its own the same way: `add_source(key, lines, host)`, lines as
## CollectibleLines `line` makes them, in the host's frame.
##
## Streaming: a token stands as nodes only within VIEW of the eye, STANDS a
## frame at most within the sky's frame budget (scripts/sky_commits.gd), its
## motes drifting only within MOTES_NEAR, and goes past FORGET or with its
## host. Beyond that a token is a point in a list: a full sky is a few
## hundred, looked over every CHECK s.
##
## Pickup (`touch`): the walker's middle or the plane passing through a
## token (CollectibleLines WALKER_REACH, PLANE_REACH: the plane's larger, so
## air lines are fair at speed; read along the way moved since the last
## frame, so a fast plane never skips one) takes it: its twist and wisp, a
## quiet readout (scripts/collectibles_hud.gd) and a bright blip, a sparkling
## run over it when its line is whole. Collected tokens are kept with the world (`save_state`, in
## SkyIslands' state) and never stand again.
##
## --no-collectibles leaves them out. --collectibles-near-home lays every
## kind near the home for review: the clusters near the home (SkyClusters
## --motif; a farmstead, a forest hold and a floating mountain unless
## --motif names others) and every host within NEAR_HOME lay every line
## they can, and the swoops off the home island are all laid.

const Lines = preload("res://scripts/collectible_lines.gd")
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const Plate = preload("res://scripts/plate.gd")
const Hud = preload("res://scripts/collectibles_hud.gd")

## Tokens stand within VIEW of the eye (m), go past FORGET; their motes
## drift within MOTES_NEAR; STANDS stand a frame at most; the sources are
## looked over every CHECK s.
const VIEW := 340.0
const FORGET := 380.0
const MOTES_NEAR := 90.0
const STANDS := 4
const CHECK := 0.25
## --collectibles-near-home: hosts within this of the home lay every line.
const NEAR_HOME := 420.0
const NEAR_MOTIFS := ["farmstead","forest","mountain"]
## A mover jumping further than this in a frame (a landing, a claim's
## shift) starts its sweep afresh.
const JUMP := 12.0

static func enabled() -> bool:
	return not "--no-collectibles" in preload("res://scripts/launch_args.gd").user_args()

static func near_home_enabled() -> bool:
	return "--collectibles-near-home" in preload("res://scripts/launch_args.gd").user_args()

## Emitted on each pickup: the token's glyph, how many of that glyph are
## collected now, its line's got and count.
signal picked(glyph: String, glyph_total: int, got: int, count: int)

## What they belong to: the islands (scripts/sky_islands.gd, may be null),
## the islets and the clusters, the cells (home coordinates), the scene
## (to keep the world after a pickup).
var islands: Node3D
var islets: Node3D
var clusters: Node3D
var cells: SkyCells
var scene: Node
var near_home := false
## Every source by key: {key, host (Node3D), lines, live (token id ->
## holder)}. A host freed takes its tokens with it.
var sources := {}
## Tokens collected (id -> glyph), kept with the world.
var collected := {}
## The world seed the lines were laid for.
var seed_value := 0
## The last frame's survey cost (µs), stood tokens and points looked over.
var spent := {}
var hud: CanvasLayer
var _since := CHECK
var _task := -1
var _task_key := ""
var _task_out := {}
var _task_host: Node3D
var _waiting: Array = []
var _stand: Array = []
var _eye := Vector3.INF
var _last := {}
var _trails_laid := false

func _init() -> void:
	name = "SkyCollectibles"
	near_home = near_home_enabled()

func _ready() -> void:
	hud = Hud.new()
	add_child(hud)
	picked.connect(hud.show_pickup)

func _exit_tree() -> void:
	_wait()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE: _wait()

func _wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

## Lets every source go (their nodes with them); what was collected stays.
func clear() -> void:
	_wait()
	_task_key = ""
	for key in sources.keys(): drop_source(key)
	sources.clear()
	_waiting.clear()
	_stand.clear()
	_last.clear()
	_trails_laid = false

## Starts over on fresh cells (after the islets' and clusters' `reset`).
func reset(new_cells: SkyCells) -> void:
	clear()
	cells = new_cells
	seed_value = SkyWorld.seed
	position = cells.origin
	_since = CHECK

# --- Sources ------------------------------------------------------------------------

## Adds a source: `lines` (CollectibleLines `line` records, points in
## `host`'s frame; home coordinates when `host` is null) riding with
## `host`. A key added again replaces the old.
func add_source(key: String, lines: Array, host: Node3D = null) -> void:
	if sources.has(key): drop_source(key)
	sources[key] = {"key":key,"host":host if host != null else self,"lines":lines,"live":{}}

## Lets a source go, its standing tokens with it.
func drop_source(key: String) -> void:
	var s: Dictionary = sources.get(key,{})
	for holder: Variant in (s.get("live",{}) as Dictionary).values():
		if is_instance_valid(holder): (holder as Node).queue_free()
	sources.erase(key)

## Every line laid so far (tests, probes): [source key, line].
func all_lines() -> Array:
	var out: Array = []
	for key in sources:
		for l: Dictionary in sources[key].lines: out.append([key,l])
	return out

## Tokens of every line laid so far, by category (tests, tuning).
func census() -> Dictionary:
	var out := {"bridge":0,"under":0,"air":0,"foot":0,"lines":0}
	for entry: Array in all_lines():
		out[entry[1].category] += (entry[1].points as PackedVector3Array).size()
		out.lines += 1
	return out

## A token's place now (global), by its source and point.
func place(s: Dictionary, point: Vector3) -> Vector3:
	return (s.host as Node3D).global_transform*point

# --- Each frame ---------------------------------------------------------------------

## Each frame of the glide (the eye global, as the islets' `advance`
## takes it): follow the origin, look the sources over, stand the near
## tokens, let the far go.
func advance(_delta: float, eye: Vector3) -> void:
	if cells == null: return
	position = cells.origin
	_eye = eye
	_since += _delta
	if _since >= CHECK:
		_since = 0.0
		var began := Time.get_ticks_usec()
		_survey(eye-cells.origin)
		_stream(eye)
		spent.survey = Time.get_ticks_usec()-began
	_finish_task()
	_light()
	var stood := 0
	while stood < STANDS and not _stand.is_empty() and SkyCommits.open():
		var began := Time.get_ticks_usec()
		var entry: Array = _stand.pop_front()
		_stand_token(entry[0],entry[1],entry[2])
		SkyCommits.spend("collectible",Time.get_ticks_usec()-began)
		stood += 1

## Stands every near token now, after laying every host's lines (tests,
## probes, captures).
func flush(eye: Vector3) -> void:
	if cells == null: return
	position = cells.origin
	_eye = eye
	while true:
		_survey(eye-cells.origin)
		if _task < 0: break
		_finish_task(true)
	_stream(eye)
	while not _stand.is_empty():
		var entry: Array = _stand.pop_front()
		_stand_token(entry[0],entry[1],entry[2])

## Which hosts stand now without their lines: each islet, cluster and
## island laid once (nearest first, on a worker for the islets and
## clusters), and the swoops between islands once the world's layout is
## known. Sources whose host has gone go too.
func _survey(home: Vector3) -> void:
	for key in sources.keys():
		if not is_instance_valid(sources[key].host): sources.erase(key)
	if not _trails_laid and (islands == null or SkyWorld.ready() or not SkyWorld.ring_on()):
		_trails_laid = true
		_lay_trails()
	if islands != null: _survey_islands()
	var wanted: Array = []
	if islets != null:
		for key: String in islets.built:
			var b: Dictionary = islets.built[key]
			if b.has("cluster"): continue
			var skey := "islet:"+key
			if sources.has(skey) or skey == _task_key: continue
			wanted.append([_flat(b.home,home),skey,b])
	if clusters != null:
		for key: String in clusters.clusters:
			var c: Dictionary = clusters.clusters[key]
			var skey := "cluster:"+key
			if sources.has(skey) or skey == _task_key: continue
			if int(c.get("task",-1)) >= 0 or not c.has("plan") or not (c.waiting as Array).is_empty(): continue
			if (c.stood as Dictionary).size() < (c.plan.members as Array).size(): continue
			wanted.append([_flat(c.spot.at,home),skey,c])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_waiting = wanted
	if _task < 0: _start_next()

## The nearest waiting islet or cluster, laid on a worker (`_lay_islet`,
## `_lay_cluster`); those that lay nothing are marked done at once.
func _start_next() -> void:
	while not _waiting.is_empty():
		var w: Array = _waiting.pop_front()
		var skey: String = w[1]
		if sources.has(skey): continue
		var job: Dictionary = _islet_job(skey,w[2]) if skey.begins_with("islet:") else _cluster_job(skey,w[2])
		if job.is_empty(): continue
		var out := {}
		_task_out = out
		_task_key = skey
		_task_host = job.host
		var work: Callable = job.work
		_task = WorkerThreadPool.add_task(func() -> void: out.lines = work.call(),false,"Sky collectibles")
		return

func _finish_task(wait := false) -> void:
	if _task < 0 or not (wait or WorkerThreadPool.is_task_completed(_task)): return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if is_instance_valid(_task_host): add_source(_task_key,_task_out.get("lines",[]),_task_host)
	_task_key = ""
	_start_next()

## An islet's lines: under its rock and on foot over it, as its hash says
## (forced near the home for review). {} (marked done) when it lays none.
func _islet_job(skey: String, b: Dictionary) -> Dictionary:
	var home: Vector3 = b.home
	var force := near_home and _flat(home,Vector3.ZERO) < NEAR_HOME
	var under := Lines.lays(seed_value,skey,"under_islet",force)
	var foot := Lines.lays(seed_value,skey,"foot_islet",force)
	if not under and not foot:
		add_source(skey,[],b.node)
		return {}
	var shape: RefCounted = b.shape
	var solids := [Lines.solid(shape,Vector3.ZERO)]
	var lowest := Lines.LOWEST-home.y
	var seed := seed_value
	return {"host":b.node,"work":func() -> Array:
		var out: Array = []
		if under:
			var l := Lines.under_line(skey+":under",func(p: Vector2) -> float: return Lines.islet_under(shape,p),Vector2.ZERO,float(shape.reach),lowest,seed)
			if not l.is_empty(): out.append(l)
		if foot:
			var l := Lines.foot_line(skey+":foot",solids,0,seed)
			if not l.is_empty(): out.append(l)
		return out}

## A cluster's lines, in its anchor member's frame: along its bridges,
## through its gaps, round its peak, under its anchor's rock, and on foot:
## over one member, across its stepping stones, along its stairs and docks.
func _cluster_job(skey: String, c: Dictionary) -> Dictionary:
	var plan: Dictionary = c.plan
	var members: Array = plan.members
	var anchor: Dictionary = members[0]
	for m: Dictionary in members:
		if (m.offset as Vector3) == Vector3.ZERO: anchor = m
	var host: Variant = (c.stood as Dictionary).get(anchor.name,{}).get("node")
	if not host is Node3D or not is_instance_valid(host): return {}
	var host_off: Vector3 = anchor.offset
	var at: Vector3 = c.spot.at
	var force := near_home and _flat(at,Vector3.ZERO) < NEAR_HOME+200.0
	var offsets := {}
	var solids: Array = []
	for m: Dictionary in members:
		offsets[m.name] = m.offset
		solids.append(Lines.solid(m.shape,(m.offset as Vector3)-host_off,m.features))
	var seed := seed_value
	var lowest := Lines.LOWEST-at.y
	return {"host":host,"work":func() -> Array:
		var out: Array = []
		out.append_array(Lines.bridge_lines(plan,offsets,host_off,skey,seed,force))
		out.append_array(Lines.gap_lines(plan,solids,host_off,skey,seed,force))
		for i in range(members.size()):
			var l := Lines.spire_line("%s:spire:%s" % [skey,members[i].name],solids,i,seed,force)
			if not l.is_empty(): out.append(l)
		if Lines.lays(seed,skey,"under_member",force):
			var shape: RefCounted = anchor.shape
			var l := Lines.under_line(skey+":under",func(p: Vector2) -> float: return Lines.islet_under(shape,p),Vector2.ZERO,float(shape.reach),lowest,seed)
			if not l.is_empty(): out.append(l)
		out.append_array(Lines.stone_lines(plan,offsets,host_off,skey,seed,force))
		out.append_array(Lines.deck_lines(plan,solids,members.map(func(m: Dictionary) -> String: return m.name),skey,seed,force))
		# On foot over one member: the hash's pick, the next if it has no
		# room.
		if Lines.lays(seed,skey,"foot_member",force):
			var order: Array = []
			for i in range(members.size()):
				order.append([Lines.roll(seed,skey,members[i].name),i])
			order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			for o: Array in order:
				var l := Lines.foot_line("%s:foot:%s" % [skey,members[o[1]].name],solids,o[1],seed)
				if not l.is_empty():
					out.append(l)
					break
		return out}

## The plate's line under its rock, laid here once its land is in, in home
## coordinates.
func _survey_islands() -> void:
	var home_at := -cells.origin
	var plate_key: String = "island:%d,%d" % [roundi(home_at.x),roundi(home_at.z)]
	if not sources.has(plate_key) and islands.editor != null and islands.editor.data != null:
		var home := -cells.origin
		var lines: Array = []
		if Lines.lays(seed_value,plate_key,"under_island",near_home):
			var under := func(p: Vector2) -> float:
				var b: Variant = islands._body(Vector3(p.x,0.0,p.y))
				return (b as Vector2).y if b != null else INF
			var l := Lines.under_line(plate_key+":under",under,Vector2.ZERO,Plate.HALF,Lines.LOWEST-home.y,seed_value)
			if not l.is_empty():
				# Laid in the plate's frame (the world's, at the origin):
				# into home coordinates.
				var points := PackedVector3Array()
				for p: Vector3 in l.points: points.append(p+home)
				l.points = points
				lines.append(l)
		add_source(plate_key,lines)

## The swoops between islands: each island's (the fixed slots' and every
## cell's) two nearest neighbours within TRAIL_REACH, each pair as its hash
## says, where the air between is open.
func _lay_trails() -> void:
	var spots: Array[Vector3] = []
	if cells == null: return
	for s in cells.reserved: spots.append(s)
	var reach := ceili(SkyWorld.SCATTER/SkyCells.CELL)+1
	if not SkyWorld.ring_on(): reach = 4
	for x in range(-reach,reach+1):
		for z in range(-reach,reach+1):
			var s: Variant = cells.spot(Vector2i(x,z))
			if s != null and not spots.has(s): spots.append(s)
	var pairs := {}
	for i in range(spots.size()):
		var near: Array = []
		for j in range(spots.size()):
			if i == j: continue
			var d := _flat(spots[i],spots[j])
			if d < Lines.TRAIL_REACH: near.append([d,j])
		near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for k in range(mini(2,near.size())):
			var j: int = near[k][1]
			pairs[Vector2i(mini(i,j),maxi(i,j))] = true
	var lines: Array = []
	for pair: Vector2i in pairs:
		var a := spots[pair.x]
		var b := spots[pair.y]
		var id := "trail:%s-%s" % [_home_key(a),_home_key(b)]
		var force := near_home and (_flat(a,Vector3.ZERO) < 1.0 or _flat(b,Vector3.ZERO) < 1.0)
		if not Lines.lays(seed_value,id,"trail",force): continue
		var l := Lines.trail_line(id,a,b,_open_air.bind(spots),seed_value)
		if not l.is_empty(): lines.append(l)
	add_source("trails",lines)

## True where a token may hang in open air (home): inside the world, clear
## of the ranges, the cumulus, the forested isles, the islands' spots, the
## clusters and the seeded islets.
func _open_air(at: Vector3, spots: Array[Vector3]) -> bool:
	if SkyPeaks.blocks(at,30.0) or SkyTowers.blocks(at,30.0) or SkyForestIsles.blocks(at,20.0): return false
	for s in spots:
		if _flat(s,at) < Lines.TRAIL_ISLAND: return false
	if clusters != null:
		for s: Dictionary in clusters.spots:
			if _flat(s.at,at) < Lines.TRAIL_CLUSTER: return false
	if islets != null:
		var cell := Vector2i(floori(at.x/SkyIslets.CELL),floori(at.z/SkyIslets.CELL))
		for dx in range(-1,2):
			for dz in range(-1,2):
				var s: Variant = islets.spot(cell+Vector2i(dx,dz))
				if s != null and _flat(s,at) < Lines.TRAIL_ISLET and absf((s as Vector3).y-at.y) < 22.0: return false
	return true

# --- Standing them ------------------------------------------------------------------

## Every source's tokens looked over: the near ones not yet standing queued
## to stand (nearest first), the far ones let go, the motes on only near.
func _stream(eye: Vector3) -> void:
	var queue: Array = []
	var looked := 0
	var live := 0
	for key in sources:
		var s: Dictionary = sources[key]
		var host: Node3D = s.host
		var frame := host.global_transform
		for l: Dictionary in s.lines:
			var points: PackedVector3Array = l.points
			for k in range(points.size()):
				var id := "%s:%d" % [l.id,k]
				looked += 1
				var holder: Variant = s.live.get(id)
				if holder != null and not is_instance_valid(holder):
					s.live.erase(id)
					holder = null
				if collected.has(id): continue
				var d := (frame*points[k]).distance_to(eye)
				if holder == null:
					if d < VIEW: queue.append([d,s,l,k])
				elif d > FORGET:
					(holder as Node).queue_free()
					s.live.erase(id)
				else:
					live += 1
					(holder as Node3D).motes_on(d < MOTES_NEAR)
	queue.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_stand = queue.map(func(q: Array) -> Array: return [q[1],q[2],q[3]])
	spent.looked = looked
	spent.live = live

func _stand_token(s: Dictionary, l: Dictionary, k: int) -> void:
	var id := "%s:%d" % [l.id,k]
	var host: Variant = s.host
	if collected.has(id) or s.live.has(id) or not is_instance_valid(host) or not sources.has(s.key): return
	var holder := GlyphPickup.make(l.glyph,float(l.size),float(k)*0.6+Lines.roll(seed_value,l.id,"phase")*TAU,l.category == "foot")
	holder.glow_for(_night)
	holder.position = (l.points as PackedVector3Array)[k]
	holder.set_meta("token",id)
	holder.set_meta("line",l.id)
	(host as Node3D).add_child(holder)
	holder.motes_on(_eye == Vector3.INF or holder.global_position.distance_to(_eye) < MOTES_NEAR)
	s.live[id] = holder

# --- Pickup -------------------------------------------------------------------------

## The walker's middle (global) this frame: tokens within his reach go.
func touch_walker(point: Vector3) -> void:
	_touch("walker",point,Lines.WALKER_REACH)

## The plane (global) this frame: tokens within its reach go.
func touch_plane(point: Vector3) -> void:
	_touch("plane",point,Lines.PLANE_REACH)

## Takes every standing token within `reach` (plus half its size) of the
## way `who` moved since its last touch. The plane passes through foot
## tokens: those are the walker's alone.
func _touch(who: String, point: Vector3, reach: float) -> void:
	var from: Vector3 = _last.get(who,point)
	if from.distance_to(point) > JUMP: from = point
	_last[who] = point
	for key in sources:
		var s: Dictionary = sources[key]
		for id: String in (s.live as Dictionary).keys():
			var holder: Variant = s.live[id]
			if not is_instance_valid(holder) or holder.taking: continue
			if who == "plane" and holder.calm: continue
			var at: Vector3 = (holder as Node3D).global_position
			var near := Geometry3D.get_closest_point_to_segment(at,from,point)
			if near.distance_to(at) < reach+float(holder.size)*0.5: collect(s,id)

## Collects token `id` of source `s`: it twists away, the readout shows it,
## and the world is kept soon after.
func collect(s: Dictionary, id: String) -> void:
	var holder: Variant = s.live.get(id)
	var line_id := id.substr(0,id.rfind(":"))
	var glyph := ""
	var count := 0
	var got := 0
	for l: Dictionary in s.lines:
		if l.id != line_id: continue
		glyph = l.glyph
		count = (l.points as PackedVector3Array).size()
	collected[id] = glyph
	s.live.erase(id)
	for k in range(count):
		if collected.has("%s:%d" % [line_id,k]): got += 1
	if is_instance_valid(holder): holder.take(hash(id) & 0xffff)
	picked.emit(glyph,glyph_total(glyph),got,count)
	var session: Variant = scene.get("world_session") if scene != null else null
	if session is Node and session.has_method("edited"): session.edited()

## How many of `glyph` are collected (every glyph with "").
func glyph_total(glyph := "") -> int:
	if glyph == "": return collected.size()
	var n := 0
	for g: String in collected.values():
		if g == glyph: n += 1
	return n

# --- Keeping --------------------------------------------------------------------------

## What the world's save keeps: the tokens collected, and the seed they
## were laid for.
func save_state() -> Dictionary:
	return {"seed":seed_value if cells != null else SkyWorld.seed,"collected":collected.duplicate()}

## Takes a world's saved tokens (`save_state`), or none for a new world.
## Kept for another seed (--sky-seed), they are left out.
func load_state(state: Dictionary) -> void:
	collected = {}
	var saved: Variant = state.get("collected",{})
	if saved is Dictionary and int(state.get("seed",SkyWorld.seed)) == SkyWorld.seed:
		for id: Variant in saved: collected[str(id)] = str(saved[id])
	for key in sources:
		for id: String in (sources[key].live as Dictionary).keys():
			if collected.has(id):
				var holder: Variant = sources[key].live[id]
				if is_instance_valid(holder): (holder as Node).queue_free()
				sources[key].live.erase(id)

## The night the tokens glow for (0 by day, 1 at full night): the
## clusters' (SkyClusters `night`), and every standing token lit to match
## as it changes.
var _night := 0.0

func _light() -> void:
	var night: float = clusters.night if clusters != null else 0.0
	if absf(night-_night) < 0.02: return
	_night = night
	for key in sources:
		for holder: Variant in (sources[key].live as Dictionary).values():
			if is_instance_valid(holder) and not holder.taking: holder.glow_for(_night)

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

static func _home_key(h: Vector3) -> String:
	return "%d,%d" % [roundi(h.x),roundi(h.z)]
