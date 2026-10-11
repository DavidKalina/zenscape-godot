extends "res://scripts/kit_isle/kit_life.gd"
## Life on the Sundered gorge isle: the kit isles' (scripts/kit_isle/
## kit_life.gd: the ground grid, undergrowth, butterflies over the flower
## patches, fireflies at dusk, the breeze ribbons, leaves, chaff and kicked
## blades, the same --no-... flags), its rays reaching the ledges and
## fragments far down the gorge, with this isle's songbirds' perches
## (`GorgeBirds`: the bridge's parapets and anchors, the gate tower's steps,
## the chapel's walls, the tor's pier), its leaves' anchors, its meadow, and
## its on-foot tokens (`GorgeTokens`).
const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")

## The meadow the chaff lies on (world rect): the west's, round the road.
const GORGE_MEADOW := Rect2(44.0,-24.0,26.0,22.0)
## The rays down: from this far over the west's lip to this far under it
## (the ledges far down the gorge's walls, the fragments deep in it).
const RAY_TOP := 45.0
const RAY_BOTTOM := 18.0

## The rays' reach in world y.
static func ray_span() -> Vector2:
	return Vector2(Gorge.TOP+RAY_TOP,Gorge.TOP-RAY_BOTTOM)

func make_birds() -> Node3D:
	return GorgeBirds.new()

func make_tokens() -> Node3D:
	return GorgeTokens.new()

func ground_span() -> Vector2:
	return ray_span()

func wind_box() -> Vector2:
	return Vector2(16.0,40.0)

func chaff_meadow() -> Rect2:
	return GORGE_MEADOW

## Loose leaves at the gate's and the tower's feet, the chapel's door and
## nave, the tor's pier, the bridge heads.
func leaf_spots() -> Array:
	return [Vector2(72.0,-12.0),Vector2(72.8,-21.0),Vector2(73.0,-26.0),Vector2(103.0,-15.5),Vector2(107.5,-13.0),
		Vector2(111.5,-17.0),Vector2(114.0,-12.5),Vector2(53.0,-31.0),Vector2(76.0,-16.8),Vector2(100.5,-13.0)]

# --- Songbirds on this isle's stone ---------------------------------------------------

class GorgeBirds extends "res://scripts/kit_isle/kit_birds.gd":
	const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")
	## [species, birds, home group].
	const GORGE_FLOCKS := [["sparrow",5,"bridge"],["goldfinch",4,"chapel"],["robin",2,"tower"],["sparrow",3,"tor"]]

	func flock_specs() -> Array:
		return GORGE_FLOCKS

	## The perch groups' points: the bridge's parapets either side of the
	## break and its anchors' caps, the gate tower's steps and crown, the
	## chapel's walls and gable, the tor's pier and stones, the crown stones
	## in the gap.
	func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
		var found := {}
		var bridge: Array = []
		for frame_break: Array in [[Gorge.west_bridge_frame(),Gorge.WEST_BREAK],[Gorge.east_bridge_frame(),Gorge.EAST_BREAK]]:
			var xf: Transform3D = frame_break[0]
			var x := -2.0
			while x < float(frame_break[1])-0.4:
				for s: float in [-1.0,1.0]:
					var p := xf*Vector3(x,0.0,s*(Gorge.DECK_HALF-Gorge.PARAPET.x*0.5))
					bridge.append(Vector2(p.x,p.z))
				x += 0.8
		for p: Dictionary in Gorge.platforms():
			if p.chain == "crown": bridge.append(Vector2((p.at as Vector3).x,(p.at as Vector3).z))
		found["bridge"] = bridge
		var tower: Array = []
		for block: Array in Gorge.TOWER:
			var r: Rect2 = block[0]
			var c := Gorge.tower_frame()*Vector3(r.get_center().x,0.0,r.get_center().y)
			tower.append(Vector2(c.x,c.z))
			var e := Gorge.tower_frame()*Vector3(r.end.x-0.2,0.0,r.get_center().y+0.3)
			tower.append(Vector2(e.x,e.z))
		found["tower"] = tower
		var chapel: Array = []
		var x := 105.8
		while x < 112.4:
			for z: float in [-18.65,-11.35]: chapel.append(Vector2(x,z))
			x += 0.7
		for z: float in [-17.8,-16.0,-14.0,-12.2]: chapel.append(Vector2(104.8,z))
		found["chapel"] = chapel
		var tor: Array = []
		for a in range(8):
			var q: Vector2 = Gorge.TOR_PIER+Vector2.from_angle(a*TAU/8.0)*0.35
			tor.append(q)
		tor.append(Vector2(Gorge.platform("mist").at.x,Gorge.platform("mist").at.z))
		found["tor"] = tor
		return found

# --- The on-foot tokens ----------------------------------------------------------

class GorgeTokens extends "res://scripts/kit_isle/kit_tokens.gd":
	const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")

	func spots_for(_isle: Node3D) -> Array[Dictionary]:
		return gorge_spots()

	## Where each token stands and the move it asks for (see the doc).
	static func gorge_spots() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		# 1. The gate tower's crown, up its fallen quarter.
		out.append({"name":"tower","at":Gorge.tower_frame()*Vector3(-1.0,9.6+0.85,-1.6),"move":"Climb the gate tower's fallen quarter to its crown"})
		# 2. The crown stones: the expert's crossing beside the rope bridge.
		var c2: Dictionary = Gorge.platform("crown_2")
		out.append({"name":"crown_stones","at":(c2.at as Vector3)+Vector3.UP*0.85,"move":"Twirled jumps over the crown stones beside the rope bridge"})
		# 3. Up the split pillar, between its slabs (wall kicks).
		var ch: Array = Gorge.chimney()
		var slot := ((ch[0][1] as float)+(ch[1][0] as float))*0.5
		out.append({"name":"chimney","at":Vector3(slot,float(ch[2])+3.3,(Gorge.CHIMNEY_Z.x+Gorge.CHIMNEY_Z.y)*0.5),"move":"Kick up the split pillar's slot from the east landing"})
		# 4. The mist stone by the curtain, off the lower ledge.
		var mist: Dictionary = Gorge.platform("mist")
		out.append({"name":"mist","at":(mist.at as Vector3)+Vector3.UP*0.85,"move":"Off the lower ledge's north end onto the stone by the fall"})
		# 5. The fallen crown, deep under the break (drop from a snapped end).
		var f: Array = Gorge.fragment("crown")
		out.append({"name":"crown","at":Vector3((f[1] as Vector2).x,float(f[3]),(f[1] as Vector2).y)+Gorge.CROWN_TOKEN,"move":"Drop from the bridge's snapped end onto the fallen crown"})
		# 6. Over the lower crossing's gap between the fragments.
		var a: Array = Gorge.fragment("chain_1")
		var b: Array = Gorge.fragment("chain_2")
		var mid := ((a[1] as Vector2)+(b[1] as Vector2))*0.5
		out.append({"name":"gap","at":Vector3(mid.x,maxf(float(a[3]),float(b[3]))+1.15,mid.y),"move":"Jump the gap between the fragments on the lower crossing"})
		# 7. The tor's top by its broken pier.
		var tp: Vector2 = Gorge.TOR_PIER+Vector2(-1.6,1.4)
		out.append({"name":"tor","at":Vector3(tp.x,Gorge.ground_w(tp.x,tp.y)+0.9,tp.y),"move":"Up the west tor's ramp to its top"})
		return out
