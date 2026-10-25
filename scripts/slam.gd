extends RefCounted
## The slam's push: a hit's ring heard by everything in GROUP. The walker's
## slam that sent it (his height cashed in as impact, docs/design/slam/
## round2.md) went with the pilot on foot and is whole at the tag
## archive/before-the-cut; what stays is the contract the floating slabs,
## the swing ropes, the loose leaves, the hung stair and the breakables
## hubs answer, for whatever hits next.
##
## Everything in GROUP hears `slam(at, radius, strength)` once (`blast`):
## `at` where it hit, `radius` the ring's reach (m), `strength` 0..1. Each
## decides for itself with `share` (1 at the heart, falling off FALLOFF to
## the rim, 0 past it or more than REACH_UP of the radius over or under)
## and `way` (out and down from the heart). A hit's power by its drop (m)
## is `power_for`, as the walker's was: DROP.x (0) to DROP.y (1, full); by
## it go the ring's RADIUS and the push's STRENGTH; `decent` is a DECENT m
## drop's strength, what turns the hung stair.

## The group whatever the slam pushes joins (see the header).
const GROUP := &"slam"
## The breakables hubs' group (scripts/breaks/breakables.gd HUBS).
const HUBS := &"breakables_hub"

const DROP := Vector2(1.8,11.0)  # m of drop: the weakest hit, and full
const DECENT := 4.0              # m of drop that opens a buried find, drops the cowl
const RADIUS := Vector2(2.4,8.5)        # m it reaches, weakest and full
const STRENGTH := Vector2(0.25,1.0)     # its strength, weakest and full
const FALLOFF := 0.6             # share of the push lost at the rim
const DOWN := 0.45               # down-share of the push's way (before normalising)
const REACH_UP := 0.6            # share of the radius it reaches over and under the heart

## The hit's power (0..1) for a drop of `drop` m by a walker `size` big.
static func power_for(drop: float, size := 1.0) -> float:
	return clampf((drop/size-DROP.x)/(DROP.y-DROP.x),0.0,1.0)

## How hard it pushes at power `p` (STRENGTH), and how far (m, RADIUS at
## size `size`).
static func strength_for(p: float) -> float:
	return lerpf(STRENGTH.x,STRENGTH.y,p)

static func radius_for(p: float, size := 1.0) -> float:
	return lerpf(RADIUS.x,RADIUS.y,p)*size

## The least strength that breaks a buried find open or drops the cowl: a
## DECENT m drop's.
static func decent() -> float:
	return strength_for(power_for(DECENT))

## The push: every node in GROUP hears `slam(at, radius, strength)`. How
## many did. Anything may call it (a test, a future hit).
## Breakable pieces (the city kit's, kit pieces) are not in GROUP: the
## breakables hub (scripts/breaks/breakables.gd, group HUBS) takes it as
## `hit(at, radius, strength, &"slam")`, so its `slam` toggle decides, and
## its count of what broke is added.
static func blast(tree: SceneTree, at: Vector3, radius: float, strength: float) -> int:
	if tree == null: return 0
	var n := 0
	for node: Node in tree.get_nodes_in_group(GROUP):
		if not is_instance_valid(node) or not node.has_method("slam"): continue
		node.slam(at,radius,strength)
		n += 1
	for hub: Node in tree.get_nodes_in_group(HUBS):
		if is_instance_valid(hub) and hub.has_method("hit"): n += int(hub.hit(at,radius,strength,&"slam"))
	return n

## A point's share of a slam at `at`, `radius` round: 1 at the heart,
## 1-FALLOFF at the rim, 0 past it or more than REACH_UP of the radius over
## or under.
static func share(at: Vector3, radius: float, point: Vector3) -> float:
	var flat := Vector2(point.x-at.x,point.z-at.z).length()
	if radius <= 0.0 or flat > radius or absf(point.y-at.y) > radius*REACH_UP: return 0.0
	return 1.0-FALLOFF*flat/radius

## The way it pushes at `point`: out from `at` and down (straight down
## under the heart).
static func way(at: Vector3, point: Vector3) -> Vector3:
	var out := Vector3(point.x-at.x,0.0,point.z-at.z)
	if out.length() < 0.05: return Vector3.DOWN
	return (out.normalized()+Vector3.DOWN*DOWN).normalized()
