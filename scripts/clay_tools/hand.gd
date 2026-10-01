extends "res://scripts/clay_tools/clay_tool.gd"
## The Modeller (docs/scenic/modeless.md "Land as clay"; docs/design/tools/PLAN.md
## "The Modeller"), the tool the clay starts with: a sculptor's boxwood modelling
## tool in the roll's first pocket, which was the bare Hand's. It keeps the
## Hand's verbs, the ones the clay had before the tools, and their names (the
## thumb, the palm, the pinch: what a sculptor's hand does with the tool), and
## keeps the id `hand`, so saves, probes and `LandClay.hand` read as before.
##
## - **Tap:** a poke. A small dimple rings out at the spot and the land comes
##   back exactly; a resident nearby looks round. Nothing is kept, no undo step.
## - **Drag:** the thumb. How fast the pointer travels decides it, blended: a
##   slow stroke digs a channel along the path, a fast back-and-forth rub
##   smooths the land under it. **Shift** makes it the palm, which levels the
##   land to a little under the height under the press, a pan a pond can fill.
## - **Hold, then drag:** the pinch. Up raises and down sinks the pinched spot,
##   directly: the summit follows the pointer. A low raise is a soft swell; a
##   tall one draws up into a horn, the edge spring's jagged peaks' kind, and is
##   painted with their rock when let go. Trees that cannot hold its flanks
##   slide to its foot. **Shift** makes it a smaller, gentler pinch.
##
## The thumb's speed blend, pointer pixels per second over the clay's
## SPEED_WINDOW (path length, so a rub's turns do not read as slow): at
## GROOVE_SPEED and under it only digs, at RUB_SPEED and over it only smooths,
## and between it does some of each.
const GROOVE_SPEED := 500.0
const RUB_SPEED := 1200.0
## The groove: half-width and depth in metres below the ground on the stroke's
## line. Across, it follows the ground: each point sinks by the line's depth
## from where it stood, so on a slope's face the uphill bank is cut no deeper
## than the downhill one (a level bed across cut 1.5-2.5 m into a flank and
## read as a trench). Full depth inside GROOVE_FLOOR of the half-width (the
## land's points are 0.45 to 0.75 m apart, so a row or two always reaches the
## bed), easing to the untouched ground at the half-width on a smoothstep, so
## the floor and the banks are rounded and the banks stay gentle. A lip of
## GROOVE_LIP metres (enough for its facets to catch the light) rises just
## outside (to LIP_OUT half-widths), the clay the thumb pushed aside. Each dab
## moves the ground GROOVE_STEP of the way to that shape, and a stroke never
## digs below it however long it lingers: a groove is even and unbroken.
## The bed never climbs along the stroke, so a downhill stroke is a channel
## that keeps falling across the ground's bumps; it cuts at most GROOVE_CUT
## metres deeper than GROOVE_DEPTH to do so, and past that it rises with a
## hump (an uphill stroke: level, then rising, so it drains back to its start).
const GROOVE_HALF_WIDTH := 1.35
const GROOVE_DEPTH := 0.75
const GROOVE_FLOOR := 0.35
const GROOVE_LIP := 0.12
const LIP_OUT := 1.6
const GROOVE_STEP := 0.5
const GROOVE_CUT := 0.2
## The rub: radius in metres, and the share each dab moves a point toward the
## mean of its neighbours at the centre (easing to nothing at the rim from
## RUB_CORE of the radius).
const RUB_RADIUS := 1.6
const RUB_STEP := 0.45
const RUB_CORE := 0.5
## The palm: radius in metres, and the share each dab moves a point toward
## the level under the press (full inside PALM_CORE of the radius). The level
## is pressed PALM_SINK metres below the ground under the press, easing to
## none at the rim, so the palm leaves a level-floored pan a pond can fill;
## each stroke presses from the ground as it stands, so pressing again deepens it.
const PALM_RADIUS := 2.0
const PALM_STEP := 0.5
const PALM_CORE := 0.55
const PALM_SINK := 0.4
## The pinch. The pinched spot rises by the pointer's travel up the screen at
## the scale of a metre standing there (so the summit keeps to the pointer),
## `(1-t²)²` falloff over a radius that widens with the height: R0 plus GROW
## per metre, at most MAX_RADIUS. The lift is between -SINK and RAISE metres,
## and sinking never takes ground below the clay's FLOOR (the land brush's
## floor). A Shift pinch is FINE_SCALE of the travel over a smaller spread.
##
## A raise turns from that rounded swell into a horn as it grows (HORN, metres
## of lift, as a smoothstep), the edge spring's peaks' kind (mountain_forms
## "alpine", scripts/edge_spring.gd `_build_range`): concave faces up to a
## sharp summit, three to five arêtes (seeded by the spot, so they hold while
## the hand moves) standing proud between hollows, and the forms' crag noise
## over the flanks, the outline wandering by the forms' lump noise (so the
## points are gathered HORN_REACH of the widest radius out). The summit still
## keeps to the pointer. Sinks stay rounded.
const PINCH := {"r0":2.2,"grow":0.45,"max_radius":5.6,"raise":8.0,"sink":4.0,"scale":1.0}
const FINE_PINCH := {"r0":1.2,"grow":0.3,"max_radius":2.6,"raise":2.0,"sink":1.0,"scale":0.4}
const HORN := Vector2(1.0,4.0)
const HORN_REACH := 1.25
## Let go, a raise of at least ROCK_FROM metres takes the range's granite on
## its steeps and upper share (mountain_forms `_rock_tint`), measured against
## a height that keeps a low swell green, as the range's gentle pulls do.
## The hand's bare earth keeps its colour.
const ROCK_FROM := 2.5
## The poke: a dimple POKE_DEPTH metres deep over POKE_RADIUS, ringing out
## over POKE_SECONDS.
const POKE_DEPTH := 0.1
const POKE_RADIUS := 1.2
const POKE_SECONDS := 0.5
const POKE_RATE := 26.0
const POKE_DAMP := 7.0
## How hard a poke disturbs the life round it (scripts/disturbance.gd), 0..1.
const POKE_STRENGTH := 0.7
## A thumb's groove that runs into the edge fade heading out of the plate (its
## travel within BREACH_ANGLE degrees of straight out across the nearest
## side) breaches the rim: it digs at full depth to the lip and notches the
## rim, a spillway the live water runs off (docs/scenic/modeless.md, "The
## thumb at the rim"). A stroke let go, or run off the plate, while breaching
## is carried on to BREACH_PAST metres beyond the rim (the clay's PLATE_HALF),
## so the rim's own points take the groove's bed. Only the groove itself is
## dug so: its banks' raised lip, the pinch, the palm, the rub and a thumb
## running along the edge still fade, so the plate's outline stays clean
## round the notch.
const BREACH_ANGLE := 50.0
const BREACH_PAST := 0.4

