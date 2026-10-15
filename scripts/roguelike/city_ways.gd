extends RefCounted
## The city's crossings as a family (docs/design/roguelike/layer-round15-
## city-crossings.md): the plan's shapes of the edges between two places of
## an underground layer, each a little place read from the rim, each sized
## from the wanderer's real motor (scripts/pilot_motor.gd, at WorldScale's
## size through KitMotif `pilot`), never from copied metres. Data only (the
## plan's edge dicts); scripts/roguelike/city_crossings.gd draws them in the
## city's basalt (scripts/city_kit_ways.gd).
##
##   slide     the spillway: a carved channel on piers sweeping downhill in
##             banked bends (an S or a swerve) to the next place, crouch-slid
##             at speed on the motor's own surf, a trough that hands him back
##             to its middle, a flat run-out (a mercy)
##   causeway  whole and quiet: one straight deck, level or gently graded,
##             the gulf either side
##   broken    the same causeway with spans in states: whole, gone (a
##             running long jump), sagged (down into a V and up), slumped
##             (dropped flat: down onto it, climb back up the far lip)
##   piers     staggered drum stacks at different heights, the gaps a long
##             jump's (a long-jump or pump chain for the skilled), a low step
##             drum aside in a gap where the hops allow (the slow safe line)
##   stones    the old column tops (LayerPlan `_lay_stones`), now and then
##
## The plan picks a kind per route edge (`order`): weighted by the danger,
## the slide likeliest, never the kind laid just before where another fits;
## the greed branch's "hard" edge is the hard piers. `--knob=city_crossings=
## plain` lays the old column tops and causeway beams (round 14) for A/B.
## Kept free of layer_plan.gd (it preloads this).
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const LayerWorlds = preload("res://scripts/roguelike/layer_worlds.gd")

## The family, and each kind's weight at danger 0 (x) and 1 (y).
const KINDS := ["slide","causeway","broken","piers","stones"]
const WEIGHT := {"slide":Vector2(3.2,2.6),"causeway":Vector2(2.4,0.7),"broken":Vector2(1.3,2.6),"piers":Vector2(0.7,2.4),"stones":Vector2(0.5,0.5)}
## The kind laid just before keeps this share of its weight.
const AGAIN := 0.08
## The corridor (LayerPlan's UNDER, OVER).
const UNDER := 2.6
const OVER := 2.6

static var _pilot: PilotMotor
static func pilot() -> PilotMotor:
	if _pilot == null: _pilot = KitMotif.pilot()
	return _pilot

static func warm() -> void:
	pilot()

## Whether a layer laid with `knobs` draws its crossings from the family.
static func on(knobs: Dictionary) -> bool:
	return LayerWorlds.city(knobs) and str(knobs.get("city_crossings","varied")) != "plain"

## The family in the order an edge tries them: drawn by weight at `danger`
## (0-1) without putting back, `prev` (the kind laid before) cut to AGAIN.
static func order(prev: String, danger: float, rng: RandomNumberGenerator) -> Array:
	var left := {}
	for k: String in KINDS:
		var w: Vector2 = WEIGHT[k]
		left[k] = lerpf(w.x,w.y,clampf(danger,0.0,1.0))*(AGAIN if k == prev else 1.0)
	var out: Array = []
	while not left.is_empty():
		var total := 0.0
		for k: String in left: total += float(left[k])
		var draw := rng.randf()*total
		var got: String = left.keys()[left.size()-1]
		for k: String in left:
			draw -= float(left[k])
			if draw <= 0.0:
				got = k
				break
		out.append(got)
		left.erase(got)
	return out

# --- The pilot's reach ----------------------------------------------------------------

## How far (m, flat) his running small jump carries before it is back down
## to `rise` over its takeoff (LayerPlan `reach`).
static func hop(rise: float) -> float:
	var p := pilot()
	var j := float(p.jumps[0])
	if rise >= j: return 0.0
	return p.run*(sqrt(2.0*j/p.gravity)+sqrt(2.0*(j-rise)/(p.gravity*p.fall)))

## The same for the pump (his second jump, JUMPS[1], chained on a landing).
static func pump(rise: float) -> float:
	var p := pilot()
	var j := float(p.jumps[1])
	if rise >= j: return 0.0
	return p.run*(sqrt(2.0*j/p.gravity)+sqrt(2.0*(j-rise)/(p.gravity*p.fall)))

