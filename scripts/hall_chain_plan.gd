extends RefCounted
## The hall chain's placement (docs/design/hall-chain.md): where each next
## Sundered hall stands, off the one before's exit. Plain data, seeded, the
## same every time for a seed.
##
## A hall is the hall rise's hall (scripts/hall_rise_plan.gd: the moments
## hall, its station metres, the entry at 0 flying north), stood in the
## world by a pose: a turn about up (`yaw`) and an origin. Its natural line
## (sky_moments_plan.gd `line`) comes in at the gate heading IN_HEAD (bay 0's
## heading), swings right through the hall and goes out past the apse
## heading OUT_HEAD (the line's last leg), about 68 degrees right of where it
## came in.
##
## By default (`mirror`) the halls alternate hands: every other hall is
## the hall mirrored across its length (`local`, RisePlan.mirrored), so it
## swings you 68 degrees left where the one before swung you right. So the
## next hall's way in can stand straight ahead of the exit, on the heading
## you leave on, and the chain still runs on as an S, never curling round.
## Without mirror, the gap's arc swings you back what the hall swung
## (`neutral`), about 70 degrees, and the next gate stands well off to the
## side as you leave.
##
## On top of that the next way in swings a seeded `turn` (within
## +-`turn` degrees, pulled back by the turns drawn so far so the chain
## wanders but never drifts round) off that heading, and the hall steps
## `climb` m up or down (within +-`climb`, kept between CLEAR_RANGE m over
## the cloud top). Its way in (LEAD_IN m before the line's first point
## along the in-heading) stands `gap` m from the exit, along the heading
## half way between the exit's heading and its own way in: so one circular
## arc, tangent at both ends, carries the plane from the one hall's exit
## into the next one's gate. A next hall that would stand on one already
## up is drawn again (TRIES), and failing that stood on the pull alone.
##
## `pose`: {yaw (rad), origin (Vector3, world), hand (1 or -1), index,
## turn, drift, climb, swing}. `hall_route` and `arc` give the points a
## plane flies, hall by hall: its way in, its lane, the arc out.

const RisePlan = preload("res://scripts/hall_rise_plan.gd")
const Plan = preload("res://scripts/sky_moments_plan.gd")
const Course = preload("res://scripts/flight_course.gd")

## The chain's defaults, all tunable by flag (scripts/hall_chain.gd
## `options`):
##   at      share of the way along a hall's line where the plane sets the
##           next one rising (0-1)
##   gap     m from a hall's exit to the next one's way in (the arc's chord)
##   turn    degrees, the most the next hall's way in swings off the line
##           you leave on (with mirror, off dead ahead)
##   climb   m, the most one hall stands over or under the one before
##   keep    how many halls stand at once; past it the oldest sinks (0:
##           all stay)
##   seed    the placement's seed
##   mirror  the halls alternate hands (one swings right, the next is the
##           hall mirrored and swings left), so the next one can stand
##           straight ahead of the exit without the chain curling round
const CHAIN := {"at":0.4,"gap":70.0,"turn":8.0,"climb":2.0,"keep":8,"seed":3,"mirror":true}
## The way in starts this far (m) before the line's first point.
const LEAD_IN := 25.0
## How hard a next hall's turn is pulled back by the turns drawn so far
## (share of them, a hall).
const PULL := 0.5
## Each hall's lowest stone stays this many metres over the cloud top.
const CLEAR_RANGE := Vector2(8.0,24.0)
## Two halls keep this far apart (m, between their chunks' boxes, flat).
const APART := 12.0
const TRIES := 8
## Arc points every this many metres.
const ARC_STEP := 4.0

## The cruise lane (`lane`): a sample every LANE_STEP m along the line; the
## heights tried (m, station: from, to, step; the top is under the gate
## half's roof and about level with the far half's wall tops, so the lane
## stays in the hall); the clearance every point keeps off stone (m); the
## clearance it would like (m); the most it climbs or drops from one
## sample to the next (m).
const LANE_STEP := 3.0
const LANE_Y := Vector3(-8.0,6.0,0.5)
const LANE_CLEAR := 1.3
const LANE_WANT := 2.2
const LANE_SLOPE := 1.0

static var _line: Array[Vector3] = []
static var _lane: Array[Vector3] = []

## The hall's natural line (station metres), cached.
static func line() -> Array[Vector3]:
	if _line.is_empty(): _line = Plan.line(RisePlan.LAYOUT)
	return _line

