extends RefCounted
## The linger serpent's body settled on the world (docs/design/roguelike/
## linger-serpent-round3.md): its rings follow the head's way
## (scripts/roguelike/linger_serpent.gd), and that way can pass through
## stone (a pillar beside it, a wall's lip, an isle's side, a pier under a
## crossing) and back across its own coils. Each frame, after the rings are
## laid on the way, this moves them off it as little as it can:
##
## 1. **Stone.** Each ring is a ball of its half height (its belly's
##    reach) tested against the drawn world (scripts/roguelike/
##    linger_shell.gd: what you see clip is the drawn stone, not the
##    collision): the contacts' push takes it out. A ring whose middle is
##    under the walkable ground is lifted onto it; one wholly inside drawn
##    stone (the first face over it, or most faces round it, seen from
##    behind: under a terrace, in a pillar, in an isle's rock) goes out the
##    nearest way first. Half the rings are tested a frame (odd, even), so a
##    ring's push is at most a frame old.
## 2. **Itself.** A ring overlapping one further back along it than SELF_ARC
##    (not its neighbours) goes over it: the newer one (nearer the head) is
##    lifted, as a snake crossing its own coil lies over it. Far below the
##    older one, the two are pushed apart sideways instead.
## 3. **The drape.** Lifts spread along the body (at most SLOPE m up a
##    metre along it), so a ring lifted over a lip or a coil takes its
##    neighbours with it in an arch; sideways pushes are smoothed the same
##    way. Each ring keeps at least its own need.
## 4. **Time.** Each ring's offset eases to its goal (quickly out of
##    stone, slowly back down) at a capped speed, so a correction never
##    snaps or shivers.
##
## Its jaw: `jaw_room` is how far the jaw may open before its tip meets the
## ground under the snout (the open jaw scrapes, never cuts in).

## A ring's ball: this share of its radius (its belly's depth under its
## middle; the round sides a little in), and the stone it may sink into
## (m, its weight on soft ground).
const Nav = preload("res://scripts/roguelike/linger_nav.gd")
const Shell = preload("res://scripts/roguelike/linger_shell.gd")
const BALL := 0.86
const SINK := 0.12
## Rings at least this far apart along it (world m) can lie on each other.
const SELF_ARC := 22.0
## Two rings' reach across (shares of their radii summed: its flanks, the
## belly's flare) and stacked (its crest over the other's belly); past
## LIFT_MOST times their stacked reach under, they part sideways.
const REACH_ACROSS := 1.0
const REACH_UP := 0.9
const LIFT_MOST := 1.3
## The drape: the most a lift falls per metre along the body; the passes of
## smoothing.
const SLOPE := 0.42
const SMOOTH := 2
## Ease (1/s) out of stone, back down, and the most a ring's offset moves
## a second (m/s) either way: a correction never snaps.
const RISE := 18.0
const FALL := 3.0
const RISE_SPEED := 22.0
const FALL_SPEED := 5.0
## Contacts read per ball; the most a frame's stone tests may take (µs).
const CONTACTS := 8
const BUDGET_US := 1200

## The drawn world it settles on (scripts/roguelike/linger_shell.gd) and
## that space's state this frame; the isles' ground (their walkable
## heights, scripts/roguelike/linger_nav.gd).
var shell: Shell
var space: PhysicsDirectSpaceState3D
var nav: Nav
## Offsets now and their goals (world), and each ring's own need (world).
var offset := PackedVector3Array()
var need := PackedVector3Array()
var goal := PackedVector3Array()
var head_offset := Vector3.ZERO
var head_need := Vector3.ZERO
## How far the jaw may open (rad), its tip on the ground.
var jaw_room := 10.0
## Counts, for drivers: balls tested, rings found inside stone, this
## frame's cost and the worst (µs).
var tests := 0
var escapes := 0
var last_usec := 0
var worst_usec := 0
var on := true

var _q := PhysicsShapeQueryParameters3D.new()
var _ball := SphereShape3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _parity := 0
var _lift := PackedFloat32Array()
var _side := PackedVector3Array()
var _tmp := PackedVector3Array()
var _plain: Array[bool] = []

func _init(drawn: Shell, ground_nav: Nav, count: int) -> void:
	shell = drawn
	nav = ground_nav
	_q.shape = _ball
	_q.collision_mask = 0xFFFFFFFF
	_ray.collision_mask = 0xFFFFFFFF
	offset.resize(count)
	need.resize(count)
	goal.resize(count)
	_side.resize(count)
	_tmp.resize(count)
	_lift.resize(count)
	_plain.resize(count)
	_plain.fill(false)
	offset.fill(Vector3.ZERO)
	need.fill(Vector3.ZERO)

