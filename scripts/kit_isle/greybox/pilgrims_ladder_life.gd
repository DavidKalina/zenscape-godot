extends "res://scripts/kit_isle/kit_life.gd"
## Life on the Pilgrim's Ladder (scripts/kit_isle/greybox/gb_pilgrims_ladder.gd
## `life_script`): kit_life's (undergrowth, butterflies, fireflies, the wind
## made visible), songbirds on its stone (`make_birds`) and its on-foot
## tokens, one a station's move, from the
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

## Songbirds on the pilgrimage's stone (scripts/kit_isle/kit_birds.gd):
## their perch groups' candidate points over LAYOUT.dressing's pieces (a
## few round each, the rays keep the ones that stand), the gate's lintel
## and the arch's head. Points in the motif's frame (kit_birds adds the
## placed offset).
func make_birds() -> Node3D:
	return LadderBirds.new()

class LadderBirds extends "res://scripts/kit_isle/kit_birds.gd":
	const FLOCKS := [["sparrow",5,"shrine"],["goldfinch",4,"west"],["robin",2,"gate"],["sparrow",3,"halo"],["goldfinch",3,"crown"]]
	## Group -> the dressing pieces' seeds round which it perches.
	const GROUPS := {"shrine":[5401,5420,5421,5422,5423,5424,5405],"west":[5408,5425,5426,5409,5410,5411,5501],
		"halo":[5412,5413,5414],"crown":[5416,5417,5501]}

	func flock_specs() -> Array:
		return FLOCKS

	func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
		var found := {}
		for group: String in GROUPS:
			var points: Array = []
			for p: Dictionary in Ladder.LAYOUT.dressing:
				if not (GROUPS[group] as Array).has(int(p.seed)): continue
				var at: Vector3 = p.at
				# The arch (seed 5501 on Threshold) and the buttress (on the
				# Crown) share a seed: keep each to its own isle.
				if int(p.seed) == 5501 and (group == "crown") != (at.y > 10.0): continue
				var turn := Basis(Vector3.UP,deg_to_rad(float(p.get("rot",0.0))))
				for k in range(-3,4):
					for side: float in [0.0,0.45]:
						var w := at+turn*Vector3(k*0.9,0.0,side)
						points.append(Vector2(w.x,w.z))
			found[group] = points
		var gate: Array = []
		var torana: Dictionary = Ladder.LAYOUT.pieces[0]
		for k in range(0,20):
			gate.append(Vector2((torana.at as Vector3).x-0.5+k,(torana.at as Vector3).z))
		found["gate"] = gate
		return found
