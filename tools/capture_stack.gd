extends "res://tools/capture_clusters.gd"
## The hermit's stack (scripts/cluster_stack.gd), rendered: the clusters
## capture (tools/capture_clusters.gd) with views framed for a column, not
## a spread: its profile from the side as a flight passes it, an overview
## from over its top, a pass close by its stairs, the hut on the top, and
## a look up a stair from its foot. Rendered only when asked for:
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_stack.gd \
##     -- --no-title --only=stack --out=captures/clusters/hermit-stack/try2 [--per=2] [--seed=7] [--hours=noon,golden,night]

func _shots(field: Node3D, s: Dictionary) -> Array:
	if s.motif != "stack": return super(field,s)
	var stood: Dictionary = field.members_of(s.key)
	var plan: Dictionary = field.clusters[s.key].plan
	var low := INF
	var high := -INF
	var centre := Vector3.ZERO
	var top: Dictionary = {}
	for b: Dictionary in stood.values():
		centre += b.home
		low = minf(low,b.home.y-float(b.shape.depth))
		high = maxf(high,b.home.y+3.0)
		if top.is_empty() or b.home.y > top.home.y: top = b
	centre /= maxf(stood.size(),1)
	var tall := high-low
	var mid := Vector3(centre.x,(low+high)*0.5,centre.z)
	var away := Vector2(centre.x,centre.z).normalized()
	if away == Vector2.ZERO: away = Vector2.RIGHT
	var toward_home := Vector3(-away.x,0.0,-away.y)
	var side := Vector3(-toward_home.z,0.0,toward_home.x)
	var hut: Vector3 = top.home
	for f: Dictionary in (plan.members as Array).filter(func(m: Dictionary) -> bool: return m.name == top.member)[0].features:
		if f.type == "cabin": hut = top.home+Vector3(f.at.x,float(top.shape.ground_at(f.at)),f.at.y)
	# A stair's foot and a point up it, for the look up it.
	var st: Dictionary = (plan.stairs as Array)[0]
	var from: Dictionary = stood[st.from]
	var points: Array = st.points
	var foot: Vector3 = from.home+(points[0] as Vector3)
	var up: Vector3 = from.home+(points[mini(4,points.size()-1)] as Vector3)
	var way := Vector3(up.x-foot.x,0.0,up.z-foot.z).normalized()
	return [{"label":"profile","eye":mid+(toward_home*0.8+side*0.6).normalized()*tall*1.45,"look":mid},
		{"label":"overview","eye":centre+(toward_home*0.7+side*0.7)*tall*0.75+Vector3(0.0,high-centre.y+tall*0.35,0.0),"look":mid+Vector3.UP*tall*0.1},
		{"label":"pass","eye":mid+(toward_home*0.9-side*0.9).normalized()*24.0+Vector3.DOWN*4.0,"look":mid+Vector3.UP*6.0},
		{"label":"hut","eye":hut+(toward_home-side*0.5).normalized()*11.0+Vector3.UP*4.5,"look":hut+Vector3.UP*1.2},
		{"label":"stair","eye":foot-way*2.5+Vector3.UP*1.7,"look":up+Vector3.UP*1.0}]
