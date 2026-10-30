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
const RUN := 40.0
const REST := 6.0
## Open ground ahead: these distances along the heading (m) all dry land,
## sloping less than OPEN_UP (the normal's up) and rising at most OPEN_RISE m
## over the ground under the plane. (First light: rocks, ruins, trees and
## water come in later.)
const OPEN_AT := [0.0,35.0,70.0,105.0,140.0]
const OPEN_UP := 0.93
const OPEN_RISE := 10.0

var land: GameLand
var burrower: Burrower
var push_ups: PushUps
## The rouse: skim built (s), rest left (s), time over CLIMB_OFF (s), the
## last reasons, and counts (for drivers).
var _idle := 0
var rouse := {"skim": 0.0, "rest": 0.0, "high": 0.0, "why": "", "wakes": 0, "dives": 0, "blocked": ""}

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

## Why the land ahead of the plane won't do for a run ("" when open).
func open_ahead(game: Node3D) -> String:
	var p: Vector3 = game.plane.position
	var f: Vector3 = game.plane.forward()
	var fwd := Vector2(f.x,f.z).normalized()
	if fwd == Vector2.ZERO: return "heading"
	var here := land.height(p.x,p.z)
	for d: float in OPEN_AT:
		var at := Vector2(p.x,p.z)+fwd*d
		var h := land.height(at.x,at.y)
		if h < land.water_y(at.x,at.y)+0.3: return "water"
		if land.normal(at.x,at.y).y < OPEN_UP: return "steep"
		if h-here > OPEN_RISE: return "rise"
	return ""

func _rouse(delta: float, game: Node3D) -> void:
	rouse.rest = maxf(float(rouse.rest)-delta,0.0)
	var flying: bool = game.hand_landing.flying()
	if burrower.active and not burrower.diving():
		rouse.skim = 0.0
		var span: float = WorldScale.TOY_SPAN*game.ground_scale.size()
		rouse.high = float(rouse.high)+delta if float(game.near.ground_clear) > span*CLIMB_OFF else 0.0
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
	# The last two checks only when it would wake (they sample the land).
	var blocked := ""
	if absf(float(game.chase.free.x)) > LOOK_FREE: blocked = "look"
	else: blocked = open_ahead(game)
	rouse.blocked = blocked
	if blocked != "": return
	wake(game)

## Up now, leading the plane (a driver's, or the gate's).
func wake(game: Node3D) -> void:
	rouse.skim = 0.0
	rouse.high = 0.0
	rouse.wakes = int(rouse.wakes)+1
	burrower.lead(game.plane)
