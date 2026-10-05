extends RefCounted
## A shaping tool in the hand (docs/design/tools/PLAN.md, "The seam"). The
## clay (scripts/land_clay.gd) reads the gesture: it decides from the shape
## and timing of a press whether it is a tap, a drag or a hold-then-drag, and
## reads Shift when it decides. The tool in hand says what that verb does to
## the land. Every tool keeps the Modeller's grammar; only what the gestures do
## changes.
##
## A tool is one script in scripts/clay_tools/, named for its id in the tool
## roll (scripts/tool_roll.gd TOOLS): `paddle` is scripts/clay_tools/paddle.gd.
## It extends this one and overrides the hooks it needs. The clay makes it on
## first use (`LandClay.set_tool`) and sets `clay`; nothing else registers it.
##
## The clay owns everything the tools share, and the hooks call back into it
## (see the plan's "What the clay gives a tool"): the undo step, the dirt tint,
## the refresh near the hand, the rock paint, trees sliding off, `size_scale`,
## the point lookup, the edge fade. A tool only writes heights.
##
## The order of calls for one press:
## - `reset()` at the press.
## - A drag: `drag_begin(fine)` once the stroke's undo step is open; then each
##   frame `drag_frame(delta)` and a `dab(heights, q)` for every point
##   DAB_SPACING apart along the pointer's path; `drag_off()` whenever the
##   pointer runs off the land; `drag_end()` at release (not when the stroke
##   is cut short by an undo or a new press); the clay closes the undo step,
##   or, while `drag_running()` is true after `drag_end`, keeps it open as the
##   tool's `frame` works on (the Wire drawing its cut through the clay) and
##   closes it once that is false, or after `finish()`.
## - A hold: `hold_begin(fine)` once the undo step is open; then
##   `hold_step(heights, rise)` each frame the pointer has moved, and once more
##   at release; `hold_end()`; the clay closes the undo step.
## - A tap: `tap(fine)`. The tool opens and closes its own undo step if it
##   keeps anything (`clay.open_stroke()` ... `clay.close_stroke()`), or none.
## - `frame(delta)` every frame, for anything that runs on after a press (the
##   Modeller's poke rings out, the Wire's cut draws through); `finish()` ends
##   it at once (an undo, a new press, a change of tool), leaving what it
##   would have left had it run out.

## The plate (scripts/plate.gd), for the tools that walk its cover grid.
const Plate = preload("res://scripts/plate.gd")

## The clay working the land (scripts/land_clay.gd), set when the tool is made.
var clay: Node
## The hold's lift in metres, as last shown (the clay reads it as `lift`).
var lift := 0.0
## The mode in hand (an id of `modes`), or "" for a tool with none.
var mode := ""
## The colour in hand (sRGB), for a tool whose mode in hand lays one
## (`swatches` not empty): the Brush's Colour.
var colour := Color.WHITE

## The tool's id: its pocket in the tool roll.
func id() -> String: return ""

## The tool's modes, fanned out beside its pocket in the tool roll (each
## drawn as scripts/hud_icons.gd "<tool id>_<mode id>"), the first taken
## when the tool is made. Each is {"id", "kind", "fine"?}: the kind is the
## gesture every press makes while it is in hand ("tap", "drag", "hold", or
## "paint" for a tool that `paints`), so the press does that verb at once
## instead of the clay reading it from the press's shape and timing; "fine"
## true presses as Shift does. Empty for a tool with one verb, which keeps
## the gesture grammar.
func modes() -> Array: return []

## The gesture every press makes with this tool ("tap", "drag", "hold",
## "paint"), or "" for the clay to read it from the press's shape and timing.
## By default the mode in hand's kind; a one-verb tool that wants its verb at
## once (the Mountain's pull) gives it here.
func press_kind() -> String: return str(mode_spec().get("kind",""))

## The mode in hand's entry in `modes`, or {} for none.
func mode_spec() -> Dictionary:
	for spec: Dictionary in modes():
		if spec.id == mode: return spec
	return {}

## The colours offered on the roll's swatch strip while the mode in hand
## lays one (sRGB), or [] when it lays none. The strip ends with a cell that
## opens a full picker (unless `picks` is false); either sets `colour`.
func swatches() -> Array: return []

