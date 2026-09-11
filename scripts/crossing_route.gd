class_name CrossingRoute
extends RefCounted
## A link between two grounds, and the walk across it.
##
## Each `CampsiteWorld` owns one `creature_navigation.gd` grid clamped to its
## own document -- plus or minus 14 m in its own frame -- so no path request can
## ever leave the ground it was asked on. A bridge is the one thing that joins
## two of them, and this is that join: the two bridgeheads, the shore each
## stands on, and a callable that answers where the live, physics-driven deck is
## at `t`.
##
## Everything here is world space. The two shores disagree about what local
## means (the far island is turned 180 degrees and carried across the chasm),
## and the deck belongs to neither, so a route that changed frames halfway would
## have to say so at every step. `plan()` converts into each shore's frame only
## to ask it for a grid path, and converts straight back.
##
## A plan is a flat array of steps, in order:
##   `{"space": "ground", "world": CampsiteWorld, "point": Vector3}`
##   `{"space": "deck", "world": null, "t": float, "point": Vector3}`
## Deck points are a snapshot: the deck sways, so a walker must re-read them
## through `point_of()` every frame rather than trusting the stored one. That is
## what `crossing_walk.gd` does, and why it exists.
##
## A link can exist before it is usable. `open_when` is the gate: while it says
## no -- a bridge still being planked -- `plan()` answers with nothing, which is
## the honest answer and the one every caller already handles. The link itself
## stays, because the half-built deck is still somewhere a builder walks out
## along; `plan_to_deck` and `plan_from_deck` are ungated for exactly that, and
## go no further than the caller's `t`.
##
## Vocabulary from `docs/world-progression/LINKS.md`: a link is a real edge
## between two things that already exist, not prose about one. This edge is the
## only reason a walker on one island can have a destination on the other.

## Metres between deck waypoints. Short enough that a walker tracks the sag and
## the sway rather than cutting a chord through them, long enough that a 50 m
## span is two dozen steps and not five hundred.
const DECK_STRIDE := 2.0
## How far off the deck centreline a foot may be before the probe calls it air.
##
## Wider than the boards, on purpose. The deck bows downwind -- the study
## measures 0.42 m under rain and 1.10 m under a storm -- and a walker between
## two waypoints is standing where the deck *was*. Refusing him ground there is
## a trap: `walk_step` stops him, and a stopped walker never catches the deck up
## again. So the lane is wide enough to cover a full storm's bow with room over,
## and a walker further out than this really has been thrown off.
const DECK_LANE := 3.0
## Close enough to a waypoint to count as standing on it.
const REACHED := 0.06
## The bridgehead sits on the rim, past where `creature_navigation.gd` stops
## calling ground safe, and on a wooded island the pocket it stands in can be
## cut off from the grid entirely (the study's `_clear_trail` opens the way
## visually; the habitat does not always agree). So the last stretch onto the
## boards is walked off the grid, on the heightfield alone, for at most this far
## -- the anchor search has already proved that ground walkable, and beyond this
## the honest answer is that there is no crossing.
const APPROACH_REACH := 4.5
const APPROACH_STRIDE := 1.0
## Grid nodes tried for a way to the bridgehead before the approach gives up.
const APPROACH_PROBES := 400
## How finely `deck_t_at` samples the curve before bisecting. Twenty-four
## samples and six halvings put it inside a centimetre on a fifty metre span.
const DECK_SAMPLES := 24
const DECK_REFINEMENTS := 6

## The shore at deck `t` = 0, and the shore at `t` = 1.
var near: CampsiteWorld
var far: CampsiteWorld
## Bridgehead positions, world space, as `bridge_anchors()` gave them.
var anchor_near := Vector3.ZERO
var anchor_far := Vector3.ZERO
## `t` -> the live walking surface, world space. The study's `deck_surface()`.
var deck: Callable
## `-> bool`: is the way across finished? Unset means yes, which is what every
## caller that never heard of construction gets.
var open_when := Callable()
## Why not, when `crossable()` says no. For a study to print.
var closed_reason := "the bridge is unfinished"
## `_reachable_near` answers, per shore.
var _approach_cache := {}

## The link, or null when there is no bridge to make one out of.
static func link(near_world: CampsiteWorld, far_world: CampsiteWorld, anchors: Array[Transform3D], deck_at: Callable, open_when := Callable()) -> CrossingRoute:
	if near_world == null or far_world == null or anchors.size() != 2 or not deck_at.is_valid():
		return null
	if near_world.navigation == null or far_world.navigation == null:
		return null
	var route := CrossingRoute.new()
	route.near = near_world
	route.far = far_world
	route.anchor_near = anchors[0].origin
	route.anchor_far = anchors[1].origin
	route.deck = deck_at
	route.open_when = open_when
	return route

## Is there a way across today? False while the deck is still being laid.
func crossable() -> bool:
	return not open_when.is_valid() or bool(open_when.call())

