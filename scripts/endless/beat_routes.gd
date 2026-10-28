extends Node
## Beat routes (endless flight; docs/design/endless-flight/spec-wild-loop.md,
## lane `beats`): a route played one beat at a time.
##
## Starters: at most one per CELL m square by the seed (like split_sites.gd),
## over open, dry, level land, a ring RING_UP m up (beat_marks.gd). A cell's
## route is planned when its square comes within PLAN_REACH m, one square a
## frame; a square whose route can't be built has no starter.
##
## The route: BEATS_MIN to BEATS_MOST beats, each picked from points LEG m
## on within OFFS of the way so far by what is there (a split, a crest, a
## river, the sea, a meadow, a rise) and by how the land rolls along the
## leg, a new kind over the last and a turn the other way scoring more;
## then a landing on a strip by the finish (rival_strip.gd `find`). Each
## beat's time is the safe, wide line's: the leg straight but climbed over
## the highest land on it (CLIMB_COST a metre up), turned on TURN_R m, at
## SAFE_PACE of cruise, plus SLACK s. A shortcut, a dive or the boost
## gains. The last beat is to stop on the strip.
##
## The run: flown through a starter (none while the rival race runs; the
## rival offers none while a route runs), the pan (beat_pan.gd) with the
## flight held, then one beat at a time, flashing faster as its time runs
## out, the finish's beacon always up. Taken within TAKE_R m, any way.
## Spare time adds to the score (--beat-spare=carry: to the next beat's
## time instead). Late: the beat fades and the route ends with what it got.
## The book: `find("starter/<id>")`, `challenge_done({id, kind "beats",
## got, of, time, points, money, done})`.
##
## The game (studies/endless_flight.gd) holds one (`beats`), holds the
## flight while `holding()` and calls `step` after its `_frame`.

