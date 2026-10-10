extends SceneTree
## Tuning the hard crash (scripts/flight_crash.gd HARD): the bots fly
## stations with crashing on but out of reach (stone's threshold 1000 m/s,
## so every contact bumps as ever) and every contact's speed into the face
## is gathered (the run's bump events, one per contact). Prints, per skill,
## how many contacts would crash at each threshold, and the spread of
## contact angles (asin of into / speed): a glancing scrape is a few
## degrees, a nose-on hit near 90.
##   godot --headless --path . -s tools/flight_crash_tune.gd -- [--pack moments] [--runs 10] [--station id,id]

const Course = preload("res://scripts/flight_course.gd")
const Bot = preload("res://scripts/flight_bot.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const Bench = preload("res://tools/flight_bench.gd")

const STEPS := [4.0,5.0,6.0,7.0,8.0,9.0,10.0,11.0,12.0]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var pack := "moments"
	var runs := 10
	var only := ""
	for i in range(args.size()-1):
		if args[i] == "--pack": pack = args[i+1]
		if args[i] == "--runs": runs = int(args[i+1])
		if args[i] == "--station": only = args[i+1]
	var stations: Array = Course.pack(pack) if only == "" else Array(only.split(",")).map(func(id: String) -> Dictionary: return Course.station(id))
	var stage := Node3D.new()
	root.add_child(stage)
	for s: Dictionary in stations: Course.build(Course.base_of(s),stage)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	var crash := {"mode":"hard","restart":"checkpoint","hard":1000.0}
	var total := {}
	for s: Dictionary in stations:
		print("%s" % s.id)
		for name: String in Metrics.SKILLS:
			var into := []
			var angles := []
			var n: int = runs if name != "perfect" else Bot.PERFECT_LOOKS.size()
			for k in range(n):
				var params := Bot.skill(name)
				if name == "perfect": params.look = Bot.PERFECT_LOOKS[k]
				var r := Bench.fly(s,name,params,hash([s.id,name,k]),space,crash)
				for e: Dictionary in r.events:
					if str(e.kind) != "bump": continue
					into.append(float(e.into))
					angles.append(rad_to_deg(asin(clampf(float(e.into)/maxf(float(e.speed),0.01),0.0,1.0))))
			print("  "+_line(name,into,angles,n))
			if not total.has(name): total[name] = {"into":[],"angles":[],"n":0}
			total[name].into.append_array(into)
			total[name].angles.append_array(angles)
			total[name].n += n
	print("all")
	for name: String in total: print("  "+_line(name,total[name].into,total[name].angles,int(total[name].n)))
	quit(0)

static func _line(name: String, into: Array, angles: Array, n: int) -> String:
	var over := PackedStringArray()
	for at: float in STEPS: over.append("%.2f" % (into.filter(func(v: float) -> bool: return v >= at).size()/float(maxi(n,1))))
	var bins := [0,0,0,0,0,0]
	for a: float in angles: bins[mini(int(a/15.0),5)] += 1
	return "%-8s contacts %.1f/run · per run, would crash at %s m/s: %s · angles 0-15/-30/-45/-60/-75/-90: %s" % [name,into.size()/float(maxi(n,1)),
		"/".join(STEPS.map(func(v: float) -> String: return "%d" % v)),"/".join(over),"/".join(bins.map(func(v: int) -> String: return str(v)))]
