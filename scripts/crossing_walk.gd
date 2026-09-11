class_name CrossingWalk
extends RefCounted
## One walker part-way across a `CrossingRoute`.
##
## The plan is a list of world-space steps; this is the cursor into it, plus the
## two things a walker has to ask every frame on a bridge that moves: where the
## next board is *now*, and what counts as ground under my feet *here*. Both
## change with the step, which is why neither can be cached by the caller.
##
## Two kinds of walker use it. Bigfoot has legs of his own -- `walk_step()` on
## `creature_actor.gd` takes a world destination and a ground probe -- so he
## reads `target()` and `probe()` and calls `advance()` when a waypoint is
## reached. A camper is a model whose position is simply assigned, so it hands
## its position to `carry()` and takes back the next one. Neither knows how many
## frames it is standing on.

var route: CrossingRoute
var steps: Array[Dictionary] = []
## The step being walked toward. Starts at 1: step 0 is where the walker stands.
var index := 1

static func along(crossing: CrossingRoute, plan: Array[Dictionary]) -> CrossingWalk:
	if crossing == null or plan.size() < 2: return null
	var walk := CrossingWalk.new()
	walk.route = crossing
	walk.steps = plan
	return walk

func finished() -> bool:
	return index >= steps.size()

func step() -> Dictionary:
	return steps[mini(index, steps.size() - 1)]

## The live world point to walk at.
func target() -> Vector3:
	return route.point_of(step())

## What is under the walker's feet on this step: the shore's heightfield, or the
## boards. Valid only while `index` is where it is.
func probe() -> Callable:
	return route.probe_of(step())

func on_deck() -> bool:
	return step().space == "deck"

## The ground this walker is standing on, or null over the chasm.
func shore() -> CampsiteWorld:
	return step().world

## The ground the walk ends on.
func destination_shore() -> CampsiteWorld:
	for i in range(steps.size() - 1, -1, -1):
		if steps[i].space == "ground": return steps[i].world
	return null

## How far across, 0 to 1, for a status line or a camera.
func progress() -> float:
	return clampf(float(index) / float(maxi(1, steps.size() - 1)), 0.0, 1.0)

## This waypoint is reached; take the next one. True when the walk is over.
func advance() -> bool:
	index += 1
	return finished()

## Move a walker that has no legs of its own. Returns the next world position:
## the caller assigns it and is done. Y comes from the step's own probe, so the
## camper rides the sag and the sway exactly as Bigfoot does.
##
## Horizontal distance decides both the stride and arrival, which is
## `creature_actor.walk_step`'s convention and has to be: the probe owns Y, so a
## walker whose feet the deck has lifted is still standing on its waypoint.
func carry(at: Vector3, speed: float, delta: float) -> Vector3:
	if finished(): return at
	var goal := target()
	var offset := goal - at
	var horizontal := Vector2(offset.x, offset.z).length()
	var travel := maxf(0.0, speed) * minf(delta, 0.05)
	if horizontal <= maxf(travel, CrossingRoute.REACHED):
		var landed: Variant = probe().call(goal)
		advance()
		return landed if landed is Vector3 else goal
	var next := at + offset * (travel / horizontal)
	var ground: Variant = probe().call(next)
	return ground if ground is Vector3 else next
