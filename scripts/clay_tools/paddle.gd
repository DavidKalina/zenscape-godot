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
## - **Plane** (its own mode on the fan, a drag): the blade drawn level. The
##   ground under the stroke is planed to the height it stood at under the
##   press, and its surface is laid afresh as one of SURFACES (grass, earth,
##   rock or sand), picked on the swatch strip under the fan. So rock, or
##   any paint, is never for keeping: plane it and it is grass again.
## - **Shift** at the moment the verb is decided: a narrower blade
##   (NARROW of the width) for all four.
##
## Each is one undo step. The Paddle is the landscape tool and the Modeller
## the detail one, so where the Modeller's groove is a crisp bare-earth line,
## the sweep is a grassed valley: its ground shows only SWEEP_DIRT of the
## clay's bare earth, a faint scuff that never kills the grass, and its
## ridges stay grassed shoulders, without the groove's pale turned-clay
## fringe (`turns_lip`), which outlined it as a trench. Trees on
## ground the paddle moved and can no longer hold slide to its foot at release.
##
## The sweep: half-width SWEEP_HALF_WIDTH metres, SWEEP_DEPTH deep on the line
## on a raised-cosine profile (no flat floor, no edge: soft), and a ridge
## SWEEP_RIDGE high from the trough's edge out to RIDGE_OUT half-widths, on a
## sin² profile. The ridge carries about the earth the trough takes out
## (0.6 m × 2.8 m of trough against 2 × 0.5 × 0.43 m × 3.92 m of ridge). Both
## are broader and gentler than the groove (steepest about 0.34 rise/run,
## against the groove's 0.75 m within 1.35 m), so the sweep reads as a swale between low
## shoulders, not a trench.
## Each dab moves the ground SWEEP_STEP of the way to that shape and never past
## it: going over a line again within one stroke does not dig it deeper, a
## new stroke does. Ground the trough has taken is never raised again by a
## later dab's ridge, so a curved sweep leaves its ridges outside the curve.
const SWEEP_HALF_WIDTH := 2.8
const SWEEP_DEPTH := 0.6
const SWEEP_RIDGE := 0.43
const RIDGE_OUT := 2.4
const SWEEP_STEP := 0.5
## The share of the clay's bare earth the sweep's ground shows (clay_tool
## `dirt_share`): under the clay's DIRT_BARE, so the grass lives on.
const SWEEP_DIRT := 0.2
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
## The plane: radius in metres; each dab moves a point PLANE_STEP of the way
## to the press's height, fully inside PLANE_CORE of the radius and easing to
## nothing at the rim, so the swath is flat and its edge a smooth shoulder.
## Dabs fall the clay's DAB_SPACING (0.3 m) apart, so a point the core passes
## over takes several of them and ends within a few centimetres of the level.
## The surface takes the same falloff: the core is laid outright, the
## shoulder blends into what was there.
const PLANE_RADIUS := 2.5
const PLANE_STEP := 0.5
const PLANE_CORE := 0.5
## The Plane's surfaces, offered on the swatch strip (no picker: these are
## its only choices), each shown by its swatch (sRGB: the palette's middle
## grass, the strata's topsoil, the palette's first rock, its shore sand)
## and laid as the world lays it (Brush `surface_colour`). Grass is the
## first, so a Plane taken fresh lays grass.
const SURFACES := ["grass","earth","rock","sand"]
const SURFACE_SWATCHES := [Color("7fb069"),Color("7a624b"),Color("8d8577"),Color("c9b57e")]
const Brush = preload("res://scripts/clay_tools/brush.gd")
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
## The plane's level (m), and the stroke's starting cover, which each dab
## lays over afresh: the tint, grass, meadow and blades as they stood at the
## press, and each cell's surface share so far (cell -> 0..1, only rising).
var _level := 0.0
var _tint_from := PackedFloat32Array()
var _grass_from := PackedFloat32Array()
var _meadow_from := PackedFloat32Array()
var _blades_from := PackedFloat32Array()
var _laid := {}

## The fan's modes (clay_tool `modes`): the swell, the sweep, the pat and the
## plane.
const MODES := [{"id":"swell","kind":"hold"},{"id":"sweep","kind":"drag"},{"id":"pat","kind":"tap"},{"id":"plane","kind":"drag"}]
func modes() -> Array: return MODES
func id() -> String: return "paddle"
func prop_tilt() -> float: return TILT
func swatches() -> Array: return SURFACE_SWATCHES if mode == "plane" else []
func picks() -> bool: return false
## The plane lays its own surface over the whole swath, so the clay's dirt
## (which would write the cut's strata over it, and bare the cells at
## release) stays out of it.
func dirt_share(verb: String) -> float:
	if verb.ends_with("plane"): return 0.0
	return SWEEP_DIRT if verb.ends_with("sweep") else 1.0
