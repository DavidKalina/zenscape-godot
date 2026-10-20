extends RefCounted
## The Olmec's place graph (scripts/enemies/headless_body.gd `plan_chase`):
## the places his whole body fits in a study, and his moves between them,
## each checked the way his own move checks itself, built once ahead (the
## study's load, `make` then `step` or `build_all`) for one body, shared by
## every Olmec of that field (`of`).
##
## The places are body_routes.gd's: a 1.5 m column's floor, read with rays,
## that his footprint fits (room over it for his whole bulk, his head on
## too: `routes.room` is his bulk's top, not his neck). Its own column reads
## (`routes.cols`), so the roaming bodies' reads at their neck's room don't
## mix with his.
##
## His moves from a place (`moves`):
##   walk   to the column beside it he fits (or a narrow way on, the fallen
##          pillar's crest: body_routes' NARROW), as body_routes walks;
##   climb  a face ahead he can climb from its foot (`_climb_at`: the face
##          meets his floor, no shelf short of the lip, his bulk hung on it
##          clear all the way up (`_climb_column`: no overhang), no roof
##          over the lip, room for his whole body past it);
##   jump   across a gap to a ledge (`_ledge`), its arc flown with his bulk;
##   drop   off a rim to a floor down there (out to `down_reach` Hh, down to
##          `down_deep` Hh), his bulk clear on one of his drop arcs
##          (`drop_bulk`), room for him where he lands;
##   cliff  a leap at a face across the gap (`cliff_gap` Hh off, `cliff_deep`
##          Hh down), only where his dry run catches it (`_catch_ok`), then
##          up it.
## Each special move (all but walk) keeps what his body needs to make it
## (where he throws himself, the arc's rise, the face, its lip), so the
## follower carries out the move that was checked, and checks it again from
## where he really stands before he goes.
##
## Built as jobs (one place's special moves each), `step(usec)` a slice at
## a time, or all at once (`build_all`); a place the build hasn't reached is
## built when the search first comes to it. A break (`forget(box)`) lets
## go of the box's columns and the moves from and into it; they are built
## again as the search comes to them.
##
## `Search`: an A* over these moves, a slice of a frame at a time, from
## where he stands to within `goal_r` of a goal; none gets there, the way to
## the place nearest the goal he can get to (`found` false).

