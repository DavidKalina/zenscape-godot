extends "res://scripts/clay_tools/clay_tool.gd"
## The Sculpt, "Shape": a trowel that paints the land. Unlike the other tools
## it does not read the tap/drag/hold grammar: it works the land from the
## press to the release, wherever the pointer is, held still or dragged (the
## clay's paint, scripts/land_clay.gd State.PAINT). What it does is its mode,
## picked on its fan in the tool roll (`modes`) or with Q and E while it is
## in hand:
##
## - **Raise:** the ground under the trowel swells while it is held, faster
##   at the middle. Drag to draw a ridge, hold still to build a mound.
##   **Shift** lowers instead.
## - **Lower:** the same, down; bare earth shows where it goes deep. **Shift**
##   raises instead.
## - **Hills:** rolling hills set down along the drag, HILL_GAP apart and
##   jittered off the path, each its own size, lean and spread, rising in
##   over HILL_RISE. Held still, the last one keeps growing. Hills meet as the
##   higher of the two, so a drag through a hill already there rolls over it
##   instead of stacking. **Shift** presses hollows instead.
## - **Smooth:** softens whatever is under it while held. **Shift** levels it
##   to the height under the press.
##
## A quick click works for the clay's TAP_WORK at the spot, so a click leaves
## a mark. Let go, a raise tall enough takes the range's rock, cut faces show
## their strata, and trees that cannot hold the new slope slide down.

const MODES := [{"id":"raise","kind":"paint"},{"id":"lower","kind":"paint"},{"id":"hills","kind":"paint"},{"id":"smooth","kind":"paint"}]
## Shift's mode for each.
const SHIFTED := {"raise":"lower","lower":"raise","hills":"hollows","smooth":"flatten"}

## Raise and lower: radius (m) and metres a second at the middle, falling
## off as (1-t²)² to the rim.
const BRUSH_RADIUS := 2.4
const RAISE_RATE := 1.6
## Hills: a hill's radius and height (m, chosen between x and y), its
## footprint's aspect (across over along, between x and y), metres of path
## between hills, the share of HILL_GAP a hill sits off the path either side,
## seconds a hill takes to rise in, how fast the last one grows held still
## (m/s), how much wider it gets per metre it grows, and its tallest.
const HILL_RADIUS := Vector2(2.6,4.2)
const HILL_HEIGHT := Vector2(0.8,2.2)
const HILL_ASPECT := Vector2(0.6,1.0)
const HILL_GAP := 3.2
const HILL_SIDE := 0.45
const HILL_RISE := 0.3
const HILL_GROW := 1.2
const HILL_WIDEN := 0.5
const HILL_MAX := 7.0
## Smooth and flatten: radius (m) and the rate (1/s) a point closes on its
## neighbours' mean or the level at the middle.
const SMOOTH_RADIUS := 2.2
const SMOOTH_RATE := 7.0
const FLATTEN_RATE := 4.0
## Let go, a raise or a hill of at least ROCK_FROM metres takes the range's
## granite (as the Modeller's pinch does).
const ROCK_FROM := 2.5
## How much of the bare earth a lowering shows (land_clay's dirt).
const LOWER_DIRT := 0.7

## The stand-in trowel, metres at the hand's own size: a turned wooden
## handle, a brass ferrule, a bent neck and a kite-shaped steel blade, point
## down. The blade in the icon's tint (scripts/hud_icons.gd "sculpt").
const TINT := Color("9fb0a0")
const WOOD := Color("b98a58")
const BRASS := Color("c2a35a")
const HANDLE := Vector2(0.045,0.38)
const BLADE := Vector3(0.16,0.26,0.02)
const TILT := -14.0

var _rng := RandomNumberGenerator.new()
## This press's hills: {at, along (unit), r0, h0, h, aspect, age, from}.
var _hills: Array[Dictionary] = []
var _level := 0.0
## The most the press has raised the ground anywhere (m), for the rock.
var _peak := 0.0

func id() -> String: return "sculpt"
func modes() -> Array: return MODES
func gesture(_verb: String) -> String: return "press"
func prop_tilt() -> float: return TILT
func turns_lip(_verb: String) -> bool: return false
func dirt_share(verb: String) -> float: return LOWER_DIRT if verb in ["lower","hollows"] else 1.0
func stroke_radius() -> float: return _radius()*_size()
func mark_size() -> Vector2: return Vector2.ONE*_radius()

func _size() -> float: return clay.size_scale

