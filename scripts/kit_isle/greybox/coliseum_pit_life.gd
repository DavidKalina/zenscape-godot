extends "res://scripts/kit_isle/kit_life.gd"
## The Coliseum Pit's life underground (scripts/kit_isle/greybox/
## gb_coliseum_pit.gd `life_script`): kit_life's undergrowth (ferns, shrubs,
## mushrooms, leaf beds, a few mossy logs on its turf) and its fireflies,
## the city going back to growth. No butterflies, birds, wind litter or
## tokens: there is no sky down here.

func begin(isle: Node3D, args: PackedStringArray) -> void:
	super.begin(isle,args)
	flags.butterflies = false
	flags.birds = false
	flags.wind = false
	flags.tokens = false
