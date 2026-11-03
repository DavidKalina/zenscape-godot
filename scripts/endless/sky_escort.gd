extends Node3D
## Company in the air (docs/design/endless-flight/spec-sky-and-water-company.md):
## now and then, flying clear of the ground, a small flock comes in from off
## screen, opens out round the plane, keeps it company for several seconds and
## breaks away. Rare on purpose: the wait is seconds flown clear of the ground,
## drawn afresh after each one, so no rhythm shows.
##
## This file says when an escort goes and where its flock is. The birds are a
## flock of the birds node (scripts/endless/endless_birds.gd, `put_escort`, the
## ESCORT state): an anchor the birds keep station on through their spring in
## `_fly_birds`, as RIDING's do, here flown on the CPU and drawn with the other
## songbirds' parts in the `starling`'s dark plumage.
##
## Where they are is worked out from the view, not the plane: a seat is a place
## on the screen (a share of the half width and half height) at some metres in
## front of the eye. The frame is the camera's way, smoothed, so a turn that
## swings the view takes the birds with it and they stay in the picture. The
## seats sit over the eye line, for the sky behind them. They cheat their speed
## to do it. Visual only: nothing here reads into or writes to the flight.
##
## Flags: --escort=X how many birds over the default (1; 0 none), --escort-gap=S
## the mean seconds clear of the ground between them (GAP), --escort-size=X the
## birds' size over SIZE. --birds=0 stops it too.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")

## Seconds clear of the ground between escorts, on average, and how far a draw
## goes to either side of that (a share of it). The first of a flight comes at
## this share of a gap.
const GAP := 60.0
const GAP_SPREAD := 0.34
const FIRST := Vector2(0.3,0.6)
## Clear of the ground, read every READ s: this high over the land under it and
## a second's flight ahead, this fast (medium cruise is 36.5), not in a tight
## place, not diving, climbing or turning hard (of speed; rad/s).
const READ := 0.25
const CLEAR := 10.0
const FAST := 24.0
const STEEP := 0.5
const TURN_MOST := 0.8
## Past these a flock in company gives up and goes: slower, steeper.
const FAST_LEAST := 18.0
const STEEP_MOST := 0.8
## The flock: its birds, their size over the far flocks' span (0.85 m), bigger
## than the trees' so they read a long way up the frame.
const BIRDS := Vector2i(7,12)
const SIZE := 1.5
## How it comes in (s), each way in turn (`_ways`), and how long it stays once
## it has (s).
const ARRIVE := Vector2(2.6,3.4)
const STAY := Vector2(6.0,10.0)
## A seat: on the screen (shares of the half width and half height from its
## middle; the plane sits about -0.25 down it) and metres ahead of the eye.
const SEAT_SIDE := Vector2(0.08,0.34)
const SEAT_UP := Vector2(0.18,0.36)
const SEAT_AHEAD := Vector2(16.0,21.0)
## Partway through it crosses over the nose to its other seat, this long (s).
const CROSS_TIME := 2.6
## The seat's slow wander (shares; m ahead), the flock's breathing.
const DRIFT := Vector2(0.05,0.045)
const DRIFT_AHEAD := 2.5
const BREATHE := 0.14
## The flock's spread (the birds node's `spread`): bunched coming and going,
## opened round the plane; how loose each bird is about its seat; a bird trades
## seats with another this often (s).
const BUNCHED := 1.0
const OPEN := Vector2(2.6,3.4)
const LOOSE := 0.2
const TRADE := Vector2(0.5,1.3)
## The anchor's follow: how hard it closes on its seat (1/s), how quickly its
## velocity takes up what it wants (1/s).
const CLOSE := 2.2
const TAKE_UP := 7.0
## The view's way, smoothed (1/s), and the most it may be off the plane's line
## (the cosine) before the plane's line is used instead: a free look.
const WAY_EASE := 3.5
const LOOK_OFF := 0.7
## Going: it turns away over this long (s) so that it slides off this fast (m/s
## across the plane's line), at this share of its pace, falling back or pulling
## on ahead; up at most this (m/s). It is dropped once it is off screen, or at
## the longest or past the furthest.
const TURN_AWAY := 1.3
const ACROSS := Vector2(19.0,25.0)
const PACE_BACK := 0.95
const PACE_ON := 1.13
const AWAY_UP := Vector2(0.0,5.0)
const OFF_SCREEN := 0.8
const LEAVE_LONGEST := 8.0
const FURTHEST := 240.0
## A jump of the plane past this (m in a frame) drops it where it is.
const JUMP := 60.0