const Routes = preload("res://scripts/enemies/body_routes.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DIRS := Routes.DIRS
const NONE := Routes.NONE
const CELL := Routes.CELL
## Costs (m of walking) of a move over its length.
const COST_CLIMB := 6.0
const COST_JUMP := 6.0
const COST_DROP := 5.0
const COST_CLIFF := 10.0
## A face to climb looked for this far along each way (m): his places
## (room for his whole bulk) stand back off an overhanging foot.
const CLIMB_LOOK := 12.0
const CLIMB_COLS := 8
## A drop's landings kept along a way at most, and how far apart (m).
const DROP_KEEP := 3
const DROP_APART := 5.0
## The build's arcs flown at this times his own step (the follower flies
## the arc again at his own before he goes).
const ARC_COARSE := 4.0
## A goal is reached within its radius flat and this up or down (m).
const GOAL_DY := 3.0
## Places expanded at most in one search.
const MOST := 30000
## A special move this near (m) a spot a move failed at is banned with it.
const BAN_NEAR := 3.5

## {field instance id: graph}.
static var _graphs := {}

var routes: Routes
var probe: Node3D
var field: Node
## Special moves per place, built: {Vector3i: Array[Dictionary]}.
var special := {}
## Room for his bulk on a place he doesn't fit (a landing, a narrow
## terrace): {Vector3i: bool}.
var _room := {}
var _queue: Array = []
var _queued := {}
var _qi := 0
var built := false
## The build's costs, for the study's line and checks.
var build_us := 0
var build_jobs := 0
var kinds := {}
var places := 0
var box := AABB()
var rays_at_build := 0
## Breaks let go of (`forget`), counted.
var forgets := 0
## Why climbs looked at were passed over (the body's `climb_why`), counted.
var passed := {}

## The graph of `field`, null none.
static func of(f: Node) -> RefCounted:
	if f == null: return null
	return _graphs.get(f.get_instance_id())

## A graph for `body` (set up: an Olmec, live or a probe off the tree, with
## his knobs and his `breaker`), over the columns in `boxes` (AABBs, world):
## its places read and fitted now, its moves queued. Registered for his field.
static func make(body: Node3D, boxes: Array) -> RefCounted:
	var g = load("res://scripts/enemies/olmec_route_graph.gd").new()
	g._setup(body,boxes)
	for k: int in _graphs.keys():
		if not is_instance_id_valid(k): _graphs.erase(k)
	_graphs[body.field.get_instance_id()] = g
	return g

func _setup(body: Node3D, boxes: Array) -> void:
	probe = body
	field = body.field
	routes = Routes.new(body)
	routes.cols = {}
	routes.room = body._bulk_top()
	routes.refresh()
	var t0 := Time.get_ticks_usec()
	var seen := {}
	for b: AABB in boxes:
		box = b if box.size == Vector3.ZERO else box.merge(b)
		var lo := Routes.cell_of(b.position)
		var hi := Routes.cell_of(b.end)
		for x in range(lo.x,hi.x+1):
			for z in range(lo.y,hi.y+1):
				var c := Vector2i(x,z)
				if seen.has(c): continue
				seen[c] = true
				var f := routes.col(c)
				for i in range(f.size()/2):
					var u := Vector3i(x,z,i)
					if routes.fits(u):
						places += 1
						_queued[u] = true
						_queue.append(u)
	build_us += Time.get_ticks_usec()-t0

## The body whose checks build the moves (a live Olmec's, once the probe is
## gone: his size is the probe's).
func use(body: Node3D) -> void:
	if body == null or not is_instance_valid(body) or body == probe: return
	if probe != null and is_instance_valid(probe) and probe.is_inside_tree(): return
	probe = body
	routes._skip = body._skip

## The bodies left out of the rays as they are now (its body's; none to
## ask once that body is gone, the last kept).
func refresh() -> void:
	if routes._skip.is_valid(): routes.refresh()

## A slice of the build, `usec` long at most; true once done.
func step(usec: int) -> bool:
	if built: return true
	if probe == null or not is_instance_valid(probe): return false
	var t0 := Time.get_ticks_usec()
	var until := t0+usec
	refresh()
	while _qi < _queue.size():
		if Time.get_ticks_usec() > until: break
		var u: Vector3i = _queue[_qi]
		_qi += 1
		if not live(u): continue
		if not special.has(u): _build(u)
		# The places his moves reach that he doesn't fit (a narrow way, a
		# landing on a narrow terrace) built too.
		for m: Array in moves(u):
			var v: Vector3i = m[0]
			if not special.has(v) and not _queued.has(v):
				_queued[v] = true
				_queue.append(v)
	build_us += Time.get_ticks_usec()-t0
	if _qi >= _queue.size():
		built = true
		rays_at_build = routes.rays
	return built

## The whole build now.
func build_all() -> void:
	while not step(1000000): pass

## How far through the build (0 to 1).
func progress() -> float:
	return 1.0 if built else float(_qi)/maxf(_queue.size(),1.0)

## Whether place `u`'s floor is still there: a column read again (a break's
## `forget`, a far isle read late) can hold fewer floors than it did.
func live(u: Vector3i) -> bool:
	return u.z >= 0 and u.z*2+1 < routes.col(Vector2i(u.x,u.y)).size()

## Whether he can stand on `u`: he fits it, or his bulk has room there (a
## narrow terrace a leap or a drop lands him on).
func standable(u: Vector3i) -> bool:
	if routes.fits(u) and clear(u): return true
	if _room.has(u): return _room[u]
	var ok: bool = probe != null and is_instance_valid(probe) and probe._room_at(routes.at(u))
	_room[u] = ok
	return ok

## Every move from place `u`: [[to, cost, kind, d (Vector2i, the way), edge
## (the special move's dict, {} walking)], ...].
func moves(u: Vector3i, build := true) -> Array:
	var had: Variant = _adj.get(u)
	if had != null: return had
	if not live(u): return []
	var out: Array = []
	var y := routes.y_of(u)
	var c := Vector2i(u.x,u.y)
	for d: Vector2i in DIRS:
		var len_d := CELL*(1.0 if d.x == 0 or d.y == 0 else 1.4142)
		var n := c+d
		var i := routes.floor_near(n,y,routes.step,routes.step)
		if i < 0: continue
		var v := Vector3i(n.x,n.y,i)
		var cost := len_d+absf(routes.y_of(v)-y)*0.5
		var mid := (Routes.centre(c)+Routes.centre(n))*0.5
		if not routes.between(mid,(y+routes.y_of(v))*0.5): continue
		if not clear(v): continue
		if routes.fits(v): out.append([v,cost,"walk",d,{}])
		elif routes.room_of(v) >= routes.room and routes.floor_near(n+d,routes.y_of(v),routes.step,routes.step) >= 0: out.append([v,cost*Routes.NARROW,"walk",d,{}])
	# The search (`build` false) builds none (a place's moves can take 15 ms):
	# a place not built yet is walked through; the build's slices reach it.
	if not special.has(u):
		if build and probe != null and is_instance_valid(probe): _build(u)
		elif not _queued.has(u):
			_queued[u] = true
			_queue.append(u)
			built = false
	for e: Dictionary in special.get(u,[]):
		var to: Vector3i = e.to
		if routes.floor_near(Vector2i(to.x,to.y),float(e.to_y),0.6,0.6) != to.z: continue
		out.append([to,float(e.cost),str(e.kind),e.d,e])
	if special.has(u): _adj[u] = out
	return out

## Whether his bulk, stood on `u` turned any way (his shoulders' breadth
## square, from over his stair to his head's top), meets nothing: the
## columns' footprint is narrower than his shoulders, and a knoll's or a
## ruin's side at shoulder height pinned him on a walk the columns allowed.
func clear(u: Vector3i) -> bool:
	var had: Variant = _clear.get(u)
	if had != null: return had
	if probe == null or not is_instance_valid(probe): return true
	var b := probe
	var q: PhysicsShapeQueryParameters3D = b._bulk_at(routes.at(u))
	var w: float = float(b.hh)*b.BULK_W*2.0*CLEAR_W
	b._bulk.size = Vector3(w,b._bulk.size.y,w)
	var ok: bool = field.study.get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()
	_clear[u] = ok
	return ok
var _clear := {}
## His bulk's square for `clear` (a share of his shoulders' breadth: his
## push-out eases him the rest).
const CLEAR_W := 0.8

## Each place's moves as `moves` gives them, kept once built: {Vector3i: Array}.
var _adj := {}

## The world changed in `box` (rubble at rest): its columns read again, the
## moves from it and into it let go (built again as the search comes).
func forget(b: AABB) -> void:
	routes.forget(b)
	var grown := b.grow(CELL*3.0)
	var drop := []
	for u: Vector3i in special.keys():
		var p := Vector3((u.x+0.5)*CELL,grown.get_center().y,(u.y+0.5)*CELL)
		if _flat_in(grown,p):
			drop.append(u)
			continue
		for e: Dictionary in special[u]:
			if _flat_in(grown,e.land as Vector3) or _flat_in(grown,e.at as Vector3):
				drop.append(u)
				break
	for u: Vector3i in drop:
		special.erase(u)
		_adj.erase(u)
		# Built again a slice at a time (the study's `step`), or as a
		# search comes to it first.
		_queued[u] = true
		_queue.append(u)
		built = false
	forgets += 1
	for u: Vector3i in _adj.keys():
		if _flat_in(grown,Vector3((u.x+0.5)*CELL,0.0,(u.y+0.5)*CELL)): _adj.erase(u)
	for u: Vector3i in _room.keys():
		if _flat_in(grown,Vector3((u.x+0.5)*CELL,0.0,(u.y+0.5)*CELL)): _room.erase(u)
	for u: Vector3i in _clear.keys():
		if _flat_in(grown,Vector3((u.x+0.5)*CELL,0.0,(u.y+0.5)*CELL)): _clear.erase(u)

## Olmec tune (`plan_smooth`): whether he walks straight from `a` to `b`
## over places he fits (each column the line crosses a place within a
## step of the last, his bulk clear there): the line-of-sight test his
## route's walk legs are shortcut by. Only read columns (no rays past
## those the search already cast, but for new ones).
func walk_line(a: Vector3, b: Vector3) -> bool:
	var flat := Vector2(b.x-a.x,b.z-a.z)
	var n := maxi(1,ceili(flat.length()/(CELL*0.5)))
	var y := a.y
	var last := Routes.cell_of(a)
	var u0 := routes.node_at(a,routes.step*2.0,routes.step*2.0)
	if u0 != NONE: y = routes.y_of(u0)
	for i in range(1,n+1):
		var p := Vector2(a.x,a.z)+flat*(float(i)/n)
		var c := Routes.cell_of(Vector3(p.x,0.0,p.y))
		if c == last: continue
		last = c
		var k := routes.floor_near(c,y,routes.step,routes.step)
		if k < 0: return false
		var v := Vector3i(c.x,c.y,k)
		if not routes.fits(v) or not clear(v): return false
		y = routes.y_of(v)
		# A place's row of neighbours he fits too: the line keeps a column
		# off a rim (his look ahead at speed meets no edge on it).
		for d: Vector2i in WALK_SIDE:
			var kn := routes.floor_near(c+d,y,routes.step,routes.step)
			if kn < 0 or not routes.fits(Vector3i(c.x+d.x,c.y+d.y,kn)): return false
	return true

const WALK_SIDE := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]

