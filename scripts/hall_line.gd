extends Node3D
## The Sundered line: big Sundered-hall pieces rising whole out of the
## cloud sea ahead of the plane, end to end in straight runs, the line
## sidestepping (or bending) now and then between runs (docs/design/
## isle-hall-line.md; where each stands and what it is: scripts/
## hall_line_plan.gd; how it rises: scripts/hall_rise.gd). The aqueduct
## isle's chain by default (studies/aqueduct_isle_chain.gd); the hall chain
## (scripts/hall_chain.gd) is the old way, behind --chain-style=halls.
##
## Each piece is one HallRise of one chunk: the whole nave stretch and the
## island under it come up together. The plane's place along the line
## (`plane_s`, m along the route) sets the next piece rising once its entry
## is `ahead` m off, or sooner at speed: once, at the plane's speed, it is
## no more than its rise plus `settle_by` s away; and never before the
## newest has broken out of the cloud, so they come up one after another.
## A piece still rising that the plane would beat rises up to `catch_up`
## times quicker. Past `keep` pieces the oldest the plane has left sinks
## back into the cloud, the rise reversed, and is freed once under.
##
## The look (`look`, --line-look=): "real" (the default) builds each piece
## as the game's own Sundered hall (scripts/hall_line_build.gd: the ruin
## kit's bays in the eroded basalt, the swaying overgrowth, its ridge
## island of the islets' terrain, trees and rock), shown near within
## NEAR_SHOW of the eye and as Sundered's far mesh past it; "greybox" draws
## it as the flight course's boxes on a faceted keel (round 1).
##
## No hitches. Real: the pieces are built on a worker, one at a time, in
## order, PREFETCH ahead of the newest standing (a piece's content never
## depends on where it stands, so it is built before it is placed); one is
## only set rising once built. Its node is handed over in one frame, its
## island stood the same frame, its collision stood a body a frame while it
## rises (HallRise `bodies`). Greybox: the next piece is planned and its
## solids drawn on a worker as soon as the one before is placed, its chunk
## made on a worker (HallRise's build) and handed over in one frame.
## `spawns` keeps each piece's main-thread costs.
##
## The caller sets the cloud top (world, `sea_top`), the plane's box
## (`plane_box`), `configure`s it, `reset`s it with the first piece's pose
## (`first_pose_at`), then calls `advance(delta, plane_at)` every physics
## frame, keeping `plane_speed` up.

