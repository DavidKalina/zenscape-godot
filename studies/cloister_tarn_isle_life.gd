extends "res://scripts/kit_isle/kit_life.gd"
## Life on the cloister tarn (studies/cloister_tarn_isle.gd): the kit isles'
## (scripts/kit_isle/kit_life.gd: undergrowth, butterflies, fireflies,
## songbirds on the stones, the wind made visible, on-foot tokens; every
## --no-... flag) on this isle's ground, its grass and undergrowth kept off
## its paths, the water and the water's edge (the scene's `flora_site`):
## its perches (`TarnBirds`), its tokens (`TarnTokens`), its meadow and its
## ruins' feet; and its sky's plane tokens (`TarnSky`).
const TarnArt = preload("res://studies/cloister_tarn_isle_art.gd")
const Footbridge = preload("res://scripts/footbridge.gd")

## The meadow the chaff lies on (world): the south terrace and the garth's
## south-west.
const TARN_CHAFF := Rect2(TarnArt.C.x-8.0,TarnArt.C.y+15.5,16.0,8.0)

func make_birds() -> Node3D:
	return TarnBirds.new()

func make_tokens() -> Node3D:
	return TarnTokens.new()

func chaff_meadow() -> Rect2:
	return TARN_CHAFF

## Off the turf a ribbon rides the cloister walk's height.
func ride_y() -> float:
	return TarnArt.K

## Loose leaves at the cloister's feet (the gap's heaps, the garth's
## corners, the lavabo's isle).
func leaf_spots() -> Array:
	var c := TarnArt.C
	return [c+Vector2(-14.6,4.0),c+Vector2(-14.6,-4.0),c+Vector2(-9.5,-9.5),c+Vector2(9.5,9.5),c+Vector2(-9.5,9.5),
		c+TarnArt.SHRINE+Vector2(2.6,1.4),c+Vector2(14.6,-8.0),c+Vector2(0.0,17.5)]

# --- The songbirds -------------------------------------------------------------------

## The kit isles' songbirds (scripts/kit_isle/kit_birds.gd) perched on this
## isle's stone: the wall-walks, the lavabo, the stubs and heaps, the
## bridge heads, the floating stones.
class TarnBirds extends "res://scripts/kit_isle/kit_birds.gd":
	const TARN_FLOCKS := [["sparrow",5,"north_walk"],["goldfinch",4,"lavabo"],["robin",2,"gap"],["sparrow",3,"south_walk"],["goldfinch",3,"stones"]]

	func flock_specs() -> Array:
		return TARN_FLOCKS

	func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
		var c := TarnArt.C
		var found := {}
		var along := func(z: float, x0: float, x1: float) -> Array:
			var out: Array = []
			var x := x0
			while x <= x1:
				out.append(c+Vector2(x,z))
				x += 1.1
			return out
		found["north_walk"] = along.call(-TarnArt.ARC,-12.0,12.0)
		found["south_walk"] = along.call(TarnArt.ARC,-12.0,12.0)
		var lavabo: Array = []
		for dx: float in [-1.6,-0.5,0.6,1.7]:
			for dz: float in [-1.6,0.0,1.6]: lavabo.append(c+TarnArt.SHRINE+Vector2(dx,dz))
		found["lavabo"] = lavabo
		var gap: Array = []
		var e := TarnArt.GAP_END
		for z: float in [TarnArt.STUB_X,e-TarnArt.HEAP_CHUNK,e+1.6,e+2.8]:
			for s: float in [-1.0,1.0]: gap.append(c+Vector2(-TarnArt.ARC,s*z))
		found["gap"] = gap
		var stones: Array = []
		for p: Dictionary in TarnArt.platforms():
			if p.chain in ["north","northeast","west"]: stones.append(Vector2((p.at as Vector3).x+0.3,(p.at as Vector3).z-0.2))
		found["stones"] = stones
		return found

# --- The tokens ----------------------------------------------------------------------