static func _flat_in(b: AABB, p: Vector3) -> bool:
	return p.x >= b.position.x and p.x <= b.end.x and p.z >= b.position.z and p.z <= b.end.z

## The place a move lands him at `at` (his floor there): one he can stand
## on within a little of it, NONE none.
func land_node(at: Vector3) -> Vector3i:
	var u := routes.node_at(at,1.5,3.0)
	if u != NONE and standable(u): return u
	return routes.fit_near(at,3.0,2.0)

# --- The special moves of a place ------------------------------------------------------

## Place `u`'s special moves, built with the probe stood on it (each of the
## 8 ways: a wall ahead climbed, a rim ahead leapt off).
func _build(u: Vector3i) -> void:
	var t0 := Time.get_ticks_usec()
	_build_moves(u)
	worst_us = maxi(worst_us,Time.get_ticks_usec()-t0)

## The longest one place's moves took to build (us).
var worst_us := 0
## The build's time in climbs and in leaps (us).
var climb_us := 0
## Drop landings by their spot (half-column, floor): where his bulk has room.
var _landing := {}
var prof := {}
var leap_us := 0

func _build_moves(u: Vector3i) -> void:
	build_jobs += 1
	var out: Array = []
	special[u] = out
	var b := probe
	var p := routes.at(u)
	var c := Vector2i(u.x,u.y)
	var step := routes.step
	var was_p: Vector3 = b.position
	var was_f: float = b.facing
	var climb_top: float = routes.climb_max+float(b.neck_h)*0.55
	for d: Vector2i in DIRS:
		# What lies ahead at his level: a wall (a floor up in his climb), a
		# rim (none, within his footprint and a column), or his level on.
		var ahead := ""
		for j in range(1,CLIMB_COLS+1):
			var n := c+d*j
			if routes.floor_near(n,p.y,step,step) >= 0: continue
			var f := routes.col(n)
			for k in range(0,f.size(),2):
				if f[k] > p.y+step and f[k] <= p.y+climb_top:
					ahead = "wall"
					break
			if ahead == "": ahead = "rim" if j <= 3 else "off"
			break
		if ahead == "": continue
		var way := PilotMotor.facing_of(Vector2(d.x,d.y).normalized())
		b.position = p
		b.facing = way
		# A face leaning back off his floor reads as no floor to the columns
		# (its slope is none): a climb is looked for either way.
		var tc := Time.get_ticks_usec()
		_climbs(u,p,d,way,out)
		climb_us += Time.get_ticks_usec()-tc
		b.position = p
		b.facing = way
		tc = Time.get_ticks_usec()
		# Drops from every other column (a checkerboard): the rim's next
		# place leaps the same, a step's walk away.
		if ahead == "rim": _leaps(u,p,d,way,out,posmod(u.x+u.y,2) == 0)
		leap_us += Time.get_ticks_usec()-tc
	b.position = was_p
	b.facing = was_f

