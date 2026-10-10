extends RefCounted
## How hard each collectible of a moments station is (scripts/flight_pack_moments.gd,
## tools/flight_bench.gd, tools/flight_moments_check.gd), read off the
## station's natural line (FlightMetrics `line` through its guides, flown at
## cruise) and its solids, on three plain axes:
##   fit    the room round it (m): its clearance less half the wingspan, as
##          the rooms measure the line (FlightCourse `survey`); where level
##          wings don't fit there, the better of level and on edge, and
##          `knife` if only on edge fits. Capped at OPEN (open air).
##   react  seconds from first seen to commit, flying the natural line: from
##          the start of the last spell it lies within the run's sight cone
##          (FlightRun CONE, SIGHT) of the line's way with a clear line to it
##          (gaps under LOSE s don't end a spell; a challenge one only once
##          the line has passed the starter), to the last moment the
##          plane can start bending off the line for it (`lead` before the
##          line passes it). Negative: from the line it can't be seen in time
##          (a second pass, or braking). Never seen before the line passes
##          it: minus the lead.
##   reach  its distance off the natural line (m); `beyond` is that less its
##          pickup reach, the sideways step the plane has to make.
## The lead (s): a sidestep of `beyond` m as a half cosine at full TURN_RATE
## at cruise, plus the roll in (FlightMetrics ROLL_IN) if it has to step at
## all, plus the roll up on edge (FlightMetrics KNIFE_IN) if it needs the
## knife edge.
## Also, for laying them out: where along the line it is (`at_s`, s from the
## entry), the time on to the next moment (`next_s`) and to the next tight
## stretch of the line (`tight_s`: the line's room under TIGHT m), so a hard
## grab has room to recover before the next opening.
## Its band (`band`) comes from the bench: the least bot skill that gets it in
## at least GET_SHARE of its runs (a challenge collectible: of the runs that
## started the challenge).