## The on-foot tokens (the kit isles', scripts/kit_isle/kit_tokens.gd),
## each where it asks for a move.
class TarnTokens extends "res://scripts/kit_isle/kit_tokens.gd":
	func spots_for(_isle: Node3D) -> Array[Dictionary]:
		return tarn_spots()

	static func tarn_spots() -> Array[Dictionary]:
		var c := TarnArt.C
		var out: Array[Dictionary] = []
		# 1. Over the lower of the cloister gap's two snapped piers (the
		# west range's pier 4, its x north in the world): down off the
		# fallen chunk onto it. The stubs stand the plane's slot apart
		# (TarnArt.STUB_GAP), too far to hop from one to the other.
		out.append({"name":"stubs","at":Vector3(c.x-TarnArt.ARC,TarnArt.K+float(TarnArt.STUBS[4])+0.85,c.y-TarnArt.STUB_X),"move":"Down onto the snapped pier at the cloister's gap"})
		# 2. On the lavabo's top: out over the stepping stones, up its drums.
		var sm := TarnArt.world(TarnArt.SHRINE)
		out.append({"name":"lavabo","at":Vector3(sm.x,TarnArt.SHRINE_TOP+TarnArt.WALK+0.85,sm.y),"move":"Out over the stepping stones and up the lavabo's fallen drums"})
		# 3. The crag's summit.
		var crag := TarnArt.world(TarnArt.way(126.0)*TarnArt.RIM/TarnArt.sq(TarnArt.way(126.0)))
		out.append({"name":"crag","at":Vector3(crag.x,TarnArt.K+TarnArt.CRAG_TOP+0.85,crag.y),"move":"Up the ridge and the carved stair to the crag's summit"})
		# 4. On the water gate's raised walk: round the wall-walk.
		out.append({"name":"gate","at":Vector3(c.x+TarnArt.ARC,TarnArt.K+TarnArt.GATE_WALK+0.85,c.y),"move":"Round the wall-walk to the water gate"})
		# 5. Over the north face's fourth rock tier: climbed tier by tier out
		# of the alley, a jump-catch each.
		var n := ceili((TarnArt.ground(c.x,c.y-22.6)-TarnArt.K)/TarnArt.TIER)
		var depth := (TarnArt.RIM-TarnArt.CREST_W-TarnArt.BACK)/n
		var z := c.y-(TarnArt.BACK+depth*3.5)
		out.append({"name":"tiers","at":Vector3(c.x,TarnArt.ground(c.x,z)+0.85,z),"move":"Climb the north face's rock tiers out of the alley"})
		# 6. Hung over the north-east rope bridge's middle: jump on the deck.
		for b: Dictionary in TarnArt.bridges():
			if b.name == "northeast_bridge":
				var mid: Vector3 = (b.a as Vector3).lerp(b.b,0.5)
				out.append({"name":"bridge","at":mid+Vector3.UP*(Footbridge.lift(Vector2(b.b.x-b.a.x,b.b.z-b.a.z).length(),0.5)+1.75),"move":"Jump on the swaying rope bridge"})
		# 7. Between the north chain's second and third stones.
		var s2: Dictionary = TarnArt.platform("north_2")
		var s3: Dictionary = TarnArt.platform("north_3")
		if not s2.is_empty() and not s3.is_empty():
			out.append({"name":"stones","at":((s2.at as Vector3)+(s3.at as Vector3))*0.5+Vector3.UP*1.0,"move":"Hop the floating stones from the crag to the north isle"})
		return out

# --- The sky's plane tokens -------------------------------------------------------------

## The kit isles' sky round this isle, its plane tokens this isle's line:
## in over the west saddle, through the cloister's gap between the stubs,
## skimming the tarn, through the water gate, down the fall.
class TarnSky extends "res://studies/aqueduct_isle_sky.gd":
	func plane_tokens() -> Array:
		return tarn_tokens()

	func token_source() -> String:
		return "cloister"

	static func tarn_tokens() -> Array:
		return preload("res://scripts/kit_isle/motif_cloister_tarn.gd").tarn_tokens()
