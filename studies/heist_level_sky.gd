extends "res://studies/islet_yard_sky.gd"
## The heist level's sky (studies/heist_level.gd): the islet yard's, with
## home (studies/heist_home.gd) among its places, so the cloud towers keep
## off it and the puffs drift round it as round the heist isle.

func places() -> Array:
	return scene.home_places() if scene != null and scene.has_method("home_places") else []