## The rings `p` (world, head first: ring 0 behind the head), their radii
## and arcs along the body (world m), balls along the head `heads` (back
## to snout) of radius `hr`;
## `delta` 0 snaps. Returns the offsets (world) to add; `head_offset` too.
func settle(p: PackedVector3Array, radius: PackedFloat32Array, arc: PackedFloat32Array, heads: PackedVector3Array, hr: float, delta: float) -> PackedVector3Array:
	var began := Time.get_ticks_usec()
	var n := p.size()
	space = shell.state() if shell != null and shell.space.is_valid() else null
	if not on or space == null:
		offset.fill(Vector3.ZERO)
		head_offset = Vector3.ZERO
		return offset
	# 1. Stone: half the rings tested this frame (all of them on a snap),
	# within BUDGET_US (a ring past it keeps last frame's need).
	_parity = 1-_parity
	for k in range(n):
		if delta > 0.0 and k%2 != _parity: continue
		if delta > 0.0 and Time.get_ticks_usec()-began > BUDGET_US: break
		need[k] = _out_of_stone(p[k],radius[k]*BALL-SINK)
	head_need = Vector3.ZERO
	for h in heads: head_need = _join(head_need,_out_of_stone(h,hr))
	# 2. Itself: rings and the head over older coils.
	for k in range(n): _tmp[k] = p[k]+need[k]
	for h in heads:
		var hp := h+head_need
		var add := Vector3.ZERO
		for j in range(n):
			if arc[j] < SELF_ARC: continue
			add += _over(hp+add,hr,_tmp[j],radius[j],true)
		head_need = _join(head_need,head_need+add)
	for i in range(n):
		var add := Vector3.ZERO
		for j in range(i+1,n):
			if arc[j]-arc[i] < SELF_ARC: continue
			add += _over(_tmp[i]+add,radius[i],_tmp[j],radius[j],true)
		need[i] += add
	# 3. The drape: lifts spread along the body as an arch, sideways pushes
	# smoothed; every ring keeps its own need.
	for k in range(n):
		_lift[k] = maxf(need[k].y,0.0)
		_side[k] = Vector3(need[k].x,minf(need[k].y,0.0),need[k].z)
	var run := head_need.y
	for k in range(n):
		run = maxf(run-SLOPE*(arc[k]-(arc[k-1] if k > 0 else 0.0)),_lift[k])
		_lift[k] = run
	run = 0.0
	for k in range(n-1,-1,-1):
		run = maxf(run-SLOPE*((arc[k+1] if k < n-1 else arc[k])-arc[k]),_lift[k])
		_lift[k] = run
	for _pass in range(SMOOTH):
		for k in range(n):
			var a := _side[maxi(k-1,0)]
			var b := _side[mini(k+1,n-1)]
			_tmp[k] = (a+_side[k]*2.0+b)*0.25
		for k in range(n): _side[k] = _tmp[k]
	for k in range(n):
		var s := _side[k]
		var own := Vector3(need[k].x,minf(need[k].y,0.0),need[k].z)
		var l := own.length()
		if l > 1e-4:
			var dir := own/l
			var got := s.dot(dir)
			if got < l: s += dir*(l-got)
		goal[k] = s+Vector3.UP*_lift[k]
		# Spread from its neighbours into stone of its own (a pillar between
		# them): its own need only. Checked on the frames it is tested.
		if (delta <= 0.0 or k%2 == _parity) and (goal[k]-need[k]).length() > SPREAD_CHECK:
			_plain[k] = _stone_at(p[k]+goal[k],radius[k]*BALL-SINK)
		elif (goal[k]-need[k]).length() <= SPREAD_CHECK:
			_plain[k] = false
		if _plain[k]: goal[k] = need[k]
	# 4. Time: eased at a capped speed.
	for k in range(n):
		offset[k] = _ease(offset[k],goal[k],delta)
	head_offset = _ease(head_offset,head_need+Vector3.UP*maxf(_lift[0]-head_need.y,0.0)*0.6,delta)
	last_usec = Time.get_ticks_usec()-began
	worst_usec = maxi(worst_usec,last_usec)
	return offset

