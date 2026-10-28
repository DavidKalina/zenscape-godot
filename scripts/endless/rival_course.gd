extends RefCounted
## A rival race's course (scripts/endless/rival_race.gd), planned once from
## the start line and never again: GATES_LEAST to GATES_MOST gates in a
## row, the openings the rival can thread (rival_line.gd `_candidates`:
## arches, split mountains, slot halls, tunnels, and the amberlands' set
## pieces' and bridges' lines, rival_pieces.gd), chained so each next one
## is ahead of the last one's way out: its lead-in GATE_NEAR to GATE_REACH m
## on, within CONE of the way out, and gone into the way it is come at
## (ALIGN). Where no opening is in reach an air gate stands down the
## lowest way ahead (LEG m on, within LEG_SPREAD), AIR_OVER m over what
## stands under its frame, its frame clear of the land; so a course always
## has at least GATES_LEAST gates.
##
## The course: {points (the route: [{p, room, bore, lead}], lead the legs
## between gates, flown low over the land), lens (m along it, XZ), gates
## ([{id, kind, p (the mouth's middle), dir (the way through, XZ), half_w,
## lo, hi (the mouth's floor and top, world y), s (m along at the mouth),
## through (m along at its middle)}]), line (the ribbon: a point every
## LINE_STEP m along, at the height flown), length}.
##
## The line's height: on the legs between gates LOW over what stands ahead
## (rival_line.gd's own read, spans counted, asking CLIMB_SLOPE less a
## metre further on), settling onto the next opening's height over its
## last LEAD_SETTLE m; through an opening the opening's own; off the start
## line a climb of CLIMB_OUT m a metre from RUNWAY m on.

const WorldScale = preload("res://scripts/world_scale.gd")

## Gates: at least, at most; the course's most length (m).
const GATES_LEAST := 3
const GATES_MOST := 5
const LENGTH_MOST := 4200.0
## The run along the ground off the start (m) and the climb out after it
## (m up a metre); the line's height over the ground on the run (m).
const RUNWAY := 90.0
const CLIMB_OUT := 0.16
const RUN_Y := 2.5
## The next gate's lead-in: this far on (m), within CONE (rad) of the way
## out of the last, its way within ALIGN (cos) of the way to it and of the
## way out.
const GATE_NEAR := 220.0
const GATE_REACH := 1300.0
const CONE := 0.85
const ALIGN := 0.55
const ALIGN_OUT := 0.2
## An air gate: LEG m on (each of CANDIDATES), within LEG_SPREAD (rad) of
## the way; half its width and height (wingspans); its bottom AIR_OVER m
## over the highest of what stands under its frame, and its middle as far
## over what stands along its way in and out; of the candidates the one
## lowest over its frame and the leg to it; its lead-in and run out (m).
const LEG := Vector2(420.0,620.0)
const LEG_SPREAD := 0.55
const CANDIDATES := 9
const AIR_HALF := Vector2(4.5,2.6)
const AIR_OVER := 9.0
const AIR_IN := 90.0
const AIR_OUT := 70.0
## A split's gate reaches up to its lower wall, read this far past its
## floor's edge (m), at least SPLIT_TOP_LEAST over the line.
const SPLIT_WALL := 12.0
const SPLIT_TOP_LEAST := 6.0
## A hall's and a tunnel's gate top over their floor (m).
const HALL_TOP := 16.0
const TUNNEL_TOP := 16.0
## The line: a point every LINE_STEP m; on the legs LOW over the ground
## ahead, read up to READ_AHEAD m on (asking CLIMB_SLOPE less a metre), no
## nearer LOW_LEAST to it; it settles onto the opening's height over the
## last LEAD_SETTLE m of a leg.
const LINE_STEP := 4.0
const READ_AHEAD := 200.0

