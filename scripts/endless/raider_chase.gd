extends RefCounted
## The raider's chase (`--raider-mode=chase`, and the run in `mix`; spec docs/design/endless-flight/
## spec-raider-combat.md, item 2): the raider (scripts/endless/raider.gd) shows
## up ahead and flees, low and fast, and the player trails it.
##
## How it flies: by plane rules, as the raider's own `_fly_to` (the heading
## turned at a capped rate TURN, the wings banked with it, the pitch at a
## capped rate), LOW m over what stands ahead (the flight's own ground,
## `plane_ground`: the land, the crowns, rocks, arches' tops), never under
## FLOOR m over the land. Every PLAN_S s it picks a heading from a fan
## (FAN steps of FAN_STEP rad either side), scored on the line ahead: trees
## along it (it likes the canopy), climbs over its height (it keeps to the
## valleys), the sea (it keeps to the land), the turn (it keeps its line
## smooth), running back at the plane (it doesn't), and a pull toward the
## land arches standing near (`arches.standing()`).
##
## Arches: one standing within ARCH_REACH m ahead whose widest opening fits
## the player's plane (wide and tall `WorldScale.opening(TOY_FIT)`; the
## rival's way of reading it, `_opening`), that it can turn onto (within
## ARCH_TURN of its heading, its way through not back at the plane) and whose
## approach and way out are clear, it takes: on to a point APPROACH m before
## the opening, through its middle at the opening's flying height, out EXIT m
## past it (`route`). The Peak's carved gates are left alone.
##
## The gap: it runs at PACE times the plane's Boost, so Boost flown high and
## straight loses it slowly and the cruise fast; past EASE_M.x m it eases
## off toward EASE_PACE times Boost by EASE_M.y, so it stays catchable.
## Behind the plane it runs ahead at the plane's speed + AHEAD_OVER.
##
## Skimming builds speed: while it's up, the plane's `skim_over` (SkyPlane,
## m/s over the throttle's speed) is `heat` x SKIM_GAIN (`--raider-skim=`).
## Heat follows how close the plane flies to the ground, the crowns or stone
## (NearMiss's clearances, within SKIM_BAND spans; rising over HEAT_UP s,
## falling over HEAT_DOWN s), and every moment NearMiss scores kicks it
## KICK. The meter fills by NearMiss's own scoring, and a hot surge roll that
## reaches it kills it (raider.gd `try_kill`, as in the dogfight).
##
## The buzz (`buzz`, how each one arrives; spec-raider-embers.md item 1): it
## shows up BUZZ_BACK m behind the plane, BUZZ_UP m over it (or BUZZ_SIDE m
## off one side and a little up) and overtakes at BUZZ_OVER m/s over the
## plane's speed along the plane's line (eased round with it), a whoosh as it
## passes, then BUZZ_DONE m ahead it runs (`run`), diving low.
##
## Lost while chased (raider.gd `chased`: locked on, or the lock lost to
## distance or sight; more than LOST_M m off, or behind the view, for LOST_S s), it comes
## back round (`round`): to a point BACK_M m ahead of the plane and off to
## the side, at the plane's speed + ROUND_OVER, then runs again.
##
## Tuning flags: --raider-skim=M/S (SKIM_GAIN), --raider-pace=X (PACE),
## --raider-low=M (LOW), --raider-dive=RAD (PITCH_DIVE).

const WorldScale = preload("res://scripts/world_scale.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")
const Build = preload("res://scripts/endless/arch_build.gd")
const SkyTraffic = preload("res://scripts/sky_traffic.gd")
const Field = preload("res://scripts/endless/land_field.gd")

