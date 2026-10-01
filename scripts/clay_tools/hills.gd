extends "res://scripts/clay_tools/clay_tool.gd"
## The Hills, "Roll": drag across the land and it rises along the way, as
## rolling hills. One verb, worked from the press to the release (the clay's
## paint, scripts/land_clay.gd State.PAINT): the land rises by how far the
## pointer travels, RISE_PER_METRE at the middle for every metre dragged, so
## sweeping back and forth over an area builds it up and nothing has to be
## worked in one spot; held still, the spot still swells, slower
## (RISE_PER_SECOND). How much a point takes is shaped by the land's own
## rolling noise (ROLL, sampled where the point stands, not where the pointer
## is), so a pass leaves a line of hills and saddles instead of an even
## ridge, and passing again lifts the same hills higher. One stroke raises a
## point at most STROKE_MAX over where it began, easing in towards it.
## **Shift:** smaller, gentler hills (FINE of the reach and the rise).
##
## Let go: hills tall enough take the range's rock (ROCK_FROM), and trees that
## cannot hold the new slopes slide down.

const RADIUS := 3.4
const RISE_PER_METRE := 0.6
const RISE_PER_SECOND := 0.4
const STROKE_MAX := 6.0
## The noise's share of the rise runs from ROLL.x (a saddle) to ROLL.y (a
## crown), over features about 1/ROLL_FREQUENCY metres across.
## The noise rarely strays far from 0, so it is read across
## ±ROLL_CONTRAST for crowns and saddles that differ clearly.
const ROLL := Vector2(0.2,1.0)
const ROLL_FREQUENCY := 0.13
const ROLL_CONTRAST := 0.35
const FINE := 0.5
const ROCK_FROM := 4.0

## The stand-in: a faceted wooden roller on a fork, its drum in the icon's tint
## (scripts/hud_icons.gd "hills").
const TINT := Color("8fae78")
const WOOD := Color("b98a58")
const TILT := -18.0

var _last: Variant = null
var _noise := FastNoiseLite.new()
var _peak := 0.0

func id() -> String: return "hills"
func gesture(_verb: String) -> String: return "press"
func prop_tilt() -> float: return TILT
func dirt_share(_verb: String) -> float: return 0.0
func stroke_radius() -> float: return RADIUS*_size()
func mark_size() -> Vector2: return Vector2.ONE*RADIUS
func paints() -> bool: return true

func _size() -> float: return clay.size_scale*(FINE if clay.verb == "fine_hills" else 1.0)

func reset() -> void:
	lift = 0.0
	_last = null
	_peak = 0.0

func paint_begin(fine: bool) -> String:
	_noise.seed = int(clay.editor.land_seed)
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = ROLL_FREQUENCY
	return "fine_hills" if fine else "hills"

func paint_dab(heights: PackedFloat32Array, q: Vector2, work: float) -> float:
	var travelled: float = q.distance_to(_last) if _last != null else 0.0
	_last = q
	var size := _size()
	var rise := (RISE_PER_METRE*travelled+RISE_PER_SECOND*work)*size
	if rise <= 0.0: return 0.0
	var radius := RADIUS*size
	var ceiling := STROKE_MAX*size
	var base: PackedFloat32Array = clay.base
	var points: PackedVector2Array = clay.editor.data.points
	clay.gather(q,radius)
	clay.touch(q,radius)
	for k in clay.near.size():
		var i: int = clay.near[k]
		var t: float = clay.near_d[k]/radius
		var p := points[i]
		var roll := lerpf(ROLL.x,ROLL.y,smoothstep(-ROLL_CONTRAST,ROLL_CONTRAST,_noise.get_noise_2d(p.x,p.y)))
		var room := clampf(1.0-(heights[i]-base[i])/ceiling,0.0,1.0)
		var shape: float = pow(1.0-t*t,2.0)*clay.fade(i)
		heights[i] = minf(heights[i]+rise*shape*roll*room,NativeTerrainData.MAX_HEIGHT)
		_peak = maxf(_peak,heights[i]-base[i])
	return 0.0

func paint_end(_tapped: bool) -> void:
	var area: Rect2 = clay.touched()
	if not area.has_area(): return
	if _peak >= ROCK_FROM: clay.paint_rock(area.get_center(),maxf(area.size.x,area.size.y)*0.5,maxf(2.0,_peak*1.5))
	clay.shake_trees(Vector2.ZERO,0.0,area)

## A faceted roller: a wooden handle down to a fork, a green drum across it.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(8),WOOD,Vector3(0.0,-0.1,0.0),Vector3(0.035,0.6,0.035)))
	root.add_child(part(_prism(6),WOOD.darkened(0.2),Vector3(0.0,-0.42,0.0),Vector3(0.2,0.04,0.03),Vector3(0.0,0.0,PI*0.5)))
	root.add_child(part(_prism(8),TINT,Vector3(0.0,-0.55,0.0),Vector3(0.13,0.36,0.13),Vector3(0.0,0.0,PI*0.5)))
	return root

static func _prism(sides: int) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh
