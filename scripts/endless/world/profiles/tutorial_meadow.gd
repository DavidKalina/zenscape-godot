extends "res://scripts/endless/world/profiles/wilderness.gd"
## The tutorial's meadow: the land the first flight is taught over, one side
## of the `tutorial` world (profiles/tutorial.gd), playable alone with
## --world=tutorial_meadow. Wilderness's grass, flowers, hour and mood over a
## flat meadow: no hills, ranges, peaks, valleys, rivers or coast, no rock
## shapes, arches, halls, tunnels or splits. Its trees and ponds are gated by
## the lesson's stage (profiles/tutorial.gd `layer_at`, `pond_gate`); alone
## it has both.

func _init() -> void:
	super()
	id = "tutorial_meadow"
	title = "Tutorial meadow"
	# Flat: the continents, hills, ranges, peaks and valleys flattened, the
	# carve off, no rivers and no coast (the ponds stay: the lesson gates them).
	land.merge({"continent_swing":0.0,"hill_tall":0.0,"mountains":0.0,"peaks":0.0,"valleys":0.0,"carve":0.0,
		"rivers":0.0,"ponds":0.5},true)
	land.erase("coast_half")
	# Copses, not woods: dense enough that one is near wherever TREES comes.
	flora = {"forest":0.6,"forest_meadows":1.0,"tree_weights":PackedFloat32Array(),"grass":1.0,"flowers":true}
	layers = {"trees":true,"grass":true,"birds":true,"fish":true,"tunnels":0.0,"halls":0.0,"arches":0.0,"splits":0.0,
		"stacks":0.0,"hoodoos":0.0,"traffic":-1}
	spawn = {"at":Vector2.ZERO,"alt":18.0,"heading":0.0}
	# Calm: past the wind field's land (the tutorial's meadow is) a light
	# breeze to look at, under what buffets the plane (WindField `beyond`;
	# the tutorial world takes its paint from this, its start).
	paint["wind_beyond"] = 0.25
