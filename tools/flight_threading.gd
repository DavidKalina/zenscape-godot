extends SceneTree
## Backfills the threading numbers (FlightMetrics `threading`) for flight
## study runs saved before they existed. Reads every run JSON in the runs
## folder and never writes to one: for each run without
## metrics.threading_share whose station still has the same hash
## (FlightCourse `station_hash`), it measures threading from the run's
## recorded ticks and the station's solids, and writes them all to one side
## file, threading_backfill.json ({file name: {threading_share, openings,
## openings_per_s, threading_s}}), which tools/flight_report.py reads (and
## runs this for, when it finds runs without the numbers). A run whose
## station has changed since is listed under "stale" and left out.
##   godot --headless --path . -s tools/flight_threading.gd [-- --dir /abs/or/user://path]

const Course = preload("res://scripts/flight_course.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")
const Log = preload("res://scripts/flight_log.gd")
const SIDE := "threading_backfill.json"

func _initialize() -> void:
	var dir := Log.DIR
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--dir" and i+1 < args.size(): dir = args[i+1]
		elif args[i].begins_with("--dir="): dir = args[i].substr(6)
	var out := backfill(dir)
	print("flight threading: %d run(s) measured, %d stale, written to %s" % [(out.runs as Dictionary).size(),(out.stale as Array).size(),ProjectSettings.globalize_path(dir+"/"+SIDE)])
	quit(0)

## Measures every run in `dir` missing the numbers; writes and returns the
## side file's contents.
static func backfill(dir: String) -> Dictionary:
	var out := {"runs":{},"stale":[]}
	var solids := {}
	for name in DirAccess.get_files_at(dir):
		if not name.ends_with(".json") or name == SIDE or name == Log.BANDS or name.begins_with("bench_"): continue
		var run := Log.read(dir+"/"+name)
		if not run.has("ticks") or not run.has("station"): continue
		if (run.get("metrics",{}) as Dictionary).has("threading_share"): continue
		var s := Course.station(str(run.station))
		if s.is_empty() or Course.station_hash(s) != str(run.get("station_hash","")):
			(out.stale as Array).append(name)
			continue
		if not solids.has(s.id): solids[s.id] = Course.solids(s)
		var duration := float(run.get("result",{}).get("duration",-1.0))
		out.runs[name] = Metrics.threading(run.ticks,solids[s.id],duration)
	Log.write(dir+"/"+SIDE,out)
	return out
