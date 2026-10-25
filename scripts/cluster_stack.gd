extends RefCounted
## The stack layout of the sky clusters (a motif's "stack" relation,
## scripts/cluster_motifs.gd, laid by scripts/cluster_solver.gd): members
## laid one over another, a column of narrow crags, and the plank stairs
## that wind up from each to the next.
##
## A member stacked (`place`) goes over the highest laid so far (the stack's
## head, else the anchor): shifted SHIFT of their two rims' reach along a
## way turned TURN round the stack from the way the one under it was
## shifted (always the same way round, so the column twists and every top
## shows from above), and risen just high enough that its hanging rock keeps
## HEADROOM clear of every member's land under it, read point by point
## against its keel (SkyIslet `underside`), never as circles: a deep keel
## over the middle of the one below rises higher than a shallow rim over
## its edge. EXTRA more at random; never less than RISE.x or more than
## RISE.y over the one under it. Tall plants left under its rock go.
##
## A stair (`_stair`) starts on the lower member's land and winds up round
## the upper one's rock, STAIR_OFF out from its rim (the rim's outline
## smoothed, so the stair runs in easy curves), at a grade in STAIR_GRADE,
## then steps in over the rim onto its land. It is laid as the lower
## member's decks (SkyIslet `decks`), straight runs about CHORD long, so the
## pilot walks it as land and the glide reads it as a solid. Over the lower
## land it stands on trestles (at most STILT tall); out in the air it is
## pinned by struts to the upper rock's wall; never more than SPAN between
## the two. It never buries itself in the lower land, keeps HEADROOM from
## every other member's rock and land and from every other stair, and never
## cuts the lower land in two (the way from the stair coming in to the one
## going on stays open: `_open_way`). Lanterns stand along it every LANTERN.
##
## A stair in the plan: {from, to (member names), points (the decks'
## corners, the from member's frame), offset (the from member's middle),
## around (the upper member's middle, from member's frame), stilts and
## struts ([{top, foot}], from member's frame), lanterns ([{at, angle}])}.
##
## The motif's own features on a member (`feature`): a garden (a small
## tilled bed in rows of flowers, a sunflower or two at the back) and hives
## (box beehives by the cabin or the garden).

const SkyIslet = preload("res://scripts/sky_islet.gd")
## The walker's step (m), frozen: the pilot on foot (scripts/
## pilot_motor.gd STEP_UP) is gone from the flight game, whole at the tag
## archive/before-the-cut.
const STEP_UP := 0.45
const MeadowTypes = preload("res://scripts/meadow_types.gd")

## Clear air (m) between a member's hanging rock and the land under it, and
## between a stair and any rock, land or stair over or under it.
const HEADROOM := 2.6
## Rims nearer than this (m, plate plane) count as over one another.
const MARGIN := 1.5
## Each member over the one under it: turned round the stack (rad), shifted
## (share of the two rims' reach along the way), risen middle to middle at
## least and at most (m), and a little more than the least that clears.
const TURN := Vector2(1.7,2.6)
const SHIFT := Vector2(0.5,0.85)
const RISE := Vector2(6.0,15.0)
const EXTRA := Vector2(0.4,2.2)
const TRIES := 24
## The stair: its width; how far out from the upper rim its middle runs;
## rim samples round the upper member, and how many each way the outline is
## smoothed over; its grade; how far in from the lower rim it starts and
## onto the upper land it ends; the most it winds (rad); a deck's length.
const STAIR_WIDTH := 1.0
const STAIR_OFF := 1.2
const RING := 72
const SMOOTH := 4
const STAIR_GRADE := Vector2(0.42,0.62)
const STAIR_IN := 0.9
const STAIR_INSET := 1.2
const STAIR_TURN := 5.0
const CHORD := 1.5
## The stair's top LANDING (m) is level, before it turns in over the rim.
const LANDING := 0.9
## A deck runs this far (m) past each bend into the next.
const OVERLAP := 0.3
## Its deck rides this far over the ground at its ends.
const LIFT := 0.05
## Held up: trestles at most STILT tall over the lower land; struts into
## the upper rock where it reaches WALL_DEPTH under the deck at one of
## WALL_IN in from the rim (m); at most SPAN (m) with neither.
const STILT := 7.5
const WALL_IN := [0.4,1.2,2.0,2.8]
const WALL_DEPTH := 0.3
const SPAN := 4.0
## Supports and lanterns along it (m of its run).
const SUPPORT_EVERY := 1.6
const LANTERN := 4.6
const LANTERN_FROM := 1.4
## Plants cleared round it (m), and tall ones round an upper rock's
## outline (m) on the land under it.
const CLEAR_PLANTS := 1.4
const CLEAR_UNDER := 2.5
const TALL := ["tree","layered_tree","redwood","broadleaf","birch","willow","juniper","snag","sunflower"]
## The garden: its bed's half extents (m), its rows, its flowers; a hive's
## footprint (m).
const GARDEN := Vector2(1.15,0.8)
const GARDEN_ROW := 0.4
const GARDEN_FLOWERS := ["lupine","cosmos","oxeye_daisy"]
const HIVE := 0.42

