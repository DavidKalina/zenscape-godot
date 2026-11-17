extends RefCounted
## The plane bouncing off a hot air balloon's envelope (scripts/endless/
## endless_balloons.gd calls it; docs/design/balloons/handoff-reveal-balloon.md).
##
## The envelope is two balls, as the pass reads it: the main one about the
## balloon's origin (R) and the lower cloth (LOW_BALL). The basket, the ropes
## and the burner frame stay untouchable: the plane flies through them as
## before. Touching the cloth (the plane's reach, PAD of its span, inside a
## ball) pushes it off softly: no crash, no damage. Its path is turned off the
## surface (the part going into it reflected at RESTITUTION), the nose turned
## with it, LOSS of the speed lost at a head-on touch (less glancing), a shove
## of KICK m/s out of the cloth dying away (SkyPlane `bump`), and the plane set
## back on the surface. Under the balloon the push is turned sideways (the
## normal no steeper down than NORMAL_DOWN) and the path never dives more than
## DIVE_MOST; with less than LOW_CLEAR m under it or under its way out (AHEAD m
## on), it leaves level or rising, so a bounce never throws it into the ground. Moving away already, it is only set
## back outside: never inside the cloth after a frame.

const SkySide = preload("res://scripts/sky_plane.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The plane's reach round its middle, as a share of its span.
const PAD := 0.4
## The share of the speed into the cloth that comes back out of it.
const RESTITUTION := 0.45
## The speed lost at a head-on touch (by how square it is).
const LOSS := 0.22
## The shove out of the cloth (m/s at a head-on touch, dying over BUMP_FADE).
const KICK := 7.0
## Under the balloon: the normal's least y, the path's least y, and the
## clearance under which it leaves level or rising (m), and how much up then.
const NORMAL_DOWN := -0.3
const DIVE_MOST := -0.22
const LOW_CLEAR := 35.0
const LOW_RISE := 0.06
## How far along its way out the ground is asked (m).
const AHEAD: Array[float] = [35.0,80.0]

## The deepest touch of a plane at `p` on the envelope of a balloon whose
## origin is `c`, scale `s` (two balls: `r` about the origin, the lower one
## `low` (y off the origin, radius) times `s`): {normal, depth, centre,
## radius} with depth > 0 inside, or {} if clear.
static func touch(c: Vector3, s: float, r: float, low: Vector2, p: Vector3) -> Dictionary:
	var pad := WorldScale.span*PAD
	var best := {}
	var best_d := 0.0
	for ball: Array in [[c,r*s],[c+Vector3.UP*low.x*s,low.y*s]]:
		var at: Vector3 = ball[0]
		var reach: float = float(ball[1])+pad
		var off := p-at
		var d := reach-off.length()
		if d > best_d:
			best_d = d
			var n := off.normalized() if off.length_squared() > 0.0001 else Vector3.UP
			best = {"normal":n,"depth":d,"centre":at,"radius":reach}
	return best

## The plane pushed off the cloth at `t` (from `touch`): set back on the
## surface and, if moving into it, turned off it. `ground` gives the height of
## what is under a point (land, trees, stone, water). Returns {into, before,
## after, out, push, clear} when it bounced ({} when only set back).
static func push_off(plane: RefCounted, t: Dictionary, ground: Callable) -> Dictionary:
	var n: Vector3 = t.normal
	var c: Vector3 = t.centre
	var reach: float = t.radius
	var push := push_way(plane,n)
	plane.position = c+n*(reach+0.05)
	var path: Vector3 = plane.path_now()
	var into := path.dot(push)
	if into >= -0.02: return {}
	var before := float(plane.speed)
	var way := way_out(plane,(path-push*into*(1.0+RESTITUTION)).normalized(),ground)
	var out: Vector3 = way[0]
	var clear: float = way[1]
	plane.speed = maxf(SkySide.SLOW,before*(1.0-LOSS*(-into)))
	var bump := push*(KICK*(-into))
	if clear < LOW_CLEAR: bump.y = maxf(bump.y,0.0)
	_fly_along(plane,out,bump)
	return {"into":-into,"before":before,"after":float(plane.speed),"out":out,"push":push,"clear":clear}

## The push's way off a cloth whose normal is `n`: under the balloon, turned
## sideways.
static func push_way(plane: RefCounted, n: Vector3) -> Vector3:
	if n.y >= NORMAL_DOWN: return n
	var level := Vector3(n.x,0.0,n.z)
	if level.length_squared() < 0.0001: level = -Vector3(-sin(float(plane.heading)),0.0,-cos(float(plane.heading)))
	level = level.normalized()*sqrt(1.0-NORMAL_DOWN*NORMAL_DOWN)
	return Vector3(level.x,NORMAL_DOWN,level.z)

## The way out `out` kept off the ground: [the way, the least of the clearance
## under the plane and under its way out]. Low over the ground it leaves level
## or rising under LOW_CLEAR, the dive let in over as much again.
static func way_out(plane: RefCounted, out: Vector3, ground: Callable) -> Array:
	var p: Vector3 = plane.position
	var clear := p.y-float(ground.call(p))
	var flat := Vector3(out.x,0.0,out.z)
	if flat.length_squared() > 0.0001:
		flat = flat.normalized()
		for a: float in AHEAD: clear = minf(clear,p.y-float(ground.call(p+flat*a)))
	var least := lerpf(LOW_RISE,0.0,clampf(clear/LOW_CLEAR,0.0,1.0))
	if clear > LOW_CLEAR: least = lerpf(0.0,DIVE_MOST,clampf((clear-LOW_CLEAR)/LOW_CLEAR,0.0,1.0))
	if out.y < least:
		var h := Vector2(out.x,out.z)
		h = (h.normalized() if h.length_squared() > 0.0001 else Vector2(-sin(float(plane.heading)),-cos(float(plane.heading))))*sqrt(1.0-least*least)
		out = Vector3(h.x,least,h.y)
	return [out,clear]

## The nose and the path both along `out`, with a shove `bump` dying away;
## the plane's own step then flies on that way.
static func _fly_along(plane: RefCounted, out: Vector3, bump: Vector3) -> void:
	var flat := Vector2(out.x,out.z)
	if flat.length() > 0.05: plane.heading = atan2(-out.x,-out.z)-float(plane.slip)
	var p := asin(clampf(out.y,-1.0,1.0))
	plane.pitch = clampf(p,SkySide.PITCH_LIMIT.x,SkySide.PITCH_LIMIT.y)
	plane._path_h = atan2(-out.x,-out.z) if flat.length() > 0.05 else float(plane.heading)+float(plane.slip)
	plane._path_p = p
	plane._path = out
	plane._pitch_rate = 0.0
	plane.bump = bump
	plane.velocity = out*float(plane.speed)+bump
	plane._left = plane.velocity

# --- The catch: the cloth takes the plane in and throws it back out ---------------
#
# The other bounce (endless_balloons.gd's default; --balloon-bounce=old the
# one above). The plane is not turned at the touch: it flies on into the
# cloth, which gives round it like a trampoline (a spring along `push_way`,
# by how deep the plane is in the ball), slows it to a stop SINK_TIME after a
# head-on touch, then throws it back out, SPRING_OUT stiffer on the way out
# so it leaves a little faster than it came. The plane's nose is held on its
# way in and turned to its way out as the cloth throws it; the stick does not
# steer it meanwhile. It is never deeper than DEEP of the ball, never held
# longer than CATCH_MOST s, and its way out is kept off the ground (`way_out`).

## From the touch to the deepest point (s), whatever the speed.
const SINK_TIME := 0.34
## The spring on the way out, over the one on the way in.
const SPRING_OUT := 1.35
## The deepest it goes (a share of the ball's radius).
const DEEP := 0.6
## The longest the cloth holds it (s); the speed out at most this over the
## speed in.
const CATCH_MOST := 1.6
const OUT_MOST := 1.25

class Catch:
	## Where the plane is and how it moves (world), kept here: the plane's own
	## step is overruled while the cloth has it.
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	## The nose on the way in (heading with the slip in it, pitch).
	var heading := 0.0
	var pitch := 0.0
	## The speed in, how square the touch was (0..1), the speed into the cloth.
	var before := 0.0
	var into := 0.0
	var vn := 0.0
	var t := 0.0
	## As last stepped: how deep (m), the push's way, the normal, the shove
	## the cloth gave this step (m/s), the deepest so far.
	var depth := 0.0
	var push := Vector3.UP
	var normal := Vector3.UP
	var shove := Vector3.ZERO
	var deepest := 0.0

## The cloth takes the plane at touch `t`: the catch, or null if the plane is
## not moving into it.
static func begin(plane: RefCounted, t: Dictionary) -> Catch:
	var path: Vector3 = plane.path_now()
	var push := push_way(plane,t.normal)
	var into := -path.dot(push)
	if into <= 0.02: return null
	var c := Catch.new()
	c.p = plane.position
	c.before = float(plane.speed)
	c.v = path*c.before
	c.heading = float(plane.heading)+float(plane.slip)
	c.pitch = float(plane.pitch)
	c.into = into
	c.vn = into*c.before
	c.push = push
	c.normal = t.normal
	return c

## A step of the catch on a balloon whose envelope is at `centre` (`s`, `r`,
## `low` as `touch`'s): the plane moved and turned. {} while the cloth holds
## it; thrown out, {into, before, after, out, push, clear} as `push_off`'s.
static func hold(c: Catch, plane: RefCounted, centre: Vector3, s: float, r: float, low: Vector2, delta: float, ground: Callable) -> Dictionary:
	var w := PI*0.5/SINK_TIME
	var steps := maxi(1,ceili(delta*120.0))
	var h := delta/float(steps)
	var inside := true
	c.shove = Vector3.ZERO
	for i in steps:
		var t := touch(centre,s,r,low,c.p)
		if t.is_empty():
			inside = false
			break
		var n: Vector3 = t.normal
		var at: Vector3 = t.centre
		var reach: float = t.radius
		c.normal = n
		c.push = push_way(plane,n)
		var a := c.push*(w*w*float(t.depth)*(1.0 if c.v.dot(n) < 0.0 else SPRING_OUT))
		c.v += a*h
		c.shove += a*h
		c.p += c.v*h
		# Never deeper than DEEP of the ball.
		var off := c.p-at
		var d := reach-off.length()
		if d > reach*DEEP:
			c.p = at+off.normalized()*(reach*(1.0-DEEP))
			d = reach*DEEP
			var vin := c.v.dot(n)
			if vin < 0.0: c.v -= n*vin
		c.depth = maxf(d,0.0)
		c.deepest = maxf(c.deepest,c.depth)
	c.t += delta
	plane.position = c.p
	if inside and c.t > CATCH_MOST:
		# Held too long (pressed in under the balloon): off it the old way.
		var last := touch(centre,s,r,low,c.p)
		if not last.is_empty():
			var res := push_off(plane,last,ground)
			if not res.is_empty(): return res
		inside = false
	if not inside:
		c.depth = 0.0
		var way := way_out(plane,c.v.normalized() if c.v.length_squared() > 0.01 else c.push,ground)
		var out: Vector3 = way[0]
		plane.speed = clampf(c.v.length(),SkySide.SLOW,maxf(c.before*OUT_MOST,SkySide.SLOW))
		_fly_along(plane,out,Vector3.ZERO)
		return {"into":c.into,"before":c.before,"after":float(plane.speed),"out":out,"push":c.push,"clear":float(way[1])}
	# Held: the nose on its way in, turned to its way out as it is thrown.
	var speed := c.v.length()
	var heading := c.heading
	var pitch := c.pitch
	var going := c.v.dot(c.normal)
	if going > 0.0 and speed > 0.5:
		var u := smoothstep(0.0,1.0,clampf(going/maxf(c.vn,0.5),0.0,1.0))
		var d := c.v/speed
		if Vector2(d.x,d.z).length() > 0.05: heading = lerp_angle(c.heading,atan2(-d.x,-d.z),u)
		pitch = lerpf(c.pitch,asin(clampf(d.y,-1.0,1.0)),u)
	pitch = clampf(pitch,SkySide.PITCH_LIMIT.x,SkySide.PITCH_LIMIT.y)
	var nose := Vector3(-sin(heading)*cos(pitch),sin(pitch),-cos(heading)*cos(pitch))
	plane.speed = maxf(SkySide.SLOW,speed)
	# The plane's own step flies it along its nose at its speed: the shove
	# makes that the cloth's own motion.
	_fly_along(plane,nose,c.v-nose*float(plane.speed))
	return {}
