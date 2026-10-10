extends "res://scripts/kit_isle/kit_tokens.gd"
## The bell spires isle's on-foot tokens: the kit isles' (scripts/kit_isle/
## kit_tokens.gd) with this isle's spots, each where it asks for a move.
const Art = preload("res://studies/bell_spires_isle_art.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Belfry = preload("res://scripts/ruin_kit_belfry.gd")

func spots_for(isle: Node3D) -> Array[Dictionary]:
	return spots(isle)

## Where each token stands and the move it asks for, from the isle's own
## layout (`isle` the study, for its belfry).
static func spots(isle: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var l: Dictionary = Art.layout()
	var fh: Dictionary = l.spires.fin_high
	var fl: Dictionary = l.spires.fin_low
	# 1. Up the chimney between the fin's stacks: wall kicks.
	var mid: Vector2 = (fh.c as Vector2).lerp(fl.c,0.5)
	var along: Vector2 = l.chock.along
	var c := mid-along*1.2
	out.append({"name":"chimney","at":Vector3(c.x,Art.TOP+5.5,c.y),"move":"Wall-kick up the chimney between the fin's two stacks"})
	# 2. Over the drift from the low stack to the south stack, at the top
	# of the jump between its second and third stones.
	var d2: Dictionary = Art.platform("drift_2")
	var d3: Dictionary = Art.platform("drift_3")
	if not d2.is_empty() and not d3.is_empty():
		out.append({"name":"drift","at":(d2.at as Vector3).lerp(d3.at,0.5)+Vector3.UP*1.2,"move":"Hop the floating stones from the low stack to the south stack"})
	# 3. The middle of the high bridge, to the needle.
	var high: Dictionary = Art.bridge("needle")
	if not high.is_empty():
		out.append({"name":"high_bridge","at":(high.a as Vector3).lerp(high.b,0.5)+Vector3.UP*0.2,"move":"Cross the high bridge to the needle"})
	# 4. The needle turret's broken head, up its spiral.
	var needle: Dictionary = l.spires.needle
	out.append({"name":"turret","at":Vector3(needle.c.x,float(needle.top)+18*RuinKit.RISER+0.9,needle.c.y),"move":"Climb the needle's turret stair to its broken head"})
	# 5. Over the last floating stone from the turret to the summit.
	var n4: Dictionary = Art.platform("needle_4")
	if not n4.is_empty():
		out.append({"name":"needle_stones","at":(n4.at as Vector3)+Vector3.UP*0.85,"move":"Jump the floating stones from the turret's head to the summit"})
	# 6. The belfry's wall head, the isle's highest standing: up the corbels.
	var bel: Node3D = isle.get("belfry") if isle != null else null
	if bel != null:
		out.append({"name":"belfry_head","at":bel.global_transform*Vector3(-1.95,Belfry.HEAD+0.85,-1.95),"move":"Climb the corbels inside the belfry onto its wall head"})
	# 7. The fin's high top, up its stair from the chockstone.
	out.append({"name":"fin_top","at":Vector3(fh.c.x,float(fh.top)+1.2,fh.c.y),"move":"Climb from the chockstone round the fin's high stack"})
	return out