# --- Laying a member --------------------------------------------------------------------

## Lays `m` over the stack's head, with the stair up to it from there; false
## when no way round the stack clears.
static func place(m: Dictionary, placed: Array, plan: Dictionary, rng: RandomNumberGenerator) -> bool:
	var lower := _lower(placed)
	if lower.is_empty(): return false
	var rel: Dictionary = (m.role_data as Dictionary).get("relation",{})
	var turn: Vector2 = rel.get("turn",TURN)
	var shift: Vector2 = rel.get("shift",SHIFT)
	var sense: float = float(lower.get("stack_sense",1.0 if rng.randf() < 0.5 else -1.0))
	var stairs: Array = plan.get_or_add("stairs",[])
	var samples := _samples(m.shape)
	for k in range(TRIES):
		var angle: float = float(lower.stack_angle)+sense*rng.randf_range(turn.x,turn.y) if lower.has("stack_angle") else rng.randf()*TAU
		var way := Vector2.from_angle(angle)
		var d: float = rng.randf_range(shift.x,shift.y)*(float(lower.shape.rim_radius(angle))+float(m.shape.rim_radius(angle+PI)))
		var xz := Vector2(lower.offset.x,lower.offset.z)+way*d
		var y := maxf(_least_height(m.shape,samples,xz,placed,stairs),float(lower.offset.y)+RISE.x)+rng.randf_range(EXTRA.x,EXTRA.y)
		if y-float(lower.offset.y) > RISE.y: continue
		var at := Vector3(xz.x,y,xz.y)
		if not _clear(m.shape,at,placed): continue
		var stair := _stair(lower,m,at,placed,plan,rng)
		if stair.is_empty(): continue
		m.offset = at
		m.y = y
		m.stack_angle = angle
		m.stack_sense = sense
		_lay(lower,m,stair,placed,plan)
		return true
	return false

## The stack's head: the last member stacked, else the anchor.
static func _lower(placed: Array) -> Dictionary:
	for k in range(placed.size()-1,-1,-1):
		var role: Dictionary = placed[k].role_data
		if (role.get("relation",{}) as Dictionary).get("type","") == "stack": return placed[k]
	for p: Dictionary in placed:
		if (p.role_data as Dictionary).get("anchor",false): return p
	return placed[0] if not placed.is_empty() else {}

## Points of a member's land (its own frame) its rock is read at: every
## other grid point on the land each way, and its rim.
static func _samples(shape: RefCounted) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = shape.cells+1
	for i in range(shape.points.size()):
		if shape.shore_distance[i] >= 0.0 and (i % n) % 2 == 0 and (i/n) % 2 == 0: out.append(shape.points[i])
	for k in range(32): out.append(shape.rim_point(TAU*k/32.0)*0.97)
	return out

## The least height (cluster frame) a member standing at `xz` must have for
## its rock to keep HEADROOM over every placed member's land and every stair.
static func _least_height(shape: RefCounted, samples: PackedVector2Array, xz: Vector2, placed: Array, stairs: Array) -> float:
	var least := -INF
	for p: Dictionary in placed:
		var off := xz-Vector2(p.offset.x,p.offset.z)
		if off.length() > float(shape.reach)+float(p.shape.reach)+MARGIN+1.0: continue
		for s in samples:
			var top := top_near(p.shape,s+off,MARGIN)
			if top == -INF: continue
			least = maxf(least,float(p.offset.y)+top+HEADROOM-float(shape.underside(s)))
	for st: Dictionary in stairs:
		for q: Vector3 in _home_points(st):
			var local := Vector2(q.x-xz.x,q.z-xz.y)
			if not _near_land(shape,local,0.9): continue
			least = maxf(least,q.y+HEADROOM-float(shape.underside(_onto(shape,local))))
	return least

## True when a member standing at `at` keeps clear of every placed one:
## apart in the plane, or over or under it with HEADROOM between.
static func _clear(shape: RefCounted, at: Vector3, placed: Array) -> bool:
	for p: Dictionary in placed:
		if vertical_gap(shape,at,p.shape,p.offset,MARGIN) < HEADROOM-0.001: return false
	return true