## The other end of the link from `world`, or null when `world` is not on it.
func other(world: CampsiteWorld) -> CampsiteWorld:
	if world == near: return far
	if world == far: return near
	return null

func joins(world: CampsiteWorld) -> bool:
	return world == near or world == far

## The bridgehead on `world`'s own rim, world space.
func anchor_on(world: CampsiteWorld) -> Vector3:
	return anchor_near if world == near else anchor_far

## `t` at `world`'s end of the deck: 0 at the near shore, 1 at the far one.
func edge_of(world: CampsiteWorld) -> float:
	return 0.0 if world == near else 1.0

func span() -> float:
	return anchor_near.distance_to(anchor_far)

## The live boards at `t`, world space.
func deck_point(t: float) -> Vector3:
	return deck.call(clampf(t, 0.0, 1.0))

## Where a step really is this frame: stored for ground, re-read for the deck.
func point_of(step: Dictionary) -> Vector3:
	return deck_point(float(step.t)) if step.space == "deck" else step.point

## A ground probe for one step, in world space: the shore's own heightfield, or
## the boards. `creature_actor.gd` takes exactly this shape -- a world point in,
## a world point with an honest Y out, or null for "there is nothing there".
func probe_of(step: Dictionary) -> Callable:
	if step.space == "deck": return deck_probe()
	var world: CampsiteWorld = step.world
	return world.ground_probe()

## The deck as ground. `t` comes from the walker's own position rather than the
## step it is heading for, so a foot halfway between two waypoints stands on the
## boards under it and not on the ones it is aiming at.
func deck_probe() -> Callable:
	return func(point: Vector3) -> Variant:
		if not point.is_finite(): return null
		var on := deck_point(deck_t_at(point))
		if Vector2(point.x - on.x, point.z - on.z).length() > DECK_LANE: return null
		return Vector3(point.x, on.y, point.z)

## Where along the span a world point lies.
##
## Not a projection onto the chord. The boards are a polyline of physics
## segments and `t` is spread over its points, not over its length -- the last
## interval runs from a segment's centre out to the anchor and is twice its
## neighbours -- so the chord's `t` and `deck_point()`'s `t` name different
## places on the same deck. A walker probing one while aiming at the other stops
## a third of a metre above the boards and never arrives, which is exactly what
## it did. Sampled along the real curve instead, then bisected.
func deck_t_at(point: Vector3) -> float:
	var best := 0.0
	var closest := INF
	for i in range(DECK_SAMPLES + 1):
		var t := float(i) / float(DECK_SAMPLES)
		var gap := _flat_gap(point, t)
		if gap < closest:
			closest = gap
			best = t
	var reach := 1.0 / float(DECK_SAMPLES)
	for refinement in range(DECK_REFINEMENTS):
		reach *= 0.5
		for side: float in [-1.0, 1.0]:
			var t := clampf(best + side * reach, 0.0, 1.0)
			var gap := _flat_gap(point, t)
			if gap < closest:
				closest = gap
				best = t
	return best

func _flat_gap(point: Vector3, t: float) -> float:
	var at := deck_point(t)
	return Vector2(point.x - at.x, point.z - at.z).length_squared()

## The whole crossing, world space: grid path to the near bridgehead, the deck,
## grid path from the far one. `from_at` and `to_at` are world points; empty
## when either shore cannot reach its own bridgehead, which is the honest answer
## -- there is no crossing today.
func plan(from_world: CampsiteWorld, from_at: Vector3, to_world: CampsiteWorld, to_at: Vector3) -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	if from_world == null or to_world == null or other(from_world) != to_world: return empty
	if not crossable(): return empty
	var lead := _leg_to_anchor(from_world, from_at)
	if lead.is_empty(): return empty
	var tail := _leg_from_anchor(to_world, to_at)
	if tail.is_empty(): return empty
	var steps: Array[Dictionary] = []
	steps.append_array(lead)
	steps.append_array(_deck_leg(edge_of(from_world), edge_of(to_world)))
	steps.append_array(tail)
	return steps

## Out of `from_world` and along the deck as far as `to_t`, and no further: the
## walk a plank-layer takes to the end of what is built. Ungated -- the built
## prefix is real deck whether or not the crossing is finished -- and the
## caller is responsible for `to_t` being inside `built_extent()`.
func plan_to_deck(from_world: CampsiteWorld, from_at: Vector3, to_t: float) -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	if from_world == null or not joins(from_world): return empty
	var lead := _leg_to_anchor(from_world, from_at)
	if lead.is_empty(): return empty
	var steps: Array[Dictionary] = []
	steps.append_array(lead)
	steps.append_array(_deck_leg(edge_of(from_world), clampf(to_t, 0.0, 1.0)))
	return steps