const BeatMarks = preload("res://scripts/endless/beat_marks.gd")
const BeatPan = preload("res://scripts/endless/beat_pan.gd")
const RivalStrip = preload("res://scripts/endless/rival_strip.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const SEA_Y := -40.0
## The squares (m), kept in from their edges (m), the share with a starter,
## the spots tried in one.
const CELL := 1600.0
const MARGIN := 320.0
const CHANCE := 0.85
const TRIES := 24
## Planned within (m of the square's middle); starters shown within (m).
const PLAN_REACH := 2600.0
const SHOW_REACH := 1900.0
## A strip looked for ahead of a beat: at most this many spots; the search's
## time a frame (us).
const STRIP_TRIES := 120
## The flats read for it: a grid this far apart (m), this far out (m).
const STRIP_GRID := 100.0
const STRIP_REACH := 1300.0
const SLICE_US := 4000
## The ring's height over the land (m); flown through within THROUGH_R m.
const RING_UP := 40.0
const THROUGH_R := 14.0
## Open land for a starter: no rise past LEVEL m within LEVEL_R m round,
## DRY m over the sea, RIVER_OFF m off a river.
const LEVEL := 18.0
const LEVEL_R := 60.0
const DRY := 6.0
const RIVER_OFF := 70.0
## Beats a route (before its landing); legs (m on) and turns (rad) tried.
const BEATS_MIN := 4
const BEATS_MOST := 6
const LEG := [440.0,580.0,720.0]
const OFFS := [0.0,0.35,-0.35,0.7,-0.7,1.05,-1.05]
## A beat no nearer another (or the starter) than this (m).
const APART := 320.0
## A beat's height over what is there (m) by its kind.
const CLEAR := {"split":16.0,"crest":18.0,"river":10.0,"sea":10.0,"meadow":9.0,"rise":14.0}
## And over the land ROUND_R m round it by ROUND_CLEAR m (a slope).
const ROUND_R := 35.0
const ROUND_CLEAR := 8.0
## What a kind is worth when picking.
const WORTH := {"split":1.4,"crest":1.0,"river":0.9,"sea":0.6,"meadow":0.5,"rise":0.2}
## A beat is taken within this (m) across, TAKE_TALL times that up or down.
const TAKE_R := 9.0
const TAKE_TALL := 1.4
## The safe line: its pace (share of cruise), the climb's cost (m of line
## a metre up), its turns' radius (m), what is flown over (m over the land:
## the trees), the slack (s).
const SAFE_PACE := 0.9
const CLIMB_COST := 2.5
const TURN_R := 130.0
const OVER := 16.0
const SLACK := 3.0
## The landing: its pace over the final and the roll, the time to set down
## and stop (s).
const LAND_PACE := 0.75
const LAND_EXTRA := 26.0
## Points: a beat, the finish, a spare second; money likewise (placeholders:
## the trunk tunes them).
const BEAT_POINTS := 100
const DONE_POINTS := 300
const SPARE_POINTS := 10
const BEAT_MONEY := 8
const DONE_MONEY := 30
## A taken beat's fade, a missed beat's, the result's hold (s).
const TAKEN_FADE := 0.35
const MISS_FADE := 1.4
const RESULT_HOLD := 4.5
## A starter rests this long after its route (s).
const REST := 45.0

## "free", "pan", "run", "end".
var state := "free"
## The route running (or last run): {id, starter {at, axis, ground}, beats
## [{at, ground, kind, len}], strip, finish, land_len}.
var route := {}
## The beat on (its index; beats.size() is the landing), its time left, the
## route's clock, taken, spare carried, the margins at each beat.
var beat_i := 0
var left := 0.0
var clock := 0.0
var got := 0
var spare_points := 0
var margins: Array = []
var times: Array = []
var result := {}
## --beat-spare=carry: spare carried on, not scored.
var carry := false

var _seed := 0
var _game: Node
var _cells := {}
var _starters := {}
var _rest := {}
var _t := 0.0
var _marks: Node3D
var _pan: RefCounted
var _live: Array = []
var _finish: Node3D
var _fade := 0.0
var _end_t := 0.0
var _armed := false
var _reader: RefCounted
var _hud: Control
var _per_beat := 0.0
var _busy := false
var _slice := 0

## What RivalStrip reads the land with (rival_line.gd's `_ground_top`).
class Reader extends RefCounted:
	var game: Node
	func _init(g: Node) -> void:
		game = g
	func _ground_top(p: Vector3, spans: bool) -> float:
		var h := maxf(float(game.field.height(p.x,p.z)),SEA_Y)
		if game.get("rocks") != null: h = maxf(h,float(game.rocks.top_near(p,6.0)))
		if spans:
			var g: Variant = game.plane_ground(Vector3(p.x,h+400.0,p.z))
			if g is Vector2: return maxf(h,(g as Vector2).x)
			if g != null: return maxf(h,float(g))
			return h
		if game.trees != null:
			var t: Variant = game.trees.ground(Vector3(p.x,h+400.0,p.z),h)
			if not t is Vector2 and t != null: h = maxf(h,float(t))
		return h

func setup(seed: int, game: Node) -> void:
	name = "BeatRoutes"
	_seed = seed
	_game = game
	_reader = Reader.new(game)
	for a: String in OS.get_cmdline_user_args():
		if a == "--beat-spare=carry": carry = true
	_marks = BeatMarks.new()
	add_child(_marks)
	_pan = BeatPan.new()
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Hud.new()
	_hud.routes = self
	layer.add_child(_hud)

## A route running (the pan or the beats): the rival offers none meanwhile.
func running() -> bool:
	return state == "pan" or state == "run"

## The pan holds the flight.
func holding() -> bool:
	return state == "pan" and _pan.phase == "pan"

## The beat on now (its at), or null.
func beat_at() -> Variant:
	if state != "run": return null
	if beat_i < (route.beats as Array).size(): return route.beats[beat_i].at
	return route.finish

## One frame, after the game's `_frame` (the camera placed by the chase).
func step(delta: float, game: Node) -> void:
	_t += delta
	var in_menu: bool = game.stage != null
	_marks.visible = not in_menu
	_hud.visible = not in_menu and game.overlay == null
	if in_menu: return
	_plan_near(game.plane.position)
	match state:
		"free": _free(game)
		"pan": _panning(delta,game)
		"run": _run(delta,game)
		"end": _ending(delta)
	_hud.queue_redraw()

# --- Starters ---------------------------------------------------------------

func _hash01(i: int, j: int, salt: int) -> float:
	return float(hash([_seed,i,j,salt,5519]) & 0xffffff)/float(0x1000000)

static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/CELL),floori(z/CELL))

