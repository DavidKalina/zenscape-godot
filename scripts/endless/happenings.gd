extends Node
## The happenings director (docs/design/endless-flight/spec-wild-kit-director.md):
## rare moments keyed to place, hour and weather, one at a time, with a
## cooldown per area.
##
## A moment (scripts/endless/moments/moment.gd) registers with a name, the
## cue it listens for, where (predicates: scripts/endless/moments/where.gd),
## when (an hour window of the day cycle, the weathers it runs in), how rare
## (a chance per cue and a cooldown per area) and what it does (start, then
## step until it is done). An area is a cell of the land AREA m square for
## the rolls; the cooldown holds within AREA m of where the moment last
## fired, so a cloud astride two cells doesn't fire it twice.
##
## Cheap when idle: the director doesn't scan the world. It watches a few
## cues off the plane's own state (CUES), and only when a cue comes does it
## ask that cue's moments whether they fit. The cloud cue tests one point
## against the clouds near the plane every CLOUD_TEST s (the list the
## pilot's tallies already keep: scripts/endless/pilot_tallies.gd).
##
## Rolls come from the seed, the moment, the area and how many times the
## moment has rolled there (`roll_of`), so a replayed flight fires the same
## moments.
##
## --happen=<name>[,<name>] forces those moments each time their cue comes
## and their place and hour fit, past chance and cooldown, so the user can
## see one on demand. --happen=off: the director is off.

const Moment = preload("res://scripts/endless/moments/moment.gd")
const CloudPunch = preload("res://scripts/endless/moments/cloud_punch.gd")
const WaterfowlTakeoff = preload("res://scripts/endless/moments/waterfowl_takeoff.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")

## An area: a cell of the land this many m square (the rolls key on it), and
## the reach of a moment's cooldown round where it fired.
const AREA := 1000.0
## The cues the director watches: what each means.
const CUES := {
	&"lifted": "the wheels left the ground (a takeoff)",
	&"cloud_top": "out of a cloud's top, climbing, after CLOUD_SECONDS inside",
}
## How often the plane is tested against the clouds near it (s).
const CLOUD_TEST := 0.1
## Inside a cloud this long (s) before climbing out of its top is a cue.
const CLOUD_SECONDS := 2.0
## How far under the plane the cloud must still be, as it leaves, for the
## way out to be its top (m).
const CLOUD_UNDER := 25.0

var _seed := 1
## Every registered moment.
var moments: Array = []
## The moment running now, or null. One at a time.
var running: Moment = null
## The context `running` was started with.
var running_ctx := {}
## Names forced by --happen=.
var forced := PackedStringArray()
## Seconds since setup (cooldowns count in it).
var clock := 0.0
## Moment name -> its fires still cooling: [[x, z, the clock time it may fire there again]].
var _cooling := {}
## "name@ax,az" -> rolls made there (the hash's counter).
var _rolls := {}
## What happened, in order: {t, name, cue, area, forced, roll, chance} for each
## fire, and {t, name, cue, area, why} for each cue that didn't fire (a check
## reads it; it is short, at most LOG_MOST entries).
var history: Array = []
const LOG_MOST := 64
var stats := {"cues":0,"fired":0,"cooldown":0,"busy":0,"rolled_out":0,"unfit":0}

var _cloud_test := 0.0
var _cloud_in := 0.0
var _was_in := false

## The --happen= value ("" when not given).
static func flag() -> String:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--happen="): return a.get_slice("=",1)
	return ""

## Whether the director runs (--happen=off: not).
static func wanted() -> bool:
	return flag() != "off"

func setup(world_seed: int, _game: Node) -> void:
	name = "Happenings"
	_seed = world_seed
	var f := flag()
	if f != "" and f != "off": forced = f.split(",",false)
	register(CloudPunch.new())
	register(WaterfowlTakeoff.new())
	for n: String in forced:
		if moment_named(n) == null: push_warning("--happen=%s: no moment by that name (%s)" % [n,", ".join(names())])

## Adds moment `m`.
func register(m: Moment) -> void:
	moments.append(m)

func names() -> PackedStringArray:
	var out := PackedStringArray()
	for m: Moment in moments: out.append(str(m.name))
	return out

func moment_named(n: String) -> Moment:
	for m: Moment in moments:
		if str(m.name) == n: return m
	return null

## The area (a cell of the land) holding world point `p`.
static func area_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x/AREA),floori(p.z/AREA))

## The weather now: "clear" until weather states exist.
func weather() -> String:
	return "clear"

func step(delta: float, game: Node, events: Dictionary) -> void:
	clock += delta
	if running != null:
		if not running.step(delta,game):
			running.finish(game)
			running = null
			running_ctx = {}
	var cues: Array = _cues(delta,game,events)
	for cue: StringName in cues:
		stats.cues += 1
		for m: Moment in moments:
			if m.cue == cue: _try(m,cue,game)

## Stops the moment running now, if any (leaving the scene).
func _exit_tree() -> void:
	if running != null and is_inside_tree():
		running.finish(get_parent())
	running = null

# --- Cues -------------------------------------------------------------------

func _cues(delta: float, game: Node, events: Dictionary) -> Array:
	var out: Array = []
	if events.has("lifted"): out.append(&"lifted")
	if _cloud_cue(delta,game): out.append(&"cloud_top")
	return out

