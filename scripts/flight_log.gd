extends RefCounted
## Where the flight study's runs are kept (scripts/flight_run.gd `finish`):
## one JSON file per run under DIR, named by when, which station and who
## flew it, so runs pile up across sessions and tools/flight_report.py can
## read them all. BANDS (bands.json in the same folder) holds each station's
## latest bot band from tools/flight_bench.gd, by the station's hash, for
## the study's end-of-run report.

const DIR := "user://flight_runs"
const BANDS := "bands.json"

## Saves `run` under `dir`; returns its path (user://...). The real path is
## printed, so a run can be found from the console.
static func save(run: Dictionary, dir := DIR) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var stamp := str(run.get("started","")).replace(":","").replace("-","").replace("Z","")
	var who := str(run.get("pilot","run")).replace(":","-")
	var path := "%s/%s_%s_%s_%04x.json" % [dir,stamp,str(run.get("station","station")),who,randi()%0x10000]
	write(path,run)
	print("flight run saved: %s" % ProjectSettings.globalize_path(path))
	return path

## Writes `run` to `path` (again, say with a rating added).
static func write(path: String, run: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		push_warning("flight run not saved: %s" % path)
		return
	file.store_string(JSON.stringify(run))
	file.close()

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

## Every station's latest band: {id: {"hash", "band", "clears", ...}}.
static func bands(dir := DIR) -> Dictionary:
	return read(dir+"/"+BANDS)

static func save_bands(found: Dictionary, dir := DIR) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var all := bands(dir)
	all.merge(found,true)
	var file := FileAccess.open(dir+"/"+BANDS,FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(all,"\t"))
	file.close()
