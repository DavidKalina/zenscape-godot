extends Node3D
## An endless chain of Sundered halls rising out of the cloud sea ahead of
## the plane (docs/design/hall-chain.md; where each stands:
## scripts/hall_chain_plan.gd; how each rises: scripts/hall_rise.gd).
##
## Each hall is a HallRise (the hall rise study's four whole chunks, the
## apse first and the gate last, so the end nearest the incoming plane comes
## up last, right ahead). When the plane gets `at` of the way along the
## newest hall's line (within NEAR m of it), the next hall is placed off its
## exit and starts rising at once, so it is coming up as the plane leaves
## and has settled by the time it gets to the gate. Past `keep` halls the
## oldest sinks back into the cloud, the rise reversed, and is freed once
## under, so it can run forever at a fixed cost.
##
## Spawning never hitches: the plan's chunks are planned once (`template`)
## and only timed again per hall, the hall's chunks are made on a worker
## (HallRise's build), and handed over one chunk a frame. `spawns` keeps
## each hall's main-thread costs.
##
## The caller gives the cloud top (world, `sea_top`) and the plane's box
## (`plane_box`: Callable() -> AABB in the world; a zero box for none),
## calls `reset`, then `advance(delta, plane_at)` every physics frame.

const Rise = preload("res://scripts/hall_rise.gd")
const RisePlan = preload("res://scripts/hall_rise_plan.gd")
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")

## The plane counts toward a hall's trigger only this close to its line (m).
const NEAR := 30.0
## The oldest hall waits to sink while the plane is within this of it (m).
const SINK_CLEAR := 20.0
## Chunks handed over a frame, per hall.
const TAKE_PER_FRAME := 1

signal spawned(index: int)

## The cloud top, world.
var sea_top := -102.0
## The first hall's lowest stone over the cloud top (m).
var clear := 14.0
var plane_box := Callable()
## The chain's settings (ChainPlan.settings) and the rise's options
## (HallRise.options).
var cfg := {}
var rise_opts := {}
var template := {}
## The same mirrored across its length (the left-hand halls).
var template_left := {}
var materials := {}
## The halls up now, oldest first: {index, pose, rise (HallRise), progress
## (0-1, the most the plane has got along its line), next (the next hall
## has been set rising), born (chain clock), triggered_at (chain clock, -1)}.
var halls: Array = []
## How many halls have been made since the reset, and the most at once.
var made := 0
var most := 0
var sunk_count := 0
var clock := 0.0
## Each hall's main-thread cost: {index, setup (usec), frame (the heaviest
## frame's hand-over), total (all of it)}, filled as its chunks come in.
var spawns: Array = []
## The route the plane flies (world points: each hall's way in and line,
## the arc to the next), and the global index of its first point.
var route: Array[Vector3] = []
var route_base := 0
var _route_halls: Array = []
var _rng := RandomNumberGenerator.new()
var _first := {}

## The chain's flags: --chain-at=<0-1>, --chain-gap=<m>, --chain-turn=<deg>,
## --chain-climb=<m>, --chain-keep=<n> (0: never sink), --chain-seed=<n>,
## --chain-mirror=on|off (the halls alternate hands; on).
static func options(args: PackedStringArray) -> Dictionary:
	var out := {}
	for a: String in args:
		var v := a.get_slice("=",1)
		if a.begins_with("--chain-at="): out.at = float(v)
		elif a.begins_with("--chain-gap="): out.gap = float(v)
		elif a.begins_with("--chain-turn="): out.turn = float(v)
		elif a.begins_with("--chain-climb="): out.climb = float(v)
		elif a.begins_with("--chain-keep="): out.keep = int(v)
		elif a.begins_with("--chain-seed="): out.seed = int(v)
		elif a.begins_with("--chain-mirror="): out.mirror = v != "off"
	return ChainPlan.settings(out)

func _init() -> void:
	name = "HallChain"

## Plans the hall's chunks once (main thread, about a millisecond).
func configure(chain_opts: Dictionary, given_rise: Dictionary) -> void:
	cfg = ChainPlan.settings(chain_opts)
	rise_opts = given_rise.duplicate()
	template = RisePlan.make(rise_opts)
	template_left = RisePlan.mirrored(template)

## The lowest stone of the hall (station metres).
func lowest() -> float:
	var out := INF
	for c: Dictionary in template.chunks: out = minf(out,float(c.lo.y))
	return out

## The origin heights a hall may stand at.
func y_range() -> Vector2:
	return Vector2(ChainPlan.origin_y_for(ChainPlan.CLEAR_RANGE.x,sea_top,lowest()),ChainPlan.origin_y_for(ChainPlan.CLEAR_RANGE.y,sea_top,lowest()))