## The stand-in modelling tool, metres at the hand's own size: a pale boxwood
## shaft, a short point standing over the grip, and a rounded spatula hanging
## below it, its working end, in the icon's tint (scripts/hud_icons.gd "hand"),
## the wood darkened by wet clay. A darker band of it marks the grip.
const TINT := Color("e0a07a")
const WOOD := Color("ecd2a2")
const BAND := Color("b87c58")
const SHAFT_LENGTH := 0.9
const SHAFT_RADIUS := 0.032
## The spatula's half extents (m): across, along the shaft, and thin across
## the way it pushes (local z).
const SPATULA := Vector3(0.1,0.17,0.03)
## The point standing over the grip (m).
const POINT_LENGTH := 0.18
## The cursor sketch's lean: held as a pencil is, its spatula drawn through
## the clay, so it leans further than the Hand's -12 did.
const TILT := -20.0

## The thumb's rub share, 0..1.
var rub := 0.0
var poking := false
var _stroking := 0.0
var _dug := PackedByteArray()
var _bed := INF
var _level := 0.0
var _shown_lift := INF
var _aretes := PackedFloat32Array()
var _jag := PackedFloat32Array()
var _lump := PackedFloat32Array()
## The outward normal of the side the thumb's last dab breached (zero when
## it did not), and whether the stroke has been carried to the lip.
var _breach := Vector2.ZERO
var _carried := false
var _poke_t := 0.0
var _poke_base := PackedFloat32Array()
var _poke_idx := PackedInt32Array()
var _poke_shape := PackedFloat32Array()
var _poke_written := PackedFloat32Array()