func _radius() -> float:
	match mode:
		"hills": return HILL_RADIUS.y
		"smooth": return SMOOTH_RADIUS
	return BRUSH_RADIUS

func reset() -> void:
	lift = 0.0
	_hills.clear()
	_peak = 0.0

# --- Paint ---------------------------------------------------------------------------

func paints() -> bool: return true

func paint_begin(fine: bool) -> String:
	_rng.seed = hash([clay.center.snapped(Vector2.ONE*0.01),Time.get_ticks_msec()])
	var ground: Variant = clay.editor.data.sample(clay.center,clay.base)
	_level = float(ground) if ground != null else 0.0
	return SHIFTED[mode] if fine else mode

## The hills rising in.
func paint_frame(heights: PackedFloat32Array, delta: float, ending: bool) -> bool:
	var wrote := false
	for hill in _hills:
		if hill.age >= HILL_RISE: continue
		hill.age = HILL_RISE if ending else minf(hill.age+delta,HILL_RISE)
		_write_hill(heights,hill)
		wrote = true
	return wrote

func paint_dab(heights: PackedFloat32Array, q: Vector2, work: float) -> float:
	var verb: String = clay.verb
	match verb:
		"raise", "lower": return _brush(heights,q,work,1.0 if verb == "raise" else -1.0)
		"hills", "hollows": return _hill_dab(heights,q,work)
		"smooth": _smooth(heights,q,work)
		"flatten": return _flatten(heights,q,work)
	return 0.0

func paint_end(_tapped: bool) -> void:
	var area: Rect2 = clay.touched()
	if area.has_area():
		var verb: String = clay.verb
		if verb in ["raise","hills"] and _peak >= ROCK_FROM:
			clay.paint_rock(area.get_center(),maxf(area.size.x,area.size.y)*0.5,maxf(2.0,_peak))
		if verb in ["lower","hollows","flatten"]: clay.paint_faces(area)
		clay.shake_trees(Vector2.ZERO,0.0,area)
	_hills.clear()

# --- Raise and lower ----------------------------------------------------------------

func _brush(heights: PackedFloat32Array, q: Vector2, work: float, way: float) -> float:
	var radius := BRUSH_RADIUS*_size()
	var rate := RAISE_RATE*_size()*work*way
	var base: PackedFloat32Array = clay.base
	clay.gather(q,radius)
	clay.touch(q,radius)
	for k in clay.near.size():
		var i: int = clay.near[k]
		var t: float = clay.near_d[k]/radius
		var h: float = heights[i]+rate*pow(1.0-t*t,2.0)*clay.fade(i)
		if way < 0.0: h = maxf(h,minf(base[i],clay.FLOOR))
		heights[i] = clampf(h,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
		_peak = maxf(_peak,heights[i]-base[i])
	return radius if way < 0.0 else 0.0

# --- Hills ----------------------------------------------------------------------------

## A hill set down HILL_GAP along the path from the last, else the last one
## grows by `work`.
func _hill_dab(heights: PackedFloat32Array, q: Vector2, work: float) -> float:
	var gap := HILL_GAP*_size()
	if _hills.is_empty() or q.distance_to(_hills[-1].from) >= gap:
		var along: Vector2 = clay.heading if clay.heading != Vector2.ZERO else Vector2.from_angle(_rng.randf()*TAU)
		var side: Vector2 = along.orthogonal()*_rng.randf_range(-HILL_SIDE,HILL_SIDE)*gap
		if _hills.is_empty(): side = Vector2.ZERO
		var h := _rng.randf_range(HILL_HEIGHT.x,HILL_HEIGHT.y)*_size()
		var hill := {"at":q+side,"from":q,"along":along.rotated(_rng.randf_range(-0.6,0.6)),
			"r0":_rng.randf_range(HILL_RADIUS.x,HILL_RADIUS.y)*_size(),"h0":h,"h":h,
			"aspect":_rng.randf_range(HILL_ASPECT.x,HILL_ASPECT.y),"age":0.0}
		_hills.append(hill)
		clay.sound(&"pat",hill.at,h/HILL_HEIGHT.y)
		_write_hill(heights,hill)
	elif work > 0.0:
		var hill: Dictionary = _hills[-1]
		hill.h = minf(float(hill.h)+HILL_GROW*_size()*work,HILL_MAX*_size())
		_write_hill(heights,hill)
	return _hill_radius(_hills[-1]) if clay.verb == "hollows" else 0.0

func _hill_radius(hill: Dictionary) -> float:
	return float(hill.r0)+HILL_WIDEN*(float(hill.h)-float(hill.h0))

## The hill as it stands (risen in by its age): every point under its
## footprint at least that high over the ground the press began on (hollows:
## at most that low under it).
func _write_hill(heights: PackedFloat32Array, hill: Dictionary) -> void:
	var radius := _hill_radius(hill)
	var rise := smoothstep(0.0,1.0,float(hill.age)/HILL_RISE)
	var amount: float = float(hill.h)*rise
	var at: Vector2 = hill.at
	var along: Vector2 = hill.along
	var across := along.orthogonal()
	var aspect: float = hill.aspect
	var hollow: bool = clay.verb == "hollows"
	var base: PackedFloat32Array = clay.base
	var points: PackedVector2Array = clay.editor.data.points
	clay.gather(at,radius)
	clay.touch(at,radius)
	for k in clay.near.size():
		var i: int = clay.near[k]
		var d := points[i]-at
		var t := Vector2(d.dot(along),d.dot(across)/aspect).length()/radius
		if t >= 1.0: continue
		var shape: float = pow(1.0-t*t,2.0)*clay.fade(i)
		if hollow:
			heights[i] = maxf(minf(heights[i],base[i]-amount*shape),minf(base[i],clay.FLOOR))
		else:
			heights[i] = minf(maxf(heights[i],base[i]+amount*shape),NativeTerrainData.MAX_HEIGHT)
			_peak = maxf(_peak,heights[i]-base[i])
	if hollow: clay.dirty(at,radius)

# --- Smooth and flatten -----------------------------------------------------------------

func _smooth(heights: PackedFloat32Array, q: Vector2, work: float) -> void:
	var radius := SMOOTH_RADIUS*_size()
	var neighbors: Array[PackedInt32Array] = clay.editor.data._neighbors
	clay.gather(q,radius)
	clay.touch(q,radius)
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	# Every mean read before any point moves, so the dab does not drift.
	var means := PackedFloat32Array()
	means.resize(near.size())
	for k in near.size():
		var around: PackedInt32Array = neighbors[near[k]]
		var total := 0.0
		for j in around: total += heights[j]
		means[k] = total/around.size() if not around.is_empty() else heights[near[k]]
	for k in near.size():
		var i := near[k]
		var t := near_d[k]/radius
		var f: float = pow(1.0-t*t,2.0)*clay.fade(i)
		heights[i] = lerpf(heights[i],means[k],1.0-exp(-SMOOTH_RATE*work*f))

func _flatten(heights: PackedFloat32Array, q: Vector2, work: float) -> float:
	var radius := SMOOTH_RADIUS*_size()
	clay.gather(q,radius)
	clay.touch(q,radius)
	for k in clay.near.size():
		var i: int = clay.near[k]
		var t: float = clay.near_d[k]/radius
		var f: float = (1.0-smoothstep(0.5,1.0,t))*clay.fade(i)
		heights[i] = maxf(lerpf(heights[i],_level,1.0-exp(-FLATTEN_RATE*work*f)),NativeTerrainData.MIN_HEIGHT)
	return radius

# --- The stand-in prop ------------------------------------------------------------------

## A faceted trowel from primitives: an eight-sided wooden handle, a brass
## ferrule, a short neck and a four-sided blade, point down, thin across
## the way it pushes. Replaced by a Blender glb later: only this function
## changes.
func build_prop() -> Node3D:
	var root := Node3D.new()
	var top := 0.2
	root.add_child(part(_prism(8,0.8),WOOD,Vector3(0.0,top-HANDLE.y*0.5,0.0),Vector3(HANDLE.x,HANDLE.y,HANDLE.x)))
	var foot := top-HANDLE.y
	root.add_child(part(_prism(8),BRASS,Vector3(0.0,foot-0.025,0.0),Vector3(HANDLE.x*0.85,0.05,HANDLE.x*0.85)))
	root.add_child(part(_prism(6),TINT.darkened(0.25),Vector3(0.0,foot-0.1,0.0),Vector3(0.012,0.12,0.012)))
	root.add_child(part(_kite(),TINT,Vector3(0.0,foot-0.16-BLADE.y,0.0),BLADE))
	return root

static func _prism(sides: int, foot := 1.0) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = foot
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh

## A four-sided double cone (an octahedron), unit half-width and height:
## the trowel's blade.
static func _kite() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	return mesh
