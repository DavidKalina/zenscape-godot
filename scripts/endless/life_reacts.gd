extends RefCounted
## Life reacts (docs/design/endless-flight/spec-wild-kit-director.md): the
## shared reactions a creature declares and the happenings director or a
## moment calls on it. A reaction moves one point (the creature's feet) and
## says which way it faces and which way the plane is; the creature poses its
## own body from `phase`, `in_phase` and `velocity`. Small and plain, so any
## creature (the waterfowl now, the elk later) can take it up.
##
##   flush    up and away: a beat alert (`wait`), a run along what it stands
##            on (`run` s, on `surface`), then a climb away from the plane.
##   bolt     a beat alert, then a run off along the ground away from the
##            plane, veering further off as it comes.
##   look_up  stays put and turns to track the plane.
##   follow   trails along behind and beside the plane for a while, as fast
##            as it can (it falls behind a plane faster than it); in the air,
##            or on its `surface` with the knob `fly` false.
##
## A creature declares what it does with a `reacts` array of these names
## (`offers`). `begin(kind, at, plane_at, knobs)` starts one; each frame
## `step(delta, at, plane_at, plane_velocity)` returns where the creature is
## now. It is over when `phase` is DONE (after the knob `time`, s).
##
## Sitting tight: with the knob `near` (m) a flush, bolt or follow holds in
## `wait`, unroused (`roused` false), watching the plane, until the plane
## comes within `near` m (flat), `hold` s pass or the creature calls
## `rouse()` (a flock rousing as one); then its `wait` beat runs. Its clock
## (`t`, `time`) starts at the rousing.

const FLUSH := &"flush"
const BOLT := &"bolt"
const LOOK_UP := &"look_up"
const FOLLOW := &"follow"

## The phases: alert before it goes, running along the surface, in the air
## (flush's climb, follow's trail), watching (look_up), over.
const WAIT := &"wait"
const RUN := &"run"
const AIR := &"air"
const WATCH := &"watch"
const DONE := &"done"

## Each kind's knobs, merged under the ones given to `begin`: s (wait, run,
## climb_for, time), m/s (run_speed, speed, climb), m/s² (accel), rad/s
## (turn, wander), m (gap, side, clear: flush's height kept over its surface
## in the air; near: sits tight until the plane is this near, 0 not at all),
## s (hold: the longest it sits tight).
const KNOBS := {
	FLUSH: {"wait":0.0,"near":0.0,"hold":12.0,"run":1.0,"run_speed":6.0,"speed":14.0,"accel":5.0,"climb":3.5,"climb_for":6.0,"wander":0.15,"clear":4.0,"time":20.0},
	BOLT: {"wait":0.0,"near":0.0,"hold":12.0,"speed":9.0,"accel":8.0,"time":6.0},
	LOOK_UP: {"turn":4.0,"time":4.0},
	FOLLOW: {"wait":0.0,"near":0.0,"hold":12.0,"speed":16.0,"accel":6.0,"gap":14.0,"side":5.0,"fly":true,"time":8.0},
}

var kind := &""
var phase := WAIT
## Seconds since it began, and since its phase began.
var t := 0.0
var in_phase := 0.0
## World m/s.
var velocity := Vector3.ZERO
## The flat way it faces (unit).
var facing := Vector3.FORWARD
## The way to the plane from it (unit, with height): a head turns to this.
var look := Vector3.FORWARD
## The flat way it sets out along, off from the plane (flush, bolt).
var away := Vector3.FORWARD
var knobs := {}
## `func(p: Vector3) -> float`: the height of what it runs on under `p`
## (water, ground). Unset: it keeps its height while it runs.
var surface := Callable()
## Whether it has been roused (always, without the knob `near`), and how
## long it sat tight before.
var roused := true
var held := 0.0
## A phase for the flush's slow wander (from `begin`'s `wobble`).
var _wobble := 0.0

## Whether `creature` declares reaction `what` (its `reacts` array).
static func offers(creature: Object, what: StringName) -> bool:
	var r: Variant = creature.get("reacts")
	return r is Array and (r as Array).has(what)

## A reaction `what` for a creature at `at` with the plane at `plane_at`;
## `given` overrides KNOBS (an `away` Vector3 sets the way off; a `wobble`
## float varies the wander between creatures).
static func begin(what: StringName, at: Vector3, plane_at: Vector3, given := {}) -> RefCounted:
	var r := new()
	r.kind = what
	r.knobs = (KNOBS.get(what,{}) as Dictionary).duplicate()
	r.knobs.merge(given,true)
	var off := at-plane_at
	off.y = 0.0
	r.away = off.normalized() if off.length() > 0.01 else Vector3.FORWARD
	if given.has("away"):
		var a: Vector3 = given.away
		a.y = 0.0
		if a.length() > 0.01: r.away = a.normalized()
	r.facing = r.away
	r._wobble = float(given.get("wobble",0.0))
	r.phase = WATCH if what == LOOK_UP else WAIT
	r.roused = r.phase != WAIT or float(r.knobs.get("near",0.0)) <= 0.0
	r._look_at(at,plane_at)
	return r

## Ends sitting tight: its `wait` beat starts now.
func rouse() -> void:
	if roused: return
	roused = true
	in_phase = 0.0