## The fan's modes (clay_tool `modes`): the pinch, the thumb's groove, the
## palm (a drag pressed as Shift does) and the poke.
const MODES := [{"id":"pinch","kind":"hold"},{"id":"groove","kind":"drag"},{"id":"palm","kind":"drag","fine":true},{"id":"poke","kind":"tap"}]
func modes() -> Array: return MODES
func id() -> String: return "hand"
func hover_gesture() -> String: return "pinch"
func gesture(verb: String) -> String: return "pinch" if verb in [_pinch_verb(false),_pinch_verb(true)] else "press"

## The pinch's spread and reach (PINCH, or FINE_PINCH with Shift) and its
## verb's name: a tool built on the pinch (the Mountain) gives its own.
func _pinch_spec(fine: bool) -> Dictionary: return FINE_PINCH if fine else PINCH
func _pinch_verb(fine: bool) -> String: return "fine_pinch" if fine else "pinch"
func pace() -> float: return 1.0+1.5*rub
func worked_as(verb: String) -> String: return "groove" if verb == "thumb" else verb
func stroke_radius() -> float: return _groove_hw()
func turns_lip(verb: String) -> bool: return verb == "thumb"
func prop_tilt() -> float: return TILT

## The ground mark is the thumb's rub: between the groove's half-width and the
## palm's, and where a pinch starts.
func mark_size() -> Vector2: return Vector2.ONE*RUB_RADIUS

func _groove_hw() -> float: return GROOVE_HALF_WIDTH*clay.size_scale
func _rub_r() -> float: return RUB_RADIUS*clay.size_scale
func _palm_r() -> float: return PALM_RADIUS*clay.size_scale

func reset() -> void:
	lift = 0.0
	rub = 0.0

# --- Drag: the thumb and the palm ----------------------------------------------------

func drag_begin(fine: bool) -> String:
	_dug = PackedByteArray()
	_dug.resize(clay.base.size())
	_bed = INF
	_stroking = 0.0
	_breach = Vector2.ZERO
	_carried = false
	var ground: Variant = clay.editor.data.sample(clay.center,clay.base)
	_level = float(ground) if ground != null else 0.0
	return "palm" if fine else "thumb"

## A thumb's first SPEED_WINDOW is held until its speed is known, so a rub
## does not start by digging (a release lays it down as it stands).
func drag_frame(delta: float) -> bool:
	_stroking += delta
	rub = smoothstep(GROOVE_SPEED,RUB_SPEED,clay.speed) if clay.verb == "thumb" else 0.0
	return not (clay.verb == "thumb" and delta > 0.0 and _stroking < clay.SPEED_WINDOW)

func dab(heights: PackedFloat32Array, q: Vector2) -> float:
	if clay.verb == "palm":
		_palm(heights,q)
		return _palm_r()
	var dirty := 0.0
	if rub < 0.99:
		_breach = _breaching(q)
		_groove(heights,q,1.0-rub,_breach)
		dirty = _groove_hw()*LIP_OUT
	if rub > 0.01: _rub(heights,q,rub)
	return dirty

## Run off the plate while breaching: the groove goes on to the lip.
func drag_off() -> void:
	if not _carried: _carry_to_lip()

func drag_end() -> bool:
	return not _carried and _carry_to_lip()