const Rise = preload("res://scripts/hall_rise.gd")
const RisePlan = preload("res://scripts/hall_rise_plan.gd")
const LinePlan = preload("res://scripts/hall_line_plan.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const LineBuild = preload("res://scripts/hall_line_build.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const FarTrees = preload("res://scripts/far_trees.gd")

## The way in: the route starts this far (m) before the first piece's
## entry, on its heading.
const LEAD_IN := 25.0
## The defaults past the plan's: how far ahead (m) a piece starts rising at
## the latest, and how many stand at once before the oldest sinks.
const AHEAD := 260.0
const KEEP := 6
## The plane counts along the line only this close to its route (m).
const NEAR := 60.0
## The oldest waits to sink while the plane is within this past its exit.
const SINK_CLEAR := 30.0
## The bursts round a whole piece (puffs at most), the stream off it (a
## second): a piece's island is some 250 m round.
const BURST_PUFFS := 150
const STREAM := 90.0
## Real pieces built ahead of the newest standing (one at a time).
const PREFETCH := 2

signal spawned(index: int)

var sea_top := -102.0
var plane_box := Callable()
var burst: Node = null
var puff_scale := 1.0
var settle_by := 0.0
var plane_speed := 0.0
var catch_up := 1.0
var ahead := AHEAD
var keep := KEEP
var cfg := {}
## "real" or "greybox" (see the header).
var look := "real"
## The islets' host the real pieces' islands stand with (its materials,
## catalog and plants: scripts/sky_islets.gd), made here, and its ground
## palette; the height (world) the islands' falls are planned from.
var islets: Node3D = null
var _palette := {}
var home_y := 0.0
## Real pieces built or building, by index: {task, out (`made`: scripts/
## hall_line_build.gd `build`)}; the one building, -1 none.
var _builds := {}
var _building := -1
## The eye (world) the near and far detail swap by: the camera's, or this
## if set (tests).
var eye := Vector3.INF
## Real pieces' nodes taken, their islands still to stand: [node, made].
var _islands_due: Array = []
## What a built piece's island first stands with, made one a frame ahead
## of its hand-over (its plants' materials and their far stand-ins, made
## once and kept: the first otherwise costs its stand some 5 ms): keys.
var _warm: Array = []
var rise_opts := {}
var materials := {}
## The pieces up now, oldest first: {index, pose (the plan's piece record),
## rise (HallRise), s_in, s_out (m along the route: its entry and exit),
## reached (the plane has got to its entry), born, pace}.
var halls: Array = []
var made := 0
var most := 0
var sunk_count := 0
var clock := 0.0
var spawns: Array = []
## The route the plane flies (world points every ROUTE_STEP m: the way in,
## each piece's lane, each gap's), its points' distances along it (m), and
## the global index of its first point.
var route: Array[Vector3] = []
var route_s := PackedFloat32Array()
var route_base := 0
## The plane's distance along the route (m; -INF until it has one), and the
## route point it was nearest.
var plane_s := -INF
var _plane_k := 0
var _route_halls: Array = []
## The next piece: planned, its template drawn on a worker.
var _next := {}
var _first_template := {}
const ROUTE_STEP := 2.0

## The line's flags: --line-bays=<a-b>, --line-gap=<a-b>, --line-run=<a-b>
## (pieces a straight run: how often it turns), --line-turn=sidestep|bend|mix,
## --line-jog=<m>, --line-jog-gap=<m>, --line-bend=<deg>, --line-band=<m>,
## --line-seed=<n>, --line-ahead=<m>, --line-keep=<n> (0: never sink),
## --line-look=real|greybox.
static func options(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a: String in args:
		var v := a.get_slice("=",1)
		var r := _range(v)
		if a.begins_with("--line-bays="): out.bays = Vector2i(int(r.x),int(r.y))
		elif a.begins_with("--line-gap="): out.gap = r
		elif a.begins_with("--line-run="): out.run = Vector2i(int(r.x),int(r.y))
		elif a.begins_with("--line-turn="): out.turn = v
		elif a.begins_with("--line-jog="): out.jog = float(v)
		elif a.begins_with("--line-jog-gap="): out.jog_gap = float(v)
		elif a.begins_with("--line-bend="): out.bend = float(v)
		elif a.begins_with("--line-band="): out.band = float(v)
		elif a.begins_with("--line-seed="): out.seed = int(v)
		elif a.begins_with("--line-ahead="): out.ahead = maxf(0.0,float(v))
		elif a.begins_with("--line-keep="): out.keep = maxi(0,int(v))
		elif a.begins_with("--line-look=") and v in ["real","greybox"]: out.look = v
	return out

## "a-b" or "a" as a range.
static func _range(v: String) -> Vector2:
	var p := v.split("-")
	if p.size() >= 2 and p[0] != "": return Vector2(float(p[0]),float(p[1]))
	return Vector2(float(v),float(v))

func _init() -> void:
	name = "HallLine"

func _exit_tree() -> void:
	_wait_next()
	_release_builds()

## The line's settings and the rise's options; plans the first piece (the
## isle times its lead from it).
func configure(line_opts: Dictionary, given_rise: Dictionary) -> void:
	cfg = LinePlan.settings(line_opts)
	ahead = float(line_opts.get("ahead",AHEAD))
	keep = int(line_opts.get("keep",KEEP))
	rise_opts = given_rise.duplicate()
	look = str(line_opts.get("look",look))
	if look == "real":
		# What a worker's build needs made here first: the islets' shared
		# pieces and catalog, the ruins' materials.
		if islets == null:
			islets = SkyIslets.new()
			islets.name = "Islets"
			# The sky's own host releases the shared pieces at the end.
			islets.owns_shared = false
			add_child(islets)
		_palette = islets.prepare_authored()
		RuinKit.materials()
		_first_template = {}
	else:
		_first_template = LinePlan.template(LinePlan.content(int(cfg.seed),0,cfg))

## How long (s) the first piece takes to rise, its lane at `lane_y` (world),
## till it is still.
func length_at(lane_y: float) -> float:
	if _first_template.is_empty():
		var piece := LinePlan.content(int(cfg.seed),0,cfg)
		piece.index = 0
		_first_template = _real_template(piece)
	var given := rise_opts.duplicate()
	given.sea = sea_top-(lane_y-LinePlan.LINE_Y)
	return float(RisePlan.remake(_first_template,given).length)

## The first piece's pose: its way in at `way_in`, run on `heading` (rad,
## SkyPlane's), so a plane flying on that heading meets its entry dead
## ahead, LEAD_IN m on, the lane at the way in's height. (`_hand` for the
## hall chain's call.)
func first_pose_at(way_in: Vector3, heading: float, _hand := 1) -> Dictionary:
	return LinePlan.first(int(cfg.seed),cfg,way_in+LinePlan.ahead(heading)*LEAD_IN,heading)

## The entry (world) of a piece standing at `pose`.
static func gate_of(pose: Dictionary) -> Vector3:
	return pose.entry

func lead_in() -> float:
	return LEAD_IN

## Every piece down at once and the first rising again (`seed`: -1 keeps
## the line's; `first`: the first piece's pose, straight north from the
## origin if empty).
func reset(seed := -1, first := {}) -> void:
	if seed >= 0 and seed != int(cfg.seed):
		cfg.seed = seed
		_release_builds()
		_first_template = LinePlan.template(LinePlan.content(seed,0,cfg)) if look != "real" else {}
	_wait_next()
	_islands_due = []
	for h: Dictionary in halls: _free(h)
	halls = []
	spawns = []
	route = []
	route_s = PackedFloat32Array()
	route_base = 0
	_route_halls = []
	plane_s = -INF
	_plane_k = 0
	made = 0
	most = 0
	sunk_count = 0
	clock = 0.0
	var piece: Dictionary = first if not first.is_empty() else LinePlan.first(int(cfg.seed),cfg,Vector3(0.0,0.0,-LEAD_IN),0.0)
	if look == "real":
		# A real piece's node goes with it: the first is built again if a
		# reset before used it.
		if _first_template.is_empty() or bool(_first_template.get("used",false)): _first_template = _real_template(piece)
		_first_template.used = true
	_add(piece,_first_template)

## Sets the next piece rising now (the trigger does this). Its index.
func spawn_next() -> int:
	if _next.is_empty(): return -1
	var began := Time.get_ticks_usec()
	var next := _next
	_wait_next()
	var template: Dictionary = next.out.template if look != "real" else _real_template(next.piece)
	_add(next.piece,template,began)
	return int(next.piece.index)

func _wait_next() -> void:
	if not _next.is_empty() and int(_next.task) >= 0:
		WorkerThreadPool.wait_for_task_completion(int(_next.task))
		_next.task = -1

## Plans the piece after `piece` and draws it on a worker.
func _plan_next(piece: Dictionary) -> void:
	var next := LinePlan.next(piece,cfg)
	var out := {}
	var job := {"piece":next,"out":out,"task":-1,"length":-1.0}
	job.gap = _gap_length(piece,next)
	if look != "real": job.task = WorkerThreadPool.add_task(func() -> void: out.template = LinePlan.template(next),true,"Hall line piece")
	_next = job

func _add(piece: Dictionary, template: Dictionary, began := -1) -> void:
	if began < 0: began = Time.get_ticks_usec()
	var rise: Node3D = Rise.new()
	rise.name = "Piece%d" % int(piece.index)
	rise.transform = LinePlan.xform(piece)
	rise.sea_y = sea_top-float((piece.origin as Vector3).y)
	rise.take_per_frame = 1
	rise.plane_box = _box_for.bind(rise)
	rise.burst = burst
	rise.puff_scale = puff_scale
	rise.burst_puffs = BURST_PUFFS
	rise.stream_rate = STREAM
	var got: Dictionary = template.get("made",{})
	if not got.is_empty(): rise.taken.connect(_on_taken.bind(got))
	add_child(rise)
	var given := rise_opts.duplicate()
	given.template = template
	given.materials = materials
	rise.setup(given)
	rise.play()
	var h := {"index":int(piece.index),"pose":piece,"rise":rise,"s_in":0.0,"s_out":0.0,"reached":false,"born":clock,"pace":1.0,"made":got}
	halls.append(h)
	_extend_route(h)
	made += 1
	_plan_next(piece)
	spawns.append({"index":int(piece.index),"setup":Time.get_ticks_usec()-began,"frame":0,"take":0,"island":0,"bodies":0,"total":0,
		"build":int(got.get("usec",0)),"hulls":int(got.get("hulls",0)),"triangles":int(got.get("triangles",0))})
	_cap()
	most = maxi(most,standing_count())
	spawned.emit(int(piece.index))

func _box_for(rise: Node3D) -> AABB:
	if not plane_box.is_valid() or not rise.is_inside_tree(): return AABB()
	var box: AABB = plane_box.call()
	if box.size == Vector3.ZERO: return box
	return AABB(rise.to_local(box.get_center())-box.size*0.5,box.size)

## One frame: where the plane is along the line, every piece's rise or
## sink, the next piece's trigger, the cap. `plane_at`: world, or null.
func advance(delta: float, plane_at: Variant) -> void:
	clock += delta
	if plane_at != null: _track(plane_at as Vector3)
	for h: Dictionary in halls:
		if not bool(h.reached) and plane_s >= float(h.s_in)-0.5: h.reached = true
		h.pace = _pace(h)
		(h.rise as Node3D).advance(delta*float(h.pace))
	for s: Dictionary in spawns:
		var h := hall(int(s.index))
		if h.is_empty(): continue
		s.take = h.rise.frame_take_usec
		s.bodies = h.rise.body_frame_usec
		s.frame = maxi(maxi(int(s.setup)+int(s.take),int(s.island)),int(s.bodies))
		s.total = int(s.setup)+int(h.rise.take_total_usec)+int(s.island)+int(h.rise.body_total_usec)
	if look == "real":
		_stand_islands()
		_pump()
		_swap_detail()
	if _due(): spawn_next()
	_cap()
	var k := 0
	while k < halls.size():
		if bool(halls[k].rise.gone):
			_free(halls[k])
			halls.remove_at(k)
			sunk_count += 1
			_trim_route()
			continue
		k += 1

## Whether the next piece should start rising now (see the header).
func _due() -> bool:
	if _next.is_empty() or halls.is_empty() or plane_s == -INF: return false
	# Never waited for on this thread: due once drawn (built).
	if int(_next.task) >= 0 and not WorkerThreadPool.is_task_completed(int(_next.task)): return false
	if look == "real" and not built(int(_next.piece.index)): return false
	var newest: Node3D = halls[-1].rise
	if newest.playing and newest.broke.size() > 0 and newest.broke[0] == 0: return false
	# Its entry along the route: past the newest's exit by the gap's lane.
	var off := float(halls[-1].s_out)+float(_next.gap)-plane_s
	if off <= ahead: return true
	if settle_by <= 0.0: return false
	var v := maxf(plane_speed,SkyPlane.CRUISE_SPEED)
	return off/v <= _next_length()+settle_by

## How long the next piece takes to rise (s): its own once drawn, till then
## the first's at its height.
func _next_length() -> float:
	if float(_next.length) >= 0.0: return float(_next.length)
	if look == "real":
		if not built(int(_next.piece.index)): return length_at(float((_next.piece.entry as Vector3).y))
		var got: Dictionary = _builds[int(_next.piece.index)].out.made
		var real := rise_opts.duplicate()
		real.sea = sea_top-float((_next.piece.origin as Vector3).y)
		_next.length = float(RisePlan.remake(LineBuild.template(_next.piece,got),real).length)
		return float(_next.length)
	if int(_next.task) >= 0 and not WorkerThreadPool.is_task_completed(int(_next.task)):
		return length_at(float((_next.piece.entry as Vector3).y))
	_wait_next()
	var given := rise_opts.duplicate()
	given.sea = sea_top-float((_next.piece.origin as Vector3).y)
	_next.length = float(RisePlan.remake(_next.out.template,given).length)
	return float(_next.length)

func _gap_length(prev: Dictionary, piece: Dictionary) -> float:
	var pts := LinePlan.gap_route(prev,piece,ROUTE_STEP)
	var out := 0.0
	var at: Vector3 = prev.exit
	for p: Vector3 in pts:
		out += at.distance_to(p)
		at = p
	return out

## How fast piece `h` rises this frame (1 its own pace): quicker, up to
## `catch_up`, while the plane would reach its entry less than `settle_by`
## s after it is still.
func _pace(h: Dictionary) -> float:
	if catch_up <= 1.0 or plane_s == -INF or h.rise.sinking or not h.rise.playing or bool(h.reached): return 1.0
	var left := float(h.rise.plan.length)+float(h.rise.stall)-float(h.rise.clock)
	if left <= 0.0: return 1.0
	var eta := (float(h.s_in)-plane_s)/maxf(plane_speed,1.0)-settle_by
	if eta <= 0.05: return catch_up
	return clampf(left/eta,1.0,catch_up)

## The plane's distance along the route: from the nearest route point a
## little way on from the last, if within NEAR of it; before the route's
## start, along its first leg run back. It only ever grows.
func _track(at: Vector3) -> void:
	if route.size() < 2: return
	var g := clampi(_plane_k,route_base,route_end())
	var best := g
	var best_d := INF
	for k in range(maxi(route_base,g-4),mini(route_end(),g+80)+1):
		var d := at.distance_to(route_at(k))
		if d < best_d:
			best_d = d
			best = k
	var i := best-route_base
	if i == 0 and route_base == 0:
		var leg := (route[1]-route[0]).normalized()
		var u := (at-route[0]).dot(leg)
		if u < 0.0:
			if ((at-route[0])-leg*u).length() > NEAR: return
			plane_s = maxf(plane_s,float(route_s[0])+u)
			return
	if best_d > NEAR: return
	_plane_k = best
	var j := mini(i,route.size()-2)
	var way := (route[j+1]-route[j]).normalized()
	plane_s = maxf(plane_s,float(route_s[i])+clampf((at-route[i]).dot(way),-ROUTE_STEP,ROUTE_STEP))

## The piece with index `index` ({} if not up).
func hall(index: int) -> Dictionary:
	for h: Dictionary in halls:
		if int(h.index) == index: return h
	return {}

func standing_count() -> int:
	var n := 0
	for h: Dictionary in halls:
		if not h.rise.sinking: n += 1
	return n

## Past `keep`, the oldest standing piece sinks, once the plane is well past
## its exit.
func _cap() -> void:
	if keep <= 0: return
	while standing_count() > keep:
		var oldest := {}
		for h: Dictionary in halls:
			if not h.rise.sinking:
				oldest = h
				break
		if oldest.is_empty() or plane_s < float(oldest.s_out)+SINK_CLEAR: return
		(oldest.rise as Node3D).sink()

# --- The real build ----------------------------------------------------------------------

## Starts building the pieces from the first (call early: the isle does as
## the ring wakes), PREFETCH ahead.
func prefetch() -> void:
	if look == "real": _pump()

## Whether piece `index` is built.
func built(index: int) -> bool:
	if not _builds.has(index): return false
	var b: Dictionary = _builds[index]
	if int(b.task) >= 0:
		if not WorkerThreadPool.is_task_completed(int(b.task)): return false
		WorkerThreadPool.wait_for_task_completion(int(b.task))
		b.task = -1
		if _building == index: _building = -1
		_warm_for(b.out.made)
	return true

func _warm_for(got: Dictionary) -> void:
	for key: String in (got.island.plants as Dictionary):
		if not _warm.has(key): _warm.append(key)

## One of `_warm` made (its plant material, a tree's far stand-in).
func _warm_one() -> void:
	if _warm.is_empty(): return
	var key: String = _warm.pop_front()
	var catalog: Dictionary = SkyIslets.catalog()
	SkyIslets._plant_material(key)
	if catalog.roles.get(key,"") == "tree" and catalog.meshes.has(key) and not FarTrees.bare(key): FarTrees.proxy(key,catalog.meshes[key])

## One build at a time, in order: the next one wanted (the newest's next
## and PREFETCH on) started once the last is done.
func _pump() -> void:
	_warm_one()
	if _building >= 0 and not built(_building): return
	# The first piece is always the first template's.
	var from := maxi(made,0 if _first_template.is_empty() else 1)
	for index in range(from,made+PREFETCH):
		if _builds.has(index): continue
		_start_build(index)
		return

func _start_build(index: int) -> void:
	var piece := LinePlan.content(int(cfg.seed),index,cfg)
	piece.index = index
	piece.origin = Vector3(0.0,home_y,0.0)
	var out := {}
	var palette := _palette
	_builds[index] = {"task":WorkerThreadPool.add_task(func() -> void: out.made = LineBuild.build(piece,palette),false,"Hall line real piece"),"out":out}
	_building = index

## Piece `piece`'s real template (scripts/hall_line_build.gd `template`),
## its build taken (waited for if it is not done: only the first, when it
## was not started early).
func _real_template(piece: Dictionary) -> Dictionary:
	var index := int(piece.index)
	if not _builds.has(index): _start_build(index)
	var b: Dictionary = _builds[index]
	if int(b.task) >= 0:
		WorkerThreadPool.wait_for_task_completion(int(b.task))
		b.task = -1
		if _building == index: _building = -1
		_warm_for(b.out.made)
	_builds.erase(index)
	var got: Dictionary = b.out.made
	var t := LineBuild.template(piece,got)
	t.made = got
	return t

## A real piece's node taken by its rise: its island stood into it the
## next frame (`_stand_islands`), so the hand-over and the island never
## share one.
func _on_taken(_i: int, node: Node3D, got: Dictionary) -> void:
	_islands_due.append([node,got])

func _stand_islands() -> void:
	if _islands_due.is_empty(): return
	var item: Array = _islands_due.pop_front()
	var node: Node3D = item[0]
	if not is_instance_valid(node): return
	var began := Time.get_ticks_usec()
	LineBuild.stand_island(islets,item[1],node)
	var took := Time.get_ticks_usec()-began
	for h: Dictionary in halls:
		if h.made == item[1]:
			for sp: Dictionary in spawns:
				if int(sp.index) == int(h.index): sp.island = took

## Near detail within LineBuild.NEAR_SHOW of the eye, Sundered's far mesh
## past it.
func _swap_detail() -> void:
	var at := eye
	if at == Vector3.INF:
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam == null: return
		at = cam.global_position
	for h: Dictionary in halls:
		var rise: Node3D = h.rise
		if (h.made as Dictionary).is_empty() or rise.nodes.is_empty() or rise.nodes[0] == null: continue
		var local := rise.to_local(at)
		var d := INF
		for p: Vector3 in h.made.samples: d = minf(d,local.distance_to(p))
		var near := d < LineBuild.NEAR_SHOW
		var node: Node3D = rise.nodes[0]
		(node.get_node(^"Near") as Node3D).visible = near
		(node.get_node(^"Far") as Node3D).visible = not near

## Lets every build not stood go (waits for the one building).
func _release_builds() -> void:
	for index: int in _builds:
		var b: Dictionary = _builds[index]
		if int(b.task) >= 0: WorkerThreadPool.wait_for_task_completion(int(b.task))
		if (b.out as Dictionary).has("made"): LineBuild.release(b.out.made)
	_builds = {}
	_building = -1
	if _first_template.has("made") and not bool(_first_template.get("used",false)):
		LineBuild.release(_first_template.made)
		_first_template = {}

func _free(h: Dictionary) -> void:
	var rise: Node3D = h.rise
	if is_instance_valid(rise):
		remove_child(rise)
		rise.queue_free()

# --- The route --------------------------------------------------------------------------

func _push(p: Vector3) -> void:
	var s := 0.0 if route.is_empty() else float(route_s[-1])+route[-1].distance_to(p)
	route.append(p)
	route_s.append(s)

func _extend_route(h: Dictionary) -> void:
	var piece: Dictionary = h.pose
	var count := route.size()
	if _route_halls.is_empty():
		var entry: Vector3 = piece.entry
		_push(entry-LinePlan.ahead(float(piece.yaw))*LEAD_IN)
		var n := ceili(LEAD_IN/ROUTE_STEP)
		for k in range(1,n): _push(entry-LinePlan.ahead(float(piece.yaw))*LEAD_IN*(1.0-float(k)/n))
	else:
		var prev: Dictionary = _route_halls[-1]
		for p: Vector3 in LinePlan.gap_route(prev.pose,piece,ROUTE_STEP):
			_push(p)
		# The gap's points belong to the piece before (trimmed with it).
		prev.count = int(prev.count)+route.size()-count
		count = route.size()
	var lane := LinePlan.lane_route(piece,ROUTE_STEP)
	if not _route_halls.is_empty(): lane = lane.slice(1)
	h.s_in = float(route_s[-1]) if not _route_halls.is_empty() else float(route_s[-1])+route[-1].distance_to(lane[0])
	for p: Vector3 in lane: _push(p)
	h.s_out = float(route_s[-1])
	_route_halls.append({"index":int(h.index),"pose":piece,"count":route.size()-count})

func _trim_route() -> void:
	while _route_halls.size() > 1 and hall(int(_route_halls[0].index)).is_empty():
		var n := int(_route_halls[0].count)
		route = route.slice(n)
		route_s = route_s.slice(n)
		route_base += n
		_route_halls.remove_at(0)

func route_at(g: int) -> Vector3:
	return route[clampi(g-route_base,0,route.size()-1)]

func route_end() -> int:
	return route_base+route.size()-1

# --- The autopilot ---------------------------------------------------------------------

## A pursuit pilot along the route (as scripts/hall_chain.gd `steer`): it
## aims at the first route point at least `look` m on from the nearest one
## it has reached. Fills SkyPlane.step's input; returns [input, at].
func steer(plane: RefCounted, at: int, look := 8.0) -> Array:
	var pos: Vector3 = plane.position
	var g := maxi(at,route_base)
	var end := route_end()
	var best := g
	var best_d := INF
	for k in range(g,mini(end,g+40)+1):
		var d := pos.distance_to(route_at(k))
		if d < best_d:
			best_d = d
			best = k
	g = best
	var target := g
	while target < end and pos.distance_to(route_at(target)) < look: target += 1
	var to := route_at(target)-pos
	var err := wrapf(LinePlan.heading_of(to)-float(plane.heading),-PI,PI)
	var want_pitch := atan2(to.y,maxf(Vector2(to.x,to.z).length(),1.0))
	return [{"turn":clampf(-err*3.0,-1.0,1.0),"pitch":clampf((want_pitch-float(plane.pitch))*2.5,-1.0,1.0)},g]

## For a HUD: {made, standing, sinking, newest, along (m), next_in (m to
## the next piece's entry), spawn (the newest's costs), sunk}.
func status() -> Dictionary:
	var sinking := 0
	for h: Dictionary in halls:
		if h.rise.sinking: sinking += 1
	var newest: Dictionary = halls[-1] if not halls.is_empty() else {}
	return {"made":made,"standing":standing_count(),"sinking":sinking,"newest":int(newest.get("index",-1)),"along":plane_s,
		"spawn":spawns[-1] if not spawns.is_empty() else {},"sunk":sunk_count}