func _edge(kind: String, to: Vector3i, cost: float, d: Vector2i, way: float, at: Vector3, land: Vector3) -> Dictionary:
	kinds[kind] = int(kinds.get(kind,0))+1
	return {"kind":kind,"to":to,"to_y":routes.y_of(to),"cost":cost,"d":d,"way":way,"at":at,"land":land,"up":-1.0}

func _climbs(u: Vector3i, p: Vector3, d: Vector2i, way: float, out: Array) -> void:
	var b := probe
	var cl: Dictionary = b._climb_at(way,CLIMB_LOOK)
	if cl.is_empty():
		var why: String = str(b.climb_why).get_slice(" ",0)+" "+str(b.climb_why).get_slice(" ",1)
		passed[why] = int(passed.get(why,0))+1
		return
	var lip: Vector3 = cl.lip
	var n: Vector3 = cl.n
	var on := lip-n*(float(b.length)*0.5+1.0)
	var v := land_node(Vector3(on.x,lip.y,on.z))
	if v == NONE or v == u: return
	var e := _edge("climb",v,p.distance_to(cl.to as Vector3)+(lip.y-p.y)*2.0+COST_CLIMB,d,way,cl.to,routes.at(v))
	e.face = cl.face
	e.n = n
	e.lip = lip
	e.foot = cl.foot
	out.append(e)

