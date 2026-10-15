extends RefCounted
## The headless body's routes (docs/design/roguelike/layer-round11-body-
## routes.md): where the body (scripts/enemies/headless_body.gd) fits, and
## the way from where it stands to its head over places it fits.
##
## The world is read with rays, a CELL m column at a time, as the search
## comes to it (`col`): each column's floors top-down, each with the room
## over it (a ray up to its neck). Read columns are shared by every body in
## the field (`_worlds`, per field); a column with no floor is read again
## after EMPTY_AGAIN ms (the far isles stand a slice a frame).
##
## A place (a node: Vector3i(column x, column z, floor index)) is one
## column's floor. The body FITS a place when the floor has room over it
## for its neck, and every column round it (the 3 x 3, its footprint) has a
## floor within `step` of it with room too: a sliver, a stair's narrow
## landing between flights, a corner by a wall or a rim it doesn't.
##
## Its moves, place to place along 8 ways (`moves`):
##   walk    to the next column's floor within `step`, a place it fits;
##   climb   up a wall (`climb_max` at most) and in over the lip to the
##           first place it fits; a lip it doesn't fit on (a stair's tread,
##           a sliver) with another wall over it is climbed on from
##           (CLIMB_LINKS walls at most): it keeps climbing till there's
##           room;
##   jump    off a rim, across open sky (`jump_gap` at most) to a ledge
##           `jump_rise` over or `jump_sink` under;
##   drop    off a rim, down (`drop_max` at most) and across (`leap_max`,
##           more the deeper: `across`) to a lower place it fits, on its
##           own isle or another.
## A move lands on a place it fits, or a lip it climbs on from.
##
## `Search` is an A* over those moves (stepped a slice of a frame at a time)
## from where it stands to its goal; where the goal can't be got to, the
## way to the place nearest it that can (the good spot nearest its head).

const CELL := 1.5
## Rays down from here, a column's floors read to the field's `lost`.
const TOP := 2000.0
## Floors read in a column at most.
const HITS := 8
## A floor with less room than this over it (m) is not read.
const SLOT := 0.5
## A column read with no floor is read again after this (ms).
const EMPTY_AGAIN := 8000
## A wall climbed on from a lip it doesn't fit on, at most this many.
const CLIMB_LINKS := 4
## The search's box: start and goal grown this much (m, flat).
const MARGIN := 45.0
## Places expanded at most in one search.
const MOST := 9000
## Costs (m of walking) of each move over its length.
const COST_CLIMB := 6.0
const COST_JUMP := 9.0
const COST_DROP := 7.0
## Columns walked on at its level to a wall or a rim, at most.
const APPROACH := 3
## A narrow way's cost over its length.
const NARROW := 1.8
## A goal is reached within this (m flat, and GOAL_DY up or down).
const GOAL_DY := 3.0
const DIRS := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]
const NONE := Vector3i(-999999,-999999,-1)

## The columns read, per field: {field id: {Vector2i: [ms read, PackedFloat32Array [y, room, ...] top-down]}}.
static var _worlds := {}

var field: Node
var cols: Dictionary
var bottom := -1000.0
var step := 1.2
var room := 6.0
var climb_max := 22.0
var drop_max := 22.0
var leap_max := 12.0
var leap_far := 22.0
var leap_fall := 0.6
var jump_gap := 10.0
var jump_rise := 1.7
var jump_sink := 5.0
var _fits := {}
var _between := {}
## Columns it met a wall in where it walked (a gate's posts, an arch's
## springing: thinner than a column, missed by the reads): {Vector2i: true}.
var _blocked := {}
var _ray := PhysicsRayQueryParameters3D.new()
var _hers_box := BoxShape3D.new()
var _hers_q := PhysicsShapeQueryParameters3D.new()
## His breadth (m), for his climbing bulk.
var breadth := 4.0
## Climbs up through walker-only stone left out (set for a search after
## her: scripts/enemies/headless_body.gd `_after_try`).
var shun_hers := false
var _skip: Callable
## Rays cast (for checks).
var rays := 0

