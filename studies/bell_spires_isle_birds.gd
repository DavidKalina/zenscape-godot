extends "res://scripts/kit_isle/kit_birds.gd"
## Songbirds on the bell spires (docs/scenic/bell-spires.md): the kit isles'
## songbirds (scripts/kit_isle/kit_birds.gd) perched on this isle's stone:
## the belfry's wall head, the bridges' anchor posts, the turrets' and
## arches' broken heads, the floating stones and the chockstone. Its spots
## are in the isle's own frame (the belfry and anchors as they stand in its
## art), so a placed isle (scripts/kit_isle/motif_isle.gd) moves them.
const Art = preload("res://studies/bell_spires_isle_art.gd")

## The flocks: [species, birds, home group].
const FLOCKS := [["sparrow",5,"belfry"],["goldfinch",4,"anchors"],["robin",2,"turret"],["sparrow",3,"stones"]]

func flock_specs() -> Array:
	return FLOCKS

func spots(_space: PhysicsDirectSpaceState3D) -> Dictionary:
	var found := {}
	# The belfry's wall head, all round, and its snapped pinnacles.
	var bel: Node3D = scene.get("belfry")
	if bel != null:
		var head: Array = []
		for k in range(16):
			var u := -2.2+4.4*float(k%8)/7.0
			var side := 1.0 if k < 8 else -1.0
			for local: Vector3 in [Vector3(u,0.0,side*1.95),Vector3(side*1.95,0.0,u)]:
				var w: Vector3 = bel.transform*local
				head.append(Vector2(w.x,w.z))
		found["belfry"] = head
	# The bridges' anchor posts.
	var posts: Array = []
	var holder: Node = scene.get("art").get_node_or_null("Bridges") if scene.get("art") != null else null
	if holder != null:
		for child in holder.get_children():
			if child.has_meta("posts"):
				for p: Vector3 in child.get_meta("posts"):
					var w: Vector3 = (child as Node3D).transform*p
					posts.append(Vector2(w.x,w.z))
	found["anchors"] = posts
	# The needle's turret and the fin's snapped one, and the arch on the
	# low stack: their broken heads.
	var turret: Array = []
	for name: String in ["needle","fin_high","low","gable"]:
		var s: Dictionary = Art.spire(name)
		var c: Vector2 = s.c
		for k in range(10):
			turret.append(c+Vector2.from_angle(TAU*k/10.0)*(1.4+0.5*float(k%2)))
	found["turret"] = turret
	# The floating stones and the chockstone.
	var stones: Array = []
	for p: Dictionary in Art.platforms(): stones.append(Vector2((p.at as Vector3).x+0.4,(p.at as Vector3).z-0.3))
	var chock: Vector3 = Art.layout().chock.at
	stones.append(Vector2(chock.x,chock.z))
	found["stones"] = stones
	return found
