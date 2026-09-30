extends "res://scripts/clay_tools/clay_tool.gd"
## The Paddle, "Mass" (docs/design/tools/PLAN.md): the Modeller's grammar with a
## broad blade, for moving a lot of land softly.
##
## - **Drag:** a sweep. The blade pushes the earth under it ahead and aside:
##   the path is left a long, soft trough, and the earth stands beside it as a
##   soft ridge on either bank (and, where the stroke ends, a little ahead of
##   it). Across, both follow the ground, as the thumb's groove does.
## - **Hold, then drag up or down:** a swell. A wide, round-shouldered rise
##   (or hollow) several times the pinch's spread; its crown follows the
##   pointer, as the pinch's summit does, but it never draws up into a horn.
## - **Tap:** a pat. The blade laid flat: the ground under it eases toward its
##   own mean, flattening bumps without raising or sinking the patch.
## - **Shift** at the moment the verb is decided: a narrower blade
##   (NARROW of the width) for all three.
##
## Each is one undo step. Ground a sweep takes down turns to bare earth and its
## ridges show the pale turned-clay fringe (the clay's dirt). Trees on ground
## the paddle moved and can no longer hold slide to its foot at release.
##
## The sweep: half-width SWEEP_HALF_WIDTH metres, SWEEP_DEPTH deep on the line
## on a raised-cosine profile (no flat floor, no edge: soft), and a ridge
## SWEEP_RIDGE high from the trough's edge out to RIDGE_OUT half-widths, on a
## sin² profile. The ridge carries about the earth the trough takes out
## (0.45 m × 2.2 m of trough against 2 × 0.5 × 0.38 m × 2.64 m of ridge).
## Each dab moves the ground SWEEP_STEP of the way to that shape and never past
## it: going over a line again within one stroke does not dig it deeper, a
## new stroke does. Ground the trough has taken is never raised again by a
## later dab's ridge, so a curved sweep leaves its ridges outside the curve.
const SWEEP_HALF_WIDTH := 2.2
const SWEEP_DEPTH := 0.45
const SWEEP_RIDGE := 0.38
const RIDGE_OUT := 2.2
const SWEEP_STEP := 0.5
## The swell: radius in metres (the pinch opens at 2.2), its lift between
## -SWELL_SINK and SWELL_RAISE metres (the clay's FLOOR still holds a sink),
## at SWELL_SCALE of the pointer's travel in metres standing at the spot. The
## profile is `1 - smoothstep(0, 1, t)`: level on the crown, steepest halfway
## out, easing into the ground at the rim: round shoulders, a soft foot.
const SWELL_RADIUS := 6.5
const SWELL_RAISE := 5.0
const SWELL_SINK := 3.0
const SWELL_SCALE := 1.0
## The pat: radius in metres; each point moves PAT_STEP of the way to the
## patch's mean height, fully inside PAT_CORE of the radius and easing out to
## the rim. The mean is weighted the same way, so the patch keeps its earth.
## The hand stays down on it PAT_SECONDS, so the pat is seen.
const PAT_RADIUS := 3.0
const PAT_STEP := 0.7
const PAT_CORE := 0.4
const PAT_SECONDS := 0.25
## How hard a pat disturbs the life round it (scripts/disturbance.gd), 0..1.
const PAT_STRENGTH := 0.5
## Shift: the narrower blade, a share of every width above.
const NARROW := 0.5
## The ground mark (`mark_size`): the pat's reach across the view, and
## MARK_DEPTH of it toward the camera. The pat is round, but the design draws
## the paddle's mark as an ellipse twice as wide as it is deep (its 180×54 px
## sketch against the Modeller's 96×58 loop), a blade's footprint, so it never
## reads as the Modeller's loop grown larger.
const MARK_DEPTH := 0.5
## The stand-in prop, metres at the hand's own size: the icon's tint
## (scripts/hud_icons.gd "paddle") on the blade, a darker handle, a lighter
## collar; a long handle below the grip and a broad blade below it.
const TINT := Color("c49a5e")
const HANDLE := Color("9c7444")
const COLLAR := Color("d9b57e")
const HANDLE_LENGTH := 1.15
const BLADE := Vector3(0.62,0.72,0.1)
## The cursor sketch's lean toward the drag.
const TILT := -24.0

var _narrow := false
var _swept := PackedByteArray()
var _shown_lift := INF
var _pat_t := -1.0

func id() -> String: return "paddle"
func prop_tilt() -> float: return TILT
func turns_lip(verb: String) -> bool: return verb.ends_with("sweep")
func stroke_radius() -> float: return _width()*SWEEP_HALF_WIDTH
func mark_size() -> Vector2: return Vector2(PAT_RADIUS,PAT_RADIUS*MARK_DEPTH)
func gesture(verb: String) -> String: return "press" if verb.ends_with("pat") else "grip"

## The blade's width share: the size pips, and Shift's narrower blade.
func _width() -> float: return clay.size_scale*(NARROW if _narrow else 1.0)

func reset() -> void:
	lift = 0.0
	_narrow = false

# --- Drag: the sweep ---------------------------------------------------------------

func drag_begin(fine: bool) -> String:
	_narrow = fine
	_swept = PackedByteArray()
	_swept.resize(clay.base.size())
	return "narrow_sweep" if fine else "sweep"