## For `body` (HeadlessBody, set up): its sizes and moves from its knobs.
func _init(body: Node3D) -> void:
	field = body.field
	var id := field.get_instance_id()
	if not _worlds.has(id):
		# One field's columns at a time: an old field's freed with it.
		for k: int in _worlds.keys():
			if not is_instance_id_valid(k): _worlds.erase(k)
		_worlds[id] = {}
	cols = _worlds[id]
	bottom = float(field.lost)
	var k: Dictionary = body.knobs
	step = float(k.step)
	# Olmec round 1 (olmec-turn-clip-round1.md): room to its stump's top
	# (0.92 of it put its shoulder slab into overhangs).
	room = float(body.neck_h)*1.0
	breadth = float(body.width)
	climb_max = float(k.climb_max)
	drop_max = float(k.drop_max)
	leap_max = float(k.leap_max)
	leap_far = float(k.leap_far)
	leap_fall = float(k.leap_fall)
	jump_gap = body.jump_gap()
	jump_rise = float(k.jump_rise)*float(body.hh)
	jump_sink = float(k.jump_sink)*float(body.hh)
	_ray.collision_mask = WalkerOnly.strip(field.study.ground.mask)
	_skip = body._skip

## The bodies left out of the rays as they are now (call before a batch
## of reads).
func refresh() -> void:
	_ray.exclude = _skip.call()

## A wall met at `p` where it walked: its column and those round it no way
## through.
func block(p: Vector3) -> void:
	var c := cell_of(p)
	for dx in range(-1,2):
		for dz in range(-1,2): _blocked[c+Vector2i(dx,dz)] = true

## The world changed in `box` (rubble come to rest: docs/design/roguelike/
## olmec-destruction-round1.md): its columns, and those a footprint off it,
## read afresh; what was known of fitting and walking there let go.
func forget(box: AABB) -> void:
	var lo := cell_of(box.position)-Vector2i(2,2)
	var hi := cell_of(box.end)+Vector2i(2,2)
	var inside := func(x: int, z: int) -> bool: return x >= lo.x and x <= hi.x and z >= lo.y and z <= hi.y
	for x in range(lo.x,hi.x+1):
		for z in range(lo.y,hi.y+1):
			cols.erase(Vector2i(x,z))
			_blocked.erase(Vector2i(x,z))
	for u: Vector3i in _fits.keys():
		if inside.call(u.x,u.y): _fits.erase(u)
	for k: Vector3i in _between.keys():
		if inside.call(floori(k.x*0.25/CELL),floori(k.y*0.25/CELL)): _between.erase(k)

## Widest a drop `down` m deep goes across (m).
func across(down: float) -> float:
	return minf(leap_far,leap_max+maxf(down,0.0)*leap_fall)

# --- The world, read ----------------------------------------------------------------

func _cast(from: Vector3, to: Vector3) -> Dictionary:
	rays += 1
	_ray.from = from
	_ray.to = to
	return field.study.get_world_3d().direct_space_state.intersect_ray(_ray)

static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x/CELL),floori(p.z/CELL))

static func centre(c: Vector2i) -> Vector2:
	return Vector2((c.x+0.5)*CELL,(c.y+0.5)*CELL)

