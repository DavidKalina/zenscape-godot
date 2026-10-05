extends RefCounted
## The little plane's landing and takeoff (scripts/sky_plane.gd): short,
## readable sequences that take the controls smoothly and give them back.
## The wanderer (scripts/wanderer_eye.gd) picks the strip
## (scripts/plane_strip.gd) and starts one on F; this flies it, as plain
## state and maths over the plane, so tests can step it.
##
## Landing, from F to walking, about 7 to 10 seconds (more from far off,
## hurried as it is):
##   LINE_UP   the plane turns onto final: it steers like a pilot onto the
##             strip's extended centreline (a pursuit of a point LOOK m
##             ahead on it, turning no tighter than TURN_RADIUS), going out
##             round first if it is past the gate or too close in; over
##             whatever lies under the way in by CLEAR m. 1.5 to 4 s.
##   DESCENT   a gentle glide down the final, FINAL_LEN m from the gate to
##             the touch at FINAL_H m up, the throttle back. About 1.5 s.
##   FLARE     the last FLARE_LEN m: the nose lifts and the sink eases off.
##   TOUCHDOWN the wheels touch with a small bounce or two (`touched` on
##             that frame, for the puff and the blip).
##   ROLLOUT   it slows to a stop along the strip, the tail settling.
##   BEAT      a moment stopped, the propeller spinning down.
##   HOP_OUT   the pilot hops out (`hop` 1 to 0 as it goes); then DONE, and
##             the wanderer walks beside the parked plane.
## Before the touch, Boost, a roll or F again calls it off (`cancel`): the
## plane flies on from where it is, nose a little up. After it, F skips to
## the hop (`skip`). Nothing in it can crash: the way in clears the ground
## and the plane never stops in the air.
##
## Takeoff, from the parked plane: BOARD (the pilot hops in), TAXI (it
## turns on the spot to its run), ROLL (along the run, tail up, faster),
## LIFT (off and climbing) and DONE, flying. A run off the shore lets it go
## as it leaves the land.

const PlaneStrip = preload("res://scripts/plane_strip.gd")

enum {LINE_UP,DESCENT,FLARE,TOUCHDOWN,ROLLOUT,BEAT,HOP_OUT,DONE,BOARD,TAXI,ROLL,LIFT}
const NAMES := ["line-up","descent","flare","touchdown","rollout","beat","hop-out","done","board","taxi","roll","lift"]

## The line-up: the tightest turn (m), how far ahead on the centreline it
## aims (m), how far out past the gate it goes round to (m), the step it
## plans in (m), and the most it plans (m).
const TURN_RADIUS := 11.0
const LOOK := 10.0
const OUT := 38.0
const STEP := 1.0
const FARTHEST := 900.0
## Its speeds (m/s): at the gate and the most it hurries to, how hard it
## speeds up and slows down hurrying (m/s²), and the time it aims to take
## at most (s). Further than that takes, it hurries: up to HURRY, along,
## and back down to the gate's speed.
const GATE_SPEED := 12.0
const HURRY := 30.0
const HURRY_PUSH := 12.0
const LINE_UP_TIME := 2.8
## Metres over whatever is under the way in, and how steeply the way may
## climb or dive to clear it (m per m).
const CLEAR := 3.0
const CLEAR_FINAL := 1.0
const CLIMB := 0.45
## The final: its length and height at the gate (m), the flare's length,
## the speeds at the flare and the touch (m/s), the pitch it descends at
## and the pitch it flares to (radians).
const FINAL_LEN := 14.0
const FINAL_H := 2.6
const FLARE_LEN := 3.5
const FLARE_SPEED := 8.5
const TOUCH_SPEED := 7.0
const DESCENT_PITCH := -0.05
const FLARE_PITCH := 0.2
## The touch's bounces: heights (m) and lengths (s).
const BOUNCE := Vector2(0.13,0.035)
const BOUNCE_TIME := Vector2(0.3,0.18)
## The rollout: the run it takes to stop at most (m) and the hardest it
## brakes (m/s²); the beat (s), the hop out (s).
const ROLL_LEN := 5.5
const BRAKE_MAX := 5.0
const BEAT_TIME := 0.35
const HOP_TIME := 0.5
## How fast the engine spins down at the beat and up on boarding (s).
const SPIN := 0.35
## Takeoff: the hop in (s), the turn on the spot (radians a second), the
## run's push (m/s²), the speeds the tail comes up and it lifts (m/s), the
## climb (s, m/s) and the speed it leaves at.
const BOARD_TIME := 0.6
const TAXI_RATE := 1.6
const PUSH := 4.5
const TAIL_UP := 5.0
const LIFT_SPEED := 9.5
const LIFT_TIME := 1.3
const LIFT_CLIMB := 3.2
const LEAVE_SPEED := 12.0
## The bank in a planned turn: share of the turn's lean, the most, and how
## fast it follows (s).
const BANK_SHARE := 1.0
const BANK_MOST := 0.85
const EASE_BANK := 0.18