## The squares round `p` planned, the nearest first, one a frame.
func _plan_near(p: Vector3) -> void:
	var home := cell_of(p.x,p.z)
	var best := Vector2i.ZERO
	var best_d := INF
	for dj in range(-2,3):
		for di in range(-2,3):
			var key := home+Vector2i(di,dj)
			if _cells.has(key): continue
			var mid := (Vector2(key)+Vector2(0.5,0.5))*CELL
			var d := mid.distance_to(Vector2(p.x,p.z))
			if d < PLAN_REACH and d < best_d:
				best_d = d
				best = key
	if best_d < INF and not _busy: _plan_cell(best)

## The square `key`'s route (or none), planned and its starter built. A
## coroutine: the strip's search goes on over frames, SLICE_US a frame.
func _plan_cell(key: Vector2i) -> Dictionary:
	while _busy: await get_tree().process_frame
	if _cells.has(key): return _cells[key]
	_busy = true
	_cells[key] = {"planning":true}
	_slice = Time.get_ticks_usec()
	var r: Dictionary = await plan(key)
	_busy = false
	_cells[key] = r
	if not r.is_empty():
		var s: Dictionary = r.starter
		_starters[r.id] = _marks.starter(s.at,s.axis,float(s.ground))
	return r

## The route for square `key`, or {} (no starter there). Deterministic by
## the seed for what the land holds.
func plan(key: Vector2i) -> Dictionary:
	if _hash01(key.x,key.y,1) >= CHANCE:
		_fail("chance")
		return {}
	var field: RefCounted = _game.field
	for k in TRIES:
		var x := float(key.x)*CELL+MARGIN+_hash01(key.x,key.y,10+k)*(CELL-2.0*MARGIN)
		var z := float(key.y)*CELL+MARGIN+_hash01(key.x,key.y,40+k)*(CELL-2.0*MARGIN)
		if not _open(field,x,z):
			_fail("open")
			continue
		var h := float(field.height(x,z))
		var bearing := _hash01(key.x,key.y,70+k)*TAU
		var axis := Vector3(-sin(bearing),0.0,-cos(bearing))
		var at := Vector3(x,h+RING_UP,z)
		var r: Dictionary = await _route(key,at,axis,h)
		if not r.is_empty(): return r
		_fail("route")
	return {}

## Why squares came up empty, by reason (for checks).
static var fails := {}
static func _fail(why: String) -> void:
	fails[why] = int(fails.get(why,0))+1

## Open land at (x, z): dry, off a river, level round, not in a split.
func _open(field: RefCounted, x: float, z: float) -> bool:
	var h := float(field.sample(x,z).x)
	if h < SEA_Y+DRY: return _no("open_sea")
	if float(field.last_river) < RIVER_OFF: return _no("open_river")
	if not (field.split_at(x,z,40.0) as PackedFloat32Array).is_empty(): return _no("open_split")
	for a in 6:
		var d := Vector2(cos(a*TAU/6.0),sin(a*TAU/6.0))*LEVEL_R
		if absf(float(field.height(x+d.x,z+d.y))-h) > LEVEL: return _no("open_level")
	return true

static func _no(why: String) -> bool:
	_fail(why)
	return false

