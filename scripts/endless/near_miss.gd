extends RefCounted
## Near misses (endless flight, the weighted presets: scripts/flight_weight.gd).
## How close the plane's body came to the land, a tree or a ruin, and the
## points that earns, chained into a boost meter that the surge spends.
##
## Measured each frame (`measure`) from five points on the body (nose, tail,
## belly, both wingtips; BODY, times the plane's size):
## - ground: each point's height over what stands under it (the study's
##   `plane_ground`: the land, a tree's crown, a ruin's top) or the water,
##   the least of them. What it is over at that point names the surface
##   (land, water, tree, stone).
## - stone: rays out along each wing (two a side, fore and aft of the
##   wing's middle) and up through the roof of the plane, on physics layer
##   1, for trunks, walls, arch legs and spans, tunnel bores; a bore's
##   tube counts as overhead. Land hit along a wing counts only while the
##   wing points sideways, not down (a hillside abeam, not the meadow under
##   a bank).
## Each is a channel. A moment opens when a channel's clearance comes under
## REACH spans and is still closing, keeps its least, and is scored at its
## turning point: once the clearance has grown back HYST spans (or
## HYST_SHARE of the least) past the least, or leaves REACH.
##
## The score (`_score`): BASE[kind] x (1 + CLOSE_GAIN k²), k = 1 - least
## over REACH (bands RAZOR and CLOSE name it), x the edge's (under EDGE
## spans, (EDGE + EDGE_SOFT) / (least + EDGE_SOFT): x2 at 0.4 m, x4 at
## 0.1 m, x6 touching, at plane 2), x speed over cruise, x for a
## pull-out the closing rate's (1 + (closing / CLOSING_REF)^1.5, at most
## CLOSING_TOP), x the farming cut. CLOSING_REF and PULL_MIN are times the
## plane's pace (scripts/flight_pace.gd). Kinds:
## - pull-out: a ground moment over land or water closing at PULL_MIN m/s
##   or more (a dive or a hill saved low); slower, it is only skimming.
## - graze: a ground moment over a tree or ruin, or a stone moment from one
##   side.
## - thread: a passage under something (an arch's span, a hall's roof, a
##   bore: `overhead`), scored as it comes out from under, by the least of
##   the ground's, the stone's and the roof's clearance under it (against
##   REACH); or a stone moment with both wings near something at once (a
##   gap). A stone moment with something overhead is the passage's.
## - skim: low over land or water (under SKIM_BAND spans, fast), a trickle
##   of SKIM_RATE points a second by closeness; it holds the bank timer (the
##   chain stays alive) but adds no step to the multiplier.
##   `skim_scale` multiplies the rate (the pirate ship's guns, near her).
## - a ball's pass (`shot_pass`, pirate_ship.gd): a graze, against the reach the
##   ball gives; each ball measures its own closest pass, as a fast ball slips
##   between the wing rays.
## Farming: each scored moment within FARM_RADIUS m and FARM_TIME s of this
## one cuts it by FARM_EACH more, and the same tree, ruin or patch of land
## again by FARM_SAME. A ball's pass neither takes the cut nor adds to it.
##
## The chain: each move adds its points and its difficulty (LineMoves
## `difficulty`) to the multiplier, cut by the farming cut and by its
## repeats in the line (a move's nth repeat adds 1/(n+1) of it); a kind new
## to a line already under way adds NEW_KIND more. The multiplier starts at
## x1 and stops at CHAIN_TOP. The meter fills live as the chain grows: its
## points x multiplier, as they rise, over `meter_full` (none while the surge
## is held or the smash is hot). BANK_AFTER s with no new moment banks the
## chain, points x multiplier, into the score only; reads the
## line back (`_line`, the frame's "line", paid by `game.book`); a scrape
## or crash (`lose`) drops what is unbanked, and the meter keeps what it
## has. Each moment kicks the speed a
## little (KICK m/s by closeness). The surge (`fly_surge` held) spends the
## meter over SURGE_TIME s full, driving the plane past Boost (SkyPlane
## `surge`).
##
## The line's score (2026-11-01; scripts/endless/line_score.gd, its numbers in
## line_tune.json): by degree of difficulty and the line's shape. Each moment is
## base x band x its factors (Close, Fast, Knife, Low, Under); runs of one kind
## and surface pay a length bonus; a flourish steps the line's multiplier
## (`multiplier`, no separate chain multiplier; LineScore's line_cap); skimming
## holds the bank but adds nothing. `_line_moment` scores every moment that way
## (and writes the `--line-log` row) under either formula; `--line-score=old`
## keeps the old one above in play for A/B, the new one shadowed in the log.
##
## `touching` (after `measure`): a body point in the land or a tree, or a
## wing in a wall, though the plane's middle is clear of it, for scripts/
## endless/flight_contact.gd to grade (a wingtip's scrape).

const WorldScale = preload("res://scripts/world_scale.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const LineMoves = preload("res://scripts/endless/line_moves.gd")
const Glyphs = preload("res://scripts/endless/near_glyphs.gd")
const LineScoreS = preload("res://scripts/endless/line_score.gd")
const LineLogS = preload("res://scripts/endless/line_log.gd")

## The body's points (toy metres, the plane's frame: x right, y up, -z
## ahead; times WorldScale.plane): the spinner, the tail, the lower
## wingtips. The belly is the wheels' bottom, SkyGlide SKIM under the
## middle (where the land is met).
const BODY := [Vector3(0.0,0.0,-0.55),Vector3(0.0,0.08,0.75),Vector3(-0.7,-0.1,0.0),Vector3(0.7,-0.1,0.0)]
## The wing rays: fore and aft of the wing's middle (toy m), and the roof
## over the middle (toy m, the upper wing's top).
const RAY_FORE := 0.3
const ROOF := 0.36
## Moments: under REACH spans of clearance over the ground (STONE_REACH
## past a wingtip or the roof); banded RAZOR and CLOSE spans; ended HYST
## spans (or HYST_SHARE of the least) past the least. A graze over a tree
## or a ruin's top counts only under CLOSE.
const REACH := 2.0
const STONE_REACH := 1.2
## Something this many spans over the roof is overhead (a passage under it).
const OVER_SPANS := 10.0
const RAZOR := 0.15
const CLOSE := 0.5
const HYST := 0.12
const HYST_SHARE := 0.5
## The score's parts (see the header).
const BASE := {"pull-out":100.0,"graze":200.0,"thread":300.0}
const CLOSE_GAIN := 3.0
const EDGE := 0.36
const EDGE_SOFT := 0.072
const PULL_MIN := 3.0
const CLOSING_REF := 5.0
const CLOSING_TOP := 6.0
## The closing rate is smoothed over CLOSING_EASE s; a moment keeps the
## most it saw while open.
const CLOSING_EASE := 0.06
## Slower than FAST_FROM of cruise nothing scores (a landing, a braked pass).
const FAST_FROM := 0.8
const SKIM_BAND := 1.0
const SKIM_RATE := 8.0
const FARM_RADIUS := 60.0
const FARM_TIME := 25.0
const FARM_EACH := 0.6
const FARM_SAME := 0.35
## The patch of land a ground moment's surface is known by (m).
const FARM_CELL := 30.0
const CHAIN_TOP := 12.0
const NEW_KIND := 0.5
## A move's difficulty when it has none.
const DIFF_PLAIN := 0.3
const BANK_AFTER := 3.0
const METER_FULL := 4000.0
const SURGE_TIME := 2.5
## The surge comes in and goes over these (s).
const SURGE_IN := 0.12
const SURGE_OUT := 0.3
const KICK := Vector2(0.6,1.6)
## A body point this far into the land (m) touches it.
const TIP_DEPTH := 0.08
const MASK := 1

## The clearances this frame (m; INF: nothing in reach): the ground's
## (least over the body's points), the stone's (least of the wings and the
## roof), and each wing's and the roof's.
var ground_clear := INF
var stone_clear := INF
var left_clear := INF
var right_clear := INF
var over_clear := INF
## What the least ground clearance was over (land, water, tree, stone),
## where, and whether something is overhead (a span, a roof, a bore).
var ground_surface := "land"
var ground_at := Vector3.ZERO
var overhead := false
## The ground's closing rate (m/s, smoothed; up closing).
var closing := 0.0
## A body point in something (see the header), or {}.
var touching := {}
## The chain: its points (before the multiplier), its moments, the seconds
## left before it banks, and the meter (0 to 1) it fills as it grows.
var chain_points := 0.0
var chain_count := 0
## The multiplier as the line has built it (`multiplier` caps it), and how
## many of each kind of move the line holds.
var chain_mult := 1.0
var _kinds := {}
var bank_left := 0.0
var meter := 0.0
## The unbanked line's points x multiplier already gone into the meter (or
## passed by while surging): the meter fills live by what's past it.
var _metered := 0.0
## How hard the surge drives now (0 to 1; SkyPlane `surge`).
var surge := 0.0
## The nearest thing in reach now (m; INF: none, or slow, or not flying):
## the ground's clearance under REACH spans, the stone's under STONE_REACH;
## the HUD's live gap.
var gap := INF
## Skimming now (holds the bank timer), and the score so far this flight.
var skimming := false
var total := 0.0
## The skim's rate times this now (the pirate ship sets it, near her).
var skim_scale := 1.0
var _prizes: Array[Dictionary] = []
## The last scored moment ({} none): kind, band, points, k, clear, at,
## surface; and every moment scored (for the drivers).
var last := {}
var moments: Array[Dictionary] = []
## The moves (line_moves.gd: what each moment was, the held moves) and the
## unbanked line's moments in order.
var moves := LineMoves.new()
var line_moments: Array[Dictionary] = []
## Seconds flown, for the farming memory.
var clock := 0.0
## The line's score (see the header): on unless `--line-score=old`; the line
## under way (LineScore.Line, scored under either formula), its number this
## flight, and why the next end happens (for the log).
var line_new := not ("--line-score=old" in preload("res://scripts/launch_args.gd").user_args())
var score_line := LineScoreS.Line.new()
var line_id := 0
var _end_reason := "banked"

var _ground := Tracker.new()
var _stone := Tracker.new()
var _pass := Tracker.new()
## An opening of the Peak's carve went through, and last frame's place.
var _gate := Tracker.new()
var _gate_last := Vector3.INF
var _gate_t := -INF
## Out from under for this long (s) ends a passage.
const PASS_GAP := 0.12
## A passage under an opening's own lintel doesn't pay again this soon after it (s).
const GATE_QUIET := 0.6
var _out_for := 0.0
var _recent: Array[Dictionary] = []
## Balls' passes waiting for the frame's score, and the tracker they score through.
var _shots: Array[Dictionary] = []
var _shot := Tracker.new()
var _ray: PhysicsRayQueryParameters3D
var _last_ground := INF
## The nearest stone this frame (its collider's id), for the farming cut.
var _near_id := 0
var _near_c := INF
var _near_what := "stone"
## The nearest stone this frame is a burrower's spur (BoreSpurs `holds`).
var _near_spur := false
var _near_body: Object

## One channel's moment.
class Tracker:
	var active := false
	## Off after a scrape until the clearance is back out of reach (so the
	## moment that scraped never scores on the way back up).
	var armed := true
	var least := INF
	var at := Vector3.ZERO
	var speed := 0.0
	var surface := "land"
	var id := 0
	var closing := 0.0
	var sides := 0
	var over := false
	## It came near a burrower's spur: a graze though the bore is overhead.
	var spur := false
	## The roll at the least (radians), and each wing's least (a gap's sides).
	var roll := 0.0
	var wl := INF
	var wr := INF
	func start(clear: float) -> void:
		active = true
		least = INF
		closing = 0.0
		sides = 0
		over = false
		spur = false
		wl = INF
		wr = INF
		least = clear
	func cancel() -> void:
		active = false
		armed = false

## The multiplier the chain has now.
func multiplier() -> float:
	if line_new: return score_line.mult
	return minf(chain_mult,CHAIN_TOP)

## The multiplier's cap (the HUD's heat): the line's under the new score.
func top() -> float:
	return float(LineScoreS.tune().line_cap) if line_new else CHAIN_TOP

## Seconds with no new moment before the line banks: the line's bank_after
## (line_tune.json) under the new score, BANK_AFTER under the old.
func bank_after() -> float:
	return float(LineScoreS.tune().bank_after) if line_new else BANK_AFTER

## The meter's fill (points).
func meter_full() -> float:
	if not line_new: return METER_FULL
	var t := LineScoreS.tune()
	return float(t.meter_full)*float(t.points_per_unit)

## The unbanked line back to nothing.
func _clear_line() -> void:
	_end_line()
	chain_points = 0.0
	chain_count = 0
	chain_mult = 1.0
	_metered = 0.0
	_kinds.clear()
	line_moments.clear()

## Everything back to nothing but the meter (a respawn).
func reset() -> void:
	_ground.cancel()
	_stone.cancel()
	_ground.armed = true
	_stone.armed = true
	_pass.cancel()
	_pass.armed = true
	_end_reason = "reset"
	_clear_line()
	_shots.clear()
	bank_left = 0.0
	surge = 0.0
	closing = 0.0
	touching = {}
	_last_ground = INF
	moves.drop()

## A ball went past `clear` m off, a pass scoring under `reach` m, the plane at
## `at`: scored in the next `score` (one a frame).
func shot_pass(clear: float, reach: float, at: Vector3) -> void:
	_shots.append({"clear":clear,"reach":reach,"at":at})

## A prize of `points` (the pirate ship sunk): a line of its own named `title`,
## banked in the next `score` beside the chain, at no multiplier, whatever the
## chain does; a scrape can't lose it. It doesn't count for the best-line records.
func prize(points: float, title: String, at: Vector3) -> void:
	_prizes.append({"points":points,"title":title,"at":at})

## A scrape or a crash: the moments under way and the unbanked chain go.
## Returns the points lost (before the multiplier, times it).
func lose() -> float:
	var lost := chain_points*multiplier()
	_end_reason = "lost"
	_ground.cancel()
	_stone.cancel()
	_pass.cancel()
	_pass.armed = true
	_clear_line()
	bank_left = 0.0
	moves.drop()
	return lost

# --- Measuring -------------------------------------------------------------------

## The clearances this frame round `game`'s plane (the endless flight study:
## `plane`, `plane_ground`, `water_at`, `field`, `trees`, `tunnels`, the
## land and ruins as physics layer 1).
func measure(delta: float, game: Node3D) -> void:
	var plane = game.plane
	var size := WorldScale.plane
	var half := WorldScale.span*0.5
	var reach := STONE_REACH*WorldScale.span
	_near_c = INF
	_near_body = null
	var xf := Transform3D(Basis.from_euler(Vector3(float(plane.pitch),float(plane.heading),-(float(plane.bank)+float(plane.spin)))),plane.position)
	touching = {}
	overhead = false
	over_clear = INF
	# The ground under each point of the body.
	ground_clear = INF
	var points: Array[Vector3] = [xf.origin+Vector3.DOWN*SkyGlide.SKIM]
	for b: Vector3 in BODY: points.append(xf*(b*size))
	for p: Vector3 in points:
		# The middle's belly asks the ground as the glide does; a body point
		# is on the plane's edge, so it asks the stone ungrown.
		var under: Variant = game.plane_ground(p,-1.0 if p == points[0] else 0.0)
		var top := -INF
		if under is Vector2:
			var span_under := (under as Vector2).y
			if p.y < span_under:
				# Under a span: overhead, the ground unknown there.
				overhead = true
				over_clear = minf(over_clear,span_under-p.y)
				continue
			top = (under as Vector2).x
		elif under != null:
			top = float(under)
		var water: float = game.water_at(p)
		var c := p.y-maxf(top,water)
		if c < ground_clear:
			ground_clear = c
			ground_at = p
			ground_surface = "water" if water > top else _standing(game,p,top)
		if c < -TIP_DEPTH and p != points[0] and ground_surface != "water":
			touching = {"at":p,"normal":Vector3.UP,"what":_standing(game,p,top)}
	# Closing on the ground (smoothed), and its peak.
	if ground_clear < INF and _last_ground < INF and delta > 0.0:
		var rate := (_last_ground-ground_clear)/delta
		closing = lerpf(closing,rate,1.0-exp(-delta/CLOSING_EASE))
	_last_ground = ground_clear
	# Stone along the wings and over the roof.
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
		_ray.collision_mask = MASK
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	left_clear = _wing(space,game,xf,-1.0,half,reach,size)
	right_clear = _wing(space,game,xf,1.0,half,reach,size)
	var roof := ROOF*size
	_ray.from = xf.origin
	_ray.to = xf.origin+xf.basis.y*(roof+OVER_SPANS*WorldScale.span)
	var hit := space.intersect_ray(_ray)
	if not hit.is_empty() and _what(game,hit.collider) != "land":
		var c := xf.origin.distance_to(hit.position)-roof
		overhead = true
		if c < reach: over_clear = minf(over_clear,c)
		if c < _near_c and c < reach:
			_near_c = c
			_near_id = hash([hit.collider.get_instance_id(),hit.shape])
			_near_what = "stone"
			_near_body = hit.collider
	if game.tunnels != null and int(game.tunnels.tube(xf.origin)) == 0: overhead = true
	_near_spur = game.tunnels != null and game.tunnels.spurs != null and game.tunnels.spurs.holds(_near_body)
	stone_clear = minf(minf(left_clear,right_clear),over_clear)

## The clearance along one wing (`side` -1 left, 1 right): two rays out
## from the middle, fore and aft, less the half span; a wing in a wall
## touches.
func _wing(space: PhysicsDirectSpaceState3D, game: Node3D, xf: Transform3D, side: float, half: float, reach: float, size: float) -> float:
	var out := xf.basis.x*side
	var best := INF
	for fore: float in [-RAY_FORE,RAY_FORE]:
		_ray.from = xf.origin+xf.basis.z*fore*size
		_ray.to = _ray.from+out*(half+reach)
		var hit := space.intersect_ray(_ray)
		if hit.is_empty(): continue
		var what := _what(game,hit.collider)
		# The land along a wing pointed down is the ground's to measure.
		if what == "land" and absf(out.y) > 0.5: continue
		var c := (_ray.from as Vector3).distance_to(hit.position)-half
		best = minf(best,c)
		if c < _near_c:
			_near_c = c
			_near_id = hash([hit.collider.get_instance_id(),hit.shape])
			_near_what = what
			_near_body = hit.collider
		if c < 0.0 and touching.is_empty():
			touching = {"at":hit.position,"normal":-out,"what":what}
	return best

## What a collider is: tree, stone (an arch, a hall, a bore) or land.
func _what(game: Node3D, collider: Object) -> String:
	var node := collider as Node
	if node == null: return "stone"
	if game.trees != null and game.trees.is_ancestor_of(node): return "tree"
	if game.land != null and game.land.is_ancestor_of(node): return "land"
	return "stone"

## What stands at `p` with its top at `top`: land, or a tree or stone on it.
func _standing(game: Node3D, p: Vector3, top: float) -> String:
	var h: float = game.field.height(p.x,p.z)
	if top <= h+0.5: return "land"
	if game.trees != null and float(game.trees.top_at(p)) > h+0.5: return "tree"
	return "stone"

# --- Scoring ---------------------------------------------------------------------

## One frame after `measure` (and the contact's grading): the moments'
## turning points scored, the skim's trickle, the chain banked, the surge
## spent (`surge_held`: the key or button held). Returns the frame's
## events: "near" {kind, band, points, k, clear, at, surface, under (a
## passage's thread, not a gap's), plus LineMoves's kind, glyph, terrain,
## diff and `step` (what it added to the multiplier)}, "banked" {points,
## line} and "line" (the same line, see `_line`), "surge" {start}.
func score(delta: float, game: Node3D, surge_held: bool) -> Dictionary:
	clock += delta
	var out := {}
	var plane = game.plane
	var cruise: float = maxf(float(plane.cruise()),1.0)
	var speed: float = float(plane.speed)
	var fast := speed >= FAST_FROM*cruise
	var reach := REACH*WorldScale.span
	# The ground's moment.
	if _track(_ground,ground_clear,reach,speed,game):
		if _ground.surface in ["tree","stone"]:
			if _ground.least < CLOSE*WorldScale.span: _moment("graze",_ground,reach,cruise,out,game)
		elif _ground.closing >= PULL_MIN*_pace(game): _moment("pull-out",_ground,reach,cruise,out,game)
	if _ground.active:
		_ground.closing = maxf(_ground.closing,closing)
		if ground_clear <= _ground.least:
			_ground.surface = ground_surface
			_ground.at = ground_at
			_ground.id = hash(Vector2i(floori(ground_at.x/FARM_CELL),floori(ground_at.z/FARM_CELL)))
	# The stone's moment.
	var stone_reach := STONE_REACH*WorldScale.span
	if _track(_stone,stone_clear,stone_reach,speed,game) and (_stone.spur or not _stone.over):
		_moment("thread" if _stone.sides == 3 else "graze",_stone,stone_reach,cruise,out,game)
	if _stone.active:
		if left_clear < stone_reach: _stone.sides |= 1
		if right_clear < stone_reach: _stone.sides |= 2
		_stone.wl = minf(_stone.wl,left_clear)
		_stone.wr = minf(_stone.wr,right_clear)
		if overhead: _stone.over = true
		if _near_spur and stone_clear < stone_reach: _stone.spur = true
		if stone_clear <= _stone.least:
			_stone.at = plane.position
			_stone.id = _near_id
			_stone.surface = _near_what
	# A passage under something.
	var under := minf(minf(ground_clear,stone_clear),over_clear)
	if overhead and bool(game.hand_landing.flying()):
		_out_for = 0.0
		if not _pass.active:
			_pass.start(under)
			_pass.speed = speed
			_pass.roll = LineMoves.roll_of(plane)
			_pass.at = plane.position
			_pass.id = hash(Vector2i(floori(plane.position.x/FARM_CELL),floori(plane.position.z/FARM_CELL)))
			_pass.surface = "stone"
		elif under < _pass.least:
			_pass.least = under
			_pass.speed = speed
			_pass.roll = LineMoves.roll_of(plane)
	elif _pass.active:
		_out_for += delta
		if _out_for >= PASS_GAP:
			_pass.active = false
			if clock-_gate_t > GATE_QUIET: _moment("thread",_pass,reach,cruise,out,game)
	# An opening of the Peak's carve (LandArches `gate_crossed`): a thread by where
	# it went through. A passage under it ends here too, so it isn't paid twice.
	var p_now: Vector3 = plane.position
	if _gate_last != Vector3.INF and fast and bool(game.hand_landing.flying()):
		var arches = game.get("arches")
		var hit: Dictionary = arches.gate_crossed(_gate_last,p_now) if arches != null else {}
		if not hit.is_empty():
			_gate.start(maxf(float(hit.room)-WorldScale.span*0.5,0.0))
			_gate.speed = speed
			_gate.roll = LineMoves.roll_of(plane)
			_gate.at = p_now
			_gate.surface = "stone"
			_gate.id = hash(str(hit.name))
			_pass.active = false
			_gate_t = clock
			_moment("thread",_gate,float(hit.half),cruise,out,game)
			_gate.active = false
	_gate_last = p_now
	# A ball's pass.
	if not _shots.is_empty() and not out.has("near") and bool(game.hand_landing.flying()):
		var shot: Dictionary = _shots.pop_front()
		_shot.least = float(shot.clear)
		_shot.speed = speed
		_shot.at = shot.at
		_shot.surface = "stone"
		_shot.closing = 0.0
		_shot.roll = LineMoves.roll_of(plane)
		_moment("graze",_shot,float(shot.reach),cruise,out,game)
	# The held moves; one done a frame is chained when nothing else was.
	moves.step(delta,game,self)
	if not out.has("near") and not moves.pending.is_empty():
		var held: Dictionary = moves.pending.pop_front()
		held.farm = float(held.get("farm",_farm(held.at,int(held.id))))
		held.points = float(held.points)*float(held.farm)
		_chain(held,out,game)
	# The skim's trickle.
	var band := SKIM_BAND*WorldScale.span
	skimming = fast and ground_clear < band and ground_surface in ["land","water"] and bool(game.hand_landing.flying())
	if skimming:
		var k := 1.0-clampf(ground_clear/band,0.0,1.0)
		var add := 0.0 if line_new else SKIM_RATE*skim_scale*k*clampf(speed/cruise,0.5,2.0)*delta
		chain_points += add
		total += add
		if bank_left <= 0.0: bank_left = bank_after()
	# The live gap.
	gap = INF
	if fast and bool(game.hand_landing.flying()):
		if ground_clear < reach: gap = maxf(ground_clear,0.0)
		if stone_clear < stone_reach: gap = minf(gap,maxf(stone_clear,0.0))
	# The meter fills live: the line's points x multiplier as they grow, not
	# while the surge is held (or the smash is hot).
	var live := chain_points*multiplier()
	if live > _metered:
		if not surge_held: meter = minf(1.0,meter+(live-_metered)/meter_full())
		_metered = live
	# The bank, on its timer: into the score only.
	if chain_points > 0.0 and not skimming and not moves.holding:
		bank_left -= delta
		if bank_left <= 0.0:
			var banked := chain_points*multiplier()
			var line := _line(banked,game)
			out["banked"] = {"points":banked,"line":line}
			out["line"] = line
			_clear_line()
	if not _prizes.is_empty() and not out.has("banked"):
		var line := _prize_line(_prizes.pop_front(),game)
		meter = minf(1.0,meter+float(line.points)/meter_full())
		total += float(line.points)
		out["banked"] = {"points":line.points,"line":line}
		out["line"] = line
	# The surge.
	var want := 1.0 if surge_held and meter > 0.0 else 0.0
	if want > 0.0 and surge <= 0.0: out["surge"] = {"start":true}
	surge = move_toward(surge,want,delta/(SURGE_IN if want > surge else SURGE_OUT))
	if want > 0.0: meter = maxf(0.0,meter-delta/SURGE_TIME)
	plane.surge = surge
	return out

## A channel's tracker this frame; true when its moment just turned (scored
## by the caller).
func _track(t: Tracker, clear: float, reach: float, speed: float, game: Node3D) -> bool:
	if not bool(game.hand_landing.flying()):
		t.cancel()
		return false
	if not t.active:
		if not t.armed:
			t.armed = clear >= reach
			return false
		if clear < reach:
			t.start(clear)
			t.speed = speed
			t.roll = LineMoves.roll_of(game.plane)
		return false
	if clear < t.least:
		t.least = clear
		t.speed = speed
		t.roll = LineMoves.roll_of(game.plane)
		return false
	var back := maxf(HYST*WorldScale.span,HYST_SHARE*t.least)
	if clear > t.least+back or clear >= reach:
		t.active = false
		return true
	return false

## A moment of `kind` scored from tracker `t`, named for how it was flown
## (LineMoves `dress`), chained, the speed kicked.
func _moment(kind: String, t: Tracker, reach: float, cruise: float, out: Dictionary, game: Node3D) -> void:
	if t.speed < FAST_FROM*cruise: return
	var k := clampf(1.0-maxf(t.least,0.0)/reach,0.0,1.0)
	var points := float(BASE[kind])*(1.0+CLOSE_GAIN*k*k)*edge(t.least)*clampf(t.speed/cruise,0.5,2.0)
	if kind == "pull-out": points *= minf(1.0+pow(maxf(t.closing,0.0)/(CLOSING_REF*_pace(game)),1.5),CLOSING_TOP)
	var band := "razor" if t.least < RAZOR*WorldScale.span else ("close" if t.least < CLOSE*WorldScale.span else "near")
	var m := {"kind":kind,"band":band,"points":points,"k":k,"clear":t.least,"at":t.at,"surface":t.surface,
		"closing":t.closing,"speed":t.speed,"under":t == _pass or t == _gate,"roll":t.roll,"id":t.id}
	# A gap measured on both sides: its opening, wall to wall.
	if t == _stone and t.sides == 3 and t.wl < INF and t.wr < INF: m.width = t.wl+t.wr+WorldScale.span
	if t == _shot: m.shot = true
	moves.dress(m,game,cruise)
	var farm := 1.0 if t == _shot else _farm(t.at,t.id)
	m.points = float(m.points)*farm
	m.farm = farm
	_chain(m,out,game)
	game.plane.speed = float(game.plane.speed)+lerpf(KICK.x,KICK.y,k)

## A move into the chain: its points, its difficulty into the multiplier
## (cut by the farming cut and its repeats, a new kind's NEW_KIND on top), the
## bank put off; the frame's "near" (with `step`, what it added).
func _chain(m: Dictionary, out: Dictionary, _game: Node3D) -> void:
	if _line_moment(m,_game):
		if line_new:
			_chain_line(m,out)
			return
	elif line_new: return
	m.t = clock
	var kind := str(m.kind)
	var n := int(_kinds.get(kind,0))
	var step := float(m.get("diff",DIFF_PLAIN))*float(m.get("farm",1.0))/(1.0+n)
	if n == 0 and chain_count > 0: step += NEW_KIND
	_kinds[kind] = n+1
	m.step = step
	chain_mult += step
	chain_points += float(m.points)
	chain_count += 1
	bank_left = BANK_AFTER
	total += float(m.points)
	last = m
	moments.append(m)
	line_moments.append(m)
	if not m.has("shot"): _recent.append({"at":m.at,"t":clock,"id":int(m.get("id",0))})
	out["near"] = m

## The line banked for `points` (after the multiplier): {points, mult,
## moves (kinds in order), glyphs and bands (near_glyphs.gd ids, for the
## badges), terrain (the land crossed, repeats run together), t (first
## move to last, s), kinds, name (LineMoves `name_for`), money}. Paid by
## `game.book` (PilotBook `line_banked`), which also tries each thread's
## clearance as the tightest gap.
func _line(points: float, game: Node3D) -> Dictionary:
	var mult := multiplier()
	var kinds: Array = []
	var glyphs: Array = []
	var bands: Array = []
	var land: Array = []
	for m: Dictionary in line_moments:
		kinds.append(str(m.kind))
		glyphs.append(Glyphs.for_moment(m))
		bands.append(str(m.band))
		var here := str(m.get("terrain",""))
		if here != "" and (land.is_empty() or land[-1] != here): land.append(here)
	var t := 0.0
	if line_moments.size() > 1: t = float(line_moments[-1].t)-float(line_moments[0].t)
	var line := {"points":points,"mult":mult,"moves":kinds,"glyphs":glyphs,"bands":bands,"terrain":land,
		"t":t,"kinds":_kinds.size(),"name":LineMoves.name_for(_kinds.size(),mult),"money":0}
	if line_new:
		# How the line was built, for the bank's recap.
		var shape: Array = []
		for run: Dictionary in score_line.runs: shape.append({"name":LineScoreS.Line.label(run),"flourish":bool(run.flourish)})
		if shape.is_empty() and not line_moments.is_empty(): shape.append({"name":str(line_moments[-1].kind).to_upper(),"flourish":false})
		line.shape = shape
		line.raw = chain_points
		# Its numbers: the closest pass (m, INF with none) and the average speed (m/s).
		var closest := INF
		var flown := 0.0
		for m: Dictionary in line_moments:
			flown += float(m.get("flown",0.0))
			closest = minf(closest,float(m.clear))
		line.closest = closest
		line.speed = flown/maxf(line_moments.size(),1)
	var book = game.get("book")
	if book != null:
		book.line_banked(line)
		for m: Dictionary in line_moments:
			if str(m.get("of",m.kind)) == "thread": book.best("tightest_gap",maxf(float(m.clear),0.0))
	return line

## The prize `z` as a line, its money paid.
func _prize_line(z: Dictionary, game: Node3D) -> Dictionary:
	var line := {"points":z.points,"mult":1.0,"moves":["prize"],"glyphs":[Glyphs.for_moment({"kind":"thread"})],"bands":["razor"],
		"terrain":[],"t":0.0,"kinds":1,"name":z.title,"money":0}
	var book = game.get("book")
	if book != null:
		line.money = book.line_pay(float(z.points),1.0,1)
		book.earn(int(line.money))
	return line

## The edge's gain for a least clearance of `least` m (see the header).
static func edge(least: float) -> float:
	var span := WorldScale.span
	return maxf((EDGE+EDGE_SOFT)*span/(maxf(least,0.0)+EDGE_SOFT*span),1.0)

## The plane's pace (scripts/flight_pace.gd): PULL_MIN and CLOSING_REF are
## times it, so a dive at the same angle grades the same at any pace.
static func _pace(game: Node3D) -> float:
	var p: Variant = game.plane.get("pace_scale")
	return maxf(float(p),0.1) if p != null else 1.0

## The farming cut for a moment at `at` on surface `id`: less for every
## recent one near it, and less again for the same surface.
func _farm(at: Vector3, id: int) -> float:
	var near := 0
	var same := false
	var keep: Array[Dictionary] = []
	for r: Dictionary in _recent:
		if clock-float(r.t) > FARM_TIME: continue
		keep.append(r)
		if (r.at as Vector3).distance_to(at) < FARM_RADIUS: near += 1
		if int(r.id) == id: same = true
	_recent = keep
	return 1.0/(1.0+FARM_EACH*near)*(FARM_SAME if same else 1.0)

# --- The line's score (scripts/endless/line_score.gd) ----------------------------

## Scores moment `m` the line's way into `score_line` and writes its log row;
## m gets units, factors, tags, run, run_n, flourish, filler and line_step. False for a
## kind the line's score skips (the slalom: its trees are a run of grazes already).
func _line_moment(m: Dictionary, game: Node3D) -> bool:
	var t := LineScoreS.tune()
	var kind := str(m.get("of",m.kind))
	if kind in (t.skip as Array): return false
	var plane = game.plane
	var cruise := maxf(float(plane.cruise()),1.0)
	var at: Vector3 = m.at
	var land := float(game.field.height(at.x,at.z)) if game.field != null else -INF
	var raw := {"k":float(m.get("k",0.0)),"speed":float(m.get("speed",float(m.get("pace",1.0))*cruise)),
		"cruise":cruise,"top":float(plane.boost_speed()),
		"roll_deg":rad_to_deg(float(m.get("roll",LineMoves.roll_of(plane)))),
		"height":at.y-maxf(land,float(game.water_at(at))),"under":bool(m.get("under",false))}
	var f := LineScoreS.factors(raw)
	var hold := minf(float(m.held)/maxf(float(m.get("held_min",1.0)),0.001),float(t.hold_top)) if m.has("held") else 1.0
	var farm := 1.0 if m.has("shot") else _farm_same(int(m.get("id",0)))
	var units := LineScoreS.moment_units(kind,str(m.band),f,hold,farm)
	var now := snappedf(clock,0.001)
	if score_line.count == 0: line_id += 1
	var got := score_line.add({"kind":kind,"surface":str(m.surface),"move":str(m.kind),"band":str(m.band),"t":now,"units":units,"fast":f.fast,"product":f.product})
	m.units = units
	m.factors = f
	m.tags = LineScoreS.tags(f)
	m.run = int(got.run)
	m.run_n = int(got.run_n)
	m.flourish = bool(got.flourish)
	m.filler = bool(got.filler)
	m.flown = raw.speed
	m.line_step = float(got.step)
	LineLogS.write({"row":"moment","t":now,"line":line_id,"kind":kind,"move":str(m.kind),"surface":str(m.surface),
		"band":str(m.band),"k":raw.k,"clear":float(m.get("clear",INF)),"speed":raw.speed,"cruise":raw.cruise,"top":raw.top,
		"closing":float(m.get("closing",0.0)),"roll_deg":raw.roll_deg,"height":raw.height,"under":raw.under,
		"width":float(m.get("width",INF)),"hold":hold,"farm":farm,"f_close":f.close,"f_fast":f.fast,"f_knife":f.knife,
		"f_low":f.low,"f_under":f.under,"product":f.product,"points":units,"run":m.run,"run_n":m.run_n,
		"flourish":m.flourish,"mult":score_line.mult,"line_total":score_line.total(),"old_points":float(m.points)})
	return true

## The new score's chain: the moment's points (units x points_per_unit), the
## line's raw sum (moments and run bonuses) as the chain's points, the bank put
## off; the frame's "near" (`step` the flourish's step).
func _chain_line(m: Dictionary, out: Dictionary) -> void:
	var ppu := float(LineScoreS.tune().points_per_unit)
	m.t = clock
	m.old_points = float(m.points)
	m.points = float(m.units)*ppu
	m.step = float(m.line_step)
	var before := chain_points
	chain_points = score_line.raw()*ppu
	chain_mult = score_line.mult
	_kinds[str(m.kind)] = int(_kinds.get(str(m.kind),0))+1
	chain_count += 1
	bank_left = bank_after()
	total += chain_points-before
	last = m
	moments.append(m)
	line_moments.append(m)
	if not m.has("shot"): _recent.append({"at":m.at,"t":clock,"id":int(m.get("id",0))})
	out["near"] = m

## The same-spot cut: farm_same when a moment on the same tree, ruin or patch
## of land was scored within FARM_TIME s.
func _farm_same(id: int) -> float:
	for r: Dictionary in _recent:
		if clock-float(r.t) <= FARM_TIME and int(r.id) == id: return float(LineScoreS.tune().farm_same)
	return 1.0

## The line under way ends (banked, lost, reset): its log row, and the line
## scored afresh.
func _end_line() -> void:
	if score_line.count > 0:
		LineLogS.write({"row":"end","t":snappedf(clock,0.001),"line":line_id,"mult":score_line.mult,
			"line_total":score_line.total(),"reason":_end_reason})
	score_line = LineScoreS.Line.new()
	_end_reason = "banked"