## The mirror: back off the boards at `from_t` and inland to `to_at`.
func plan_from_deck(from_t: float, to_world: CampsiteWorld, to_at: Vector3) -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	if to_world == null or not joins(to_world): return empty
	var tail := _leg_from_anchor(to_world, to_at)
	if tail.is_empty(): return empty
	var steps := _deck_leg(clampf(from_t, 0.0, 1.0), edge_of(to_world))
	steps.append_array(tail)
	return steps

## Metres along a plan, deck included. INF for no plan.
static func length_of(steps: Array[Dictionary]) -> float:
	if steps.is_empty(): return INF
	var total := 0.0
	for i in range(1, steps.size()):
		total += Vector3(steps[i - 1].point).distance_to(steps[i].point)
	return total

## The walk inland-to-bridgehead: a grid path, then the anchor itself. The last
## stride is taken off the grid on purpose -- the bridgehead sits at the rim,
## where `_safe_grounded` starts refusing points, and the anchor search has
## already proved that stride walkable (`ANCHOR_STEP_OFF`).
func _leg_to_anchor(world: CampsiteWorld, from_at: Vector3) -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	var navigation: RefCounted = world.navigation
	var start: Variant = navigation.nearest_safe(world.to_local(from_at))
	if not start is Vector3: return empty
	var path := _path_to_head(world, start)
	if path.is_empty(): return empty
	var steps: Array[Dictionary] = []
	for point in path:
		steps.append(_ground_step(world, world.to_world(point)))
	steps.append_array(_step_off(world, world.to_world(path[-1]), anchor_on(world)))
	return steps

## The mirror: off the bridgehead and inland to `to_at`.
func _leg_from_anchor(world: CampsiteWorld, to_at: Vector3) -> Array[Dictionary]:
	var empty: Array[Dictionary] = []
	var navigation: RefCounted = world.navigation
	var goal: Variant = navigation.nearest_safe(world.to_local(to_at))
	if not goal is Vector3: return empty
	var path := _path_to_head(world, goal)
	if path.is_empty(): return empty
	path.reverse()
	var steps := _step_off(world, anchor_on(world), world.to_world(path[0]))
	for point in path:
		steps.append(_ground_step(world, world.to_world(point)))
	return steps

## A grid path from `start` to the bridgehead, or as near it as the grid gets.
## Document-local, `start` first. Empty when the grid cannot get within
## `APPROACH_REACH` of the bridgehead at all.
func _path_to_head(world: CampsiteWorld, start: Vector3) -> PackedVector3Array:
	var navigation: RefCounted = world.navigation
	var anchor_at: Vector3 = world.to_local(anchor_on(world))
	var head: Variant = navigation.nearest_safe(anchor_at)
	if head is Vector3:
		var direct: PackedVector3Array = navigation.path(start, head)
		if not direct.is_empty(): return direct
	var reached: Variant = _reachable_near(world, start, anchor_at)
	if not reached is Vector3: return PackedVector3Array()
	return navigation.path(start, reached)

## The nearest node to the bridgehead a walker at `start` can actually get to,
## within `APPROACH_REACH`. Cached per shore: the answer depends on the grid,
## not on who is asking, and the search is a few hundred A* queries.
func _reachable_near(world: CampsiteWorld, start: Vector3, anchor_at: Vector3) -> Variant:
	if _approach_cache.has(world): return _approach_cache[world]
	var navigation: RefCounted = world.navigation
	var nodes: Array[Vector3] = []
	for node in navigation._nodes:
		if node.distance_to(anchor_at) <= APPROACH_REACH: nodes.append(node)
	nodes.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(anchor_at) < b.distance_squared_to(anchor_at))
	var found: Variant = null
	for i in range(mini(APPROACH_PROBES, nodes.size())):
		if not navigation.path(start, nodes[i]).is_empty():
			found = nodes[i]
			break
	_approach_cache[world] = found
	return found

## The stretch between the grid and the boards, in strides, on the heightfield
## alone. Both ends are world space and both are kept.
func _step_off(world: CampsiteWorld, from_at: Vector3, to_at: Vector3) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var probe := world.ground_probe()
	var count := maxi(1, int(ceil(from_at.distance_to(to_at) / APPROACH_STRIDE)))
	for i in range(1, count + 1):
		var at := from_at.lerp(to_at, float(i) / float(count))
		var grounded: Variant = probe.call(at)
		steps.append(_ground_step(world, grounded if grounded is Vector3 else at))
	return steps

func _deck_leg(from_t: float, to_t: float) -> Array[Dictionary]:
	var count := maxi(2, int(ceil(span() * absf(to_t - from_t) / DECK_STRIDE)))
	var steps: Array[Dictionary] = []
	for i in range(count + 1):
		var t := lerpf(from_t, to_t, float(i) / float(count))
		steps.append({"space": "deck", "world": null, "t": t, "point": deck_point(t)})
	return steps

func _ground_step(world: CampsiteWorld, point: Vector3) -> Dictionary:
	return {"space": "ground", "world": world, "t": -1.0, "point": point}
