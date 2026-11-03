extends RefCounted
## Where the burrower's way lies in a sunk tunnel (scripts/endless/burrower_bore.gd,
## bore_spurs.gd): the angle round the bore at each distance along the path, and the
## bore's real rock at that distance, the same rock `_build_rock` lays (lumps included).
## Nothing here holds state: the same seed gives the same line on every machine.
##
## The angle round the bore is the share of the way round its section: 0 the floor's
## middle, on over the +d wall, the crown near PI, down the -d wall, TAU the floor again.
## It is a plain function of the distance, drawn from the tunnel's seed, so he reveals a
## fixed line rather than deciding one. He starts and ends on the floor's middle.

const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")

## The winding: about one turn round the bore every WIND_M m, and a wander of up to
## WIND_SWAY of a turn over about SWAY_M m, so he hangs on a wall and sweeps across it.
const WIND_M := 340.0
const WIND_SWAY := 0.4
const SWAY_M := 300.0
## The bore's middle, over the floor (a share of the crown).
const MIDDLE := 0.45
## The rock's mesh: its rings and floor as `_build_rock` lays them out.
const RING_SEGS := LandTunnels.RING_SEGS
const FLOOR_SEGS := LandTunnels.FLOOR_SEGS

## The angle round the bore at distance `at` along the path of `t` (the header).
static func angle_at(t: Tunnels.Site, at: float) -> float:
	var q := clampf(at/t.length,0.0,1.0)
	var turns := maxf(roundf(t.length/WIND_M),1.0)
	var hand := 1.0 if (hash([t.seed,"bore wind"]) & 1) == 0 else -1.0
	var sway := WIND_SWAY*TAU*t.rock.get_noise_2d(at*Tunnels.ROCK_WAVE/SWAY_M,1600.0)*sin(PI*q)
	return hand*TAU*turns*q+sway

## The bore's middle at distance `at` (world).
static func middle(t: Tunnels.Site, at: float) -> Vector3:
	var on: Array = Tunnels.at_s(t,at)
	var c: Vector2 = on[0]
	var tg: Vector2 = on[1]
	var pr := Tunnels.profile(t,at)
	var n := Vector2(-tg.y,tg.x)*(pr.y-pr.x)*0.5
	return Vector3(c.x+n.x,Tunnels.floor_at(t,at)+pr.z*MIDDLE,c.y+n.y)

## About where the rock lies at distance `at`, `angle` round: an ellipse over the bore's
## middle, no lumps, cheap enough for every frame.
static func about(t: Tunnels.Site, at: float, angle: float) -> Vector3:
	var tg: Vector2 = Tunnels.at_s(t,at)[1]
	var pr := Tunnels.profile(t,at)
	var c := cos(angle)
	return middle(t,at)+Vector3(-tg.y,0.0,tg.x)*sin(angle)*(pr.x+pr.y)*0.5+Vector3.UP*(-c)*pr.z*(MIDDLE if c > 0.0 else 1.0-MIDDLE)

## The rock round the bore at distance `at`, as `_build_rock` lays it out, closed, from
## the floor's middle on over the +d wall (the angle's way). `grain`: the site's
## LandTunnels `rock_grain`.
static func ring(t: Tunnels.Site, grain: FastNoiseLite, at: float) -> PackedVector3Array:
	var on: Array = Tunnels.at_s(t,at)
	var c: Vector2 = on[0]
	var tg: Vector2 = on[1]
	var n := Vector2(-tg.y,tg.x)
	var n3 := Vector3(n.x,0.0,n.y)
	var pr := Tunnels.profile(t,at)
	var lump := LandTunnels.rock_lump(t,at)
	var fy := Tunnels.floor_at(t,at)
	var hw := (pr.x+pr.y)*0.5
	var arch := PackedVector3Array()
	arch.resize(RING_SEGS+1)
	# k 0 at the +d wall's foot, as the angle runs: `_build_rock`'s k backwards.
	for k in RING_SEGS+1:
		var q := Tunnels.profile_point(pr,PI*float(k)/RING_SEGS)
		var x := (q.x-(pr.y-pr.x)*0.5)/hw
		var y := q.y/pr.z
		var g := Vector2(signf(x)*pow(absf(x),pr.w-1.0)/hw,pow(y,pr.w-1.0)/pr.z).normalized()
		var base := Vector3(c.x,fy,c.y)+n3*q.x+Vector3.UP*q.y
		var nz := clampf(grain.get_noise_3dv(base)*0.5+0.5,0.0,1.0)
		var calm := 1.0
		for sh: Dictionary in t.shafts:
			calm = minf(calm,smoothstep(LandTunnels.LIP_R+0.5,LandTunnels.LIP_R+4.0,Vector2(base.x,base.z).distance_to(sh.at)))
		arch[k] = base+(n3*g.x+Vector3.UP*g.y)*lump*nz*calm
	var plus := arch[0]
	var minus := arch[RING_SEGS]
	var half := FLOOR_SEGS/2
	var out := PackedVector3Array()
	for k in range(half,FLOOR_SEGS): out.append(_floor_point(t,minus,plus,float(k)/FLOOR_SEGS,lump))
	out.append_array(arch)
	for k in range(1,half+1): out.append(_floor_point(t,minus,plus,float(k)/FLOOR_SEGS,lump))
	return out

## The floor between the wall's feet, as `_build_rock` drops it.
static func _floor_point(t: Tunnels.Site, minus: Vector3, plus: Vector3, k: float, lump: float) -> Vector3:
	var v := minus.lerp(plus,k)
	if k > 0.0 and k < 1.0:
		v.y -= lump*(t.rock.get_noise_2d(v.x*3.0,v.z*3.0)*0.5+0.5)
	return v

## How far round `ring` each of its points is (m); the last is the whole way round.
static func round_m(of: PackedVector3Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(of.size())
	var total := 0.0
	for i in range(1,of.size()):
		total += of[i].distance_to(of[i-1])
		out[i] = total
	return out

## The point `u` m round the ring (`metres`: its `round_m`).
static func on_ring(of: PackedVector3Array, metres: PackedFloat32Array, u: float) -> Vector3:
	var at := fposmod(u,metres[metres.size()-1])
	var lo := 0
	var hi := metres.size()-1
	while hi-lo > 1:
		var m := (lo+hi)/2
		if metres[m] <= at: lo = m
		else: hi = m
	var k := (at-metres[lo])/maxf(metres[hi]-metres[lo],0.0001)
	return of[lo].lerp(of[hi],k)

## How far `ring` runs from `from` along `way`, a direction in the ring's plane, to the
## rock on the far side (m).
static func across(of: PackedVector3Array, from: Vector3, way: Vector3, along: Vector3) -> float:
	var side := way.cross(along).normalized()
	var best := 0.0
	for i in of.size():
		var a := of[i]-from
		var b := of[(i+1)%of.size()]-from
		var da := a.dot(side)
		var db := b.dot(side)
		if (da < 0.0) == (db < 0.0): continue
		best = maxf(best,lerpf(a.dot(way),b.dot(way),da/(da-db)))
	return best