## The clear air (m) between the higher of two members' rock and the lower
## one's land where they are within `margin` of over one another (the
## higher's land read point by point); INF where they are apart.
static func vertical_gap(a: RefCounted, a_at: Vector3, b: RefCounted, b_at: Vector3, margin := MARGIN) -> float:
	var hi := a
	var hi_at := a_at
	var lo := b
	var lo_at := b_at
	if b_at.y > a_at.y:
		hi = b
		hi_at = b_at
		lo = a
		lo_at = a_at
	var off := Vector2(hi_at.x-lo_at.x,hi_at.z-lo_at.z)
	if off.length() > float(hi.reach)+float(lo.reach)+margin+1.0: return INF
	var best := INF
	for s in _samples(hi):
		var top := top_near(lo,s+off,margin)
		if top == -INF: continue
		best = minf(best,hi_at.y+float(hi.underside(s))-(lo_at.y+top))
	return best

## True when two members, near or over one another in the plane, are
## stacked: one's rock HEADROOM (nearly) clear of the other's land.
static func stacked(a: Dictionary, b: Dictionary) -> bool:
	return vertical_gap(a.shape,a.offset,b.shape,b.offset,0.5) >= HEADROOM*0.95

## The highest land (its own frame) within `margin` of `q`, or -INF.
static func top_near(shape: RefCounted, q: Vector2, margin: float) -> float:
	if absf(q.x) > float(shape.reach)+margin+0.5 or absf(q.y) > float(shape.reach)+margin+0.5: return -INF
	var top := -INF
	for k in range(9):
		var r := q if k == 8 else q+Vector2.from_angle(TAU*k/8.0)*margin
		if shape.on_land(r): top = maxf(top,land_y(shape,r))
	return top

## The land's own height at `p` (its decks not counted).
static func land_y(shape: RefCounted, p: Vector2) -> float:
	return float(shape._sample(shape.heights,p,SkyIslet.RIM_HEIGHT))

static func _near_land(shape: RefCounted, q: Vector2, margin: float) -> bool:
	return top_near(shape,q,margin) > -INF

## `q` or, off the land, the nearest of its probes on it (for the rock
## under it).
static func _onto(shape: RefCounted, q: Vector2) -> Vector2:
	if shape.on_land(q): return q
	for k in range(8):
		var r := q+Vector2.from_angle(TAU*k/8.0)*0.9
		if shape.on_land(r): return r
	return q

# --- The stair --------------------------------------------------------------------------