func dab(heights: PackedFloat32Array, q: Vector2) -> float:
	var half := SWEEP_HALF_WIDTH*_width()
	var reach := half*RIDGE_OUT
	var base: PackedFloat32Array = clay.base
	clay.gather(q,reach)
	clay.touch(q,reach)
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	for k in near.size():
		var i := near[k]
		var t := near_d[k]/half
		var fade: float = clay.fade(i)
		var h := heights[i]
		if t < 1.0:
			_swept[i] = 1
			var goal := base[i]-SWEEP_DEPTH*0.5*(1.0+cos(PI*t))
			if goal < h: heights[i] = maxf(lerpf(h,goal,SWEEP_STEP*fade),NativeTerrainData.MIN_HEIGHT)
		elif _swept[i] == 0:
			var s := sin(PI*(t-1.0)/(RIDGE_OUT-1.0))
			var goal := base[i]+SWEEP_RIDGE*s*s
			if goal > h: heights[i] = minf(lerpf(h,goal,SWEEP_STEP*fade),NativeTerrainData.MAX_HEIGHT)
	return half

## Let go: trees the sweep left on ground they cannot hold slide off.
func drag_end() -> bool:
	clay.shake_trees(clay.center,0.0,clay.touched())
	return false

# --- Hold: the swell -----------------------------------------------------------------

func hold_begin(fine: bool) -> String:
	_narrow = fine
	clay.gather(clay.center,SWELL_RADIUS*_width())
	_shown_lift = INF
	return "narrow_swell" if fine else "swell"

func hold_step(heights: PackedFloat32Array, rise: float) -> bool:
	lift = clampf(rise*SWELL_SCALE,-SWELL_SINK,SWELL_RAISE)
	if is_equal_approx(lift,_shown_lift): return false
	_shown_lift = lift
	var radius := SWELL_RADIUS*_width()
	var base: PackedFloat32Array = clay.base
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	for k in near.size():
		var i := near[k]
		var shape := 1.0-smoothstep(0.0,1.0,near_d[k]/radius)
		var h: float = base[i]+lift*shape*clay.fade(i)
		if lift < 0.0: h = maxf(h,minf(base[i],clay.FLOOR))
		heights[i] = clampf(h,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	clay.touch(clay.center,radius)
	return true

func hold_end() -> void:
	clay.shake_trees(clay.center,SWELL_RADIUS*_width()+1.0)

# --- Tap: the pat ---------------------------------------------------------------------

func tap(fine: bool) -> void:
	_narrow = fine
	clay.verb = "narrow_pat" if fine else "pat"
	var radius := PAT_RADIUS*_width()
	var center: Vector2 = clay.center
	clay.open_stroke()
	clay.gather(center,radius)
	clay.touch(center,radius)
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	var weights := PackedFloat32Array()
	var total := 0.0
	var mean := 0.0
	for k in near.size():
		var w: float = (1.0-smoothstep(PAT_CORE,1.0,near_d[k]/radius))*clay.fade(near[k])
		weights.append(w)
		total += w
		mean += heights[near[k]]*w
	if total > 0.0:
		mean /= total
		for k in near.size():
			var i := near[k]
			heights[i] = lerpf(heights[i],mean,PAT_STEP*weights[k])
		data.heights = heights
		clay.show_land()
	var at: Vector3 = clay.ground_at(center)
	clay.stir(center,radius,PAT_STRENGTH)
	clay.close_stroke()
	# The hand comes down on the blade for a beat.
	clay.hand_gesture("press",at,true)
	_pat_t = 0.0

func frame(delta: float) -> void:
	if _pat_t < 0.0: return
	_pat_t += delta
	if _pat_t >= PAT_SECONDS: finish()

func finish() -> void:
	if _pat_t < 0.0: return
	_pat_t = -1.0
	if clay.hand_set == "press" and clay.state == clay.State.IDLE: clay.hand_gesture("")

# --- The stand-in prop ------------------------------------------------------------------

## A faceted paddle from primitives: a hexagonal handle hanging from the grip,
## a pommel over it, a collar, and a broad octagonal blade, thin across the
## way it pushes (local z, turned to face the drag by the clay). Replaced by
## the Blender paddle's glb later: only this function changes.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(6),HANDLE,Vector3(0.0,-HANDLE_LENGTH*0.5+0.12,0.0),Vector3(0.045,HANDLE_LENGTH,0.045)))
	root.add_child(part(_ball(),COLLAR,Vector3(0.0,0.16,0.0),Vector3(0.075,0.06,0.075)))
	root.add_child(part(_prism(6),COLLAR,Vector3(0.0,-HANDLE_LENGTH+0.12,0.0),Vector3(0.075,0.12,0.075)))
	var blade := _prism(8,0.82)
	root.add_child(part(blade,TINT,Vector3(0.0,-HANDLE_LENGTH+0.06-BLADE.y*0.5,0.0),BLADE*Vector3(0.5,1.0,0.5)))
	return root

## An upright n-sided prism, unit radius and height, tapering to `foot` of
## its radius at the bottom.
static func _prism(sides: int, foot := 1.0) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
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