func _leaps(u: Vector3i, p: Vector3, d: Vector2i, way: float, out: Array, drops := true) -> void:
	var b := probe
	var dir: Vector3 = b._way3(way)
	var lands := {}
	var t0 := Time.get_ticks_usec()
	# What the columns out along `d` hold (read already, cheap): a ledge in
	# his jump's rise and sink, a floor under him in his drop, a face across.
	var hh: float = float(b.hh)
	var rise: float = maxf(float(b.knobs.jump_rise),float(b.knobs.hunt_rise))*hh+routes.step
	var sink: float = float(b.knobs.jump_sink)*hh
	var gap: float = b.jump_gap()
	var reach: float = float(b.knobs.down_reach)*hh if float(b.knobs.get("down_to",0)) >= 0.5 else float(b.knobs.leap_max)
	var deep: float = maxf(float(b.knobs.drop_max),float(b.knobs.down_deep)*hh)
	var far: float = float(b.knobs.cliff_gap)*hh
	var under: float = float(b.knobs.cliff_deep)*hh
	var ledge_at := false
	var floor_at := false
	var face_at := false
	var len_d := CELL*(1.0 if d.x == 0 or d.y == 0 else 1.4142)
	var c := Vector2i(u.x,u.y)
	for j in range(1,ceili(maxf(maxf(gap,reach),far)/len_d)+3):
		var f := routes.col(c+d*j)
		var dist := j*len_d
		for k in range(0,f.size(),2):
			var y: float = f[k]
			if dist <= gap+len_d*2.0 and y >= p.y-sink and y <= p.y+rise: ledge_at = true
			if dist <= reach+len_d*2.0 and y < p.y-routes.step and y >= p.y-deep: floor_at = true
			if dist <= far+len_d*2.0 and y >= p.y-under: face_at = true
	# Across to a ledge.
	var lg: Dictionary = b._ledge(dir) if ledge_at else {}
	if not lg.is_empty() and b._arc_clear(lg.at,"jump",false,ARC_COARSE):
		var v := land_node(lg.at)
		if v != NONE and v != u:
			lands[v] = true
			out.append(_edge("jump",v,Vector2(lg.at.x-p.x,lg.at.z-p.z).length()+COST_JUMP,d,way,lg.at,routes.at(v)))
	prof["jump"] = int(prof.get("jump",0))+Time.get_ticks_usec()-t0
	t0 = Time.get_ticks_usec()
	# Down to a floor.
	var step := routes.step
	var dd: float = float(b.length)*0.5+float(b.knobs.look) if floor_at and drops else INF
	var kept: Array = []
	var tries := 0
	while dd <= reach and kept.size() < DROP_KEEP:
		var q := p+dir*dd
		var hit: Dictionary = b._cast(q+Vector3.UP*step,q-Vector3.UP*deep)
		dd += CELL
		if hit.is_empty() or (hit.normal as Vector3).y <= 0.7: continue
		var y := (hit.position as Vector3).y
		if y >= p.y-step: continue
		var onto := q+dir*(float(b.length)*0.5+1.0)
		# The landing there, found once for every rim that drops onto it.
		var lk := Vector3i(floori(onto.x/CELL*2.0),floori(onto.z/CELL*2.0),roundi(y))
		var at: Vector3
		if _landing.has(lk): at = _landing[lk]
		else:
			var g: float = b._floor(Vector3(onto.x,y,onto.z),1.0,1.0)
			at = b._down_room(Vector3(onto.x,g,onto.z)) if g != -INF else Vector3.INF
			_landing[lk] = at
		if at == Vector3.INF: continue
		prof["drop_n"] = int(prof.get("drop_n",0))+1
		if kept.any(func(k: Vector3) -> bool: return k.distance_to(at) < DROP_APART): continue
		var v := land_node(at)
		if v == NONE or v == u or lands.has(v): continue
		tries += 1
		if tries > DROP_KEEP*2: break
		var to_at := Vector2(at.x-p.x,at.z-p.z)
		b.facing = PilotMotor.facing_of(to_at.normalized()) if to_at.length() > 0.1 else way
		for up: float in [float(b.knobs.leap_up),float(b.hh)*0.8,float(b.hh)*1.4,float(b.knobs.down_arc)*float(b.hh)]:
			b._drop_up = up
			var ta := Time.get_ticks_usec()
			var ok: bool = b._arc_clear(at,"drop",true,ARC_COARSE)
			prof["drop_arcs"] = int(prof.get("drop_arcs",0))+Time.get_ticks_usec()-ta
			prof["drop_arc_n"] = int(prof.get("drop_arc_n",0))+1
			b._drop_up = -1.0
			if ok:
				kept.append(at)
				lands[v] = true
				var e := _edge("drop",v,to_at.length()+COST_DROP+(p.y-at.y)*0.15,d,way,at,routes.at(v))
				e.up = up
				out.append(e)
				break
		b.facing = way
	prof["drop"] = int(prof.get("drop",0))+Time.get_ticks_usec()-t0
	t0 = Time.get_ticks_usec()
	# A face across, leapt at and climbed.
	if float(b.knobs.get("cliff_leap",0)) >= 0.5 and face_at:
		var cf: Dictionary = b._cliff_find(way,Vector3.INF,ARC_COARSE)
		if not cf.is_empty():
			var lip: Vector3 = cf.lip
			var n: Vector3 = cf.n
			var on := lip-n*(float(b.length)*0.5+1.0)
			var v := land_node(Vector3(on.x,lip.y,on.z))
			if v != NONE and v != u and not lands.has(v):
				var to: Vector3 = cf.to
				var e := _edge("cliff",v,Vector2(to.x-p.x,to.z-p.z).length()+maxf(lip.y-to.y,0.0)*2.0+COST_CLIFF,d,way,to,routes.at(v))
				e.face = cf.face
				e.lip = lip
				out.append(e)
	prof["cliff"] = int(prof.get("cliff",0))+Time.get_ticks_usec()-t0