var plane: RefCounted
var phase := LINE_UP
## Seconds in this phase and since it began.
var time := 0.0
var elapsed := 0.0
## True on the frame the wheels first touch.
var touched := false
## The engine running (0 to 1: the propeller and its hum) and the throttle
## (-1 back to 1 open) for the hum.
var engine := 1.0
var throttle := 0.0
## The pilot's hop: 0 in the cockpit, 1 out beside it.
var hop := 0.0
## The strip (global): {touch, end: Vector3 on the ground, dir: Vector3
## level, length, hop}; and what stands under a point.
var strip := {}
var floor_at := Callable()
## The planned way in: points (global) and the level distance to each, the
## distances where the gate and the flare begin, and each part's timing:
## Vector4(start distance, length, start speed, end speed) and seconds.
var _way := PackedVector3Array()
var _along := PackedFloat32Array()
var _gate := 0.0
var _flare := 0.0
var _parts: Array[Vector4] = []
var _times := PackedFloat32Array()
## A hurried line-up: Vector4(seconds speeding up, seconds along, seconds
## slowing down, the speed along), or ZERO for an easy one.
var _hurry := Vector4.ZERO
var _heading_was := 0.0
## The rollout: the touch speed and braking; and the rest it settles to.
var _touch_speed := TOUCH_SPEED
var _brake := 0.0
var _rest := Vector4.ZERO
var _rolled := 0.0
## Takeoff: where it starts, the run's way and length, whether it leaves
## the shore, the heading it turns to, and the climb so far.
var _start := Vector3.ZERO
var _run := {}
var _run_heading := 0.0
var _climb := 0.0
var _lift_from := 0.0

# --- Landing ---------------------------------------------------------------------

## Which of `strips` (global, best first, each with its `score`) to land on:
## the best once the way in is weighed, seconds of line-up costing TIME_COST
## m of strip, a final the trees push up costing LIFT_COST a metre.
const TIME_COST := 2.5
const LIFT_COST := 4.0
func choose(from: RefCounted, strips: Array, top: Callable) -> Dictionary:
	var best := {}
	var best_score := -INF
	for s: Dictionary in strips:
		var probe: RefCounted = get_script().new()
		probe.plane = from
		probe.strip = s
		probe._plan(top)
		var cost: float = TIME_COST*probe._times[0]+LIFT_COST*probe._final_lift(top)
		var score: float = float(s.get("score",0.0))-cost
		if best.is_empty() or score > best_score:
			best = s
			best_score = score
	return best

## Starts landing `plane` (a SkyPlane, flying) on `strip`; `top` is
## Callable(Vector3) -> Variant (Vector2(top, underside) or null) for what
## the way in must clear, `ground` Callable(Vector2) -> float (NAN off the
## land) for the wheels, both global.
##
## `touching`: it is already on the ground (a slow touch without F), and
## only rolls out along the strip from where it is.
func land(on_plane: RefCounted, on_strip: Dictionary, top: Callable, ground: Callable, touching := false) -> void:
	plane = on_plane
	strip = on_strip
	floor_at = ground
	phase = LINE_UP
	time = 0.0
	elapsed = 0.0
	touched = false
	engine = 1.0
	throttle = 0.0
	hop = 0.0
	_heading_was = float(plane.heading)
	var length: float = strip.length
	_touch_speed = TOUCH_SPEED if length >= ROLL_LEN else clampf(sqrt(2.0*BRAKE_MAX*maxf(length,0.3)),3.5,TOUCH_SPEED)
	if touching: _touch_speed = minf(clampf(float(plane.speed),3.5,9.0),sqrt(2.0*BRAKE_MAX*1.5*maxf(length,0.3)))
	_brake = _touch_speed*_touch_speed/(2.0*clampf(length,0.3,ROLL_LEN))
	_rolled = 0.0
	if touching:
		_touch()
		return
	_plan(top)

