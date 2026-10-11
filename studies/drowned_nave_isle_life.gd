extends "res://scripts/kit_isle/kit_life.gd"
## Life on the drowned nave (studies/drowned_nave_isle.gd): the kit isles'
## (scripts/kit_isle/kit_life.gd) on this isle's ground, its grass and
## undergrowth kept off its paths and the water: its perches (`NaveBirds`),
## its foot tokens (`NaveTokens`), its meadow (the west beach) and its
## ruins' feet; and its sky's plane tokens (`NaveSky`).
const NaveArt = preload("res://studies/drowned_nave_isle_art.gd")

## The meadow the chaff lies on (world): the west beach.
const NAVE_CHAFF := Rect2(NaveArt.C.x-58.0,NaveArt.C.y-5.5,15.0,8.0)

func make_birds() -> Node3D:
	return NaveBirds.new()

func make_tokens() -> Node3D:
	return NaveTokens.new()

func chaff_meadow() -> Rect2:
	return NAVE_CHAFF

## Off the turf a ribbon rides the shore's height.
func ride_y() -> float:
	return NaveArt.K

## Loose leaves at the ruins' feet: the beach, the shoulders, the plateau.
func leaf_spots() -> Array:
	var c := NaveArt.C
	return [c+Vector2(-40.0,-5.0),c+Vector2(-40.0,6.0),c+Vector2(-47.0,0.0),c+Vector2(38.0,-8.0),c+Vector2(38.0,8.0),
		c+Vector2(50.0,-5.0),c+Vector2(50.0,5.0),c+Vector2(-20.0,-23.0),c+Vector2(18.0,22.0)]

# --- The songbirds -------------------------------------------------------------------

class NaveBirds extends "res://scripts/kit_isle/kit_birds.gd":
	const NAVE_FLOCKS := [["sparrow",5,"north_walk"],["goldfinch",4,"plateau"],["robin",2,"stubs"],["sparrow",3,"south_walk"],["goldfinch",3,"causeway"]]

	func flock_specs() -> Array:
		return NAVE_FLOCKS

	func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
		var c := NaveArt.C
		var found := {}
		var along := func(z: float, x0: float, x1: float) -> Array:
			var out: Array = []
			var x := x0
			while x <= x1:
				out.append(c+Vector2(x,z))
				x += 1.1
			return out
		found["north_walk"] = along.call(-NaveArt.ROW_Z,-26.0,26.0)
		found["south_walk"] = along.call(NaveArt.ROW_Z,-26.0,26.0)
		var stubs: Array = []
		for x: float in [-10.8,-5.4]:
			for dz: float in [-0.3,0.0,0.3]: stubs.append(c+Vector2(x+dz,NaveArt.ROW_Z))
		found["stubs"] = stubs
		var plateau: Array = []
		for dx: float in [-2.6,-1.4,1.4,2.6]:
			for dz: float in [-3.0,-1.5,1.5,3.0]: plateau.append(c+Vector2(NaveArt.GABLE_X-3.5+dx,dz))
		found["plateau"] = plateau
		var stones: Array = []
		for p: Dictionary in NaveArt.platforms():
			if p.chain == "causeway": stones.append(Vector2((p.at as Vector3).x+0.3,(p.at as Vector3).z-0.2))
		found["causeway"] = stones
		return found

# --- The tokens ----------------------------------------------------------------------

class NaveTokens extends "res://scripts/kit_isle/kit_tokens.gd":
	func spots_for(_isle: Node3D) -> Array[Dictionary]:
		return nave_spots()

	static func nave_spots() -> Array[Dictionary]:
		var c := NaveArt.C
		var out: Array[Dictionary] = []
		# 1. Over the drowned nave on the causeway, a stone from the middle.
		var mid: Dictionary = NaveArt.platform("causeway_10")
		out.append({"name":"causeway","at":(mid.at as Vector3)+Vector3.UP*0.85,"move":"Hop the causeway down the drowned nave"})
		# 2. The lookout: the plateau before the rose gable, up the grand stair.
		var g := NaveArt.world(Vector2(NaveArt.GABLE_X-3.0,-1.5))
		out.append({"name":"lookout","at":Vector3(g.x,NaveArt.plateau_top()+0.85,g.y),"move":"Up the apse's grand stair to the rose gable"})
		# 3. The north arcade's wall-walk, up the buttress.
		out.append({"name":"walk","at":Vector3(c.x-13.5,NaveArt.NAVE_FLOOR+NaveArt.TALL+0.85,c.y-NaveArt.ROW_Z),"move":"Up the buttress onto the arcade's wall-walk"})
		# 4. A snapped pier in the south row, its stub the top.
		out.append({"name":"stub","at":Vector3(c.x-10.8,NaveArt.NAVE_FLOOR+3.1+0.85,c.y+NaveArt.ROW_Z),"move":"Onto the snapped pier"})
		# 5. The spill's bank, by the slabs over the channel.
		var lp := NaveArt.lip()
		var sz := c.y-32.0
		var sx := lp.x+NaveArt.CH+3.0
		out.append({"name":"spill","at":Vector3(sx,NaveArt.ground(sx,sz)+0.85,sz),"move":"Along the north shore to the spill"})
		return out

# --- The sky's plane tokens -------------------------------------------------------------

class NaveSky extends "res://studies/aqueduct_isle_sky.gd":
	func plane_tokens() -> Array:
		return nave_tokens()

	func token_source() -> String:
		return "nave"

	static func nave_tokens() -> Array:
		return preload("res://scripts/kit_isle/motif_drowned_nave.gd").nave_tokens()
