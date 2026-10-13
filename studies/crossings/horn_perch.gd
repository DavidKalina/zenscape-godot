extends Node3D
## A perch's stone wind horn (scripts/ruin_kit_horn.gd) with the stand-in's
## face (studies/crossings/horn_stand_in.gd): its "Head" turns, its "Mouth"
## is where the ball leaves, and `aim_at`, `tell`, `fired`, `disabled`,
## `is_disabled` go to the horn's own rig (scripts/wind_horn.gd).
const RuinKitHorn = preload("res://scripts/ruin_kit_horn.gd")

var horn: Node3D
var rig: Node

func setup(seed_value: int, weathered: float) -> void:
	name = "Horn"
	horn = RuinKitHorn.wind_horn(seed_value,weathered)
	add_child(horn)
	rig = RuinKitHorn.rig(horn)

func aim_at(p: Vector3, delta: float) -> void:
	rig.aim_at(p,delta)

func tell(share: float) -> void:
	rig.tell(share if share > 0.0 else -1.0)

func fired() -> void:
	rig.fired()

func disabled(seconds: float) -> void:
	rig.disabled(seconds)

func is_disabled() -> bool:
	return rig.is_disabled()

func aim_error(p: Vector3) -> float:
	return rig.aim_error(p)

func facing() -> Vector3:
	return rig.facing()