func can_cancel() -> bool:
	return phase in [LINE_UP,DESCENT,FLARE]

func on_ground() -> bool:
	return phase in [TOUCHDOWN,ROLLOUT,BEAT,HOP_OUT,BOARD,TAXI,ROLL]

func done() -> bool:
	return phase == DONE

## Called off before the touch: the plane flies on from where it is, nose a
## little up so it climbs away. Returns false once it is too late.
func cancel() -> bool:
	if not can_cancel(): return false
	plane.resume(maxf(float(plane.speed),GATE_SPEED*0.9),0.12)
	phase = DONE
	return true

## After the touch, straight to the hop out.
func skip() -> void:
	if phase in [TOUCHDOWN,ROLLOUT,BEAT]:
		_stop_here()
		_enter(HOP_OUT)

## One step of the sequence.
func step(delta: float) -> void:
	touched = false
	time += delta
	elapsed += delta
	match phase:
		LINE_UP,DESCENT,FLARE: _fly(delta)
		TOUCHDOWN,ROLLOUT: _roll(delta)
		BEAT:
			engine = maxf(0.0,engine-delta/SPIN)
			throttle = -1.0
			_hold()
			if time >= BEAT_TIME: _enter(HOP_OUT)
		HOP_OUT:
			engine = 0.0
			hop = clampf(time/HOP_TIME,0.0,1.0)
			_hold()
			if time >= HOP_TIME: _enter(DONE)
		BOARD,TAXI,ROLL,LIFT: _takeoff(delta)

func _enter(next: int) -> void:
	phase = next
	time = 0.0

## The planned way in, from the plane to the touch: the line-up's route,
## the gate, the final straight down the centreline; each point's height
## the base glide lifted over what is under it.
func _plan(top: Callable) -> void:
	var touch: Vector3 = strip.touch
	var dir: Vector3 = strip.dir
	var d2 := Vector2(dir.x,dir.z).normalized()
	var gate := touch-dir*FINAL_LEN
	var from: Vector3 = plane.position
	var flat := route(Vector2(from.x,from.z),float(plane.heading),Vector2(gate.x,gate.z),d2)
	_way = PackedVector3Array()
	_along = PackedFloat32Array()
	var walked := 0.0
	for i in range(flat.size()):
		if i > 0: walked += flat[i].distance_to(flat[i-1])
		_way.append(Vector3(flat[i].x,0.0,flat[i].y))
		_along.append(walked)
	_gate = walked
	var n := int(ceil(FINAL_LEN/STEP))
	for i in range(1,n+1):
		var u := float(i)/n
		var p := gate.lerp(touch,u)
		_way.append(Vector3(p.x,0.0,p.z))
		_along.append(_gate+FINAL_LEN*u)
	_flare = _gate+FINAL_LEN-FLARE_LEN
	var total := _gate+FINAL_LEN
	# Heights: the line-up eases from the plane's height to the gate's; the
	# final glides down at its slope and flares.
	var gate_y := touch.y+PlaneStrip.contact(DESCENT_PITCH)+FINAL_H
	var base := PackedFloat32Array()
	base.resize(_way.size())
	var low := PackedFloat32Array()
	low.resize(_way.size())
	for i in range(_way.size()):
		var s := _along[i]
		if s <= _gate:
			base[i] = lerpf(from.y,gate_y,smoothstep(0.0,1.0,s/maxf(_gate,0.01)))
		else:
			var u := total-s
			base[i] = touch.y+PlaneStrip.contact(_pitch_at(s))+_final_height(u)
		low[i] = -INF
		if s < _flare-1.0:
			var under: Variant = top.call(Vector3(_way[i].x,base[i],_way[i].z))
			if under != null:
				var t := (under as Vector2).x if under is Vector2 else float(under)
				low[i] = t+(CLEAR if s <= _gate else CLEAR_FINAL)
	# Lifted over what is under it, ramped so the way climbs and dives no
	# steeper than CLIMB.
	var up := low.duplicate()
	for i in range(1,up.size()): up[i] = maxf(up[i],up[i-1]-CLIMB*(_along[i]-_along[i-1]))
	for i in range(up.size()-2,-1,-1): up[i] = maxf(up[i],up[i+1]-CLIMB*(_along[i+1]-_along[i]))
	for i in range(_way.size()):
		var y := maxf(base[i],up[i])
		# The first metres ease from where the plane is, never into what is
		# under it.
		var k := smoothstep(0.0,10.0,_along[i])
		y = lerpf(from.y,y,k) if y > from.y else y
		if low[i] > -INF: y = maxf(y,low[i]-(CLEAR if _along[i] <= _gate else CLEAR_FINAL)+0.9)
		_way[i].y = y
	var v0 := maxf(float(plane.speed),7.0)
	_parts = [Vector4(0.0,_gate,v0,GATE_SPEED),Vector4(_gate,_flare-_gate,GATE_SPEED,FLARE_SPEED),Vector4(_flare,FLARE_LEN,FLARE_SPEED,TOUCH_SPEED)]
	_times = PackedFloat32Array()
	_hurry = Vector4.ZERO
	for part in _parts:
		var t := 2.0*part.y/maxf(part.z+part.w,0.1)
		if part.x == 0.0 and t > LINE_UP_TIME:
			_hurry = _hurried(part.y,part.z,part.w)
			t = _hurry.x+_hurry.y+_hurry.z
		_times.append(maxf(t,0.05))