## How far a running long jump (his least long-jump pace, LONG_SPEED) comes
## down `rise` m over its takeoff (its own gravity up and down; the viaduct's
## `long_reach`).
static func long_reach(rise: float, pace := 0.0) -> float:
	var p := pilot()
	var g := p.long_gravity
	var h := p.long_height
	if rise >= h: return 0.0
	var v := p.long_speed if pace <= 0.0 else pace
	return v*(sqrt(2.0*h/g)+sqrt(2.0*(h-rise)/g))

## The highest lip he takes hold of from a standing jump (his small jump,
## the hands HANG_DROP over the feet, GRAB_LOW under them): RuinKit
## GRAB_TOP at his size.
static func grab_top() -> float:
	var p := pilot()
	return float(p.jumps[0])+p.hang_drop+PilotMotor.GRAB_LOW

## The surf's fastest down a slope of `deg` (m/s): where the pull down it
## meets the drag and the air (pilot_motor.gd `_surf`).
static func surf_top(deg: float) -> float:
	var p := pilot()
	var a := p.slide_pull*sin(deg_to_rad(deg))-PilotMotor.SLIDE_DRAG
	return minf(sqrt(maxf(a,0.0)/p.slide_air),p.slide_top)

# --- The shapes -----------------------------------------------------------------------

## An edge of `kind` leaving lip `a` along `dir` (flat, unit): LayerPlan
## `_shape`'s dict ({b, stones, bridges, trap, parts, path, mean}) and the
## family's own: spans (the causeway's, each {a, b, state, ...}), chute (the
## spillway's), flank (more corridor samples, [point, under, over], off the
## walked line). `hard` the greed branch's.
static func shape(kind: String, a: Vector3, dir: Vector3, rng: RandomNumberGenerator, meanness := 0.0, hard := false) -> Dictionary:
	var out := {"stones":[],"bridges":[],"trap":{},"parts":[],"path":[],"mean":meanness,"spans":[],"chute":{},"flank":[]}
	match kind:
		"slide": out.b = _slide(out,a,dir,rng)
		"causeway": out.b = _whole(out,a,dir,rng)
		"broken": out.b = _broken(out,a,dir,rng,meanness,hard)
		"piers": out.b = _piers(out,a,dir,rng,meanness,hard)
		_: return {}
	return out

## Samples from `a` to `b` every `step` m: [point, under, over].
static func _line(a: Vector3, b: Vector3, under: float, step := 0.5) -> Array:
	var out: Array = []
	var n := maxi(int(ceil(a.distance_to(b)/step)),1)
	for i in range(n+1): out.append([a.lerp(b,float(i)/n),under,OVER])
	return out

