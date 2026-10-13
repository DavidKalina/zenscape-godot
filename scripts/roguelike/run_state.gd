extends RefCounted
## A run of the climb (docs/design/roguelike/stakes-experiment.md): the seed
## it began from, how deep it has gone (layer 1 is the first), how high it
## has climbed (metres above the run's start spot), the runes carried, how
## long it has lasted; and, across runs, the deepest layer and the highest
## climb ever reached, kept in a small file (`record_path`).
##
## The player sees the height; the layer count stays for the gate and the
## record. Through the gate the run goes on a layer down (`descend`), the
## runes and the height climbed kept (the next layer's start counts as the
## height he reached the gate at); into the void it ends (`die`), the runes
## lost with it.

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
## Metres above the run's start: now, where he last stood (on the ground),
## the most stood at this run, and what this layer's start counts as.
var height := 0.0
var footing := 0.0
var best := 0.0
var banked := 0.0
## Across runs: the deepest layer reached, the highest climb (m), the runs
## begun and ended.
var deepest := 0
var highest := 0.0
var runs := 0
var deaths := 0

func _init() -> void:
	load_record()

## A new run from `seed_value`, at layer 1 with nothing carried.
func begin(seed_value: int) -> void:
	run_seed = seed_value
	_before = deepest
	_before_high = highest
	depth = 1
	runes = 0
	time = 0.0
	height = 0.0
	footing = 0.0
	best = 0.0
	banked = 0.0
	runs += 1
	_reach()

## Through the gate: a layer deeper, the runes kept, the next start at the
## height he last stood at (the gate's).
func descend() -> void:
	depth += 1
	banked = footing
	height = footing
	_reach()

## Where he is: `above_start` metres above this layer's start, on the
## ground or not (only a footing counts toward the best).
func at(above_start: float, grounded: bool) -> void:
	height = banked+above_start
	if grounded:
		footing = height
		best = maxf(best,footing)

func take_rune() -> void:
	runes += 1

func tick(delta: float) -> void:
	time += delta

## The run ended in the void: what it came to ({depth, runes, time,
## deepest, record, height, best, highest, high_record}: `height` where he
## last stood, record / high_record true when this run set the deepest /
## the highest over an earlier one), the record saved.
func die() -> Dictionary:
	deaths += 1
	highest = maxf(highest,best)
	var out := {"depth":depth,"runes":runes,"time":time,"deepest":deepest,"record":depth > _before and _before > 0,
		"height":footing,"best":best,"highest":highest,"high_record":best > _before_high and _before_high > 0.0}
	save_record()
	return out

## The deepest and the highest before this run began.
var _before := 0
var _before_high := 0.0

func _reach() -> void:
	if depth > deepest: deepest = depth
	highest = maxf(highest,best)
	save_record()

## "6:41" for 401 s.
static func clock(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s/60,s%60]

## The record file; one from before heights (no "highest") reads as 0 m
## and gains the key at its next save.
func load_record() -> void:
	if not FileAccess.file_exists(record_path): return
	var f := FileAccess.open(record_path,FileAccess.READ)
	if f == null: return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		deepest = int((data as Dictionary).get("deepest",0))
		highest = float((data as Dictionary).get("highest",0.0))
		runs = int((data as Dictionary).get("runs",0))
		deaths = int((data as Dictionary).get("deaths",0))

func save_record() -> void:
	var f := FileAccess.open(record_path,FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"deepest":deepest,"highest":snappedf(highest,0.1),"runs":runs,"deaths":deaths}))
