extends Node
## The pilot's wake through low foliage: grass, flowers, wheat, ferns,
## shrubs, reeds and the meadow's dense grass part round him and lie over as
## he goes through, then spring back up past upright and settle, like a
## spring let go (mushrooms tip and wobble the same way). On the figure, it
## publishes where he is and the path he just took to the shaders
## (zs_tread_*, read by zs_tread_push in shaders/foliage_tread.gdshaderinc):
## slot 0 where he is now, then a point every SPACING metres he has come,
## newest first, each with the lean it puts on the plants by it, sprung by
## its age (`spring`), so the stretch just behind him is still parted and the
## wake closes up a beat later with an overshoot. At a run the wake is wider
## and leans harder than at a walk; standing he parts a little ring; in the
## air (more than LIFT over the ground) he parts nothing, and coming down
## hard parts a wider ring a moment (KICK). Hidden (building, flying) his
## wake springs back and the shaders stop reading it.
##
## A downdraft (scripts/downdraft.gd, its GROUP: `downdraft`) lays a ring
## of it flat where it touched: a circle growing out to the blast's radius
## over BLAST_GROW s, pressed down at its middle, held BLAST_HOLD s, then
## springing back up as his wake does. While it lies flat it takes the
## shaders' slots (his own wake drops out of sight for that second and is
## kept, so it comes back whole).
##
## Everything here is world x, z (the plants' roots are), from the figure's
## own place, so it holds on the plate and on an islet alike. `push_at` is
## the shaders' push on the CPU, for tests and probes.

## The shaders' globals: the path's points, then the box round it.
const POINTS := 16
const GLOBALS: Array[StringName] = [&"zs_tread_0",&"zs_tread_1",&"zs_tread_2",&"zs_tread_3",&"zs_tread_4",&"zs_tread_5",&"zs_tread_6",&"zs_tread_7",&"zs_tread_8",&"zs_tread_9",&"zs_tread_10",&"zs_tread_11",&"zs_tread_12",&"zs_tread_13",&"zs_tread_14",&"zs_tread_15",&"zs_tread_box"]
## Metres he comes between the path's points: 0.1 s apart at a run, so the
## spring reads smoothly along the wake, and the path's fifteen reach 6 m
## back, as long as a run's wake takes to settle.
const SPACING := 0.4
## The wake's reach out from his path (m), and the lean it puts on what is
## by it (1 lays a small plant well over): standing, at a walk (PilotMotor
## WALK), at a run (RUN). Tune these first by feel.
const RADIUS_STAND := 0.45
const RADIUS_WALK := 0.7
const RADIUS_RUN := 1.0
const LEAN_STAND := 0.45
const LEAN_WALK := 0.8
const LEAN_RUN := 1.0
const WALK := 2.0
const RUN := 4.0
## The spring back, once he has passed a point: held HOLD s (his body going
## by), then let go as a spring from rest at RING rad/s, damped DAMP 1/s.
## Back past upright by exp(-PI * DAMP / RING) (about 28 %) at about
## HOLD + PI / RING s, a second smaller swing, settled by about 1.5 s: at a
## run the wake stays open about 2 m behind him and closes up over the next
## 2 m or so.
const HOLD := 0.22
const RING := 8.0
const DAMP := 3.2
## A point is dropped this many seconds after he passed it.
const LIFE := 1.6
## Metres over the ground: under the first he parts it all, over the second
## nothing (a jump leaves a gap in the wake).
const LIFT := Vector2(0.12,0.55)
## Coming down at more than KICK_FROM m/s the ring at his feet is wider and
## leans harder by KICK per m/s over it (at most KICK_MAX), fading over
## KICK_FADE s.
const KICK_FROM := 3.0
const KICK := 0.1
const KICK_MAX := 0.6
const KICK_FADE := 0.3
## Seconds the lean and reach at his feet ease to their goal, and his pace
## to what he moved.
const EASE := 0.07
const EASE_PACE := 0.1
## Moved further than this in a frame he was set down somewhere else: the
## path starts over there.
const CUT := 2.0
## Wading deeper than this (m), or swimming, he parts nothing: underwater.
const UNDER := 0.2
## A downdraft's flattened ring: seconds it grows out over, is held flat,
## and its lean (by the blast's strength, least and full).
const BLAST_GROW := 0.3
const BLAST_HOLD := 0.45
const BLAST_LEAN := Vector2(0.75,1.2)

## The motor he is moved by (scripts/pilot_motor.gd), for his height over the
## ground and his fall; without one he is always on the ground.
var motor: RefCounted
## Whether the wake follows him; off (or the figure hidden) it springs back.
var on := true
## What was last published, one per GLOBALS.
var published := PackedVector4Array()
## Seconds this wake has run.
var clock := 0.0
## His place (world x, z), lean and reach now, his pace (m/s) and landing kick.
var head := Vector2.ZERO
var lean := 0.0
var radius := 0.0
var pace := 0.0
var kick := 0.0
## The path behind him, newest first: (x, z, when passed on `clock`, lean
## then), with each one's reach.
var path := PackedVector4Array()
var reach := PackedFloat32Array()
var _placed := false
var _was_on := false
var _fall := 0.0
var _grounded := true