## The first hall's pose: turned `yaw`, standing `clear` over the cloud.
func first_pose(yaw := 0.0) -> Dictionary:
	return {"yaw":yaw,"origin":Vector3(0.0,ChainPlan.origin_y_for(clear,sea_top,lowest()),0.0),"hand":1,"index":0,"turn":0.0,"drift":0.0,"climb":0.0,"swing":0.0}

## Every hall down at once and the first rising again (`seed`: -1 keeps
## the chain's).
func reset(seed := -1) -> void:
	if seed >= 0: cfg.seed = seed
	for h: Dictionary in halls: _free(h)
	halls = []
	spawns = []
	route = []
	route_base = 0
	_route_halls = []
	made = 0
	most = 0
	sunk_count = 0
	clock = 0.0
	_rng.seed = int(cfg.seed)*7919+11
	_first = first_pose()
	_add(_first)

## Sets the next hall rising off the newest one's exit (the trigger does
## this; also the study's N key). Returns its index.
func spawn_next() -> int:
	if halls.is_empty():
		reset()
		return 0
	var last: Dictionary = halls[-1]
	last.next = true
	if float(last.triggered_at) < 0.0: last.triggered_at = clock
	var standing := []
	for h: Dictionary in halls: standing.append(h.pose)
	var pose := ChainPlan.next_pose(last.pose,_rng,cfg,y_range(),standing,boxes())
	_add(pose)
	return int(pose.index)

## The hall's chunks' boxes (station metres).
func boxes() -> Array:
	var out := []
	for c: Dictionary in template.chunks: out.append(AABB(c.lo,(c.hi as Vector3)-(c.lo as Vector3)))
	return out

func _add(pose: Dictionary) -> void:
	var rise: Node3D = Rise.new()
	rise.name = "Hall%d" % int(pose.index)
	rise.transform = ChainPlan.xform(pose)
	rise.sea_y = sea_top-float(pose.origin.y)
	rise.take_per_frame = TAKE_PER_FRAME
	rise.plane_box = _box_for.bind(rise)
	add_child(rise)
	var given := rise_opts.duplicate()
	given.template = template if ChainPlan.hand_of(pose) > 0 else template_left
	given.materials = materials
	rise.setup(given)
	rise.play()
	var h := {"index":int(pose.index),"pose":pose,"rise":rise,"progress":0.0,"next":false,"born":clock,"triggered_at":-1.0}
	halls.append(h)
	spawns.append({"index":int(pose.index),"setup":rise.setup_usec,"frame":0,"total":0})
	made += 1
	_extend_route(h)
	_cap()
	most = maxi(most,standing_count())
	spawned.emit(int(pose.index))

## The plane's box (world) in a hall's frame.
func _box_for(rise: Node3D) -> AABB:
	if not plane_box.is_valid() or not rise.is_inside_tree(): return AABB()
	var box: AABB = plane_box.call()
	if box.size == Vector3.ZERO: return box
	return AABB(rise.to_local(box.get_center())-box.size*0.5,box.size)

## One frame: every hall's rise or sink, the newest hall's trigger, the cap.
## `plane_at` is the plane's position (world), or null.
func advance(delta: float, plane_at: Variant) -> void:
	clock += delta
	for h: Dictionary in halls:
		var rise: Node3D = h.rise
		rise.advance(delta)
	for s: Dictionary in spawns:
		var h := hall(int(s.index))
		if h.is_empty(): continue
		s.frame = h.rise.frame_take_usec
		s.total = int(s.setup)+int(h.rise.take_total_usec)
	if plane_at != null and not halls.is_empty():
		for h: Dictionary in halls:
			if h.rise.sinking: continue
			var local: Vector3 = (h.rise as Node3D).to_local(plane_at)
			var got := ChainPlan.progress_at(ChainPlan.local(local,ChainPlan.hand_of(h.pose)))
			if got.y <= NEAR: h.progress = maxf(float(h.progress),got.x)
		var newest: Dictionary = halls[-1]
		if not bool(newest.next) and float(newest.progress) >= float(cfg.at): spawn_next()
	_cap(plane_at)
	var k := 0
	while k < halls.size():
		if bool(halls[k].rise.gone):
			_free(halls[k])
			halls.remove_at(k)
			sunk_count += 1
			_trim_route()
			continue
		k += 1

## The hall with index `index` ({} if not up).
func hall(index: int) -> Dictionary:
	for h: Dictionary in halls:
		if int(h.index) == index: return h
	return {}

## How many halls stand (not sinking).
func standing_count() -> int:
	var n := 0
	for h: Dictionary in halls:
		if not h.rise.sinking: n += 1
	return n