## What is at `p` (XZ): {kind, at (the beat there), ground}.
func _read(field: RefCounted, p: Vector3) -> Dictionary:
	var s: Vector2 = field.sample(p.x,p.z)
	var h := s.x
	var mountain := float(field.last_mountain)
	var river := float(field.last_river)
	var kind := "rise"
	var floor_y := maxf(h,SEA_Y)
	if h < SEA_Y+1.0: kind = "sea"
	elif not (field.split_at(p.x,p.z,0.0) as PackedFloat32Array).is_empty(): kind = "split"
	elif river < 50.0:
		kind = "river"
		floor_y = maxf(floor_y,float(_game.water_at(Vector3(p.x,h+1.0,p.z))))
	elif mountain > 0.55: kind = "crest"
	elif s.y > 0.5: kind = "meadow"
	# On a slope: over the land round it too, never into the hill.
	var round_top := floor_y
	for k in 4:
		var e := Vector2(cos(k*PI*0.5),sin(k*PI*0.5))*ROUND_R
		round_top = maxf(round_top,float(field.height(p.x+e.x,p.z+e.y)))
	var y := maxf(floor_y+float(CLEAR[kind]),round_top+ROUND_CLEAR)
	return {"kind":kind,"at":Vector3(p.x,y,p.z),"ground":floor_y}

## The beats from the starter at `at` along `axis`, and the landing: the
## route, or {} when no strip is found by the last beat.
func _route(key: Vector2i, at: Vector3, axis: Vector3, ground: float) -> Dictionary:
	var field: RefCounted = _game.field
	var n := BEATS_MIN+int(_hash01(key.x,key.y,2)*float(BEATS_MOST-BEATS_MIN+1))
	n = mini(n+1,BEATS_MOST)
	var cur := at
	var way := axis
	var beats: Array = []
	var kinds: Array = []
	var last_off := 0.0
	var used: Array = [at]
	var ways: Array = []
	for i in n:
		var bearing := atan2(-way.x,-way.z)
		var best := {}
		var best_score := -INF
		var best_off := 0.0
		for j in LEG.size():
			for o in OFFS.size():
				var off: float = OFFS[o]
				var b := bearing+off
				var p := cur+Vector3(-sin(b),0.0,-cos(b))*float(LEG[j])
				var near := false
				for u: Vector3 in used:
					if Vector2(u.x-p.x,u.z-p.z).length() < APART: near = true
				if near: continue
				var r := _read(field,p)
				var score := float(WORTH[r.kind])
				var prev: String = kinds[-1] if not kinds.is_empty() else "start"
				score += 0.6 if r.kind != prev else -0.5
				score += minf(_relief(field,cur,p),150.0)/100.0
				score -= absf(off)*0.35
				if off != 0.0 and signf(off) != signf(last_off): score += 0.25
				score += _hash01(key.x*31+i,key.y*17+j,100+o)*0.35
				if score > best_score:
					best_score = score
					best = r
					best_off = off
		if best.is_empty():
			_fail("beat")
			return {}
		var bat: Vector3 = best.at
		best["len"] = _safe_len(field,cur,bat,way)
		beats.append(best)
		kinds.append(best.kind)
		used.append(bat)
		way = Vector3(bat.x-cur.x,0.0,bat.z-cur.z).normalized()
		ways.append(way)
		cur = bat
		last_off = best_off
	# The landing: a strip ahead of the last beat, else of the one before
	# (the route cut there), down to BEATS_MIN.
	var strip := {}
	var last := beats.size()-1
	while last >= BEATS_MIN-1 and strip.is_empty():
		var from: Vector3 = beats[last].at
		var dir: Vector3 = ways[last]
		strip = await _strip_near(field,from,dir)
		if strip.is_empty(): last -= 1
	if strip.is_empty():
		_fail("strip")
		return {}
	beats = beats.slice(0,last+1)
	cur = beats[last].at
	way = ways[last]
	var id := "%d_%d" % [key.x,key.y]
	var r := {"id":id,"starter":{"at":at,"axis":axis,"ground":ground},"beats":beats,"strip":strip}
	_land_spot(r)
	var approach: Vector3 = strip.approach
	r["land_len"] = _safe_len(field,cur,approach,way)+RivalStrip.FINAL+RivalStrip.ROLL
	return r

