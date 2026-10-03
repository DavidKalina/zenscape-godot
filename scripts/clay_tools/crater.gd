extends "res://scripts/clay_tools/hand.gd"
## The Crater, "Hollow" (docs/design/tools/PLAN.md "The roll, revised"): press
## on the land and drag down, and a crater opens under the press, its floor
## following the pointer down. It is the Mountain's pull turned over, built on
## the Modeller's pinch (scripts/clay_tools/hand.gd) as the Mountain is, and
## it is its only verb, taken at the press (`press_kind`): no holding still
## first. Dragging up does nothing past the press's ground. **Shift:** a
## smaller crater (FINE_CRATER). The user, 2026-10-02, asked for it as its own
## tool, after the Mountain's pull-down crater: one landform, one tool.
##
## The floor sinks by the pull, level inside CRATER_FLOOR of the radius and
## rising to the rim at CRATER_RIM_AT; a rim CRATER_RIM of the depth stands
## round it, out to CRATER_RIM_OUT radii, the ground thrown out of the hole.
## The radius widens with the depth as the peak's does. Sinking never takes
## ground below the clay's FLOOR, and the rim stands by the depth the floor
## really reached, not by the pull. The floor shows the stratum it reached
## (the clay's dirt). When the hold takes, the spot dips at GRIP_KICK and
## rings back, so the grip shows before the hand moves.

const CRATER := {"r0":2.4,"grow":0.5,"max_radius":7.0,"raise":0.0,"sink":6.0,"scale":1.4}
const FINE_CRATER := {"r0":1.4,"grow":0.35,"max_radius":3.5,"raise":0.0,"sink":3.0,"scale":0.6}
const CRATER_FLOOR := 0.45
const CRATER_RIM_AT := 0.95
const CRATER_RIM := 0.3
const CRATER_RIM_OUT := 1.25

## The stand-in: a faceted tamper, a wooden haft down to a broad round stone
## foot in the icon's tint (scripts/hud_icons.gd "crater").
const STONE := Color("a08a68")
const HAFT := Color("b98a58")

func id() -> String: return "crater"
func modes() -> Array: return []
func press_kind() -> String: return "hold"
func hover_gesture() -> String: return "pinch"
func stroke_radius() -> float: return float(CRATER.r0)*clay.size_scale
func mark_size() -> Vector2: return Vector2.ONE*float(CRATER.r0)
func _pinch_spec(fine: bool) -> Dictionary: return FINE_CRATER if fine else CRATER
func _pinch_verb(fine: bool) -> String: return "fine_crater" if fine else "crater"

## The pinch's hold, with the grip's kick turned down.
func hold_begin(fine: bool) -> String:
	var verb := super.hold_begin(fine)
	_lift_speed = -_lift_speed
	return verb

## The crater round the press, from `clay.base`, at the lift (never above 0).
func hold_step(heights: PackedFloat32Array, rise: float) -> bool:
	var spec: Dictionary = _pinch_spec(clay.verb == _pinch_verb(true))
	_follow(spec,rise)
	if is_equal_approx(lift,_shown_lift): return false
	_shown_lift = lift
	var radius: float = minf(float(spec.r0)+float(spec.grow)*absf(lift),float(spec.max_radius))*clay.size_scale
	var depth := maxf(-lift,0.0)
	var ground: Variant = clay.editor.data.sample(clay.center,clay.base)
	var thrown := minf(depth,maxf(float(ground)-clay.FLOOR,0.0)) if ground != null else depth
	var base: PackedFloat32Array = clay.base
	var near: PackedInt32Array = clay.near
	var near_d: PackedFloat32Array = clay.near_d
	for k in near.size():
		var i := near[k]
		var t: float = near_d[k]/radius
		var bowl := 1.0-smoothstep(CRATER_FLOOR,CRATER_RIM_AT,t)
		var rim := 0.0
		if t > CRATER_FLOOR and t < CRATER_RIM_OUT: rim = pow(sin(PI*(t-CRATER_FLOOR)/(CRATER_RIM_OUT-CRATER_FLOOR)),2.0)
		var h: float = base[i]+(thrown*CRATER_RIM*rim-depth*bowl)*clay.fade(i)
		if h < base[i]: h = maxf(h,minf(base[i],clay.FLOOR))
		heights[i] = clampf(h,NativeTerrainData.MIN_HEIGHT,NativeTerrainData.MAX_HEIGHT)
	clay.touch(clay.center,radius*CRATER_RIM_OUT)
	if depth > 0.0: clay.dirty(clay.center,radius*CRATER_RIM_AT)
	return true

## Let go: trees on the rim and walls that cannot hold them slide off.
func hold_end() -> void:
	clay.shake_trees(clay.center,float(CRATER.max_radius)*clay.size_scale*CRATER_RIM_OUT+1.0)

# --- The stand-in prop ------------------------------------------------------------------

## A faceted tamper: a wooden haft down to a broad, flat, round stone foot.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(8),HAFT,Vector3(0.0,-0.12,0.0),Vector3(0.035,0.62,0.035)))
	root.add_child(part(_prism(8,0.9),STONE,Vector3(0.0,-0.5,0.0),Vector3(0.16,0.1,0.16)))
	return root