## The groove's dab at `q` with weight `g`: toward a level bed GROOVE_DEPTH
## under the stroke's line, never below it, and never above the bed behind it
## (by at most GROOVE_CUT). `breach` (the outward normal of the side it is
## breaching, or zero) digs its bed without the edge fade.
func _groove(heights: PackedFloat32Array, q: Vector2, g: float, breach := Vector2.ZERO) -> void:
	var base: PackedFloat32Array = clay.base
	var half: float = clay.PLATE_HALF
	# Past the rim (a breach carried to the lip) the bed follows the ground
	# at the rim.
	var ground: Variant = clay.editor.data.sample(q.clamp(-Vector2.ONE*(half-0.02),Vector2.ONE*(half-0.02)),base)
	if ground == null: return
	var bed := float(ground)-GROOVE_DEPTH
	bed = maxf(minf(bed,_bed),bed-GROOVE_CUT)
	_bed = bed
	# The cut across follows the ground: each point sinks by the line's depth
	# from where it stood, so a groove along a slope's face is no deeper on its
	# uphill bank than on its downhill one.
	var depth := float(ground)-bed
	var reach := _groove_hw()*LIP_OUT
	clay.gather(q,reach)
	clay.touch(q,reach)
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	var points: PackedVector2Array = clay.editor.data.points
	var notched := false
	for k in near.size():
		var i := near[k]
		var t := near_d[k]/_groove_hw()
		var fade: float = clay.fade(i)
		if t < 1.0:
			_dug[i] = 1
			if breach != Vector2.ZERO:
				fade = 1.0
				notched = notched or points[i].dot(breach) >= half-0.001
			var goal := base[i]-depth*(1.0-smoothstep(GROOVE_FLOOR,1.0,t))
			var h := heights[i]
			if goal < h: heights[i] = maxf(lerpf(h,goal,GROOVE_STEP*g*fade),NativeTerrainData.MIN_HEIGHT)
		elif _dug[i] == 0:
			var rim := GROOVE_LIP*sin(PI*(t-1.0)/(LIP_OUT-1.0))
			var goal := base[i]+rim
			var h := heights[i]
			if goal > h: heights[i] = lerpf(h,goal,GROOVE_STEP*g*fade)
	if notched:
		var last: Dictionary = clay.last_notch
		if last.is_empty() or last.normal != breach or (last.at as Vector2).distance_to(q) > _groove_hw()*2.0:
			clay.notches += 1
			clay.sound(&"notch",q)
		var along := Vector2(breach.y,-breach.x)
		clay.last_notch = {"normal":breach,"at":breach*half+along*q.dot(along),"bed":bed}

## The outward normal of the side a groove dab at `q` breaches: the nearest
## side's, when `q` is in the edge fade and the stroke heads out across that
## side within BREACH_ANGLE degrees; else zero.
func _breaching(q: Vector2) -> Vector2:
	var heading: Vector2 = clay.heading
	if maxf(absf(q.x),absf(q.y)) < clay.EDGE.x or heading == Vector2.ZERO: return Vector2.ZERO
	var normal := Vector2(signf(q.x),0.0) if absf(q.x) >= absf(q.y) else Vector2(0.0,signf(q.y))
	return normal if heading.dot(normal) >= cos(deg_to_rad(BREACH_ANGLE)) else Vector2.ZERO

## Carries a breaching groove on along its heading to BREACH_PAST beyond the
## rim, queued as the pointer's next point. False when it is not breaching or
## is already there.
func _carry_to_lip() -> bool:
	if clay.verb != "thumb" or _breach == Vector2.ZERO or clay.last_plate == null: return false
	var heading: Vector2 = clay.heading
	var from: Vector2 = clay.path_end()
	var out := heading.dot(_breach)
	var left: float = clay.PLATE_HALF+BREACH_PAST-from.dot(_breach)
	if out <= 0.0 or left <= 0.05: return false
	_carried = true
	clay.queue_point(from+heading*(left/out))
	return true

## The rub's dab at `q` with weight `w`: each point toward its neighbours' mean.
func _rub(heights: PackedFloat32Array, q: Vector2, w: float) -> void:
	var neighbors: Array[PackedInt32Array] = clay.editor.data._neighbors
	clay.gather(q,_rub_r())
	clay.touch(q,_rub_r())
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	for k in near.size():
		var i := near[k]
		var around: PackedInt32Array = neighbors[i]
		if around.is_empty(): continue
		var total := 0.0
		for j in around: total += heights[j]
		var f := 1.0-smoothstep(RUB_CORE,1.0,near_d[k]/_rub_r())
		heights[i] = lerpf(heights[i],total/around.size(),RUB_STEP*w*f*clay.fade(i))

## The palm's dab at `q`: toward the level under the press, pressed PALM_SINK
## down in the middle.
func _palm(heights: PackedFloat32Array, q: Vector2) -> void:
	clay.gather(q,_palm_r())
	clay.touch(q,_palm_r())
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	for k in near.size():
		var i := near[k]
		var f := 1.0-smoothstep(PALM_CORE,1.0,near_d[k]/_palm_r())
		var goal := _level-PALM_SINK*f
		heights[i] = maxf(lerpf(heights[i],goal,PALM_STEP*f*clay.fade(i)),NativeTerrainData.MIN_HEIGHT)