## The straight causeway: one deck lip to lip, RUN_SECONDS of his run long,
## graded at most GRADE_MOST (a walk, never a slow one: under SLOPE_SLOW),
## spans of SPAN_SECONDS of his run between piers.
const RUN_SECONDS := Vector2(3.4,6.0)
const GRADE := Vector2(-0.02,0.08)
const SPAN_SECONDS := Vector2(1.3,1.7)
static func _whole(out: Dictionary, a: Vector3, dir: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var p := pilot()
	var length := p.run*rng.randf_range(RUN_SECONDS.x,RUN_SECONDS.y)
	var b := a+dir*length+Vector3.UP*length*rng.randf_range(GRADE.x,GRADE.y)
	var n := maxi(int(round(length/(p.run*SPAN_SECONDS.y))),1)
	for k in range(n):
		out.spans.append({"a":a.lerp(b,float(k)/n),"b":a.lerp(b,float(k+1)/n),"state":"whole"})
	out.parts.append("causeway %.1f m, %d spans" % [length,n])
	out.path.append_array(_line(a,b,UNDER))
	return b

## The broken causeway: whole spans with beats between: "gone" (a running
## long jump, its gap GONE_SHARE of the long jump's reach, past HOP_PAST
## of his small jump's, after a whole span's run-up), "sagged" (its middle
## SAG degrees down: down into the V and up, a walk), "slumped" (dropped
## flat from SLUMP of the way between his small jump and his grab: down
## onto it, then a standing jump to the far lip, a hand on it, up).
const GONE_SHARE := Vector2(0.62,0.7)
const GONE_MEAN := 0.25
const HOP_PAST := 1.2
const STUB := Vector2(0.9,1.3)
const SAG := Vector2(9.0,15.0)
const SLUMP := Vector2(0.2,0.75)
static func _broken(out: Dictionary, a: Vector3, dir: Vector3, rng: RandomNumberGenerator, meanness: float, hard: bool) -> Vector3:
	var p := pilot()
	var beats: Array = ["gone","sagged" if rng.randf() < 0.5 else "slumped"]
	var third := rng.randf()
	if third < 0.4: beats.append(["sagged","slumped"][rng.randi_range(0,1)])
	elif third < 0.4+0.5*meanness or hard: beats.append("gone")
	for i in range(beats.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var t: Variant = beats[i]
		beats[i] = beats[j]
		beats[j] = t
	var seq: Array = ["whole"]
	for beat: String in beats:
		if beat == "gone" and seq[-1] != "whole": seq.append("whole")
		seq.append(beat)
	seq.append("whole")
	var at := a
	var names := PackedStringArray()
	var deepest := 0.0
	for state: String in seq:
		var s := p.run*rng.randf_range(SPAN_SECONDS.x,SPAN_SECONDS.y)
		var span := {"state":state,"a":at}
		match state:
			"whole":
				span.b = at+dir*s+Vector3.UP*s*rng.randf_range(0.0,0.05)
				names.append("whole")
			"gone":
				var share := rng.randf_range(GONE_SHARE.x,GONE_SHARE.y)+GONE_MEAN*meanness+(0.08 if hard else 0.0)
				var drop := rng.randf_range(0.0,0.4)
				var gap := clampf(long_reach(-drop)*share,hop(-drop)*HOP_PAST,long_reach(-drop)*0.88)
				span.stub_a = rng.randf_range(STUB.x,STUB.y)
				span.stub_b = rng.randf_range(STUB.x,STUB.y)
				span.gap = gap
				span.b = at+dir*(gap+float(span.stub_a)+float(span.stub_b))-Vector3.UP*drop
				names.append("gone %.1f m" % gap)
			"sagged":
				span.b = at+dir*s
				span.sag = s*0.5*tan(deg_to_rad(rng.randf_range(SAG.x,SAG.y)))
				deepest = maxf(deepest,float(span.sag))
				names.append("sagged %.1f m" % float(span.sag))
			"slumped":
				var lo := float(p.jumps[0])+0.15
				var h := lerpf(lo,grab_top()-0.3,clampf(rng.randf_range(SLUMP.x,SLUMP.y)+meanness*0.4,0.0,1.0))
				span.b = at+dir*s*0.85
				span.drop_far = h
				span.drop_near = h*rng.randf_range(1.0,1.2)
				deepest = maxf(deepest,float(span.drop_near))
				names.append("slumped %.1f m" % h)
		out.spans.append(span)
		at = span.b
	out.parts.append("broken causeway: %s" % ", ".join(names))
	out.path.append_array(_line(a,at,UNDER+deepest))
	return at

## The staggered piers: PIERS drum stacks, each a gap a long jump's
## (LONG_SHARE of its reach at the rise, past HOP_PAST of his small jump's
## and PUMP_PAST of his pump's, so a hop or a pump falls short), its top
## long enough that a long jump taken up to TAKEOFF short of the last's edge
## still comes down on it and, let go of, he stops on it (his brake from
## the long jump's pace); the rises RISE_UP or RISE_DOWN in turn. In a gap where both hops come under STEP_HOP of his small
## jump, a step drum STEP_DOWN under the lower top, off to one side: the
## slow safe line, hop by hop.
const PIERS := Vector2i(3,5)
const LONG_SHARE := Vector2(0.7,0.8)
const LONG_MEAN := 0.12
const PUMP_PAST := 1.05
const TAKEOFF := 0.8
const TOP_SECONDS := Vector2(0.5,0.62)
const RISE_UP := Vector2(0.1,0.4)
const RISE_DOWN := Vector2(-1.4,-0.4)
const STEP_DOWN := 0.3
const STEP_SECONDS := 0.2
static func _piers(out: Dictionary, a: Vector3, dir: Vector3, rng: RandomNumberGenerator, meanness: float, hard: bool) -> Vector3:
	var p := pilot()
	var n := rng.randi_range(PIERS.x,PIERS.y)+(1 if hard else 0)
	var side := Vector3.UP.cross(dir).normalized()
	var yaw := atan2(-dir.z,dir.x)
	var chain := "piers_%d_%d" % [roundi(a.x),roundi(a.z)]
	var share_add := LONG_MEAN*meanness+(0.12 if hard else 0.0)
	var step_odds := 0.0 if hard else 0.9-0.6*meanness
	var edge := a
	var prev_c := a
	var prev_r := 0.0
	var tops: Array = []
	var gaps := PackedStringArray()
	var steps := 0
	var up := rng.randf() < 0.5
	for k in range(n+1):
		var last := k == n
		var r := rng.randf_range(-0.3,0.2) if last else (rng.randf_range(RISE_UP.x,RISE_UP.y) if up else rng.randf_range(RISE_DOWN.x,RISE_DOWN.y))
		# Keep near the lip's level overall.
		if not last and edge.y+r < a.y-2.6: r = rng.randf_range(RISE_UP.x,RISE_UP.y)
		if not last and edge.y+r > a.y+1.2: r = rng.randf_range(RISE_DOWN.x,RISE_DOWN.y)
		up = not up if rng.randf() < 0.8 else up
		var lr := long_reach(r)
		var share := rng.randf_range(LONG_SHARE.x,LONG_SHARE.y)+share_add
		var gap := clampf(lr*share,maxf(hop(r)*HOP_PAST,pump(r)*PUMP_PAST),lr*0.9)
		var near := edge+dir*gap+Vector3.UP*r
		gaps.append("%.1f%+.1f" % [gap,r])
		var top := 0.0
		var c := near
		if not last:
			var stop := p.long_speed*p.long_speed/(2.0*p.brake)
			top = maxf(p.run*rng.randf_range(TOP_SECONDS.x,TOP_SECONDS.y)*(0.82 if hard else 1.0),lr-gap+TAKEOFF*0.5+stop)
			c = near+dir*top*0.5
			out.stones.append({"name":"%s_%d" % [chain,k+1],"at":c,"size":Vector3(top,0.9,top),"yaw":yaw+rng.randf_range(-0.2,0.2),"kind":"block","chain":chain,
				"gap":gap,"rise":r,"pier":true})
		# The step drum, the slow line (not to the far lip: the place's own).
		if not last and rng.randf() < step_odds:
			var s := _step_drum(prev_c,prev_r,c,top*0.5,minf(prev_c.y,c.y)-STEP_DOWN,side*(1.0 if rng.randf() < 0.5 else -1.0),k == 0)
			if not s.is_empty():
				out.stones.append({"name":"%s_step%d" % [chain,k+1],"at":s.at,"size":Vector3(s.d,0.7,s.d),"yaw":yaw+rng.randf_range(-0.5,0.5),"kind":"block","chain":chain,"step":true})
				out.flank.append_array(_line(prev_c,s.at,UNDER,1.0))
				out.flank.append_array(_line(s.at,c,UNDER,1.0))
				steps += 1
		out.path.append_array(_line(prev_c if k > 0 else a,c,UNDER))
		tops.append(c)
		prev_c = c
		prev_r = top*0.5
		edge = near+dir*top
	out.parts.append("%s%d piers (gaps %s), %d step drums" % ["hard " if hard else "",n,", ".join(gaps),steps])
	return edge

## A step drum between the top at `ca` (radius `ra`; the lip if `lip`) and
## the one at `cb` (radius `rb`), its top at `y` (raised so the hop on up
## off it stays under his small jump, less a margin), along the way and
## off it along `aside`, where each hop comes down on what it is aimed at:
## his running hop at its rise lands past its near edge even taken TAKEOFF
## short of his edge, and short of its far edge taken right at it (so the
## drum's own top is the window): {at, d (its top across)}, or {} if none
## fits.
static func _step_drum(ca: Vector3, ra: float, cb: Vector3, rb: float, y: float, aside: Vector3, lip: bool) -> Dictionary:
	var p := pilot()
	var rs := p.run*STEP_SECONDS
	var most := float(p.jumps[0])*0.8
	if cb.y-y > most: y = cb.y-most
	if y > ca.y+0.05: return {}
	var la := hop(y-ca.y)
	var lb := hop(cb.y-y)
	var way := Vector3(cb.x-ca.x,0.0,cb.z-ca.z).normalized()
	for t: float in [0.5,0.42,0.58,0.34,0.66]:
		for off: float in [1.0,0.7,1.3,0.4,0.0]:
			var at := Vector3(ca.x,y,ca.z).lerp(Vector3(cb.x,y,cb.z),t)+aside*off*(ra+rb)*0.5
			var da := (Vector2(at.x-ca.x,at.z-ca.z).length() if not lip else (at-ca).dot(way))-ra-rs
			var db := Vector2(cb.x-at.x,cb.z-at.z).length()-rb-rs
			if da < 0.3 or db < 0.3: continue
			# Onto the drum: lands on its top from anywhere in his takeoff.
			if la-TAKEOFF < da+0.2 or la > da+2.0*rs-0.3: continue
			# Onto the next top: reaches it even taken early (its top is long).
			if lb-TAKEOFF < db+0.2 or lb > db+2.0*rb-0.3: continue
			return {"at":at,"d":rs*2.0}
	return {}

## The spillway: a carved channel on piers, DS m a sample. A flat head on
## the lip, then down at GRADE_DEG (past SLIDE_FROM so a crouch surfs, under
## SLOPE_SLOW so it is walked back up at his pace) through bends of radius
## his surf's top pace squared over LAT (m/s² across: what the bank and the
## trough hand him), each turning BEND degrees (an S of three, or a swerve
## of two; they sum to none, so it leaves along `dir`); the floor banked
## into each bend by the pace he has there (the motor's surf integrated
## down it), up to BANK_MOST; the trough's walls WALL high, the outside of
## a bend up to WALL_OUT; then flat, RUNOUT of the surf's stop from his
## pace at the foot, the walls easing down to the far lip.
const DS := 1.0
const HEAD := 2.0
const GRADE_DEG := Vector2(13.0,17.0)
const EASE := 3.0
const LAT := 4.2
const BEND_SWERVE := Vector2(38.0,55.0)
const BEND_S := Vector2(28.0,40.0)
const BEND_GAP := Vector2(1.0,4.0)
const BANK_MOST := 16.0
const WALL := 0.9
const WALL_OUT := 1.5
const FLOOR := 2.4
const RAMP_DEG := 38.0
const RUNOUT := 0.7
const RUNOUT_LEAST := 7.0
const TAPER := 4.0
static func _slide(out: Dictionary, a: Vector3, dir: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var p := pilot()
	var grade := rng.randf_range(GRADE_DEG.x,GRADE_DEG.y)
	var vt := surf_top(grade)
	var radius := maxf(vt*vt/LAT,8.0)
	var turn := 1.0 if rng.randf() < 0.5 else -1.0
	var bends: Array = []
	if rng.randf() < 0.55:
		var b := deg_to_rad(rng.randf_range(BEND_S.x,BEND_S.y))
		bends = [b*turn,-2.0*b*turn,b*turn]
	else:
		var b := deg_to_rad(rng.randf_range(BEND_SWERVE.x,BEND_SWERVE.y))
		bends = [b*turn,-b*turn]
	# The plan of the centreline: [length, turn rate] pieces, flat head
	# and descent in turn; then the run-out (its length from the pace).
	var pieces: Array = [[HEAD,0.0,false],[EASE+1.0,0.0,true]]
	for i in range(bends.size()):
		pieces.append([absf(float(bends[i]))*radius,float(bends[i])/(absf(float(bends[i]))*radius),true])
		pieces.append([rng.randf_range(BEND_GAP.x,BEND_GAP.y) if i < bends.size()-1 else EASE+1.0,0.0,true])
	var pts: Array = [a]
	var heads: Array = [dir]
	var turns: Array = [0.0]
	var slopes: Array = [0.0]
	var t := dir
	var q := a
	var gt := tan(deg_to_rad(grade))
	var down_len := 0.0
	for pc: Array in pieces: if bool(pc[2]): down_len += float(pc[0])
	var down_at := 0.0
	for pc: Array in pieces:
		var n := maxi(int(round(float(pc[0])/DS)),1)
		var ds := float(pc[0])/n
		for i in range(n):
			var g := 0.0
			if bool(pc[2]):
				# Eased in off the head and out onto the run-out.
				down_at += ds
				g = gt*clampf(minf(down_at,down_len-down_at+ds)/EASE,0.15,1.0)
			var mid_t := t.rotated(Vector3.UP,float(pc[1])*ds*0.5)
			q += mid_t*ds+Vector3.DOWN*g*ds
			t = t.rotated(Vector3.UP,float(pc[1])*ds)
			pts.append(q)
			heads.append(t)
			turns.append(float(pc[1]))
			slopes.append(g)
	# His pace down it (the surf, from a run's crouch): the bank it wants.
	var v := p.run*0.8
	var speeds: Array = [v]
	for i in range(1,pts.size()):
		var g := float(slopes[i])
		var deg := rad_to_deg(atan(g))
		var acc := p.slide_pull*sin(atan(g))-(PilotMotor.SLIDE_DRAG if deg >= PilotMotor.SLIDE_END else p.slide_runout)-p.slide_air*v*v
		v = clampf(sqrt(maxf(v*v+2.0*acc*DS,0.0)),0.0,p.slide_top)
		speeds.append(v)
	var foot_v := v
	# The run-out: flat, RUNOUT of the stop from the foot's pace.
	var stop := 0.0
	var w := foot_v
	while w > PilotMotor.SLIDE_STOP and stop < 60.0:
		w = sqrt(maxf(w*w-2.0*(p.slide_runout+p.slide_air*w*w)*0.25,0.0))
		stop += 0.25
	var run_len := maxf(stop*RUNOUT,RUNOUT_LEAST)
	var runout_from := pts.size()-1
	var n_run := maxi(int(round(run_len/DS)),1)
	for i in range(n_run):
		q += t*(run_len/n_run)
		pts.append(q)
		heads.append(t)
		turns.append(0.0)
		slopes.append(0.0)
		speeds.append(0.0)
	# The bank: across the floor, the rise a metre toward his right that
	# hands him the turn at the pace he has there, smoothed along.
	var raw: Array = []
	var most := tan(deg_to_rad(BANK_MOST))
	for i in range(pts.size()):
		var sv := float(speeds[i])
		raw.append(clampf(sv*sv*float(turns[i])/(p.slide_pull*0.95),-most,most))
	var lean: Array = []
	var wall_l: Array = []
	var wall_r: Array = []
	for i in range(pts.size()):
		var sum := 0.0
		var cnt := 0
		for j in range(maxi(i-3,0),mini(i+4,pts.size())):
			sum += float(raw[j])
			cnt += 1
		var l := sum/cnt
		lean.append(l)
		# The outside of the bend walled higher (left turn: the right side).
		var out_share := absf(l)/most
		var hi := lerpf(WALL,WALL_OUT,out_share)
		var to_end := (pts.size()-1-i)*DS
		var ease := clampf(to_end/TAPER,0.0,1.0)
		var head_ease := clampf(float(i)*DS/HEAD,0.35,1.0)
		var wl := (hi if l < 0.0 else WALL)*ease*head_ease
		var wr := (hi if l > 0.0 else WALL)*ease*head_ease
		wall_l.append(wl)
		wall_r.append(wr)
	var b: Vector3 = pts[pts.size()-1]
	out.chute = {"pts":pts,"heads":heads,"lean":lean,"wall_l":wall_l,"wall_r":wall_r,"floor":FLOOR,"ramp":RAMP_DEG,"grade":grade,
		"runout_from":runout_from,"top_pace":vt,"foot_pace":foot_v,"radius":radius,"bends":bends.map(func(x: float) -> float: return rad_to_deg(x))}
	# The walked line (his corridor) and the walls' (its flanks).
	for i in range(pts.size()):
		out.path.append([pts[i],UNDER,OVER])
		if i%2 == 0:
			var h: Vector3 = heads[i]
			var right := Vector3(-h.z,0.0,h.x)
			var half := FLOOR*0.5+WALL_OUT/tan(deg_to_rad(RAMP_DEG))+0.6
			out.flank.append([(pts[i] as Vector3)+right*half,UNDER,OVER])
			out.flank.append([(pts[i] as Vector3)-right*half,UNDER,OVER])
	var drop := a.y-b.y
	var lng := 0.0
	for i in range(1,pts.size()): lng += Vector2((pts[i] as Vector3).x-(pts[i-1] as Vector3).x,(pts[i] as Vector3).z-(pts[i-1] as Vector3).z).length()
	out.parts.append("spillway %.0f m down %.1f m at %.0f deg, bends %s at r %.0f m, surf top %.1f m/s, run-out %.0f m" % [lng,drop,grade,
		str(out.chute.bends.map(func(x: float) -> int: return roundi(x))),radius,vt,run_len])
	return b
