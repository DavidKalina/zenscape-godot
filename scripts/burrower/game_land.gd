extends "res://scripts/burrower/burrower_ground.gd"
## Endless flight's land as the burrower sees it (burrower_ground.gd): the
## land field's height and colour, the sea's and rivers' water
## (studies/endless_flight.gd `water_at`). No lists and no rim: it feels
## ahead with `open` (steep ground, and the game's rocks, sea stacks, arches,
## ruins, halls and tunnels; not trees, it runs through a forest), and `room` is
## 0 where it can't run (so a start, a resurfacing or a push-up there is
## passed over) and ROOM elsewhere.

const Field = preload("res://scripts/endless/land_field.gd")
const TreePlan = preload("res://scripts/endless/tree_plan.gd")

## The game (studies/endless_flight.gd): its `field` and `water_at`.
var game: Node3D

## Ground it runs up: the normal's up at least RUN_UP (~28 deg); water
## counts at any bed. Things are felt for PROBE_UP m over the ground or water.
const RUN_UP := 0.88
## Steeper than WALL_UP's up (~40 deg) is a wall: it sounds there.
const WALL_UP := 0.76
const PROBE_UP := 1.5
const ROOM := 1000.0

func _init() -> void:
	name = "BurrowerGround"
	probes = true

func setup(the_game: Node3D) -> void:
	game = the_game

func height(x: float, z: float) -> float:
	return game.field.height(x,z)

func colour(x: float, z: float, y: float, nm: Vector3) -> Color:
	return game.field.colour(x,z,y,nm.y,1.0)

## The sea's swell or a river's or lake's level (Field.SEA_Y and under on
## dry land, which is far over it).
func water_y(x: float, z: float) -> float:
	return game.water_at(Vector3(x,Field.SEA_Y,z))

## Not steep (or water) and clear of what stands on the land.
func open(at: Vector2) -> bool:
	var h := height(at.x,at.y)
	var w := water_y(at.x,at.y)
	if h >= w and normal(at.x,at.y).y < RUN_UP: return false
	return not blocked(at,maxf(h,w))

## Too steep to run on through, or something standing (not over water).
func wall(at: Vector2) -> bool:
	var h := height(at.x,at.y)
	var w := water_y(at.x,at.y)
	if h >= w and normal(at.x,at.y).y < WALL_UP: return true
	return blocked(at,maxf(h,w))

## Something standing at (x, z) a little over `y` (the ground or water
## there): a rock or sea stack, an arch's leg, a hall, a tunnel's mouth (as
## the game's `_blocked`, less trees: a run goes through a forest, spec
## "Through the forest"; weaving its trunks is that task's).
func blocked(at: Vector2, y: float) -> bool:
	var p := Vector3(at.x,y+PROBE_UP,at.y)
	return game.arches.inside(p) or game.rocks.inside(p) or game.halls.inside(p) or game.tunnels.inside(p)

## Under a tree's crown at (x, z) (the wake gate's forest test).
func wooded(at: Vector2, y: float) -> bool:
	return game.trees.inside(Vector3(at.x,y+PROBE_UP,at.y))

## How many standing trees lie in the strip `half` m to each side of the
## line from `at` along `fwd` (unit) for `length` m (the wake gate's forest
## test: the trees the game has stood, near the plane).
func trees_along(at: Vector2, fwd: Vector2, length: float, half: float) -> int:
	var end := at+fwd*length
	var lo := TreePlan.cell_of(minf(at.x,end.x)-half,minf(at.y,end.y)-half)
	var hi := TreePlan.cell_of(maxf(at.x,end.x)+half,maxf(at.y,end.y)+half)
	var n := 0
	for cz in range(lo.y,hi.y+1):
		for cx in range(lo.x,hi.x+1):
			var t: PackedFloat32Array = game.trees.cell_trees(Vector2i(cx,cz))
			for q in range(0,t.size(),8):
				if t[q+5] <= 0.0: continue
				var rel := Vector2(t[q]-at.x,t[q+1]-at.y)
				var along := rel.dot(fwd)
				if along < 0.0 or along > length: continue
				if absf(rel.dot(fwd.orthogonal())) <= half+t[q+6]: n += 1
	return n

func room(at: Vector2) -> float:
	return ROOM if open(at) else 0.0
