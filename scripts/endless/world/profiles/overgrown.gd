extends "res://scripts/endless/world/world_profile.gd"
## Overgrown (working name): the world of the old builders' ruins, grown
## over: warm red-orange-yellow grass, ruins to fly through, a real sea
## (--world=overgrown). Its land recipe lives in
## scripts/endless/world/overgrown/land.gd, its paint, flora and layers in
## scripts/endless/world/overgrown/look.gd, so each can change alone.

const Land = preload("res://scripts/endless/world/overgrown/land.gd")
const Look = preload("res://scripts/endless/world/overgrown/look.gd")

func _init() -> void:
	id = "overgrown"
	title = "Overgrown"
	land = Land.recipe()
	flora = Look.flora()
	paint = Look.paint()
	layers = Look.layers()
	spawn = {"at":Vector2.ZERO,"alt":45.0,"heading":0.0}
