extends RefCounted
## Finding a ledge's lip for the pilot on foot (scripts/pilot_motor.gd): the
## edge where ground that can be stood on ends in a drop, from nothing but
## the ground's heights. Any terrain gives them: an island's or islet's rim
## (no ground past it), or a step in the land too steep to walk. Nothing
## here is placed by hand.
##
## `height` takes a point (x, z) and gives its ground's height, or -INF
## where there is none (off the island's outline, in a chasm).

## Metres round the point the ring of samples that finds the way in looks.
const RING := 0.45
const SAMPLES := 16
## How far below the top the drop must go to be a ledge, and how much
## lower than the top the ground may be and still count as the top.
const DROP := 0.6
const TOP_SLACK := 0.3
## How far either side of the point along the way in the edge is looked
## for.
const ACROSS := 0.7
## Off the island, the ring counts the missing ground this far below.
const VOID := 3.0
## Metres either side along the edge its way off is measured over.
const TANGENT := 0.25
## The most the edge may turn (radians) over that span.
const BEND := 0.6

## The lip nearest plate point `near`, its top about `y` (a hint: the ground
## at or near the lip; heights far above it are walls, not the top), as
## {"at": the edge on the top's height (x, y, z), "out": the way off it, a
## unit (x, z)}, or {} if there is none here.
static func find(height: Callable, near: Vector2, y: float) -> Dictionary:
	# The way in: towards the ground standing highest round the point, the
	# missing ground counted VOID below the hint.
	var inward := Vector2.ZERO
	var low := INF
	var high := -INF
	for k in range(SAMPLES):
		var way := Vector2.from_angle(TAU*k/SAMPLES)
		var h := _at(height,near+way*RING,y)
		low = minf(low,h)
		high = maxf(high,h)
		inward += way*(h-y)
	if high-low < DROP or inward.length() < 0.001: return {}
	inward = inward.normalized()
	# The top: in from the point, nearer and nearer (a beam's is narrower
	# than the ring).
	var inner := near+inward*ACROSS
	var outer := near-inward*ACROSS
	var top := NAN
	for d: float in [ACROSS,RING,0.25,0.12]:
		var h := float(height.call(near+inward*d))
		if is_finite(h) and absf(h-y) <= 1.0:
			top = h
			inner = near+inward*d
			break
	if is_nan(top):
		inner = near+inward*RING
		top = float(height.call(inner))
	if not is_finite(top): return {}
	if _at(height,outer,top) > top-DROP: return {}
	# The edge: between the outer (low) point and the inner (top), the last
	# point still on the top.
	var a := outer
	var b := inner
	for i in range(12):
		var m := (a+b)*0.5
		if _at(height,m,top) >= top-TOP_SLACK: b = m
		else: a = m
	var lip := float(height.call(b+inward*0.02))
	if not is_finite(lip): lip = top
	# The way off it square to the edge itself, from its points TANGENT
	# either side along it (the ring's way in only finds the edge).
	var along := Vector2(-inward.y,inward.x)
	var ends: Array[Vector2] = []
	for side: float in [-1.0,1.0]:
		var c := b+along*side*TANGENT
		var e := _edge(height,c-inward*ACROSS,c+inward*ACROSS,top)
		if e == Vector2.INF: return {"at":Vector3(b.x,lip,b.y),"out":-inward}
		ends.append(e)
	# A corner sharper than BEND within it is no lip to hang from.
	if absf((b-ends[0]).angle_to(ends[1]-b)) > BEND: return {}
	var out := (ends[1]-ends[0]).orthogonal().normalized()
	if out.dot(-inward) < 0.0: out = -out
	# The lip straight in from the point, square to the edge.
	var square := _edge(height,near+out*ACROSS,near-out*ACROSS,top)
	if square != Vector2.INF: b = square
	return {"at":Vector3(b.x,lip,b.y),"out":out}

## The edge between `a` (off the top) and `b` (on it), or Vector2.INF if
## they are not.
static func _edge(height: Callable, a: Vector2, b: Vector2, top: float) -> Vector2:
	if _at(height,a,top) >= top-TOP_SLACK or _at(height,b,top) < top-TOP_SLACK: return Vector2.INF
	for i in range(12):
		var m := (a+b)*0.5
		if _at(height,m,top) >= top-TOP_SLACK: b = m
		else: a = m
	return b

static func _at(height: Callable, p: Vector2, y: float) -> float:
	var h := float(height.call(p))
	return h if is_finite(h) else y-VOID