## The last downdraft's ring: {at (x, z), radius, lean, t (on `clock`)},
## {} none.
var blast := {}

func _ready() -> void:
	add_to_group(&"downdraft")
	published.resize(GLOBALS.size())
	for i in range(published.size()): published[i] = Vector4(INF,0,0,0)

func _exit_tree() -> void:
	path.clear()
	reach.clear()
	_placed = false
	_publish(true)

func _process(delta: float) -> void:
	var parent := get_parent() as Node3D
	var visible_now := on and parent != null and parent.is_visible_in_tree() and not _under_water()
	var at := parent.global_position if parent != null else Vector3.ZERO
	advance(delta,at,visible_now,_lift(at))

## Whether he is in water too deep for anything to grow (scripts/
## pilot_motor.gd `wade`, `swimming`): swimming, or wading deeper than
## UNDER m; the wake is quiet there.
func _under_water() -> bool:
	if motor == null: return false
	if "swimming" in motor and motor.swimming: return true
	return "wade" in motor and float(motor.wade) > UNDER

## His height over the ground under him, from the motor.
func _lift(_at: Vector3) -> float:
	if motor == null: return 0.0
	return maxf(0.0,float(motor.get("feet").y)-float(motor.get("ground_y")))

## One frame: he is at `at` (world), `walking` whether he is on foot and
## seen, `lift` metres over the ground.
func advance(delta: float, at: Vector3, walking: bool, lift := 0.0) -> void:
	if delta <= 0.0: return
	if not walking and not _placed and path.is_empty():
		_was_on = false
		return
	clock += delta
	var now := Vector2(at.x,at.z)
	if walking and (not _placed or now.distance_to(head) > CUT):
		# Stepped in, or set down somewhere new: a fresh path from here.
		path.clear()
		reach.clear()
		head = now
		pace = 0.0
		lean = 0.0
		radius = RADIUS_STAND
		_placed = true
	if walking:
		var moved := now.distance_to(head)/delta
		pace = lerpf(pace,moved,1.0-exp(-delta/EASE_PACE))
		head = now
		_land(lift)
		var low := 1.0-smoothstep(LIFT.x,LIFT.y,lift)
		var goal := _lean_for(pace)*low*(1.0+kick)
		var wide := _radius_for(pace)*(1.0+0.6*kick)
		var k := 1.0-exp(-delta/EASE)
		lean = lerpf(lean,goal,k)
		radius = lerpf(radius,wide,k)
		kick *= exp(-delta/KICK_FADE)
		if path.is_empty() or head.distance_to(Vector2(path[0].x,path[0].y)) >= SPACING: _drop()
	elif _was_on:
		# Gone from here: where he stood springs back with the rest.
		_drop()
		lean = 0.0
	_was_on = walking
	# The oldest points, long settled, fall away.
	while not path.is_empty() and clock-path[path.size()-1].z > LIFE:
		path.resize(path.size()-1)
		reach.resize(reach.size()-1)
	if not walking and path.is_empty(): _placed = false
	_publish()

## Landing: a hard one kicks the ring at his feet wider for a moment.
func _land(lift: float) -> void:
	if motor == null: return
	var grounded := bool(motor.get("grounded"))
	var vy := float(motor.get("velocity").y)
	if not grounded: _fall = maxf(_fall,-vy)
	elif not _grounded:
		kick = maxf(kick,clampf((_fall-KICK_FROM)*KICK,0.0,KICK_MAX))
		_fall = 0.0
	_grounded = grounded

func _drop() -> void:
	path.insert(0,Vector4(head.x,head.y,clock,lean))
	reach.insert(0,radius)
	while path.size() > POINTS-1:
		path.resize(POINTS-1)
		reach.resize(POINTS-1)

static func _lean_for(speed: float) -> float:
	if speed < WALK: return lerpf(LEAN_STAND,LEAN_WALK,smoothstep(0.0,WALK,speed))
	return lerpf(LEAN_WALK,LEAN_RUN,clampf((speed-WALK)/(RUN-WALK),0.0,1.0))

static func _radius_for(speed: float) -> float:
	if speed < WALK: return lerpf(RADIUS_STAND,RADIUS_WALK,smoothstep(0.0,WALK,speed))
	return lerpf(RADIUS_WALK,RADIUS_RUN,clampf((speed-WALK)/(RUN-WALK),0.0,1.0))

