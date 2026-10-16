extends RefCounted
## Toward the void: a shove
## on the walker (the Olmec's waves and swats, his head's blast) bent toward
## the nearest open edge, so a hit near a rim is the one that kills (the
## brief's rule 3) and one in the middle of a top is only a knock.
##
## Looked for by rays down off the field's ground (EnemyField
## `floor_under`), in WAYS directions either side of the shove's own, at
## STEPS out to VOID_REACH m: the first spot with no floor within DROP m
## under his feet is the void that way. The nearer the void, the more of
## `share` the shove turns to it; none found, the shove is as it was.

const WAYS := [0.0,0.5,-0.5,1.0,-1.0,1.5,-1.5]
const STEPS := [1.5,3.0,4.5,6.0,7.5,9.0]
const VOID_REACH := 9.0
const DROP := 4.0

## `way` (x, z, unit) bent toward the nearest void round `feet`.
static func toward(field: Node, feet: Vector3, way: Vector2, share: float) -> Vector2:
	var void_way := Vector2.ZERO
	var nearest := INF
	for a: float in WAYS:
		var w := way.rotated(a)
		for d: float in STEPS:
			if d >= nearest: break
			var p := feet+Vector3(w.x,0.0,w.y)*d
			if field.floor_under(p,1.5,DROP) == -INF:
				nearest = d
				void_way = w
				break
	if nearest == INF: return way
	var k := share*clampf(1.0-(nearest-1.5)/VOID_REACH,0.25,1.0)
	return way.lerp(void_way,k).normalized()

## The nearest void's way round `feet` and how far (m): [way, d] or [ZERO, INF].
static func nearest(field: Node, feet: Vector3) -> Array:
	var best := [Vector2.ZERO,INF]
	for i in range(12):
		var w := Vector2.from_angle(TAU*i/12.0)
		for d: float in STEPS:
			if d >= float(best[1]): break
			if field.floor_under(feet+Vector3(w.x,0.0,w.y)*d,1.5,DROP) == -INF:
				best = [w,d]
				break
	return best
