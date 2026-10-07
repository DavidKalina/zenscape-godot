extends "res://tools/capture_clusters.gd"
## The lake motif (scripts/cluster_motifs.gd "lake"), rendered close: the
## cluster tool's visits (tools/capture_clusters.gd) dealt to the lake
## only, each lake seen from near views of its own: overview (the whole
## cluster, a flight off), lake (low over the far bank across the water to
## the jetty), jetty (standing at its head, looking out along it), fall
## (off the rim, the spill pouring down) and pass (a plane's pass).
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_lake.gd \
##     -- --no-title --only=lake --out=captures/clusters/lake/try2 [--per=2] [--seed=7] [--hours=noon,golden,night]

func _shots(field: Node3D, s: Dictionary) -> Array:
	var stood: Dictionary = field.members_of(s.key)
	if not stood.has("lake"): return super._shots(field,s)
	var lead: Dictionary = stood.lake
	var home: Vector3 = lead.home
	var shape: RefCounted = lead.shape
	var level: float = shape.water_level
	var plan: Dictionary = field.clusters[s.key].plan
	var jetty := {}
	for m: Dictionary in plan.members:
		if m.name != "lake": continue
		for f: Dictionary in m.features:
			if f.type == "dock" and f.get("jetty",false): jetty = f
	var centre := Vector3.ZERO
	for b: Dictionary in stood.values(): centre += b.home
	centre /= maxf(stood.size(),1)
	var shots: Array = []
	var deep: Vector2 = shape.lake.deep
	var water := home+Vector3(deep.x,level,deep.y)
	var reach: float = shape.reach
	var away := Vector2(home.x-centre.x,home.z-centre.z)
	away = away.normalized() if away.length() > 0.5 else Vector2.RIGHT
	shots.append({"label":"overview","eye":home+Vector3(away.x,0.0,away.y)*reach*1.6+Vector3(-away.y,0.0,away.x)*reach*1.2+Vector3.UP*reach*1.5,"look":home+Vector3.DOWN*2.0})
	if not jetty.is_empty():
		var a: Vector3 = jetty.a
		var b: Vector3 = jetty.b
		var way := (b-a).normalized()
		# Across the lake from beyond the jetty's end, low, back at it.
		shots.append({"label":"lake","eye":home+b+way*9.0+Vector3.UP*2.2+Vector3(-way.z,0.0,way.x)*3.0,"look":home+(a+b)*0.5+Vector3.UP*0.4})
		shots.append({"label":"jetty","eye":home+a-way*1.2+Vector3.UP*1.7,"look":home+b+way*4.0+Vector3.DOWN*0.6})
	var lip: Vector2 = shape.lip
	var out: Vector2 = shape.lip_out
	var side := Vector2(-out.y,out.x)
	shots.append({"label":"fall","eye":home+Vector3(lip.x+out.x*16.0+side.x*9.0,level-4.0,lip.y+out.y*16.0+side.y*9.0),"look":home+Vector3(lip.x,level-3.0,lip.y)})
	shots.append({"label":"pass","eye":water+Vector3(-away.y,0.0,away.x)*reach*1.5+Vector3.UP*7.0,"look":water})
	return shots