enum { COMING, STAYING, GOING }

var density := 1.0
var gap := GAP
var size := 1.0
## The numbers: escorts so far, seconds clear of the ground, how many a full
## sky of birds held back (seconds), a read's cost (ms).
var stats := {"escorts":0,"birds":0,"clear_s":0.0,"reads":0,"read_ms":0.0,"no_room_s":0.0}
## The last escorts (for drivers): the time, seconds clear since the one before,
## birds, how it came and went, speed and height.
var log_escorts: Array = []

var _field: RefCounted
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _wait := 0.0
var _due := 0.0
var _since := 0.0
var _yaw := 0.0
var _turning := 0.0
var _flock: RefCounted = null
var _fwd := Vector3.ZERO
var _last := Vector3.ZERO
var _ways_left: Array = []

static func flags() -> Dictionary:
	var out := {"density":1.0,"gap":GAP,"size":1.0}
	for a: String in LaunchArgs.user_args():
		var v := a.get_slice("=",1)
		if a.begins_with("--escort="): out.density = maxf(0.0,float(v))
		elif a.begins_with("--escort-gap="): out.gap = maxf(float(v),1.0)
		elif a.begins_with("--escort-size="): out.size = maxf(float(v),0.1)
	return out

func setup(land_seed: int, field: RefCounted) -> void:
	var f := flags()
	density = f.density
	gap = f.gap
	size = f.size
	_field = field
	_rng.seed = hash("sky escort%d" % land_seed)
	_due = _next_gap()*_rng.randf_range(FIRST.x,FIRST.y)

## Seconds clear of the ground to the next.
func _next_gap() -> float:
	return gap*_rng.randf_range(1.0-GAP_SPREAD,1.0+GAP_SPREAD)

## One frame: a read of the sky now and then.
func step(delta: float, plane: RefCounted, eye: Vector3) -> void:
	if density <= 0.0: return
	_time += delta
	_wait -= delta
	if _wait > 0.0: return
	_wait = READ
	var t0 := Time.get_ticks_usec()
	_read(plane.position,plane.velocity,eye)
	stats.reads += 1
	stats.read_ms = lerpf(float(stats.read_ms),(Time.get_ticks_usec()-t0)/1000.0,0.1)

# --- When ------------------------------------------------------------------------

func _read(pp: Vector3, pv: Vector3, eye: Vector3) -> void:
	var flat := Vector3(pv.x,0.0,pv.z)
	if flat.length() < 1.0: return
	var fwd := flat.normalized()
	var yaw := atan2(-fwd.x,-fwd.z)
	_turning = lerpf(_turning,angle_difference(_yaw,yaw)/READ,0.4)
	_yaw = yaw
	var speed := pv.length()
	if speed < FAST or absf(pv.y) > speed*STEEP or absf(_turning) > TURN_MOST: return
	var over := pp.y-maxf(_field.height(pp.x,pp.z),Field.SEA_Y)
	var ahead := pp+fwd*speed
	over = minf(over,pp.y-maxf(_field.height(ahead.x,ahead.z),Field.SEA_Y))
	if over < CLEAR or _tight(): return
	stats.clear_s += READ
	_since += READ
	_due -= READ
	if _due > 0.0: return
	_try(pv,over,eye)

