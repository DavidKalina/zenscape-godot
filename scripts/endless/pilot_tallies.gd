class_name PilotTallies
extends RefCounted
## The counting hooks (endless flight; docs/design/endless-flight/spec-wild-loop.md,
## lane `logbook`): each frame, what the flight did into the pilot's book
## (`game.book`, PilotBook `count` / `best`), and the landing's edge for the
## summary. One call a frame from the main scene's `tick`, after the near
## misses: `step(delta, game, events)`.
##
## Tallies (book.tally / book.flight.tally):
##   metres    flown (aloft)          aloft     seconds aloft
##   landings  came to rest from the air (the STOPPED edge; ManualLanding's
##             "stopped" repeats every frame stood still)
##   crashes, scrapes                 trees     knocked down (events "knock")
##   grass_m   metres cut low over grass: the way flown weighted by the wash
##             GrassReact gets (`wash_strength`); shown as blades (GRASS_BLADES)
##   clouds    flown into (`in_cloud`, an edge, out CLOUD_OUT s first)
##   flocks    flushed (EndlessBirds stats.flushed, the plane's)
##   skims     low fast runs over water (the near-miss spray's test), held
##             SKIM_HOLD s
## Records (book.records): top_speed (m/s), highest (m over the sea),
## longest_flight (s aloft in one flight).
##
## `say(key, value)` writes a tally or record for the logbook and the
## summary; keys it doesn't know (another lane's) read by their name.