## The quickest even way along `length` m from `v0` to `v1` m/s that takes
## about LINE_UP_TIME: up at HURRY_PUSH to a speed no more than HURRY,
## along at it, and down at HURRY_PUSH to `v1`.
static func _hurried(length: float, v0: float, v1: float) -> Vector4:
	var low := maxf(v0,v1)
	var high := HURRY
	var best := Vector4.ZERO
	for i in range(24):
		var v := high if i == 0 else (low+high)*0.5
		var up := (v-v0)/HURRY_PUSH
		var down := (v-v1)/HURRY_PUSH
		var ramps := (v0+v)*0.5*up+(v+v1)*0.5*down
		var along := (length-ramps)/v
		var plan := Vector4(up,maxf(along,0.0),down,v)
		if i == 0:
			best = plan
			if up+along+down >= LINE_UP_TIME or along < 0.0: return plan
			continue
		if along >= 0.0 and up+along+down >= LINE_UP_TIME:
			best = plan
			high = v
		else:
			low = v
	return best

## How much the final had to be lifted over trees and ground (m).
func _final_lift(top: Callable) -> float:
	var most := 0.0
	var touch: Vector3 = strip.touch
	var total := _gate+FINAL_LEN
	for i in range(_way.size()):
		if _along[i] <= _gate or _along[i] >= _flare: continue
		var base := touch.y+PlaneStrip.contact(_pitch_at(_along[i]))+_final_height(total-_along[i])
		most = maxf(most,_way[i].y-base)
	return most

## The height over the touch at `u` m before it: the glide slope, then the
## flare's curve, easing to a gentle sink at the touch.
static func _final_height(u: float) -> float:
	var slope := FINAL_H/FINAL_LEN
	if u >= FLARE_LEN: return slope*u
	var t := clampf(1.0-u/FLARE_LEN,0.0,1.0)
	var h0 := slope*FLARE_LEN
	# Hermite from (h0, -slope) to (0, -0.03 a metre).
	var h00 := 2.0*t*t*t-3.0*t*t+1.0
	var h10 := t*t*t-2.0*t*t+t
	var h11 := t*t*t-t*t
	return maxf(0.0,h00*h0+h10*FLARE_LEN*(-slope)+h11*FLARE_LEN*(-0.03))

## The pitch at a distance along the way: level-ish down the final, lifting
## through the flare.
func _pitch_at(s: float) -> float:
	if s < _flare: return DESCENT_PITCH
	return lerpf(DESCENT_PITCH,FLARE_PITCH,smoothstep(0.0,1.0,(s-_flare)/FLARE_LEN))

