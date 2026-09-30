extends Node3D
## The small ambient life that answers what was built (docs/scenic/life.md):
## dragonflies over still ponds, butterflies over flowering meadow, a
## woodpecker drumming on snags and geese passing in a V. Each lives in its own
## script and reads LandLife's survey and clock; this node only owns them and
## hands them the frame. Nothing is saved: they come and go with the season,
## the hour and the weather.

const Dragonflies = preload("res://scripts/life_dragonflies.gd")
const Butterflies = preload("res://scripts/life_butterflies.gd")
const Woodpecker = preload("res://scripts/life_woodpecker.gd")
const Geese = preload("res://scripts/life_geese.gd")

var dragonflies: Node3D
var butterflies: Node3D
var woodpecker: Node3D
var geese: Node3D
## Microseconds all four took this frame, and the most in one.
var last_usec := 0
var worst_usec := 0

func setup(life: Node3D) -> void:
	name = "SmallLife"
	for entry: Array in [["dragonflies",Dragonflies],["butterflies",Butterflies],["woodpecker",Woodpecker],["geese",Geese]]:
		var node: Node3D = entry[1].new()
		add_child(node)
		node.setup(life)
		set(entry[0],node)

func clear() -> void:
	for node: Node3D in get_children(): node.clear()

func advance(step: float) -> void:
	var began := Time.get_ticks_usec()
	for node: Node3D in get_children(): node.advance(step)
	last_usec = Time.get_ticks_usec()-began
	worst_usec = maxi(worst_usec,last_usec)