const GrassReact = preload("res://scripts/endless/grass_react.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const NearMiss = preload("res://scripts/endless/near_miss.gd")

## Blades for a metre cut: the wash's width (about 8 m) times a meadow's
## blades to the square metre. A placeholder estimate, for the words.
const GRASS_BLADES := 8.0*350.0
## Out of cloud this long before the next one counts (a ragged edge is one).
const CLOUD_OUT := 1.5
## Skimming this long makes a skim.
const SKIM_HOLD := 0.4
## A record's try at most this often (s) where it grows by the frame.
const TRY_EVERY := 0.5
## The clouds near the plane: a list rebuilt at most every CLOUDS_EVERY s on a
## worker thread (EndlessClouds `clouds_near`, 15-25 ms a build), reaching
## CLOUDS_MARGIN m past what a depth test needs; the plane tested against
## it every CLOUD_TEST s. Asked whole every frame it cost the frame rate.
const CLOUDS_EVERY := 1.0
const CLOUDS_MARGIN := 250.0
const CLOUD_TEST := 0.1

## True the frame the plane came to rest from the air (the summary's cue).
var landed := false
## True the frame it lifted off.
var lifted := false
var _stopped := true
var _aloft := false
var _in_cloud := false
var _out_for := 99.0
var _skim_for := 0.0
var _skimmed := false
var _flushed := -1
var _try := 0.0
var _near_clouds: Variant = null
var _next_clouds: Array = []
var _clouds_task := -1
var _clouds_age := 99.0
var _cloud_test := 0.0

func step(delta: float, game: Node, events: Dictionary) -> void:
	landed = false
	lifted = events.has("lifted")
	var book: PilotBook = game.book
	if book == null: return
	var hl: ManualLanding = game.hand_landing
	var held: bool = game.stage != null and game.stage.holding()
	var flying := hl.flying() and not held
	var stopped := hl.phase == ManualLanding.STOPPED
	if stopped and not _stopped and _aloft:
		book.count("landings")
		book.best("longest_flight",_aloft_of(book))
		_aloft = false
		landed = true
		_place(game,book)
	_stopped = stopped
	if events.has("crash"): book.count("crashes")
	if events.has("scrape"): book.count("scrapes")
	if events.get("knock") is Dictionary: book.count("trees",float(int(events.knock.get("count",1))))
	_birds(game,book)
	if not flying:
		_in_cloud = false
		_skim_for = 0.0
		_skimmed = false
		return
	_aloft = true
	var plane: RefCounted = game.plane
	var p: Vector3 = plane.position
	var way := float((plane.velocity as Vector3).length())*delta
	book.count("metres",way)
	book.count("aloft",delta)
	_grass(game,book,p,way)
	_clouds(delta,game,book,p)
	_skim(delta,game,book)
	book.best("top_speed",float(plane.speed))
	_try -= delta
	if _try <= 0.0:
		_try = TRY_EVERY
		book.best("highest",p.y-Field.SEA_Y)
		book.best("longest_flight",_aloft_of(book))

## Where the plane came to rest, when that is a place: on the Peak's plateau
## (peak_massif.gd `on_plateau`) the book finds `place/peak` and the flight
## keeps `place` "peak" for the landing card.
func _place(game: Node, book: PilotBook) -> void:
	var f: Variant = game.get("field")
	if f == null or not (f as Object).has_method("peak"): return
	var pk: RefCounted = f.peak()
	if pk == null or not pk.on_plateau(game.plane.position): return
	book.find("place/peak")
	book.flight["place"] = "peak"

## Seconds aloft this flight so far: the flight's own "aloft" tally, the
## one the summary reads, so the record and the card always agree.
static func _aloft_of(book: PilotBook) -> float:
	return float((book.flight.get("tally",{}) as Dictionary).get("aloft",0.0))

## The way cut through the grass: the wash's strength at the plane's height
## over the land (as the main scene's `_react` reckons it).
func _grass(game: Node, book: PilotBook, p: Vector3, way: float) -> void:
	if game.grass == null or not bool(game.grass.enabled): return
	var h: float = game.field.height(p.x,p.z)
	if h <= Field.SEA_Y+0.2 or bool(game._on_river()): return
	var cut := GrassReact.wash_strength(p.y-h,1.0,WorldScale.span)
	if cut > 0.01: book.count("grass_m",way*cut)

func _clouds(delta: float, game: Node, book: PilotBook, p: Vector3) -> void:
	var clouds: Variant = game.look.clouds if game.look != null else null
	if clouds == null or not bool(clouds.enabled): return
	_clouds_age += delta
	if _clouds_task >= 0 and WorkerThreadPool.is_task_completed(_clouds_task):
		WorkerThreadPool.wait_for_task_completion(_clouds_task)
		_clouds_task = -1
		_near_clouds = _next_clouds
	if _clouds_task < 0 and _clouds_age >= CLOUDS_EVERY:
		_clouds_age = 0.0
		var at := Vector2(p.x,p.z)
		_clouds_task = WorkerThreadPool.add_task(func() -> void: _next_clouds = clouds.clouds_near(at,CLOUDS_MARGIN))
	_cloud_test -= delta
	if _near_clouds == null or _cloud_test > 0.0: return
	var since := CLOUD_TEST-_cloud_test
	_cloud_test = CLOUD_TEST
	var inside := float(clouds.cloud_depth(p,_near_clouds)) > 0.0
	if inside and not _in_cloud and _out_for >= CLOUD_OUT: book.count("clouds")
	_out_for = 0.0 if inside else _out_for+since
	_in_cloud = inside

## Waits out a cloud list being built (before the clouds go: the game's
## `_exit_tree`).
func finish() -> void:
	if _clouds_task >= 0: WorkerThreadPool.wait_for_task_completion(_clouds_task)
	_clouds_task = -1

## Low and fast over the sea or a river: the near misses' spray test.
func _skim(delta: float, game: Node, book: PilotBook) -> void:
	var near: NearMiss = game.near
	var plane: RefCounted = game.plane
	var wet: bool = bool(plane.weighted) and near.ground_surface == "water" \
		and near.ground_clear < WorldScale.span*float(game.SPRAY_SPANS) and float(plane.speed) > plane.cruise()*float(game.SPRAY_FAST)
	_skim_for = _skim_for+delta if wet else 0.0
	if _skim_for >= SKIM_HOLD and not _skimmed:
		_skimmed = true
		book.count("skims")
	if not wet: _skimmed = false

func _birds(game: Node, book: PilotBook) -> void:
	if game.birds == null or not "stats" in game.birds: return
	var n := int(game.birds.stats.get("flushed",0))-int(game.birds.stats.get("foot_flushed",0))
	if _flushed >= 0 and n > _flushed: book.count("flocks",float(n-_flushed))
	_flushed = n

# --- The words ------------------------------------------------------------------------

## The tallies in the order they read, each [key, label].
const TALLIES := [["metres","flown"],["aloft","aloft"],["landings","landings"],["lines","lines banked"],
	["trees","trees knocked"],["grass_m","grass cut"],["clouds","clouds flown through"],["flocks","flocks flushed"],
	["skims","water skims"],["scrapes","scrapes"],["crashes","crashes"],["photos","photos"],
	["challenges_done","challenges finished"],["challenges_tried","challenges tried"]]
## The records in the order they read, each [key, label].
const RECORDS := [["best_line","best line"],["best_mult","best multiplier"],["longest_line","longest line"],
	["tightest_gap","tightest gap"],["top_speed","top speed"],["highest","highest flown"],["longest_flight","longest flight"]]
## The finds by the start of their ids ("gap/..."), each [prefix, label].
const FINDS := [["gap","gaps"],["starter","starters"],["shop","shops"],["place","places"],["find","wilderness finds"]]

## The label for `key` (a tally's or a record's), else its own name spaced.
static func label(key: String) -> String:
	for row: Array in TALLIES+RECORDS:
		if row[0] == key: return row[1]
	# A place line's time (place_lines.gd): its name.
	if key.begins_with("line/"): return key.get_slice("/",2).replace("_"," ")
	return key.replace("_"," ")

## `value` of `key` as it reads.
static func say(key: String, value: float) -> String:
	match key:
		"metres": return ("%.1f km" % (value/1000.0)) if value >= 1000.0 else ("%d m" % roundi(value))
		"aloft","longest_flight","longest_line": return clock(value)
		"grass_m": return ("~%s blades" % big(value*GRASS_BLADES)) if value > 0.0 else "0"
		"top_speed": return "%d km/h" % roundi(value*3.6)
		"highest": return "%d m" % roundi(value)
		"tightest_gap": return "%.2f m" % value
		"best_mult": return "x%.1f" % value
	if key.begins_with("line/"):
		var d := roundi(maxf(value,0.0)*10.0)
		return "%d:%02d.%d" % [d/600,(d/10)%60,d%10]
	return big(value)

## Seconds as 0:42 or 1:02:05.
static func clock(s: float) -> String:
	var t := maxi(roundi(s),0)
	if t >= 3600: return "%d:%02d:%02d" % [t/3600,(t/60)%60,t%60]
	return "%d:%02d" % [t/60,t%60]

## A count as 12, 1,204, 38k or 2.4M.
static func big(v: float) -> String:
	var n := roundi(v)
	if n >= 10_000_000: return "%dM" % roundi(n/1_000_000.0)
	if n >= 1_000_000: return "%.1fM" % (n/1_000_000.0)
	if n >= 100_000: return "%dk" % roundi(n/1000.0)
	if n >= 1000: return "%d,%03d" % [n/1000,n%1000]
	return str(n)

## The finds in `found` (ids, an Array or a Dictionary's keys) counted by
## FINDS' prefixes, each [label, n]; other kinds by their own prefix.
static func finds(found: Variant) -> Array:
	var counts := {}
	for id: Variant in found:
		var kind := str(id).get_slice("/",0)
		counts[kind] = int(counts.get(kind,0))+1
	var out := []
	for row: Array in FINDS:
		out.append([row[1],int(counts.get(row[0],0))])
		counts.erase(row[0])
	for kind: String in counts: out.append([kind.replace("_"," "),int(counts[kind])])
	return out
