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
##   opened    what the plane broke open and stays open (cracked walls' handles)
##   look      the plane's own look from the hangar (scripts/endless/plane_look.gd),
##             {} while none is set; set, it wins over the worn paint
## and `flight`, this flight's own (lift-off to the next lift-off), never
## kept: its tallies, its money, its lines, its challenges, the records it
## set. The landing summary reads it.
##
## The game holds one (`game.book`), steps it every frame (it writes at most
## every SAVE_EVERY s, and only when something changed) and saves it on the
## way out.

const PATH := "user://pilot.json"
## Where a --fresh run keeps its book, apart from PATH.
const FRESH_PATH := "user://pilot_fresh.json"
const SAVE_EVERY := 5.0
## The coin economy's numbers (a line's pay, the save's version and its
## scaling) are scripts/endless/economy.gd's.
const Economy = preload("res://scripts/endless/economy.gd")
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
var opened := {}
## The hangar's look (PlaneLook; `set_look`), {} for none, and a name for
## this state of it ("" for none) that changes each time it is set: what
## ShopStock `dress` compares to know the plane wears it already.
var look := {}
var look_key := ""
var _look_rev := 0
var flights := 0
var flight := {}
## Where it is kept ("" never writes).
var path := PATH
var _dirty := false
var _since := 0.0
static var _fresh_wiped := false

## The book for this run, from the command line.
static func open() -> PilotBook:
	var b := PilotBook.new()
	# Harness runs fly bots: their tallies stay out of the player's book.
	if OS.has_environment("ZENSCAPE_NO_BOOK"): b.path = ""
	# The launch args (a driver's `open` and the scene picker give theirs).
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		# A replay (scripts/endless/flight_replay.gd) keeps no book either.
		if arg == "--pilot=fresh" or arg.begins_with("--replay="): b.path = ""
		elif arg.begins_with("--pilot-file="): b.path = arg.substr(13)
		elif arg == "--fresh" or arg == "--fresh=keep": b._go_fresh(arg == "--fresh=keep")
	b.load_book()
	b.new_flight()
	return b

## --fresh: a clean book in its own file, the saved book never touched. Wiped
## once a run, so going back to the title and on again keeps what this run
## found; --fresh=keep carries on from the last --fresh run. A harness run
## (no book, or its own file by a flag before this one) stays as it was.
func _go_fresh(keep: bool) -> void:
	if path != PATH: return
	path = FRESH_PATH
	if keep or _fresh_wiped: return
	_fresh_wiped = true
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func load_book() -> void:
	if path == "" or not FileAccess.file_exists(path): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	money = int(data.get("money",0))
	# A book from before the economy's SAVE_VERSION holds the old, smaller
	# coins: scaled once to the new, then saved with the version so it never
	# scales again (owned items stay owned as they are).
	if int(data.get("economy",1)) < Economy.SAVE_VERSION:
		money = int(round(money*Economy.SAVE_SCALE))
		_dirty = true
	tally = {}
	# A value JSON couldn't hold (an inf or NaN once saved) reads back null: drop it.
	for k: String in (data.get("tally",{}) as Dictionary):
		if data.tally[k] is float or data.tally[k] is int: tally[k] = float(data.tally[k])
	records = {}
	for k: String in (data.get("records",{}) as Dictionary):
		if data.records[k] is float or data.records[k] is int: records[k] = data.records[k]
	found = data.get("found",{})
	owned = data.get("owned",{})
	worn = data.get("worn",{})
	opened = data.get("opened",{})
	var kept: Variant = data.get("look",{})
	var was := _dirty
	set_look(kept if kept is Dictionary else {})
	_dirty = was
	flights = int(data.get("flights",0))

func save() -> void:
	_dirty = false
	_since = 0.0
	if path == "": return
	var data := {"economy":Economy.SAVE_VERSION,"money":money,"tally":tally,"records":records,"found":found,"owned":owned,"worn":worn,"opened":opened,"look":look,"flights":flights}
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
	if not is_finite(n): return
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

## `name` is broken open for good, kept at once.
func open_up(name: String) -> void:
	opened[name] = flights
	save()

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
	# A paint put on at the shop is what the plane wears: the hangar's look
	# over it goes (until skins are presets, spec-hangar.md).
	if slot == "paint" and not look.is_empty(): set_look({})
	_dirty = true

## The hangar's look (a PlaneLook dictionary, JSON's own types only), or {}
## for none: kept, and worn from the next `ShopStock.dress`.
func set_look(to: Dictionary) -> void:
	look = to
	_look_rev += 1
	look_key = "" if look.is_empty() else "look#%d" % _look_rev
	_dirty = true

func worn_in(slot: String, default: String = "") -> String:
	return String(worn.get(slot,default))

## A banked line: {points, mult, moves: Array of move names in order,
## terrain: Array of kinds of land crossed in order, t: seconds long, plus
## whatever the line keeps}. Pays `line_pay`, keeps the flight's best,
## tries the line records. Returns the money paid.
func line_banked(line: Dictionary) -> int:
	var points := float(line.get("points",0.0))
	var paid := line_pay(points,(line.get("moves",[]) as Array).size())
	earn(paid)
	line["money"] = paid
	flight.lines.append(line)
	if points > float(flight.best_line.get("points",0.0)): flight.best_line = line
	best("best_line",points)
	best("best_mult",float(line.get("mult",1.0)))
	best("longest_line",float(line.get("t",0.0)))
	count("lines")
	return paid

## The money for a line of `points` (as banked and shown: its multiplier
## already in them) with `moves` moves: Economy.COINS_PER_POINT of the
## points, at least 1 when it has a move.
static func line_pay(points: float, moves: int = 1) -> int:
	var paid := int(round(maxf(points,0.0)*Economy.COINS_PER_POINT))
	if moves > 0: paid = maxi(paid,1)
	return paid

## A finished challenge: {id, kind, got, of, time, points, money, done:
## bool}. Pays its money.
func challenge_done(result: Dictionary) -> void:
	earn(int(result.get("money",0)))
	flight.challenges.append(result)
	count("challenges_done" if bool(result.get("done",false)) else "challenges_tried")
