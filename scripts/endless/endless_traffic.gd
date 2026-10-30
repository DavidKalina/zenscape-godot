extends "res://scripts/sky_traffic.gd"
## Other planes in the endless sky (studies/endless_flight.gd;
## docs/design/endless-flight/traffic-handoff.md): the isles' AI biplanes
## (scripts/sky_traffic.gd: its liveries, its steering, banking, wander and
## tricks) flown over the endless land round the player instead of round
## islands, each laying a thin white smoke trail.
##
## Each plane comes in from the haze on a plan (`_spawn`): a "cross" comes
## in from the side, out of the view, aimed to cross the player's line a
## readable distance ahead of him; a "pass" comes head on from far ahead and
## goes by alongside; a "cruise" just flies across the land somewhere out
## there. Once its plan is flown it cruises on, from one valley to the next
## (`_choose`: the lowest of a few points ahead). Far from the eye, or
## behind it for long, it is put back into the haze on a new plan
## (`_recycle`). It reads the field's height (land_field.gd, not physics)
## far ahead and climbs early to keep clear of the ground (`_floor`), and
## steers off the player and never comes within SAFE m of him. Visual
## only: no collision.
##
## The trail (`Trail`): one camera-facing ribbon per plane, rebuilt each
## frame from a ring of samples laid off its tail, widening and fading over
## TRAIL_LIFE s; one shared unshaded material, its colour the mood's sun and
## sky light (EndlessLook `sun`, `environment`), fogged like everything
## else. Hard turns pull vapour off the wingtips (the figure's own vapour,
## PlaneFigure `_trail_vapour`).
##
## A plane challenged to a race (scripts/endless/rival_race.gd) carries a
## `rival` (scripts/endless/rival_line.gd) that flies it in place of `_fly`;
## it keeps off the player by its own, nearer, SAFE (none on the ground),
## lays no smoke on the ground and is not recycled.
##
## A "door" plan (`door_run`, scripts/endless/region_doors.gd) comes in
## between the player and a door's wall of cloud and flies into it, put
## away once inside: no tricks on the way, not recycled for distance.
##
## Flags: --traffic=0 off, --traffic=N planes (DEFAULT_COUNT), --trails=0
## no trails.