## Column `c`'s floors top-down: [y, room over it, ...].
func col(c: Vector2i) -> PackedFloat32Array:
	var had: Variant = cols.get(c)
	if had != null:
		var f: PackedFloat32Array = had[1]
		if not f.is_empty() or Time.get_ticks_msec()-int(had[0]) < EMPTY_AGAIN: return f
	var out := PackedFloat32Array()
	var xz := centre(c)
	var y := TOP
	for i in HITS:
		var hit := _cast(Vector3(xz.x,y,xz.y),Vector3(xz.x,bottom,xz.y))
		if hit.is_empty(): break
		var p: Vector3 = hit.position
		if (hit.normal as Vector3).y >= 0.55:
			var up := _cast(p+Vector3.UP*0.1,p+Vector3.UP*(room+0.5))
			var over := ((up.position as Vector3).y-p.y) if not up.is_empty() else room+0.5
			# City breaks round 1: a floor with a solid just over it (a
			# felled drum's or a heap's foot) is no floor, not the nearest
			# one a place's neighbours take.
			if over >= SLOT:
				out.append(p.y)
				out.append(over)
		y = p.y-0.05
	cols[c] = [Time.get_ticks_msec(),out]
	return out

## The floor of column `c` within `down` under and `up` over `y` nearest
## it: its index, or -1.
func floor_near(c: Vector2i, y: float, up: float, down: float) -> int:
	var f := col(c)
	var best := -1
	var near := INF
	for i in range(0,f.size(),2):
		var d := f[i]-y
		if d > up or d < -down: continue
		if absf(d) < near:
			near = absf(d)
			best = i/2
	return best

func y_of(u: Vector3i) -> float:
	return col(Vector2i(u.x,u.y))[u.z*2]

func room_of(u: Vector3i) -> float:
	return col(Vector2i(u.x,u.y))[u.z*2+1]

func at(u: Vector3i) -> Vector3:
	var xz := centre(Vector2i(u.x,u.y))
	return Vector3(xz.x,y_of(u),xz.y)

## The place under `p` (its floor within `up` over and `down` under), NONE
## if none.
func node_at(p: Vector3, up := 1.5, down := 3.0) -> Vector3i:
	var c := cell_of(p)
	var i := floor_near(c,p.y,up,down)
	return Vector3i(c.x,c.y,i) if i >= 0 else NONE

## Whether the body fits place `u`: room over it for its neck, every
## column round it a floor within `step` with room, and floor between it
## and the four beside it (not stepping stones with gaps between).
func fits(u: Vector3i) -> bool:
	if _blocked.has(Vector2i(u.x,u.y)): return false
	var had: Variant = _fits.get(u)
	if had != null: return had
	var ok := room_of(u) >= room
	if ok:
		var y := y_of(u)
		var c := Vector2i(u.x,u.y)
		for d: Vector2i in DIRS:
			var i := floor_near(c+d,y,step,step)
			if i < 0 or col(c+d)[i*2+1] < room*0.8:
				ok = false
				break
		if ok:
			var at_c := centre(c)
			for k in 4:
				var d: Vector2i = DIRS[k]
				if not between(at_c+Vector2(d.x,d.y)*CELL*0.5,y):
					ok = false
					break
	_fits[u] = ok
	return ok

## Whether there's floor at `xz` within `step` of `y` (half a column off a
## column's middle: the floor between two places).
func between(xz: Vector2, y: float) -> bool:
	var key := Vector3i(roundi(xz.x*4.0),roundi(xz.y*4.0),roundi(y))
	var had: Variant = _between.get(key)
	if had != null: return had
	var ok := _between_at(xz,y)
	# Body climb-after round 1: a ray straight down a riser's face (a stair
	# whose risers stand on a column's edge: the city landmarks' epic
	# stair) meets neither tread; a hair either side, it does.
	if not ok: ok = _between_at(xz+Vector2(0.06,0.06),y) or _between_at(xz-Vector2(0.06,0.06),y)
	_between[key] = ok
	return ok

func _between_at(xz: Vector2, y: float) -> bool:
	var from := Vector3(xz.x,y+step*1.6,xz.y)
	for i in 3:
		var hit := _cast(from,Vector3(xz.x,y-step,xz.y))
		if hit.is_empty(): return false
		if (hit.normal as Vector3).y >= 0.55: return absf((hit.position as Vector3).y-y) <= step
		from = (hit.position as Vector3)-Vector3.UP*0.05
	return false

