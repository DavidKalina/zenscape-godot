extends RefCounted
## A run of the climb (docs/design/roguelike/stakes-experiment.md,
## game-v1-climb-up.md): the seed it began from, how many layers it has
## gone through (layer 1 is the first), how high it
## has climbed (metres above the run's start spot), the runes carried, how
## long it has lasted; and, across runs, the deepest layer and the highest
## climb ever reached, kept in a small file (`record_path`).
##
## The player sees the height; the layer count stays for the gate and the
## record. Through the gate the run goes on a layer UP (`ascend`): the next
## layer stands above this one, and its start counts as its true height
## over this layer's start (the rise the run loop measures through the
## next region's placing), so the record is the run's true height; the
## runes are kept. Into the void it ends (`die`), the runes lost with it.
## (`depth` / `deepest` are the layer count's old names, kept for the record
## file: not shown.)

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
## Hearts (docs/design/roguelike/game-v1-hearts.md): HEARTS a wanderer at a
## run's start, none given back through the gate. Kept per wanderer (keyed
## by his motor, so a second one later has his own): `hearts_of`, `hurt`,
## the seconds he is safe from another hit after one (`safe_for`), and
## what last hurt him (`cause_of`).
const HEARTS := 4
## Seconds safe after a hit: past the motor's RESTUN_GAP (1.2 s, one
## source's own second stun) so the bump that stunned can't take another
## heart as he gets up, short enough that a second blow soon after counts.
const SAFE := 1.6
var hearts := {}
var _safe := {}
var _cause := {}
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
	hearts.clear()
	_safe.clear()
	_cause.clear()
	runs += 1
	_reach()

## Through the gate: a layer on, the runes kept, the next start `rise` m
## over this layer's start (its true height: the gate's climb and the next
## layer's rise over the gate), stood on, so it counts toward the best.
func ascend(rise: float) -> void:
	depth += 1
	banked += rise
	height = banked
	footing = banked
	best = maxf(best,footing)
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
	for w: Variant in _safe.keys(): _safe[w] = maxf(0.0,float(_safe[w])-delta)

func hearts_of(wanderer: Object) -> int:
	return int(hearts.get(wanderer,HEARTS))

func safe_for(wanderer: Object) -> float:
	return float(_safe.get(wanderer,0.0))

func cause_of(wanderer: Object) -> String:
	return String(_cause.get(wanderer,""))

## `wanderer` hurt `amount` by `cause`: the hearts it took (0 while he is
## safe from a hit; a fall's always counts, `always`), then he is safe for
## SAFE s.
func hurt(wanderer: Object, amount: int, cause: String, always := false) -> int:
	if amount <= 0 or hearts_of(wanderer) <= 0: return 0
	if safe_for(wanderer) > 0.0 and not always: return 0
	var took := mini(amount,hearts_of(wanderer))
	hearts[wanderer] = hearts_of(wanderer)-took
	_safe[wanderer] = SAFE
	_cause[wanderer] = cause
	return took

## The run ended (in the void, or out of hearts): what it came to ({depth, runes, time,
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