## The chase camera in a tight place: a tunnel, a hall, a door.
func _tight() -> bool:
	var chase: Variant = get_parent().get_parent().get("chase")
	return chase != null and bool(chase.tight)

func _try(pv: Vector3, over: float, eye: Vector3) -> void:
	var host := get_parent()
	if _flock != null and host.flocks.has(_flock): return
	_flock = null
	if host.count_in(host.COVEY) > 0: return
	var n := clampi(roundi(_rng.randi_range(BIRDS.x,BIRDS.y)*density),1,30)
	if not host.covey_room(n):
		stats.no_room_s += READ
		return
	_fwd = _view_way(pv)
	var plan := _plan(n)
	var rel := _rel(plan,0.0)
	var to := _rel(plan,0.02)
	var f: RefCounted = host.put_escort(_at(eye,rel),pv+_along((to-rel)/0.02),n,SIZE*size,plan)
	f.loose = LOOSE
	f.spread = BUNCHED
	_last = eye
	_flock = f
	stats.escorts += 1
	stats.birds += n
	log_escorts.append({"t":_time,"clear":_since,"n":n,"way":plan.way,"speed":pv.length(),"over":over,"stay":plan.stay})
	if log_escorts.size() > 128: log_escorts.pop_front()
	_since = 0.0
	_due = _next_gap()

# --- Where -----------------------------------------------------------------------

## The way to look from: the view's, unless a free look has it off the line.
func _view_way(pv: Vector3) -> Vector3:
	var line := pv.normalized() if pv.length() > 1.0 else Vector3.FORWARD
	var view := get_viewport().get_camera_3d()
	if view == null: return line
	var way := -view.global_basis.z
	return way if way.dot(line) > LOOK_OFF else line

## The half width and half height of the view at a metre.
func _view_size() -> Vector2:
	var view := get_viewport().get_camera_3d()
	var tall := tan(deg_to_rad((view.fov if view != null else 80.0)*0.5))
	var rect := get_viewport().get_visible_rect().size
	return Vector2(tall*(rect.x/maxf(rect.y,1.0)),tall)

## Off the view's frame (m right, up, ahead) into the world, from the eye.
func _at(eye: Vector3, rel: Vector3) -> Vector3:
	return eye+_along(rel)

func _along(rel: Vector3) -> Vector3:
	var right := _fwd.cross(Vector3.UP).normalized()
	return right*rel.x+right.cross(_fwd)*rel.y+_fwd*rel.z

## The three ways in, each used before any comes again. `start` and `bend` are
## m right, up and ahead of the eye: a seat's off screen, the bend the way round.
func _ways() -> String:
	if _ways_left.is_empty():
		_ways_left = ["overtake","cross","over"]
		for i in range(2,0,-1):
			var j := _rng.randi_range(0,i)
			var w: String = _ways_left[i]
			_ways_left[i] = _ways_left[j]
			_ways_left[j] = w
	return _ways_left.pop_back()

func _plan(n: int) -> Dictionary:
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var wide := _view_size()
	var way := _ways()
	var ahead := _rng.randf_range(SEAT_AHEAD.x,SEAT_AHEAD.y)
	var up := _rng.randf_range(SEAT_UP.x,SEAT_UP.y)
	var start := Vector3.ZERO
	var bend := Vector3.ZERO
	match way:
		"overtake":
			# From behind the eye, out past the wing, overtaking.
			var out := _rng.randf_range(17.0,24.0)
			start = Vector3(side*out,_rng.randf_range(2.0,7.0),-_rng.randf_range(24.0,34.0))
			bend = Vector3(side*(out+6.0),_rng.randf_range(6.0,10.0),ahead*0.45)
		"cross":
			# Off the far edge, well out ahead, and across.
			var far := _rng.randf_range(52.0,64.0)
			start = Vector3(side*wide.x*far*1.3,wide.y*far*0.45,far)
			bend = Vector3(side*wide.x*far*0.35,wide.y*far*0.42,far*0.7)
		"over":
			# Off the top, coming down round the wing.
			var high := _rng.randf_range(24.0,30.0)
			start = Vector3(side*_rng.randf_range(4.0,12.0),wide.y*high*1.35,high)
			bend = Vector3(side*wide.x*high*0.62,wide.y*high*0.8,high*1.05)
	var arrive := _rng.randf_range(ARRIVE.x,ARRIVE.y)
	var stay := _rng.randf_range(STAY.x,STAY.y)
	# It comes to the side it came from, then over the nose to the other.
	var one := _rng.randf_range(SEAT_SIDE.x,SEAT_SIDE.y)
	var two := _rng.randf_range(SEAT_SIDE.x,SEAT_SIDE.y)
	return {"stage":COMING,"way":way,"side":side,"start":start,"bend":bend,"arrive":arrive,"stay":stay,
		"seat_a":Vector3(side*one,up,ahead),"seat_b":Vector3(-side*two,up+_rng.randf_range(-0.08,0.08),ahead+_rng.randf_range(-4.0,4.0)),
		"cross_at":arrive+_rng.randf_range(0.25,0.55)*maxf(stay-CROSS_TIME,0.5),
		"open":_rng.randf_range(OPEN.x,OPEN.y),"phase":_rng.randf()*TAU,"trade":_rng.randf_range(TRADE.x,TRADE.y),
		"left":0.0,"from":Vector3.FORWARD,"speed":0.0,"pace":PACE_BACK,"turn":0.0,"up":0.0,"n":n}

## Where a flock's seat is at `t`, off the view's frame.
func _seat(p: Dictionary, t: float) -> Vector3:
	var s: Vector3 = (p.seat_a as Vector3).lerp(p.seat_b,smoothstep(float(p.cross_at),float(p.cross_at)+CROSS_TIME,t))
	var ph: float = p.phase
	var ahead := s.z+DRIFT_AHEAD*sin(t*0.7+ph)
	var wide := _view_size()
	return Vector3((s.x+DRIFT.x*sin(t*0.9+ph*2.0))*wide.x*ahead,(s.y+DRIFT.y*sin(t*1.1+ph*3.0))*wide.y*ahead,ahead)

## The flock's place at `t`: its way in, quick at first and settling on the seat.
func _rel(p: Dictionary, t: float) -> Vector3:
	var seat := _seat(p,t)
	var u := t/float(p.arrive)
	if u >= 1.0: return seat
	var e := 1.0-(1.0-u)*(1.0-u)
	var a: Vector3 = (p.start as Vector3).lerp(p.bend,e)
	return a.lerp((p.bend as Vector3).lerp(seat,e),e)

# --- The flock's frame -------------------------------------------------------------

## One frame of a flock in company: the anchor on its seat, the birds opened
## round it, trading places; false once it is to be dropped.
func fly(f: RefCounted, delta: float, eye: Vector3, pp: Vector3, pv: Vector3) -> bool:
	var p: Dictionary = f.plan
	if eye.distance_to(_last) > JUMP: return false
	_last = eye
	var open := 0.0
	if int(p.stage) == GOING:
		p.left = float(p.left)+delta
		open = 1.0-smoothstep(0.0,1.6,float(p.left))
		_going(f,p,delta)
		if _over(f,p,eye): return false
	else:
		_fwd = _fwd.slerp(_view_way(pv),1.0-exp(-delta*WAY_EASE)).normalized()
		var rel := _rel(p,f.t)
		var ahead := _rel(p,f.t+0.05)
		var want: Vector3 = pv+_along((ahead-rel)/0.05)+(_at(eye,rel)-f.a)*CLOSE
		f.av = f.av.lerp(want,1.0-exp(-delta*TAKE_UP))
		f.a += f.av*delta
		var k := float(f.t)/float(p.arrive)
		open = smoothstep(0.5,1.15,k)
		if int(p.stage) == COMING and k >= 1.0: p.stage = STAYING
		var done := float(p.arrive)+float(p.stay)
		if f.t > done or _shaken(pv): _go(f,p)
	f.spread = lerpf(BUNCHED,float(p.open)*(1.0+BREATHE*sin(float(f.t)*0.8+float(p.phase))),open)
	for b: RefCounted in f.birds: b.off = b.bunch.lerp(b.seat,open)
	p.trade = float(p.trade)-delta
	if float(p.trade) <= 0.0:
		p.trade = _rng.randf_range(TRADE.x,TRADE.y)
		_trade(f)
	return true

