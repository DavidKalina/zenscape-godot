extends "res://scripts/endless/world/world_profile.gd"
## Amberlands (working name; the id lives in `ID` alone, with the folder
## scripts/endless/world/amberlands/ and the regions registry's entry): a
## windy land under a low gold sun, with the remains of giants half sunk in it
## (scripts/endless/giant_ruins.gd). No trees; amber tall grass over broad worn
## terraces and shallow valleys, broken by mountain massifs and tiered plateau
## chunks (--world=amberlands;
## docs/design/endless-flight/amberlands-round1-handoff.md). Its land recipe
## lives in scripts/endless/world/amberlands/land.gd, its paint, flora and
## layers in scripts/endless/world/amberlands/look.gd.

const ID := "amberlands"
const Land = preload("res://scripts/endless/world/amberlands/land.gd")
const Look = preload("res://scripts/endless/world/amberlands/look.gd")

func _init() -> void:
	id = ID
	title = "Amberlands"
	land = Land.recipe()
	flora = Look.flora()
	paint = Look.paint()
	layers = Look.layers()
	spawn = {"at":Vector2.ZERO,"alt":45.0,"heading":0.0}
