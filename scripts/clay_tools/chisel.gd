extends "res://scripts/clay_tools/clay_tool.gd"
## The Chisel, "Cut" (docs/design/tools/PLAN.md): the Modeller's grammar with a
## steel edge. It is the only tool that makes crisp rock: faces, cliffs,
## mesas, terraces. Everything it makes is a level flat and a steep face, and
## the faces show the strata (granite in a tall column) while the flats stay
## ground.
##
## - **Drag:** a shelf. The blade is pushed level through the land at the
##   height of the press: along the path a strip SHELF_HALF_WIDTH either side
##   is cut (or filled) dead level, and on its downhill side a face drops
##   FACE_DROP to a narrow lower bench that eases back into the ground. On a
##   slope that is a terrace: a riser cut into the hill behind it, a face in
##   front. Strokes at other heights make a flight of terraces.
## - **Hold, then drag up or down:** a mesa or a pit. A flat-topped block with
##   an irregular straight-sided outline rises with cliff walls, its top
##   following the pointer as the pinch's summit does; drag down and it is a
##   pit with a flat floor and sheer walls.
## - **Tap:** a notch. A small square is knocked NOTCH_DEPTH out of the ground
##   to a flat floor, squared to the fall line (on the flat, to the view), so
##   on a slope it is a single step.
## - **Shift** at the moment the verb is decided: a shallower cut (SHALLOW of
##   every depth and of the hold's travel), the same extent.
##
## The size pips scale every width, never a depth. Each verb is one undo step.
##
## Crispness. The land's points are scattered 0.45 to 0.75 m apart and the
## land is a triangle mesh over them, so the steepest face possible is one
## facet row: the triangles between the last point on the flat and the first
## off it. The chisel therefore never eases a face: a point is either on the
## flat (exactly at its level) or off it (at its own ground, or the bench's),
## and the face is whatever row of triangles spans the step. The flats are
## written exactly level, not moved a share of the way per dab as the
## paddle's trough is, so going over them again cannot roughen them; the only
## eased part is the bench's outer ramp, which is soil, not rock.
##
## Rock. The faces take the strata from the clay's `paint_faces` (bands
## below the plain, earth on a low mesa, the granite core in one CORE_FROM
## tall, scripts/strata.gd): every tint cell the stroke moved whose ground is
## now steep, weighted by its slope alone, with no summit share, so a mesa's top and a shelf stay ground
## however high they stand. (`paint_rock` would not do: it paints only ground
## a stroke raised, and a chisel's faces are mostly cut.) It is laid at
## release, inside the stroke, so the undo step takes it back.