## The cruise lane (station metres), cached: the natural line's way across
## the ground, but at the smoothest height that keeps LANE_CLEAR off stone.
## The natural line weaves over and under the tie beams (a moments line, a
## challenge at speed); the lane flies level-ish through the gaps between
## them, as a casual pilot would, so the autopilot and the route marks
## show a line you can hold at cruise. Found once (a shortest path over
## the heights, climbing at most LANE_SLOPE a sample, paying for every
## metre of height change and for clearance under LANE_WANT).
static func lane() -> Array[Vector3]:
	if not _lane.is_empty(): return _lane
	var solids := Plan.local_solids(RisePlan.LAYOUT)
	var l := line()
	var pts: Array[Vector3] = []
	for i in range(1,l.size()):
		var n := maxi(1,int(ceil(l[i].distance_to(l[i-1])/LANE_STEP)))
		for k in range(n): pts.append(l[i-1].lerp(l[i],float(k)/float(n)))
	pts.append(l[-1])
	var ny := int(round((LANE_Y.y-LANE_Y.x)/LANE_Y.z))+1
	var reach := int(round(LANE_SLOPE/LANE_Y.z))
	var cost := []
	var from := []
	for s in range(pts.size()):
		var p: Vector3 = pts[s]
		var near := []
		for q: Dictionary in solids:
			var e := Plan.extent(q)
			var m: Vector3 = q.middle
			if absf(m.x-p.x) < e.x+LANE_WANT+1.0 and absf(m.z-p.z) < e.z+LANE_WANT+1.0: near.append(q)
		var row := PackedFloat32Array()
		var back := PackedInt32Array()
		row.resize(ny)
		back.resize(ny)
		for j in range(ny):
			var y := LANE_Y.x+LANE_Y.z*j
			var clear := INF
			for q: Dictionary in near: clear = minf(clear,Course.distance(q,Vector3(p.x,y,p.z)))
			var own := INF if clear < LANE_CLEAR else maxf(0.0,LANE_WANT-clear)*4.0
			# The first sample: near the line's own height (the way in).
			if s == 0:
				row[j] = own+absf(y-p.y)
				back[j] = -1
				continue
			var best := INF
			var at := -1
			var prev: PackedFloat32Array = cost[s-1]
			for d in range(-reach,reach+1):
				var k := j+d
				if k < 0 or k >= ny: continue
				var c := prev[k]+absf(d*LANE_Y.z)*1.5+(d*LANE_Y.z)*(d*LANE_Y.z)
				if c < best:
					best = c
					at = k
			row[j] = best+own
			back[j] = at
		cost.append(row)
		from.append(back)
	var last: PackedFloat32Array = cost[-1]
	var j := 0
	for k in range(ny):
		if last[k] < last[j]: j = k
	var ys := PackedFloat32Array()
	ys.resize(pts.size())
	for s in range(pts.size()-1,-1,-1):
		ys[s] = LANE_Y.x+LANE_Y.z*j
		j = (from[s] as PackedInt32Array)[j]
		if j < 0: j = 0
	_lane = []
	for s in range(pts.size()): _lane.append(Vector3(pts[s].x,ys[s],pts[s].z))
	return _lane

## The way in (station metres): LEAD_IN before the line's first point, at its
## height, along IN_HEAD.
static func approach() -> Vector3:
	return line()[0]-ahead(in_head())*LEAD_IN

## The heading (rad, 0 north, right negative) the line comes in on: bay 0's.
static func in_head() -> float:
	return float(RisePlan._bay_part(0)[2])

## The heading the line goes out on: its last leg's.
static func out_head() -> float:
	var l := line()
	return heading_of(l[-1]-l[-2])

## Flat unit vector for heading `h` (0 is -z, as SkyPlane's).
static func ahead(h: float) -> Vector3:
	return Vector3(-sin(h),0.0,-cos(h))

static func heading_of(d: Vector3) -> float:
	return atan2(-d.x,-d.z)

## The settings: CHAIN with any given.
static func settings(opts := {}) -> Dictionary:
	var out := CHAIN.duplicate()
	for key: String in CHAIN:
		if opts.has(key): out[key] = opts[key]
	out.at = clampf(float(out.at),0.0,1.0)
	out.gap = maxf(20.0,float(out.gap))
	out.turn = clampf(float(out.turn),0.0,60.0)
	out.climb = maxf(0.0,float(out.climb))
	out.keep = maxi(0,int(out.keep))
	out.seed = int(out.seed)
	out.mirror = bool(out.mirror)
	return out

## A pose's transform: station metres to world (a turn only; a mirrored
## hall's points are mirrored first, `local`).
static func xform(pose: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,float(pose.yaw)),pose.origin)

## The hall's own station point `p` for a hall of hand `hand` (1 as built,
## -1 mirrored across its length, so it swings left instead of right).
static func local(p: Vector3, hand: int) -> Vector3:
	return Vector3(p.x*float(hand),p.y,p.z)

static func hand_of(pose: Dictionary) -> int:
	return int(pose.get("hand",1))

## The heading (world) a hall at `pose` is come into on, and left on.
static func in_heading(pose: Dictionary) -> float:
	return float(pose.yaw)+float(hand_of(pose))*in_head()

static func out_heading(pose: Dictionary) -> float:
	return float(pose.yaw)+float(hand_of(pose))*out_head()

## The exit point (world) and heading of a hall standing at `pose`.
static func exit_of(pose: Dictionary) -> Array:
	return [xform(pose)*local(line()[-1],hand_of(pose)),out_heading(pose)]

## The first hall's origin height that stands its lowest stone `clear` m
## over the cloud top `sea_top` (world).
static func origin_y_for(clear: float, sea_top: float, lowest: float) -> float:
	return sea_top+clear-lowest

## The swing (rad, left positive) from one hall's exit heading to the next
## one's way in that keeps the chain on course with no draw: none when the
## halls alternate hands (the next one swings back what this one swung),
## and this hall's own swing back when they don't (the gap's arc undoes it).
static func neutral(prev: Dictionary, next_hand: int) -> float:
	if next_hand != hand_of(prev): return 0.0
	return -float(hand_of(prev))*wrapf(out_head()-in_head(),-PI,PI)

## The next hall's pose after `prev`, `rng` drawn from (seeded by the
## caller), avoiding `standing` (poses of the halls up now). `y_range` is
## the origin heights allowed (from CLEAR_RANGE). `hall_boxes` are the
## hall's chunks' boxes (station metres, as built), for keeping apart.
## With cfg.mirror the hands alternate. The drawn turn is pulled back by
## the turns drawn so far (`drift`), so the chain never curls round.
static func next_pose(prev: Dictionary, rng: RandomNumberGenerator, cfg: Dictionary, y_range: Vector2, standing: Array, hall_boxes: Array) -> Dictionary:
	var limit := deg_to_rad(float(cfg.turn))
	var hand := -hand_of(prev) if bool(cfg.get("mirror",true)) else hand_of(prev)
	var drift := float(prev.get("drift",0.0))
	var best := {}
	for attempt in range(TRIES+1):
		var draw := rng.randf_range(-1.0,1.0)
		var turn := clampf(draw*limit-drift*PULL,-limit,limit)
		if attempt == TRIES: turn = clampf(-drift*PULL,-limit,limit)
		var dy := rng.randf_range(-1.0,1.0)*float(cfg.climb)
		var y := clampf(float(prev.origin.y)+dy,y_range.x,y_range.y)
		var pose := place(prev,neutral(prev,hand)+turn,y,float(cfg.gap),hand)
		pose.turn = turn
		pose.drift = drift+turn
		pose.climb = y-float(prev.origin.y)
		best = pose
		if not overlaps(pose,standing,hall_boxes): return pose
	return best

## The pose of hand `hand` whose way in swings `swing` (rad, left positive)
## from `prev`'s exit heading, its origin at height `y`, its way in `gap` m
## from `prev`'s exit (the chord of the arc between them).
static func place(prev: Dictionary, swing: float, y: float, gap: float, hand := 1) -> Dictionary:
	var out_pt: Array = exit_of(prev)
	var p: Vector3 = out_pt[0]
	var x := float(out_pt[1])
	var q := p+ahead(x+swing*0.5)*gap
	var yaw := x+swing-float(hand)*in_head()
	var turned := Basis(Vector3.UP,yaw)*local(approach(),hand)
	var origin := Vector3(q.x-turned.x,y,q.z-turned.z)
	return {"yaw":yaw,"origin":origin,"hand":hand,"index":int(prev.get("index",0))+1,"swing":swing}

## The way in, in the world, for a hall at `pose`.
static func approach_of(pose: Dictionary) -> Vector3:
	return xform(pose)*local(approach(),hand_of(pose))