## Its size, for the study's line: places, special moves by kind, the
## build's ms, and a rough count of its memory (KB).
func stats() -> Dictionary:
	var moves_n := 0
	for u: Vector3i in special.keys(): moves_n += (special[u] as Array).size()
	return {"places":places,"built":special.size(),"special":moves_n,"kinds":kinds,"climbs_passed":passed,"ms":snappedf(build_us/1000.0,1.0),"worst_place_ms":snappedf(worst_us/1000.0,0.1),"climb_ms":climb_us/1000,"leap_ms":leap_us/1000,"prof":prof,"rays":routes.rays,"cols":routes.cols.size()}

# --- The search ------------------------------------------------------------------------

## An A* from `from` to within `goal_r` m (flat, GOAL_DY up or down) of
## `goal` over the graph's moves, stepped `step(usec)` a slice at a time.
## `banned` ({"u>v": true}) moves he found he couldn't make. Done: `path`
## the legs [{kind, to, from (Vector3), node, from_node, d (Vector2), edge}],
## `found` whether it gets to the goal (else the way to the place nearest
## it he can get to; [] if that is where he stands).
class Search:
	var graph
	var goal: Vector3
	var goal_r: float
	var banned: Dictionary
	var start: Vector3i
	var done := false
	var found := false
	var path: Array = []
	var expanded := 0
	var usec := 0
	var _open: Array = []
	var _g := {}
	var _came := {}
	var _closed := {}
	var _best: Vector3i
	var _best_h := INF

	func _init(g, from: Vector3, to: Vector3, r_goal: float, ban := {}) -> void:
		graph = g
		goal = to
		goal_r = r_goal
		banned = ban
		graph.refresh()
		start = graph.routes.node_at(from,2.0,4.0)
		if start == NONE or not graph.standable(start):
			# Off any place (in rubble, on a sliver): the nearest he fits.
			for r: float in [4.5,9.0]:
				var near: Vector3i = graph.routes.fit_near(from,r,4.0)
				if near != NONE:
					start = near
					break
		if start == NONE:
			done = true
			return
		_g[start] = 0.0
		_best = start
		_best_h = _h(start)
		_push(_best_h,start)

	func _h(u: Vector3i) -> float:
		var p: Vector3 = graph.routes.at(u)
		return maxf(0.0,Vector2(p.x-goal.x,p.z-goal.z).length()-goal_r)+maxf(absf(p.y-goal.y)-GOAL_DY,0.0)*0.5

	func _is_goal(u: Vector3i) -> bool:
		var p: Vector3 = graph.routes.at(u)
		return Vector2(p.x-goal.x,p.z-goal.z).length() <= goal_r and absf(p.y-goal.y) <= GOAL_DY

	func _push(f: float, u: Vector3i) -> void:
		_open.append([f,u])
		var i := _open.size()-1
		while i > 0:
			var p := (i-1)/2
			if float(_open[p][0]) <= f: break
			var t: Array = _open[p]
			_open[p] = _open[i]
			_open[i] = t
			i = p

	func _pop() -> Array:
		var top: Array = _open[0]
		var last: Array = _open.pop_back()
		if not _open.is_empty():
			_open[0] = last
			var i := 0
			var n := _open.size()
			while true:
				var l := i*2+1
				var r := l+1
				var m := i
				if l < n and float(_open[l][0]) < float(_open[m][0]): m = l
				if r < n and float(_open[r][0]) < float(_open[m][0]): m = r
				if m == i: break
				var t: Array = _open[m]
				_open[m] = _open[i]
				_open[i] = t
				i = m
		return top

	## A slice of the search, `us` long at most; true once done.
	func step(us: int) -> bool:
		if done: return true
		var t0 := Time.get_ticks_usec()
		graph.refresh()
		var until := t0+us
		var spots: Array = banned.get("@spots",[])
		while not _open.is_empty():
			if Time.get_ticks_usec() > until:
				usec += Time.get_ticks_usec()-t0
				return false
			var top := _pop()
			var u: Vector3i = top[1]
			if _closed.has(u): continue
			_closed[u] = true
			expanded += 1
			var stand: bool = u == start or graph.standable(u)
			if stand and _is_goal(u):
				_finish(u)
				found = true
				usec += Time.get_ticks_usec()-t0
				return true
			var h := _h(u)
			if stand and (h < _best_h-0.01 or (absf(h-_best_h) <= 0.01 and float(_g[u]) < float(_g.get(_best,INF)))):
				_best_h = h
				_best = u
			if expanded >= MOST: break
			for m: Array in graph.moves(u,false):
				var v: Vector3i = m[0]
				if _closed.has(v): continue
				if banned.has(key(u,v)): continue
				# A special move from or at a spot he failed one at (a face
				# he let go of, from any place along its foot).
				if not (m[4] as Dictionary).is_empty() and not spots.is_empty() and _near(m[4].at as Vector3,spots): continue
				var g: float = float(_g[u])+float(m[1])
				if g < float(_g.get(v,INF)):
					_g[v] = g
					_came[v] = [u,m[2],m[3],m[4]]
					_push(g+_h(v),v)
		_finish(_best)
		usec += Time.get_ticks_usec()-t0
		return true

	static func _near(p: Vector3, spots: Array) -> bool:
		for q: Vector3 in spots:
			if p.distance_to(q) < BAN_NEAR: return true
		return false

	static func key(u: Vector3i, v: Vector3i) -> String:
		return "%s>%s" % [u,v]

	## The route's cost (its end's) and what's left from its end to the
	## goal (the search's estimate): for the hysteresis (`plan_keep`).
	var cost := 0.0
	var left := 0.0

	func _finish(u: Vector3i) -> void:
		done = true
		cost = float(_g.get(u,0.0))
		left = _h(u)
		var legs: Array = []
		while _came.has(u):
			var c: Array = _came[u]
			var from: Vector3i = c[0]
			legs.push_front({"kind":c[1],"to":graph.routes.at(u),"from":graph.routes.at(from),"node":u,"from_node":from,
				"d":Vector2(c[2].x,c[2].y).normalized(),"edge":c[3]})
			u = from
		path = legs
