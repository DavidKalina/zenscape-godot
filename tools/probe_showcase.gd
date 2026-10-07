extends SceneTree
## Headless probe of the showcase cluster's members (scripts/sky_showcase.gd):
## each member's outline as a map a metre a character (# land, ~ water,
## T tree, w wheat, C cabin, L lamp), for laying things out by hand.
##   godot --headless --path . --script tools/probe_showcase.gd -- [--only=lead]
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyShowcase = preload("res://scripts/sky_showcase.gd")
const TREES := ["tree","redwood","juniper","broadleaf","birch","willow","layered_tree"]

func _initialize() -> void:
	var only := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.trim_prefix("--only=")
	for m: Dictionary in SkyShowcase.members():
		if only != "" and m.name != only: continue
		var began := Time.get_ticks_usec()
		var shape: RefCounted = SkyIslet.author(int(m.seed),m.spec)
		print("== %s (%s, r %.1f, reach %.1f, ground %.2f..%.2f, rim %.2f, %.0f ms)" % [m.name,shape.kind,shape.radius,shape.reach,_low(shape),_high(shape),SkyIslet.RIM_HEIGHT,(Time.get_ticks_usec()-began)/1000.0])
		var marks := {}
		for o: Dictionary in shape.objects:
			var key := Vector2i(roundi(o.x),roundi(o.z))
			var c := "T" if o.asset in TREES else ("w" if o.asset == "wheat" else ("C" if o.asset == "cabin" else ("L" if o.asset == "stone_lamp" else "")))
			if c != "" and (not marks.has(key) or c in ["C","L"]): marks[key] = c
		var r := ceili(shape.reach)
		for z in range(-r,r+1):
			var line := "%4d " % z
			for x in range(-r,r+1):
				var p := Vector2(x,z)
				var ch := " "
				if shape.on_land(p): ch = "~" if shape.wet(p) else "#"
				if marks.has(Vector2i(x,z)): ch = marks[Vector2i(x,z)] if ch != " " else "!"
				if x == 0 and z == 0: ch = "+"
				line += ch
			print(line)
	quit(0)

func _low(shape: RefCounted) -> float:
	var v := INF
	for i in range(shape.points.size()):
		if shape.shore_distance[i] >= 0.0: v = minf(v,shape.heights[i])
	return v

func _high(shape: RefCounted) -> float:
	var v := -INF
	for i in range(shape.points.size()):
		if shape.shore_distance[i] >= 0.0: v = maxf(v,shape.heights[i])
	return v
