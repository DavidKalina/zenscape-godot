extends RefCounted
## The chase camera's sight in the tunnels and the burrower's steering in C++
## (native/terrain_kernels/bore_sight_bind.h): ZenScapeHallSolid (LandHalls
## `inside`), ZenScapeBoreSight (LandTunnels `near`, `tube`, `inside`,
## `land_y`, `sight`) and ZenScapeBurrowerSteer (burrower.gd's trunk gather
## and its steering round them). The GDScript stays the reference and
## answers where these are null: no library, a stale one, or
## --sight-native=0 (or --gdscript-kernels). Handoff:
## docs/design/endless-flight/handoff-native-sight-steer.md.

const LaunchArgs = preload("res://scripts/launch_args.gd")

## Each class's interface version (its C++ `version`).
const HALL_VERSION := 1
const BORE_VERSION := 1
const STEER_VERSION := 1

static var _wanted := -1

## Whether the flags allow it.
static func wanted() -> bool:
	if _wanted < 0:
		_wanted = 1
		for a: String in LaunchArgs.user_args():
			if a == "--sight-native=0" or a == "--gdscript-kernels": _wanted = 0
	return _wanted == 1

## A new `cls` of interface `version`, or null.
static func make(cls: StringName, version: int) -> Object:
	if not wanted() or not ClassDB.class_exists(cls) or not ClassDB.can_instantiate(cls): return null
	var o: Object = ClassDB.instantiate(cls)
	if o == null or int(o.call(&"version")) != version: return null
	return o

static func hall_solid() -> Object:
	return make(&"ZenScapeHallSolid",HALL_VERSION)

static func bore_sight() -> Object:
	return make(&"ZenScapeBoreSight",BORE_VERSION)

static func steer() -> Object:
	return make(&"ZenScapeBurrowerSteer",STEER_VERSION)

## A Vector2i key as one int (LandHalls' records, published by it).
static func key_id(k: Vector2i) -> int:
	return (k.x << 32) | (k.y & 0xffffffff)
