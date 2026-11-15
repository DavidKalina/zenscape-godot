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
	# The push's way: under the balloon, turned sideways.
	var push := n
	if push.y < NORMAL_DOWN:
		var level := Vector3(push.x,0.0,push.z)
		if level.length_squared() < 0.0001: level = -Vector3(-sin(float(plane.heading)),0.0,-cos(float(plane.heading)))
		level = level.normalized()*sqrt(1.0-NORMAL_DOWN*NORMAL_DOWN)
		push = Vector3(level.x,NORMAL_DOWN,level.z)
	plane.position = c+n*(reach+0.05)
	var path: Vector3 = plane.path_now()
	var into := path.dot(push)
	if into >= -0.02: return {}
	var before := float(plane.speed)
	var out := (path-push*into*(1.0+RESTITUTION)).normalized()
	# The least of the clearance under it and under its way out.
	var p: Vector3 = plane.position
	var clear := p.y-float(ground.call(p))
	var flat := Vector3(out.x,0.0,out.z)
	if flat.length_squared() > 0.0001:
		flat = flat.normalized()
		for a: float in AHEAD: clear = minf(clear,p.y-float(ground.call(p+flat*a)))
	# Low over the ground: level or rising under LOW_CLEAR, the dive let in
	# over as much again.
	var least := lerpf(LOW_RISE,0.0,clampf(clear/LOW_CLEAR,0.0,1.0))
	if clear > LOW_CLEAR: least = lerpf(0.0,DIVE_MOST,clampf((clear-LOW_CLEAR)/LOW_CLEAR,0.0,1.0))
	if out.y < least:
		var h := Vector2(out.x,out.z)
		h = (h.normalized() if h.length_squared() > 0.0001 else Vector2(-sin(float(plane.heading)),-cos(float(plane.heading))))*sqrt(1.0-least*least)
		out = Vector3(h.x,least,h.y)
	plane.speed = maxf(SkySide.SLOW,before*(1.0-LOSS*(-into)))
	var bump := push*(KICK*(-into))
	if clear < LOW_CLEAR: bump.y = maxf(bump.y,0.0)
	_fly_along(plane,out,bump)
	return {"into":-into,"before":before,"after":float(plane.speed),"out":out,"push":push,"clear":clear}

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
