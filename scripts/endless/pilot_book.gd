class_name PilotBook
extends RefCounted
## The pilot's book (endless flight; docs/design/endless-flight/spec-wild-loop.md):
## what carries from one run to the next, kept as JSON at PATH
## (--pilot-file=<path> for another; --pilot=fresh starts empty and never
## writes, for drivers and checks).
##   money     earned by banked lines and challenges, spent at the shop
##   tally     counts that only grow (trees, clouds, landings, metres ...)
##   records   bests: higher wins, except the names in LOWER_WINS
##   found     ids met once (gaps, starters, shops), each with its flight
##   owned     shop items bought; worn: the item worn in each slot
## and `flight`, this flight's own (lift-off to the next lift-off), never
## kept: its tallies, its money, its lines, its challenges, the records it
## set. The landing summary reads it.
##
## The game holds one (`game.book`), steps it every frame (it writes at most
## every SAVE_EVERY s, and only when something changed) and saves it on the
## way out.

const PATH := "user://pilot.json"
const SAVE_EVERY := 5.0
## Money for a banked line: its points (already times its multiplier) at
## MONEY_PER_POINT, times the multiplier again to MULT_POW, so a line's pay
## leans on how hard it was more than on how long: a safe repeated line of
## 10k points at x2.4 pays 10, a mixed 22k at x5 pays 31 (trunk 1's balance:
## a first paint, 60, in about ten minutes of decent flying). A line with a
## move in it pays at least 1.
const MONEY_PER_POINT := 1.0/1600.0
const MULT_POW := 0.5
## Records where the least is the best, and the starts of names that are
## so (the place lines' times, place_lines.gd: `line/<place>/<name>`).
const LOWER_WINS := ["tightest_gap"]
const LOWER_WINS_PREFIX := ["line/"]

var money := 0
var tally := {}
var records := {}
var found := {}
var owned := {}
var worn := {}
var flights := 0
var flight := {}
## Where it is kept ("" never writes).
var path := PATH
var _dirty := false
var _since := 0.0

## The book for this run, from the command line.
static func open() -> PilotBook:
	var b := PilotBook.new()
	# Harness runs fly bots: their tallies stay out of the player's book.
	if OS.has_environment("ZENSCAPE_NO_BOOK"): b.path = ""
	# The launch args (a driver's `open` and the scene picker give theirs).
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--pilot=fresh": b.path = ""
		elif arg.begins_with("--pilot-file="): b.path = arg.substr(13)
	b.load_book()
	b.new_flight()
	return b

func load_book() -> void:
	if path == "" or not FileAccess.file_exists(path): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	money = int(data.get("money",0))
	tally = data.get("tally",{})
	records = data.get("records",{})
	found = data.get("found",{})
	owned = data.get("owned",{})
	worn = data.get("worn",{})
	flights = int(data.get("flights",0))

func save() -> void:
	_dirty = false
	_since = 0.0
	if path == "": return
	var data := {"money":money,"tally":tally,"records":records,"found":found,"owned":owned,"worn":worn,"flights":flights}
	var tmp := path+".tmp"
	var f := FileAccess.open(tmp,FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(data,"\t"))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),ProjectSettings.globalize_path(path))

func step(delta: float) -> void:
	_since += delta
	if _dirty and _since >= SAVE_EVERY: save()

## A new flight: called at lift-off (and at the run's start).
func new_flight() -> void:
	flights += 1
	flight = {"n":flights,"t":0.0,"tally":{},"earned":0,"lines":[],"best_line":{},"challenges":[],"records":[],"found":[]}
	_dirty = true

## `n` more of `what`, in the book and this flight.
func count(what: String, n: float = 1.0) -> void:
	tally[what] = float(tally.get(what,0.0))+n
	flight.tally[what] = float(flight.tally.get(what,0.0))+n
	_dirty = true

## `value` tried as the record `what`; true when it is a new best (and then
## noted in this flight's records).
func best(what: String, value: float) -> bool:
	if not is_finite(value): return false
	var lower := lower_wins(what)
	if records.get(what) != null:
		var was := float(records[what])
		if (lower and value >= was) or (not lower and value <= was): return false
	records[what] = value
	if not what in flight.records: flight.records.append(what)
	_dirty = true
	return true

## Whether the least `what` is the best.
static func lower_wins(what: String) -> bool:
	if what in LOWER_WINS: return true
	for pre: String in LOWER_WINS_PREFIX:
		if what.begins_with(pre): return true
	return false

## `id` met; true the first time ever.
func find(id: String) -> bool:
	if found.has(id): return false
	found[id] = flights
	flight.found.append(id)
	_dirty = true
	return true

func earn(amount: int) -> void:
	if amount <= 0: return
	money += amount
	flight.earned = int(flight.earned)+amount
	_dirty = true

## True (and spent) when there is enough.
func spend(amount: int) -> bool:
	if amount > money: return false
	money -= amount
	_dirty = true
	return true

func owns(item: String) -> bool:
	return owned.has(item)

func own(item: String) -> void:
	owned[item] = flights
	_dirty = true

func wear(slot: String, item: String) -> void:
	worn[slot] = item
	_dirty = true

func worn_in(slot: String, default: String = "") -> String:
	return String(worn.get(slot,default))

## A banked line: {points, mult, moves: Array of move names in order,
## terrain: Array of kinds of land crossed in order, t: seconds long, plus
## whatever the line keeps}. Pays `line_pay`, keeps the flight's best,
## tries the line records. Returns the money paid.
func line_banked(line: Dictionary) -> int:
	var points := float(line.get("points",0.0))
	var paid := line_pay(points,float(line.get("mult",1.0)),(line.get("moves",[]) as Array).size())
	earn(paid)
	line["money"] = paid
	flight.lines.append(line)
	if points > float(flight.best_line.get("points",0.0)): flight.best_line = line
	best("best_line",points)
	best("best_mult",float(line.get("mult",1.0)))
	best("longest_line",float(line.get("t",0.0)))
	count("lines")
	return paid

## The money for a line of `points` at `mult` with `moves` moves.
static func line_pay(points: float, mult: float, moves: int) -> int:
	var paid := int(round(points*MONEY_PER_POINT*pow(maxf(mult,1.0),MULT_POW)))
	if moves > 0: paid = maxi(paid,1)
	return paid

## A finished challenge: {id, kind, got, of, time, points, money, done:
## bool}. Pays its money.
func challenge_done(result: Dictionary) -> void:
	earn(int(result.get("money",0)))
	flight.challenges.append(result)
	count("challenges_done" if bool(result.get("done",false)) else "challenges_tried")
