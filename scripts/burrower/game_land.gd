extends "res://scripts/burrower/burrower_ground.gd"
## Endless flight's land as the burrower sees it (burrower_ground.gd): the
## land field's height and colour, the sea's and rivers' water
## (studies/endless_flight.gd `water_at`). No rim: it runs anywhere; what
## the land holds (rocks, ruins, trees, steep ground) comes in later
## (spec-burrower-flight.md, task 3).

const Field = preload("res://scripts/endless/land_field.gd")

## The game (studies/endless_flight.gd): its `field` and `water_at`.
var game: Node3D

func _init() -> void:
	name = "BurrowerGround"

func setup(the_game: Node3D) -> void:
	game = the_game

func height(x: float, z: float) -> float:
	return game.field.height(x,z)

func colour(x: float, z: float, y: float, nm: Vector3) -> Color:
	return game.field.colour(x,z,y,nm.y,1.0)

## The sea's swell or a river's or lake's level (Field.SEA_Y and under on
## dry land, which is far over it).
func water_y(x: float, z: float) -> float:
	return game.water_at(Vector3(x,Field.SEA_Y,z))