## Past `keep`, the oldest standing hall sinks (once the plane is clear of it).
func _cap(plane_at: Variant = null) -> void:
	if int(cfg.keep) <= 0: return
	while standing_count() > int(cfg.keep):
		var oldest := {}
		for h: Dictionary in halls:
			if not h.rise.sinking:
				oldest = h
				break
		if oldest.is_empty(): return
		if plane_at != null and _near(oldest,plane_at): return
		(oldest.rise as Node3D).sink()

func _near(h: Dictionary, at: Vector3) -> bool:
	var local: Vector3 = (h.rise as Node3D).to_local(at)
	for b: AABB in boxes():
		if b.grow(SINK_CLEAR).has_point(local): return true
	return false

func _free(h: Dictionary) -> void:
	var rise: Node3D = h.rise
	if is_instance_valid(rise):
		remove_child(rise)
		rise.queue_free()

# --- The route --------------------------------------------------------------------------

func _extend_route(h: Dictionary) -> void:
	if not _route_halls.is_empty():
		var prev: Dictionary = _route_halls[-1]
		var pts := ChainPlan.arc(prev.pose,h.pose)
		route.append_array(pts)
		prev.count = int(prev.count)+pts.size()
	var pts := ChainPlan.hall_route(h.pose)
	route.append_array(pts)
	_route_halls.append({"index":int(h.index),"pose":h.pose,"count":pts.size()})

## Drops the route's points for halls gone (keeps the first standing one's).
func _trim_route() -> void:
	while _route_halls.size() > 0 and hall(int(_route_halls[0].index)).is_empty():
		var n := int(_route_halls[0].count)
		route = route.slice(n)
		route_base += n
		_route_halls.remove_at(0)

## Route point at global index `g` (clamped).
func route_at(g: int) -> Vector3:
	return route[clampi(g-route_base,0,route.size()-1)]

func route_end() -> int:
	return route_base+route.size()-1

## Where the plane starts: `out` m before the first hall's way in, flying
## in along it. [position, heading].
func start(out: float) -> Array:
	var pose: Dictionary = halls[0].pose if not halls.is_empty() else first_pose()
	var head := ChainPlan.in_heading(pose)
	return [ChainPlan.approach_of(pose)-ChainPlan.ahead(head)*out,head]

# --- The cloud -------------------------------------------------------------------------

## The sea's swells (world: x, z, radius, height), up to HallRise.SWELLS,
## the nearest `near` first.
func swells(near: Vector3) -> Array[Vector4]:
	var all: Array[Vector4] = []
	for h: Dictionary in halls:
		var rise: Node3D = h.rise
		for v: Vector4 in rise.swells():
			var w: Vector3 = rise.to_global(Vector3(v.x,0.0,v.y))
			all.append(Vector4(w.x,w.z,v.z,v.w))
	all.sort_custom(func(a: Vector4, b: Vector4) -> bool: return Vector2(a.x,a.y).distance_squared_to(Vector2(near.x,near.z)) < Vector2(b.x,b.y).distance_squared_to(Vector2(near.x,near.z)))
	if all.size() > Rise.SWELLS: all.resize(Rise.SWELLS)
	return all

# --- The autopilot ---------------------------------------------------------------------

## A simple pursuit pilot along the route (the study's P key, the tests):
## it aims at the first route point at least `look` m ahead of the nearest
## one it has reached, and banks and pitches toward it. Fills SkyPlane.step's
## input. `at` is its route index so far (global); returns [input, at].
func steer(plane: RefCounted, at: int, look := 8.0) -> Array:
	var pos: Vector3 = plane.position
	var g := maxi(at,route_base)
	var end := route_end()
	# The nearest point a little way on from where it was.
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
	var aim := route_at(target)
	var to := aim-pos
	var want_head := ChainPlan.heading_of(to)
	var err := wrapf(want_head-float(plane.heading),-PI,PI)
	var flat := Vector2(to.x,to.z).length()
	var want_pitch := atan2(to.y,maxf(flat,1.0))
	var input := {"turn":clampf(-err*3.0,-1.0,1.0),"pitch":clampf((want_pitch-float(plane.pitch))*2.5,-1.0,1.0)}
	return [input,g]

## How the chain stands, for the HUD: {made, standing, sinking, newest
## (index), progress (the newest's, 0-1), at, spawn (the newest's costs)}.
func status() -> Dictionary:
	var sinking := 0
	for h: Dictionary in halls:
		if h.rise.sinking: sinking += 1
	var newest: Dictionary = halls[-1] if not halls.is_empty() else {}
	return {"made":made,"standing":standing_count(),"sinking":sinking,"newest":int(newest.get("index",-1)),"progress":float(newest.get("progress",0.0)),
		"at":float(cfg.at),"spawn":spawns[-1] if not spawns.is_empty() else {},"sunk":sunk_count}