## A point's share of its lean `age` s after he passed it: 1 while held,
## then a damped spring let go from rest (no kink as it lets go), back past
## 0 and settling.
static func spring(age: float) -> float:
	if age <= HOLD: return 1.0
	var t := age-HOLD
	if t > LIFE: return 0.0
	return exp(-DAMP*t)*(cos(RING*t)+DAMP/RING*sin(RING*t))

## A downdraft touched at `at`, `radius` round (scripts/downdraft.gd): the
## grass lies flat in a ring there.
func downdraft(at: Vector3, radius: float, strength: float) -> void:
	blast = {"at":Vector2(at.x,at.z),"radius":radius,"lean":lerpf(BLAST_LEAN.x,BLAST_LEAN.y,clampf(strength,0.0,1.0)),"t":clock}

## The flattened ring's slot now ((x, z, reach, lean)), or none (w 0) once
## it has sprung back.
func blast_slot() -> Vector4:
	if blast.is_empty(): return Vector4.ZERO
	var age := clock-float(blast.t)
	if age > BLAST_HOLD+LIFE:
		blast = {}
		return Vector4.ZERO
	var grow := 1.0-pow(1.0-clampf(age/BLAST_GROW,0.0,1.0),2.0)
	var at: Vector2 = blast.at
	return Vector4(at.x,at.y,maxf(float(blast.radius)*grow,0.01),float(blast.lean)*spring(maxf(age-BLAST_HOLD,0.0)))

## The globals as they stand: all zero once there is nothing to part.
func values() -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(GLOBALS.size())
	var ring := blast_slot()
	if ring.z > 0.0 and not blast.is_empty():
		# The ring alone: the rest left zero, so the path stops at it.
		out[0] = ring
		out[POINTS] = Vector4(ring.x-ring.z,ring.y-ring.z,ring.x+ring.z,ring.y+ring.z)
		return out
	if not _placed and path.is_empty(): return out
	var widest := radius
	out[0] = Vector4(head.x,head.y,maxf(radius,0.01),lean if _was_on else 0.0)
	var low := head
	var high := head
	for i in range(path.size()):
		var p := path[i]
		# A full path's oldest point leans nothing, so the wake fades toward
		# the end that drops away rather than ending in a step.
		var last := i == POINTS-2
		out[1+i] = Vector4(p.x,p.y,maxf(reach[i],0.01),0.0 if last else p.w*spring(clock-p.z))
		low = low.min(Vector2(p.x,p.y))
		high = high.max(Vector2(p.x,p.y))
		widest = maxf(widest,reach[i])
	out[POINTS] = Vector4(low.x-widest,low.y-widest,high.x+widest,high.y+widest)
	return out

func _publish(force := false) -> void:
	var now := values()
	if published.size() != now.size():
		published.resize(now.size())
		force = true
	for i in range(now.size()):
		if force or now[i] != published[i]:
			published[i] = now[i]
			RenderingServer.global_shader_parameter_set(GLOBALS[i],now[i])

## The shaders' zs_tread_push on the CPU, from what is published: the push
## at a world x, z (x, z: out from the path, length at most 1, negative
## leans springing back toward it) and its press (z). Keep in step with
## shaders/foliage_tread.gdshaderinc and its constants.
const CORE := 0.12
const DRAG := 0.35
const POP := 0.5
func push_at(root: Vector2) -> Vector3:
	var v := published
	if v.size() != GLOBALS.size() or v[0].z <= 0.0 or v[0].x == INF: return Vector3.ZERO
	var box := v[POINTS]
	if root.x < box.x or root.y < box.y or root.x > box.z or root.y > box.w: return Vector3.ZERO
	var off := root-Vector2(v[0].x,v[0].y)
	var best := off.length_squared()
	var r := v[0].z
	var w_lean := v[0].w
	var way := Vector2.ZERO
	for j in range(POINTS-1):
		var a := v[j]
		var b := v[j+1]
		if b.z <= 0.0: break
		var ab := Vector2(a.x-b.x,a.y-b.y)
		var len2 := ab.length_squared()
		if len2 < 0.000001: continue
		var s := clampf((root-Vector2(b.x,b.y)).dot(ab)/len2,0.0,1.0)
		var d := root-(Vector2(b.x,b.y)+ab*s)
		if d.length_squared() < best:
			best = d.length_squared()
			off = d
			r = lerpf(b.z,a.z,s)
			w_lean = lerpf(b.w,a.w,s)
			way = ab/sqrt(len2)
	var dist := sqrt(best)
	if r <= 0.0 or dist >= r: return Vector3.ZERO
	var w := 1.0-smoothstep(0.3,1.0,dist/r)
	var away := off/sqrt(best+CORE*CORE)
	var push := (away+way*DRAG)*(w_lean*w)
	var core := 1.0-smoothstep(0.0,0.55,dist/r)
	var press := clampf((w_lean if w_lean > 0.0 else w_lean*POP)*core,-0.5,1.0)
	if push.length() > 1.0: push = push.normalized()
	return Vector3(push.x,push.y,press)
