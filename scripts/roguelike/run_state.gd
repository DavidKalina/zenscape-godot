extends RefCounted
## A run of the climb (docs/design/roguelike/stakes-experiment.md): the seed
## it began from, how deep it has gone (layer 1 is the first), the runes
## carried, how long it has lasted; and, across runs, the deepest layer
## ever reached, kept in a small file (`record_path`).
##
## Through the gate the run goes on a layer down (`descend`), the runes
## kept; into the void it ends (`die`), the runes lost with it.

## Where the record is kept. A test points it elsewhere.
static var record_path := "user://run_record.json"

## The seed the run began from (its layer 1's), -1 before any.
var run_seed := -1
## The layer the run stands on (1 the first).
var depth := 0
## Runes carried: taken on any layer of the run, kept through the gate.
var runes := 0
## Seconds played in the run.
var time := 0.0
## Across runs: the deepest layer reached, the runs begun and ended.
var deepest := 0
var runs := 0
var deaths := 0

func _init() -> void:
	load_record()

## A new run from `seed_value`, at layer 1 with nothing carried.
func begin(seed_value: int) -> void:
	run_seed = seed_value
	_before = deepest
	depth = 1
	runes = 0
	time = 0.0
	runs += 1
	_reach()

## Through the gate: a layer deeper, the runes kept.
func descend() -> void:
	depth += 1
	_reach()

func take_rune() -> void:
	runes += 1

func tick(delta: float) -> void:
	time += delta

## The run ended in the void: what it came to ({depth, runes, time,
## deepest, record}: record true when this run set the deepest), the
## record saved.
func die() -> Dictionary:
	deaths += 1
	var out := {"depth":depth,"runes":runes,"time":time,"deepest":deepest,"record":depth > _before and _before > 0}
	save_record()
	return out

## The deepest before this run began.
var _before := 0

func _reach() -> void:
	if depth > deepest: deepest = depth
	save_record()

## "6:41" for 401 s.
static func clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s/60,s%60]

func load_record() -> void:
	if not FileAccess.file_exists(record_path): return
	var f := FileAccess.open(record_path,FileAccess.READ)
	if f == null: return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		deepest = int((data as Dictionary).get("deepest",0))
		runs = int((data as Dictionary).get("runs",0))
		deaths = int((data as Dictionary).get("deaths",0))

func save_record() -> void:
	var f := FileAccess.open(record_path,FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"deepest":deepest,"runs":runs,"deaths":deaths}))