## True the test the plane leaves a cloud through its top, climbing, after
## CLOUD_SECONDS inside it.
func _cloud_cue(delta: float, game: Node) -> bool:
	_cloud_test -= delta
	if _cloud_test > 0.0: return false
	var since := CLOUD_TEST-_cloud_test
	_cloud_test = CLOUD_TEST
	if not game.hand_landing.flying():
		_cloud_in = 0.0
		_was_in = false
		return false
	var clouds: Variant = game.look.clouds if game.look != null else null
	if clouds == null or not bool(clouds.enabled): return false
	var near: Variant = game.tallies.get("_near_clouds")
	if near == null: return false
	var p: Vector3 = game.plane.position
	var inside := float(clouds.cloud_depth(p,near)) > 0.0
	var cue := false
	if inside:
		_cloud_in += since
	elif _was_in:
		var climbing := float((game.plane.velocity as Vector3).y) > 1.0
		if _cloud_in >= CLOUD_SECONDS and climbing:
			cue = float(clouds.cloud_depth(p-Vector3(0.0,CLOUD_UNDER,0.0),near)) > 0.0
		_cloud_in = 0.0
	_was_in = inside
	return cue

# --- Firing -----------------------------------------------------------------

## The context a moment is asked with: where the plane is and how it goes.
func context(game: Node, cue: StringName) -> Dictionary:
	var plane: RefCounted = game.plane
	var p: Vector3 = plane.position
	var h := float(plane.heading)
	var sun := Vector3.UP
	if game.look != null and game.look.celestial != null:
		sun = game.look.celestial.state.zs_sun_direction
	return {"cue":cue,"at":p,"area":area_of(p),"velocity":plane.velocity,
		"forward":Vector3(-sin(h),0.0,-cos(h)),"heading":h,"hour":hour_of(game),
		"weather":weather(),"sun":sun,"time":clock}

static func hour_of(game: Node) -> float:
	return float(game.look.hour()) if game.look != null else 12.0

func _try(m: Moment, cue: StringName, game: Node) -> bool:
	var ctx := context(game,cue)
	var area: Vector2i = ctx.area
	var is_forced := forced.has(str(m.name))
	if running != null:
		_note(m,ctx,"busy (%s running)" % running.name)
		stats.busy += 1
		return false
	var why: String = m.unfit(ctx,game)
	if why != "":
		_note(m,ctx,why)
		stats.unfit += 1
		return false
	var key := "%s@%d,%d" % [m.name,area.x,area.y]
	var chance: float = m.chance_at(ctx,game)
	var roll := -1.0
	var at: Vector3 = ctx.at
	if not is_forced:
		var left := cooling(str(m.name),at)
		if left > 0.0:
			_note(m,ctx,"cooldown %.0f s" % left)
			stats.cooldown += 1
			return false
		var n := int(_rolls.get(key,0))
		_rolls[key] = n+1
		roll = roll_of(_seed,str(m.name),area,n)
		if roll >= chance:
			_note(m,ctx,"rolled %.2f over %.2f" % [roll,chance])
			stats.rolled_out += 1
			return false
	var fires: Array = _cooling.get(str(m.name),[])
	fires = fires.filter(func(f: Array) -> bool: return float(f[2]) > clock)
	fires.append([at.x,at.z,clock+m.cooldown])
	_cooling[str(m.name)] = fires
	running = m
	running_ctx = ctx
	stats.fired += 1
	_add({"t":snappedf(clock,0.01),"name":str(m.name),"cue":str(cue),"area":[area.x,area.y],"forced":is_forced,
		"roll":snappedf(roll,0.001),"chance":chance})
	print("[happen] %s at (%.0f, %.0f, %.0f), area %s, %.1f h%s" % [m.name,ctx.at.x,ctx.at.y,ctx.at.z,str(area),float(ctx.hour),
		", forced" if is_forced else ", rolled %.2f under %.2f" % [roll,chance]])
	m.start(ctx,game)
	return true

## Seconds before moment `moment` may fire again at world point `at` (0: it
## may): the most left of its fires within AREA m.
func cooling(moment: String, at: Vector3) -> float:
	var left := 0.0
	for f: Array in _cooling.get(moment,[]):
		if Vector2(at.x,at.z).distance_to(Vector2(float(f[0]),float(f[1]))) < AREA:
			left = maxf(left,float(f[2])-clock)
	return left

## A roll in 0..1 for the `n`th try of `moment` in `area`: the same on every
## machine and every replay. The string's hash seeds a PCG draw, which mixes
## it (the hash alone barely moves its low bits for the last characters).
static func roll_of(world_seed: int, moment: String, area: Vector2i, n: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|%s|%d|%d|%d" % [world_seed,moment,area.x,area.y,n]).hash()
	return rng.randf()

func _note(m: Moment, ctx: Dictionary, why: String) -> void:
	var area: Vector2i = ctx.area
	_add({"t":snappedf(clock,0.01),"name":str(m.name),"cue":str(ctx.cue),"area":[area.x,area.y],"why":why})

func _add(entry: Dictionary) -> void:
	history.append(entry)
	if history.size() > LOG_MOST: history.pop_front()

## The fires in the history (entries without a `why`).
func fired() -> Array:
	return history.filter(func(e: Dictionary) -> bool: return not e.has("why"))