## Its pace: times the plane's Boost speed; behind the plane, m/s over its speed.
const PACE := 1.12
## Past EASE_M.x m off it eases to EASE_PACE times Boost by EASE_M.y m.
const EASE_M := Vector2(350.0,650.0)
const EASE_PACE := 1.0
const AHEAD_OVER := 22.0
## Where it shows up: m ahead of the view, degrees off its axis; at most
## SPAWN_UP m over its low flying height (never over the plane's height).
const SPAWN_M := 200.0
const SPAWN_OFF := 8.0
const SPAWN_UP := 10.0
## Its turn (rad/s at most; a line the player can follow), the gain per rad
## off the aim, its pitch at most (rad: up, and down: a gentler dive, so a
## rise ahead never catches it nose down) and the pitch's rate (rad/s).
const TURN := 0.9
const TURN_GAIN := 1.8
const PITCH_MAX := 0.55
const PITCH_DOWN := 0.3
## High over where it means to fly (more than DIVE_M.x m, fully by DIVE_M.y:
## breaking off from a dogfight up high), it dives as steep as PITCH_DIVE, so
## "it runs low" reads in a few seconds, and eases back to PITCH_DOWN near it.
const PITCH_DIVE := 0.7
const DIVE_M := Vector2(30.0,80.0)
## On an arch's line (its height set), over it by DIVE_LINE m it dives as
## steep: the line comes down DESCENT, and PITCH_DOWN alone never catches it
## from above. An arch it can't come down to by the run-in at DESCENT_MOST a m
## (broken off up high) it doesn't take.
const DIVE_LINE := Vector2(2.0,12.0)
const DESCENT_MOST := 0.35
const PITCH_RATE := 1.2
## m over what stands ahead it flies; the least over the land (m); the
## samples ahead (m) and to each side (m) its height is read from, and the
## slope it climbs by to meet what stands ahead (rise per m on).
const LOW := 4.0
const FLOOR := 3.0
const AHEAD := [0.0,6.0,12.0,18.0,24.0,30.0,36.0,42.0,48.0,56.0,66.0,80.0,96.0,114.0,134.0,156.0,180.0]
const SIDE := 5.0
const CLIMB := 0.4
## The least it keeps over a crown it's over (m); how far up it reads the
## solids from (m), and the pad round them (m: past its half span).
const CROWN_CLEAR := 1.0
const PROBE := 250.0
const SOLID_PAD := 3.0
## The plan: every PLAN_S s; FAN headings each side FAN_STEP rad apart; the
## line read LOOK m ahead.
const PLAN_S := 0.35
const FAN := 5
const FAN_STEP := 0.17
const LOOK := [60.0,120.0,180.0,240.0,300.0]
## The plan's weights: a sample in trees; a m climbed past its height; a
## sample over the sea; a rad of turn; a rad off the last plan; running
## back at the plane (below FLEE_COS of straight away from it); toward an
## arch; home from past HOME_M m off the land's middle; toward the nearest
## land while it's over the sea (W_SEA_HOME); a rock or an arch
## in the way at its height (it goes round, not over).
const W_TREE := 0.35
const W_BLOCK := 2.0
const W_CLIMB := 0.02
const W_SEA := 0.35
const W_SEA_HOME := 4.0
## Out over the sea: rings looked over for land (m), and directions in each.
const SEA_LOOK := [150.0,300.0,600.0,1000.0,1600.0,2400.0]
const SEA_DIRS := 16
## Over the sea, running away from the plane counts this much (it would
## rather come back past you to the land than run out over open water).
const SEA_FLEE := 0.35
const W_TURN := 0.5
const W_KEEP := 0.6
const FLEE_COS := 0.55
const W_FLEE := 6.0
const W_ARCH := 0.9
const ARCH_SEEK := 1500.0
const HOME_M := 5500.0
const W_HOME := 1.0
## Arches: within ARCH_REACH m ahead, ARCH_TURN rad off its heading; its
## opening at least WorldScale.opening(TOY_FIT) wide and tall; the route's
## run-in and run-out (m).
const ARCH_REACH := 650.0
const ARCH_TURN := 0.95
const TOY_FIT := 3.5
const APPROACH := 110.0
const EXIT := 70.0
## The route's line: held at the opening's height from RUN_IN m before its
## middle to RUN_OUT past it, coming down to it DESCENT a m before that; the
## aim LEAD m on along it; on rails the last RAILS m in.
const RUN_IN := 40.0
const RUN_OUT := 25.0
const DESCENT := 0.3
const LEAD := 35.0
const RAILS := 50.0
## The opening's flying height, its share of the gap (the rival's GAP_SHARE).
const GAP_SHARE := 0.42
## The buzz: m behind it shows up, m over the plane (overhead) or off its side
## and over (beside), m/s over the plane's speed, how fast its line follows the
## plane's turns (1/s), m ahead where it starts to run.
const BUZZ_BACK := 110.0
const BUZZ_UP := 9.0
const BUZZ_SIDE := Vector2(14.0,3.0)
const BUZZ_OVER := 48.0
const BUZZ_FOLLOW := 1.5
const BUZZ_DONE := 70.0
## Lost: m off, s; back round to BACK_M m ahead of the plane, BACK_SIDE m
## off its line, at its speed + ROUND_OVER.
const LOST_M := 750.0
const LOST_S := 3.0
const BACK_M := 330.0
const BACK_SIDE := 110.0
const ROUND_OVER := 28.0
## Skimming: spans of clearance it counts within, the heat's ease up and
## down (s), a scored moment's kick, the speed at full heat (m/s).
const SKIM_BAND := 6.0
const HEAT_UP := 0.6
const HEAT_DOWN := 2.5
const KICK := 0.4
const SKIM_GAIN := 40.0

var raider: Node3D
## buzz (arriving), run (fleeing), round (coming back)
var phase := &"run"
## The plane's skim heat (0 to 1) and the speed it adds (m/s).
var heat := 0.0
var skim_over := 0.0
## The gap (m): its distance from the plane, - when it's behind the plane.
var gap := 0.0
## The arch it's taking: its name, route points, the next point's index.
var arch := ""
var route: Array[Vector3] = []
var leg := 0
var tuning := {}
## Counted, for the drivers: arch passes (and their names), seconds over
## trees (within 12 m of a crown), frames inside a solid, rounds.
var stats := {"arches":0,"arch_names":[],"tree_s":0.0,"clips":0,"clip_what":"","rounds":0,"plans":0,"lifts":0,"arch_near":0,"arch_fit":0,"arch_way":0,"arch_clear":0}