## Whether the swatch strip ends with the full picker's cell: false for a
## mode whose swatches are the only choices (the Paddle's Plane, its four
## surfaces), where any other colour would mean nothing.
func picks() -> bool: return true

## Take the next or previous mode (Q and E).
func step_mode(by: int) -> void:
	var all := modes()
	if all.is_empty(): return
	var at := 0
	for k in range(all.size()):
		if all[k].id == mode: at = k
	mode = all[posmod(at+by,all.size())].id

## The God Hand's gesture (a key of scripts/god_hand.gd GESTURES) while the
## hand hovers the land holding this tool, and while `verb` works it.
func hover_gesture() -> String: return "grip"
func gesture(_verb: String) -> String: return "grip"

## How fast the gesture's Hold plays while a drag works (1 is as made).
func pace() -> float: return 1.0

## The name `worked` reports for a verb when its press ends.
func worked_as(verb: String) -> String: return verb

## The reach in metres the editor's stroke signals report (emergence, the
## cursor): about the tool's working width at this size.
func stroke_radius() -> float: return 1.0

## The ground mark's half extents in metres at the middle pip (the ground
## marks scale it by the pips): what a press here will touch, x along the
## mark's axis and y across it (scripts/ground_marks.gd `size_of`; the axis is
## the view's right, or the fall line for the chisel's square). A tool whose
## verbs reach differently gives the one the hover best stands for, usually
## its tap's. Zero leaves the mark its own placeholder size.
func mark_size() -> Vector2: return Vector2.ZERO

## Whether ground this drag raises shows the pale turned-clay fringe
## (land_clay TURNED): clay pushed aside.
func turns_lip(_verb: String) -> bool: return false

## How much of the clay's bare earth ground this verb takes down shows, 0..1:
## 1 the full dirt (a crisp line, the Modeller's groove), less a faint scuff
## over the grass, 0 none. Below the clay's DIRT_BARE the grass stays alive.
func dirt_share(_verb: String) -> float: return 1.0

## Metres the prop hangs above its working end's usual hover (the can holds
## its rose up, to pour from).
func prop_lift() -> float: return 0.0

## Whether the prop hovers over standing water's surface rather than the
## ground under it (the can, rising with the lake it fills).
func rides_water() -> bool: return false

## The stand-in prop, the tool's own cursor over the land, or null for none.
## Built each time the tool is taken, in the terrain's space, with the
## handle's grip at the origin and the tool's working end down -Y. A Blender
## glb replaces the body of this one function later.
func build_prop() -> Node3D: return null

## Degrees the prop leans off upright toward the way the hand is going (the
## cursor sketches' tilt; negative leans its working end forward, into the
## drag, and its handle back).
func prop_tilt() -> float: return 0.0

## A new press: forget the last verb's own state.
func reset() -> void: lift = 0.0

# --- Drag --------------------------------------------------------------------------

## The drag is decided; `fine` is Shift. Returns the verb's name.
func drag_begin(_fine: bool) -> String: return "drag"

## Each frame of a drag, before its dabs are laid. False holds this frame's
## dabs back (they are laid with the next frame's).
func drag_frame(_delta: float) -> bool: return true

## One dab at plate point `q`: write `heights` (the clay's working copy; it
## writes them to the land after the frame's dabs). Returns the reach in
## metres round `q` the dab may have taken the ground down, for the dirt, or
## 0 for none.
func dab(_heights: PackedFloat32Array, _q: Vector2) -> float: return 0.0

## The pointer ran off the land mid-drag.
func drag_off() -> void: pass

## The button came up on a drag, before the stroke closes. True when it
## queued more path (`clay.queue_point`) for the clay to lay first.
func drag_end() -> bool: return false

## True while a drag let go still works the land (the Wire's cut drawing
## through), run on by `frame` and landed whole by `finish`: the clay keeps
## the stroke's undo step open until it is false. `busy` is true then too.
func drag_running() -> bool: return false

# --- Hold --------------------------------------------------------------------------

## The hold is decided; `fine` is Shift. May move `clay.center` (the pinch
## takes the land's nearest point) before the clay measures the metre there.
## Returns the verb's name.
func hold_begin(_fine: bool) -> String: return "hold"