## A strip near `from` (come in along `dir`): the flats round it read on a
## grid (STRIP_GRID m apart, out to STRIP_REACH m, ahead first), the levelest
## meadows tried with RivalStrip's whole check at a few headings. {} if none.
func _strip_near(field: RefCounted, from: Vector3, dir: Vector3) -> Dictionary:
	var spots: Array = []
	var n := int(STRIP_REACH/STRIP_GRID)
	for j in range(-n,n+1):
		for i in range(-n,n+1):
			var o := Vector3(float(i),0.0,float(j))*STRIP_GRID
			var d := o.length()
			if d > STRIP_REACH or d < 250.0: continue
			var c := from+o
			var s: Vector2 = field.sample(c.x,c.z)
			if s.x < SEA_Y+3.0 or float(field.last_river) < 30.0: continue
			var rise := 0.0
			for a in 4:
				var e := Vector3(cos(a*PI*0.5),0.0,sin(a*PI*0.5))*90.0
				rise = maxf(rise,absf(float(field.height(c.x+e.x,c.z+e.z))-s.x))
			if rise > 4.0: continue
			var ahead := o.normalized().dot(dir)
			spots.append([rise*0.5-s.y*2.0-ahead*1.0+d/STRIP_REACH,c])
	spots.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var tried := 0
	for sp: Array in spots:
		if tried >= STRIP_TRIES: break
		var c: Vector3 = sp[1]
		var toward := Vector3(c.x-from.x,0.0,c.z-from.z).normalized()
		var base := atan2(-toward.x,-toward.z)
		for turn: float in [0.0,0.5,-0.5,1.0,-1.0,PI]:
			var yaw := base+turn
			var axis := Vector3(-sin(yaw),0.0,-cos(yaw))
			for side: float in [1.0,-1.0]:
				tried += 1
				var touch := c-axis*RivalStrip.ROLL*0.5-axis.cross(Vector3.UP)*side*RivalStrip.lane()*0.5
				touch.y = float(field.height(touch.x,touch.z))
				var st := RivalStrip.check(_game,_reader,touch,axis,side)
				if not st.is_empty(): return st
				if Time.get_ticks_usec()-_slice > SLICE_US:
					await get_tree().process_frame
					_slice = Time.get_ticks_usec()
	return {}

## The landing's box and the finish's beacon, from the strip.
func _land_spot(r: Dictionary) -> void:
	var s: Dictionary = r.strip
	var axis: Vector3 = s.axis
	var across: Vector3 = s.across
	var lane := float(s.lane)
	var touch: Vector3 = s.touch
	var stop: Vector3 = s.stop
	var from := touch-axis*RivalStrip.TOUCH_ZONE+across*lane*0.5
	var to := stop+axis*RivalStrip.RUN_ON+across*lane*0.5
	var end := to+axis*12.0
	r["finish"] = Vector3(end.x,float(_game.field.height(end.x,end.z)),end.z)
	r["land_from"] = from
	r["land_to"] = to
	r["land_wide"] = lane+WorldScale.span*6.0

## Whether `p` stands in the route's landing box.
func on_strip(r: Dictionary, p: Vector3) -> bool:
	var from: Vector3 = r.land_from
	var to: Vector3 = r.land_to
	var way := Vector3(to.x-from.x,0.0,to.z-from.z)
	var len := way.length()
	way /= len
	var o := Vector3(p.x-from.x,0.0,p.z-from.z)
	var u := o.dot(way)
	var v := o.dot(way.cross(Vector3.UP))
	return u >= -20.0 and u <= len+20.0 and absf(v) <= float(r.land_wide)*0.5

## How much the land rolls along a leg (m, highest less lowest).
func _relief(field: RefCounted, a: Vector3, b: Vector3) -> float:
	var lo := INF
	var hi := -INF
	for i in 9:
		var p := a.lerp(b,float(i)/8.0)
		var h := maxf(float(field.height(p.x,p.z)),SEA_Y)
		lo = minf(lo,h)
		hi = maxf(hi,h)
	return hi-lo

