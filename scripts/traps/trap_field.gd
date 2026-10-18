extends Node3D
## The traps of a scene, stepped round the pilot's motor: what
## scripts/interactables/foot_pieces.gd is to slabs (a character study's
## `foot_pieces` slot, so its frame calls `before` and `after` round the
## motor's step; studies/trap_yard.gd attaches one). Each trap
## (scripts/traps/trap.gd) gets the frame, and the motor's `air` answers
## with the traps' winds summed (vectors and numbers added by key).
## `pose` is part of the slot's contract: handed to a trap that has one
## (a motif mechanic's rope, scripts/kit_isle/motif_mechanics.gd).
const PilotMotor = preload("res://scripts/pilot_motor.gd")

var study: Node3D
var motor: PilotMotor
var traps: Array = []

func _init() -> void:
	name = "TrapField"

## Hooked into `scene` (a character study).
func attach(scene: Node3D) -> void:
	study = scene
	motor = scene.motor
	scene.foot_pieces = self
	motor.air = _air

## A trap laid in the world and stepped from now on.
func add(trap: Node3D) -> Node3D:
	trap.motor = motor
	add_child(trap)
	traps.append(trap)
	return trap

func named(key: String) -> Node3D:
	for trap: Node3D in traps:
		if trap.trap_name == key: return trap
	return null

func before(delta: float) -> void:
	for trap: Node3D in traps: trap.before(delta)

func after(delta: float, events: Dictionary) -> void:
	for trap: Node3D in traps: trap.after(delta,events)

func pose(figure: Node3D) -> void:
	# A mechanic holding a rope tilts him along it (motif_mechanics.gd).
	for trap: Node3D in traps:
		if trap.has_method("rope_pose"): trap.rope_pose(figure)

## Every trap back as built.
func reset() -> void:
	for trap: Node3D in traps: trap.reset()

func _air(p: Vector3) -> Dictionary:
	var out := {}
	for trap: Node3D in traps:
		var here: Dictionary = trap.air_at(p)
		for key: Variant in here:
			out[key] = (out[key]+here[key]) if out.has(key) else here[key]
	return out