## The shelf, metres at the middle pip. Across the path: level for
## SHELF_HALF_WIDTH either side of the line; then, on the downhill side only,
## a face FACE_DROP down to a bench BENCH wide at that depth, and a ramp RAMP
## wide back up to the untouched ground (a smoothstep: soil, not rock). The
## bench and ramp only ever cut (where the ground already falls away faster,
## the natural slope is the face's foot). The uphill side is never touched,
## so on a slope the cut into the hill stands as a riser behind the shelf.
const SHELF_HALF_WIDTH := 1.2
const FACE_DROP := 1.0
const BENCH := 0.6
const RAMP := 1.2
## The downhill side: the side the ground falls more than FLAT_FALL metres
## to across the stroke's first stretch, read SIDE_NEAR metres out either
## side, else SIDE_PROBE out; on the flat, the side toward the camera, so the
## face is seen. The near reading comes first for a stroke pressed on a bench:
## the terrace above stands a whole face over it within a metre, while past
## the ramp on the other side the ground may stand as high again, so the far
## reading alone can call it flat and send the face toward the camera, into
## the terrace above.
const SIDE_NEAR := 0.9
const SIDE_PROBE := 2.0
const FLAT_FALL := 0.2
## Each dab writes the stretch of path from the last dab to it (at most the
## clay's DAB_SPACING, 0.3 m), squared off STRIP metres past either end, so
## consecutive dabs overlap, and a stroke ends square, not rounded. Round a
## sharp bend the squared strips leave a wedge on the outside of the turn
## unlevelled, as wide as the shelf there (a drag along the foot of a face
## picks now the bench, now the face, so its path zigzags), so the shelf is
## also laid round every joint between dabs, SHELF_HALF_WIDTH out: round at
## the joints, square at the two ends.
const STRIP := 0.1
## The shelf stays at the press's height until the ground on its line falls
## FILL_MAX below it (or climbs CUT_MAX above it); then it steps down (or up)
## by whole FACE_DROPs, so a stroke run down a hill leaves a flight of steps
## rather than a causeway, and one run up it a stair rather than a canyon.
const FILL_MAX := 1.2
const CUT_MAX := 2.0
## A press on a face is a press on the bench at its foot. The land is a
## triangle mesh, so a face is one facet row, and a pointer aimed at a narrow
## bench (BENCH wide) often picks the facet above it instead: taken at its
## own height, the new shelf would stand partway up the face, a sliver of
## fill above the bench it was meant to cut down from. So where the ground
## under the press is steeper than the clay's full face slope
## (land_clay FACE_SLOPE.y, the slope the faces take full rock at), the shelf
## takes the lowest ground within FOOT_REACH metres instead: the bench. It
## never takes anything higher than the press, so a terrace is never raised
## above the bench it was pressed on.
const FOOT_REACH := 0.6
## A shelf with less than FLOOR_ROOM metres between it and the land's
## MIN_HEIGHT is on the floor: it takes no face, and nothing downhill of it is
## cut, so a stroke pressed on a bench at the floor leaves that bench level.
const FLOOR_ROOM := 0.05
## The mesa: outline radius MESA_RADIUS metres at the middle pip, a polygon of
## MESA_SIDES corners (seeded by the spot, so it holds while the hand moves)
## each MESA_JAG of the radius in or out, joined by straight edges: a cut
## block, not a round swell. Its top rises between -PIT_SINK and MESA_RAISE
## metres (the clay's FLOOR still holds a pit), 1:1 with the pointer's travel
## standing at the spot (SHALLOW of it with Shift). The top is written flat
## at the spot's height plus the lift; below FLAT_FROM metres of lift it
## eases in, so a hold let go without moving changes nothing.
const MESA_RADIUS := 2.5
const MESA_SIDES := Vector2i(6,8)
const MESA_JAG := 0.18
const MESA_RAISE := 6.0
const PIT_SINK := 3.0
const FLAT_FROM := 0.3
## The notch: a square NOTCH_HALF metres from its middle to each side (the
## ground mark's chisel square, `mark_size`), its floor
## NOTCH_DEPTH below the ground at the tap. Only cut: where the ground inside
## already lies under the floor it is left, so on a slope the notch is a step.
const NOTCH_HALF := 0.8
const NOTCH_DEPTH := 0.6
## How hard a notch disturbs the life round it (scripts/disturbance.gd), 0..1,
## and the seconds the hand stays down on it, so the knock is seen.
const NOTCH_STRENGTH := 0.6
const KNOCK_SECONDS := 0.2
## Shift: the shallower cut, a share of every depth and of the hold's travel.
const SHALLOW := 0.5
## The stand-in prop, metres at the hand's own size, in the icon's tint
## (scripts/hud_icons.gd "chisel", steel) with a darker and a lighter steel
## and wood handles: the chisel hangs from the grip, its wedge edge down; the
## mallet stands beside it, head up, as the icon draws them.
const TINT := Color("6f8aa6")
const STEEL_DARK := Color("4f6680")
const STEEL_LIGHT := Color("9fb6cc")
const WOOD := Color("9c7444")

var _shallow := false
## The drag: the shelf's level, the downhill side (+1 is the path's right,
## -1 its left, 0 until decided), the last dab, the path's direction there,
## and which points the shelf has taken (never cut into by a later bench).
var _level := 0.0
var _side := 0
var _last := Vector2.ZERO
var _joined := false
var _along := Vector2.ZERO
var _shelf := PackedByteArray()
## The hold: the outline's corners (angle, radius) and the top's own ground.
var _corners: Array[Vector2] = []
var _ground := 0.0
var _shown_lift := INF
var _knock_t := -1.0