func step(delta: float, at: Vector3, plane_at: Vector3, plane_velocity := Vector3.ZERO) -> Vector3:
	if phase == DONE: return at
	if not roused:
		_look_at(at,plane_at)
		if kind != FLUSH: _turn_to(Vector3(look.x,0.0,look.z),3.0,delta)
		held += delta
		if Vector2(plane_at.x-at.x,plane_at.z-at.z).length() < float(knobs.near) or held >= float(knobs.hold): rouse()
		else: return at
	t += delta
	in_phase += delta
	_look_at(at,plane_at)
	var p := at
	match kind:
		FLUSH: p = _flush(delta,at)
		BOLT: p = _bolt(delta,at)
		LOOK_UP: _turn_to(Vector3(look.x,0.0,look.z),float(knobs.turn),delta)
		FOLLOW: p = _follow(delta,at,plane_at,plane_velocity)
	if t >= float(knobs.time): phase = DONE
	return p

func _enter(next: StringName) -> void:
	phase = next
	in_phase = 0.0

func _look_at(at: Vector3, plane_at: Vector3) -> void:
	var to := plane_at-at
	if to.length() > 0.01: look = to.normalized()

## Turns `facing` towards flat `way` at `rate` rad/s.
func _turn_to(way: Vector3, rate: float, delta: float) -> void:
	if way.length() < 0.01: return
	var a := facing.signed_angle_to(way.normalized(),Vector3.UP)
	facing = facing.rotated(Vector3.UP,clampf(a,-rate*delta,rate*delta)).normalized()

func _on_surface(p: Vector3) -> Vector3:
	if surface.is_valid(): p.y = float(surface.call(p))
	return p

func _flush(delta: float, at: Vector3) -> Vector3:
	if phase == WAIT:
		if in_phase < float(knobs.wait): return at
		_enter(RUN if float(knobs.run) > 0.0 else AIR)
		velocity = away
		facing = away
		if phase == AIR: velocity.y = float(knobs.climb)
	if phase == RUN:
		# Speeding up along the surface, its way set.
		var k := clampf(in_phase/maxf(float(knobs.run),0.01),0.0,1.0)
		velocity = away*lerpf(1.0,float(knobs.run_speed),k)
		var p := _on_surface(at+velocity*delta)
		if in_phase >= float(knobs.run):
			_enter(AIR)
			velocity.y = float(knobs.climb)*0.6
		return p
	# In the air: away and up, faster, wandering a little; the climb eases
	# off after climb_for.
	away = away.rotated(Vector3.UP,float(knobs.wander)*sin(t*0.6+_wobble)*delta)
	var flat := Vector2(velocity.x,velocity.z).length()
	flat = move_toward(flat,float(knobs.speed),float(knobs.accel)*delta)
	var climb := float(knobs.climb)*(1.0-smoothstep(float(knobs.climb_for)*0.6,float(knobs.climb_for),in_phase))
	var vy := move_toward(velocity.y,climb,4.0*delta)
	# Kept `clear` m over what is under it: rising land lifts it.
	if surface.is_valid():
		var ahead := at+Vector3(away.x,0.0,away.z)*flat*1.5
		var short := float(surface.call(ahead))+float(knobs.clear)-at.y
		if short > 0.0: vy = maxf(vy,minf(short,float(knobs.climb)*2.5))
	velocity = Vector3(away.x*flat,vy,away.z*flat)
	facing = away
	return at+velocity*delta

func _bolt(delta: float, at: Vector3) -> Vector3:
	if phase == WAIT:
		_turn_to(Vector3(look.x,0.0,look.z),6.0,delta)
		if in_phase < float(knobs.wait): return at
		_enter(RUN)
	# Veering further off the plane as it comes.
	var off := -Vector3(look.x,0.0,look.z)
	if off.length() > 0.01: away = away.lerp(off.normalized(),clampf(1.5*delta,0.0,1.0)).normalized()
	var flat := move_toward(Vector2(velocity.x,velocity.z).length(),float(knobs.speed),float(knobs.accel)*delta)
	velocity = away*flat
	_turn_to(away,8.0,delta)
	return _on_surface(at+velocity*delta)

func _follow(delta: float, at: Vector3, plane_at: Vector3, plane_velocity: Vector3) -> Vector3:
	if phase == WAIT:
		_turn_to(Vector3(look.x,0.0,look.z),6.0,delta)
		if in_phase < float(knobs.wait): return at
		_enter(AIR if bool(knobs.fly) else RUN)
	var fwd := Vector3(plane_velocity.x,0.0,plane_velocity.z)
	fwd = fwd.normalized() if fwd.length() > 0.5 else facing
	var side := fwd.cross(Vector3.UP)
	var target := plane_at-fwd*float(knobs.gap)+side*float(knobs.side)
	var want := (target-at)
	if not bool(knobs.fly): want.y = 0.0
	# The plane still coming: off its way already, to fall in beside it as it
	# passes, not back towards it.
	if Vector3(want.x,0.0,want.z).dot(fwd) < 0.0: want = fwd*float(knobs.speed)
	want = want.normalized()*minf(float(knobs.speed),want.length()*2.0) if want.length() > 0.01 else Vector3.ZERO
	velocity = velocity.move_toward(want,float(knobs.accel)*delta)
	_turn_to(Vector3(velocity.x,0.0,velocity.z),3.0,delta)
	var p := at+velocity*delta
	return p if bool(knobs.fly) else _on_surface(p)
