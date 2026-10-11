extends SceneTree
## The landing study's bench: the CPU pilots (scripts/landing_bot.gd) fly
## every station (scripts/landing_course.gd) headless under the manual
## landing's rules (scripts/manual_landing.gd), `--runs` times each with
## their own noise, and a table of each skill's numbers per station is
## printed (markdown): stopped share, time to stop, the good touch's speed
## and sink, bounces, go-arounds, rollout and rolls off the edge, as means
## over the runs. docs/design/manual-landing.md keeps the latest.
##
##   godot --headless --path . -s tools/landing_bench.gd -- [--runs 10] [--station id[,id]] [--skills sloppy,decent]
##   options: --save (each run's JSON to user://landing_runs, as the study's)

const Course = preload("res://scripts/landing_course.gd")
const Run = preload("res://scripts/landing_run.gd")
const Bot = preload("res://scripts/landing_bot.gd")
const Log = preload("res://scripts/flight_log.gd")
const DT := 1.0/60.0
const DIR := "user://landing_runs"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := 10
	var ids: Array = Course.STATIONS.map(func(s: Dictionary) -> String: return s.id)
	var skills: Array = Bot.SKILL_NAMES.duplicate()
	var save := false
	for i in range(args.size()):
		match args[i]:
			"--runs": runs = int(args[i+1])
			"--station": ids = Array(args[i+1].split(","))
			"--skills": skills = Array(args[i+1].split(","))
			"--save": save = true
	print("| station | skill | stopped | time to stop s | touch m/s | sink m/s | bounces | go-arounds | rollout m | off edge |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for id: String in ids:
		var s := Course.station(id)
		if s.is_empty(): continue
		for skill: String in skills:
			var rows: Array[Dictionary] = []
			for k in range(runs if skill != "perfect" else 1):
				var run := fly(s,skill,k)
				rows.append(run.metrics())
				if save: Log.save(run.finish(),DIR)
			print(row(id,skill,rows))
	quit(0)

## One run of `s` by `skill`, seeded `k`, to its end.
static func fly(s: Dictionary, skill: String, k: int) -> RefCounted:
	var params := Bot.params(skill)
	var run := Run.new(s,"bot:"+skill,params)
	var bot := Bot.new(params,1000+k*7919)
	while not run.done:
		run.tick(DT,bot.input(run,DT))
	return run

static func row(id: String, skill: String, rows: Array[Dictionary]) -> String:
	var stopped := rows.filter(func(m: Dictionary) -> bool: return m.stopped)
	return "| %s | %s | %d/%d | %s | %s | %s | %.1f | %.1f | %s | %.1f |" % [id,skill,stopped.size(),rows.size(),
		mean(stopped,"time_to_stop","%.1f"),mean(stopped,"touch_speed","%.1f"),mean(stopped,"touch_sink","%.2f"),
		avg(rows,"bounces"),avg(rows,"go_arounds"),mean(stopped,"rollout","%.1f"),avg(rows,"off_edge")]

static func mean(rows: Array, key: String, fmt: String) -> String:
	var values := rows.filter(func(m: Dictionary) -> bool: return m.get(key) != null).map(func(m: Dictionary) -> float: return float(m[key]))
	if values.is_empty(): return "-"
	var total := 0.0
	for v: float in values: total += v
	return fmt % (total/values.size())

static func avg(rows: Array, key: String) -> float:
	if rows.is_empty(): return 0.0
	var total := 0.0
	for m: Dictionary in rows: total += float(m.get(key,0))
	return total/rows.size()