const Course = preload("res://scripts/flight_course.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const Run = preload("res://scripts/flight_run.gd")

const OPEN := 9.9
const TIGHT := 1.0
const GET_SHARE := 0.6
## Line samples tested for sight (every this many of the line's STEP m).
const SIGHT_STRIDE := 2
## Out of view this long (s) and a moment counts as not seen yet.
const LOSE := 2.0
const ROLES := ["free","starter","challenge"]
const KINDS := ["fit","react","reach"]

## Each moment of station `s` measured (see the header): [{"i", "role",
## "kind", "note", "at", "reach", "fit", "knife", "react", "seen", "off",
## "beyond", "lead", "at_s", "next_s", "tight_s"}]. Sight uses `space`'s
## physics (the station built in it); with none, the solids' own rays.
static func measure(s: Dictionary, space: PhysicsDirectSpaceState3D = null) -> Array:
	var entry := Course.entry(s)
	var line := Metrics.line(entry.position,entry.heading,Course.tokens(s))
	var all := Course.solids(s)
	var arc := PackedFloat32Array([0.0])
	for i in range(1,line.size()): arc.append(arc[i-1]+(line[i].p as Vector3).distance_to(line[i-1].p))
	var v := Metrics.CRUISE
	# Where the line is tight (its room under TIGHT), by sample.
	var tight := PackedByteArray()
	for i in range(line.size()): tight.append(1 if Course.clearance(all,line[i].p)-Course.SPAN*0.5 < TIGHT else 0)
	var out := []
	var list := Course.moments(s)
	# A challenge collectible is there only from when the starter is taken.
	var revealed := 0
	for m: Dictionary in list:
		if m.role == "starter": revealed = _nearest(line,m.at)
	for k in range(list.size()):
		var m: Dictionary = list[k]
		var p: Vector3 = m.at
		var near := _nearest(line,p)
		var way := _way(line,near)
		var room := spot_room(all,p,way)
		var off := p.distance_to(line[near].p)
		var beyond := maxf(0.0,off-float(m.reach))
		var lead := 0.0
		if beyond > 0.0:
			lead += PI*sqrt(beyond*v/(2.0*Metrics.TURN_RATE))/v+Metrics.ROLL_IN
		if room.knife: lead += Metrics.KNIFE_IN
		# Seen: the start of the last spell in view before the line passes
		# it (out of view for under LOSE s doesn't end a spell; on a line
		# that curls back, a glimpse across the loop long before doesn't
		# count). A challenge one from where the line passes the starter.
		var seen := -1
		var lost_at := -1
		for i in range(revealed if m.role == "challenge" else 0,near+1,SIGHT_STRIDE):
			var q: Vector3 = line[i].p
			var d := p-q
			var in_view := d.length() <= Run.SIGHT and _way(line,i).angle_to(d) <= Run.CONE and _clear(space,all,q,p)
			if in_view:
				if seen < 0: seen = i
				lost_at = -1
			elif seen >= 0:
				if lost_at < 0: lost_at = i
				if (arc[i]-arc[lost_at])/v > LOSE: seen = -1
		var react := -lead
		if seen >= 0: react = (arc[near]-arc[seen])/v-lead
		var tight_s := INF
		for i in range(near,line.size()):
			if tight[i] == 1 and i > near+2:
				tight_s = (arc[i]-arc[near])/v
				break
		out.append({"i":k,"role":m.role,"kind":m.kind,"note":m.note,"at":p,"reach":float(m.reach),
			"fit":minf(room.room,OPEN),"knife":room.knife,"react":react,"seen":seen >= 0,"off":off,"beyond":beyond,"lead":lead,
			"at_s":arc[near]/v,"next_s":INF,"tight_s":tight_s})
	# The time on to the next moment along the line.
	var order := range(out.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(out[a].at_s) < float(out[b].at_s))
	for j in range(order.size()-1): out[order[j]].next_s = float(out[order[j+1]].at_s)-float(out[order[j]].at_s)
	return out

## The room round point `p` (see the header), the plane flying along `way`:
## {"room", "knife"}.
static func spot_room(all: Array, p: Vector3, way: Vector3) -> Dictionary:
	var room := Course.clearance(all,p)-Course.SPAN*0.5
	if room >= 0.0: return {"room":room,"knife":false}
	var level := way.cross(Vector3.UP)
	level = level.normalized() if level.length() > 0.01 else Vector3.RIGHT
	var edge := level.cross(way).normalized()
	var flat := Course.wing_room(all,p,level)
	var on_edge := Course.wing_room(all,p,edge)
	return {"room":maxf(room,maxf(flat,on_edge)),"knife":flat < 0.0 and on_edge >= flat+Course.KNIFE_BETTER}

## The band of a collectible got in `rates` ({"sloppy": 0.7, ...}): the least
## skill getting it in GET_SHARE of its runs (FlightMetrics BANDS), "none" if
## no bot does.
static func band(rates: Dictionary) -> String:
	for k: String in Metrics.SKILLS:
		if rates.has(k) and float(rates[k]) >= GET_SHARE: return Metrics.BANDS[k]
	return "none"

static func _nearest(line: Array, p: Vector3) -> int:
	var best := INF
	var at := 0
	for i in range(line.size()):
		var d := p.distance_squared_to(line[i].p)
		if d < best:
			best = d
			at = i
	return at

static func _way(line: Array, i: int) -> Vector3:
	var a: Vector3 = line[maxi(i-1,0)].p
	var b: Vector3 = line[mini(i+1,line.size()-1)].p
	return (b-a).normalized() if a.distance_to(b) > 0.0001 else Vector3.FORWARD

## A clear line from `a` to `b`: physics if there is a space, else every
## solid's own ray (FlightMetrics `ray_hits`).
static func _clear(space: PhysicsDirectSpaceState3D, all: Array, a: Vector3, b: Vector3) -> bool:
	if space != null: return Course.line_clear(space,a,b)
	var d := b-a
	var length := d.length()
	if length < 0.001: return true
	for solid: Dictionary in all:
		if Metrics.ray_hits(solid,a,d/length,length): return false
	return true
