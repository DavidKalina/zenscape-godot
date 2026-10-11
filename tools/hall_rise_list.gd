extends SceneTree
## Prints the hall rise's chunks and their timing (scripts/hall_rise_plan.gd),
## for tuning, with the cloud top where the study stands it; headless:
##   godot --headless --path . -s tools/hall_rise_list.gd [-- --rise=14 --rise-speed=9 --chunk-gap=1.7 --rise-from=gate --keels --stones]
const RisePlan = preload("res://scripts/hall_rise_plan.gd")
const Rise = preload("res://scripts/hall_rise.gd")
const Study = preload("res://studies/hall_rise.gd")

func _initialize() -> void:
	var args := preload("res://scripts/launch_args.gd").user_args()
	var opts := Rise.options(args)
	var clear := Study.RISE_CLEAR
	for a: String in args:
		if a.begins_with("--rise="): clear = float(a.get_slice("=",1))
	var hall_y := Study.hall_y_for(clear,opts)
	opts.sea = Study.SEA_Y+Study.SEA_TOP-hall_y
	var began := Time.get_ticks_usec()
	var made := RisePlan.make(opts)
	var usec := Time.get_ticks_usec()-began
	for c: Dictionary in made.chunks:
		var climb := float(c.pivot.y)+float(c.over)-float(c.from_y)
		var breaks := -1.0
		for k in range(2000):
			var t := k*0.01
			if RisePlan.height_at(c,t)+float(c.top) > float(made.sea):
				breaks = t
				break
		print("%-8s bays %2d-%2d  solids %3d%s  start %5.2f  breaks through %5.2f  stops %5.2f  still %5.2f  climb %5.1f m  (%4.1f m tall)" % [c.id,c.bays[0],c.bays[1],c.solids.size(),
			"  +%d own" % c.extra.size() if not c.extra.is_empty() else "",c.start,float(c.start)+breaks,RisePlan.stops(c),RisePlan.settles(c),climb,float(c.hi.y)-float(c.lo.y)])
	print("chunks %d  hall solids %d  the entry %.1f m over home, the cloud top %.1f m under it  length %.2f s  planned in %.1f ms" % [made.chunks.size(),made.solids.size(),hall_y,-float(made.sea),made.length,usec/1000.0])
	quit(0)
