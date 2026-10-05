extends SceneTree
## The sky world's regions as laid out (scripts/sky_world.gd), seed by seed:
## how many tries the ridges took, how long the layout took, each region's
## room for islands (km^2) and its islands as the plan finds them, its
## cumulus. Headless, nothing drawn:
##   Godot --headless --path . -s res://tools/probe_sky_regions.gd -- --seeds=7,1,99
const SkyWorld = preload("res://scripts/sky_world.gd")

func _initialize() -> void:
	var seeds := [7,1,99,12345,31337,424242,5,2024]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = Array(a.trim_prefix("--seeds=").split(",")).map(func(s: String) -> int: return int(s))
	var worst := 0.0
	for s: int in seeds:
		SkyWorld.seed = s
		var began := Time.get_ticks_usec()
		var l := SkyWorld.layout()
		var ms := (Time.get_ticks_usec()-began)/1000.0
		worst = maxf(worst,ms)
		var areas: Array = l.regions.map(func(g: Dictionary) -> String: return ("home " if g.home else "")+str(g.area))
		var ridges: int = l.ranges.filter(func(r: Dictionary) -> bool: return r.kind == "ridge").size()
		print("seed %d: try %d, kept %s, %.0f ms; %d ridge pieces; room %s km^2; islands %s; cumulus %d" % [s,int(l.get("tries",0)),str(l.kept_rules),ms,ridges,str(areas),str(l.get("islands",[])),l.towers.size()])
	print("worst layout %.0f ms" % worst)
	quit(0)