## The pointer moved while held: `rise` is its travel up the screen from the
## press, in metres standing at `clay.center` (down is negative). Write
## `heights` from `clay.base` and set `lift`. False when nothing changed, so
## the clay neither writes nor shows the land.
func hold_step(_heights: PackedFloat32Array, _rise: float) -> bool: return false

## Whether the hold wants the pointer's sideways travel as ground: true and
## the clay picks it each time the pointer moves, into `clay.hold_point`
## (the Mountain's range runs to it). Default false: the clay picks nothing.
func hold_tracks() -> bool: return false

## The hold is let go (or cut short), before the stroke closes: rock paint,
## trees sliding off (`clay.paint_rock`, `clay.shake_trees`).
func hold_end() -> void: pass

# --- Tap ---------------------------------------------------------------------------

## A tap: let go within HOLD_SECONDS, moved under MOVE_PIXELS.
func tap(_fine: bool) -> void: pass

# --- Paint --------------------------------------------------------------------------
## A tool that paints skips the tap/drag/hold grammar: a press opens its
## undo step at once and the tool works the land every frame the button is
## down, at the pointer, whether it holds still or moves (the Sculpt's
## modes). Its order of calls: `paint_begin(fine)`; each frame
## `paint_frame(heights, delta, false)` and then a `paint_dab(heights, q, work)`
## at the pointer, or for every point DAB_SPACING apart along its path when it
## moved, sharing that frame's `work` seconds; at release (or when cut short)
## a last `paint_frame(heights, 0, true)`, with any dabs a tap is owed, then
## `paint_end(tapped)`; the clay closes the undo step.

## True when this tool paints.
func paints() -> bool: return false

## The paint is pressed; `fine` is Shift. Returns the verb's name.
func paint_begin(_fine: bool) -> String: return "paint"

## Each frame of the paint, before its dabs (`ending` at release: finish what
## is still growing). True when it wrote `heights`.
func paint_frame(_heights: PackedFloat32Array, _delta: float, _ending: bool) -> bool: return false

## `work` seconds of the paint at plate point `q`. Returns the reach round
## `q` the dab may have taken the ground down, for the dirt, or 0.
func paint_dab(_heights: PackedFloat32Array, _q: Vector2, _work: float) -> float: return 0.0

## Let go: `tapped` when it was a quick press that never moved. Rock paint
## and trees sliding off go here, as a hold's do.
func paint_end(_tapped: bool) -> void: pass

# --- Running on ---------------------------------------------------------------------

func frame(_delta: float) -> void: pass
func finish() -> void: pass
## True while something the tool started still runs (a poke ringing out, a
## cut drawing through).
func busy() -> bool: return false

# --- Stand-in props -----------------------------------------------------------------

## A faceted part for a stand-in prop, like the materials' pebbles: `mesh`
## flat-shaded (every face its own normal, as the land and the HUD icons'
## facets), `colour` sRGB, placed at `at` and scaled by `size`.
static func part(mesh: Mesh, colour: Color, at: Vector3, size: Vector3, turn := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = faceted(mesh)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.85
	# A little light of its own, so it reads by night and beside the hand's glow.
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 0.2
	node.material_override = material
	node.position = at
	node.rotation = turn
	node.scale = size
	return node

## `mesh` with its faces unshared and each face's own normal (turned to the
## side the mesh's own normals face), so it shades in flat facets.
static func faceted(mesh: Mesh) -> Mesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var smooth: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if index.is_empty(): index = PackedInt32Array(range(vertices.size()))
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for t in range(0,index.size()-2,3):
		var a := vertices[index[t]]
		var b := vertices[index[t+1]]
		var c := vertices[index[t+2]]
		var normal := (b-a).cross(c-a)
		if normal.length_squared() < 1e-12: continue
		normal = normal.normalized()
		if not smooth.is_empty() and normal.dot(smooth[index[t]]+smooth[index[t+1]]+smooth[index[t+2]]) < 0.0: normal = -normal
		for v in [a,b,c]:
			points.append(v)
			normals.append(normal)
	var flat: Array = []
	flat.resize(Mesh.ARRAY_MAX)
	flat[Mesh.ARRAY_VERTEX] = points
	flat[Mesh.ARRAY_NORMAL] = normals
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,flat)
	return out