## Hall boxes (station metres, as built) for a hall of hand `hand`.
static func boxes_for(hall_boxes: Array, hand: int) -> Array:
	if hand > 0: return hall_boxes
	var out := []
	for b: AABB in hall_boxes: out.append(AABB(Vector3(-b.end.x,b.position.y,b.position.z),b.size))
	return out

## Whether a hall at `pose` would stand within APART of any of `standing`
## (flat: each chunk's box turned with its hall, checked by points every
## 6 m over it against the others' boxes grown by APART).
static func overlaps(pose: Dictionary, standing: Array, hall_boxes: Array) -> bool:
	var mine := xform(pose)
	var my_boxes := boxes_for(hall_boxes,hand_of(pose))
	for other: Dictionary in standing:
		if int(other.get("index",-1)) == int(pose.get("index",-2)): continue
		var back := xform(other).affine_inverse()
		var theirs := boxes_for(hall_boxes,hand_of(other))
		for b: AABB in my_boxes:
			for p: Vector3 in _samples(b):
				var at := back*(mine*p)
				for o: AABB in theirs:
					if at.x > o.position.x-APART and at.x < o.end.x+APART and at.z > o.position.z-APART and at.z < o.end.z+APART: return true
	return false

static func _samples(b: AABB) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var nx := maxi(1,int(ceil(b.size.x/6.0)))
	var nz := maxi(1,int(ceil(b.size.z/6.0)))
	for ix in range(nx+1):
		for iz in range(nz+1):
			out.append(Vector3(b.position.x+b.size.x*float(ix)/float(nx),b.get_center().y,b.position.z+b.size.z*float(iz)/float(nz)))
	return out

## The route through a hall at `pose` (world): its way in, its cruise lane.
static func hall_route(pose: Dictionary) -> Array[Vector3]:
	var t := xform(pose)
	var hand := hand_of(pose)
	var out: Array[Vector3] = [t*local(approach(),hand)]
	for p: Vector3 in lane(): out.append(t*local(p,hand))
	return out

## The arc from `from`'s exit to `to`'s way in (world points, the ends
## left out): a circle tangent to the exit's heading, the height eased
## from the lane's end to the way in.
static func arc(from: Dictionary, to: Dictionary) -> Array[Vector3]:
	var out_pt: Array = exit_of(from)
	var p: Vector3 = out_pt[0]
	p.y = (xform(from)*local(lane()[-1],hand_of(from))).y
	var x := float(out_pt[1])
	var q := approach_of(to)
	var turn := wrapf(in_heading(to)-x,-PI,PI)
	var chord := Vector2(q.x-p.x,q.z-p.z).length()
	var steps := maxi(2,int(ceil(chord/ARC_STEP)))
	var out: Array[Vector3] = []
	for k in range(1,steps):
		var u := float(k)/float(steps)
		var flat: Vector3
		if absf(turn) < 1e-3: flat = p.lerp(q,u)
		else:
			# Along the circle: heading x+turn*u, radius chord/(2 sin(turn/2)).
			var r := chord/(2.0*sin(absf(turn)*0.5))
			var h := x+turn*u
			# The centre, to the turn's side of the exit.
			var side := signf(turn)
			var centre := p+ahead(x+side*PI*0.5)*r
			flat = centre-ahead(h+side*PI*0.5)*r
		flat.y = lerpf(p.y,q.y,smoothstep(0.0,1.0,u))
		out.append(flat)
	return out

## Arc length of the line (m), and from point `k` on.
static func line_length(from_k := 0) -> float:
	var l := line()
	var out := 0.0
	for k in range(maxi(1,from_k+1),l.size()): out += l[k].distance_to(l[k-1])
	return out

## How far along the line (0-1) the point nearest `p` (station metres) is,
## and how far off it `p` is: Vector2(share, distance).
static func progress_at(p: Vector3) -> Vector2:
	var l := line()
	var total := line_length()
	var best := INF
	var share := 0.0
	var run := 0.0
	for k in range(1,l.size()):
		var a: Vector3 = l[k-1]
		var b: Vector3 = l[k]
		var seg := a.distance_to(b)
		var u := clampf((p-a).dot(b-a)/maxf(seg*seg,1e-6),0.0,1.0)
		var d := p.distance_to(a.lerp(b,u))
		if d < best:
			best = d
			share = (run+u*seg)/total
		run += seg
	return Vector2(share,best)
