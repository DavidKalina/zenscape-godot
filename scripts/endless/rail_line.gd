extends RefCounted
## The railroad's line on seed 1's land: the rail path (spec-railroad.md, "the
## contract"). A double track round the Peak, one lap `length()` m, its data
## made by tools/rail_line.py from the drafted route
## (docs/design/endless-flight/railroad/) and read from PATH.
##
## s runs anticlockwise on the map from the start station (s = 0): north-east
## shore, farm town, the west tunnel, mine town, cattle town, the bay bridge.
## Every call wraps s round the loop.
##
## - `pose(s, track)`: the centre of a track's rails on the bed. Its basis's -z
##   is that track's travel direction (track 0 along +s, track 1 along -s: the
##   trains run opposite ways, each on its right), y is up off the bed (tilted
##   by the grade only), x is the travel's right. s is the centre line's: on
##   a curve the outer track runs (1 + gap/2/r) m per m of s, the inner one
##   less (5% either way on the tightest, r = 160 m).
## - `kind(s)`: grade, cut, fill, tunnel, trestle or bridge.
## - `pieces()`: the named stations, towns, tunnels, trestles and bridges, each
##   with its handle (`rail/<piece>`) through LayoutOverrides (AGENTS.md
##   Handles). Keep the names stable: layouts key on them.
##
## Use: `const RailLine = preload("res://scripts/endless/rail_line.gd")`, then
## `RailLine.shared()` (loaded once) or `RailLine.new()`.

const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const PATH := "res://assets/railroad/rail_line.json"
## The toy-era width of the gap between two trains side by side, car side to
## car side: an opening to thread (WorldScale.opening; 10 m at the defaults).
const TOY_BETWEEN := 5.0
## The widest car the line is laid for: the trains' cars are no wider.
const CAR_WIDTH := 6.0

static var _shared: RefCounted

var step := 4.0
var _length := 0.0
var _n := 0
var _x := PackedFloat64Array()
var _z := PackedFloat64Array()
var _y := PackedFloat64Array()
var _kind_s := PackedFloat64Array()   # each stretch's start
var _kind := PackedStringArray()
var _pieces: Array[Dictionary] = []
var ok := false

## The line, loaded once for everyone.
static func shared() -> RefCounted:
	if _shared == null: _shared = new()
	return _shared

func _init(path := PATH) -> void:
	if not FileAccess.file_exists(path):
		push_error("rail line: %s missing (tools/rail_line.py makes it)" % path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("rail line: %s is not a JSON object" % path)
		return
	var d: Dictionary = parsed
	step = float(d.get("step", 4.0))
	_x = PackedFloat64Array(d.get("x", []))
	_z = PackedFloat64Array(d.get("z", []))
	_y = PackedFloat64Array(d.get("y", []))
	_n = _x.size()
	_length = _n*step
	for k: Array in d.get("kinds", []):
		_kind.append(str(k[0]))
		_kind_s.append(float(k[1]))
	for p: Dictionary in d.get("pieces", []):
		_pieces.append(p)
	ok = _n > 3 and _z.size() == _n and _y.size() == _n and not _kind.is_empty()

## One lap, in metres.
func length() -> float:
	return _length

## Track centre to track centre: a car's width and the opening between trains.
func track_gap() -> float:
	return CAR_WIDTH + WorldScale.opening(TOY_BETWEEN)

func wrap_s(s: float) -> float:
	return fposmod(s, _length)

## The middle of the bed (between the tracks) at s, on the bed's top.
func centre(s: float) -> Vector3:
	var u := wrap_s(s)/step
	var i := int(u)
	var t := u - i
	var p0 := _at(i - 1)
	var p1 := _at(i)
	var p2 := _at(i + 1)
	var p3 := _at(i + 2)
	# Catmull-Rom on the evenly spaced samples: through each one, smooth between
	var t2 := t*t
	var t3 := t2*t
	return 0.5*((2.0*p1) + (p2 - p0)*t + (2.0*p0 - 5.0*p1 + 4.0*p2 - p3)*t2 + (3.0*p1 - p0 - 3.0*p2 + p3)*t3)

## The unit direction of +s at s (with the grade in it).
func tangent(s: float) -> Vector3:
	var u := wrap_s(s)/step
	var i := int(u)
	var t := u - i
	var p0 := _at(i - 1)
	var p1 := _at(i)
	var p2 := _at(i + 1)
	var p3 := _at(i + 2)
	var d := 0.5*((p2 - p0) + 2.0*(2.0*p0 - 5.0*p1 + 4.0*p2 - p3)*t + 3.0*(3.0*p1 - p0 - 3.0*p2 + p3)*t*t)
	return d.normalized()

## The bed's top (world y) at s.
func bed(s: float) -> float:
	return centre(s).y

## Track 0 or 1's centre at s; -z its travel direction, y up off the bed.
func pose(s: float, track: int) -> Transform3D:
	var fwd := tangent(s)
	var up := (Vector3.UP - fwd*fwd.dot(Vector3.UP)).normalized()
	var right := fwd.cross(up)
	var o := centre(s) + right*(track_gap()*0.5*(1.0 if track == 0 else -1.0))
	if track != 0:
		fwd = -fwd
		right = -right
	return Transform3D(Basis(right, up, -fwd), o)

## What the bed is at s: grade, cut, fill, tunnel, trestle or bridge.
func kind(s: float) -> String:
	if _kind.is_empty(): return "grade"
	var i := _kind_s.bsearch(wrap_s(s), false) - 1
	return _kind[clampi(i, 0, _kind.size() - 1)]

## The stretches of one kind: [[s0, s1], ...].
func stretches(of_kind: String) -> Array:
	var out: Array = []
	for i in _kind.size():
		if _kind[i] != of_kind: continue
		var s1 := _kind_s[i + 1] if i + 1 < _kind.size() else _length
		out.append([_kind_s[i], s1])
	return out

## The named pieces: {name ("rail/<piece>"), kind (station, town, tunnel,
## trestle, bridge), s0, s1, xform (the handle's: the centre pose at the
## piece's middle, -z along +s, unless the layout moved it)}; a town's place
## on the map is `place`. Pieces the layout deletes are left out.
func pieces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Dictionary in _pieces:
		var name := str(p.name)
		if LayoutOverrides.deleted(name): continue
		var s0 := float(p.s0)
		var s1 := float(p.s1)
		var mid := (s0 + s1)*0.5
		var coded := Transform3D(pose(mid, 0).basis, centre(mid))
		var q := {"name": name, "kind": str(p.kind), "s0": s0, "s1": s1,
				"xform": LayoutOverrides.xform(name, coded)}
		if p.has("x"): q["place"] = Vector2(float(p.x), float(p.z))
		out.append(q)
	return out

## One piece by name ("rail/west-tunnel"), else {}.
func piece(name: String) -> Dictionary:
	for p: Dictionary in pieces():
		if p.name == name: return p
	return {}

## The nearest s to a world XZ point and the distance to the centre line,
## by brute force over the samples (for tools and drivers, not the frame).
func nearest(x: float, z: float) -> Vector2:
	var best := INF
	var bi := 0
	for i in _n:
		var d := Vector2(_x[i] - x, _z[i] - z).length_squared()
		if d < best:
			best = d
			bi = i
	return Vector2(bi*step, sqrt(best))

func _at(i: int) -> Vector3:
	var j := posmod(i, _n)
	return Vector3(_x[j], _y[j], _z[j])
