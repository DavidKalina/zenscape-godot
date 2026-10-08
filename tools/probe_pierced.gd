extends SceneTree
## Probe: plans the pierced isle (scripts/pierced_isle.gd) for a run of
## seeds and prints each one's holes, routes, problems and time.
##   godot --headless --path . --script tools/probe_pierced.gd -- [--seeds=1-12]
const PiercedIsle = preload("res://scripts/pierced_isle.gd")

func _initialize() -> void:
	var lo := 1
	var hi := 8
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			var parts := a.trim_prefix("--seeds=").split("-")
			lo = int(parts[0])
			hi = int(parts[1]) if parts.size() > 1 else lo
	var bad := 0
	for s in range(lo,hi+1):
		var t := Time.get_ticks_usec()
		var plan: RefCounted = PiercedIsle.make(s)
		var ms := (Time.get_ticks_usec()-t)/1000.0
		var names: Array = plan.holes.map(func(h: Dictionary) -> String: return "%s(%.0f)" % [h.name,float(h.clear)*2.0])
		print("seed %d  R %.0f  base %.1f tip %.1f inner %.0f  %.0f ms  holes %s  routes %s" % [s,plan.radius,plan.base,plan.tip_y,plan.inner_max,ms," ".join(names)," ".join(plan.routes.map(func(r: Dictionary) -> String: return r.name))])
		for p: String in plan.problems: print("   ! ",p)
		if not plan.problems.is_empty(): bad += 1
	print("%d of %d with problems" % [bad,hi-lo+1])
	quit()