## A pilot's way onto a line: from `from` heading `heading` (the scene's
## yaw), to the gate `gate` on the line the way `dir`, turning no tighter
## than TURN_RADIUS. Close in or past the gate it goes out round first.
## Level points every STEP m, ending at the gate.
static func route(from: Vector2, heading: float, gate: Vector2, dir: Vector2) -> PackedVector2Array:
	var across := Vector2(-dir.y,dir.x)
	var line := atan2(-dir.x,-dir.y)
	var pos := from
	var h := heading
	var points := PackedVector2Array([pos])
	var rel := pos-gate
	var lat := rel.dot(across)
	var going := Vector2(-sin(h),-cos(h))
	var side := signf(lat) if absf(lat) > 1.0 else (signf(going.dot(across)) if absf(going.dot(across)) > 0.01 else 1.0)
	# Room to join: well before the gate, and not flying away from it.
	var out := rel.dot(dir) > -(LOOK+TURN_RADIUS*2.0) or going.dot(dir) < -0.3 and rel.dot(dir) > -(LOOK+TURN_RADIUS*4.0)
	var out_at := gate-dir*OUT+across*side*TURN_RADIUS*1.2
	var turn := STEP/TURN_RADIUS
	var walked := 0.0
	var joined := false
	while walked < FARTHEST:
		rel = pos-gate
		var s := rel.dot(dir)
		lat = rel.dot(across)
		var carrot: Vector2
		if out:
			carrot = out_at
			if pos.distance_to(out_at) < TURN_RADIUS*1.2: out = false
		else:
			if s >= -STEP*0.5:
				if absf(lat) < 1.5 and absf(angle_difference(h,line)) < 0.2:
					joined = true
					break
				# Missed it: round again.
				side = signf(lat) if absf(lat) > 0.5 else side
				out = true
				out_at = gate-dir*OUT+across*side*TURN_RADIUS*1.2
				continue
			carrot = gate+dir*(s+LOOK)
		var to := carrot-pos
		var want := atan2(-to.x,-to.y)
		h += clampf(angle_difference(h,want),-turn,turn)
		pos += Vector2(-sin(h),-cos(h))*STEP
		walked += STEP
		points.append(pos)
	if not joined:
		# Never left to wander: a straight way to the gate.
		points = PackedVector2Array([from,gate])
		return points
	# The last stretch eased onto the line so it ends at the gate, on it.
	var ease := mini(points.size()-1,int(LOOK*2.0/STEP))
	var last := points[points.size()-1]
	var miss := gate-last
	for i in range(ease+1):
		var k := points.size()-1-ease+i
		points[k] += miss*smoothstep(0.0,1.0,float(i)/maxf(ease,1))
	points[points.size()-1] = gate
	return points

## The point and speed at time `t` into the part `index`.
func _at(index: int, t: float) -> Array:
	var part: Vector4 = _parts[index]
	var total := _times[index]
	if index == 0 and _hurry != Vector4.ZERO: return _at_hurried(part,t)
	var u := clampf(t/total,0.0,1.0)
	# Hermite in time: from the start speed to the end speed, covering the
	# part's length.
	var h10 := u*u*u-2.0*u*u+u
	var h01 := -2.0*u*u*u+3.0*u*u
	var h11 := u*u*u-u*u
	var s := part.x+h10*total*part.z+h01*part.y+h11*total*part.w
	var d10 := 3.0*u*u-4.0*u+1.0
	var d01 := -6.0*u*u+6.0*u
	var d11 := 3.0*u*u-2.0*u
	var v := (d10*total*part.z+d01*part.y+d11*total*part.w)/total
	return [clampf(s,part.x,part.x+part.y),maxf(v,0.5)]

func _at_hurried(part: Vector4, t: float) -> Array:
	var v0 := part.z
	var v1 := part.w
	var vc := _hurry.w
	if t < _hurry.x:
		var a := (vc-v0)/maxf(_hurry.x,0.0001)
		return [part.x+v0*t+0.5*a*t*t,v0+a*t]
	var s := part.x+(v0+vc)*0.5*_hurry.x
	t -= _hurry.x
	if t < _hurry.y: return [s+vc*t,vc]
	s += vc*_hurry.y
	t = minf(t-_hurry.y,_hurry.z)
	var b := (vc-v1)/maxf(_hurry.z,0.0001)
	return [minf(s+vc*t-0.5*b*t*t,part.x+part.y),vc-b*t]

## The way's point at level distance `s`, and its direction.
func _sample(s: float) -> Array:
	var n := _along.size()
	if n < 2: return [_way[0] if n > 0 else Vector3.ZERO,Vector3.FORWARD]
	var lo := 0
	var hi := n-1
	while hi-lo > 1:
		var mid := (lo+hi)/2
		if _along[mid] <= s: lo = mid
		else: hi = mid
	var span := maxf(_along[hi]-_along[lo],0.0001)
	var k := clampf((s-_along[lo])/span,0.0,1.0)
	return [_way[lo].lerp(_way[hi],k),_way[hi]-_way[lo]]