## The nearest place it fits to `p` within `r` m (flat) and `dy` up or
## down: NONE if none.
func fit_near(p: Vector3, r: float, dy := 2.0) -> Vector3i:
	var c := cell_of(p)
	var n := ceili(r/CELL)
	var best := NONE
	var near := INF
	for dx in range(-n,n+1):
		for dz in range(-n,n+1):
			var cc := c+Vector2i(dx,dz)
			var d := centre(cc).distance_to(Vector2(p.x,p.z))
			if d > r or d >= near: continue
			var i := floor_near(cc,p.y,dy,dy)
			if i < 0: continue
			var u := Vector3i(cc.x,cc.y,i)
			if fits(u):
				best = u
				near = d
	return best

# --- Moves ---------------------------------------------------------------------------

## The first place along `d` from column `c` at about `y` (within `step`;
## `k` columns on at most) it fits; NONE if none.
func _fit_along(c: Vector2i, d: Vector2i, y: float, most: int) -> Vector3i:
	for j in range(0,most+1):
		var n := c+d*j
		var i := floor_near(n,y,step,step)
		if i < 0: return NONE
		var u := Vector3i(n.x,n.y,i)
		if fits(u): return u
	return NONE

## Every move from place `u`: [[to, cost, kind ("walk", "climb", "jump",
## "drop"), d (the way)], ...].
func moves(u: Vector3i) -> Array:
	var out: Array = []
	var y := y_of(u)
	var c := Vector2i(u.x,u.y)
	for d: Vector2i in DIRS:
		var len_d := CELL*(1.0 if d.x == 0 or d.y == 0 else 1.4142)
		var n := c+d
		var i := floor_near(n,y,step,step)
		if i >= 0 and not _blocked.has(n):
			var v := Vector3i(n.x,n.y,i)
			var cost := len_d+absf(y_of(v)-y)*0.5
			var mid := (centre(c)+centre(n))*0.5
			if between(mid,(y+y_of(v))*0.5):
				if fits(v): out.append([v,cost,"walk",d])
				# A narrow way (a stair, a bridge, a ledge) on along `d`,
				# room over it: walked, slower, too narrow to stop on.
				elif room_of(v) >= room and floor_near(n+d,y_of(v),step,step) >= 0: out.append([v,cost*NARROW,"walk",d])
		# On along `d` at its level (APPROACH columns at most: the strip by
		# a rim or a wall it doesn't fit on) to the first column off it: a
		# wall to climb, or a rim to leap off.
		var j := 1
		var level := y
		while j <= APPROACH:
			var k := floor_near(c+d*j,level,step,step)
			if k < 0: break
			level = col(c+d*j)[k*2]
			j += 1
		if j > APPROACH: continue
		var base := c+d*(j-1)
		var lead := (j-1)*len_d
		var f := col(c+d*j)
		# A wall: the lowest floor over its step in reach of a climb.
		var wall := INF
		var blocked := false
		for k in range(0,f.size(),2):
			if f[k] > level+step and f[k] <= level+climb_max and f[k] < wall: wall = f[k]
			# Something in the way up to its neck: no leap that way.
			if f[k] > level+step and f[k] < level+room: blocked = true
		if wall != INF and _face(base,d,level,wall) and not (shun_hers and _hers_on(base,d,level,wall)):
			var up := _climb_to(base,d,level,wall)
			if up[0] != NONE: out.append([up[0],lead+len_d*float(up[1])+(at(up[0]).y-level)*2.0+COST_CLIMB,"climb",d])
		if blocked: continue
		for leap: Array in _leap_to(base,d,level):
			leap[1] = float(leap[1])+lead
			out.append(leap)
	return out

