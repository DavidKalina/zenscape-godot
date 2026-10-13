extends SceneTree
## The ring shape's layers as text maps (scripts/roguelike/layer_ring.gd;
## LayerSprawl `overview`, the serpent's loop drawn as `~`), headless, no
## scene built: the plan, its rides and cannons, each ring isle's room for
## the dragon's grip, the next region (a sprawl, alternating) and the
## roost.
##   godot --headless --path . --script tools/layer_ring_map.gd -- --seeds=1,2,3 [--no-maps] [--knob=...]
const LayerRing = preload("res://scripts/roguelike/layer_ring.gd")
const LayerSprawl = preload("res://scripts/roguelike/layer_sprawl.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const NextRegionLod = preload("res://scripts/roguelike/next_region_lod.gd")

func _initialize() -> void:
	var seeds: Array = [1,2,3]
	var maps := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): seeds = Array(arg.trim_prefix("--seeds=").split(",")).map(func(s: String) -> int: return int(s))
		if arg == "--no-maps": maps = false
		if arg == "--trace": LayerPlan.trace = true
	var knobs := LayerPlan.knobs_from(OS.get_cmdline_user_args())
	for s: int in seeds:
		var began := Time.get_ticks_msec()
		var plan := LayerRing.core(s,knobs)
		var ms := Time.get_ticks_msec()-began
		print("=== seed %d: ring planned in %d ms (attempt %d) %s" % [s,ms,int(plan.get("attempt",-1)),str(plan.problems)])
		if not (plan.problems as Array).is_empty(): continue
		began = Time.get_ticks_msec()
		LayerSprawl.attach_next(plan)
		print("next region laid in %d ms" % (Time.get_ticks_msec()-began))
		print(LayerPlan.describe(plan))
		print(LayerRing.card(plan))
		for i: int in plan.ring.order:
			var isle: Dictionary = plan.isles[i]
			var c := LayerPlan._rect(isle).get_center()
			print("ring isle %d %s: %.0f m out, foot %.0f m, top %.0f m; grip %s" % [i,isle.id,c.distance_to(Vector2(LayerPlan.MIDDLE.x,LayerPlan.MIDDLE.z)),
				LayerRing._foot(isle)+(isle.offset as Vector3).y,LayerPlan._span(isle).y,str(isle.grip)])
		if plan.has("next"):
			var nx: Dictionary = plan.next
			var lod := NextRegionLod.build(nx)
			var st: Dictionary = lod.get_meta("stats")
			print("next region: layer %d, landmark %s, %.0f m from the spawn's eye (nearest reach %.0f m), %.0f m over the gate; sight %s; LOD %d triangles, built in %.1f ms" % [
				int(nx.seed),nx.landmark_id,float(nx.far),float(nx.near),float(nx.rise),"clear" if nx.sight_ok else "BLOCKED",int(st.triangles),float(st.ms)])
			lod.free()
		var r: Dictionary = plan.roost
		print("roost: middle %s, gap %.0f m, %.0f deg off the spawn's facing, seen from %d of %d" % [(r.at as Vector3).round(),float(r.gap),float(r.view),int(r.seen[0]),int(r.seen[1])])
		if maps: print(LayerSprawl.overview(LayerRing.drawn(plan)))
	LayerSprawl.forget()
	LayerRing.forget()
	quit()
