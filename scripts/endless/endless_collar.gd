extends RefCounted
## The collar: one standing ring of dense cloud round a place, apart from the
## cloud field (scripts/endless/endless_clouds.gd calls it; the march is
## shaders/endless_cloud_march.glsl, "The collar"). A flat slab between an
## inner and an outer radius and a band of heights, its noise turning slowly
## about its centre. It does not drift with the wind and `--cloud-cover`
## does not touch it; it stands in every world the scene plays.
##
## `EndlessClouds.set_collar(centre, radius, lo, hi)` puts it in
## (`clear_collar()` takes it out). `--collar=0` leaves it out whatever the
## scene asks; `--collar=x,z,radius,lo,hi` stands one at that spot for a still
## (the scene's own calls are then ignored).

const Field = preload("res://scripts/endless/land_field.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The turn (rad/s): about one round in 26 minutes.
const TURN := 0.004
## The ring's inner radius as a share of the outer, when not given.
const INNER_SHARE := 0.45
## The first of the march buffer's spare floats (spare[3]; scripts/endless/
## endless_clouds.gd _fill): the centre xz, outer and inner radius, then
## the base y, the top y (world), the turn and on.
const AT := 80

var on := false
var centre := Vector2.ZERO
var radius := 0.0
var inner := 0.0
## World heights.
var lo := 0.0
var hi := 0.0
var allowed := true
var forced := false

## Reads the launch flags: `--collar=0`, or `--collar=x,z,radius,lo,hi`.
func read_flags() -> void:
	for a: String in LaunchArgs.user_args():
		if not a.begins_with("--collar="): continue
		var v := a.get_slice("=", 1)
		if v == "0":
			allowed = false
			on = false
			return
		var p := v.split(",")
		if p.size() >= 5:
			forced = false
			set_ring(Vector2(p[0].to_float(), p[1].to_float()), p[2].to_float(), p[3].to_float(), p[4].to_float())
			forced = true

## A ring at `at` (xz; a Vector3's x and z), outer radius `outer` m, its base
## and top `base` and `top` m over the sea (SEA_Y), the hole `hole` m
## across the inside (default INNER_SHARE of the radius; 0 a whole disc).
func set_ring(at: Variant, outer: float, base: float, top: float, hole := -1.0) -> void:
	if not allowed or forced: return
	centre = Vector2(at.x, at.z) if at is Vector3 else Vector2(at)
	radius = maxf(outer, 10.0)
	inner = clampf(radius * INNER_SHARE if hole < 0.0 else hole * 0.5, 0.0, radius - 5.0)
	lo = Field.SEA_Y + base
	hi = Field.SEA_Y + maxf(top, base + 10.0)
	on = true

func clear() -> void:
	if forced: return
	on = false

## The march's floats (spare[3], spare[4]) at the clock `time`.
func put(p: PackedFloat32Array, time: float) -> void:
	if not on:
		for i in 8: p[AT + i] = 0.0
		return
	p[AT] = centre.x
	p[AT + 1] = centre.y
	p[AT + 2] = radius
	p[AT + 3] = inner
	p[AT + 4] = lo
	p[AT + 5] = hi
	p[AT + 6] = fposmod(time * TURN, TAU)
	p[AT + 7] = 1.0

## How far `p` is into the collar's smooth body (m; negative outside).
func depth(p: Vector3) -> float:
	if not on: return -1e9
	var r := Vector2(p.x, p.z).distance_to(centre)
	return minf(minf(radius - r, r - inner), minf(p.y - lo, hi - p.y))
