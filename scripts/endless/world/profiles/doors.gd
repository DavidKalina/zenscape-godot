extends "res://scripts/endless/world/profiles/regions.gd"
## Doors: one region at a time, each endless and whole, joined by a door
## flown through (--world=doors, the default; docs/design/endless-flight/
## doors-handoff.md).
##
## The land is the regions world's engine over a map of two half-worlds
## (scripts/endless/world/door_map.gd): wilderness round x = 0 (the start),
## amberlands round x = OFFSET, the one border band half way, past the far
## view from either home. The doors (scripts/endless/region_doors.gd) stand
## a wall of cloud on each side and carry the plane OFFSET m across.
##
## Knobs:
##   --door-offset=M   how far apart the two homes are (OFFSET)
##   --regions=a:1:start,b:1   the two regions (the first is home; only the
##                     first two are used)

const DoorMap = preload("res://scripts/endless/world/door_map.gd")

## From wilderness's home to amberlands' (m, along x): each 25 km from the
## band, past the farthest view (EndlessLook FOG_END x LandStream's widest).
const OFFSET := 50000.0

## The far side's home, from the near side's (m, XZ).
var offset := Vector2(OFFSET,0.0)

func _init() -> void:
	super()
	id = "doors"
	title = "Doors"

func _region_list() -> Array:
	return [{"id":"wilderness","share":1.0,"start":true},{"id":"amberlands","share":1.0,"start":false}]

func _make_map(_size: float, band: float, _layout_seed: int, shares: PackedFloat32Array) -> RefCounted:
	var far := OFFSET
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--door-offset="): far = a.get_slice("=",1).to_float()
	var m: RefCounted = DoorMap.new(far,band,mini(shares.size(),2))
	offset = Vector2(m.size,0.0)
	return m

## The start: the home region's own start (its spawn), on the near side.
func _place_start() -> void:
	start_region = 0
	spawn = (regions[0].spawn as Dictionary).duplicate(true)

## The side (region index) world XZ (x, z) is on: 0 home, 1 the far side.
func side_of(x: float, z: float) -> int:
	return int(map.dominant(x,z))
