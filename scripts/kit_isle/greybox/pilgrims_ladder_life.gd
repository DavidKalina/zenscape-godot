extends "res://scripts/kit_isle/kit_life.gd"
## Life on the Pilgrim's Ladder (scripts/kit_isle/greybox/gb_pilgrims_ladder.gd
## `life_script`): kit_life's (undergrowth, butterflies, fireflies, the wind
## made visible) plus its on-foot tokens, one a station's move, from the
## motif's LAYOUT.tokens (the plan's collectibles that are walked to; the
## two flown threads have no token kind yet).
const Ladder = preload("res://scripts/kit_isle/greybox/gb_pilgrims_ladder.gd")

func make_tokens() -> Node3D:
	return LadderTokens.new()

class LadderTokens extends "res://scripts/kit_isle/kit_tokens.gd":
	func spots_for(_isle: Node3D) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for t: Dictionary in Ladder.LAYOUT.tokens:
			out.append({"name":t.name,"at":t.at,"move":t.move})
		return out
