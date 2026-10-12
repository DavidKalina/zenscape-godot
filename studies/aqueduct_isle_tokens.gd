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
	# 1.8 m wide, the deck deep; kicked up from wall to wall.
	out.append({"name":"slot","at":Vector3(97.9,Art.TOP+Art.DECK*0.65,-2.6),
		"move":"Wall-kick up the slot between the castellum and the blind wall"})
	# 2. Along the blind wall's east face, at the top of the wall run (a
	# jump can't reach it: the run lifts him 3 m).
	out.append({"name":"wallrun","at":Vector3(101.66,Art.TOP+3.45,-4.9),
		"move":"Run along the blind wall's east face (a running jump into it)"})
	# 3. In the fallen span, under the channel's level: run off the snapped
	# end without jumping, take it as he sinks, twirl to make the far lip.
	out.append({"name":"span","at":Vector3(Art.MID_X,Art.TOP+Art.DECK-0.35,-Art.arch(Art.FALLEN)+0.3),
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
	var last: Array = Art.stumps()[-1]
	out.append({"name":"stumps","at":Vector3(Art.STUMPS_X,Art.TOP+1.25,float(last[2])-1.45),
		"move":"Jump the stepping stumps back from the far island"})
	# 8. Buried in the turf (scripts/buried_find.gd) a few metres in off the
	# north edge's worn path to the stumps, BURIED_ALONG of its middle run,
	# BURIED_IN inland: a faint shimmer in the grass, glinting through the
	# telescope; a downdraft over it blows it open.
	var ground := buried_ground()
	out.append({"name":"buried","at":ground+Vector3.UP*BURIED_HOVER,"ground":ground,"buried":true,
		"move":"Spot the shimmer off the north path and blow the turf off it with a downdraft"})
	return out

## The buried token: along the north path's middle run (Art.PATHS[1], its
## second leg), and in from it, away from the edge (m).
const BURIED_ALONG := 0.6
const BURIED_IN := 3.6
const BURIED_HOVER := 0.85
static func buried_ground() -> Vector3:
	var path: Array = Art.PATHS[1]
	var a: Vector2 = path[1]
	var b: Vector2 = path[2]
	var way := (b-a).normalized()
	# Inland is to the path's left going east (the edge lies to its right).
	var p := a.lerp(b,BURIED_ALONG)+Vector2(-way.y,way.x)*BURIED_IN
	return Vector3(p.x,Art.TOP,p.y)

