class_name Beacon
extends Node3D
## A place every Olmec turns to while it is "lit": a sound's echo out of a
## refuge's mouth (scripts/city_kit_refuges.gd), and the base of a heard
## noise's lure (scripts/enemies/body_hearing.gd `Lure`). Lit, every
## headless body and calm whole Olmec within `draw` m (flat) hears it the
## way a body hears its head's call (scripts/enemies/headless_body.gd,
## `_beacon_pick`), turns to it and goes there by its routes, stands looking
## at it `dwell` s, then tires of it (its `beacon_rest` knob, s) unless it is
## lit again. It lights nothing.
##
## Any piece adds one as a child where the sound comes from:
##   var b := Beacon.new()
##   b.position = Vector3(0, 1, 0)
##   b.stand = Vector3(0, 0, 3)      # optional: where an Olmec comes to, local
##   b.draw = 45.0
##   piece.add_child(b)
##   b.lit = false ... b.light()     # lit_changed(on) fires
## It joins the group BEACONS while in the tree.

signal lit_changed(on: bool)

const BEACONS := &"beacons"

## How strongly it draws, against other beacons (a body takes the one with
## the most `pull` / (1 + d / `draw`)).
@export var pull := 1.0
## How far off (m, flat) it draws an Olmec.
@export var draw := 8.0
## Where an Olmec comes to, in its own space (INF: under it, on the ground
## the body finds there).
@export var stand := Vector3.INF
## How near it comes to `stand` (m, past its own half length) before it
## stops and looks, and how long it looks (s).
@export var gather := 3.0
@export var dwell := 6.0
## Sounding: it draws. Set it, or `light()` / `douse()`.
@export var lit := true:
	set(v):
		if v == lit: return
		lit = v
		if lit: lightings += 1
		lit_changed.emit(lit)

## Times it was lit (a beacon lit again is news to those that tired of it).
var lightings := 0

func _enter_tree() -> void:
	add_to_group(BEACONS)

func light() -> void:
	lit = true

func douse() -> void:
	lit = false

## How far off it draws (m, flat).
func draw_range() -> float:
	return draw

## Where an Olmec comes to (world).
func stand_at() -> Vector3:
	if stand == Vector3.INF: return global_position
	return to_global(stand)

## The lit beacons in `tree`.
static func all_lit(tree: SceneTree) -> Array:
	var out := []
	if tree == null: return out
	for b in tree.get_nodes_in_group(BEACONS):
		if b is Beacon and b.lit and b.is_inside_tree():
			out.append(b)
	return out