func stroke_radius() -> float: return _width()*(PLANE_RADIUS if mode == "plane" else SWEEP_HALF_WIDTH)
func mark_size() -> Vector2: return Vector2(PAT_RADIUS,PAT_RADIUS*MARK_DEPTH)
func gesture(verb: String) -> String: return "press" if verb.ends_with("pat") else "grip"

## The blade's width share: the size pips, and Shift's narrower blade.
func _width() -> float: return clay.size_scale*(NARROW if _narrow else 1.0)

## The surface the Plane lays: the swatch in hand's (SURFACES), grass if the
## colour in hand is none of them.
func surface() -> String:
	for k in range(SURFACE_SWATCHES.size()):
		if (SURFACE_SWATCHES[k] as Color).is_equal_approx(colour): return SURFACES[k]
	return SURFACES[0]

func _init() -> void:
	colour = SURFACE_SWATCHES[0]

func reset() -> void:
	lift = 0.0
	_narrow = false

# --- Drag: the sweep ---------------------------------------------------------------

func drag_begin(fine: bool) -> String:
	_narrow = fine
	if mode == "plane": return _plane_begin(fine)
	_swept = PackedByteArray()
	_swept.resize(clay.base.size())
	return "narrow_sweep" if fine else "sweep"

func dab(heights: PackedFloat32Array, q: Vector2) -> float:
	if str(clay.verb).ends_with("plane"): return _plane_dab(heights,q)
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

# --- Drag: the plane ---------------------------------------------------------------

## The level is the ground under the press; the cover is taken as it stands.
func _plane_begin(fine: bool) -> String:
	var data: NativeTerrainData = clay.editor.data
	_level = clay.ground_at(clay.center).y
	_tint_from = data.tint.duplicate()
	_grass_from = data.grass.duplicate()
	_meadow_from = data.meadow.duplicate()
	_blades_from = data.blades.duplicate()
	_laid = {}
	return "narrow_plane" if fine else "plane"

## One dab of the plane: the ground round `q` toward the level, and the cover
## cells round it laid afresh. A cell's share is the most any dab has given
## it, written over the stroke's starting cover, so going over it again never
## lays it twice and it comes out the same at any pace. A full share (the
## core) replaces the cell outright (Brush `coat` at 1): the surface's colour
## at full weight, whatever was painted there (the Brush's rock, a range's
## rock, the clay's dirt). Grass brings the cover up to full and leaves the
## meadow and blades as they stood, to grow; the bare surfaces take cover,
## meadow and blades away. Every cell laid is hand-made.
func _plane_dab(heights: PackedFloat32Array, q: Vector2) -> float:
	var radius := PLANE_RADIUS*_width()
	clay.gather(q,radius)
	clay.touch(q,radius)
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	for k in near.size():
		var i := near[k]
		var w: float = (1.0-smoothstep(PLANE_CORE,1.0,near_d[k]/radius))*clay.fade(i)
		if w <= 0.0: continue
		heights[i] = clampf(lerpf(heights[i],_level,PLANE_STEP*w),NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	var data: NativeTerrainData = clay.editor.data
	var palette: NativeTerrainPalette = data._palette
	var kind := surface()
	var cover := 1.0 if kind == "grass" else 0.0
	var side := NativeTerrainData.MEADOW_CELLS
	var step := NativeTerrainData.MEADOW_STEP
	var low := Vector2i(((q-Vector2.ONE*radius+Vector2.ONE*14.0)/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var high := Vector2i(((q+Vector2.ONE*radius+Vector2.ONE*14.0)/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var tint := data.tint
	var grass := data.grass
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var p := data.meadow_position(x,z)+Vector2.ONE*step*0.5
			var cell := z*side+x
			var share := 1.0-smoothstep(PLANE_CORE*radius,radius,p.distance_to(q))
			if share <= float(_laid.get(cell,0.0)): continue
			_laid[cell] = share
			var t := cell*NativeTerrainTint.STRIDE
			for c in range(NativeTerrainTint.STRIDE): tint[t+c] = _tint_from[t+c]
			Brush.coat(tint,cell,Brush.surface_colour(kind,palette,p),share)
			grass[cell] = lerpf(_grass_from[cell],cover,share)
			if kind != "grass":
				data.meadow[cell] = _meadow_from[cell]*(1.0-share)
				data.blades[cell] = _blades_from[cell]*(1.0-share)
			data.provenance[cell] = NativeTerrainData.SOURCE_HAND
	data.tint = tint
	data.grass = grass
	return 0.0

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
	clay.sound(&"pat",center,0.6 if fine else 1.0)
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