## The stair from `lower` up to `upper` standing at `at` (its decks' corners
## and how it winds), or {} when none clears.
static func _stair(lower: Dictionary, upper: Dictionary, at: Vector3, placed: Array, plan: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var uc := Vector2(at.x-lower.offset.x,at.z-lower.offset.z)
	var dy: float = at.y-float(lower.offset.y)
	var rims := PackedFloat32Array()
	for k in range(RING): rims.append(float(upper.shape.rim_radius(TAU*k/RING)))
	# The outline's bulges taken (the most each way), then eased (the mean
	# each way), so the stair swings round in long curves.
	var most := PackedFloat32Array()
	for k in range(RING):
		var r := 0.0
		for w in range(-SMOOTH,SMOOTH+1): r = maxf(r,rims[(k+w+RING) % RING])
		most.append(r)
	var ring := PackedFloat32Array()
	for k in range(RING):
		var r := 0.0
		for w in range(-SMOOTH,SMOOTH+1): r += most[(k+w+RING) % RING]
		ring.append(r/(SMOOTH*2+1)+STAIR_OFF)
	var came: Variant = _arrival(lower,plan)
	var starts: Array = []
	for k in range(0,RING,2): starts.append(k)
	_shuffle(starts,rng)
	for k: int in starts:
		var phi0 := TAU*k/RING
		var a := uc+Vector2.from_angle(phi0)*_around(ring,phi0)
		if not lower.shape.on_land(a) or float(lower.shape.inland(a)) < STAIR_IN: continue
		var senses := [1.0,-1.0] if rng.randf() < 0.5 else [-1.0,1.0]
		for sense: float in senses:
			var stair := _wind(lower,upper,uc,dy,ring,rims,phi0,sense,rng.randf_range(STAIR_GRADE.x,STAIR_GRADE.y))
			if stair.is_empty(): continue
			if not _path_ok(stair,lower,upper,at,placed,plan): continue
			if came != null and not _open_way(lower.shape,came,a,stair.points): continue
			return stair
	return {}

## A value round the upper member at angle `phi`, from RING samples.
static func _around(values: PackedFloat32Array, phi: float) -> float:
	var f := fposmod(phi,TAU)/TAU*RING
	var i := floori(f)
	return lerpf(values[i % RING],values[(i+1) % RING],f-i)

## The stair's run from `phi0` round the upper member the way `sense`
## turns, rising at `grade` until it meets the upper rim's height, then in
## onto its land: {points, around, end (where the run in begins)}.
static func _wind(lower: Dictionary, upper: Dictionary, uc: Vector2, dy: float, ring: PackedFloat32Array, rims: PackedFloat32Array, phi0: float, sense: float, grade: float) -> Dictionary:
	var a := uc+Vector2.from_angle(phi0)*_around(ring,phi0)
	var ya := land_y(lower.shape,a)+LIFT
	var dense: Array[Vector2] = [a]
	var arcs: Array[float] = [0.0]
	var phi := phi0
	var arc := 0.0
	var yb := 0.0
	var b := Vector2.ZERO
	while true:
		phi += 0.03*sense
		if absf(phi-phi0) > STAIR_TURN: return {}
		var p := uc+Vector2.from_angle(phi)*_around(ring,phi)
		arc += p.distance_to(dense.back())
		dense.append(p)
		arcs.append(arc)
		var inside := Vector2.from_angle(phi)*(_around(rims,phi)-STAIR_INSET)
		if not upper.shape.on_land(inside) or float(upper.shape.inland(inside)) < 0.5: continue
		yb = dy+land_y(upper.shape,inside)+LIFT
		if ya+(arc-LANDING)*grade >= yb:
			b = uc+inside
			break
	if yb-ya < 1.0 or arc < CHORD+LANDING: return {}
	# Decks about CHORD long up to the landing, then the landing, level.
	var climb := arc-LANDING
	var wants: Array[float] = []
	var n := maxi(1,ceili(climb/CHORD))
	for i in range(n+1): wants.append(climb*i/n)
	wants.append(arc)
	var points: Array[Vector3] = []
	var j := 0
	for i in range(wants.size()):
		while j < arcs.size()-1 and arcs[j] < wants[i]: j += 1
		var p: Vector2 = dense[j] if i > 0 else a
		points.append(Vector3(p.x,lerpf(ya,yb,minf(arcs[j]/climb,1.0) if i > 0 else 0.0),p.y))
	points.append(Vector3(b.x,yb,b.y))
	return {"points":points,"around":uc,"end":points.size()-2}

## Where a strut from the stair at `pu` (the upper member's frame, the
## stair's deck at `y`, `dy` over the lower member's) meets the upper rock,
## Vector3(x, height in the lower member's frame, z) in the upper member's
## frame: the first of WALL_IN in from the rim whose rock reaches WALL_DEPTH
## under the deck; or null where the rock is all overhead or too far in.
static func _wall(shape: RefCounted, pu: Vector2, dy: float, y: float) -> Variant:
	var out := pu.normalized()
	var rim: float = shape.rim_radius(pu.angle())
	for k: float in WALL_IN:
		var at := out*(rim-k)
		if not shape.on_land(at): continue
		var under := dy+float(shape.underside(at))
		if under > y-WALL_DEPTH: continue
		return Vector3(at.x,maxf(y-1.1-k*0.3,under+0.3),at.y)
	return null

## Samples along a stair's decks every `step` m: [Vector2 (plane), y, i (its
## deck), arc (m from the foot)].
static func _along(points: Array, step: float) -> Array:
	var out: Array = []
	var arc := 0.0
	for i in range(points.size()-1):
		var p0: Vector3 = points[i]
		var p1: Vector3 = points[i+1]
		var run := Vector2(p1.x-p0.x,p1.z-p0.z).length()
		var n := maxi(1,ceili(run/step))
		for k in range(n):
			var p := p0.lerp(p1,float(k)/n)
			out.append([Vector2(p.x,p.z),p.y,i,arc+run*k/n])
		arc += run
	var last: Vector3 = points.back()
	out.append([Vector2(last.x,last.z),last.y,points.size()-2,arc])
	return out

## True when a stair's every stretch is held up, in the clear and above
## the lower land (see the head).
static func _path_ok(stair: Dictionary, lower: Dictionary, upper: Dictionary, at: Vector3, placed: Array, plan: Dictionary) -> bool:
	var points: Array = stair.points
	var uc: Vector2 = stair.around
	var dy: float = at.y-float(lower.offset.y)
	var lxz := Vector2(lower.offset.x,lower.offset.z)
	var loose := 0.0
	var step := 0.4
	var last_end: int = stair.end
	for s: Array in _along(points,step):
		var p: Vector2 = s[0]
		var y: float = s[1]
		var final: bool = int(s[2]) >= last_end
		var held := final
		if lower.shape.on_land(p):
			var g := land_y(lower.shape,p)
			if y < g-0.02: return false
			if y-g <= STILT: held = true
		var pu := p-uc
		if not final:
			# Its inner edge too stays off the upper land.
			for side: float in [-0.5,0.0,0.5]:
				if upper.shape.on_land(pu+pu.normalized()*side*STAIR_WIDTH*1.2): return false
			if _wall(upper.shape,pu,dy,y) != null: held = true
		loose = 0.0 if held else loose+step
		if loose > SPAN: return false
		if not _in_clear(Vector3(p.x+lxz.x,y+float(lower.offset.y),p.y+lxz.y),[lower.name,upper.name],placed,plan.get("stairs",[])): return false
	return true

## True when a point of a stair (cluster frame) keeps HEADROOM of every
## member's land and rock but those named in `except`, and of every stair.
static func _in_clear(q: Vector3, except: Array, members: Array, stairs: Array) -> bool:
	for m: Dictionary in members:
		if m.name in except: continue
		var local := Vector2(q.x-m.offset.x,q.z-m.offset.z)
		var top := top_near(m.shape,local,0.9)
		if top == -INF: continue
		if q.y >= float(m.offset.y)+top+HEADROOM: continue
		if q.y+HEADROOM <= float(m.offset.y)+float(m.shape.underside(_onto(m.shape,local))): continue
		return false
	for st: Dictionary in stairs:
		var home := _home_points(st)
		for i in range(home.size()-1):
			var a: Vector3 = home[i]
			var b: Vector3 = home[i+1]
			var flat := Geometry2D.get_closest_point_to_segment(Vector2(q.x,q.z),Vector2(a.x,a.z),Vector2(b.x,b.z))
			if flat.distance_to(Vector2(q.x,q.z)) > STAIR_WIDTH+0.6: continue
			var t := Vector2(a.x,a.z).distance_to(flat)/maxf(Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z)),0.001)
			if absf(q.y-lerpf(a.y,b.y,t)) < HEADROOM: return false
	return true

