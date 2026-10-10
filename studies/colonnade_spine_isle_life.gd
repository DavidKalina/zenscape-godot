extends "res://scripts/kit_isle/kit_life.gd"
## Life on the colonnade spine (studies/colonnade_spine_isle.gd): the kit
## isles' (scripts/kit_isle/kit_life.gd: undergrowth, butterflies,
## fireflies, songbirds on the stones, the wind made visible, on-foot
## tokens; the same flags), its stone perches, its chaff's meadows, its
## leaves' anchors and its tokens this isle's.
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")

func make_birds() -> Node3D:
	return SpineBirds.new()

func make_tokens() -> Node3D:
	return SpineTokens.new()

func wind_box() -> Vector2:
	return Vector2(6.0,40.0)

## The chaff on the plaza and the low terrace (the isle's open turf).
func chaff_anchors() -> Array:
	var anchors: Array = []
	for meadow: Rect2 in [Rect2(46.0,Spine.zc(58.0)-6.0,24.0,12.0),Rect2(116.0,Spine.zc(124.0)-6.0,16.0,12.0)]:
		anchors.append_array(GrassChaff.anchors_on(grass_at,GrassChaff.count_for(meadow.get_area()*0.4),meadow))
	return anchors

## Leaves gather at the piers' feet, the stairs' and the gate's.
func leaf_spots() -> Array:
	var anchors: Array = []
	for i in range(0,Spine.LINES.size(),2):
		var x: float = Spine.LINES[i][0]
		anchors.append(Spine.at(x+0.9,-Spine.ROW+0.8))
	anchors.append(Spine.at(Spine.GATE_X+1.6,1.5))
	anchors.append(Spine.at(Spine.STEP_L3+5.0,1.8))
	return anchors

# --- Songbirds on the colonnade --------------------------------------------------------

## The kit isles' songbirds (scripts/kit_isle/kit_birds.gd), their perches
## the colonnade's: the upper terraces' lintels by the temple, the low
## terraces' lintels, the snapped piers' stubs, the tail's stones and the
## bridges' anchor posts.
class SpineBirds extends "res://scripts/kit_isle/kit_birds.gd":
	const HOMES := [["sparrow",5,"upper"],["goldfinch",4,"lower"],["robin",2,"stubs"],["sparrow",3,"tail"]]

	func flock_specs() -> Array:
		return HOMES

	func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
		var found := {"upper":[],"lower":[],"stubs":[],"tail":[]}
		for l: Dictionary in Spine.lintels():
			var a: Vector3 = l.a
			var b: Vector3 = l.b
			var key := "upper" if a.x < Spine.STEP_L2 else "lower"
			var n := int(a.distance_to(b)/1.1)
			for k in range(n+1):
				var p := a.lerp(b,(k+0.5)/(n+1))
				(found[key] as Array).append(Vector2(p.x,p.z))
		var colonnade: Node3D = scene.get("colonnade")
		if colonnade != null:
			for s: Dictionary in colonnade.get_meta("stubs"): (found.stubs as Array).append(Vector2((s.at as Vector3).x,(s.at as Vector3).z))
		for p: Dictionary in Spine.platforms(): (found.tail as Array).append(Vector2((p.at as Vector3).x+0.3,(p.at as Vector3).z-0.2))
		return found

# --- On-foot tokens --------------------------------------------------------------------

## The kit isles' on-foot tokens, set where this isle asks for a move.
class SpineTokens extends "res://scripts/kit_isle/kit_tokens.gd":
	func spots_for(isle: Node3D) -> Array[Dictionary]:
		return spine_spots(isle)

	## Where each stands and the move it asks for.
	static func spine_spots(isle: Node3D) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		var colonnade: Node3D = isle.get("colonnade") if isle != null else null
		for l: Dictionary in Spine.lintels():
			if float(l.side) != 0.0: continue
			var mid: Vector3 = ((l.a as Vector3)+(l.b as Vector3))*0.5
			var low := mid.x > Spine.STEP_L2
			out.append({"name":"cross_low" if low else "cross_high","at":mid+Vector3.UP*0.85,
				"move":"Climb onto the lintels (the drum and the stub by the start) and cross between the rows" if low else "From the plaza's edge, catch the next terrace's lintels and cross between the rows"})
		if colonnade != null:
			var w: Array = colonnade.get_meta("wedged")
			out.append({"name":"cleft","at":((w[0] as Vector3)+(w[1] as Vector3))*0.5+Vector3.UP*1.0,
				"move":"Hop down the drums wedged in the cleft"})
		for name: String in ["south_3","pulpit"]:
			var s := Spine.slab(name)
			var c := Spine.slab_at(s)
			out.append({"name":name,"at":Vector3(c.x,Spine.TOP+float(s[4])+0.85,c.y),
				"move":"Up the shelves jutting from the south flank" if name == "south_3" else "Drop off the podium onto the pulpit hanging over the sky"})
		var ends: Array = Spine.bridge_ends()[0]
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		var span := Vector2(b.x-a.x,b.z-a.z).length()
		out.append({"name":"bridge","at":a.lerp(b,0.5)+Vector3.UP*(Spine.Footbridge.lift(span,0.5)+0.75),
			"move":"Cross the rope bridge in the tail's curl"})
		return out
