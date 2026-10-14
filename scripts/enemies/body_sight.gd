extends "res://scripts/dragon_sight.gd"
## The whole body's sight (docs/design/roguelike/whole-body-chase-round1.md):
## the dragon's (scripts/dragon_sight.gd, docs/design/dragon-vision/round1.md)
## at a walker's scale, its numbers set by the body's knobs instead of the
## dragon's constants. The same rays to the walker's feet, chest and head
## (`pilot_points`), the same share-seen falloffs, the same awareness meter
## and hysteresis (`next_state`: unaware, suspicious, spotted) and
## `state_changed`. Two differences: the cone is flat (`half` rad either side
## of its facing, any pitch: it stands a few walker heights over him and
## looks down at his feet), and the rays stop on the study's own ground
## (`mask`).

## The cone (m, rad), the distance falloff (fully seen within `near`,
## `far_seen` of it at `deep`), the rim's share (`edge_seen`).
var deep := 45.0
var half := 0.9
var near := 15.0
var far_seen := 0.3
var edge_seen := 0.6
## How plain he is on the ground and in the air.
var ground := 0.7
var air := 1.0
## Awareness: fill a second at visibility 1, grace unseen (s), drain a second.
var fill := 1.4
var grace := 1.0
var drain := 0.3
## What a ray stops on.
var mask := 1

## Its numbers from the body's knobs `k` (the `sight_*` ones).
func tune(k: Dictionary) -> void:
	deep = float(k.sight_range)
	half = float(k.sight_half)
	near = float(k.sight_near)
	fill = float(k.sight_fill)
	grace = float(k.sight_grace)
	drain = float(k.sight_drain)

## Whether `p` is in its flat cone from `from` along `way`, in range.
func sees_way(from: Vector3, way: Vector3, p: Vector3) -> bool:
	var to := p-from
	if to.length() > deep: return false
	var flat := Vector2(to.x,to.z)
	var fwd := Vector2(way.x,way.z)
	if flat.length() < 0.01 or fwd.length() < 0.01: return true
	return absf(fwd.angle_to(flat)) <= half

func look_at_pilot(space: PhysicsDirectSpaceState3D, from: Vector3, way: Vector3, pilot: PackedVector3Array, in_air: bool) -> float:
	eye = from
	look = Vector3(way.x,0.0,way.z).normalized() if Vector2(way.x,way.z).length() > 0.001 else Vector3.FORWARD
	points = pilot
	airborne = in_air
	seen.clear()
	visibility = 0.0
	seen_share = 0.0
	in_cone = false
	distance = INF
	if pilot.is_empty(): return 0.0
	var middle := Vector3.ZERO
	for p in pilot: middle += p
	middle /= float(pilot.size())
	distance = from.distance_to(middle)
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = mask
	ray.exclude = exclude
	var got := 0
	for p in pilot:
		var ok := sees_way(from,look,p)
		if ok:
			in_cone = true
			if space != null:
				ray.from = from
				ray.to = p
				ok = space.intersect_ray(ray).is_empty()
		seen.append(ok)
		if ok: got += 1
	seen_share = float(got)/float(pilot.size())
	if got == 0: return 0.0
	var flat := Vector2(middle.x-from.x,middle.z-from.z)
	var angle := absf(Vector2(look.x,look.z).angle_to(flat)) if flat.length() > 0.01 else 0.0
	var by_d := lerpf(1.0,far_seen,clampf((distance-near)/maxf(deep-near,0.01),0.0,1.0))
	var u := clampf(angle/maxf(half,0.01),0.0,1.0)
	visibility = seen_share*by_d*lerpf(1.0,edge_seen,u*u)*(air if in_air else ground)
	return visibility

func step(delta: float, vis: float) -> void:
	if vis > NOTICE:
		unseen_for = 0.0
		awareness = minf(1.0,awareness+fill*vis*delta)
	else:
		unseen_for += delta
		if unseen_for > grace: awareness = maxf(0.0,awareness-drain*delta)
	var now := next_state(state,awareness)
	if now != state:
		var was := state
		state = now
		state_changed.emit(now,was)

## Seen this frame (any of his points).
func seeing() -> bool:
	return visibility > NOTICE

## Back to unaware at once (a reset).
func clear() -> void:
	awareness = 0.0
	unseen_for = INF
	state = "unaware"
	visibility = 0.0
	seen.clear()
	points = PackedVector3Array()