## The course from `start` (the start line, on the ground) facing `axis`.
static func plan(line: RefCounted, start: Vector3, axis: Vector3) -> Dictionary:
	axis = Vector3(axis.x,0.0,axis.z).normalized()
	var p0 := start+Vector3.UP*RUN_Y
	var points: Array = [{"p":p0,"room":INF,"bore":false,"lead":true}]
	var cur := start+axis*RUNWAY
	var way := axis
	var gates: Array = []
	var used := {}
	var length := RUNWAY
	while gates.size() < GATES_MOST and length < LENGTH_MOST:
		var c := _next_opening(line,cur,way,used)
		if c.is_empty():
			if gates.size() >= GATES_LEAST: break
			c = _air_gate(line,cur,way,gates.size())
		used[c.id] = true
		var pts: Array = c.points
		var entry: Vector3 = pts[0].p
		length += Vector2(entry.x-cur.x,entry.z-cur.z).length()
		# The leg to it, then its own points; its run out is the next leg's
		# start.
		points.append({"p":cur,"room":INF,"bore":false,"lead":true})
		# Its points out in the open (a split's or a hall's way in, no room
		# given) are flown as the legs are.
		for i in range(pts.size()):
			var q: Dictionary = (pts[i] as Dictionary).duplicate()
			q.lead = i == pts.size()-1 or float(q.room) == INF
			points.append(q)
		var last: Vector3 = pts[pts.size()-1].p
		var before: Vector3 = pts[pts.size()-2].p
		for i in range(1,pts.size()):
			var a: Vector3 = pts[i-1].p
			var b: Vector3 = pts[i].p
			length += Vector2(b.x-a.x,b.z-a.z).length()
		var g := _gate(line,c)
		g.at = points.size()-pts.size()
		gates.append(g)
		# The run out ends the leg; the next leg begins past it.
		points.pop_back()
		cur = last
		way = Vector3(last.x-before.x,0.0,last.z-before.z).normalized()
	points.append({"p":cur,"room":INF,"bore":false,"lead":true})
	var lens := PackedFloat32Array([0.0])
	for i in range(1,points.size()):
		var a: Vector3 = points[i-1].p
		var b: Vector3 = points[i].p
		lens.append(lens[i-1]+Vector2(b.x-a.x,b.z-a.z).length())
	for g: Dictionary in gates:
		var at := int(g.at)
		g.s = lens[at+int(g.mouth)]
		g.through = lens[at+int(g.through_i)]
	var course := {"points":points,"lens":lens,"gates":gates,"length":lens[lens.size()-1],"line_step":LINE_STEP}
	course.line = _line(line,course)
	return course