## A climb from column `c` (floor `level`) to `top` isn't under something:
## the room over his floor there reaches the top. Climbing up out from under
## a deck or a pier's corbels stepping out over him (the city kit's
## causeway over the road a bay falls to, city-kit-round1.md) is an
## overhang he can't climb.
func _face(c: Vector2i, _d: Vector2i, level: float, top: float) -> bool:
	var at := centre(c)
	return _cast(Vector3(at.x,level+0.1,at.y),Vector3(at.x,top-0.3,at.y)).is_empty()

## Body climb-after round 1: walker-only stone (her shelves, ledges, a
## chimney's leaves) on the face over column `c` along `d`, from `level` to
## `top`, within his shoulders: he'd climb through it (it's air to him).
## Climbing after her, he climbs the face beside it (`shun_hers`).
func _hers_on(c: Vector2i, d: Vector2i, level: float, top: float) -> bool:
	if top-level-step < 0.5: return false
	var at := centre(c)
	var dn := Vector2(d.x,d.y).normalized()
	# His climbing bulk: his breadth across, from his column's middle to a
	# little into the face's, his knees to the lip.
	_hers_box.size = Vector3(breadth,top-level-step,CELL*1.6)
	_hers_q.shape = _hers_box
	_hers_q.collision_mask = WalkerOnly.LAYER
	var mid := at+dn*CELL*0.6
	_hers_q.transform = Transform3D(Basis(Vector3.UP,atan2(dn.x,dn.y)),Vector3(mid.x,(level+step+top)*0.5,mid.y))
	rays += 1
	return not field.study.get_world_3d().direct_space_state.intersect_shape(_hers_q,1).is_empty()

## A climb from column `c` (floor `y`) up the wall along `d` whose top is
## `top`: [the place it ends on, columns on], over lips it doesn't fit on
## and on up the walls over them; [NONE, 0] if it tops out with no room.
func _climb_to(c: Vector2i, d: Vector2i, y: float, top: float) -> Array:
	var n := c+d
	var level := top
	for link in CLIMB_LINKS:
		# In over the lip: the first place it fits at this level.
		for j in range(0,3):
			var m := n+d*j
			var i := floor_near(m,level,step,step)
			if i < 0:
				# A higher wall in over the lip: climbed on from here.
				var f := col(m)
				var next := INF
				for k in range(0,f.size(),2):
					if f[k] > level+step and f[k] <= y+climb_max and f[k] < next: next = f[k]
				if next == INF: return [NONE,0]
				n = m
				level = next
				break
			var u := Vector3i(m.x,m.y,i)
			if col(m)[i*2+1] < room: return [NONE,0]
			if fits(u): return [u,(m-c).length()]
			if j == 2: return [NONE,0]
	return [NONE,0]

## Off the rim along `d` from column `c` (floor `y`): across open sky to a
## ledge to jump to or a floor to drop to, and in to the first place it fits
## there: [[to, cost, kind, d], ...] (a near drop and a far jump both, where
## there are). A floor out there with nowhere it fits, lower than its feet,
## it leaps over; one at about its level or over, it doesn't.
func _leap_to(c: Vector2i, d: Vector2i, y: float) -> Array:
	var out: Array = []
	var len_d := CELL*(1.0 if d.x == 0 or d.y == 0 else 1.4142)
	var most := ceili(maxf(leap_far,jump_gap+len_d)/len_d)+1
	var kinds := {}
	for j in range(1,most+1):
		var n := c+d*j
		var f := col(n)
		# The top floor out here under its neck (a floor deeper than it
		# drops is open sky to it).
		var top := -INF
		for k in range(0,f.size(),2):
			if f[k] < y+room and f[k] >= y-drop_max and f[k] > top: top = f[k]
		if top == -INF: continue
		if top > y+jump_rise: break
		var dist := j*len_d
		var gap := (j-1)*len_d
		var dh := top-y
		var kind := ""
		# Level or a little up: only a jump gets there; down, a jump over a
		# narrow gap, else a drop.
		if dh >= -step:
			if gap <= jump_gap: kind = "jump"
		elif dh >= -jump_sink and gap <= jump_gap and gap > 0.0: kind = "jump"
		elif dist <= across(-dh): kind = "drop"
		if kind != "" and not kinds.has(kind):
			var v := _fit_along(n,d,top,3)
			if v != NONE:
				kinds[kind] = true
				out.append([v,dist+(COST_JUMP if kind == "jump" else COST_DROP+(y-top)*0.15),kind,d])
		# About its level: in the way of any leap further.
		if dh >= -step or out.size() >= 2: break
	return out