var _want := 0.0
var _plan_t := 0.0
var _lost := 0.0
var _seen := 0
var _openings := {}
var _want_y := NAN
var _slope := 0.0
## The buzz: m along the plane's line from it, the line (flat, unit), the
## offset across and up, whether its whoosh has played.
var _buzz_s := 0.0
var _buzz_line := Vector3.FORWARD
var _buzz_off := Vector2.ZERO
var _buzz_heard := false

func _init(r: Node3D) -> void:
	raider = r
	tuning = {"skim":r._flag("--raider-skim",SKIM_GAIN),"pace":maxf(r._flag("--raider-pace",PACE),0.3),
		"low":maxf(r._flag("--raider-low",LOW),FLOOR),
		"dive":clampf(r._flag("--raider-dive",PITCH_DIVE),PITCH_DOWN,1.2)}

## Shown: ahead of the view, low, facing on along the plane's line.
func spawn() -> void:
	var game: Node3D = raider.game
	var plane = game.plane
	var p: Vector3 = plane.position
	var cam: Camera3D = game.camera
	var look := -cam.global_basis.z
	var flat := Vector3(look.x,0.0,look.z)
	if flat.length() < 0.1: flat = Vector3(plane.forward().x,0.0,plane.forward().z)
	flat = flat.normalized()
	var side := 1.0 if raider._rng.randf() < 0.5 else -1.0
	var at := p+flat.rotated(Vector3.UP,deg_to_rad(SPAWN_OFF)*side)*SPAWN_M
	var low := _floor_y(at,flat,true)+float(tuning.low)
	at.y = maxf(minf(p.y,low+SPAWN_UP),low)
	var f: SkyTraffic.Flight = raider.flight
	f.position = at
	f.heading = atan2(-flat.x,-flat.z)
	f.pitch = 0.0
	f.bank = 0.0
	raider.speed = maxf(float(plane.speed),float(plane.boost_speed())*float(tuning.pace))
	f.speed = raider.speed
	f.velocity = f.forward()*raider.speed
	_want = f.heading
	_plan_t = 0.0
	_lost = 0.0
	phase = &"run"
	_drop_route()
	_seen = (game.near.moments as Array).size()