## The safe, wide line's length from `a` to `b`, come in along `way`: the
## leg, the climb over its highest land (CLIMB_COST a metre), the turn.
func _safe_len(field: RefCounted, a: Vector3, b: Vector3, way: Vector3) -> float:
	var top := -INF
	for i in range(1,12):
		var p := a.lerp(b,float(i)/12.0)
		top = maxf(top,maxf(float(field.height(p.x,p.z)),SEA_Y)+OVER)
	var up := maxf(top-a.y,0.0)+maxf(b.y-maxf(top,a.y),0.0)
	var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
	var turn := 0.0
	if flat.length() > 1.0 and way.length() > 0.1: turn = way.angle_to(flat.normalized())
	return a.distance_to(b)+up*CLIMB_COST+turn*TURN_R

## Starters shown near, hidden while the rival races; flown through: the run.
func _free(game: Node) -> void:
	var racing: bool = game.get("race") != null and String(game.race.state) != "free"
	var p: Vector3 = game.plane.position
	var flying: bool = game.hand_landing.flying()
	for id: String in _starters:
		var s: Node3D = _starters[id]
		var d := s.global_position.distance_to(p)
		var resting := _rest.has(id) and _t < float(_rest[id])
		s.visible = not racing and not resting and d < SHOW_REACH
		if s.visible and flying and d < THROUGH_R: _begin(game,id)

func _route_of(id: String) -> Dictionary:
	for r: Dictionary in _cells.values():
		if r.has("id") and r.id == id: return r
	return {}

## Flown through starter `id`: the pan, the flight held.
func _begin(game: Node, id: String) -> void:
	route = _route_of(id)
	if route.is_empty(): return
	state = "pan"
	(_starters[id] as Node3D).visible = false
	game.book.find("starter/"+id)
	# Each beat's time at this flight's cruise.
	var v := float(game.plane.cruise())
	times = []
	for b: Dictionary in route.beats: times.append(float(b.len)/(v*SAFE_PACE)+SLACK)
	times.append(float(route.land_len)/(v*LAND_PACE)+LAND_EXTRA)
	# The marks: every beat dim for the pan, the finish up.
	for m: Node in _live: m.queue_free()
	_live = []
	for b: Dictionary in route.beats: _live.append(_marks.beat(b.at,float(b.ground)))
	var s: Dictionary = route.strip
	_finish = _marks.finish(route.finish,route.land_from,route.land_to,s.across,float(route.land_wide),Callable(game.field,"height"))
	for m: Node3D in _live: BeatMarks.dim(m,0.8)
	var targets: Array = [route.starter.at]
	for b: Dictionary in route.beats: targets.append(b.at)
	targets.append(route.finish)
	_pan.begin(game.camera.global_transform,targets)
	_armed = false
	beat_i = 0
	clock = 0.0
	got = 0
	spare_points = 0
	margins = []
	result = {}
	print("beat route %s: %d beats and a landing, %s s" % [id,(route.beats as Array).size(),str(times.map(func(t: float) -> String: return "%.1f" % t))])

func _panning(delta: float, game: Node) -> void:
	if _pan.phase == "pan":
		var asked := _fly_asked()
		if not asked: _armed = true
		elif _armed: _pan.skip(game.camera.global_transform)
	var x: Transform3D = _pan.step(delta,game.camera.global_transform)
	game.camera.global_transform = x
	if _pan.phase != "pan":
		# The flight goes on as the camera comes back: the first beat's clock runs.
		state = "run"
		_start_beat(0)

## Any fly input, or Tab.
static func _fly_asked() -> bool:
	for a: StringName in [&"move_left",&"move_right",&"move_forward",&"move_back",&"fly_boost",&"fly_brake",&"fly_lean_left",&"fly_lean_right",&"fly_challenge"]:
		if InputMap.has_action(a) and Input.get_action_strength(a) > 0.3: return true
	return false

