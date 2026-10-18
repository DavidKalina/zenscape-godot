extends "res://scripts/kit_isle/kit_life.gd"
## Life on the Stair to the Clouds (studies/stair_clouds_isle.gd): the kit
## isles' (scripts/kit_isle/kit_life.gd: undergrowth, butterflies, fireflies,
## songbirds on the stones, the wind made visible, on-foot tokens; the same
## flags), its stone perches, its chaff's meadow, its leaves' anchors and its
## tokens this isle's.
const Stair = preload("res://studies/stair_clouds_isle_art.gd")

func make_birds() -> Node3D:
	return StairBirds.new()

func make_tokens() -> Node3D:
	return StairTokens.new()

## The loose bits rise with the mesa.
func wind_box() -> Vector2:
	return Vector2(6.0,Stair.SUMMIT+14.0)

## The chaff on the lawn.
func chaff_meadow() -> Rect2:
	var c := Stair.side_at(Stair.SIDES-1,0.0,Stair.LAWN_AT+2.0)
	return Rect2(c.x-7.0,c.y-5.0,14.0,10.0)

## Leaves gather at the landings' shrines and the gate's feet.
func leaf_spots() -> Array:
	var anchors: Array = []
	for spec: Array in Stair.SHRINES:
		if spec[0] == "pad":
			var p := Stair.vertex_at(int(spec[1]),float(spec[2])-1.2,deg_to_rad(float(spec[3])))
			anchors.append(p)
	anchors.append(Stair.side_at(Stair.SIDES-1,2.0,-5.0))
	return anchors

# --- Songbirds on the shrines ------------------------------------------------------

## The kit isles' songbirds (scripts/kit_isle/kit_birds.gd), their perches
## the shrines': the fallen pier and the terrace arch (a grid of points
## over each, so the ray finds their tops), the piers' stubs and the
## summit's turret and lancet walls (a finer grid: their tops are thin).
class StairBirds extends "res://scripts/kit_isle/kit_birds.gd":
	const HOMES := [["sparrow",4,"fallen"],["goldfinch",3,"stubs"],["robin",2,"summit"]]

	func flock_specs() -> Array:
		return HOMES

	func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
		var found := {"fallen":[],"stubs":[],"summit":[]}
		for spec: Array in Stair.SHRINES:
			var at := Stair.shrine_frame(spec).origin
			var p := Vector2(at.x,at.z)
			match str(spec[4]):
				"pier": (found.stubs as Array).append(p)
				"fallen_pier","arch":
					var f := Stair.shrine_frame(spec)
					for i in range(-3,4):
						for j in range(-3,4):
							var q := f*Vector3(0.6*i,0.0,0.6*j)
							(found.fallen as Array).append(Vector2(q.x,q.z))
		for f: Transform3D in summit_frames():
			for i in range(-6,7):
				for j in range(-6,7):
					var q := f*Vector3(0.3*i,0.0,0.3*j)
					(found.summit as Array).append(Vector2(q.x,q.z))
		return found

	## The summit's turret and lancet walls: the robins sit on their
	## broken tops.
	static func summit_frames() -> Array[Transform3D]:
		return Stair.summit_frames()

# --- On-foot tokens ---------------------------------------------------------------------

## The kit isles' on-foot tokens, set where this isle asks for a move.
class StairTokens extends "res://scripts/kit_isle/kit_tokens.gd":
	func spots_for(_isle: Node3D) -> Array[Dictionary]:
		return stair_spots()

	## Where each stands and the move it asks for.
	static func stair_spots() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for spec: Array in TOKENS:
			var p := Stair.vertex_at(int(spec[1]),float(spec[2]))
			out.append({"name":spec[0],"at":Vector3(p.x,Stair.TOP+float(spec[3])+0.85,p.y),"move":spec[4]})
		var gate := Stair.side_at(Stair.SIDES-1,Stair.GATE_AT.x,Stair.GATE_AT.y)
		out.append({"name":"gate","at":Vector3(gate.x,Stair.TOP+Stair.SUMMIT+0.85,gate.y),"move":"Climb the whole stair to the gate on the summit"})
		var pin := Stair.pinnacle_at()
		out.append({"name":"pinnacle","at":Vector3(pin.x,Stair.TOP+Stair.PIN_TOP+0.85,pin.y),"move":"Cross the rope bridge from the summit's rim to the hanging pinnacle"})
		return out

	## [name, vertex, radius, height over TOP, move]. At radius 22 on the
	## landing's inner side: pads 1 and 5 have their piers at about 25 on the
	## vertex line, and their stone stands from 23 out.
	const TOKENS := [
		["landing_1",1,22.0,1.0*Stair.STEP,"Up the first flights to the first landing, and its piers"],
		["landing_3",3,22.0,3.0*Stair.STEP,"Round the mesa to the third landing"],
		["landing_5",5,22.0,5.0*Stair.STEP,"Up and round to the fifth landing, high over the lawn"],
		["landing_7",7,22.0,7.0*Stair.STEP,"The seventh landing, one flight under the summit"],
	]