## The plane has gone off doing something else: no keeping up with that.
func _shaken(pv: Vector3) -> bool:
	return pv.length() < FAST_LEAST or absf(pv.y) > pv.length()*STEEP_MOST or _tight()

## Two birds change places, each swinging across on its spring.
func _trade(f: RefCounted) -> void:
	var n: int = f.birds.size()
	if n < 2: return
	var i := _rng.randi_range(0,n-1)
	var j := (i+_rng.randi_range(1,n-1))%n
	var seat: Vector3 = f.birds[i].seat
	f.birds[i].seat = f.birds[j].seat
	f.birds[j].seat = seat

## Off: to whichever side it is on now, falling back or pulling on ahead.
func _go(f: RefCounted, p: Dictionary) -> void:
	p.stage = GOING
	p.left = 0.0
	var right := _fwd.cross(Vector3.UP).normalized()
	var lat: float = (f.a-_last).dot(right)
	p.side = signf(lat) if absf(lat) > 1.0 else float(p.side)
	var flat := Vector3(f.av.x,0.0,f.av.z)
	p.from = flat.normalized() if flat.length() > 1.0 else f.heading
	p.speed = maxf(f.av.length(),FAST_LEAST)
	p.pace = PACE_BACK if _rng.randf() < 0.5 else PACE_ON
	p.turn = asin(clampf(_rng.randf_range(ACROSS.x,ACROSS.y)/float(p.speed),0.0,0.9))
	p.up = _rng.randf_range(AWAY_UP.x,AWAY_UP.y)

func _going(f: RefCounted, p: Dictionary, delta: float) -> void:
	var k := smoothstep(0.0,TURN_AWAY,float(p.left))
	var way: Vector3 = (p.from as Vector3).rotated(Vector3.UP,-float(p.side)*float(p.turn)*k)
	var want := way*float(p.speed)*float(p.pace)+Vector3.UP*float(p.up)*k
	f.av = f.av.lerp(want,1.0-exp(-delta*TAKE_UP*0.6))
	f.a += f.av*delta

## Gone: out of the frame, the last of them, or a long way off.
func _over(f: RefCounted, p: Dictionary, eye: Vector3) -> bool:
	if float(p.left) > LEAVE_LONGEST or (f.a-eye).length() > FURTHEST: return true
	if float(p.left) < OFF_SCREEN: return false
	var view := get_viewport().get_camera_3d()
	if view == null: return false
	for b: RefCounted in f.birds:
		if view.is_position_in_frustum(b.p): return false
	return true

## A bird's place in the open flock: a crescent round the plane, its horns back
## beside the wings, its middle ahead and all of it over the eye line.
func seat_of(i: int, n: int) -> Vector3:
	var u := (i+0.5)/n*2.0-1.0
	return Vector3(u+_rng.randf_range(-0.14,0.14),_rng.randf_range(-0.25,0.7),u*u*0.9-0.32+_rng.randf_range(-0.28,0.28))

## The numbers line (F1).
func note() -> String:
	if density <= 0.0: return ""
	return "\nsky escort: %d so far, %d birds  ·  %.0f s clear of the ground, %.0f s to the next  ·  read %.2f ms" % [
		int(stats.escorts),int(stats.birds),float(stats.clear_s),_due,float(stats.read_ms)]