## A stair's decks' corners in the cluster's frame.
static func _home_points(st: Dictionary) -> Array:
	var out: Array = []
	var off: Vector3 = st.offset
	for p: Vector3 in st.points: out.append(p+off)
	return out

## The run in of the stair coming up onto `m` (from its landing to its
## head, in `m`'s frame), or null.
static func _arrival(m: Dictionary, plan: Dictionary) -> Variant:
	for st: Dictionary in plan.get("stairs",[]):
		if st.to != m.name: continue
		var points: Array = st.points
		var shift: Vector3 = (st.offset as Vector3)-(m.offset as Vector3)
		var landing: Vector3 = points[points.size()-2]+shift
		var head: Vector3 = points.back()+shift
		return [Vector2(landing.x,landing.z),Vector2(head.x,head.z)]
	return null

## True where a stair's deck (`points`) stands over `p` higher than a step
## over the land: a wall to a walker on it.
static func _walled(shape: RefCounted, p: Vector2, points: Array) -> bool:
	var g := land_y(shape,p)
	for k in range(points.size()-1):
		var a: Vector3 = points[k]
		var b: Vector3 = points[k+1]
		var flat := Geometry2D.get_closest_point_to_segment(p,Vector2(a.x,a.z),Vector2(b.x,b.z))
		if flat.distance_to(p) > STAIR_WIDTH*0.5+0.35: continue
		var t := Vector2(a.x,a.z).distance_to(flat)/maxf(Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z)),0.001)
		if lerpf(a.y,b.y,t)-g > STEP_UP: return true
	return false

