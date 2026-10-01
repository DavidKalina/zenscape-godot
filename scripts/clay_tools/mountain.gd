extends "res://scripts/clay_tools/hand.gd"
## The Mountain, "Peak": press on the land and drag up, and a mountain is pulled
## out of it, its summit following the pointer; drag down and the land sinks.
## It is the Modeller's pinch (scripts/clay_tools/hand.gd) made bigger
## (PEAK: a wider spread, a taller reach, a faster pull), and it is its only
## verb, taken at the press (`press_kind`): no holding still first. As it
## grows it turns from a swell into a horn with arêtes, and let go it takes
## the range's rock, as the pinch does. **Shift:** a smaller peak (FINE_PEAK).

const PEAK := {"r0":3.0,"grow":0.55,"max_radius":8.0,"raise":14.0,"sink":6.0,"scale":1.4}
const FINE_PEAK := {"r0":1.8,"grow":0.4,"max_radius":4.0,"raise":6.0,"sink":3.0,"scale":0.6}

## The stand-in: a faceted stone pick, its head in the icon's tint
## (scripts/hud_icons.gd "mountain").
const STONE := Color("9a948c")
const HAFT := Color("b98a58")

func id() -> String: return "mountain"
func modes() -> Array: return []
func press_kind() -> String: return "hold"
func hover_gesture() -> String: return "pinch"
func stroke_radius() -> float: return float(PEAK.r0)*clay.size_scale
func mark_size() -> Vector2: return Vector2.ONE*float(PEAK.r0)
func _pinch_spec(fine: bool) -> Dictionary: return FINE_PEAK if fine else PEAK
func _pinch_verb(fine: bool) -> String: return "fine_peak" if fine else "peak"

## A faceted pick: a wooden haft down to a grey stone point.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(8),HAFT,Vector3(0.0,-0.1,0.0),Vector3(0.035,0.6,0.035)))
	root.add_child(part(_prism(6,0.05),STONE,Vector3(0.0,-0.52,0.0),Vector3(0.09,0.24,0.09)))
	return root
