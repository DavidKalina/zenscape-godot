extends "res://tools/capture_clusters.gd"
## The forest hold (scripts/forest_hold.gd), rendered: capture_clusters'
## overview and pass of forest holds, then closer views of each: from the
## plane coming in over the canopy (canopy), down on the glade with the hut
## and the hold tree's platform (glade), a walker's eye on the trail under
## the trees (trail), and along a rope bridge to a grove (bridge).
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_forest_hold.gd \
##     -- --no-title --only=forest --per=1 --out=captures/clusters/forest-hold/try [--seed=7] [--hours=noon,golden,night]

func _shots(field: Node3D, s: Dictionary) -> Array:
	var shots: Array = super(field,s)
	if s.motif != "forest": return shots
	var c: Dictionary = field.clusters.get(s.key,{})
	if not c.has("plan"): return shots
	var stood: Dictionary = field.members_of(s.key)
	if not stood.has("hold"): return shots
	var hold: Vector3 = stood.hold.home
	var member: Dictionary = c.plan.members[0]
	var shape: RefCounted = member.shape
	var cabin := Vector2.ZERO
	var tree := Vector2.ZERO
	for f: Dictionary in member.features:
		if f.type == "cabin": cabin = f.at
		if f.type == "treehouse": tree = f.at
	var ground := func(p: Vector2) -> Vector3: return hold+Vector3(p.x,shape.ground_at(p),p.y)
	var heart: Vector3 = ground.call(cabin)
	var out := Vector2(hold.x,hold.z).normalized()
	if out == Vector2.ZERO: out = Vector2.RIGHT
	var side := Vector2(-out.y,out.x)
	shots.append({"label":"canopy","eye":hold+Vector3(out.x*-38.0+side.x*22.0,26.0,out.y*-38.0+side.y*22.0),"look":hold+Vector3(0.0,3.0,0.0)})
	var glade_eye: Vector3 = heart+Vector3(side.x*9.0,10.0,side.y*9.0)
	shots.append({"label":"glade","eye":glade_eye,"look":(heart+ground.call(tree))*0.5+Vector3.UP*2.5})
	for f: Dictionary in member.features:
		if f.type == "trail" and not (f.lines as Array).is_empty():
			var line: PackedVector2Array = f.lines[0]
			var from: Vector2 = line[0].lerp(line[1],0.6)
			shots.append({"label":"trail","eye":ground.call(from)+Vector3.UP*1.7,"look":ground.call(line[2])+Vector3.UP*2.2})
			break
	for br: Dictionary in c.plan.bridges:
		if br.from != "hold": continue
		var a: Vector3 = hold+(br.a as Vector3)
		var b: Vector3 = hold+(br.b as Vector3)
		var way := (b-a).normalized()
		shots.append({"label":"bridge","eye":a-way*3.0+Vector3.UP*2.2+way.cross(Vector3.UP)*1.2,"look":b+Vector3.UP*1.5})
		break
	return shots