func _start_beat(i: int) -> void:
	var spare := left if i > 0 and carry else 0.0
	beat_i = i
	left = float(times[i])+maxf(spare,0.0)
	_per_beat = left
	for k in _live.size(): BeatMarks.dim(_live[k],0.0)
	if i < _live.size():
		_settle(i)
		BeatMarks.dim(_live[i],1.0)
	if _finish != null:
		(_finish as BeatMarks.Beat).posts.visible = i >= _live.size()

## A beat raised over what stands there now that it is built (a tree's
## crown, a rock), so it is never inside one.
func _settle(i: int) -> void:
	var b: Dictionary = route.beats[i]
	var at: Vector3 = b.at
	var top := float(_reader._ground_top(at,false))+6.0
	if top > at.y:
		at.y = top
		b.at = at
		(_live[i] as Node3D).global_position = at

func _run(delta: float, game: Node) -> void:
	if _pan.running(): game.camera.global_transform = _pan.step(delta,game.camera.global_transform)
	clock += delta
	left -= delta
	var p: Vector3 = game.plane.position
	var n := (route.beats as Array).size()
	if beat_i < n:
		var b: Dictionary = route.beats[beat_i]
		var at: Vector3 = b.at
		if p.distance_to(at) < 500.0 and not b.has("settled"):
			b.settled = true
			_settle(beat_i)
			at = b.at
		BeatMarks.flash(_live[beat_i],left/maxf(_per_beat,0.01),clock)
		if Vector2(p.x-at.x,p.z-at.z).length() <= TAKE_R and absf(p.y-at.y) <= TAKE_R*TAKE_TALL:
			got += 1
			margins.append(left)
			if not carry: spare_points += int(round(maxf(left,0.0)*SPARE_POINTS))
			print("beat %d of %d taken: %.1f s to spare" % [beat_i+1,n+1,left])
			_start_beat(beat_i+1)
			return
	else:
		BeatMarks.flash(_finish,left/maxf(_per_beat,0.01),clock)
		var stopped: bool = game.hand_landing.phase == ManualLanding.STOPPED
		if stopped and on_strip(route,p):
			got += 1
			margins.append(left)
			if not carry: spare_points += int(round(maxf(left,0.0)*SPARE_POINTS))
			print("beat %d of %d (the landing) done: %.1f s to spare" % [n+1,n+1,left])
			_finish_route(game,true)
			return
	if left <= 0.0:
		print("beat %d of %d missed" % [beat_i+1,n+1])
		_finish_route(game,false)

func _finish_route(game: Node, done: bool) -> void:
	var n := (route.beats as Array).size()+1
	var points := got*BEAT_POINTS+spare_points+(DONE_POINTS if done else 0)
	var money := got*BEAT_MONEY+(DONE_MONEY if done else 0)+int(spare_points/SPARE_POINTS/4)
	result = {"id":route.id,"kind":"beats","got":got,"of":n,"time":clock,"points":points,"money":money,"done":done,"margins":margins.duplicate()}
	game.book.challenge_done(result.duplicate())
	_rest[route.id] = _t+REST
	state = "end"
	_end_t = 0.0
	print("beat route %s %s: %d of %d, %.1f s, %d points, %d money" % [route.id,"done" if done else "over",got,n,clock,points,money])

func _ending(delta: float) -> void:
	_end_t += delta
	var fade := 1.0-clampf(_end_t/MISS_FADE,0.0,1.0)
	if bool(result.get("done",false)):
		BeatMarks.dim(_finish,fade)
	else:
		if beat_i < _live.size(): BeatMarks.flash(_live[beat_i],0.0,clock+_end_t,fade)
		BeatMarks.dim(_finish,fade)
	if _end_t >= RESULT_HOLD:
		for m: Node in _live: m.queue_free()
		_live = []
		if _finish != null: _finish.queue_free()
		_finish = null
		state = "free"

# --- The HUD -----------------------------------------------------------------

