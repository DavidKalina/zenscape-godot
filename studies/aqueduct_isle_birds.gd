extends "res://scripts/kit_isle/kit_birds.gd"
## Songbirds on the aqueduct isle's ruins (docs/scenic/aqueduct-isle-life.md):
## the kit isles' songbirds (scripts/kit_isle/kit_birds.gd) perched on this
## isle's stone: the aqueduct's parapets and channel lip, the castellum's
## crown and steps, the stone circle's lintels, the heel stone, the gate on
## the far island, the stepping stumps and the floating stones.
const Art = preload("res://studies/aqueduct_isle_art.gd")

## The flocks: [species, birds, home group].
const FLOCKS := [["sparrow",5,"aqueduct"],["goldfinch",4,"circle"],["robin",2,"castellum"],["sparrow",3,"gate"]]
## The stepping stumps' tops (studies/aqueduct_isle_art.gd `stumps`, x
## and the middle of each z span).
static func stump_tops() -> Array:
	var out: Array = []
	for st: Array in Art.stumps(): out.append(Vector2(float(st[0]),(float(st[1])+float(st[2]))*0.5))
	return out

func flock_specs() -> Array:
	return FLOCKS

func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
	var found := {}
	# The aqueduct: both parapets and the channel's lips, the head to the snap
	# and past the fallen span.
	var aq: Array = []
	var z := -2.6
	while z > -(Art.END-0.5):
		if z > -Art.SNAP+0.3 or z < -Art.RESUME-0.3:
			for side: float in [-1.0,1.0]: aq.append(Vector2(Art.MID_X+side*Art.PARAPET_Z,z))
		z -= 0.9
	found["aqueduct"] = aq
	# The castellum: its crown's broken parapet and its steps' edges.
	var cast: Array = []
	for zz in [-2.8,-1.9,-1.0,-0.1,0.7]: cast.append(Vector2(93.25,zz))
	for xx in [93.9,94.6]: cast.append(Vector2(xx,-2.8))
	for block: Array in Art.CASTELLUM:
		var r: Rect2 = block[0]
		cast.append(Vector2(r.end.x-0.15,r.get_center().y))
		cast.append(Vector2(r.position.x+0.2,r.get_center().y+0.4))
	found["castellum"] = cast
	# The stone circle: its standing lintels, at their middles and towards
	# their ends; and the floating sarsen.
	var circ: Array = []
	var circle: Node3D = scene.get("circle")
	if circle != null and circle.has_meta("ring"):
		for l: Array in (circle.get_meta("ring").lintels as Array):
			if not bool(l[1]): continue
			var mid: Vector3 = circle.transform*(l[0] as Vector3)
			circ.append(Vector2(mid.x,mid.z))
			var out := Vector2(mid.x,mid.z)-Vector2(circle.transform.origin.x,circle.transform.origin.z)
			var along := Vector2(-out.y,out.x).normalized()
			circ.append(Vector2(mid.x,mid.z)+along*0.8)
	var floating: Dictionary = Art.platform("ring_sarsen")
	if not floating.is_empty(): circ.append(Vector2(floating.at.x,floating.at.z))
	found["circle"] = circ
	# The heel stone and the east stones.
	found["heel"] = [Vector2(Art.HEEL.x,Art.HEEL.y),Vector2(Art.HEEL.x+0.4,Art.HEEL.y+0.2),Vector2(Art.platform("east_0").at.x,Art.platform("east_0").at.z),Vector2(Art.platform("east_1").at.x+0.6,Art.platform("east_1").at.z+0.5)]
	# The gate on the far island and the stumps back from it.
	var gate: Array = []
	for dx in [-2.4,-1.6,-0.8,0.0,0.8,1.6,2.4]:
		for dz in [-0.4,0.0,0.4]: gate.append(Vector2(Art.GATE.x+dx,Art.GATE.y+dz))
	for s: Vector2 in stump_tops(): gate.append(s)
	found["gate"] = gate
	# The drift of floating stones from the summit to the castellum.
	var drift: Array = []
	for p: Dictionary in Art.platforms():
		if p.chain in ["drift","south"]: drift.append(Vector2((p.at as Vector3).x+0.4,(p.at as Vector3).z-0.3))
	found["drift"] = drift
	return found
