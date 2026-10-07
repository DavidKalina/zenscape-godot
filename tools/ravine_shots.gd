extends RefCounted
## The ravine's own views for tools/capture_clusters.gd: threading the
## cleft from its wide mouth (thread), in the gap looking on to the bridge
## (inside), up at the bridge from under it (under), and on foot at the
## near half's bridge head (bridge), and from high off the wide end
## looking down the tear (aerial). In the islets' frame, from the plan's
## `cleft` (scripts/ravine_cut.gd `place`) and the cluster's middle `at`.
const RavineCut = preload("res://scripts/ravine_cut.gd")

static func shots(plan: Dictionary, at: Vector3) -> Array:
	var cleft: Dictionary = plan.cleft
	var tear: Dictionary = {}
	var near: Dictionary = {}
	for m: Dictionary in plan.members:
		if m.name == cleft.near:
			near = m
			tear = m.shape.recipe.tear
	if tear.is_empty(): return []
	var origin: Vector3 = at+(cleft.origin as Vector3)
	var rim := origin.y+0.4
	var point := func(s: float, y: float) -> Vector3:
		var q := RavineCut.middle_at(tear,s)
		return Vector3(origin.x+q.x,y,origin.z+q.y)
	var r := float(tear.radius)
	var bridge_s := float(cleft.bridge_s)
	var out: Array = [
		{"label":"aerial","eye":point.call(RavineCut.share_s(tear,2.4),rim+28.0),"look":point.call(RavineCut.share_s(tear,-0.2),rim-4.0)},
		{"label":"thread","eye":point.call(RavineCut.share_s(tear,1.45),rim+2.0),"look":point.call(RavineCut.share_s(tear,0.1),rim-2.5)},
		{"label":"inside","eye":point.call(RavineCut.share_s(tear,0.55),rim-3.0),"look":point.call(bridge_s,rim-0.5)},
		{"label":"under","eye":point.call(bridge_s+RavineCut.share_s(tear,0.3)-RavineCut.share_s(tear,0.0),rim-9.0),"look":point.call(bridge_s,rim)}]
	for br: Dictionary in plan.bridges:
		var a: Vector3 = at+(near.offset as Vector3)+(br.a as Vector3)
		var b: Vector3 = at+(near.offset as Vector3)+(br.b as Vector3)
		var back := (a-b).normalized()
		out.append({"label":"bridge","eye":a+back*3.0+Vector3.UP*1.8,"look":b+Vector3.UP*0.8})
	return out