const Field = preload("res://scripts/endless/land_field.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const DEFAULT_COUNT := 3
const MAX_COUNT := 8
## Cruise speed (m/s), lowest and highest: about the player's (SkyPlane
## CRUISE_SPEED x GAME_SPEED, 16).
const ENDLESS_SPEED := Vector2(15.0,20.0)
## How far from the eye a plane comes in (m): in the haze.
const SPAWN := Vector2(1000.0,1300.0)
## A cross: how far to the side it comes in (m), and how far ahead of the
## player (m) it crosses his line.
const CROSS_SIDE := Vector2(550.0,700.0)
const CROSS_AHEAD := Vector2(110.0,260.0)
## A pass: how far off his line it goes by (m).
const PASS_SIDE := Vector2(95.0,170.0)
## Height over the player (m) a cross or pass flies at; a cruise's height
## over the ground (m).
const OVER_PLAYER := Vector2(-15.0,35.0)
const OVER_GROUND := Vector2(40.0,130.0)
## Plans and how often each is drawn.
const PLANS := [["cross",0.5],["pass",0.2],["cruise",0.3]]
## A plan is re-aimed at the player's line while it is further than this
## (m) from him, then held.
const REAIM := 380.0
## Recycled: further than this from the eye (m), or behind the view and
## going away, further than BEHIND (m) or this long (s).
const RECYCLE := 1700.0
const BEHIND := 650.0
const BEHIND_TIME := 25.0
## Seconds hidden before (re)spawning, lowest and highest.
const WAIT := Vector2(3.0,14.0)
## Never nearer the player than SAFE m; within KEEP m it steers off when
## its line would pass within MISS m of him in the next LOOK_AHEAD s.
const SAFE := 55.0
const KEEP := 400.0
const MISS := 110.0
const LOOK_AHEAD := 12.0
## The ground read ahead (m), the height kept over it (m), and how much
## less is asked per metre further out (so it climbs early, not late).
const READ := [0.0,30.0,70.0,120.0,180.0,250.0,340.0,450.0]
const KEEP_CLEAR := 30.0
const CLIMB_SLOPE := 0.2
const FLOOR_EVERY := 0.15
## A cruise's next point: this far ahead (m), within this much of its
## heading (radians), the lowest ground of CANDIDATES points.
const LEG := Vector2(500.0,900.0)
const LEG_SPREAD := 0.9
const CANDIDATES := 5
## The trail: seconds a sample lives, seconds between samples, width at
## the tail and at the end (m, at plane scale 1), and its strongest alpha.
const TRAIL_LIFE := 10.0
const TRAIL_EVERY := 0.2
const TRAIL_WIDTH := Vector2(0.5,4.5)
const TRAIL_ALPHA := 0.9
## Near the eye it fades out (m: gone at the first, whole from the
## second), so a trail flown through (a rival's, followed close) is never
## a wall across the view.
const TRAIL_NEAR := Vector2(12.0,70.0)
## Further than this from the eye (m) a plane is only posed (`FarPose`):
## no vapour, propeller or control surfaces worked.
const DETAIL := 260.0
## Its shadow is cast only nearer the eye than this (m): each plane is a
## dozen draws, and every shadow split draws them again.
const SHADOW_NEAR := 140.0
## Wingtip vapour from this bank on, full at the second.
const PULL_BANK := Vector2(0.55,0.9)

var field: RefCounted
var look: Node3D
var count := DEFAULT_COUNT
var trails_on := true
## What the planes cost on the CPU last frame (ms) and how many are up.
var stats := {"ms":0.0,"up":0,"spawned":0,"recycled":0}
var _trail_material: ShaderMaterial
var _player := Vector3.ZERO
var _player_fwd := Vector3.FORWARD
var _player_speed := 0.0
var _eye := Vector3.ZERO
var _view := Vector3.FORWARD
var _pull := 0.0
## The door the last door plan flies into (`door_run`).
var _door := {}
## A door plan is recycled only further than this from the eye (m).
const DOOR_RECYCLE := 7000.0
## How far from the door a door plan comes in (m; a share of the player's
## distance from it, held to this range) and how far off to the side.
const DOOR_LEAD := Vector2(500.0,1100.0)
const DOOR_SIDE := Vector2(180.0,380.0)

## How many planes the flags ask for (0: off).
static func wanted() -> int:
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--traffic="): return clampi(int(arg.get_slice("=",1)),0,MAX_COUNT)
	# The world's traffic layer (planes; -1 the engine's DEFAULT_COUNT).
	var n := int(preload("res://scripts/endless/world/world_profile.gd").current().layer("traffic",-1))
	return DEFAULT_COUNT if n < 0 else clampi(n,0,MAX_COUNT)

func setup(seed: int, land_field: RefCounted, mood: Node3D, planes_wanted := DEFAULT_COUNT) -> void:
	name = "Traffic"
	field = land_field
	look = mood
	count = planes_wanted
	trails_on = not "--trails=0" in LaunchArgs.user_args()
	ground = func(p: Vector3) -> Variant: return maxf(float(field.height(p.x,p.z)),Field.SEA_Y)
	cloud_depth = func(_p: Vector3) -> float: return _pull
	_trail_material = ShaderMaterial.new()
	_trail_material.shader = _trail_shader()
	clear()
	for n in range(count):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed*7919+n*131+17
		var figure := PlaneFigure.new(LIVERIES[n%LIVERIES.size()])
		figure.name = "Traffic%d" % n
		figure.visible = false
		add_child(figure)
		var plane := {"figure":figure,"body":figure,"casters":_casters(figure,[]),"far":FarPose.new(),"flight":Flight.new(),"rng":rng,
			"cruise":rng.randf_range(ENDLESS_SPEED.x,ENDLESS_SPEED.y),"turn":0.0,"trick":{},
			"next":rng.randf_range(TRICK_EVERY.x,TRICK_EVERY.y),"phase":rng.randf()*TAU,
			"goal":{"kind":"wait"},"up":false,"wait":rng.randf_range(0.5,1.0)+float(n)*rng.randf_range(WAIT.x,WAIT.y)*0.5,
			"behind":0.0,"near":INF,"plan":"","life":0.0,"trail":null}
		if trails_on:
			var trail := Trail.new()
			trail.name = "Trail%d" % n
			trail.material_override = _trail_material
			trail._scale = _size
			add_child(trail)
			plane.trail = trail
		planes.append(plane)
	_shown = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for plane: Dictionary in planes:
			if is_instance_valid(plane.far): plane.far.free()

## The base's own clock only runs round islands; the host steps this one.
func _process(_delta: float) -> void:
	pass

## One frame: the player (his plane, or the eye on foot), where the eye is
## and looks; the planes spawned, flown, kept off him and recycled, the
## trails laid.
func step(delta: float, eye: Vector3, view: Vector3, player: Vector3, player_fwd: Vector3, player_speed: float) -> void:
	if planes.is_empty() or delta <= 0.0: return
	var t0 := Time.get_ticks_usec()
	_eye = eye
	_view = Vector3(view.x,0.0,view.z).normalized() if Vector2(view.x,view.z).length() > 0.01 else Vector3.FORWARD
	_player = player
	var flat := Vector3(player_fwd.x,0.0,player_fwd.z)
	_player_fwd = flat.normalized() if flat.length() > 0.01 else _view
	_player_speed = player_speed
	_clock += delta
	var up := 0
	for plane: Dictionary in planes:
		if not plane.up:
			plane.wait = float(plane.wait)-delta
			if float(plane.wait) <= 0.0: _spawn(plane)
			else:
				if plane.trail != null: plane.trail.fade(delta,eye)
				continue
		up += 1
		var flight: Flight = plane.flight
		_pull = smoothstep(PULL_BANK.x,PULL_BANK.y,absf(flight.bank)) if plane.trick.is_empty() else 0.0
		plane.life = float(plane.life)+delta
		_reaim(plane)
		_detail(plane)
		# A challenged rival flies its own line (scripts/endless/rival_line.gd).
		var rival: RefCounted = plane.get("rival")
		if rival != null: rival.fly(self,delta)
		else: _fly(plane,delta)
		if plane.figure != plane.body: plane.body.transform = plane.far.transform
		# A door plan inside its wall: gone.
		if plane.plan == "door" and _in_door(plane):
			if plane.trail != null: plane.trail.lay(delta,_tail(plane),eye,true)
			_put_away(plane)
			continue
		_keep_off(plane)
		if plane.trail != null:
			# A rival on the ground lays no smoke; off again, a fresh trail.
			if rival != null and not rival.smoking():
				plane.trail.fade(delta,eye)
				plane.smoke_off = true
			else:
				if plane.get("smoke_off",false):
					plane.trail.restart()
					plane.smoke_off = false
				plane.trail.lay(delta,_tail(plane),eye,true)
		if rival == null and _recycle(plane,delta): _put_away(plane)
	if _trail_material != null: _trail_material.set_shader_parameter("tint",_light())
	stats.up = up
	stats.ms = float(Time.get_ticks_usec()-t0)/1000.0

## A line for the numbers (F1).
func note() -> String:
	return "\ntraffic: %d up of %d, %.2f ms, %d spawned, %d recycled%s" % [int(stats.up),planes.size(),float(stats.ms),int(stats.spawned),int(stats.recycled),"" if trails_on else ", no trails"]

# --- Plans --------------------------------------------------------------------------

## For drivers and stills: plane `n` put back in the haze now on `plan`
## ("cross", "pass" or "cruise").
func force(n: int, plan: String) -> void:
	if n < 0 or n >= planes.size(): return
	_spawn(planes[n],plan)

## A plane flown into a door (`door`: {xform, the wall's frame with z its
## through way; half, the core's half sizes in that frame; aim, the point
## flown at}): a plane not up (else the furthest up, not racing) comes in
## between the player and the door. True when one was sent.
func door_run(door: Dictionary) -> bool:
	var pick := {}
	var far := -1.0
	for plane: Dictionary in planes:
		if plane.get("rival") != null: continue
		if not plane.up:
			pick = plane
			break
		var d := (plane.flight as Flight).position.distance_to(_eye)
		if d > far:
			far = d
			pick = plane
	if pick.is_empty(): return false
	_door = door
	_spawn(pick,"door")
	return true

## Whether a door plan is inside its door's core.
func _in_door(plane: Dictionary) -> bool:
	var door: Dictionary = plane.goal.get("door",{})
	if door.is_empty(): return false
	var q: Vector3 = (door.xform as Transform3D).affine_inverse()*(plane.flight as Flight).position
	var half: Vector3 = door.half
	return absf(q.x) < half.x and q.y > 0.0 and q.y < half.y and absf(q.z) < half.z

## Plane `n` put at `at` on `heading` now, cruising on ahead
## (--race-near-start: a rival to challenge in view).
func place(n: int, at: Vector3, heading: float) -> void:
	if n < 0 or n >= planes.size(): return
	var plane: Dictionary = planes[n]
	_spawn(plane,"cruise")
	var flight: Flight = plane.flight
	flight.position = at
	flight.heading = heading
	flight.velocity = flight.forward()*flight.speed
	plane.goal = _leg(plane,at,heading)
	plane.body.update(0.0,flight,0.0,Callable(),false)
	PlaneGroundScale.grow(plane.body,_size)
	plane.body.reset(flight)
	if plane.trail != null: plane.trail.restart()

func _spawn(plane: Dictionary, plan := "") -> void:
	var rng: RandomNumberGenerator = plane.rng
	var flight: Flight = plane.flight
	var kind := plan if plan != "" else _pick(PLANS,rng)
	var side := _player_fwd.cross(Vector3.UP).normalized()
	var hand := -1.0 if rng.randf() < 0.5 else 1.0
	var at := Vector3.ZERO
	var goal := {}
	var cruise := float(plane.cruise)
	if kind == "cross":
		var off := rng.randf_range(CROSS_SIDE.x,CROSS_SIDE.y)
		var ahead := rng.randf_range(CROSS_AHEAD.x,CROSS_AHEAD.y)
		# Where it crosses: ahead of where he'll be by the time it gets
		# there; it comes in from the side, near square across his line, so
		# it sweeps across the view.
		var lead := _player_speed*off/cruise
		var cross := _player+_player_fwd*(ahead+lead)
		at = cross+side*off*hand+_player_fwd*rng.randf_range(-0.1,0.15)*off
		goal = {"kind":"cross","ahead":ahead,"hand":hand,"lift":rng.randf_range(OVER_PLAYER.x,OVER_PLAYER.y)}
		goal.point = cross+Vector3.UP*float(goal.lift)
		at.y = _player.y+float(goal.lift)
	elif kind == "pass":
		var off := rng.randf_range(PASS_SIDE.x,PASS_SIDE.y)
		at = _player+_player_fwd*rng.randf_range(SPAWN.x,SPAWN.y)+side*off*hand
		goal = {"kind":"pass","off":off,"hand":hand,"lift":rng.randf_range(OVER_PLAYER.x,OVER_PLAYER.y)}
		goal.point = _player-_player_fwd*400.0+side*off*hand+Vector3.UP*float(goal.lift)
		at.y = _player.y+float(goal.lift)
	elif kind == "door" and not _door.is_empty():
		# In between the player and the door, off to one side, flying in.
		var xf: Transform3D = _door.xform
		var aim: Vector3 = _door.aim
		var back := -Vector3(xf.basis.z.x,0.0,xf.basis.z.z).normalized()
		var to_player := _player-aim
		to_player.y = 0.0
		if to_player.dot(back) < 0.0: back = -back
		var lead := clampf(to_player.length()*0.55,DOOR_LEAD.x,DOOR_LEAD.y)
		var across := back.cross(Vector3.UP).normalized()
		at = aim+back*lead+across*hand*rng.randf_range(DOOR_SIDE.x,DOOR_SIDE.y)
		at.y = maxf(aim.y,float(ground.call(at))+OVER_GROUND.x)
		goal = {"kind":"door","point":aim,"door":_door}
	else:
		if kind == "door": kind = "cruise"
		# Somewhere out in the haze, off the view, flying across it.
		var a := atan2(_view.x,_view.z)+hand*rng.randf_range(0.6,2.4)
		at = _eye+Vector3(sin(a),0.0,cos(a))*rng.randf_range(SPAWN.x,SPAWN.y)
		at.y = float(ground.call(at))+rng.randf_range(OVER_GROUND.x,OVER_GROUND.y)
		var across := (_eye+_view*rng.randf_range(200.0,700.0)-at)
		across.y = 0.0
		goal = _leg(plane,at,atan2(-across.x,-across.z))
	at.y = maxf(at.y,float(ground.call(at))+KEEP_CLEAR)
	flight.position = at
	var to: Vector3 = goal.point-at
	flight.heading = atan2(-to.x,-to.z)
	flight.pitch = 0.0
	flight.bank = 0.0
	flight.spin = 0.0
	flight.speed = cruise
	flight.velocity = flight.forward()*flight.speed
	plane.goal = goal
	plane.trick = {}
	plane.turn = 0.0
	plane.floor_at = -1.0
	plane.behind = 0.0
	plane.near = INF
	plane.plan = kind
	# A door plan flies straight in; the others get their tricks back.
	if kind == "door": plane.next = 1e6
	elif float(plane.next) > 1e5: plane.next = rng.randf_range(TRICK_EVERY.x,TRICK_EVERY.y)
	plane.life = 0.0
	plane.up = true
	plane.figure = plane.body
	plane.body.visible = true
	plane.body.update(0.0,flight,0.0,Callable(),false)
	PlaneGroundScale.grow(plane.body,_size)
	plane.body.reset(flight)
	if plane.trail != null: plane.trail.restart()
	stats.spawned = int(stats.spawned)+1

## The base's step of a plane (scripts/sky_traffic.gd `_fly`), but kept
## out of the ground by the ground under it, not by `_floor`'s ramp.
func _fly(plane: Dictionary, delta: float) -> void:
	var flight: Flight = plane.flight
	if _done(plane): plane.goal = _choose(plane)
	var aim := _aim(plane)
	var t := _clock*TAU+float(plane.phase)
	var floor_y := _floor(plane)
	var want_y := maxf(aim.y+sin(t*WANDER_RATE.y+1.3)*WANDER_HEIGHT,floor_y)
	var trick: Dictionary = plane.trick
	var pace := float(plane.cruise)
	if trick.is_empty():
		plane.next = float(plane.next)-delta
		if float(plane.next) <= 0.0 and flight.position.y-floor_y+CLEAR > TRICK_CLEAR:
			plane.trick = _trick(plane)
			trick = plane.trick
	if not trick.is_empty():
		trick.t = float(trick.t)+delta
	var looping: bool = not trick.is_empty() and trick.kind == "loop"
	if not trick.is_empty() and trick.kind == "swoop":
		var s := clampf(float(trick.t)/SWOOP_TIME,0.0,1.0)
		var dip := sin(s*PI)
		want_y = maxf(want_y-SWOOP_DROP*dip,floor_y)
		pace += SWOOP_SPEED*dip
	if not looping:
		# The heading turns toward the aim, wandering, at a limited rate.
		var to := aim-flight.position
		var wander := sin(t*WANDER_RATE.x)*WANDER_TURN+sin(t*WANDER_RATE.x*2.7+0.8)*WANDER_TURN*0.4
		var want := atan2(-to.x,-to.z)+wander
		var rate := clampf(angle_difference(flight.heading,want)*TURN_GAIN,-TURN_MAX,TURN_MAX)
		plane.turn = lerpf(float(plane.turn),rate,_ease(EASE_TURN,delta))
		flight.heading = wrapf(flight.heading+float(plane.turn)*delta,-PI,PI)
		flight.bank = clampf(-float(plane.turn)*BANK,-BANK_MAX,BANK_MAX)
		var pitch := clampf((want_y-flight.position.y)/PITCH_PER,-PITCH_MAX,PITCH_MAX)
		flight.pitch = lerpf(flight.pitch,pitch,_ease(EASE_PITCH,delta))
	else:
		# Round the loop: the nose comes up and over, the wings level.
		var s := clampf(float(trick.t)/LOOP_TIME,0.0,1.0)
		flight.pitch = float(trick.from)+TAU*_smooth(s)
		flight.bank = lerpf(flight.bank,0.0,_ease(0.2,delta))
		plane.turn = 0.0
	if not trick.is_empty() and trick.kind == "roll":
		flight.spin = TAU*_smooth(clampf(float(trick.t)/ROLL_TIME,0.0,1.0))
	if not trick.is_empty() and float(trick.t) >= float(trick.length):
		if trick.kind == "loop": flight.pitch = wrapf(flight.pitch,-PI,PI)
		flight.spin = 0.0
		plane.trick = {}
		plane.next = plane.rng.randf_range(TRICK_EVERY.x,TRICK_EVERY.y)
	flight.speed = lerpf(flight.speed,pace,_ease(EASE_SPEED,delta))
	flight.velocity = flight.forward()*flight.speed
	flight.position += flight.velocity*delta
	# Never sunk into the ground it is over (the ground right under it, not
	# the ramp ahead `_floor` asks it to climb toward, so it never pops up).
	flight.position.y = maxf(flight.position.y,float(ground.call(flight.position))+CLEAR*0.5)
	var mist := float(cloud_depth.call(flight.position)) if cloud_depth.is_valid() else 0.0
	plane.figure.update(delta,flight,0.0,Callable(),false,mist,flight.bank)
	PlaneGroundScale.grow(plane.figure,_size)

## Near the eye the figure is worked in full; far, only posed. Its
## shadow only close.
func _detail(plane: Dictionary) -> void:
	var gap := (plane.flight as Flight).position.distance_to(_eye)
	var shade := gap < SHADOW_NEAR
	if shade != bool(plane.get("shade",true)):
		plane.shade = shade
		_cast(plane.casters,shade)
	var near := gap < DETAIL
	if near and plane.figure != plane.body:
		plane.figure = plane.body
		plane.body.reset(plane.flight)
	elif not near and plane.figure == plane.body:
		plane.figure = plane.far

## Its parts that cast a shadow as built, on or off.
static func _cast(casters: Array, on: bool) -> void:
	for part: GeometryInstance3D in casters:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _casters(node: Node, into: Array) -> Array:
	if node is GeometryInstance3D and (node as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: into.append(node)
	for child in node.get_children(): _casters(child,into)
	return into

## A cross or pass keeps its aim on the player's line while it is far.
func _reaim(plane: Dictionary) -> void:
	var goal: Dictionary = plane.goal
	if not goal.kind in ["cross","pass"] or goal.get("held",false): return
	var flight: Flight = plane.flight
	var gap := flight.position.distance_to(_player)
	if gap < REAIM:
		goal.held = true
		return
	var side := _player_fwd.cross(Vector3.UP).normalized()
	if goal.kind == "cross":
		# Where it meets his line: ahead of where he'll be by then.
		var t := 0.0
		var point := _player
		for i in range(3):
			point = _player+_player_fwd*(float(goal.ahead)+_player_speed*t)+Vector3.UP*float(goal.lift)
			t = minf(point.distance_to(flight.position)/maxf(flight.speed,1.0),60.0)
		goal.point = point
	else:
		goal.point = _player-_player_fwd*400.0+side*float(goal.off)*float(goal.hand)+Vector3.UP*float(goal.lift)

## Done when its point is reached or passed (the base's rule); a door
## plan never (it is put away inside the wall).
func _done(plane: Dictionary) -> bool:
	var goal: Dictionary = plane.goal
	if goal.kind == "door": return false
	if goal.kind == "cross" and goal.get("held",false):
		# Over his line: on across and away.
		var flight: Flight = plane.flight
		var gap: Vector3 = goal.point-flight.position
		if gap.dot(flight.forward()) < 0.0: return true
	return super(plane)

## After a plan: cruise on to the lowest of a few points ahead (valleys).
func _choose(plane: Dictionary) -> Dictionary:
	var flight: Flight = plane.flight
	return _leg(plane,flight.position,flight.heading)

func _leg(plane: Dictionary, from: Vector3, heading: float) -> Dictionary:
	var rng: RandomNumberGenerator = plane.rng
	var best := Vector3.ZERO
	var low := INF
	for i in range(CANDIDATES):
		var a := heading+rng.randf_range(-LEG_SPREAD,LEG_SPREAD)
		var p := from+Vector3(-sin(a),0.0,-cos(a))*rng.randf_range(LEG.x,LEG.y)
		var h := float(ground.call(p))
		if h < low:
			low = h
			best = p
	best.y = low+rng.randf_range(OVER_GROUND.x,OVER_GROUND.y)
	return {"kind":"cruise","point":best}

## Steers off the player when its line would bring it within MISS m of
## him in the next LOOK_AHEAD s (up or down and aside), on top of the
## plan's aim.
func _aim(plane: Dictionary) -> Vector3:
	var aim: Vector3 = plane.goal.point
	var flight: Flight = plane.flight
	var off := flight.position-_player
	if off.length() > KEEP: return aim
	var rel := flight.velocity-_player_fwd*_player_speed
	var closest := off
	if rel.length_squared() > 0.01:
		var t := clampf(-off.dot(rel)/rel.length_squared(),0.0,LOOK_AHEAD)
		closest = off+rel*t
	var miss := closest.length()
	if miss >= MISS: return aim
	var away := closest/maxf(miss,0.01) if miss > 0.5 else Vector3.UP
	if absf(away.y) < 0.4: away.y = 0.4 if flight.position.y >= _player.y else -0.4
	return aim+away.normalized()*(MISS-miss)*4.0

## The lowest it may fly: KEEP_CLEAR over the ground ahead, asking less
## the further out, so it starts up a ridge early.
func _floor(plane: Dictionary) -> float:
	# Read every FLOOR_EVERY s, not every frame (the ramp covers the gap).
	if _clock-float(plane.get("floor_at",-1.0)) < FLOOR_EVERY: return float(plane.floor)
	plane.floor_at = _clock
	plane.floor = _read_floor(plane)
	return float(plane.floor)

func _read_floor(plane: Dictionary) -> float:
	var flight: Flight = plane.flight
	var ahead := Vector3(-sin(flight.heading),0.0,-cos(flight.heading))
	var lowest := -INF
	for d: float in READ:
		var p := flight.position+ahead*d
		lowest = maxf(lowest,float(ground.call(p))+KEEP_CLEAR-d*CLIMB_SLOPE)
	return lowest

## Never within SAFE m of the player: pushed out where it would be.
func _keep_off(plane: Dictionary) -> void:
	var flight: Flight = plane.flight
	var off := flight.position-_player
	var d := off.length()
	plane.near = minf(float(plane.near),d)
	# A rival races close: its own, nearer, keep-off (none on the ground,
	# nor on the way down or up again).
	var rival: RefCounted = plane.get("rival")
	var safe := SAFE if rival == null else float(rival.keep_r())
	if d >= safe: return
	var away := off.normalized() if d > 0.01 else Vector3.UP
	flight.position = _player+away*safe
	var under: float = float(ground.call(flight.position))+(KEEP_CLEAR*0.5 if rival == null else float(rival.LOW_LEAST)*0.5)
	if flight.position.y < under: flight.position.y = under
	plane.body.update(0.0,flight,0.0,Callable(),false,_pull,flight.bank)
	PlaneGroundScale.grow(plane.body,_size)

func _recycle(plane: Dictionary, delta: float) -> bool:
	var flight: Flight = plane.flight
	var off := flight.position-_eye
	var d := Vector2(off.x,off.z).length()
	if plane.plan == "door": return d > DOOR_RECYCLE
	if d > RECYCLE: return true
	# Behind the view and going away (one still closing in may yet cross).
	var behind := Vector3(off.x,0.0,off.z).dot(_view) < -0.3*d and flight.velocity.dot(off) > 0.0
	plane.behind = float(plane.behind)+delta if behind else 0.0
	return behind and (d > BEHIND or float(plane.behind) > BEHIND_TIME)

func _put_away(plane: Dictionary) -> void:
	plane.up = false
	plane.body.visible = false
	plane.wait = plane.rng.randf_range(WAIT.x,WAIT.y)
	stats.recycled = int(stats.recycled)+1

## Where the smoke leaves it: under the tail.
func _tail(plane: Dictionary) -> Vector3:
	var flight: Flight = plane.flight
	return flight.position-flight.forward()*2.6*_size

## The trail's colour now: the sun's light and the sky's, as the mood has
## them, or plain white.
func _light() -> Color:
	if look == null or not is_instance_valid(look): return Color(0.95,0.95,0.95)
	var sun: DirectionalLight3D = look.get("sun")
	var env: Environment = look.get("environment")
	var c := Color(0.0,0.0,0.0)
	if sun != null and sun.visible: c += sun.light_color*minf(sun.light_energy,2.5)*0.55
	if env != null: c += env.ambient_light_color*minf(env.ambient_light_energy,2.0)*0.55
	# Smoke is white: the light's colour only tints it.
	var bright := clampf(maxf(c.r,maxf(c.g,c.b)),0.25,1.05)
	c = Color(bright,bright,bright).lerp(c,0.45)
	return Color(clampf(c.r,0.2,1.05),clampf(c.g,0.2,1.05),clampf(c.b,0.2,1.05))

static func _trail_shader() -> Shader:
	var s := Shader.new()
	s.code = """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint = vec3(0.95);
void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float soft = 1.0 - across * across;
	// A little break-up along it, so it reads as smoke, not tape.
	float puff = 0.9 + 0.1 * sin(UV.y * 4.0 + across * 2.0);
	ALBEDO = tint * COLOR.rgb;
	ALPHA = COLOR.a * soft * puff;
}
"""
	return s

## A far plane's stand-in for its figure in the base's `_fly` (never in
## the tree): it is only posed (PlaneFigure `pose`) and grown, and the
## figure takes its transform after (`step`).
class FarPose extends Node3D:
	func update(_delta: float, glide: RefCounted, _dive: float, _ground: Callable, _landable: bool, _near := 0.0, _lean := 0.0) -> void:
		transform = PlaneFigure.pose(glide.position,float(glide.heading),float(glide.pitch),float(glide.bank)+float(glide.spin))

## One plane's smoke: a ring of samples laid off the tail, drawn as one
## camera-facing ribbon that widens and fades with age.
class Trail extends MeshInstance3D:
	var _mesh := ImmediateMesh.new()
	var _points := PackedVector3Array()
	var _ages := PackedFloat32Array()
	var _since := 0.0
	var _scale := 1.0

	func _init() -> void:
		mesh = _mesh
		top_level = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func restart() -> void:
		_points.clear()
		_ages.clear()
		_since = 0.0
		_mesh.clear_surfaces()
		visible = true

	## The plane gone: what's laid ages out.
	func fade(delta: float, eye: Vector3) -> void:
		if _points.is_empty(): return
		_age(delta)
		_draw(eye,Vector3.INF)

	func lay(delta: float, head: Vector3, eye: Vector3, _flying: bool) -> void:
		_age(delta)
		_since += delta
		if _points.is_empty() or _since >= TRAIL_EVERY:
			_since = 0.0
			_points.insert(0,head)
			_ages.insert(0,0.0)
		_draw(eye,head)

	func _age(delta: float) -> void:
		for i in range(_ages.size()): _ages[i] += delta
		while not _ages.is_empty() and _ages[_ages.size()-1] > TRAIL_LIFE:
			_ages.remove_at(_ages.size()-1)
			_points.remove_at(_points.size()-1)
		# The smoke drifts up and spreads a little as it ages.
		for i in range(_points.size()): _points[i] += Vector3.UP*0.25*delta

	func _draw(eye: Vector3, head: Vector3) -> void:
		_mesh.clear_surfaces()
		var pts := PackedVector3Array()
		var ages := PackedFloat32Array()
		if head != Vector3.INF:
			pts.append(head)
			ages.append(0.0)
		pts.append_array(_points)
		ages.append_array(_ages)
		if pts.size() < 2:
			visible = false
			return
		visible = true
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n := pts.size()
		for i in range(n):
			var p := pts[i]
			var along := pts[maxi(i-1,0)]-pts[mini(i+1,n-1)]
			var across := along.cross(eye-p)
			if across.length_squared() < 0.000001: across = Vector3.UP
			var age := clampf(ages[i]/TRAIL_LIFE,0.0,1.0)
			var w := lerpf(TRAIL_WIDTH.x,TRAIL_WIDTH.y,sqrt(age))*_scale*0.5
			# Far off, it never thins under about a pixel and a half.
			w = maxf(w,eye.distance_to(p)*0.0017)
			var a := TRAIL_ALPHA*pow(1.0-age,1.2)*smoothstep(0.0,0.03,age+0.005)*smoothstep(TRAIL_NEAR.x,TRAIL_NEAR.y,eye.distance_to(p))
			var c := Color(1.0,1.0,1.0,a)
			var side := across.normalized()*w
			_mesh.surface_set_color(c)
			_mesh.surface_set_uv(Vector2(0.0,ages[i]))
			_mesh.surface_add_vertex(p-side)
			_mesh.surface_set_color(c)
			_mesh.surface_set_uv(Vector2(1.0,ages[i]))
			_mesh.surface_add_vertex(p+side)
		_mesh.surface_end()
