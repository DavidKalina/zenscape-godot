extends RefCounted
## A run in the character study (studies/character_study.gd), recorded:
## the motor's whole state at the start, then every tick's delta, inputs
## (the stick in the motor's frame, jump, crouch, twirl), the camera's yaw
## and pitch, and where he went (feet, speed, state). Saved, it is the
## platforming the user wants possible: it replays exactly through the
## motor (the study's F6, tests/test_character_recordings.gd), and its
## beats (each jump, landing, twirl, grab, slide) and summary read as what
## was done where.
##
## One JSON file a run under DIR, in the repo so runs persist and can be
## read back: format, label (what it shows), pack (the island pack it was
## made in, studies/island_packs/; "" the room), station (the nearest
## station's key), started (UTC), feel (the tunables then), motor (its state at the
## start, var_to_str), ticks (columns), beats, summary.

const DIR := "res://studies/character_runs"
const FORMAT := 1
## Tick columns, each a list as long as the run.
const COLUMNS := ["dt","wx","wz","jump","crouch","twirl","yaw","polar","x","y","z","speed","state"]
## The motor's events kept as beats, and the word for each.
const BEATS := ["jumped","landed","twirl","grabbed","climbed","let_go","slide","wall","wallrun","swam","stood","hopped"]

var label := ""
var pack := ""
var station := 0
var started := ""
var feel := {}
var motor_state := ""
var ticks := {}
var beats: Array = []
var _t := 0.0

## Begun with the motor as it stands now.
func _init(motor: RefCounted = null, at_station := 0, tunables := {}, in_pack := "") -> void:
	for c: String in COLUMNS: ticks[c] = []
	station = at_station
	pack = in_pack
	feel = tunables
	started = Time.get_datetime_string_from_system(true)+"Z"
	if motor != null: motor_state = var_to_str(snapshot(motor))

## One tick: what was asked, the camera, and where the step left him.
func add(dt: float, want: Vector2, jump: bool, crouch: bool, twirl: bool, yaw: float, polar: float, motor: RefCounted, state: String, events: Dictionary) -> void:
	_t += dt
	var feet: Vector3 = motor.feet
	var row := [dt,want.x,want.y,int(jump),int(crouch),int(twirl),yaw,polar,feet.x,feet.y,feet.z,float(motor.speed()),state]
	for i in range(COLUMNS.size()): ticks[COLUMNS[i]].append(row[i])
	for key: String in BEATS:
		if not events.has(key): continue
		var what := key
		if key == "jumped":
			what = "long" if events.has("long") else ("wallrun_jump" if events.has("wallrun_jump") else ("wall_jump" if events.has("wall_jump") else ("side_flip" if events.has("side_flip") else ("slide_jump" if events.has("slide_jump") else ("pump" if int(events.jumped) > 1 else "jump")))))
		elif key == "slide" or key == "wall" or key == "wallrun": what = key+(" on" if events[key] else " off")
		elif key == "grabbed": what = "grabbed "+str(events[key])
		beats.append({"t":snappedf(_t,0.001),"what":what,"at":[snappedf(feet.x,0.01),snappedf(feet.y,0.01),snappedf(feet.z,0.01)],"speed":snappedf(float(motor.speed()),0.01)})

func size() -> int:
	return ticks.dt.size()

func duration() -> float:
	return _t

## The run as saved.
func to_dict() -> Dictionary:
	return {"format":FORMAT,"label":label,"pack":pack,"station":station,"started":started,"feel":feel,"motor":motor_state,
		"ticks":ticks,"beats":beats,"summary":summary()}

## Start and end, how far along and up, the highest, the fastest, and the
## moves used, counted.
func summary() -> Dictionary:
	if size() == 0: return {}
	var xs: Array = ticks.x
	var ys: Array = ticks.y
	var zs: Array = ticks.z
	var path := 0.0
	var top := float(ys[0])
	var low := float(ys[0])
	for i in range(1,size()):
		path += Vector3(float(xs[i])-float(xs[i-1]),float(ys[i])-float(ys[i-1]),float(zs[i])-float(zs[i-1])).length()
		top = maxf(top,float(ys[i]))
		low = minf(low,float(ys[i]))
	var start := Vector3(float(xs[0]),float(ys[0]),float(zs[0]))
	var end := Vector3(float(xs[-1]),float(ys[-1]),float(zs[-1]))
	var moves := {}
	for b: Dictionary in beats: moves[b.what] = int(moves.get(b.what,0))+1
	var fastest := 0.0
	for s: float in ticks.speed: fastest = maxf(fastest,s)
	return {"seconds":snappedf(_t,0.01),"start":_v(start),"end":_v(end),"across":snappedf(Vector2(end.x-start.x,end.z-start.z).length(),0.01),
		"rise":snappedf(end.y-start.y,0.01),"highest":snappedf(top-start.y,0.01),"lowest":snappedf(low-start.y,0.01),
		"path":snappedf(path,0.01),"fastest":snappedf(fastest,0.01),"moves":moves}

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x,0.01),snappedf(v.y,0.01),snappedf(v.z,0.01)]

## Saved under `dir`, named by when and the label; its path (res://...).
func save(dir := DIR) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var slug := label.to_lower().strip_edges()
	var clean := ""
	for ch in slug: clean += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "-"
	while clean.contains("--"): clean = clean.replace("--","-")
	clean = clean.trim_prefix("-").trim_suffix("-").left(48)
	var stamp := started.replace(":","").replace("-","").replace("Z","").replace("T","_")
	var path := "%s/%s_%s.json" % [dir,stamp,clean if clean != "" else "run"]
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		push_warning("character run not saved: %s" % path)
		return ""
	file.store_string(JSON.stringify(to_dict(),"\t",false,true))
	file.close()
	print("character run saved: %s" % ProjectSettings.globalize_path(path))
	return path

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

## Every saved run's path under `dir`, oldest first.
static func paths(dir := DIR) -> PackedStringArray:
	var found := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null: return found
	for f in d.get_files():
		if f.ends_with(".json"): found.append(dir+"/"+f)
	found.sort()
	return found

## The motor's own state (its script vars, callables left out).
static func snapshot(motor: RefCounted) -> Dictionary:
	var out := {}
	for p: Dictionary in motor.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var v: Variant = motor.get(p.name)
		if v is Callable: continue
		out[p.name] = v.duplicate() if v is Array else v
	return out

## Puts back a state `snapshot` took (as saved: var_to_str), all but the
## vars named in `keep` (the feel: a replay runs on the feel now, so a run
## that no longer works shows it).
static func restore(motor: RefCounted, saved: String, keep: Array = []) -> void:
	var state: Variant = str_to_var(saved)
	if not state is Dictionary: return
	for key: String in state:
		if key in keep: continue
		var v: Variant = state[key]
		motor.set(key,v.duplicate() if v is Array else v)