## The least push doing both `a` and `b`'s work (each's own depth along
## its own way).
static func _join(a: Vector3, b: Vector3) -> Vector3:
	var out := a
	var l := b.length()
	if l < 1e-4: return out
	var dir := b/l
	var got := out.dot(dir)
	if got < l: out += dir*(l-got)
	return out

static func _ease(now: Vector3, want: Vector3, delta: float) -> Vector3:
	if delta <= 0.0: return want
	var rising := want.length_squared() > now.length_squared()+1e-4
	var out := now.lerp(want,1.0-exp(-(RISE if rising else FALL)*delta))
	var step := out-now
	var most := (RISE_SPEED if rising else FALL_SPEED)*delta
	if step.length() > most: out = now+step.normalized()*most
	return out

## The push taking a ball of radius `r` at `c` out of the drawn stone (the
## head's way asks it too: scripts/roguelike/linger.gd `_path_clear`).
func out_of_stone(c: Vector3, r: float) -> Vector3:
	if space == null or not on: return Vector3.ZERO
	return _out_of_stone(c,r)

func _out_of_stone(c: Vector3, r: float) -> Vector3:
	# Wholly or half inside drawn stone (its middle under a ground's top, in
	# a terrace it runs under, in an isle's rock): out the nearest way first,
	# so the contacts after push it out of the faces in front of it, never
	# through one from behind.
	var push := Vector3.ZERO
	# Its middle at or under the isle's walkable ground (a step it rode
	# into, the lip it pours over): onto the ground.
	var g := nav.height(c) if nav != null else NAN
	if not is_nan(g) and c.y < g+r*0.2 and c.y > g-r*DEEP_K:
		push.y = g+r-c.y
	else:
		push = _escape(c,r)
	_ball.radius = maxf(r,0.3)
	for _it in range(2):
		_q.transform = Transform3D(Basis.IDENTITY,c+push)
		tests += 1
		var pts := space.collide_shape(_q,CONTACTS)
		if pts.is_empty(): break
		var add := Vector3.ZERO
		var sum := Vector3.ZERO
		var most := 0.0
		for i in range(0,pts.size()-1,2):
			var v: Vector3 = pts[i+1]-pts[i]
			var d := v.length()
			if d < 1e-4: continue
			sum += v
			most = maxf(most,d)
			var dir := v/d
			var got := add.dot(dir)
			if got < d: add += dir*(d-got)
		# Contacts pulling every way (its middle inside a column, a pier):
		# out to the nearest side, across.
		if most > r*0.5 and sum.length() < most*0.6:
			var out := _escape_across(c+push,r)
			if out != Vector3.ZERO:
				push += out
				continue
		push += add
		if add.length() < 0.05: break
	return push

## Its middle inside a column or a wall (most ways across meet a face
## from behind): the nearest way out across, clearing it by `r`; zero if
## not inside.
func _escape_across(c: Vector3, r: float) -> Vector3:
	var best := Vector3.ZERO
	var hits := 0
	for i in range(ESCAPE_WAYS):
		var a := TAU*float(i)/ESCAPE_WAYS
		var dir := Vector3(cos(a),0.0,sin(a))
		var d := _behind(c,dir,r*ESCAPE_K*1.5)
		if d < 0.0: continue
		hits += 1
		if best == Vector3.ZERO or d+r < best.length(): best = dir*(d+r)
	if hits < ESCAPE_INSIDE: return Vector3.ZERO
	escapes += 1
	return best

## Whether a ball of radius `r` at `c` is in drawn stone (deeper than
## SPREAD_DEPTH, or inside it).
const SPREAD_CHECK := 0.6
const SPREAD_DEPTH := 0.4
func _stone_at(c: Vector3, r: float) -> bool:
	_ball.radius = maxf(r,0.3)
	_q.transform = Transform3D(Basis.IDENTITY,c)
	tests += 1
	var pts := space.collide_shape(_q,CONTACTS)
	for i in range(0,pts.size()-1,2):
		if pts[i].distance_to(pts[i+1]) > SPREAD_DEPTH: return true
	return inside(c,r)

## Inside the drawn stone (drivers, the climb's check).
func inside(c: Vector3, r: float) -> bool:
	if space == null: return false
	return _escape(c,r) != Vector3.ZERO