## The route's tag, top middle: the beat and its time, an arrow at the edge
## toward a beat off the screen, the pan's words, the result.
class Hud extends Control:
	const WORDS = preload("res://assets/fonts/newsreader-latin.woff2")
	const NUMS = preload("res://assets/fonts/barlow-semi-condensed-800-italic-latin.woff2")
	const GOLD := Color("ffd36b")
	const CREAM := Color("f6f3ea")
	const LOST := Color("ff8a6b")
	const EDGE := Color(0.23,0.15,0.04,0.8)
	var routes: Node

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _k() -> float:
		return get_viewport_rect().size.y/1440.0

	func _draw() -> void:
		var r: Node = routes
		var k := _k()
		var mid := Vector2(get_viewport_rect().size.x*0.5,120.0*k)
		match String(r.state):
			"pan":
				var n := (r.route.beats as Array).size()+1
				_line(WORDS,"a route  ·  %d beats, the last a landing" % n,mid,40.0*k,CREAM,k)
				_line(WORDS,"fly or Tab to skip",mid+Vector2(0.0,48.0*k),28.0*k,Color(CREAM,0.7),k)
			"run":
				var n := (r.route.beats as Array).size()+1
				var i := int(r.beat_i)+1
				var what := "land on the strip" if i == n else "beat %d of %d" % [i,n]
				_line(WORDS,what,mid,34.0*k,CREAM,k)
				var t := maxf(float(r.left),0.0)
				var col := GOLD if t > 5.0 else LOST
				_line(NUMS,("%.1f" % t) if t < 10.0 else "%d" % ceili(t),mid+Vector2(0.0,70.0*k),64.0*k,col,k)
				_arrow(r,k)
			"end":
				var res: Dictionary = r.result
				var a := 1.0-clampf((float(r._end_t)-3.5)/1.0,0.0,1.0)
				var head := "route flown" if bool(res.get("done",false)) else "route over"
				_line(WORDS,"%s  ·  %d of %d" % [head,int(res.got),int(res.of)],mid,40.0*k,Color(CREAM,a),k)
				_line(NUMS,"+%d" % int(res.money),mid+Vector2(0.0,72.0*k),60.0*k,Color(GOLD,a),k)

	func _line(font: Font, text: String, at: Vector2, px: float, col: Color, k: float) -> void:
		var size := maxi(roundi(px),8)
		var w := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var p := at-Vector2(w*0.5,0.0)
		draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,maxi(roundi(7.0*k),2),Color(EDGE.r,EDGE.g,EDGE.b,EDGE.a*col.a))
		draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,col)

	## A gold facet at the screen's edge toward the beat when it is off screen.
	func _arrow(r: Node, k: float) -> void:
		var at: Variant = r.beat_at()
		if at == null: return
		var cam := get_viewport().get_camera_3d()
		if cam == null: return
		var size := get_viewport_rect().size
		var p: Vector3 = at
		var behind := cam.is_position_behind(p)
		var s := cam.unproject_position(p)
		var inset := 70.0*k
		if not behind and s.x > inset and s.x < size.x-inset and s.y > inset and s.y < size.y-inset: return
		var c := size*0.5
		var d := s-c
		if behind: d = -d
		if d.length() < 1.0: d = Vector2(0.0,1.0)
		d = d.normalized()
		var reach := minf((size.x*0.5-inset)/maxf(absf(d.x),0.001),(size.y*0.5-inset)/maxf(absf(d.y),0.001))
		var tip := c+d*reach
		var side := Vector2(-d.y,d.x)
		var r_ := 22.0*k
		var pts := PackedVector2Array([tip+d*r_,tip-d*r_*0.6+side*r_*0.8,tip-d*r_*0.6-side*r_*0.8])
		if r_ < 1.0: return
		draw_primitive(pts,PackedColorArray([Color(0,0,0,0.45)]),PackedVector2Array())
		draw_primitive(PackedVector2Array([tip+d*r_*0.8,tip-d*r_*0.4+side*r_*0.6,tip-d*r_*0.4-side*r_*0.6]),PackedColorArray([GOLD]),PackedVector2Array())