## True when the pilot can come in up the stair arriving (`came`, its run
## in), step off it, and walk the lower land to `to` with the new stair
## standing (its high stretches a wall), round the water.
static func _open_way(shape: RefCounted, came: Array, to: Vector2, points: Array) -> bool:
	var landing: Vector2 = came[0]
	var head: Vector2 = came[1]
	var across := (head-landing).normalized().orthogonal()*STAIR_WIDTH*0.4
	for k in range(9):
		var q := landing.lerp(head,k/8.0)
		for side: Vector2 in [Vector2.ZERO,across,-across]:
			if shape.on_land(q+side) and _walled(shape,q+side,points): return false
	# And room to step off it.
	for ring: float in [0.8,1.6]:
		for k in range(12):
			var q := head+Vector2.from_angle(TAU*k/12.0)*ring
			if shape.on_land(q) and _walled(shape,q,points): return false
	var from := head
	var n: int = shape.cells+1
	var count: int = shape.points.size()
	var open := PackedByteArray()
	open.resize(count)
	for i in range(count):
		var p: Vector2 = shape.points[i]
		if shape.shore_distance[i] < 0.2 or shape.wet(p):
			open[i] = 0
			continue
		open[i] = 0 if _walled(shape,p,points) else 1
	var start := _nearest_open(shape,open,from)
	var goal := _nearest_open(shape,open,to)
	if start < 0 or goal < 0: return false
	var seen := PackedByteArray()
	seen.resize(count)
	var queue: Array[int] = [start]
	seen[start] = 1
	while not queue.is_empty():
		var i: int = queue.pop_back()
		if i == goal: return true
		var x := i % n
		var z := i/n
		for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1)]:
			var nx := x+d.x
			var nz := z+d.y
			if nx < 0 or nz < 0 or nx >= n or nz >= n: continue
			var j := nz*n+nx
			if seen[j] == 1 or open[j] == 0: continue
			seen[j] = 1
			queue.append(j)
	return false

static func _nearest_open(shape: RefCounted, open: PackedByteArray, at: Vector2) -> int:
	var best := -1
	var near := 1.6
	for i in range(open.size()):
		if open[i] == 0: continue
		var d: float = (shape.points[i] as Vector2).distance_to(at)
		if d < near:
			near = d
			best = i
	return best

