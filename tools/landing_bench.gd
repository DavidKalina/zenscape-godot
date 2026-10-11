extends SceneTree
## The landing study's bench: the CPU pilots (scripts/landing_bot.gd) fly
## every station (scripts/landing_course.gd) headless under the manual
## landing's rules (scripts/manual_landing.gd), `--runs` times each with
## their own noise, on each approach (Course APPROACHES: "normal" flown
## slow, "hot" flown in at cruise, "boost" flown in at Boost's speed), and
## a table of each skill's numbers per station is printed (markdown):
## stopped share and on the first approach, time to stop, the touch's
## speed (the entry speed it stopped from) and the fastest it saved first
## time, greasers, metres slid, peak slip, the stop's margin to the edge,
## hops, go-arounds and rolls off the edge, as means over the runs.
## docs/design/manual-landing.md keeps the latest.
##
##   godot --headless --path . -s tools/landing_bench.gd -- [--runs 10] [--station id[,id]] [--skills sloppy,decent] [--approach normal,hot,boost]
##   options: --save (each run's JSON to user://landing_runs, as the study's)

const Course = preload("res://scripts/landing_course.gd")
const Run = preload("res://scripts/landing_run.gd")
const Bot = preload("res://scripts/landing_bot.gd")
const Log = preload("res://scripts/flight_log.gd")
const DT := 1.0/60.0
const DIR := "user://landing_runs"
## The pace a bot flies each approach at.
const PACE := {"normal":"slow","hot":"cruise","boost":"boost"}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := 10
	var ids: Array = Course.STATIONS.map(func(s: Dictionary) -> String: return s.id)
	var skills: Array = Bot.SKILL_NAMES.duplicate()
	var approaches: Array = Course.APPROACH_NAMES.duplicate()
	var save := false
	for i in range(args.size()):
		match args[i]:
			"--runs": runs = int(args[i+1])
			"--station": ids = Array(args[i+1].split(","))
			"--skills": skills = Array(args[i+1].split(","))
			"--approach": approaches = Array(args[i+1].split(","))
			"--save": save = true
	print("| station | approach | skill | stopped | first try | time s | touch m/s | saved m/s | greasers | slid m | peak slip ° | margin m | hops | go-arounds | off edge |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for id: String in ids:
		var s := Course.station(id)
		if s.is_empty(): continue
		for approach: String in approaches:
			for skill: String in skills:
				var rows: Array[Dictionary] = []
				for k in range(runs if skill != "perfect" else 1):
					var run := fly(s,skill,k,approach)
					rows.append(run.metrics())
					if save: Log.save(run.finish(),DIR)
				print(row(id,approach,skill,rows))
	quit(0)

## One run of `s` by `skill` on `approach`, seeded `k`, to its end.
static func fly(s: Dictionary, skill: String, k: int, approach := "normal") -> RefCounted:
	var params := Bot.params(skill)
	var run := Run.new(s,"bot:"+skill,params,approach)
	var bot := Bot.new(params,1000+k*7919,PACE.get(approach,"slow"))
	while not run.done:
		run.tick(DT,bot.input(run,DT))
	return run

static func row(id: String, approach: String, skill: String, rows: Array[Dictionary]) -> String:
	var stopped := rows.filter(func(m: Dictionary) -> bool: return m.stopped)
	var first := rows.filter(func(m: Dictionary) -> bool: return m.first_try)
	var saved := "-"
	if not first.is_empty(): saved = "%.1f" % first.map(func(m: Dictionary) -> float: return float(m.touch_speed)).max()
	var greasers := stopped.filter(func(m: Dictionary) -> bool: return m.greaser).size()
	return "| %s | %s | %s | %d/%d | %d/%d | %s | %s | %s | %d/%d | %s | %s | %s | %.1f | %.1f | %.1f |" % [id,approach,skill,
		stopped.size(),rows.size(),first.size(),rows.size(),mean(stopped,"time_to_stop","%.1f"),mean(stopped,"touch_speed","%.1f"),saved,
		greasers,stopped.size(),mean(stopped,"slide_distance","%.1f"),mean(stopped,"peak_slip","%.0f",rad_to_deg(1.0)),mean(stopped,"stop_margin","%.1f"),
		avg(rows,"bounces"),avg(rows,"go_arounds"),avg(rows,"off_edge")]

static func mean(rows: Array, key: String, fmt: String, scale := 1.0) -> String:
	var values := rows.filter(func(m: Dictionary) -> bool: return m.get(key) != null).map(func(m: Dictionary) -> float: return float(m[key]))
	if values.is_empty(): return "-"
	var total := 0.0
	for v: float in values: total += v
	return fmt % (total/values.size()*scale)

static func avg(rows: Array, key: String) -> float:
	if rows.is_empty(): return 0.0
	var total := 0.0
	for m: Dictionary in rows: total += float(m.get(key,0))
	return total/rows.size()
