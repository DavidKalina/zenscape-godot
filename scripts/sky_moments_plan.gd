extends RefCounted
## The flight study's moments set pieces (scripts/flight_pack_moments.gd) as
## the sky world lays them out (scripts/sky_world.gd `_moments`) and the
## sky stands them (scripts/sky_moments.gd): each of the five stations'
## greybox stone, its natural line, its free collectibles and its challenge
## ones, unchanged, in the station's own metres (the entry at 0, flying
## north, -z); turned by a placement's `turn` (radians about y, as the
## ranges' `turn`) and mirrored across its line (x to -x) when it says so.
##
## What the world adds round a station:
##   the starter: not where the study had it, mid-line, but on the line's
##     own way in, STARTER_OUT m before the entry, a magenta hoop RING_R
##     across facing along the line. Flown through toward the entry (and
##     only that way) it starts the challenge, so whoever arrives from
##     wherever lines up with the station's line by taking it; its beacon
##     (BEACON) stands over it and LEADS small markers further out on the
##     same line draw the eye onto the way in from afar;
##   the plinth: under a station whose stone stands on the study's floor
##     (its pillars, walls and stacks go down to it), a slab where that
##     floor was (PLINTH thick), so it reads as one thing floating in the
##     sky and is shut underneath as the study's was;
##   the area: the box round all of it, grown AREA m every way: leaving it
##     ends the challenge (the study's `area` was measured off the line).
## A footprint (`footprint`) is the plate-plane rectangle round all of it
## (stone, line, collectibles, starter and leads), which is what the layout
## keeps clear of everything else.

const Course = preload("res://scripts/flight_course.gd")

## The starter's hoop: how far before the entry (m, along the line's way
## in), its radius, the beacon's height over it and its radius, and the
## leads' distances out along the same line.
const STARTER_OUT := 35.0
const RING_R := 3.0
const BEACON := Vector2(70.0,1.4)
const LEADS := [65.0,100.0,135.0]
## The plinth's thickness (m), under a station whose stone reaches the
## study's floor (FlightCourse ALT under the entry, give or take FLOOR_NEAR).
const PLINTH := 3.0
const FLOOR_NEAR := 1.0
## The area round a station, past its box (m).
const AREA := 30.0

## Worked out once (`prepare`): each station's footprint and collectibles.
static var _footprints: Array = []
static var _moments: Array = []

## The five stations, in the pack's order.
static func stations() -> Array:
	return Course.pack("moments")

static func count() -> int:
	return stations().size()

## Station `i`'s solids in its own metres (the entry at the origin):
## FlightCourse `solids` less the station's origin, with its plinth.
static func local_solids(i: int) -> Array:
	var s: Dictionary = stations()[i]
	var at := Course.origin(s)
	var out := []
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for q: Dictionary in Course.solids(s):
		var c: Dictionary = q.duplicate()
		c.middle = (q.middle as Vector3)-at
		out.append(c)
		var e := extent(c)
		lo = lo.min(c.middle-e)
		hi = hi.max(c.middle+e)
	if lo.y <= -Course.ALT+FLOOR_NEAR:
		var size := Vector3(hi.x-lo.x,PLINTH,hi.z-lo.z)
		out.append({"kind":"box","middle":Vector3((lo.x+hi.x)*0.5,-Course.ALT-PLINTH*0.5,(lo.z+hi.z)*0.5),"size":size,"basis":Basis.IDENTITY,"plinth":true})
	return out

## A solid's half extents along x, y and z.
static func extent(q: Dictionary) -> Vector3:
	if q.kind == "box":
		var b: Basis = q.basis
		var h: Vector3 = (q.size as Vector3)*0.5
		return (b.x*h.x).abs()+(b.y*h.y).abs()+(b.z*h.z).abs()
	return Vector3(float(q.radius),float(q.height)*0.5,float(q.radius))

## Station `i`'s natural line (its tokens: all guides), in its own metres.
static func line(i: int) -> Array[Vector3]:
	var s: Dictionary = stations()[i]
	var out: Array[Vector3] = []
	for t: Vector3 in s.tokens: out.append(t)
	return out

## Station `i`'s collectibles in its own metres, the study's starter moved
## onto the way in (`starter`): [{at, role, kind, reach, note, index}].
static func moments(i: int) -> Array:
	if _footprints.is_empty(): prepare()
	return _moments[i]