## Lays a stair found: its decks on the lower member, both its heads
## claimed, the plants on and round it cleared, its supports and lanterns
## worked out; and the tall plants under the new member's rock gone.
static func _lay(lower: Dictionary, upper: Dictionary, stair: Dictionary, placed: Array, plan: Dictionary) -> void:
	var points: Array = stair.points
	var uc: Vector2 = stair.around
	var dy: float = float(upper.offset.y)-float(lower.offset.y)
	var first: Vector3 = points[0]
	var last: Vector3 = points.back()
	lower.shape.claim(Vector2(first.x,first.z),0.9)
	# The upper land levelled to the deck from its head out to the rim, so
	# the stair steps straight onto it.
	var head := Vector2(last.x,last.z)-uc
	var level := last.y-dy-LIFT
	var before: Vector3 = points[points.size()-2]
	var outward := Vector2(before.x,before.z)-uc-head
	for k in range(int(outward.length()/0.6)+1):
		var at := head+outward.normalized()*k*0.6
		if not upper.shape.on_land(at): break
		upper.shape.claim(at,1.1 if k == 0 else 0.7,level-land_y(upper.shape,at))
	_clear_plants(lower.shape,points,Vector2.ZERO)
	_clear_plants(upper.shape,points,uc)
	# Each deck runs on OVERLAP past the bends, so their outer corners meet.
	for i in range(points.size()-1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var way := (b-a)/maxf(Vector2(b.x-a.x,b.z-a.z).length(),0.001)
		if i > 0: a -= way*OVERLAP
		if i < points.size()-2: b += way*OVERLAP
		lower.shape.decks.append({"a":a,"b":b,"width":STAIR_WIDTH,"bow":0.0,"stair":true})
		var end: Vector3 = points[i+1]
		lower.shape.reach = maxf(lower.shape.reach,Vector2(end.x,end.z).length()+1.0)
	# What holds it up, and its lanterns.
	var stilts: Array = []
	var struts: Array = []
	var lanterns: Array = []
	var next_lantern := LANTERN_FROM
	var next_support := 0.8
	var end_at: int = stair.end
	for s: Array in _along(points,0.2):
		var p: Vector2 = s[0]
		var y: float = s[1]
		var arc: float = s[3]
		var pu := p-uc
		var out := pu.normalized()
		if int(s[2]) >= end_at: break
		if arc >= next_lantern:
			next_lantern += LANTERN
			var foot := p+out*(STAIR_WIDTH*0.5-0.08)
			lanterns.append({"at":Vector3(foot.x,y,foot.y),"angle":atan2(out.x,out.y)})
		if arc < next_support: continue
		next_support += SUPPORT_EVERY
		if lower.shape.on_land(p) and y-land_y(lower.shape,p) > 0.25:
			for side: float in [-1.0,1.0]:
				var leg := p+out*side*(STAIR_WIDTH*0.5-0.06)
				if lower.shape.on_land(leg): stilts.append({"top":Vector3(leg.x,y-0.1,leg.y),"foot":Vector3(leg.x,land_y(lower.shape,leg)-0.1,leg.y)})
			continue
		var wall: Variant = _wall(upper.shape,pu,dy,y)
		if wall != null:
			var top := p-out*(STAIR_WIDTH*0.5-0.08)
			var foot: Vector3 = wall
			struts.append({"top":Vector3(top.x,y-0.12,top.y),"foot":Vector3(foot.x+uc.x,foot.y,foot.z+uc.y)})
	# Nothing tall stays under the new member's rock.
	var uxz := Vector2(upper.offset.x,upper.offset.z)
	for m: Dictionary in placed:
		if float(m.offset.y) >= float(upper.offset.y): continue
		var off := Vector2(m.offset.x,m.offset.z)-uxz
		m.shape.objects = (m.shape.objects as Array[Dictionary]).filter(func(o: Dictionary) -> bool:
			return not (str(o.asset) in TALL and _near_land(upper.shape,Vector2(o.x,o.z)+off,CLEAR_UNDER)))
	lower.features.append({"type":"stair","to":upper.name})
	plan.get_or_add("stairs",[]).append({"from":lower.name,"to":upper.name,"points":points,"offset":lower.offset,"around":uc,
		"stilts":stilts,"struts":struts,"lanterns":lanterns})

## Clears the plants of `shape` (whose middle is `shift` in the stair's
## frame) within CLEAR_PLANTS of a stair's run.
static func _clear_plants(shape: RefCounted, points: Array, shift: Vector2) -> void:
	shape.objects = (shape.objects as Array[Dictionary]).filter(func(o: Dictionary) -> bool:
		var p := Vector2(o.x,o.z)+shift
		for i in range(points.size()-1):
			var a: Vector3 = points[i]
			var b: Vector3 = points[i+1]
			if Geometry2D.get_closest_point_to_segment(p,Vector2(a.x,a.z),Vector2(b.x,b.z)).distance_to(p) < CLEAR_PLANTS: return false
		return true)

static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var t: Variant = items[i]
		items[i] = items[j]
		items[j] = t

# --- Its features -----------------------------------------------------------------------

## The stack's own features on member `m`: "garden" and "hives".
static func feature(m: Dictionary, f: Dictionary, rng: RandomNumberGenerator, plan: Dictionary) -> void:
	var shape: RefCounted = m.shape
	var by := _near_built(m)
	match str(f.type):
		"garden":
			var at: Variant = shape.find_spot(0.0,0.5,0.45,[],{"near":by,"near_weight":0.6},GARDEN)
			if at == null:
				_missing(m,f,plan)
				return
			var p: Vector2 = at
			shape.claim(p,0.0,0.0,GARDEN)
			var rect := Rect2(p-GARDEN,GARDEN*2.0)
			shape.soil.append(rect)
			# Rows across the bed; the back row (from the cabin) sunflowers.
			var back := 1.0 if (p-by).y < 0.0 else -1.0
			var flower: String = GARDEN_FLOWERS[rng.randi() % GARDEN_FLOWERS.size()]
			var z := rect.position.y+0.28
			while z < rect.end.y-0.15:
				var row_back := (z-p.y)*back > GARDEN.y*0.45
				var kind := "sunflower" if row_back else flower
				var x := rect.position.x+0.25
				var tint := MeadowTypes.tint(kind,rng.randf())
				while x < rect.end.x-0.15:
					shape.add_record(kind,Vector2(x+rng.randf_range(-0.05,0.05),z+rng.randf_range(-0.04,0.04)),rng.randf()*TAU,rng.randf_range(0.85,1.05),tint)
					x += 0.55 if row_back else 0.3
				z += GARDEN_ROW
			m.features.append({"type":"garden","rect":rect})
		"hives":
			var count: Vector2i = f.get("count",Vector2i(2,2))
			var laid := 0
			for k in range(rng.randi_range(count.x,count.y)):
				var at: Variant = shape.find_spot(HIVE,0.4,0.3,[],{"near":by+Vector2.from_angle(rng.randf()*TAU)*2.5,"near_weight":1.0})
				if at == null: continue
				shape.claim(at,HIVE)
				var blocks: Array = shape.recipe.get_or_add("blocks",[])
				blocks.append(Vector3(at.x,at.y,HIVE*0.8))
				var toward := by-(at as Vector2)
				m.features.append({"type":"hive","at":at,"angle":atan2(-toward.x,-toward.y)+rng.randf_range(-0.5,0.5)+PI})
				laid += 1
			if laid == 0: _missing(m,f,plan)

static func _near_built(m: Dictionary) -> Vector2:
	for type: String in ["cabin","garden"]:
		for f: Dictionary in m.features:
			if f.type == type: return f.at if f.has("at") else (f.rect as Rect2).get_center()
	return Vector2.ZERO

static func _missing(m: Dictionary, f: Dictionary, plan: Dictionary) -> void:
	if float(f.get("chance",1.0)) >= 1.0: plan.problems.append("no room for the %s on %s" % [f.type,m.name])

# --- Checking -------------------------------------------------------------------------------

## What is wrong with a plan's stairs and the stack's features, as
## sentences: a stair's foot off the lower land or floating, its head off
## the upper land or floating, a deck too steep, a stretch in another
## member's rock or land or in another stair, over the upper land before its
## run in, the way on the lower land cut, a lantern off it; a hive or the
## garden off the land, in water or on uneven ground.
static func validate(plan: Dictionary) -> Array:
	var problems: Array = []
	var by_name := {}
	for m: Dictionary in plan.members: by_name[m.name] = m
	var stairs: Array = plan.get("stairs",[])
	for si in range(stairs.size()):
		var st: Dictionary = stairs[si]
		var from: Dictionary = by_name.get(st.from,{})
		var to: Dictionary = by_name.get(st.to,{})
		if from.is_empty() or to.is_empty():
			problems.append("stair %s-%s: a member is missing" % [st.from,st.to])
			continue
		var points: Array = st.points
		var foot: Vector3 = points[0]
		var head: Vector3 = points.back()
		var off: Vector3 = (to.offset as Vector3)-(from.offset as Vector3)
		var head_local := Vector2(head.x-off.x,head.z-off.z)
		if not from.shape.on_land(Vector2(foot.x,foot.z)): problems.append("stair %s-%s: foot off the land" % [st.from,st.to])
		elif absf(foot.y-land_y(from.shape,Vector2(foot.x,foot.z))) > 0.35: problems.append("stair %s-%s: foot floats" % [st.from,st.to])
		if not to.shape.on_land(head_local): problems.append("stair %s-%s: head off the land" % [st.from,st.to])
		elif absf(head.y-off.y-land_y(to.shape,head_local)) > 0.35: problems.append("stair %s-%s: head floats" % [st.from,st.to])
		for i in range(points.size()-1):
			var a: Vector3 = points[i]
			var b: Vector3 = points[i+1]
			var run := Vector2(b.x-a.x,b.z-a.z).length()
			if absf(b.y-a.y) > run*(STAIR_GRADE.y+0.1)+0.05: problems.append("stair %s-%s too steep" % [st.from,st.to])
		var others: Array = stairs.slice(0,si)+stairs.slice(si+1)
		var end := points.size()-2
		for s: Array in _along(points,0.5):
			var p: Vector2 = s[0]
			var q := Vector3(p.x+from.offset.x,float(s[1])+float(from.offset.y),p.y+from.offset.z)
			if not _in_clear(q,[from.name,to.name],plan.members,others):
				problems.append("stair %s-%s runs into something" % [st.from,st.to])
				break
			if int(s[2]) < end and to.shape.on_land(Vector2(q.x-to.offset.x,q.z-to.offset.z)):
				problems.append("stair %s-%s cuts the upper land" % [st.from,st.to])
				break
			if from.shape.on_land(p) and float(s[1]) < land_y(from.shape,p)-0.05:
				problems.append("stair %s-%s buried in the land" % [st.from,st.to])
				break
		for l: Dictionary in st.lanterns:
			var at: Vector3 = l.at
			if from.shape.deck_y(Vector2(at.x,at.z)) == -INF: problems.append("stair %s-%s: lantern off the stair" % [st.from,st.to])
		var came: Variant = _arrival(from,plan)
		if came != null and not _open_way(from.shape,came,Vector2(foot.x,foot.z),points): problems.append("stair %s-%s cuts the way on %s" % [st.from,st.to,st.from])
	for m: Dictionary in plan.members:
		for f: Dictionary in m.features:
			match str(f.type):
				"hive": _footing(m.shape,f.at,HIVE,"hive",m.name,problems)
				"garden":
					var rect: Rect2 = f.rect
					for c: Vector2 in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y),rect.get_center()]:
						if not m.shape.on_land(c) or m.shape.wet(c):
							problems.append("garden off the land or in water on %s" % m.name)
							break
	return problems

static func _footing(shape: RefCounted, at: Vector2, radius: float, what: String, member: String, problems: Array) -> void:
	var low := INF
	var high := -INF
	for k in range(9):
		var q := at if k == 8 else at+Vector2.from_angle(TAU*k/8.0)*radius*0.85
		if not shape.on_land(q) or shape.wet(q):
			problems.append("off the land or in water: %s on %s" % [what,member])
			return
		low = minf(low,land_y(shape,q))
		high = maxf(high,land_y(shape,q))
	if high-low > 0.3: problems.append("floating: %s on %s (ground varies %.2f m)" % [what,member,high-low])
