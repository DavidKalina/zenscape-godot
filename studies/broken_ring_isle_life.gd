extends "res://scripts/kit_isle/kit_life.gd"
## Life on the Broken Ring (studies/broken_ring_isle.gd): the kit isles'
## (scripts/kit_isle/kit_life.gd: undergrowth, butterflies, fireflies,
## songbirds on the stones, the wind made visible, on-foot tokens; every
## --no-... flag) with this isle's perches (the circle's lintels, the
## bridges' anchor posts, the floating stones, the notes), tokens up the
## spiral, meadow and leaf spots.
const Ring = preload("res://studies/broken_ring_isle_art.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

func make_birds() -> Node3D:
	return RingBirds.new()

func make_tokens() -> Node3D:
	return RingTokens.new()

## The meadow the chaff lies on (the circle's floor, frame of the isle).
func chaff_meadow() -> Rect2:
	return Rect2(Ring.C.x-6.0,Ring.C.y-6.0,12.0,12.0)

## The loose bits ride up the whole spiral: a taller box.
func wind_box() -> Vector2:
	return Vector2(6.0,50.0)

## Leaves gather at the notes' feet.
func leaf_spots() -> Array:
	var out: Array = []
	for note: Array in Ring.notes():
		var p: Vector3 = (note[3] as Transform3D).origin
		out.append(Vector2(p.x,p.z)+Vector2(0.8,0.8))
	return out

# --- Songbirds -----------------------------------------------------------------------

## The kit isles' songbirds (scripts/kit_isle/kit_birds.gd) perched on the
## ring's stone: the circle's sarsens, the anchors' posts, the floating
## stones, the turret's head and the satellites' notes.
class RingBirds extends "res://scripts/kit_isle/kit_birds.gd":
	const FLOCKS := [["sparrow",5,"circle"],["goldfinch",4,"anchors"],["robin",2,"notes"],["sparrow",3,"stones"]]

	func flock_specs() -> Array:
		return FLOCKS

	func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
		var found := {}
		var circle: Array = []
		var xf := Ring.circle_transform()
		for k in range(RuinKit.CIRCLE_STONES):
			if k in Ring.MISSING: continue
			var a := (k+0.0)*TAU/RuinKit.CIRCLE_STONES
			var w := xf*Vector3(sin(a)*RuinKit.CIRCLE_RADIUS,0.0,cos(a)*RuinKit.CIRCLE_RADIUS)
			circle.append(Vector2(w.x,w.z))
		found["circle"] = circle
		var posts: Array = []
		var holder: Node = scene.get("art").get_node_or_null("Bridges") if scene.get("art") != null else null
		if holder != null:
			for child in holder.get_children():
				if child.has_meta("posts"):
					for p: Vector3 in child.get_meta("posts"):
						var w: Vector3 = (child as Node3D).transform*p
						posts.append(Vector2(w.x,w.z))
		found["anchors"] = posts
		var notes: Array = []
		for note: Array in Ring.notes():
			var p: Vector3 = (note[3] as Transform3D).origin
			for k in range(4): notes.append(Vector2(p.x,p.z)+Vector2.from_angle(TAU*k/4.0+0.5)*1.4)
		found["notes"] = notes
		var stones: Array = []
		for p: Dictionary in Ring.platforms(): stones.append(Vector2((p.at as Vector3).x+0.3,(p.at as Vector3).z-0.2))
		found["stones"] = stones
		return found

# --- On-foot tokens -------------------------------------------------------------------

## The kit isles' on-foot tokens, set up the spiral where each asks for a move.
class RingTokens extends "res://scripts/kit_isle/kit_tokens.gd":
	func spots_for(_isle: Node3D) -> Array[Dictionary]:
		return ring_spots()

	static func ring_spots() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		# 1. Mid-way over the first rope bridge.
		var bridges: Array = Ring.bridges()
		var b0: Dictionary = bridges[0]
		var span0 := Vector2(b0.b.x-b0.a.x,b0.b.z-b0.a.z).length()
		out.append({"name":"first_bridge","at":(b0.a as Vector3).lerp(b0.b,0.5)+Vector3.UP*(Footbridge.lift(span0,0.5)+0.75),"move":"Cross the first rope bridge"})
		# 2. Over the first floating stones, high between the third and fourth.
		var s3: Dictionary = Ring.platform("stones_1_2_2")
		var s4: Dictionary = Ring.platform("stones_1_2_3")
		if not s3.is_empty() and not s4.is_empty():
			out.append({"name":"stones_low","at":((s3.at as Vector3)+(s4.at as Vector3))*0.5+Vector3.UP*1.0,"move":"Hop the floating stones up to the third isle"})
		# 3. Over the jump between the fourth and the fifth isle.
		var ends: Array = Ring.hop_ends(3,4)
		var mid: Vector2 = ((ends[0] as Vector2)+(ends[1] as Vector2))*0.5
		out.append({"name":"jump","at":Vector3(mid.x,float(Ring.sat(3).top)+1.6,mid.y),"move":"Jump the gap between the fourth and fifth isles"})
		# 4. Over the second floating stones.
		var t2: Dictionary = Ring.platform("stones_4_5_2")
		var t3: Dictionary = Ring.platform("stones_4_5_3")
		if not t2.is_empty() and not t3.is_empty():
			out.append({"name":"stones_high","at":((t2.at as Vector3)+(t3.at as Vector3))*0.5+Vector3.UP*1.0,"move":"Hop the floating stones up to the sixth isle"})
		# 5. The turret's broken head, up its spiral stair, on the central isle.
		var tt := Ring.turret_transform()
		out.append({"name":"turret","at":tt.origin+Vector3(0.0,18*RuinKit.RISER+0.9,0.0),"move":"Climb the turret's stair to its broken head in the circle"})
		# 6. The summit isle.
		var last: Dictionary = Ring.sat(Ring.SATS.size()-1)
		out.append({"name":"summit","at":Vector3(last.c.x,Ring.summit_y()+0.85,last.c.y),"move":"Climb the whole ring to the highest isle"})
		return out