func _fly(delta: float) -> void:
	var index := phase-LINE_UP
	var at := _at(index,time)
	var s: float = at[0]
	var v: float = at[1]
	var here: Array = _sample(s)
	var p: Vector3 = here[0]
	var way: Vector3 = here[1]
	var level := Vector2(way.x,way.z).length()
	var heading := atan2(-way.x,-way.z) if level > 0.0001 else float(plane.heading)
	var climb := way.y/maxf(level,0.0001)
	plane.position = p
	var turned := angle_difference(_heading_was,heading)
	_heading_was = heading
	plane.heading = heading
	var lean := clampf(atan(-turned/maxf(delta,0.0001)*v/9.8)*BANK_SHARE,-BANK_MOST,BANK_MOST)
	plane.bank = lerpf(float(plane.bank),lean,1.0-exp(-delta/EASE_BANK))
	var aim := atan(climb)*0.6 if phase == LINE_UP else _pitch_at(s)
	plane.pitch = lerpf(float(plane.pitch),aim,1.0-exp(-delta/0.25))
	# Down the final the wheels' height is planned for the planned pitch;
	# the nose easing to it keeps them there.
	if phase != LINE_UP: plane.position.y += PlaneStrip.contact(plane.pitch)-PlaneStrip.contact(_pitch_at(s))
	plane.speed = v*sqrt(1.0+climb*climb)
	plane.velocity = Vector3(-sin(heading),climb,-cos(heading))*v
	plane.spin = 0.0
	plane.rolling = false
	plane.skimming = false
	# Throttle back from the gate.
	throttle = 0.0 if phase == LINE_UP else -1.0
	if time >= _times[index]:
		if phase == FLARE:
			_touch()
		else:
			_enter(phase+1)

func _touch() -> void:
	_enter(TOUCHDOWN)
	touched = true
	_rolled = 0.0
	plane.pitch = FLARE_PITCH
	var end_at := (strip.touch as Vector3)+(strip.dir as Vector3)*minf(float(strip.length),ROLL_LEN)
	_rest = PlaneStrip.rest(floor_at,Vector2(end_at.x,end_at.z),float(plane.heading))

func _roll(delta: float) -> void:
	var since := _since_touch()
	var tt := minf(since,_touch_speed/_brake)
	var s := _touch_speed*tt-0.5*_brake*tt*tt
	var v := maxf(_touch_speed-_brake*tt,0.0)
	_rolled = s
	var dir: Vector3 = strip.dir
	var p: Vector3 = (strip.touch as Vector3)+dir*s
	var ground := float(floor_at.call(Vector2(p.x,p.z)))
	if is_nan(ground): ground = (strip.touch as Vector3).y
	# The tail settles as it slows; each bounce rocks the nose.
	var settle := smoothstep(0.0,1.0,1.0-v/_touch_speed)
	var bounce := _bounce(since)
	var pitch := lerpf(FLARE_PITCH,_rest.y,settle)-bounce*0.6
	plane.pitch = pitch
	plane.bank = lerpf(float(plane.bank),_rest.z*settle,1.0-exp(-delta/0.2))
	plane.position = Vector3(p.x,ground+PlaneStrip.contact(pitch)+bounce,p.z)
	plane.speed = v
	plane.velocity = dir*v
	throttle = -1.0
	if phase == TOUCHDOWN and time >= BOUNCE_TIME.x+BOUNCE_TIME.y: _enter(ROLLOUT)
	if phase == ROLLOUT and v <= 0.0:
		_stop_here()
		_enter(BEAT)

func _since_touch() -> float:
	return time if phase == TOUCHDOWN else time+BOUNCE_TIME.x+BOUNCE_TIME.y

func _bounce(t: float) -> float:
	if t < BOUNCE_TIME.x: return BOUNCE.x*sin(PI*t/BOUNCE_TIME.x)
	t -= BOUNCE_TIME.x
	if t < BOUNCE_TIME.y: return BOUNCE.y*sin(PI*t/BOUNCE_TIME.y)
	return 0.0

## Stopped where it is: sat on its wheels and tail.
func _stop_here() -> void:
	var p: Vector3 = plane.position
	_rest = PlaneStrip.rest(floor_at,Vector2(p.x,p.z),float(plane.heading))
	if is_nan(_rest.x): _rest = Vector4(p.y,PlaneStrip.REST_PITCH,0.0,p.y-PlaneStrip.contact(PlaneStrip.REST_PITCH))
	plane.position = Vector3(p.x,_rest.x,p.z)
	plane.pitch = _rest.y
	plane.bank = _rest.z
	plane.speed = 0.0
	plane.velocity = Vector3.ZERO