# --- Hold: the pinch -------------------------------------------------------------------

func hold_begin(fine: bool) -> String:
	var spec: Dictionary = _pinch_spec(fine)
	# The pinch takes the clay's nearest point, so the horn's tip stands on
	# a point of the land and the summit reaches the pointer.
	clay.gather(clay.center,clay.CELL)
	var nearest := INF
	for k in clay.near.size():
		if clay.near_d[k] < nearest:
			nearest = clay.near_d[k]
			clay.center = clay.editor.data.points[clay.near[k]]
	clay.gather(clay.center,float(spec.max_radius)*clay.size_scale*HORN_REACH)
	_horn_setup()
	_shown_lift = INF
	return _pinch_verb(fine)

## The pinch follows the pointer: its lift is the pointer's travel up the
## screen in metres standing at the spot.
func hold_step(heights: PackedFloat32Array, rise: float) -> bool:
	var spec: Dictionary = _pinch_spec(clay.verb == _pinch_verb(true))
	lift = clampf(rise*float(spec.scale),-float(spec.sink),float(spec.raise))
	if is_equal_approx(lift,_shown_lift): return false
	_shown_lift = lift
	var radius: float = minf(float(spec.r0)+float(spec.grow)*absf(lift),float(spec.max_radius))*clay.size_scale
	var horn := smoothstep(HORN.x,HORN.y,lift)
	var base: PackedFloat32Array = clay.base
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	for k in near.size():
		var i := near[k]
		var t: float = near_d[k]/radius
		var shape := pow(1.0-t*t,2.0) if t < 1.0 else 0.0
		if horn > 0.0: shape = lerpf(shape,_horn(i,t),horn)
		var h: float = base[i]+lift*shape*clay.fade(i)
		if lift < 0.0: h = maxf(h,minf(base[i],clay.FLOOR))
		heights[i] = clampf(h,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	clay.touch(clay.center,radius*HORN_REACH)
	return true

## Let go: a raise takes the range's rock (see ROCK_FROM), and trees that
## cannot hold the flanks slide down.
func hold_end() -> void:
	var reach: float = float(_pinch_spec(false).max_radius)*clay.size_scale*HORN_REACH
	if clay.verb == _pinch_verb(false) and lift >= ROCK_FROM:
		var horn := smoothstep(HORN.x,HORN.y,lift)
		clay.paint_rock(clay.center,reach,maxf(2.0,lerpf(10.0,lift,horn)))
	clay.shake_trees(clay.center,reach+1.0)

## The pinch's noise and arêtes: the mountain forms' per-point noise (built
## once per world) and three to five arêtes seeded by the pinched spot.
func _horn_setup() -> void:
	var editor: Node = clay.editor
	var mountain: RefCounted = editor.mountain
	mountain.prepare(editor.data,editor.land_seed)
	_jag = mountain._jag
	_lump = mountain._lump
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([editor.land_seed,"pinch",(clay.center as Vector2).snapped(Vector2.ONE*0.01)])
	_aretes = PackedFloat32Array()
	var count := rng.randi_range(3,5)
	var turn := rng.randf()*TAU
	for a in range(count): _aretes.append(turn+TAU*(float(a)+rng.randf_range(-0.22,0.22))/count)

## The horn's share of the lift at point `i`, `t` radii from the pinch: the
## alpine form (mountain_forms `_stamp`) scaled so its summit is 1.
func _horn(i: int, t: float) -> float:
	var rw := t*(1.0+(_lump[i]-0.5)*0.4)
	if rw >= 1.0: return 0.0
	var d: Vector2 = clay.editor.data.points[i]-clay.center
	var theta := atan2(d.y,d.x)
	var arete := 0.0
	for angle in _aretes: arete = maxf(arete,1.0-absf(angle_difference(theta,angle))/0.6)
	arete = arete*arete*smoothstep(0.02,0.25,rw)
	var profile := pow(1.0-rw,1.9)
	var crag := (_jag[i]-0.5)*0.16*rw*(1.0-rw)*4.0
	var shoulder := pow(1.0-rw,1.2)*0.12*arete
	return clampf((profile*(0.8+0.2*arete)+shoulder+crag)/0.8,0.0,1.0)

# --- Tap: the poke ---------------------------------------------------------------------

## A tap on bare land: a small dimple that rings out, and a resident near it
## looks round. The ground comes back exactly and no undo step is added.
func tap(_fine: bool) -> void:
	clay.verb = ""
	var data: NativeTerrainData = clay.editor.data
	var center: Vector2 = clay.center
	clay.gather(center,POKE_RADIUS)
	_poke_idx = clay.near.duplicate()
	_poke_shape = PackedFloat32Array()
	_poke_written = PackedFloat32Array()
	_poke_base = data.heights.duplicate()
	for k in clay.near.size():
		var t: float = clay.near_d[k]/POKE_RADIUS
		_poke_shape.append(pow(1.0-t*t,2.0)*clay.fade(clay.near[k]))
	_poke_written.resize(_poke_idx.size())
	_poke_t = 0.0
	poking = true
	clay.hand_gesture("press",clay.ground_at(center))
	clay.stir(center,POKE_RADIUS,POKE_STRENGTH)
	clay.sound(&"poke",center)
	_poke_step(0.0)

func frame(delta: float) -> void:
	if poking: _poke_step(delta)

func finish() -> void:
	if poking: _end_poke()

func busy() -> bool: return poking

func _poke_step(delta: float) -> void:
	_poke_t += delta
	if _poke_t >= POKE_SECONDS:
		_end_poke()
		return
	var amount := -POKE_DEPTH*exp(-POKE_DAMP*_poke_t)*cos(POKE_RATE*_poke_t)
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	for k in _poke_idx.size():
		var i := _poke_idx[k]
		heights[i] = _poke_base[i]+amount*_poke_shape[k]
		_poke_written[k] = heights[i]
	data.heights = heights
	clay.show_land()

## The dimple is taken back: the exact ground from before, where nothing else
## has moved it since.
func _end_poke() -> void:
	poking = false
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	for k in _poke_idx.size():
		var i := _poke_idx[k]
		if i < heights.size() and heights[i] == _poke_written[k]: heights[i] = _poke_base[i]
	data.heights = heights
	clay.settle()
	if clay.hand_set == "press": clay.hand_gesture("")
	clay.worked.emit("poke",false)

# --- The stand-in prop ------------------------------------------------------------------

## A faceted boxwood modelling tool from primitives: an octagonal shaft through
## the grip, a banded grip, a tapered point over it, and below, a neck that
## flares into a flattened seven-sided spatula, thin across the way it pushes
## (local z, turned to face the drag by the clay). Replaced by a Blender glb
## later: only this function changes.
func build_prop() -> Node3D:
	var root := Node3D.new()
	var top := 0.25
	root.add_child(part(_prism(8),WOOD,Vector3(0.0,top-SHAFT_LENGTH*0.5,0.0),Vector3(SHAFT_RADIUS,SHAFT_LENGTH,SHAFT_RADIUS)))
	root.add_child(part(_prism(8),BAND,Vector3(0.0,-0.02,0.0),Vector3(SHAFT_RADIUS*1.2,0.06,SHAFT_RADIUS*1.2)))
	root.add_child(part(_prism(8,1.0,0.25),WOOD.lightened(0.1),Vector3(0.0,top+POINT_LENGTH*0.5,0.0),Vector3(SHAFT_RADIUS,POINT_LENGTH,SHAFT_RADIUS)))
	var foot := top-SHAFT_LENGTH
	root.add_child(part(_prism(8,1.8),WOOD,Vector3(0.0,foot-0.06,0.0),Vector3(SHAFT_RADIUS,0.12,SHAFT_RADIUS*0.7)))
	root.add_child(part(_ball(),TINT,Vector3(0.0,foot-0.1-SPATULA.y*0.8,0.0),SPATULA))
	return root

## An upright n-sided prism, unit radius and height, tapering to `foot` of
## its radius at the bottom and `top` of it at the top.
static func _prism(sides: int, foot := 1.0, top := 1.0) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = foot
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh

static func _ball() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
	mesh.rings = 4
	return mesh