# --- The search ------------------------------------------------------------------------

## An A* from `from` to within `goal_r` m of `goal` over the body's moves,
## stepped `step(usec)` a slice at a time. `banned` ({"u>v": true}) moves
## it found it couldn't make. Done: `path` the legs [{kind, to (Vector3),
## from (Vector3), node, d (Vector2)}], `found` whether it gets to the goal
## (else the way to the place nearest it it can get to; [] if that is where
## it stands).
class Search:
	var routes
	var goal: Vector3
	var goal_r: float
	var banned: Dictionary
	var start: Vector3i
	var box: Rect2
	var done := false
	var found := false
	var path: Array = []
	var expanded := 0
	var _open: Array = []
	var _g := {}
	var _came := {}
	var _closed := {}
	var _best: Vector3i
	var _best_h := INF

	func _init(r, from: Vector3, to: Vector3, r_goal: float, ban := {}) -> void:
		routes = r
		goal = to
		goal_r = r_goal
		banned = ban
		routes.refresh()
		start = routes.node_at(from,2.0,4.0)
		box = Rect2(Vector2(from.x,from.z),Vector2.ZERO).expand(Vector2(to.x,to.z)).grow(MARGIN)
		if start == NONE:
			done = true
			return
		_g[start] = 0.0
		_best = start
		_push(0.0,start)

	func _h(u: Vector3i) -> float:
		var p: Vector3 = routes.at(u)
		return maxf(0.0,Vector2(p.x-goal.x,p.z-goal.z).length()-goal_r)+absf(p.y-goal.y)*0.5

	func _is_goal(u: Vector3i) -> bool:
		var p: Vector3 = routes.at(u)
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

	## A slice of the search, `usec` long at most; true once done.
	func step(usec: int) -> bool:
		if done: return true
		routes.refresh()
		var until := Time.get_ticks_usec()+usec
		while not _open.is_empty():
			if Time.get_ticks_usec() > until: return false
			var top := _pop()
			var u: Vector3i = top[1]
			if _closed.has(u): continue
			_closed[u] = true
			expanded += 1
			if _is_goal(u) and (u == start or routes.fits(u)):
				_finish(u)
				found = true
				return true
			var h := _h(u)
			if h < _best_h and (u == start or routes.fits(u)):
				_best_h = h
				_best = u
			if expanded >= MOST: break
			for m: Array in routes.moves(u):
				var v: Vector3i = m[0]
				if _closed.has(v): continue
				var p: Vector3 = routes.at(v)
				if not box.has_point(Vector2(p.x,p.z)): continue
				if banned.has(_key(u,v)): continue
				var g: float = float(_g[u])+float(m[1])
				if g < float(_g.get(v,INF)):
					_g[v] = g
					_came[v] = [u,m[2],m[3]]
					_push(g+_h(v),v)
		_finish(_best)
		return true

	static func _key(u: Vector3i, v: Vector3i) -> String:
		return "%s>%s" % [u,v]

	func _finish(u: Vector3i) -> void:
		done = true
		var legs: Array = []
		while _came.has(u):
			var c: Array = _came[u]
			var from: Vector3i = c[0]
			legs.push_front({"kind":c[1],"to":routes.at(u),"from":routes.at(from),"node":u,"from_node":from,
				"d":Vector2(c[2].x,c[2].y).normalized()})
			u = from
		path = legs