## Inside the drawn stone: the first face straight up is seen from behind
## (a ground's top from under it). Then the shortest way out of it: up onto
## it, or across to a side's face (seen from behind too), clearing it by
## `r`. Zero outside.
## Seen from behind further up than ESCAPE_K of its radius it is not
## inside (an isle's ground far over it, its keel drawn short); within
## DEEP_K of it under the walkable ground it is lifted onto it.
const ESCAPE_K := 3.0
const DEEP_K := 1.2
const ESCAPE_WAYS := 8
const ESCAPE_INSIDE := 5
func _escape(c: Vector3, r: float) -> Vector3:
	var up := _behind(c,Vector3.UP,r*ESCAPE_K)
	if up >= 0.0:
		escapes += 1
		var best := Vector3.UP*(up+r)
		for i in range(ESCAPE_WAYS):
			var a := TAU*float(i)/ESCAPE_WAYS
			var dir := Vector3(cos(a),0.0,sin(a))
			var d := _behind(c,dir,best.length())
			if d >= 0.0 and d+r < best.length(): best = dir*(d+r)
		return best
	# Deeper under a ground than that: only under an isle (its footprint,
	# under its top) can it be inside its rock (a landing's corbel, a
	# hillside); inside, most ways across meet a face from behind.
	if nav == null: return Vector3.ZERO
	var u: Dictionary = nav.under(c,r)
	if u.is_empty() or float(u.top) < c.y or float(u.inside) < -r: return Vector3.ZERO
	var reach := r*ESCAPE_K*1.5
	var best := Vector3.UP*(float(u.top)-c.y+r)
	var hits := 0
	for i in range(ESCAPE_WAYS):
		var a := TAU*float(i)/ESCAPE_WAYS
		var dir := Vector3(cos(a),0.0,sin(a))
		var d := _behind(c,dir,reach)
		if d < 0.0: continue
		hits += 1
		if d+r < best.length(): best = dir*(d+r)
	if hits < ESCAPE_INSIDE: return Vector3.ZERO
	escapes += 1
	return best

## How far along `dir` from `c` the first face is, if it is seen from
## behind; -1 if none within `most` or it faces `c`.
func _behind(c: Vector3, dir: Vector3, most: float) -> float:
	_ray.from = c
	_ray.to = c+dir*most
	_ray.hit_back_faces = true
	var any := space.intersect_ray(_ray)
	if any.is_empty(): return -1.0
	var t := (any.position as Vector3).distance_to(c)
	_ray.hit_back_faces = false
	var front := space.intersect_ray(_ray)
	_ray.hit_back_faces = true
	if not front.is_empty() and (front.position as Vector3).distance_to(c) <= t+0.01: return -1.0
	return t

## The lift (or sideways push) taking the newer ball (`a`, radius `ra`)
## over the older (`b`, `rb`) where they overlap; zero if they don't.
func _over(a: Vector3, ra: float, b: Vector3, rb: float, apart: bool) -> Vector3:
	if not apart: return Vector3.ZERO
	var across := (ra+rb)*REACH_ACROSS
	var stack := (ra+rb)*REACH_UP
	var d := a-b
	var flat := Vector2(d.x,d.z).length()
	if flat >= across: return Vector3.ZERO
	var k := flat/across
	var up := stack*sqrt(1.0-k*k)
	if d.y >= up: return Vector3.ZERO
	var lift := up-d.y
	if lift <= stack*LIFT_MOST: return Vector3.UP*lift
	# Far under it: aside.
	var side := Vector3(d.x,0.0,d.z)
	side = side/flat if flat > 0.01 else Vector3.RIGHT
	return side*(across-flat)

## The jaw's room (rad): its tip (head frame `xf`, the hinge `hinge` and
## the tip at rest `tip`, world) kept over the ground straight under it.
func jaw_limit(xf: Transform3D, hinge: Vector3, tip: Vector3, want: float) -> float:
	if want <= 0.02 or space == null or not on:
		jaw_room = 10.0
		return want
	var side := xf.basis.x.normalized()
	var at := xf*hinge
	var tip_w := xf*tip
	var open := (tip_w-at).rotated(side,want)+at
	_ray.from = open+Vector3.UP*14.0
	_ray.to = open+Vector3.DOWN*6.0
	var hit := space.intersect_ray(_ray)
	if hit.is_empty():
		jaw_room = 10.0
		return want
	var g := (hit.position as Vector3).y+0.15
	if open.y >= g:
		jaw_room = 10.0
		return want
	# Bisect the angle that sets the tip on the ground.
	var lo := 0.0
	var hi := want
	for _i in range(8):
		var mid := (lo+hi)*0.5
		var q := (tip_w-at).rotated(side,mid)+at
		if q.y >= g: lo = mid
		else: hi = mid
	jaw_room = lo
	return lo
