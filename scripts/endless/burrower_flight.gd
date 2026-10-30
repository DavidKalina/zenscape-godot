extends Node
## The burrower in endless flight (docs/design/endless-flight/
## spec-burrower-flight.md): the study's creature (scripts/burrower/
## burrower.gd) and its push-ups (push_ups.gd) on the game's land
## (scripts/burrower/game_land.gd), woken by a skim the player chose.
##
## It wakes only when all hold: the chase camera roughly forward (its free
## look within LOOK_FREE rad), NearMiss skimming for WAKE_SKIM s (built up,
## bled at twice the rate when not), open ground ahead (`open_ahead`), and
## REST s since the last run. Then it comes in from off screen at a side and
## runs to be chased; it dives after CLIMB_HOLD s over CLIMB_OFF spans, after
## RUN s, or when the plane lands or crashes. `--no-burrower` leaves it out.

const Burrower = preload("res://scripts/burrower/burrower.gd")
const PushUps = preload("res://scripts/burrower/push_ups.gd")
const GameLand = preload("res://scripts/burrower/game_land.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const LOOK_FREE := deg_to_rad(10.0)
const WAKE_SKIM := 1.2
const CLIMB_OFF := 5.0
const CLIMB_HOLD := 1.4
## In a wood the plane can't skim under the crowns, so high over the ground
## it stays on the run while within CANOPY_OFF spans over the tallest crown
## round the head (CANOPY_HEAD m) or the plane (CANOPY_PLANE m), and over a
## clearing the roof it last had for ROOF_HOLD s (time to drop back in).
const CANOPY_OFF := 4.0
const CANOPY_HEAD := 16.0
const CANOPY_PLANE := 24.0
const ROOF_HOLD := 3.0
const RUN := 40.0
const REST := 6.0
## Open ahead: at these distances along the heading (m), water, or land
## sloping less than OPEN_UP (the normal's up), rising at most OPEN_RISE m
## over the land or water under the plane; nothing standing (the land's
## `blocked`: rocks, sea stacks, ruins, halls, tunnels) there or OPEN_SIDE m
## to each side. A forest ahead is open: the run goes through it (with
## FOREST_OPEN false, FOREST_N trees in the strip shut it).
const OPEN_AT := [0.0,20.0,40.0,60.0,80.0,100.0,120.0,140.0,160.0]
const OPEN_SIDE := 12.0
const OPEN_UP := 0.93
const FOREST_OPEN := true
const FOREST_N := 4
const OPEN_RISE := 10.0

var land: GameLand
var burrower: Burrower
var push_ups: PushUps
## The rouse: skim built (s), rest left (s), time over CLIMB_OFF (s), the
## last reasons, and counts (for drivers).
var _idle := 0
## Time to the gate's next look at the land, once shut (s).
const ASK := 0.2
var _ask := 0.0
var _roof := -INF
var _roof_at := -INF
var rouse := {"skim": 0.0, "rest": 0.0, "high": 0.0, "why": "", "wakes": 0, "dives": 0, "blocked": "", "canopy": 0.0}

static func wanted() -> bool:
	return not "--no-burrower" in OS.get_cmdline_user_args()

func _init() -> void:
	name = "BurrowerFlight"

func setup(game: Node3D) -> void:
	land = GameLand.new()
	land.setup(game)
	add_child(land)
	burrower = Burrower.new()
	add_child(burrower)
	burrower.setup(land,game.react)
	burrower.view = game.camera
	push_ups = PushUps.new()
	add_child(push_ups)
	push_ups.setup(land,burrower)
	push_ups.taken.connect(_taken.bind(game))

## One frame: the gate (asleep, only that), the creature and its push-ups.
func step(delta: float, game: Node3D) -> void:
	_rouse(delta,game)
	# Asleep and all settled: nothing more a frame (a couple of frames on
	# after, so the last halo and mote are cleared).
	_idle = _idle+1 if burrower.settled() and push_ups.settled() else 0
	if _idle > 2: return
	var span: float = WorldScale.TOY_SPAN*game.ground_scale.size()
	burrower.tick(delta)
	push_ups.tick(delta,game.plane,span*0.5,false)

## A push-up taken: a move in the chain (LineMoves `push_up`), when the chain
## is running (NearMiss is stepped only then).
func _taken(kind: StringName, at: Vector3, game: Node3D) -> void:
	if game.plane.weighted and game.hand_landing.flying(): game.near.moves.push_up(str(kind),at,game)

## Why the land ahead of the plane won't do for a run ("" when open).
func open_ahead(game: Node3D) -> String:
	var p: Vector3 = game.plane.position
	var f: Vector3 = game.plane.forward()
	var fwd := Vector2(f.x,f.z).normalized()
	if fwd == Vector2.ZERO: return "heading"
	return open_from(Vector2(p.x,p.z),fwd)

## As `open_ahead`, from `at` along `fwd` (unit).
func open_from(at0: Vector2, fwd: Vector2) -> String:
	var here := maxf(land.height(at0.x,at0.y),land.water_y(at0.x,at0.y))
	for d: float in OPEN_AT:
		var at := at0+fwd*d
		var ground := land.height(at.x,at.y)
		var w := land.water_y(at.x,at.y)
		var h := maxf(ground,w)
		if ground >= w and land.normal(at.x,at.y).y < OPEN_UP: return "steep"
		if h-here > OPEN_RISE: return "rise"
		for s: float in [0.0,-1.0,1.0]:
			var off := at+fwd.orthogonal()*s*OPEN_SIDE
			var oh := h if s == 0.0 else land.height(off.x,off.y)
			if land.blocked(off,oh): return "blocked"
	if not FOREST_OPEN and land.trees_along(at0,fwd,OPEN_AT.back(),OPEN_SIDE) >= FOREST_N: return "forest"
	return ""

func _rouse(delta: float, game: Node3D) -> void:
	rouse.rest = maxf(float(rouse.rest)-delta,0.0)
	var flying: bool = game.hand_landing.flying()
	if burrower.active and not burrower.diving():
		rouse.skim = 0.0
		var span: float = WorldScale.TOY_SPAN*game.ground_scale.size()
		rouse.high = float(rouse.high)+delta if _clear(game) > span*CLIMB_OFF else 0.0
		var why := ""
		if not flying: why = "down"
		elif float(rouse.high) > CLIMB_HOLD: why = "climb"
		elif burrower._run > RUN: why = "run"
		if why != "":
			burrower.dive()
			rouse.why = why
			rouse.dives = int(rouse.dives)+1
			rouse.rest = REST
		return
	if burrower.active: return
	var skimming: bool = flying and game.near.skimming
	rouse.skim = clampf(float(rouse.skim)+(delta if skimming else -2.0*delta),0.0,WAKE_SKIM)
	if not skimming or float(rouse.skim) < WAKE_SKIM or float(rouse.rest) > 0.0: return
	# The last two checks only when it would wake (they sample the land),
	# and shut, again only every ASK s.
	_ask -= delta
	if _ask > 0.0: return
	_ask = ASK
	var blocked := ""
	if absf(float(game.chase.free.x)) > LOOK_FREE: blocked = "look"
	else: blocked = open_ahead(game)
	rouse.blocked = blocked
	if blocked != "": return
	wake(game)

## The plane's height for the climb-off: over the ground, or in a wood, in
## the same terms, over the crowns (only asked once high).
func _clear(game: Node3D) -> float:
	var clear := float(game.near.ground_clear)
	var span: float = WorldScale.TOY_SPAN*game.ground_scale.size()
	if clear <= span*CLIMB_OFF: return clear
	var p: Vector3 = game.plane.position
	var top := maxf(land.canopy_top(burrower.pos,CANOPY_HEAD),land.canopy_top(Vector2(p.x,p.z),CANOPY_PLANE))
	var now := Time.get_ticks_msec()*0.001
	if top > -INF:
		_roof = top
		_roof_at = now
	elif now-_roof_at < ROOF_HOLD: top = _roof
	if top == -INF: return clear
	rouse.canopy = float(rouse.canopy)+1.0
	return minf(clear,(p.y-top)*CLIMB_OFF/CANOPY_OFF)

## Up now, leading the plane (a driver's, or the gate's).
func wake(game: Node3D) -> void:
	rouse.skim = 0.0
	rouse.high = 0.0
	rouse.wakes = int(rouse.wakes)+1
	burrower.lead(game.plane)
