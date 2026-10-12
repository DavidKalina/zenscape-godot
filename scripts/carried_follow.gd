extends RefCounted
## The hover of things carried: where each rides round the pilot (from one
## side behind to the other) and the ease that takes it there. The plane
## arc's carried parts (scripts/plane_arc/plane_arc.gd) and the cannon's
## powder kegs (scripts/cannon/) both use it, so a keg hovers like a part.
const OUT := 0.62
const UP := 0.85
const SPREAD := 1.35
const BOB := 0.04
const EASE := 0.09

## The goal of item `k` of `n` round `at` (world), the pilot facing `way`
## (x, z), at the wanderer's `scale`; `clock` runs the bob.
static func goal(at: Vector3, way: Vector2, scale: float, k: int, n: int, clock: float, out := OUT, up := UP, spread := SPREAD, bob := BOB) -> Vector3:
	var ahead := Vector3(way.x,0.0,way.y)
	var right := Vector3(-way.y,0.0,way.x)
	var a := -1.0 if n == 1 else lerpf(-spread,spread,float(k)/(n-1))
	return at+(right*sin(a)-ahead*cos(a))*out*scale+Vector3.UP*(up+sin(clock*1.6+k)*bob)*scale

## `holder` eased to `target` (at once with `snap`, or past `jump` m away).
static func ease_to(holder: Node3D, target: Vector3, delta: float, snap: bool, jump: float, ease_time := EASE) -> void:
	if snap or delta <= 0.0 or holder.global_position.distance_to(target) > jump: holder.global_position = target
	else: holder.global_position = holder.global_position.lerp(target,1.0-exp(-delta/ease_time))