## Shown by a buzz: behind the plane, overhead or beside it, overtaking.
func buzz() -> void:
	var game: Node3D = raider.game
	var plane = game.plane
	var p: Vector3 = plane.position
	var fwd: Vector3 = plane.forward()
	var flat := Vector3(fwd.x,0.0,fwd.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
	_buzz_line = flat
	_buzz_s = -BUZZ_BACK
	var side := 1.0 if raider._rng.randf() < 0.5 else -1.0
	_buzz_off = Vector2(0.0,BUZZ_UP) if raider._rng.randf() < 0.5 else Vector2(BUZZ_SIDE.x*side,BUZZ_SIDE.y)
	_buzz_heard = false
	var f: SkyTraffic.Flight = raider.flight
	f.position = _buzz_at(p)
	f.heading = atan2(-flat.x,-flat.z)
	f.pitch = 0.0
	f.bank = 0.0
	raider.speed = maxf(float(plane.speed),float(plane.cruise()))+BUZZ_OVER
	f.speed = raider.speed
	f.velocity = f.forward()*raider.speed
	_want = f.heading
	_plan_t = 0.0
	_lost = 0.0
	phase = &"buzz"
	_drop_route()
	_seen = (game.near.moments as Array).size()
	stats.buzzes = int(stats.get("buzzes",0))+1

## Where the buzz puts it now: `_buzz_s` m along the line from the plane, the
## offset across and up, never under what stands there.
func _buzz_at(p: Vector3) -> Vector3:
	var across := _buzz_line.cross(Vector3.UP)
	var at := p+_buzz_line*_buzz_s+across*_buzz_off.x
	at.y = maxf(p.y+_buzz_off.y,_floor_y(at,_buzz_line,true)+float(tuning.low))
	return at

## A frame of the buzz: on along the plane's line (eased round with its
## turns) at BUZZ_OVER over its speed; heading, pitch and bank from the move.
func _buzz(delta: float, p: Vector3, ps: float) -> void:
	var game: Node3D = raider.game
	var fwd: Vector3 = game.plane.forward()
	var flat := Vector3(fwd.x,0.0,fwd.z)
	if flat.length() > 0.1:
		_buzz_line = _buzz_line.slerp(flat.normalized(),minf(BUZZ_FOLLOW*delta,1.0)).normalized()
	var f: SkyTraffic.Flight = raider.flight
	var was: Vector3 = f.position
	var along_was := _buzz_s
	# Its speed over the plane's along the line: the plane's own forward pace.
	_buzz_s += BUZZ_OVER*delta
	var at := _buzz_at(p)
	var v := (at-was)/maxf(delta,0.0001)
	f.position = at
	f.velocity = v
	raider.speed = v.length()
	f.speed = raider.speed
	var h := atan2(-v.x,-v.z) if Vector2(v.x,v.z).length() > 1.0 else f.heading
	var rate := angle_difference(f.heading,h)/maxf(delta,0.0001)
	raider.turn = lerpf(raider.turn,clampf(rate,-TURN,TURN),raider._ease(0.3,delta))
	f.heading = h
	f.pitch = clampf(atan2(v.y,maxf(Vector2(v.x,v.z).length(),1.0)),-PITCH_MAX,PITCH_MAX)
	f.bank = clampf(-raider.turn*raider.BANK,-raider.BANK_MAX,raider.BANK_MAX)
	if along_was < 0.0 and _buzz_s >= 0.0 and not _buzz_heard:
		_buzz_heard = true
		game.sound.shot("whoosh",1.0,0.8,f.position)
		stats.buzz_pass = Vector3(f.position-p).length()
	if _buzz_s >= BUZZ_DONE:
		phase = &"run"
		_want = f.heading
		_want_y = NAN
		_plan_t = 0.0

## Breaking off (the mix): it runs from where it flies, as it flies.
func begin() -> void:
	var f: SkyTraffic.Flight = raider.flight
	_want = f.heading
	_plan_t = 0.0
	_lost = 0.0
	phase = &"run"
	_drop_route()
	_seen = (raider.game.near.moments as Array).size()

## Not up (away, dead, or back to the dogfight): no speed from skimming.
func idle() -> void:
	heat = 0.0
	skim_over = 0.0
	raider.game.plane.skim_over = 0.0

## One frame of the chase (raider.gd `step`, state `flee`).
func step(delta: float, p: Vector3, rel: Vector3, dist: float, ps: float) -> void:
	var game: Node3D = raider.game
	var plane = game.plane
	var f: SkyTraffic.Flight = raider.flight
	_skim(delta)
	var fwd: Vector3 = plane.forward()
	var pf := Vector3(fwd.x,0.0,fwd.z).normalized()
	var ahead := rel.dot(pf) >= 0.0
	gap = dist if ahead else -dist
	# Lost: far, or out of the view, for a while: back round.
	if phase == &"buzz":
		_buzz(delta,p,ps)
		return
	var cam: Camera3D = game.camera
	var unseen: bool = cam.is_position_behind(f.position)
	_lost = _lost+delta if (dist > LOST_M or unseen) else 0.0
	# Only a chased raider comes round (raider.gd `chased`); one let go leaves.
	if phase == &"run" and _lost > LOST_S and bool(raider.chased):
		phase = &"round"
		_drop_route()
		stats.rounds = int(stats.rounds)+1
	if phase == &"round":
		var side := pf.cross(Vector3.UP)
		side *= 1.0 if side.dot(rel) >= 0.0 else -1.0
		var aim := p+pf*BACK_M+side*BACK_SIDE
		_fly(_heading_to(aim),delta,ps+ROUND_OVER)
		var to := aim-f.position
		if Vector2(to.x,to.z).length() < 120.0 or (ahead and gap > 150.0 and gap < 450.0 and not unseen and f.forward().dot(pf) > 0.3):
			phase = &"run"
			_lost = 0.0
			_want = f.heading
		return
	var pace := float(plane.boost_speed())*lerpf(float(tuning.pace),EASE_PACE,smoothstep(EASE_M.x,EASE_M.y,gap))
	if not ahead: pace = maxf(pace,ps+AHEAD_OVER)
	pace *= float(raider.pace_k())  # pulling away after an ember's hit
	_plan_t -= delta
	if route.is_empty() and _plan_t <= 0.0:
		_plan_t = PLAN_S
		stats.plans = int(stats.plans)+1
		if not _take_arch(p): _plan(p)
	if not route.is_empty():
		_follow(delta,pace)
		return
	_fly(_want,delta,pace)

# --- The plan -----------------------------------------------------------------

func _plan(p: Vector3) -> void:
	var game: Node3D = raider.game
	var f: SkyTraffic.Flight = raider.flight
	var at: Vector3 = f.position
	var away := Vector3(at.x-p.x,0.0,at.z-p.z)
	away = away.normalized() if away.length() > 1.0 else Vector3(f.forward().x,0.0,f.forward().z).normalized()
	var arch_way := _arch_pull(at)
	var home := Vector3(-at.x,0.0,-at.z)
	var far := home.length()
	home = home/maxf(far,1.0)
	var land_way := _land_way(at)
	var best := -INF
	var best_h := f.heading
	for k in range(-FAN,FAN+1):
		var h := wrapf(float(f.heading)+k*FAN_STEP,-PI,PI)
		var dir := Vector3(-sin(h),0.0,-cos(h))
		var score := 0.0
		var top := -INF
		for s: float in LOOK:
			var q := at+dir*s
			var land := float(game.field.height(q.x,q.z))
			# A rock or an arch at its height, or one whose top it can't climb
			# over by then at CLIMB (an arch's lintel over its line: it isn't
			# routed through, so `_fly` would climb over it, too late).
			if s <= 180.0:
				var solid := _top(game.plane_ground(Vector3(q.x,at.y+PROBE,q.z),SOLID_PAD))
				if _pillar(Vector3(q.x,at.y,q.z)) or (solid > land+1.0 and solid > at.y+s*CLIMB): score -= W_BLOCK
			var water := float(game.water_at(q))
			top = maxf(top,maxf(land,water))
			if water > land: score -= W_SEA
			elif _trees_at(q,land): score += W_TREE
		score -= maxf(top-(at.y-float(tuning.low)),0.0)*W_CLIMB
		score -= absf(k*FAN_STEP)*W_TURN
		score -= absf(angle_difference(_want,h))*W_KEEP
		var flee := dir.dot(away)
		if flee < FLEE_COS: score -= (FLEE_COS-flee)*W_FLEE*(SEA_FLEE if land_way != Vector3.ZERO else 1.0)
		if arch_way != Vector3.ZERO: score += maxf(dir.dot(arch_way),0.0)*W_ARCH
		if far > HOME_M: score += dir.dot(home)*W_HOME
		if land_way != Vector3.ZERO: score += dir.dot(land_way)*W_SEA_HOME
		if score > best:
			best = score
			best_h = h
	_want = best_h

## Over the sea's floor (not a river): the way (flat, unit) to the nearest
## land within SEA_LOOK m, else zero.
func _land_way(at: Vector3) -> Vector3:
	var field = raider.game.field
	if float(field.height(at.x,at.z)) >= Field.SEA_Y-1.0: return Vector3.ZERO
	for s: float in SEA_LOOK:
		var best := Vector3.ZERO
		var best_h := Field.SEA_Y+1.0
		for k in SEA_DIRS:
			var a := TAU*k/SEA_DIRS
			var d := Vector3(sin(a),0.0,cos(a))
			var h := float(field.height(at.x+d.x*s,at.z+d.z*s))
			if h > best_h:
				best_h = h
				best = d
		if best != Vector3.ZERO: return best
	return Vector3.ZERO

## A rock or an arch standing at `q`.
func _pillar(q: Vector3) -> bool:
	var game: Node3D = raider.game
	return (game.rocks != null and bool(game.rocks.inside(q))) or (game.arches != null and bool(game.arches.inside(q)))

## Trees about `q` (a crown within a few m), `land` the ground there.
func _trees_at(q: Vector3, land: float) -> bool:
	var trees: Node3D = raider.game.trees
	if trees == null: return false
	for o: Vector2 in [Vector2.ZERO,Vector2(9,0),Vector2(-9,0),Vector2(0,9),Vector2(0,-9)]:
		if float(trees.top_at(q+Vector3(o.x,0.0,o.y))) > land+3.0: return true
	return false

## The way (flat, unit) to the nearest fitting arch standing ahead-ish
## within ARCH_SEEK, or zero.
func _arch_pull(at: Vector3) -> Vector3:
	var game: Node3D = raider.game
	if game.arches == null: return Vector3.ZERO
	var fwd: Vector3 = raider.flight.forward()
	var best := INF
	var way := Vector3.ZERO
	for a: Dictionary in game.arches.standing():
		var o := _opening(a)
		if o.is_empty(): continue
		var c: Vector3 = o.centre
		var to := Vector3(c.x-at.x,0.0,c.z-at.z)
		var d := to.length()
		if d > ARCH_SEEK or d < 1.0 or to.dot(fwd) < 0.0: continue
		if d < best:
			best = d
			way = to/d
	return way

## Takes an arch ahead whose opening fits and whose approach is clear: the
## route set. False if none.
func _take_arch(p: Vector3) -> bool:
	var game: Node3D = raider.game
	if game.arches == null: return false
	var f: SkyTraffic.Flight = raider.flight
	var at: Vector3 = f.position
	var fwd: Vector3 = f.forward()
	var flat := Vector3(fwd.x,0.0,fwd.z).normalized()
	var away := Vector3(at.x-p.x,0.0,at.z-p.z).normalized()
	for a: Dictionary in game.arches.standing():
		var ap: Vector3 = a.pos
		if Vector2(ap.x-at.x,ap.z-at.z).length() > ARCH_REACH+100.0: continue
		stats.arch_near = int(stats.arch_near)+1
		var o := _opening(a)
		if o.is_empty(): continue
		stats.arch_fit = int(stats.arch_fit)+1
		var c: Vector3 = o.centre
		var d := Vector2(c.x-at.x,c.z-at.z).length()
		if d > ARCH_REACH: continue
		var z := Vector3(float(a.sin),0.0,float(a.cos))
		for sgn: float in [1.0,-1.0]:
			var w := z*sgn
			if w.dot(flat) < cos(ARCH_TURN) or w.dot(away) < 0.0: continue
			var entry := c-w*APPROACH
			var to := entry-at
			# Ahead of it, far enough to line up on.
			if to.dot(flat) < 50.0: continue
			# Low enough to come down to the line by the run-in.
			if at.y-c.y > maxf(d-RUN_IN,0.0)*DESCENT_MOST: continue
			stats.arch_way = int(stats.arch_way)+1
			if not _clear_way(c,w): continue
			stats.arch_clear = int(stats.arch_clear)+1
			arch = String(a.name)
			route = [entry,c,c+w*EXIT]
			leg = 0
			return true
	return false

## The way through `o` along `w` clear: from RUN_IN m before its middle
## to RUN_OUT past it at its height, the land under by a span and nothing
## solid but the opening; before that, out to APPROACH, the land and crowns
## under the line that comes down DESCENT a m (LOW under it); after it, out to
## EXIT, the land under the line that climbs out the same.
func _clear_way(c: Vector3, w: Vector3) -> bool:
	var game: Node3D = raider.game
	var low := float(tuning.low)
	var u := -APPROACH
	while u <= EXIT:
		var q := c+w*u
		var line := c.y+maxf(maxf(-u-RUN_IN,u-RUN_OUT),0.0)*DESCENT
		q.y = line
		var land := maxf(float(game.field.height(q.x,q.z)),float(game.water_at(q)))
		var crown := float(game.trees.top_at(q)) if game.trees != null else -INF
		var why := ""
		if land > line-(WorldScale.span if u >= -RUN_IN and u <= RUN_OUT else low): why = "land"
		elif crown > line-low: why = "tree"
		elif game.rocks != null and bool(game.rocks.inside(q)): why = "rock"
		elif absf(u) > 12.0 and bool(game.arches.inside(q,WorldScale.span*0.5)): why = "arch"
		if why != "":
			stats["no_"+why] = int(stats.get("no_"+why,0))+1
			return false
		u += 8.0
	return true

## Along the route: on to its run-in, then along the line through the
## opening's middle (aimed LEAD m on along it), on rails over the last RAILS
## m in, a pass counted at its middle; off the route RUN_OUT m past it.
func _follow(delta: float, pace: float) -> void:
	var f: SkyTraffic.Flight = raider.flight
	var c: Vector3 = route[1]
	var w: Vector3 = (route[2]-route[1]).normalized()
	var off: Vector3 = f.position-c
	var along := off.dot(w)
	var lateral := off-w*along
	lateral.y = 0.0
	if leg == 0:
		# On to the run-in, then onto the line.
		var to: Vector3 = route[0]-f.position
		if Vector2(to.x,to.z).length() < 25.0 or (along > -APPROACH+15.0 and lateral.length() < 12.0): leg = 1
		# Solids read short of the run-in only: the arch past it is the route's.
		_fly(_heading_to(route[0]),delta,pace,NAN,true,Vector2(to.x,to.z).length())
		return
	# Along the line through the middle: down to the opening's height by RUN_IN
	# m before it (DESCENT a m on before that), held RUN_OUT m past it.
	var y := c.y+maxf(-along-RUN_IN,0.0)*DESCENT
	# Still over the opening's top by the run-in (it shouldn't be): off the
	# route, over the arch (the look-ahead reads its solids again).
	var o: Dictionary = _openings.get(arch,{})
	if along > -RUN_IN and along < 0.0 and not o.is_empty() and f.position.y > float(o.top)-WorldScale.span:
		stats.aborts = int(stats.get("aborts",0))+1
		_drop_route()
		_want = f.heading
		_fly(_want,delta,pace)
		return
	_fly(_heading_to(c+w*maxf(along+LEAD,LEAD*0.5)),delta,pace,y,false)
	# On rails the last RAILS m in: the miss off the line eased out.
	off = f.position-c
	var now := off.dot(w)
	if now > -RAILS and now < RUN_OUT:
		var miss := off-w*now
		miss.y = 0.0
		f.position -= miss*minf(delta*4.0,1.0)
	if along < 0.0 and now >= 0.0: _pass(c,w)
	if now > RUN_OUT:
		_drop_route()
		_want = f.heading

func _pass(c: Vector3, w: Vector3) -> void:
	var f: SkyTraffic.Flight = raider.flight
	var o: Dictionary = _openings.get(arch,{})
	if o.is_empty(): return
	var off: Vector3 = f.position-c
	var across := absf((off-w*off.dot(w)).dot(Vector3.UP.cross(w).normalized()))
	var y: float = f.position.y
	if across < float(o.room) and y > float(o.floor) and y < float(o.top):
		stats.arches = int(stats.arches)+1
		(stats.arch_names as Array).append(arch)

func _drop_route() -> void:
	route.clear()
	arch = ""
	leg = 0

## An arch's widest opening (rival_line.gd `_arch_opening`'s reading: its
## solid's columns across its span at three depths): {centre (world, at its
## flying height), room (half its width), floor, top}, or {} when none fits
## the player's plane (WorldScale.opening(TOY_FIT) wide and tall). The
## Peak's carve and the set pieces are left out.
func _opening(a: Dictionary) -> Dictionary:
	var name := String(a.name)
	if _openings.has(name): return _openings[name]
	var spec: Dictionary = a.spec
	if spec.has("tone") or spec.has("carve") or spec.has("set") or spec.has("bridge") or not a.has("solid"):
		_openings[name] = {}
		return {}
	var game: Node3D = raider.game
	var fit := WorldScale.opening(TOY_FIT)
	var o: Vector3 = a.pos
	var x := Vector3(float(a.cos),0.0,-float(a.sin))
	var z := Vector3(float(a.sin),0.0,float(a.cos))
	var depth := float(spec.get("depth",6.0))
	var runs: Array = []
	var run := []
	var sx := BoxSolid.span_x(a.solid)
	var n := int(ceil((sx.y-sx.x)/Build.BIN))
	for j in range(n+1):
		var ok := false
		var room := INF
		var floor_y := -INF
		if j < n:
			var lx := sx.x+(j+0.5)*Build.BIN
			ok = true
			for lz: float in [-depth*0.35,0.0,depth*0.35]:
				var p := o+x*lx+z*lz
				var h := maxf(float(game.field.height(p.x,p.z)),float(game.water_at(Vector3(p.x,0.0,p.z))))
				var list: Array = game.arches.stretches(Vector3(p.x,h+fit*0.5,p.z),0.0)
				if list.is_empty():
					ok = false
					break
				var under := INF
				for s: Vector2 in list:
					if s.y > h+0.6:
						under = s.x
						break
				if under-h < fit:
					ok = false
					break
				room = minf(room,under-h)
				floor_y = maxf(floor_y,h)
		if ok: run.append([sx.x+(j+0.5)*Build.BIN,room,floor_y])
		elif not run.is_empty():
			runs.append(run)
			run = []
	var best := {}
	var best_score := -INF
	for r: Array in runs:
		var wide := float(r.size())*Build.BIN
		if wide < fit: continue
		var tall := INF
		var fl := -INF
		for k in range(r.size()/4,maxi(r.size()*3/4,r.size()/4+1)):
			tall = minf(tall,float(r[k][1]))
			fl = maxf(fl,float(r[k][2]))
		var mid := (float(r[0][0])+float(r[r.size()-1][0]))*0.5
		var score := minf(wide,tall)
		if score > best_score:
			best_score = score
			var y := fl+clampf(tall*GAP_SHARE,WorldScale.span,tall-WorldScale.span*1.5)
			best = {"centre":Vector3(o.x,0.0,o.z)+x*mid+Vector3.UP*y,"room":wide*0.5,"floor":fl,"top":fl+tall}
	_openings[name] = best
	return best

# --- Flying -------------------------------------------------------------------

func _heading_to(aim: Vector3) -> float:
	var to: Vector3 = aim-raider.flight.position
	return atan2(-to.x,-to.z)

## Onto heading `want` at `pace` m/s: the turn capped, the wings banked with
## it, the nose to `y` (world; NAN: LOW over what stands ahead), never under
## FLOOR over the land.
func _fly(want: float, delta: float, pace: float, y := NAN, solids := true, reach := INF) -> void:
	var f: SkyTraffic.Flight = raider.flight
	var rate := clampf(angle_difference(f.heading,want)*TURN_GAIN,-TURN,TURN)
	raider.turn = lerpf(raider.turn,rate,raider._ease(0.3,delta))
	f.heading = wrapf(f.heading+raider.turn*delta,-PI,PI)
	f.bank = clampf(-raider.turn*raider.BANK,-raider.BANK_MAX,raider.BANK_MAX)
	var fwd: Vector3 = f.forward()
	var flat := Vector3(fwd.x,0.0,fwd.z).normalized()
	# Routed through an arch's opening (`y` the line's height, the way checked
	# clear; `solids` off): only the land and the crowns under it.
	var under := _floor_y(f.position,flat,solids,reach)
	var want_y := y if not is_nan(y) else under+maxf(float(tuning.low)*float(raider.low_k()),FLOOR)
	# The aim's own climb led (its rise a m on), then the miss closed.
	var run := maxf(raider.speed*delta,0.01)
	if not is_nan(_want_y):
		_slope = lerpf(_slope,clampf((want_y-_want_y)/run,-PITCH_DOWN,PITCH_MAX),raider._ease(0.12,delta))
	_want_y = want_y
	var band := DIVE_M if is_nan(y) else DIVE_LINE
	var down := lerpf(PITCH_DOWN,float(tuning.dive),smoothstep(band.x,band.y,f.position.y-want_y))
	var pitch := clampf(atan(_slope)+atan2(want_y-f.position.y,maxf(raider.speed*0.4,15.0)),-down,PITCH_MAX)
	if f.position.y < under+FLOOR: pitch = maxf(pitch,0.3)
	f.pitch = move_toward(f.pitch,pitch,PITCH_RATE*delta)
	raider.speed = lerpf(raider.speed,pace,raider._ease(1.0,delta))
	f.speed = raider.speed
	f.velocity = f.forward()*raider.speed
	f.position += f.velocity*delta
	# Never into the land or a crown: held over them.
	var land: float = raider._ground_at(f.position)
	f.position.y = maxf(f.position.y,land+FLOOR)
	if raider.game.trees != null: f.position.y = maxf(f.position.y,float(raider.game.trees.top_at(f.position))+CROWN_CLEAR)
	# Off a route, never inside a rock or an arch: lifted onto its top (the
	# look-ahead should keep this from ever happening; counted).
	if solids and _pillar(f.position):
		f.position.y = maxf(f.position.y,_top(raider.game.plane_ground(f.position+Vector3.UP*PROBE,SOLID_PAD))+CROWN_CLEAR)
		stats.lifts = int(stats.lifts)+1
	_count(f.position,land)

## The height it needs here to meet what stands ahead climbing CLIMB: at
## AHEAD's samples along `flat`, the land, the water and the crowns (read
## SIDE m to each side too), and with `solids` the flight's own ground read
## from PROBE m over it (`plane_ground`: the tops of rocks, arches, halls),
## each less CLIMB of its way on (solids only within `reach` m). An arch it
## isn't routed through it flies over, not into.
func _floor_y(at: Vector3, flat: Vector3, solids: bool, reach := INF) -> float:
	var game: Node3D = raider.game
	var side := flat.cross(Vector3.UP)
	var top := -INF
	for a: float in AHEAD:
		var q := at+flat*a
		var h := float(game.field.height(q.x,q.z))
		if solids and a <= reach:
			h = maxf(h,_top(game.plane_ground(Vector3(q.x,at.y+PROBE,q.z),SOLID_PAD)))
		h = maxf(h,float(game.water_at(q)))
		if game.trees != null: h = maxf(h,float(game.trees.top_at(q)))
		if game.trees != null:
			h = maxf(h,float(game.trees.top_at(q+side*SIDE)))
			h = maxf(h,float(game.trees.top_at(q-side*SIDE)))
		top = maxf(top,h-a*CLIMB)
	return top

## The top of what `plane_ground` read from high up finds: a height, or
## Vector2(top, underside) over an opening (an arch's lintel); -INF else.
static func _top(g: Variant) -> float:
	if g is float or g is int: return float(g)
	if g is Vector2: return (g as Vector2).x
	return -INF

## The drivers' tallies: time low over crowns, frames inside a solid.
func _count(at: Vector3, land: float) -> void:
	var game: Node3D = raider.game
	var dt := 1.0/60.0
	if game.trees != null:
		var crown := -INF
		for o: Vector2 in [Vector2.ZERO,Vector2(6,0),Vector2(-6,0),Vector2(0,6),Vector2(0,-6)]:
			crown = maxf(crown,float(game.trees.top_at(at+Vector3(o.x,0.0,o.y))))
		if crown > land+3.0 and at.y-crown < 12.0: stats.tree_s = float(stats.tree_s)+dt
	if game.has_method("_blocked") and bool(game._blocked(at)):
		stats.clips = int(stats.clips)+1
		var what := "tree" if game.trees.inside(at) else ("arch" if game.arches.inside(at) else ("rock" if game.rocks.inside(at) else "other"))
		stats.clip_what = what
		stats.clip_at = at
		stats.clip_route = arch

# --- Skimming -------------------------------------------------------------------

## The plane's heat from how close it skims, kicked by NearMiss's moments,
## into its speed (SkyPlane `skim_over`).
func _skim(delta: float) -> void:
	var game: Node3D = raider.game
	var plane = game.plane
	var near: RefCounted = game.near
	var span := WorldScale.span
	var clear := minf(minf(float(near.ground_clear),float(near.stone_clear)),minf(float(near.left_clear),float(near.right_clear)))
	clear = minf(clear,float(near.over_clear))
	var fast: bool = float(plane.speed) >= float(plane.cruise())*0.8 and bool(game.hand_landing.flying())
	var k := 0.0
	if fast and clear < INF: k = clampf(1.0-(clear-span*0.25)/(SKIM_BAND*span),0.0,1.0)
	var moments: Array = near.moments
	if moments.size() > _seen:
		k = maxf(k,minf(heat+KICK*(moments.size()-_seen),1.0))
	_seen = moments.size()
	heat = lerpf(heat,k,raider._ease(HEAT_UP if k > heat else HEAT_DOWN,delta))
	skim_over = heat*float(tuning.skim)
	plane.skim_over = skim_over