func id() -> String: return "chisel"
## The Chisel stands upright in the hand, as its cursor sketch does.
func prop_tilt() -> float: return 0.0
func gesture(verb: String) -> String: return "press" if verb.ends_with("notch") else "grip"
func stroke_radius() -> float: return (SHELF_HALF_WIDTH+BENCH)*clay.size_scale
## The ground mark's square is the notch, the tap's reach: the square the
## ground marks lay in the ground's plane, squared to the fall line as the
## notch is. The shelf levels SHELF_HALF_WIDTH either side of its line and the
## mesa reaches MESA_RADIUS; the hover stands for the tap.
func mark_size() -> Vector2: return Vector2.ONE*NOTCH_HALF

## The depth share: Shift's shallower cut.
func _depth() -> float: return SHALLOW if _shallow else 1.0

func reset() -> void:
	lift = 0.0
	_shallow = false

# --- Drag: the shelf -------------------------------------------------------------------

func drag_begin(fine: bool) -> String:
	_shallow = fine
	_shelf = PackedByteArray()
	_shelf.resize(clay.base.size())
	_level = _press_level(clay.center)
	_side = 0
	_last = clay.center
	_joined = false
	_along = Vector2.ZERO
	return "shallow_shelf" if fine else "shelf"

func dab(heights: PackedFloat32Array, q: Vector2) -> float:
	var from := _last
	var step := q-from
	var length := step.length()
	if length < 0.01: return 0.0
	_last = q
	_along = step/length
	var right := Vector2(-_along.y,_along.x)
	var width: float = clay.size_scale
	var half := SHELF_HALF_WIDTH*width
	var drop := FACE_DROP*_depth()
	if _side == 0: _side = _downhill(q,right)
	_step_level(q,drop)
	# The face drops only as far as the land's floor lets it. On the floor
	# there is no face: the bench and ramp would only cut the ground beside
	# the shelf down to its level, so they are left alone (see FLOOR_ROOM).
	drop = clampf(_level-NativeTerrainData.MIN_HEIGHT,0.0,drop)
	var reach := half+(BENCH+RAMP)*width
	var base: PackedFloat32Array = clay.base
	var points: PackedVector2Array = clay.editor.data.points
	var mid := (from+q)*0.5
	clay.gather(mid,reach+length*0.5+STRIP)
	var near: PackedInt32Array = clay.near
	for k in near.size():
		var i := near[k]
		var d := points[i]-mid
		# Past the strip's ends, only the joint with the last dab's strip.
		if absf(d.dot(_along)) > length*0.5+STRIP and not (_joined and points[i].distance_to(from) <= half): continue
		var s := d.dot(right)*_side
		var fade: float = clay.fade(i)
		if absf(s) <= half:
			# The shelf: dead level, cut or filled.
			_shelf[i] = 1
			heights[i] = clampf(lerpf(base[i],_level,fade),NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
		elif s > half and _shelf[i] == 0 and drop >= FLOOR_ROOM:
			# Downhill of it: the face's foot, a bench, a ramp back up. Only cuts.
			var t := (s-half)/width
			if t >= BENCH+RAMP: continue
			var goal := _level-drop*(1.0-smoothstep(BENCH,BENCH+RAMP,t))
			if goal >= base[i]: continue
			heights[i] = minf(heights[i],maxf(lerpf(base[i],goal,fade),NativeTerrainData.MIN_HEIGHT))
	_joined = true
	clay.touch(mid,reach+length*0.5)
	return reach+length*0.5

## The side of the path the ground falls to, +1 (right) or -1 (left): the
## lower side near, else far (see SIDE_NEAR), or on the flat the side toward
## the camera.
func _downhill(q: Vector2, right: Vector2) -> int:
	var data: NativeTerrainData = clay.editor.data
	for out in [SIDE_NEAR,SIDE_PROBE]:
		var r: Variant = data.sample(q+right*out,clay.base)
		var l: Variant = data.sample(q-right*out,clay.base)
		if r != null and l != null and absf(float(r)-float(l)) > FLAT_FALL: return 1 if float(r) < float(l) else -1
	var eye: Vector3 = clay.editor.terrain.to_local(clay.scene.camera.global_position)
	return 1 if (Vector2(eye.x,eye.z)-q).dot(right) >= 0.0 else -1

## The shelf's level for a press at `at`: the ground there, or on a face the
## bench at its foot (see FOOT_REACH). Never over the ground pressed.
func _press_level(at: Vector2) -> float:
	var data: NativeTerrainData = clay.editor.data
	var base: PackedFloat32Array = clay.base
	var ground: Variant = data.sample(at,base)
	if ground == null: return 0.0
	var level := float(ground)
	var e: float = clay.FACE_REACH
	var slope := Vector2.ZERO
	for axis in [Vector2.RIGHT,Vector2.DOWN]:
		var ahead: Variant = data.sample(at+axis*e,base)
		var behind: Variant = data.sample(at-axis*e,base)
		if ahead == null or behind == null: return level
		slope += axis*(float(ahead)-float(behind))/(2.0*e)
	if slope.length() < float(clay.FACE_SLOPE.y): return level
	var lowest := level
	for k in range(8):
		var way := Vector2.from_angle(TAU*k/8.0)
		for r in [FOOT_REACH*0.5,FOOT_REACH]:
			var h: Variant = data.sample(at+way*r,base)
			if h != null: lowest = minf(lowest,float(h))
	return lowest

## The shelf keeps the press's height until the ground on its line runs
## FILL_MAX under it or CUT_MAX over it, then steps by whole drops. It never
## steps under the land's MIN_HEIGHT or over its MAX_HEIGHT: at the floor the
## shelf stays level where it is, and its face drops only as far as the floor
## lets it (none at all when the shelf is on the floor, so a stroke pressed on
## a bench at the floor leaves that bench level, one step, not a sliver).
func _step_level(q: Vector2, drop: float) -> void:
	var ground: Variant = clay.editor.data.sample(q,clay.base)
	if ground == null: return
	var g := float(ground)
	var steps := 0.0
	if g < _level-FILL_MAX: steps = -ceilf((_level-FILL_MAX-g)/drop)
	elif g > _level+CUT_MAX: steps = ceilf((g-_level-CUT_MAX)/drop)
	if steps < 0.0: steps = maxf(steps,-floorf((_level-NativeTerrainData.MIN_HEIGHT)/drop))
	elif steps > 0.0: steps = minf(steps,floorf((NativeTerrainData.MAX_HEIGHT-_level)/drop))
	_level += drop*steps
	if steps != 0.0: clay.sound(&"chisel_step",q,minf(absf(steps),3.0)/3.0)

## Let go: the faces take rock, and trees the cut left standing on ground
## they cannot hold slide off.
func drag_end() -> bool:
	var area: Rect2 = clay.touched()
	clay.paint_faces(area)
	clay.sound(&"crumble",clay.center,area.get_area()/60.0)
	clay.shake_trees(clay.center,0.0,area)
	return false

# --- Hold: the mesa, or the pit ------------------------------------------------------------

func hold_begin(fine: bool) -> String:
	_shallow = fine
	var ground: Variant = clay.editor.data.sample(clay.center,clay.base)
	_ground = float(ground) if ground != null else 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([clay.editor.land_seed,"chisel",(clay.center as Vector2).snapped(Vector2.ONE*0.01)])
	var count := rng.randi_range(MESA_SIDES.x,MESA_SIDES.y)
	var turn := rng.randf()*TAU
	_corners = []
	for c in range(count):
		_corners.append(Vector2(turn+TAU*(float(c)+rng.randf_range(-0.25,0.25))/count,1.0+rng.randf_range(-MESA_JAG,MESA_JAG)))
	clay.gather(clay.center,_radius()*(1.0+MESA_JAG))
	_shown_lift = INF
	return "shallow_mesa" if fine else "mesa"

func _radius() -> float: return MESA_RADIUS*clay.size_scale

func hold_step(heights: PackedFloat32Array, rise: float) -> bool:
	var share := _depth()
	lift = clampf(rise*share,-PIT_SINK*share,MESA_RAISE*share)
	if is_equal_approx(lift,_shown_lift): return false
	if absf(_shown_lift) < FLAT_FROM and absf(lift) >= FLAT_FROM: clay.sound(&"mesa_break",clay.center,0.5 if _shallow else 1.0)
	_shown_lift = lift
	var top := _ground+lift
	var ease := smoothstep(0.0,FLAT_FROM,absf(lift))
	var radius := _radius()
	var base: PackedFloat32Array = clay.base
	var points: PackedVector2Array = clay.editor.data.points
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	for k in near.size():
		var i := near[k]
		var d := points[i]-(clay.center as Vector2)
		if near_d[k] > radius*_outline(atan2(d.y,d.x)):
			heights[i] = base[i]
			continue
		var goal := top
		if lift < 0.0: goal = minf(base[i],maxf(top,minf(base[i],clay.FLOOR)))
		heights[i] = clampf(lerpf(base[i],goal,ease*clay.fade(i)),NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	var reach := radius*(1.0+MESA_JAG)
	clay.touch(clay.center,reach)
	if lift < 0.0: clay.dirty(clay.center,reach)
	return true

## The outline's radius at angle `theta`, as a share of the mesa's: where the
## ray from the middle crosses the straight edge between the corners either
## side of it.
func _outline(theta: float) -> float:
	var count := _corners.size()
	if count < 3: return 1.0
	for c in range(count):
		var a := _corners[c]
		var b := _corners[(c+1)%count]
		var span := wrapf(b.x-a.x,0.0,TAU)
		var into := wrapf(theta-a.x,0.0,TAU)
		if into > span: continue
		var pa := Vector2.from_angle(a.x)*a.y
		var pb := Vector2.from_angle(b.x)*b.y
		var ray := Vector2.from_angle(theta)
		# Solve ray*r = pa + (pb-pa)*u for r.
		var edge := pb-pa
		var denom := ray.cross(edge)
		if absf(denom) < 1e-6: return a.y
		return pa.cross(edge)/denom
	return 1.0

## Let go: the walls take rock, and trees on the moved ground slide off.
func hold_end() -> void:
	var reach := _radius()*(1.0+MESA_JAG)+1.0
	if absf(lift) >= FLAT_FROM: clay.paint_faces(Rect2(clay.center-Vector2.ONE*reach,Vector2.ONE*reach*2.0))
	clay.shake_trees(clay.center,reach)

# --- Tap: the notch ------------------------------------------------------------------------

func tap(fine: bool) -> void:
	_shallow = fine
	clay.verb = "shallow_notch" if fine else "notch"
	var center: Vector2 = clay.center
	var half: float = NOTCH_HALF*clay.size_scale
	var reach := half*sqrt(2.0)
	clay.open_stroke()
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	var ground: Variant = data.sample(center,heights)
	var floor_at := (float(ground) if ground != null else 0.0)-NOTCH_DEPTH*_depth()
	var axis := _notch_axis(center)
	var cross := Vector2(-axis.y,axis.x)
	clay.gather(center,reach)
	var points := data.points
	for k in clay.near.size():
		var i: int = clay.near[k]
		var d := points[i]-center
		if absf(d.dot(axis)) > half or absf(d.dot(cross)) > half: continue
		var goal := maxf(floor_at,minf(heights[i],clay.FLOOR))
		if goal < heights[i]: heights[i] = lerpf(heights[i],goal,clay.fade(i))
	data.heights = heights
	clay.touch(center,reach+1.0)
	# The notch's floor shows bare earth as a drag's cut does (the clay's dirt,
	# which a tap does not lay by itself), and then its walls take rock over it.
	clay.lay_dirt(center,reach+0.5)
	clay.paint_faces(Rect2(center-Vector2.ONE*(reach+1.0),Vector2.ONE*(reach+1.0)*2.0))
	clay.show_land()
	var at: Vector3 = clay.ground_at(center)
	clay.stir(center,reach,NOTCH_STRENGTH)
	clay.sound(&"chisel_knock",center,0.6 if fine else 1.0)
	clay.close_stroke()
	# The hand comes down on the chisel's butt for a beat.
	clay.hand_gesture("press",at,true)
	_knock_t = 0.0

## The notch's square is set to the fall line at `at` (the ground mark's
## chisel square, ground_marks `_shape`); on the flat, to the view's right.
func _notch_axis(at: Vector2) -> Vector2:
	var data: NativeTerrainData = clay.editor.data
	var e := 0.5
	var hx: Variant = data.sample(at+Vector2(e,0.0),data.heights)
	var lx: Variant = data.sample(at-Vector2(e,0.0),data.heights)
	var hz: Variant = data.sample(at+Vector2(0.0,e),data.heights)
	var lz: Variant = data.sample(at-Vector2(0.0,e),data.heights)
	if hx != null and lx != null and hz != null and lz != null:
		var fall := -Vector2(float(hx)-float(lx),float(hz)-float(lz))
		if fall.length() > 0.02: return fall.normalized()
	var right: Vector3 = clay.editor.terrain.global_basis.inverse()*clay.scene.camera.global_basis.x
	var flat := Vector2(right.x,right.z)
	return flat.normalized() if flat.length() > 0.01 else Vector2.RIGHT

func frame(delta: float) -> void:
	if _knock_t < 0.0: return
	_knock_t += delta
	if _knock_t >= KNOCK_SECONDS: finish()

func finish() -> void:
	if _knock_t < 0.0: return
	_knock_t = -1.0
	if clay.hand_set == "press" and clay.state == clay.State.IDLE: clay.hand_gesture("")

# --- The stand-in prop ------------------------------------------------------------------------

## A faceted chisel and mallet from primitives. The chisel hangs from the
## grip: an octagonal wooden handle through it, a steel ferrule, a square
## steel shank, and a wedge blade whose edge runs across local x at the foot,
## its broad faces looking along ±z (toward the drag, as the clay turns it).
## The mallet stands beside it on +x, head up, handle down, as the icon has
## it. Replaced by the Blender pair's glb later: only this function changes.
func build_prop() -> Node3D:
	var root := Node3D.new()
	# The chisel.
	root.add_child(part(_prism(8),WOOD,Vector3(0.0,0.05,0.0),Vector3(0.05,0.42,0.05)))
	root.add_child(part(_prism(8),STEEL_LIGHT,Vector3(0.0,0.28,0.0),Vector3(0.056,0.05,0.056)))
	root.add_child(part(_prism(8),STEEL_DARK,Vector3(0.0,-0.18,0.0),Vector3(0.058,0.06,0.058)))
	root.add_child(part(BoxMesh.new(),STEEL_DARK,Vector3(0.0,-0.38,0.0),Vector3(0.06,0.36,0.045)))
	root.add_child(part(_wedge(),TINT,Vector3(0.0,-0.64,0.0),Vector3(0.16,0.18,0.06)))
	# The mallet.
	root.add_child(part(_prism(6),WOOD,Vector3(0.3,-0.12,0.0),Vector3(0.035,0.62,0.035)))
	root.add_child(part(_prism(8),TINT,Vector3(0.3,0.26,0.0),Vector3(0.085,0.3,0.085),Vector3(0.0,0.0,PI*0.5)))
	return root

## An upright n-sided prism, unit radius and height.
static func _prism(sides: int) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh

## A unit wedge: a square top at y +0.5 narrowing to an edge along x at
## y -0.5, the chisel's cutting end.
static func _wedge() -> Mesh:
	var t0 := Vector3(-0.5,0.5,-0.5)
	var t1 := Vector3(0.5,0.5,-0.5)
	var t2 := Vector3(0.5,0.5,0.5)
	var t3 := Vector3(-0.5,0.5,0.5)
	var e0 := Vector3(-0.5,-0.5,0.0)
	var e1 := Vector3(0.5,-0.5,0.0)
	var faces := [t0,t2,t1, t0,t3,t2, t3,e0,e1, t3,e1,t2, t1,e1,e0, t1,e0,t0, t0,e0,t3, t2,e1,t1]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for v: Vector3 in faces:
		vertices.append(v)
		normals.append(v.normalized())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
