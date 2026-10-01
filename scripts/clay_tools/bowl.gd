extends "res://scripts/clay_tools/clay_tool.gd"
## The Bowl, "Hollow": drag across the land and it is pressed out into a soft
## basin along the way. One verb, worked from the press to the release (the
## clay's paint, scripts/land_clay.gd State.PAINT). The basin's floor is level,
## DEPTH under the ground where the press began, full across the inner FLOOR of
## the reach and rounding up to the untouched ground at its rim, so a drag
## leaves a pan a pond can fill, its banks gentle. Each metre dragged takes
## the ground a share of the way there (SINK_PER_METRE, as a rate), and held
## still it keeps sinking (SINK_PER_SECOND); it only ever lowers ground, and
## never below the floor. A new press presses from where the ground now
## stands, so pressing again deepens it.
## **Shift:** a smaller, shallower bowl (FINE of the reach and the depth).
##
## Let go: the cut banks show their strata, and trees that cannot hold them
## slide down.

const RADIUS := 3.0
const DEPTH := 1.4
const FLOOR := 0.45
const SINK_PER_METRE := 0.9
const SINK_PER_SECOND := 1.6
const FINE := 0.55
## How much of the clay's bare earth its floor shows.
const DIRT := 0.5

## The stand-in: a faceted wooden scoop, its bowl in the icon's tint
## (scripts/hud_icons.gd "bowl").
const TINT := Color("a08a68")
const WOOD := Color("b98a58")
const TILT := -16.0

var _last: Variant = null
var _level := 0.0

func id() -> String: return "bowl"
func gesture(_verb: String) -> String: return "press"
func prop_tilt() -> float: return TILT
func dirt_share(_verb: String) -> float: return DIRT
func stroke_radius() -> float: return RADIUS*_size()
func mark_size() -> Vector2: return Vector2.ONE*RADIUS
func paints() -> bool: return true

func _size() -> float: return clay.size_scale*(FINE if clay.verb == "fine_bowl" else 1.0)

func reset() -> void:
	lift = 0.0
	_last = null

func paint_begin(fine: bool) -> String:
	var ground: Variant = clay.editor.data.sample(clay.center,clay.base)
	_level = float(ground) if ground != null else 0.0
	return "fine_bowl" if fine else "bowl"

func paint_dab(heights: PackedFloat32Array, q: Vector2, work: float) -> float:
	var travelled: float = q.distance_to(_last) if _last != null else 0.0
	_last = q
	var share := 1.0-exp(-(SINK_PER_METRE*travelled+SINK_PER_SECOND*work))
	if share <= 0.0: return 0.0
	var radius := RADIUS*_size()
	var depth := DEPTH*(FINE if clay.verb == "fine_bowl" else 1.0)
	clay.gather(q,radius)
	clay.touch(q,radius)
	for k in clay.near.size():
		var i: int = clay.near[k]
		var t: float = clay.near_d[k]/radius
		var f := 1.0-smoothstep(FLOOR,1.0,t)
		var goal := maxf(_level-depth*f,clay.FLOOR)
		if heights[i] <= goal: continue
		heights[i] = lerpf(heights[i],goal,share*f*clay.fade(i))
	return radius

func paint_end(_tapped: bool) -> void:
	var area: Rect2 = clay.touched()
	if not area.has_area(): return
	clay.paint_faces(area)
	clay.shake_trees(Vector2.ZERO,0.0,area)

## A faceted scoop: a wooden handle down to a round, shallow bowl.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(8),WOOD,Vector3(0.0,-0.12,0.0),Vector3(0.03,0.6,0.03)))
	var cup := SphereMesh.new()
	cup.radius = 1.0
	cup.height = 2.0
	cup.radial_segments = 8
	cup.rings = 4
	cup.is_hemisphere = true
	root.add_child(part(cup,TINT,Vector3(0.0,-0.44,0.0),Vector3(0.17,0.12,0.17),Vector3(PI,0.0,0.0)))
	return root

static func _prism(sides: int) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh
