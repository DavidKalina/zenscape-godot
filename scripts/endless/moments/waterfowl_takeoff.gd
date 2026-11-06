extends "res://scripts/endless/moments/moment.gd"
## The waterfowl takeoff: the plane takes off near water (the inlet by the
## start, a lake, a river) and a few ducks on the water ahead, or a heron in
## the shallows, run along the surface and lift off away from the plane
## (scripts/endless/waterfowl.gd, flushed by scripts/endless/life_reacts.gd).
## It looks for water ahead of the plane (in view) as the wheels leave; it
## fires more near the start, so a session's first takeoff tends to show it.
## --happen=waterfowl forces it; --fowl=duck or --fowl=heron picks the birds
## (a heron needs shallows: none, ducks). The birds sit tight, watching the
## plane come, and go as it nears (waterfowl.gd): it looks for them off to
## one side of the plane's line, where the chase camera sees them beside
## the plane, not hidden behind it.

const Waterfowl = preload("res://scripts/endless/waterfowl.gd")
const Where = preload("res://scripts/endless/moments/where.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The placed site by the start's inlet, and how near it (or the start) the
## chance is START_CHANCE.
const INLET := "wild/inlet_wreck"
const START_REACH := 600.0
const START_CHANCE := 0.9
## Where it looks for water: these distances out (m), nearest first, in
## ANGLES ways spread SPREAD rad either side of the plane's way.
const RADII: Array[float] = [30.0,45.0,60.0,80.0,100.0,125.0,150.0,180.0,210.0,245.0,280.0,320.0]
const ANGLES := 11
const SPREAD := 1.3
## The spot's score is its distance plus SIDE_W x how far it is from SIDE m
## off the plane's line (beside the plane as it passes: dead ahead, the
## plane hides them from the camera behind it), plus SIDE_W x how far short
## it is of NEAREST m along the line (abeam at once, they go unseen).
const SIDE := 25.0
const SIDE_W := 2.0
const NEAREST := 40.0
## The birds' way off: straight away from the plane plus this much of its
## way (more, and they race on ahead of a slow plane; less, and they cross
## its view going off to the side).
const LEAN := 0.8
## Water at least this deep (m) holds a bird; a heron wants it shallower
## than SHALLOW; ducks deeper than DUCKS_DEEP if they can have it.
const WET := 0.08
const SHALLOW := 0.6
## How far (m) round a spot must be water too, so it isn't a puddle's edge.
const OPEN := 3.0
## The run's way: tried this far along (m) in RUN_STEP steps, at these turns
## (rad) off the way it leans to; the longest wet run wins.
const RUN_LOOK := 16.0
const RUN_STEP := 2.0
const RUN_TURNS: Array[float] = [0.0,0.4,-0.4,0.8,-0.8]
## How many ducks.
const DUCKS_FEW := 4
const DUCKS_MOST := 7

## The water found by the last `unfit`: {at (the surface), bed, depth, way, off (m off the plane's line)}.
var spot := {}
## The birds running now.
var fowl: Node3D = null
## DUCK, HERON or &"" (the roll picks): --fowl=, or a driver.
var kind_wanted := &""

func _init() -> void:
	name = &"waterfowl"
	cue = &"lifted"
	hours = Vector2(5.5,20.5)
	chance = 0.25
	cooldown = 600.0
	var f := _fowl_flag()
	if f == "duck" or f == "heron": kind_wanted = StringName(f)

static func _fowl_flag() -> String:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--fowl="): return a.get_slice("=",1)
	return ""

func unfit(ctx: Dictionary, game: Node) -> String:
	var why := super.unfit(ctx,game)
	if why != "": return why
	spot = water_ahead(game,ctx.at,ctx.forward)
	return "" if not spot.is_empty() else "no water within %.0f m ahead" % RADII.back()

func chance_at(ctx: Dictionary, game: Node) -> float:
	var at: Vector3 = ctx.at
	var start: Variant = game.get("_start")
	if start is Vector2 and Vector2(at.x,at.z).distance_to(start) <= START_REACH: return START_CHANCE
	return START_CHANCE if Where.near_site(INLET,START_REACH).call(ctx,game) == "" else chance

func start(ctx: Dictionary, game: Node) -> void:
	var at: Vector3 = ctx.at
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|waterfowl|%d|%d" % [int(game.get("seed")),roundi(at.x),roundi(at.z)]).hash()
	var shallow := float(spot.depth) < SHALLOW
	var kind := Waterfowl.DUCK
	if kind_wanted == Waterfowl.HERON and shallow: kind = Waterfowl.HERON
	elif kind_wanted == &"" and shallow and rng.randf() < 0.5: kind = Waterfowl.HERON
	fowl = Waterfowl.new()
	game.add_child(fowl)
	fowl.setup(game,spot,kind,rng.randi_range(DUCKS_FEW,DUCKS_MOST),rng.randi())
	print("[happen] waterfowl: %d %s at (%.0f, %.1f, %.0f), %.1f m deep, %.0f m off, %.0f m off the line" % [fowl.birds.size(),kind,
		float(spot.at.x),float(spot.at.y),float(spot.at.z),float(spot.depth),Vector2(at.x,at.z).distance_to(Vector2(spot.at.x,spot.at.z)),float(spot.off)])

func step(delta: float, game: Node) -> bool:
	return fowl != null and is_instance_valid(fowl) and fowl.step(delta,game)

func finish(_game: Node) -> void:
	if fowl != null and is_instance_valid(fowl): fowl.queue_free()
	fowl = null

## The open water ahead of `at` (within SPREAD of flat way `forward`) with
## the least `score_of`: near, SIDE m off the plane's line, not abeam already.
## {at (its surface), bed, depth, way (the flat way its birds run off: off
## the plane, leaning along its way so they fly on in view), off}, or {}.
static func water_ahead(game: Node, at: Vector3, forward: Vector3) -> Dictionary:
	var fwd := Vector3(forward.x,0.0,forward.z).normalized()
	var best := {}
	var best_score := INF
	for r: float in RADII:
		if r >= best_score: break
		for i in ANGLES:
			# 0, +1, -1, +2, -2 ... steps of SPREAD/(ANGLES/2) either side.
			var k := floori((i+1)*0.5)*(1 if i%2 == 1 else -1)
			var turn := SPREAD*float(k)/(float(ANGLES-1)*0.5)
			var score := score_of(r,turn)
			if score >= best_score: continue
			var dir := fwd.rotated(Vector3.UP,turn)
			var p := at+dir*r
			var w := _water(game,p)
			if w.y-w.x < WET: continue
			var open := true
			for j in 4:
				var q := p+Vector3(cos(j*PI*0.5),0.0,sin(j*PI*0.5))*OPEN
				var wq := _water(game,q)
				if wq.y-wq.x < WET*0.5:
					open = false
					break
			if not open: continue
			best_score = score
			best = {"at":Vector3(p.x,w.y,p.z),"bed":w.x,"depth":w.y-w.x,"way":_run_way(game,p,(dir+fwd*LEAN).normalized()),
				"off":r*absf(sin(turn))}
	return best

## A spot `r` m out at `turn` rad off the plane's way: lower is better (at
## least `r`, so the search stops once its distances pass the best score).
static func score_of(r: float, turn: float) -> float:
	var side := r*absf(sin(turn))
	var along := r*cos(turn)
	return r+SIDE_W*absf(side-SIDE)+SIDE_W*maxf(NEAREST-along,0.0)

## (land, water) heights under `p`'s x, z.
static func _water(game: Node, p: Vector3) -> Vector2:
	var land: float = game.field.height(p.x,p.z)
	var w: float = game.water_at(Vector3(p.x,land,p.z),land)
	return Vector2(land,w)

## The flat way from `p` with the longest run of water, of the ways round
## `away` in RUN_TURNS.
static func _run_way(game: Node, p: Vector3, away: Vector3) -> Vector3:
	var best := away
	var best_run := -1.0
	for turn: float in RUN_TURNS:
		var way := away.rotated(Vector3.UP,turn)
		var run := 0.0
		while run < RUN_LOOK:
			var w := _water(game,p+way*(run+RUN_STEP))
			if w.y-w.x < WET*0.5: break
			run += RUN_STEP
		if run > best_run+0.5:
			best = way
			best_run = run
	return best
