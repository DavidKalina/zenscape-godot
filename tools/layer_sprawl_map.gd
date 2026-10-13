extends SceneTree
## The sprawl shape's layers as text maps (scripts/roguelike/
## layer_sprawl.gd `overview`), headless, no scene built: the plan, its
## exit chain, the next region's silhouette's cost and where it stands, and
## where the dragon's roost stands.
##   godot --headless --path . --script tools/layer_sprawl_map.gd -- --seeds=15,1,2
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const NextRegionLod = preload("res://scripts/roguelike/next_region_lod.gd")

func _initialize() -> void:
	var seeds: Array = [15,1,2]
	var maps := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): seeds = Array(arg.trim_prefix("--seeds=").split(",")).map(func(s: String) -> int: return int(s))
		if arg == "--no-maps": maps = false
	for s: int in seeds:
		var began := Time.get_ticks_msec()
		var plan := LayerSprawl.make(s)
		var ms := Time.get_ticks_msec()-began
		print("=== seed %d: planned in %d ms (attempt %d) %s" % [s,ms,int(plan.get("attempt",-1)),str(plan.problems)])
		if not (plan.problems as Array).is_empty(): continue
		print(LayerPlan.describe(plan))
		print(LayerSprawl.card(plan))
		var nx: Dictionary = plan.next
		var lod := NextRegionLod.build(nx)
		var st: Dictionary = lod.get_meta("stats")
		print("next region: layer %d, landmark %s at %s, %.0f m from the spawn's eye (nearest reach %.0f m), %.0f m over the gate; sight %s; LOD %d triangles, %d vertices, %d surface, built in %.1f ms" % [
			int(nx.seed),nx.landmark_id,(nx.landmark as Vector3).round(),float(nx.far),float(nx.near),float(nx.rise),"clear" if nx.sight_ok else "BLOCKED",
			int(st.triangles),int(st.vertices),int(st.surfaces),float(st.ms)])
		lod.free()
		var r: Dictionary = plan.roost
		var high := -INF
		for isle: Dictionary in plan.isles: high = maxf(high,LayerPlan._span(isle).y)
		print("roost: middle %s, turf %.0f m (%.0f over the highest isle), gap %.0f m, %.0f deg off the spawn's facing, in sight from %d of %d neighbourhoods, laid in %.0f ms; in the next region's silhouette: %s" % [
			(r.at as Vector3).round(),(r.at as Vector3).y,(r.at as Vector3).y-high,float(r.gap),float(r.view),int(r.seen[0]),int(r.seen[1]),float(r.get("ms",0.0)),
			"yes" if nx.has("roost") else "no"])
		if maps: print(LayerSprawl.overview(plan))
	quit()