static func _moments_of(i: int) -> Array:
	var s: Dictionary = stations()[i]
	var at := Course.origin(s)
	var out := []
	var k := 0
	for m: Dictionary in Course.moments(s):
		var c: Dictionary = m.duplicate()
		c.at = (m.at as Vector3)-at
		c.index = k
		if c.role == "starter": c.at = starter()
		out.append(c)
		k += 1
	return out

## The starter's middle (its own metres): on the way in, STARTER_OUT before
## the entry.
static func starter() -> Vector3:
	return Vector3(0.0,0.0,STARTER_OUT)

## Station `i`'s challenge settings (FlightCourse `challenge`).
static func challenge(i: int) -> Dictionary:
	return Course.challenge(stations()[i])

## Station `i`'s footprint and box (its own metres): {id, name, mid
## (Vector2, the plate-plane rectangle's middle), half (Vector2, its half
## extents along x and z), lo, hi (Vector3: the box round stone, line,
## collectibles, starter and leads), plinth (bool)}. Worked out once (main
## thread first: `prepare`).
static func footprint(i: int) -> Dictionary:
	if _footprints.is_empty(): prepare()
	return _footprints[i]

## Works every footprint out (on the main thread, before a worker reads
## them).
static func prepare() -> void:
	if not _footprints.is_empty(): return
	_moments = []
	for i in range(count()): _moments.append(_moments_of(i))
	var made := []
	for i in range(count()):
		var lo := Vector3.INF
		var hi := -Vector3.INF
		var plinth := false
		for q: Dictionary in local_solids(i):
			var e := extent(q)
			lo = lo.min((q.middle as Vector3)-e)
			hi = hi.max((q.middle as Vector3)+e)
			if q.get("plinth",false): plinth = true
		for p in line(i):
			lo = lo.min(p)
			hi = hi.max(p)
		for m: Dictionary in _moments[i]:
			lo = lo.min(m.at)
			hi = hi.max(m.at)
		var out := Vector3(0.0,0.0,float(LEADS[-1]))
		lo = lo.min(out-Vector3.ONE*RING_R)
		hi = hi.max(out+Vector3.ONE*RING_R)
		var s: Dictionary = stations()[i]
		made.append({"id":s.id,"name":str(s.name).trim_prefix("Moments: ").get_slice(" (",0),"mid":Vector2((lo.x+hi.x)*0.5,(lo.z+hi.z)*0.5),
			"half":Vector2((hi.x-lo.x)*0.5,(hi.z-lo.z)*0.5),"lo":lo,"hi":hi,"plinth":plinth})
	_footprints = made

# --- A placement's frame ------------------------------------------------------------

## The basis that carries a station's own metres into the plate plane's:
## mirrored across its line (x to -x) if `mirror`, then turned by `turn`
## about y. Not a rotation when mirrored: points only (`place`).
static func frame(turn: float, mirror: bool) -> Basis:
	var b := Basis(Vector3.UP,turn)
	if mirror: b = b*Basis(Vector3(-1,0,0),Vector3.UP,Vector3.BACK)
	return b

## A point of a station's own metres where a placement (`p`: at, turn,
## mirror) stands it (home).
static func place(p: Dictionary, local: Vector3) -> Vector3:
	return (p.at as Vector3)+frame(float(p.turn),bool(p.mirror))*local

## A point of the plate plane back in a placement's own metres.
static func unplace(p: Dictionary, home: Vector3) -> Vector3:
	return frame(float(p.turn),bool(p.mirror)).inverse()*(home-(p.at as Vector3))

## A solid's basis where a placement stands it: a proper rotation (a box
## mirrored is a box), M B M under the turn.
static func solid_basis(b: Basis, turn: float, mirror: bool) -> Basis:
	var m := Basis(Vector3(-1,0,0),Vector3.UP,Vector3.BACK) if mirror else Basis.IDENTITY
	return Basis(Vector3.UP,turn)*m*b*m

## The heading that flies a placement's line (the study's north at turn 0:
## SkyPlane's heading turns the same way as `turn`).
static func heading(p: Dictionary) -> float:
	return float(p.turn)

## True if a point of a placement's own metres stands in its area.
static func in_area(i: int, local: Vector3) -> bool:
	var f := footprint(i)
	var lo: Vector3 = f.lo-Vector3.ONE*AREA
	var hi: Vector3 = f.hi+Vector3.ONE*AREA
	return local.x >= lo.x and local.y >= lo.y and local.z >= lo.z and local.x <= hi.x and local.y <= hi.y and local.z <= hi.z
