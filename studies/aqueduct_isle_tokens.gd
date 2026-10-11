extends "res://scripts/kit_isle/kit_tokens.gd"
## The aqueduct isle's on-foot tokens (docs/scenic/aqueduct-isle-life.md):
## the kit isles' (scripts/kit_isle/kit_tokens.gd), set where each asks for
## a move on this isle.
const Art = preload("res://studies/aqueduct_isle_art.gd")

func spots_for(isle: Node3D) -> Array[Dictionary]:
	return spots(isle)

## Where each token stands and the move it asks for, worked out from the
## isle's own geometry (`isle` the study, for its stone circle).
static func spots(isle: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# 1. The slot between the castellum's high step and the blind wall:
	# 1.8 m wide, 6 m deep; kicked up from wall to wall.
	out.append({"name":"slot","at":Vector3(97.9,Art.TOP+3.9,-2.6),
		"move":"Wall-kick up the slot between the castellum and the blind wall"})
	# 2. Along the blind wall's east face, at the top of the wall run (a
	# jump can't reach it: the run lifts him 3 m).
	out.append({"name":"wallrun","at":Vector3(101.66,Art.TOP+3.45,-4.9),
		"move":"Run along the blind wall's east face (a running jump into it)"})
	# 3. In the fallen span, under the channel's level: run off the snapped
	# end without jumping, take it as he sinks, twirl to make the far lip.
	out.append({"name":"span","at":Vector3(Art.MID_X,Art.TOP+Art.DECK-0.35,-33.7),
		"move":"Drop into the fallen span, then twirl up to the far lip"})
	# 4. The floating sarsen over the bite: two twirled jumps on the lintel
	# loop, onto it and off.
	var sarsen: Dictionary = Art.platform("ring_sarsen")
	if not sarsen.is_empty():
		out.append({"name":"sarsen","at":(sarsen.at as Vector3)+Vector3.UP*0.85,
			"move":"Twirl from the ring's lintels onto the floating sarsen over the bite"})
	# 5. The great trilithon, the isle's summit: up the leaning stone or the
	# fallen trilithon onto the lintels, round to the back one, a jump up.
	var circle: Node3D = isle.get("circle") if isle != null else null
	if circle != null and circle.has_meta("ring"):
		var top: Vector3 = circle.transform*(circle.get_meta("ring").trilithon as Vector3)
		out.append({"name":"trilithon","at":top+Vector3.UP*0.85,
			"move":"Climb the ring's lintels and jump up onto the great trilithon"})
	# 6. Under the drift lintel's north lip, high over the forecourt: hang
	# off it and shimmy along.
	var lintel: Dictionary = Art.platform("drift_3")
	if not lintel.is_empty():
		out.append({"name":"drift","at":under_lip(lintel,0.45),
			"move":"Hang off the drift lintel's north lip and shimmy along it"})
	# 7. Back from the far island over the broken piers: over the first gap
	# out over the sky, at the top of a running jump.
	out.append({"name":"stumps","at":Vector3(92.0,Art.TOP+1.25,-39.3),
		"move":"Jump the stepping stumps back from the far island"})
	return out

