extends "res://scripts/kit_isle/kit_life.gd"
## Life on the Hollow Keel (studies/hollow_keel_isle.gd): the kit isles'
## (scripts/kit_isle/kit_life.gd: undergrowth, butterflies, fireflies,
## songbirds on the stones, the wind made visible, on-foot tokens; the same
## flags), its songbirds on the chapel's walls and the bridge's anchors, its
## chaff on the plate's open turf, its leaves at the chapel's feet, its
## tokens this isle's.
const Keel = preload("res://studies/hollow_keel_isle_art.gd")

func make_birds() -> Node3D:
	return KeelBirds.new()

func make_tokens() -> Node3D:
	return KeelTokens.new()

## The plate east of the chapel.
func chaff_meadow() -> Rect2:
	return Rect2(Keel.HALL_X+58.0,Keel.MID.y-10.0,12.0,20.0)

func chaff_anchors() -> Array:
	var anchors: Array = []
	for meadow: Rect2 in [chaff_meadow(),Rect2(Keel.HALL_X+4.0,Keel.MID.y-8.0,9.0,16.0)]:
		anchors.append_array(GrassChaff.anchors_on(grass_at,GrassChaff.count_for(meadow.get_area()*0.4),placed(meadow)))
	return anchors

## Leaves gather at the chapel's feet and the shaft's rim.
func leaf_spots() -> Array:
	var anchors: Array = []
	for c: Array in Keel.CHAPEL:
		anchors.append(Vector2(Keel.HALL_X+float(c[3]),Keel.MID.y+float(c[4])))
	return anchors

# --- Songbirds on the chapel -------------------------------------------------------------

## The kit isles' songbirds (scripts/kit_isle/kit_birds.gd), their perches
## the chapel's wall tops and broken piers, the arch's, and the bridge's
## anchor on the islet.
class KeelBirds extends "res://scripts/kit_isle/kit_birds.gd":
	const HOMES := [["sparrow",5,"chapel"],["goldfinch",3,"north"],["robin",2,"islet"]]

	func flock_specs() -> Array:
		return HOMES

	func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
		var found := {"chapel":[],"north":[],"islet":[]}
		for x in range(14,55,1):
			for z in range(-4,16,1):
				(found.chapel as Array).append(Vector2(Keel.HALL_X+float(x)+0.3,Keel.MID.y+float(z)+0.2))
		for x in range(20,38,1):
			for z in range(-17,-9,1):
				(found.north as Array).append(Vector2(Keel.HALL_X+float(x)+0.3,Keel.MID.y+float(z)+0.2))
		var b: Vector3 = (Keel.bridge_ends()[0] as Array)[1]
		for dx in range(-3,2):
			for dz in range(-3,4):
				(found.islet as Array).append(Vector2(b.x+float(dx)*0.5,b.z+float(dz)*0.5))
		return found

# --- On-foot tokens -----------------------------------------------------------------------

## The kit isles' on-foot tokens, set where this isle asks for a move.
class KeelTokens extends "res://scripts/kit_isle/kit_tokens.gd":
	func spots_for(_isle: Node3D) -> Array[Dictionary]:
		return Keel.foot_spots()