func _hold() -> void:
	plane.speed = 0.0
	plane.velocity = Vector3.ZERO

## Where the wheels stopped: the plane's rest (Vector4 as PlaneStrip
## `rest`).
func rest() -> Vector4:
	return _rest

## Total seconds of the way in planned (line-up, descent, flare).
func planned_time() -> float:
	var total := 0.0
	for t in _times: total += t
	return total

# --- Takeoff ---------------------------------------------------------------------

## Starts taking `on_plane` off from where it stands parked (its position,
## heading, pitch and bank already set), along `run` ({dir: Vector3 level,
## length, edge}), with `ground` as for `land`.
func take_off(on_plane: RefCounted, run: Dictionary, ground: Callable) -> void:
	plane = on_plane
	floor_at = ground
	_run = run
	_start = plane.position
	var dir: Vector3 = run.dir
	_run_heading = atan2(-dir.x,-dir.z)
	_rest = Vector4(plane.position.y,float(plane.pitch),float(plane.bank),plane.position.y-PlaneStrip.contact(float(plane.pitch)))
	phase = BOARD
	time = 0.0
	elapsed = 0.0
	engine = 0.0
	throttle = 0.0
	hop = 1.0
	_rolled = 0.0
	_climb = 0.0
	_hold()

func _takeoff(delta: float) -> void:
	match phase:
		BOARD:
			hop = 1.0-clampf(time/BOARD_TIME,0.0,1.0)
			engine = minf(1.0,engine+delta/SPIN)
			_hold()
			if time >= BOARD_TIME:
				hop = 0.0
				_enter(TAXI)
		TAXI:
			engine = 1.0
			throttle = -0.3
			var off := angle_difference(float(plane.heading),_run_heading)
			var turn := clampf(off,-TAXI_RATE*delta,TAXI_RATE*delta)
			plane.heading = float(plane.heading)+turn
			var p: Vector3 = plane.position
			var r := PlaneStrip.rest(floor_at,Vector2(p.x,p.z),float(plane.heading))
			if not is_nan(r.x):
				plane.position.y = r.x
				plane.pitch = r.y
				plane.bank = r.z
			_hold()
			if absf(off) < 0.01:
				plane.heading = _run_heading
				_start = plane.position
				_enter(ROLL)
		ROLL:
			throttle = 1.0
			var v := PUSH*time
			var s := 0.5*PUSH*time*time
			var dir: Vector3 = _run.dir
			var p: Vector3 = _start+dir*s
			var ground := float(floor_at.call(Vector2(p.x,p.z)))
			var tail := smoothstep(0.0,TAIL_UP,v)
			var pitch := lerpf(_rest.y,0.03,tail)
			plane.heading = _run_heading
			plane.pitch = pitch
			plane.bank = lerpf(float(plane.bank),0.0,1.0-exp(-delta/0.2))
			plane.speed = v
			plane.velocity = dir*v
			_rolled = s
			if is_nan(ground):
				# Off the shore: it flies off the edge from here.
				plane.position = Vector3(p.x,plane.position.y,p.z)
				_leave(v)
				return
			plane.position = Vector3(p.x,ground+PlaneStrip.contact(pitch),p.z)
			var room: float = float(_run.length)-0.5
			if v >= LIFT_SPEED or (not bool(_run.edge) and s >= maxf(room,0.5)):
				_lift_from = v
				_enter(LIFT)
		LIFT:
			throttle = 1.0
			var u := clampf(time/LIFT_TIME,0.0,1.0)
			var v := lerpf(_lift_from,LEAVE_SPEED,u)
			var rise := LIFT_CLIMB*smoothstep(0.0,0.6,u)
			var dir: Vector3 = _run.dir
			plane.position += dir*v*delta+Vector3.UP*rise*delta
			plane.pitch = lerpf(float(plane.pitch),atan2(rise,v)+0.08,1.0-exp(-delta/0.2))
			plane.speed = v
			plane.velocity = dir*v+Vector3.UP*rise
			if time >= LIFT_TIME: _leave(v)

func _leave(v: float) -> void:
	plane.resume(maxf(v,7.0),maxf(float(plane.pitch),0.12))
	_enter(DONE)
