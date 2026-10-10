extends SceneTree
## Prints the hall eruption's pieces and their timing (scripts/
## hall_eruption_plan.gd), for tuning; headless:
##   godot --headless --path . -s tools/hall_eruption_list.gd [-- --erupt-speed=1.2 --erupt-gaps=0.8 --erupt-path=straight --no-keels --no-stones]
const EPlan = preload("res://scripts/hall_eruption_plan.gd")
const Eruption = preload("res://scripts/hall_eruption.gd")

func _initialize() -> void:
	var opts := Eruption.options(preload("res://scripts/launch_args.gd").user_args())
	var began := Time.get_ticks_usec()
	var made := EPlan.make(opts)
	var usec := Time.get_ticks_usec()-began
	var counts := {}
	for p: Dictionary in made.pieces:
		counts[p.category] = int(counts.get(p.category,0))+1
		print("%-18s %-6s start %6.2f  arrives %6.2f  settled %6.2f  out %5.1f  lift %4.1f  solids %3d%s" % [p.id,p.category,p.start,EPlan.arrives(p),EPlan.settles(p),p.out,p.lift,p.solids.size(),"  +%d own" % p.extra.size() if not p.extra.is_empty() else ""])
	print("pieces %d %s  hall solids %d  length %.2f s  planned in %.1f ms" % [made.pieces.size(),counts,made.solids.size(),made.length,usec/1000.0])
	quit(0)
