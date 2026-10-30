extends RefCounted
## The region map of the doors world (scripts/endless/world/profiles/
## doors.gd): two half-worlds, region 0 west of `split` and region 1 east of
## it, `offset` m apart, so each side's home (x = 0 and x = offset) lies
## offset/2 from the one border band, past the far view. The doors
## (scripts/endless/region_doors.gd) carry the plane `offset` m across.
##
## The same answers as region_map.gd (weights, dominant, cell_at,
## region_of, site, warp, count, size, blend), so the land's blend
## (land_blend.gd), the paint and the sky read it unchanged. Pure maths on
## immutable numbers: thread-safe.

## From one side's home to the other's (m, along x).
var size := 50000.0
## The band's width (m).
var blend := 1500.0
var seed := 1
## Where region 1 takes over (m, x).
var split := 25000.0
var _n := 2

func _init(offset: float, band: float, regions: int) -> void:
	size = maxf(offset,4000.0)
	blend = clampf(band,1.0,size*0.25)
	split = size*0.5
	_n = maxi(regions,1)

func count() -> int:
	return _n

func warp(x: float, z: float) -> Vector2:
	return Vector2(x,z)

## Cell i is side i (0 west, 1 east); its site the side's home.
func site(i: int, _j: int) -> Vector2:
	return Vector2(clampi(i,0,1)*size,0.0)

func region_of(i: int, _j: int) -> int:
	return mini(clampi(i,0,1),_n-1)

func cell_at(x: float, _z: float) -> Vector2i:
	return Vector2i(1 if x >= split and _n > 1 else 0,0)

func weights(x: float, _z: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_n)
	if _n == 1:
		out[0] = 1.0
		return out
	var east := smoothstep(split-blend*0.5,split+blend*0.5,x)
	out[0] = 1.0-east
	out[1] = east
	return out

func dominant(x: float, z: float) -> int:
	return cell_at(x,z).x