## The nearest opening ahead of `cur` going `way`, not `used`, or {}.
static func _next_opening(line: RefCounted, cur: Vector3, way: Vector3, used: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	for c: Dictionary in line._candidates(cur):
		if used.has(c.id): continue
		var pts: Array = c.points
		var entry: Vector3 = pts[0].p
		var to := Vector3(entry.x-cur.x,0.0,entry.z-cur.z)
		var d := to.length()
		if d < GATE_NEAR or d > GATE_REACH: continue
		var off := absf(Vector2(way.x,way.z).angle_to(Vector2(to.x,to.z)))
		if off > CONE: continue
		var nxt: Vector3 = pts[1].p
		var w := Vector3(nxt.x-entry.x,0.0,nxt.z-entry.z).normalized()
		if w.dot(to.normalized()) < ALIGN or w.dot(way) < ALIGN_OUT: continue
		var score := d*(1.0+off/CONE)
		if score < best_score:
			best_score = score
			best = c
	return best

## An air gate down the lowest way ahead of `cur`: an opening candidate's
## shape ({id, kind "air", points, through, mouth, half_w, lo, hi}).
static func _air_gate(line: RefCounted, cur: Vector3, way: Vector3, n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([line._salt,"air",n])
	var half_w := WorldScale.span*AIR_HALF.x
	var half_h := WorldScale.span*AIR_HALF.y
	var heading := atan2(-way.x,-way.z)
	var best: Dictionary = {}
	var best_y := INF
	for i in range(CANDIDATES):
		var a := heading+rng.randf_range(-LEG_SPREAD,LEG_SPREAD)
		var at := cur+Vector3(-sin(a),0.0,-cos(a))*rng.randf_range(LEG.x,LEG.y)
		var w := Vector3(at.x-cur.x,0.0,at.z-cur.z).normalized()
		var across := w.cross(Vector3.UP)
		# What stands under its frame, and along its way in and out (its
		# lead-in to its run out, half its width each side).
		var top := -INF
		for u: float in [-half_w,-half_w*0.5,0.0,half_w*0.5,half_w]:
			for v: float in [-12.0,0.0,12.0]:
				top = maxf(top,float(line._ground_top(at+across*u+w*v,true)))
		var way_top := -INF
		var v2 := -AIR_IN
		while v2 <= AIR_OUT:
			for u: float in [-half_w*0.5,0.0,half_w*0.5]:
				way_top = maxf(way_top,float(line._ground_top(at+across*u+w*v2,true)))
			v2 += 10.0
		top = maxf(maxf(top,way_top-half_h),SEA_Y_AIR)
		# The leg to it: what it crosses on the way counts too (a ridge
		# between asks a climb over it).
		var leg_top := -INF
		var d := 0.0
		var to := at-cur
		to.y = 0.0
		while d <= to.length():
			leg_top = maxf(leg_top,float(line._ground_top(cur+to.normalized()*d,true)))
			d += 25.0
		var score := maxf(top,leg_top-AIR_OVER-half_h)
		if score < best_y:
			best_y = score
			var c := at
			c.y = top+AIR_OVER+half_h
			best = {"c":c,"w":w}
	var c: Vector3 = best.c
	var w: Vector3 = best.w
	var pts: Array = [_pt(c-w*AIR_IN,half_w),_pt(c,half_w),_pt(c+w*AIR_OUT,INF)]
	pts[0].air = true
	pts[1].air = true
	return {"id":"air/%d" % n,"kind":"air","points":pts,"through":1,"mouth":1,"half_w":half_w,"lo":c.y-half_h,"hi":c.y+half_h}

const SEA_Y_AIR := -40.0

static func _pt(p: Vector3, room: float) -> Dictionary:
	return {"p":p,"room":room,"bore":false,"lead":false}

## The gate of opening candidate `c`: {id, kind, p, dir, half_w, lo, hi,
## mouth, through_i}.
static func _gate(line: RefCounted, c: Dictionary) -> Dictionary:
	var game: Node = line.game
	var pts: Array = c.points
	var m := clampi(int(c.mouth),1,pts.size()-2)
	var a: Vector3 = pts[m-1].p
	var b: Vector3 = pts[m+1].p
	var dir := Vector3(b.x-a.x,0.0,b.z-a.z).normalized()
	var p: Vector3 = pts[m].p
	var room := float(pts[m].room)
	var kind := String(c.kind)
	var half_w := room if room < INF else WorldScale.span*AIR_HALF.x
	var lo := p.y-WorldScale.span
	var hi := p.y+WorldScale.span
	if c.has("lo"):
		lo = float(c.lo)
		hi = float(c.hi)
		half_w = float(c.get("half_w",half_w))
	elif kind == "split":
		var across := dir.cross(Vector3.UP)
		lo = p.y-line.SPLIT_FLY-1.0
		var l := float(game.field.height(p.x+across.x*(room+SPLIT_WALL),p.z+across.z*(room+SPLIT_WALL)))
		var r := float(game.field.height(p.x-across.x*(room+SPLIT_WALL),p.z-across.z*(room+SPLIT_WALL)))
		hi = maxf(minf(l,r),p.y+SPLIT_TOP_LEAST)
	elif kind == "hall":
		var hc: Vector3 = c.hall[0]
		lo = hc.y-1.0
		hi = hc.y+HALL_TOP
	elif kind == "tunnel":
		lo = p.y-line.TUNNEL_FLY-1.0
		hi = lo+TUNNEL_TOP
	var g := {"id":String(c.id),"kind":kind,"p":p,"dir":dir,"half_w":half_w,"lo":lo,"hi":hi,"mouth":m,"through_i":int(c.through)}
	if c.has("hall"): g.hall = c.hall
	return g

## The ribbon's points: one every LINE_STEP m along the route, at the
## height flown (see the header). What stands is read once a point (spans
## counted) and the read ahead taken off those.
static func _line(line: RefCounted, course: Dictionary) -> PackedVector3Array:
	var points: Array = course.points
	var lens: PackedFloat32Array = course.lens
	var total := lens[lens.size()-1]
	var n := int(total/LINE_STEP)+1
	# Where each point's leg ends (m along), for the settle and the read.
	var lead_end := PackedFloat32Array()
	lead_end.resize(points.size())
	var end := total
	for i in range(points.size()-1,-1,-1):
		if not bool(points[i].lead): end = lens[i]
		lead_end[i] = end
	var xz := PackedVector3Array()
	var segs := PackedInt32Array()
	var tops := PackedFloat32Array()
	var lows := PackedFloat32Array()
	var seg := 0
	for k in range(n):
		var s := minf(k*LINE_STEP,total)
		while seg < points.size()-2 and lens[seg+1] < s: seg += 1
		var a: Dictionary = points[seg]
		var b: Dictionary = points[seg+1]
		var u := clampf((s-lens[seg])/maxf(lens[seg+1]-lens[seg],0.001),0.0,1.0)
		var q: Vector3 = (a.p as Vector3).lerp(b.p,u)
		xz.append(q)
		segs.append(seg)
		tops.append(float(line._ground_top(q,true)) if bool(a.lead) else 0.0)
		lows.append(float(line._ground_top(q,false)))
	var reach := int(READ_AHEAD/LINE_STEP)
	var out := PackedVector3Array()
	for k in range(n):
		var s := minf(k*LINE_STEP,total)
		var i := segs[k]
		var a: Dictionary = points[i]
		var b: Dictionary = points[i+1]
		var q := xz[k]
		if bool(a.lead):
			var left := lead_end[i]-s
			# LOW over what stands ahead, read up to the leg's end.
			var low := -INF
			var j := k
			while j < n and j <= k+reach and (j-k)*LINE_STEP <= left+0.1:
				low = maxf(low,tops[j]+line.LOW-(j-k)*LINE_STEP*line.CLIMB_SLOPE)
				j += 1
			var y := low
			if lead_end[i] < total:
				var line_y := (points[_index_at(lens,lead_end[i])].p as Vector3).y
				y = lerpf(low,line_y,smoothstep(line.LEAD_SETTLE,line.LEAD_SETTLE*0.25,left))
			y = maxf(y,lows[k]+line.LOW_LEAST)
			# Off the start line: the run along the ground, then the climb;
			# never under what stands there (spans counted).
			if s < RUNWAY+400.0:
				y = minf(y,maxf(lows[k]+RUN_Y,(points[0].p as Vector3).y+maxf(s-RUNWAY,0.0)*CLIMB_OUT))
				y = maxf(y,maxf(lows[k]+RUN_Y,tops[k]+line.LOW_LEAST))
			q.y = y
		elif not bool(a.bore) or not bool(b.bore): q.y = maxf(q.y,lows[k]+line.LOW_LEAST*0.5)
		out.append(q)
	return out

static func _index_at(lens: PackedFloat32Array, s: float) -> int:
	for i in range(lens.size()):
		if lens[i] >= s-0.01: return i
	return lens.size()-1

## The ribbon's point `s` m along (`line` evenly spaced, LINE_STEP apart).
static func at(course: Dictionary, s: float) -> Vector3:
	var pts: PackedVector3Array = course.line
	var f := clampf(s/LINE_STEP,0.0,float(pts.size()-1))
	var i := mini(int(f),pts.size()-2)
	return pts[i].lerp(pts[i+1],f-i)

## How far along the course `p` is (m, XZ), searched from `near` m within
## `back` m behind and `ahead` m on.
static func project(course: Dictionary, p: Vector3, near: float, back := 80.0, ahead := 400.0) -> float:
	var pts: PackedVector3Array = course.line
	var i0 := maxi(0,int((near-back)/LINE_STEP))
	var i1 := mini(pts.size()-1,int((near+ahead)/LINE_STEP)+1)
	var best := near
	var best_d := INF
	for i in range(i0,i1):
		var a := Vector2(pts[i].x,pts[i].z)
		var b := Vector2(pts[i+1].x,pts[i+1].z)
		var ab := b-a
		var l2 := ab.length_squared()
		var u := clampf((Vector2(p.x,p.z)-a).dot(ab)/l2,0.0,1.0) if l2 > 0.0001 else 0.0
		var d := (a+ab*u).distance_to(Vector2(p.x,p.z))
		if d < best_d:
			best_d = d
			best = (i+u)*LINE_STEP
	return best

## How far `p` is from the course's ribbon near `s` (m, 3D).
static func off(course: Dictionary, p: Vector3, s: float) -> float:
	return at(course,s).distance_to(p)
